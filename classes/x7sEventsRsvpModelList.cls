/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsRsvpModelList {
	public List<x7sEventsRsvpModel> records { get; set; }
	private Map<String, x7sEventsRsvpModel> modelByEmailId = new Map<String, x7sEventsRsvpModel>();

	public x7sEventsRsvpModelList() {
		this.records = new List<x7sEventsRsvpModel>();
	}

	public void addRegistrantRsvp(x7sEventsRsvpModel rsvp) {
		x7sEventsRsvpModel existingRsvp = findByEmail(rsvp.email, rsvp.eventId);

		if (existingRsvp == null) {
			records.add(rsvp);
		}

		modelByEmailId.put(rsvp.email + rsvp.eventId, rsvp);
	}

	public void addRsvp(x7sEventsRsvpModel rsvp) {
		x7sEventsRsvpModel existingRsvp = findByEmail(rsvp.email, rsvp.eventId);

		if (existingRsvp == null) {
			if (String.isNotBlank(rsvp.attendeeJoin) && String.isNotBlank(rsvp.attendeeLeave)) {
				rsvp.attendeeDuration = String.valueOf(
					getDurationMinutesRoundedUp(rsvp.attendeeJoin, rsvp.attendeeLeave)
				);
			}

			records.add(rsvp);
		} else {
			if (String.isNotBlank(rsvp.attendeeJoin) && String.isNotBlank(rsvp.attendeeLeave)) {
				existingRsvp.attendeeDuration = String.valueOf(
					Long.valueOf(existingRsvp.attendeeDuration) +
					getDurationMinutesRoundedUp(rsvp.attendeeJoin, rsvp.attendeeLeave)
				);
			}
		}

		modelByEmailId.put(rsvp.email + rsvp.eventId, rsvp);
	}

	public x7sEventsRsvpModel findByEmail(String emailValue, String eventId) {
		String uniqueKey = emailValue + eventId;

		if (modelByEmailId.containsKey(uniqueKey)) {
			return modelByEmailId.get(uniqueKey);
		}

		return null;
	}

	public static Long getDurationMinutesRoundedUp(String startString, String endString) {
		Long duration =
			Datetime.valueOfGmt(endString.replace('T', ' ')).getTime() -
			Datetime.valueOfGmt(startString.replace('T', ' ')).getTime();
		Long minutes = duration / 60000;
		Long remainder = Math.mod(duration / 1000, 60);

		return remainder > 0 ? minutes + 1 : minutes;
	}

	public static Long getMinutes(String durationString) {
		Long duration = Long.valueOf(durationString);
		Long minutes = duration / 60;
		Long remainder = Math.mod(duration, 60);
		return remainder > 0 ? minutes + 1 : minutes;
	}

	public void dump(String title) {
		System.debug('x7sEventsRsvpModelList: ' + title);
		for (x7sEventsRsvpModel record : this.records) {
			record.dump(title);
		}
	}
}