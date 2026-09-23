public with sharing class ELV_OppSubTriggerHandler {
    @TestVisible private static Boolean isHandling = false;
    public static void afterChange(
        List<Ruby__OpportunitySubscription__c> newRows,
        List<Ruby__OpportunitySubscription__c> oldRows
    ) {
        if (isHandling) return;
        Set<Id> opportunityIds = ELV_OppSubTriggerUtility.opportunityIds(newRows);
        opportunityIds.addAll(ELV_OppSubTriggerUtility.opportunityIds(oldRows));
        isHandling = true;
        try { ELV_OpportunityARRService.recalculate(opportunityIds); }
        finally { isHandling = false; }
    }
}