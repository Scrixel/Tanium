/**
 * TNCI-135 / ELV-CPQ-068
 * Normalizes Quote renewal-uplift policy inputs before pricing evaluation.
 */
public with sharing class ELV_RenewalUpliftQuotePolicy {
    public static void apply(List<Quote> quotes) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> endUserIds = new Set<Id>();
        for (Quote quoteRecord : quotes) {
            if (quoteRecord.AccountId != null) {
                accountIds.add(quoteRecord.AccountId);
            }
            if (isPartnerRenewal(quoteRecord)) {
                endUserIds.add(resolvedEndUserId(quoteRecord));
            }
        }
        Map<Id, Account> accountsById = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountsById = new Map<Id, Account>([
                SELECT Id, Sector__c, Region__c
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }
        for (Quote quoteRecord : quotes) {
            normalize(quoteRecord, accountsById.get(quoteRecord.AccountId));
        }
        Set<Id> customersWithPriorPartnerRenewals = new Set<Id>();
        if (!endUserIds.isEmpty()) {
            for (AggregateResult result : [
                SELECT ELV_End_User_Account__c customerId
                FROM Ruby__Subscription__c
                WHERE ELV_End_User_Account__c IN :endUserIds
                  AND Ruby__OrderProduct__r.Order.Quote.Opportunity.StageName = 'Closed Won'
                  AND Ruby__OrderProduct__r.Order.Quote.ELV_Is_Renewal__c = true
                  AND Ruby__OrderProduct__r.Order.Quote.ELV_Partner__c != null
                GROUP BY ELV_End_User_Account__c
            ]) {
                customersWithPriorPartnerRenewals.add((Id) result.get('customerId'));
            }
        }
        for (Quote quoteRecord : quotes) {
            Id customerId = resolvedEndUserId(quoteRecord);
            quoteRecord.ELV_Is_First_Partner_Renewal__c = isPartnerRenewal(quoteRecord)
                && customerId != null
                && !customersWithPriorPartnerRenewals.contains(customerId);
        }
    }

    private static void normalize(Quote quoteRecord, Account quoteAccount) {
        if (quoteRecord.ELV_Business_Motion_Oppty__c == 'MSP') {
            quoteRecord.ELV_Uplift_Route_To_Market__c = 'MSP';
        } else if (quoteRecord.ELV_Distributor__c != null) {
            quoteRecord.ELV_Uplift_Route_To_Market__c = 'Distributor';
        } else if (quoteRecord.ELV_Partner__c != null || quoteRecord.ELV_Downstream_Reseller__c != null) {
            quoteRecord.ELV_Uplift_Route_To_Market__c = 'Partner/Resale';
        } else {
            quoteRecord.ELV_Uplift_Route_To_Market__c = 'Direct';
        }
        quoteRecord.ELV_Exclude_Uplift__c = quoteAccount != null
            && (containsIgnoreCase(quoteAccount.Sector__c, 'Federal')
                || containsIgnoreCase(quoteAccount.Region__c, 'Japan'));
    }

    private static Boolean containsIgnoreCase(String value, String target) {
        return !String.isBlank(value) && value.toLowerCase().contains(target.toLowerCase());
    }

    private static Boolean isPartnerRenewal(Quote quoteRecord) {
        return quoteRecord.ELV_Is_Renewal__c == true
            && (quoteRecord.ELV_Uplift_Route_To_Market__c == 'Partner/Resale'
                || quoteRecord.ELV_Uplift_Route_To_Market__c == 'Distributor');
    }

    private static Id resolvedEndUserId(Quote quoteRecord) {
        return quoteRecord.ELV_End_User_Account__c == null ? quoteRecord.AccountId : quoteRecord.ELV_End_User_Account__c;
    }
}