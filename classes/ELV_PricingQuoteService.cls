/**
 * ELV_PricingQuoteService
 * ─────────────────────────
 * Quote-level pricing logic:
 *   1. Delegates to ELV_SubscriptionStampService on insert (stamps ELV_ sub fields)
 *   2. Aggregates line-level data back onto the Quote after line DML
 *      (deployment-method rollup, etc.)
 *
 * Called from:
 *   - Quote before-insert/before-update trigger → stampAndPrepare()
 *   - QuoteLineItem after trigger → aggregateFromLines()
 */
public with sharing class ELV_PricingQuoteService {

    /**
     * Quote before-insert / before-update: stamp subscription fields.
     */
    public static void stampAndPrepare(List<Quote> quotes, Boolean isInsert) {
        if (!ELV_PricingControl.isActive() || quotes.isEmpty()) return;

        // Always stamp on insert; on update, only if account changed
        if (isInsert) {
            ELV_SubscriptionStampService.stampSubscriptionFields(quotes);
        } else {
            List<Quote> needsRestamp = new List<Quote>();
            for (Quote q : quotes) {
                Quote old = (Quote) Trigger.oldMap.get(q.Id);
                if (old == null || q.AccountId != old.AccountId) {
                    needsRestamp.add(q);
                }
            }
            if (!needsRestamp.isEmpty()) {
                ELV_SubscriptionStampService.stampSubscriptionFields(needsRestamp);
            }
        }
    }

    /**
     * After QLI insert/update/delete: aggregate line data onto Quote.
     * Runs a single SOQL to collect all lines per affected Quote, then
     * uses ELV_LineCountService to compute aggregates.
     */
    public static void aggregateFromLines(Set<Id> quoteIds) {
        if (!ELV_PricingControl.isActive() || quoteIds.isEmpty()) return;

        // Query all lines for affected quotes
        String soql = 'SELECT Id, QuoteId, Quantity, '
            + 'ELV_Product_Code__c, ELV_Product_Line__c, ELV_Product_Group__c, '
            + 'ELV_Deployment_Method__c '
            + 'FROM QuoteLineItem WHERE QuoteId IN :quoteIds';

        Map<Id, List<QuoteLineItem>> linesByQuote = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem li : (List<QuoteLineItem>) Database.query(soql)) {
            if (!linesByQuote.containsKey(li.QuoteId)) {
                linesByQuote.put(li.QuoteId, new List<QuoteLineItem>());
            }
            linesByQuote.get(li.QuoteId).add(li);
        }

        // Compute aggregates and build updates
        List<Quote> updates = new List<Quote>();
        for (Id qId : quoteIds) {
            List<QuoteLineItem> qLines = linesByQuote.get(qId);
            if (qLines == null) qLines = new List<QuoteLineItem>();

            ELV_LineCountService.LineAggregates agg = ELV_LineCountService.compute(qLines);

            Quote upd = new Quote(Id = qId);

            // Deployment Method Aggregate: Hybrid if both on-prem and cloud exist
            String deploymentMethod;
            if (agg.onPremCount > 0 && (agg.cloudCount > 0 || agg.cloudGovCount > 0)) {
                deploymentMethod = 'Hybrid';
            } else if (agg.onPremCount > 0) {
                deploymentMethod = 'On-Prem';
            } else if (agg.cloudGovCount > 0) {
                deploymentMethod = 'Gov Cloud';
            } else if (agg.cloudCount > 0) {
                deploymentMethod = 'Cloud';
            } else {
                deploymentMethod = null;
            }
            upd.put('ELV_Deployment_Method_Aggregate__c',
                deploymentMethod != null ? 1 : 0);

            updates.add(upd);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
