/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Test class for BatchPostRefreshContactReset
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12777   2026-03-19    Fix test class and best practice updates
 */
@IsTest
public class BatchPostRefreshContactResetTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			List<Account> accounts = new List<Account>();
			for (Integer i = 0; i < 5; i++) {
				accounts.add(TestFactory.buildAccount('Test Account ' + i));
			}
			insert accounts;

			List<Contact> contacts = new List<Contact>();
			for (Integer i = 0; i < 5; i++) {
				contacts.add(TestFactory.buildContact(accounts[i].Id));
			}
			insert contacts;
		}
	}

	@IsTest
	static void testBatchPostRefreshContactReset_Always_AddPostFixToEmails() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Id jobId = Database.executeBatch(new BatchPostRefreshContactReset());
			Test.stopTest();

			Assert.isNotNull(jobId, 'Batch job should have been executed');
			for (Contact updatedContact : [SELECT Id, Email FROM Contact]) {
				Assert.isTrue(
					updatedContact.Email.contains(BatchPostRefreshContactReset.SANDBOX_EMAIL_POSTFIX),
					'Emails must have a postfix appended'
				);
			}
		}
	}
}