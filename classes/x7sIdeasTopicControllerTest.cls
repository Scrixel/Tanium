/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasTopicControllerTest {
	private static final String TestTopicName = 'test_X7__1';

	@IsTest
	static void test_getTopicNamesList() {
		Topic t = new Topic(Name = TestTopicName);
		insert t;

		List<String> topicList = x7sIdeasTopicController.getTopicNamesList();

		Boolean containsValue = false;

		for (String s : topicList) {
			if (s == TestTopicName) {
				containsValue = true;
			}
		}
		System.assertEquals(true, containsValue);
	}

	@IsTest
	static void test_getTopicMap() {
		List<Community> currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];

		Topic t = new Topic(Name = TestTopicName);
		insert t;

		Idea currIdea = new Idea(CommunityId = currCommunity[0].Id, Title = TestTopicName, Related_Topic_Name__c = TestTopicName);
		insert currIdea;

		Set<String> uniqueTopicNames = new Set<String>();
		uniqueTopicNames.add(TestTopicName);
		List<String> topicNames = new List<String>();

		for (String name : uniqueTopicNames) {
			topicNames.add(name);
		}

		Map<String, String> topicMap = x7sIdeasTopicController.getTopicMap(topicNames);

		Boolean containsValue = topicMap.containsKey(TestTopicName);

		System.assertEquals(true, containsValue);
	}
}