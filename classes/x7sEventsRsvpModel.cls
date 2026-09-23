/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsRsvpModel {
	public String eventSegmentId { get; set; }
	public String eventId { get; set; }
	public String registrantId { get; set; }
	public String firstName { get; set; }
	public String lastName { get; set; }
	public String name { get; set; }
	public String email { get; set; }
	public String company { get; set; }
	public String joinUrl { get; set; }
	public String userId { get; set; }
	public String userType { get; set; }
	public String registrationDate { get; set; }
	public String registrationStatus { get; set; }
	public String attendeeJoin { get; set; }
	public String attendeeLeave { get; set; }
	public String attendeeDuration { get; set; }

	public x7sEventsRsvpModel(String eventId) {
		this.eventId = eventId;
	}

	public void dump(String title) {
		System.debug('x7sEventsRsvpModel: ' + title);
		System.debug(eventId + ': ' + email + ', type: ' + userType + ', userId: ' + userId);
	}
}