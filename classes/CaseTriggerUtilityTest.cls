/*
 * @DATE: 2024-02-16
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Test methods for class CaseTriggerUtility
 * RequestId  ModifiedDate  Comment
 * SS-7278    2024-02-16    Created the test class
 * SS-7697    2024-04-19    Updated test class
 * SS-7740    2024-04-23    Updated test class
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */
@IsTest
private class CaseTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'CaseTriggerHandler' });
		Id supportCaseRecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			insert contact;

			Case supportCase = new Case(RecordTypeId = supportCaseRecordTypeId);
			supportCase.Origin = 'Community';
			supportCase.Severity_Community__c = '3';
			supportCase.ContactId = contact.Id;
			supportCase.AccountId = account.Id;
			supportCase.Subject = 'Case Subject';
			insert supportCase;
		}
	}

	@IsTest
	static void testSetCaseTeamField_WhenPubsecAccount_SetTeamToPubsec() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'CaseTriggerHandler' });
		// Case contains a formula field (Support Model) from the account
		// So to ensure I get the desired value, I insert a Pubsec account and update the case.AccountId in this method.
		Account pubsecAccount = TestFactory.buildAccount('Pubsec Account');
		pubsecAccount.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Client');
		pubsecAccount.Support_Model__c = CaseTriggerUtility.PUBLIC_SECTOR_SUPPORT_CENTER;
		Case[] cases = [SELECT Id, AccountId, Team__c, Support_Model__c FROM Case];
		Case[] pubsecCases;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			insert pubsecAccount;
			cases[0].AccountId = pubsecAccount.Id;
			cases[0].Team__c = null;
			update cases[0];
			pubsecCases = [
				SELECT Id, AccountId, Team__c, Support_Model__c
				FROM Case
				WHERE AccountId = :pubsecAccount.Id
			];
			CaseTriggerUtility.setCaseTeamField(pubsecCases);
			Test.stopTest();
		}

		Assert.isTrue(pubsecCases[0].Team__c == CaseTriggerUtility.PUBLIC_SECTOR);
	}

	@IsTest
	static void testGetPolandSupportComponents_Always_ReturnPolandSupportComponents() {
		Set<String> polandSupportComponents;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			polandSupportComponents = CaseTriggerUtility.getPolandSupportComponents();
			Test.stopTest();
		}

		Assert.isFalse(polandSupportComponents.isEmpty());
	}

	@IsTest
	static void testSevIncreaseSlackNotification_WhenNoSevEscalation_DoNotSendSlack() {
		Case[] cases = [SELECT Id, Severity_Community__c FROM Case];
		Map<Id, Case> oldMap = new Map<Id, Case>(cases.deepClone(true, true, true));

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CaseTriggerUtility.sevIncreaseSlackNotification(cases, oldMap);
			Test.stopTest();
		}
		// Assert: Test method would fail if slack message was sent with error: "Methods defined as TestMethod do not support Web service callouts"
	}
}