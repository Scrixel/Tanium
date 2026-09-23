/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for ContactSDRBatch class.
 * @Date: 2026-06-02
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13234     2026-06-02       Initial development
 */
@IsTest
private class ContactSDRBatchTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
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

			Contact con1 = TestFactory.buildContact(acc.Id);
			Contact con2 = TestFactory.buildContact(acc.Id);
			insert new List<Contact>{ con1, con2 };
		}
	}

	@IsTest
	static void testContactSDRBatch_executeBatch_AlwaysRun() {
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
			jobId = Database.executeBatch(new ContactSDRBatch(accountIds));
			Test.stopTest();
		}

		List<Contact> contacts = [SELECT Id, SDR_Owner__c, SDR_Manager__c FROM Contact];
		Assert.isNotNull(jobId, 'Batch job was not enqueued successfully');
		Assert.areEqual(2, contacts.size(), 'There should be two contacts present');
		Assert.areEqual(standardUser.Id, contacts[0].SDR_Owner__c, 'SDR is not set correctly');
		Assert.areEqual(standardUser.Id, contacts[1].SDR_Owner__c, 'SDR is not set correctly');
		Assert.areEqual(
			standardUser.ManagerId,
			contacts[0].SDR_Manager__c,
			'SDR Manager is not set correctly'
		);
		Assert.areEqual(
			standardUser.ManagerId,
			contacts[1].SDR_Manager__c,
			'SDR Manager is not set correctly'
		);
	}
}