/**
 * @DAATE: 2022-03-22
 * @AUTHOR: APPTUS
 * @BUSINESS: Auto-expire agreements.
 *
 * Modified		ModifiedDate	Description
 * SS-6622		2023-12-02		Remove record type filter and allOrNone to false
 */
global class APTS_AgreementAutoExpiryBatch implements Database.Batchable<sObject>, Database.Stateful {
	public String query = '';
	global Database.QueryLocator start(Database.BatchableContext BC) {
		// default query
		if (String.isBlank(query)) {
			return Database.getQueryLocator(
				[
					SELECT
						Id,
						Apttus__Status_Category__c,
						Apttus__Status__c,
						Record_Type_Name__c,
						Evergreen__c,
						Apttus__Contract_End_Date__c
					FROM Apttus__APTS_Agreement__c
					WHERE
						Apttus__Status_Category__c = 'In Effect'
						AND Apttus__Status__c = 'Activated'
						AND Apttus__Contract_End_Date__c < TODAY
						AND Evergreen__c = FALSE
				]
			);
		} else {
			return Database.getQueryLocator(query);
		}
	}

	global void execute(Database.BatchableContext BC, List<Apttus__APTS_Agreement__c> agreementList) {
		try {
			for (Apttus__APTS_Agreement__c agreement : agreementList) {
				agreement.Apttus__Status_Category__c = 'Expired';
				agreement.Apttus__Status__c = 'Expired';
			}
			Utility.fireUpdateOnObject(agreementList, null, false);
		} catch (Exception error) {
			Logger.error('APTS_AgreementAutoExpiryBatch Errors', error)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}

	global void finish(Database.BatchableContext BC) {
		// Check batch status - IF COMPLETED then log the statistics
		AsyncApexJob job = [
			SELECT
				Id,
				Status,
				NumberOfErrors,
				JobItemsProcessed,
				TotalJobItems,
				CreatedBy.Email,
				ExtendedStatus
			FROM AsyncApexJob
			WHERE Id = :BC.getJobId()
		];

		if (job.Status == 'Completed' && job.NumberOfErrors > 0 || Test.isRunningTest()) {
			String results =
				'NumberOfErrors: ' +
				job.NumberOfErrors +
				'.' +
				' APTS_AgreementAutoExpiryBatch processed ' +
				job.TotalJobItems +
				' batches with ' +
				job.NumberOfErrors;
			if (job.ExtendedStatus != null) {
				results = results + ' failures.ExtendedStatus: ' + job.ExtendedStatus;
			}
			Logger.error('APTS_AgreementAutoExpiryBatch FAILURE STATISTICS:' + results)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}
}