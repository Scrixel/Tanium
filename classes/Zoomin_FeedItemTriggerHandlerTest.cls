/**
 * @Business: Zoomin's Salesforce Feed Items Connector
 * @Date: 2024-01-24
 * @Request: SS-6903
 * Modified  ModifiedDate   Description
 * SS-6903   2024-01-24     Initial development
 **/
@IsTest
private class Zoomin_FeedItemTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler', 'AccountTriggerHandler' });
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('parent of post');
			insert acc;
		}
	}

	@IsTest
	static void testFeedItem_WhenFeedItemCreatedOrDeleted_AlwaysCreateOrDeleteRelatedZoominFeedItem() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [SELECT Id FROM Account LIMIT 1];

			Test.startTest();
			FeedItem fi = new FeedItem(
				title = 'post',
				body = 'some html',
				type = 'QuestionPost',
				parentid = acc.Id
			);
			insert fi;
			Test.stopTest();

			List<Zoomin_FeedItem__c> zoominFeedItem = [
				SELECT Id
				FROM Zoomin_FeedItem__c
				WHERE Feed_Item__c = :fi.Id
			];
			Assert.areEqual(
				1,
				zoominFeedItem.size(),
				'Related Zoomin_FeedItem should be created when FeedItem is inserted.'
			);

			delete fi;
			zoominFeedItem = [SELECT Id FROM Zoomin_FeedItem__c WHERE Feed_Item__c = :fi.Id];
			Assert.areEqual(
				0,
				zoominFeedItem.size(),
				'Related Zoomin_FeedItem should be deleted when FeedItem is deleted.'
			);
		}
	}

	@IsTest
	static void testFeedItem_WhenTriggerHandlerDisabled_DoNotCreateOrDeleteZoominFeedItem() {
		TriggerHandler.bypass('UserTriggerHandler');

		User runningUser = TestUserFactory.getAdminUser();
		runningUser.DisableTaniumCustomTriggers__c = 'Zoomin_FeedItemTriggerHandler';
		update runningUser;

		Utility.runningUser = runningUser;
		System.runAs(runningUser) {
			Account acc = [SELECT Id FROM Account LIMIT 1];

			Test.startTest();
			FeedItem fi = new FeedItem(
				title = 'post',
				body = 'some html',
				type = 'QuestionPost',
				parentid = acc.Id
			);
			insert fi;
			Test.stopTest();

			List<Zoomin_FeedItem__c> zoominFeedItem = [
				SELECT Id
				FROM Zoomin_FeedItem__c
				WHERE Feed_Item__c = :fi.Id
			];
			Assert.areEqual(
				0,
				zoominFeedItem.size(),
				'No Zoomin_Feeditem record should be created when trigger is bypassed.'
			);
		}
	}
}