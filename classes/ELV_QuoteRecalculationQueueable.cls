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

    // updateQuote() performs synchronous pricing callouts. Keep a safe margin
    // below the platform's 100-callout transaction limit.
    private static final Integer MAX_QUOTES_PER_JOB = 40;

    // Quote Id -> changed Quote Line Item Ids. The map is built by the service
    // in the triggering transaction, before this asynchronous work begins.
    private final Map<Id, Set<Id>> lineIdsByQuoteId;

    public ELV_QuoteRecalculationQueueable(Map<Id, Set<Id>> lineIdsByQuoteId) {
        this.lineIdsByQuoteId = copy(lineIdsByQuoteId);
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

        Set<Id> lineIds = new Set<Id>();
        for (Set<Id> ids : current.values()) {
            lineIds.addAll(ids);
        }

        Map<Id, List<QuoteLineItem>> linesByQuoteId = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem line : [
            SELECT Id, QuoteId, ELV_Customer_Discount__c, ELV_PartnerDiscount__c,
                   ELV_DistributorDiscount__c
            FROM QuoteLineItem
            WHERE Id IN :lineIds
        ]) {
            if (!current.containsKey(line.QuoteId)) {
                continue;
            }
            if (!linesByQuoteId.containsKey(line.QuoteId)) {
                linesByQuoteId.put(line.QuoteId, new List<QuoteLineItem>());
            }
            linesByQuoteId.get(line.QuoteId).add(line);
        }

        for (Id quoteId : current.keySet()) {
            recalculateQuote(quoteId, linesByQuoteId.get(quoteId));
        }

        if (!remaining.isEmpty()) {
            System.enqueueJob(new ELV_QuoteRecalculationQueueable(remaining));
        }
    }

    private static void recalculateQuote(Id quoteId, List<QuoteLineItem> lines) {
        if (lines == null || lines.isEmpty()) {
            return;
        }

        List<Object> lineItems = new List<Object>();
        for (QuoteLineItem line : lines) {
            lineItems.add(new Map<String, Object>{
                'lineItemId' => line.Id,
                'fieldValues' => new Map<String, Object>{
                    'Ruby__Discount__c' => compoundedDiscount(line)
                }
            });
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
        Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
        if (source == null) {
            return result;
        }

        for (Id quoteId : source.keySet()) {
            Set<Id> lineIds = source.get(quoteId);
            if (quoteId != null && lineIds != null && !lineIds.isEmpty()) {
                result.put(quoteId, new Set<Id>(lineIds));
            }
        }
        return result;
    }
}