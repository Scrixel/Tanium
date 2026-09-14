/** Integration coverage for TNCI-139 / ELV-CPQ-036 against Build data; all DML rolls back. */
@IsTest(SeeAllData=true)
private class ELV_OppSubIntegrationTest {
    @IsTest static void synchroniseRealOpenRenewalSubscriptionsAndAggregate() {
        List<Ruby__Subscription__c> candidates = [
            SELECT Id, Ruby__RenewalOpportunity__c
            FROM Ruby__Subscription__c
            WHERE Ruby__RenewalOpportunity__c != null
              AND Ruby__RenewalOpportunity__r.IsClosed = false
            LIMIT 20
        ];
        if (candidates.isEmpty()) return;

        Set<Id> subscriptionIds = new Map<Id, Ruby__Subscription__c>(candidates).keySet();
        Set<Id> opportunityIds = new Set<Id>();
        for (Ruby__Subscription__c sub : candidates) opportunityIds.add(sub.Ruby__RenewalOpportunity__c);

        Test.startTest();
        ELV_OpportunitySubscriptionService.synchronise(subscriptionIds);
        ELV_OpportunityARRService.recalculate(opportunityIds);
        Test.stopTest();

        List<Ruby__OpportunitySubscription__c> rows = [
            SELECT Id, Ruby__Subscription__c, Ruby__Opportunity__c, ELV_External_Id__c,
                   ELV_ARR_Amount__c, ELV_Order_Product_Count__c, ELV_Include_in_ARR__c
            FROM Ruby__OpportunitySubscription__c
            WHERE Ruby__Subscription__c IN :subscriptionIds
        ];
        System.assert(!rows.isEmpty(), 'Open renewal subscriptions create auditable junction rows.');
        for (Ruby__OpportunitySubscription__c row : rows) {
            System.assertEquals(String.valueOf(row.Ruby__Subscription__c) + '-' +
                String.valueOf(row.Ruby__Opportunity__c), row.ELV_External_Id__c);
            System.assertNotEquals(null, row.ELV_ARR_Amount__c);
            System.assertNotEquals(null, row.ELV_Order_Product_Count__c);
        }
    }

    @IsTest static void upstreamAndJunctionTriggersExecute() {
        List<Ruby__Subscription__c> subs = [
            SELECT Id, Ruby__RenewalOpportunity__c, Ruby__CancellationDate__c
            FROM Ruby__Subscription__c
            WHERE Ruby__RenewalOpportunity__c != null
              AND Ruby__RenewalOpportunity__r.IsClosed = false
            LIMIT 1
        ];
        if (subs.isEmpty()) return;
        Ruby__Subscription__c sub = subs[0];
        ELV_OpportunitySubscriptionService.synchronise(new Set<Id>{sub.Id});

        Test.startTest();
        update new Ruby__Subscription__c(Id=sub.Id, Ruby__CancellationDate__c=sub.Ruby__CancellationDate__c);

        List<Ruby__AssetOrderProduct__c> joins = [
            SELECT Id, Ruby__Subscription__c FROM Ruby__AssetOrderProduct__c
            WHERE Ruby__Subscription__c = :sub.Id LIMIT 1
        ];
        if (!joins.isEmpty()) update new Ruby__AssetOrderProduct__c(
            Id=joins[0].Id, Ruby__Subscription__c=joins[0].Ruby__Subscription__c
        );

        List<OrderItem> items = [
            SELECT Id, Description FROM OrderItem WHERE Id IN
              (SELECT Ruby__OrderProduct__c FROM Ruby__AssetOrderProduct__c
               WHERE Ruby__Subscription__c = :sub.Id) LIMIT 1
        ];
        if (!items.isEmpty()) update new OrderItem(Id=items[0].Id, Description=items[0].Description);

        Ruby__OpportunitySubscription__c row = [
            SELECT Id, ELV_ARR_Last_Stamped__c FROM Ruby__OpportunitySubscription__c
            WHERE Ruby__Subscription__c = :sub.Id LIMIT 1
        ];
        row.ELV_ARR_Last_Stamped__c = System.now();
        update row;
        Test.stopTest();
    }

    @IsTest static void entryUtilitiesCoverChangedAndOldRelationships() {
        Id subId = Id.valueOf('aKq000000000001');
        Id oppA = Id.valueOf('006000000000001');
        Id oppB = Id.valueOf('006000000000002');
        Ruby__Subscription__c beforeSub = new Ruby__Subscription__c(Id=subId, Ruby__Status__c='Draft');
        Ruby__Subscription__c afterSub = new Ruby__Subscription__c(Id=subId, Ruby__Status__c='Active');
        System.assertEquals(new Set<Id>{subId},
            ELV_OpportunitySubscriptionEntryUtility.changedSubscriptions(
                new List<Ruby__Subscription__c>{afterSub}, new Map<Id,Ruby__Subscription__c>{subId=>beforeSub}));
        System.assertEquals(0, ELV_OpportunitySubscriptionEntryUtility.changedSubscriptions(null, null).size());

        Ruby__AssetOrderProduct__c oldJoin = new Ruby__AssetOrderProduct__c(Ruby__Subscription__c=subId);
        Ruby__AssetOrderProduct__c newJoin = new Ruby__AssetOrderProduct__c(Ruby__Subscription__c=subId);
        System.assertEquals(new Set<Id>{subId},
            ELV_OpportunitySubscriptionEntryUtility.subscriptionsForAssetOrderProducts(
                new List<Ruby__AssetOrderProduct__c>{newJoin}, new List<Ruby__AssetOrderProduct__c>{oldJoin}));

        Set<Id> both = ELV_OppSubTriggerUtility.opportunityIds(
            new List<Ruby__OpportunitySubscription__c>{
                new Ruby__OpportunitySubscription__c(Ruby__Opportunity__c=oppA),
                new Ruby__OpportunitySubscription__c(Ruby__Opportunity__c=oppB)});
        System.assertEquals(new Set<Id>{oppA,oppB}, both);
    }
}