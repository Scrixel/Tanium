/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Apex controller for Events community components — list view, detail, create/edit
 * @Date: 2022
 * @Author: IBM Corp / 7Summits
 * RequestId  ModifiedDate  Description
 * SS-13018   2026-05-29    Block guest user access to write and external-API methods; enforce USER_MODE in getCustomLookupDisplayName
 */
@SuppressWarnings('PMD.ExcessiveClassLength')
public with sharing class x7sEventsListController {
	private static final Integer DEFAULT_LIST_SIZE = 50;
	private static final Integer DEFAULT_PAGE_VALUE = 1;
	private static final String SEARCH_SEPARATOR = ';';
	private static final String SEARCH_FIELD = ':';
	private static final String FIELD_SEPARATOR = ',';
	private static final String EVENT_OBJECT_NAME = 'X7S_Event__c';
	private static final Integer MAX_TOPICS = 1000;
	private static final String EVENT_TRANSLATION_OBJECT_NAME = 'X7S_Event_Translation__c';
	private static final String CHILD_RELATIONSHIP_OBJECT_NAME = 'X7S_Event_Translation__r';
	private static final String FOR_GUEST_TYPE = 'Guest';
	public static final String EVENT_FORMAT_STANDARD = 'Non-Integrated Service';
	private static final String EVENTS_SETTING_DEFAULT = 'Default';
	private static final String NAME_LITERAL = 'Name';
	private static final String EVENT_TYPE = 'Event_Type__c';
	private static final String EXPERIENCE_LITERAL = 'Experience__c';
	private static final String CUSTOM_OBJECT_EXTENSION = '__c';
	private static final String CLOSING_ROUND_BRACKET = '\')';
	private static final String PERCENTAGE_LITERAL = '%\'';
	private static final String MULTILNG_QUERY_STRING = ' And Id IN :multiLngIds ';
	private static final String SELECT_QUERY_STRING = 'SELECT ';
	private static final String FROM_QUERY_STRING = ' FROM ';
	private static final String ERROR_LINE = ', Error Line:';
	private static final String ERROR_MESSAGE = 'Error Message:';

	public class EventListControllerException extends Exception {
	}

	private static Id communityId {
		get {
			return System.Network.getNetworkId();
		}
	}

	private static String[] TopicAssigmtAccessFields = new List<String>{ 'EntityId', 'TopicId' };
	private static String[] TopicAccessFields = new List<String>{ NAME_LITERAL, 'Id' };
	private static String[] TopicAssignmentInsertFields = new List<String>{ 'EntityId', 'TopicId' };
	private static String[] eventInsertFields = new List<String>{
		'NetworkId__c',
		'All_Day_Event__c',
		'All_Day_Start__c',
		'All_Day_End__c',
		'Start_DateTime__c',
		'End_DateTime__c',
		'Details__c',
		'Location_Address__c',
		'Location_Name__c',
		'Ticket_Price__c',
		'Venue_Information__c',
		'Location_URL__c',
		'Payment_URL__c',
		EVENT_TYPE,
		'Language__c',
		'GroupId__c',
		'Audience_Selected__c',
		'Summary__c',
		'Registration_Setting__c',
		'Pre_RSVP_Message__c',
		'Meeting_Type__c',
		'Registration__c',
		'Event_Format__c',
		'Registration_Url__c',
		'Host_Email__c',
		'Created_At__c',
		EXPERIENCE_LITERAL,
		'Event_Organizer__c'
	};

	private static String[] EventAccessFields = new List<String>{
		'Id',
		NAME_LITERAL,
		'All_Day_Event__c',
		'All_Day_Start__c',
		'All_Day_End__c',
		'Details__c',
		'Enable_Pricing_Payment__c',
		'Enable_RSVP__c',
		'End_DateTime__c',
		'Location_Address__c',
		'Location_Name__c',
		'Location_URL__c',
		'NetworkId__c',
		'Number_of_Attendees__c',
		'Payment_URL__c',
		EVENT_TYPE,
		'RSVP_Count_Threshold__c',
		'Start_DateTime__c',
		'Ticket_Price__c',
		'Venue_Information__c',
		'GroupId__c',
		'Language__c',
		'Audience_Selected__c',
		'Summary__c',
		'Image_Reference__c',
		'Image_Type__c',
		'Registration_Setting__c',
		'Pre_RSVP_Message__c',
		'Meeting_Type__c',
		'Registration__c',
		'Registration_Url__c',
		'Event_Format__c',
		'MeetingId__c',
		'Join_Url__c',
		'Join_Url_Icon__c',
		'Join_Url_Label__c',
		'Start_Url__c',
		'Host_Email__c',
		'Created_At__c',
		EXPERIENCE_LITERAL,
		'Event_Organizer__c'
	};

	private static String[] EventTranslationFields = new List<String>{
		'Id',
		NAME_LITERAL,
		'Detail__c',
		'Venue_Information__c',
		'Language__c',
		'Parent__c',
		'Location_Name__c',
		'Title__c'
	};

	private static List<String> customFieldList { get; set; }

	private static String filterString { get; set; }

	private static String[] AttachmentAccessFields = new List<String>{ 'Id', NAME_LITERAL };

	private static String nameSpace {
		get {
			if (nameSpace == null) {
				String ns = getNameSpacePrefix();
				nameSpace = String.isBlank(ns) ? '' : ns + '__';
			}
			return nameSpace;
		}
		private set;
	}

	@TestVisible
	private static String getNameSpacePrefix() {
		return x7sEventsBaseController.getModel().namespacePrefix;
	}

	/**
	 * @description Used to get session Id for the logged in user
	 * @return Session Id
	 */
	@AuraEnabled
	public static String getSessionId() {
		requireAuthenticatedUser();
		try {
			return String.isEmpty(UserInfo.getSessionId()) ? '' : UserInfo.getSessionId();
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Used to get locale timezone of the logged in user
	 * @return Timezone
	 */
	@AuraEnabled
	public static String getTimeZone() {
		try {
			return String.valueOf(UserInfo.getTimeZone());
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description EVENT CUSTOM METADATA SETTINGS RELATED, This method checks if user is authorize to post to the Groups
	 * @return True if user is authorize post to the group else false
	 */
	@AuraEnabled
	public static Boolean userAuthorizedToPost() {
		Boolean hasPermission = false;

		try {
			X7S_Events_Setting__mdt setting = X7S_Events_Setting__mdt.getInstance(EVENTS_SETTING_DEFAULT);

			System.debug('userAuthorizedToPost name = ' + setting.Post_to_General_Permission_Set__c);
			hasPermission = permissionSetMember(
				UserInfo.getUserId(),
				setting.Post_to_General_Permission_Set__c
			);

			if (!hasPermission) {
				hasPermission = FeatureManagement.checkPermission('X7S_Events_Group_Post');
			}
		} catch (Exception e) {
			System.debug(
				System.LoggingLevel.ERROR,
				'X7S_Events_Setting__mdt not configured Permission set name: ' + e.getMessage()
			);
			throw new AuraHandledException(e.getMessage());
		}

		return hasPermission;
	}

	@TestVisible
	private static Boolean userAuthorizedToViewAll() {
		Boolean authorized = false;
		try {
			X7S_Events_Setting__mdt setting = X7S_Events_Setting__mdt.getInstance(EVENTS_SETTING_DEFAULT);

			authorized = permissionSetMember(UserInfo.getUserId(), setting.View_All_Permission_Set__c);
			System.debug('user authorized to see all = ' + authorized);
		} catch (Exception ex) {
			System.debug(System.LoggingLevel.ERROR, 'CMT Author_Permission_Set__c : ' + ex.getMessage());
		}

		return authorized;
	}

    @TestVisible
	private static Boolean permissionSetMember(String userId, String permissionSetList) {
		Boolean isMember = false;

		if (String.isNotBlank(permissionSetList)) {
			List<String> permissionSets = permissionSetList.split(',\\s*');

			isMember =
				[
					SELECT COUNT()
					FROM PermissionSetAssignment
					WHERE AssigneeId = :userId AND PermissionSet.Name IN :permissionSets
				] > 0;
		}

		return isMember;
	}

	/**
	 * @description This method checks CMT seeting for require membership to create event for specifc group
	 * @return True if membership is required else false
	 */
	@AuraEnabled
	public static Boolean requireGroupMembership() {
		try {
			X7S_Events_Setting__mdt setting = X7S_Events_Setting__mdt.getInstance(EVENTS_SETTING_DEFAULT);

			return setting.Require_Group_Membership__c;
		} catch (Exception e) {
			System.debug(
				System.LoggingLevel.ERROR,
				'X7S_Events_Setting__mdt not configured for Require Group Membership : ' + e.getMessage()
			);
			throw new AuraHandledException(e.getMessage());
		}
	}

	@TestVisible
	private static Integer getTopicLimit() {
		Integer topicLimit = MAX_TOPICS;

		try {
			X7S_Events_Setting__mdt setting = X7S_Events_Setting__mdt.getInstance(EVENTS_SETTING_DEFAULT);

			topicLimit = setting.Topic_Limit__c == null
				? MAX_TOPICS
				: Integer.valueOf(setting.Topic_Limit__c);
		} catch (Exception e) {
			System.debug(
				System.LoggingLevel.ERROR,
				'X7S_Events_Setting__mdt not configured for Topic Limit'
			);
		}

		return topicLimit;
	}

	/**
	 * @description	: Method for deleting the first attachment for a particular record when user selects another record in Edit Detail page.
	 *
	 * @param eventRecordId target event id
	 *
	 * @return list of deleted attachments
	 */
	@AuraEnabled
	public static List<Attachment> deleteAttachment(String eventRecordId) {
		requireAuthenticatedUser();
		List<Attachment> attachments = new List<Attachment>();

		if (
			!Attachment.SObjectType.getDescribe().isAccessible() &&
			!Attachment.SObjectType.getDescribe().isDeletable()
		) {
			System.debug('deleteAttachment(): unable to delete Attachment');
			return attachments;
		}
		try {
			attachments = [
				SELECT Id
				FROM Attachment
				WHERE ParentId = :eventRecordId
				WITH SECURITY_ENFORCED
			];

			if (!attachments.isEmpty()) {
				delete attachments;
			}
		} catch (Exception e) {
			System.debug('deleteAttachment() : ' + e.getMessage() + ' line number: ' + e.getLineNumber());
			throw new AuraHandledException(e.getMessage());
		}

		return attachments;
	}

	/**
	 * @description Method to check whether Event__c object is creatable or not.
	 * @return If user has create access of the event object then true else false
	 */
	@AuraEnabled
	public static Boolean isObjectCreatable() {
		try {
			return Schema.SObjectType.X7S_Event__c.isCreateable();
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Method to check whether Event__c object is Updateable or not.
	 * @return If user has update access of the event object then true else false
	 */
	@AuraEnabled
	public static Boolean isObjectEditable() {
		try {
			return Schema.SObjectType.X7S_Event__c.isUpdateable();
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Method to check whether user has record access for the given event id
	 * @param eventRecordId Event record id
	 * @return If user has record access of the given event record then true else false
	 */
	@AuraEnabled
	public static Boolean isRecordEditable(String eventRecordId) {
		try {
			List<UserRecordAccess> userRecordAccess = new List<UserRecordAccess>();

			userRecordAccess = [
				SELECT HasEditAccess, RecordId
				FROM UserRecordAccess
				WHERE RecordId = :eventRecordId AND UserId = :UserInfo.getUserId()
				WITH SECURITY_ENFORCED
			];

			return (!userRecordAccess.isEmpty() && userRecordAccess[0].HasEditAccess);
		} catch (Exception e) {
			System.debug(
				'isRecordEditable() : ' +
				e.getMessage() +
				' line NUmber : ' +
				e.getLineNumber()
			);
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description	: Method for saving all event records for create as well ad detail page.
	 *
	 * @param eventObj New event object
	 * @param strEventFilterTopic topic filter
	 * @param audience selected audience
	 *
	 * @return new event
	 */
	@AuraEnabled
	public static X7S_Event__c saveEvents(
		X7S_Event__c eventObj,
		String strEventFilterTopic,
		String audience
	) {
		requireAuthenticatedUser();
		if (
			X7S_Event__c.SObjectType.getDescribe().isCreateable() &&
			X7S_Event__c.SObjectType.getDescribe().isUpdateable()
		) {
			Map<String, Schema.SObjectField> eventFldMap = Schema.SObjectType.X7S_Event__c.fields.getMap();
			Map<String, Schema.SObjectField> TAFldMap = Schema.SObjectType.TopicAssignment.fields.getMap();

			for (String fieldToCheck : eventInsertFields) {
				String fullFieldName = fieldToCheck.contains(CUSTOM_OBJECT_EXTENSION)
					? nameSpace + fieldToCheck
					: fieldToCheck;

				if (!eventFldMap.get(fullFieldName).getDescribe().isCreateable()) {
					throw new EventListControllerException(Label.x7sEventsFieldAccessError);
				}
			}

			for (String fieldToCheck : TopicAssignmentInsertFields) {
				if (!TAFldMap.get(fieldToCheck).getDescribe().isCreateable()) {
					throw new EventListControllerException(Label.x7sEventsTopicAccessError);
				}
			}

			x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
				eventObj
			);
			x7sEventsIExternalMeetingResponse externalMeetingResponse;

			if (String.isEmpty(eventObj.MeetingId__c)) {
				externalMeetingResponse = externalMeeting.create(eventObj);
			} else {
				externalMeetingResponse = externalMeeting.updateExternal(eventObj);
			}

			if (!externalMeetingResponse.isSuccess()) {
				System.debug('Error: ' + externalMeetingResponse.getError());
				throw new EventListControllerException(externalMeetingResponse.getError());
			}

			Savepoint preEventSavepoint = Database.setSavepoint();

			eventObj.NetworkId__c = communityId;
			eventObj.Audience_Selected__c = String.isNotBlank(audience);

			Integer maxTopics = getTopicLimit();
			String entityTypeName = nameSpace + EVENT_OBJECT_NAME;

			Map<String, TopicAssignment> topicMap = new Map<String, TopicAssignment>();

			try {
				if (eventObj.Id != null) {
					List<TopicAssignment> topicAssignments = [
						SELECT Id, EntityId, Topic.Id, Topic.Name
						FROM TopicAssignment
						WHERE
							NetworkId = :communityId
							AND EntityId = :eventObj.Id
							AND EntityType = :entityTypeName
						WITH SECURITY_ENFORCED
						LIMIT :maxTopics
					];

					for (TopicAssignment topicAssignment : topicAssignments) {
						topicMap.put(topicAssignment.TopicId, topicAssignment);
					}
				}

				upsert eventObj;
			} catch (Exception e) {
				System.debug('Error :' + e.getMessage());
				Database.rollback(preEventSavepoint);
				throw new EventListControllerException(e);
			}

			if (
				(!topicMap.isEmpty() || String.isNotBlank(strEventFilterTopic)) &&
				TopicAssignment.SObjectType.getDescribe().isCreateable() &&
				TopicAssignment.SObjectType.getDescribe().isDeletable()
			) {
				List<TopicAssignment> topicAssignmentLst = new List<TopicAssignment>();
				Set<String> topicLst = new Set<String>();

				if (!strEventFilterTopic.isWhitespace()) {
					topicLst.addAll(String.escapeSingleQuotes(strEventFilterTopic).split(','));
				}
				Set<String> topicSet = new Set<String>();
				List<TopicAssignment> deleteAssignments = new List<TopicAssignment>();
				if (topicMap.isEmpty()) {
					for (String strTopicId : topicLst) {
						if (!String.isEmpty(strTopicId)) {
							TopicAssignment t = new TopicAssignment();
							t.EntityId = eventObj.Id;
							t.TopicId = strTopicId;
							topicAssignmentLst.add(t);
						}
					}
				} else {
					for (String topicId : topicMap.keySet()) {
						for (String tId : topicLst) {
							if (tId != topicId && !topicSet.contains(tId)) {
								topicSet.add(tId);
								topicAssignmentLst.add(new TopicAssignment(EntityId = eventObj.Id, TopicId = tId));
							}
						}
						if (!topicLst.contains(topicId)) {
							deleteAssignments.add(topicMap.get(topicId));
						}
					}
				}
				try {
					if (!deleteAssignments.isEmpty()) {
						delete deleteAssignments;
					}

					if (!topicAssignmentLst.isEmpty()) {
						insert topicAssignmentLst;
					}
				} catch (Exception e) {
					System.debug('Error :' + e.getMessage());
					Database.rollback(preEventSavepoint);
					throw new EventListControllerException(e);
				}
			}

			if (String.isNotBlank(audience)) {
				assignAudienceToRecord(audience, eventObj.Id, communityId);
			}

			return eventObj;
		} else {
			throw new EventListControllerException(Label.x7sEventsFieldAccessError);
		}
	}

	private static Boolean checkFieldType(
		Map<String, Schema.SObjectField> fldMap,
		String[] objectAccess
	) {
		for (String fieldToCheck : objectAccess) {
			String fullFieldName = fieldToCheck.contains(CUSTOM_OBJECT_EXTENSION)
				? nameSpace + fieldToCheck
				: fieldToCheck;

			if (!fldMap.get(fullFieldName).getDescribe().isAccessible()) {
				System.debug(LoggingLevel.ERROR, 'Access failed for field: ' + fullFieldName);
				return false;
			}
		}
		return true;
	}

	/**
	 * @description Get a list of all the groups this user is a member of
	 * @return Map of Group Id Name pair
	 */
	@AuraEnabled
	public static Map<String, String> getGroups() {
		Map<String, String> groups = new Map<String, String>();

		try {
			if (UserInfo.getUserType() != 'Guest') {
				for (
					CollaborationGroupMember member : [
						SELECT Id, CollaborationGroupId, CollaborationGroup.Name
						FROM CollaborationGroupMember
						WHERE MemberId = :UserInfo.getUserId() AND NetworkId = :communityId
						LIMIT 1000
					]
				) {
					groups.put(member.CollaborationGroupId, member.CollaborationGroup.Name);
				}
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}

		return groups;
	}

	/**
	 * @description Get a list of all the groups on the org
	 * @return Map of Group Id Name pair
	 */
	@AuraEnabled
	public static Map<String, String> getAllGroups() {
		Map<String, String> groups = new Map<String, String>();
		try {
			for (
				CollaborationGroup groupItem : [
					SELECT Id, Name
					FROM CollaborationGroup
					WHERE NetworkId = :communityId
					LIMIT 1000
				]
			) {
				groups.put(groupItem.Id, groupItem.Name);
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}

		return groups;
	}

	/*
	 * @description Method to fetch all event records for list view, topic and search pages.
	 *
	 * @param : pageNumber,compactMode,recordSize,listSize,strFilterType,sortBy,
	 * filterByTopic,topicName,searchTerm,filterOn,fromDate,toDate,listViewMode,
	 * customFields,filters,eventIdList
	 * @return x7sEventsListWrapper - event list wrapper
	 */
	@AuraEnabled
	public static x7sEventsListWrapper getEventsList(
		Boolean compactMode,
		Integer recordSize,
		Integer listSize,
		String strFilterType,
		String sortBy,
		String filterByTopic,
		String topicName,
		String searchTerm,
		String filterOn,
		String fromDate,
		String toDate,
		String listViewMode,
		String customFields,
		String filters,
		List<String> eventIdList,
		String showPastEvent,
		Boolean limitToGeneralEvents
	) {
		try {
			customFieldList = getCustomFields(customFields);
			filterString = filters;

			return getEvents(
				compactMode,
				recordSize,
				listSize,
				strFilterType,
				topicName,
				sortBy,
				filterByTopic,
				topicName,
				searchTerm,
				filterOn,
				fromDate,
				toDate,
				listViewMode,
				eventIdList,
				showPastEvent,
				limitToGeneralEvents
			);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/*
	 * To get event for perticular page ex: events for page number-4
	 *
	 * @param pageNumber - pageNumber,compactMode,recordSize,listSize,
	 * strFilterType,sortBy,filterByTopic,topicName,searchTerm,filterOn,
	 * fromDate,toDate,listViewMode,customFields,filters,eventIdList
	 *
	 * @return x7sEventsListWrapper - event list wrapper
	 */
	@AuraEnabled
	public static x7sEventsListWrapper getEventsForPage(
		Integer pageNumber,
		Boolean compactMode,
		Integer recordSize,
		Integer listSize,
		String strFilterType,
		String sortBy,
		String filterByTopic,
		String topicName,
		String searchTerm,
		String filterOn,
		String fromDate,
		String toDate,
		String listViewMode,
		String customFields,
		String filters,
		List<String> eventIdList,
		String showPastEvent,
		Boolean limitToGeneralEvents
	) {
		try {
			customFieldList = getCustomFields(customFields);
			filterString = filters;

			Integer listSizeValue = listSize == null ? DEFAULT_LIST_SIZE : Integer.valueOf(listSize);
			Integer pageNumberValue = pageNumber == null
				? DEFAULT_PAGE_VALUE
				: Integer.valueOf(pageNumber);

			x7sEventsListWrapper wrapper = getEvents(
				compactMode,
				recordSize,
				listSizeValue,
				strFilterType,
				topicName,
				sortBy,
				filterByTopic,
				topicName,
				searchTerm,
				filterOn,
				fromDate,
				toDate,
				listViewMode,
				eventIdList,
				showPastEvent,
				limitToGeneralEvents
			);
			wrapper.pageNumber = pageNumberValue;
			wrapper.currentPage();
			return wrapper;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@TestVisible
	private static x7sEventsListWrapper getEvents(
		Boolean eventListFlag,
		Integer numberofresults,
		Integer listSize,
		String strfilterType,
		String strRecordId,
		String sortBy,
		String filterByTopic,
		String topicName,
		String searchTerm,
		String filterOn,
		String fromDate,
		String toDate,
		String listViewMode,
		List<String> eventIdList,
		String showPastEvent,
		Boolean limitToGeneralEvents
	) {
		Integer maxTopics = getTopicLimit();
		String entityTypeName = nameSpace + EVENT_OBJECT_NAME;
		Set<String> multiLngIds = new Set<String>();

		Map<String, Schema.SObjectField> topicFldMap = Schema.SObjectType.Topic.fields.getMap();
		Map<String, Schema.SObjectField> TAFldMap = Schema.SObjectType.TopicAssignment.fields.getMap();

		if (!checkFieldType(topicFldMap, TopicAccessFields)) {
			System.debug('ACCESS CHECK failed for TopicAccessFields');
			throw new System.NoAccessException();
		}

		if (!checkFieldType(TAFldMap, TopicAssigmtAccessFields)) {
			System.debug('ACCESS CHECK failed for TopicAssignmentAccessFields');
			throw new System.NoAccessException();
		}

		Integer eventListSize = Integer.valueOf(listSize);

		Datetime fromDt;
		Datetime toDt;

		try {
			if (String.isNotBlank(fromDate) || String.isNotBlank(toDate)) {
				if (String.isNotBlank(fromDate)) {
					fromDt = Datetime.valueOf(String.escapeSingleQuotes(fromDate) + ' ' + '00:00:00');
				}
				if (String.isNotBlank(toDate)) {
					toDt = Datetime.valueOf(String.escapeSingleQuotes(toDate) + ' ' + '23:59:00');
				}
			}
		} catch (Exception e) {
			System.debug('ERROR:' + e);
			return new x7sEventsListWrapper('Date', e.getMessage());
		}

		Integer limitInt = Integer.valueOf(numberofresults);
		Set<String> topicIds = new Set<String>();
		Set<String> groupEventIds = null;

		for (TopicAssignment topicAssignment : [
			SELECT Id, EntityId, Topic.Id
			FROM TopicAssignment
			WHERE
				NetworkId = :communityId
				AND EntityId = :String.valueOf(strRecordId)
				AND EntityType = :entityTypeName
			LIMIT :maxTopics
		]) {
			topicIds.add(topicAssignment.Topic.Id);
		}

		Set<String> eventIds = new Set<String>();
		for (TopicAssignment topicAssignment : [
			SELECT Id, EntityId, Topic.Id
			FROM TopicAssignment
			WHERE NetworkId = :communityId AND Topic.Id IN :topicIds AND EntityType = :entityTypeName
			LIMIT :maxTopics
		]) {
			eventIds.add(topicAssignment.EntityId);
		}

		List<String> keywordSetCategoriesList = new List<String>(eventIds);
		String categoriesJoined =
			'(\'' +
			String.join(keywordSetCategoriesList, '\',\'') +
			CLOSING_ROUND_BRACKET;

		Boolean requireGroupId = requireGroupMembership();
		List<String> myEventIds = new List<String>();

		Boolean useAudience = audienceEnabled() && !userAuthorizedToViewAll();
		List<String> audienceIds = new List<String>();

		if (useAudience) {
			audienceIds = getAudienceTargetIds(communityId);
			System.debug('Using audience - ' + audienceIds);
		}

		if (filterOn.startsWith('My Events')) {
			String userId = UserInfo.getUserId();

			if (filterOn.indexOf(':') > 0) {
				userId = filterOn.substringAfterLast(SEARCH_FIELD);
			}

			for (X7S_Event_RSVP__c myRsvp : [
				SELECT Event__c
				FROM X7S_Event_RSVP__c
				WHERE User__c = :userId
				WITH SECURITY_ENFORCED
			]) {
				myEventIds.add(myRsvp.Event__c);
			}
		}

		String userLanguage = getLanguage();
		Boolean useMultiLanguage =
			String.isNotBlank(userLanguage) && UserInfo.getUserType() != FOR_GUEST_TYPE;

		if (useMultiLanguage) {
			String queryEventsTranslate = getTranslationQuery();

			if (String.isNotBlank(queryEventsTranslate)) {
				List<X7S_Event_Translation__c> translateList;

				if (String.isNotBlank(searchTerm) && !searchTerm.isWhitespace()) {
					translateList = Database.query(
						String.escapeSingleQuotes(queryEventsTranslate) +
						' WHERE Name LIKE \'%' +
						String.escapeSingleQuotes(searchTerm.trim()) +
						PERCENTAGE_LITERAL +
						' AND Language__c = \'' +
						String.escapeSingleQuotes(userLanguage) +
						'\''
					);
				} else {
					translateList = Database.query(
						String.escapeSingleQuotes(queryEventsTranslate) +
						' WHERE Language__c = \'' +
						String.escapeSingleQuotes(userLanguage) +
						'\''
					);
				}

				for (X7S_Event_Translation__c eventRecord : translateList) {
					multiLngIds.add(eventRecord.Parent__c);
				}
			}

			String queryEventsArticle = getEventsQuery();
			if (String.isNotBlank(queryEventsArticle)) {
				List<X7S_Event__c> eventList;

				if (String.isNotBlank(searchTerm) && !searchTerm.isWhitespace()) {
					eventList = Database.query(
						String.escapeSingleQuotes(queryEventsArticle) +
						' WHERE Name LIKE \'%' +
						String.escapeSingleQuotes(searchTerm.trim()) +
						PERCENTAGE_LITERAL +
						' AND Language__c = \'' +
						String.escapeSingleQuotes(userLanguage) +
						'\''
					);
				} else {
					eventList = Database.query(
						String.escapeSingleQuotes(queryEventsArticle) +
						' WHERE Language__c = \'' +
						String.escapeSingleQuotes(userLanguage) +
						'\''
					);
				}

				for (X7S_Event__c eventRecord : eventList) {
					multiLngIds.add(eventRecord.Id);
				}
			}
		}

		String Query = getSelectClause();
		Query += getFromClause();
		Query += getWhereClause();

		if (filterOn == 'None' && limitInt != null && eventListFlag == false) {
			if (useMultiLanguage) {
				if (categoriesJoined.length() > 5) {
					multiLngIds = multiLanguageSet(keywordSetCategoriesList, multiLngIds);

					Query += MULTILNG_QUERY_STRING;
				}
			} else {
				Query += categoriesJoined.length() > 5 ? ' AND Id IN ' + categoriesJoined : ' ';
			}

			if (String.isNotBlank(strRecordId)) {
				Query += ' And Id != \'' + String.escapeSingleQuotes(strRecordId.trim()) + '\'';
			}
		}

		if (String.isNotBlank(searchTerm) && !searchTerm.isWhitespace()) {
			Query += useMultiLanguage
				? MULTILNG_QUERY_STRING
				: ' AND Name LIKE \'%' + String.escapeSingleQuotes(searchTerm.trim()) + PERCENTAGE_LITERAL;
		}

		if (filterOn == 'Topic Value' && String.isNotEmpty(topicName)) {
			eventIds = new Set<String>();
			List<TopicAssignment> topicsLst;
			if (topicName instanceof Id) {
				topicsLst = new List<TopicAssignment>(
					[
						SELECT Id, EntityId, Topic.Id, Topic.Name
						FROM TopicAssignment
						WHERE Topic.Id = :topicName AND EntityType = :entityTypeName
						LIMIT :maxTopics
					]
				);
			} else {
				String topic = topicName.trim();
				if (topic.indexOf('-') != -1) {
					topic = topic.replace('-', '%');
				}
				topic = String.escapeSingleQuotes(topic);
				entityTypeName = String.escapeSingleQuotes(entityTypeName.trim());
				topicsLst = new List<TopicAssignment>(
					[
						SELECT Id, EntityId, Topic.Id, Topic.Name
						FROM TopicAssignment
						WHERE Topic.Name LIKE :topic AND EntityType = :entityTypeName
						LIMIT :maxTopics
					]
				);
			}

			for (TopicAssignment t : topicsLst) {
				eventIds.add(t.EntityId);
			}

			if (useMultiLanguage) {
				Set<String> eventLanguageIds = new Set<String>();
				for (String id : eventIds) {
					if (multiLngIds.contains(id)) {
						eventLanguageIds.add(id);
					}
				}

				multiLngIds = eventLanguageIds;
				Query += MULTILNG_QUERY_STRING;
			} else {
				Query += ' AND Id IN : eventIds '; //**
			}

			Query += ' AND NetworkId__c = \'' + communityId + '\'';
		}

		if (limitToGeneralEvents) {
			Query += ' AND GroupId__c  = \'\'';
		}

		if (filterOn == 'Group' && String.isNotEmpty(topicName)) {
			Query += ' AND GroupId__c  = \'' + String.escapeSingleQuotes(topicName.trim()) + '\'';
		}

		if (filterOn == 'LocationName' && String.isNotBlank(strfilterType)) {
			Query +=
				' AND Location_Name__c  = \'' +
				String.escapeSingleQuotes(strfilterType.trim()) +
				'\'';
		}

		if (filterOn == EVENT_TYPE && String.isNotBlank(strfilterType)) {
			Query += ' AND Event_Type__c  = \'' + String.escapeSingleQuotes(strfilterType.trim()) + '\'';
		}

		if (filterOn.startsWith('My Events')) {
			String myEventIdString = '(\'' + String.join(myEventIds, '\',\'') + CLOSING_ROUND_BRACKET;
			if (useMultiLanguage) {
				multiLngIds = multiLanguageSet(myEventIds, multiLngIds);
				Query += MULTILNG_QUERY_STRING;
			} else {
				Query += ' AND Id IN ' + myEventIdString; //**
			}
		}

		if (!eventIdList.isEmpty()) {
			String eventIdString = '(\'' + String.join(eventIdList, '\',\'') + CLOSING_ROUND_BRACKET;
			System.debug('Featured Events : ' + eventIdString);

			if (useMultiLanguage) {
				multiLngIds = multiLanguageSet(eventIdList, multiLngIds);
				Query += MULTILNG_QUERY_STRING;
			} else {
				Query += ' AND Id IN ' + eventIdString;
			}
		}

		if (String.isNotBlank(filterString)) {
			Query += getCustomFilterClause(filterString);
		}

		if (fromDt != null || toDt != null || String.isNotBlank(filterByTopic)) {
			if (fromDt != null || toDt != null) {
				if (fromDt != null) {
					Query += ' And (UpComing_Sort__c >= :fromDt OR All_Day_Start__c >= :fromDate) ';
				}
				if (toDt != null) {
					Query += ' And (UpComing_Sort__c <= :toDt OR ALL_Day_Start__c <= :toDate) ';
				}
			}

			if (String.isNotBlank(filterByTopic)) {
				Set<String> topicLst = new Set<String>();
				topicLst.addAll(String.escapeSingleQuotes(filterByTopic).split(','));

				Boolean fieldIsId = false;

				for (String topicNameEntry : topicLst) {
					if (topicNameEntry instanceof Id) {
						fieldIsId = true;
					} else {
						if (topicNameEntry.indexOf('-') == -1) {
							topicLst.add(topicNameEntry.trim());
						} else {
							topicLst.add(topicNameEntry.trim().replace('-', ' '));
						}
					}
				}

				List<String> topicIdList = new List<String>();
				String targetName = fieldIsId ? 'Id' : 'name';
				String topicIdQuery = 'SELECT Id, Name FROM Topic WHERE ' + targetName + ' IN : topicLst';
				List<Topic> topics = Database.query(String.escapeSingleQuotes(topicIdQuery));
				for (Topic entry : topics) {
					topicIdList.add(entry.Id);
				}

				eventIds = new Set<String>();

				for (TopicAssignment t : [
					SELECT Id, EntityId, Topic.Id
					FROM TopicAssignment
					WHERE
						NetworkId = :communityId
						AND Topic.Id = :topicIdList
						AND EntityType = :entityTypeName
					LIMIT :maxTopics
				]) {
					eventIds.add(t.EntityId);
				}

				if (useMultiLanguage) {
					Set<String> eventLanguageIds = new Set<String>();
					for (String id : eventIds) {
						if (multiLngIds.contains(id)) {
							eventLanguageIds.add(id);
						}
					}

					multiLngIds = eventLanguageIds;
					Query += ' AND Id IN :multiLngIds ';
				} else {
					Query += ' AND Id IN :eventIds ';
				}
			}
		}

		if (String.isNotBlank(showPastEvent)) {
			if (showPastEvent == 'Include Past Events') {
				Query += ' AND (UpComing_Sort__c < TODAY OR End_DateTime__c < TODAY OR All_Day_End__c < TODAY OR UpComing_Sort__c = TODAY OR End_DateTime__c >= TODAY OR All_Day_End__c >= TODAY) ';
			} else if (showPastEvent == 'Show Only Past Events') {
				Query += ' AND (UpComing_Sort__c < TODAY OR End_DateTime__c < TODAY OR All_Day_End__c < TODAY) ';
			} else {
				Query += ' AND (UpComing_Sort__c = TODAY OR End_DateTime__c >= TODAY OR All_Day_End__c >= TODAY) ';
			}
		}

		if (!Query.contains('Id IN') && useMultiLanguage) {
			Query += ' AND Id IN :multiLngIds ';
		}

		if (requireGroupId || !limitToGeneralEvents) {
			groupEventIds = getGroups().keySet();
			Query += groupEventIds.isEmpty()
				? ' AND GroupId__c = null'
				: ' AND (GroupId__c = null OR GroupId__c IN : groupEventIds)';
		}

		if (useAudience) {
			Query += getAudienceQuery(audienceIds);
		}

		Query += getSortClause(sortBy);
		Query += getLimitClause(limitInt);

		return new x7sEventsListWrapper(
			Query,
			multiLngIds,
			eventListSize,
			fromDt,
			toDt,
			String.isNotBlank(fromDate) ? Date.valueOf(String.escapeSingleQuotes(fromDate)) : null,
			String.isNotBlank(toDate) ? Date.valueOf(String.escapeSingleQuotes(toDate)) : null,
			eventIds,
			listViewMode,
			false,
			null,
			groupEventIds,
			userLanguage,
			UserInfo.getUserType(),
			audienceIds
		);
	}

	private static String getSelectClause() {
		String userLanguage = getLanguage();
		Boolean useMultiLanguage =
			String.isNotBlank(userLanguage) && UserInfo.getUserType() != FOR_GUEST_TYPE;

		String fields = String.join(EventAccessFields, ',');
		fields = fields.removeEnd(',');

		String selectClause = SELECT_QUERY_STRING + fields + ', (SELECT Id, Name FROM Attachments)';

		if (useMultiLanguage) {
			String fieldsTranslation = String.join(EventTranslationFields, ',');
			fieldsTranslation = fieldsTranslation.removeEnd(',');
			selectClause +=
				', (SELECT ' +
				fieldsTranslation +
				FROM_QUERY_STRING +
				CHILD_RELATIONSHIP_OBJECT_NAME +
				'';
			selectClause +=
				' WHERE Language__c = \'' +
				String.escapeSingleQuotes(userLanguage) +
				CLOSING_ROUND_BRACKET;
		}

		if (customFieldList != null) {
			for (String field : customFieldList) {
				if (!EventAccessFields.contains(field)) {
					selectClause += ', ' + String.escapeSingleQuotes(field.trim());
				}
			}
		}

		return selectClause;
	}

	private static String getTranslationQuery() {
		String fieldsTranslation = String.join(EventTranslationFields, ',');
		fieldsTranslation = fieldsTranslation.removeEnd(',');
		String selectClause =
			SELECT_QUERY_STRING +
			fieldsTranslation +
			FROM_QUERY_STRING +
			EVENT_TRANSLATION_OBJECT_NAME +
			'';

		return selectClause;
	}

	private static String getEventsQuery() {
		String fields = String.join(EventAccessFields, ',');
		fields = fields.removeEnd(',');
		String selectClause = SELECT_QUERY_STRING + fields + FROM_QUERY_STRING + EVENT_OBJECT_NAME + '';

		return selectClause;
	}

	private static String getFromClause() {
		return FROM_QUERY_STRING + EVENT_OBJECT_NAME;
	}

	private static String getWhereClause() {
		String query = ' WHERE NetworkId__c = ';
		query += String.isNotBlank(communityId) ? '\'' + communityId + '\'' : 'null';

		return query;
	}

    @TestVisible
	private static String getSortClause(String sortBy) {
		String sortByClause = '';

		if (sortBy == 'Recently Created') {
			sortByClause += ' ORDER BY CreatedDate DESC';
		} else if (sortBy == 'Name A to Z') {
			sortByClause += ' ORDER BY Name';
		} else if (sortBy == 'Name Z to A') {
			sortByClause += ' ORDER BY Name DESC';
		} else if (sortBy == 'Most Attended') {
			sortByClause += ' ORDER BY Number_of_Attendees__c DESC NULLS LAST';
		} else if (sortBy == 'Least Attended') {
			sortByClause += ' ORDER BY Number_of_Attendees__c';
		} else if (sortBy == 'Event Start Date Latest to Earliest') {
			sortByClause += ' ORDER BY UpComing_Sort__c DESC';
		} else if (sortBy == 'Event Start Date Earliest to Latest') {
			sortByClause += ' ORDER BY UpComing_Sort__c';
		}

		return sortByClause;
	}

	private static String getLimitClause(Integer limitValue) {
		return limitValue == null ? '' : ' LIMIT ' + limitValue;
	}

	@TestVisible
	private static String getCustomFilterClause(String filterString) {
		String filterQuery = '';

		if (String.isNotBlank(filterString)) {
			List<String> searchParts = filterString.split(SEARCH_SEPARATOR);

			for (Integer i = 0; i < searchParts.size(); i++) {
				if (searchParts[i].indexOf(SEARCH_FIELD) != -1) {
					String fieldName = searchParts[i].substringBefore(SEARCH_FIELD);
					String fieldValue = searchParts[i].substringAfter(SEARCH_FIELD);

					filterQuery +=
						' AND ' +
						fieldName.trim() +
						' LIKE \'%' +
						String.escapeSingleQuotes(fieldValue) +
						PERCENTAGE_LITERAL;
				}
			}
		}

		return filterQuery;
	}

	/**
	 * @description Create the query sub-string to select records for the use's audience
	 *
	 * @param audienceIds list of target ids applicable to the user's audience
	 *
	 * @return sub-query string to select records for the target audience
	 */
	private static String getAudienceQuery(List<String> audienceIds) {
		return ' AND (Audience_Selected__c = false' +
			(audienceIds.isEmpty() ? '' : ' OR Id IN : audienceIds') +
			(') ');
	}

	@TestVisible
	private static List<String> getCustomFields(String fieldList) {
		List<String> fieldsSet = String.escapeSingleQuotes(fieldList).split(FIELD_SEPARATOR);

		for (Integer pos = 0; pos < fieldsSet.size(); pos++) {
			String fieldValue = fieldsSet.get(pos);
			fieldsSet.set(pos, nameSpace + fieldValue);
		}

		List<String> fields = new List<String>();

		Map<String, Schema.SObjectField> eventFldMap = Schema.SObjectType.X7S_Event__c.fields.getMap();

		for (String field : fieldsSet) {
			if (eventFldMap.containsKey(field.trim())) {
				fields.add(field.trim());
			} else {
				System.debug('Custom field ' + field + ' not found on the X7S_Event__C record');
			}
		}

		return fields;
	}

	@AuraEnabled
	public static x7sEventsListWrapper nextPageList(
		Integer pageNumber,
		Boolean compactMode,
		Integer recordSize,
		Integer listSize,
		String strFilterType,
		String sortBy,
		String filterByTopic,
		String topicName,
		String searchTerm,
		String filterOn,
		String fromDate,
		String toDate,
		String listViewMode,
		String customFields,
		String filters,
		List<String> eventIdList,
		String showPastEvent,
		Boolean limitToGeneralEvents
	) {
		customFieldList = getCustomFields(customFields);
		filterString = filters;

		try {
			return nextPage(
				compactMode,
				recordSize,
				listSize,
				pageNumber,
				strFilterType,
				topicName,
				sortBy,
				filterByTopic,
				topicName,
				searchTerm,
				filterOn,
				fromDate,
				toDate,
				listViewMode,
				eventIdList,
				showPastEvent,
				limitToGeneralEvents
			);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@TestVisible
	private static x7sEventsListWrapper nextPage(
		Boolean eventListFlag,
		Integer numberofresults,
		Integer listSize,
		Integer pageNumber,
		String strfilterType,
		String strRecordId,
		String sortBy,
		String filterByTopic,
		String topicName,
		String searchTerm,
		String filterOn,
		String fromDate,
		String toDate,
		String listViewMode,
		List<String> eventIdList,
		String showPastEvent,
		Boolean limitToGeneralEvents
	) {
		Integer listSizeValue = listSize == null ? DEFAULT_LIST_SIZE : Integer.valueOf(listSize);
		Integer pageNumberValue = pageNumber == null ? DEFAULT_PAGE_VALUE : Integer.valueOf(pageNumber);

		x7sEventsListWrapper ilw = getEvents(
			eventListFlag,
			numberofresults,
			listSizeValue,
			strfilterType,
			strRecordId,
			sortBy,
			filterByTopic,
			topicName,
			searchTerm,
			filterOn,
			fromDate,
			toDate,
			listViewMode,
			eventIdList,
			showPastEvent,
			limitToGeneralEvents
		);
		ilw.pageNumber = pageNumberValue;

		ilw.nextPage();

		return ilw;
	}

	@AuraEnabled
	public static x7sEventsListWrapper previousPageList(
		Integer pageNumber,
		Boolean compactMode,
		Integer recordSize,
		Integer listSize,
		String strFilterType,
		String sortBy,
		String filterByTopic,
		String topicName,
		String searchTerm,
		String filterOn,
		String fromDate,
		String toDate,
		String listViewMode,
		String customFields,
		String filters,
		List<String> eventIdList,
		String showPastEvent,
		Boolean limitToGeneralEvents
	) {
		customFieldList = getCustomFields(customFields);
		filterString = filters;

		try {
			return previousPage(
				compactMode,
				recordSize,
				listSize,
				pageNumber,
				strFilterType,
				topicName,
				sortBy,
				filterByTopic,
				topicName,
				searchTerm,
				filterOn,
				fromDate,
				toDate,
				listViewMode,
				eventIdList,
				showPastEvent,
				limitToGeneralEvents
			);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@TestVisible
	private static x7sEventsListWrapper previousPage(
		Boolean eventListFlag,
		Integer numberofresults,
		Integer listSize,
		Integer pageNumber,
		String strfilterType,
		String strRecordId,
		String sortBy,
		String filterByTopic,
		String topicName,
		String searchTerm,
		String filterOn,
		String fromDate,
		String toDate,
		String listViewMode,
		List<String> eventIdList,
		String showPastEvent,
		Boolean limitToGeneralEvents
	) {
		Integer listSizeValue = listSize == null ? DEFAULT_LIST_SIZE : Integer.valueOf(listSize);
		Integer pageNumberValue = pageNumber == null ? DEFAULT_PAGE_VALUE : Integer.valueOf(pageNumber);

		x7sEventsListWrapper ilw = getEvents(
			eventListFlag,
			numberofresults,
			listSizeValue,
			strfilterType,
			strRecordId,
			sortBy,
			filterByTopic,
			topicName,
			searchTerm,
			filterOn,
			fromDate,
			toDate,
			listViewMode,
			eventIdList,
			showPastEvent,
			limitToGeneralEvents
		);
		ilw.pageNumber = pageNumberValue;

		ilw.previousPage();

		return ilw;
	}

	/**
	 * @description Method to fetch all topics records.
	 * @return Id Name pair map of the topics
	 */
	@AuraEnabled
	public static Map<String, String> getTopics() {
		Map<String, String> topics = new Map<String, String>();
		List<Topic> topicList = new List<Topic>();
		try {
			Map<String, Schema.SObjectField> topicFldMap = Schema.SObjectType.Topic.fields.getMap();

			if (communityId == null) {
				for (String fieldToCheck : TopicAccessFields) {
					if (!topicFldMap.get(fieldToCheck).getDescribe().isAccessible()) {
						throw new System.NoAccessException();
					}
				}

				topicList = [
					SELECT CreatedById, CreatedDate, Description, Id, Name, NetworkId, TalkingAbout
					FROM Topic
					WHERE NetworkId = NULL
					WITH SECURITY_ENFORCED
					LIMIT 2000
				];
			} else {
				for (String fieldToCheck : TopicAccessFields) {
					if (!topicFldMap.get(fieldToCheck).getDescribe().isAccessible()) {
						throw new System.NoAccessException();
					}
				}
				topicList = [
					SELECT CreatedById, CreatedDate, Description, Id, Name, NetworkId, TalkingAbout
					FROM Topic
					WHERE NetworkId = :communityId
					WITH SECURITY_ENFORCED
					LIMIT 2000
				];
			}
			for (Topic t : topicList) {
				topics.put(t.Id, t.Name);
			}

			return topics;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Used to get event record details of given event Id
	 * @param eventRecordId Event record Id
	 * @param customFields Custom fields
	 * @return Event List Wrapper
	 */
	@AuraEnabled
	public static x7sEventsListWrapper getEventRecord(String eventRecordId, String customFields) {
		try {
			if (String.isNotBlank(customFields)) {
				customFieldList = getCustomFields(customFields);
				System.debug('Custom fields: ' + customFieldList);
			}

			return getEventRecordFromId(eventRecordId);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@TestVisible
	private static x7sEventsListWrapper getEventRecordFromId(String eventRecordId) {
		Map<String, Schema.SObjectField> eventFldMap = Schema.SObjectType.X7S_Event__c.fields.getMap();
		Map<String, Schema.SObjectField> attFldMap = Schema.SObjectType.Attachment.fields.getMap();

		for (String fieldToCheck : EventAccessFields) {
			String fullFieldName = fieldToCheck.contains(CUSTOM_OBJECT_EXTENSION)
				? nameSpace + fieldToCheck
				: fieldToCheck;

			if (!eventFldMap.get(fullFieldName).getDescribe().isAccessible()) {
				throw new System.NoAccessException();
			}
		}
		for (String fieldToCheck : AttachmentAccessFields) {
			if (!attFldMap.get(fieldToCheck).getDescribe().isAccessible()) {
				throw new System.NoAccessException();
			}
		}

		Boolean useAudience = audienceEnabled() && !userAuthorizedToViewAll();
		List<String> audienceIds = new List<String>();

		System.debug('Use Audience: ' + useAudience);

		if (useAudience) {
			audienceIds = getAudienceTargetIds(communityId);
		}

		Set<String> eventIds = new Set<String>();
		String Query = getSelectClause();

		Query += getFromClause();

		Query += ' WHERE  Id = \'' + String.escapeSingleQuotes(eventRecordId.trim()) + '\'';

		if (requireGroupMembership()) {
			Set<String> memberGroups = getGroups().keySet();
			List<String> memberGroupList = new List<String>(memberGroups);
			List<String> memberGroupIdList = new List<String>();

			for (Id singleId : memberGroupList) {
				memberGroupIdList.add('\'' + (String) singleId + '\'');
			}

			String listOfGroups = String.join(memberGroupIdList, ',');
			String queryWithGroups = ' AND (GroupId__c = null OR GroupId__c IN (' + listOfGroups + '))';

			Query += memberGroups.isEmpty() ? ' AND GroupId__c = null' : queryWithGroups;
		}

		if (useAudience) {
			Query += getAudienceQuery(audienceIds);
		}

		x7sEventsBaseController.debugPrintLongString('Load Event From Id', Query);

		x7sEventsListWrapper wrapper = new x7sEventsListWrapper(
			Query,
			null,
			1,
			null,
			null,
			null,
			null,
			eventIds,
			null,
			false,
			null,
			null,
			UserInfo.getLanguage(),
			UserInfo.getUserType(),
			audienceIds
		);

		if (wrapper.objEventList.size() > 0) {
			X7S_Event__c event = wrapper.objEventList[0];

			wrapper.detailsForAddToCalendar = breakUpDetails(event.Details__c);
			wrapper.summaryForAddToCalendar = breakUpDetails(event.Summary__c);
		} else {
			System.debug('Did not load any events.');
		}

		return wrapper;
	}

	@TestVisible
	private static String breakUpDetails(String details) {
		if (String.isBlank(details)) {
			return '';
		}

		Integer sizeOfDetails = measureString(details);
		String updatedDetails = '';

		if (sizeOfDetails > 75) {
			String newLine = '\r\n ';
			Integer stringLength = details.length();
			Integer characterIndex = 0;
			Integer maximumLineLength = 75 - measureString(newLine);
			Integer lineLength = maximumLineLength;

			do {
				String characterToCheck = details.substring(characterIndex, characterIndex + 1);
				Integer characterLength = measureString(characterToCheck);

				if (lineLength - characterLength >= 0) {
					lineLength -= characterLength;
					updatedDetails += characterToCheck;

					if (lineLength == 0) {
						updatedDetails += newLine;

						lineLength = maximumLineLength;
					}
				} else {
					updatedDetails += newLine + characterToCheck;
					lineLength = maximumLineLength - characterLength;
				}

				characterIndex++;
			} while (characterIndex < stringLength);
		} else {
			updatedDetails = details;
		}

		return updatedDetails;
	}

	private static Integer measureString(String stringToMeasure) {
		if (String.isNotBlank(stringToMeasure)) {
			Blob stringBlob = Blob.valueOf(stringToMeasure);
			return stringBlob.size();
		}

		return 0;
	}

	@AuraEnabled
	public static String getEventTypeList() {
		try {
			return x7sEventsBaseController.buildPicklistValuesJSON(EVENT_OBJECT_NAME, 'Event_Type__c');
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static String getEventMeetingTypeList() {
		try {
			return x7sEventsBaseController.buildPicklistValuesJSON(EVENT_OBJECT_NAME, 'Meeting_Type__c');
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static String getEventRegRequiredList() {
		try {
			return x7sEventsBaseController.buildPicklistValuesJSON(EVENT_OBJECT_NAME, 'Registration__c');
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static List<String> getEventFormatList() {
		try {
			return x7sEventsBaseController.buildPicklistValues(EVENT_OBJECT_NAME, EXPERIENCE_LITERAL);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static String getExperienceList() {
		try {
			return x7sEventsBaseController.buildPicklistValuesJSON(EVENT_OBJECT_NAME, EXPERIENCE_LITERAL);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static List<String> getEventPickList(String fieldName, String searchString) {
		List<String> values = new List<String>();

		try {
			String queryStart = 'SELECT e.';
			String queryEnd = '';

			queryStart += nameSpace + fieldName;
			queryStart += ' c, ';
			queryStart += ' COUNT_DISTINCT(e.Id)';
			queryStart += FROM_QUERY_STRING;
			queryStart += nameSpace + 'X7S_Event__c e';

			if (String.isNotBlank(searchString)) {
				queryStart += ' WHERE (' + fieldName;
			}

			queryEnd += ' GROUP BY ' + fieldName;
			queryEnd += ' LIMIT ' + 100;

			List<AggregateResult> results;

			if (String.isNotBlank(searchString)) {
				results = Database.query(
					String.escapeSingleQuotes(queryStart) +
					' LIKE \'%' +
					String.escapeSingleQuotes(searchString) +
					'%\')' +
					String.escapeSingleQuotes(queryEnd)
				);
			} else {
				results = Database.query(String.escapeSingleQuotes(queryStart + queryEnd));
			}

			for (AggregateResult ar : results) {
				String entry = (String) ar.get('c');

				if (String.isNotBlank(entry)) {
					values.add(entry);
				}
			}

			return values;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Method to attach attachment to Event
	 *
	 * @param eventId Event Id
	 * @param attachmentType Attachment Type
	 * @param attachmentName Image attachment file name
	 * @param image Featured image as a binary64 encoded string
	 *
	 * @return Attachment Object
	 */
	@AuraEnabled
	public static Attachment updateImage(
		String eventId,
		String attachmentType,
		String attachmentName,
		String image
	) {
		requireAuthenticatedUser();

		try {
			if (
				Attachment.SObjectType.getDescribe().isAccessible() &&
				Attachment.SObjectType.getDescribe().isCreateable() &&
				Schema.SObjectType.Attachment.fields.ParentId.isCreateable() &&
				Schema.SObjectType.Attachment.fields.Body.isCreateable() &&
				Schema.SObjectType.Attachment.fields.ContentType.isCreateable() &&
				Schema.SObjectType.Attachment.fields.Name.isCreateable() &&
				String.isNotEmpty(image) &&
				String.isNotEmpty(attachmentType) &&
				String.isNotEmpty(attachmentName)
			) {
				Attachment attachment = new Attachment();
				attachment.Body = EncodingUtil.base64Decode(image);
				attachment.Name = String.valueOf(('' + attachmentName));
				attachment.ParentId = eventId;
				attachment.ContentType = attachmentType;
				insert attachment;
				return attachment;
			}
			return null;
		} catch (Exception ex) {
			System.debug('Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @description Method to save and link related file to event
	 *
	 * @param eventId Event Id
	 * @param attachmentName Image attachment file name
	 * @param image Featured image as a binary64 encoded string
	 *
	 * @return Newly created ContentDocumentLink object
	 */
	@AuraEnabled
	public static ContentDocumentLink saveRelatedFile(
		String eventId,
		String attachmentName,
		String image
	) {
		requireAuthenticatedUser();
		if (
			String.isNotEmpty(eventId) &&
			String.isNotEmpty(image) &&
			String.isNotEmpty(attachmentName)
		) {
			try {
				if (
					ContentVersion.SObjectType.getDescribe().isCreateable() &&
					Schema.SObjectType.ContentVersion.fields.Title.isCreateable() &&
					Schema.SObjectType.ContentVersion.fields.PathOnClient.isCreateable() &&
					Schema.SObjectType.ContentVersion.fields.ContentLocation.isCreateable() &&
					Schema.SObjectType.ContentVersion.fields.VersionData.isCreateable() &&
					ContentDocumentLink.SObjectType.getDescribe().isCreateable() &&
					Schema.SObjectType.ContentDocumentLink.fields.ContentDocumentId.isCreateable() &&
					Schema.SObjectType.ContentDocumentLink.fields.LinkedEntityId.isCreateable() &&
					Schema.SObjectType.ContentDocumentLink.fields.ShareType.isCreateable() &&
					Schema.SObjectType.ContentDocumentLink.fields.Visibility.isCreateable()
				) {
					ContentVersion content = new ContentVersion();

					content.Title = attachmentName;
					content.PathOnClient = '/' + attachmentName;
					content.ContentLocation = 'S';
					content.VersionData = EncodingUtil.base64Decode(image);

					insert content;

					ContentVersion insertedContent = [
						SELECT ContentDocumentId
						FROM ContentVersion
						WHERE Id = :content.Id
					];

					ContentDocumentLink relatedLink = new ContentDocumentLink();

					relatedLink.ContentDocumentId = insertedContent.ContentDocumentId;
					relatedLink.LinkedEntityId = eventId;
					relatedLink.ShareType = 'I';
					relatedLink.Visibility = 'AllUsers';
					insert relatedLink;

					ContentDocumentLink docLink = [
						SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
						FROM ContentDocumentLink
						WHERE LinkedEntityId = :eventId AND ContentDocumentId = :relatedLink.ContentDocumentId
						LIMIT 1
					];
					X7S_Event__c event = [
						SELECT Id, Image_Reference__c
						FROM X7S_Event__c
						WHERE Id = :eventId
						LIMIT 1
					];

					if (
						event.Id != null &&
						docLink.ContentDocument.LatestPublishedVersionId != null &&
						X7S_Event__c.SObjectType.getDescribe().isUpdateable() &&
						Schema.SObjectType.X7S_Event__c.fields.Image_Reference__c.isUpdateable()
					) {
						event.Image_Reference__c = docLink.ContentDocument.LatestPublishedVersionId;
						update event;
					}
					return relatedLink;
				}
				return null;
			} catch (Exception ex) {
				System.debug(
					'Error in saveRelatedFile():' +
					ex.getMessage() +
					',Line number : ' +
					ex.getLineNumber()
				);
				throw new AuraHandledException(ex.getMessage());
			}
		}

		return null;
	}

	private static Boolean useLanguage() {
		Boolean useMultiLanguage = false;

		try {
			X7S_Events_Setting__mdt setting = X7S_Events_Setting__mdt.getInstance(EVENTS_SETTING_DEFAULT);

			useMultiLanguage = setting.Enable_Multi_Language__c;
		} catch (Exception e) {
			System.debug(
				System.LoggingLevel.ERROR,
				'X7S_Events_Setting__mdt not configured for Enable_Multi_Language__c'
			);
		}

		return useMultiLanguage;
	}

	@AuraEnabled
	public static String getLanguage() {
		try {
			return useLanguage() ? UserInfo.getLanguage() : '';
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@TestVisible
	private static Set<String> multiLanguageSet(List<String> eventIds, Set<String> multiLngIds) {
		Set<String> eventLanguageIds = new Set<String>();

		for (String id : eventIds) {
			if (multiLngIds.contains(id)) {
				eventLanguageIds.add(id);
			}
		}
		return eventLanguageIds;
	}

	@AuraEnabled(Cacheable=true)
	public static Map<String, String> getLanguageOption() {
		Map<String, String> languageOpts = new Map<String, String>();
		try {
			Schema.DescribeFieldResult fieldResult = X7S_Event__c.language__c.getDescribe();
			List<Schema.PicklistEntry> pList = fieldResult.getPicklistValues();
			for (Schema.PicklistEntry picklistEntry : pList) {
				languageOpts.put(picklistEntry.getLabel(), picklistEntry.getValue());
			}
			return languageOpts;
		} catch (Exception ex) {
			System.debug(ERROR_MESSAGE + ex.getMessage() + ERROR_LINE + ex.getLineNumber());
			throw new AuraHandledException(ex.getMessage());
		}
	}

	//////////////////////////////////////////////////////////////////////////////////////////////////
	// Audience Personalization
	//

	final static ConnectApi.PublishStatus CONNECT_API_PUBLISH_STATUS_DRAFT = ConnectApi.PublishStatus.Draft;
	final static ConnectApi.PublishStatus CONNECT_API_PUBLISH_STATUS_LIVE = ConnectApi.PublishStatus.Live;
	final static String AUDIENCE_DEFAULT = 'Default';
	final static Integer AUDIENCE_QUERY_LIMIT = 200;
	final static String TOKEN_SOBJECT_NAME = 'X7S_Event__c';
	final static String TOKEN_GROUP_NAME = 'Event Entry';

	/**
	 * @description Check CMT record for audience checkbox
	 *
	 * @return Audience enabled status - true or false
	 */
	@AuraEnabled(Cacheable=true)
	public static Boolean audienceEnabled() {
		try {
			return X7S_Events_Setting__mdt.getInstance(EVENTS_SETTING_DEFAULT)
				?.Enable_Audience_Targeting__c;
		} catch (Exception ex) {
			System.debug('CMT audienceEnabled exception: ' + ex.getMessage());
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @description Get all defined audiences for the community
	 *
	 * @param networkId Community Id
	 * @param searchString search by name
	 *
	 * @return Map of audience Ids and Names
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<String, String> getAudienceList(String networkId, String searchString) {
		requireAuthenticatedUser();
		Map<String, String> audienceList = new Map<String, String>();

		try {
			String tempCommunityId = String.isBlank(networkId)
				? communityId
				: String.escapeSingleQuotes(networkId);

			if (String.isBlank(tempCommunityId)) {
				if (Test.isRunningTest()) {
					tempCommunityId = x7sEventsUtility.strNetworkId;
				} else {
					return audienceList;
				}
			}

			String siteId = tempCommunityId.substring(0, 15);

			String query = 'SELECT Id, AudienceName, ContainerId, DeveloperName FROM Audience WHERE ContainerId = :siteId ';
			if (String.isNotBlank(searchString)) {
				query +=
					' AND AudienceName LIKE \'%' +
					String.escapeSingleQuotes(searchString) +
					PERCENTAGE_LITERAL;
			}
			query += ' ORDER BY AudienceName LIMIT :AUDIENCE_QUERY_LIMIT';

			List<Audience> audiences = Database.query(String.escapeSingleQuotes(query));

			for (Audience audience : audiences) {
				if (audience.AudienceName != AUDIENCE_DEFAULT) {
					audienceList.put(audience.Id, audience.AudienceName);
				}
			}

			return audienceList;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Assign the item to an audience
	 *
	 * @param audienceId Selected Audience is
	 * @param recordId record Id
	 * @param networkId Community ID
	 *  NOTE: networkId must be provided as the future method do not have access to NetWork
	 */
	@Future
	public static void assignAudienceToRecord(String audienceId, String recordId, String networkId) {
		ConnectApi.TargetCollectionInput inputCollection = new ConnectApi.TargetCollectionInput();
		List<ConnectApi.TargetInput> targetInputList = new List<ConnectApi.TargetInput>();
		ConnectApi.TargetInput targetInput = new ConnectApi.TargetInput();

		targetInput.audienceId = audienceId.substring(0, 15);
		targetInput.groupName = TOKEN_GROUP_NAME;
		targetInput.publishStatus = CONNECT_API_PUBLISH_STATUS_LIVE;
		targetInput.targetType = EVENT_OBJECT_NAME;
		targetInput.targetValue = recordId.substring(0, 15);

		targetInputList.add(targetInput);

		inputCollection.targets = targetInputList;

		ConnectApi.TargetCollection targetOutput = ConnectApi.Personalization.createTargets(
			networkId.substring(0, 15),
			inputCollection
		);

		for (ConnectApi.TargetInput input : inputCollection.targets) {
			input.publishStatus = CONNECT_API_PUBLISH_STATUS_DRAFT;
		}

		targetOutput = ConnectApi.Personalization.createTargets(
			networkId.substring(0, 15),
			inputCollection
		);

		System.debug('assignAudienceToRecord' + targetOutput);
	}

	/**
	 * @description Remove the item from the audience
	 *
	 * @param recordId record Id
	 */
	@AuraEnabled
	public static void deleteCurrentAudience(String recordId) {
		requireAuthenticatedUser();
		try {
			if (Schema.SObjectType.X7S_Event__c.isUpdateable()) {
				X7S_Event__c event = [
					SELECT Id, Audience_Selected__c
					FROM X7S_Event__c
					WHERE Id = :recordId
					WITH SECURITY_ENFORCED
					LIMIT 1
				];
				if (event != null) {
					event.Audience_Selected__c = false;
					update event;
				}

				deleteAudienceRecord(System.Network.getNetworkId(), recordId);
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description Remove the item from the audience
	 *
	 * @param networkId Community Id
	 * @param recordId record Id
	 * NOTE: networkId must be provided as the future method do not have access to NetWork
	 */
	@Future
	public static void deleteAudienceRecord(String networkId, String recordId) {
		if (String.isNotBlank(recordId)) {
			String tempCommunityId = networkId;
			if (String.isBlank(tempCommunityId)) {
				if (Test.isRunningTest()) {
					tempCommunityId = x7sEventsUtility.strNetworkId;
				} else {
					return;
				}
			}

			List<String> targets = getTargetsForRecordId(tempCommunityId, recordId);

			if (!targets.isEmpty()) {
				for (String target : targets) {
					ConnectApi.Personalization.deleteTarget(
						tempCommunityId.substring(0, 15),
						target.substring(0, 15)
					);
				}
			}
		}
	}

	@TestVisible
	private static List<String> getAudienceTargetIds(String networkId) {
		List<String> targetIds = new List<String>();
		List<String> targetTypes = new List<String>{ TOKEN_SOBJECT_NAME };
		List<String> groupTypes = new List<String>{ TOKEN_GROUP_NAME };
		Boolean includeAudience = true;
		Boolean includeInGroups = true;

		String tempCommunityId = String.isBlank(networkId) ? communityId : networkId;

		if (String.isBlank(tempCommunityId)) {
			if (Test.isRunningTest()) {
				tempCommunityId = x7sEventsUtility.strNetworkId;
			} else {
				return targetIds;
			}
		}

		ConnectApi.TargetCollection targetCollection = ConnectApi.Personalization.getTargets(
			tempCommunityId.substring(0, 15),
			null,
			null,
			null,
			CONNECT_API_PUBLISH_STATUS_DRAFT,
			null,
			targetTypes,
			includeAudience,
			includeInGroups,
			groupTypes
		);

		for (ConnectApi.Target target : targetCollection.targets) {
			targetIds.add(target.targetValue);
		}

		return targetIds;
	}

	/**
	 * @description Get the audience Id for the specified record
	 *
	 * @param networkId Community ID
	 * @param recordId Item record Id
	 *
	 * @return Audience id
	 */
	@AuraEnabled
	public static String getAudienceIdForRecordId(String networkId, String recordId) {
		requireAuthenticatedUser();
		try {
			String audienceId = '';
			ConnectApi.Target target = getTarget(networkId, recordId);

			if (target != null) {
				audienceId = (String) ((ConnectApi.AudienceTarget) target.audience).id;
			}

			return audienceId;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@TestVisible
	private static List<String> getTargetsForRecordId(String networkId, String recordId) {
		List<String> targetIds = new List<String>();

		try {
			String tempCommunityId = String.isBlank(networkId) ? communityId : networkId;

			if (String.isBlank(tempCommunityId)) {
				if (Test.isRunningTest()) {
					tempCommunityId = x7sEventsUtility.strNetworkId;
				} else {
					return targetIds;
				}
			}

			String targetRecordId = recordId.substring(0, 15);
			String targetCommunity = tempCommunityId.substring(0, 15);

			List<PersonalizationTargetInfo> targets = [
				SELECT Id, ContainerId, TargetValue, PublishStatus
				FROM PersonalizationTargetInfo
				WHERE ContainerId = :targetCommunity AND TargetValue = :targetRecordId
				WITH SECURITY_ENFORCED
				ORDER BY PublishStatus DESC
				LIMIT :AUDIENCE_QUERY_LIMIT
			];

			if (!targets.isEmpty()) {
				for (PersonalizationTargetInfo target : targets) {
					targetIds.add(target.Id);
				}
			}
		} catch (Exception e) {
			System.debug(
				'getTargetsForRecordId(): ' +
				e.getMessage() +
				' line number: ' +
				e.getLineNumber()
			);
		}

		return targetIds;
	}

	private static ConnectApi.Target getTarget(String networkId, String recordId) {
		ConnectApi.Target target = null;
		try {
			String tempCommunityId = String.isBlank(networkId) ? communityId : networkId;
			String targetValue = String.isNotBlank(recordId) ? recordId.substring(0, 15) : null;

			List<PersonalizationTargetInfo> targetInfos = [
				SELECT Id, DraftRowId, ContainerId, TargetType, TargetValue, GroupName, PublishStatus
				FROM PersonalizationTargetInfo
				WHERE TargetValue = :targetValue AND ContainerId = :tempCommunityId
				WITH SECURITY_ENFORCED
			];

			if (!targetInfos.isEmpty()) {
				String targetId = targetInfos[0].Id;

				target = ConnectApi.Personalization.getTarget(tempCommunityId, targetId);

				System.debug(
					'Found target for recordId :' +
					target.id +
					' audience: (' +
					((ConnectApi.AudienceTarget) target.audience).id +
					') ' +
					((ConnectApi.AudienceTarget) target.audience).audienceName
				);
			}
		} catch (Exception e) {
			System.debug('getTarget() : ' + e.getMessage() + ' line number: ' + e.getLineNumber());
		}

		return target;
	}
	/**
	 * @description Get the Registration Setting records from CMT
	 *
	 * @return RegSetting CMT Records
	 */
	@AuraEnabled
	public static Map<String, String> getRegistrationCMT() {
		Map<String, String> regRecords = new Map<String, String>();

		try {
			Map<String, X7S_Event_Reg_Setting__mdt> mapReg = X7S_Event_Reg_Setting__mdt.getAll();
			for (String rec : mapReg.keySet()) {
				if (mapReg.get(rec).Active__c == true) {
					regRecords.put(mapReg.get(rec).MasterLabel, mapReg.get(rec).DeveloperName);
				}
			}
			return regRecords;
		} catch (Exception ex) {
			System.debug(ERROR_MESSAGE + ex.getMessage() + ERROR_LINE + ex.getLineNumber());
			throw new AuraHandledException(ex.getMessage());
		}
	}

	@AuraEnabled
	public static String getRegCMTDescription(String cmtName) {
		String cmtDescription;
		try {
			X7S_Event_Reg_Setting__mdt mc = X7S_Event_Reg_Setting__mdt.getInstance(cmtName);
			if (mc != null) {
				cmtDescription = mc.Description__c;
			}
			return cmtDescription;
		} catch (Exception ex) {
			System.debug(ERROR_MESSAGE + ex.getMessage() + ERROR_LINE + ex.getLineNumber());
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @description Get the Registration Setting records from CMT
	 *
	 * @return Map RegSetting label and MasterLabel
	 */
	@AuraEnabled
	public static Map<String, String> getEventIntegrationCMT() {
		Map<String, String> integrationOptions = new Map<String, String>();

		try {
			// Add default option.
			integrationOptions.put(Label.x7sEventsMeetingFormatStandard, EVENT_FORMAT_STANDARD);

			Map<String, X7S_Event_Integration_Setting__mdt> mapReg = X7S_Event_Integration_Setting__mdt.getAll();

			for (String rec : mapReg.keySet()) {
				if (mapReg.get(rec).Active__c == true) {
					integrationOptions.put(mapReg.get(rec).MasterLabel, mapReg.get(rec).DeveloperName);
				}
			}

			return integrationOptions;
		} catch (Exception ex) {
			System.debug(ERROR_MESSAGE + ex.getMessage() + ERROR_LINE + ex.getLineNumber());
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @description Get the Registration Setting virtual platform field value from CMT
	 * @param cmtName CMT Setting name
	 * @return String virtual platform value
	 */
	@AuraEnabled
	public static String getVirtualPlatform(String cmtName) {
		String virtualPlatform = null;

		try {
			X7S_Event_Integration_Setting__mdt mapReg = X7S_Event_Integration_Setting__mdt.getInstance(
				cmtName
			);
			if (mapReg.DeveloperName != null) {
				virtualPlatform = mapReg.Virtual_Platform__c;
				System.debug('virtualPlatform---' + virtualPlatform);
			}
			return virtualPlatform;
		} catch (Exception ex) {
			System.debug(ERROR_MESSAGE + ex.getMessage() + ERROR_LINE + ex.getLineNumber());
			throw new AuraHandledException(ex.getMessage());
		}
	}

	/**
	 * @description This method is used to sync meeting id
	 * @param meetingId     : id of external meeting to search for
	 * @param eventFormat   : Event format, will identify the CMT to load external meeting specific information.
	 *
	 * @return A structure containing the external meeting information for Name, Description, Start Time, End Time Meeting Type, and Registration
	 */
	@AuraEnabled
	public static String syncMeetingId(String meetingId, String eventFormat) {
		requireAuthenticatedUser();
		try {
			// Create a temp event, this event will not be saved.
			X7S_Event__c event = new X7S_Event__c();

			event.MeetingId__c = meetingId;
			event.Event_Format__c = eventFormat;

			x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
				event
			);

			x7sEventsIExternalMeetingResponse meetingResponse = externalMeeting.get(event);

			if (meetingResponse.isSuccess()) {
				return meetingResponse.getResult();
			} else {
				System.debug('Error: ' + meetingResponse.getError());

				throw new EventListControllerException(meetingResponse.getError());
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description : To delete external meeting
	 * @param meetingId        : External meeting id
	 * @param eventFormat       : CMT name of integration setting
	 * @param meetingType       : Type of meeting, Webinar or Meeting
	 *
	 * @return  result of delete operation.
	 */
	@AuraEnabled
	public static String deleteMeetingExternal(
		String meetingId,
		String eventFormat,
		String meetingType
	) {
		requireAuthenticatedUser();
		try {
			// Create a temp event, this event will not be saved.
			X7S_Event__c event = new X7S_Event__c();

			event.MeetingId__c = meetingId;
			event.Event_Format__c = eventFormat;
			event.Meeting_Type__c = meetingType;

			x7sEventsIExternalMeeting externalMeeting = x7sEventsExternalMeetingFactory.getExternalMeeting(
				event
			);

			x7sEventsIExternalMeetingResponse meetingResponse = externalMeeting.deleteExternal(event);

			if (meetingResponse.isSuccess()) {
				return meetingResponse.getResult();
			} else {
				System.debug('Error: ' + meetingResponse.getError());

				throw new EventListControllerException(meetingResponse.getError());
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static String getUserName(String userId) {
		try {
			User queryUser = [SELECT Id, Name FROM User WHERE Id = :userId WITH SECURITY_ENFORCED];

			if (queryUser != null) {
				return queryUser.Name;
			}
			return '';
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description :  Validate field API name
	 *
	 * @param recordId Id of the record
	 *
	 * @return string as name of the record
	 */
	@AuraEnabled
	public static List<SObject> getCustomLookupDisplayName(String recordId) {
		try {
			// Prepare results
			List<SObject> results = new List<SObject>();

			if (String.isNotBlank(recordId)) {
				Id myId = (Id) recordId;
				String sObjName = myId.getSobjectType().getDescribe().getName();
				System.debug(sObjName);

				String queryRecord = 'SELECT Id, Name FROM ' + sObjName + ' WHERE Id =: myId WITH USER_MODE';

				results.addAll(Database.query(queryRecord)); //NOPMD
			}

			return results;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	/**
	 * @description :  get default fieldset
	 *
	 * @return string as name of the fieldset
	 */
	@AuraEnabled
	public static String getFieldSetName() {
		try {
			String shrFieldSet = '';
			X7S_Events_Setting__mdt fieldSet = X7S_Events_Setting__mdt.getInstance(
				EVENTS_SETTING_DEFAULT
			);
			if (fieldSet.X7S_Event_Default_Custom_Field_Set__c != null) {
				String fieldSetId = fieldSet.X7S_Event_Default_Custom_Field_Set__c;
				X7S_Shr_Custom_Field_Set__mdt fieldSetName = X7S_Shr_Custom_Field_Set__mdt.getInstance(
					fieldSetId
				);
				if (fieldSetName.Active__c && fieldSetName.Object_API_Name__c == 'X7S_Event__c') {
					shrFieldSet = fieldSetName.DeveloperName;
				}
			}
			return shrFieldSet;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static void requireAuthenticatedUser() {
		if (Auth.CommunitiesUtil.isGuestUser()) {
			throw new AuraHandledException('Access denied.');
		}
	}
}