/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public class x7sIdeasUtilityTest {
	public static final String TEST_USER_LASTNAME = 'X7S_Testing';
	public static final String PORTAL_USER_LASTNAME = 'x7s_LastName';

	@IsTest
	static void test_getNameSpacePrefix() {
		String nameSpace = x7sIdeasUtility.getNameSpacePrefix();
		System.assertNotEquals(null, nameSpace);
	}

	@IsTest
	static void test_getZoneId() {
		List<Community> currCommunity = [SELECT Id, Name FROM Community];
		String zoneId = x7sIdeasUtility.getZoneId(currCommunity[0].Name);
		System.assertNotEquals(null, zoneId);
	}

	@IsTest
	static void test_profileMember() {
		User u = createStandardTestUser();
		System.runAs(u) {
			System.assertEquals(
				true,
				x7sIdeasUtility.profileMember(u.Id, 'System Administrator, Community User')
			);
		}
	}

	@IsTest
	static void test_parseFieldValueString() {
		String testFieldString = 'field1:value1';
		Map<String, String> mapPair = x7sIdeasUtility.parseFieldValueString(testFieldString);
		System.assertNotEquals(null, mapPair);
		System.assertEquals(true, mapPair.containsKey('field1'));
	}

	@IsTest
	public static void test_permissionSetMember() {
		User u = createStandardTestUser();
		System.runAs(u) {
			System.assertEquals(
				false,
				x7sIdeasUtility.permissionSetMember(u.Id, 'Permission Set `, Permission Set 2')
			);
		}
	}

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Utility functions

	public static String DEFAULT_PROFILE_NAME {
		get {
			List<X7S_Ideas_Setting__mdt> setting = [
				SELECT Id, Default_Test_Profile__c
				FROM X7S_Ideas_Setting__mdt
				WHERE DeveloperName = 'Default'
			];
			if (setting != null && setting.size() > 0) {
				return setting[0].Default_Test_Profile__c;
			}

			return 'Customer Community User Login';
		}
	}

	public static String DEFAULT_STANDARD_PROFILE {
		get {
			return 'System Administrator';
		}
	}

	public static User createStandardTestUser() {
		Profile p = [SELECT Id FROM Profile WHERE Name = :DEFAULT_STANDARD_PROFILE];

		User newUser = new User(
			ProfileId = p.Id,
			Username = 'x7s_standarduser@CCIDEASLC.com',
			LastName = TEST_USER_LASTNAME,
			Alias = 'standt',
			Email = 'x7s_standarduser@testorg.com',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'America/Los_Angeles'
		);

		newUser = x7sIdeasUtility.setCustomUserFields(newUser);
		insert newUser;

		System.assertNotEquals(null, newUser);
		System.debug('Standard user: ');
		System.debug(newUser);

		return newUser;
	}

	public static User createPortalTestUser() {
		// Create Portal User
		Account acc = new Account(Name = 'newAcc1', NumberOfEmployees = 10);
		insert acc;

		Contact con = new Contact(AccountId = acc.Id, LastName = PORTAL_USER_LASTNAME);
		insert con;

		System.debug('Default User Profile: ' + DEFAULT_PROFILE_NAME);
		Profile p = [SELECT Id FROM Profile WHERE Name = :DEFAULT_PROFILE_NAME];

		User newUser = new User(
			ProfileId = p.Id,
			ContactId = con.Id,
			Username = 'newUser@x7s.com',
			LastName = PORTAL_USER_LASTNAME,
			Alias = 'xnuser',
			Email = 'x7s_pb@testorg.com',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'America/Los_Angeles'
		);

		newUser = x7sIdeasUtility.setCustomUserFields(newUser);
		insert newUser;

		System.assertNotEquals(null, newUser);
		System.debug('Portal user: ');
		System.debug(newUser);

		return newUser;
	}

	@IsTest
	public static void testNickNameDisplayed() {
		Boolean display = x7sIdeasUtility.isNicknameDisplayEnabled();
		System.debug('Nickname displayed: ' + display);
		System.assertNotEquals(null, display);
	}

	@IsTest
	static void testGetThemeCategories() {
		System.assertNotEquals(null, x7sIdeasUtility.getThemeCategories('Theme 1'));
	}

	@IsTest
	static void test_getIdeaCategoryValues() {
		System.assertNotEquals(null, x7sIdeasUtility.getIdeaCategoryValues());
	}

	@IsTest
	static void test_getSitePrefix() {
		System.assertEquals('', x7sIdeasUtility.getSitePrefix(), 'Invalid SitePrefix');
	}

	@IsTest
	static void test_IsReadOnly() {
		System.assertEquals(
			false,
			x7sIdeasUtility.IsReadOnly(),
			'Current Profile should not be Read Only'
		);
	}
}