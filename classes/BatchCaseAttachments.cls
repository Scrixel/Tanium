global class BatchCaseAttachments implements Database.Batchable<sObject>, Schedulable {
	String query =
		'SELECT Id, (SELECT Id FROM Attachments) ' +
		'FROM Case ' +
		'WHERE ClosedDate < LAST_n_DAYS:91';
	List<Case> casesToUpdate = new List<Case>();
	Set<Id> parentIds = new Set<Id>();
	List<Attachment> attachmentsToDelete = new List<Attachment>();
	Database.DeleteResult[] results;

	global BatchCaseAttachments() {
	}

	global BatchCaseAttachments(String customQuery) {
		if (!String.isBlank(customQuery)) {
			query = customQuery;
		}
	}

	global Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<Case> casesToUpdate) {
		try {
			casesToUpdate = new List<Case>(
				[SELECT Id, (SELECT Id FROM Attachments) FROM Case WHERE Id IN :casesToUpdate]
			);
			for (Case eachCase : casesToUpdate) {
				if (!eachCase.attachments.isEmpty()) {
					attachmentsToDelete.addAll(eachCase.attachments);
				}
			}
			results = Database.delete(attachmentsToDelete, false);
		} catch (Exception e) {
			Logger.error('BatchCaseAttachments ERRORS :', e);
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
			Logger.error('BatchCaseAttachments FAILURE STATISTICS:' + results);
			Logger.saveLog();
		}
	}

	global void execute(SchedulableContext sc) {
		BatchCaseAttachments batch = new BatchCaseAttachments('');
		Database.executebatch(batch, 200);
	}
}