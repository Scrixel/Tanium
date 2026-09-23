/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@SuppressWarnings('PMD.ApexUnitTestShouldNotUseSeeAllDataTrue')
@IsTest
public class x7sEventsImageControllerTest {
	private static final String RELATED_FILES = 'Related File';
	private static final String STATIC_RESOURCE = 'Static Resource';
	private static final String EXTERNAL_URL = 'External URL';

	@IsTest
	static void testGetImageTypes() {
		Map<String, String> imageTypeMap = x7sEventsImageController.getImageTypes();

		System.assertNotEquals(null, imageTypeMap, 'There must be image types.');

		User communityUser = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE
		);

		System.runAs(communityUser) {
			Test.startTest();
			Map<String, String> imageTypes = x7sEventsImageController.getImageTypes();
			System.assertEquals(false, imageTypes.isEmpty(), 'There must be an image type.');

			Test.stopTest();
		}
	}

	@IsTest(SeeAllData=true)
	static void testGetCMSImageForCommunity() {
		Test.startTest();
		x7sEventsCMSHelper eventsCMSHelperMock = (x7sEventsCMSHelper) x7sEventsImageMockUtil.createMock(
			x7sEventsCMSHelper.class
		);
		Map<String, String> imageURLMap;
		List<String> contentIds = new List<String>();
		Map<Id, String> eventsWithCMSImage = new Map<Id, String>();

		contentIds.add(x7sEventsTestConstants.TEST_CMS_ID_1);
		contentIds.add(x7sEventsTestConstants.TEST_CMS_ID_2);

		// Test with empty events with CMS Image map.
		imageURLMap = x7sEventsImageController.callCMSUtilities(
			eventsWithCMSImage,
			contentIds,
			null,
			eventsCMSHelperMock
		);
		System.assertEquals(1, imageURLMap.size(), 'Should return one item');

		eventsWithCMSImage.put(
			x7sEventsTestConstants.TEST_CMS_ID_1,
			x7sEventsTestConstants.TEST_CMS_ID_1
		);
		eventsWithCMSImage.put(
			x7sEventsTestConstants.TEST_CMS_ID_2,
			x7sEventsTestConstants.TEST_CMS_ID_2
		);

		// Test with populated events with CMS image map and Test Community Id.
		imageURLMap = x7sEventsImageController.callCMSUtilities(
			eventsWithCMSImage,
			contentIds,
			x7sEventsTestConstants.TEST_COMMUNITY_ID,
			eventsCMSHelperMock
		);
		System.assertEquals(1, imageURLMap.size(), 'Should return one item');

		// Test with populated events with CMS image map and no community id.
		imageURLMap = x7sEventsImageController.callCMSUtilities(
			eventsWithCMSImage,
			contentIds,
			null,
			eventsCMSHelperMock
		);
		System.assertEquals(1, imageURLMap.size(), 'Should return one item');

		// Test with non-mocked Connect API.
		imageURLMap = x7sEventsImageController.getCMSImageURL(eventsWithCMSImage, contentIds);
		System.assertEquals(0, imageURLMap.size(), 'Should return zero items');

		imageURLMap = x7sEventsImageController.callCMSUtilities(
			eventsWithCMSImage,
			contentIds,
			x7sEventsTestConstants.TEST_COMMUNITY_ID,
			new x7sEventsCMSHelper()
		);
		Test.stopTest();
	}

	@IsTest
	static void testGetImageURL() {
		Test.startTest();

		List<Topic> topics = x7sEventsUtility.createTopic(1);
		System.assertEquals(1, topics.size(), 'Should return 1 topic');

		X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = 'UnitTestEvent';
		objEvent.Start_DateTime__c = System.today();
		objEvent.End_DateTime__c = System.today().addDays(5);
		objEvent.Details__c = 'Event Details is here.';
		objEvent.Location_Name__c = 'Test Location';
		objEvent.Enable_RSVP__c = false;
		objEvent.Image_Type__c = STATIC_RESOURCE;
		objEvent.Image_Reference__c = 'UnitTestResource/test.jpg';

		x7sEventsListController.saveEvents(objEvent, topics[0].Id, '');
		System.assertNotEquals(null, objEvent.Id, 'Object should have an Id');

		List<X7S_Event__c> eventList = [
			SELECT Id, Image_Type__c, Image_Reference__c
			FROM X7S_Event__c
			WHERE Id = :objEvent.Id
		];

		Map<Id, String> eventToImageURLMap = x7sEventsImageController.getImageURL(eventList);
		System.assertEquals(1, eventToImageURLMap.size(), 'Should return a single image entry');

		Test.stopTest();
	}

	@IsTest
	static void test_saveImageExternalUrl() {
		Test.startTest();

		List<Topic> topics = x7sEventsUtility.createTopic(1);
		System.assertEquals(1, topics.size(), 'Should return 1 topic');

		X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = 'UnitTestEvent';
		objEvent.Start_DateTime__c = System.today();
		objEvent.End_DateTime__c = System.today().addDays(5);
		objEvent.Details__c = 'Event Details is here.';
		objEvent.Location_Name__c = 'Test Location';
		objEvent.Enable_RSVP__c = false;
		objEvent.Image_Type__c = EXTERNAL_URL;
		objEvent.Image_Reference__c = 'UnitTestResource/test.jpg';

		x7sEventsListController.saveEvents(objEvent, topics[0].Id, '');
		System.assertNotEquals(null, objEvent.Id, 'Should return an object that has an id');

		List<X7S_Event__c> eventList = [
			SELECT Id, Image_Type__c, Image_Reference__c
			FROM X7S_Event__c
			WHERE Id = :objEvent.Id
		];

		Map<Id, String> eventToImageURLMap = x7sEventsImageController.getImageURL(eventList);
		System.assertEquals(1, eventToImageURLMap.size(), 'Should return a single image entry');

		Test.stopTest();
	}

	@IsTest
	static void test_saveRelatedFile() {
		Test.startTest();
		List<Topic> topics = x7sEventsUtility.createTopic(1);
		System.assertEquals(1, topics.size(), 'Should return 1 topic');

		X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = 'UnitTestEvent';
		objEvent.Start_DateTime__c = System.today();
		objEvent.End_DateTime__c = System.today().addDays(5);
		objEvent.Details__c = 'Event Details is here.';
		objEvent.Location_Name__c = 'Test Location';
		objEvent.Enable_RSVP__c = false;
		objEvent.Image_Type__c = RELATED_FILES;

		x7sEventsListController.saveEvents(objEvent, topics[0].Id, '');
		System.assertNotEquals(null, objEvent.Id, 'Should return an object that has an id');

		ContentDocumentLink contentDoc = x7sEventsListController.saveRelatedFile(
			objEvent.Id,
			'Attachment1.jpg',
			'This is test image'
		);
		System.assertNotEquals(null, contentDoc.Id, 'Should return an object that has an id');

		List<X7S_Event__c> eventList = [
			SELECT Id, Image_Type__c, Image_Reference__c
			FROM X7S_Event__c
			WHERE Id = :objEvent.Id
		];

		Map<Id, String> eventToImageURLMap = x7sEventsImageController.getImageURL(eventList);
		System.assertEquals(1, eventToImageURLMap.size(), 'Should return a single image entry');

		Test.stopTest();
	}
}