/**
 * ELV_PricingLineService
 * ────────────────────────
 * Consolidated price-rule execution for the 24 pricing families from
 * New_Rules.csv.  Runs in the QuoteLineItem before-insert / before-update
 * trigger context.  Each family is a private method.
 *
 * Field references use the standard Quote / QuoteLineItem object model with
 * ELV_ custom fields — no SBQQ__* compile-time dependencies.
 *
 * Key field mappings (SBQQ → Standard/ELV):
 *   SBQQ__StartDate__c            → ServiceDate (QLI) / ELV_Start_Date__c (Quote)
 *   SBQQ__EndDate__c              → ELV_End_Date__c
 *   SBQQ__SubscriptionTerm__c     → Ruby__ActualSubscriptionTerm__c
 *   SBQQ__ProductCode__c          → Product2.ProductCode / ELV_Product_Code__c
 *   SBQQ__Type__c (Quote)         → ELV_Quote_Type__c
 *   SBQQ__Discount__c             → Discount
 *   SBQQ__AdditionalDiscountAmount__c → Ruby__DiscountAmount__c
 *   SBQQ__DistributorDiscount__c  → ELV_Distributor_Discount__c
 *   SBQQ__PartnerDiscount__c      → ELV_Partner_Discount__c
 *   SBQQ__Hidden__c               → ELV_Hidden__c
 *   SBQQ__Bundle__c               → ELV_Is_Bundle__c
 *   SBQQ__RequiredBy__c           → ELV_Required_By__c (lookup to parent QLI)
 *   SBQQ__RenewedSubscription__c  → Ruby__ChangeReferenceQuoteLineItem__c
 *   SBQQ__UpgradedSubscription__c → ELV_Upgraded_Subscription__c
 *   Opportunity_Type__c (Quote)   → ELV_Opportunity_Type__c
 *   Business_Motion_Oppty__c      → ELV_Business_Motion__c
 *   Apply_Volume_Discount__c      → ELV_Apply_Volume_Discount__c
 *   Apply_Term_Discount__c        → ELV_Apply_Term_Discount__c
 *   Eligible_for_Distributor_Discount__c → ELV_Eligible_for_Distributor_Discount__c
 *   Marketplace_Partner__c        → ELV_Marketplace_Partner__c
 *   Disti_Discount_Percent__c     → ELV_Disti_Discount_Percent__c
 *   Disti_Renewal_Discount_Percent__c → ELV_Disti_Renewal_Discount_Percent__c
 *   Disti_Discount_Percent_Marketplace__c → ELV_Disti_Discount_Percent_Marketplace__c
 *   Product_Line__c               → ELV_Product_Line__c
 *   Product_Group__c              → ELV_Product_Group__c
 *   Bundled_Product__c            → ELV_Bundled_Product__c
 *   Transaction_Type__c           → ELV_Transaction_Type__c
 *   Show_on_Invoice__c            → ELV_Show_on_Invoice__c
 *   Distribution_Involvement_Discount__c → ELV_Distribution_Involvement_Discount__c
 *   Standard_Partner_Discount__c  → ELV_Standard_Partner_Discount__c
 *   Advantage_Plus_Partner_Discount__c → ELV_Advantage_Plus_Partner_Discount__c
 *   Opportunity_Registration_Discount__c → ELV_Opportunity_Registration_Discount__c
 *   Partner_Discretionary_Discount__c → ELV_Partner_Discretionary_Discount__c
 */
