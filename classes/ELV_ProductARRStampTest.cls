@IsTest(SeeAllData=true)
private class ELV_ProductARRStampTest {
    private static QuoteLineItem lineFor(Id productId) {
        Map<String, Object> values = new Map<String, Object>{'attributes' => new Map<String, Object>{'type' => 'QuoteLineItem'}, 'Product2Id' => productId};
        return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
    }
    private static Product2 findProduct(Boolean excluded) {
        for (Product2 product : [SELECT Id, Exclude_from_ARR__c FROM Product2 WHERE Exclude_from_ARR__c = :excluded LIMIT 1]) return product;
        return null;
    }
    @IsTest static void anExcludedProductStampsTrueAndAnIncludedProductStampsFalse() {
        Product2 excluded = findProduct(true), included = findProduct(false);
        if (excluded == null || included == null) return;
        List<QuoteLineItem> lines = new List<QuoteLineItem>{lineFor(excluded.Id), lineFor(included.Id)};
        Test.startTest(); ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(lines, null); Test.stopTest();
        System.assertEquals(true, lines[0].ELV_Product_Exclude_from_ARR__c);
        System.assertEquals(false, lines[1].ELV_Product_Exclude_from_ARR__c);
    }
    @IsTest static void reparentingTheLineRestampsItAndAnUnchangedProductDoesNot() {
        Product2 excluded = findProduct(true), included = findProduct(false);
        if (excluded == null || included == null) return;
        Id lineId = '0QL000000000001AAA';
        QuoteLineItem reparented = lineFor(excluded.Id); reparented.Id = lineId; reparented.ELV_Product_Exclude_from_ARR__c = false;
        QuoteLineItem oldLine = lineFor(included.Id); oldLine.Id = lineId; oldLine.ELV_Product_Exclude_from_ARR__c = false;
        Test.startTest(); ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(new List<QuoteLineItem>{reparented}, new Map<Id, QuoteLineItem>{lineId => oldLine}); Test.stopTest();
        System.assertEquals(true, reparented.ELV_Product_Exclude_from_ARR__c);
    }
    @IsTest static void onlyAChangedExclusionFlagSelectsAProduct() {
        Id movedId = '01t000000000011AAA', staticId = '01t000000000012AAA';
        Set<Id> changed = ELV_ProductARRStampService.getProductsWithChangedExclusion(new List<Product2>{new Product2(Id=movedId, Exclude_from_ARR__c=true), new Product2(Id=staticId, Exclude_from_ARR__c=true)}, new Map<Id, Product2>{movedId => new Product2(Id=movedId, Exclude_from_ARR__c=false), staticId => new Product2(Id=staticId, Exclude_from_ARR__c=true)});
        System.assertEquals(1, changed.size()); System.assert(changed.contains(movedId));
    }
    @IsTest static void restampIsANoOpWithoutProducts() {
        Test.startTest(); Integer updated = ELV_ProductARRStampService.restampLines(new Set<Id>()); Test.stopTest();
        System.assertEquals(0, updated);
    }
}