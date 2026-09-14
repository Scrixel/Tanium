@IsTest
private class OppRegistrationApprovalFlowTest {
	@TestSetup
	private static void makeData() {
		Lead lead = TestFactory.buildLead(
			'John',
			'Doe',
			'john.doe@taniumleadtest101.com',
			'LeadTest-101'
		);
		lead.Status = 'Marketing Qualified';
		insert lead;
	}

	@IsTest
	static void testOppRegistrationApprovalFlow() {
		Lead[] leads = [SELECT Id FROM Lead];

		List<OppRegistrationApprovalFlow.Requests> requests = new List<OppRegistrationApprovalFlow.Requests>();
		List<OppRegistrationApprovalFlow.Results> results = new List<OppRegistrationApprovalFlow.Results>();

		OppRegistrationApprovalFlow.Requests request = new OppRegistrationApprovalFlow.Requests();
		request.recordId = leads[0].Id;
		request.processName = 'Opportunity Registration';
		requests.add(request);

		Test.startTest();

		OppRegistrationApprovalFlow.getPricingRecordInvocable(requests);

		Test.stopTest();
	}
}