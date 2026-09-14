/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for ContactStageCustomerBatch class.
 * @Date: 2026-01-30
 * @Author: Tanium Dev Team
 * RequestId   ModifiedDate   Description
 * SS-12167    2026-01-30     Initial development
 */
@IsTest
private class ContactStageCustomerBatchTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			acc.Type = 'Customer';
			insert acc;

			Contact contact = TestFactory.buildContact(acc.Id);
			contact.Contact_Stage__c = 'New';
			insert contact;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				System.today(),
				'Prospecting',
				acc.Id
			);
			opp.Type = 'Expansion';
			insert opp;
		}
	}

	@IsTest
	static void testContactStageCustomerBatch_executeBatch_AlwaysRun() {
		Id jobId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jobId = Database.executeBatch(new ContactStageCustomerBatch());
			Test.stopTest();
		}
		Assert.isNotNull(jobId, 'Batch job should have been executed');
	}

	@IsTest
	static void testContactStageCustomerBatch_execute_AlwaysRun() {
		List<Contact> contacts = [SELECT Id FROM Contact];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ContactStageCustomerBatch batch = new ContactStageCustomerBatch();
			batch.execute(null, contacts);
			Test.stopTest();
		}

		contacts = [SELECT Id FROM Contact WHERE Contact_Stage__c = 'Customer'];
		Assert.areEqual(1, contacts.size(), 'A contact should have been updated to Customer');
	}
}