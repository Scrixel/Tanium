/**
 * @Business: Test class for BatchSyncContactsScheduler
 * @Date: 2017-08-09
 * @Author: Cumulus Vision
 * @Request: TAN-434
 * Modified  ModifiedDate   Description
 * TAN-434   2017-08-09     Initial Development
 * SS-13159  2026-05-14     Add class back to fix deployment
 */
@isTest
private class BatchSyncContactsTest {
	// set up test data for this testing
	@testSetup
	static void setup() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	@isTest
	public static void SyncContactsTest() {
		//Find User
		User u = [SELECT Id FROM User WHERE isActive = TRUE AND Profile.Name = 'Super User' LIMIT 1];

		Account account = new Account(
			Name = 'Test 1',
			HQ_State__c = 'CA',
			HQ_Zip__c = '94101',
			HQ_City__c = 'San Francisco',
			HQ_Country__c = 'USA',
			Industry = 'Construction',
			OwnerId = u.Id
		);
		insert account;

		// insert Contact
		Contact con = new Contact(LastName = 'Test', AccountId = account.Id);
		insert con;

		Test.startTest();

		// execute scheduler
		String cronString = '0 0 11 1/1 * ? *';
		String jobID = system.schedule(
			'SyncContactOwners',
			cronString,
			new BatchSyncContactsScheduler()
		);
		// execute batch class
		database.executebatch(new BatchSyncContactsScheduler());

		Test.stopTest();

		Account acc = [SELECT id, OwnerId FROM Account WHERE ID = :account.Id];
		Contact con1 = [SELECT id, OwnerId FROM Contact WHERE accountId = :account.Id];

		System.assertEquals(acc.OwnerId, con1.OwnerId);
	}
}