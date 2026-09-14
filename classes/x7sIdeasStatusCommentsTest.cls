/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasStatusCommentsTest {
	public static Network currNetwork;
	public static List<Community> currCommunity;
	public static Idea currIdea;

	static void testSetupQuery() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdea = [SELECT Id FROM Idea WHERE Title = 'test' ORDER BY CreatedDate DESC LIMIT 1];
	}

	@TestSetup
	static void testSetupData() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		System.assertNotEquals(null, currCommunity);
		System.assert(currCommunity.size() > 0);

		List<Idea> tmpIdeaList = new List<Idea>();
		tmpIdeaList.add(new Idea(CommunityId = currCommunity[0].Id, Title = 'test1'));
		tmpIdeaList.add(new Idea(CommunityId = currCommunity[0].Id, Title = 'test2'));
		insert tmpIdeaList;

		System.assertNotEquals(null, tmpIdeaList[0].Id);
		System.assertNotEquals(null, tmpIdeaList[1].Id);
	}

	@IsTest
	static void testInsertIdeaComments() {
		//test summary and comments is null currently for idea
		Idea idea = [SELECT Id,Status_Comment__c,Status FROM Idea LIMIT 1];
		List<x7sIdeasCommentsWrapper.CommentsModel> comments = x7sIdeasStatusComments.getComments(idea.Id);
		System.assertEquals(true, comments.isEmpty(), 'Comments for idea should be empty');

		//change status and comments for idea
		idea.Status = 'In Review';
		idea.Status_Comment__c = 'Testing comments from test class';
		update idea;

		comments = x7sIdeasStatusComments.getComments(idea.Id);
		System.debug('testInsertIdeaComments: ' + comments);
		System.assert(comments != null);

	}

	@IsTest
	static void testWrapperClass() {
		//nothing to cover here. just initialize the wrapper class.
		x7sIdeasCommentsWrapper.CommentsModel wrapper = new x7sIdeasCommentsWrapper.CommentsModel();
		wrapper.changedBy = 'test';
		wrapper.changedById = 'test';
		wrapper.changedDate = System.today();
		wrapper.commentText = 'test';
		wrapper.newStatus = 'test';

		System.assertEquals(System.today(), wrapper.changedDate);
	}

	@IsTest
	static void testGetSitePrefix() {
		System.assertNotEquals(null, x7sIdeasStatusComments.getSitePrefix());
	}
}