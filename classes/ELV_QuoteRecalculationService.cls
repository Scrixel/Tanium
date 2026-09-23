/**
 * Detects background changes to the discount inputs on Quote Line Items and
 * defers the corresponding Nue quote recalculation until after commit.
 */
public with sharing class ELV_QuoteRecalculationService {
    private static final String LINE_ITEM_LINE_TYPE = 'LineItem';
    private static final String RAMP_ITEM_LINE_TYPE = 'RampItem';
    private static Boolean isQueued = false;

    public static void requestRecalculation(
        List<QuoteLineItem> newLines,
        Map<Id, QuoteLineItem> oldMap
    ) {
        if (isQueued || newLines == null || newLines.isEmpty() || oldMap == null) {
            return;
        }

        Map<Id, Set<Id>> lineIdsByQuoteId = new Map<Id, Set<Id>>();
        for (QuoteLineItem line : newLines) {
            QuoteLineItem oldLine = oldMap.get(line.Id);
            if (line.Id == null || line.QuoteId == null || oldLine == null) {
                continue;
            }
            if (!isDirectChannelDiscountLine(line)) {
                continue;
            }
            if (!hasDiscountInputChanged(line, oldLine)) {
                continue;
            }

            if (!lineIdsByQuoteId.containsKey(line.QuoteId)) {
                lineIdsByQuoteId.put(line.QuoteId, new Set<Id>());
            }
            lineIdsByQuoteId.get(line.QuoteId).add(line.Id);
        }

        if (lineIdsByQuoteId.isEmpty()) {
            return;
        }

        // The global update writes Ruby__Discount__c, not either source field,
        // so its resulting QuoteLineItem update does not meet this entry rule.
        isQueued = true;
        System.enqueueJob(new ELV_QuoteRecalculationQueueable(lineIdsByQuoteId));
    }

    public static void requestRecalculationForStampedDiscounts(
        List<QuoteLineItem> newLines
    ) {
        if (isQueued || newLines == null || newLines.isEmpty()) {
            return;
        }

        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem line : newLines) {
            if (
                line.Id == null ||
                line.QuoteId == null ||
                !isDirectChannelDiscountLine(line) ||
                !hasStampedDiscountInput(line)
            ) {
                continue;
            }

            quoteIds.add(line.QuoteId);
        }

        if (quoteIds.isEmpty()) {
            return;
        }

        isQueued = true;
        System.enqueueJob(new ELV_QuoteRecalculationQueueable(quoteIds));
    }

    private static Boolean hasDiscountInputChanged(
        QuoteLineItem line,
        QuoteLineItem oldLine
    ) {
        return line.ELV_PartnerDiscount__c != oldLine.ELV_PartnerDiscount__c ||
            line.ELV_DistributorDiscount__c != oldLine.ELV_DistributorDiscount__c ||
            isPricingRefreshRequested(line, oldLine);
    }

    private static Boolean isPricingRefreshRequested(
        QuoteLineItem line,
        QuoteLineItem oldLine
    ) {
        return line.ELV_Pricing_Refresh_Required__c == true &&
            oldLine.ELV_Pricing_Refresh_Required__c != true;
    }

    private static Boolean isDirectChannelDiscountLine(QuoteLineItem line) {
        return line.Ruby__LineType__c == LINE_ITEM_LINE_TYPE ||
            line.Ruby__LineType__c == RAMP_ITEM_LINE_TYPE;
    }

    private static Boolean hasStampedDiscountInput(QuoteLineItem line) {
        return (line.ELV_PartnerDiscount__c != null &&
            line.ELV_PartnerDiscount__c != 0) ||
            (line.ELV_DistributorDiscount__c != null &&
            line.ELV_DistributorDiscount__c != 0);
    }
}