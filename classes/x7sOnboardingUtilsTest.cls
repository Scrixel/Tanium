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
public with sharing class x7sOnboardingUtilsTest {

	@TestSetup
	static void testSetup() {
		Contact testContact = x7sOnboardingTestUtils.createTestContact();
		System.assertNotEquals(null, testContact);
	}

	// Test building a formatted string from a set of strings
	@IsTest
	public static void testBuildStringFromSet() {
		Set<String> sourceSet = new Set<String>();
		sourceSet.add('Hello');
		sourceSet.add('There');
		System.assertEquals('Hello, There', x7sOnboardingUtils.buildStringFromSet(sourceSet)); // test that this is building a string from a set properly
	}

	@IsTest
	public static void testGetUser() {
		// Set up and run as a standard user
		List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sOnboardingTestConstants.STANDARD_EMAIL];

		User testUser = x7sOnboardingTestUtils.createStandardUserNoContact();
		try {
			testUser.ContactId = testContacts[0].Id;
			insert testUser;
		}
		catch (Exception e) {
			testUser.ContactId = null;
			insert testUser;
		}

		System.runAs(testUser) {
			System.assertEquals(testUser.Id, x7sOnboardingUtils.getUser().Id);
		}
	}

	@IsTest
	public static void testIsNullOrEmpty() {
		// Assert return true for empty list
		List<String> stringList = new List<String>();
		System.assertEquals(x7sOnboardingUtils.isNullOrEmpty(stringList), true);

		// Assert return false for not empty list
		stringList.add(x7sOnboardingTestConstants.ACCOUNT_NAME);
		System.assertEquals(x7sOnboardingUtils.isNullOrEmpty(stringList), false);
	}

	@IsTest
	public static void testGetSitePrefix() {
		System.assert(x7sOnboardingUtils.getSitePrefix() != null);
	}

	@IsTest
	public static void testCreateAttachment() {
		// Set up and run as a standard user
		List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sOnboardingTestConstants.STANDARD_EMAIL];

		User testUser = x7sOnboardingTestUtils.createStandardUserNoContact();
		try {
			testUser.ContactId = testContacts[0].Id;
			insert testUser;
		}
		catch (Exception e) {
			testUser.ContactId = null;
			insert testUser;
		}

		Attachment testAttachment = x7sOnboardingTestUtils.createAttachment(testUser.Id);
		System.assert(testAttachment != null);
	}

	@IsTest
	public static void testGetPicklistValues() {
		List<String> options = x7sOnboardingUtils.getPicklistValues('User', 'LanguageLocaleKey');
		System.assert(options.size() > 0);
	}

	@IsTest
	public static void testCreateListFromMultiPicklist() {

		String multiPicklistString = 'string1;string2;string3';

		List<String> multiPicklistList = x7sOnboardingUtils.createListFromMultiPicklist(multiPicklistString);

		System.assertEquals(multiPicklistList.get(0), 'string1');
		System.assertEquals(multiPicklistList.get(1), 'string2');
		System.assertEquals(multiPicklistList.get(2), 'string3');

	}

	@IsTest
	public static void testDoesStringContainListItem() {

		List<String> compareList = new List<String>();
		compareList.add('string1');
		compareList.add('string2');

		//Assert list contains target string
		System.assert(x7sOnboardingUtils.doesStringContainListItem(compareList, 'string1'));

		//Assert list does not contain target string
		System.assert(!x7sOnboardingUtils.doesStringContainListItem(compareList, 'string3'));
	}

	@IsTest
	public static void testisGuestUser() {
		// Set up and run as a standard user
		List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sOnboardingTestConstants.STANDARD_EMAIL];

		User testUser = x7sOnboardingTestUtils.createStandardUserNoContact();
		try {
			testUser.ContactId = testContacts[0].Id;
			insert testUser;
		}
		catch (Exception e) {
			testUser.ContactId = null;
			insert testUser;
		}

		System.runAs(testUser) {
			Boolean isGuest = x7sOnboardingUtils.isGuestUser();
			System.assertEquals(isGuest, false);
		}


		User testGuest = x7sOnboardingTestUtils.createGuestUser();
		System.runAs(testGuest) {
			Boolean isGuest = x7sOnboardingUtils.isGuestUser();
			System.assertEquals(isGuest, true);
		}
	}

	@IsTest
	public static void testgetFieldSchema() {
		// Super simple - just assert that the account keyset returns name. We know this will always be true
		System.assert(x7sOnboardingUtils.getFieldSchema('Account').containsKey('Name'));
	}

	@IsTest
	public static void testToIds() {
		// Set up and run as a standard user
		List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sOnboardingTestConstants.STANDARD_EMAIL];

		// Get IDs
		List<Id> toIds = x7sOnboardingUtils.toIds(testContacts, 'Id');

		// Assert that one ID has been added to the list!
		System.assertEquals(toIds.size(), 1);
	}

	@IsTest
	public static void testReplaceSpace() {
		System.assertEquals('Hi_Friend', x7sOnboardingUtils.replaceSpace('Hi Friend'));
	}
}