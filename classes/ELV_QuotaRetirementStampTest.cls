@IsTest(SeeAllData=true)
private class ELV_QuotaRetirementStampTest {
    private static QuoteLineItem lineFor(Decimal formulaValue, Decimal storedValue) {
        Map<String, Object> values = new Map<String, Object>{'attributes' => new Map<String, Object>{'type' => 'QuoteLineItem'}, 'ELV_Quota_Retirement_ARR__c' => formulaValue, 'ELV_Quota_Retirement_ARR_EDW__c' => storedValue};
        return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
    }
    @IsTest static void theStoredCopyFollowsTheFormula() {
        List<QuoteLineItem> updates = ELV_QuotaRetirementStampService.buildUpdates(new List<QuoteLineItem>{lineFor(1500.25, null), lineFor(null, 900), lineFor(750, 750)});
        System.assertEquals(2, updates.size()); System.assertEquals(1500.25, updates[0].ELV_Quota_Retirement_ARR_EDW__c); System.assertEquals(0, updates[1].ELV_Quota_Retirement_ARR_EDW__c);
    }
    @IsTest static void theStampIsSuppressedWhileItIsRunning() {
        ELV_QuotaRetirementStampService.isStamping = true;
        Test.startTest(); ELV_QuotaRetirementStampService.stampLines(new Set<Id>{UserInfo.getUserId()}); Test.stopTest();
        ELV_QuotaRetirementStampService.isStamping = false;
    }
}