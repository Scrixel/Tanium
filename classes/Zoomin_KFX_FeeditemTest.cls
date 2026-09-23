/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Zoomin's Salesforce Feed Items Connector
 * @Date: 2024-01-24
 * @Request: SS-6903
 * RequestId  ModifiedDate  Description
 * SS-6903    2024-01-24    Initial development
 * SS-13032   2026-04-27    Updated test method
 **/
@IsTest
private class Zoomin_KFX_FeeditemTest {
	@IsTest
	static void add_and_delete() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = new Account(
				Name = 'Account for feed item',
				ShippingCountry = 'United States'
			);
			insert account;
			FeedItem feedItem = new FeedItem(
				title = 'Feed Item Title',
				body = 'Feed Item Body',
				type = 'QuestionPost',
				parentid = account.id
			);
			insert feedItem;
			delete feedItem;
		}
	}
}