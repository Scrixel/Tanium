/**
 * ELV_PricingQuoteTrigger
 * ──────────────────
 * Consolidated pricing trigger on Quote.
 * - Always stamps the fail-closed ELV_Pilot_Gate_Active__c marker so the
 *   plug-in has a trustworthy, server-computed signal to read — even when
 *   the gate resolves false.
 * - When the gate is active (CMT Active__c = true AND running user is the
 *   pilot user): stamps ELV_ subscription fields from Ruby__Subscription__c
 *   (insert), or re-stamps on Account change (update).
 *
 * Gated by ELV_PricingControl.isActive() — ships inactive, restricted to a
 * single pilot user even once the CMT switch is flipped on.
 */
trigger ELV_PricingQuoteTrigger on Quote (before insert, before update) {
    // Always stamp the marker — fail-closed by construction (defaults false).
    ELV_PricingControl.stampPilotGate(Trigger.new);

    if (!ELV_PricingControl.isActive()) return;

    ELV_PricingQuoteService.stampAndPrepare(
        Trigger.new,
        Trigger.isInsert
    );
}