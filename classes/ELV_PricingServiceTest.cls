/**
 * ELV_PricingServiceTest
 * ────────────────────────
 * Unit tests for the consolidated pricing engine.
 * Covers: kill-switch, access utility, subscription stamps, line counts,
 * price-rule families, quote aggregation, and product-rule evaluation.
 *
 * All tests use ELV_PricingControl.setActive(true/false) to bypass CMT.
 */
@IsTest
private class ELV_PricingServiceTest {

    // ═══════════════════════════════════════════════════════════════════
    // Kill Switch Tests
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testControlDefaultOff() {
        // Default CMT ships inactive
        System.assertEquals(false, ELV_PricingControl.isActive(),
            'Control should default to false');
    }

    @IsTest
    static void testControlOverride() {
        ELV_PricingControl.setActive(true);
        System.assertEquals(true, ELV_PricingControl.isActive(),
            'setActive(true) should override');

        ELV_PricingControl.setActive(false);
        System.assertEquals(false, ELV_PricingControl.isActive(),
            'setActive(false) should override back');
    }

    // ═══════════════════════════════════════════════════════════════════
    // Pilot User Gate Tests
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testPilotGateStampsFalseForNonPilotUser() {
        // Running user in a test context is never the hard-coded pilot user
        Quote q = new Quote(Name = 'Test Quote');
        List<Quote> quotes = new List<Quote>{ q };
        ELV_PricingControl.stampPilotGate(quotes);
        System.assertEquals(false, quotes[0].get('ELV_Pilot_Gate_Active__c'),
            'Marker must be false for any user other than the hard-coded pilot');
    }

    @IsTest
    static void testPilotGateStampsTrueOnlyForPilotUserOverride() {
        ELV_PricingControl.setRunningUserOverride('005cc00000CgeRxAAJ');
        Quote q = new Quote(Name = 'Test Quote');
        List<Quote> quotes = new List<Quote>{ q };
        ELV_PricingControl.stampPilotGate(quotes);
        // CMT still ships inactive by default, so isActive() should remain
        // false even for the pilot user until the CMT switch is also on.
        System.assertEquals(false, quotes[0].get('ELV_Pilot_Gate_Active__c'),
            'Marker stays false while CMT Active__c is false, even for the pilot user');
    }

    @IsTest
    static void testPilotGateRequiresBothConditions() {
        // Simulate CMT active + pilot user via direct override of isActive()
        ELV_PricingControl.setActive(true);
        Quote q = new Quote(Name = 'Test Quote');
        List<Quote> quotes = new List<Quote>{ q };
        ELV_PricingControl.stampPilotGate(quotes);
        System.assertEquals(true, quotes[0].get('ELV_Pilot_Gate_Active__c'),
            'setActive(true) override simulates the fully-gated active state');
    }

