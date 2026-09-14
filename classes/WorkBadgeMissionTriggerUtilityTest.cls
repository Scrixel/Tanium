/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Test class for WorkBadgeMissionTriggerUtility.
 * RequestId  ModifiedDate  Comment
 * SS-8303    2024-12-05    Created the class
 */
@IsTest
private class WorkBadgeMissionTriggerUtilityTest {
	private static User communityPortalUser;

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
		Id communityNetworkId = Utility.getNetworkId('Tanium Customer Community');
		Account account;
		Contact contact;
		FeedItem feedItemQuestion1;
		FeedItem feedItemQuestion2;
		FeedComment feedCommentAnswer1;
		Idea idea;
		IdeaComment ideaComment;

		System.runAs(TestUserFactory.getAdminUser()) {
			account = TestFactory.buildAccount('Test Account');
			insert account;

			contact = TestFactory.buildContact(account.Id);
			contact.Email = 'some.communityportaluser@somecorp.io.apextest';
			contact.FirstName = 'Some';
			contact.LastName = 'CommunityPortalUser';
			insert contact;

			WorkBadgeDefinition workBadgeDefinition = new WorkBadgeDefinition();
			workBadgeDefinition.Name = 'Thanks';
			workBadgeDefinition.Description = 'Thanks';
			workBadgeDefinition.IsActive = true;
			workBadgeDefinition.ImageUrl =
				URL.getOrgDomainURL().toExternalForm() + '/img/rypple/Thanks.png';
			insert workBadgeDefinition;

			WorkBadgeMission__c workBadgeMission = new WorkBadgeMission__c();
			workBadgeMission.Name = 'Ask a question x 1';
			workBadgeMission.Badge_Name__c = 'Thanks';
			workBadgeMission.IsActive__c = true;
			workBadgeMission.Action__c = 'Ask a question';
			workBadgeMission.Threshold__c = 1;
			workBadgeMission.Message__c = 'Great job asking your first question!';
			insert workBadgeMission;
			update workBadgeMission;
		}

