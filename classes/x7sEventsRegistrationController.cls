/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsRegistrationController {
	// Zoom constants
	public static final String USER_EMAIL = 'email';
	public static final String COMPANY = 'org';
	public static final String USER_ID = 'user_id';
	public static final String PARTICIPANT_NAME = 'name';
	public static final String PARTICIPANT_ID = 'user_id';
	public static final String PARTICIPANT_EMAIL = 'user_email';
	public static final String JOIN_TIME = 'join_time';
	public static final String LEAVE_TIME = 'leave_time';
	public static final String DURATION = 'duration';
	public static final String REGISTRANT_ID = 'id';
	public static final String FIRSTNAME = 'first_name';
	public static final String LASTNAME = 'last_name';
	public static final String JOIN_URL = 'join_url';
	public static final String REGISTRATION_DATE = 'create_time';
	public static final String REGISTRATION_STATUS = 'status';
	public static final String RSVP_RESPONSE_YES = 'Attending';
	public static final String RSVP_RESPONSE_WAIT_LIST = 'Waitlist';
	public static final String RSVP_REGISTRATION_STATUS_PENDING = 'pending';
	public static final String RSVP_REGISTRATION_STATUS_DENIED = 'denied';
	public static final Integer MAX_LENGTH_FIRST_NAME = 40;
	public static final Integer MAX_LENGTH_LAST_NAME = 80;

	public class MeetingRegistrationException extends Exception {
	}

	// add external user constants
	public static final String INTEGRATION_SETTING = 'Zoom7S';
	public static final String RSVP_USER = 'User';
	public static final String RSVP_CONTACT = 'Contact';
	public static final String RSVP_LEAD = 'Lead';
	public static final String LEAD_STATUS = 'Open - Not Contacted';
	public static final String NAME_SEPARATOR = ' ';

	/**
	 * @description Update meeting RSVP records with participant stats
	 *
	 * @param eventIdList Event ID List
	 */
	@AuraEnabled
	public static void updateMeetingParticipantsWithId(List<String> eventIdList) {
		try {
			updateMeetingParticipants(getEvents(eventIdList));
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Update meeting RSVP records with participant stats
	 *
	 * @param eventList list of events
	 */
	public static void updateMeetingParticipants(List<X7S_Event__c> eventList) {
		if (!eventList.isEmpty()) {
			Set<String> eventIdSet = new Set<String>();

			for (X7S_Event__c event : eventList) {
				eventIdSet.add(event.Id);
			}

			x7sEventsRsvpModelList rsvpRecords = getParticipants(eventList, eventIdSet);

			if (!rsvpRecords.records.isEmpty()) {
				updateParticipants(rsvpRecords, eventIdSet);
			}
		}
	}

	private static x7sEventsRsvpModelList getParticipants(
		List<X7S_Event__c> eventList,
		Set<String> eventIdSet
	) {
		x7sEventsRsvpModelList rsvpRecords = new x7sEventsRsvpModelList();
		Map<String, String> eventIdToSegmentIdMap = new Map<String, String>();

		for (X7S_Event_Segment__c eventSegment : [
			SELECT Id, Event__c
			FROM X7S_Event_Segment__c
			WHERE Event__c IN :eventIdSet AND Segment__c = :x7sEventsSegmentController.SEGMENT_VIRTUAL
			WITH SECURITY_ENFORCED
		]) {
			eventIdToSegmentIdMap.put(eventSegment.Event__c, eventSegment.Id);
		}

		for (X7S_Event__c eventItem : eventList) {
			x7sEventsIExternalMeeting meeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
				eventItem
			);

			x7sEventsIExternalMeetingResponse response = meeting.getParticipants(eventItem);

			if (response.isSuccess() && String.isNotBlank(response.getResult())) {
				List<Object> meetingInfo = (List<Object>) JSON.deserializeUntyped(response.getResult());

				for (Object entry : meetingInfo) {
					x7sEventsRsvpModel newRegistrant = getParticipant(
						(Map<String, Object>) entry,
						eventItem.Id,
						eventIdToSegmentIdMap
					);
					if (newRegistrant != null) {
						rsvpRecords.addRsvp(newRegistrant);
					}
				}
			}
		}

		return rsvpRecords;
	}

	@TestVisible
	private static x7sEventsRsvpModel getParticipant(
		Map<String, Object> entryItem,
		String eventId,
		Map<String, String> eventIdToSegmentIdMap
	) {
		x7sEventsRsvpModel rsvp = new x7sEventsRsvpModel(eventId);

		rsvp.eventSegmentId = eventIdToSegmentIdMap.get(eventId);
		rsvp.userId = (String) entryItem.get(USER_ID);
		rsvp.name = (String) entryItem.get(PARTICIPANT_NAME);
		rsvp.registrantId = (String) entryItem.get(PARTICIPANT_ID);
		rsvp.email = (String) entryItem.get(PARTICIPANT_EMAIL);
		rsvp.attendeeJoin = (String) entryItem.get(JOIN_TIME);
		rsvp.attendeeLeave = (String) entryItem.get(LEAVE_TIME);
		rsvp.attendeeDuration = String.valueOf((Integer) entryItem.get(DURATION));
		rsvp.registrationDate = (String) entryItem.get(REGISTRATION_DATE);
		rsvp.registrationStatus = (String) entryItem.get(REGISTRATION_STATUS);

		if (String.isBlank((String) entryItem.get(PARTICIPANT_EMAIL))) {
			System.debug('Participant email not found: ' + rsvp);
			return null;
		}

		return rsvp;
	}

	@TestVisible
	private static void updateParticipants(
		x7sEventsRsvpModelList rsvpRecords,
		Set<String> eventIdSet
	) {
		x7sEventsRsvpModelList rsvpCandidates = new x7sEventsRsvpModelList();
		x7sEventsRsvpModelList newRsvpRecords = new x7sEventsRsvpModelList();
		Set<X7S_Event_RSVP__c> updatedRsvpRecords = new Set<X7S_Event_RSVP__c>();
		List<X7S_Event_RSVP__c> existingRsvpRecords = getExistingRsvpRecords(eventIdSet);
		Map<String, X7S_Event_RSVP__c> mapEmailToRsvp = new Map<String, X7S_Event_RSVP__c>();

		for (X7S_Event_RSVP__c eventRSVP : existingRsvpRecords) {
			mapEmailToRsvp.put(eventRSVP.Email__c.toLowerCase() + eventRSVP.Event__c, eventRSVP);
		}

		for (x7sEventsRsvpModel participantRsvp : rsvpRecords.records) {
			String emailIdKey = participantRsvp.email.toLowerCase() + participantRsvp.eventId;

			if (mapEmailToRsvp.containsKey(emailIdKey)) {
				updatedRsvpRecords.add(
					setRsvpRecordValues(mapEmailToRsvp.get(emailIdKey), participantRsvp)
				);
			} else {
				rsvpCandidates.addRsvp(participantRsvp);
			}
		}
		//rsvpCandidates.dump('RSVP Candidates');

		if (!rsvpCandidates.records.isEmpty()) {
			x7sEventsRsvpModelList newLeadRecords = new x7sEventsRsvpModelList();
			Map<String, String> externalUsersEmail = getEmailAddressesFromExternalRecords(rsvpRecords);
			Map<String, String> existingUserEmailList = getExistingUsersEmail(externalUsersEmail);
			Map<String, String> newUserEmailList = getNewsUsersFromExternalUsers(
				existingUserEmailList,
				externalUsersEmail
			);

			for (x7sEventsRsvpModel newRsvp : rsvpCandidates.records) {
				if (newUserEmailList.containsKey(newRsvp.email.toLowerCase())) {
					newLeadRecords.addRsvp(newRsvp);
				} else {
					newRsvpRecords.addRsvp(newRsvp);
				}
			}

			if (generateLeadsEnabled()) {
				// Add new rsvp items for new leads.
				for (x7sEventsRsvpModel rsvpModel : newLeadRecords.records) {
					newRsvpRecords.addRsvp(rsvpModel);
				}

				Map<String, Lead> newLeads = buildNewLeads(newRsvpRecords, newUserEmailList);

				if (
					!newLeads.isEmpty() &&
					Lead.SObjectType.getDescribe().isAccessible() &&
					Lead.SObjectType.getDescribe().isCreateable() &&
					Lead.SObjectType.getDescribe().isUpdateable()
				) {
					upsert newLeads.values();

					updateNewRsvpRecords(newRsvpRecords, newLeads);
				}
			}
		}

		if (
			X7S_Event_RSVP__c.SObjectType.getDescribe().isAccessible() &&
			X7S_Event_RSVP__c.SObjectType.getDescribe().isCreateable() &&
			X7S_Event_RSVP__c.SObjectType.getDescribe().isUpdateable()
		) {
			if (!updatedRsvpRecords.isEmpty()) {
				upsert new List<X7S_Event_RSVP__c>(updatedRsvpRecords);
			}

			//newRsvpRecords.dump('New RSVP Records');

			if (!newRsvpRecords.records.isEmpty()) {
				List<X7S_Event_RSVP__c> newRecords = createNewRsvpRecords(newRsvpRecords);

				for (X7S_Event_RSVP__c eventRSVP : newRecords) {
					x7sEventsRsvpModel eventsRsvpModel = newRsvpRecords.findByEmail(
						eventRSVP.Email__c,
						eventRSVP.Event__c
					);

					if (eventsRsvpModel != null) {
						setRsvpRecordValues(eventRSVP, eventsRsvpModel);
					}
				}

				upsert newRecords;
			}
		}
	}

	private static X7S_Event_RSVP__c setRsvpRecordValues(
		X7S_Event_RSVP__c rsvpRecord,
		x7sEventsRsvpModel participantRsvp
	) {
		rsvpRecord.Participant_Id__c = participantRsvp.registrantId;
		rsvpRecord.Participant_Start__c = Datetime.valueOfGmt(
			participantRsvp.attendeeJoin.replace('T', ' ')
		);
		rsvpRecord.Participant_End__c = Datetime.valueOfGmt(
			participantRsvp.attendeeLeave.replace('T', ' ')
		);
		rsvpRecord.Participant_Duration__c = Decimal.valueOf(participantRsvp.attendeeDuration);
		rsvpRecord.Response__c = RSVP_RESPONSE_YES;

		return rsvpRecord;
	}

	/**
	 * @description Update RSVP records for all external registrant for a list of events.
	 *
	 * @param eventIdList Event ID List
	 */
	@AuraEnabled
	public static void updateMeetingRegistrantsWithId(List<String> eventIdList) {
		try {
			updateMeetingRegistrants(getEvents(eventIdList));
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Update RSVP records for all external registrant for a list of events.
	 *
	 * @param eventList list of events
	 */
	public static void updateMeetingRegistrants(List<X7S_Event__c> eventList) {
		if (!eventList.isEmpty()) {
			x7sEventsRsvpModelList externalRegistrants = getRegistrants(eventList);

			if (!externalRegistrants.records.isEmpty()) {
				x7sEventsIExternalMeetingResponse updateResponse = updateRegistrants(externalRegistrants);

				if (!updateResponse.isSuccess()) {
					throw new MeetingRegistrationException('updateMeetingRegistrants');
				}
			}
		}
	}

	@TestVisible
	private static x7sEventsRsvpModelList getRegistrants(List<X7S_Event__c> eventList) {
		x7sEventsRsvpModelList rsvpRecords = new x7sEventsRsvpModelList();
		List<String> eventIds = new List<String>();
		Map<String, String> eventIdToSegmentIdMap = new Map<String, String>();

		for (X7S_Event__c event : eventList) {
			eventIds.add(event.Id);
		}

		for (X7S_Event_Segment__c eventSegment : [
			SELECT Id, Event__c
			FROM X7S_Event_Segment__c
			WHERE Event__c IN :eventIds AND Segment__c = :x7sEventsSegmentController.SEGMENT_VIRTUAL
			WITH SECURITY_ENFORCED
		]) {
			eventIdToSegmentIdMap.put(eventSegment.Event__c, eventSegment.Id);
		}

		for (X7S_Event__c eventItem : eventList) {
			x7sEventsIExternalMeeting meeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
				eventItem
			);

			x7sEventsIExternalMeetingResponse response = meeting.getRegistrants(eventItem);

			if (response.isSuccess() && String.isNotBlank(response.getResult())) {
				List<Object> meetingRegistrants = (List<Object>) JSON.deserializeUntyped(
					response.getResult()
				);

				for (Object entry : meetingRegistrants) {
					x7sEventsRsvpModel newRegistrant = getRegistrant(
						(Map<String, Object>) entry,
						eventItem.Id,
						eventIdToSegmentIdMap
					);
					if (newRegistrant != null) {
						rsvpRecords.addRegistrantRsvp(newRegistrant);
					}
				}
			}
		}

		return rsvpRecords;
	}

	@TestVisible
	private static x7sEventsRsvpModel getRegistrant(
		Map<String, Object> entryItem,
		String eventId,
		Map<String, String> eventIdToSegmentIdMap
	) {
		x7sEventsRsvpModel rsvp = new x7sEventsRsvpModel(eventId);

		rsvp.eventSegmentId = eventIdToSegmentIdMap.get(eventId);
		rsvp.registrantId = (String) entryItem.get(REGISTRANT_ID);

		updateRegistrantFirstLastName(
			rsvp,
			(String) entryItem.get(FIRSTNAME),
			(String) entryItem.get(LASTNAME)
		);

		rsvp.email = (String) entryItem.get(USER_EMAIL);
		rsvp.company = (String) entryItem.get(COMPANY);
		rsvp.joinUrl = (String) entryItem.get(JOIN_URL);
		rsvp.registrationDate = (String) entryItem.get(REGISTRATION_DATE);
		rsvp.registrationStatus = (String) entryItem.get(REGISTRATION_STATUS);

		if (String.isBlank((String) entryItem.get(USER_EMAIL))) {
			System.debug('Registrant email not found: ' + rsvp);
			return null;
		}

		return rsvp;
	}

	@TestVisible
	private static void updateRegistrantFirstLastName(
		x7sEventsRsvpModel rsvp,
		String firstName,
		String lastName
	) {
		// Check if first name is valid
		if (String.isNotBlank(firstName)) {
			Map<String, String> nameComponents = splitNameAndTruncate(firstName);

			if (nameComponents.size() > 1 && String.isBlank(lastName)) {
				rsvp.firstName = getSafeName(nameComponents.get(x7sEventsRegistrationController.FIRSTNAME));
				rsvp.lastName = getSafeName(nameComponents.get(x7sEventsRegistrationController.LASTNAME));

				return;
			}

			rsvp.firstName = getSafeName(truncateName(firstName, MAX_LENGTH_FIRST_NAME));
		} else {
			rsvp.firstName = x7sEventsBaseController.UNKNOWN_NAME;
		}

		// Check if last name is valid
		rsvp.lastName = getSafeName(truncateName(lastName, MAX_LENGTH_FIRST_NAME));
	}

	@TestVisible
	private static Map<String, String> splitNameAndTruncate(String name) {
		String[] nameParts = name.split(' ');
		Map<String, String> nameComponents = new Map<String, String>();

		if (nameParts.size() > 1) {
			nameComponents.put(FIRSTNAME, truncateName(nameParts[0], MAX_LENGTH_FIRST_NAME));
			nameParts.remove(0);
			nameComponents.put(LASTNAME, truncateName(String.join(nameParts, ' '), MAX_LENGTH_LAST_NAME));
		} else {
			nameComponents.put(FIRSTNAME, truncateName(name, MAX_LENGTH_FIRST_NAME));
		}

		return nameComponents;
	}

	@TestVisible
	private static String getSafeName(String name) {
		if (String.isBlank(name)) {
			return x7sEventsBaseController.UNKNOWN_NAME;
		}

		return name.trim();
	}

	@TestVisible
	private static x7sEventsExternalMeetingResponse updateRegistrants(
		x7sEventsRsvpModelList externalRegistrants
	) {
		x7sEventsExternalMeetingResponse registrantResponse = new x7sEventsExternalMeetingResponse();

		x7sEventsRsvpModelList deniedRegistrants = new x7sEventsRsvpModelList();
		x7sEventsRsvpModelList allowedRegistrants = new x7sEventsRsvpModelList();

		// get a list of events
		Set<String> eventIdList = new Set<String>();
		for (x7sEventsRsvpModel rsvp : externalRegistrants.records) {
			if (rsvp.registrationStatus == x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_DENIED) {
				// Collect users that have status = Denied.
				deniedRegistrants.addRsvp(rsvp);
			} else {
				allowedRegistrants.addRsvp(rsvp);
			}

			eventIdList.add(rsvp.eventId);
		}
		//deniedRegistrants.dump('Denied Users');
		//allowedRegistrants.dump('Allowed Users');

		x7sEventsRsvpModelList newLeadRecords = new x7sEventsRsvpModelList();

		List<X7S_Event_RSVP__c> existingRsvpRecords = getExistingRsvpRecords(eventIdList);
		// Get any RSVP records for users with status = Denied
		List<X7S_Event_RSVP__c> deniedRsvpRecords = getRsvpRecords(
			existingRsvpRecords,
			deniedRegistrants
		);

		// This will return a map with keys of emails and event ids.  This will give us a list of existing
		// rsvp objects for each event.
		Map<String, String> emailListExistingRsvp = getEmailAddressesFromRsvpRecords(
			existingRsvpRecords
		);
		Map<String, String> emailListExternalRegistrants = getEmailAddressesFromExternalRecords(
			allowedRegistrants
		);
		Map<String, String> emailListExistingUsers = getExistingUsersEmail(
			emailListExternalRegistrants
		);
		Map<String, String> emailListNewUsers = getNewsUsersFromExternalUsers(
			emailListExistingUsers,
			emailListExternalRegistrants
		);

		// get new rsvp candidates
		x7sEventsRsvpModelList newRsvpRecords = new x7sEventsRsvpModelList();

		for (x7sEventsRsvpModel entry : allowedRegistrants.records) {
			if (!emailListExistingRsvp.containsKey(entry.email.toLowerCase() + entry.eventId)) {
				if (emailListNewUsers.containsKey(entry.email.toLowerCase())) {
					newLeadRecords.addRsvp(entry);
				} else {
					newRsvpRecords.addRsvp(entry);
				}
			}
		}

		if (generateLeadsEnabled()) {
			// Add new rsvp items for new leads.
			for (x7sEventsRsvpModel rsvpModel : newLeadRecords.records) {
				newRsvpRecords.addRsvp(rsvpModel);
			}

			Map<String, Lead> newLeads = buildNewLeads(newRsvpRecords, emailListNewUsers);

			if (
				!newLeads.isEmpty() &&
				Lead.SObjectType.getDescribe().isAccessible() &&
				Lead.SObjectType.getDescribe().isCreateable() &&
				Lead.SObjectType.getDescribe().isUpdateable()
			) {
				upsert newLeads.values();

				updateNewRsvpRecords(newRsvpRecords, newLeads);
			}
		}

		if (
			X7S_Event_RSVP__c.SObjectType.getDescribe().isCreateable() &&
			X7S_Event_RSVP__c.SObjectType.getDescribe().isUpdateable()
		) {
			// create new rsvp records
			List<X7S_Event_RSVP__c> rsvpUpdates = createNewRsvpRecords(newRsvpRecords);
			if (!rsvpUpdates.isEmpty()) {
				upsert rsvpUpdates;
			}

			existingRsvpRecords = getUpdateExistingRsvpStatus(existingRsvpRecords, allowedRegistrants);

			if (!existingRsvpRecords.isEmpty()) {
				upsert existingRsvpRecords;
			}
		}

		// Delete cancelled Zoom registrants
		if (X7S_Event_RSVP__c.SObjectType.getDescribe().isDeletable()) {
			List<X7S_Event_RSVP__c> deletedRsvpRecord = getCancelledRsvpRecordsToDelete(
				existingRsvpRecords,
				externalRegistrants
			);

			// Add denied users RSVP records to be deleted.
			deletedRsvpRecord.addAll(deniedRsvpRecords);

			if (!deletedRsvpRecord.isEmpty()) {
				delete deletedRsvpRecord;
			}
		}

		return registrantResponse;
	}

	private static List<X7S_Event_RSVP__c> getUpdateExistingRsvpStatus(
		List<X7S_Event_RSVP__c> existingRsvpRecords,
		x7sEventsRsvpModelList externalRegistrants
	) {
		List<X7S_Event_RSVP__c> updatedRsvpRecords = new List<X7S_Event_RSVP__c>();

		for (X7S_Event_RSVP__c rsvpRecord : existingRsvpRecords) {
			x7sEventsRsvpModel registrantRsvp = externalRegistrants.findByEmail(
				rsvpRecord.Email__c,
				rsvpRecord.Event__c
			);

			// skip records without an owner
			if (
				registrantRsvp != null &&
				(rsvpRecord.Contact__c != null ||
				rsvpRecord.Lead__c != null ||
				rsvpRecord.User__c != null)
			) {
				rsvpRecord.Registration_Status__c = registrantRsvp.registrationStatus;
				rsvpRecord.Registration_Date__c = Datetime.valueOfGmt(
					registrantRsvp.registrationDate.replace('T', ' ')
				);
				rsvpRecord.Registration_Url__c = registrantRsvp.joinUrl;

				// update owner if needed
				if (registrantRsvp.userType == RSVP_CONTACT) {
					rsvpRecord.Contact__c = registrantRsvp.userId;
				}
				if (registrantRsvp.userType == RSVP_USER) {
					rsvpRecord.User__c = registrantRsvp.userId;
				}
				if (registrantRsvp.userType == RSVP_LEAD) {
					rsvpRecord.Lead__c = registrantRsvp.userId;
				}

				updatedRsvpRecords.add(rsvpRecord);
			}
		}

		return updatedRsvpRecords;
	}

	private static void updateNewRsvpRecords(
		x7sEventsRsvpModelList rsvpRecords,
		Map<String, Lead> newLeads
	) {
		for (x7sEventsRsvpModel rsvpModel : rsvpRecords.records) {
			Lead currentLead = newLeads.get(rsvpModel.email.toLowerCase());

			if (currentLead != null) {
				rsvpModel.userId = currentLead.Id;
				rsvpModel.userType = RSVP_LEAD;
			}
		}
	}

	private static List<X7S_Event_RSVP__c> getRsvpRecords(
		List<X7S_Event_RSVP__c> existingRsvpRecords,
		x7sEventsRsvpModelList externalRegistrants
	) {
		List<X7S_Event_RSVP__c> rsvpRecords = new List<X7S_Event_RSVP__c>();

		for (X7S_Event_RSVP__c rsvpRecord : existingRsvpRecords) {
			for (x7sEventsRsvpModel rsvpModel : externalRegistrants.records) {
				if (
					rsvpModel.eventId == rsvpRecord.Event__c &&
					rsvpModel.email.equalsIgnoreCase(rsvpRecord.Email__c)
				) {
					rsvpRecords.add(rsvpRecord);
				}
			}
		}

		return rsvpRecords;
	}

	@TestVisible
	private static List<X7S_Event_RSVP__c> createNewRsvpRecords(x7sEventsRsvpModelList rsvpRecords) {
		List<X7S_Event_RSVP__c> newRsvpRecords = new List<X7S_Event_RSVP__c>();

		for (x7sEventsRsvpModel rsvp : rsvpRecords.records) {
			if (rsvp.userType == null) {
				KnownUser item = knownUsers.findByEmail(rsvp.email);

				if (item != null) {
					if (item.userType == RSVP_USER) {
						rsvp.userType = RSVP_USER;
						rsvp.userId = item.Id;
					}
					if (item.userType == RSVP_CONTACT) {
						rsvp.userType = RSVP_CONTACT;
						rsvp.userId = item.Id;
					}
					if (item.userType == RSVP_LEAD) {
						rsvp.userType = RSVP_LEAD;
						rsvp.userId = item.Id;
					}
				}
			}

			if (rsvp.userId == null) {
				continue;
			}

			updateFirstLastName(rsvp);

			newRsvpRecords.add(
				new X7S_Event_RSVP__c(
					Event_Segment__c = rsvp.eventSegmentId,
					Event__c = rsvp.eventId,
					Email__c = rsvp.email,
					First_Name__c = rsvp.firstName,
					Last_Name__c = rsvp.lastName,
					Registration_Id__c = rsvp.registrantId,
					Registration_Url__c = rsvp.joinUrl,
					Registration_Date__c = rsvp.registrationDate == null
						? null
						: Datetime.valueOfGmt(rsvp.registrationDate.replace('T', ' ')),
					Registration_Status__c = rsvp.registrationStatus,
					User__c = rsvp.userType == RSVP_USER ? rsvp.userId : null,
					Contact__c = rsvp.userType == RSVP_CONTACT ? rsvp.userId : null,
					Lead__c = rsvp.userType == RSVP_LEAD ? rsvp.userId : null,
					Response__c = RSVP_RESPONSE_YES
				)
			);
		}

		return newRsvpRecords;
	}

	@TestVisible
	private static void updateFirstLastName(x7sEventsRsvpModel rsvpModel) {
		if (
			rsvpModel.firstName == null &&
			rsvpModel.lastName == null &&
			String.isNotEmpty(rsvpModel.name)
		) {
			Map<String, String> nameComponents = splitNameAndTruncate(rsvpModel.name);

			if (nameComponents.size() > 1) {
				rsvpModel.firstName = getSafeName(nameComponents.get(FIRSTNAME));
				rsvpModel.lastName = getSafeName(nameComponents.get(LASTNAME));
			} else {
				rsvpModel.firstName = getSafeName(nameComponents.get(FIRSTNAME));
				rsvpModel.lastName = getSafeName('');
			}
		}
	}

	@TestVisible
	private static Map<String, String> getEmailAddressesFromRsvpRecords(
		List<X7S_Event_RSVP__c> rsvpRecords
	) {
		Map<String, String> emailUpdates = new Map<String, String>();

		for (X7S_Event_RSVP__c entry : rsvpRecords) {
			emailUpdates.put(entry.Email__c.toLowerCase() + entry.Event__c, '');
		}

		return emailUpdates;
	}

	public static Map<String, String> getEmailAddressesFromExternalRecords(
		x7sEventsRsvpModelList rsvpRecords
	) {
		Map<String, String> emailUpdates = new Map<String, String>();

		for (x7sEventsRsvpModel entry : rsvpRecords.records) {
			emailUpdates.put(entry.email.toLowerCase(), entry.eventId);
		}

		return emailUpdates;
	}

	@TestVisible
	private static Map<String, Lead> buildNewLeads(
		x7sEventsRsvpModelList rsvpRecords,
		Map<String, String> emailList
	) {
		List<Lead> newLeads = new List<Lead>();
		Map<String, Lead> leadMap = new Map<String, Lead>();

		for (x7sEventsRsvpModel entry : rsvpRecords.records) {
			if (
				emailList.containsKey(entry.email.toLowerCase()) &&
				!knownUsers.findExistingLead(entry.email.toLowerCase())
			) {
				// Recipient data does not have firstname, lastname
				if (String.isBlank(entry.firstName)) {
					Map<String, String> nameComponents = splitNameAndTruncate(entry.name);

					if (nameComponents.size() > 1) {
						entry.firstName = getSafeName(nameComponents.get(FIRSTNAME));
						entry.lastName = getSafeName(nameComponents.get(LASTNAME));
					} else {
						entry.firstName = getSafeName(nameComponents.get(FIRSTNAME));
						entry.lastName = getSafeName('');
					}
				} else {
					entry.firstName = getSafeName(truncateName(entry.firstName, MAX_LENGTH_FIRST_NAME));
					entry.lastName = getSafeName(truncateName(entry.lastName, MAX_LENGTH_LAST_NAME));
				}

				Lead currentLead = new Lead(
					Email = entry.email,
					FirstName = entry.firstName,
					LastName = entry.lastName,
					Status = LEAD_STATUS,
					Company = String.isNotBlank(entry.company)
						? entry.company
						: Label.x7sEventsRegistrationUnknownCompany
				);

				newLeads.add(currentLead);

				leadMap.put(entry.email.toLowerCase(), currentLead);
			}
		}

		return leadMap;
	}

	@TestVisible
	private class KnownUser {
		public String Id { get; set; }
		public String emailAddress { get; set; }
		public String userType { get; set; }
	}

	@TestVisible
	private class KnownUserList {
		private Map<String, KnownUser> mapKnownUsers = new Map<String, KnownUser>();
		public List<Lead> existingLeads { get; set; }

		public void addUser(String Id, String emailAddress, String userType) {
			if (findByEmail(emailAddress) == null) {
				KnownUser currentUser = new KnownUser();

				currentUser.Id = Id;
				currentUser.emailAddress = emailAddress;
				currentUser.userType = userType;

				mapKnownUsers.put(emailAddress.toLowerCase(), currentUser);
			}
		}

		public KnownUser findByEmail(String email) {
			if (mapKnownUsers.containsKey(email.toLowerCase())) {
				return mapKnownUsers.get(email.toLowerCase());
			}

			return null;
		}

		public Boolean findExistingLead(String email) {
			if (existingLeads != null && String.isNotBlank(email)) {
				for (Lead item : existingLeads) {
					if (item.Email.equalsIgnoreCase(email)) {
						return true;
					}
				}
			}

			return false;
		}

		public void dump(String title) {
			System.debug(title);
			System.debug(knownUsers);
		}
	}

	private static KnownUserList knownUsers = new KnownUserList();

	@TestVisible
	private static Map<String, String> getExistingUsersEmail(Map<String, String> mailUpdates) {
		Map<String, String> existingEmail = new Map<String, String>();

		List<Contact> existingContacts = [
			SELECT Id, Email
			FROM Contact
			WHERE Email IN :mailUpdates.keySet()
			WITH SECURITY_ENFORCED
		];
		for (Contact existingContact : existingContacts) {
			existingEmail.put(existingContact.Email.toLowerCase(), '');
			knownUsers.addUser(existingContact.Id, existingContact.Email, RSVP_CONTACT);
		}

		List<User> existingUsers = [
			SELECT Id, Email
			FROM User
			WHERE Email IN :mailUpdates.keySet()
			WITH SECURITY_ENFORCED
		];
		for (User existingUser : existingUsers) {
			existingEmail.put(existingUser.Email.toLowerCase(), '');
			knownUsers.addUser(existingUser.Id, existingUser.Email, RSVP_USER);
		}

		if (Lead.SObjectType.getDescribe().isAccessible()) {
			List<Lead> existingLeads = [
				SELECT Id, Email
				FROM Lead
				WHERE Email IN :mailUpdates.keySet()
				WITH SECURITY_ENFORCED
			];
			knownUsers.existingLeads = existingLeads;
			for (Lead existingLead : existingLeads) {
				existingEmail.put(existingLead.Email.toLowerCase(), '');
				knownUsers.addUser(existingLead.Id, existingLead.Email, RSVP_LEAD);
			}
		}
		//knownUsers.dump('Found users');

		return existingEmail;
	}

	private static Map<String, String> getNewsUsersFromExternalUsers(
		Map<String, String> existingEmail,
		Map<String, String> externalUsers
	) {
		Map<String, String> emailList = new Map<String, String>();

		for (String email : externalUsers.keySet()) {
			if (!existingEmail.containsKey(email.toLowerCase())) {
				emailList.put(email.toLowerCase(), externalUsers.get(email));
			}
		}

		return emailList;
	}

	public static List<X7S_Event_RSVP__c> getExistingRsvpRecords(Set<String> eventIdList) {
		List<X7S_Event_RSVP__c> existingRsvpRecords = new List<X7S_Event_RSVP__c>();

		String query = 'SELECT Id, Event__c, Email__c, Participant_Id__c, Participant_Start__c, Participant_End__c, Participant_Duration__c, Registration_Status__c, Response__c, User__c, Contact__c ';

		if (Lead.SObjectType.getDescribe().isAccessible()) {
			query += ', Lead__c ';
		}

		query += 'FROM X7S_Event_RSVP__c WHERE Event__c IN :eventIdList WITH SECURITY_ENFORCED';

		existingRsvpRecords = Database.query(query);

		return existingRsvpRecords;
	}

	private static List<X7S_Event_RSVP__c> getCancelledRsvpRecordsToDelete(
		List<X7S_Event_RSVP__c> existingRsvpRecords,
		x7sEventsRsvpModelList externalRegistrantRsvp
	) {
		List<X7S_Event_RSVP__c> deleteRsvpRecords = new List<X7S_Event_RSVP__c>();

		for (X7S_Event_RSVP__c rsvpRecord : existingRsvpRecords) {
			if (externalRegistrantRsvp.findByEmail(rsvpRecord.Email__c, rsvpRecord.Event__c) == null) {
				deleteRsvpRecords.add(rsvpRecord);
			}
		}

		return deleteRsvpRecords;
	}

	private static List<X7S_Event__c> getEvents(List<String> eventIds) {
		return [
			SELECT Id, Name, MeetingId__c, Meeting_Type__c, Event_Format__c, UpComing_Sort__c
			FROM X7S_Event__c
			WHERE Id IN :eventIds
			WITH SECURITY_ENFORCED
		];
	}

	@TestVisible
	private static Boolean generateLeadsEnabled() {
		Boolean show = false;
		X7S_Event_Integration_Setting__mdt settings = X7S_Event_Integration_Setting__mdt.getInstance(
			INTEGRATION_SETTING
		);

		if (settings != null) {
			show = settings.Import_Unknown_Users__c;
		}

		return show;
	}

	/**
	 * truncateName : if the name exceeds the field length (First Name/Last Name) the name will be truncated.
	 *
	 * @param nameToCheck Name to check
	 * @param maxLength Maximum length of name to check.
	 * @return a name that has a valid length.
	 */
	@TestVisible
	public static String truncateName(String nameToCheck, Integer maxLength) {
		String updatedName = nameToCheck;

		if (nameToCheck != null && nameToCheck.length() > maxLength) {
			updatedName = nameToCheck.substring(0, maxLength);
		}

		return updatedName;
	}
}