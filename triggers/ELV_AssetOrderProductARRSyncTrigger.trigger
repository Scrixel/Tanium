trigger ELV_AssetOrderProductARRSyncTrigger on Ruby__AssetOrderProduct__c
    (after insert, after update, after delete, after undelete) {
    Set<Id> subscriptionIds = ELV_OpportunitySubscriptionEntryUtility.subscriptionsForAssetOrderProducts(
        (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) ? Trigger.new : null,
        (Trigger.isUpdate || Trigger.isDelete) ? Trigger.old : null
    );
    ELV_OpportunitySubscriptionService.synchronise(subscriptionIds);
}