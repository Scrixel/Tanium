public with sharing class ELV_OppARRBackfillBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id FROM Opportunity WHERE IsClosed = false AND Id IN
              (SELECT Ruby__RenewalOpportunity__c FROM Ruby__Subscription__c
               WHERE Ruby__RenewalOpportunity__c != null)
        ]);
    }
    public void execute(Database.BatchableContext context, List<Opportunity> scope) {
        ELV_OpportunityARRService.recalculate(new Map<Id,Opportunity>(scope).keySet());
    }
    public void finish(Database.BatchableContext context) {}
}