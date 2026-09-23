/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for AccountInternalSupportRequestAsync
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * @Request:
 * RequestId  ModifiedDate  Description
 * SS-13176   2026-05-27    Replaced Level_4__c with Region__c for LATAM RVP detection
 */
@IsTest
private class AccountInternalSupportRequestAsyncTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass('AccountTriggerHandler');
		TriggerHandler.bypass('UserTriggerHandler');
		Id currentUserId = UserInfo.getUserId();

		User adminUser = TestUserFactory.getAdminUser();
		adminUser.Area_VP__c = currentUserId;
		update adminUser;

		System.runAs(adminUser) {
			List<Account> accounts = new List<Account>();
			Account account;
			for (Integer i = 0; i < 2; i++) {
				account = TestFactory.buildAccount('Test Account' + i);
				account.OwnerId = currentUserId;
				account.Area_VP__c = adminUser.Id;
				accounts.add(account);
			}
			insert accounts;

			List<Account_Support_Request__c> requests = new List<Account_Support_Request__c>();
			Account_Support_Request__c request;
			for (Integer i = 0; i < 2; i++) {
				request = new Account_Support_Request__c();
				request.Account__c = accounts[0].Id;
				request.OwnerId = (i == 0) ? adminUser.Id : currentUserId;
				request.AVP__c = (i == 0) ? adminUser.Id : currentUserId;
				request.RVP__c = (i == 0) ? adminUser.Id : currentUserId;
				request.Status__c = 'Draft';
				requests.add(request);
			}
			insert requests;
		}
	}

	@IsTest
	static void testAccountInternalSupportRequestAsync() {
		TriggerHandler.bypass('AccountSupportRequestTriggerHandler');
		List<Account> accounts = [SELECT Id, OwnerId, Area_VP__c, RVP__c, Region__c FROM Account];
		List<Account_Support_Request__c> requests;
		Set<Id> userIds = new Set<Id>();

		for (Account_Support_Request__c request : [
			SELECT Id, OwnerId
			FROM Account_Support_Request__c
		]) {
			userIds.add(request.OwnerId);
		}

		Id accountRvpUserId;
		Id currentUserId = UserInfo.getUserId();
		Map<Id, User> usersMap = new Map<Id, User>(
			[
				SELECT Id, Area_VP__c, Full_Name__c, Manager.Id, Manager.Full_Name__c
				FROM User
				WHERE Id IN :userIds
			]
		);

		AccountInternalSupportRequestAsync async1 = new AccountInternalSupportRequestAsync(
			accounts,
			true
		);
		AccountInternalSupportRequestAsync async2 = new AccountInternalSupportRequestAsync(
			new List<Account>(),
			false
		);

		Test.startTest();

		Id jobId1 = System.enqueueJob(async1);
		Id jobId2 = System.enqueueJob(async2);

		accountRvpUserId = async2.getAccountRvpUserId(null, null, usersMap);
		accountRvpUserId = async2.getAccountRvpUserId(currentUserId, null, usersMap);
		requests = async1.getSupportRequestsToSync();
		async1.syncSupportRequests(requests);

		Test.stopTest();

		Assert.isTrue(requests.size() > 0);
		Assert.isTrue(requests[0].OwnerId == currentUserId);
	}
}