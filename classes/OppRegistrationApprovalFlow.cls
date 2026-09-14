/**
 * @Business: Standard trigger handler
 * @Date: 2020-11-05
 * @Author: Cumulus Vision
 * ModifiedBy   ModifiedDate   Comment
 * TAN-1007     2020-11-05     Initial Development
 * TAN-1048     2020-12-29     make Approval Process name dynamic to a custom setting / metadata type.
 **/
global class OppRegistrationApprovalFlow {
	@InvocableMethod
	public static List<Results> getPricingRecordInvocable(List<Requests> requests) {
		List<Lead> lead = [SELECT id FROM Lead WHERE id = :requests[0].recordId];
		Results curResult = new Results();
		boolean approvalSubmitted = false;
		map<string, object> results_map = submitApprovalRequest(
			requests[0].recordId,
			requests[0].processName
		);
		system.debug(results_map);
		OppRegistrationApprovalFlowDTO approvalResult = OppRegistrationApprovalFlowDTO.parse(
			JSON.serialize(results_map)
		);
		curResult.approvalResult = approvalResult;
		List<Results> resultsList = new List<Results>();
		resultsList.add(curResult);
		return resultsList;
	}

	private static map<string, string> submitApprovalRequest(
		string recordId,
		string apporvalProcessName
	) {
		Automation_Management__c am = Automation_Management__c.getInstance();
		// Create an approval request for the account
		Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
		req1.setComments('Submitting Opportunity Registration for approval.');
		req1.setObjectId(recordId);
		req1.setSubmitterId(userinfo.getUserId());

		// Submit the record to specific process and skip the criteria evaluation
		req1.setProcessDefinitionNameOrId(apporvalProcessName);
		req1.setSkipEntryCriteria(true);
		// Submit the approval request for the lead
		map<string, string> results_map = new Map<string, string>();
		Approval.ProcessResult result;
		try {
			result = Approval.process(req1);
			results_map.put('result', 'Approval Request Submitted Successfully.');
		} catch (Exception e) {
			results_map.put(
				'result',
				'There was a problem submitting request for Approval. Please see system administrator. Exception: ' +
				e
			);
		}
		return results_map;
	}

	global class Requests {
		@InvocableVariable
		global string recordId;

		@InvocableVariable
		global string processName;
	}

	global class Results {
		@InvocableVariable
		global OppRegistrationApprovalFlowDTO approvalResult;
	}
}