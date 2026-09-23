public with sharing class OppRegistrationApprovalFlowDTO {
	@AuraEnabled
	public string result;

	public static OppRegistrationApprovalFlowDTO parse(String json) {
		return (OppRegistrationApprovalFlowDTO) System.JSON.deserialize(
			json,
			OppRegistrationApprovalFlowDTO.class
		);
	}
}