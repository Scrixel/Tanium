trigger ELV_OpportunitySubscriptionTrigger on Ruby__OpportunitySubscription__c
    (after insert, after update, after delete, after undelete) {
    ELV_OppSubTriggerHandler.afterChange(
        (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) ? Trigger.new : null,
        (Trigger.isUpdate || Trigger.isDelete) ? Trigger.old : null
    );
}