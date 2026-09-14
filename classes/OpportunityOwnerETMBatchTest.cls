/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OpportunityOwnerETMBatch class.
 * @Date: 2026-06-17
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13349     2026-06-17       Initial development
 */
@IsTest
private class OpportunityOwnerETMBatchTest {
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

			Territory2 testSalesTerritoryL1 = [
				SELECT Id, Name
				FROM Territory2
				WHERE Territory2Model.State = 'Active' AND Territory2Type.MasterLabel = 'Sales'
				ORDER BY Id
				LIMIT 1
			];

			User standardUser = TestUserFactory.getStandardUser();
			standardUser.ManagerId = TestUserFactory.getAdminUser().Id;
			update standardUser;

			Account acc = TestFactory.buildAccount('Test Account');
			acc.Type = 'Customer';
			acc.Primary_Sales_Territory_Id__c = testSalesTerritoryL1.Id;
			acc.Primary_Sales_Territory_Name__c = testSalesTerritoryL1.Name;
			acc.OwnerId = standardUser.Id;
			insert acc;

			Opportunity opp1 = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today().addDays(30),
				'Prospecting',
				acc.Id
			);
			opp1.Territory2Id = testSalesTerritoryL1.Id;
			Opportunity opp2 = TestFactory.buildOpportunity(
				'Test Opportunity 2',
				Date.today().addDays(30),
				'Prospecting',
				acc.Id
			);
			opp2.Territory2Id = testSalesTerritoryL1.Id;
			insert new List<Opportunity>{ opp1, opp2 };
		}
	}

	@IsTest
	static void testOpportunityOwnerETMBatch_executeBatch_AlwaysRun() {
		Account acc = [SELECT Id, OwnerId FROM Account LIMIT 1];
		Set<Id> accountIds = new Set<Id>{ acc.Id };

		Id jobId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jobId = Database.executeBatch(new OpportunityOwnerETMBatch(accountIds));
			Test.stopTest();
		}

		List<Opportunity> opportunities = [SELECT Id, OwnerId FROM Opportunity];
		Assert.isNotNull(jobId, 'Batch job was not enqueued successfully');
		Assert.areEqual(2, opportunities.size(), 'There should be two opportunities present');
		Assert.areEqual(acc.OwnerId, opportunities[0].OwnerId, 'Owner is not set correctly');
		Assert.areEqual(acc.OwnerId, opportunities[1].OwnerId, 'Owner is not set correctly');
	}
}