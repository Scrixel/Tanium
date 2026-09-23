/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsRegistration {
	public class EventsRegistrationException extends Exception {
	}

	static public Map<String, List<SObject>> MetadataCoverageRecordMap = new Map<String, List<SObject>>();

	// Current community ID
	private static Id communityId {
		get {
			return System.Network.getNetworkId();
		}
	}

	private static Id getContactId() {
		return [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED]
		?.ContactId;
	}

	/**
	 * @description Method to fetch the rsvp member status. Whether they are joining or not.
	 * @param eventId Event Id
	 * @return  True if member is joining else false
	 */
	@AuraEnabled
	public static Boolean getMemberAttendance(Id eventId) {
		try {
			if (!X7S_Event_RSVP__c.SObjectType.getDescribe().isAccessible()) {
				System.debug('Error: Cannot access X7S_Event_RSVP__c object.');
				return false;
			}

			Id contactId = getContactId();
			List<X7S_Event_RSVP__c> lstEventRSVP;

			if (contactId == null) {
				lstEventRSVP = new List<X7S_Event_RSVP__c>(
					[
						SELECT Id, Name, Event__c, User__c
						FROM X7S_Event_RSVP__c
						WHERE Event__c = :eventId AND User__c = :UserInfo.getUserId()
					]
				);
			} else {
				lstEventRSVP = new List<X7S_Event_RSVP__c>(
					[
						SELECT Id, Name, Event__c, User__c
						FROM X7S_Event_RSVP__c
						WHERE
							Event__c = :eventId
							AND (User__c = :UserInfo.getUserId()
							OR Contact__c = :contactId)
					]
				);
			}
			System.debug('contact id: ' + contactId);
			System.debug('RSVP List: ' + lstEventRSVP.isEmpty());

			return !lstEventRSVP.isEmpty();
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Method to fetch the rsvp reg url and Status.
	 * @param eventId Event Id
	 * @return Event RSVP Object
	 */
	@AuraEnabled
	public static X7S_Event_RSVP__c getRegUrlAndStatus(Id eventId) {
		try {
			if (!X7S_Event_RSVP__c.SObjectType.getDescribe().isAccessible()) {
				System.debug('Error: Cannot access X7S_Event_RSVP__c object.');
				return null;
			}

			Id contactId = getContactId();
			List<X7S_Event_RSVP__c> lstEventRSVP;

			if (contactId == null) {
				lstEventRSVP = new List<X7S_Event_RSVP__c>(
					[
						SELECT Id, Registration_Url__c, Registration_Status__c, Response__c
						FROM X7S_Event_RSVP__c
						WHERE Event__c = :eventId AND User__c = :UserInfo.getUserId()
					]
				);
			} else {
				lstEventRSVP = new List<X7S_Event_RSVP__c>(
					[
						SELECT Id, Registration_Url__c, Registration_Status__c, Response__c
						FROM X7S_Event_RSVP__c
						WHERE
							Event__c = :eventId
							AND (User__c = :UserInfo.getUserId()
							OR Contact__c = :contactId)
					]
				);
			}

			return lstEventRSVP.isEmpty() ? null : lstEventRSVP[0];
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Method to create X7S_Event_RSVP__c records on clicking yes on the RSVP component.
	 * @param rsvpObj Event RSVP Object
	 * @param eventId Event Id
	 * @param response RSVP Response
	 * @return Newly created RSVP Record
	 */
	@AuraEnabled
	public static X7S_Event_RSVP__c createRegistration(
		X7S_Event_RSVP__c rsvpObj,
		Id eventId,
		String response
	) {
		try {
			if (X7S_Event_RSVP__c.SObjectType.getDescribe().isCreateable()) {
				User user = [
					SELECT Id, ContactId
					FROM User
					WHERE Id = :UserInfo.getUserId()
					WITH SECURITY_ENFORCED
					LIMIT 1
				];
				Id contactId;

				if (user.ContactId != null) {
					contactId = user.ContactId;
				}

				if (
					[
						SELECT COUNT()
						FROM X7S_Event_RSVP__c
						WHERE Event__c = :eventId AND User__c = :UserInfo.getUserId()
					] <= 0
				) {
					String firstName = UserInfo.getFirstName();
					rsvpObj.Event__c = eventId;
					rsvpObj.User__c = UserInfo.getUserId();
					rsvpObj.First_Name__c = String.isBlank(firstName)
						? System.Label.x7sEventsNoFirstName
						: firstName;
					rsvpObj.Last_Name__c = UserInfo.getLastName();
					rsvpObj.Email__c = UserInfo.getUserEmail();
					rsvpObj.Contact__c = contactId;
					rsvpObj.Response__c = response;

					// Add Zoom Registrant.
					X7S_Event__c event = [
						SELECT
							Id,
							Name,
							MeetingId__c,
							Meeting_Type__c,
							Registration__c,
							Event_Format__c,
							Host_Email__c
						FROM X7S_Event__c
						WHERE Id = :eventId
						WITH SECURITY_ENFORCED
					];

					x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
						event
					);

					x7sEventsIExternalMeetingResponse externalMeetingResponse = externalMeeting.addRegistrant(
						event,
						rsvpObj
					);

					if (!externalMeetingResponse.isSuccess()) {
						throw new EventsRegistrationException(externalMeetingResponse.getError());
					}

					insert rsvpObj;
				}
			}
			return null;
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Method to Check that user has registered for Event.
	 * @param eventId Event Id
	 * @return If registered then true else false
	 */
	@AuraEnabled
	public static Boolean checkRegistration(Id eventId) {
		try {
			if (!X7S_Event__c.SObjectType.getDescribe().isAccessible()) {
				System.debug('Error: Cannot access Event__c object.');
				return false;
			}

			Id contactId = getContactId();
			Integer rsvpCount;

			if (contactId == null) {
				rsvpCount = [
					SELECT COUNT()
					FROM X7S_Event_RSVP__c
					WHERE
						Event__c = :eventId
						AND User__c = :UserInfo.getUserId()
						AND Event__r.NetworkId__c = :communityId
						AND Registration_Status__c = :x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_APPROVED
				];
			} else {
				rsvpCount = [
					SELECT COUNT()
					FROM X7S_Event_RSVP__c
					WHERE
						Event__c = :eventId
						AND (User__c = :UserInfo.getUserId()
						OR Contact__c = :contactId)
						AND Event__r.NetworkId__c = :communityId
						AND Registration_Status__c = :x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_APPROVED
				];
			}

			return rsvpCount > 0;
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/*
	 * MethodName	: getAttendeeCount
	 * param			: EventId
	 * Description	: Method to fetch number of Attendees for the event.
	 */
	@AuraEnabled
	public static Decimal getAttendeeCount(Id eventId) {
		X7S_Event__c[] events = [
			SELECT Id, Number_of_Attendees__c
			FROM X7S_Event__c
			WHERE Id = :eventId
			WITH SECURITY_ENFORCED
		];

		return (events.size() > 0) ? events[0].Number_of_Attendees__c : 0;
	}

	/**
	 * @description Method to delete X7S_Event_RSVP__c records on clicking No on RSVP component.
	 * @param EventId  Event Id
	 * @return Event RSVP Object
	 */
	@AuraEnabled
	public static X7S_Event_RSVP__c deleteRegistration(Id EventId) {
		try {
			if (EventId != null && X7S_Event_RSVP__c.SObjectType.getDescribe().isDeletable()) {
				// Cancel a users registration in a external system.
				// Need to load the objects for the process.
				X7S_Event_RSVP__c eventRSVP = [
					SELECT
						Id,
						Registration_Id__c,
						User__c,
						Email__c,
						Registration_Status__c,
						Event_Segment__c,
						Response__c
					FROM X7S_Event_RSVP__c
					WHERE Event__c = :EventId AND User__c = :UserInfo.getUserId()
				];
				X7S_Event__c event = [
					SELECT Id, Name, MeetingId__c, Meeting_Type__c, Registration__c, Event_Format__c
					FROM X7S_Event__c
					WHERE Id = :EventId
					WITH SECURITY_ENFORCED
				];

				// This will set the action to cancel.
				eventRSVP.Registration_Status__c = x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_CANCEL;

				x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
					event
				);

				x7sEventsIExternalMeetingResponse externalMeetingResponse = externalMeeting.updateRegistrant(
					event,
					eventRSVP
				);

				if (!externalMeetingResponse.isSuccess()) {
					System.debug('Error: ' + externalMeetingResponse.getError());

					throw new EventsRegistrationException(externalMeetingResponse.getError());
				}

				delete [
					SELECT Id
					FROM X7S_Event_RSVP__c
					WHERE User__c = :UserInfo.getUserId() AND Event__c = :EventId
					LIMIT 1
				];
			}

			return null;
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Method to all fields related to CMT setting.
	 * @param cmtName  RSVP CMT Setting name
	 * @return x7sEventsRegList
	 */
	@AuraEnabled
	public static x7sEventsRegList getRegFields(String cmtName) {
		List<x7sEventsRegistrationFieldsModal> regRecords = new List<x7sEventsRegistrationFieldsModal>();
		x7sEventsRegList regList = new x7sEventsRegList();

		Boolean allRequired = false;
		if (String.isNotBlank(cmtName)) {
			try {
				X7S_Event_Reg_Setting__mdt regSet = X7S_Event_Reg_Setting__mdt.getInstance(cmtName);
				String fieldSetName = regSet.X7S_Event_Reg_Field_Set__c;
				if (String.isNotBlank(fieldSetName)) {
					X7S_Event_Reg_Field_Set__mdt reqField = X7S_Event_Reg_Field_Set__mdt.getInstance(
						fieldSetName
					);
					allRequired = reqField.All_Fields_Required__c;

					Map<String, X7S_Event_Reg_Field_Set_Assignment__mdt> mapEd = X7S_Event_Reg_Field_Set_Assignment__mdt.getAll();

					for (String rec : mapEd.keySet()) {
						if (mapEd.get(rec).X7S_Event_Field_Set_Name__c == fieldSetName) {
							String fieldName = mapEd.get(rec).X7S_Event_Field_Name__c;
							if (String.isNotBlank(fieldName)) {
								X7S_Event_Reg_Field__mdt mc = X7S_Event_Reg_Field__mdt.getInstance(fieldName);
								List<String> picklistValues = new List<String>();
								String apiName = mc.Field_API_Name__c;
								String fieldType = mc.Type__c;
								String fieldToolTip = mc.Tooltip_Text__c;
								Boolean fieldRequired = false;
								String label = '';

								if (mc.Type__c == 'Picklist') {
									picklistValues = getPicklistValues(mc.Field_API_Name__c);
								}

								if (String.isNotBlank(mc.Field_API_Name__c)) {
									if (isFieldRequired(mc.Field_API_Name__c)) {
										fieldRequired = true;
									} else if (allRequired == true) {
										fieldRequired = true;
									} else {
										fieldRequired = mapEd.get(rec).Required__c;
									}
								}

								if (String.isNotBlank(mapEd.get(rec).Field_Label_Override__c)) {
									label = mapEd.get(rec).Field_Label_Override__c;
								} else {
									label = getFieldLabel(mc.Field_API_Name__c, mc.Field_Label__c);
								}
								regRecords.add(
									new x7sEventsRegistrationFieldsModal(
										apiName,
										label,
										fieldType,
										fieldToolTip,
										fieldRequired,
										picklistValues
									)
								);
								regList.listItem = regRecords;
							}
						}
					}
				}
				return regList;
			} catch (Exception ex) {
				System.debug('Error Message:' + ex.getMessage() + ', Error Line:' + ex.getLineNumber());
				throw new AurahandledException(ex.getMessage());
			}
		}
		return null;
	}

	private static String getFieldLabel(String fieldAPIName, String fieldLabel) {
		List<Schema.DescribeSObjectResult> describeSobjectsResult = Schema.describeSObjects(
			new List<String>{ 'X7S_Event_RSVP__c' }
		); // this can accept list of strings, we describe only one object here
		Map<String, Schema.SObjectField> allFields = describeSobjectsResult[0].fields.getMap();

		String fLabel = '';
		try {
			if (String.isBlank(fieldLabel)) {
				fLabel = allFields.get(fieldAPIName).getDescribe().getLabel();
			} else {
				fLabel = String.escapeSingleQuotes(fieldLabel);
			}
		} catch (Exception ex) {
			System.debug('Invalid Field - ' + fieldAPIName + '- Error :' + ex.getMessage());
		}
		return fLabel;
	}

	private static List<String> getPicklistValues(String Field_name) {
		String ObjectApi_name = 'X7S_Event_RSVP__c';
		List<String> lstPickvals = new List<String>();
		Schema.SObjectType targetType = Schema.getGlobalDescribe().get(ObjectApi_name);
		SObject Object_name = targetType.newSObject();
		Schema.SObjectType sobject_type = Object_name.getSObjectType();
		Schema.DescribeSObjectResult sobject_describe = sobject_type.getDescribe();
		Map<String, Schema.SObjectField> field_map = sobject_describe.fields.getMap();
		List<Schema.PicklistEntry> pick_list_values = field_map.get(Field_name)
			.getDescribe()
			.getPicklistValues();
		for (Schema.PicklistEntry a : pick_list_values) {
			lstPickvals.add(a.getValue());
		}
		return lstPickvals;
	}

	private static Boolean isFieldRequired(String fieldAPIName) {
		Boolean isRequired = false;
		try {
			Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
			Schema.DescribeSObjectResult r = gd.get('X7S_Event_RSVP__c').getDescribe();
			Map<String, Schema.SObjectField> FsMap = r.fields.getMap();
			if (FsMap.containsKey(fieldAPIName)) {
				Schema.DescribeFieldResult fieldDetails = FsMap.get(fieldAPIName).getDescribe();
				if (!fieldDetails.isNillable()) {
					isRequired = true;
				}
			}
		} catch (Exception ex) {
			System.debug('Invalid Field - ' + fieldAPIName + '- Error :' + ex.getMessage());
		}
		return isRequired;
	}
	@AuraEnabled
	public static Integer getExperienceCount(String EventId, String segment) {
		Integer totalCount = 0;
		try {
			if (String.isNotBlank(EventId) && String.isNotBlank(segment)) {
				List<AggregateResult> segments = [
					SELECT count(Event_Segment__c) total
					FROM X7S_Event_RSVP__c
					WHERE
						Event__c = :EventId
						AND Event_Segment__r.Segment__c = :segment
						AND Response__c = :x7sEventsRegistrationController.RSVP_RESPONSE_YES
						AND Response__c != :x7sEventsRegistrationController.RSVP_RESPONSE_WAIT_LIST
						AND Registration_Status__c != :x7sEventsRegistrationController.RSVP_REGISTRATION_STATUS_PENDING
						AND Registration_Status__c != :x7sEventsRegistrationController.RSVP_REGISTRATION_STATUS_DENIED
					WITH SECURITY_ENFORCED
				];
				if (!segments.isEmpty()) {
					totalCount = (Integer) segments[0].get('total');
					System.debug('---totalCount---' + totalCount);
					if (totalCount > 0) {
						return totalCount;
					} else {
						return 0;
					}
				}
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
		return totalCount;
	}
}