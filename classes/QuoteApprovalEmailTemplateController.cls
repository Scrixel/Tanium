/**
 * @Business: Controller for Visualforce Components - QuoteFinalApprover and QuoteApprovalRules
 * @Date: 07/16/2025
 * @Authors: Tanium Dev Team
 * @Request: SS-11017
 * RequestId    ModifiedDate    Description
 * SS-11017     2025-07-16      Created the class
 */
public class QuoteApprovalEmailTemplateController {
	public String quoteId { get; set; }
	public String approverId { get; set; }
	public String color { get; set; }

	public String getFinalApproverName() {
		String finalApprover = '';

		if (String.isBlank(quoteId)) {
			return finalApprover;
		}
		try {
			sbaa__Approval__c finalApproval = [
				SELECT Id, sbaa__Approver__r.Name
				FROM sbaa__Approval__c
				WHERE Quote__c = :quoteId
				ORDER BY sbaa__ApprovalStep__c DESC, Name DESC
				LIMIT 1
			];
			finalApprover = finalApproval.sbaa__Approver__r?.Name ?? '';
		} catch (Exception e) {
			Logger.error('QuoteApprovalEmailTemplateController.getFinalApproverName ERRORS', e)
				.setRecordId(quoteId)
				.addTag('apex');
			Logger.saveLog();
		}
		return finalApprover;
	}

	public List<sbaa__Approval__c> getApprovals() {
		List<sbaa__Approval__c> approvals = new List<sbaa__Approval__c>();

		if (String.isBlank(quoteId) || String.isBlank(approverId)) {
			return approvals;
		}
		approvals = [
			SELECT Id, Name, sbaa__Rule__r.Name, Reason_for_Approval__c
			FROM sbaa__Approval__c
			WHERE Quote__c = :quoteId AND sbaa__Approver__c = :approverId
		];
		return approvals;
	}

	public String getFlagUrl() {
		String flagUrl = '';
		String documentName = color + '_Flag';
		String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
		String orgId = UserInfo.getOrganizationId();

		try {
			Document doc = [SELECT Id FROM Document WHERE DeveloperName = :documentName LIMIT 1];
			flagUrl = instanceUrl + '/servlet/servlet.ImageServer?id=' + doc.Id + '&oid=' + orgId;
		} catch (Exception e) {
			Logger.error('QuoteApprovalEmailTemplateController.getFlagUrl ERRORS', e)
				.setRecordId(quoteId)
				.addTag('apex');
			Logger.saveLog();
		}
		return flagUrl;
	}
}