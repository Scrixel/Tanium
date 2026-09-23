@IsTest
private class ELV_SalesARRStampTest {
    private static Quote quoteWith(Decimal rollup, Decimal arrAdjustment, Decimal inYear, Decimal marketplacePercent, Decimal referralFee, Decimal stored) {
        Map<String, Object> values = new Map<String, Object>{'attributes' => new Map<String, Object>{'type' => 'Quote'}, 'ELV_Day_1_ARR_Unadjusted_Rollup__c' => rollup, 'ELV_ARR_Adjustment__c' => arrAdjustment, 'ELV_In_Year_ARR_Adjustment__c' => inYear, 'ELV_Marketplace_ARR_Impact_Percent__c' => marketplacePercent, 'ELV_Partner_Referral_Fee_Dollars__c' => referralFee, 'ELV_Day_1_ARR__c' => stored};
        return (Quote) JSON.deserialize(JSON.serialize(values), Quote.class);
    }
    @IsTest static void aPlainQuoteIsItsUnadjustedRollup() {
        System.assertEquals(1000.00, ELV_SalesARRStampService.calculate(quoteWith(1000, null, null, null, null, null)));
    }
    @IsTest static void adjustmentsAddAndImpactsSubtract() {
        System.assertEquals(10355400.00, ELV_SalesARRStampService.calculate(quoteWith(10460000, 0, 0, 1, 0, null)));
        System.assertEquals(1051800.00, ELV_SalesARRStampService.calculate(quoteWith(1105000, -53200, 0, 0, 0, null)));
        System.assertEquals(393201.67, ELV_SalesARRStampService.calculate(quoteWith(508050, 0, -114848.33, 0, 0, null)));
    }
    @IsTest static void aQuoteWithNoRollupIsZero() {
        System.assertEquals(0, ELV_SalesARRStampService.calculate(quoteWith(null, 50000, 25000, 0, 0, null)));
    }
    @IsTest static void anAlreadyCorrectQuoteCostsNoUpdate() {
        List<Quote> updates = ELV_SalesARRStampService.buildUpdates(new List<Quote>{quoteWith(1000, 0, 0, 0, 0, 1000.00), quoteWith(1000, 500, 0, 0, 0, 1000.00)});
        System.assertEquals(1, updates.size()); System.assertEquals(1500.00, updates[0].ELV_Day_1_ARR__c);
    }
    @IsTest static void theStampIsSuppressedWhileItIsRunning() {
        ELV_SalesARRStampService.isStamping = true;
        Test.startTest(); ELV_SalesARRStampService.stampQuotes(new Set<Id>{UserInfo.getUserId()}); Test.stopTest();
        ELV_SalesARRStampService.isStamping = false;
    }
}