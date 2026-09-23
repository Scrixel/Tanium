/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasNewControllerTest {
	public static List<Community> currCommunity;
	public static Idea awesomeIdea;
	public static Network currNetwork;
	public static List<Idea> currIdeaList;

	private static final String TestIdeaName = 'test_X7__1';

	static void testSetupQuery(Boolean queryData) {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdeaList = [SELECT Id FROM Idea WHERE Title = 'test_X7__1' ORDER BY CreatedDate DESC];

		if (queryData) {
			awesomeIdea = [SELECT Id FROM Idea WHERE Title = 'test is awesome'];
		}
	}

	@TestSetup
	static void testSetupData() {
		x7sIdeasNewControllerTest.testSetupQuery(false);
		System.assertNotEquals(null, x7sIdeasNewControllerTest.currCommunity);
		System.assert(x7sIdeasNewControllerTest.currCommunity.size() > 0);
		List<Idea> ideasToInsert = new List<Idea>();

		for (Integer i = 0; i < 1; i++) {
			Idea currIdea = new Idea(Title = 'test is awesome', CommunityId = x7sIdeasNewControllerTest.currCommunity[0].Id);
			ideasToInsert.add(currIdea);
		}

		for (Integer i = 0; i < 5; i++) {
			Idea currIdea = new Idea(Title = TestIdeaName, CommunityId = x7sIdeasNewControllerTest.currCommunity[0].Id);
			ideasToInsert.add(currIdea);
		}

		insert ideasToInsert;
		System.assert(ideasToInsert.size() == 6);
		System.assertNotEquals(null, ideasToInsert[0].Id);
	}

	@IsTest
	static void test_isAuthenticated() {
		System.assert(true, x7sIdeasNewController.isAuthenticated());
	}

	@IsTest
	static void test_getSitePrefix() {
		System.assertEquals('', x7sIdeasNewController.getSitePrefix());
	}

	@IsTest
	static void test_getZoneId() {
		x7sIdeasNewControllerTest.testSetupQuery(false);
		System.assertNotEquals('', x7sIdeasNewController.getZoneId(x7sIdeasNewControllerTest.currCommunity[0].Name));
		System.assertEquals('', x7sIdeasNewController.getZoneId('______'));
		System.assertEquals('', x7sIdeasNewController.getZoneId(''));
	}

	@IsTest
	static void test_createIdeaNew() {
		x7sIdeasNewControllerTest.testSetupQuery(false);
		List<Idea> ideaList = new List<Idea>();
		Idea currIdea = new Idea(Title = TestIdeaName, CommunityId = x7sIdeasNewControllerTest.currCommunity[0].Id);
		ideaList.add(currIdea);
		System.assertNotEquals(null, x7sIdeasNewController.createIdeaNew('x7sTestZone',ideaList, '', null, ''));
		System.assertEquals(null, x7sIdeasNewController.createIdeaNew('x7sTestZone',null, null, null, ''));
	}

	@IsTest
	static void test_createIdeaWithRelatedFile() {
		x7sIdeasNewControllerTest.testSetupQuery(false);
		List<Idea> ideaList = new List<Idea>();
		Idea currIdea = new Idea(Title = TestIdeaName, CommunityId = x7sIdeasNewControllerTest.currCommunity[0].Id);
		ideaList.add(currIdea);

		x7sIdeasNewController.RelatedFiles relatedFiles = new x7sIdeasNewController.RelatedFiles();
		x7sIdeasNewController.RelatedFile relatedFile = new x7sIdeasNewController.RelatedFile();
		relatedFiles.files = new List<x7sIdeasNewController.RelatedFile>();

		relatedFile.name = 'x7s_test_File1';
		relatedFile.fileName = 'x7s_test_file1.txt';
		relatedFile.dataString = 'abcdefg';
		relatedFiles.files.add(relatedFile);
		String relatedFilesString = JSON.serialize(relatedFiles);

		System.assertNotEquals(null, x7sIdeasNewController.createIdeaNew('x7sTestZone',ideaList, '', relatedFilesString, 'AllUsers'));
	}

	@IsTest
	static void test_updateIdea() {
		x7sIdeasNewControllerTest.testSetupQuery(false);
		List<Idea> ideaList = new List<Idea>();
		Idea currIdea = new Idea(Title = TestIdeaName, CommunityId = x7sIdeasNewControllerTest.currCommunity[0].Id);
		ideaList.add(currIdea);
		System.assertNotEquals(null, x7sIdeasNewController.createIdeaNew('x7sTestZone',ideaList, '', null, ''));

		currIdea.Title = 'Updated Title X7';
		List<Idea> updateList = new List<Idea>();
		updateList.add(currIdea);
		x7sIdeasNewController.createIdeaNew('x7sTestZone',updateList, '', null, '');
		x7sIdeasListWrapper wrapper = x7sIdeasViewController.getIdeaRecord(x7sIdeasNewControllerTest.currCommunity[0].Id, currIdea.Id, '');
		Idea savedIdea = wrapper.ideaList[0];
		System.assertEquals('Updated Title X7', savedIdea.Title);

		System.assertEquals(null, x7sIdeasNewController.createIdeaNew('x7sTestZone',null, null, null, ''));
	}

	@IsTest
	static void test_deleteIdea() {
		x7sIdeasNewControllerTest.testSetupQuery(false);
		List<Idea> ideaList = new List<Idea>();
		Idea currIdea = new Idea(Title = TestIdeaName, CommunityId = x7sIdeasNewControllerTest.currCommunity[0].Id);
		ideaList.add(currIdea);
		Id currIdeaId = x7sIdeasNewController.createIdeaNew('x7sTestZone',ideaList, '', null, '');
		System.assertNotEquals(null, currIdeaId);

		System.assertEquals(true, x7sIdeasNewController.deleteIdea(currIdeaId + ''));
		System.assertEquals(false, x7sIdeasNewController.deleteIdea(currIdeaId + ''));
	}

	@IsTest
	static void test_checkDuplicateIdeas() {
		x7sIdeasNewControllerTest.testSetupQuery(true);
		Id[] fixedSearchResults = new Id[]{
			x7sIdeasNewControllerTest.awesomeIdea.Id
		};
		System.Test.setFixedSearchResults(fixedSearchResults);
		List<Idea> ideaList = x7sIdeasNewController.checkDuplicateIdeas(TestIdeaName, x7sIdeasNewControllerTest.currCommunity[0].Id + '', 5, '');
		System.assertEquals(5, ideaList.size());
	}

	@IsTest
	static void test_getTopicNamesList() {
		String testTopicName = 'test_X7S__1';
		Topic t = new Topic(Name = testTopicName);
		insert t;

		Test.startTest();
		List<Topic> topicList = x7sIdeasNewController.getTopicNamesList(false);
		Boolean containsValue = false;
		for (Topic s : topicList) {
			if (s.Name == testTopicName) {
				containsValue = true;
			}
		}
		System.assertEquals(true, containsValue);
		Test.stopTest();
	}

	@IsTest
	static void test_getPicklistValues() {
		List<String> pickList = x7sIdeasUtility.getIdeaCategoryValues();
		System.debug(LoggingLevel.DEBUG, pickList);
		System.assertNotEquals(null, pickList);
	}

	@IsTest
	static void test_getThemeList() {
		List<IdeaTheme> themes = x7sIdeasNewController.getThemeList('');
		System.assertEquals(true, themes.isEmpty(), 'Themes for idea should be empty');
	}

	@IsTest
	static void test_defaultStatus() {
		String statusList = '';
		String status = x7sIdeasNewController.getDefaultStatus('x7sTestZone', statusList);
		System.assertNotEquals(null, status, 'There must be Idea Status Default Value');

		statusList = 'New,In Progress';
		status = x7sIdeasNewController.getDefaultStatus('x7sTestZone', statusList);
		System.assertNotEquals(null, status, 'There must be Idea Status Default Value');
	}

	@IsTest
	static void test_getCommonSettings() {
		x7sIdeasCommon settings = x7sIdeasNewController.getCommonSettings('');
		System.assertNotEquals(null, settings);
	}

	@IsTest
	static void test_getIdeaNewModel() {
		x7sIdeasNewModel newModel = new x7sIdeasNewModel();
		System.assertNotEquals(null, newModel);

		newModel = x7sIdeasNewController.getIdeasNewModel('', '', true, true, true, '');
		System.assertNotEquals(null, newModel);
	}

	@IsTest
	static void test_fetchUsers() {
		User usr = x7sIdeasUtilityTest.createStandardTestUser();
		usr.LastName = 'X7STesting';
		update usr;

		List<User> listOfUsers = x7sIdeasNewController.fetchUsers('X7STest');
		System.assert(listOfUsers.size() > 0);

	}

	@IsTest
	static void test_getRequestedByRecord() {
		User usr = x7sIdeasUtilityTest.createStandardTestUser();
		User reqUser = x7sIdeasNewController.getRequestedByRecord(usr.Id);
		System.assertEquals(reqUser.LastName, x7sIdeasUtilityTest.TEST_USER_LASTNAME);
	}

	@IsTest
	static void test_getQuestionDetail() {
		User usr = x7sIdeasUtilityTest.createStandardTestUser();

		System.runAs(usr) {
			FeedItem feedItem = new FeedItem(Type = 'QuestionPost', Title = 'Test Title', Body = 'testing', ParentId = usr.Id);
			insert feedItem;
			System.debug('Feed item: ' + feedItem);

			x7sIdeasNewController.QuestionDetail questionDetail = x7sIdeasNewController.getQuestionDetail(feedItem.Id);
			System.debug('Detail: ' + questionDetail);

			System.assertEquals(questionDetail.Title, 'Test Title', 'Feed Item TITLE do not match');
			System.assertEquals(questionDetail.Body, 'testing', 'Feed Item BODY do not match');
			System.assertEquals(questionDetail.requestedBy.Id, usr.Id, 'Feed Item REQUESTED BY do not match');
		}
	}

	@IsTest
	static void test_getStatusValues() {
		List<String> values = x7sIdeasNewController.getStatusValues('x7s Test Zone');
		System.assertNotEquals(null, values);
	}

	@IsTest
	static void test_getCategoryValues() {
		List<String> values = x7sIdeasNewController.getCategoryValues('');
		System.assertNotEquals(null, values);
	}

	@IsTest
	static void test_hasFeaturedFieldAccess() {
		System.assertEquals(true, x7sIdeasNewController.hasFeaturedFieldAccess());
	}
}