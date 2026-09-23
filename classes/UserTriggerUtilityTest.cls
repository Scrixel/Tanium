/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for User Trigger Utility
 * @Date: 2014-12-10
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * TAN-536    2018-04-14    Fixed issue due to the newly added validation rule on the Opportunity
 * TAN-574    2018-05-14    Updated testuser due to error of existing user
 * SS-9255    2024-12-18    Removed method related to Deal Desk Approver testing
 * SS-10173	  2025-02-05    Account.Segment__c is not driven off from User's L1 thru' L6
 * SS-7266	  2025-11-24    Deleted TestDataFactory class, had to make adjustments accordingly
 * SS-10186   2026-02-27    Renamed the test class from UserTriggerHandlerTest to UserTriggerUtilityTest
 * SS-13176   2026-05-27    Removed Level_2__c, Level_4__c, Level_6__c references from Sales_Heirarchy__c
 * SS-13497   2026-07-07    Remove deprecated fields for project kondo group 2
 * SS-12811   2026-07-10    Added code coverage for processDeactivatedUsers
 */
@IsTest
private class UserTriggerUtilityTest {
	@TestSetup
	private static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler'
			}
		);

		Profile portalLoginAuthProfile = [
			SELECT Id
			FROM Profile
			WHERE Name = 'Tanium Community Login Authenticated'
		];
		User adminUser = TestFactory.buildUser(
			'Admin',
			'admin.user@org.com',
			'admUser',
			Utility.getAdminUserProfileId(),
			null
		);
		insert adminUser;

		TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
		TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');

		User user1;
		User user2;
		User partnerUser;
		UserRole userRole;
		System.runAs(adminUser) {
			userRole = new UserRole(Name = 'West: North Central');
			insert userRole;

			adminUser.UserRoleId = userRole.Id;
			update adminUser;

			Account account = TestFactory.buildAccount('Test Account');
			account.Commission__c = 100;
			account.Total_Addressable_Seats__c = 100;
			account.Country_Restrictions__c = 'Business Allowed';
			account.Type = 'Analyst';

			Account partnerAccount = TestFactory.buildAccount('Partner Account');
			partnerAccount.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			partnerAccount.Sync_with_Zift__c = true;
			partnerAccount.Partner_Level__c = 'Strategic';
			partnerAccount.Partner_Maturity__c = 'Active';
			partnerAccount.OwnerId = adminUser.Id;
			insert new List<Account>{ account, partnerAccount };

			Contact partnerContact = TestFactory.buildContact(partnerAccount.Id);
			partnerContact.FirstName = 'Partner';
			partnerContact.LastName = 'Contact';
			partnerContact.Email = 'test' + partnerAccount.Id + '@test.com';
			partnerContact.Partner_Role__c = 'Technical';
			insert partnerContact;

			user1 = TestFactory.buildUser(
				'User1',
				'test.user1@org.com',
				'tUser1',
				Utility.getAdminUserProfileId(),
				userRole.Id
			);
			user1.RVP_Override__c = adminUser.Id;

			user2 = TestFactory.buildUser(
				'User2',
				'test.user2@org.com',
				'tUser2',
				Utility.getAdminUserProfileId(),
				null
			);
			user2.ManagerId = adminUser.Id;

			partnerUser = TestFactory.buildUser(
				'PartnerUser',
				'partner.user@org.com',
				'tPartner',
				portalLoginAuthProfile.Id,
				null
			);

			partnerUser.ContactId = partnerContact.Id;
			partnerUser.Role_Category__c = 'Customer';
			insert new List<User>{ user1, user2, partnerUser };
			account.ownerId = user2.Id;
			update account;
		}

		System.runAs(user1) {
			List<BDR_Assignments__c> bdrAssignments = new List<BDR_Assignments__c>();
			bdrAssignments.add(
				new BDR_Assignments__c(
					Name = userRole.Name,
					User_ID__c = user2.Id,
					User_Name__c = user2.Username
				)
			);
			insert bdrAssignments;
		}
	}

	@IsTest
	static void test_Level2Changed_UpdateAccountsOwnerAndSegment() {
		User adminUser = [
			SELECT Id, UserName
			FROM User
			WHERE UserName = 'admin.user@org.com'
			LIMIT 1
		];
		User testUser1 = [
			SELECT Id, UserName
			FROM User
			WHERE UserName = 'test.user1@org.com'
			LIMIT 1
		];
		User testUser2 = [
			SELECT Id, UserName
			FROM User
			WHERE UserName = 'test.user2@org.com'
			LIMIT 1
		];
		UserRole userRole = [
			SELECT Id, Name
			FROM UserRole
			WHERE Name = 'West: North Central'
			LIMIT 1
		];
		Account testAccount = [
			SELECT Id, Name, BDR__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];

		System.runAs(adminUser) {
			Test.startTest();
			testUser2.UserRoleId = userRole.Id;
			update testUser2;
			Test.stopTest();
		}

		Account resAccount = [SELECT Segment__c, OwnerId FROM Account WHERE Id = :testAccount.Id];
		Assert.areNotEqual(null, resAccount.Segment__c);
		Assert.areEqual(testUser2.Id, resAccount.OwnerId);
	}

	@IsTest
	static void testSyncInternalSupportRequests() {
		TriggerHandler.bypass('UserTriggerHandler');

		User adminUser = [
			SELECT Id, ManagerId, Manager.Full_Name__c
			FROM User
			WHERE UserName = 'admin.user@org.com'
			LIMIT 1
		];
		User manager1 = [
			SELECT Id, ManagerId, Manager.Full_Name__c
			FROM User
			WHERE UserName = 'test.user1@org.com'
			LIMIT 1
		];
		User manager2 = [
			SELECT Id, ManagerId, Manager.Full_Name__c
			FROM User
			WHERE UserName = 'test.user2@org.com'
			LIMIT 1
		];

		adminUser.ManagerId = manager1.Id;
		update adminUser;

		List<User> users = [
			SELECT Id, ManagerId, Manager.Full_Name__c
			FROM User
			WHERE Id = :adminUser.Id
		];

		Map<Id, User> oldMap = new Map<Id, User>(users.deepClone(true, true, true));
		for (User u : oldMap.values()) {
			u.ManagerId = manager2.Id;
		}

		Test.startTest();
		UserTriggerUtility.syncInternalSupportRequests(users, oldMap);
		Test.stopTest();
	}

	@IsTest
	static void testProcessDeactivatedUsers_WhenUserDeactivated_UpdateAccountOwner() {
		User testUser1 = [
			SELECT Id, IsActive, ManagerId, RVP_Override__c
			FROM User
			WHERE UserName = 'test.user1@org.com'
			LIMIT 1
		];
		User testUser2 = [
			SELECT Id, IsActive, ManagerId, RVP_Override__c
			FROM User
			WHERE UserName = 'test.user2@org.com'
			LIMIT 1
		];

		List<User> users = new List<User>{ testUser1, testUser2 };
		Map<Id, User> oldMap = new Map<Id, User>(users.deepClone(true, true, true));
		for (User u : users) {
			u.IsActive = false;
		}
		update users;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			UserTriggerUtility.processDeactivatedUsers(users, oldMap);
			Test.stopTest();
		}
	}
}