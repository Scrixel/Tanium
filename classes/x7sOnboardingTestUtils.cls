/*
 * Licensed Materials - Property of IBM
 * 6949-82D
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

// =====================
// Onboarding Test Utils
// =====================
@IsTest
public class x7sOnboardingTestUtils {
	public static User createStandardUserNoContact() {
		List<Profile> standardProfileList = [
			SELECT Id
			FROM Profile
			WHERE Name = :x7sOnboardingTestConstants.COMMUNITY_PROFILE
		];
		User testUser;
		if (!x7sOnboardingUtils.isNullOrEmpty(standardProfileList)) {
			Profile standardProfile = standardProfileList[0];
			testUser = new User(
				Alias = x7sOnboardingTestConstants.STANDARD_ALIAS,
				Email = x7sOnboardingTestConstants.STANDARD_EMAIL,
				EmailEncodingKey = x7sOnboardingTestConstants.ENCODING,
				FirstName = x7sOnboardingTestConstants.FIRSTNAME,
				LastName = x7sOnboardingTestConstants.LASTNAME,
				LanguageLocaleKey = x7sOnboardingTestConstants.LOCALE,
				LocaleSidKey = x7sOnboardingTestConstants.LOCALE,
				ProfileId = standardProfile.Id,
				TimeZoneSidKey = x7sOnboardingTestConstants.TIMEZONE,
				Username = x7sOnboardingTestConstants.STANDARD_USERNAME
			);
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

		if (!x7sOnboardingUtils.isNullOrEmpty(standardProfileList)) {
			Profile standardProfile = standardProfileList[0];
			guestUser = new User(
				Alias = x7sOnboardingTestConstants.GUEST_ALIAS,
				Email = x7sOnboardingTestConstants.GUEST_EMAIL,
				EmailEncodingKey = x7sOnboardingTestConstants.ENCODING,
				FirstName = x7sOnboardingTestConstants.FIRSTNAME,
				LastName = x7sOnboardingTestConstants.LASTNAME,
				LanguageLocaleKey = x7sOnboardingTestConstants.LOCALE,
				LocaleSidKey = x7sOnboardingTestConstants.LOCALE,
				ProfileId = standardProfile.Id,
				TimeZoneSidKey = x7sOnboardingTestConstants.TIMEZONE,
				Username = x7sOnboardingTestConstants.GUEST_USERNAME
			);
		}

		return guestUser;
	}

	// Create an account so we can create a Contact
	public static Account createTestAccount() {
		Account account = new Account(
			Name = x7sOnboardingTestConstants.ACCOUNT_NAME,
			NumberOfEmployees = 10
		);
		insert account;
		return account;
	}

	// Create a contact associated with an account
	public static Contact createTestContact() {
		Account account = createTestAccount();
		Contact contact = new Contact(
			FirstName = x7sOnboardingTestConstants.FIRSTNAME,
			LastName = x7sOnboardingTestConstants.LASTNAME,
			Email = x7sOnboardingTestConstants.STANDARD_EMAIL
		);
		contact.AccountId = account.Id;
		insert contact;

		return contact;
	}

	// Create an attachment
	public static Attachment createAttachment(Id parentId) {
		Attachment attachment = new Attachment();
		Blob bodyBlob = Blob.valueOf('');
		attachment.ParentId = parentId;
		attachment.Body = bodyBlob;
		attachment.Name = x7sOnboardingTestConstants.FIRSTNAME;
		return attachment;
	}
}