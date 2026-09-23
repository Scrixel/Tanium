/*
 * @DATE: 2024-10-16
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Test class for FeedCommentTriggerUtility
 * RequestId  ModifiedDate  Comment
 * SS-9451    2024-10-16    Initial Development
 * SS-8303    2024-12-05    Updated the test class
 */
@IsTest
private class FeedCommentTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
		Id supportCaseRecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
		Id communityNetworkId = Utility.getNetworkId('Tanium Customer Community');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			contact.Email = 'RoscoCaseProcesses@foo.com';
			contact.FirstName = 'RoscoCaseProcesse';
			contact.LastName = 'Foo';
			insert contact;

			Case supportCaseL1 = new Case(RecordTypeId = supportCaseRecordTypeId);
			supportCaseL1.Origin = 'Community';
			supportCaseL1.Severity_Community__c = '3';
			supportCaseL1.ContactId = contact.Id;
			supportCaseL1.AccountId = account.Id;
			supportCaseL1.Subject = 'Case Subject';
			supportCaseL1.Escalation_Tier__c = 'Level 1';
			supportCaseL1.Subject = 'TestCase';

			insert new List<Case>{ supportCaseL1 };

			User roscoUser = TestUserFactory.createUser(
				'Testing',
				'RoscoCaseProcesses@foo.com',
				'rcpfed',
				Utility.getProfileId('Tanium Community Login Authenticated Case'),
				null
			);
			roscoUser.ContactId = contact.Id;
			insert roscoUser;

			System.runAs(roscoUser) {
				FeedItem feedItem = new FeedItem(
					ParentId = supportCaseL1.Id,
					Body = 'ROSCOTESTCASE-Customer',
					Visibility = 'AllUsers',
					IsRichText = true,
					NetworkScope = 'AllNetworks'
				);
				FeedItem feedItemQuestion = new FeedItem(
					ParentId = roscoUser.Id,
					Body = 'I have a question',
					Visibility = 'AllUsers',
					IsRichText = true,
					Title = 'SomeTitle',
					Type = 'QuestionPost',
					NetworkScope = communityNetworkId
				);
				insert new List<FeedItem>{ feedItem, feedItemQuestion };

				FeedComment feedComment = new FeedComment(
					FeedItemId = feedItem.Id,
					CommentBody = 'ROSCOTESTCASE-Tanium',
					CommentType = 'TextComment',
					Status = 'Published'
				);
				FeedComment feedCommentAnswer = new FeedComment(
					FeedItemId = feedItemQuestion.Id,
					CommentBody = 'I have an answer',
					CommentType = 'TextComment',
					Status = 'Published'
				);
				insert new List<FeedComment>{ feedComment, feedCommentAnswer };

				feedComment.CommentBody = 'Test Post';
				update feedComment;
			}
		}
	}

	@IsTest
	static void testPreventFeeCommentsOnClosedCases_WhenCommentIsAddedOnAClosedCase_ErrorIsThrown() {
		Exception e;
		FeedItem feedItem = [SELECT Id FROM FeedItem LIMIT 1];
		Case caseRec = [SELECT Id FROM Case WHERE Subject = 'TestCase'];
		caseRec.Status = 'Closed';
		update caseRec;

		FeedComment feedComment = new FeedComment(
			FeedItemId = feedItem.Id,
			CommentBody = 'ROSCOTESTCASE-Tanium',
			CommentType = 'TextComment',
			Status = 'Published'
		);

		Test.startTest();
		try {
			insert feedComment;
		} catch (Exception ex) {
			e = ex;
		}
		Test.stopTest();

		Assert.isTrue(
			e.getMessage().contains('You cannot comment to a closed case. Please open a new case.')
		);
	}

	@IsTest
	static void testPublishWorkBadgeMissionEvent_WhenCommunityAnswer_PublishPlatformEvent() {
		FeedComment[] feedComments = [
			SELECT Id, CommentType, InsertedById, FeedItemId
			FROM FeedComment
			WHERE CommentType = 'TextComment'
		];

		Test.startTest();
		FeedCommentTriggerUtility.publishWorkBadgeMissionEvent(feedComments);
		Test.stopTest();

		Integration_Callout__c[] callouts = [SELECT Id FROM Integration_Callout__c];
		Assert.isFalse(callouts.isEmpty());
	}
}