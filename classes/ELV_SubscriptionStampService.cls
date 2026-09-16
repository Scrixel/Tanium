/**
 * ELV_SubscriptionStampService
 * ──────────────────────────────
 * Stamps 12 ELV_ quote fields from Ruby__Subscription__c at quote creation
 * and renewal.  These fields carry subscription-level counts and max-end-dates
 * that the UI plug-in cannot query at edit time (plug-in has no Subscription
 * access).  Runs in the Quote before-insert / before-update trigger context.
 *
 * Subscription count fields:
 *   ELV_SubCnt_AEM_Core_OnPrem_Sub__c
 *   ELV_SubCnt_AEM_Core_PlusStd_Sub__c
 *   ELV_SubCnt_Req_Provision_Cloud__c
 *   ELV_SubCnt_Req_Provision_GovCloud__c
 *   ELV_SubCnt_Req_Provision_Sub__c
 *   ELV_SubCount_TAN_CORE_OT_CLOUD__c
 *   ELV_SubCount_TAN_CORE_OT_S__c
 *   ELV_SubCount_Tanium_Threat_Response__c
 *
 * Subscription max-end-date fields:
 *   ELV_SubMaxEndDate_CoreOT_Cloud__c
 *   ELV_SubMaxEndDate_CoreOT_Subscription__c
 *   ELV_SubMaxEnd_TAN_SUPP_EXT24x7__c
 *   ELV_SubMaxEndDate_Threat_Resp__c
 *
 * The stamp runs when:
 *   - Quote is inserted (new quote or renewal clone), OR
 *   - An explicit re-stamp is requested (e.g. field change trigger).
 *
 * SKU-to-field mapping is maintained in the STAMP_CONFIG list so new
 * subscription-sourced fields can be added without structural changes.
 */
