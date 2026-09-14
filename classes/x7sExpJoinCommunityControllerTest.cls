/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sExpJoinCommunityControllerTest {
	@testSetup
	public static void setupTestData() {
		TriggerHandler.bypass(new List<String>{ 'ContactTriggerHandler', 'AccountTriggerHandler' });
		x7sExpTestUtils.createTestContact();
	}

	@IsTest
	public static void testGetUsersWithPublicPhotos() {
		List<User> allUsers = [
			SELECT Id, UserPreferencesShowProfilePicToGuestUsers
			FROM User
			WHERE UserPreferencesShowProfilePicToGuestUsers = TRUE
			LIMIT 5
		];

		// Mark all users as not allowing guest access to their photo
		for (User thisUser : allUsers) {
			thisUser.UserPreferencesShowProfilePicToGuestUsers = false;
		}
		update allUsers;

		/* Get User list. This will initially find 0 because there are now no users with public photos.
		 * However, the function builds up a list of empty users for us!
		 */
		List<User> userList = x7sExpJoinCommunityController.getUsersWithPublicPhotos('2');

		System.assertEquals(2, userList.size());
	}

	@IsTest
	public static void testGetUsersWithPublicPhotos_CatchBlock() {
		Boolean exceptionThrown = false;
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });
		Contact con = [
			SELECT Id
			FROM Contact
			WHERE Email = :x7sExpTestConstants.STANDARD_EMAIL
			LIMIT 1
		];

		Test.startTest();
		System.runAs(createCommunityUser(con.Id)) {
			try {
				List<User> userList = x7sExpJoinCommunityController.getUsersWithPublicPhotos('2147483650');
			} catch (Exception e) {
				exceptionThrown = true;
			}
		}
		Test.stopTest();
		System.assertEquals(true, exceptionThrown);
	}

	private static User createCommunityUser(Id contactId) {
		Id communityProfileId = Utility.getProfileId('Tanium Community Login Unknown');
		User communityUser = TestUserFactory.createBasicUser('TaniumCommunityUser', communityProfileId);
		communityUser.UserRoleId = null;
		communityUser.ContactId = contactId;
		return communityUser;
	}
}