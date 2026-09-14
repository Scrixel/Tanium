/**
 * @Business: Controller for Lead Reject VF Page
 * @Date: 2017-06-27
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * TAN-427   2017-06-27     Initial Development
 * TAN-1050  2020-12-23     Added dependent picklist options
 * SS-7070   2024-01-20     Added redirect validation
 */
public class LeadRejectionReasonController {
	public List<wUpdate> updateSelected { get; set; }
	public string returnURL { get; set; }
	public Lead leadRecord { get; set; }
	public String errorMessage { get; set; }

	ApexPages.StandardSetController setCon;

	public LeadRejectionReasonController(ApexPages.StandardSetController controller) {
		leadRecord = new Lead();

		setCon = controller;
		updateSelected = new List<wUpdate>();
		List<Lead> lstLead = controller.getSelected();
		for (Lead x : lstLead) {
			updateSelected.add(new wUpdate(x));
		}
		returnURL = Utility.isValidRedirectUrl(ApexPages.currentPage().getParameters().get('retURL'))
			? ApexPages.currentPage().getParameters().get('retURL')
			: '/';
		errorMessage = '';
	}

	//handle update to leads
	public PageReference process() {
		//PageReference redirect = new PageReference();
		String selectedStatus = leadRecord.Status;
		String selectedReject = leadRecord.Lead_Reject_Rationale__c;

		if (
			selectedStatus == 'Reject' &&
			(selectedReject == '--Select Reason--' ||
			selectedReject == '' ||
			selectedReject == null)
		) {
			displayPageMessage(
				ApexPages.Severity.ERROR,
				'You must select reject reason if status is set to reject.'
			);
			errorMessage = 'You must select reject reason if status is set to reject.';
			return null;
		} else {
			if (selectedStatus != 'Reject')
				selectedReject = null;
			List<Lead> lstLeadToUpdate = new List<Lead>();
			for (wUpdate wrapper : updateSelected) {
				lstLeadToUpdate.add(
					new Lead(
						id = wrapper.theLead.id,
						Status = selectedStatus,
						Lead_Reject_Rationale__c = selectedReject
					)
				);
			}
			if (lstLeadToUpdate.size() > 0) {
				update lstLeadToUpdate;
			}
			errorMessage = '';
			return null;
			//return new pageReference('/' + returnURL);
		}
	}

	public Pagereference redirectBackClassic() {
		if (String.isNotBlank(errorMessage)) {
			return null;
		} else {
			return new PageReference(returnURL);
		}
	}

	private void displayPageMessage(ApexPages.Severity severity, String message) {
		ApexPages.addMessage(new ApexPages.Message(severity, message));
	}

	public class wUpdate {
		public Lead theLead { get; set; }
		public wUpdate(Lead l) {
			theLead = l;
		}
	}
}