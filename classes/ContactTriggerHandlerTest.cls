/**
 * Copyright (c) 2026 Tanium
 *
 * Test class for ContactTriggerHandler
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * TAN-483    2018-02-22    Updated StageName
 * TAN-536    2018-04-14    Modified Account creation as per "Country_Restriction" validation rule on opportunity
 * TAN-903    2020-07-22    Commented a Test Method because the logic which it tests is commented in the actual class.
 * SS-9000    2024-09-23    Opp Reg to Deal Reg Migration
 * SS-12496   2026-02-24    Updated method getContactDeleteAllowedUser
 * SS-13075   2026-04-21    Changed FCRM__FCR_Admin_Originating_Contact__c to Primary_Opportunity_Contact__c field
 * SS-13500   2026-07-27    Remove deprecated fields for project kondo group 2 contact
 */
@IsTest
private class ContactTriggerHandlerTest {
	static List<Domain_Blacklist__c> bl { get; set; }

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'DealRegistrationTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			bl = new List<Domain_Blacklist__c>();
			bl.add(new Domain_Blacklist__c(name = 'test.com'));
			bl.add(new Domain_Blacklist__c(name = 'test1.com'));
			insert bl;

			Account standardAccount = TestFactory.buildAccount('Standard Account');
			Account partnerAccount = TestFactory.buildAccount('Partner Account');
			partnerAccount.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			insert new List<Account>{ standardAccount, partnerAccount };

			List<Contact> testContacts = new List<Contact>();
			Contact communityContact = TestFactory.buildContact(standardAccount.Id);
			communityContact.FirstName = 'Community';
			communityContact.LastName = 'Contact';
			testContacts.add(communityContact);
			Contact partnerContact = TestFactory.buildContact(partnerAccount.Id);
			partnerContact.FirstName = 'Partner';
			partnerContact.LastName = 'Contact';
			testContacts.add(partnerContact);
			Contact oppRegContact = TestFactory.buildContact(standardAccount.Id);
			oppRegContact.FirstName = 'Deal';
			oppRegContact.LastName = 'Registration';
			testContacts.add(oppRegContact);
			insert testContacts;

			Deal_Registration__c deal = TestFactory.buildDealReg(
				'Test',
				'Deal',
				'testDeal' +
				Math.random() +
				'@tanium.com',
				'Test Company'
			);
			deal.End_Customer_Account_Segment__c = 'Emerging Enterprise';
			deal.Account__c = partnerAccount.Id;
			deal.wi_Partner_Contact__c = testContacts[2].Id;
			insert deal;
		}
	}

	@IsTest
	static void domainTest() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('test', 'Analyst');
			insert acc;

			Contact con = new Contact(
				LastName = 'testEmail',
				Email = 'test@email.test',
				AccountId = acc.Id
			);
			insert con;

			acc = [SELECT Id, Domain__c FROM Account WHERE Id = :acc.Id LIMIT 1];

			System.assertEquals('email.test', acc.Domain__c);
		}
	}

	@IsTest
	static void checkDeletePermission_WhenOppRegContact_RestrictDeletion() {
		String expectedError;

		Contact oppRegContact = [SELECT Id FROM Contact WHERE Name = 'Deal Registration' LIMIT 1];

		System.runAs(getContactDeleteRestrictedUser()) {
			Test.startTest();
			try {
				delete oppRegContact;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(
			expectedError.contains(System.Label.Contact_Deletion_Restricted),
			'Contact should not be allowed to be deleted'
		);
	}

	@IsTest
	static void checkDeletePermission_WhenCommunityUser_RestrictDeletion() {
		String expectedError;

		Contact communityContact = [SELECT Id FROM Contact WHERE Name = 'Community Contact' LIMIT 1];
		createCommunityUser(communityContact.Id);

		System.runAs(getContactDeleteRestrictedUser()) {
			Test.startTest();
			try {
				delete communityContact;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(
			expectedError.contains(System.Label.Contact_Deletion_Restricted),
			'Contact should not be allowed to be deleted'
		);
	}

	@IsTest
	static void checkDeletePermission_WhenPartnerAccount_RestrictDeletion() {
		String expectedError;

		Contact partnerContact = [SELECT Id FROM Contact WHERE Name = 'Partner Contact' LIMIT 1];

		System.runAs(getContactDeleteRestrictedUser()) {
			Test.startTest();
			try {
				delete partnerContact;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(
			expectedError.contains(System.Label.Contact_Deletion_Restricted),
			'Contact should not be allowed to be deleted'
		);
	}

	@IsTest
	static void checkDeletePermission_WhenUserWithoutRestriction_AllowDeletion() {
		String expectedError;

		Contact partnerContact = [SELECT Id FROM Contact WHERE Name = 'Partner Contact' LIMIT 1];
		System.runAs(getContactDeleteAllowedUser()) {
			Test.startTest();
			try {
				delete partnerContact;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(String.isBlank(expectedError), 'Contact was deleted, no exception thrown');
	}

	@IsTest
	static void checkDeletePermission_WhenUserWithPermissionSet_AllowContactDeletion() {
		String expectedError;

		Contact contact = [SELECT Id FROM Contact WHERE Name = 'Partner Contact' LIMIT 1];
		System.runAs(getContactDeleteAllowedUser()) {
			Test.startTest();
			try {
				delete contact;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(String.isBlank(expectedError), 'Contact deletion should be allowed');
	}

	static User getContactDeleteRestrictedUser() {
		User contactDeleteRestrictedUser = TestUserFactory.createTaniumStandardUser();
		insert contactDeleteRestrictedUser;
		TestingUtility.assignCustomPermission(
			contactDeleteRestrictedUser.Id,
			ContactTriggerService.CUSTOM_DELETE_RESTRICTION
		);

		return contactDeleteRestrictedUser;
	}

	static User getContactDeleteAllowedUser() {
		User contactDeleteAllowedUser = TestUserFactory.createTaniumAdminUser();
		contactDeleteAllowedUser.UserName = 'contactDeleteAllowedUser@tanium.test.com';
		insert contactDeleteAllowedUser;

		TestingUtility.assignCustomPermission(
			contactDeleteAllowedUser.Id,
			Constants.DELETE_LEADS_AND_CONTACTS_PERMISSION
		);
		return contactDeleteAllowedUser;
	}

	static void createCommunityUser(Id contactId) {
		Id communityProfileId = Utility.getProfileId('Customer Community User');
		User communityUser = TestUserFactory.createBasicUser(
			'TaniumCommunityUser',
			communityProfileId
		);
		communityUser.UserRoleId = null;
		communityUser.ContactId = contactId;
		insert communityUser;
	}
}