/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpMyAccountTeamControllerTest {
	private static User testCommunityUser;
	private static User testStandardUser;

	@IsTest
	public static void setupTestData() {
		//Create Test Community User with Contact and Account
		testCommunityUser = x7sExpTestUtils.createStandardUser();
		try {
			insert testCommunityUser;
		}
		catch (Exception e) {
			testCommunityUser.ContactId = null;
			insert testCommunityUser;
		}

		testStandardUser = x7sExpTestUtils.createGuestUser();
		insert testStandardUser;
		System.assertNotEquals(testStandardUser.Id, 'Guest user not created');
	}
	@IsTest
	public static void getAccountTeam() {
		setupTestData();
		x7sExpResponse testResponse = new x7sExpResponse();

		// Run as user without a contact ID
		System.runAs(testStandardUser) {
			testResponse = x7sExpMyAccountTeamController.getAccountTeam();
			System.assertEquals(testResponse.messages[0], Label.x7sExpLabelNoContactId, 'Message expected');
		}
	}

	@IsTest
	public static void testQueryAccountTeams() {

		List<Contact> testContactList = new List<Contact>();
		testContactList.add(x7sExpTestUtils.createTestContact());

		x7sExpResponse expResponse = x7sExpMyAccountTeamController.queryAccountTeams(testContactList);

		Schema.SObjectType targetType = Schema.getGlobalDescribe().get('AccountTeamMember');
		if (targetType != null) {
			System.assertEquals(expResponse.messages.size(), 0, 'Expected 0 messages');
		}
		else {
			System.assertEquals(expResponse.messages.size(), 1, 'Expected 1 message');
		}
	}
}