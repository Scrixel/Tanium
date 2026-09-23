/*
 * @BUSINESS: SubmitForApprovalForFlow class
 * @DATE: 2024-07-12
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  	ModifiedDate  Comment
 * SS-8407    	2024-07-12    Submit for advanced approval called from flow - "Quote - Required for Approval"
 * SS-9651    	2024-11-07    Update class to without sharing
 */
public without sharing class SubmitForApprovalForFlow {
	@InvocableMethod(
		label='Submit for CPQ Advanced Approval'
		description='calls advanced approval process, logs exceptions in Nebula'
	)
	public static List<SendDataToFlow> submit(List<RequestDataFromFlow> requests) {
		List<SendDataToFlow> resultData = new List<SendDataToFlow>();
		SendDataToFlow result = new SendDataToFlow();
		result.msgToUser = 'SUCCESS';
		try {
			SBAA.ApprovalAPI.submit(requests[0].recordId, SBAA__Approval__c.Quote__c);
		} catch (Exception ex) {
			result.msgToUser = ex.getMessage();
			Logger.error(
					'SubmitForApprovalForFlow.submitForAdvancedApproval() ERROR' +
					'###' +
					ex.getStackTraceString() +
					'###' +
					ex.getMessage(),
					requests[0].recordId
				)
				.addTag('apex');
			Logger.saveLog();
		} finally {
			resultData.add(result);
		}
		return resultData;
	}
	public class RequestDataFromFlow {
		@InvocableVariable(required=true)
		public String recordId;
	}
	public class SendDataToFlow {
		@InvocableVariable
		public String msgToUser = '';
	}
}