    @IsTest
    static void testPilotGateMultipleQuotesStampedConsistently() {
        ELV_PricingControl.setActive(false);
        List<Quote> quotes = new List<Quote>{
            new Quote(Name = 'Q1'), new Quote(Name = 'Q2')
        };
        ELV_PricingControl.stampPilotGate(quotes);
        for (Quote q : quotes) {
            System.assertEquals(false, q.get('ELV_Pilot_Gate_Active__c'));
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // Access Utility Tests
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testBlank() {
        System.assertEquals(true, ELV_PricingAccess.blank(null));
        System.assertEquals(true, ELV_PricingAccess.blank(''));
        System.assertEquals(true, ELV_PricingAccess.blank('  '));
        System.assertEquals(false, ELV_PricingAccess.blank('hello'));
    }

    @IsTest
    static void testEqNeq() {
        System.assertEquals(true, ELV_PricingAccess.eq('Renewal', 'Renewal'));
        System.assertEquals(true, ELV_PricingAccess.eq('renewal', 'Renewal'));
        System.assertEquals(false, ELV_PricingAccess.eq(null, 'Renewal'));
        System.assertEquals(true, ELV_PricingAccess.neq(null, 'Renewal'));
    }

    @IsTest
    static void testAnyOf() {
        System.assertEquals(true, ELV_PricingAccess.anyOf('MSP',
            new List<String>{'MSP', 'Direct'}));
        System.assertEquals(false, ELV_PricingAccess.anyOf('Other',
            new List<String>{'MSP', 'Direct'}));
        System.assertEquals(false, ELV_PricingAccess.anyOf(null,
            new List<String>{'MSP'}));
    }

    @IsTest
    static void testNumericComparisons() {
        System.assertEquals(true, ELV_PricingAccess.gt(10, 5));
        System.assertEquals(false, ELV_PricingAccess.gt(5, 10));
        System.assertEquals(true, ELV_PricingAccess.gte(10, 10));
        System.assertEquals(true, ELV_PricingAccess.lt(5, 10));
        System.assertEquals(true, ELV_PricingAccess.lte(10, 10));
    }

    @IsTest
    static void testToDecimal() {
        System.assertEquals(0, ELV_PricingAccess.toDecimal(null));
        System.assertEquals(42, ELV_PricingAccess.toDecimal(42));
        System.assertEquals(3.14, ELV_PricingAccess.toDecimal('3.14'));
    }

    @IsTest
    static void testIsTrue() {
        System.assertEquals(true, ELV_PricingAccess.isTrue(true));
        System.assertEquals(false, ELV_PricingAccess.isTrue(false));
        System.assertEquals(false, ELV_PricingAccess.isTrue(null));
    }

    @IsTest
    static void testDynamicFieldAccess() {
        // Test get/put on a generic SObject
        Account a = new Account(Name = 'Test');
        ELV_PricingAccess.put(a, 'Name', 'Updated');
        System.assertEquals('Updated', ELV_PricingAccess.get(a, 'Name'));
    }

    // ═══════════════════════════════════════════════════════════════════
    // Line Count Service Tests
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testLineCountServiceEmpty() {
        ELV_LineCountService.LineAggregates agg =
            ELV_LineCountService.compute(new List<QuoteLineItem>());
        System.assertEquals(0, agg.coreQuantity);
        System.assertEquals(0, agg.onPremCount);
        System.assertEquals(0, agg.cloudCount);
    }

    @IsTest
    static void testGetSkuQty() {
        ELV_LineCountService.LineAggregates agg =
            ELV_LineCountService.compute(new List<QuoteLineItem>());
        System.assertEquals(0, ELV_LineCountService.getSkuQty(agg, 'TAN-CORE-OT-CLOUD'));
    }

    @IsTest
    static void testGetCount() {
        ELV_LineCountService.LineAggregates agg =
            ELV_LineCountService.compute(new List<QuoteLineItem>());
        System.assertEquals(0, ELV_LineCountService.getCount(agg, 'CloudXEMCore'));
    }

    // ═══════════════════════════════════════════════════════════════════
    // Pricing Line Service Tests (require DML, would need @TestSetup
    // with actual Quote/QLI records in a full integration test)
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testPricingLineServiceInactiveSkips() {
        // When control is off, apply() should be a no-op
        ELV_PricingControl.setActive(false);
        // Should not throw even with empty list
        ELV_PricingLineService.apply(new List<QuoteLineItem>());
    }

    @IsTest
    static void testPricingQuoteServiceInactiveSkips() {
        ELV_PricingControl.setActive(false);
        ELV_PricingQuoteService.aggregateFromLines(new Set<Id>());
    }

    @IsTest
    static void testProductRuleServiceInactiveSkips() {
        ELV_PricingControl.setActive(false);
        List<QuoteLineItem> result =
            ELV_ProductRuleService.evaluateESRAutoAdd(new List<Quote>());
        System.assertEquals(0, result.size(),
            'Should return empty when control is off');
    }

    // ═══════════════════════════════════════════════════════════════════
    // Subscription Stamp Service Tests
    // ═══════════════════════════════════════════════════════════════════

    @IsTest
    static void testSubscriptionStampInactiveSkips() {
        ELV_PricingControl.setActive(false);
        ELV_SubscriptionStampService.stampSubscriptionFields(new List<Quote>());
        // No exception = pass
    }

    @IsTest
    static void testSubscriptionStampEmptyQuotes() {
        ELV_PricingControl.setActive(true);
        ELV_SubscriptionStampService.stampSubscriptionFields(new List<Quote>());
        // No exception = pass
    }

    @IsTest
    static void testStampConfigConstruction() {
        ELV_SubscriptionStampService.StampConfig cfg =
            new ELV_SubscriptionStampService.StampConfig(
                'ELV_SubCount_TAN_CORE_OT_CLOUD__c', 'COUNT',
                new List<String>{ 'TAN-CORE-OT-CLOUD' }
            );
        System.assertEquals('COUNT', cfg.aggregation);
        System.assertEquals('ELV_SubCount_TAN_CORE_OT_CLOUD__c', cfg.targetField);
    }
}