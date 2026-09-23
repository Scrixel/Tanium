@IsTest
private class ELV_OpportunitySubscriptionServiceTest {
    @IsTest static void termAlignmentHonoursToleranceAndBlanks() {
        Date endDate = Date.newInstance(2026, 8, 20);
        System.assertEquals(true,
            ELV_OpportunitySubscriptionService.isTermAligned(endDate.addDays(15), endDate));
        System.assertEquals(true,
            ELV_OpportunitySubscriptionService.isTermAligned(endDate.addDays(1), endDate));
        System.assertEquals(false,
            ELV_OpportunitySubscriptionService.isTermAligned(endDate.addDays(16), endDate));
        System.assertEquals(true,
            ELV_OpportunitySubscriptionService.isTermAligned(null, endDate));
        System.assertEquals(true,
            ELV_OpportunitySubscriptionService.isTermAligned(endDate, null));
    }

    @IsTest static void emptySynchroniseIsNoOp() {
        Test.startTest();
        ELV_OpportunitySubscriptionService.synchronise(null);
        ELV_OpportunitySubscriptionService.synchronise(new Set<Id>());
        Test.stopTest();
        System.assertEquals(0, [SELECT count() FROM Ruby__OpportunitySubscription__c]);
    }

    @IsTest static void junctionUtilityCollectsBothSides() {
        Id firstOpp = Id.valueOf('006000000000001');
        Id secondOpp = Id.valueOf('006000000000002');
        List<Ruby__OpportunitySubscription__c> rows = new List<Ruby__OpportunitySubscription__c>{
            new Ruby__OpportunitySubscription__c(Ruby__Opportunity__c = firstOpp),
            new Ruby__OpportunitySubscription__c(Ruby__Opportunity__c = secondOpp),
            new Ruby__OpportunitySubscription__c()
        };
        Set<Id> ids = ELV_OppSubTriggerUtility.opportunityIds(rows);
        System.assertEquals(new Set<Id>{firstOpp, secondOpp}, ids);
    }
}