/**
 * @Business: Controller class for NFR VF Page (to Create/Edit NFR Record)
 * @Date: 2019-04-01
 * @Author: Cumulus Vision
 * @Request: TAN-762
 * Modified  ModifiedDate   Description
 * TAN-762   2019-04-01     Initial development
 */

public class NFRController {
	public NFR__c newNFR { get; set; }
	public Boolean isNFRNotCreated { get; set; }

	public NFRController() {
		isNFRNotCreated = true;
		newNFR = new NFR__c();
	}

	// Create NFR record on submit
	public PageReference save() {
		try {
			insert newNFR;

			isNFRNotCreated = false;
		} catch (Exception ex) {
			isNFRNotCreated = true;
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, ex.getMessage()));
		}

		return null;
	}
}