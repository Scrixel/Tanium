public with sharing class ELV_OriginalRenewalUpliftService {
    private static final String LINE_ITEM = 'LineItem';
    private static final String RAMP_ITEM = 'RampItem';
    private static final String CHANGE_TYPE_RENEW = 'Renew';
    private static final String CHANGE_TYPE_ADJUST_PRICE = 'AdjustPrice';

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
            quoteLine.ELV_RenewalUpliftPercent__c = resolveEffectiveRate(policyRate, quoteLine.ELV_Contracted_Renewal_Uplift_Percent__c, quoteRecord.ELV_Contracted_Renewal_Uplift_Percent__c);
        }
    }

    public static void stampAppliedRates(List<QuoteLineItem> lines) {
        if (lines == null || lines.isEmpty()) return;

        Set<Id> quoteIds = new Set<Id>();
        Set<Id> subscriptionIds = new Set<Id>();
        for (QuoteLineItem line : lines) {
            if (line.QuoteId != null) quoteIds.add(line.QuoteId);
            if (line.ELV_Changed_Subscription__c != null) subscriptionIds.add(line.ELV_Changed_Subscription__c);
        }

        Map<Id, Quote> quotes = quoteIds.isEmpty()
            ? new Map<Id, Quote>()
            : new Map<Id, Quote>([
                SELECT Id, ELV_Is_Renewal__c, ELV_Exclude_Uplift__c,
                    ELV_Is_First_Partner_Renewal__c, ELV_Account_Segment__c,
                    ELV_Contracted_Renewal_Uplift_Percent__c
                FROM Quote
                WHERE Id IN :quoteIds
            ]);
        Map<Id, Ruby__Subscription__c> subscriptions = subscriptionIds.isEmpty()
            ? new Map<Id, Ruby__Subscription__c>()
            : new Map<Id, Ruby__Subscription__c>([
                SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c
                FROM Ruby__Subscription__c
                WHERE Id IN :subscriptionIds
            ]);
        Map<String, Renewal_Uplift_Percent__mdt> policies = getRenewalUpliftPolicies();
        Map<String, Decimal> ratesByAsset = new Map<String, Decimal>();

        for (QuoteLineItem line : lines) {
            Quote quoteRecord = quotes.get(line.QuoteId);
            if (!isAppliedRateSourceLine(line, quoteRecord)) continue;

            Renewal_Uplift_Percent__mdt policy = policies.get(policyKey(quoteRecord.ELV_Account_Segment__c));
            if (policy == null) policy = policies.get('Undetermined');
            if (policy == null) continue;

            Decimal rate = quoteRecord.ELV_Is_First_Partner_Renewal__c == true
                ? policy.First_Renewal_Uplift__c
                : policy.Uplift_Percent__c;
            Decimal cap = quoteRecord.ELV_Contracted_Renewal_Uplift_Percent__c;
            if (line.ELV_Contracted_Renewal_Uplift_Percent__c != null && (cap == null || line.ELV_Contracted_Renewal_Uplift_Percent__c < cap)) {
                cap = line.ELV_Contracted_Renewal_Uplift_Percent__c;
            }

            Ruby__Subscription__c subscription = subscriptions.get(line.ELV_Changed_Subscription__c);
            if (subscription != null && subscription.ELV_Contracted_Renewal_Uplift_Percent__c != null && (cap == null || subscription.ELV_Contracted_Renewal_Uplift_Percent__c < cap)) {
                cap = subscription.ELV_Contracted_Renewal_Uplift_Percent__c;
            }
            if (cap != null && rate > cap) rate = cap;

            line.ELV_RenewalUpliftPercent__c = rate;
            if (String.isNotBlank(line.Ruby__ChangeAssetId__c)) {
                ratesByAsset.put(line.Ruby__ChangeAssetId__c, rate);
            }
        }

        for (QuoteLineItem line : lines) {
            if (isAppliedRateTargetLine(line) && ratesByAsset.containsKey(line.Ruby__ChangeAssetId__c)) {
                line.ELV_RenewalUpliftPercent__c = ratesByAsset.get(line.Ruby__ChangeAssetId__c);
            }
        }
    }

    private static Map<String, Renewal_Uplift_Percent__mdt> getRenewalUpliftPolicies() {
        Map<String, Renewal_Uplift_Percent__mdt> policies = new Map<String, Renewal_Uplift_Percent__mdt>();
        for (Renewal_Uplift_Percent__mdt policy : [
            SELECT DeveloperName, Uplift_Percent__c, First_Renewal_Uplift__c
            FROM Renewal_Uplift_Percent__mdt
        ]) {
            policies.put(policy.DeveloperName, policy);
        }
        return policies;
    }

    private static Boolean isAppliedRateSourceLine(QuoteLineItem line, Quote quoteRecord) {
        return line.ELV_Renewal_Uplift_Override__c != true &&
            quoteRecord != null &&
            quoteRecord.ELV_Is_Renewal__c == true &&
            quoteRecord.ELV_Exclude_Uplift__c != true &&
            line.ELV_Exclude_Uplift__c != true &&
            line.ELV_Changed_Subscription__c != null &&
            line.Ruby__LineType__c != RAMP_ITEM;
    }

    private static Boolean isAppliedRateTargetLine(QuoteLineItem line) {
        return line.ELV_Renewal_Uplift_Override__c != true &&
            line.Ruby__LineType__c == LINE_ITEM &&
            line.ELV_Exclude_Uplift__c != true &&
            (line.Ruby__ChangeType__c == CHANGE_TYPE_RENEW ||
            line.Ruby__ChangeType__c == CHANGE_TYPE_ADJUST_PRICE);
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