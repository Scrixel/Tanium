/**
 * Recalculates the Ruby discretionary discount for quote lines whose source
 * partner or distributor discount changed outside the Nue Line Editor.
 *
 * One global updateQuote() request is made for each Quote. A large batch is
 * split by Quote, never by line, so one Quote never receives two requests
 * from the same source transaction.
 */
public with sharing class ELV_QuoteRecalculationQueueable
    implements Queueable, Database.AllowsCallouts {

    private static final Integer MAX_QUOTES_PER_JOB = 40;
    private static final Set<String> DIRECT_LINE_TYPES = new Set<String>{
        'LineItem',
        'RampItem'
    };
    private static final Set<String> ELIGIBLE_QUOTE_STATUSES = new Set<String>{
        'Draft',
        'Needs Review'
    };

    // Quote Id -> changed Quote Line Item Ids. The map is built by the service
    // in the triggering transaction, before this asynchronous work begins.
    private final Map<Id, Set<Id>> lineIdsByQuoteId;
    private final Boolean scanCurrentQuoteLines;

    public ELV_QuoteRecalculationQueueable(Map<Id, Set<Id>> lineIdsByQuoteId) {
        this.lineIdsByQuoteId = copy(lineIdsByQuoteId);
        this.scanCurrentQuoteLines = false;
    }

    public ELV_QuoteRecalculationQueueable(Set<Id> quoteIds) {
        this.lineIdsByQuoteId = copyQuoteIds(quoteIds);
        this.scanCurrentQuoteLines = true;
    }

    public void execute(QueueableContext context) {
        if (lineIdsByQuoteId.isEmpty()) {
            return;
        }

        List<Id> quoteIds = new List<Id>(lineIdsByQuoteId.keySet());
        Integer quoteCount = Math.min(MAX_QUOTES_PER_JOB, quoteIds.size());

        Map<Id, Set<Id>> current = new Map<Id, Set<Id>>();
        Map<Id, Set<Id>> remaining = new Map<Id, Set<Id>>();
        for (Integer index = 0; index < quoteIds.size(); index++) {
            Id quoteId = quoteIds[index];
            if (index < quoteCount) {
                current.put(quoteId, lineIdsByQuoteId.get(quoteId));
            } else {
                remaining.put(quoteId, lineIdsByQuoteId.get(quoteId));
            }
        }

        Map<Id, List<QuoteLineItem>> linesByQuoteId = scanCurrentQuoteLines
            ? getCurrentLinesByQuoteId(current.keySet())
            : getChangedLinesByQuoteId(current);

        for (Id quoteId : current.keySet()) {
            recalculateQuote(quoteId, linesByQuoteId.get(quoteId));
        }

        if (!remaining.isEmpty()) {
            System.enqueueJob(
                new ELV_QuoteRecalculationQueueable(
                    remaining,
                    scanCurrentQuoteLines
                )
            );
        } else {
            ELV_CustomCalculationClearQueueable.enqueue(current.keySet());
        }
    }

    private ELV_QuoteRecalculationQueueable(
        Map<Id, Set<Id>> lineIdsByQuoteId,
        Boolean scanCurrentQuoteLines
    ) {
        this.lineIdsByQuoteId = copy(lineIdsByQuoteId, true);
        this.scanCurrentQuoteLines = scanCurrentQuoteLines;
    }

    private static Map<Id, List<QuoteLineItem>> getChangedLinesByQuoteId(
        Map<Id, Set<Id>> current
    ) {
        Set<Id> lineIds = new Set<Id>();
        for (Set<Id> ids : current.values()) {
            lineIds.addAll(ids);
        }

        Map<Id, List<QuoteLineItem>> linesByQuoteId = new Map<Id, List<QuoteLineItem>>();
        if (lineIds.isEmpty()) {
            return linesByQuoteId;
        }

        for (QuoteLineItem line : [
            SELECT Id, QuoteId, Ruby__Discount__c, ELV_Customer_Discount__c,
                   ELV_PartnerDiscount__c, ELV_DistributorDiscount__c
            FROM QuoteLineItem
            WHERE Id IN :lineIds
        ]) {
            addLine(linesByQuoteId, line);
        }

        return linesByQuoteId;
    }

    private static Map<Id, List<QuoteLineItem>> getCurrentLinesByQuoteId(
        Set<Id> quoteIds
    ) {
        Map<Id, List<QuoteLineItem>> linesByQuoteId = new Map<Id, List<QuoteLineItem>>();
        if (quoteIds == null || quoteIds.isEmpty()) {
            return linesByQuoteId;
        }

        for (QuoteLineItem line : [
            SELECT Id, QuoteId, Ruby__Discount__c, ELV_Customer_Discount__c,
                   ELV_PartnerDiscount__c, ELV_DistributorDiscount__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
            AND Quote.Status IN :ELIGIBLE_QUOTE_STATUSES
            AND Ruby__LineType__c IN :DIRECT_LINE_TYPES
        ]) {
            if (shouldRecalculate(line)) {
                addLine(linesByQuoteId, line);
            }
        }

        return linesByQuoteId;
    }

    private static void addLine(
        Map<Id, List<QuoteLineItem>> linesByQuoteId,
        QuoteLineItem line
    ) {
        if (line == null || line.QuoteId == null) {
            return;
        }
        if (!linesByQuoteId.containsKey(line.QuoteId)) {
            linesByQuoteId.put(line.QuoteId, new List<QuoteLineItem>());
        }
        linesByQuoteId.get(line.QuoteId).add(line);
    }

    private static void recalculateQuote(Id quoteId, List<QuoteLineItem> lines) {
        if (lines == null || lines.isEmpty()) {
            return;
        }

        List<Object> lineItems = new List<Object>();
        for (QuoteLineItem line : lines) {
            if (!shouldRecalculate(line)) {
                continue;
            }
            lineItems.add(new Map<String, Object>{
                'lineItemId' => line.Id,
                'fieldValues' => new Map<String, Object>{
                    'Ruby__Discount__c' => compoundedDiscount(line)
                }
            });
        }

        if (lineItems.isEmpty()) {
            return;
        }

        Ruby.GlobalAPITypes.UpdateAction action = new Ruby.GlobalAPITypes.UpdateAction();
        action.action = 'updateLineItems';
        action.payload = new Map<String, Object>{ 'lineItems' => lineItems };

        Ruby.GlobalAPITypes.UpdateQuoteRequest request =
            new Ruby.GlobalAPITypes.UpdateQuoteRequest();
        request.quoteId = String.valueOf(quoteId);
        request.isCommit = true;
        request.recalc = 'PRICING_ONLY';
        request.actions = new List<Ruby.GlobalAPITypes.UpdateAction>{ action };

        Ruby.GlobalAPITypes.UpdateQuoteResponse response =
            Ruby.GlobalQuoteServiceAPI.updateQuote(request);

        if (response == null || response.status != 'SUCCESS') {
            System.debug(
                LoggingLevel.ERROR,
                'ELV quote recalculation failed for quote ' + quoteId + ': ' +
                JSON.serialize(response)
            );
        }
    }

    private static Boolean shouldRecalculate(QuoteLineItem line) {
        return hasStampedDiscountInput(line) && !isCompoundedDiscountCurrent(line);
    }

    private static Boolean hasStampedDiscountInput(QuoteLineItem line) {
        if (line == null) {
            return false;
        }
        return (line.ELV_PartnerDiscount__c != null &&
            line.ELV_PartnerDiscount__c != 0) ||
            (line.ELV_DistributorDiscount__c != null &&
            line.ELV_DistributorDiscount__c != 0);
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

    private static Map<Id, Set<Id>> copy(Map<Id, Set<Id>> source) {
        return copy(source, false);
    }

    private static Map<Id, Set<Id>> copy(
        Map<Id, Set<Id>> source,
        Boolean keepEmptySets
    ) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        if (source == null) {
            return result;
        }

        for (Id quoteId : source.keySet()) {
            Set<Id> lineIds = source.get(quoteId);
            if (
                quoteId != null &&
                lineIds != null &&
                (keepEmptySets || !lineIds.isEmpty())
            ) {
                result.put(quoteId, new Set<Id>(lineIds));
            }
        }
        return result;
    }

    private static Map<Id, Set<Id>> copyQuoteIds(Set<Id> source) {
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        if (source == null) {
            return result;
        }

        for (Id quoteId : source) {
            if (quoteId != null) {
                result.put(quoteId, new Set<Id>());
            }
        }
        return result;
    }
}