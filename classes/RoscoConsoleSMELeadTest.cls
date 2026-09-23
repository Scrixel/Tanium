/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoConsoleSMELead
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId   ModifiedDate   Description
 * SS-12607    2026-02-12     Remove TAM profile references and best practice updates
 */
@IsTest
private class RoscoConsoleSMELeadTest {
	private static String caseSupportRecordTypeId = Utility.getRecordTypeIdByAPIName(
		'Case',
		'Support'
	);

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'CaseTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			acc.slack_channel_id__c = 'TESTCASE';
			insert acc;

			Contact con = TestFactory.buildContact(acc.Id);
			con.Email = 'roscoapextest@roscolab.com';
			con.FirstName = 'Test';
			con.LastName = 'Apex';
			insert con;

			Case caseRec = TestFactory.buildCase(acc.Id, con.Id);
			caseRec.Description = 'Description 123';
			caseRec.Origin = 'Igloo';
			caseRec.RecordTypeId = caseSupportRecordTypeId;
			caseRec.Subject = 'ROSCOTESTCASE';
			caseRec.Type = 'Incident';
			caseRec.Escalation_Date__c = Date.today();
			insert caseRec;

			FeedItem feedItem = TestFactory.buildFeedItem(caseRec.Id);
			feedItem.Body = 'Escalation Test FeedItem\nLevel:\nSME Group:';
			insert feedItem;
		}
	}

	@IsTest
	static void testGetEscalationHistory_Always_Succeed() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoConsoleSMELead.getEscalationHistory();
			Test.stopTest();
		}
	}
}