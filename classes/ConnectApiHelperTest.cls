/*
 * Copyright (c) 2025 Tanium
 *
 * @Business: Test class for ConnectApiHelper
 * @Date:     2026-01-07
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate   Description
 * SS-12298   2026-01-07     Initial development
 */
@isTest
private class ConnectApiHelperTest {
	@IsTest(SeeAllData=true)
	static void testCreateInputFromBody_Always_ReturnData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();

			ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
			messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();

			String expectedText = 'Text ';
			String expectedLink = 'http://link.com';
			String expectedHashtag = 'hashtag';
			String expectedBoldText = 'Bold text';

			ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();
			textSegmentInput.text = expectedText + expectedLink + ' #' + expectedHashtag;
			messageBodyInput.messageSegments.add(textSegmentInput);

			ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
			mentionSegmentInput.id = UserInfo.getUserId();
			messageBodyInput.messageSegments.add(mentionSegmentInput);

			ConnectApi.MarkupBeginSegmentInput markupBeginSegmentInput = new ConnectApi.MarkupBeginSegmentInput();
			markupBeginSegmentInput.markupType = ConnectApi.MarkupType.Bold;
			messageBodyInput.messageSegments.add(markupBeginSegmentInput);

			textSegmentInput = new ConnectApi.TextSegmentInput();
			textSegmentInput.text = expectedBoldText;
			messageBodyInput.messageSegments.add(textSegmentInput);

			ConnectApi.MarkupEndSegmentInput markupEndSegmentInput = new ConnectApi.MarkupEndSegmentInput();
			markupEndSegmentInput.markupType = ConnectApi.MarkupType.Bold;
			messageBodyInput.messageSegments.add(markupEndSegmentInput);

			feedItemInput.body = messageBodyInput;
			feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
			feedItemInput.subjectId = UserInfo.getUserId();

			ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(
				null,
				feedItemInput
			);

			ConnectApi.MessageBodyInput input = ConnectApiHelper.createInputFromBody(feedElement.body);
			Assert.areEqual(8, input.messageSegments.size(), 'Wrong number of message segments.');

			Assert.isTrue(
				input.messageSegments.get(0) instanceof ConnectApi.TextSegmentInput,
				'Segment 0 is not a text segment input.'
			);
			ConnectApi.TextSegmentInput textInput = (ConnectApi.TextSegmentInput) input.messageSegments.get(
				0
			);
			Assert.areEqual(expectedText, textInput.text, 'Segment 0 text does not match.');

			Assert.isTrue(
				input.messageSegments.get(1) instanceof ConnectApi.LinkSegmentInput,
				'Segment 1 is not a link segment input.'
			);
			ConnectApi.LinkSegmentInput linkInput = (ConnectApi.LinkSegmentInput) input.messageSegments.get(
				1
			);
			Assert.areEqual(expectedLink, linkInput.url, 'Segment 1 url does not match.');

			Assert.isTrue(
				input.messageSegments.get(2) instanceof ConnectApi.TextSegmentInput,
				'Segment 2 is not a text segment input.'
			);
			ConnectApi.TextSegmentInput textInput2 = (ConnectApi.TextSegmentInput) input.messageSegments.get(
				2
			);
			Assert.areEqual(' ', textInput2.text, 'Segment 2 text does not match.');

			Assert.isTrue(
				input.messageSegments.get(3) instanceof ConnectApi.HashtagSegmentInput,
				'Segment 3 is not a hashtag segment input.'
			);
			ConnectApi.HashtagSegmentInput hashtagInput = (ConnectApi.HashtagSegmentInput) input.messageSegments.get(
				3
			);
			Assert.areEqual(expectedHashtag, hashtagInput.tag, 'Segment 3 hashtag does not match.');

			Assert.isTrue(
				input.messageSegments.get(4) instanceof ConnectApi.MentionSegmentInput,
				'Segment 4 is not a mention segment input.'
			);
			ConnectApi.MentionSegmentInput mentionInput = (ConnectApi.MentionSegmentInput) input.messageSegments.get(
				4
			);
			Assert.areEqual(
				UserInfo.getUserId(),
				mentionInput.id,
				'Segment 4 mention ID does not match.'
			);

