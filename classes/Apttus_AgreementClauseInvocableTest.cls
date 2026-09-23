/**
 * @Business: Test class for Apttus_AgreementClauseInvocable
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate   Description
 * SS-12145   2025-11-25     Initial Development
 */
@IsTest
private class Apttus_AgreementClauseInvocableTest {
	@TestSetup
	static void makeData() {
		String partnerAgreementRecordType = Utility.getRecordTypeIdByAPIName(
			'Apttus__APTS_Agreement__c',
			'Partner_Agreement'
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Apttus__APTS_Agreement__c agreement = new Apttus__APTS_Agreement__c(
				Name = 'Amendment',
				RecordTypeId = partnerAgreementRecordType,
				Apttus__Status_Category__c = 'In Authoring',
				Apttus__Agreement_Number__c = '123457'
			);
			insert agreement;

			Apttus__Agreement_Clause__c agreementClause = new Apttus__Agreement_Clause__c();
			agreementClause.Apttus__Text__c = 'Test Agreement Clause';
			agreementClause.Apttus__Category__c = 'Audit';
			agreementClause.Apttus__Action__c = 'Modified';
			agreementClause.Apttus__Agreement__c = agreement.Id;
			agreementClause.Apttus__Clause__c = 'Test Clause';
			agreementClause.Apttus__PrevText__c = 'Test Prev Text';
			agreementClause.Apttus__Text__c = 'Test Text';
			insert agreementClause;
		}
	}

	@IsTest
	static void testSearchNonStandard_WhenOneMatchingAgreementClause_ReturnOneUpdatedRecordsMessage() {
		List<String> results;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = Apttus_AgreementClauseInvocable.searchNonStandardTerms(
				new List<String>{ 'test' }
			);
			Test.stopTest();
		}

		Assert.isTrue(results[0].contains('Successfully updated 1 agreement clause records.'));
	}
}