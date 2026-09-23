/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class that creates Billing Schedule records for Opportunities whose billing amount has drifted from their primary quote's net amount.
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13619   2026-08-17    Migrated to standard Quote fields
 */
public class BatchCreateBillingScheduleRecords implements Database.Batchable<sObject>, Schedulable {
	private static final integer BATCH_SIZE_LIMIT = 1;

	private String queryString =
		'SELECT ' +
		'Id, ' +
		'CloseDate, ' +
		'( ' +
		'SELECT ' +
		'Id, ' +
		'Name, ' +
		'BillAmount__c, ' +
		'BillDate__c, ' +
		'BillingScheduleOrder__c, ' +
		'IsReverseBilling__c, ' +
		'Opportunity__c, ' +
		'PaymentType__c, ' +
		'ELV_Quote__c ' +
		'FROM BillingsByQuoteLines__r ' +
		'WHERE ELV_Quote__r.Ruby__IsPrimaryQuote__c = TRUE ' +
		'ORDER BY BillingScheduleOrder__c, BillDate__c ' +
		') ' +
		'FROM  Opportunity ' +
		'WHERE isClosed = false ' +
		'AND (Ruby__PrimaryQuote__r.ELV_QteNetTotQLBillDiscrep__c >= 1 OR Ruby__PrimaryQuote__r.ELV_QteNetTotQLBillDiscrep__c <= -1) ' +
		'AND RecordType.DeveloperName IN (\'Open\') ' +
		'AND Ruby__PrimaryQuote__c != null ' +
		'AND ' +
		'( ' +
		'Ruby__PrimaryQuote__r.ELV_ApprovalStatus__c = null ' +
		'OR ' +
		'Ruby__PrimaryQuote__r.ELV_ApprovalStatus__c IN (\'Recalled\',\'Rejected\') ' +
		') ';

	public static void executeBatch(String customQuery) {
		Database.executeBatch(new BatchCreateBillingScheduleRecords(customQuery), BATCH_SIZE_LIMIT);
	}

	@InvocableMethod
	public static void executeBatch() {
		Database.executeBatch(new BatchCreateBillingScheduleRecords(), BATCH_SIZE_LIMIT);
	}

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new BatchCreateBillingScheduleRecords(), BATCH_SIZE_LIMIT);
	}

	@TestVisible
	private BatchCreateBillingScheduleRecords() {
	}

	private BatchCreateBillingScheduleRecords(String customQuery) {
		if (!String.isBlank(customQuery)) {
			this.queryString = customQuery;
		}
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(this.queryString);
	}

	public void execute(Database.BatchableContext BC, List<Opportunity> opportunitiesToUpdate) {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);

		try {
			List<Opportunity> oppsToUpdate = [
				SELECT Id, Name, CloseDate
				FROM Opportunity
				WHERE Id IN :opportunitiesToUpdate
				FOR UPDATE
			];
			List<BillingByQuoteLine__c> billingsToInsert = BillingScheduleService.getPrimaryQuoteLinesData(
				oppsToUpdate[0].Id,
				'Opportunity'
			);
			if (!billingsToInsert.isEmpty()) {
				BillingScheduleConfiguratorController.createBillingScheduleAndRelatedRecords(
					billingsToInsert,
					oppsToUpdate[0].CloseDate,
					billingsToInsert[0].ELV_Quote__r.ELV_First_Billing_Override__c
				);
			}
		} catch (Exception e) {
			Logger.error('BatchCreateBillingScheduleRecords Errors', e)
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
				' BatchCreateBillingScheduleRecords processed ' +
				job.TotalJobItems +
				' batches with ' +
				job.NumberOfErrors;
			if (job.ExtendedStatus != null) {
				results = results + ' failures.ExtendedStatus: ' + job.ExtendedStatus;
			}
			Logger.error('BatchCreateBillingScheduleRecords FAILURE STATISTICS:' + results);
			Logger.saveLog();
		}
	}
}