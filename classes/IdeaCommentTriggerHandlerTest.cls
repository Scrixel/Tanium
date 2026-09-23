/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Test class for IdeaCommentTriggerHandler
 * RequestId  ModifiedDate  Comment
 * SS-8303    2025-01-14    Created the class
 */
@IsTest
private class IdeaCommentTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Idea idea = new Idea(
				Title = 'Title',
				Body = 'SomeIdea',
				Categories = 'Improve Efficiency',
				CommunityId = Constants.COMMUNITY_PLAYBOOK_IDEAS_ID
			);
			insert idea;

			IdeaComment ideaComment = new IdeaComment(CommentBody = 'SomeIdeaComment', IdeaId = idea.Id);
			insert ideaComment;
			update ideaComment;
		}
	}

	@IsTest
	static void testPublishWorkBadgeMissionEvent_WhenNewIdeaComment_PublishPlatformEvent() {
		Idea[] ideas = [
			SELECT Id, CreatedById
			FROM Idea
		];
		IdeaComment[] ideaComments = [
			SELECT Id, CreatedById, IdeaId
			FROM IdeaComment
			WHERE IdeaId = :ideas[0].Id
		];

		Test.startTest();
		IdeaCommentTriggerHandler.publishWorkBadgeMissionEvent(ideaComments);
		Test.stopTest();

		Integration_Callout__c[] callouts = [SELECT Id FROM Integration_Callout__c];
		Assert.isFalse(callouts.isEmpty());
	}
}