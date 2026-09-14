@IsTest
private class ELV_OriginalRenewalUpliftServiceTest {
    @IsTest static void appliesLowestPopulatedCap() {
        System.assertEquals(5.2, ELV_OriginalRenewalUpliftService.resolveEffectiveRate(7, 5.2, null));
        System.assertEquals(4.5, ELV_OriginalRenewalUpliftService.resolveEffectiveRate(7, null, 4.5));
        System.assertEquals(4.5, ELV_OriginalRenewalUpliftService.resolveEffectiveRate(7, 5.2, 4.5));
    }
    @IsTest static void preservesExplicitZeroCap() {
        System.assertEquals(0, ELV_OriginalRenewalUpliftService.resolveEffectiveRate(7, 0, null));
        System.assertEquals(0, ELV_OriginalRenewalUpliftService.resolveEffectiveRate(7, null, 0));
    }
    @IsTest static void blankCapUsesPolicyRate() {
        System.assertEquals(7, ELV_OriginalRenewalUpliftService.resolveEffectiveRate(7, null, null));
    }
    @IsTest static void normalizesMetadataKeyAndFallsBackToUndetermined() {
        System.assertEquals('Enterprise', ELV_OriginalRenewalUpliftService.policyKey('Enterprise'));
        System.assertEquals('Small_Business', ELV_OriginalRenewalUpliftService.policyKey('Small Business'));
        System.assertEquals('Undetermined', ELV_OriginalRenewalUpliftService.policyKey(null));
        System.assertEquals('Undetermined', ELV_OriginalRenewalUpliftService.policyKey(''));
    }
    @IsTest(SeeAllData=true) static void overrideTruePreventsAutomaticStamp() {
        Quote quoteRecord = [SELECT Id FROM Quote WHERE Id = '0Q0cc000002ZoOzCAK' LIMIT 1];
        QuoteLineItem overriddenLine = new QuoteLineItem(
            QuoteId = quoteRecord.Id, Ruby__LineType__c = 'LineItem',
            ELV_Renewal_Uplift_Override__c = true, Ruby__RenewalUpliftPercent__c = 9.9
        );
        Test.startTest();
        ELV_OriginalRenewalUpliftService.stamp(new List<QuoteLineItem>{overriddenLine});
        Test.stopTest();
        System.assertEquals(9.9, overriddenLine.Ruby__RenewalUpliftPercent__c, 'Override must be preserved.');
    }
}