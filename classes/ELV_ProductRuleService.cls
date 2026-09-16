/**
 * ELV_ProductRuleService
 * ────────────────────────
 * Server-side product-rule enforcement for Selection rules that cannot be
 * expressed as native Nue product rules due to complex multi-field conditions.
 *
 * Covers the ESR auto-add family (Rules #30, #31, #32, #42, #43) which
 * depend on geography, segment, seat count, deployment partner, and
 * business motion.
 *
 * NOTE: The 15 simple perpetual-maintenance auto-add rules (#29, #33-41,
 * #44-48) should be configured as native Nue product rules, NOT coded here.
 * This class handles only the rules that exceed native-rule expressiveness.
 *
 * This service is designed to run AFTER quote creation / line addition,
 * and will insert additional QuoteLineItem records as needed.
 */
public with sharing class ELV_ProductRuleService {

    // ESR SKU constants
    private static final String ESR_TIER1 = 'ELV-TAN-PREM-ESR-TIER1-1D/M';
    private static final String ESR_TIER2 = 'ELV-TAN-PREM-ESR-TIER2-1D/M';
    private static final String ESR_TIER3 = 'ELV-TAN-PREM-ESR-TIER3-1D/M';
    private static final String ESR_1WEEK = 'ELV-TAN-PREM-ESR-1W';
    private static final String ESR_1DAY  = 'ELV-TAN-PREM-ESR-1D/W';

    // Deployment partner ID (hardcoded per source rules)
    private static final String DEPLOYMENT_PARTNER_ID = '0017V00002740yeQAA';

    // Country lists per ESR tier
    private static final Set<String> TIER1_COUNTRIES = new Set<String>{
        'Australia', 'United States', 'Canada'
    };
    private static final Set<String> TIER2_COUNTRIES = new Set<String>{
        'Belgium', 'Denmark', 'Finland', 'France', 'Germany', 'Iceland',
        'Ireland', 'Luxembourg', 'Netherlands', 'Norway', 'Sweden',
        'Switzerland', 'United Kingdom'
    };
    private static final Set<String> TIER3_COUNTRIES = new Set<String>{
        'Austria', 'Brazil', 'Bulgaria', 'Croatia', 'Cyprus', 'Czech Republic',
        'Greece', 'Hungary', 'Israel', 'Italy', 'Korea, Republic of', 'Malta',
        'Mexico', 'New Zealand', 'Poland', 'Portugal', 'Romania', 'Singapore',
        'Slovakia', 'Slovenia', 'Spain'
    };
    // Combined exclusion set for rules #42, #43 (all tiered countries)
    private static final Set<String> ALL_TIERED_COUNTRIES = new Set<String>();
    static {
        ALL_TIERED_COUNTRIES.addAll(TIER1_COUNTRIES);
        ALL_TIERED_COUNTRIES.addAll(TIER2_COUNTRIES);
        ALL_TIERED_COUNTRIES.addAll(TIER3_COUNTRIES);
    }

    /**
     * Evaluate ESR auto-add rules for the given quotes.
     * Called after quote creation or when relevant quote fields change.
     * Returns the list of QuoteLineItems to insert (caller handles DML).
     */
    public static List<QuoteLineItem> evaluateESRAutoAdd(List<Quote> quotes) {
        List<QuoteLineItem> toInsert = new List<QuoteLineItem>();
        if (!ELV_PricingControl.isActive()) return toInsert;

        // Collect quotes that already have ESR lines (don't double-add)
        Set<Id> quoteIds = new Set<Id>();
        for (Quote q : quotes) quoteIds.add(q.Id);

        Set<Id> quotesWithESR = new Set<Id>();
        for (QuoteLineItem li : [
            SELECT QuoteId, ELV_Product_Code__c
            FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
              AND ELV_Product_Code__c IN (:ESR_TIER1, :ESR_TIER2, :ESR_TIER3, :ESR_1WEEK, :ESR_1DAY)
        ]) {
            quotesWithESR.add(li.QuoteId);
        }

        // Check T5S/T5M presence
        Set<Id> quotesWithT5 = new Set<Id>();
        for (QuoteLineItem li : [
            SELECT QuoteId FROM QuoteLineItem
            WHERE QuoteId IN :quoteIds
              AND (ELV_Product_Code__c LIKE 'ELV-TAN-T5S%' OR ELV_Product_Code__c LIKE 'ELV-TAN-T5M%')
        ]) {
            quotesWithT5.add(li.QuoteId);
        }

        for (Quote q : quotes) {
            if (quotesWithESR.contains(q.Id)) continue;
            if (quotesWithT5.contains(q.Id)) continue;

            Boolean dontRun = ELV_PricingAccess.isTrue(q.get('ELV_Dont_Run_Product_Rule__c'));
            if (dontRun) continue;

            String oppType     = (String) q.get('ELV_Opportunity_Type__c');
            String acctType    = (String) q.get('ELV_Account_Type__c');
            String quoteType   = (String) q.get('ELV_Quote_Type__c');
            String country     = (String) q.get('ShippingCountry');
            String bizMotion   = (String) q.get('ELV_Business_Motion__c');
            String segment     = (String) q.get('ELV_Account_Segment__c');
            Decimal seats      = ELV_PricingAccess.toDecimal(q.get('ELV_Sales_Ops_Derived_EP__c'));
            String deployPartner = (String) q.get('ELV_Deployment_Partner__c');

            String esrSku = null;

            // ── Rules #30-32: Geography-based ESR auto-add (new customer, partner-deployed) ──
            if (oppType != null && oppType.equalsIgnoreCase('New Customer')
                && deployPartner != null && deployPartner.contains(DEPLOYMENT_PARTNER_ID)
                && seats <= 50000
                && (bizMotion == null || !bizMotion.equalsIgnoreCase('MSP'))) {

                if (country != null && TIER1_COUNTRIES.contains(country)
                    && (segment == null || !segment.equalsIgnoreCase('Major'))
                    && !isInSet(q, 'ELV_Region__c', new Set<String>{'US Federal','Channel_Federal','USPS Federal HA'})) {
                    esrSku = ESR_TIER1;  // Rule #30
                } else if (country != null && TIER2_COUNTRIES.contains(country)
                    && (segment == null || !ELV_PricingAccess.anyOf(segment, new List<String>{'Majors','Public Sector'}))) {
                    esrSku = ESR_TIER2;  // Rule #31
                } else if (country != null && TIER3_COUNTRIES.contains(country)
                    && (segment == null || !ELV_PricingAccess.anyOf(segment, new List<String>{'Majors','Public Sector'}))) {
                    esrSku = ESR_TIER3;  // Rule #32
                }
            }

            // ── Rule #43: ESR 1-week (large accounts, non-tiered countries) ──
            if (esrSku == null && seats >= 10000
                && (country == null || !ALL_TIERED_COUNTRIES.contains(country))
                && acctType != null && ELV_PricingAccess.anyOf(acctType, new List<String>{'Former Customer','Prospect'})
                && quoteType != null && quoteType.equalsIgnoreCase('Quote')
                && (bizMotion == null || !bizMotion.equalsIgnoreCase('MSP'))
                && segment != null && ELV_PricingAccess.anyOf(segment, new List<String>{'Majors','Enterprise'})
                && (deployPartner == null || ELV_PricingAccess.blank(deployPartner) || deployPartner.contains(DEPLOYMENT_PARTNER_ID))) {
                esrSku = ESR_1WEEK;
            }

            // ── Rule #42: ESR 1-day/week (small accounts or MSP, non-tiered countries) ──
            if (esrSku == null
                && (country == null || !ALL_TIERED_COUNTRIES.contains(country))
                && quoteType != null && quoteType.equalsIgnoreCase('Quote')
                && (deployPartner == null || ELV_PricingAccess.blank(deployPartner) || deployPartner.contains(DEPLOYMENT_PARTNER_ID))) {

                Boolean qualifies = false;
                // Path 1: small non-MSP prospects
                if (seats < 10000
                    && acctType != null && ELV_PricingAccess.anyOf(acctType, new List<String>{'Former Customer','Prospect'})
                    && (bizMotion == null || !bizMotion.equalsIgnoreCase('MSP'))) {
                    qualifies = true;
                }
                // Path 2: MSP new customers
                if (!qualifies && bizMotion != null && bizMotion.equalsIgnoreCase('MSP')
                    && oppType != null && ELV_PricingAccess.anyOf(oppType, new List<String>{'New Customer','New MSP End User'})) {
                    qualifies = true;
                }

                if (qualifies) {
                    esrSku = ESR_1DAY;
                }
            }

            // If a SKU was determined, build the line item
            if (esrSku != null) {
                QuoteLineItem newLine = new QuoteLineItem(QuoteId = q.Id);
                newLine.put('ELV_Product_Code__c', esrSku);
                newLine.Quantity = 1;
                // PricebookEntryId must be resolved by caller or a helper
                toInsert.add(newLine);
            }
        }

        return toInsert;
    }

    private static Boolean isInSet(SObject q, String field, Set<String> vals) {
        String v = (String) q.get(field);
        return v != null && vals.contains(v);
    }
}
