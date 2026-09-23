/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CaseSendEmailOnOwnershipChange
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId   ModifiedDate   Description
 * SS-12607    2026-02-12     Remove TAM profile references and best practice updates
 */
@IsTest
private class CaseSendEmailOnOwnershipChangeT {
	private static String caseSupportRecordTypeId = Utility.getRecordTypeIdByAPIName(
		'Case',
		'Support'
	);

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'CaseTriggerHandler' }
		);

		User adminUser = TestUserFactory.getAdminUser();
		adminUser.Email = 'roscoapextest@tanium.com';
		update adminUser;

		System.runAs(adminUser) {
			Account acc = TestFactory.buildAccount('Test Account');
			acc.slack_channel_id__c = 'foo';
			insert acc;

			Contact con = TestFactory.buildContact(acc.Id);
			con.Email = 'roscoapextest@roscolab.com';
			con.FirstName = 'Test';
			con.LastName = 'Apex';
			insert con;

			Case caseRec = TestFactory.buildCase(acc.Id, con.Id);
			caseRec.Subject = 'ROSCOTESTCASE';
			caseRec.Severity_Community__c = '3';
			caseRec.Type = 'Incident';
			caseRec.Reason = 'New problem';
			caseRec.Origin = 'Email';
			caseRec.SuppliedEmail = '99@outlook.com';
			caseRec.Status = 'On Hold';
			caseRec.RecordTypeId = caseSupportRecordTypeId;
			caseRec.OwnerId = adminUser.Id;
			insert caseRec;
		}
	}

	@IsTest
	static void testGetCaseDetailsSendEmailOnOwnerChange_Always_Succeed() {
		List<Case> cases = [SELECT Id, OwnerId, CaseNumber, Subject FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoUtility.getCaseDetails(cases[0].Id);
			CaseSendEmailOnOwnershipChange.sendEmailOnOwnerChange(cases);
			Test.stopTest();
		}
	}
}