		communityPortalUser = getCommunityPortalUser(contact.Id);
		System.runAs(communityPortalUser) {
			feedItemQuestion1 = new FeedItem(
				ParentId = communityPortalUser.Id,
				Body = 'I have a question',
				Visibility = 'AllUsers',
				IsRichText = true,
				Title = 'Question1',
				Type = 'QuestionPost',
				NetworkScope = communityNetworkId
			);
			feedItemQuestion2 = new FeedItem(
				ParentId = communityPortalUser.Id,
				Body = 'I have another question',
				Visibility = 'AllUsers',
				IsRichText = true,
				Title = 'Question2',
				Type = 'QuestionPost',
				NetworkScope = communityNetworkId
			);
			insert new List<FeedItem>{ feedItemQuestion1, feedItemQuestion2 };

			feedCommentAnswer1 = new FeedComment(
				FeedItemId = feedItemQuestion1.Id,
				CommentBody = 'I have an answer',
				CommentType = 'TextComment',
				Status = 'Published'
			);
			insert feedCommentAnswer1;

			idea = new Idea(
				Title = 'Title',
				Body = 'SomeIdea',
				Categories = 'Improve Efficiency',
				CommunityId = Constants.COMMUNITY_PLAYBOOK_IDEAS_ID
			);
			insert idea;

			ideaComment = new IdeaComment(IdeaId = idea.Id, CommentBody = 'SomeIdeComment');
			insert ideaComment;
		}
	}

	@IsTest
	static void testValidateActiveBadge_WhenNoExistingBadge_ThrowBadgeNotFoundError() {
		String errorMessage;
		WorkBadgeMission__c[] workBadgeMissions = [
			SELECT Id, Badge_Name__c
			FROM WorkBadgeMission__c
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			workBadgeMissions[0].Badge_Name__c = 'Thanks1';
			try {
				update workBadgeMissions;
			} catch (Exception e) {
				errorMessage = e.getMessage();
			}
			Test.stopTest();
		}
		Assert.isTrue(errorMessage.contains('Unable to find an existing badge with name'));
	}

	@IsTest
	static void testValidateActiveBadge_WhenExistingBadgeIsInactive_ThrowInactiveBadgeError() {
		String errorMessage;
		WorkBadgeDefinition[] badges = [
			SELECT Id, Name, IsActive
			FROM WorkBadgeDefinition
		];
		WorkBadgeMission__c[] workBadgeMissions = [
			SELECT Id, Badge_Name__c
			FROM WorkBadgeMission__c
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			badges[0].IsActive = false;
			try {
				update badges;
				update workBadgeMissions;
			} catch (Exception e) {
				errorMessage = e.getMessage();
			}
			Test.stopTest();
		}
		Assert.isTrue(errorMessage.contains('is not Active'));
	}

	@IsTest
	static void testSetSourceId_WhenBadgeDefinitionIsCreated_SourceIdIsPopulated() {
		WorkBadgeDefinition workBadgeDefinition;
		WorkBadgeMission__c workBadgeMission;

		System.runAs(TestUserFactory.getAdminUser()) {
			workBadgeDefinition = [
				SELECT Id
				FROM WorkBadgeDefinition
				WHERE Name = 'Thanks'
			];
			workBadgeMission = [
				SELECT Id, SourceId__c
				FROM WorkBadgeMission__c
				WHERE Badge_Name__c = 'Thanks'
			];
		}

		Assert.areEqual(workBadgeDefinition.Id, workBadgeMission.SourceId__c);
	}

	@IsTest
	static void testProcessEvent_WhenPostingCommunityQuestion_AssignBadge() {
		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;
		FeedItem[] feedItemQuestions = [SELECT Id, Type, InsertedById, Body FROM FeedItem];
		Set<Id> insertedByIds = new Set<Id>();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			for (FeedItem feedItemQuestion : feedItemQuestions) {
				workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
				workBadgeMissionEvent.InsertedById__c = feedItemQuestion.InsertedById;
				workBadgeMissionEvent.FeedItemId__c = feedItemQuestion.Id;
				workBadgeMissionEvent.Type__c = feedItemQuestion.Type;
				workBadgeMissionEvents.add(workBadgeMissionEvent);
				insertedByIds.add(feedItemQuestion.InsertedById);
			}
			WorkBadgeMissionTriggerUtility.processEvent(workBadgeMissionEvents);
			Test.stopTest();

			WorkBadge[] assignedBadges = [
				SELECT Id
				FROM WorkBadge
				WHERE
					RecipientId IN :insertedByIds
					AND NetworkId = :WorkBadgeMissionTriggerUtility.CUSTOMER_COMMUNITY_ID
			];
			Assert.isFalse(assignedBadges.isEmpty());
		}
	}

	@IsTest
	static void testProcessEvent_WhenCommunityAnswerWitNoLinkedBadge_DoNotAssignBadge() {
		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;
		FeedComment[] feedCommentAnswers = [
			SELECT Id, FeedItemId, CommentType, InsertedById
			FROM FeedComment
		];
		Set<Id> insertedByIds = new Set<Id>();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			for (FeedComment feedCommentAnswer : feedCommentAnswers) {
				workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
				workBadgeMissionEvent.InsertedById__c = feedCommentAnswer.InsertedById;
				workBadgeMissionEvent.FeedItemId__c = feedCommentAnswer.FeedItemId;
				workBadgeMissionEvent.FeedCommentId__c = feedCommentAnswer.Id;
				workBadgeMissionEvent.Type__c = feedCommentAnswer.CommentType;
				workBadgeMissionEvents.add(workBadgeMissionEvent);
				insertedByIds.add(feedCommentAnswer.InsertedById);
			}
			WorkBadgeMissionTriggerUtility.processEvent(workBadgeMissionEvents);
			Test.stopTest();
		}

		WorkBadge[] assignedBadges = [
			SELECT Id
			FROM WorkBadge
			WHERE
				RecipientId IN :insertedByIds
				AND NetworkId = :WorkBadgeMissionTriggerUtility.CUSTOMER_COMMUNITY_ID
		];
		Assert.isTrue(assignedBadges.isEmpty());
	}

	@IsTest
	static void testProcessEvent_WhenCommunityIdeaWitNoLinkedBadge_DoNotAssignBadge() {
		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;
		Idea[] ideas = [
			SELECT Id, CreatedById
			FROM Idea
			WHERE CommunityId = :Constants.COMMUNITY_PLAYBOOK_IDEAS_ID
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			for (Idea idea : ideas) {
				workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
				workBadgeMissionEvent.InsertedById__c = idea.CreatedById;
				workBadgeMissionEvent.IdeaId__c = idea.Id;
				workBadgeMissionEvent.Type__c = 'IdeaPost';
				workBadgeMissionEvents.add(workBadgeMissionEvent);
			}
			WorkBadgeMissionTriggerUtility.processEvent(workBadgeMissionEvents);
			Test.stopTest();
		}
		WorkBadge[] assignedBadges = [
			SELECT Id
			FROM WorkBadge
			WHERE
				RecipientId = :ideas[0].CreatedById
				AND NetworkId = :WorkBadgeMissionTriggerUtility.CUSTOMER_COMMUNITY_ID
		];
		Assert.isTrue(assignedBadges.isEmpty());
	}

	@IsTest
	static void testProcessEvent_WhenCommunityIdeaCommentWitNoLinkedBadge_DoNotAssignBadge() {
		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;
		IdeaComment[] ideaComments = [
			SELECT Id, IdeaId, CreatedById
			FROM IdeaComment
			WHERE CommunityId = :Constants.COMMUNITY_PLAYBOOK_IDEAS_ID
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			for (IdeaComment ideaComment : ideaComments) {
				workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
				workBadgeMissionEvent.InsertedById__c = ideaComment.CreatedById;
				workBadgeMissionEvent.IdeaId__c = ideaComment.IdeaId;
				workBadgeMissionEvent.IdeaCommentId__c = ideaComment.Id;
				workBadgeMissionEvent.Type__c = 'IdeaComment';
				workBadgeMissionEvents.add(workBadgeMissionEvent);
			}
			WorkBadgeMissionTriggerUtility.processEvent(workBadgeMissionEvents);
			Test.stopTest();

			WorkBadge[] assignedBadges = [
				SELECT Id
				FROM WorkBadge
				WHERE
					RecipientId = :ideaComments[0].CreatedById
					AND NetworkId = :WorkBadgeMissionTriggerUtility.CUSTOMER_COMMUNITY_ID
			];
			Assert.isTrue(assignedBadges.isEmpty());
		}
	}

	static User getCommunityPortalUser(Id contactId) {
		User[] communityPortalUsers = [
			SELECT Id
			FROM User
			WHERE Email = 'some.communityportaluser@somecorp.io.apextest'
		];
		User communityPortalUser;
		if (communityPortalUsers.isEmpty()) {
			communityPortalUser = TestUserFactory.createUser(
				'CommunityPortalUser',
				'some.communityportaluser@somecorp.io.apextest',
				'sc12345',
				Utility.getProfileId('Tanium Community Login Authenticated Case'),
				null
			);
			communityPortalUser.ContactId = contactId;
			insert communityPortalUser;
			return communityPortalUser;
		}
		return communityPortalUsers[0];
	}
}