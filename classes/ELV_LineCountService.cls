/**
 * ELV_LineCountService
 * ──────────────────────
 * Computes shared line-level aggregates (counts, sums, max dates) over the
 * current set of quote lines.  These values are consumed by both:
 *   - The Apex trigger (for persisted field stamps and product-rule enforcement)
 *   - The UI plug-in (which recomputes them client-side over $$quoteLines)
 *
 * This service operates over an in-memory list of QuoteLineItem records,
 * not a SOQL query, so it can run in a before-trigger context on the
 * current transaction's lines.
 *
 * 78 plug-in variables from the Product Rules workbook are organized into
 * families below.  The plug-in mirrors this logic in JavaScript.
 */
public with sharing class ELV_LineCountService {

    /**
     * LineAggregates holds all computed counts/sums/maxes for one Quote's lines.
     * The plug-in JS mirrors this structure.
     */
    public class LineAggregates {
        // SKU-specific quantity counts (QL totals)
        public Map<String, Decimal> skuQty     = new Map<String, Decimal>();
        // SKU-specific max quantities
        public Map<String, Decimal> skuMaxQty  = new Map<String, Decimal>();
        // SKU-specific max end dates
        public Map<String, Date>    skuMaxEnd  = new Map<String, Date>();
        // Named summary variable counts
        public Map<String, Decimal> namedCount = new Map<String, Decimal>();
        // Core Quantity aggregate
        public Decimal coreQuantity = 0;
        // Deployment method counts
        public Decimal onPremCount  = 0;
        public Decimal cloudCount   = 0;
        public Decimal cloudGovCount = 0;
    }

    // ── SKU patterns for quantity tracking ────────────────────────────────
    // These match the 78 plug-in variables from the Product Rules workbook.

    private static final Set<String> QTY_TRACKED_SKUS = new Set<String>{
        'TAN-EXPMGMT-OT-CLOUD', 'TAN-EXPMGMT-OT-S',
        'TAN-CORE-OT-CLOUD', 'TAN-CORE-OT-S',
        'TAN-SUPP-ENHANCED', 'TAN-SUPP-EXTENDED24X7',
        'TAN-SUPP-HUNTIQ-CLOUD', 'TAN-SECOPSHUNTIQ-CLOUD', 'TAN-SECOPSHUNTIQ-S',
        'TAN-PREM-ESR-1W', 'TAN-PREM-ESR-TIER1-1D/M', 'TAN-PREM-ESR-TIER2-1D/M', 'TAN-PREM-ESR-TIER3-1D/M',
        'TAN-TRN-TIER1BUNDLE', 'TAN-TRN-TIER2BUNDLE', 'TAN-TRN-TIER3BUNDLE',
        'TAN-TRN-TIER4BUNDLE', 'TAN-TRN-TIER5BUNDLE',
        'TAN-DISC-P', 'TAN-CORE-S', 'GCP-CHRNCL',
        'TAN-PREM-ESR-1D/W'
    };

    private static final Set<String> MAX_END_TRACKED_SKUS = new Set<String>{
        'TAN-SUPP-ENHANCED', 'TAN-SUPP-EXTENDED24X7',
        'TAN-SUPP-HUNTIQ-CLOUD',
        'TAN-CORE-OT-CLOUD', 'TAN-CORE-OT-S',
        'TAN-EXPMGMT-OT-CLOUD', 'TAN-EXPMGMT-OT-S'
    };

    /**
     * Compute aggregates over the given quote lines.
     * Designed to run on a single quote's lines at a time.
     */
    public static LineAggregates compute(List<QuoteLineItem> lines) {
        LineAggregates agg = new LineAggregates();

        for (QuoteLineItem li : lines) {
            String sku = (String) li.get('Product2.ProductCode');
            if (sku == null) {
                // Fallback: try the ELV product code field
                sku = (String) li.get('ELV_Product_Code__c');
            }
            if (sku == null) continue;

            String skuUpper = sku.toUpperCase();
            Decimal qty = ELV_PricingAccess.toDecimal(li.Quantity);

            // ── SKU quantity tracking ──
            if (QTY_TRACKED_SKUS.contains(skuUpper) || QTY_TRACKED_SKUS.contains(sku)) {
                String key = skuUpper;
                Decimal existing = agg.skuQty.containsKey(key) ? agg.skuQty.get(key) : 0;
                agg.skuQty.put(key, existing + qty);
            }

            // ── SKU max quantity (for perpetual auto-add rules) ──
            if (QTY_TRACKED_SKUS.contains(skuUpper)) {
                Decimal existingMax = agg.skuMaxQty.containsKey(skuUpper) ? agg.skuMaxQty.get(skuUpper) : 0;
                if (qty > existingMax) agg.skuMaxQty.put(skuUpper, qty);
            }

            // ── SKU max end date tracking ──
            if (MAX_END_TRACKED_SKUS.contains(skuUpper)) {
                Date endDt = ELV_PricingAccess.toDate(li.get('ELV_End_Date__c'));
                if (endDt == null) endDt = ELV_PricingAccess.toDate(li.get('ServiceDate'));
                if (endDt != null) {
                    Date existing = agg.skuMaxEnd.get(skuUpper);
                    if (existing == null || endDt > existing) {
                        agg.skuMaxEnd.put(skuUpper, endDt);
                    }
                }
            }

            // ── Core Quantity (used by training promo rules #18, #55-59) ──
            String productLine = (String) li.get('ELV_Product_Line__c');
            String productGroup = (String) li.get('ELV_Product_Group__c');
            if (productGroup != null && productGroup.equalsIgnoreCase('Software')) {
                if (productLine != null && productLine.containsIgnoreCase('Core')) {
                    agg.coreQuantity += qty;
                }
            }

            // ── Deployment Method counts (rules #94, #99-102) ──
            String deployMethod = (String) li.get('ELV_Deployment_Method__c');
            if (deployMethod != null) {
                if (deployMethod.equalsIgnoreCase('On-Prem') || deployMethod.equalsIgnoreCase('On-Premise')) {
                    agg.onPremCount += qty;
                } else if (deployMethod.containsIgnoreCase('Gov Cloud') || deployMethod.containsIgnoreCase('GovCloud')) {
                    agg.cloudGovCount += qty;
                } else if (deployMethod.containsIgnoreCase('Cloud')) {
                    agg.cloudCount += qty;
                }
            }

            // ── Named summary variable counts ──
            // Training promo counts
            String promoName = (String) li.get('ELV_Product_Promotion_Name__c');
            if (promoName != null && !ELV_PricingAccess.blank(promoName)) {
                incrementNamed(agg, 'TrainingPromoLineCount', 1);
            }

            // Product-family-specific named counts
            // AEM solution counts for rules #24, #25, #60-63
            String aemFamily = (String) li.get('ELV_AEM_Solution_Family__c');
            if (aemFamily != null) {
                incrementNamed(agg, 'AEM_' + aemFamily, qty);
            }

            // Tanium Cloud/Subscription XEM Core and Solution products for #23, #27
            Boolean isXemCore = ELV_PricingAccess.isTrue(li.get('ELV_Is_XEM_Core__c'));
            Boolean isSolution = ELV_PricingAccess.isTrue(li.get('ELV_Is_Solution_Product__c'));
            if (isXemCore) {
                if (deployMethod != null && deployMethod.containsIgnoreCase('Cloud')) {
                    incrementNamed(agg, 'CloudXEMCore', qty);
                } else {
                    incrementNamed(agg, 'SubscriptionXEMCore', qty);
                }
            }
            if (isSolution) {
                if (deployMethod != null && deployMethod.containsIgnoreCase('Cloud')) {
                    incrementNamed(agg, 'CloudSolutionProducts', qty);
                } else {
                    incrementNamed(agg, 'SubscriptionSolutionProducts', qty);
                }
            }

            // Bundle/promo tracking for #7, #21
            Boolean isBundle = ELV_PricingAccess.isTrue(li.get('ELV_Is_Bundle__c'));
            if (isBundle && productLine != null && productLine.equalsIgnoreCase('Training')) {
                if (promoName != null && !ELV_PricingAccess.blank(promoName)) {
                    incrementNamed(agg, 'TrainingBundleQuantityLimit', qty);
                }
            }

            // Provision module counts for #12, #13, #14
            Boolean isProvisionModule = ELV_PricingAccess.isTrue(li.get('ELV_Is_Provision_Module__c'));
            if (isProvisionModule) {
                if (deployMethod != null && deployMethod.containsIgnoreCase('Gov Cloud')) {
                    incrementNamed(agg, 'ProvisionCloudGovModule', qty);
                } else if (deployMethod != null && deployMethod.containsIgnoreCase('Cloud')) {
                    incrementNamed(agg, 'ProvisionCloudModule', qty);
                } else {
                    incrementNamed(agg, 'ProvisionSubscriptionModule', qty);
                }
            }

            // Required-for-provision counts (QL total)
            Boolean reqProvCloud = ELV_PricingAccess.isTrue(li.get('ELV_Required_for_Provision_Cloud__c'));
            Boolean reqProvGov   = ELV_PricingAccess.isTrue(li.get('ELV_Required_for_Provision_Gov_Cloud__c'));
            Boolean reqProvSub   = ELV_PricingAccess.isTrue(li.get('ELV_Required_for_Provision_Subscription__c'));
            if (reqProvCloud)  incrementNamed(agg, 'ReqProvisionCloud', qty);
            if (reqProvGov)    incrementNamed(agg, 'ReqProvisionGovCloud', qty);
            if (reqProvSub)    incrementNamed(agg, 'ReqProvisionSubscription', qty);

            // Threat Response required count for #50
            Boolean threatReqd = ELV_PricingAccess.isTrue(li.get('ELV_Threat_Response_Required__c'));
            if (threatReqd) incrementNamed(agg, 'ThreatResponseRequired', qty);
        }

        return agg;
    }

    private static void incrementNamed(LineAggregates agg, String name, Decimal amount) {
        Decimal existing = agg.namedCount.containsKey(name) ? agg.namedCount.get(name) : 0;
        agg.namedCount.put(name, existing + amount);
    }

    /** Convenience: get a named count, defaulting to 0. */
    public static Decimal getCount(LineAggregates agg, String name) {
        return agg.namedCount.containsKey(name) ? agg.namedCount.get(name) : 0;
    }

    /** Convenience: get a SKU quantity total, defaulting to 0. */
    public static Decimal getSkuQty(LineAggregates agg, String sku) {
        String key = sku.toUpperCase();
        return agg.skuQty.containsKey(key) ? agg.skuQty.get(key) : 0;
    }
}