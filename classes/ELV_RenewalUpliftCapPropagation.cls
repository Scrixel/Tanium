public with sharing class ELV_RenewalUpliftCapPropagation {
    /** Inherit only a blank cap; explicit zero and lower child caps remain authoritative. */
    public static void stampQuotes(List<Quote> records) {
        Set<Id> ids = new Set<Id>();
        for (Quote r : records) if (r.OpportunityId != null && r.ELV_Contracted_Renewal_Uplift_Percent__c == null) ids.add(r.OpportunityId);
        if (ids.isEmpty()) return;
        Map<Id, Opportunity> parents = new Map<Id, Opportunity>([SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c FROM Opportunity WHERE Id IN :ids]);
        for (Quote r : records) {
            Opportunity p = parents.get(r.OpportunityId);
            if (r.ELV_Contracted_Renewal_Uplift_Percent__c == null && p != null && p.ELV_Contracted_Renewal_Uplift_Percent__c != null) r.ELV_Contracted_Renewal_Uplift_Percent__c = p.ELV_Contracted_Renewal_Uplift_Percent__c;
        }
    }
    public static void stampQuoteLines(List<QuoteLineItem> records) {
        Set<Id> ids = new Set<Id>();
        for (QuoteLineItem r : records) if (r.QuoteId != null && r.ELV_Contracted_Renewal_Uplift_Percent__c == null) ids.add(r.QuoteId);
        if (ids.isEmpty()) return;
        Map<Id, Quote> parents = new Map<Id, Quote>([SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c FROM Quote WHERE Id IN :ids]);
        for (QuoteLineItem r : records) {
            Quote p = parents.get(r.QuoteId);
            if (r.ELV_Contracted_Renewal_Uplift_Percent__c == null && p != null && p.ELV_Contracted_Renewal_Uplift_Percent__c != null) r.ELV_Contracted_Renewal_Uplift_Percent__c = p.ELV_Contracted_Renewal_Uplift_Percent__c;
        }
    }
}