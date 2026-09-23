/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for AccountSDRBatch class.
 * @Date: 2026-06-02
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13234     2026-06-02       Initial development
 */
@IsTest
private class AccountSDRBatchTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
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

			Account acc1 = TestFactory.buildAccount('Test Account 1');
			acc1.Type = 'Customer';
			acc1.Primary_Sales_Territory_Id__c = testSalesTerritoryL1.Id;
			acc1.Primary_Sales_Territory_Name__c = testSalesTerritoryL1.Name;
			Account acc2 = TestFactory.buildAccount('Test Account 2');
			acc2.Type = 'Customer';
			acc2.Primary_Sales_Territory_Id__c = testSalesTerritoryL1.Id;
			acc2.Primary_Sales_Territory_Name__c = testSalesTerritoryL1.Name;
			insert new List<Account>{ acc1, acc2 };
		}
	}

	@IsTest
	static void testAccountSDRBatch_executeBatch_AlwaysRun() {
		Map<Id, Id> accountIdToUserId = new Map<Id, Id>();
		Map<Id, Id> userIdToUserManagerId = new Map<Id, Id>();

		User standardUser = [
			SELECT Id, ManagerId
			FROM User
			WHERE LastName = :TestUserFactory.TANIUM_STANDARD_USER
			LIMIT 1
		];
		for (Account acc : [SELECT Id FROM Account]) {
			accountIdToUserId.put(acc.Id, standardUser.Id);
		}
		userIdToUserManagerId.put(standardUser.Id, standardUser.ManagerId);

		Id jobId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jobId = Database.executeBatch(
				new AccountSDRBatch(accountIdToUserId, userIdToUserManagerId)
			);
			Test.stopTest();
		}

		List<Account> accounts = [SELECT Id, BDR__c, SDR_Manager__c FROM Account];
		Assert.isNotNull(jobId, 'Batch job was not enqueued successfully');
		Assert.areEqual(2, accounts.size(), 'There should be two accounts present');
		Assert.areEqual(standardUser.Id, accounts[0].BDR__c, 'SDR is not set correctly');
		Assert.areEqual(standardUser.Id, accounts[1].BDR__c, 'SDR is not set correctly');
		Assert.areEqual(
			standardUser.ManagerId,
			accounts[0].SDR_Manager__c,
			'SDR Manager is not set correctly'
		);
		Assert.areEqual(
			standardUser.ManagerId,
			accounts[1].SDR_Manager__c,
			'SDR Manager is not set correctly'
		);
	}
}