/*
 * @DATE: 2018-04-23
 * @AUTHOR: Cumulus Vision
 * @REQUEST: TAN-546
 * @BUSINESS: Test class for CaseFeedTriggerHandler
 * RequestId  ModifiedDate  Comment
 * TAN-546    2018-04-24    Created the test class
 * SS-9485    2024-10-19    Rewrote the class with improved test coverage
 */
@IsTest
private class FeedItemTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
		TriggerHandler.bypass(new List<String>{ 'ContactTriggerHandler' });
		TriggerHandler.bypass(new List<String>{ 'CaseTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('roscoapextestingd');
			account.slack_channel_id__c = 'TESTCASE';
			insert account;

			Contact contact = new Contact(
				Email = 'roscoapextest@roscolab.com',
				FirstName = 'Test',
				LastName = 'Apex'
			);
			insert contact;

			Case supportCase = TestFactory.buildCase(account.Id, contact.Id);
			insert supportCase;

			List<FeedItem> feedItems = new List<FeedItem>();
			for (Integer i = 0; i < 2; i++) {
				FeedItem feedItem = buildFeedItem(
					supportCase.Id,
					'TextPost',
					'AllUsers',
					'FeedItem Body ' + i
				);
				feedItems.add(feedItem);
			}
			insert feedItems;
		}
	}

	@IsTest
	static void testFeedItem_WhenUpdate_UpdatedFeedItems() {
		FeedItem[] feedItems = [SELECT Id, Body FROM FeedItem];
		String feedBodyBeforeUpdate = feedItems[0].Body;
		for (FeedItem feedItem : feedItems) {
			feedItem.Body = 'Updated';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update feedItems;
			Test.stopTest();
		}

		FeedItem[] updatedFeedItems = [SELECT Id, Body FROM FeedItem];
		Assert.isFalse(updatedFeedItems[0].Body == feedBodyBeforeUpdate);
	}

	static FeedItem buildFeedItem(String parentId, String feedType, String visibility, String body) {
		return new FeedItem(ParentId = parentId, Type = feedType, Visibility = visibility, Body = body);
	}
}