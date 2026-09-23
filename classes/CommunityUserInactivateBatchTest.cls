/**
 * @Business: Test class for CommunityUserInactivateBatch
 * @Date: 08/05/2025
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-8594    2025-08-26    Initial Development
 */
@isTest
private with sharing class CommunityUserInactivateBatchTest {
	static final String COMMUNITY_USER = 'CommunityUser';

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler', 'UserTriggerHandler' }
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			acc.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			acc.Tech_Partner_Program_Tier__c = 'Silver';
			insert acc;

			List<Contact> contacts = new List<Contact>();
			contacts.add(TestFactory.buildContact(acc.Id));
			contacts[0].Email = 'CommunityContact@example.com';
			contacts[0].LastName = 'CommunityContact';
			contacts[0].AccountId = acc.Id;
			insert contacts;

			List<User> users = new List<User>();
			users.add(
				TestUserFactory.createBasicUser(
					COMMUNITY_USER,
					Utility.getProfileId('Tanium Community Login Authenticated')
				)
			);
			users[0].UserRoleId = null;
			users[0].ContactId = contacts[0].Id;
			users[0].IsActive = true;
			insert users;

			Case c = TestFactory.buildCase(acc.Id, contacts[0].Id);
			c.Origin = 'Email';
			insert c;
		}
	}

	@isTest(SeeAllData=false)
	static void testBatch_userWithCase() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Id jobId = Database.executeBatch(new CommunityUserInactivateBatch());
			Test.stopTest();

			Assert.isNotNull(jobId, 'Batch job should have been executed');
		}
	}

	@isTest(SeeAllData=false)
	static void testBatch_userWithoutCaseAndCustomQueries() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Case c = [SELECT Id FROM Case WHERE Contact.LastName = 'CommunityContact'];
			delete c;
			Id jobId = Database.executeBatch(new CommunityUserInactivateBatch('', '', 1));
			Test.stopTest();

			Assert.isNotNull(jobId, 'Batch job should have been executed');
		}
	}
}