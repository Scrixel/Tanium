/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsSegmentControllerTest {
	private static final String TEST_EVENT_NAME = 'Test Event With Segments';
	private static final Integer IN_PERSON_CAPACITY = 50;
	private static final Integer VIRTUAL_CAPACITY = 50;

	@IsTest
	public static void testLoadSaveSegments() {
		Test.startTest();

		List<Topic> topics = x7sEventsUtility.createTopic(1001);
		System.assertEquals(topics.size(), 1001);

		//check save event
		X7S_Event__c eventObj = new X7S_Event__c(
			Name = TEST_EVENT_NAME,
			Start_DateTime__c = System.today().addDays(2),
			End_DateTime__c = System.today().addDays(5)
		);
		insert eventObj;

		x7sEventsUtility.createTopicAssignment(topics[0].Id, eventObj.Id);

		x7sEventsListController.saveEvents(eventObj, topics[0].Id, '');
		System.assertNotEquals(eventObj.Id, null);

		// Segments
		List<x7sEventsSegmentWrapper> segments = new List<x7sEventsSegmentWrapper>();

		// Create In Person
		x7sEventsSegmentWrapper inPersonWrapper = new x7sEventsSegmentWrapper();

		inPersonWrapper.eventId = eventObj.Id;
		inPersonWrapper.Segment = x7sEventsSegmentController.SEGMENT_IN_PERSON;
		inPersonWrapper.TrackCapacity = true;
		inPersonWrapper.WaitList = true;
		inPersonWrapper.Capacity = IN_PERSON_CAPACITY;
		inPersonWrapper.RegistrationSetting = '';

		segments.add(inPersonWrapper);

		// Create Virtual
		x7sEventsSegmentWrapper virtualWrapper = new x7sEventsSegmentWrapper();

		virtualWrapper.eventId = eventObj.Id;
		virtualWrapper.Segment = x7sEventsSegmentController.SEGMENT_VIRTUAL;
		virtualWrapper.TrackCapacity = true;
		virtualWrapper.WaitList = true;
		virtualWrapper.Capacity = VIRTUAL_CAPACITY;
		virtualWrapper.RegistrationSetting = '';

		segments.add(virtualWrapper);

		// Save Segments
		x7sEventsSegmentController.updateSegments(segments);

		// Load Segments
		List<x7sEventsSegmentWrapper> loadedSegments = x7sEventsSegmentController.loadSegments(
			eventObj.Id
		);

		System.assertEquals(2, loadedSegments.size(), 'Verify there are 2 segments');

		if (loadedSegments[0].Segment == x7sEventsSegmentController.SEGMENT_VIRTUAL) {
			validateVirtualSegment(loadedSegments[0]);
			validateInPersonSegment(loadedSegments[1]);
		} else {
			validateVirtualSegment(loadedSegments[1]);
			validateInPersonSegment(loadedSegments[0]);
		}

		Test.stopTest();
	}

	private static void validateVirtualSegment(x7sEventsSegmentWrapper virtualSegment) {
		System.assertEquals(
			x7sEventsSegmentController.SEGMENT_VIRTUAL,
			virtualSegment.Segment,
			'Verify Segment Type'
		);
		System.assertEquals(VIRTUAL_CAPACITY, virtualSegment.Capacity, 'Verify capacity');
		System.assertEquals(true, virtualSegment.TrackCapacity, 'Verify track capacity');
		System.assertEquals(true, virtualSegment.WaitList, 'Verify Wait list');
	}

	private static void validateInPersonSegment(x7sEventsSegmentWrapper inPersonSegment) {
		System.assertEquals(
			x7sEventsSegmentController.SEGMENT_IN_PERSON,
			inPersonSegment.Segment,
			'Verify Segment Type'
		);
		System.assertEquals(IN_PERSON_CAPACITY, inPersonSegment.Capacity, 'Verify capacity');
		System.assertEquals(true, inPersonSegment.TrackCapacity, 'Verify track capacity');
		System.assertEquals(true, inPersonSegment.WaitList, 'Verify Wait list');
	}
}