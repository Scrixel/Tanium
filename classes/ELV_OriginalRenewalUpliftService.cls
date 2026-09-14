public with sharing class ELV_OriginalRenewalUpliftService {
    private static final String LINE_ITEM = 'LineItem';
    public static void stamp(List<QuoteLineItem> lines) {
        if (lines == null || lines.isEmpty()) return;
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem quoteLine : lines) if (quoteLine.QuoteId != null) quoteIds.add(quoteLine.QuoteId);
        if (quoteIds.isEmpty()) return;
        Map<Id, Quote> quotes = new Map<Id, Quote>([SELECT Id, ELV_Is_Renewal__c, ELV_Account_Segment__c, ELV_Is_First_Partner_Renewal__c, ELV_Exclude_Uplift__c, ELV_Contracted_Renewal_Uplift_Percent__c FROM Quote WHERE Id IN :quoteIds]);
        for (QuoteLineItem quoteLine : lines) {
            Quote quoteRecord = quotes.get(quoteLine.QuoteId);
            if (quoteLine.ELV_Renewal_Uplift_Override__c == true || !isEligibleSourceLine(quoteLine, quoteRecord)) continue;
            Renewal_Uplift_Percent__mdt policy = Renewal_Uplift_Percent__mdt.getInstance(policyKey(quoteRecord.ELV_Account_Segment__c));
            if (policy == null) policy = Renewal_Uplift_Percent__mdt.getInstance('Undetermined');
            if (policy == null) continue;
            Decimal policyRate = quoteRecord.ELV_Is_First_Partner_Renewal__c == true ? policy.First_Renewal_Uplift__c : policy.Uplift_Percent__c;
            quoteLine.Ruby__RenewalUpliftPercent__c = resolveEffectiveRate(policyRate, quoteLine.ELV_Contracted_Renewal_Uplift_Percent__c, quoteRecord.ELV_Contracted_Renewal_Uplift_Percent__c);
        }
    }
    @TestVisible private static Decimal resolveEffectiveRate(Decimal policyRate, Decimal lineCap, Decimal quoteCap) {
        if (policyRate == null) return null;
        Decimal cap = lineCap;
        if (quoteCap != null && (cap == null || quoteCap < cap)) cap = quoteCap;
        return cap == null || cap >= policyRate ? policyRate : cap;
    }
    @TestVisible private static String policyKey(String segment) { return String.isBlank(segment) ? 'Undetermined' : segment.replace(' ', '_'); }
    private static Boolean isEligibleSourceLine(QuoteLineItem quoteLine, Quote quoteRecord) {
        return quoteRecord != null && quoteRecord.ELV_Is_Renewal__c != true && quoteRecord.ELV_Exclude_Uplift__c != true && quoteLine.ELV_Exclude_Uplift__c != true && quoteLine.Ruby__LineType__c == LINE_ITEM && String.isBlank(quoteLine.Ruby__ChangeType__c) && String.isBlank(quoteLine.Ruby__ChangeAssetId__c);
    }
}