/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public interface x7sEventsIExternalMeeting {
	x7sEventsIExternalMeetingResponse create(X7S_Event__c x7SEvent);
	x7sEventsIExternalMeetingResponse updateExternal(X7S_Event__c x7SEvent);
	x7sEventsIExternalMeetingResponse get(X7S_Event__c x7SEvent);
	x7sEventsIExternalMeetingResponse deleteExternal(X7S_Event__c x7SEvent);
	x7sEventsIExternalMeetingResponse addRegistrant(
		X7S_Event__c x7SEvent,
		X7S_Event_RSVP__c eventRSVP
	);
	x7sEventsIExternalMeetingResponse updateRegistrant(
		X7S_Event__c x7SEvent,
		X7S_Event_RSVP__c eventRSVP
	);
	x7sEventsIExternalMeetingResponse getRegistrants(X7S_Event__c x7SEvent);
	x7sEventsIExternalMeetingResponse getParticipants(X7S_Event__c x7SEvent);
}