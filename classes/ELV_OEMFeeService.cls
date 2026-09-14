/**
 * TNCI-208. Computes Legacy Quote Line OEM fees from active OEM fee-rule metadata.
 * Royalty is applied to Ruby__TotalPrice__c (discounted line total). The selected fee is
 * the greater of the royalty and the rule's annual minimum, with only metadata-flagged
 * annual minimums prorated for a shorter subscription term.
 */
public with sharing class ELV_OEMFeeService {
    public static void apply(List<QuoteLineItem> lines) {
        if (lines == null || lines.isEmpty()) return;
        Map<String, List<ELV_OEM_Fee_Rule__mdt>> rulesBySku = new Map<String, List<ELV_OEM_Fee_Rule__mdt>>();
        for (ELV_OEM_Fee_Rule__mdt rule : [
            SELECT DeveloperName, ELV_Product_SKU__c, ELV_Min_Quantity__c, ELV_Max_Quantity__c,
                   ELV_Royalty_Percent__c, ELV_Minimum_Fee_Per_Unit__c,
                   ELV_Minimum_Fee_Per_Subscription__c, ELV_Prorate_Annual_Minimum__c,
                   ELV_Active__c
            FROM ELV_OEM_Fee_Rule__mdt WHERE ELV_Active__c = true
        ]) {
            if (!rulesBySku.containsKey(rule.ELV_Product_SKU__c)) rulesBySku.put(rule.ELV_Product_SKU__c, new List<ELV_OEM_Fee_Rule__mdt>());
            rulesBySku.get(rule.ELV_Product_SKU__c).add(rule);
        }
        apply(lines, rulesBySku);
    }

    @TestVisible private static void apply(List<QuoteLineItem> lines, Map<String, List<ELV_OEM_Fee_Rule__mdt>> rulesBySku) {
        for (QuoteLineItem line : lines) {
            ELV_OEM_Fee_Rule__mdt match = findRule(rulesBySku.get(line.Ruby__ProductSKU__c), line.Quantity);
            if (match == null || line.Ruby__TotalPrice__c == null) {
                clear(line); continue;
            }
            applyMatch(line, match, line.Ruby__TotalPrice__c);
        }
    }
    @TestVisible private static void applyMatch(QuoteLineItem line, ELV_OEM_Fee_Rule__mdt match, Decimal netRevenue) {
        Decimal term = line.Ruby__SubscriptionTerm__c == null || line.Ruby__SubscriptionTerm__c <= 0 ? 1 : line.Ruby__SubscriptionTerm__c;
        Decimal royalty = netRevenue * (match.ELV_Royalty_Percent__c == null ? 0 : match.ELV_Royalty_Percent__c / 100);
        Decimal minimum = match.ELV_Minimum_Fee_Per_Unit__c != null ? line.Quantity * match.ELV_Minimum_Fee_Per_Unit__c : (match.ELV_Minimum_Fee_Per_Subscription__c == null ? 0 : match.ELV_Minimum_Fee_Per_Subscription__c);
        if (match.ELV_Prorate_Annual_Minimum__c == true && term < 1) minimum *= term;
        line.ELV_OEM_Fee__c = (royalty >= minimum ? royalty : minimum).setScale(2);
        line.ELV_OEM_Applied_Royalty_Percent__c = match.ELV_Royalty_Percent__c;
        line.ELV_OEM_Applied_Minimum_Fee__c = minimum.setScale(2);
        line.ELV_OEM_Fee_Rule__c = match.DeveloperName;
    }
    /** TNCI-208. Reconciles each Quote's stored OEM total after line-save rollups settle. */
    public static void refreshQuoteTotals(Set<Id> quoteIds) {
        if (quoteIds == null || quoteIds.isEmpty()) return;
        Map<Id, Decimal> totalByQuote = new Map<Id, Decimal>();
        for (AggregateResult row : [SELECT QuoteId quoteId, SUM(ELV_OEM_Fee__c) total FROM QuoteLineItem WHERE QuoteId IN :quoteIds GROUP BY QuoteId]) {
            totalByQuote.put((Id)row.get('quoteId'), (Decimal)row.get('total'));
        }
        List<Quote> updates = new List<Quote>();
        for (Quote quote : [SELECT Id, ELV_Total_OEM_Fee__c FROM Quote WHERE Id IN :quoteIds]) {
            Decimal calculated = totalByQuote.containsKey(quote.Id) ? totalByQuote.get(quote.Id) : 0;
            if (quote.ELV_Total_OEM_Fee__c != calculated) updates.add(new Quote(Id=quote.Id, ELV_Total_OEM_Fee__c=calculated));
        }
        if (!updates.isEmpty()) update updates;
    }

    private static ELV_OEM_Fee_Rule__mdt findRule(List<ELV_OEM_Fee_Rule__mdt> rules, Decimal quantity) {
        if (rules == null || quantity == null || quantity <= 0) return null;
        for (ELV_OEM_Fee_Rule__mdt rule : rules) if (quantity >= rule.ELV_Min_Quantity__c && (rule.ELV_Max_Quantity__c == null || quantity <= rule.ELV_Max_Quantity__c)) return rule;
        return null;
    }
    private static void clear(QuoteLineItem line) {
        line.ELV_OEM_Fee__c = null; line.ELV_OEM_Applied_Royalty_Percent__c = null;
        line.ELV_OEM_Applied_Minimum_Fee__c = null; line.ELV_OEM_Fee_Rule__c = null;
    }
}