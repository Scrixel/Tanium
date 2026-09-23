/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CommunitiesSelfRegController
 * @Date: 2017-12-04
 * @Authors: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7070    2024-01-20    Added redirect validation
 * SS-7781    2024-03-26    Updated Test method
 * SS-10251   2025-02-27    Remove Constellant Dev references and replace it with Tanium Developer Users
 * SS-10404   2025-03-11    Added test method for assigning Partner Case Access Permision Set
 * SS-13500   2026-07-24    Remove deprecated fields for project kondo group 2 contact
 */
@IsTest
private class CommunitiesSelfRegControllerTest {
	static final String COMMUNITY_USER = 'CommunityUser';
	static final String GUEST_USER = 'GuestUser';

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'UserTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			acc.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			acc.Tech_Partner_Program_Tier__c = 'Silver';
			insert acc;

			Rosco_domain__c roscoDomain = new Rosco_domain__c(
				Name = 'example.com',
				user_automation__c = 'No Automation',
				Auto_register_developer_tanium_com__c = true,
				Account__c = acc.Id
			);
			insert roscoDomain;

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

			users.add(
				TestUserFactory.createBasicUser(GUEST_USER, Utility.getProfileId('Guest License User'))
			);
			users[1].UserRoleId = null;
			users[1].UserPermissionsKnowledgeUser = false;
			insert users;
		}
	}

	@IsTest
	static void registerUser_WhenNoDuplicateContactOrUser_AlwaysNoError() {
		User guestUser = [SELECT Id FROM User WHERE LastName = :GUEST_USER LIMIT 1];
		System.runAs(guestUser) {
			CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
			controller.firstName = 'FirstName';
			controller.lastName = 'LastName';
			controller.email = 'test@122333force.com';
			controller.communityNickname = 'test';
			controller.safeRecaptchaCallback();
			controller.password = 'abcd1234';
			controller.confirmPassword = 'abcd123';

			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();

			Assert.isTrue(controller.userCreateErrors.size() == 0, 'No error should occur.');
		}
	}

	@IsTest
	static void registerUser_WhenBadDataUsed_ReturnNullAndErrorsExist() {
		User guestUser = [SELECT Id FROM User WHERE LastName = :GUEST_USER LIMIT 1];
		System.runAs(guestUser) {
			CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
			controller.firstName = '0123456789012345678901234567890123456789A';
			controller.lastName = '01234567890123456789012345678901234567890123456789012345678901234567890123456789A';
			controller.email = 'bad';
			controller.communityNickname = '0123456789012345678901234567890123456789A';
			controller.password = 'abcd1234';
			controller.confirmPassword = 'abcd123';

			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();

			Assert.isNull(result, 'Should return null when bad data exists.');
			Assert.isTrue(
				controller.userCreateErrors.size() != 0,
				'userCreateErrors should contain the error message'
			);
			Assert.isTrue(
				controller.userCreateErrors[0].contains('MaxLength'),
				'Error message should contain the max length error.'
			);
		}
	}

	@IsTest
	static void registerUser_WhenBlankFields_ReturnNullAndErrorsExist() {
		User guestUser = [SELECT Id FROM User WHERE LastName = :GUEST_USER LIMIT 1];
		System.runAs(guestUser) {
			CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
			controller.firstName = '';
			controller.lastName = '';
			controller.email = '';
			controller.communityNickname = '';

			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();

			Assert.isNull(result, 'Should return null when bad data exists.');
			Assert.isTrue(
				controller.userCreateErrors.size() != 0,
				'userCreateErrors should contain the error message'
			);
			Assert.isTrue(
				controller.userCreateErrors[0].contains('Missing Value'),
				'Error message should contain the missing value error.'
			);
		}
	}

	@IsTest
	static void registerUser_WhenContactExistsWithSameEmail_ReturnNullAndErrorsExist() {
		TriggerHandler.bypass('UserTriggerHandler');
		Contact con = [SELECT Email FROM Contact LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			con.Email = 'CommunityUser@TestTanium.com';
			update con;

			CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
			controller.firstName = 'FirstName';
			controller.lastName = 'LastName';
			controller.email = con.Email;
			controller.communityNickname = 'test';
			controller.password = 'abcd1234';
			controller.confirmPassword = 'abcd123';

			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();

			Assert.isTrue(
				controller.userCreateErrors.size() != 0,
				'userCreateErrors should contain the error message'
			);

			Assert.isTrue(
				controller.userCreateErrors[0].contains('Email is already taken'),
				'Error message should contain the "Email is already taken" value error.'
			);
		}
	}

	@IsTest
	static void registerUser_WhenDistictEmailUsed_AlwaysNoError() {
		TriggerHandler.bypass('UserTriggerHandler');
		Contact con = [SELECT Email FROM Contact LIMIT 1];
		User communityUser = [SELECT ContactId FROM User WHERE LastName = :COMMUNITY_USER];

		System.runAs(TestUserFactory.getAdminUser()) {
			communityUser.IsActive = false;
			update communityUser;

			CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
			controller.firstName = 'FirstName';
			controller.lastName = 'LastName';
			controller.email = con.Email;
			controller.communityNickname = 'test';

			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();

			Assert.isTrue(controller.userCreateErrors.size() == 0, 'No error should occur.');
		}
	}

	@IsTest
	static void registerUser_WhenEmailDomainIsBlackListed_ReturnNullAndErrorExist() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Site_User_Blacklisted_Domains__c setting = new Site_User_Blacklisted_Domains__c();
			setting.Name = 'hotmail.com';
			insert setting;

			CommunitiesSelfRegController controller = new CommunitiesSelfRegController();
			controller.firstName = 'FirstName';
			controller.lastName = 'LastName';
			controller.email = 'test@hotmail.com';
			controller.communityNickname = 'test';
			controller.password = 'abcd1234';
			controller.confirmPassword = 'abcd123';

			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();

			Assert.isNull(result, 'Should return null when bad data exists.');
			Assert.isTrue(
				controller.userCreateErrors.size() != 0,
				'userCreateErrors should contain the error message'
			);
			Assert.isTrue(
				controller.userCreateErrors[0]
					.contains('registration must be with a corporate email address'),
				'Email domain should not be blacklisted.'
			);
		}
	}

	@IsTest
	static void getAccountId_WhenRoscoDomainExists_ReturnAccountId() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Rosco_domain__c dom = new Rosco_domain__c(
				name = '123Foo123.com',
				user_automation__c = 'Support KB',
				Account__c = acc.Id
			);
			insert dom;

			Test.startTest();
			String email = 'roscottestcase@123Foo123.com';
			String accountId = CommunitiesSelfRegController.getAccountId(email);
			Test.stopTest();

			Assert.areEqual(
				acc.Id,
				accountId,
				'Account Id should be the same from the method return.'
			);
		}

	}

	@IsTest
	static void getProfileId_WhenSupportKB_ReturnLoginAuthProfileId() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Rosco_domain__c dom = new Rosco_domain__c(
				name = '123Foo123.com',
				user_automation__c = 'Support KB',
				Account__c = acc.Id
			);
			insert dom;

			Test.startTest();
			String email = 'roscottestcase@123Foo123.com';
			Id profileId = CommunitiesSelfRegController.getProfileId(email);
			Test.stopTest();

			Assert.areEqual(
				CommunitiesSelfRegController.TANIUM_COMMUNITY_LOGIN_AUTH_PROFILEID,
				profileId,
				'Tanium Community Login Authenticated profile id should be the return.'
			);
		}

	}

	@IsTest
	static void getProfileId_WhenSupportCase_ReturnLoginAuthCaseProfileId() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Rosco_domain__c dom = new Rosco_domain__c(
				name = 'ABCFooABC.com',
				user_automation__c = 'Support Case',
				Account__c = acc.Id
			);
			insert dom;

			Test.startTest();
			String email = 'roscottestcase@ABCFooABC.com';
			Id profileId = CommunitiesSelfRegController.getProfileId(email);
			Test.stopTest();

			Assert.areEqual(
				CommunitiesSelfRegController.TANIUM_COMMUNITY_LOGIN_AUTH_CASE_PROFILEID,
				profileId,
				'Tanium Community Login Authenticated Case profile id should be the return.'
			);
		}
	}

	@IsTest
	static void setPermissionSet_AlwaysCreatePermissionSetAssignmentRecord() {
		System.runAs(TestUserFactory.getAdminUser()) {
			User communityUser = [
				SELECT Id
				FROM User
				WHERE Profile.Name LIKE 'Tanium Community%'
				LIMIT 1
			];

			Test.startTest();
			CommunitiesSelfRegController.setPermissionSet(
				communityUser.Id,
				Constants.CONSTELLANT_DEV_PERM_SET
			);
			Test.stopTest();

			Integer count = [
				SELECT COUNT()
				FROM PermissionSetAssignment
				WHERE AssigneeId = :communityUser.Id
			];
			Assert.isTrue(count > 0, 'PermissionSetAssignment record should be created');
		}
	}

	@IsTest
	static void updateRelatedContact_AlwaysUpdateCommunityUserRelatedContact() {
		User user = [SELECT Id, ContactId FROM User WHERE LastName = :COMMUNITY_USER LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CommunitiesSelfRegController.updateRelatedContact(user.Id);
			Test.stopTest();
		}
	}

	@IsTest
	static void updateRelatedContact_WhenRelatedContactAccountIsCommunityAccount_AlwaysUpdateAccountId() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		Contact con = [SELECT Id, Email, AccountId FROM Contact LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			con.AccountId = Id.valueOf('0010e00001JOFGPAA5');

			List<String> emailSplit = con.email.split('@');
			Rosco_domain__c dom = new Rosco_domain__c(
				name = emailSplit[1],
				user_automation__c = 'Support KB',
				Account__c = acc.Id
			);
			insert dom;

			Test.startTest();
			CommunitiesSelfRegController.updateRelatedContact(con);
			Test.stopTest();

			con = [SELECT Id, Email, AccountId FROM Contact LIMIT 1];
			Assert.areEqual(acc.Id, con.AccountId, 'AccountId should be the same.');
		}
	}

	@IsTest
	static void testSetPartnerCaseAccessPermissionSet_AlwaysCreatePermissionSetAssignmentRecord() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Id partnerCaseAccessPermSetId = [
				SELECT Id
				FROM PermissionSet
				WHERE Name = :Constants.PARTNER_CASE_ACCESS
			]
			.Id;
			User communityUser = [
				SELECT Id, Email
				FROM User
				WHERE Contact.Account.Tech_Partner_Program_Tier__c != NULL
				LIMIT 1
			];
			List<String> email = communityUser.Email.split('@');
			String domain = email[1];

			Rosco_domain__c roscoDomain = [
				SELECT Id, Name
				FROM Rosco_domain__c
				WHERE Name = 'example.com'
			];
			roscoDomain.Name = domain;
			update roscoDomain;

			Test.startTest();
			CommunitiesSelfRegController.setPartnerCaseAccessPermissionSet(communityUser.Id);
			Test.stopTest();

			Integer count = [
				SELECT COUNT()
				FROM PermissionSetAssignment
				WHERE AssigneeId = :communityUser.Id AND PermissionSetId = :partnerCaseAccessPermSetId
			];
			Assert.isTrue(count == 1, 'PermissionSetAssignment record should be created');
		}
	}
}