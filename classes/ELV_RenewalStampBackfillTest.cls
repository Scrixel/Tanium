@IsTest
private class ELV_RenewalStampBackfillTest {
    private static QuoteLineItem lineFor(String changeType, Boolean stamped) {
        Map<String, Object> values = new Map<String, Object>{'attributes' => new Map<String, Object>{'type' => 'QuoteLineItem'}, 'Ruby__ChangeType__c' => changeType, 'ELV_Is_Renewal_Transaction__c' => stamped};
        return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
    }
    @IsTest static void theStampFollowsTheContainsRenewRule() {
        List<QuoteLineItem> lines = new List<QuoteLineItem>{lineFor('Renew', false), lineFor('RenewWithQuantityUpdate', false), lineFor('NewProduct', false), lineFor(null, false)};
        Test.startTest(); ELV_QuoteLineTriggerUtility.stampIsRenewalTransaction(lines); Test.stopTest();
        System.assertEquals(true, lines[0].ELV_Is_Renewal_Transaction__c); System.assertEquals(true, lines[1].ELV_Is_Renewal_Transaction__c); System.assertEquals(false, lines[2].ELV_Is_Renewal_Transaction__c); System.assertEquals(false, lines[3].ELV_Is_Renewal_Transaction__c);
    }
}