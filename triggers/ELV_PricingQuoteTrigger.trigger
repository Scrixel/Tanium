/**
 * Deprecated compatibility shell.
 * Consolidated pricing now runs from ELV_QuoteTriggerHandler so Salesforce
 * trigger order cannot create duplicate writes. Metadata status is Inactive.
 */
trigger ELV_PricingQuoteTrigger on Quote (before insert, before update) {
    // Intentionally empty. Retained only so an in-place deployment can disable it safely.
}