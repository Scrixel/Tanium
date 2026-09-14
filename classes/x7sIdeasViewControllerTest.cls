/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasViewControllerTest {
	public static Network currNetwork;
	public static List<Community> currCommunity;
	public static List<Idea> currIdeaList;

	private static final String TestIdeaName = 'X7S_test__1';

	static void testSetupQuery() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdeaList = [SELECT Id FROM Idea WHERE Title = 'X7S_test__1' ORDER BY CreatedDate DESC];
	}

	@TestSetup
	static void testSetupData() {
		x7sIdeasViewControllerTest.testSetupQuery();
		System.assertNotEquals(null, x7sIdeasViewControllerTest.currCommunity);
		System.assert(x7sIdeasViewControllerTest.currCommunity.size() > 0);

		Idea currIdea1 = new Idea(
			CommunityId = currCommunity[0].Id,
			Title = TestIdeaName,
			Related_Topic_Name__c = 'X7S_test__1'
		);
		Idea currIdea2 = new Idea(
			CommunityId = currCommunity[0].Id,
			Title = TestIdeaName,
			Related_Topic_Name__c = 'X7S_test__1'
		);

		List<Idea> tmpIdeaList = new List<Idea>();
		tmpIdeaList.add(currIdea1);
		tmpIdeaList.add(currIdea2);

		insert tmpIdeaList;
		System.assertNotEquals(null, tmpIdeaList[0].Id);
		System.assertNotEquals(null, tmpIdeaList[1].Id);
	}

	@IsTest
	static void test_isAuthenticated() {
		System.assert(true, x7sIdeasViewController.isAuthenticated());
	}

	@IsTest
	static void test_isNicknameDisplayEnabled() {
		System.assertNotEquals(null, x7sIdeasViewController.isNicknameDisplayEnabled());
	}

	@IsTest
	static void test_getIdea() {
		x7sIdeasViewControllerTest.testSetupQuery();
		x7sIdeasListWrapper wrapper = x7sIdeasViewController.getIdeaRecord(
			x7sIdeasViewControllerTest.currCommunity[0].Id,
			x7sIdeasViewControllerTest.currIdeaList[0].Id,
			''
		);
		Idea tempIdea = wrapper.ideaList[0];
		System.assertEquals(tempIdea.Id, x7sIdeasViewControllerTest.currIdeaList[0].Id);

		Boolean canDelete = x7sIdeasViewController.isRecordDeletable(tempIdea.Id + '');
		System.assertNotEquals(null, canDelete);

		Boolean canEdit = x7sIdeasViewController.isRecordEditable(tempIdea.Id + '');
		System.assertNotEquals(null, canEdit);
	}

	@IsTest
	static void test_getMergedIdeas() {
		x7sIdeasViewControllerTest.testSetupQuery();
		List<Idea> mergedIdeas = x7sIdeasViewController.getMergedIdeas(
			x7sIdeasViewControllerTest.currIdeaList[0].Id,
			x7sIdeasViewControllerTest.currCommunity[0].Id
		);
		System.assertNotEquals(null, mergedIdeas);
	}

	@IsTest
	static void test_getIdeaTitle() {
		x7sIdeasViewControllerTest.testSetupQuery();
		x7sIdeasListWrapper wrapper = x7sIdeasViewController.getIdeaRecord(
			x7sIdeasViewControllerTest.currCommunity[0].Id,
			x7sIdeasViewControllerTest.currIdeaList[0].Id,
			''
		);
		Idea tempIdea = wrapper.ideaList[0];
		System.assertEquals(tempIdea.Id, x7sIdeasViewControllerTest.currIdeaList[0].Id);
		System.assertEquals(tempIdea.Id, x7sIdeasViewControllerTest.currIdeaList[0].Id);
	}

	@IsTest
	static void test_deleteIdea() {
		x7sIdeasViewControllerTest.testSetupQuery();
		x7sIdeasListWrapper wrapper = x7sIdeasViewController.getIdeaRecord(
			x7sIdeasViewControllerTest.currCommunity[0].Id,
			x7sIdeasViewControllerTest.currIdeaList[0].Id,
			''
		);
		Idea tempIdea = wrapper.ideaList[0];
		Id currIdeaId = tempIdea.Id;
		Boolean canDelete = x7sIdeasViewController.isRecordDeletable(currIdeaId + '');
		System.assertNotEquals(null, canDelete);
		System.assertEquals(true, x7sIdeasViewController.deleteIdea(currIdeaId + ''));
		System.assertEquals(false, x7sIdeasViewController.deleteIdea(currIdeaId + ''));
	}

	@IsTest
	static void test_vote() {
		x7sIdeasViewControllerTest.testSetupQuery();
		User u = x7sIdeasUtilityTest.createStandardTestUser();

		Test.startTest();
		System.runAs(u) {
			Vote v = x7sIdeasViewController.vote(x7sIdeasViewControllerTest.currIdeaList[0].Id, true);
			System.assertNotEquals(null, v.Id);

			Boolean authorized = x7sIdeasViewController.userAuthorizedChatter();
			System.assertNotEquals(null, authorized);

			Vote deletedVote = x7sIdeasViewController.deleteVote(
				x7sIdeasViewControllerTest.currIdeaList[0].Id
			);
			System.assertEquals(null, deletedVote);
		}

		Vote v = x7sIdeasViewController.vote(x7sIdeasViewControllerTest.currIdeaList[0].Id, true);
		System.assertEquals(null, v);

		v = x7sIdeasViewController.vote(null, true);
		System.assertEquals(null, v);

		Test.stopTest();
	}

	@IsTest
	static void test_getVote() {
		x7sIdeasViewControllerTest.testSetupQuery();
		Vote v = x7sIdeasViewController.getVote(x7sIdeasViewControllerTest.currIdeaList[0].Id);
		System.assertEquals(x7sIdeasViewControllerTest.currIdeaList[0].Id, v.ParentId);
		System.assertEquals(UserInfo.getUserId(), v.CreatedById);
		System.assertEquals('Up', v.Type);

		Id tmpId = x7sIdeasViewControllerTest.currIdeaList[0].Id;
		delete x7sIdeasViewControllerTest.currIdeaList[0];
		v = x7sIdeasViewController.getVote(tmpId);
		System.assertEquals(null, v.CreatedById);
	}

	@IsTest
	static void test_getCommonSettings() {
		x7sIdeasCommon common = x7sIdeasViewController.getCommonSettings('', false, '');

		// custom settings
		System.assertNotEquals(null, common);
		System.assertNotEquals(null, common.allowDownVoting);
		System.assertNotEquals(null, common.debugMode);
	}

	@IsTest
	static void test_getTopicList() {
		Topic t = new Topic(Name = TestIdeaName);
		insert t;

		List<Topic> topicList = x7sIdeasViewController.getTopicNamesList(false);
		Boolean containsValue = false;

		for (Topic s : topicList) {
			if (s.Name == TestIdeaName) {
				containsValue = true;
			}
		}
		System.assertEquals(true, containsValue);
	}

	@IsTest
	static void test_getTopicMap() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];

		Topic t = new Topic(Name = TestIdeaName);
		insert t;

		Idea currIdea = new Idea(
			CommunityId = currCommunity[0].Id,
			Title = TestIdeaName,
			Related_Topic_Name__c = 'X7S_test__1'
		);
		insert currIdea;

		Map<String, String> topicMap = x7sIdeasViewController.getTopicMap('X7S_test__1');
		System.assertEquals(true, topicMap.containsKey('X7S_test__1'));
	}

	@IsTest
	static void test_getVotingLimitsForAccount() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];

		// Create Portal User
		User newUser = x7sIdeasUtilityTest.createPortalTestUser();

		// Create Idea
		Topic t = new Topic(Name = TestIdeaName);
		insert t;

		Idea currIdea = new Idea(
			CommunityId = currCommunity[0].Id,
			Title = TestIdeaName,
			Related_Topic_Name__c = TestIdeaName
		);
		insert currIdea;

		Vote vtSU = x7sIdeasViewController.vote(currIdea.Id, true);

		System.runAs(newUser) {
			Vote vt = x7sIdeasViewController.vote(currIdea.Id, true);
			x7sIdeasViewController.VotingDetails votingDetails = x7sIdeasViewController.getVotingLimitsForAccount(
				currIdea.Id
			);

			System.assertNotEquals(null, votingDetails.totalVotes);
		}
	}

	@IsTest
	static void testGetIdeaStatusValues() {
		System.assertNotEquals(null, x7sIdeasViewController.getIdeaStatusValues('x7sTestZone'));
	}

	@IsTest
	static void testFollowIdea() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		Idea currIdea = new Idea(
			CommunityId = currCommunity[0].Id,
			Title = TestIdeaName,
			Related_Topic_Name__c = TestIdeaName
		);
		insert currIdea;

		System.assertEquals(true, x7sIdeasViewController.followIdea(currIdea.Id));
		System.assertEquals(true, x7sIdeasViewController.isFollowingIdea(currIdea.Id));
		System.assertEquals(true, x7sIdeasViewController.unFollowIdea(currIdea.Id));
		System.assertEquals(false, x7sIdeasViewController.isFollowingIdea(currIdea.Id));
	}
}