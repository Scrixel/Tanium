/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoCmtyProcesses
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId   ModifiedDate   Description
 * SS-12607    2026-02-12     Remove TAM profile references and best practice updates
 */
@IsTest
private class RoscoCmtyProcessesTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Contact con = TestFactory.buildContact(acc.Id);
			con.Email = 'RoscoCaseProcesses@foo.com';
			con.FirstName = 'RoscoCaseProcesse';
			con.LastName = 'Foo';
			insert con;

			User roscoUser = TestUserFactory.createUser(
				'Testing',
				'RoscoCaseProcesses@foo.com',
				'rcpfed',
				Utility.getProfileId('Tanium Community Login Authenticated Case'),
				null
			);
			roscoUser.ContactId = con.Id;
			insert roscoUser;

			FeedItem feedItemQuestion = new FeedItem(
				ParentId = roscoUser.Id,
				Body = 'Test FeedItem Community Question',
				Visibility = 'AllUsers',
				IsRichText = true,
				Title = 'Test FeedItem Community Question',
				NetworkScope = Constants.TANIUM_CUSTOMER_COMMUNITY_ID
			);
			insert feedItemQuestion;
		}
	}

	@IsTest
	static void testProcessNewCmtyQuestion_Always_Succeed() {
		FeedItem feedItem = [SELECT Id, NetworkScope, Title, Body, ParentId FROM FeedItem];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Test.setMock(HttpCalloutMock.class, new CaseSendToSlackMock());
			RoscoCmtyProcesses.processNewCmtyQuestion(feedItem);
			RoscoCmtyProcesses.tempTillReWriteYo();
			RoscoCmtyProcesses.slackCommunity(feedItem.Body, feedItem.ParentId);
			Test.stopTest();
		}
	}
}