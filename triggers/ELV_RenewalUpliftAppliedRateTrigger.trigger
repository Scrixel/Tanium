trigger ELV_RenewalUpliftAppliedRateTrigger on QuoteLineItem (before insert, before update) {
    Set<Id> quoteIds = new Set<Id>();
    Set<Id> subscriptionIds = new Set<Id>();
    for (QuoteLineItem line : Trigger.new) {
        if (line.QuoteId != null) quoteIds.add(line.QuoteId);
        if (line.ELV_Changed_Subscription__c != null) subscriptionIds.add(line.ELV_Changed_Subscription__c);
    }
    Map<Id, Quote> quotes = new Map<Id, Quote>([SELECT Id, ELV_Is_Renewal__c, ELV_Exclude_Uplift__c, ELV_Is_First_Partner_Renewal__c, ELV_Account_Segment__c, ELV_Contracted_Renewal_Uplift_Percent__c FROM Quote WHERE Id IN :quoteIds]);
    Map<Id, Ruby__Subscription__c> subscriptions = new Map<Id, Ruby__Subscription__c>([SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c FROM Ruby__Subscription__c WHERE Id IN :subscriptionIds]);
    Map<String, Renewal_Uplift_Percent__mdt> policies = new Map<String, Renewal_Uplift_Percent__mdt>();
    for (Renewal_Uplift_Percent__mdt policy : [SELECT DeveloperName, Uplift_Percent__c, First_Renewal_Uplift__c FROM Renewal_Uplift_Percent__mdt]) policies.put(policy.DeveloperName, policy);
    Map<String, Decimal> ratesByAsset = new Map<String, Decimal>();
    for (QuoteLineItem line : Trigger.new) {
        Quote quoteRecord = quotes.get(line.QuoteId);
        if (line.ELV_Renewal_Uplift_Override__c == true || quoteRecord == null || quoteRecord.ELV_Is_Renewal__c != true || quoteRecord.ELV_Exclude_Uplift__c == true || line.ELV_Exclude_Uplift__c == true || line.ELV_Changed_Subscription__c == null || line.Ruby__LineType__c == 'RampItem') continue;
        String key = String.isBlank(quoteRecord.ELV_Account_Segment__c) ? 'Undetermined' : quoteRecord.ELV_Account_Segment__c.replace(' ', '_');
        Renewal_Uplift_Percent__mdt policy = policies.get(key);
        if (policy == null) policy = policies.get('Undetermined');
        if (policy == null) continue;
        Decimal rate = quoteRecord.ELV_Is_First_Partner_Renewal__c == true ? policy.First_Renewal_Uplift__c : policy.Uplift_Percent__c;
        Decimal cap = quoteRecord.ELV_Contracted_Renewal_Uplift_Percent__c;
        if (line.ELV_Contracted_Renewal_Uplift_Percent__c != null && (cap == null || line.ELV_Contracted_Renewal_Uplift_Percent__c < cap)) cap = line.ELV_Contracted_Renewal_Uplift_Percent__c;
        Ruby__Subscription__c subscription = subscriptions.get(line.ELV_Changed_Subscription__c);
        if (subscription != null && subscription.ELV_Contracted_Renewal_Uplift_Percent__c != null && (cap == null || subscription.ELV_Contracted_Renewal_Uplift_Percent__c < cap)) cap = subscription.ELV_Contracted_Renewal_Uplift_Percent__c;
        if (cap != null && rate > cap) rate = cap;
        line.Ruby__RenewalUpliftPercent__c = rate;
        if (String.isNotBlank(line.Ruby__ChangeAssetId__c)) ratesByAsset.put(line.Ruby__ChangeAssetId__c, rate);
    }
    for (QuoteLineItem line : Trigger.new) {
        if (line.ELV_Renewal_Uplift_Override__c != true && line.Ruby__LineType__c == 'LineItem' && line.ELV_Exclude_Uplift__c != true && (line.Ruby__ChangeType__c == 'Renew' || line.Ruby__ChangeType__c == 'AdjustPrice') && ratesByAsset.containsKey(line.Ruby__ChangeAssetId__c)) line.Ruby__RenewalUpliftPercent__c = ratesByAsset.get(line.Ruby__ChangeAssetId__c);
    }
}