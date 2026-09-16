/**
 * ELV_PricingQuoteLineTrigger
 * ──────────────────────
 * Consolidated pricing trigger on QuoteLineItem.
 * - Before Insert/Update: apply price-rule families (date defaults, sub term,
 *   schedule clears, distributor discount, bundle propagation, transaction type)
 * - After Insert/Update/Delete/Undelete: aggregate line data back to Quote
 *   (deployment-method rollup, etc.)
 *
 * Gated by ELV_PricingControl.isActive() — ships inactive, restricted to a
 * single pilot user (see ELV_PricingControl / ELV_Pilot_Gate_Active__c).
 */
trigger ELV_PricingQuoteLineTrigger on QuoteLineItem (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (!ELV_PricingControl.isActive()) return;

    if (Trigger.isBefore) {
        // Apply consolidated price rules
        ELV_PricingLineService.apply(Trigger.new);
    } else {
        // Aggregate to parent Quote
        Set<Id> quoteIds = new Set<Id>();
        List<QuoteLineItem> items = Trigger.isDelete ? Trigger.old : Trigger.new;
        for (QuoteLineItem li : items) {
            if (li.QuoteId != null) quoteIds.add(li.QuoteId);
        }
        if (!quoteIds.isEmpty()) {
            ELV_PricingQuoteService.aggregateFromLines(quoteIds);
        }
    }
}