/*
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2024-10-16
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Test class for FeedItemTriggerUtility
 * RequestId  ModifiedDate  Comment
 * SS-9451    2024-10-17    Initial Development
 * SS-8303    2024-12-05    Updated test method
 * SS-12885   2026-03-26    Added test method for processMilestoneEventFeedItems
 */
@IsTest
private class FeedItemTriggerUtilityTest {
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
			supportCaseL1.Escalation_Tier__c = 'Level 1';
			supportCaseL1.Subject = 'TestCase';
			insert new List<Case>{ supportCaseL1 };

			FeedItem feedItemMilestoneEvent = new FeedItem(
				ParentId = supportCaseL1.Id,
				NetworkScope = 'AllNetworks',
				Type = 'MilestoneEvent'
			);
			insert feedItemMilestoneEvent;

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
				insert feedComment;

				feedItem.Body = 'Test Post';
				update feedItem;
			}
		}
	}

	@IsTest
	static void testPublishWorkBadgeMissionEvent_WhenCommunityQuestion_PublishPlatformEvent() {
		FeedItem[] feedItems = [
			SELECT Id, Type, InsertedById, FeedItem.ParentId
			FROM FeedItem
			WHERE Type = 'QuestionPost'
		];

		Test.startTest();
		FeedItemTriggerUtility.publishWorkBadgeMissionEvent(feedItems);
		Test.stopTest();

		Integration_Callout__c[] callouts = [SELECT Id FROM Integration_Callout__c];
		Assert.isFalse(callouts.isEmpty());
	}

	@IsTest
	static void testPreventFeedItemsOnClosedCases_WhenPostIsAddedOnAClosedCase_ErrorIsThrown() {
		Exception e;
		Case caseRec = [SELECT Id FROM Case WHERE Subject = 'TestCase'];
		caseRec.Status = 'Closed';
		update caseRec;

		FeedItem feedItem = new FeedItem(
			ParentId = caseRec.Id,
			Body = 'ROSCOTESTCASE-Customer',
			Visibility = 'AllUsers',
			IsRichText = true,
			NetworkScope = 'AllNetworks'
		);

		Test.startTest();
		try {
			insert feedItem;
		} catch (Exception ex) {
			e = ex;
		}
		Test.stopTest();

		Assert.isTrue(
			e.getMessage().contains('You cannot post to a closed case. Please open a new case.')
		);
	}

	@IsTest
	static void testProcessMilestoneEventFeedItems_WhenMilestoneEventFeedItem_VisibilityIsUpdated() {
		List<FeedItem> feedItems = [
			SELECT Id, Visibility, Type
			FROM FeedItem
			WHERE Type = 'MilestoneEvent'
		];
		for (FeedItem feedItem : feedItems) {
			feedItem.Visibility = 'AllUsers';
		}
		update feedItems;

		Test.startTest();
		FeedItemTriggerUtility.processMilestoneEventFeedItems(feedItems);
		Test.stopTest();

		for (FeedItem feedItem : feedItems) {
			Assert.areEqual(
				'InternalUsers',
				feedItem.Visibility,
				'Visibility should be InternalUsers for milestone event feed items'
			);
		}
	}
}