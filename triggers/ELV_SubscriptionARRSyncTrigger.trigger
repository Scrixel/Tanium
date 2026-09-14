trigger ELV_SubscriptionARRSyncTrigger on Ruby__Subscription__c (after insert, after update) {
    ELV_OpportunitySubscriptionService.synchronise(
        ELV_OpportunitySubscriptionEntryUtility.changedSubscriptions(
            Trigger.new, Trigger.isUpdate ? Trigger.oldMap : null
        )
    );
}