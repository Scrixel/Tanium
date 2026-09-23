public with sharing class ELV_MarketplaceImpactService {
    // TNCI-208. Applies the existing Marketplace Discount configuration to Legacy Quotes.
    public static void apply(List<Quote> quotes) {
        Set<Id> partnerIds=new Set<Id>(), oppIds=new Set<Id>();
        for(Quote q:quotes){if(q.ELV_Partner__c!=null)partnerIds.add(q.ELV_Partner__c);if(q.OpportunityId!=null)oppIds.add(q.OpportunityId);}
        Map<Id,Account> partners=new Map<Id,Account>([SELECT Id,Name,Partner_Level__c FROM Account WHERE Id IN :partnerIds]);
        Map<Id,Opportunity> opps=new Map<Id,Opportunity>([SELECT Id,Type FROM Opportunity WHERE Id IN :oppIds]);
        List<Tanium_Marketplace_Discount__c> rules=[SELECT Marketplace_Partner__c,Offer_Type__c,Opportunity_Type__c,Deal_Size_Minimum__c,Deal_Size_Maximum__c,Discount_Amount__c,Disti_Discount__c FROM Tanium_Marketplace_Discount__c];
        for(Quote q:quotes){
            Account p=partners.get(q.ELV_Partner__c); if(p==null || p.Partner_Level__c!='Marketplace'){clear(q);continue;}
            if(q.ELV_Marketplace_Impact_Override__c==true){q.ELV_Marketplace_ARR_Impact_Dollars__c=(q.Ruby__TotalAmount__c==null||q.ELV_Marketplace_ARR_Impact_Percent__c==null)?0:q.Ruby__TotalAmount__c*q.ELV_Marketplace_ARR_Impact_Percent__c/100;continue;}
            String offer=p.Name!=null && p.Name.contains('Amazon Web Services') ? (q.ELV_Downstream_Reseller__c==null?'Private Offer':'Consulting Partner Private Offer (CPPO)'):'Not applicable';
            String type=opps.containsKey(q.OpportunityId)&&opps.get(q.OpportunityId).Type=='New Customer'?'New Customer':opps.containsKey(q.OpportunityId)&&opps.get(q.OpportunityId).Type=='Expansion'?'Expansion':'Renewal';
            Decimal amount=q.Ruby__TotalAmount__c==null ? 0 : q.Ruby__TotalAmount__c;
            Tanium_Marketplace_Discount__c match=null; for(Tanium_Marketplace_Discount__c r:rules)if(r.Marketplace_Partner__c==q.ELV_Partner__c&&r.Offer_Type__c==offer&&r.Opportunity_Type__c==type&&amount>=r.Deal_Size_Minimum__c&&amount<=r.Deal_Size_Maximum__c){match=r;break;}
            Decimal percent=(match==null || match.Discount_Amount__c==null || match.Discount_Amount__c==0) ? Decimal.valueOf(System.Label.Marketplace_Discount) : match.Discount_Amount__c; q.ELV_Marketplace_Offer_Type__c=offer;q.ELV_Marketplace_ARR_Impact_Percent__c=percent;q.ELV_DistiDiscountPercentMarketplace__c=match==null?0:match.Disti_Discount__c;q.ELV_Marketplace_ARR_Impact_Dollars__c=amount*percent/100;
        }
    }
    public static void refreshAndSave(Set<Id> quoteIds) {
        if (quoteIds == null || quoteIds.isEmpty()) return;
        List<Quote> quotes = [SELECT Id, OpportunityId, ELV_Partner__c, ELV_Downstream_Reseller__c, ELV_Marketplace_Impact_Override__c, ELV_Marketplace_ARR_Impact_Percent__c, ELV_Marketplace_ARR_Impact_Dollars__c, ELV_DistiDiscountPercentMarketplace__c, ELV_Marketplace_Offer_Type__c, Ruby__TotalAmount__c FROM Quote WHERE Id IN :quoteIds];
        Map<Id,String> before = new Map<Id,String>();
        for (Quote q : quotes) before.put(q.Id, String.valueOf(q.ELV_Marketplace_ARR_Impact_Percent__c)+'|'+String.valueOf(q.ELV_Marketplace_ARR_Impact_Dollars__c)+'|'+String.valueOf(q.ELV_DistiDiscountPercentMarketplace__c)+'|'+String.valueOf(q.ELV_Marketplace_Offer_Type__c));
        apply(quotes);
        List<Quote> updates = new List<Quote>();
        for (Quote q : quotes) if (before.get(q.Id) != String.valueOf(q.ELV_Marketplace_ARR_Impact_Percent__c)+'|'+String.valueOf(q.ELV_Marketplace_ARR_Impact_Dollars__c)+'|'+String.valueOf(q.ELV_DistiDiscountPercentMarketplace__c)+'|'+String.valueOf(q.ELV_Marketplace_Offer_Type__c)) updates.add(new Quote(Id=q.Id,ELV_Marketplace_ARR_Impact_Percent__c=q.ELV_Marketplace_ARR_Impact_Percent__c,ELV_Marketplace_ARR_Impact_Dollars__c=q.ELV_Marketplace_ARR_Impact_Dollars__c,ELV_DistiDiscountPercentMarketplace__c=q.ELV_DistiDiscountPercentMarketplace__c,ELV_Marketplace_Offer_Type__c=q.ELV_Marketplace_Offer_Type__c));
        if (!updates.isEmpty()) update updates;
    }
    private static void clear(Quote q){q.ELV_Marketplace_Offer_Type__c=null;q.ELV_Marketplace_ARR_Impact_Percent__c=0;q.ELV_DistiDiscountPercentMarketplace__c=0;q.ELV_Marketplace_ARR_Impact_Dollars__c=0;}
}