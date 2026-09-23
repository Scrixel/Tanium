public with sharing class ELV_SubscriptionTriggerHandler extends TriggerHandler {
    private List<Ruby__Subscription__c> subs;
    private Map<Id, Ruby__Subscription__c> oldMap;

    public ELV_SubscriptionTriggerHandler() {
        super('ELV_SubscriptionTriggerHandler');
        this.subs = (List<Ruby__Subscription__c>) Trigger.new;
        this.oldMap = (Map<Id, Ruby__Subscription__c>) Trigger.oldMap;
    }

    public override void afterInsert() {
        System.debug(LoggingLevel.INFO, 'ELV_SubscriptionTriggerHandler.afterInsert started. Subscription count=' + subs.size());
        Ruby_SubscriptionTriggerUtility.populateSupportedAsset(subs);
        ELV_RenewalOppCapService.stampFromRenewalLinkChanges(subs, null);

        // ELV-CPQ-036 / GAP-02. A new Subscription can establish a renewal baseline.
        ELV_OpportunitySubscriptionService.synchronise(subscriptionIds(subs));
    }

    public override void afterUpdate() {
        System.debug(LoggingLevel.INFO, 'ELV_SubscriptionTriggerHandler.afterUpdate started. Subscription count=' + subs.size());
        for (Ruby__Subscription__c sub : subs) {
            Ruby__Subscription__c oldSub = oldMap.get(sub.Id);
            System.debug(LoggingLevel.INFO, 'ELV_SubscriptionTriggerHandler.afterUpdate evaluating subscription. Subscription Id=' + sub.Id + ', subscription name=' + sub.Name + ', old status=' + oldSub?.Ruby__Status__c + ', new status=' + sub.Ruby__Status__c + ', old order product=' + oldSub?.Ruby__OrderProduct__c + ', new order product=' + sub.Ruby__OrderProduct__c);
        }
        Ruby_SubscriptionTriggerUtility.populateSupportedAsset(subs, oldMap);
        ELV_RenewalOppCapService.stampFromRenewalLinkChanges(subs, oldMap);

        // ELV-CPQ-036 / GAP-02. Refresh only when a Subscription field used by the
        // Opportunity Subscription service changes.
        ELV_OpportunitySubscriptionService.synchronise(changedARRSubscriptionIds(subs, oldMap));
    }

    @TestVisible
    private static Set<Id> subscriptionIds(List<Ruby__Subscription__c> subscriptions) {
        Set<Id> ids = new Set<Id>();
        if (subscriptions == null) return ids;
        for (Ruby__Subscription__c subscription : subscriptions) {
            if (subscription.Id != null) ids.add(subscription.Id);
        }
        return ids;
    }

    @TestVisible
    private static Set<Id> changedARRSubscriptionIds(
        List<Ruby__Subscription__c> subscriptions,
        Map<Id, Ruby__Subscription__c> oldSubscriptions
    ) {
        Set<Id> ids = new Set<Id>();
        if (subscriptions == null) return ids;
        for (Ruby__Subscription__c subscription : subscriptions) {
            Ruby__Subscription__c oldSubscription = oldSubscriptions == null ? null : oldSubscriptions.get(subscription.Id);
            if (oldSubscription == null || isARRRelevantChange(subscription, oldSubscription)) {
                ids.add(subscription.Id);
            }
        }
        return ids;
    }

    @TestVisible
    private static Boolean isARRRelevantChange(
        Ruby__Subscription__c subscription,
        Ruby__Subscription__c oldSubscription
    ) {
        return subscription.Ruby__RenewalOpportunity__c != oldSubscription.Ruby__RenewalOpportunity__c ||
            subscription.Ruby__Status__c != oldSubscription.Ruby__Status__c ||
            subscription.Ruby__SubscriptionStartDate__c != oldSubscription.Ruby__SubscriptionStartDate__c ||
            subscription.Ruby__SubscriptionEndDate__c != oldSubscription.Ruby__SubscriptionEndDate__c ||
            subscription.Ruby__OriginalSubscription__c != oldSubscription.Ruby__OriginalSubscription__c;
    }
}