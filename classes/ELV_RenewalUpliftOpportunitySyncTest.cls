@IsTest(SeeAllData=true)
private class ELV_RenewalUpliftOpportunitySyncTest {
    @IsTest static void synchronizesPrimaryQuoteForCapChangeAndClear() {
        Quote quoteRecord = [SELECT Id, OpportunityId FROM Quote WHERE Id = '0Q0cc000002jygPCAQ' LIMIT 1];
        Opportunity opportunityRecord = [SELECT Id, Ruby__PrimaryQuote__c, ELV_Contracted_Renewal_Uplift_Percent__c FROM Opportunity WHERE Id = :quoteRecord.OpportunityId];
        opportunityRecord.Ruby__PrimaryQuote__c = quoteRecord.Id;
        opportunityRecord.ELV_Contracted_Renewal_Uplift_Percent__c = 4.0;
        Test.startTest();
        update opportunityRecord;
        Test.stopTest();
        System.assertEquals(4.0, [SELECT ELV_Contracted_Renewal_Uplift_Percent__c FROM Quote WHERE Id = :quoteRecord.Id].ELV_Contracted_Renewal_Uplift_Percent__c);
        opportunityRecord.ELV_Contracted_Renewal_Uplift_Percent__c = null;
        update opportunityRecord;
        System.assertEquals(null, [SELECT ELV_Contracted_Renewal_Uplift_Percent__c FROM Quote WHERE Id = :quoteRecord.Id].ELV_Contracted_Renewal_Uplift_Percent__c);
    }
}