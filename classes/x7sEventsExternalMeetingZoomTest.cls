/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsExternalMeetingZoomTest {
	private static final String TEST_EVENT_NAME = 'Test Event';
	private static final String TEST_EVENT_CREATE_MESSAGE = 'There must be event created.';
	private static final String TEST_MEETING_ID = '123';
	private static final String TEST_TOPIC = '"topic":"Sample Webinar Test",';
	private static final String TEST_START_TIME = '"start_time":"2021-03-31T14:30:00Z",';
	private static final String TEST_DURATION = '"duration":120,';
	private static final String TEST_TIMEZONE = '"timezone":"America/Chicago",';
	private static final String TEST_AGENDA = '"agenda":"<p>Sample Webinar Agenda</p>",';
	private static final String TEST_SETTINGS = '"settings": {';
	private static final String CLOSING_CURLY_BRACKET = '}';
	private static final String OPENING_CURLY_BRACKET = '{';
	private static final String PAGE_COUNT = '"page_count": 2,';
	private static final String PAGE_SIZE = '"page_size": 1,';
	private static final String PAGE_TOTAL_RECORDS = '"total_records": 2,';

	@TestSetup
	static void testSetup() {
		X7S_Event__c testEvent = new X7S_Event__c(Name = TEST_EVENT_NAME);

		testEvent.Start_DateTime__c = DateTime.now();
		testEvent.End_DateTime__c = Datetime.now().addHours(2);
		testEvent.Details__c = 'Sample Event';

		insert testEvent;
	}

	@IsTest
	static void testExternalMeetingFactory() {
		x7sEventsIExternalMeeting externalMeeting;
		X7S_Event__c event = new X7S_Event__c();

		// Check default
		externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(event);

		System.assertEquals(true, externalMeeting instanceof x7sEventsExternalMeetingDefault);

		// Check Zoom
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;

		externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(event);

		System.assertEquals(true, externalMeeting instanceof x7sEventsExternalMeetingZoom);
	}

	/**
	 *  @description Meeting Tests.
	 */

	@IsTest
	static void testCreateZoomMeetingSuccess() {
		Integer responseCode = 201;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		X7S_Event__c event = getEvent();
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		createMeeting(event, true);

		event.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;

		createMeeting(event, true);

		event.Registration__c = x7sEventsExternalMeetingConstants.MANUAL_APPROVAL;

		createMeeting(event, true);
		List<X7S_Event__c> eventList = [SELECT Id FROM X7S_Event__c LIMIT 5];
		System.assertEquals(false, eventList.isEmpty(), TEST_EVENT_CREATE_MESSAGE);

		Test.stopTest();
	}

	@IsTest
	static void testCreateZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;

		createMeeting(event, false);

		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;

		createMeeting(event, false);
		List<X7S_Event__c> eventList = [SELECT Id FROM X7S_Event__c LIMIT 5];
		System.assertEquals(false, eventList.isEmpty(), TEST_EVENT_CREATE_MESSAGE);

		Test.stopTest();
	}

	static void createMeeting(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.create(event);

		System.debug('response: ' + externalMeetingResponse);
		System.assertEquals(success, externalMeetingResponse.isSuccess());

		if (success) {
			System.assertNotEquals('', externalMeetingResponse.getResult());
		} else {
			System.assertNotEquals('', externalMeetingResponse.getError());
		}
	}

	@IsTest
	static void testUpdateZoomMeetingSuccess() {
		Integer responseCode = 204;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);

		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		updateMeeting(event, true);

		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;
		updateMeeting(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testUpdateZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;

		updateMeeting(event, false);

		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;

		updateMeeting(event, false);

		Test.stopTest();
	}

	static void updateMeeting(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting, 'External Meeting must not be null.');

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.updateExternal(event);

		System.assertEquals(
			success,
			externalMeetingResponse.isSuccess(),
			'Incorrect external meeting response.'
		);

		if (success) {
			System.assertNotEquals(
				'',
				externalMeetingResponse.getResult(),
				'External meeting response can not be null.'
			);
		} else {
			System.assertNotEquals(
				'',
				externalMeetingResponse.getError(),
				'There should be error response.'
			);
		}
	}

	@IsTest
	static void testGetMeetingZoomMeetingNoRegSuccess() {
		Integer responseCode = 200;

		Test.startTest();
		String sampleBody =
			OPENING_CURLY_BRACKET +
			TEST_TOPIC +
			TEST_START_TIME +
			TEST_DURATION +
			TEST_TIMEZONE +
			TEST_AGENDA +
			TEST_SETTINGS +
			'        "approval_type": 2' +
			CLOSING_CURLY_BRACKET +
			CLOSING_CURLY_BRACKET;

		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode, sampleBody));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		getMeeting(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetMeetingZoomMeetingAutoSuccess() {
		Integer responseCode = 200;

		Test.startTest();
		String sampleBody =
			OPENING_CURLY_BRACKET +
			TEST_TOPIC +
			TEST_START_TIME +
			TEST_DURATION +
			TEST_TIMEZONE +
			TEST_AGENDA +
			TEST_SETTINGS +
			'        "approval_type": 0' +
			CLOSING_CURLY_BRACKET +
			CLOSING_CURLY_BRACKET;

		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode, sampleBody));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		getMeeting(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetMeetingZoomMeetingManualSuccess() {
		Integer responseCode = 200;

		Test.startTest();
		String sampleBody =
			OPENING_CURLY_BRACKET +
			TEST_TOPIC +
			TEST_START_TIME +
			TEST_DURATION +
			TEST_TIMEZONE +
			TEST_AGENDA +
			TEST_SETTINGS +
			'        "approval_type": 1' +
			CLOSING_CURLY_BRACKET +
			CLOSING_CURLY_BRACKET;

		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode, sampleBody));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		getMeeting(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetMeetingZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;

		getMeeting(event, false);

		event.MeetingId__c = TEST_MEETING_ID;
		getMeeting(event, false);

		Test.stopTest();
	}

	static void getMeeting(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.get(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testDeleteZoomMeetingSuccess() {
		Integer responseCode = 204;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		deleteMeeting(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testDeleteZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;

		deleteMeeting(event, false);

		event.MeetingId__c = TEST_MEETING_ID;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;
		deleteMeeting(event, false);

		Test.stopTest();
	}

	static void deleteMeeting(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.deleteExternal(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testAddMeetingRegistrantZoomMeetingSuccess() {
		Integer responseCode = 201;
		X7S_Event_RSVP__c eventRSVP = new X7S_Event_RSVP__c();
		String sampleBody =
			OPENING_CURLY_BRACKET +
			'    "id":"1234",' +
			TEST_START_TIME +
			'    "join_url":"http://Sample.url",' +
			'    "registrant_id":"Sample id"' +
			CLOSING_CURLY_BRACKET;

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;
		event.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;

		X7S_Event_Segment__c testSegment = new X7S_Event_Segment__c();
		testSegment.Segment__c = x7sEventsSegmentController.SEGMENT_VIRTUAL;
		testSegment.Wait_list__c = false;
		testSegment.Event__c = event.Id;

		insert testSegment;

		eventRSVP.Event_Segment__c = testSegment.Id;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode, sampleBody));

		addMeetingRegistrant(event, eventRSVP, true);

		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;
		event.Registration__c = x7sEventsExternalMeetingConstants.MANUAL_APPROVAL;

		addMeetingRegistrant(event, eventRSVP, true);

		Test.stopTest();
	}

	@IsTest
	static void testAddMeetingRegistrantZoomMeetingError() {
		X7S_Event_RSVP__c eventRSVP = new X7S_Event_RSVP__c();

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;
		event.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;

		addMeetingRegistrant(event, null, false);

		addMeetingRegistrant(event, eventRSVP, false);

		addMeetingRegistrant(event, eventRSVP, false);

		Test.stopTest();
	}

	static void addMeetingRegistrant(
		X7S_Event__c event,
		X7S_Event_RSVP__c eventRSVP,
		Boolean success
	) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.addRegistrant(event, eventRSVP);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testUpdateMeetingRegistrantZoomMeetingSuccess() {
		Integer responseCode = 204;
		X7S_Event_RSVP__c eventRSVP = new X7S_Event_RSVP__c();

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;
		event.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;

		eventRSVP.Registration_Id__c = '1234';
		eventRSVP.User__c = UserInfo.getUserId();
		eventRSVP.Event__c = event.Id;

		X7S_Event_Segment__c testSegment = new X7S_Event_Segment__c();
		testSegment.Segment__c = x7sEventsSegmentController.SEGMENT_VIRTUAL;
		testSegment.Wait_list__c = false;
		testSegment.Event__c = event.Id;

		insert testSegment;

		eventRSVP.Event_Segment__c = testSegment.Id;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		updateMeetingRegistrant(event, eventRSVP, true);

		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		updateMeetingRegistrant(event, eventRSVP, true);

		Test.stopTest();
	}

	@IsTest
	static void testUpdateMeetingRegistrantZoomMeetingError() {
		X7S_Event_RSVP__c eventRSVP = new X7S_Event_RSVP__c();

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;
		event.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;

		eventRSVP.Registration_Id__c = '1234';
		eventRSVP.User__c = UserInfo.getUserId();

		updateMeetingRegistrant(event, null, false);

		updateMeetingRegistrant(event, eventRSVP, false);

		updateMeetingRegistrant(event, eventRSVP, false);

		Test.stopTest();
	}

	static void updateMeetingRegistrant(
		X7S_Event__c event,
		X7S_Event_RSVP__c eventRSVP,
		Boolean success
	) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.updateRegistrant(event, eventRSVP);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testGetMeetingRegistrantsZoomMeetingSuccess() {
		Integer responseCode = 200;
		String body =
			OPENING_CURLY_BRACKET +
			PAGE_COUNT +
			'  "page_number": 1,' +
			PAGE_SIZE +
			PAGE_TOTAL_RECORDS +
			'  "next_page_token": "repeat_body",' +
			'  "registrants": [' +
			OPENING_CURLY_BRACKET +
			'      "id": "abcdef123",\n' +
			'      "first_name": "Sample",\n' +
			'      "last_name": "User",\n' +
			'      "email": "sample.user@test.com"\n' +
			'    }\n' +
			'  ]\n' +
			CLOSING_CURLY_BRACKET;
		String bodyRepeat =
			OPENING_CURLY_BRACKET +
			PAGE_COUNT +
			PAGE_SIZE +
			PAGE_TOTAL_RECORDS +
			'  "next_page_token": "",' +
			'  "participants": [' +
			OPENING_CURLY_BRACKET +
			'      "id": "abcdef5678",' +
			'      "user_id": "5678",' +
			'      "name": "Sample2 User",' +
			'      "user_email": "sample.user2@test.com",' +
			'      "join_time": "2021-07-29T00:49:40Z",' +
			'      "leave_time": "2021-07-29T00:49:48Z",' +
			'      "duration": 8,' +
			'      "attentiveness_score": "",' +
			'      "failover": false,' +
			'      "customer_key": ""' +
			CLOSING_CURLY_BRACKET +
			'  ]' +
			CLOSING_CURLY_BRACKET;

		Test.startTest();
		Test.setMock(
			HttpCalloutMock.class,
			new x7sEventsMockWebService200Repeat(responseCode, body, bodyRepeat)
		);

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		getMeetingRegistrants(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetMeetingRegistrantsZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;

		getMeetingRegistrants(event, false);

		getMeetingRegistrants(event, false);

		Test.stopTest();
	}

	static void getMeetingRegistrants(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.getRegistrants(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testGetMeetingParticipantsZoomMeetingSuccess() {
		Integer responseCode = 200;
		String body =
			OPENING_CURLY_BRACKET +
			PAGE_COUNT +
			PAGE_SIZE +
			PAGE_TOTAL_RECORDS +
			'  "next_page_token": "repeat_body",' +
			'  "participants": [' +
			OPENING_CURLY_BRACKET +
			'      "id": "abcdef123",' +
			'      "user_id": "1234",' +
			'      "name": "Sample User",' +
			'      "user_email": "sample.user@test.com",' +
			'      "join_time": "2021-07-29T00:49:40Z",' +
			'      "leave_time": "2021-07-29T00:49:48Z",' +
			'      "duration": 8,' +
			'      "attentiveness_score": "",' +
			'      "failover": false,' +
			'      "customer_key": ""' +
			CLOSING_CURLY_BRACKET +
			'  ]' +
			CLOSING_CURLY_BRACKET;
		String bodyRepeat =
			OPENING_CURLY_BRACKET +
			PAGE_COUNT +
			PAGE_SIZE +
			PAGE_TOTAL_RECORDS +
			'  "next_page_token": "",' +
			'  "participants": [' +
			OPENING_CURLY_BRACKET +
			'      "id": "abcdef5678",' +
			'      "user_id": "5678",' +
			'      "name": "Sample2 User",' +
			'      "user_email": "sample.user2@test.com",' +
			'      "join_time": "2021-07-29T00:49:40Z",' +
			'      "leave_time": "2021-07-29T00:49:48Z",' +
			'      "duration": 8,' +
			'      "attentiveness_score": "",' +
			'      "failover": false,' +
			'      "customer_key": ""' +
			CLOSING_CURLY_BRACKET +
			'  ]' +
			CLOSING_CURLY_BRACKET;

		Test.startTest();
		Test.setMock(
			HttpCalloutMock.class,
			new x7sEventsMockWebService200Repeat(responseCode, body, bodyRepeat)
		);

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;

		getMeetingParticipants(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetMeetingParticipantsZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());
		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;

		getMeetingParticipants(event, false);

		getMeetingParticipants(event, false);

		Test.stopTest();
	}

	static void getMeetingParticipants(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.getParticipants(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	/**
	 *  @description Webinar Tests
	 */
	@IsTest
	static void testCreateZoomWebinarSuccess() {
		Integer responseCode = 201;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		createWebinar(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testCreateZoomWebinarError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		createWebinar(event, false);

		Test.stopTest();
	}

	static void createWebinar(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.create(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testGetWebinarZoomMeetingSuccess() {
		Integer responseCode = 200;

		Test.startTest();
		String sampleBody =
			OPENING_CURLY_BRACKET +
			TEST_TOPIC +
			TEST_START_TIME +
			TEST_DURATION +
			TEST_TIMEZONE +
			TEST_AGENDA +
			TEST_SETTINGS +
			'        "approval_type": 2' +
			CLOSING_CURLY_BRACKET +
			CLOSING_CURLY_BRACKET;

		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode, sampleBody));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;
		event.MeetingId__c = TEST_MEETING_ID;

		getWebinar(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetWebinarZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		getWebinar(event, false);

		getWebinar(event, false);

		Test.stopTest();
	}

	static void getWebinar(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.get(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testDeleteZoomWebinarSuccess() {
		Integer responseCode = 204;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;
		event.MeetingId__c = TEST_MEETING_ID;

		deleteWebinar(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testDeleteZoomWebinarError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());
		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		deleteWebinar(event, false);

		deleteWebinar(event, false);

		Test.stopTest();
	}

	static void deleteWebinar(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.deleteExternal(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testAddWebinarRegistrantZoomMeetingSuccess() {
		Integer responseCode = 201;
		X7S_Event_RSVP__c eventRSVP = new X7S_Event_RSVP__c();
		String sampleBody =
			OPENING_CURLY_BRACKET +
			'    "id":"1234",' +
			TEST_START_TIME +
			'    "join_url":"http://Sample.url",' +
			'    "registrant_id":"Sample id"' +
			CLOSING_CURLY_BRACKET;

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;
		event.MeetingId__c = TEST_MEETING_ID;
		event.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;

		X7S_Event_Segment__c testSegment = new X7S_Event_Segment__c();
		testSegment.Segment__c = x7sEventsSegmentController.SEGMENT_VIRTUAL;
		testSegment.Wait_list__c = false;
		testSegment.Event__c = event.Id;

		insert testSegment;

		eventRSVP.Event_Segment__c = testSegment.Id;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode, sampleBody));

		addWebinarRegistrant(event, eventRSVP, true);

		Test.stopTest();
	}

	@IsTest
	static void testAddWebinarRegistrantZoomMeetingError() {
		X7S_Event_RSVP__c eventRSVP = new X7S_Event_RSVP__c();

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.MEETING;
		event.MeetingId__c = TEST_MEETING_ID;
		event.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;

		addWebinarRegistrant(event, null, false);

		addWebinarRegistrant(event, eventRSVP, false);

		addWebinarRegistrant(event, eventRSVP, false);

		Test.stopTest();
	}

	static void addWebinarRegistrant(
		X7S_Event__c event,
		X7S_Event_RSVP__c eventRSVP,
		Boolean success
	) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.addRegistrant(event, eventRSVP);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testGetWebinarRegistrantsZoomMeetingSuccess() {
		Integer responseCode = 200;

		Test.startTest();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		X7S_Event__c event = getEvent();
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		getWebinarRegistrants(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetWebinarRegistrantsZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		getWebinarRegistrants(event, false);

		getWebinarRegistrants(event, false);

		Test.stopTest();
	}

	static void getWebinarRegistrants(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.getRegistrants(event);
		System.debug('TEST: ' + externalMeetingResponse);
		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	@IsTest
	static void testGetWebinarParticipantsZoomMeetingSuccess() {
		Integer responseCode = 200;

		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(responseCode));

		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;
		event.MeetingId__c = TEST_MEETING_ID;

		getWebinarParticipants(event, true);

		Test.stopTest();
	}

	@IsTest
	static void testGetWebinarParticipantsZoomMeetingError() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService404());
		X7S_Event__c event = getEvent();
		System.assertNotEquals(null, event.Id, TEST_EVENT_CREATE_MESSAGE);
		event.Event_Format__c = x7sEventsExternalMeetingConstants.ZOOM;
		event.Meeting_Type__c = x7sEventsExternalMeetingConstants.WEBINAR;

		getWebinarParticipants(event, false);

		getWebinarParticipants(event, false);
		Test.stopTest();
	}

	static void getWebinarParticipants(X7S_Event__c event, Boolean success) {
		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.getParticipants(event);

		System.assertEquals(success, externalMeetingResponse.isSuccess());
	}

	/**
	 * @description Support Functions
	 * @return Event Object
	 */

	private static X7S_Event__c getEvent() {
		return [
			SELECT
				Id,
				Name,
				Start_DateTime__c,
				End_DateTime__c,
				Details__c,
				MeetingId__c,
				Meeting_Type__c,
				Registration__c,
				Host_Email__c
			FROM X7S_Event__c
			WHERE Name = :TEST_EVENT_NAME
		];
	}
}