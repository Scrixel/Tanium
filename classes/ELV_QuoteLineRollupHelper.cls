/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Stamps quote-line-derived rollup fields onto the standard Quote. These fields
 *            are the replacements for the retired CPQ summary variables, and their only
 *            purpose is to let ELV_Quote_Term_Version__c.Tested_Formula__c decide which
 *            quote term versions apply to a Quote.
 *
 * WHERE THIS RUNS
 * ---------------
 *            This class is invoked from exactly ONE place: the first element of the
 *            "Quote Terms - v4 Quote Provision Manager" screen flow, immediately before
 *            "Find Matching Term Versions" (FindMatchingQuoteTermVersions) evaluates the
 *            stored formulas.
 *
 *            IT DOES NOT FIRE IN THE QLE.
 *
 *            It is deliberately NOT wired to the Quote trigger, the QuoteLineItem trigger,
 *            or any Nue Line Editor UI Plugin path, and it must not be. It aggregates every
 *            line on the Quote and performs DML on the Quote, so calling it during pricing
 *            or line editing would add a query and a save to every keystroke-level
 *            recalculation. The values it produces are only ever read at quote-term sync
 *            time, so sync time is the only time they need to be correct.
 *
 *            The paired class ELV_QuoteRollupHelper does the same job for Subscription-derived
 *            values (the ELV_Sub* fields). The two field sets are disjoint.
 *
 *            Field list, aggregation, filters and value sets are transcribed from
 *            Quote_Term_Condition_-_Summary_Variables > "Variables Mapped".
 *
 *            GENERATED from the workbook - if the workbook changes, regenerate rather
 *            than hand-editing the SPECS block.
 *
 *            SPECS.add(new Spec(
 *              'TARGET_QUOTE_FIELD__c',     // Where the calculated result is stored
 *               Aggregation.SUM,                        // COUNT or SUM
 *               'QUANTITY_FIELD__c',              // Field to sum; use null for COUNT
 *               'FILTER_FIELD__c',                    // Quote Line field used to determine matches
 *               MatchMode.EQUALS,                 // EQUALS, CONTAINS, BOOLEAN_TRUE, or ALL_LINES
 *               new Set<String>{
 *                   'MATCH_VALUE_1',
 *                   'MATCH_VALUE_2'
 *               }
));
 */
