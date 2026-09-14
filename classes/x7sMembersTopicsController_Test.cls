/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sMembersTopicsController_Test {
	@TestSetup
	private static void setupTestData() {
		List<Topic> testTopics = new List<Topic>();

		for (Integer i = 0; i < x7sMembersTestConstants.TEST_TOPIC_COUNT; i++) {
			testTopics.add(new Topic(Name = 'Topic' + i));
		}

		insert testTopics;
	}

	@IsTest
	private static void testGetTopicMap() {
		Test.startTest();

		Map<String, String> topicMap = x7sMembersTopicsController.getTopics();
		System.assertEquals(x7sMembersTestConstants.TEST_TOPIC_COUNT, topicMap.size());
		System.debug('Topic ' + topicMap);

		Test.stopTest();
	}

	@IsTest
	private static void testGetTopicMapWithNetwork() {
		insert new Topic(
			Name = 'TopicWithNetwork',
			NetworkId = x7sMembersTestConstants.TEST_COMMUNITY_ID
		);

		Test.startTest();

		x7sMembersTopicsController.netwrkId = Id.valueOf(x7sMembersTestConstants.TEST_COMMUNITY_ID);
		Map<String, String> topicMap = x7sMembersTopicsController.getTopics();
		System.assertEquals(1, topicMap.size());
		System.debug('Topic ' + topicMap);

		Test.stopTest();
	}
}