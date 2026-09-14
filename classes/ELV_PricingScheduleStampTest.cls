@IsTest
private class ELV_PricingScheduleStampTest {
    @IsTest static void utilityMirrorsLookupPresence() {
        QuoteLineItem blankLine = new QuoteLineItem();
        QuoteLineItem populatedLine = new QuoteLineItem(ELV_Tanium_Pricing_Schedule__c='a5L000000000001AAA');
        ELV_QuoteLineTriggerUtility.stampHasTaniumPricingSchedule(new List<QuoteLineItem>{blankLine,populatedLine});
        System.assertEquals(false, blankLine.ELV_Has_Tanium_Pricing_Schedule__c);
        System.assertEquals(true, populatedLine.ELV_Has_Tanium_Pricing_Schedule__c);
        ELV_QuoteLineTriggerUtility.stampHasTaniumPricingSchedule(null);
    }

    @IsTest static void renewalStampUsesContainsRenew() {
        List<QuoteLineItem> lines=new List<QuoteLineItem>{new QuoteLineItem(Ruby__ChangeType__c='Renew'),new QuoteLineItem(Ruby__ChangeType__c='RenewWithQuantityUpdate'),new QuoteLineItem(Ruby__ChangeType__c='NewProduct'),new QuoteLineItem()};
        ELV_QuoteLineTriggerUtility.stampIsRenewalTransaction(lines);
        System.assertEquals(true,lines[0].ELV_Is_Renewal_Transaction__c); System.assertEquals(true,lines[1].ELV_Is_Renewal_Transaction__c); System.assertEquals(false,lines[2].ELV_Is_Renewal_Transaction__c); System.assertEquals(false,lines[3].ELV_Is_Renewal_Transaction__c);
        ELV_QuoteLineTriggerUtility.stampIsRenewalTransaction(null);
    }
}