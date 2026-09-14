/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsRSVPTriggerHelperTest {
	@IsTest
	static void testCapacity() {
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(1);
		List<X7S_Event_Segment__c> segmentList = new List<X7S_Event_Segment__c>();

		X7S_Event_Segment__c segmentInPerson = new X7S_Event_Segment__c(
			Event__c = eventList[0].Id,
			Segment__c = x7sEventsSegmentController.SEGMENT_IN_PERSON,
			Track_capacity__c = true,
			Wait_list__c = true,
			Capacity__c = 10,
			Registration_Setting__c = ''
		);

		X7S_Event_Segment__c segmentVirtual = new X7S_Event_Segment__c(
			Event__c = eventList[0].Id,
			Segment__c = x7sEventsSegmentController.SEGMENT_VIRTUAL,
			Track_capacity__c = true,
			Wait_list__c = false,
			Capacity__c = 1,
			Registration_Setting__c = ''
		);

		segmentList.add(segmentInPerson);
		segmentList.add(segmentVirtual);

		insert segmentList;

		List<X7S_Event_RSVP__c> eventRSVPList = new List<X7S_Event_RSVP__c>();

		for (Integer i = 0; i < 10; i++) {
			X7S_Event_RSVP__c objEventRSVP = createRSVP(i, eventList[0].Id, segmentInPerson.Id);

			eventRSVPList.add(objEventRSVP);
		}

		insert eventRSVPList;

		System.assertEquals(
			segmentInPerson.Capacity__c,
			x7sEventsRegistration.getExperienceCount(segmentInPerson.Event__c, segmentInPerson.Segment__c)
		);
		x7sEventsRSVPTriggerHelper.handleEventsRSVPInsert(eventRSVPList);

		// Test waitlist
		X7S_Event_RSVP__c waitListRSVP = createRSVP(11, eventList[0].Id, segmentInPerson.Id);

		try {
			insert waitListRSVP;
		} catch (Exception exp) {
			System.assertEquals(
				true,
				exp.getMessage().contains(Label.x7sEventsCapacityFullWaitlist),
				'Verify the correct error message is returned when a user trys to register for a full event that has waitlisting enabled.'
			);
		}

		// Test event full
		try {
			X7S_Event_RSVP__c validVirtualRSVP = createRSVP(12, eventList[0].Id, segmentVirtual.Id);
			X7S_Event_RSVP__c fullVirtualRSVP = createRSVP(13, eventList[0].Id, segmentVirtual.Id);

			insert validVirtualRSVP;
			insert fullVirtualRSVP;
		} catch (Exception exp) {
			System.assertEquals(
				true,
				exp.getMessage().contains(Label.x7sEventsCapacityFull),
				'Verify the correct error message is returned when a user trys to register for a full event that has waitlisting disabled.'
			);
		}
	}

	private static X7S_Event_RSVP__c createRSVP(Integer index, String eventId, String segmentId) {
		X7S_Event_RSVP__c objEventRSVP = new X7S_Event_RSVP__c();

		objEventRSVP.Event__c = eventId;
		objEventRSVP.Response__c = 'Attending';
		objEventRSVP.Email__c = 'x7s_test_user' + index + '@email.com';
		objEventRSVP.User__c = UserInfo.getUserId();
		objEventRSVP.Event_Segment__c = segmentId;

		return objEventRSVP;
	}
}