			Assert.isTrue(
				input.messageSegments.get(5) instanceof ConnectApi.MarkupBeginSegmentInput,
				'Segment 5 is not a markup begin segment input.'
			);
			ConnectApi.MarkupBeginSegmentInput markupBeginInput = (ConnectApi.MarkupBeginSegmentInput) input.messageSegments.get(
				5
			);
			Assert.areEqual(
				ConnectApi.MarkupType.Bold,
				markupBeginInput.markupType,
				'Segment 5 markup type does not match.'
			);

			Assert.isTrue(
				input.messageSegments.get(6) instanceof ConnectApi.TextSegmentInput,
				'Segment 6 is not a text segment input.'
			);
			ConnectApi.TextSegmentInput textInput3 = (ConnectApi.TextSegmentInput) input.messageSegments.get(
				6
			);
			Assert.areEqual(expectedBoldText, textInput3.text, 'Segment 6 text does not match.');

			Assert.isTrue(
				input.messageSegments.get(7) instanceof ConnectApi.MarkupEndSegmentInput,
				'Segment 7 is not a markup end segment input.'
			);
			ConnectApi.MarkupEndSegmentInput markupEndInput = (ConnectApi.MarkupEndSegmentInput) input.messageSegments.get(
				7
			);
			Assert.areEqual(
				ConnectApi.MarkupType.Bold,
				markupEndInput.markupType,
				'Segment 7 markup type does not match.'
			);

			ConnectApi.FeedItemInput feedItemInput2 = ConnectApiHelper.createFeedItemInputFromBody(
				feedElement.body
			);
			Assert.areEqual(
				input,
				feedItemInput2.body,
				'createFeedItemInputFromBody is returning a different input body than createInputFromBody.'
			);

			ConnectApi.CommentInput commentInput = ConnectApiHelper.createCommentInputFromBody(
				feedElement.body
			);
			Assert.areEqual(
				input,
				commentInput.body,
				'createCommentInputFromBody is returning a different input body than createInputFromBody.'
			);
		}
	}

	@IsTest(SeeAllData=true)
	static void testAddFeedItemFilterFields_WhenFeedItemAdded_FieldsAreAdded() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Case supportCase = TestFactory.buildCase(account.Id);
			insert supportCase;

			FeedItem feedItem = TestFactory.buildFeedItem(supportCase.Id);
			feedItem.Visibility = 'AllUsers';
			feedItem.IsRichText = true;
			feedItem.NetworkScope = 'AllNetworks';
			feedItem.Type = 'TextPost';
			insert feedItem;

			List<FeedItem> feedItems = new List<FeedItem>{ feedItem };

			Test.startTest();
			CaseTriggerUtilityWithoutSharing.addFeedItemFilterFields(feedItems);
			Test.stopTest();

			FeedItem updatedFeedItem = [SELECT Id, Body FROM FeedItem WHERE Id = :feedItems[0].Id];
			Assert.isNotNull(updatedFeedItem.Body);
		}
	}

	@IsTest(SeeAllData=true)
	static void testAddFeedCommentFilterFields_WhenFeedCommentAdded_FieldsAreAdded() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Case supportCase = TestFactory.buildCase(account.Id);
			insert supportCase;

			FeedItem feedItem = TestFactory.buildFeedItem(supportCase.Id);
			feedItem.Visibility = 'AllUsers';
			feedItem.IsRichText = true;
			feedItem.NetworkScope = 'AllNetworks';
			feedItem.Type = 'TextPost';
			insert feedItem;

			FeedComment feedComment = TestFactory.buildFeedComment(feedItem.Id);
			feedComment.CommentType = 'TextComment';
			feedComment.Status = 'Published';
			insert feedComment;

			feedComment = [
				SELECT Id, CommentBody, ParentId
				FROM FeedComment
				WHERE Id = :feedComment.Id
			];

			List<FeedComment> feedComments = new List<FeedComment>{ feedComment };

			Test.startTest();
			CaseTriggerUtilityWithoutSharing.addFeedCommentFilterFields(feedComments);
			Test.stopTest();

			FeedComment updatedFeedComment = [
				SELECT Id, CommentBody
				FROM FeedComment
				WHERE Id = :feedComments[0].Id
			];
			Assert.isNotNull(updatedFeedComment.CommentBody);
		}
	}
}