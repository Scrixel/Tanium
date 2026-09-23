/** Resolver methods called by existing Subscription, Asset Order Product and OrderItem handlers. */
public with sharing class ELV_OpportunitySubscriptionEntryUtility {
    public static Set<Id> changedSubscriptions(
        List<Ruby__Subscription__c> subscriptions,
        Map<Id, Ruby__Subscription__c> oldMap
    ) {
        Set<Id> ids = new Set<Id>();
        if (subscriptions == null) return ids;
        for (Ruby__Subscription__c current : subscriptions) {
            Ruby__Subscription__c prior = oldMap == null ? null : oldMap.get(current.Id);
            if (prior == null ||
                current.Ruby__RenewalOpportunity__c != prior.Ruby__RenewalOpportunity__c ||
                current.Ruby__Status__c != prior.Ruby__Status__c ||
                current.Ruby__SubscriptionStartDate__c != prior.Ruby__SubscriptionStartDate__c ||
                current.Ruby__SubscriptionEndDate__c != prior.Ruby__SubscriptionEndDate__c ||
                current.Ruby__OriginalSubscription__c != prior.Ruby__OriginalSubscription__c ||
                current.Ruby__CancellationDate__c != prior.Ruby__CancellationDate__c) ids.add(current.Id);
        }
        return ids;
    }

    public static Set<Id> subscriptionsForAssetOrderProducts(
        List<Ruby__AssetOrderProduct__c> newRows,
        List<Ruby__AssetOrderProduct__c> oldRows
    ) {
        Set<Id> ids = new Set<Id>();
        if (newRows != null) for (Ruby__AssetOrderProduct__c row : newRows)
            if (row.Ruby__Subscription__c != null) ids.add(row.Ruby__Subscription__c);
        if (oldRows != null) for (Ruby__AssetOrderProduct__c row : oldRows)
            if (row.Ruby__Subscription__c != null) ids.add(row.Ruby__Subscription__c);
        return ids;
    }

    public static Set<Id> subscriptionsForChangedOrderItems(
        List<OrderItem> items,
        Map<Id, OrderItem> oldMap
    ) {
        Set<Id> itemIds = new Set<Id>();
        if (items != null) for (OrderItem current : items) {
            OrderItem prior = oldMap == null ? null : oldMap.get(current.Id);
            if (prior == null || current.ELV_ARR_Amount__c != prior.ELV_ARR_Amount__c ||
                current.Ruby__LineType__c != prior.Ruby__LineType__c ||
                current.Ruby__SubscriptionStartDate__c != prior.Ruby__SubscriptionStartDate__c ||
                current.Ruby__SubscriptionEndDate__c != prior.Ruby__SubscriptionEndDate__c) itemIds.add(current.Id);
        }
        Set<Id> subscriptionIds = new Set<Id>();
        if (!itemIds.isEmpty()) for (Ruby__AssetOrderProduct__c row : [
            SELECT Ruby__Subscription__c FROM Ruby__AssetOrderProduct__c
            WHERE Ruby__OrderProduct__c IN :itemIds AND Ruby__Subscription__c != null
        ]) subscriptionIds.add(row.Ruby__Subscription__c);
        return subscriptionIds;
    }
}