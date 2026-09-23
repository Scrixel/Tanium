/*************************************************************
@Name: APTS_AgreementAutoExpiryTest
@Description : Tests schedule to APTS_AgreementAutoExpiryBatch,APTS_AgreementAutoExpiryScheduler class
******************************************************************/
@isTest
private class APTS_AgreementAutoExpiryTest {
	@TestSetup
	static void makeData() {
		Account acct = TestFactory.buildAccount('Test Account');
		insert acct;

		Apttus__APTS_Agreement__c agreement = new Apttus__APTS_Agreement__c(
			Name = 'test agreement1',
			Apttus__Account__c = acct.Id,
			Apttus__Contract_Start_Date__c = Date.today() - 366,
			Agreement_Effective_Date__c = Date.today(),
			Apttus__Contract_End_Date__c = Date.today() - 1,
			Apttus_ff_Clause_Certification__c = 'No',
			Apttus__Status__c = 'Activated',
			Apttus__Status_Category__c = 'In Effect',
			Evergreen__c = false,
			Payment_terms__c = true,
			RecordTypeId = Utility.getRecordTypeIdByAPIName('Apttus__APTS_Agreement__c', 'MLA')
		);
		insert agreement;
	}

	@isTest
	static void agreementAutoExpiryBatch_WhenBatchScheduled_CreatesCronTrigger() {
		String cronExpression = '0 1 * * * ?';
		Id jobId;

		Apttus__APTS_Agreement__c inputAgreement = [
			SELECT Id, Record_Type_Name__c, Apttus__Status_Category__c, Apttus__Status__c
			FROM Apttus__APTS_Agreement__c
		];

		Test.startTest();
		System.runAs(TestFactory.getAutomationAdminUser()) {
			jobId = System.schedule(
				'ScheduleApexClassTest',
				cronExpression,
				new APTS_AgreementAutoExpiryScheduler()
			);
		}
		Test.stopTest();

		CronTrigger cronTrigger = [
			SELECT CronExpression, TimesTriggered
			FROM CronTrigger
			WHERE Id = :jobId
		];

		// Assert that the expressions are the same
		System.assertEquals(cronExpression, cronTrigger.CronExpression);
	}

	@isTest
	static void agreementAutoExpiryBatch_WhenContractEndDateInPast_MarkAgreementExpired() {
		List<Apttus__APTS_Agreement__c> agreements = [
			SELECT
				Id,
				Apttus__Status_Category__c,
				Apttus__Status__c,
				Record_Type_Name__c,
				Evergreen__c,
				Apttus__Contract_End_Date__c
			FROM Apttus__APTS_Agreement__c
		];
		System.assertNotEquals(0, agreements.size());
		Test.startTest();
		APTS_AgreementAutoExpiryBatch batch = new APTS_AgreementAutoExpiryBatch();
		batch.query =
			'SELECT ' +
			'Id, ' +
			'Apttus__Status_Category__c, ' +
			'Apttus__Status__c, ' +
			'Record_Type_Name__c, ' +
			'Evergreen__c, ' +
			'Apttus__Contract_End_Date__c ' +
			'FROM Apttus__APTS_Agreement__c';
		Database.executebatch(batch, 1);
		Test.stopTest();

		Apttus__APTS_Agreement__c resultAgreement = [
			SELECT Id, Apttus__Status_Category__c, Apttus__Status__c
			FROM Apttus__APTS_Agreement__c
		];
		System.assertEquals('Expired', resultAgreement.Apttus__Status_Category__c);
	}
}