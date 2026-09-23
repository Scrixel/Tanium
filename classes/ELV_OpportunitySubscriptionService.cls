/** TNCI-139 / ELV-CPQ-036. Owns Opportunity Subscription junction rows only. */
public with sharing class ELV_OpportunitySubscriptionService {
    @TestVisible private static Boolean isSynchronising = false;
    private static final String STATUS_ACTIVE = 'Active';
    private static final String STATUS_INACTIVE = 'Inactive';
    private static final String STATUS_DRAFT = 'Draft';
    private static final Set<String> CANCEL_STATUSES = new Set<String>{'Cancelled', 'ScheduledForCancel'};
    /** Fallback used when no ELV_ARR_Settings__c record supplies a tolerance. */
    @TestVisible private static final Integer DEFAULT_ALIGNMENT_DAYS = 14;

    public static void synchronise(Set<Id> subscriptionIds) {
        if (isSynchronising || subscriptionIds == null || subscriptionIds.isEmpty()) return;
        isSynchronising = true;
        try {
            Map<Id, Ruby__Subscription__c> subscriptions = new Map<Id, Ruby__Subscription__c>([
                SELECT Id, CurrencyIsoCode, Ruby__RenewalOpportunity__c,
                       Ruby__RenewalOpportunity__r.IsClosed,
                       Ruby__RenewalOpportunity__r.CloseDate,
                       Ruby__Status__c, Ruby__SubscriptionStartDate__c,
                       Ruby__SubscriptionEndDate__c, Ruby__CancellationDate__c
                FROM Ruby__Subscription__c WHERE Id IN :subscriptionIds
            ]);
            if (subscriptions.isEmpty()) return;

            Map<Id, Ruby__OpportunitySubscription__c> existingBySubscription = new Map<Id, Ruby__OpportunitySubscription__c>();
            for (Ruby__OpportunitySubscription__c row : [
                SELECT Id, Ruby__Subscription__c, Ruby__Opportunity__c, ELV_ARR_Amount__c,
                       ELV_Max_End_Date__c, ELV_Order_Product_Count__c, ELV_Status__c,
                       ELV_Include_in_ARR__c, ELV_Subscription_Status__c,
                       ELV_Subscription_Start_Date__c, ELV_Subscription_End_Date__c,
                       ELV_Term_Aligned__c, ELV_External_Id__c
                FROM Ruby__OpportunitySubscription__c
                WHERE Ruby__Subscription__c IN :subscriptionIds
            ]) existingBySubscription.put(row.Ruby__Subscription__c, row);

            Map<Id, Totals> totalsBySubscription = calculateTotals(subscriptionIds, subscriptions);
            List<Ruby__OpportunitySubscription__c> upserts = new List<Ruby__OpportunitySubscription__c>();
            List<Ruby__OpportunitySubscription__c> deletes = new List<Ruby__OpportunitySubscription__c>();

            for (Ruby__Subscription__c subscription : subscriptions.values()) {
                Ruby__OpportunitySubscription__c existing = existingBySubscription.get(subscription.Id);
                Id opportunityId = subscription.Ruby__RenewalOpportunity__c;

                // Closed Opportunities are booked history: do not create, update, or delete their rows.
                if (opportunityId != null && subscription.Ruby__RenewalOpportunity__r.IsClosed) continue;

                if (opportunityId == null) {
                    if (existing != null) {
                        existing.ELV_Status__c = STATUS_INACTIVE;
                        existing.ELV_Include_in_ARR__c = false;
                        existing.ELV_ARR_Last_Stamped__c = System.now();
                        upserts.add(existing);
                    }
                    continue;
                }

                // A master-detail junction cannot be reparented. Remove a wrong-opportunity row;
                // the deterministic external id creates its replacement below.
                if (existing != null && existing.Ruby__Opportunity__c != opportunityId) {
                    deletes.add(existing);
                    existing = null;
                }

                Totals totals = totalsBySubscription.containsKey(subscription.Id)
                    ? totalsBySubscription.get(subscription.Id) : new Totals();
                // Term alignment anchors on the renewal Opportunity Close Date, which carries the
                // renewal service start in this org. Tolerance comes from ELV_ARR_Settings__c.
                Boolean aligned = isTermAligned(
                    subscription.Ruby__RenewalOpportunity__r.CloseDate,
                    subscription.Ruby__SubscriptionEndDate__c
                );
                Boolean draft = STATUS_DRAFT.equalsIgnoreCase(subscription.Ruby__Status__c);
                Boolean cancelledAtTerm = CANCEL_STATUSES.contains(subscription.Ruby__Status__c) &&
                    subscription.Ruby__CancellationDate__c != null &&
                    subscription.Ruby__SubscriptionEndDate__c != null &&
                    subscription.Ruby__CancellationDate__c <= subscription.Ruby__SubscriptionEndDate__c;
                if (cancelledAtTerm) totals.amount = 0;

                Ruby__OpportunitySubscription__c row = existing == null
                    ? new Ruby__OpportunitySubscription__c() : existing;
                if (existing == null) {
                    row.Ruby__Subscription__c = subscription.Id;
                    row.Ruby__Opportunity__c = opportunityId;
                    row.CurrencyIsoCode = subscription.CurrencyIsoCode;
                }
                row.ELV_External_Id__c = String.valueOf(subscription.Id) + '-' + String.valueOf(opportunityId);
                row.ELV_ARR_Amount__c = totals.amount.setScale(2);
                row.ELV_Max_End_Date__c = totals.maxEndDate;
                row.ELV_Order_Product_Count__c = totals.count;
                row.ELV_Status__c = STATUS_ACTIVE;
                row.ELV_Subscription_Status__c = subscription.Ruby__Status__c;
                row.ELV_Subscription_Start_Date__c = subscription.Ruby__SubscriptionStartDate__c;
                row.ELV_Subscription_End_Date__c = subscription.Ruby__SubscriptionEndDate__c;
                row.ELV_Term_Aligned__c = aligned;
                // Status is deliberately not an inclusion filter except Draft.
                row.ELV_Include_in_ARR__c = aligned && !draft;
                row.ELV_ARR_Last_Stamped__c = System.now();
                upserts.add(row);
            }

            if (!deletes.isEmpty()) delete deletes;
            if (!upserts.isEmpty()) upsert upserts ELV_External_Id__c;
        } finally {
            isSynchronising = false;
        }
    }

    @TestVisible
    private static Map<Id, Totals> calculateTotals(
        Set<Id> subscriptionIds,
        Map<Id, Ruby__Subscription__c> subscriptions
    ) {
        Map<Id, Totals> result = new Map<Id, Totals>();
        for (Id subscriptionId : subscriptionIds) result.put(subscriptionId, new Totals());

        // Deliberately no Ruby__IsFromLatestSubscription__c predicate. Cancellation negatives
        // must net against originals carried by superseded versions.
        for (Ruby__AssetOrderProduct__c joinRow : [
            SELECT Ruby__Subscription__c,
                   Ruby__OrderProduct__r.ELV_ARR_Amount__c,
                   Ruby__OrderProduct__r.Ruby__LineType__c,
                   Ruby__OrderProduct__r.Ruby__SubscriptionStartDate__c,
                   Ruby__OrderProduct__r.Ruby__SubscriptionEndDate__c
            FROM Ruby__AssetOrderProduct__c
            WHERE Ruby__Subscription__c IN :subscriptionIds
              AND Ruby__OrderProduct__c != null
        ]) {
            Ruby__Subscription__c subscription = subscriptions.get(joinRow.Ruby__Subscription__c);
            OrderItem item = joinRow.Ruby__OrderProduct__r;
            Date termEnd = subscription.Ruby__SubscriptionEndDate__c;
            if (item == null || 'SummaryItem'.equals(item.Ruby__LineType__c)) continue;
            if (termEnd != null && item.Ruby__SubscriptionStartDate__c != null &&
                item.Ruby__SubscriptionStartDate__c > termEnd) continue;
            if (termEnd != null && item.Ruby__SubscriptionEndDate__c != null &&
                item.Ruby__SubscriptionEndDate__c < termEnd) continue;

            Totals totals = result.get(subscription.Id);
            totals.amount += item.ELV_ARR_Amount__c == null ? 0 : item.ELV_ARR_Amount__c;
            totals.count++;
            if (item.Ruby__SubscriptionEndDate__c != null &&
                (totals.maxEndDate == null || item.Ruby__SubscriptionEndDate__c > totals.maxEndDate)) {
                totals.maxEndDate = item.Ruby__SubscriptionEndDate__c;
            }
        }
        return result;
    }

    /** Tolerance in days, from the hierarchy custom setting, falling back to 14. */
    @TestVisible private static Integer alignmentDays() {
        ELV_ARR_Settings__c settings = ELV_ARR_Settings__c.getInstance();
        if (settings == null || settings.ELV_Term_Alignment_Days__c == null) return DEFAULT_ALIGNMENT_DAYS;
        return Integer.valueOf(settings.ELV_Term_Alignment_Days__c);
    }

    @TestVisible private static Boolean isTermAligned(Date serviceStart, Date subscriptionEnd) {
        return serviceStart == null || subscriptionEnd == null ||
            Math.abs(subscriptionEnd.addDays(1).daysBetween(serviceStart)) <= alignmentDays();
    }

    @TestVisible private class Totals {
        Decimal amount = 0;
        Integer count = 0;
        Date maxEndDate;
    }
}