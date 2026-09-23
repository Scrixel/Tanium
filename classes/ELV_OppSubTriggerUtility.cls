public with sharing class ELV_OppSubTriggerUtility {
    public static Set<Id> opportunityIds(List<Ruby__OpportunitySubscription__c> rows) {
        Set<Id> result = new Set<Id>();
        if (rows != null) for (Ruby__OpportunitySubscription__c row : rows)
            if (row.Ruby__Opportunity__c != null) result.add(row.Ruby__Opportunity__c);
        return result;
    }
}