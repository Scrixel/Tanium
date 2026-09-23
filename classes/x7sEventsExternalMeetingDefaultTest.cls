/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsExternalMeetingDefaultTest {
	@IsTest
	static void testExternalMeetingDefault() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new x7sEventsMockWebService200(201));

		X7S_Event__c event = new X7S_Event__c();

		x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
			event
		);

		System.assertNotEquals(null, externalMeeting);

		x7sEventsIExternalMeetingResponse externalMeetingResponse;

		externalMeetingResponse = externalMeeting.create(event);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		externalMeetingResponse = externalMeeting.updateExternal(event);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		externalMeetingResponse = externalMeeting.get(event);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		externalMeetingResponse = externalMeeting.deleteExternal(event);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		X7S_Event_RSVP__c eventRSVP = null;

		externalMeetingResponse = externalMeeting.addRegistrant(event, eventRSVP);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		externalMeetingResponse = externalMeeting.updateRegistrant(event, eventRSVP);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		externalMeetingResponse = externalMeeting.getRegistrants(event);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		externalMeetingResponse = externalMeeting.getParticipants(event);

		System.assertEquals(true, externalMeetingResponse.isSuccess());

		Test.stopTest();
	}
}