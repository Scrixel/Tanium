/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for LeadSDRBatch class.
 * @Date: 2026-06-02
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13234     2026-06-02       Initial development
 */
@IsTest
private class LeadSDRBatchTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'LeadTriggerHandler' });
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

			User standardUser = TestUserFactory.createTaniumStandardUser();
			standardUser.ManagerId = TestUserFactory.getAdminUser().Id;
			insert standardUser;

			Account acc = TestFactory.buildAccount('Test Account');
			acc.Type = 'Customer';
			acc.Primary_Sales_Territory_Id__c = testSalesTerritoryL1.Id;
			acc.Primary_Sales_Territory_Name__c = testSalesTerritoryL1.Name;
			acc.BDR__c = standardUser.Id;
			acc.SDR_Manager__c = standardUser.ManagerId;
			insert acc;

			Lead lead1 = TestFactory.buildLead(
				'Test',
				'Lead 1',
				'test.lead1@example.com',
				'Test Company'
			);
			lead1.Account__c = acc.Id;
			Lead lead2 = TestFactory.buildLead(
				'Test',
				'Lead 2',
				'test.lead2@example.com',
				'Test Company'
			);
			lead2.Account__c = acc.Id;
			insert new List<Lead>{ lead1, lead2 };
		}
	}

	@IsTest
	static void testLeadSDRBatch_executeBatch_AlwaysRun() {
		User standardUser = [
			SELECT Id, ManagerId
			FROM User
			WHERE LastName = :TestUserFactory.TANIUM_STANDARD_USER
			LIMIT 1
		];

		Set<Id> accountIds = new Set<Id>();
		for (Account acc : [SELECT Id FROM Account]) {
			accountIds.add(acc.Id);
		}

		Id jobId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jobId = Database.executeBatch(new LeadSDRBatch(accountIds));
			Test.stopTest();
		}

		List<Lead> leads = [SELECT Id, SDR_Owner__c, SDR_Manager__c FROM Lead];
		Assert.isNotNull(jobId, 'Batch job was not enqueued successfully');
		Assert.areEqual(2, leads.size(), 'There should be two leads present');
		Assert.areEqual(standardUser.Id, leads[0].SDR_Owner__c, 'SDR is not set correctly');
		Assert.areEqual(standardUser.Id, leads[1].SDR_Owner__c, 'SDR is not set correctly');
		Assert.areEqual(
			standardUser.ManagerId,
			leads[0].SDR_Manager__c,
			'SDR Manager is not set correctly'
		);
		Assert.areEqual(
			standardUser.ManagerId,
			leads[1].SDR_Manager__c,
			'SDR Manager is not set correctly'
		);
	}
}