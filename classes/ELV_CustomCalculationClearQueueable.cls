/**
 * Clears Nue's quote-level custom-calculation latch after custom channel pricing
 * has settled. The clear is conservative: if any direct line still has a stale
 * compounded discount, the quote stays marked.
 */
public with sharing class ELV_CustomCalculationClearQueueable implements Queueable {
    private static final Integer MAX_QUOTES_PER_JOB = 100;
    private static final Set<String> DIRECT_LINE_TYPES = new Set<String>{
        'LineItem',
        'RampItem'
    };
    private static final String QUOTE_STATUS_DRAFT = 'Draft';
    private static final String QUOTE_STATUS_NEEDS_REVIEW = 'Needs Review';

    private final Set<Id> quoteIds;

    public ELV_CustomCalculationClearQueueable(Set<Id> quoteIds) {
        this.quoteIds = quoteIds == null ? new Set<Id>() : new Set<Id>(quoteIds);
    }

    public void execute(QueueableContext context) {
        if (quoteIds.isEmpty()) {
            return;
        }

        List<Id> orderedQuoteIds = new List<Id>(quoteIds);
        Set<Id> current = new Set<Id>();
        Set<Id> remaining = new Set<Id>();
        for (Integer index = 0; index < orderedQuoteIds.size(); index++) {
            Id quoteId = orderedQuoteIds[index];
            if (index < MAX_QUOTES_PER_JOB) {
                current.add(quoteId);
            } else {
                remaining.add(quoteId);
            }
        }

        Set<String> eligibleStatuses = new Set<String>{
            QUOTE_STATUS_DRAFT,
            QUOTE_STATUS_NEEDS_REVIEW
        };
        Set<Id> quotesToEvaluate = new Set<Id>();
        for (Quote quote : [
            SELECT Id
            FROM Quote
            WHERE Id IN :current
            AND (
                Status IN :eligibleStatuses
                OR (
                    ELV_Quote_Migrated_Record__c = TRUE
                    AND ELV_Quote_Migration_External_Id__c != NULL
                )
            )
            AND Ruby__IsCustomCalculationNeeded__c = TRUE
        ]) {
            quotesToEvaluate.add(quote.Id);
        }

        if (!quotesToEvaluate.isEmpty()) {
            clearSettledQuotes(quotesToEvaluate);
        }

        if (!remaining.isEmpty()) {
            System.enqueueJob(new ELV_CustomCalculationClearQueueable(remaining));
        }
    }

    public static void enqueue(Set<Id> quoteIds) {
        if (
            quoteIds == null ||
            quoteIds.isEmpty() ||
            Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()
        ) {
            return;
        }

        System.enqueueJob(new ELV_CustomCalculationClearQueueable(quoteIds));
    }

    private static void clearSettledQuotes(Set<Id> quoteIds) {
        if (ELV_QuoteLineTriggerUtility.restampCurrentChannelDiscounts(quoteIds)) {
            return;
        }

        Set<Id> unsettledQuoteIds = new Set<Id>();
        for (QuoteLineItem line : [
            SELECT Id, QuoteId, Ruby__Discount__c, ELV_Customer_Discount__c,
                   ELV_PartnerDiscount__c, ELV_DistributorDiscount__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
            AND Ruby__LineType__c IN :DIRECT_LINE_TYPES
        ]) {
            if (isUnsettled(line)) {
                unsettledQuoteIds.add(line.QuoteId);
            }
        }

        List<Quote> quotesToClear = new List<Quote>();
        for (Id quoteId : quoteIds) {
            if (!unsettledQuoteIds.contains(quoteId)) {
                quotesToClear.add(
                    new Quote(
                        Id = quoteId,
                        Ruby__IsCustomCalculationNeeded__c = false
                    )
                );
            }
        }

        if (!quotesToClear.isEmpty()) {
            update quotesToClear;
        }
    }

    @TestVisible
    private static Boolean isUnsettled(QuoteLineItem line) {
        return !isCompoundedDiscountCurrent(line);
    }

    private static Boolean isCompoundedDiscountCurrent(QuoteLineItem line) {
        Decimal current = line.Ruby__Discount__c == null
            ? 0
            : line.Ruby__Discount__c;

        return current.setScale(5) == compoundedDiscount(line);
    }

    private static Decimal compoundedDiscount(QuoteLineItem line) {
        Decimal customer = line.ELV_Customer_Discount__c == null
            ? 0
            : line.ELV_Customer_Discount__c;
        Decimal partner = line.ELV_PartnerDiscount__c == null
            ? 0
            : line.ELV_PartnerDiscount__c;
        Decimal distributor = line.ELV_DistributorDiscount__c == null
            ? 0
            : line.ELV_DistributorDiscount__c;

        return ((1 - ((1 - customer / 100) * (1 - partner / 100) *
            (1 - distributor / 100))) * 100).setScale(5);
    }
}