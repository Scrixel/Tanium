/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Test class for PostRefreshAccountResetBatch
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12775   2026-03-24    Initial Development
 */
@IsTest
public class PostRefreshAccountResetBatchTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			List<Account> accounts = new List<Account>();
			for (Integer i = 0; i < 5; i++) {
				accounts.add(TestFactory.buildAccount('Test Account ' + i));
				accounts[i].Slack_Channel_Id__c = 'test-slack-channel-id';
			}
			insert accounts;
		}
	}

	@IsTest
	static void testPostRefreshAccountResetBatch_Always_ResetSlackChannelId() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Id jobId = Database.executeBatch(new PostRefreshAccountResetBatch());
			Test.stopTest();

			Assert.isNotNull(jobId, 'Batch job should have been executed');
			for (Account updatedAccount : [SELECT Id, Slack_Channel_Id__c FROM Account]) {
				Assert.isTrue(
					updatedAccount.Slack_Channel_Id__c ==
					PostRefreshAccountResetBatch.nonProdAccountSlackChannelId,
					'Slack channel id must be reset'
				);
			}
		}
	}
}