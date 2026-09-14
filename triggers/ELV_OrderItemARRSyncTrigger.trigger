trigger ELV_OrderItemARRSyncTrigger on OrderItem (after update) {
    Set<Id> subscriptionIds = ELV_OpportunitySubscriptionEntryUtility.subscriptionsForChangedOrderItems(
        Trigger.new, Trigger.oldMap
    );
    ELV_OpportunitySubscriptionService.synchronise(subscriptionIds);
}