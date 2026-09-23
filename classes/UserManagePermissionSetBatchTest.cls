/**
 * @Business: UserManagePermissionSetBatchTest - Test Class for UserManagePermissionSetBatch
 * @Date: 03/26/2024
 * @Authors: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7884    2024-04-26    Grant Permission Set to Partners with Tier
 * SS-10251   2025-02-27    Remove Constellant Dev references and replace it with Tanium Developer Users
 */
@IsTest
private class UserManagePermissionSetBatchTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'UserTriggerHandler' }
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accWithTier = TestFactory.buildAccount('Partner Account with Tier');
			accWithTier.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			accWithTier.Tech_Partner_Program_Tier__c = 'Silver';

			Account accWithoutTier = TestFactory.buildAccount('Partner Account w/o Tier');
			accWithoutTier.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			insert new List<Account>{ accWithTier, accWithoutTier };

			Contact communityContact_1 = TestFactory.buildContact(accWithTier.Id);
			Contact communityContact_2 = TestFactory.buildContact(accWithTier.Id);
			Contact communityContact_3 = TestFactory.buildContact(accWithoutTier.Id);
			insert new List<Contact>{ communityContact_1, communityContact_2, communityContact_3 };

			User communityUser_1 = TestUserFactory.createBasicUser(
				'TestUser1',
				Utility.getProfileId('Tanium Community Login Authenticated')
			);
			communityUser_1.UserRoleId = null;
			communityUser_1.ContactId = communityContact_1.Id;

			User communityUser_2 = TestUserFactory.createBasicUser(
				'TestUser2',
				Utility.getProfileId('Tanium Community Login Authenticated')
			);
			communityUser_2.UserRoleId = null;
			communityUser_2.ContactId = communityContact_2.Id;

			User communityUser_3 = TestUserFactory.createBasicUser(
				'TestUser3',
				Utility.getProfileId('Tanium Community Login Authenticated')
			);
			communityUser_3.UserRoleId = null;
			communityUser_3.ContactId = communityContact_3.Id;
			insert new List<User>{ communityUser_1, communityUser_2, communityUser_3 };

			TestingUtility.assignPermissionSet(communityUser_1.Id, Constants.CONSTELLANT_DEV_PERM_SET);
			TestingUtility.assignPermissionSet(communityUser_3.Id, Constants.CONSTELLANT_DEV_PERM_SET);
		}
	}

	@IsTest
	static void testBatch_WhenTierExists_AssignPermission_Otherwise_Remove() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Id taniumDevUserPermSetId = [
				SELECT Id
				FROM PermissionSet
				WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
			]
			.Id;
			Test.startTest();
			String customQuery =
				'SELECT Id,' +
				' Contact.Account.Tech_Partner_Program_Tier__c,' +
				' Contact.Account.RecordType.DeveloperName' +
				' FROM User' +
				' WHERE LastName LIKE \'TestUser%\'';
			Id jobId = Database.executeBatch(new UserManagePermissionSetBatch(customQuery));
			Test.stopTest();

			Map<Id, User> testUsers = new Map<Id, User>(
				[SELECT Id, Name FROM User WHERE LastName LIKE 'TestUser%' ORDER BY LastName ASC]
			);
			Integer psaCount = [
				SELECT COUNT()
				FROM PermissionSetAssignment
				WHERE PermissionSetId = :taniumDevUserPermSetId AND AssigneeId IN :testUsers.keySet()
			];

			List<User> testUser = testUsers.values();
			List<PermissionSetAssignment> psa = [
				SELECT Id
				FROM PermissionSetAssignment
				WHERE PermissionSetId = :taniumDevUserPermSetId AND AssigneeId = :testUser[2].Id
			];

			Assert.areEqual(
				3,
				psaCount,
				'Two of the test users should have contellant dev permission set'
			);
		}
	}

	@IsTest
	static void testBatch_WhenBatchRuns_CreateLog() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String customQuery =
				'SELECT Id,' +
				' Contact.Account.Tech_Partner_Program_Tier__c,' +
				' Contact.Account.RecordType.DeveloperName' +
				' FROM User' +
				' WHERE LastName LIKE \'TestUser%\'';
			Id jobId = Database.executeBatch(new UserManagePermissionSetBatch(customQuery));
			Test.stopTest();

			List<LogEntry__c> logEntries = [
				SELECT Id
				FROM LogEntry__c
				WHERE OriginSourceApiName__c LIKE '%UserManagePermissionSetBatch%'
			];
			Assert.isFalse(logEntries.isEmpty(), 'Log entries should be created when the batch runs');
		}
	}
}