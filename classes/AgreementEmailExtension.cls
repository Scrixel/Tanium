/**
 * @Business: Controller Extension for Managed Package Apttus Controller
 * @Date: 2018-04-10
 * @Author: Cumulus Vision
 * @Request: TAN-530
 * Modified  ModifiedDate   Description
 */
global class AgreementEmailExtension {
	global id approvalRequestId {
		get;
		set {
			approvalRequestId = value;
			if (approvalRequestId != null) {
				initializeData();
			}
		}
	}
	global Apttus_Approval.AgreementApprovalEmailController myReference;
	global Apttus_Approval__Approval_Request__c appRequest { get; set; }

	global AgreementEmailExtension(
		Apttus_Approval.AgreementApprovalEmailController AgreementController
	) {
		this.myReference = AgreementController;
		System.debug('myReference: ' + myReference);
	}

	private void initializeData() {
		System.debug('\n approvalRequestId: ' + approvalRequestId);
		appRequest = [
			SELECT
				Id,
				Apttus_Approval__Related_Agreement__r.Budget__r.Name,
				Apttus_Approval__Related_Agreement__r.Budget__r.Business_Department__c,
				Apttus_Approval__Related_Agreement__r.Budget__r.Business_Region__c,
				Apttus_Approval__Related_Agreement__r.Apttus__Total_Contract_Value__c,
				Apttus_Approval__SubmissionComment1__c,
				Apttus_Approval__Related_Agreement__r.Amount_Rollup__c,
				Apttus_Approval__Initial_Submitter__r.Name
			FROM Apttus_Approval__Approval_Request__c
			WHERE Id = :approvalRequestId
		];
	}
}