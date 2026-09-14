/** TNCI-135 / ELV-CPQ-068 — Account classification policy tests. */
@IsTest(SeeAllData=true)
private class ELV_RenewalUpliftQuotePolicyTest {
    private static Quote createQuote(Id accountId, String billTo, String shipTo, Id partnerId, Id distributorId) {
        String payload = '{"AccountId":"' + accountId + '",'
            + '"ELV_Bill_To_Country__c":"' + billTo + '",'
            + '"ELV_Ship_To_Country__c":"' + shipTo + '",'
            + '"ELV_Partner__c":"' + partnerId + '",'
            + '"ELV_Distributor__c":"' + distributorId + '"}';
        return (Quote) JSON.deserialize(payload.replace('"null"', 'null'), Quote.class);
    }

    @IsTest static void excludesWhenSectorContainsFederal() {
        Account accountRecord = new Account(Name = 'ELV Federal Policy Test', Sector__c = 'Federal - Civilian');
        insert accountRecord;
        Quote quoteRecord = createQuote(accountRecord.Id, 'United States', null, null, null);
        Test.startTest(); ELV_RenewalUpliftQuotePolicy.apply(new List<Quote>{quoteRecord}); Test.stopTest();
        System.assertEquals(true, quoteRecord.ELV_Exclude_Uplift__c);
        System.assertEquals('Direct', quoteRecord.ELV_Uplift_Route_To_Market__c);
    }

    @IsTest static void excludesWhenRegionContainsJapan() {
        Account accountRecord = [SELECT Id FROM Account WHERE Region__c LIKE '%Japan%' LIMIT 1];
        Quote quoteRecord = createQuote(accountRecord.Id, 'United States', null, null, null);
        Test.startTest(); ELV_RenewalUpliftQuotePolicy.apply(new List<Quote>{quoteRecord}); Test.stopTest();
        System.assertEquals(true, quoteRecord.ELV_Exclude_Uplift__c);
    }

    @IsTest static void addressValuesDoNotDetermineExclusion() {
        Account accountRecord = new Account(Name = 'ELV Commercial Policy Test', Sector__c = 'Commercial');
        insert accountRecord;
        Quote quoteRecord = createQuote(accountRecord.Id, 'Japan', 'Japan', null, null);
        Test.startTest(); ELV_RenewalUpliftQuotePolicy.apply(new List<Quote>{quoteRecord}); Test.stopTest();
        System.assertEquals(false, quoteRecord.ELV_Exclude_Uplift__c);
    }

    @IsTest static void preservesPartnerAndDistributorRoutes() {
        Account customer = new Account(Name = 'ELV Customer Policy Test', Sector__c = 'Commercial');
        Account partner = new Account(Name = 'ELV Partner Policy Test');
        Account distributor = new Account(Name = 'ELV Distributor Policy Test');
        insert new List<Account>{customer, partner, distributor};
        Quote partnerQuote = createQuote(customer.Id, null, null, partner.Id, null);
        Quote distributorQuote = createQuote(customer.Id, null, null, null, distributor.Id);
        Test.startTest(); ELV_RenewalUpliftQuotePolicy.apply(new List<Quote>{partnerQuote, distributorQuote}); Test.stopTest();
        System.assertEquals('Partner/Resale', partnerQuote.ELV_Uplift_Route_To_Market__c);
        System.assertEquals('Distributor', distributorQuote.ELV_Uplift_Route_To_Market__c);
        System.assertEquals(false, partnerQuote.ELV_Exclude_Uplift__c);
        System.assertEquals(false, distributorQuote.ELV_Exclude_Uplift__c);
    }
}