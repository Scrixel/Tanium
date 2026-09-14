/*
 * @BUSINESS: Controller class for LWC - caseRoscoAccountFlashMessage
 * @DATE: 2024-01-29
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-9787    2024-01-29    Initial creation
 */
public class CaseRoscoAccountFlashMsgController {
	@AuraEnabled(cacheable=true)
	public static String getRoscoAccountDetails(String accountId, String caseStatus) {
		String flashMessage = '';

		List<Rosco_Account__c> roscoAccounts = [
			SELECT Name, case_flash__c, Case_Flash_Persist__c
			FROM Rosco_Account__c
			WHERE account__c = :accountId
		];

		if (!roscoAccounts.isEmpty()) {
			flashMessage = (caseStatus == 'New')
				? roscoAccounts[0].case_flash__c
				: roscoAccounts[0].Case_Flash_Persist__c;
		}

		return flashMessage;
	}
}