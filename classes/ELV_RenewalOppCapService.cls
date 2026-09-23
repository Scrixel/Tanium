public with sharing class ELV_RenewalOppCapService {
    /** TNCI-135. Stamps a blank renewal Opportunity cap from linked source Subscriptions. */
    public static void stampFromRenewalLinkChanges(List<Ruby__Subscription__c> subscriptions, Map<Id, Ruby__Subscription__c> oldMap) {
        Set<Id> renewalOpportunityIds = linkedRenewalOpportunityIds(subscriptions, oldMap);
        if (renewalOpportunityIds.isEmpty()) return;
        Map<Id, Decimal> lowestCapByOpportunity = new Map<Id, Decimal>();
        for (Ruby__Subscription__c sourceSubscription : [SELECT Ruby__RenewalOpportunity__c, ELV_Contracted_Renewal_Uplift_Percent__c FROM Ruby__Subscription__c WHERE Ruby__RenewalOpportunity__c IN :renewalOpportunityIds AND ELV_Contracted_Renewal_Uplift_Percent__c != null]) {
            Id opportunityId = sourceSubscription.Ruby__RenewalOpportunity__c;
            Decimal sourceCap = sourceSubscription.ELV_Contracted_Renewal_Uplift_Percent__c;
            if (!lowestCapByOpportunity.containsKey(opportunityId) || sourceCap < lowestCapByOpportunity.get(opportunityId)) lowestCapByOpportunity.put(opportunityId, sourceCap);
        }
        if (lowestCapByOpportunity.isEmpty()) return;
        List<Opportunity> updates = new List<Opportunity>();
        for (Opportunity renewalOpportunity : [SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c FROM Opportunity WHERE Id IN :lowestCapByOpportunity.keySet()]) {
            if (renewalOpportunity.ELV_Contracted_Renewal_Uplift_Percent__c == null) updates.add(new Opportunity(Id = renewalOpportunity.Id, ELV_Contracted_Renewal_Uplift_Percent__c = lowestCapByOpportunity.get(renewalOpportunity.Id)));
        }
        if (!updates.isEmpty()) update updates;
    }
    @TestVisible private static Set<Id> linkedRenewalOpportunityIds(List<Ruby__Subscription__c> subscriptions, Map<Id, Ruby__Subscription__c> oldMap) {
        Set<Id> ids = new Set<Id>();
        for (Ruby__Subscription__c subscriptionRecord : subscriptions) {
            Ruby__Subscription__c oldRecord = oldMap == null ? null : oldMap.get(subscriptionRecord.Id);
            if (subscriptionRecord.Ruby__RenewalOpportunity__c != null && (oldRecord == null || oldRecord.Ruby__RenewalOpportunity__c != subscriptionRecord.Ruby__RenewalOpportunity__c)) ids.add(subscriptionRecord.Ruby__RenewalOpportunity__c);
        }
        return ids;
    }
    @TestVisible private static Decimal lowestPopulatedCap(List<Ruby__Subscription__c> subscriptions) {
        Decimal lowestCap;
        for (Ruby__Subscription__c subscriptionRecord : subscriptions) {
            Decimal sourceCap = subscriptionRecord.ELV_Contracted_Renewal_Uplift_Percent__c;
            if (sourceCap != null && (lowestCap == null || sourceCap < lowestCap)) lowestCap = sourceCap;
        }
        return lowestCap;
    }
}