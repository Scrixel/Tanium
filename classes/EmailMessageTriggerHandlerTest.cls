/*
 * Copyright (c) 2026 Tanium
 * 
 * @DATE: 2020-05-12
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Test class for the EmailMessageTriggerHandler class.
 * RequestId  ModifiedDate  Comment
 * SS-12056   2025-11-18    Rewrote test class
 * SS-13459   2026-06-29    Added coverage for FromAddress on outbound POC_Case emails
 */

@IsTest
private class EmailMessageTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'CaseTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('roscoapextestingd');
			account.slack_channel_id__c = 'TESTCASE';
			insert account;

			Contact contact1 = TestFactory.buildContact(account.Id);
			contact1.Email = 'roscoapextest@roscolab.com';
			contact1.FirstName = 'Test';
			contact1.LastName = 'Apex';
			Contact contact2 = TestFactory.buildContact(account.Id);
			contact2.Email = 'chronicle-support@chronicle.security';
			contact2.FirstName = 'Test2';
			contact2.LastName = 'Apex';
			insert new List<Contact>{ contact1, contact2 };

			Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;
			Id recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');

			User user = new User(
				Email = 'roscoapextest@roscolab.com',
				FirstName = 'Test',
				LastName = 'ApexUser',
				Username = 'roscoapextest@roscolab.com',
				Alias = 'n12345',
				CommunityNickname = 'nk12345',
				TimeZoneSidKey = 'America/Los_Angeles',
				LocaleSidKey = 'en_US',
				EmailEncodingKey = 'ISO-8859-1',
				ProfileId = profileId,
				LanguageLocaleKey = 'en_US'
			);

			insert user;

			Case cs = new Case(
				ContactId = contact1.Id,
				Accountid = account.Id,
				Ownerid = user.Id,
				Subject = 'IGNORE:testing',
				Severity_Community__c = '3',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				suppliedEmail = '99@outlook.com',
				LatestPublicCommentHTML__c = '<html>hello</html>',
				Status = 'On Hold',
				RecordTypeId = recordTypeId
			);
			Case pocCase = new Case(
				ContactId = contact1.Id,
				AccountId = account.Id,
				OwnerId = user.Id,
				Subject = 'POC outbound test',
				Severity_Community__c = '3',
				Origin = 'Email',
				Status = 'On Hold',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'POC_Case')
			);
			insert new List<Case>{ cs, pocCase };

			insert new List<CaseContactRole>{
				new CaseContactRole(CasesId = cs.Id, ContactId = contact2.Id),
				new CaseContactRole(CasesId = pocCase.Id, ContactId = contact1.Id)
			};

			EmailMessage emailMessage = new EmailMessage(
				ParentId = cs.Id,
				RelatedToId = cs.Id,
				Incoming = false
			);
			emailMessage.HtmlBody = '<html><body>hello</body></html>';
			insert emailMessage;
			emailMessage.subject = 'foo1';
			update emailMessage;
		}
	}

	@IsTest
	static void testProcessOutboundSupportCaseEmail_EmailMessageLinkedToCase_AddAccountIdentifier() {
		EmailMessage emailMessage = [
			SELECT Id, ParentId, HtmlBody, TextBody, Subject, FromAddress, ToAddress
			FROM EmailMessage
			WHERE Subject = 'foo1'
		];

		Case cs = [SELECT Id, Account.Name, CaseNumber FROM Case WHERE Id = :emailMessage.ParentId];
		String accountIdentifier = cs.Account.Name + ',' + cs.CaseNumber;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoCaseProcesses.processOutboundSupportCaseEmail(emailMessage);
			Test.stopTest();
		}

		Assert.isTrue(emailMessage.HtmlBody.contains(accountIdentifier));
	}

	@IsTest
	static void testProcessOutboundSupportCaseEmail_OutboundPOCCase_SetsFromToAndSubject() {
		Case pocCase = [SELECT Id FROM Case WHERE Subject = 'POC outbound test'];
		EmailMessage email = new EmailMessage(
			ParentId = pocCase.Id,
			RelatedToId = pocCase.Id,
			Incoming = false
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoCaseProcesses.processOutboundSupportCaseEmail(email);
			Test.stopTest();
		}

		Assert.areEqual(
			'support@tanium.com',
			email.FromAddress,
			'Outbound POC email should send from the verified address'
		);
		Assert.areEqual(
			'POC outbound test',
			email.Subject,
			'Outbound POC subject should be set from the case subject'
		);
		Assert.areEqual(
			'roscoapextest@roscolab.com',
			email.ToAddress,
			'Outbound POC To should be populated from the case contact roles'
		);
	}
}