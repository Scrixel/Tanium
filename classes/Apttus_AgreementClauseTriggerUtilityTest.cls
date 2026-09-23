/**
 * @Business: Standard trigger handler
 * @Date: 2023-12-07
 * @Author: Varun Shah
 */

@IsTest
public class Apttus_AgreementClauseTriggerUtilityTest {
	private static List<Apttus__Agreement_Clause__c> clausetest = new List<Apttus__Agreement_Clause__c>();
	private static Map<Id, Apttus__Agreement_Clause__c> oldMap = new Map<Id, Apttus__Agreement_Clause__c>();

	@TestSetup
	static void makeData() {
		String recordTypeId = Utility.getRecordTypeIdByAPIName(
			'Apttus__APTS_Agreement__c',
			'Partner_Agreement'
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			List<Apttus__APTS_Agreement__c> existingAgreements = new List<Apttus__APTS_Agreement__c>();
			List<Apttus__Agreement_Clause__c> clausetest = new List<Apttus__Agreement_Clause__c>();

			existingAgreements.add(
				new Apttus__APTS_Agreement__c(
					name = 'Partner Agreement',
					recordTypeId = recordTypeId,
					Apttus__Status_Category__c = 'In Authoring',
					Apttus__Agreement_Number__c = '123457'
				)
			);
			insert existingAgreements;

			for (Integer i = 0; i < 2; i++) {
				clausetest.add(TestFactory.buildClause('Test', 'Final', existingAgreements[0].Id));
			}
			insert clausetest;
		}
	}

	@isTest
	static void testChangeApprovalStatus_Status_ApprovalRequired() {
		Map<Id, Apttus__Agreement_Clause__c> oldMap = new Map<Id, Apttus__Agreement_Clause__c>();
		List<Apttus__Agreement_Clause__c> clauses = [
			SELECT Approval_Status__c
			FROM Apttus__Agreement_Clause__c
		];
		for (Apttus__Agreement_Clause__c clause : clauses) {
			oldMap.put(clause.Id, clause);
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Apttus_AgreementClauseTriggerUtility.changeStatus(clauses, oldMap);
			Test.stopTest();
		}

		List<Apttus__Agreement_Clause__c> res = [
			SELECT Approval_Status__c
			FROM Apttus__Agreement_Clause__c
			WHERE Id IN :clauses
		];
		System.assertEquals('Approval Required', res[0].Approval_Status__c);
	}
}