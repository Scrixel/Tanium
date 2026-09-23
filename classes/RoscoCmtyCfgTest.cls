@isTest
public with sharing class RoscoCmtyCfgTest {
	@isTest(SeeAllData=false)
	static void testProcessCeooId() {
		Account accountObj = new Account(name = 'roscoapextestingd');
		insert accountObj;

		Contact contactObj = new Contact(
			Email = 'foo@bar.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.Id,
			HasOptedOutOfEmail = false
		);
		insert contactObj;

		RoscoCmtyCfg.processEmailOptOut(String.valueOf(contactObj.Id));

		Contact c = [SELECT HasOptedOutOfEmail FROM Contact WHERE Id = :contactObj.Id];

		//System.assertEquals(true, c.HasOptedOutOfEmail);
	}

	@isTest(SeeAllData=false)
	static void testProcessvooId() {
		String email = 'testProcessvooId@roscolab.com';

		Account accountObj = new Account(
			name = 'test_Unit_createCase',
			slack_channel_id__c = 'TESTCASE',
			Country_Exception_Approved__c = true
		);
		insert accountObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.Id
		);
		insert contactObj;

		User userObj = new User(
			Email = email,
			FirstName = 'Foo',
			LastName = 'Bar',
			UserName = email,
			Alias = 'foo',
			CommunityNickName = 'foo',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert userObj;

		RoscoTanVuln.addSubscriberEmail(email);
		RoscoCmtyCfg.processTanVulnEmailOptOut(String.valueOf(contactObj.Id));
	}
}