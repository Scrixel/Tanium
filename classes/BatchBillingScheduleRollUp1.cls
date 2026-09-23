/*
	Batch rolls up following fields on Opportunity from attached Billing Schedules having Billing Order 1:- 
	1) InitialGrossBillingAmountNew__c
	2) InitialNetBillingAmountNew__c
	3) Calls BatchBillingScheduleRollUp2 that aggregates following fields on Opportunity from attached Billing Schedules:-
		a) BillingScheduleTotalAmountNew__c
		b) BillingScheduleTotalNetAmountPaidNew__c
		c) BillingScheduleTotalCount__c
*/
global class BatchBillingScheduleRollUp1 implements Database.Batchable<sObject>, Schedulable {
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
		'WHERE isClosed = false ';
	Map<Id, Opportunity> oppsToUpdateInMap = new Map<Id, Opportunity>();

	// custom query can be passed when needed
	global BatchBillingScheduleRollUp1(String customQuery) {
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
			BillingScheduleUtility.calculateInitialBillingRelatedFldsOnOppForUpsert(
				oppsToUpdateInMap,
				new List<Billing_Schedule__c>(
					[
						SELECT
							Id,
							Billing_Amount__c,
							Billing_Amount_Net_Rollup__c,
							Billing_Order__c,
							Opportunity__c
						FROM Billing_Schedule__c
						WHERE Opportunity__c IN :oppsToUpdateInMap.keySet() AND Billing_Order__c = 1
					]
				)
			);
			Utility.fireUpdateOnObject(oppsToUpdateInMap.values(), null, false);
		} catch (Exception e) {
			Logger.error('BatchBillingScheduleRollUp1 Errors', e)
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

		if ((job.Status == 'Completed' && job.NumberOfErrors > 0) || Test.isRunningTest()) {
			String results =
				'NumberOfErrors: ' +
				job.NumberOfErrors +
				'.' +
				' BatchBillingScheduleRollUp1 processed ' +
				job.TotalJobItems +
				' batches with ' +
				job.NumberOfErrors;
			if (job.ExtendedStatus != null) {
				results = results + ' failures.ExtendedStatus: ' + job.ExtendedStatus;
			}
			Logger.error('BatchBillingScheduleRollUp1 FAILURE STATISTICS:' + results);
			Logger.saveLog();

		}
		/* 
			Calculate the aggregate fields on Opp:-
			a) BillingScheduleTotalAmountNew__c
			b) BillingScheduleTotalNetAmountPaidNew__c
			c) BillingScheduleTotalCount__c
		*/
		BatchBillingScheduleRollUp2 batch = new BatchBillingScheduleRollUp2(query);
		Database.executeBatch(batch, 200);
	}

	global void execute(SchedulableContext sc) {
		BatchBillingScheduleRollUp1 batch = new BatchBillingScheduleRollUp1('');
		Database.executebatch(batch, 200);
	}
}