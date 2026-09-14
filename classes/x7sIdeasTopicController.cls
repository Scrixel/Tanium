/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasTopicController {
	private static final Integer TOPIC_LOAD_LIMIT = 2000;

	@AuraEnabled
	public static List<String> getTopicNamesList() {
		Id networkId = System.Network.getNetworkId();
		List<String> topicNamesList = new List<String>();
		List<Topic> topicList = new List<Topic>();

		if (networkId != null) { topicList = [SELECT CreatedById,CreatedDate,Description,Id,Name,NetworkId,TalkingAbout FROM Topic WHERE NetworkId = :networkId];
		}
		else {
			topicList = [
				SELECT CreatedById,CreatedDate,Description,Id,Name,NetworkId,TalkingAbout
				FROM Topic
				LIMIT :TOPIC_LOAD_LIMIT
			];
		}

		for (Topic t : topicList) {
			topicNamesList.add(t.Name);
		}

		return topicNamesList;
	}

	@AuraEnabled
	public static Map <String, String> getTopicMap(List<String> uniqueTopicNames) {
		Id networkId = System.Network.getNetworkId();
		Map <String, String> topicNameToId = new Map <String, String>();
		List<Topic> topicList = new List<Topic>();
		try {
			if (networkId != null) { topicList = [SELECT CreatedById, CreatedDate, Description, Id, Name, NetworkId, TalkingAbout FROM Topic WHERE Name IN :uniqueTopicNames AND NetworkId = :networkId];
			}
			else {
				topicList = [
					SELECT CreatedById, CreatedDate, Description, Id, Name, NetworkId, TalkingAbout
					FROM Topic
					WHERE Name IN :uniqueTopicNames
				];
			}

			for (Topic t : topicList) {
				topicNameToId.put(t.Name, t.Id);
			}
			System.debug('----topicNameToId' + topicNameToId);

			return topicNameToId;
		} catch (Exception ex) { System.debug('getTopicMap() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());return topicNameToId;}
	}
}