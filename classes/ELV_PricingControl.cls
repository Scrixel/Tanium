/**
 * ELV_PricingControl
 * ────────────────────
 * Kill-switch gate for the consolidated pricing engine, backed by:
 *   1. Tanium_Pricing_Control__mdt.Default.Active__c — org-wide master switch.
 *   2. A hard-coded pilot user gate — restricts execution to a single pilot
 *      user's context while validation is in progress.
 *
 * SECURITY NOTE: PILOT_USER_ID is server-side only. It must never be copied
 * into client-side JavaScript (mirrors the existing pilot-gate convention in
 * QuoteTriggerHandler / ELV_QuoteApprovalSubmitController). The plug-ins only
 * ever read the server-stamped marker field below — they never evaluate the
 * user identity themselves.
 *
 * Ships INACTIVE — Active__c = false AND the pilot gate further restricts
 * to a single user, so consolidated pricing cannot fire broadly even if the
 * CMT record is flipped on prematurely.
 */
public with sharing class ELV_PricingControl {

    /** Hard-coded pilot user — server-side only, never exposed to the plug-in. */
    private static final Id PILOT_USER_ID = '005cc00000CgeRxAAJ';

    private static Boolean cachedActive;
    @TestVisible
    private static Id runningUserOverride;

    /**
     * Master gate: true only when
     *   - the Default CMT record has Active__c = true, AND
     *   - the running user is the pilot user.
     * Both conditions are evaluated server-side; nothing here is exposed
     * to the plug-in beyond the boolean marker stamped by stampPilotGate().
     */
    public static Boolean isActive() {
        if (cachedActive != null) {
            return cachedActive;
        }
        cachedActive = isControlEnabled() && isPilotUser(currentUserId());
        return cachedActive;
    }

    /** Reads the CMT master switch. */
    private static Boolean isControlEnabled() {
        List<Tanium_Pricing_Control__mdt> recs = [
            SELECT Active__c
            FROM Tanium_Pricing_Control__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        return !recs.isEmpty() && recs[0].Active__c;
    }

    /** True only for the hard-coded pilot user. Server-side only. */
    private static Boolean isPilotUser(Id userId) {
        return userId != null && userId == PILOT_USER_ID;
    }

    private static Id currentUserId() {
        return runningUserOverride != null ? runningUserOverride : UserInfo.getUserId();
    }

    /**
     * Stamps the fail-closed marker field the plug-ins read.
     * Called from ELV_PricingQuoteTrigger before insert/update.
     * The plug-in NEVER evaluates user identity itself — it only reads
     * this server-computed boolean, defaulting to false on any doubt.
     */
    public static void stampPilotGate(List<Quote> quotes) {
        Boolean active = isActive();
        for (Quote q : quotes) {
            q.put('ELV_Pilot_Gate_Active__c', active);
        }
    }

    /** Test-visible override so unit tests can bypass CMT. */
    @TestVisible
    private static void setActive(Boolean val) {
        cachedActive = val;
    }

    /** Test-visible override so unit tests can simulate running as the pilot user. */
    @TestVisible
    private static void setRunningUserOverride(Id userId) {
        runningUserOverride = userId;
        cachedActive = null; // force re-evaluation
    }
}
