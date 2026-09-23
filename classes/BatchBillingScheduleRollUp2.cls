/*
	This Apex class aggegates following fields on Opportunity:- 
	1) BillingScheduleTotalAmountNew__c
	2) BillingScheduleTotalNetAmountPaidNew__c
	3) BillingScheduleTotalCount__c
*/
global class BatchBillingScheduleRollUp2 implements Database.Batchable<sObject>, Schedulable {
	// default query
	String query =
		'SELECT ' +
		'Id, ' +
		'BillingScheduleTotalAmountNew__c, ' +
		'BillingScheduleTotalNetAmountPaidNew__c, ' +
		'BillingScheduleTotalCount__c, ' +
		'InitialBillingDateNew__c, ' +
		'InitialGrossBillingAmountNew__c, ' +
		'InitialNetBillingAmountNew__c ' +
		'FROM Opportunity ' +
		'WHERE isClosed = false';
	Map<Id, Opportunity> oppsToUpdateInMap = new Map<Id, Opportunity>();

	global BatchBillingScheduleRollUp2(String customQuery) {
		if (!String.isBlank(customQuery)) {
			query = customQuery;
		}
	}

	global Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<Opportunity> oppsToUpdate) {
		try {
			oppsToUpdateInMap = new Map<Id, Opportunity>(
				[
					SELECT
						Id,
						BillingScheduleTotalAmountNew__c,
						BillingScheduleTotalNetAmountPaidNew__c,
						BillingScheduleTotalCount__c,
						InitialBillingDateNew__c,
						InitialGrossBillingAmountNew__c,
						InitialNetBillingAmountNew__c
					FROM Opportunity
					WHERE ID IN :oppsToUpdate
					FOR UPDATE
				]
			);
			BillingScheduleUtility.calculateBillingScheduleTotalAmount(oppsToUpdateInMap);
			Utility.fireUpdateOnObject(oppsToUpdateInMap.values(), null, false);
		} catch (Exception e) {
			Logger.error('BatchBillingScheduleRollUp2 Errors', e)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}

	global void finish(Database.BatchableContext BC) {
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

		if ((job.Status == 'Completed' && job.NumberOfErrors > 0) || Test.isRunningTest()) {
			String results =
				'NumberOfErrors: ' +
				job.NumberOfErrors +
				'.' +
				' BatchBillingScheduleRollUp2 processed ' +
				job.TotalJobItems +
				' batches with ' +
				job.NumberOfErrors;
			if (job.ExtendedStatus != null) {
				results = results + ' failures.ExtendedStatus: ' + job.ExtendedStatus;
			}
			Logger.error('BatchBillingScheduleRollUp2 FAILURE STATISTICS:' + results);
			Logger.saveLog();
		}
	}

	global void execute(SchedulableContext sc) {
		BatchBillingScheduleRollUp2 batch = new BatchBillingScheduleRollUp2('');
		Database.executebatch(batch, 200);
	}
}