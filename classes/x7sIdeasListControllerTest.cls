/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasListControllerTest {
	public static Network currNetwork;
	public static List<Community> currCommunity;
	public static Idea currIdea;

	static void testSetupQuery() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdea = [SELECT Id FROM Idea WHERE Title = 'test' ORDER BY CreatedDate DESC LIMIT 1];
		currNetwork = [SELECT Id, Name FROM Network WHERE Status IN ('Live', 'UnderConstruction') LIMIT 1];
	}

	@TestSetup
	static void testSetupData() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		System.assertNotEquals(null, currCommunity);
		System.assert(currCommunity.size() > 0);
		List<Idea> tmpIdeaList = new List<Idea>();
		Idea tmpIdea = new Idea(CommunityId = currCommunity[0].Id, Title = 'test');
		tmpIdeaList.add(tmpIdea);
		Idea tmpIdea2 = new Idea(CommunityId = currCommunity[0].Id, Title = 'test');
		tmpIdeaList.add(tmpIdea2);
		insert tmpIdeaList;
		System.assertNotEquals(null, tmpIdeaList[0].Id);
		System.assertNotEquals(null, tmpIdeaList[1].Id);
		IdeaComment tmpIdeaComment = new IdeaComment(CommentBody = 'test', IdeaId = tmpIdeaList[1].Id);
		insert tmpIdeaComment;
		System.assertNotEquals(null, tmpIdeaComment.Id);

		// Create Portal account user
		User user = x7sIdeasUtilityTest.createStandardTestUser();
	}

	@IsTest
	static void test_isAuthenticated() {
		System.assert(true, x7sIdeasListController.isAuthenticated());
	}

	@IsTest
	static void test_isNicknameDisplayEnabled() {
		System.assertEquals(true, x7sIdeasListController.isNicknameDisplayEnabled());
	}

	@IsTest
	static void test_getUserId() {
		System.assertEquals(UserInfo.getUserId(), x7sIdeasListController.getUserId());
	}

	@IsTest
	static void test_getSitePrefix() {
		System.assertEquals('', x7sIdeasListController.getSitePrefix());
	}

	@IsTest
	static void test_getIdeasAttributeCount() {
		x7sIdeasListControllerTest.testSetupQuery();
		Integer countAttr = x7sIdeasListController.getIdeasAttributeCount(x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Voted On Ideas', UserInfo.getUserId() + '');
		System.assertEquals(0, countAttr);
		countAttr = x7sIdeasListController.getIdeasAttributeCount(x7sIdeasListControllerTest.currCommunity[0].Id + '', 'My Ideas', UserInfo.getUserId() + '');
		System.assert(countAttr == 2);
	}

	@IsTest
	static void test_getZoneId() {
		x7sIdeasListControllerTest.testSetupQuery();
		System.assertNotEquals('', x7sIdeasListController.getZoneId(x7sIdeasListControllerTest.currCommunity[0].Name));
		System.assertEquals('', x7sIdeasListController.getZoneId('______'));
		System.assertEquals('', x7sIdeasListController.getZoneId(''));
	}

	@IsTest
	static void test_getIdeas() {
		x7sIdeasListControllerTest.testSetupQuery();

		Test.startTest();
		x7sIdeasListWrapper ilw = x7sIdeasListController.getIdeas();
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 2);

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 1);

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Recent', false, false, null, false, null, false, true, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Top All-Time', false, false, null, false, null, true, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 1);

		Test.stopTest();
	}

	@IsTest
	static void test_getIdeasWithOptions() {
		x7sIdeasListControllerTest.testSetupQuery();
		Test.startTest();

		x7sIdeasListWrapper ilw = x7sIdeasListController.getIdeas();

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, true, '________________', false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 0);

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Recent Comments', false, false, null, true, '', false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 0);

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Recent Comments', true, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 1);

		ilw = x7sIdeasListController.getIdeas(1, '_____,------', x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 0);

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, true, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);

		ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, true, false, false, false, false, false, 'None','');
		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);

		Test.stopTest();
	}

	@IsTest
	static void test_getIdeasAsPortalUser() {
		x7sIdeasListControllerTest.testSetupQuery();
		Test.startTest();

		x7sIdeasListWrapper ilw = x7sIdeasListController.getIdeas();

		// Get Portal User
		List<User> usrL = [SELECT Id, Name FROM User WHERE LastName = 'x7s_LastName'];
		if (!usrL.isEmpty()) {
			System.runAs(usrL[0]) {
				ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, true, false, false, false, 'None','');
				System.assertNotEquals(null, ilw);
				System.assertNotEquals(null, ilw.ideaList);
				System.assert(ilw.ideaList.size() == 0);

				ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, true, false, false, 'None','');
				System.assertNotEquals(null, ilw);
				System.assertNotEquals(null, ilw.ideaList);
				System.assert(ilw.ideaList.size() == 0);

				ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, true, false, 'None','');
				System.assertNotEquals(null, ilw);
				System.assertNotEquals(null, ilw.ideaList);
				System.assert(ilw.ideaList.size() == 0);

				ilw = x7sIdeasListController.getIdeas(1, null, x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular', false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, true, 'Featured Flag','');
				System.assertNotEquals(null, ilw);
				System.assertNotEquals(null, ilw.ideaList);
				System.assert(ilw.ideaList.size() == 0);

			}
		}
		Test.stopTest();
	}

	@IsTest
	static void test_nextPage() {
		x7sIdeasListControllerTest.testSetupQuery();
		x7sIdeasListWrapper ilw = x7sIdeasListController.nextPage(1, 1, null,
			x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular',
			false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertEquals(2, ilw.pageNumber);
	}

	@IsTest
	static void test_previousPage() {
		x7sIdeasListControllerTest.testSetupQuery();
		x7sIdeasListWrapper ilw = x7sIdeasListController.nextPage(1, 1, null,
			x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular',
			false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertEquals(2, ilw.pageNumber);
		ilw = x7sIdeasListController.previousPage(1, 2, null,
			x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular',
			false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertEquals(1, ilw.pageNumber);
	}

	@IsTest
	static void test_getPage() {
		x7sIdeasListControllerTest.testSetupQuery();
		x7sIdeasListWrapper ilw = x7sIdeasListController.getPage(1, 1, null,
			x7sIdeasListControllerTest.currCommunity[0].Id + '', 'Popular',
			false, false, null, false, null, false, false, '', '', '', '', '', false, false, false, false, false, false, false, false, 'None','');
		System.assertEquals(1, ilw.pageNumber);
	}

	@IsTest
	static void test_submitVote() {
		x7sIdeasListControllerTest.testSetupQuery();
		User u = [SELECT Id, Name FROM User WHERE LastName = :x7sIdeasUtilityTest.TEST_USER_LASTNAME LIMIT 1];

		System.runAs(u) {
			x7sIdeasListWrapper afterVoteIdea = x7sIdeasListController.submitVote(x7sIdeasListControllerTest.currIdea.Id + '', 'Down');
			System.assertEquals(0, afterVoteIdea.ideaList[0].VoteTotal);
		}

		x7sIdeasListWrapper afterVoteIdea = x7sIdeasListController.submitVote(x7sIdeasListControllerTest.currIdea.Id + '', 'Up');
		System.assertEquals(null, afterVoteIdea);
	}

	@IsTest
	static void test_getPicklistValues() {
		System.assertNotEquals(null, x7sIdeasUtility.getIdeaCategoryValues());
	}

	@IsTest
	static void test_getCommonSettings() {
		x7sIdeasCommon common = x7sIdeasListController.getCommonSettings('');

		// custom settings
		System.assertNotEquals(null, common);
	}

	@IsTest
	static void test_getNameSpacePrefix() {
		x7sIdeasBaseController controller = new x7sIdeasBaseController();
		System.assertNotEquals(null, controller);

		x7sIdeasBaseController.BaseModel model = x7sIdeasBaseController.getModel();
		System.assertNotEquals(null, model);
		System.assertNotEquals(null, model.lexMode);
	}

	@IsTest
	static void test_parseStringList() {
		String testString = 'Topic 1, Topic 2, Topic 3';
		List<String> stringList = x7sIdeasListController.parseStringToList(testString);
		System.assertEquals(3, stringList.size());
	}

	@IsTest
	static void test_buildInQuery() {
		String testString = 'Topic 1, Topic 2, Topic 3';
		List<String> stringList = x7sIdeasListController.parseStringToList(testString);

		String inQuery = x7sIdeasListController.buildInQuery(stringList, 'Related_Topic_Name__c');
		System.debug('Topic query: ' + inQuery);
		System.assertNotEquals(null, inQuery);

		String themeString = 'Theme 1, Theme 2';
		List<String> themeList = x7sIdeasListController.parseStringToList(themeString);
		String themeQuery = x7sIdeasListController.buildInQuery(themeList, 'IdeaTheme.title');
		System.debug('Theme query: ' + themeQuery);
		System.assertNotEquals(null, themeQuery);
	}

	@IsTest
	static void testGetTopicName() {
		List<Topic> topicList = createTestTopics('Topic-1,Topic 2,Sub Topic QA1 - Child');
		System.assertEquals('Sub Topic QA1 - Child', x7sIdeasListController.getTopicNameFromId(topicList[2].Id));
	}

	static List<Topic> createTestTopics(String topicNames) {
		List<String> topicNameList = topicNames.split(',');
		List<Topic>  topicList = new List<Topic>();
		for (String topicName : topicNameList) {
			topicList.add(new Topic(Name=topicName));
		}
		insert topicList;

		return topicList;
	}

    @IsTest
	static void testGetFieldset() {
		String fieldSetName = x7sIdeasListController.getFieldSetName();
		System.assertNotEquals(null, fieldSetName, 'List expected');
	}

    @IsTest
    static void test_getRecordName(){
        List<SObject> nameOfRecord = x7sIdeasListController.getCustomLookupDisplayName(UserInfo.getUserId());
        System.assertNotEquals(null,nameOfRecord , 'Record name should not be null');
    }

	@IsTest static void test_CMTPicklist() {
		x7sIdeasCMTPicklist cmtPicklistClass = new x7sIdeasCMTPicklist();

		System.assertNotEquals(null, cmtPicklistClass.getDefaultValue(), 'Incorrect CMT Picklist default value.');
		System.assertEquals(true, cmtPicklistClass.getValues().size() > 0, 'There must be picklist values.');
	}
}