/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CustAuthSelfRegController
 * @Date: 2026-08-11
 * @Authors: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13683   2026-08-11    Created the test class
 */
@IsTest
private class CustAuthSelfRegControllerTest {
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
			Account account = TestFactory.buildAccount('Test Account');
			account.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Client');
			account.Domain__c = 'cust-auth-selfreg-controller-test.com';
			insert account;

			Contact communityUser = TestFactory.buildContact(account.Id);
			communityUser.Email = 'communityuser@cust-auth-selfreg-controller-test.com';
			communityUser.FirstName = 'FirstName';
			communityUser.LastName = 'CommunityUser';
			communityUser.AccountId = account.Id;

			Contact contact = TestFactory.buildContact(account.Id);
			contact.Email = 'contact@cust-auth-selfreg-controller-test.com';
			contact.FirstName = 'FirstName';
			contact.LastName = 'Contact';
			contact.AccountId = account.Id;
			insert new List<Contact>{ communityUser, contact };

			List<User> users = new List<User>();
			users.add(
				TestUserFactory.createBasicUser(
					COMMUNITY_USER,
					Utility.getProfileId('Tanium Community Login Authenticated')
				)
			);
			users[0].UserRoleId = null;
			users[0].ContactId = communityUser.Id;
			users[0].CommunityNickname = 'CommunityUser';

			users.add(
				TestUserFactory.createBasicUser(GUEST_USER, Utility.getProfileId('Guest License User'))
			);
			users[1].UserRoleId = null;
			users[1].UserPermissionsKnowledgeUser = false;
			insert users;

			insert new Domain_Blacklist__c(Name = 'hotmail.com');
		}
	}

	@IsTest
	static void testRegisterUser_WhenBlockedEmailDomain_GenerateError() {
		User guestUser = [SELECT Id FROM User WHERE LastName = :GUEST_USER LIMIT 1];
		Contact contact = [SELECT Email FROM Contact LIMIT 1];
		CustAuthSelfRegController controller = new CustAuthSelfRegController();
		controller.firstName = 'FirstName';
		controller.lastName = 'LastName';
		controller.email = 'community.contact2@hotmail.com';
		controller.communityNickname = 'communitycontact2';
		controller.safeRecaptchaCallback();
		controller.password = 'abcd1234';

		System.runAs(guestUser) {
			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();
		}

		Assert.isTrue(
			controller.userRegistrationErrors[0]
				.contains('registration must be with a corporate email address'),
			'We should get a blocked email domain error.'
		);
	}

	@IsTest
	static void testRegisterUser_WhenUserWithEmailExists_GenerateError() {
		User guestUser = [SELECT Id FROM User WHERE LastName = :GUEST_USER LIMIT 1];
		User communityUser = [SELECT Id, Email FROM User WHERE LastName = :COMMUNITY_USER LIMIT 1];

		CustAuthSelfRegController controller = new CustAuthSelfRegController();
		controller.firstName = 'FirstName';
		controller.lastName = 'LastName';
		controller.email = communityUser.Email;
		controller.communityNickname = 'communitycontact2';
		controller.safeRecaptchaCallback();
		controller.password = 'abcd1234';

		System.runAs(guestUser) {
			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();
		}

		Assert.isTrue(
			controller.userRegistrationErrors[0].contains('Email is already taken'),
			'We should get an email already taken error.'
		);
	}

	@IsTest
	static void testRegisterUser_WhenBadData_GenerateError() {
		User guestUser = [SELECT Id FROM User WHERE LastName = :GUEST_USER LIMIT 1];
		CustAuthSelfRegController controller = new CustAuthSelfRegController();
		controller.firstName = '0123456789012345678901234567890123456789A';
		controller.lastName = '01234567890123456789012345678901234567890123456789012345678901234567890123456789A';
		controller.email = 'bad';
		controller.communityNickname = '0123456789012345678901234567890123456789A';
		controller.password = 'abcd1234';

		System.runAs(guestUser) {
			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();
		}

		Assert.isTrue(
			controller.userRegistrationErrors[0].contains('MaxLength'),
			'Error message should contain the max length error.'
		);
	}

	@IsTest
	static void testRegisterUser_WhenNoExistingContactOrUser_createUser() {
		User guestUser = [SELECT Id FROM User WHERE LastName = :GUEST_USER LIMIT 1];
		Contact contact = [SELECT Email FROM Contact LIMIT 1];
		CustAuthSelfRegController controller = new CustAuthSelfRegController();
		controller.firstName = 'FirstName';
		controller.lastName = 'NewContact';
		controller.email = 'newcontact@cust-auth-selfreg-controller-test.com';
		controller.communityNickname = 'newcontact';
		controller.safeRecaptchaCallback();
		controller.password = 'qwerQWER1234!@#$';

		System.runAs(guestUser) {
			Test.startTest();
			PageReference result = controller.registerUser();
			Test.stopTest();
		}

		Assert.isTrue(controller.userRegistrationErrors.isEmpty(), 'No error should occur.');
	}

	@IsTest
	static void getAccountId_WhenDomainExists_ReturnAccountId() {
		Account acc = [SELECT Id, Domain__c FROM Account LIMIT 1];
		String email = 'some.dude@' + acc.Domain__c;
		Id accountId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountId = CustAuthSelfRegController.getAccountId(email);
			Test.stopTest();
		}

		Assert.areEqual(acc.Id, accountId, 'Account Id should be found based on domain.');
	}

	@IsTest
	static void getAccountId_WhenDomainDoesNotExists_ReturnDefaultAccountId() {
		String email = 'some.dude@domain-that-does-not-exist.io';
		List<String> selfRegDefaultAccountIds = System.Label.Customer_Community_AccountIds.split(',');
		Id accountId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountId = CustAuthSelfRegController.getAccountId(email);
			Test.stopTest();
		}

		Assert.areEqual(
			selfRegDefaultAccountIds[0],
			accountId,
			'DefaultAccountId should be returned.'
		);
	}

	@IsTest
	static void setAccountIdOnNewlyCreatedContact_Always_UpdateCommunityUserRelatedContact() {
		User user = [SELECT Id, ContactId FROM User WHERE LastName = :COMMUNITY_USER LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CustAuthSelfRegController.setAccountIdOnNewlyCreatedContact(user.Id);
			Test.stopTest();
		}

		Contact contact = [SELECT Id, AccountId FROM Contact WHERE Id = :user.ContactId LIMIT 1];

		Assert.isFalse(contact.AccountId == null);
	}
}