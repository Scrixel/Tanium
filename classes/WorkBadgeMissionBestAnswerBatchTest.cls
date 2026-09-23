/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Test class for WorkBadgeMissionBestAnswerBatch
 * RequestId  ModifiedDate  Comment
 * SS-8303    2025-02-25    Created the test class
 */
@IsTest(SeeAllData=true)
private class WorkBadgeMissionBestAnswerBatchTest {
	@IsTest(SeeAllData=true)
	static void testProcessBestAnswers_WhenBestAnswerComment_AssignBadge() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'UserTriggerHandler' });
		Id communityNetworkId = Utility.getNetworkId('Tanium Customer Community');
		Account account;
		Contact contact;
		User communityPortalUser;
		FeedItem feedItemQuestion;
		FeedComment feedCommentAnswer;
		ChatterActivity chatterActivity;

		System.runAs(TestUserFactory.getAdminUser()) {
			account = getAccount();
			contact = getContact(account.Id);
			communityPortalUser = getCommunityPortalUser(contact.Id);

			WorkBadgeDefinition bestAnswerBadgeX1 = getWorkBadgeDefinition(
				'Best Answer x1',
				'You had an answer chosen as best!',
				communityNetworkId
			);
			WorkBadgeMission__c bestAnswerBadgeMissionX1 = getWorkBadgeMission(
				bestAnswerBadgeX1,
				'Best Answer',
				1
			);
		}

		System.runAs(communityPortalUser) {
			feedItemQuestion = new FeedItem(
				ParentId = communityPortalUser.Id,
				Body = 'I have a question',
				Visibility = 'AllUsers',
				IsRichText = true,
				Title = 'Question1',
				Type = 'QuestionPost',
				NetworkScope = communityNetworkId
			);
			insert feedItemQuestion;

			feedCommentAnswer = new FeedComment(
				FeedItemId = feedItemQuestion.Id,
				CommentBody = 'I have an answer',
				CommentType = 'TextComment',
				Status = 'Published'
			);
			insert feedCommentAnswer;

			ConnectApi.QuestionAndAnswersCapabilityInput qaInput = new ConnectApi.QuestionAndAnswersCapabilityInput();
			qaInput.bestAnswerId = feedCommentAnswer.Id;

			ConnectApi.QuestionAndAnswersCapability qa = ConnectApi.QuestionAndAnswers.updateQuestionAndAnswers(
				communityNetworkId,
				feedItemQuestion.Id,
				qaInput
			);

			FeedItem[] feedItems = [
				SELECT Id, BestCommentId
				FROM FeedItem
				WHERE Id = :feedItemQuestion.Id
			];

			Utility.sleep(3);

			Test.startTest();
			WorkBadgeMissionBestAnswerBatch batch = new WorkBadgeMissionBestAnswerBatch();
			batch.processBestAnswers(new Set<Id>{ communityPortalUser.Id });
			Test.stopTest();
		}

		WorkBadge[] assignedBadges = [
			SELECT Id
			FROM WorkBadge
			WHERE RecipientId = :communityPortalUser.Id
		];
		Assert.isFalse(assignedBadges.isEmpty());
	}

	@IsTest(SeeAllData=true)
	static void testExecute_WhenSubmittingBatch_InsertJobRecord() {
		WorkBadgeMissionBestAnswerBatch batch;
		Id jobId;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			batch = new WorkBadgeMissionBestAnswerBatch();
			batch.execute(null);
			jobId = Database.executeBatch(batch, 1);
			Test.stopTest();
		}

		AsyncApexJob[] jobs = [SELECT Id FROM AsyncApexJob WHERE Id = :jobId];
		Assert.isFalse(jobs.isEmpty());
	}

	static Account getAccount() {
		Account[] accounts = [SELECT Id FROM Account WHERE Name = 'Test Account-SS-8303'];
		if (accounts.isEmpty()) {
			accounts.add(TestFactory.buildAccount('Test Account-SS-8303'));
			insert accounts;
		}
		return accounts[0];
	}

	static Contact getContact(Id accountId) {
		Contact[] contacts = [
			SELECT Id
			FROM Contact
			WHERE Email = 'portal.user@customercorp.io.apextest.SS-8303'
		];
		if (contacts.isEmpty()) {
			contacts.add(TestFactory.buildContact(accountId));
			contacts[0].Email = 'portal.user@customercorp.io.apextest.SS-8303';
			contacts[0].FirstName = 'Portal';
			contacts[0].LastName = 'User';
			insert contacts;
		}
		return contacts[0];
	}

	static User getCommunityPortalUser(Id contactId) {
		User[] communityPortalUsers = [
			SELECT Id
			FROM User
			WHERE Email = 'portal.user@customercorp.io.apextest.SS-8303'
		];
		User communityPortalUser;
		if (communityPortalUsers.isEmpty()) {
			communityPortalUser = TestUserFactory.createUser(
				'CommunityPortalUser',
				'portal.user@customercorp.io.apextest.SS-8303',
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

	static WorkBadgeDefinition getWorkBadgeDefinition(
		String badgeName,
		String badgeDescription,
		Id communityNetworkId
	) {
		WorkBadgeDefinition[] workBagdes = [
			SELECT Id, Name, Description, ImageUrl, IsActive, NetworkId
			FROM WorkBadgeDefinition
			WHERE Name = :badgeName
		];

		if (workBagdes.isEmpty()) {
			workBagdes.add(
				new WorkBadgeDefinition(
					Name = badgeName,
					Description = badgeDescription,
					IsActive = true,
					NetworkId = communityNetworkId,
					ImageUrl = URL.getOrgDomainURL().toExternalForm() + '/img/rypple/Thanks.png'
				)
			);
			insert workBagdes;
		}

		return workBagdes[0];
	}

	static WorkBadgeMission__c getWorkBadgeMission(
		WorkBadgeDefinition workBadge,
		String action,
		Integer threshold
	) {
		WorkBadgeMission__c[] workBagdeMissions = [
			SELECT Id, Name, Badge_Name__c, Message__c, Action__c, Threshold__c, IsActive__c
			FROM WorkBadgeMission__c
			WHERE Badge_Name__c = :workBadge.Name
		];

		if (workBagdeMissions.isEmpty()) {
			workBagdeMissions.add(
				new WorkBadgeMission__c(
					Name = workBadge.Name,
					Badge_Name__c = workBadge.Name,
					IsActive__c = true,
					Action__c = action,
					Threshold__c = threshold,
					Message__c = workBadge.Description
				)
			);
			insert workBagdeMissions;
		}

		return workBagdeMissions[0];
	}
}