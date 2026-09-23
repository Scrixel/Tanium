/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsExternalMeetingZoom implements x7sEventsIExternalMeeting {
	/**
	 * Constants
	 */
	private static final String POST = 'POST';
	private static final String HTTP_GET = 'GET';
	private static final String PATCH = 'PATCH';
	private static final String PUT = 'PUT';
	private static final String HTTP_DELETE = 'DELETE';
	private static final String ZOOM_PREFIX = 'https://api.zoom.us/v2';
	private static final String MEETINGS = '/meetings/';
	private static final String WEBINARS = '/webinars/';
	private static final String REGISTRANTS_TEXT = '/registrants';
	private static final String ERROR = 'Error: ';
	/**
	 *  @description Specific representation of parameters for zoom create request
	 */
	private class CreateParameters {
		public String topic { get; set; }
		public Integer type { get; set; }
		public String start_time { get; set; }
		public String timezone { get; set; }
		public Integer duration { get; set; }
		public String agenda { get; set; }
		public Settings settings = new Settings();

		CreateParameters() {
			type = 2; // default meeting type
			timezone = '';
		}
	}

	private class Settings {
		public Integer registration_type { get; set; }
		public String registrants_email_notification { get; set; }
		public Integer approval_type { get; set; }

		Settings() {
			registration_type = 1;
			registrants_email_notification = 'true';
			approval_type = 0;
		}
	}

	private class GetParameters {
		public String occurrence_id { get; set; }
		public Boolean show_previous_occurrences { get; set; }

		GetParameters() {
			occurrence_id = '';
			show_previous_occurrences = false;
		}
	}

	private class AddRegistrantParameters {
		public String email { get; set; }
		public String first_name { get; set; }
		public String last_name { get; set; }
	}

	private class UpdateRegistrantParameters {
		public String action { get; set; }
		public List<Registrant> registrants { get; set; }

		UpdateRegistrantParameters() {
			this.registrants = new List<Registrant>();
		}
	}

	private class Registrant {
		public String id { get; set; }
		public String email { get; set; }
	}

	private class DeleteParameters {
		public String occurrence_id { get; set; }
		public Boolean schedule_for_reminder { get; set; }
		public Boolean cancel_meeting_reminder { get; set; }
	}

	private class ListRegistrantsParameters {
		public String occurrence_id { get; set; }
		public Integer page_size { get; set; }
		public String next_page_token { get; set; }
		public String status { get; set; }

		ListRegistrantsParameters() {
			occurrence_id = '';
			page_size = 100;
			next_page_token = '';
			status = 'approved';
		}
	}

	private class ReportRegistrantsParameters {
		public Integer page_size { get; set; }
		public String next_page_token { get; set; }
		public String include_fields { get; set; }

		ReportRegistrantsParameters() {
			page_size = 100;
			next_page_token = '';
			include_fields = '';
		}
	}

	public class ExternalMeetingException extends Exception {
	}

	private void Check7SEventObject(
		X7S_Event__c x7SEvent,
		x7sEventsExternalMeetingResponse meetingResponse
	) {
		if (x7SEvent == null) {
			meetingResponse.success = false;
			meetingResponse.error = Label.x7sEventsObjectError;
			throw new ExternalMeetingException(Label.x7sEventsObjectError);
		}
	}

	public x7sEventsIExternalMeetingResponse create(X7S_Event__c x7SEvent) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		String url = '';
		String userId = UserInfo.getUserEmail();

		if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.MEETING) {
			url = ZOOM_PREFIX + '/users/' + userId + '/meetings';
		} else if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.WEBINAR) {
			url = ZOOM_PREFIX + '/users/' + userId + '/webinars';
		}

		Integer responseCode = 201;

		meetingResponse = (x7sEventsExternalMeetingResponse) createMeeting(
			x7SEvent,
			url,
			POST,
			responseCode
		);

		return meetingResponse;
	}

	public x7sEventsIExternalMeetingResponse updateExternal(X7S_Event__c x7SEvent) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		String url = '';

		if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.MEETING) {
			url = ZOOM_PREFIX + MEETINGS + x7SEvent.MeetingId__c;
		} else if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.WEBINAR) {
			url = ZOOM_PREFIX + WEBINARS + x7SEvent.MeetingId__c;
		}

		Integer responseCode = 204;

		meetingResponse = (x7sEventsExternalMeetingResponse) createMeeting(
			x7SEvent,
			url,
			PATCH,
			responseCode
		);

		return meetingResponse;
	}

	/**
	 * @description We only expect an event that has a meeting id.  This meeting id can be either a Meeting or a
	 * Webinar.  We will search both to find it.
	 *
	 * @param x7SEvent  : event to hold the meeting Id
	 *
	 * @return A JSON collection of information about the meeting returned by Zoom.
	 */
	public x7sEventsIExternalMeetingResponse get(X7S_Event__c x7SEvent) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		// First try to search Meeting
		String url = ZOOM_PREFIX + MEETINGS + x7SEvent.MeetingId__c;

		meetingResponse = (x7sEventsExternalMeetingResponse) getMeeting(
			x7SEvent,
			url,
			x7sEventsExternalMeetingConstants.MEETING
		);

		if (!meetingResponse.isSuccess()) {
			url = ZOOM_PREFIX + WEBINARS + x7SEvent.MeetingId__c;

			meetingResponse = (x7sEventsExternalMeetingResponse) getMeeting(
				x7SEvent,
				url,
				x7sEventsExternalMeetingConstants.WEBINAR
			);
		}

		return meetingResponse;
	}

	public x7sEventsIExternalMeetingResponse deleteExternal(X7S_Event__c x7SEvent) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		String url;

		if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.MEETING) {
			url = ZOOM_PREFIX + MEETINGS + x7SEvent.MeetingId__c;
		} else if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.WEBINAR) {
			url = ZOOM_PREFIX + WEBINARS + x7SEvent.MeetingId__c;
		}

		meetingResponse = (x7sEventsExternalMeetingResponse) deleteMeeting(x7SEvent, url);

		return meetingResponse;
	}

	public x7sEventsIExternalMeetingResponse addRegistrant(
		X7S_Event__c x7SEvent,
		X7S_Event_RSVP__c x7SEventRSVP
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		if (x7SEvent.Registration__c == x7sEventsExternalMeetingConstants.NONE_REQUIRED) {
			return meetingResponse;
		}

		if (x7SEvent.Host_Email__c == UserInfo.getUserEmail()) {
			return meetingResponse;
		}

		String url;

		if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.MEETING) {
			url = ZOOM_PREFIX + MEETINGS + x7SEvent.MeetingId__c + REGISTRANTS_TEXT;
		} else if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.WEBINAR) {
			url = ZOOM_PREFIX + WEBINARS + x7SEvent.MeetingId__c + REGISTRANTS_TEXT;
		}

		meetingResponse = (x7sEventsExternalMeetingResponse) addMeetingRegistrant(
			x7SEvent,
			x7SEventRSVP,
			url
		);

		return meetingResponse;
	}

	public x7sEventsIExternalMeetingResponse updateRegistrant(
		X7S_Event__c x7SEvent,
		X7S_Event_RSVP__c x7SEventRSVP
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		if (x7SEvent.Registration__c == x7sEventsExternalMeetingConstants.NONE_REQUIRED) {
			return meetingResponse;
		}

		String url;

		if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.MEETING) {
			url = ZOOM_PREFIX + MEETINGS + x7SEvent.MeetingId__c + '/registrants/status';
		} else if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.WEBINAR) {
			url = ZOOM_PREFIX + WEBINARS + x7SEvent.MeetingId__c + '/registrants/status';
		}

		meetingResponse = (x7sEventsExternalMeetingResponse) updateMeetingRegistrant(
			x7SEvent,
			x7SEventRSVP,
			url
		);

		return meetingResponse;
	}

	public x7sEventsIExternalMeetingResponse getRegistrants(X7S_Event__c x7SEvent) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		String url;

		if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.MEETING) {
			url = ZOOM_PREFIX + MEETINGS + x7SEvent.MeetingId__c + REGISTRANTS_TEXT;
		} else if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.WEBINAR) {
			url = ZOOM_PREFIX + WEBINARS + x7SEvent.MeetingId__c + REGISTRANTS_TEXT;
		}

		meetingResponse = (x7sEventsExternalMeetingResponse) getMeetingRegistrants(x7SEvent, url);

		return meetingResponse;
	}

	public x7sEventsIExternalMeetingResponse getParticipants(X7S_Event__c x7SEvent) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		Check7SEventObject(x7SEvent, meetingResponse);

		String url;

		if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.MEETING) {
			url = ZOOM_PREFIX + '/report/meetings/' + x7SEvent.MeetingId__c + '/participants';
		} else if (x7SEvent.Meeting_Type__c == x7sEventsExternalMeetingConstants.WEBINAR) {
			url = ZOOM_PREFIX + '/report/webinars/' + x7SEvent.MeetingId__c + '/participants';
		}

		meetingResponse = (x7sEventsExternalMeetingResponse) getMeetingParticipants(x7SEvent, url);

		return meetingResponse;
	}

	/**
	 * @description Create Meeting : Create a Zoom meeting with info from a 7S Event.
	 *
	 * @param x7SEvent : 7S Event to create a Zoom meeting from.
	 * @param url : Url to service to call, can be for Meetings or Webinars
	 * @param httpMethod : Type of HTTP request to make,
	 *                      POST - Create a Meeting or Webinar
	 *                      PATCH - Update a Meeting or Webinar
	 * @param responseCode : Successful response code expected.
	 *                      Create : 201
	 *                      Update : 204
	 *
	 * @return x7sEventsIExternalMeetingResponse : response to report function status
	 *      isSuccess()  : true if successful, false otherwise
	 *      getError()   : error message
	 *      getResult()  : data returned by Zoom
	 */
	private x7sEventsIExternalMeetingResponse createMeeting(
		X7S_Event__c x7SEvent,
		String url,
		String httpMethod,
		Integer responseCode
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		try {
			CreateParameters createMeetingParameters = new CreateParameters();
			Integer duration = (Integer) ((x7SEvent.End_DateTime__c.getTime() -
			x7SEvent.Start_DateTime__c.getTime()) /
			1000 /
			60);
			String timeString = x7SEvent.Start_DateTime__c.format('yyyy-MM-dd HH:mm:ss')
				.replace(' ', 'T');

			createMeetingParameters.type = (x7SEvent.Meeting_Type__c ==
				x7sEventsExternalMeetingConstants.MEETING)
				? x7sEventsExternalMeetingConstants.MEETING_VALUE
				: x7sEventsExternalMeetingConstants.WEBINAR_VALUE;
			createMeetingParameters.topic = x7SEvent.Name;
			createMeetingParameters.start_time = timeString;
			createMeetingParameters.timezone = UserInfo.getTimeZone().getID();
			createMeetingParameters.duration = duration;

			if (x7SEvent.Details__c.length() > x7sEventsExternalMeetingConstants.AGENDA_MAX_LENGTH) {
				createMeetingParameters.agenda = x7SEvent.Details__c.substring(
					0,
					x7sEventsExternalMeetingConstants.AGENDA_MAX_LENGTH
				);
			} else {
				createMeetingParameters.agenda = x7SEvent.Details__c;
			}

			if (x7SEvent.Registration__c == x7sEventsExternalMeetingConstants.NONE_REQUIRED) {
				createMeetingParameters.settings.approval_type = x7sEventsExternalMeetingConstants.NONE_REQUIRED_VALUE;
			} else if (x7SEvent.Registration__c == x7sEventsExternalMeetingConstants.AUTO_APPROVAL) {
				createMeetingParameters.settings.approval_type = x7sEventsExternalMeetingConstants.AUTO_APPROVAL_VALUE;
			} else if (x7SEvent.Registration__c == x7sEventsExternalMeetingConstants.MANUAL_APPROVAL) {
				createMeetingParameters.settings.approval_type = x7sEventsExternalMeetingConstants.MANUAL_APPROVAL_VALUE;
			}

			String requestParametersJson = JSON.serialize(createMeetingParameters);

			System.debug('Json: ' + requestParametersJson);

			meetingResponse = httpRequest(
				httpMethod,
				url,
				requestParametersJson,
				x7SEvent.Event_Format__c,
				responseCode
			);

			if (meetingResponse.isSuccess()) {
				System.debug('isSuccess');
				String meetingBody = meetingResponse.getResult();

				// Meeting result will be empty if an update is performed.
				if (String.isNotEmpty(meetingBody)) {
					Map<String, Object> meetingInfo = (Map<String, Object>) JSON.deserializeUntyped(
						meetingResponse.getResult()
					);

					x7SEvent.MeetingId__c = String.valueOf(
						meetingInfo.get(x7sEventsExternalMeetingConstants.ZOOM_MEETING_ID)
					);
					x7SEvent.Join_Url__c = String.valueOf(
						meetingInfo.get(x7sEventsExternalMeetingConstants.JOIN_URL)
					);
					x7SEvent.Start_Url__c = String.valueOf(
						meetingInfo.get(x7sEventsExternalMeetingConstants.START_URL)
					);
					x7SEvent.Registration_Url__c = String.valueOf(
						meetingInfo.get(x7sEventsExternalMeetingConstants.REGISTRATION_URL)
					);
					x7SEvent.Host_Email__c = String.valueOf(
						meetingInfo.get(x7sEventsExternalMeetingConstants.HOST_EMAIL)
					);
					x7SEvent.Created_At__c = convertDateTime(
						String.valueOf(meetingInfo.get(x7sEventsExternalMeetingConstants.CREATED_AT))
					);
				}
			}
		} catch (Exception e) {
			System.debug(ERROR + e.getMessage() + ' line: ' + e.getLineNumber());

			meetingResponse.success = false;
			meetingResponse.error = e.getMessage();
		}

		return meetingResponse;
	}

	private x7sEventsIExternalMeetingResponse getMeeting(
		X7S_Event__c x7SEvent,
		String url,
		String meetingType
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		try {
			Integer responseCode = 200;
			GetParameters getMeetingParameters = new GetParameters();
			String meetingUrl;
			meetingUrl =
				url +
				'?occurrence_id=' +
				getMeetingParameters.occurrence_id +
				'?show_previous_occurrences=' +
				getMeetingParameters.show_previous_occurrences;

			System.debug('URL: ' + meetingUrl);

			meetingResponse = httpRequest(
				HTTP_GET,
				meetingUrl,
				'',
				x7SEvent.Event_Format__c,
				responseCode
			);

			if (meetingResponse.isSuccess()) {
				Map<String, Object> meetingInfo = (Map<String, Object>) JSON.deserializeUntyped(
					meetingResponse.getResult()
				);

				x7SEvent.Meeting_Type__c = meetingType;
				x7SEvent.Name = String.valueOf(meetingInfo.get(x7sEventsExternalMeetingConstants.TOPIC));
				x7SEvent.Details__c = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.AGENDA)
				);
				x7SEvent.Join_Url__c = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.JOIN_URL)
				);
				x7SEvent.Start_Url__c = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.START_URL)
				);
				x7SEvent.Registration_Url__c = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.REGISTRATION_URL)
				);
				x7SEvent.Host_Email__c = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.HOST_EMAIL)
				);
				x7SEvent.Created_At__c = convertDateTime(
					String.valueOf(meetingInfo.get(x7sEventsExternalMeetingConstants.CREATED_AT))
				);

				Map<String, Object> settings = (Map<String, Object>) meetingInfo.get(
					x7sEventsExternalMeetingConstants.SETTINGS
				);
				Integer approvalType = Integer.valueOf(
					settings.get(x7sEventsExternalMeetingConstants.APPROVAL_TYPE)
				);

				x7SEvent.Start_DateTime__c = convertDateTime(
					String.valueOf(meetingInfo.get(x7sEventsExternalMeetingConstants.START_TIME))
				);

				Integer duration = Integer.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.DURATION)
				);

				Datetime meetingEndDate = x7SEvent.Start_DateTime__c.addMinutes(duration);

				x7SEvent.End_DateTime__c = meetingEndDate;

				if (approvalType == x7sEventsExternalMeetingConstants.AUTO_APPROVAL_VALUE) {
					x7SEvent.Registration__c = x7sEventsExternalMeetingConstants.AUTO_APPROVAL;
				} else if (approvalType == x7sEventsExternalMeetingConstants.MANUAL_APPROVAL_VALUE) {
					x7SEvent.Registration__c = x7sEventsExternalMeetingConstants.MANUAL_APPROVAL;
				} else if (approvalType == x7sEventsExternalMeetingConstants.NONE_REQUIRED_VALUE) {
					x7SEvent.Registration__c = x7sEventsExternalMeetingConstants.NONE_REQUIRED;
				}

				// Build result JSON.
				Map<String, Object> meetingInfoUpdate = new Map<String, Object>();

				meetingInfoUpdate.put('Meeting_Type__c', x7SEvent.Meeting_Type__c);
				meetingInfoUpdate.put('Name', x7SEvent.Name);
				meetingInfoUpdate.put('Details__c', x7SEvent.Details__c);
				meetingInfoUpdate.put('Start_DateTime__c', x7SEvent.Start_DateTime__c);
				meetingInfoUpdate.put('End_DateTime__c', x7SEvent.End_DateTime__c);
				meetingInfoUpdate.put('Registration__c', x7SEvent.Registration__c);
				meetingInfoUpdate.put('Join_Url__c', x7SEvent.Join_Url__c);
				meetingInfoUpdate.put('Start_Url__c', x7SEvent.Start_Url__c);
				meetingInfoUpdate.put('Registration_Url__c', x7SEvent.Registration_Url__c);
				meetingInfoUpdate.put('Host_Email__c', x7SEvent.Host_Email__c);
				meetingInfoUpdate.put('Created_At__c', x7SEvent.Created_At__c);

				meetingResponse.success = true;
				meetingResponse.result = JSON.serialize(meetingInfoUpdate);
			}
		} catch (Exception e) {
			System.debug(ERROR + e.getMessage());

			meetingResponse.success = false;
			meetingResponse.error = e.getMessage();
		}

		return meetingResponse;
	}

	private x7sEventsIExternalMeetingResponse deleteMeeting(X7S_Event__c x7SEvent, String url) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		try {
			DeleteParameters deleteMeetingParameters = new DeleteParameters();
			Integer responseCode = 204;
			String meetingUrl;
			deleteMeetingParameters.occurrence_id = '';
			deleteMeetingParameters.schedule_for_reminder = false;
			deleteMeetingParameters.cancel_meeting_reminder = false;

			meetingUrl =
				url +
				'?occurrence_id=' +
				deleteMeetingParameters.occurrence_id +
				'&schedule_for_reminder=' +
				deleteMeetingParameters.schedule_for_reminder +
				'&cancel_meeting_reminder=' +
				deleteMeetingParameters.cancel_meeting_reminder;

			meetingResponse = httpRequest(
				HTTP_DELETE,
				meetingUrl,
				'',
				x7SEvent.Event_Format__c,
				responseCode
			);
		} catch (Exception e) {
			System.debug(ERROR + e.getMessage());

			meetingResponse.success = false;
			meetingResponse.error = e.getMessage();
		}

		return meetingResponse;
	}

	private x7sEventsIExternalMeetingResponse addMeetingRegistrant(
		X7S_Event__c x7SEvent,
		X7S_Event_RSVP__c eventRSVP,
		String url
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		try {
			if (eventRSVP == null) {
				throw new ExternalMeetingException('7S Event RSVP object not set.');
			}

			Integer responseCode = 201;

			AddRegistrantParameters addMeetingRegistrantParameters = new AddRegistrantParameters();

			addMeetingRegistrantParameters.email = eventRSVP.Email__c;
			addMeetingRegistrantParameters.first_name = String.isBlank(eventRSVP.First_Name__c)
				? System.Label.x7sEventsNoFirstName
				: eventRSVP.First_Name__c;
			addMeetingRegistrantParameters.last_name = eventRSVP.Last_Name__c;

			String requestParametersJson = JSON.serialize(addMeetingRegistrantParameters);

			System.debug('Json: ' + requestParametersJson);

			meetingResponse = httpRequest(
				POST,
				url,
				requestParametersJson,
				x7SEvent.Event_Format__c,
				responseCode
			);

			if (meetingResponse.isSuccess()) {
				Map<String, Object> meetingInfo = (Map<String, Object>) JSON.deserializeUntyped(
					meetingResponse.getResult()
				);

				eventRSVP.Registration_Url__c = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.JOIN_URL)
				);
				eventRSVP.Registration_Id__c = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.REGISTRATION_ID)
				);

				String startTime = String.valueOf(
					meetingInfo.get(x7sEventsExternalMeetingConstants.REGISTRATION_DATE)
				);

				startTime = startTime.replace('T', ' ');
				Datetime meetingStartDate = Datetime.valueOfGmt(startTime);

				eventRSVP.Registration_Date__c = meetingStartDate;

				if (x7SEvent.Registration__c == x7sEventsExternalMeetingConstants.AUTO_APPROVAL) {
					eventRSVP.Registration_Status__c = x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_APPROVED;
				} else if (x7SEvent.Registration__c == x7sEventsExternalMeetingConstants.MANUAL_APPROVAL) {
					eventRSVP.Registration_Status__c = x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_PENDING;
				}
			}
		} catch (Exception e) {
			System.debug(ERROR + e.getMessage());

			meetingResponse.success = false;
			meetingResponse.error = e.getMessage();
		}

		return meetingResponse;
	}

	private x7sEventsIExternalMeetingResponse updateMeetingRegistrant(
		X7S_Event__c x7SEvent,
		X7S_Event_RSVP__c eventRSVP,
		String url
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		try {
			if (eventRSVP == null) {
				throw new ExternalMeetingException('7S Event RSVP object not set.');
			}

			Integer responseCode = 204;

			UpdateRegistrantParameters updateRegistrantParameters = new UpdateRegistrantParameters();

			updateRegistrantParameters.action = eventRSVP.Registration_Status__c;

			Registrant registrant = new Registrant();

			registrant.id = eventRSVP.Registration_Id__c;
			registrant.email = eventRSVP.Email__c;

			updateRegistrantParameters.registrants.add(registrant);

			String requestParametersJson = JSON.serialize(updateRegistrantParameters);

			System.debug('Json: ' + requestParametersJson);

			meetingResponse = httpRequest(
				PUT,
				url,
				requestParametersJson,
				x7SEvent.Event_Format__c,
				responseCode
			);
		} catch (Exception e) {
			System.debug(ERROR + e.getMessage());

			meetingResponse.success = false;
			meetingResponse.error = e.getMessage();
		}

		return meetingResponse;
	}

	private x7sEventsIExternalMeetingResponse getMeetingRegistrants(
		X7S_Event__c x7SEvent,
		String url
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		try {
			if (x7SEvent == null) {
				throw new ExternalMeetingException('7S Event object not set.');
			}

			Integer responseCode = 200;

			ListRegistrantsParameters listMeetingRegistrantParameters = new ListRegistrantsParameters();
			List<Object> meetingRegistrants = new List<Object>();

			// Get Approved Registrants
			listMeetingRegistrantParameters.status = x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_APPROVED;

			this.getRegistrantsByStatus(
				meetingRegistrants,
				listMeetingRegistrantParameters,
				url,
				x7SEvent,
				responseCode
			);

			// Get Pending Registrants
			listMeetingRegistrantParameters.status = x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_PENDING;

			this.getRegistrantsByStatus(
				meetingRegistrants,
				listMeetingRegistrantParameters,
				url,
				x7SEvent,
				responseCode
			);

			// Get Denied Registrants
			listMeetingRegistrantParameters.status = x7sEventsExternalMeetingConstants.REGISTRATION_STATUS_DENIED;

			this.getRegistrantsByStatus(
				meetingRegistrants,
				listMeetingRegistrantParameters,
				url,
				x7SEvent,
				responseCode
			);

			System.debug('meetingRegistrants: ' + meetingRegistrants);
			meetingResponse.result = JSON.serialize(meetingRegistrants);
		} catch (Exception e) {
			System.debug('getMeetingRegistrants Error: ' + e.getMessage() + ' ' + e.getLineNumber());

			meetingResponse.success = false;
			meetingResponse.error = e.getMessage();
		}

		return meetingResponse;
	}

	private void getRegistrantsByStatus(
		List<Object> meetingRegistrants,
		ListRegistrantsParameters listMeetingRegistrantParameters,
		String url,
		X7S_Event__c x7SEvent,
		Integer responseCode
	) {
		String currentUrl;

		do {
			x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();
			currentUrl =
				url +
				'?occurrence_id=' +
				listMeetingRegistrantParameters.occurrence_id +
				'&page_size=' +
				listMeetingRegistrantParameters.page_size +
				'&next_page_token=' +
				listMeetingRegistrantParameters.next_page_token +
				'&status=' +
				listMeetingRegistrantParameters.status;

			meetingResponse = httpRequest(
				HTTP_GET,
				currentUrl,
				'',
				x7SEvent.Event_Format__c,
				responseCode
			);

			Map<String, Object> meetingInfo = (Map<String, Object>) JSON.deserializeUntyped(
				meetingResponse.getResult()
			);

			listMeetingRegistrantParameters.next_page_token = (String) meetingInfo.get('next_page_token');
			if (meetingInfo.get(x7sEventsExternalMeetingConstants.REGISTRANTS) != null) {
				meetingRegistrants.addAll(
					(List<Object>) meetingInfo.get(x7sEventsExternalMeetingConstants.REGISTRANTS)
				);
			}
		} while (String.isNotBlank(listMeetingRegistrantParameters.next_page_token));
	}

	private x7sEventsIExternalMeetingResponse getMeetingParticipants(
		X7S_Event__c x7SEvent,
		String url
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		try {
			if (x7SEvent == null) {
				throw new ExternalMeetingException('7S Event object not set.');
			}

			Integer responseCode = 200;

			ReportRegistrantsParameters reportMeetingRegistrants = new ReportRegistrantsParameters();
			List<Object> meetingParticipants = new List<Object>();

			do {
				String httpURL;
				httpURL =
					url +
					'?page_size=' +
					reportMeetingRegistrants.page_size +
					'&next_page_token=' +
					reportMeetingRegistrants.next_page_token +
					'&include_fields=' +
					reportMeetingRegistrants.include_fields;

				meetingResponse = httpRequest(
					HTTP_GET,
					httpURL,
					'',
					x7SEvent.Event_Format__c,
					responseCode
				);

				Map<String, Object> meetingInfo = (Map<String, Object>) JSON.deserializeUntyped(
					meetingResponse.getResult()
				);
				reportMeetingRegistrants.next_page_token = (String) meetingInfo.get('next_page_token');

				if (meetingInfo.get(x7sEventsExternalMeetingConstants.PARTICIPANTS) != null) {
					meetingParticipants.addAll(
						(List<Object>) meetingInfo.get(x7sEventsExternalMeetingConstants.PARTICIPANTS)
					);
				}
			} while (String.isNotBlank(reportMeetingRegistrants.next_page_token));

			meetingResponse.result = JSON.serialize(meetingParticipants);
		} catch (Exception e) {
			System.debug(ERROR + e.getMessage());

			meetingResponse.success = false;
			meetingResponse.error = e.getMessage();
		}

		return meetingResponse;
	}

	/**
	 * @description postRequest       : Send a POST request via HTTP
	 * @param httpMethod : Type of request: POST, GET, DELETE
	 * @param url        : Request endpoint url (Complete address).
	 * @param parameters : JSON string of parameters to send in request.
	 * @param eventIntegrationDeveloperName : Name of CMT to get zoom specific api settings from.
	 * @param successResponseCode : Success response code from Zoom
	 *
	 * @return x7sEventsIExternalMeetingResponse : response to report function status
	 *      isSuccess()  : true if successful, false otherwise
	 *      getError()   : error message
	 *      getResult()  : data returned by Zoom
	 */
	private x7sEventsExternalMeetingResponse httpRequest(
		String httpMethod,
		String url,
		String parameters,
		String eventIntegrationDeveloperName,
		Integer successResponseCode
	) {
		x7sEventsExternalMeetingResponse meetingResponse = new x7sEventsExternalMeetingResponse();

		String headerAuthorization = 'Authorization';
		x7sEventsExternalMeetingSecurity meetingSecurity = new x7sEventsExternalMeetingSecurity();
		String headerAuthorizationValue =
			'Bearer ' + meetingSecurity.generateToken(eventIntegrationDeveloperName);
		String headerContentType = 'Content-Type';
		String headerContentTypeValue = 'application/json';

		HttpRequest request = new HttpRequest();
		Http http = new Http();
		request.setHeader(headerAuthorization, headerAuthorizationValue); //NOPMD
		request.setHeader(headerContentType, headerContentTypeValue);
		request.setMethod(httpMethod);
		request.setEndpoint(url);

		if (String.isNotEmpty(parameters)) {
			request.setBody(parameters);
		}

		HttpResponse response = http.send(request);

		System.debug('Body: ' + response.getBody());

		if (response.getStatusCode() == successResponseCode) {
			meetingResponse.result = response.getBody();
		} else {
			Map<String, Object> errorInfo = (Map<String, Object>) JSON.deserializeUntyped(
				response.getBody()
			);

			System.debug(
				System.Label.x7sEventsExternalMeetingError +
				' Status code: ' +
				response.getStatusCode() +
				' Status: ' +
				response.getStatus()
			);

			if (
				errorInfo.containsKey(x7sEventsExternalMeetingConstants.CODE) &&
				errorInfo.containsKey(x7sEventsExternalMeetingConstants.MESSAGE)
			) {
				System.debug(
					'Code: ' +
					errorInfo.get(x7sEventsExternalMeetingConstants.CODE) +
					' message: ' +
					errorInfo.get(x7sEventsExternalMeetingConstants.MESSAGE)
				);

				meetingResponse.error = String.valueOf(
					errorInfo.get(x7sEventsExternalMeetingConstants.MESSAGE)
				);
			} else {
				meetingResponse.error = System.Label.x7sEventsExternalMeetingError;
			}

			meetingResponse.success = false;
		}

		return meetingResponse;
	}

	private Datetime convertDateTime(String dateTimeToConvert) {
		return String.isNotBlank(dateTimeToConvert)
			? Datetime.valueOfGmt(dateTimeToConvert.replace('T', ' '))
			: Datetime.now();
	}
}