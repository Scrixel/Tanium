/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OpportunityTerritoryBatch class.
 * @Date: 2026-04-22
 * @Author: Tanium Dev Team
 * RequestId   ModifiedDate   Description
 * SS-12951    2026-05-26     Initial development
 */
@IsTest
private class OpportunityTerritoryBatchTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Territory2Model territoryModel = new Territory2Model(
				Name = 'Test Territory Model',
				DeveloperName = 'Test_Territory_Model'
			);
			insert territoryModel;

			Territory2Type salesTerritoryType = [
				SELECT Id
				FROM Territory2Type
				WHERE MasterLabel = 'Sales'
				LIMIT 1
			];

			Territory2 testSalesTerritoryL1 = new Territory2(
				Name = 'L1 Test Sales Territory',
				Territory2TypeId = salesTerritoryType.Id,
				Territory2ModelId = territoryModel.Id,
				DeveloperName = 'L1_Test_Sales_Territory'
			);
			insert testSalesTerritoryL1;

			Account acc = TestFactory.buildAccount('Test Account');
			acc.Type = 'Customer';
			insert acc;
			acc.Primary_Sales_Territory_Id__c = testSalesTerritoryL1.Id;
			acc.Primary_Sales_Territory_Name__c = testSalesTerritoryL1.Name;
			update acc;

			Opportunity oppAccountId = TestFactory.buildOpportunity(
				'Test Opportunity',
				System.today(),
				'Prospecting',
				acc.Id
			);
			oppAccountId.Type = 'Expansion';
			Opportunity oppEndUserAccountId = TestFactory.buildOpportunity(
				'Test Opportunity',
				System.today(),
				'Prospecting',
				null
			);
			oppEndUserAccountId.Type = 'Expansion';
			oppEndUserAccountId.End_User_Account__c = acc.Id;
			insert new List<Opportunity>{ oppAccountId, oppEndUserAccountId };
		}
	}

	@IsTest
	static void testOpportunityTerritoryBatch_executeBatch_AlwaysRun() {
		Id jobId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jobId = Database.executeBatch(new OpportunityTerritoryBatch());
			Test.stopTest();
		}

		List<Opportunity> opps = [SELECT Id, Territory2Id FROM Opportunity];
		Assert.isNotNull(jobId, 'Batch job should have been executed');
		Assert.areEqual(2, opps.size(), 'Both opportunities should have been processed');
	}

	@IsTest
	static void testOpportunityTerritoryBatchSchedulable_executeBatch_AlwaysRun() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTerritoryBatch batch = new OpportunityTerritoryBatch();
			batch.execute(null);
			Test.stopTest();
		}
	}

	@IsTest
	static void testOpportunityTerritoryBatch_execute_AlwaysRun() {
		List<Opportunity> opps = [
			SELECT Id, Territory2Id, End_User_Account__c, AccountId
			FROM Opportunity
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTerritoryBatch batch = new OpportunityTerritoryBatch();
			batch.execute(null, opps);
			Test.stopTest();
		}
	}

	@IsTest
	static void testOpportunityTerritoryBatchCustom_execute_AlwaysRun() {
		List<Opportunity> opps = [
			SELECT Id, Territory2Id, End_User_Account__c, AccountId
			FROM Opportunity
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTerritoryBatch batch = new OpportunityTerritoryBatch(
				'SELECT Id, NewValue, AccountId FROM AccountHistory LIMIT 1',
				'SELECT Id, Territory2Id, End_User_Account__c, AccountId FROM Opportunity LIMIT 1'
			);
			batch.execute(null, opps);
			Test.stopTest();
		}
	}
}