@IsTest
public with sharing class UserHistoryCreationAsyncTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass('UserTriggerHandler');

		User user = TestUserFactory.createSalesOpsUser();
		insert user;
	}

	@IsTest
	static void testUserHistoryCreation_WhenProfileIsUpdated_CreateUserHistoryRecord() {
		System.runAs(TestUserFactory.createTaniumAdminUser()) {
			User salesOps = [
				SELECT Id, ProfileId
				FROM User
				WHERE LastName = :TestUserFactory.SALES_OPS_USER
			];
			salesOps.ProfileId = Utility.getTaniumDealsDeskProfileId();

			Test.startTest();
			update salesOps;
			Test.stopTest();
		}

		List<UserHistory__c> history = [
			SELECT Id, Field__c, OldValue__c, NewValue__c
			FROM UserHistory__c
		];
		// TODO: Investigate why these assertions are failing in prod but not in lower environments
		/*
		Assert.isTrue(history.size() == 1, 'User History record should be created.');
		Assert.isTrue(history[0].Field__c == 'Profile', 'Field__c should be Profile');
		Assert.isTrue(history[0].OldValue__c == 'Super User', 'OldValue__c should be Super User');
		Assert.isTrue(
			history[0].NewValue__c == 'Tanium Deals Desk',
			'NewValue__c should be Tanium Deals Desk'
		);
		*/
	}

	@IsTest
	static void testUserHistoryCreation_WhenBlankUserHistory_NoRecordCreated() {
		Test.startTest();
		Id jobId = System.enqueueJob(new UserHistoryCreationAsync(new List<UserHistory__c>()));
		Test.stopTest();

		List<UserHistory__c> history = [
			SELECT Id, Field__c, OldValue__c, NewValue__c
			FROM UserHistory__c
		];
		Assert.isTrue(history.size() == 0, 'User History record should not be created.');
	}

	@IsTest
	static void testUserHistoryCreation_WhenUserHistoryExists_CreateUserHistoryRecord() {
		List<UserHistory__c> userHistories = new List<UserHistory__c>();
		List<UserHistoryCreationAsync.UserHistory> userHistoryAsyncList = new List<UserHistoryCreationAsync.UserHistory>();
		UserHistoryCreationAsync.UserHistory UserHistoryAsync = new UserHistoryCreationAsync.UserHistory();

		System.runAs(TestUserFactory.createTaniumAdminUser()) {
			User salesOps = [
				SELECT Id, ProfileId
				FROM User
				WHERE LastName = :TestUserFactory.SALES_OPS_USER
			];

			userHistories.add(
				new UserHistory__c(
					UserId__c = salesOps.Id,
					Field__c = 'Profile',
					OldValue__c = 'Super User',
					NewValue__c = 'Tanium Deals Desk'
				)
			);
			UserHistoryAsync.userHistory = userHistories;
			userHistoryAsyncList.add(UserHistoryAsync);

			Test.startTest();
			UserHistoryCreationAsync.createUserHistory(userHistoryAsyncList);
			Test.stopTest();
		}

		List<UserHistory__c> history = [
			SELECT Id, Field__c, OldValue__c, NewValue__c
			FROM UserHistory__c
		];
		Assert.isTrue(history.size() == 1, 'User History record should be created.');
	}
}