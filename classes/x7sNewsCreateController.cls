/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Apex class to handle create news article operations
 * @Date: 2022
 * @Author: IBM Corp / 7Summits
 * RequestId  ModifiedDate  Description
 * SS-13018   2026-05-29    Block guest user access to author-only methods (deleteAttachment, getAudienceList); getTopics stays open for the guest-visible News topic filter
 */
public with sharing class x7sNewsCreateController {

    private static final String NEWS_CMT_SETTING_DEFAULT = 'Default';
    private static String TOKEN_SOBJECT_NAME = 'X7S_News__c';
	final static String AUDIENCE_DEFAULT = 'Default';
	final static Integer AUDIENCE_QUERY_LIMIT = 200;

    //We need to use both networkId and strNetworkId to handle 15 digit and 18 digit id in news records as per CLF-210
	//networkId of type id returns 18 digit id
	@TestVisible private static Id networkId = System.Network.getNetworkId();
	//networkId of type string i.e. strNetworkId returns 15 digit id
	@TestVisible private static String strNetworkId = System.Network.getNetworkId();

    @AuraEnabled(Cacheable=true)
	public static Map<String, String> getLanguageOption() {

		Map<String, String> languageOpts = new Map<String, String>();
		try {
			Schema.DescribeFieldResult fieldResult = X7S_News__c.Language__c.getDescribe();
			List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();

			for (Schema.PicklistEntry picklistEntry : picklistEntries) {
				languageOpts.put(picklistEntry.getLabel(), picklistEntry.getValue());
			}
			return languageOpts;
		}
		catch (Exception ex) { System.debug('Error Message:' + ex.getMessage() + ', Error Line:' + ex.getLineNumber()); throw new AuraHandledException(ex.getMessage());}
	}

    @AuraEnabled
	public static Boolean userAuthorizedToPost() {
		Boolean authorized = false;
		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);

			if(setting != null) {				
				authorized = x7sNewsBaseController.permissionSetMember(UserInfo.getUserId(), setting.PermissionSetName__c);
			}
			return authorized;
		}
		catch (Exception ex) {System.debug(System.LoggingLevel.ERROR, 'X7S_News_Setting__mdt not configured ' + +ex.getMessage());  throw new AuraHandledException(ex.getMessage());}
	}

    /**
	 * @description :  Method to fetch topics and display in dropdown of "Topic Filter" component.
	 *
	 * @return Map TopicId, Topic
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<String, String> getTopics() {

		Map<String, String> topics = new Map<String, String>();
		List<Topic> topicList = new List<Topic>();

		try {
			String queryTopic = x7sNewsBaseController.getQueryString('Topic');
			if (String.isNotBlank(queryTopic)) {
				if (String.isNotBlank(networkId)) {
					topicList = Database.query(String.escapeSingleQuotes(queryTopic) +
						' WHERE (NetworkId = \'' + String.escapeSingleQuotes(networkId) + '\'' +
						' OR NetworkId = \'' + String.escapeSingleQuotes(strNetworkId) + '\')' +
						' LIMIT 1000'
					);
				}
				else { topicList = Database.query(String.escapeSingleQuotes(queryTopic) + ' WHERE NetworkId = NULL' + ' LIMIT 1000');}

				for (Topic t : topicList) {
					topics.put(t.Id, t.Name);
				}

				return topics;
			}

			return topics;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	//Delete attachment where user updates attachment on news edit page
	@AuraEnabled
	public static void deleteAttachment(String newsRecordId) {
		requireAuthenticatedUser();
		try {
			if (!Attachment.SObjectType.getDescribe().isDeletable()) {
				System.debug('deleteAttachment() : Unable to delete Attachment');
				return;
			}

			List<Attachment> attachments = new List<Attachment>();
			attachments = [SELECT Id FROM Attachment WHERE ParentId = :newsRecordId];
			if (!attachments.isEmpty()) {
				delete attachments;
			}
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
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
			String communityId = String.isBlank(networkId) ? System.Network.getNetworkId() : networkId;
			if (String.isBlank(communityId)) {
				if (Test.isRunningTest()) { communityId = x7sNewsUtilityTest.strNetworkId;} else { return audienceList;}
			}

			communityId = communityId.substring(0, 15);

			String query = 'SELECT Id, AudienceName, ContainerId, DeveloperName FROM Audience WHERE ContainerId = :communityId ';
			if (String.isNotBlank(searchString)) { query += ' AND AudienceName LIKE \'%' + String.escapeSingleQuotes(searchString) + '%\'';}
			query += ' ORDER BY AudienceName LIMIT :AUDIENCE_QUERY_LIMIT';

			List<Audience> audiences = Database.query(String.escapeSingleQuotes(query));

			for (Audience audience : audiences) {
				if (audience.AudienceName != AUDIENCE_DEFAULT) { audienceList.put(audience.Id, audience.AudienceName);}
			}			

			return audienceList;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description Use to get the ID of the organization timezone.
	 *
	 * @return Timezone Id
	 */
	@AuraEnabled
	public static String getTimeZoneId() {
		String timeZoneId = UserInfo.getTimeZone().getID();

		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);

			if(setting != null && setting.Article_Publish_Date__c == 'Company Time Zone') {
				timeZoneId = [SELECT TimeZoneSidKey FROM Organization LIMIT 1]?.TimeZoneSidKey;
			}

			return timeZoneId;
		}
		catch (Exception ex) { System.debug(System.LoggingLevel.ERROR, 'X7S_News_Setting__mdt not configured ' + ex.getMessage()); throw new AuraHandledException(ex.getMessage());}
	}

	private static void requireAuthenticatedUser() {
		if (Auth.CommunitiesUtil.isGuestUser()) {
			throw new AuraHandledException('Access denied.');
		}
	}
}