/*
 * @BUSINESS: Test methods for class CloseCase
 * @DATE: 2025-02-21
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-8178    2025-02-21    Created
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */
@IsTest
private class CloseCaseTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'CaseTriggerHandler' });
		Id supportRecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;

			List<Case> cases = new List<Case>();
			Case openCase = TestFactory.buildCase(acct.Id);
			openCase.RecordTypeId = supportRecordTypeId;
			openCase.Description = 'Open Case';
			openCase.Status = 'New';
			openCase.Severity_Community__c = '3';
			cases.add(openCase);

			insert cases;
		}
	}

	@IsTest
	static void testCloseCase_WhenValuesAreSet_CloseCase() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case caseRecord = [SELECT Id FROM Case LIMIT 1];

			List<CloseCase.Requests> requests = new List<CloseCase.Requests>();
			List<CloseCase.Results> results = new List<CloseCase.Results>();

			CloseCase.Requests request = new CloseCase.Requests();
			request.caseId = caseRecord.Id;
			request.problem = 'Test problem';
			request.solution = 'Test solution';
			request.kb = 'false';
			request.spam = 'false';
			request.incidentCause = 'Software Issue';
			request.resolutionCode = 'Solved (Bug Workaround)';
			request.standardEmail = 'false';
			request.psEmail = 'false';
			request.hydra = 'No';
			request.component = 'Tanium - Microsoft Integration';
			request.subcomponent = 'Sentinel';
			requests.add(request);

			Test.startTest();
			results = CloseCase.closeCase(requests);
			Test.stopTest();

			Assert.isNotNull(results, 'Result has been received');
		}
	}
}