/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsRegistrationControllerTest {
	private static final Integer EVENT_COUNT = 10;
	private static final Integer RSVP_USER_COUNT = 90;
	private static final Integer LARGE_USER_COUNT = 2000;
	static final String CONTACT_EMAIL = 'testcontact@email.com';
	static final String TEST_LEAD = 'existing_lead@email.com';
	static final String TEST_UNKNOWN_LEAD = 'unknown_lead@email.com';
	static final String MEETING_FORMAT = 'Zoom';
	static final String SYSTEM_ADMIN = 'System Administrator';
	private static final String LEAVE_TIME = '"leave_time" : "2021-04-08 21:55:53" ,';
	private static final String MEMBER_ID = '123';
	private static final String ORGANIZATION = '"org" : "Company X" ,';
	private static final String STATUS = '"status" : "approved" ,';
	private static final String EMAIL_LITERAL = '"email" : \"';
	private static final String BACKSLASH = '\", ';

	@TestSetup
	static void testSetup() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'UserTriggerHandler' }
		);
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(EVENT_COUNT);
		System.debug('Test event count: ' + eventList.size());
		List<X7S_Event_RSVP__c> rsvpList = x7sEventsUtility.createMultipleRSVPRecords(
			EVENT_COUNT,
			RSVP_USER_COUNT,
			eventList
		);
		System.debug('Test rsvp count: ' + rsvpList.size());
		System.debug(rsvpList);

		List<User> testUsers = x7sEventsUtility.createUsers(1, SYSTEM_ADMIN);
		System.assertEquals(1, testUsers.size(), 'Should create one test user');
		System.assertEquals('0' + x7sEventsUtility.TEST_EMAIL, testUsers[0].Email, 'Validate email');

		Contact testContact = x7sEventsUtility.createContact(CONTACT_EMAIL);
		System.assertNotEquals(null, testContact, 'A test contact should be created.');

		testContact = x7sEventsUtility.createContact('x7s_test_user0@email.com');
		System.assertNotEquals(null, testContact, 'A test contact should be created.');

		Lead testLead = x7sEventsUtility.createLead(TEST_LEAD);
		System.assertNotEquals(null, testLead, 'A test lead should be created.');
	}

	@IsTest
	static void testUpdateMeetingParticipantsWithSampleData() {
		String sampleBody =
			'{' +
			'    "participants": [' +
			'      {"user_id": "12345",' +
			'       "user_email" : "x7s_test_user0@email.com",' +
			'       "join_time" : "2021-04-08 21:49:53" ,' +
			'       "leave_time" : "2021-04-08 21:52:53" ,' +
			'       "duration" : 180}, ' +
			'      {"user_id": "12346",' +
			'       "name" : "Lead_First Lead_Last", ' +
			'       "user_email" : \"' +
			TEST_LEAD +
			'\",' +
			'       "join_time" : "2021-04-08 21:49:53" ,' +
			LEAVE_TIME +
			'       "duration" : 360}, ' +
			'      {"user_id": "12350",' +
			'       "name" : "Lead_First Lead_Last", ' +
			'       "user_email" : \"' +
			TEST_LEAD +
			'\",' +
			'       "join_time" : "2021-04-08 21:49:53" ,' +
			LEAVE_TIME +
			'       "duration" : 360}, ' +
			'      {"user_id": "12347",' +
			'       "user_email" : "created_lead@email.com",' +
			'       "name" : "New Lead Person", ' +
			'       "join_time" : "2021-04-08 21:45:53" ,' +
			LEAVE_TIME +
			'       "duration" : 600}, ' +
			'      {"user_id": "12355",' +
			'       "user_email" : "x7s_test_user0@email.com",' +
			'       "name" : "Nequeporroquisquamestquidoloremipsumquiadolorsitamet Nequeporroquisquamestquidoloremipsumquiadolorsitamet", ' +
			'       "join_time" : "2021-04-08 21:45:53" ,' +
			LEAVE_TIME +
			'       "duration" : 600}, ' +
			'      {"user_id": "12345",' +
			'       "user_email" : "x7s_test_user0@email.com",' +
			'       "join_time" : "2021-04-08 21:53:53" ,' +
			'       "leave_time" : "2021-04-08 21:54:53" ,' +
			'       "duration" : 60}' +
			'     ]' +
			'}';

		testUpdateMeetingParticipants(sampleBody);

		x7sEventsRegistrationController controller = new x7sEventsRegistrationController();
		System.assertNotEquals(null, controller);
	}

	@IsTest
	static void testUpdateMeetingParticipantLargeNumberOfUsers() {
		// Generate sample body
		Map<String, Object> participantList = new Map<String, Object>();
		List<Map<String, Object>> participants = new List<Map<String, Object>>();

		for (Integer index = 0; index < LARGE_USER_COUNT; index++) {
			Map<String, Object> participant = new Map<String, Object>();

			participant.put('user_id', String.valueOf(index));
			participant.put('name', 'Joe Green');
			participant.put('user_email', 'joe_green' + index + '@test.com');
			participant.put('join_time', '2021-04-08 21:49:53');
			participant.put('leave_time', '2021-04-08 21:50:53');
			participant.put('duration', 36);

			participants.add(participant);
		}

		participantList.put('participants', participants);

		String sampleBody = JSON.serialize(participantList);

		testUpdateMeetingParticipants(sampleBody);

		Boolean isLeadsEnabled = x7sEventsRegistrationController.generateLeadsEnabled();
		System.assertNotEquals(null, isLeadsEnabled);
	}

	static void testUpdateMeetingParticipants(String sampleBody) {
		List<X7S_Event__c> events = getTestEvents();
		X7S_Event__c event = events[0];
		event.Event_Format__c = MEETING_FORMAT;
		event.Meeting_Type__c = 'Webinar';
		event.MeetingId__c = MEMBER_ID;

		List<Lead> existingLeads = [SELECT Id, Email, FirstName, LastName FROM Lead LIMIT 100];
		System.debug('Existing Leads: ' + existingLeads);

		List<Contact> existingContacts = [SELECT Id, Name, Email FROM Contact LIMIT 100];
		System.debug('Existing Contacts: ' + existingContacts);

		List<User> existingUsers = [SELECT Id, Name, Email FROM User LIMIT 100];
		System.debug('User: ' + existingUsers);

		List<X7S_Event_RSVP__c> preUpdateRsvpList = x7sEventsRegistrationController.getExistingRsvpRecords(
			getTestEventIdSet()
		);
		System.debug('Pre-update RSVP List: ' + preUpdateRsvpList.size());
		for (X7S_Event_RSVP__c rsvp : preUpdateRsvpList) {
			System.debug(rsvp);
		}

		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(200, sampleBody));

		Test.startTest();
		{
			System.debug('About to process participants.');
			x7sEventsRegistrationController.updateMeetingParticipants(events);
		}
		Test.stopTest();

		List<X7S_Event_RSVP__c> rsvpList = [
			SELECT
				Id,
				Email__c,
				Participant_Start__c,
				Participant_End__c,
				Participant_Duration__c,
				Response__c
			FROM X7S_Event_RSVP__c
			LIMIT 5
		];
		System.assertEquals('Attending', rsvpList[0].Response__c);

		for (X7S_Event_RSVP__c rsvp : rsvpList) {
			System.debug(rsvp);
		}
		List<Lead> leads = [SELECT Name, FirstName, LastName, Email FROM Lead LIMIT 100];
		System.debug('Updated Leads: ');
		for (Lead leadEntry : leads) {
			System.debug(leadEntry);
		}
	}

	@IsTest
	static void testUpdateMeetingRegistrantsSampleData() {
		Set<String> eventIdList = getTestEventIdSet();
		List<X7S_Event_RSVP__c> rsvpUserList = x7sEventsRegistrationController.getExistingRsvpRecords(
			eventIdList
		);
		Map<String, String> emailList = x7sEventsRegistrationController.getEmailAddressesFromRsvpRecords(
			rsvpUserList
		);
		Map<String, String> emailUsers = x7sEventsRegistrationController.getExistingUsersEmail(
			emailList
		);
		System.assertNotEquals(null, emailUsers);

		String sampleBody =
			'{' +
			'    "registrants": [' +
			'       {"id": "12345",' +
			'       "first_name" : "x7s first1", ' +
			'       "last_name" : "existing user1", ' +
			'       "email" : "x7s_test_user0@email.com",' +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-04-08 21:49:53" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12345" },' +
			'       {"id": "12346",' +
			'       "first_name" : "newlead", ' +
			'       "last_name" : "NewLead1", ' +
			'       "email" : "created_lead@email.com", ' +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-04-08 22:57:55" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12346" },' +
			'       {"id": "12349",' +
			'       "first_name" : "Lead_First", ' +
			'       "last_name" : "Lead_Last", ' +
			EMAIL_LITERAL +
			TEST_LEAD +
			BACKSLASH +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-04-08 22:57:55" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12346" },' +
			'       {"id": "12350",' +
			'       "first_name" : "First ipsum dolor sit amet, consecteture", ' +
			'       "last_name" : "Lastn ipsum dolor sit amet, Neque porro quisquam est qui dolorem ipsum quia dolor sit amet ipsum quia dolor sit amet", ' +
			EMAIL_LITERAL +
			TEST_LEAD +
			BACKSLASH +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-04-08 22:57:55" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12351" },' +
			'       {"id": "12347",' +
			'       "first_name" : "existingcontact", ' +
			'       "last_name" : "Existing_Contact", ' +
			EMAIL_LITERAL +
			CONTACT_EMAIL +
			BACKSLASH +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-04-08 22:57:57" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12347" }' +
			'     ]' +
			'}';

		testUpdateMeetingRegistrants(sampleBody);
	}

	@IsTest
	static void testUpdateMeetingRegistrantsLargeNumberOfUsers() {
		// Generate sample body
		Map<String, Object> registrantList = new Map<String, Object>();
		List<Map<String, Object>> registrants = new List<Map<String, Object>>();

		for (Integer index = 0; index < LARGE_USER_COUNT; index++) {
			Map<String, Object> registrant = new Map<String, Object>();

			registrant.put('id', String.valueOf(index));
			registrant.put('first_name', 'Joe');
			registrant.put('last_name', 'Green');
			registrant.put('email', 'joe_green' + index + '@test.com');
			registrant.put('org', 'Company X');
			registrant.put('status', 'approved');
			registrant.put('create_time', '2021-04-08 22:57:57');
			registrant.put('join_url', 'https://www.zoom.com/meeting?id=12347');

			registrants.add(registrant);
		}

		registrantList.put('participants', registrants);

		String sampleBody = JSON.serialize(registrantList);
		System.assertNotEquals(null, sampleBody, 'Sample body can not be null.');

		testUpdateMeetingRegistrants(sampleBody);
	}

	@IsTest
	/**
	 *	This test case is specific to test that RSVP records are created for both known and unknown
	 *  users that can come from the Zoom API call.
	 */
	static void testUpdateMeetingRegistrantsKnownUsers() {
		String sampleBody =
			'{' +
			'    "registrants": [' +
			'       {"id": "12345",' +
			'       "first_name" : "Real", ' +
			'       "last_name" : "User", ' +
			EMAIL_LITERAL +
			0 +
			x7sEventsUtility.TEST_EMAIL +
			BACKSLASH +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-11-18 21:49:53" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12345" },' +
			'       {"id": "12349",' +
			'       "first_name" : "Known", ' +
			'       "last_name" : "Lead", ' +
			EMAIL_LITERAL +
			TEST_LEAD +
			BACKSLASH +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-11-18 21:49:53" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12346" },' +
			'       {"id": "12349",' +
			'       "first_name" : "Unknown", ' +
			'       "last_name" : "Lead", ' +
			EMAIL_LITERAL +
			TEST_UNKNOWN_LEAD +
			BACKSLASH +
			ORGANIZATION +
			STATUS +
			'       "create_time" : "2021-11-18 21:51:53" ,' +
			'       "join_url" : "https://www.zoom.com/meeting?id=12346" }' +
			'     ]' +
			'}';

		testUpdateMeetingRegistrants(sampleBody);

		List<X7S_Event_RSVP__c> postUpdateRsvpList = x7sEventsRegistrationController.getExistingRsvpRecords(
			getTestEventIdSet()
		);
		System.assertNotEquals(null, postUpdateRsvpList);
		// There are already 2 RSVP objects that were created during test setup.  We want to confirm that there will now be
		// three more for a total of 5 RSVP objects.
		//System.assertEquals(5, postUpdateRsvpList.size(), 'Should have 5 RSVP items');
	}

	static void testUpdateMeetingRegistrants(String sampleBody) {
		Test.startTest();
		{
			List<X7S_Event__c> events = getTestEvents();
			X7S_Event__c event = events[0];
			event.Event_Format__c = MEETING_FORMAT;
			event.Meeting_Type__c = 'Webinar';
			event.MeetingId__c = MEMBER_ID;

			List<Lead> existingLeads = [SELECT Id, Email, FirstName, LastName FROM Lead LIMIT 100];

			List<Contact> existingContacts = [SELECT Id, Name, Email FROM Contact LIMIT 100];

			List<User> existingUsers = [SELECT Id, Name, Email FROM User LIMIT 100];

			List<X7S_Event_RSVP__c> preUpdateRsvpList = x7sEventsRegistrationController.getExistingRsvpRecords(
				getTestEventIdSet()
			);
			for (X7S_Event_RSVP__c rsvp : preUpdateRsvpList) {
				System.debug(rsvp);
			}

			Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(200, sampleBody));

			System.debug('Calling updateMeetingRegistrants');
			x7sEventsRegistrationController.updateMeetingRegistrants(events);

			List<X7S_Event_RSVP__c> postUpdateRsvpList = x7sEventsRegistrationController.getExistingRsvpRecords(
				getTestEventIdSet()
			);
			System.assertNotEquals(null, postUpdateRsvpList);

			System.debug('Post-update Rsvp List: ' + postUpdateRsvpList.size());
			for (X7S_Event_RSVP__c rsvp : postUpdateRsvpList) {
				System.debug(rsvp);
			}

			List<Lead> leads = [SELECT Name, Email FROM Lead LIMIT 100];
			System.debug('Updated Leads: ');
			for (Lead leadEntry : leads) {
				System.debug(leadEntry);
			}
		}
		Test.stopTest();
	}

	@IsTest
	static void testGetExistingRsvpRecords() {
		Set<String> eventIdList = getTestEventIdSet();
		List<X7S_Event_RSVP__c> rsvpList = x7sEventsRegistrationController.getExistingRsvpRecords(
			eventIdList
		);
		System.assertNotEquals(null, rsvpList);

		List<X7S_Event_RSVP__c> rsvpUserList = x7sEventsRegistrationController.getExistingRsvpRecords(
			eventIdList
		);
		Map<String, String> emailList = x7sEventsRegistrationController.getEmailAddressesFromRsvpRecords(
			rsvpUserList
		);
		System.assertNotEquals(null, emailList);
	}

	@IsTest
	static void testCreateNewLeads() {
		List<X7S_Event__c> eventList = getTestEvents();
		x7sEventsRsvpModelList model = x7sEventsRegistrationController.getRegistrants(eventList);
		System.assertNotEquals(null, model);

		Map<String, String> emailList = x7sEventsRegistrationController.getEmailAddressesFromExternalRecords(
			model
		);
		Map<String, Lead> newLeads = x7sEventsRegistrationController.buildNewLeads(model, emailList);
		System.assertNotEquals(null, newLeads.values());
	}

	@IsTest
	static void testGetRegistrants() {
		List<X7S_Event__c> eventList = getTestEvents();
		x7sEventsRsvpModelList model = x7sEventsRegistrationController.getRegistrants(eventList);
		System.assertNotEquals(null, model);
	}

	@IsTest
	static void testGetRegistrant() {
		String validFirstName = 'user1';
		String validLastName = 'lastName';

		Map<String, Object> entry = new Map<String, Object>{
			x7sEventsRegistrationController.REGISTRANT_ID => '1234',
			x7sEventsRegistrationController.FIRSTNAME => validFirstName,
			x7sEventsRegistrationController.LASTNAME => validLastName,
			x7sEventsRegistrationController.USER_EMAIL => 'user1@email.com',
			x7sEventsRegistrationController.COMPANY => 'companyX',
			x7sEventsRegistrationController.JOIN_URL => 'https://www.link.com'
		};

		Map<String, String> eventIdToSegmentIdMap = new Map<String, String>();
		eventIdToSegmentIdMap.put(MEMBER_ID, '3454');

		// Test with valid user.
		x7sEventsRsvpModel testModel = x7sEventsRegistrationController.getRegistrant(
			entry,
			MEMBER_ID,
			eventIdToSegmentIdMap
		);
		System.assertNotEquals(null, testModel, 'testModel should be a valid object.');
		System.assertEquals(
			validFirstName,
			testModel.firstName,
			'First name should be ' + validFirstName
		);
		System.assertEquals(validLastName, testModel.lastName, 'Last name should be ' + validLastName);

		// Test with no first name
		entry = new Map<String, Object>{
			x7sEventsRegistrationController.REGISTRANT_ID => '1234',
			x7sEventsRegistrationController.FIRSTNAME => null,
			x7sEventsRegistrationController.LASTNAME => validLastName,
			x7sEventsRegistrationController.USER_EMAIL => 'user1@email.com',
			x7sEventsRegistrationController.COMPANY => 'companyX',
			x7sEventsRegistrationController.JOIN_URL => 'https://www.link.com'
		};

		testModel = x7sEventsRegistrationController.getRegistrant(
			entry,
			MEMBER_ID,
			eventIdToSegmentIdMap
		);
		System.assertNotEquals(null, testModel);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			testModel.firstName,
			'First name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);
		System.assertEquals(validLastName, testModel.lastName, 'Last name should be ' + validLastName);

		entry = new Map<String, Object>{
			x7sEventsRegistrationController.REGISTRANT_ID => '1234',
			x7sEventsRegistrationController.FIRSTNAME => '',
			x7sEventsRegistrationController.LASTNAME => validLastName,
			x7sEventsRegistrationController.USER_EMAIL => 'user1@email.com',
			x7sEventsRegistrationController.COMPANY => 'companyX',
			x7sEventsRegistrationController.JOIN_URL => 'https://www.link.com'
		};

		testModel = x7sEventsRegistrationController.getRegistrant(
			entry,
			MEMBER_ID,
			eventIdToSegmentIdMap
		);
		System.assertNotEquals(null, testModel);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			testModel.firstName,
			'First name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);
		System.assertEquals(validLastName, testModel.lastName, 'Last name should be ' + validLastName);

		// Test with no last name
		entry = new Map<String, Object>{
			x7sEventsRegistrationController.REGISTRANT_ID => '1234',
			x7sEventsRegistrationController.FIRSTNAME => validFirstName,
			x7sEventsRegistrationController.LASTNAME => '   ',
			x7sEventsRegistrationController.USER_EMAIL => 'user1@email.com',
			x7sEventsRegistrationController.COMPANY => 'companyX',
			x7sEventsRegistrationController.JOIN_URL => 'https://www.link.com'
		};

		testModel = x7sEventsRegistrationController.getRegistrant(
			entry,
			MEMBER_ID,
			eventIdToSegmentIdMap
		);
		System.assertNotEquals(null, testModel);
		System.assertEquals(
			validFirstName,
			testModel.firstName,
			'First name should be ' + validFirstName
		);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			testModel.lastName,
			'Last name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);

		entry = new Map<String, Object>{
			x7sEventsRegistrationController.REGISTRANT_ID => '1234',
			x7sEventsRegistrationController.FIRSTNAME => validFirstName,
			x7sEventsRegistrationController.LASTNAME => null,
			x7sEventsRegistrationController.USER_EMAIL => 'user1@email.com',
			x7sEventsRegistrationController.COMPANY => 'companyX',
			x7sEventsRegistrationController.JOIN_URL => 'https://www.link.com'
		};

		testModel = x7sEventsRegistrationController.getRegistrant(
			entry,
			MEMBER_ID,
			eventIdToSegmentIdMap
		);
		System.assertNotEquals(null, testModel);
		System.assertEquals(
			validFirstName,
			testModel.firstName,
			'First name should be ' + validFirstName
		);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			testModel.lastName,
			'Last name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);

		// Test with no first or last name
		entry = new Map<String, Object>{
			x7sEventsRegistrationController.REGISTRANT_ID => '1234',
			x7sEventsRegistrationController.FIRSTNAME => '',
			x7sEventsRegistrationController.LASTNAME => '',
			x7sEventsRegistrationController.USER_EMAIL => 'user1@email.com',
			x7sEventsRegistrationController.COMPANY => 'companyX',
			x7sEventsRegistrationController.JOIN_URL => 'https://www.link.com'
		};

		testModel = x7sEventsRegistrationController.getRegistrant(
			entry,
			MEMBER_ID,
			eventIdToSegmentIdMap
		);
		System.assertNotEquals(null, testModel);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			testModel.firstName,
			'First name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			testModel.lastName,
			'Last name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);
	}

	@IsTest
	static void getTestParticipant() {
		Map<String, Object> entry = new Map<String, Object>{
			x7sEventsRegistrationController.USER_ID => '12345',
			x7sEventsRegistrationController.PARTICIPANT_EMAIL => 'user1@email.com',
			x7sEventsRegistrationController.JOIN_TIME => 'join_time',
			x7sEventsRegistrationController.LEAVE_TIME => 'leave_time',
			x7sEventsRegistrationController.REGISTRATION_DATE => '2021-04-08 21:49:53',
			x7sEventsRegistrationController.REGISTRATION_STATUS => 'approved',
			x7sEventsRegistrationController.DURATION => 1
		};

		Map<String, String> eventIdToSegmentIdMap = new Map<String, String>();
		eventIdToSegmentIdMap.put(MEMBER_ID, '3454');

		x7sEventsRsvpModel model = x7sEventsRegistrationController.getParticipant(
			entry,
			MEMBER_ID,
			eventIdToSegmentIdMap
		);
		System.assertNotEquals(null, model);
	}

	@IsTest
	static void testGetRsvpUpdates() {
		x7sEventsRsvpModelList model = new x7sEventsRsvpModelList();
		Map<String, Object> entry = new Map<String, Object>{
			x7sEventsRegistrationController.USER_ID => '12345',
			x7sEventsRegistrationController.PARTICIPANT_EMAIL => 'x7s_test_user0@email.com',
			x7sEventsRegistrationController.JOIN_TIME => 'join_time',
			x7sEventsRegistrationController.LEAVE_TIME => 'leave_time',
			x7sEventsRegistrationController.REGISTRATION_DATE => '2021-04-08 21:49:53',
			x7sEventsRegistrationController.REGISTRATION_STATUS => 'approved',
			x7sEventsRegistrationController.DURATION => 1
		};

		Map<String, String> eventIdToSegmentIdMap = new Map<String, String>();
		eventIdToSegmentIdMap.put(MEMBER_ID, '3454');

		x7sEventsRsvpModel rsvp = x7sEventsRegistrationController.getParticipant(
			entry,
			null,
			eventIdToSegmentIdMap
		);
		model.records.add(rsvp);

		List<X7S_Event_RSVP__c> updates = x7sEventsRegistrationController.createNewRsvpRecords(model);
		System.assertNotEquals(null, updates);
	}

	@IsTest
	static void testKnownUser() {
		x7sEventsRegistrationController.KnownUserList userList = new x7sEventsRegistrationController.KnownUserList();
		userList.addUser('1234', 'email.com', 'LEAD');
		System.assertNotEquals(null, userList.findByEmail('email.com'));
	}

	static List<X7S_Event__c> getTestEvents() {
		return [
			SELECT Id, Name, MeetingId__c, Meeting_Type__c, Event_Format__c, UpComing_Sort__c
			FROM X7S_Event__c
			LIMIT 150
		];
	}

	static Set<String> getTestEventIdSet() {
		List<X7S_Event__c> eventList = getTestEvents();
		Set<String> eventIdList = new Set<String>();
		for (X7S_Event__c eventItem : eventList) {
			eventIdList.add(eventItem.Id);
		}
		return eventIdList;
	}

	@IsTest
	static void testUpdateFirstLastName() {
		x7sEventsRsvpModel testModel = new x7sEventsRsvpModel('0');

		testModel.name = 'Test User';

		x7sEventsRegistrationController.updateFirstLastName(testModel);

		System.assertEquals('Test', testModel.firstName, 'Verify that first name is populated');
		System.assertEquals('User', testModel.lastName, 'Verify that last name is populated');

		x7sEventsRsvpModel testModelSingleName = new x7sEventsRsvpModel('0');

		testModelSingleName.name = 'KnownUser';

		x7sEventsRegistrationController.updateFirstLastName(testModelSingleName);

		System.assertEquals(
			'KnownUser',
			testModelSingleName.firstName,
			'Verify that first name is populated'
		);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			testModelSingleName.lastName,
			'Verify that last name is Unknown'
		);
	}

	@IsTest
	static void testTruncateName() {
		String testNull;
		Integer maxLength = 40;

		System.assertEquals(
			null,
			x7sEventsRegistrationController.truncateName(testNull, maxLength),
			'Null name should remain null'
		);

		String testShort = 'Lorem';

		System.assertEquals(
			testShort,
			x7sEventsRegistrationController.truncateName(testShort, maxLength),
			'Names less than 40 characters should not be truncated'
		);

		String testLong = 'Neque porro quisquam est qui dolorem ipsum quia dolor sit amet';
		String updatedName = testLong.substring(0, 40);

		System.assertEquals(
			updatedName,
			x7sEventsRegistrationController.truncateName(testLong, maxLength),
			'Names longer than 40 characters will be truncated to 40 characters'
		);

		maxLength = 80;
		String testExtended = 'Neque porro quisquam est qui dolorem ipsum quia dolor sit amet ipsum quia dolor sit amet';
		String updatedExtended = testExtended.substring(0, maxLength);

		System.assertEquals(
			updatedExtended,
			x7sEventsRegistrationController.truncateName(testExtended, maxLength),
			'Names longer than 80 characters will be truncated to 80 characters'
		);
	}

	@IsTest
	static void testGetSafeName() {
		String testName;
		String modifiedName;

		modifiedName = x7sEventsRegistrationController.getSafeName(testName);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			modifiedName,
			'Name should be unknown'
		);

		testName = '   ';
		modifiedName = x7sEventsRegistrationController.getSafeName(testName);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			modifiedName,
			'Name should be unknown'
		);

		testName = '  TestName ';
		modifiedName = x7sEventsRegistrationController.getSafeName(testName);
		System.assertEquals(testName.trim(), modifiedName, 'Name should be TestName');
	}

	@IsTest
	static void testSplitNameAndTruncate() {
		String testName = 'John Doe';
		Map<String, String> nameComponents;

		nameComponents = x7sEventsRegistrationController.splitNameAndTruncate(testName);
		System.assertNotEquals(null, nameComponents, 'nameComponents should be valid');
		System.assertEquals(2, nameComponents.size(), 'nameComponents must contain 2 entries');
		System.assertEquals(
			'John',
			nameComponents.get(x7sEventsRegistrationController.FIRSTNAME),
			'first component should be the first name'
		);
		System.assertEquals(
			'Doe',
			nameComponents.get(x7sEventsRegistrationController.LASTNAME),
			'second component should be the last name'
		);

		testName = 'John A Doe';

		nameComponents = x7sEventsRegistrationController.splitNameAndTruncate(testName);
		System.assertNotEquals(null, nameComponents, 'nameComponents should be valid');
		System.assertEquals(2, nameComponents.size(), 'nameComponents must contain 2 entries');
		System.assertEquals(
			'John',
			nameComponents.get(x7sEventsRegistrationController.FIRSTNAME),
			'first component should be the first name'
		);
		System.assertEquals(
			'A Doe',
			nameComponents.get(x7sEventsRegistrationController.LASTNAME),
			'second component should be the last name'
		);

		testName = 'John';

		nameComponents = x7sEventsRegistrationController.splitNameAndTruncate(testName);
		System.assertNotEquals(null, nameComponents, 'nameComponents should be valid');
		System.assertEquals(1, nameComponents.size(), 'nameComponents must contain 2 entries');
		System.assertEquals(
			'John',
			nameComponents.get(x7sEventsRegistrationController.FIRSTNAME),
			'first component should be the first name'
		);

		testName = 'NequeporroquisquamestquidoloremquamestAuidoloremquamestquidoloremquamestquidolorem BequeporroquisquamestquidoloremquamestAuidoloremquamestquidoloremquamestquidolBem';

		nameComponents = x7sEventsRegistrationController.splitNameAndTruncate(testName);
		System.assertNotEquals(null, nameComponents, 'nameComponents should be valid');
		System.assertEquals(2, nameComponents.size(), 'nameComponents must contain 2 entries');
		System.assertEquals(
			'NequeporroquisquamestquidoloremquamestAu',
			nameComponents.get(x7sEventsRegistrationController.FIRSTNAME),
			'first component should be  NequeporroquisquamestquidoloremquamestAu'
		);
		System.assertEquals(
			'BequeporroquisquamestquidoloremquamestAuidoloremquamestquidoloremquamestquidolBe',
			nameComponents.get(x7sEventsRegistrationController.LASTNAME),
			'second component should be BequeporroquisquamestquidoloremquamestAuidoloremquamestquidoloremquamestquidolBe'
		);
	}

	@IsTest
	static void testUpdateRegistrantFirstLastName() {
		x7sEventsRsvpModel rsvp = new x7sEventsRsvpModel('12343');
		String firstName = 'John';
		String lastName = 'Doe';

		x7sEventsRegistrationController.updateRegistrantFirstLastName(rsvp, firstName, lastName);
		System.assertEquals('John', rsvp.firstName, 'First name should be John');
		System.assertEquals('Doe', rsvp.lastName, 'Last name should be Doe');

		firstName = 'John';
		lastName = '';

		x7sEventsRegistrationController.updateRegistrantFirstLastName(rsvp, firstName, lastName);
		System.assertEquals('John', rsvp.firstName, 'First name should be John');
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			rsvp.lastName,
			'Last name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);

		firstName = '';
		lastName = '';

		x7sEventsRegistrationController.updateRegistrantFirstLastName(rsvp, firstName, lastName);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			rsvp.firstName,
			'First name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);
		System.assertEquals(
			x7sEventsBaseController.UNKNOWN_NAME,
			rsvp.lastName,
			'Last name should be ' + x7sEventsBaseController.UNKNOWN_NAME
		);

		firstName = 'John A Doe';
		lastName = '';

		x7sEventsRegistrationController.updateRegistrantFirstLastName(rsvp, firstName, lastName);
		System.assertEquals('John', rsvp.firstName, 'First name should be John');
		System.assertEquals('A Doe', rsvp.lastName, 'Last name should be A Doe');
	}
}