/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description x7sExp Test Utils
 */
@IsTest
public class x7sExpTestUtils {
	public static User createStandardUserNoContact() {
		List<Profile> standardProfileList = [
			SELECT Id
			FROM Profile
			WHERE Name = :x7sExpTestConstants.COMMUNITY_PROFILE
		];
		User testUser;
		if (!x7sExpUtils.isNullOrEmpty(standardProfileList)) {
			Profile standardProfile = standardProfileList[0];
			testUser = new User(
				Alias = x7sExpTestConstants.STANDARD_ALIAS,
				Email = x7sExpTestConstants.STANDARD_EMAIL,
				EmailEncodingKey = x7sExpTestConstants.ENCODING,
				FirstName = x7sExpTestConstants.FIRSTNAME,
				LastName = x7sExpTestConstants.LASTNAME,
				LanguageLocaleKey = x7sExpTestConstants.LOCALE,
				LocaleSidKey = x7sExpTestConstants.LOCALE,
				ProfileId = standardProfile.Id,
				TimeZoneSidKey = x7sExpTestConstants.TIMEZONE,
				Username = x7sExpTestConstants.STANDARD_USERNAME
			);
		}

		return testUser;
	}

	// Create a standard user
	public static User createStandardUser() {
		Contact contact = createTestContact();
		User testUser;

		List<Profile> standardProfileList = [
			SELECT Id
			FROM Profile
			WHERE Name = :x7sExpTestConstants.COMMUNITY_PROFILE
		];

		if (!x7sExpUtils.isNullOrEmpty(standardProfileList)) {
			Profile standardProfile = standardProfileList[0];
			testUser = new User(
				Alias = x7sExpTestConstants.STANDARD_ALIAS,
				Email = x7sExpTestConstants.STANDARD_EMAIL,
				EmailEncodingKey = x7sExpTestConstants.ENCODING,
				FirstName = x7sExpTestConstants.FIRSTNAME,
				LastName = x7sExpTestConstants.LASTNAME,
				LanguageLocaleKey = x7sExpTestConstants.LOCALE,
				LocaleSidKey = x7sExpTestConstants.LOCALE,
				ProfileId = standardProfile.Id,
				TimeZoneSidKey = x7sExpTestConstants.TIMEZONE,
				Username = x7sExpTestConstants.STANDARD_USERNAME
			);
			testUser.ContactId = contact.Id;
		}

		return testUser;
	}

	// Create a guest user
	public static User createGuestUser() {
		List<Profile> standardProfileList;
		User guestUser;

		try {
			standardProfileList = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
		} catch (DmlException e) {
			System.debug(e);
		}

		if (!x7sExpUtils.isNullOrEmpty(standardProfileList)) {
			Profile standardProfile = standardProfileList[0];
			guestUser = new User(
				Alias = x7sExpTestConstants.GUEST_ALIAS,
				Email = x7sExpTestConstants.GUEST_EMAIL,
				EmailEncodingKey = x7sExpTestConstants.ENCODING,
				FirstName = x7sExpTestConstants.FIRSTNAME,
				LastName = x7sExpTestConstants.LASTNAME,
				LanguageLocaleKey = x7sExpTestConstants.LOCALE,
				LocaleSidKey = x7sExpTestConstants.LOCALE,
				ProfileId = standardProfile.Id,
				TimeZoneSidKey = x7sExpTestConstants.TIMEZONE,
				Username = x7sExpTestConstants.GUEST_USERNAME
			);
		}

		return guestUser;
	}

	// Create an account so we can create a Contact
	public static Account createTestAccount() {
		List<Account> account = [SELECT Id FROM Account WHERE Name = :x7sExpTestConstants.ACCOUNT_NAME];
		Account acc;

		if (x7sExpUtils.isNullOrEmpty(account)) {
			acc = new Account(Name = x7sExpTestConstants.ACCOUNT_NAME, NumberOfEmployees = 5000);
			insert acc;
		} else {
			acc = account[0];
		}

		return acc;
	}

	// Create a contact associated with an account
	public static Contact createTestContact() {
		List<Contact> contact = [
			SELECT Id
			FROM Contact
			WHERE Email = :x7sExpTestConstants.STANDARD_EMAIL
		];
		Contact con;

		Account account = createTestAccount();

		if (x7sExpUtils.isNullOrEmpty(contact)) {
			con = new Contact(
				FirstName = x7sExpTestConstants.FIRSTNAME,
				LastName = x7sExpTestConstants.LASTNAME,
				Email = x7sExpTestConstants.STANDARD_EMAIL
			);
			con.AccountId = account.Id;
			insert con;
		} else {
			con = contact[0];
		}

		return con;
	}

	// Create an attachment
	public static Attachment createAttachment(Id parentId) {
		Attachment attachment = new Attachment();
		Blob bodyBlob = Blob.valueOf('');
		attachment.ParentId = parentId;
		attachment.Body = bodyBlob;
		attachment.Name = x7sExpTestConstants.FIRSTNAME;
		return attachment;
	}

	// Fake ID x7sExpTestUtils.getFakeId(User.SObjectType));
	public static String getFakeId(Schema.SObjectType sot) {
		Integer s_num = 1;
		String result = String.valueOf(s_num++);
		return sot.getDescribe().getKeyPrefix() + '0'.repeat(12 - result.length()) + result;
	}

	// Internal Chatter Group (No Network Id)
	public static CollaborationGroup createChatterGroup(String groupName, String collaborationType) {
		CollaborationGroup testGroup = new CollaborationGroup(
			Name = groupName,
			CollaborationType = collaborationType
		);
		return testGroup;
	}
}