public with sharing class ELV_QuoteLineRollupHelper {
    private enum Aggregation {
        /** Number of matching lines. The CPQ summary variable used Count. */
        COUNT,
        /** Sum of the spec's quantity field across matching lines. */
        SUM
    }

    private enum MatchMode {
        /** Filter field value is one of the spec's values. */
        EQUALS,
        /** Filter field value contains the spec's single value as a substring. */
        CONTAINS,
        /** Filter field is a checkbox and must be true. */
        BOOLEAN_TRUE,
        /** No filter - every line on the Quote is counted. */
        ALL_LINES
    }

    /** One stamped Quote field and the quote-line population that feeds it. */
    @TestVisible
    private class Spec {
        public String targetField;
        public Aggregation agg;
        /** Null for COUNT specs, which count lines rather than units. */
        public String quantityField;
        public String filterField;
        public MatchMode mode;
        public Set<String> values;

        public Spec(
            String targetField,
            Aggregation agg,
            String quantityField,
            String filterField,
            MatchMode mode,
            Set<String> values
        ) {
            this.targetField = targetField;
            this.agg = agg;
            this.quantityField = quantityField;
            this.filterField = filterField;
            this.mode = mode;
            this.values = values;
        }

        public Boolean matches(QuoteLineItem line) {
            if (mode == MatchMode.ALL_LINES) {
                return true;
            }

            Object raw = readPath(line, filterField);

            if (mode == MatchMode.BOOLEAN_TRUE) {
                return raw == true;
            }

            if (raw == null) {
                return false;
            }
            String value = String.valueOf(raw);

            if (mode == MatchMode.CONTAINS) {
                // CONTAINS specs always carry exactly one value.
                for (String needle : values) {
                    if (value.contains(needle)) {
                        return true;
                    }
                }
                return false;
            }

            return values.contains(value);
        }
    }

    @TestVisible
    private static final List<Spec> SPECS = new List<Spec>();

    static {
        SPECS.add(new Spec('ELV_TotalPGA__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-PREM-ESR-PGA' })); // Total PGA
        SPECS.add(new Spec('ELV_TotalWebBasedTraining__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Product2.TrainingDeliveryType__c', MatchMode.EQUALS, new Set<String>{ 'Web-Based Training (WBT)' })); // Total Web Based Training
        SPECS.add(new Spec('ELV_TotalInstructorLedTraining__c', Aggregation.SUM, 'Quantity', 'Product2.TrainingDeliveryType__c', MatchMode.EQUALS, new Set<String>{ 'Instructor-Led Training (ILT)' })); // Total Instructor-Led Training
        SPECS.add(new Spec('ELV_TotalVirtualInstructorLedTraining__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Product2.TrainingDeliveryType__c', MatchMode.EQUALS, new Set<String>{ 'Virtual Instructor-Led Training (vILT)' })); // Total Virtual Instructor-Led Training
        SPECS.add(new Spec('ELV_TotalExam__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Product2.TrainingDeliveryType__c', MatchMode.EQUALS, new Set<String>{ 'Exam' })); // Total Exam
        SPECS.add(new Spec('ELV_CountnumberofSubscriptionProduct__c', Aggregation.COUNT, null, 'Product2.Product_Group__c', MatchMode.EQUALS, new Set<String>{ 'Software' })); // Count number of Subscription Product
        SPECS.add(new Spec('ELV_CountTANTAMSUM__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-TAM-SUM' })); // Count TAN-TAM-SUM
        SPECS.add(new Spec('ELV_CountTaaSConversionSKU__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.CONTAINS, new Set<String>{ 'CONVERSION-TAAS' })); // Count TaaS Conversion SKU
        SPECS.add(new Spec('ELV_TotalPremiumSupport__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-PREM-SUM' })); // Total Premium Support
        SPECS.add(new Spec('ELV_CountProductTypeTaniumCloud__c', Aggregation.COUNT, null, 'Product2.Product_Type__c', MatchMode.EQUALS, new Set<String>{ 'TaaS' })); // Count Product Type 'Tanium Cloud'
        SPECS.add(new Spec('ELV_CountProductTypeSubPerpetual__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Product2.Product_Type__c', MatchMode.EQUALS, new Set<String>{ 'Subscription', 'Perpetual' })); // Count Product Type 'Subscriptions/Perpetual'
        SPECS.add(new Spec('ELV_CountCloudGovSKUs__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.CONTAINS, new Set<String>{ 'CONVERSION-CLOUDGOV-US' })); // Count Cloud Gov SKUs
        SPECS.add(new Spec('ELV_TaniumSubscriptionSolutionProducts__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-DEX-X-S', 'TAN-EPMGMT-X-S', 'TAN-IR-X-S', 'TAN-RC-X-S' })); // Tanium Subscription Solution Products
        SPECS.add(new Spec('ELV_TaniumSubscriptionXEMCoreProducts__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-X1-S', 'TAN-X2-S', 'TAN-X3-S' })); // Tanium Subscription XEM Core Products
        SPECS.add(new Spec('ELV_TaniumCloudSolutionProducts__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-RC-X-TAAS', 'TAN-IR-X-TAAS', 'TAN-EPMGMT-X-TAAS', 'TAN-DEX-X-TAAS' })); // Tanium Cloud Solution Products
        SPECS.add(new Spec('ELV_TaniumCloudXEMCoreProducts__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-X1-TAAS', 'TAN-X2-TAAS', 'TAN-X3-TAAS' })); // Tanium Cloud XEM Core Products
        SPECS.add(new Spec('ELV_EmergingEnterprisePromoProducts__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-PRO-PROMO-UPG-ENT-CLOUD', 'TAN-STND-PROMO-UPG-ENT-CLOUD', 'TAN-STND-PROMO-UPG-PRO-CLOUD', 'TAN-ENT-PROMO-CLOUD', 'TAN-PRO-PROMO-CLOUD', 'TAN-STND-PROMO-CLOUD' })); // Emerging Enterprise Promo Products
        SPECS.add(new Spec('ELV_EmergingEnterpriseProducts__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-STD-TAAS', 'TAN-PRO-TAAS', 'TAN-ENT-TAAS', 'TAN-STD-UPG-PRO-TAAS', 'TAN-PRO-UPG-ENT-TAAS', 'TAN-STND-CLOUD', 'TAN-PRO-CLOUD', 'TAN-ENT-CLOUD', 'TAN-STND-UPG-PRO-CLOUD', 'TAN-STND-UPG-ENT-CLOUD', 'TAN-PRO-UPG-ENT-CLOUD' })); // Emerging Enterprise Products
        SPECS.add(new Spec('ELV_CountTANTRNTIER2BUNDLE__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-TRN-TIER2BUNDLE' })); // Count TAN-TRN-TIER2BUNDLE
        SPECS.add(new Spec('ELV_CountTANTRNTIER3BUNDLE__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-TRN-TIER3BUNDLE' })); // Count TAN-TRN-TIER3BUNDLE
        SPECS.add(new Spec('ELV_CountTANTRNTIER1BUNDLE__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-TRN-TIER1BUNDLE' })); // Count TAN-TRN-TIER1BUNDLE
        SPECS.add(new Spec('ELV_CountTANTRNTIER4BUNDLE__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-TRN-TIER4BUNDLE' })); // Count TAN-TRN-TIER4BUNDLE
        SPECS.add(new Spec('ELV_CountTANTRNTIER5BUNDLE__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.EQUALS, new Set<String>{ 'TAN-TRN-TIER5BUNDLE' })); // Count TAN-TRN-TIER5BUNDLE
        SPECS.add(new Spec('ELV_TANSUPPEXTENDED24x7QuoteLine__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Code__c', MatchMode.EQUALS, new Set<String>{ 'TAN-SUPP-EXTENDED24x7' })); // TAN-SUPP-EXTENDED24x7 - Quote Line
        SPECS.add(new Spec('ELV_SUMOTSatelliteSKUs__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Code__c', MatchMode.EQUALS, new Set<String>{ 'TAN-CORE-OT-CLOUD', 'TAN-EXPMGMT-OT-CLOUD', 'TAN-CORE-OT-S', 'TAN-EXPMGMT-OT-S', 'TAN-CORE-OT-S-CONVERSION-CLOUD', 'TAN-EXPMGMT-OT-S-CONVERSION-CLOUD' })); // SUM OT Satellite SKUs
        SPECS.add(new Spec('ELV_SUMTANEMMCLOUD__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Code__c', MatchMode.EQUALS, new Set<String>{ 'TAN-EMM-CLOUD' })); // SUM TAN-EMM-CLOUD
        SPECS.add(new Spec('ELV_CountCONVERSIONCLOUDSKU__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.CONTAINS, new Set<String>{ 'CONVERSION-CLOUD' })); // Count CONVERSION-CLOUD SKU
        SPECS.add(new Spec('ELV_CountSSRMT__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Code__c', MatchMode.EQUALS, new Set<String>{ 'SS-RMT' })); // Count SS-RMT
        SPECS.add(new Spec('ELV_CountLicenseMetricManageOS__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_LicenseMetric__c', MatchMode.EQUALS, new Set<String>{ 'Managed OS' })); // Count License Metric - Manage OS
        SPECS.add(new Spec('ELV_CountLicenseMetricActiveUser__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_LicenseMetric__c', MatchMode.EQUALS, new Set<String>{ 'Active User' })); // Count License Metric - Active User
        SPECS.add(new Spec('ELV_CountTANPREMONSITEFED__c', Aggregation.COUNT, null, 'ELV_Product_Code__c', MatchMode.EQUALS, new Set<String>{ 'TAN-PREM-ONSITE-FED' })); // Count TAN-PREM-ONSITE-FED
        SPECS.add(new Spec('ELV_CountProductLineAppliance__c', Aggregation.COUNT, null, 'Product2.Product_Line__c', MatchMode.EQUALS, new Set<String>{ 'Appliance' })); // Count Product Line 'Appliance'
        SPECS.add(new Spec('ELV_CountTANCOREUPG__c', Aggregation.COUNT, null, 'ELV_Product_Code__c', MatchMode.EQUALS, new Set<String>{ 'TAN-CORE-UPG-P', 'TAN-CORE-UPG-S', 'TAN-CORE-UPG-TAAS' })); // Count TAN-CORE-UPG
        SPECS.add(new Spec('ELV_CountSCONVERSIONSKUs__c', Aggregation.COUNT, null, 'Ruby__ProductSKU__c', MatchMode.CONTAINS, new Set<String>{ 'S-CONVERSION' })); // Count S-CONVERSION SKUs
        SPECS.add(new Spec('ELV_SumEffectiveQuantity__c', Aggregation.COUNT, null, null, MatchMode.ALL_LINES, null)); // Sum Effective Quantity
        SPECS.add(new Spec('ELV_SumTANCONVERGELAB__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Code__c', MatchMode.EQUALS, new Set<String>{ 'TAN-CONVERGE-INPERSON-LABS', 'TAN-CONVERGE-INPERSON-LABS-G', 'TAN-CONVERGE-VIRTUAL-LABS' })); // Sum TAN-CONVERGE-LAB
        SPECS.add(new Spec('ELV_SumESRProduct__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'Product2.Is_ESR_Product__c', MatchMode.BOOLEAN_TRUE, null)); // Sum ESR Product
        SPECS.add(new Spec('ELV_SumPromoTrial__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Promotion_Name__c', MatchMode.EQUALS, new Set<String>{ 'Trial' })); // Sum Promo 'Trial'
        SPECS.add(new Spec('ELV_SumPromoBursting__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Promotion_Name__c', MatchMode.EQUALS, new Set<String>{ 'Burst' })); // Sum Promo 'Bursting'
        SPECS.add(new Spec('ELV_SumPromoFOC__c', Aggregation.SUM, 'Ruby__ActualQuantity__c', 'ELV_Product_Promotion_Name__c', MatchMode.EQUALS, new Set<String>{ 'FOC' })); // Sum Promo 'FOC'
        SPECS.add(new Spec('ELV_Training_Products__c', Aggregation.COUNT, null, 'Product2.Product_Type__c', MatchMode.EQUALS, new Set<String>{ 'Training' })); // Count Training Products
    }

    /**
     * Reads a field off a line, following the dot path for parent fields
     * (e.g. 'Product2.Product_Type__c'). SObject.get() takes a single field
     * only, so each hop is walked with getSObject(). A null parent anywhere
     * on the path yields null, which the callers treat as "does not match".
     */
    @TestVisible
    private static Object readPath(SObject record, String path) {
        if (record == null || String.isBlank(path)) {
            return null;
        }
        if (!path.contains('.')) {
            return record.get(path);
        }

        List<String> hops = path.split('\\.');
        SObject current = record;
        for (Integer i = 0; i < hops.size() - 1; i++) {
            current = current.getSObject(hops[i]);
            if (current == null) {
                return null;
            }
        }
        return current.get(hops[hops.size() - 1]);
    }

    /**
     * Every quote-line field any spec reads, plus the fields needed to group by Quote.
     * Collected from SPECS so adding a workbook row cannot leave a field out of the query.
     * Parent paths ('Product2.X__c') are selected as-is, so one query still covers
     * everything and no field can be left out by hand.
     */
    @TestVisible
    private static Set<String> lineFieldsToQuery() {
        Set<String> fields = new Set<String>{ 'Id', 'QuoteId', 'Quantity' };

        for (Spec sp : SPECS) {
            if (sp.filterField != null) {
                fields.add(sp.filterField);
            }
            if (sp.quantityField != null) {
                fields.add(sp.quantityField);
            }
        }

        return fields;
    }

    /**
     * Stamps every rollup field in memory. Performs no DML.
     *
     * Exposed separately from the invocable so the calculation can be exercised without
     * writing, and so a future caller that already holds the Quote in memory - for example
     * FindMatchingQuoteTermVersions - can stamp without a save.
     */
    public static List<Quote> stampLineRollups(List<Quote> quotes) {
        if (quotes == null || quotes.isEmpty()) {
            return quotes;
        }

        Set<Id> quoteIds = new Set<Id>();
        for (Quote q : quotes) {
            if (q.Id != null) {
                quoteIds.add(q.Id);
            }
        }

        Map<Id, Map<String, Decimal>> byQuote = aggregate(queryLines(quoteIds));

        for (Quote q : quotes) {
            Map<String, Decimal> vals = (q.Id == null) ? null : byQuote.get(q.Id);

            for (Spec sp : SPECS) {
                Decimal v = (vals == null) ? null : vals.get(sp.targetField);

                // Zero rather than null so a formula testing "> 0" never evaluates against
                // a blank. Every one of these fields is a Number.
                q.put(sp.targetField, (v == null) ? 0 : v);
            }
        }

        return quotes;
    }

    /**
     * Re-stamps and persists.
     *
     * PERFORMS DML - never call this from a before-trigger or from any QLE-time path.
     * Invoked as the first element of the "Quote Terms - v4 Quote Provision Manager"
     * screen flow, so the stored values are current before the term formulas are
     * evaluated later in the same flow.
     */
    @InvocableMethod(
        label='Refresh Quote Line Rollups'
        description='Recalculates the quote-line summary-variable replacement fields on the Quote and saves them. Call before evaluating Quote Term Version formulas. Not for QLE use - performs DML.'
        category='Quote Term Management'
    )
    public static void refreshQuoteLineRollups(List<Id> quoteIds) {
        if (quoteIds == null || quoteIds.isEmpty()) {
            return;
        }

        refreshAndSave(new Set<Id>(quoteIds));
    }

    /**
     * Re-stamps and persists for an arbitrary set of Quotes.
     */
    public static List<Quote> refreshAndSave(Set<Id> quoteIds) {
        if (quoteIds == null || quoteIds.isEmpty()) {
            return new List<Quote>();
        }

        List<String> fields = new List<String>{ 'Id' };
        for (Spec sp : SPECS) {
            fields.add(sp.targetField);
        }

        String soql = 'SELECT ' + String.join(fields, ', ') + ' FROM Quote WHERE Id IN :quoteIds';
        List<Quote> quotes = (List<Quote>) Database.query(soql);

        stampLineRollups(quotes);

        // Update a SPARSE copy carrying only Id and the stamped fields.
        //
        // Updating the fully queried record fails with "Operation failed due to fields
        // being inaccessible on Sobject Quote" - the Nue managed trigger validates access
        // across every populated field, and Quote carries managed and formula fields the
        // running user cannot write. Sending only what we changed avoids that entirely,
        // keeps the DML payload minimal, and removes any risk of clobbering a concurrent
        // edit to a field this class does not own. Same pattern as ELV_QuoteRollupHelper.
        List<Quote> toUpdate = new List<Quote>();
        for (Quote q : quotes) {
            Quote sparse = new Quote(Id = q.Id);

            for (Spec sp : SPECS) {
                sparse.put(sp.targetField, q.get(sp.targetField));
            }

            toUpdate.add(sparse);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        return quotes;
    }

    /**
     * One query for every line on the given Quotes, selecting only the fields SPECS reads.
     * One query regardless of how many specs exist, so adding workbook rows costs no SOQL.
     */
    @TestVisible
    private static List<QuoteLineItem> queryLines(Set<Id> quoteIds) {
        if (quoteIds == null || quoteIds.isEmpty()) {
            return new List<QuoteLineItem>();
        }

        String soql =
            'SELECT ' +
            String.join(new List<String>(lineFieldsToQuery()), ', ') +
            ' FROM QuoteLineItem WHERE QuoteId IN :quoteIds';

        return (List<QuoteLineItem>) Database.query(soql);
    }

    /**
     * Folds the lines into one value per spec per Quote, in memory.
     */
    @TestVisible
    private static Map<Id, Map<String, Decimal>> aggregate(List<QuoteLineItem> lines) {
        Map<Id, Map<String, Decimal>> byQuote = new Map<Id, Map<String, Decimal>>();

        for (QuoteLineItem line : lines) {
            if (!byQuote.containsKey(line.QuoteId)) {
                byQuote.put(line.QuoteId, new Map<String, Decimal>());
            }
            Map<String, Decimal> vals = byQuote.get(line.QuoteId);

            for (Spec sp : SPECS) {
                if (!sp.matches(line)) {
                    continue;
                }

                Decimal running = vals.get(sp.targetField);
                if (running == null) {
                    running = 0;
                }

                if (sp.agg == Aggregation.COUNT) {
                    vals.put(sp.targetField, running + 1);
                } else {
                    Object rawQty = readPath(line, sp.quantityField);
                    Decimal qty = (rawQty == null) ? 0 : (Decimal) rawQty;
                    vals.put(sp.targetField, running + qty);
                }
            }
        }

        return byQuote;
    }
}