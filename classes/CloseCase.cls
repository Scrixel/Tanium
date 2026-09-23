/*
 * @BUSINESS: Invocable class for handling case close
 * @DATE: 2025-02-21
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-8178    2025-02-21    Created
 */
global with sharing class CloseCase {
	@InvocableMethod(label='Close Case')
	global static List<Results> closeCase(List<Requests> requestList) {
		List<Results> responseWrapper = new List<Results>();
		Results response = new Results();
		String result = RoscoClose.saveCase(
			requestList[0].caseId,
			requestList[0].problem,
			requestList[0].solution,
			requestList[0].kb,
			requestList[0].spam,
			requestList[0].incidentCause,
			requestList[0].resolutionCode,
			requestList[0].standardEmail,
			requestList[0].psEmail,
			requestList[0].hydra,
			requestList[0].component,
			requestList[0].subcomponent
		);
		response.result = result;
		responseWrapper.add(response);

		return responseWrapper;
	}

	global class Requests {
		@InvocableVariable(required=true)
		global String caseId;
		@InvocableVariable
		global String problem;
		@InvocableVariable
		global String solution;
		@InvocableVariable
		global String kb;
		@InvocableVariable
		global String spam;
		@InvocableVariable
		global String incidentCause;
		@InvocableVariable
		global String resolutionCode;
		@InvocableVariable
		global String standardEmail;
		@InvocableVariable
		global String psEmail;
		@InvocableVariable
		global String hydra;
		@InvocableVariable
		global String component;
		@InvocableVariable
		global String subcomponent;
	}

	global class Results {
		@InvocableVariable
		global String result;
	}
}