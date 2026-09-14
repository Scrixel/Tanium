/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for AccountSupportRequestEmailHandler
 * @Date: 2025-04-11
 * @Author: Nick Weeks, Tanium Dev Team
 * @Request: SS-10271
 * RequestId  ModifiedDate  Description
 * SS-10271   2025-04-11	Inital test class for AccountSupportRequestHandler
 * SS-11706   2026-01-20    Added test coverage for getISREmailWrapperFromEmail
 */
@IsTest
private class AccountSupportRequestEmailHandlerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'UserTriggerHandler',
				'EmailMessageTriggerHandler',
				'AccountTriggerHandler',
				'OpportunityTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			User testUser = TestFactory.buildUser(
				'Quote Email Test',
				'randomEmail1234512341256164234@test.com',
				'quotesup',
				Utility.getSuperUserProfileId(),
				Utility.getCorporateRoleId()
			);
			testUser.email = 'quotingSupportTest@tanium.com';
			insert testUser;

			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today(),
				Utility.PROSPECTING,
				acc.Id
			);
			insert opp;
		}
	}

	@IsTest
	static void testAcctSupportRequestCreation_whenInboundEmailRecieved_createAccountSupportRequest() {
		AccountSupportRequestEmailHandler accountSupportRequestEmailHandlerObj = new AccountSupportRequestEmailHandler();
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, String> inboundEmailSettings = getDefaultInboundEmail();
			Map<String, String> defaultInboundEnvelope = getDefaultInboundEmail();
			Messaging.InboundEmail testEmail = createTestInboundEmail(inboundEmailSettings);
			Messaging.InboundEnvelope testEnvelope = createTestInboundEnvelope(defaultInboundEnvelope);
			accountSupportRequestEmailHandlerObj.handleInboundEmail(testEmail, testEnvelope);
			Test.stopTest();
			User createdByUser = [SELECT Id FROM User WHERE Email = :testEnvelope.fromAddress];
			Account_Support_Request__c createdAcctSupportRequest = [
				SELECT Id, CreatedById, Description__c, OwnerId, recordTypeId, Status__c
				FROM Account_Support_Request__c
				WHERE CreatedById = :createdByUser.Id
			];
			Assert.areEqual(createdByUser.Id, createdAcctSupportRequest.CreatedById);
			Assert.isTrue(createdAcctSupportRequest.Description__c.contains(testEmail.plainTextBody));
			Assert.areEqual(createdAcctSupportRequest.OwnerId, Utility.getQueueId('Quoting Support'));
			Assert.areEqual(
				createdAcctSupportRequest.recordTypeId,
				Utility.getRecordTypeIdByAPIName('Account_Support_Request__c', 'Quoting_Support')
			);
			Assert.isTrue(createdAcctSupportRequest.Status__c.contains('Requested'));
		}
	}

	@IsTest
	static void testGetISREmailWrapperFromEmail_whenPlainTextBodyIsPresent_returnWrapperIds() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, String> inboundEmailSettings = buildQuoteApprovalDefaultEmail();
			Messaging.InboundEmail inboundEmail = createTestInboundEmail(inboundEmailSettings);
			AccountSupportRequestEmailHandler.AccountSupportRequestEmailWrapper isrEmailWrapper = AccountSupportRequestEmailHandler.getISREmailWrapperFromEmail(
				inboundEmail
			);
			Test.stopTest();

			Id accountId = [SELECT Id FROM Account WHERE Name = 'Test Account'].Id;
			Id opportunityId = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity'].Id;
			Assert.areEqual(accountId, isrEmailWrapper.accountId);
			Assert.areEqual(opportunityId, isrEmailWrapper.opportunityId);
			Assert.isTrue(String.isNotBlank(isrEmailWrapper.description));
		}
	}

	@IsTest
	static void testGetISREmailWrapperFromEmail_whenHTMLBodyIsPresent_returnWrapperIds() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, String> inboundEmailSettings = buildQuoteApprovalNoPlainTextEmail();
			Messaging.InboundEmail inboundEmail = createTestInboundEmail(inboundEmailSettings);
			AccountSupportRequestEmailHandler.AccountSupportRequestEmailWrapper isrEmailWrapper = AccountSupportRequestEmailHandler.getISREmailWrapperFromEmail(
				inboundEmail
			);
			Test.stopTest();

			Id accountId = [SELECT Id FROM Account WHERE Name = 'Test Account'].Id;
			Id opportunityId = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity'].Id;
			Assert.areEqual(accountId, isrEmailWrapper.accountId);
			Assert.areEqual(opportunityId, isrEmailWrapper.opportunityId);
			Assert.isTrue(String.isNotBlank(isrEmailWrapper.description));
		}
	}

	static Map<String, String> getDefaultInboundEmail() {
		Map<String, String> inboundEmailSettings = new Map<String, String>{
			'fromAddress' => 'quotingSupportTest@tanium.com',
			'plainTextBody' => 'plain old text body',
			'htmlBody' => '<html>HTML <ul><li>body</li></ul></html>',
			'subject' => 'default'
		};
		return inboundEmailSettings;
	}

	static Map<String, String> getDefultEmailEnvelope() {
		Map<String, String> defaultEmailEnvelope = new Map<String, String>{
			'fromAddress' => 'quotingSupportTest@tanium.com'
		};
		return defaultEmailEnvelope;
	}

	static Map<String, String> buildQuoteApprovalDefaultEmail() {
		Map<String, String> inboundEmailSettings = new Map<String, String>{
			'fromAddress' => 'quotingSupportTest@tanium.com',
			'plainTextBody' => 'Account Name: Test Account\nOpportunity Name: Test Opportunity\n',
			'htmlBody' => '',
			'subject' => 'default'
		};
		return inboundEmailSettings;
	}

	static Map<String, String> buildQuoteApprovalNoPlainTextEmail() {
		Map<String, String> inboundEmailSettings = new Map<String, String>{
			'fromAddress' => 'quotingSupportTest@tanium.com',
			'plainTextBody' => '',
			'htmlBody' => '<html><body>Account Name: <span>Test Account</span><br>Opportunity Name: <span>Test Opportunity</span><br></body></html>',
			'subject' => 'default'
		};
		return inboundEmailSettings;
	}

	static Messaging.InboundEmail createTestInboundEmail(Map<String, String> emailSettings) {
		Messaging.InboundEmail email = new Messaging.InboundEmail();
		email.subject = emailSettings.get('subject');
		email.fromAddress = emailSettings.get('fromAddress');
		email.plainTextBody = emailSettings.get('plainTextBody');
		email.htmlBody = emailSettings.get('htmlBody');
		return email;
	}

	static Messaging.InboundEnvelope createTestInboundEnvelope(
		Map<String, String> envelopeSettings
	) {
		Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
		env.FromAddress = envelopeSettings.get('fromAddress');
		return env;
	}
}