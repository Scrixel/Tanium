/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasCommentControllerTest {
	private static final String TEST_IDEA_NAME = 'test_dev_01';
	private static Network currNetwork;
	private static List<Community> currCommunity;
	private static Idea currIdea;
	private static IdeaComment currIdeaComment;

	@TestSetup
	static void testSetupData() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		System.assertNotEquals(null, currCommunity);
		System.assert(currCommunity.size() > 0);

		Idea tmpIdea = new Idea(CommunityId = currCommunity[0].Id, Title = TEST_IDEA_NAME);
		insert tmpIdea;
		System.assertNotEquals(null, tmpIdea.Id);

		IdeaComment tmpIdeaComment = new IdeaComment(CommentBody = TEST_IDEA_NAME, IdeaId = tmpIdea.Id);
		insert tmpIdeaComment;
		System.assertNotEquals(null, tmpIdeaComment.Id);
	}

	static void testSetupQuery() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdea = [SELECT Id FROM Idea WHERE Title = :TEST_IDEA_NAME ORDER BY CreatedDate DESC LIMIT 1];
		currIdeaComment = [SELECT Id FROM IdeaComment WHERE IdeaId = :currIdea.Id];
	}

	@IsTest
	static void test_commentVoting() {
		x7sIdeasCommentControllerTest.testSetupQuery();

		x7sIdeasCommentList commentsList = x7sIdeasCommentController.getComments(
			currCommunity[0].Name,
			currIdea.Id,
			1,
			1,
			'LatestComment');
		System.assertEquals(0, commentsList.statusCode);

		Map<String, Vote> voteMap = x7sIdeasCommentController.getCommentVotes(commentsList.commentIds);
		System.assertEquals(0, voteMap.values().size());

		Vote v = x7sIdeasCommentController.likeIdeaComment(commentsList.items[0].id);
		System.assertNotEquals(null, v.Id);

		voteMap = x7sIdeasCommentController.getCommentVotes(commentsList.commentIds);
		System.assertEquals(1, voteMap.values().size());

		System.assertEquals(true, x7sIdeasCommentController.unlikeIdeaComment(v.Id));

		voteMap = x7sIdeasCommentController.getCommentVotes(commentsList.commentIds);
		System.assertEquals(0, voteMap.values().size());
	}

	@IsTest
	static void test_badZone() {
		x7sIdeasCommentControllerTest.testSetupQuery();

		x7sIdeasCommentList commentsList = x7sIdeasCommentController.getComments(
			'Bad  Zone',
			currIdea.Id,
			1,
			1,
			'LatestComment');
		System.assertEquals(1, commentsList.statusCode);
	}

	@IsTest
	static void test_noComments() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		System.assertNotEquals(null, currCommunity);
		System.assert(currCommunity.size() > 0);

		Idea tmpIdea = new Idea(CommunityId = currCommunity[0].Id, Title = TEST_IDEA_NAME);
		insert tmpIdea;
		System.assertNotEquals(null, tmpIdea.Id);

		x7sIdeasCommentList commentsList = x7sIdeasCommentController.getComments(
			currCommunity[0].Name,
			tmpIdea.Id,
			1,
			1,
			'LatestComment');
		System.assertEquals(2, commentsList.statusCode);
	}

	@IsTest
	static void test_addComment() {
		x7sIdeasCommentControllerTest.testSetupQuery();

		IdeaComment tmpIdeaComment = x7sIdeasCommentController.addComment(currIdea.Id, 'test comment');
		System.assertNotEquals(null, tmpIdeaComment.Id);
	}

	@IsTest
	static void test_orderByClause() {
		String orderBy = x7sIdeasCommentController.getOrderByClause('OldestComment');
		System.debug('order by: ' + orderBy);
		System.assertEquals(' ORDER BY CreatedDate ASC', orderBy);

		orderBy = x7sIdeasCommentController.getOrderByClause('MostVotes');
		System.debug('order by: ' + orderBy);
		System.assertEquals(' ORDER BY UpVotes DESC', orderBy);

		orderBy = x7sIdeasCommentController.getOrderByClause('LeastVotes');
		System.debug('order by: ' + orderBy);
		System.assertEquals(' ORDER BY UpVotes ASC', orderBy);
	}

	@IsTest
	static void test_noZone() {
		System.assertEquals('', x7sIdeasCommentController.getZoneId(''));
	}

	@IsTest
	static void test_nickname() {
		System.assertEquals(false, x7sIdeasCommentController.nickNameEnabled());
	}

	@IsTest
	static void testGetCommonSettings() {
		x7sIdeasCommon settings = x7sIdeasCommentController.getCommonSettings('', false, '');
		System.assertNotEquals(null, settings);
	}
}