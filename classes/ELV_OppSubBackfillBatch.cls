public with sharing class ELV_OppSubBackfillBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id FROM Ruby__Subscription__c
            WHERE Ruby__RenewalOpportunity__c != null
              AND Ruby__RenewalOpportunity__r.IsClosed = false
        ]);
    }
    public void execute(Database.BatchableContext context, List<Ruby__Subscription__c> scope) {
        ELV_OpportunitySubscriptionService.synchronise(new Map<Id,Ruby__Subscription__c>(scope).keySet());
    }
    public void finish(Database.BatchableContext context) {
        Database.executeBatch(new ELV_OppARRBackfillBatch(), 50);
    }
}