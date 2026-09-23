/**
 * TEMPORARY backfill job (Ravus, 2026-09-22).
 * Recalculates Ruby__Discount__c as the compounded customer/partner/distributor
 * discount, treating null inputs as 0. One Quote per transaction, because
 * Ruby.GlobalQuoteServiceAPI.updateQuote performs a callout.
 */
public with sharing class ELV_QuoteDiscountBackfillQueueable implements Queueable, Database.AllowsCallouts {

    public class BackfillException extends Exception {}

    private final Id quoteId;

    public ELV_QuoteDiscountBackfillQueueable(Id quoteId) {
        this.quoteId = quoteId;
    }

    public void execute(QueueableContext context) {
        List<Object> lineItems = new List<Object>();

        for (QuoteLineItem line : [
            SELECT Id, Ruby__Discount__c, ELV_Customer_Discount__c,
                   ELV_PartnerDiscount__c, ELV_DistributorDiscount__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            AND Ruby__LineType__c IN ('LineItem', 'RampItem')
        ]) {
            Decimal customer = line.ELV_Customer_Discount__c == null ? 0 : line.ELV_Customer_Discount__c;
            Decimal partner = line.ELV_PartnerDiscount__c == null ? 0 : line.ELV_PartnerDiscount__c;
            Decimal distributor = line.ELV_DistributorDiscount__c == null ? 0 : line.ELV_DistributorDiscount__c;

            Decimal compoundedDiscount = (
                (1 - ((1 - customer / 100) * (1 - partner / 100) * (1 - distributor / 100))) * 100
            ).setScale(5);

            Decimal currentDiscount = line.Ruby__Discount__c == null ? 0 : line.Ruby__Discount__c;
            if (currentDiscount.setScale(5) == compoundedDiscount) {
                continue;
            }

            lineItems.add(new Map<String, Object>{
                'lineItemId' => line.Id,
                'fieldValues' => new Map<String, Object>{
                    'Ruby__Discount__c' => compoundedDiscount
                }
            });
        }

        if (lineItems.isEmpty()) {
            return;
        }

        Ruby.GlobalAPITypes.UpdateAction action = new Ruby.GlobalAPITypes.UpdateAction();
        action.action = 'updateLineItems';
        action.payload = new Map<String, Object>{ 'lineItems' => lineItems };

        Ruby.GlobalAPITypes.UpdateQuoteRequest request = new Ruby.GlobalAPITypes.UpdateQuoteRequest();
        request.quoteId = String.valueOf(quoteId);
        request.isCommit = true;
        request.recalc = 'PRICING_ONLY';
        request.actions = new List<Ruby.GlobalAPITypes.UpdateAction>{ action };

        Ruby.GlobalAPITypes.UpdateQuoteResponse response = Ruby.GlobalQuoteServiceAPI.updateQuote(request);

        if (response == null || response.status != 'SUCCESS') {
            throw new BackfillException(
                'Ruby quote pricing recalculation failed for quote ' + quoteId + ': ' + JSON.serialize(response)
            );
        }
    }
}