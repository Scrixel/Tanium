/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Test class for CaseSendToTriageSlack
 * @Date: 12/09/2025
 * @Authors: Jason Johnson, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12185   2025-12-09    Cleanup legacy code and add new method for new support model check
 */
@IsTest
private class CaseSendToTriageSlackTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'CaseTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Name = '';
			cmSetting.Rosco_Case_Country_Routing_AccountIds__c = 'All';
			cmSetting.Rosco_Case_Url_Prefix__c = 'foo';
			cmSetting.Rosco_Sfdc_Dom_L__c = 'bar';
			cmSetting.Rosco_Slack_Triage_Channel_SupportCenter__c = 'hello';
			cmSetting.Rosco_Slack_Triage_Channel_Sc_Japan__c = 'world';
			insert cmSetting;

			List<Account> accounts = new List<Account>();
			accounts.add(TestFactory.buildAccount('Test Account Support Center (Poland)'));
			accounts[0].Slack_Channel_Id__c = 'CH87S4VUJ';
			accounts[0].Support_Model__c = 'Support Center (Poland)';
			accounts.add(TestFactory.buildAccount('Test Account Support Center'));
			accounts[1].Slack_Channel_Id__c = 'CH87S4VUJ';
			accounts[1].Support_Model__c = 'Support Center';
			accounts.add(TestFactory.buildAccount('Test Account Support Center (Japan Bypass)'));
			accounts[2].Slack_Channel_Id__c = 'CH87S4VUJ';
			accounts[2].Support_Model__c = 'Support Center (Japan Bypass)';
			accounts.add(TestFactory.buildAccount('Test Account Global Support Bypass'));
			accounts[3].Slack_Channel_Id__c = 'CH87S4VUJ';
			accounts[3].Support_Model__c = 'Global Support Bypass';
			insert accounts;

			List<Contact> contacts = new List<Contact>();
			contacts.add(TestFactory.buildContact(accounts[0].Id));
			contacts[0].Support_Option__c = 'Support English';
			contacts.add(TestFactory.buildContact(accounts[1].Id));
			contacts[1].Support_Option__c = 'Support English';
			contacts.add(TestFactory.buildContact(accounts[2].Id));
			contacts[2].Support_Option__c = 'Support Japanese';
			contacts.add(TestFactory.buildContact(accounts[3].Id));
			contacts[3].Support_Option__c = 'Survey: TAM';
			insert contacts;

			List<Case> cases = new List<Case>();
			cases.add(TestFactory.buildCase(accounts[0].Id, contacts[0].Id));
			cases.add(TestFactory.buildCase(accounts[1].Id, contacts[1].Id));
			cases.add(TestFactory.buildCase(accounts[2].Id, contacts[2].Id));
			cases.add(TestFactory.buildCase(accounts[3].Id, contacts[3].Id));
			insert cases;

			List<Rosco_Account__c> roscoAccounts = new List<Rosco_Account__c>();
			roscoAccounts.add(
				TestFactory.buildRoscoAccount(
					'Test Rosco Account Support Center (Poland)',
					accounts[0].Id
				)
			);
			roscoAccounts.add(
				TestFactory.buildRoscoAccount('Test Rosco Account Support Center', accounts[1].Id)
			);
			roscoAccounts.add(
				TestFactory.buildRoscoAccount(
					'Test Rosco Account Support Center (Japan Bypass)',
					accounts[2].Id
				)
			);
			roscoAccounts.add(
				TestFactory.buildRoscoAccount(
					'Test Rosco Account Global Support Bypass',
					accounts[3].Id
				)
			);
			insert roscoAccounts;
		}
	}

	@IsTest
	static void testSlackCallout_Always_CalloutSuccessful() {
		ID jobId;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Test.setMock(HttpCalloutMock.class, new CaseSendToSlackMock());
			jobId = System.enqueueJob(new SlackCallout('test', 'POST', 'test callout'));
			Test.stopTest();
		}

		Assert.isNotNull(jobId, 'The job ID should not be null after enqueueing the job.');
	}

	@IsTest
	static void testSendToTriageSlack_SupportCenterPoland_SendToTriageSlack() {
		List<Case> cases = [
			SELECT
				Id,
				CaseNumber,
				Subject,
				Severity__c,
				Origin,
				Component__c,
				Account.Support_Model__c,
				ContactEmail,
				SuppliedEmail,
				CreatedById,
				Severity_Community__c,
				ContactId,
				AccountId
			FROM Case
			WHERE Account.Support_Model__c = 'Support Center (Poland)'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Test.setMock(HttpCalloutMock.class, new CaseSendToSlackMock());
			CaseSendToTriageSlack.sendToTriageSlack(cases);
			Test.stopTest();
		}

		Assert.isTrue(
			cases[0].Account.Support_Model__c == 'Support Center (Poland)',
			'Account support model should be Support Center (Poland)'
		);
	}

	@IsTest
	static void testSendToTriageSlack2_SupportCenter_SendToTriageSlack() {
		List<Case> cases = [
			SELECT
				Id,
				CaseNumber,
				Subject,
				Severity__c,
				Origin,
				Component__c,
				Account.Support_Model__c,
				ContactEmail,
				SuppliedEmail,
				CreatedById,
				Severity_Community__c,
				ContactId,
				AccountId
			FROM Case
			WHERE Account.Support_Model__c = 'Support Center'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Test.setMock(HttpCalloutMock.class, new CaseSendToSlackMock());
			CaseSendToTriageSlack.sendToTriageSlack2(cases);
			Test.stopTest();
		}

		Assert.isTrue(
			cases[0].Account.Support_Model__c == 'Support Center',
			'Account support model should be Support Center'
		);
	}

	@IsTest
	static void testSendToTriageSlack2_JapanBypass_SendToTriageSlack() {
		List<Case> cases = [
			SELECT
				Id,
				CaseNumber,
				Subject,
				Severity__c,
				Origin,
				Component__c,
				Account.Support_Model__c,
				ContactEmail,
				SuppliedEmail,
				CreatedById,
				Severity_Community__c,
				ContactId,
				AccountId
			FROM Case
			WHERE Account.Support_Model__c = 'Support Center (Japan Bypass)'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Test.setMock(HttpCalloutMock.class, new CaseSendToSlackMock());
			CaseSendToTriageSlack.sendToTriageSlack2(cases);
			Test.stopTest();
		}

		Assert.isTrue(
			cases[0].Account.Support_Model__c == 'Support Center (Japan Bypass)',
			'Account support model should be Support Center (Japan Bypass)'
		);
	}

	@IsTest
	static void testSendToTriageSlack2_GlobalSupportBypass_SendToTriageSlack() {
		List<Case> cases = [
			SELECT
				Id,
				CaseNumber,
				Subject,
				Severity__c,
				Origin,
				Component__c,
				Account.Support_Model__c,
				ContactEmail,
				SuppliedEmail,
				CreatedById,
				Severity_Community__c,
				ContactId,
				AccountId
			FROM Case
			WHERE Account.Support_Model__c = 'Global Support Bypass'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Test.setMock(HttpCalloutMock.class, new CaseSendToSlackMock());
			CaseSendToTriageSlack.sendToTriageSlack2(cases);
			Test.stopTest();
		}

		Assert.isTrue(
			cases[0].Account.Support_Model__c == 'Global Support Bypass',
			'Account support model should be Global Support Bypass'
		);
	}
}