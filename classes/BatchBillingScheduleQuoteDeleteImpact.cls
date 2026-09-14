/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class that deletes Billing Schedules left without a Quote after their related Quote Lines are removed.
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-13619     2026-08-10      Migrated queryString to ELV_Quote__c
 */
public class BatchBillingScheduleQuoteDeleteImpact implements Database.Batchable<sObject>, Schedulable {
	private static final integer BATCH_SIZE_LIMIT = 100;
	private String queryString =
		'SELECT ' +
		'Id, ' +
		'Name, ' +
		'(SELECT Id FROM BillingsByQuoteLines__r) ' +
		'FROM Billing_Schedule__c ' +
		'WHERE Opportunity__r.isClosed = false ' +
		'AND Opportunity__r.RecordType.DeveloperName IN (\'Open\') ' +
		'AND ELV_Quote__c = null ';

	public static void executeBatch(String customQuery) {
		Database.executeBatch(new BatchBillingScheduleQuoteDeleteImpact(customQuery), BATCH_SIZE_LIMIT);
	}

	@InvocableMethod
	public static void executeBatch() {
		Database.executeBatch(new BatchBillingScheduleQuoteDeleteImpact(), BATCH_SIZE_LIMIT);
	}

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new BatchBillingScheduleQuoteDeleteImpact(), BATCH_SIZE_LIMIT);
	}

	@TestVisible
	private BatchBillingScheduleQuoteDeleteImpact() {
	}

	private BatchBillingScheduleQuoteDeleteImpact(String customQuery) {
		if (!String.isBlank(customQuery)) {
			this.queryString = customQuery;
		}
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(this.queryString);
	}

	public void execute(Database.BatchableContext BC, List<Billing_Schedule__c> billingsWithNoQuote) {
		Set<Id> billingsToDelete = new Set<Id>();
		try {
			for (Billing_Schedule__c each : billingsWithNoQuote) {
				if (!each.BillingsByQuoteLines__r.isEmpty()) {
					billingsToDelete.add(each.Id);
				}
			}
			QuoteCPQTriggerUtility.deleteBillingSchedules(billingsToDelete);
		} catch (Exception e) {
			Logger.error('BatchBillingScheduleQuoteDeleteImpact Errors', e)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}

	public void finish(Database.BatchableContext BC) {
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
				' BatchBillingScheduleQuoteDeleteImpact processed ' +
				job.TotalJobItems +
				' batches with ' +
				job.NumberOfErrors;
			if (job.ExtendedStatus != null) {
				results = results + ' failures.ExtendedStatus: ' + job.ExtendedStatus;
			}
			Logger.error('BatchBillingScheduleQuoteDeleteImpact FAILURE STATISTICS:' + results)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}
}