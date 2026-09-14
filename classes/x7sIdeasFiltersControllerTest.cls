/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasFiltersControllerTest {
	public static Network currNetwork;
	public static List<Community> currCommunity;
	public static Idea currIdea;

	@TestSetup
	static void testSetupData() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		System.assertNotEquals(null, currCommunity);
	}

	static void testSetupQuery() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdea = [SELECT Id FROM Idea WHERE Title = 'test' ORDER BY CreatedDate DESC LIMIT 1];
		System.assertNotEquals(null, currIdea);
	}

	@IsTest
	static void test_getPicklistValues() {
		System.assertNotEquals(null, x7sIdeasFiltersController.getCategoryValues(''));
		System.assertNotEquals(null, x7sIdeasFiltersController.getStatusValues('Test Zone'));
	}

	@IsTest
	static void test_getTopicNamesList() {
		Topic t = new Topic(Name = 'UnitTestTopic');
		insert t;

		List<String> topicList = x7sIdeasFiltersController.getTopicNamesList();
		Boolean containsValue = false;

		for (String s : topicList) {
			if (s == 'UnitTestTopic') {
				containsValue = true;
			}
		}
		System.assertEquals(true, containsValue);
	}

	@IsTest
	static void test_getThemeValues() {
		List<String> themeList = x7sIdeasFiltersController.getThemeValues('Internal Zone');
		System.assertNotEquals(null, themeList);
		System.debug('Themes: ' + themeList);
	}
	@IsTest
	static void testGetCategoryValues() {
		System.assertNotEquals(null, x7sIdeasFiltersController.getCategoryValues('Theme 1'));
	}

	@IsTest
	static void test_showAccountFilter() {
		System.assertNotEquals(null, x7sIdeasFiltersController.showAccountFilter());
	}
}