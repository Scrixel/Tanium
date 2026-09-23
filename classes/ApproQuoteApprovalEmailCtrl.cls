/**
 * Controller for Visualforce Components - ApproQuoteFinalApprover and ApproQuoteApprovalRules
 * Rebuilt against Approvals Pro (appro__Approval__c), replacing the SBAA-era
 * QuoteApprovalEmailTemplateController used by the original sbaa__Approval__c components.
 */
public class ApproQuoteApprovalEmailCtrl {
	public String quoteId { get; set; }
	public String approverId { get; set; }
	public String color { get; set; }

	public String getFinalApproverName() {
		String finalApprover = '';

		if (String.isBlank(quoteId)) {
			return finalApprover;
		}
		try {
			appro__Approval__c finalApproval = [
				SELECT Id, appro__Approver__r.Name
				FROM appro__Approval__c
				WHERE Quote__c = :quoteId
				ORDER BY appro__Approval_Step__r.Category_Step_Number__c DESC, Name DESC
				LIMIT 1
			];
			finalApprover = finalApproval.appro__Approver__r?.Name ?? '';
		} catch (Exception e) {
			System.debug('ApproQuoteApprovalEmailCtrl.getFinalApproverName ERROR: ' + e.getMessage());
		}
		return finalApprover;
	}

	// Managed-package (appro__) fields on appro__Approval__c cannot be bound directly in
	// Apex Visualforce Component markup in this org (FIELD_INTEGRITY_EXCEPTION on any
	// appro__ field reference, even single-level, regardless of component access level).
	// Route through a plain wrapper so the component only ever touches ordinary Strings.
	public class ApprovalRow {
		public String recordId { get; set; }
		public String approvalName { get; set; }
		public String stepName { get; set; }
		public String reason { get; set; }
	}

	public List<ApprovalRow> getApprovalRows() {
		List<ApprovalRow> rows = new List<ApprovalRow>();

		if (String.isBlank(quoteId) || String.isBlank(approverId)) {
			return rows;
		}
		List<appro__Approval__c> approvals = [
			SELECT Id, Name, appro__Approval_Step__r.appro__Approval_Step_Name__c, appro__Approval_Reason__c
			FROM appro__Approval__c
			WHERE Quote__c = :quoteId AND appro__Approver__c = :approverId
		];
		for (appro__Approval__c approval : approvals) {
			ApprovalRow row = new ApprovalRow();
			row.recordId = approval.Id;
			row.approvalName = approval.Name;
			row.stepName = approval.appro__Approval_Step__r?.appro__Approval_Step_Name__c;
			row.reason = approval.appro__Approval_Reason__c;
			rows.add(row);
		}
		return rows;
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
			System.debug('ApproQuoteApprovalEmailCtrl.getFlagUrl ERROR: ' + e.getMessage());
		}
		return flagUrl;
	}
}