public with sharing class ELV_PricingLineService {

    // ── Quote fields queried for pricing context ─────────────────────────
    private static final String QUOTE_FIELDS =
        'Id, ELV_Start_Date__c, ELV_End_Date__c, Ruby__ActualSubscriptionTerm__c, '
        + 'ELV_Quote_Type__c, ELV_Opportunity_Type__c, ELV_Business_Motion__c, '
        + 'ELV_Apply_Volume_Discount__c, ELV_Apply_Term_Discount__c, '
        + 'ELV_Eligible_for_Distributor_Discount__c, ELV_Marketplace_Partner__c, '
        + 'ELV_Disti_Discount_Percent__c, ELV_Disti_Renewal_Discount_Percent__c, '
        + 'ELV_Disti_Discount_Percent_Marketplace__c';

    // ── Parent QLI fields queried for bundle propagation ─────────────────
    private static final String PARENT_FIELDS =
        'Id, ServiceDate, ELV_End_Date__c, Ruby__ActualSubscriptionTerm__c, '
        + 'Discount, Ruby__DiscountAmount__c, ELV_Partner_Discount__c, '
        + 'ELV_Transaction_Type__c, ELV_Standard_Partner_Discount__c, '
        + 'ELV_Distribution_Involvement_Discount__c, '
        + 'ELV_Advantage_Plus_Partner_Discount__c, '
        + 'ELV_Opportunity_Registration_Discount__c, '
        + 'ELV_Partner_Discretionary_Discount__c';

    /**
     * Main entry point — called from QuoteLineItem before trigger.
     */
    public static void apply(List<QuoteLineItem> lines) {
        if (!ELV_PricingControl.isActive() || lines.isEmpty()) return;

        // ── Collect parent IDs ───────────────────────────────────────────
        Set<Id> quoteIds  = new Set<Id>();
        Set<Id> parentIds = new Set<Id>();

        for (QuoteLineItem li : lines) {
            if (li.QuoteId != null) quoteIds.add(li.QuoteId);
            Id parentId = (Id) li.get('ELV_Required_By__c');
            if (parentId != null) parentIds.add(parentId);
        }

        // ── Query quote context ──────────────────────────────────────────
        Map<Id, SObject> quotes = new Map<Id, SObject>();
        if (!quoteIds.isEmpty()) {
            for (SObject q : Database.query(
                'SELECT ' + QUOTE_FIELDS + ' FROM Quote WHERE Id IN :quoteIds'
            )) {
                quotes.put((Id) q.get('Id'), q);
            }
        }

        // ── Query parent QLI context for bundle propagation ──────────────
        Map<Id, SObject> parents = new Map<Id, SObject>();
        if (!parentIds.isEmpty()) {
            for (SObject p : Database.query(
                'SELECT ' + PARENT_FIELDS + ' FROM QuoteLineItem WHERE Id IN :parentIds'
            )) {
                parents.put((Id) p.get('Id'), p);
            }
        }

        // ── Apply each pricing family in order ───────────────────────────
        for (QuoteLineItem li : lines) {
            SObject q = quotes.get(li.QuoteId);
            if (q == null) continue;

            Id parentId = (Id) li.get('ELV_Required_By__c');
            SObject parent = parentId != null ? parents.get(parentId) : null;

            applyDateDefaults(li, q);           // Rules #2, #4
            applySubscriptionTerm(li, q);       // Rules #5, #6, #7
            applyScheduleClears(li, q);         // Rules #17, #41
            applyDistributorDiscount(li, q);    // Rules #18, #39, #69, #72
            applyBundlePropagation(li, q, parent); // Rules #65, #68, #85
            applyTransactionType(li, q);        // Rules #104, #106, #107, #109
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Family: Date Defaults (Rules #2, #4)
    // ────────────────────────────────────────────────────────────────────
    // #2: If QL End Date blank and Quote End Date not blank → copy Quote End Date
    // #4: If QL Start Date blank and Quote Start Date not blank → copy Quote Start Date
    // ════════════════════════════════════════════════════════════════════
    private static void applyDateDefaults(QuoteLineItem li, SObject q) {
        // Rule #4: Start Date default
        if (ELV_PricingAccess.blank(li.ServiceDate)
            && !ELV_PricingAccess.blank(q.get('ELV_Start_Date__c'))) {
            li.ServiceDate = ELV_PricingAccess.toDate(q.get('ELV_Start_Date__c'));
        }

        // Rule #2: End Date default
        if (ELV_PricingAccess.blank(li.get('ELV_End_Date__c'))
            && !ELV_PricingAccess.blank(q.get('ELV_End_Date__c'))) {
            li.put('ELV_End_Date__c', q.get('ELV_End_Date__c'));
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Family: Subscription Term Defaults (Rules #5, #6, #7)
    // ────────────────────────────────────────────────────────────────────
    // #5: QL ProductCode = TAN-ESR-DEPLMT-EE → set term to 12
    // #6: QL Product_Line = Training AND Quote term not blank AND QL term blank → 12
    // #7: QL term blank AND Quote term not blank AND not Training →
    //     IF(ProductCode = TAN-PREM-ESR-1D/W, 2, Quote.term)
    // ════════════════════════════════════════════════════════════════════
    private static void applySubscriptionTerm(QuoteLineItem li, SObject q) {
        String sku = (String) li.get('ELV_Product_Code__c');
        Decimal qlTerm = ELV_PricingAccess.toDecimal(li.get('Ruby__ActualSubscriptionTerm__c'));
        Decimal qTerm  = ELV_PricingAccess.toDecimal(q.get('Ruby__ActualSubscriptionTerm__c'));
        String productLine = (String) li.get('ELV_Product_Line__c');

        // Rule #5: Deployment SKU hard-coded to 12
        if (sku != null && sku.equalsIgnoreCase('TAN-ESR-DEPLMT-EE')) {
            li.put('Ruby__ActualSubscriptionTerm__c', 12);
            return;
        }

        // Rule #6: Training lines default to 12 when quote term exists
        if (ELV_PricingAccess.blank(li.get('Ruby__ActualSubscriptionTerm__c'))
            && productLine != null && productLine.equalsIgnoreCase('Training')
            && !ELV_PricingAccess.blank(q.get('Ruby__ActualSubscriptionTerm__c'))) {
            li.put('Ruby__ActualSubscriptionTerm__c', 12);
            return;
        }

        // Rule #7: General term default from quote (with TAN-PREM-ESR-1D/W override)
        if (ELV_PricingAccess.blank(li.get('Ruby__ActualSubscriptionTerm__c'))
            && !ELV_PricingAccess.blank(q.get('Ruby__ActualSubscriptionTerm__c'))
            && (productLine == null || !productLine.equalsIgnoreCase('Training'))) {
            if (sku != null && sku.equalsIgnoreCase('TAN-PREM-ESR-1D/W')) {
                li.put('Ruby__ActualSubscriptionTerm__c', 2);
            } else {
                li.put('Ruby__ActualSubscriptionTerm__c', q.get('Ruby__ActualSubscriptionTerm__c'));
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Family: Schedule Clears (Rules #17, #41)
    // ────────────────────────────────────────────────────────────────────
    // #17: If Quote.Apply_Term_Discount = false AND Apply_Volume_Discount = false
    //      → clear TermDiscountSchedule and TermDiscountTier
    // #41: If Quote.Apply_Volume_Discount = false
    //      → clear DiscountSchedule and DiscountTier
    // ════════════════════════════════════════════════════════════════════
    private static void applyScheduleClears(QuoteLineItem li, SObject q) {
        Boolean volOff  = ELV_PricingAccess.isFalse(q.get('ELV_Apply_Volume_Discount__c'));
        Boolean termOff = ELV_PricingAccess.isFalse(q.get('ELV_Apply_Term_Discount__c'));

        // Rule #17: Both off → clear term discount schedule
        if (volOff && termOff) {
            li.put('ELV_Term_Discount_Schedule__c', null);
            li.put('ELV_Term_Discount_Tier__c', null);
        }

        // Rule #41: Volume off → clear volume discount schedule
        if (volOff) {
            li.put('ELV_Discount_Schedule__c', null);
            li.put('ELV_Discount_Tier__c', null);
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Family: Distributor Discount (Rules #18, #39, #69, #72)
    // ────────────────────────────────────────────────────────────────────
    // Only applies to Product_Group = Software.
    // #72: Marketplace_Partner = true → Disti % = Marketplace %,
    //      Distribution_Involvement = true
    // #69: Eligible + not Marketplace → Disti % = (Renewal? Renewal% : Standard%),
    //      Distribution_Involvement = true
    // #18/#39: Not Eligible → clear Disti %, Distribution_Involvement = false
    // ════════════════════════════════════════════════════════════════════
    private static void applyDistributorDiscount(QuoteLineItem li, SObject q) {
        String pg = (String) li.get('ELV_Product_Group__c');
        if (pg == null || !pg.equalsIgnoreCase('Software')) return;

        Boolean marketplace = ELV_PricingAccess.isTrue(q.get('ELV_Marketplace_Partner__c'));
        Boolean eligible    = ELV_PricingAccess.isTrue(q.get('ELV_Eligible_for_Distributor_Discount__c'));
        String  quoteType   = (String) q.get('ELV_Quote_Type__c');

        if (marketplace) {
            li.put('ELV_Distributor_Discount__c', q.get('ELV_Disti_Discount_Percent_Marketplace__c'));
            li.put('ELV_Distribution_Involvement_Discount__c', true);
        } else if (eligible) {
            Object pct = (quoteType != null && quoteType.equalsIgnoreCase('Renewal'))
                ? q.get('ELV_Disti_Renewal_Discount_Percent__c')
                : q.get('ELV_Disti_Discount_Percent__c');
            li.put('ELV_Distributor_Discount__c', pct);
            li.put('ELV_Distribution_Involvement_Discount__c', true);
        } else {
            li.put('ELV_Distributor_Discount__c', null);
            li.put('ELV_Distribution_Involvement_Discount__c', false);
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Family: Bundle Propagation (Rules #65, #68, #85)
    // ────────────────────────────────────────────────────────────────────
    // #65: Bundled_Product = true → copy parent discount fields, hide, copy dates/type
    // #68: Bundle parent → copy AdditionalDiscountAmount from parent
    // #85: Bundle parent → copy Discount % from parent
    // ════════════════════════════════════════════════════════════════════
    private static void applyBundlePropagation(QuoteLineItem li, SObject q, SObject parent) {
        if (parent == null) return;

        Boolean isBundled = ELV_PricingAccess.isTrue(li.get('ELV_Bundled_Product__c'));
        Boolean isBundle  = ELV_PricingAccess.isTrue(li.get('ELV_Is_Bundle__c'));

        // Rule #65: Component propagation
        if (isBundled) {
            // Copy discount fields from direct parent
            for (String f : new List<String>{
                'ELV_Standard_Partner_Discount__c',
                'ELV_Distribution_Involvement_Discount__c',
                'ELV_Advantage_Plus_Partner_Discount__c',
                'ELV_Partner_Discretionary_Discount__c',
                'ELV_Opportunity_Registration_Discount__c',
                'ELV_Partner_Discount__c',
                'Ruby__ActualSubscriptionTerm__c'
            }) {
                li.put(f, parent.get(f));
            }

            // Hide component and copy dates/type
            li.put('ELV_Hidden__c', true);
            li.put('ELV_Show_on_Invoice__c', false);
            li.ServiceDate = ELV_PricingAccess.toDate(parent.get('ServiceDate'));
            li.put('ELV_End_Date__c', parent.get('ELV_End_Date__c'));
            li.put('ELV_Transaction_Type__c', parent.get('ELV_Transaction_Type__c'));
        }

        // Rules #68, #85: Bundle-parent propagation (discount amount and %)
        if (isBundle) {
            li.put('Ruby__DiscountAmount__c', parent.get('Ruby__DiscountAmount__c'));
            li.Discount = (Decimal) parent.get('Discount');
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Family: Transaction Type Classification (Rules #104, #106, #107, #109)
    // ────────────────────────────────────────────────────────────────────
    // #104: Opportunity_Type = Renewal AND has RenewedSubscription → 'Renewal'
    // #106: Opportunity_Type in (New Customer, New MSP End User) → 'New Customer'
    // #107: Quote_Type = Amendment AND has UpgradedSubscription → 'Add-on'
    // #109: Quote_Type = Amendment AND no UpgradedSubscription → 'Upsell'
    // ════════════════════════════════════════════════════════════════════
    private static void applyTransactionType(QuoteLineItem li, SObject q) {
        String oppType   = (String) q.get('ELV_Opportunity_Type__c');
        String quoteType = (String) q.get('ELV_Quote_Type__c');

        // Rule #104: Renewal
        if (oppType != null && oppType.equalsIgnoreCase('Renewal')
            && !ELV_PricingAccess.blank(li.get('Ruby__ChangeReferenceQuoteLineItem__c'))) {
            li.put('ELV_Transaction_Type__c', 'Renewal');
            return;
        }

        // Rule #106: New Customer
        if (oppType != null
            && (oppType.equalsIgnoreCase('New Customer') || oppType.equalsIgnoreCase('New MSP End User'))) {
            li.put('ELV_Transaction_Type__c', 'New Customer');
            return;
        }

        // Rule #107: Add-on (Amendment with upgraded subscription)
        if (quoteType != null && quoteType.equalsIgnoreCase('Amendment')
            && !ELV_PricingAccess.blank(li.get('ELV_Upgraded_Subscription__c'))) {
            li.put('ELV_Transaction_Type__c', 'Add-on');
            return;
        }

        // Rule #109: Upsell (Amendment without upgraded subscription)
        if (quoteType != null && quoteType.equalsIgnoreCase('Amendment')
            && ELV_PricingAccess.blank(li.get('ELV_Upgraded_Subscription__c'))) {
            li.put('ELV_Transaction_Type__c', 'Upsell');
            return;
        }
    }
}
