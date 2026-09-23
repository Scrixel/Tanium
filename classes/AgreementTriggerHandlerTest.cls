@isTest
public class AgreementTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		String partnerAgreementRecordType = Utility.getRecordTypeIdByAPIName(
			'Apttus__APTS_Agreement__c',
			'Partner_Agreement'
		);

		Apttus__APTS_Agreement__c agreement = new Apttus__APTS_Agreement__c(
			Name = 'Amendment',
			RecordTypeId = partnerAgreementRecordType,
			Apttus__Status_Category__c = 'In Authoring',
			Apttus__Agreement_Number__c = '123457'
		);
		insert agreement;

		Apttus__Agreement_Clause__c agreementClause = new Apttus__Agreement_Clause__c();
		agreementClause.Apttus__Category__c = 'Systems Information';
		agreementClause.Apttus__Action__c = 'Final';
		agreementClause.Apttus__Agreement__c = agreement.Id;
		agreementClause.Apttus__Clause__c = AgreementTriggerHandler.NON_STANDARD_USE;
		insert agreementClause;
	}

	public static testMethod void prePopulateAmendAgreementData_WhenAgreementNameContainsAmend_SetStatusToApprovalRequired() {
		String otherAgreementRecordType = Utility.getRecordTypeIdByAPIName(
			'Apttus__APTS_Agreement__c',
			'Other_Agreement'
		);

		Test.startTest();
		Apttus__APTS_Agreement__c agreement = new Apttus__APTS_Agreement__c(
			Name = 'Amendment',
			RecordTypeId = otherAgreementRecordType,
			Apttus__Agreement_Number__c = '123457'
		);
		insert agreement;
		Test.stopTest();

		Apttus__APTS_Agreement__c agreementResult = [
			SELECT Id, Name, Apttus_Approval__Approval_Status__c
			FROM Apttus__APTS_Agreement__c
			LIMIT 1
		];

		System.assertEquals(
			AgreementTriggerHandler.AMENDMENT_APPROVAL_STATUS,
			agreementResult.Apttus_Approval__Approval_Status__c,
			'Approval Status should be the same as AgreementTriggerHandler.AMENDMENT_APPROVAL_STATUS'
		);
	}

	public static testMethod void createAccountAgreementClause_WhenInEffectStatus_CreatesAccountAgreementClause() {
		Apttus__APTS_Agreement__c agreement = [
			SELECT Id, Name, Apttus__Status_Category__c
			FROM Apttus__APTS_Agreement__c
			LIMIT 1
		];

		Test.startTest();
		agreement.Apttus__Status_Category__c = 'In Effect';
		agreement.MLA_Template_Type__c = AgreementTriggerHandler.TEMPLATE_TYPES_FOR_FINAL_ACTION[0];
		update agreement;
		Test.stopTest();

		List<APTMS_Account_Agreement_Clauses__c> accountAgreementClauseList = [
			SELECT Id
			FROM APTMS_Account_Agreement_Clauses__c
			WHERE Agreement_Names__c = :agreement.Id
		];

		System.assertEquals(
			1,
			accountAgreementClauseList.size(),
			'Account Agreement Clause should be created.'
		);
	}

	public static testMethod void deleteAccountAgreementClause_WhenNotInEffectStatus_DeletesAccountAgreementClause() {
		Apttus__APTS_Agreement__c agreement = [
			SELECT Id, Name, Apttus__Status_Category__c
			FROM Apttus__APTS_Agreement__c
			LIMIT 1
		];
		agreement.Apttus__Status_Category__c = 'In Effect';
		update agreement;

		TriggerHandler.resetRecursionLimits();

		Test.startTest();
		agreement.Apttus__Status_Category__c = 'In Signatures';
		update agreement;
		Test.stopTest();

		List<APTMS_Account_Agreement_Clauses__c> accountAgreementClauseAfterDelList = [
			SELECT Id
			FROM APTMS_Account_Agreement_Clauses__c
			WHERE Agreement_Names__c = :agreement.Id
		];
		System.assertEquals(
			0,
			accountAgreementClauseAfterDelList.size(),
			'Existing Account Agreement Clause should be deleted.'
		);
	}
}