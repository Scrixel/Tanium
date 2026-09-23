/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sMembersTopicsController {
	@TestVisible
	private static Id netwrkId = System.Network.getNetworkId();

	// Set of fields used for checking access to Topic fields
	private static String[] TopicAccessFields = new List<String>{ 'Id', 'Name' };

	/**
	 * @description get topics list
	 * @return Map of topics
	 */
	@AuraEnabled
	public static Map<String, String> getTopics() {
		Map<String, String> topics = new Map<String, String>();
		List<Topic> topicList = new List<Topic>();
		Map<String, Schema.SObjectField> topicFldMap = Schema.SObjectType.Topic.fields.getMap();
		try {
			for (String fieldToCheck : TopicAccessFields) {
				if (!topicFldMap.get(fieldToCheck).getDescribe().isAccessible()) {
					throw new System.NoAccessException();
				}
			}

			topicList = netwrkId != null
				? [SELECT Id, Name FROM Topic WHERE NetworkId = :netwrkId ORDER BY Name LIMIT 2000]
				: [SELECT Id, Name FROM Topic ORDER BY Name LIMIT 2000];

			for (Topic t : topicList) {
				topics.put(t.Id, t.Name);
			}

			return topics;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}
}