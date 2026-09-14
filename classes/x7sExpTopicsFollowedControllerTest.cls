/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public class x7sExpTopicsFollowedControllerTest {
	private static User testUser;

	@IsTest
	public static void testGetMyFollowedTopics() {
		setupData();

		Topic newTopic = new Topic(Name = 'Test Topic');
		insert newTopic;

		Test.startTest();

		List<Topic> followedTopics = new List<Topic>();
		System.runAs(testUser) {
			followedTopics = x7sExpTopicsFollowedController.getMyFollowedTopics(null);
			System.assertEquals(0, followedTopics.size());
		}

		EntitySubscription newSub = new EntitySubscription(
			ParentId = newTopic.Id,
			SubscriberId = testUser.Id
		);
		insert newSub;

		System.runAs(testUser) {
			followedTopics = x7sExpTopicsFollowedController.getMyFollowedTopics(null);
			System.assertEquals(1, followedTopics.size());
		}

		Test.stopTest();
	}

	public static void setupData() {
		testUser = x7sExpTestUtils.createGuestUser();
		insert testUser;
	}

	@IsTest
	public static void testGetMyFollowedTopics_WhenErrorOccured_ReturnsException() {
		Boolean exceptionThrown = false;
		try {
			List<Topic> followedTopics = x7sExpTopicsFollowedController.getMyFollowedTopics('2147483650');
		} catch (Exception e) {
			exceptionThrown = true;
		}

		System.assertEquals(true, exceptionThrown, 'Exception should be thrown.');
	}
}