public with sharing class ELV_SubscriptionStampService {

    // ── Configuration: which subscription product families map to which Quote fields ──

    /**
     * Each StampConfig entry defines:
     *   targetField   – the ELV_ field on Quote to write
     *   aggregation   – COUNT or MAX_END_DATE
     *   skuFilter     – product code prefix or exact match on the subscription product
     *   productFamily – optional broader family match (used when SKU filter is insufficient)
     */
    public class StampConfig {
        public String targetField;
        public String aggregation; // 'COUNT' or 'MAX_END_DATE'
        public List<String> skuPatterns;

        public StampConfig(String targetField, String aggregation, List<String> skuPatterns) {
            this.targetField = targetField;
            this.aggregation = aggregation;
            this.skuPatterns = skuPatterns;
        }
    }

    private static final List<StampConfig> CONFIGS = new List<StampConfig>{
        // Counts
        new StampConfig('ELV_SubCnt_AEM_Core_OnPrem_Sub__c', 'COUNT',
            new List<String>{ 'TAN-CORE-ONPREM', 'ELV-TAN-CORE-ONPREM' }),
        new StampConfig('ELV_SubCnt_AEM_Core_PlusStd_Sub__c', 'COUNT',
            new List<String>{ 'TAN-CORE-CLOUD-PLUS', 'TAN-CORE-CLOUD-STD', 'ELV-TAN-CORE-CLOUD-PLUS', 'ELV-TAN-CORE-CLOUD-STD' }),
        new StampConfig('ELV_SubCnt_Req_Provision_Cloud__c', 'COUNT',
            new List<String>{ 'TAN-DEPLOY-CLOUD', 'ELV-TAN-DEPLOY-CLOUD' }),
        new StampConfig('ELV_SubCnt_Req_Provision_GovCloud__c', 'COUNT',
            new List<String>{ 'TAN-DEPLOY-GOV-CLOUD', 'ELV-TAN-DEPLOY-GOV-CLOUD' }),
        new StampConfig('ELV_SubCnt_Req_Provision_Sub__c', 'COUNT',
            new List<String>{ 'TAN-DEPLOY-S', 'ELV-TAN-DEPLOY-S' }),
        new StampConfig('ELV_SubCount_TAN_CORE_OT_CLOUD__c', 'COUNT',
            new List<String>{ 'TAN-CORE-OT-CLOUD', 'ELV-TAN-CORE-OT-CLOUD' }),
        new StampConfig('ELV_SubCount_TAN_CORE_OT_S__c', 'COUNT',
            new List<String>{ 'TAN-CORE-OT-S', 'ELV-TAN-CORE-OT-S' }),
        new StampConfig('ELV_SubCount_Tanium_Threat_Response__c', 'COUNT',
            new List<String>{ 'TAN-THR', 'ELV-TAN-THR' }),

        // Max End Dates
        new StampConfig('ELV_SubMaxEndDate_CoreOT_Cloud__c', 'MAX_END_DATE',
            new List<String>{ 'TAN-CORE-OT-CLOUD', 'ELV-TAN-CORE-OT-CLOUD' }),
        new StampConfig('ELV_SubMaxEndDate_CoreOT_Subscription__c', 'MAX_END_DATE',
            new List<String>{ 'TAN-CORE-OT-S', 'ELV-TAN-CORE-OT-S' }),
        new StampConfig('ELV_SubMaxEnd_TAN_SUPP_EXT24x7__c', 'MAX_END_DATE',
            new List<String>{ 'TAN-SUPP-EXTENDED24X7', 'ELV-TAN-SUPP-EXTENDED24X7' }),
        new StampConfig('ELV_SubMaxEndDate_Threat_Resp__c', 'MAX_END_DATE',
            new List<String>{ 'TAN-THR', 'ELV-TAN-THR' })
    };

    /**
     * Main entry: stamp ELV_ fields on the given quotes.
     * Called from the Quote trigger (before insert / before update).
     */
    public static void stampSubscriptionFields(List<Quote> quotes) {
        if (!ELV_PricingControl.isActive() || quotes.isEmpty()) return;

        // Collect Account IDs from the quotes
        Set<Id> accountIds = new Set<Id>();
        for (Quote q : quotes) {
            if (q.AccountId != null) {
                accountIds.add(q.AccountId);
            }
        }
        if (accountIds.isEmpty()) return;

        // Query active subscriptions for those accounts
        // Ruby__Subscription__c is the Nue subscription object
        Map<Id, List<SObject>> subsByAccount = querySubscriptions(accountIds);

        // For each quote, aggregate and stamp
        for (Quote q : quotes) {
            List<SObject> subs = subsByAccount.get(q.AccountId);
            if (subs == null) subs = new List<SObject>();

            for (StampConfig cfg : CONFIGS) {
                Object result = aggregate(subs, cfg);
                q.put(cfg.targetField, result);
            }
        }
    }

    /** Query active subscriptions grouped by Account. */
    private static Map<Id, List<SObject>> querySubscriptions(Set<Id> accountIds) {
        Map<Id, List<SObject>> result = new Map<Id, List<SObject>>();

        String soql = 'SELECT Id, Ruby__Account__c, Ruby__Product__r.ProductCode, '
            + 'Ruby__EndDate__c, Ruby__Status__c '
            + 'FROM Ruby__Subscription__c '
            + 'WHERE Ruby__Account__c IN :accountIds '
            + 'AND Ruby__Status__c = \'Active\'';

        for (SObject sub : Database.query(soql)) {
            Id acctId = (Id) sub.get('Ruby__Account__c');
            if (!result.containsKey(acctId)) {
                result.put(acctId, new List<SObject>());
            }
            result.get(acctId).add(sub);
        }
        return result;
    }

    /** Aggregate subscriptions per config: COUNT or MAX_END_DATE. */
    private static Object aggregate(List<SObject> subs, StampConfig cfg) {
        Integer count = 0;
        Date maxDate = null;

        for (SObject sub : subs) {
            String productCode = (String) ELV_PricingAccess.getRelated(sub, 'Ruby__Product__r.ProductCode');
            if (productCode == null) continue;

            Boolean matches = false;
            for (String pattern : cfg.skuPatterns) {
                if (productCode.startsWithIgnoreCase(pattern)) {
                    matches = true;
                    break;
                }
            }
            if (!matches) continue;

            if (cfg.aggregation == 'COUNT') {
                count++;
            } else if (cfg.aggregation == 'MAX_END_DATE') {
                Date endDt = ELV_PricingAccess.toDate(sub.get('Ruby__EndDate__c'));
                if (endDt != null && (maxDate == null || endDt > maxDate)) {
                    maxDate = endDt;
                }
            }
        }

        return cfg.aggregation == 'COUNT' ? (Object) count : (Object) maxDate;
    }
}