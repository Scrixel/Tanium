/**
 * @Business: Standard trigger handler
 * @Date: 2023-12-07
 * @Author: Varun Shah
 */

@IsTest
private class Apttus_AgreementClauseTriggerHandlerTest {
	private static List<Apttus__Agreement_Clause__c> clausetest = new List<Apttus__Agreement_Clause__c>();

	@TestSetup
	static void makeData() {
		String recordTypeId = Utility.getRecordTypeIdByAPIName(
			'Apttus__APTS_Agreement__c',
			'Partner_Agreement'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Apttus__APTS_Agreement__c> existingAgreements = new List<Apttus__APTS_Agreement__c>();
			existingAgreements.add(
				new Apttus__APTS_Agreement__c(
					name = 'Amendment',
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

	@IsTest
	static void testChangeApprovalStatus_Status_ApprovalRequired() {
		List<Apttus__Agreement_Clause__c> clauses = [
			SELECT Approval_Status__c
			FROM Apttus__Agreement_Clause__c
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			for (Apttus__Agreement_Clause__c clause : clauses) {
				clause.Approval_Status__c = 'Approved';
			}
			update clauses;
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