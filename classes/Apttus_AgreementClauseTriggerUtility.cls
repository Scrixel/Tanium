/**
 * @Business: Standard trigger handler
 * @Date: 2023-12-07
 * @Author: Varun Shah
 */

public class Apttus_AgreementClauseTriggerUtility {
	@TestVisible
	private static final String APPROVAL_REQUIRED = 'Approval Required';

	public static void changeStatus(
		List<Apttus__Agreement_Clause__c> newClause,
		Map<Id, Apttus__Agreement_Clause__c> oldMap
	) {
		for (Apttus__Agreement_Clause__c clause : newClause) {
			if (
				clause.Approval_Status__c != oldMap.get(clause.Id).Approval_Status__c &&
				clause.Approval_Status__c != APPROVAL_REQUIRED
			) {
				clause.Approval_Status__c = APPROVAL_REQUIRED;
			}
		}
	}

	public static void changeStatus(List<Apttus__Agreement_Clause__c> newClause) {
		for (Apttus__Agreement_Clause__c clause : newClause) {
			clause.Approval_Status__c = APPROVAL_REQUIRED;
		}
	}
}