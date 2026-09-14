/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsSegmentController {
	public static final String SEGMENT_IN_PERSON = 'In-person';
	public static final String SEGMENT_VIRTUAL = 'Virtual';
	private static final Integer SEGMENT_LIST_LIMIT = 1000;

	/**
	 * @description : Insert or Update 7S Event Segments
	 *
	 * @param segments List of x7sEventsSegmentWrapper
	 */
	@AuraEnabled
	public static void updateSegments(List<x7sEventsSegmentWrapper> segments) {
		try {
			if (
				!segments.isEmpty() &&
				X7S_Event_Segment__c.SObjectType.getDescribe().isCreateable() &&
				X7S_Event_Segment__c.SObjectType.getDescribe().isUpdateable()
			) {
				List<X7S_Event_Segment__c> eventSegments = new List<X7S_Event_Segment__c>();

				for (x7sEventsSegmentWrapper segment : segments) {
					X7S_Event_Segment__c eventSegment = new X7S_Event_Segment__c();

					eventSegment.Id = segment.id;

					if (segment.id == null) {
						eventSegment.Event__c = segment.eventId;
					}

					eventSegment.Track_capacity__c = segment.TrackCapacity;
					eventSegment.Capacity__c = segment.Capacity;
					eventSegment.Wait_list__c = segment.WaitList;
					eventSegment.Registration_Setting__c = segment.RegistrationSetting;
					eventSegment.Segment__c = segment.Segment;

					eventSegments.add(eventSegment);
				}

				if (!eventSegments.isEmpty()) {
					upsert eventSegments;
				}
			}
		} catch (Exception ex) {
			System.debug('Error saving segments: ' + ex.getMessage());
		}
	}

	/**
	 * @param eventId Id of the event to load the segments for
	 *
	 * @return List of segments associated with event.
	 */
	@AuraEnabled
	public static List<x7sEventsSegmentWrapper> loadSegments(String eventId) {
		try {
			List<x7sEventsSegmentWrapper> segments = new List<x7sEventsSegmentWrapper>();

			if (String.isNotBlank(eventId)) {
				List<X7S_Event_Segment__c> eventSegments = new List<X7S_Event_Segment__c>();
				eventSegments = [
					SELECT
						Id,
						Track_capacity__c,
						Capacity__c,
						Wait_list__c,
						Event__c,
						Registration_Setting__c,
						Segment__c
					FROM X7S_Event_Segment__c
					WHERE Event__c = :eventId
					WITH SECURITY_ENFORCED
					LIMIT :SEGMENT_LIST_LIMIT
				];

				if (!eventSegments.isEmpty()) {
					for (X7S_Event_Segment__c eventSegment : eventSegments) {
						x7sEventsSegmentWrapper segment = new x7sEventsSegmentWrapper();

						segment.id = eventSegment.Id;
						segment.eventId = eventSegment.Event__c;
						segment.TrackCapacity = eventSegment.Track_capacity__c;
						segment.Capacity = (Integer) eventSegment.Capacity__c;
						segment.WaitList = eventSegment.Wait_list__c;
						segment.RegistrationSetting = eventSegment.Registration_Setting__c;
						segment.Segment = eventSegment.Segment__c;

						segments.add(segment);
					}
				}
			}
			return segments;
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}
}