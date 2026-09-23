public with sharing class ELV_RenewalUpliftOpportunitySync {
    public static void synchronize(List<Opportunity> records, Map<Id, Opportunity> oldMap) {
        if (records == null || records.isEmpty() || oldMap == null) return;
        Map<Id, Decimal> capByPrimaryQuote = new Map<Id, Decimal>();
        for (Opportunity record : records) {
            Opportunity oldRecord = oldMap.get(record.Id);
            if (oldRecord != null && record.ELV_Contracted_Renewal_Uplift_Percent__c != oldRecord.ELV_Contracted_Renewal_Uplift_Percent__c && record.Ruby__PrimaryQuote__c != null) capByPrimaryQuote.put(record.Ruby__PrimaryQuote__c, record.ELV_Contracted_Renewal_Uplift_Percent__c);
        }
        if (capByPrimaryQuote.isEmpty()) return;
        List<Quote> quoteUpdates = new List<Quote>();
        for (Quote quoteRecord : [SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c FROM Quote WHERE Id IN :capByPrimaryQuote.keySet()]) {
            Decimal cap = capByPrimaryQuote.get(quoteRecord.Id);
            if (quoteRecord.ELV_Contracted_Renewal_Uplift_Percent__c != cap) quoteUpdates.add(new Quote(Id = quoteRecord.Id, ELV_Contracted_Renewal_Uplift_Percent__c = cap));
        }
        if (!quoteUpdates.isEmpty()) update quoteUpdates;
        List<QuoteLineItem> lineUpdates = new List<QuoteLineItem>();
        for (QuoteLineItem line : [SELECT Id, QuoteId, ELV_Contracted_Renewal_Uplift_Percent__c FROM QuoteLineItem WHERE QuoteId IN :capByPrimaryQuote.keySet()]) {
            Decimal cap = capByPrimaryQuote.get(line.QuoteId);
            if (line.ELV_Contracted_Renewal_Uplift_Percent__c != cap) lineUpdates.add(new QuoteLineItem(Id = line.Id, ELV_Contracted_Renewal_Uplift_Percent__c = cap));
        }
        if (!lineUpdates.isEmpty()) update lineUpdates;
    }
}