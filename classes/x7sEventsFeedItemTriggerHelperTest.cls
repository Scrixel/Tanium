/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
@SuppressWarnings('PMD.ApexUnitTestShouldNotUseSeeAllDataTrue')
@IsTest
public with sharing class x7sEventsFeedItemTriggerHelperTest {
	private static final String TEST_EVENT_NAME = 'Sample Feed Item Event';
	private static final String TEST_BODY = 'Sample Feed Body';
	private static final String ORGANIZER_USER_NAME = 'eventOrganizer@testing.com';
	private static final String COMMUNITY_USER_NAME = 'eventUser@testing.com';

	@IsTest
	public static void testWithoutNotification() {
		//Create Community User
		//As we are using custom object News, we have created user with a CUSTOM Community Profile,
		//Because standard community profile do not allow to give permissions to custom objects.
		User communityUser = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE,
			ORGANIZER_USER_NAME,
			false
		);
		User userOrganizer = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE,
			COMMUNITY_USER_NAME,
			false
		);

		// Create event with an event organizer
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventRecord(
			TEST_EVENT_NAME,
			userOrganizer.Id
		);
		System.assertEquals(eventList.size(), 1, 'Incorrect events count found.');

		System.runAs(communityUser) {
			Test.startTest();

			// Create Feed item
			FeedItem testFeedItem = new FeedItem(
				ParentId = eventList[0].Id,
				Type = 'ContentPost',
				Body = TEST_BODY
			);

			insert testFeedItem;

			// Check the feed item content
			FeedItem updatedFeedItem = [SELECT Id, Body FROM FeedItem WHERE Id = :testFeedItem.Id];

			System.debug(updatedFeedItem.Body);

			System.assertEquals(TEST_BODY, updatedFeedItem.Body, 'Feed item is not updated correctly');

			Test.stopTest();
		}
	}

	@IsTest
	public static void testOnUserObject() {
		//Create Community User
		//As we are using custom object News, we have created user with a CUSTOM Community Profile,
		//Because standard community profile do not allow to give permissions to custom objects.
		User communityUser = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE,
			ORGANIZER_USER_NAME,
			false
		);

		System.runAs(communityUser) {
			Test.startTest();

			// Create Feed item
			FeedItem testFeedItem = new FeedItem(
				ParentId = communityUser.Id,
				Type = 'ContentPost',
				Body = TEST_BODY
			);

			insert testFeedItem;

			// Check the feed item content
			FeedItem updatedFeedItem = [SELECT Id, Body FROM FeedItem WHERE Id = :testFeedItem.Id];

			System.debug(updatedFeedItem.Body);

			System.assertEquals(TEST_BODY, updatedFeedItem.Body, 'Feed item is not updated correctly');

			Test.stopTest();
		}
	}

	@IsTest(SeeAllData=true)
	public static void testWithNotification() {
		//Create Community User
		//As we are using custom object News, we have created user with a CUSTOM Community Profile,
		//Because standard community profile do not allow to give permissions to custom objects.
		User communityUser = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE,
			ORGANIZER_USER_NAME,
			false
		);
		User userOrganizer = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE,
			COMMUNITY_USER_NAME,
			true
		);

		// Create event with an event organizer
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventRecord(
			TEST_EVENT_NAME,
			userOrganizer.Id
		);
		System.assertEquals(eventList.size(), 1, 'Incorrect events count found.');

		System.runAs(communityUser) {
			Test.startTest();

			// Create Feed item
			FeedItem testFeedItem = new FeedItem(
				ParentId = eventList[0].Id,
				Type = 'ContentPost',
				Body = TEST_BODY
			);

			insert testFeedItem;

			// Check the feed item content
			FeedItem updatedFeedItem = [SELECT Id, Body FROM FeedItem WHERE Id = :testFeedItem.Id];

			// Verify that post contains a mention to the organizer.
			System.assertEquals(
				true,
				updatedFeedItem.Body.contains('@Test'),
				'Feed item is not created correctly.'
			);
			System.assertEquals(
				true,
				updatedFeedItem.Body.contains(System.Label.x7sEventsMentionText),
				'Feed item is not created correctly.'
			);

			Test.stopTest();
		}
	}
}