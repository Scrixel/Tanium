/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for AccountOwnerETMBatch class.
 * @Date: 2026-06-17
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-12811     2026-06-17       Initial development
 */
@IsTest
private class AccountOwnerETMBatchTest {
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

			User standardUser = TestUserFactory.getStandardUser();
			standardUser.ManagerId = TestUserFactory.getAdminUser().Id;
			update standardUser;

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
	static void testAccountOwnerETMBatch_executeBatch_AlwaysRun() {
		User standardUser = TestUserFactory.getStandardUser();
		Map<Id, Id> accountIdToUserId = new Map<Id, Id>();
		for (Account acc : [SELECT Id FROM Account]) {
			accountIdToUserId.put(acc.Id, standardUser.Id);
		}

		Id jobId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jobId = Database.executeBatch(new AccountOwnerETMBatch(accountIdToUserId));
			Test.stopTest();
		}

		List<Account> accounts = [SELECT Id, OwnerId FROM Account];
		Assert.isNotNull(jobId, 'Batch job was not enqueued successfully');
		Assert.areEqual(2, accounts.size(), 'There should be two accounts present');
		Assert.areEqual(standardUser.Id, accounts[0].OwnerId, 'Owner is not set correctly');
		Assert.areEqual(standardUser.Id, accounts[1].OwnerId, 'Owner is not set correctly');
	}
}