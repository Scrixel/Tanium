/**
 * Deprecated compatibility shell.
 * Consolidated pricing now runs from ELV_QuoteLineTriggerHandler so Salesforce
 * trigger order cannot create duplicate writes. Metadata status is Inactive.
 */
trigger ELV_PricingQuoteLineTrigger on QuoteLineItem (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    // Intentionally empty. Retained only so an in-place deployment can disable it safely.
}