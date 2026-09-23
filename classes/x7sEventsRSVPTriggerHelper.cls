/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
public with sharing class x7sEventsRSVPTriggerHelper {
	public static void handleEventsRSVPInsert(List<X7S_Event_RSVP__c> rsvpItems) {
		Set<Id> rsvpIds = new Set<Id>();
		Set<Id> eventIds = new Set<Id>();

		if (!rsvpItems.isEmpty()) {
			for (X7S_Event_RSVP__c rsvp : rsvpItems) {
				rsvpIds.add(rsvp.Event_Segment__c);
				eventIds.add(rsvp.Event__c);
			}
		}

		List<X7S_Event_Segment__c> segments = [
			SELECT Id, Capacity__c, Event__c, Track_capacity__c, Segment__c, Wait_list__c
			FROM X7S_Event_Segment__c
			WHERE Id = :rsvpIds AND Event__c = :eventIds
			WITH SECURITY_ENFORCED
		];

		if (!rsvpItems.isEmpty() && !segments.isEmpty()) {
			for (X7S_Event_RSVP__c rsvp : rsvpItems) {
				for (X7S_Event_Segment__c eventSegment : segments) {
					try {
						if (
							eventSegment.Track_capacity__c &&
							(eventSegment.Event__c == rsvp.Event__c) &&
							(eventSegment.Id == rsvp.Event_Segment__c)
						) {
							Integer count = x7sEventsRegistration.getExperienceCount(
								eventSegment.Event__c,
								eventSegment.Segment__c
							);

							if (count > eventSegment.Capacity__c) {
								if (eventSegment.Wait_list__c) {
									rsvp.addError(Label.x7sEventsCapacityFullWaitlist);
									WriteError(Label.x7sEventsCapacityFullWaitlist, rsvp);
								} else {
									rsvp.addError(Label.x7sEventsCapacityFull);
									WriteError(Label.x7sEventsCapacityFull, rsvp);
								}
							}
						}
					} catch (Exception e) {
						throw new EventRSVPTriggerException(e);
					}
				}
			}
		}
	}

	private static void WriteError(String message, X7S_Event_RSVP__c rsvp) {
		System.debug(
			message +
			' User: ' +
			rsvp.First_Name__c +
			' ' +
			rsvp.Last_Name__c +
			' Emai: ' +
			rsvp.Email__c
		);
	}

	public class EventRSVPTriggerException extends Exception {
	}
}