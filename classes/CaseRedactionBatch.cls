/*
 * Copyright (c) 2026 Tanium
 *
 * @BUSINESS: Batch class for handling case redaction
 * @DATE: 2024-11-28
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-9696    2024-11-28    Created
 * SS-10213   2025-01-18    Updated the batch to create Log Apex Job and Log Apex Job Details Details records
 * SS-10722   2025-04-18    Limit queries to 10K records
 * SS-10883   2025-05-13    Exclude Internal Accounts
 * SS-11653   2025-09-15    Changes to constants and queries
 * SS-11773   2025-09-23    Update Case Description when fully redacted.
 * SS-13494   2026-06-22    Added logic to delete ContentDocument records (renamed method deleteContentDocumentLink to deleteContentDocument amd updated method)
 */
public without sharing class CaseRedactionBatch implements Database.Batchable<sObject>, Schedulable, Database.Stateful {
	public static final Integer DAYS_FOR_FEED_ITEM_AND_EMAIL_MESSAGE_DELETION = 366;
	public static final Integer DAYS_FOR_OTHER_DELETION = 91;
	private static final Integer MAX_LIST_SIZE = 10000;
	private Id accountId;
	final String CASE_CLOSE_SUMMARY = 'Case Close Summary';
	public Map<Id, Log_Apex_Job_Details__c> accountIdLogApexJobDetailsMap = new Map<Id, Log_Apex_Job_Details__c>();

	public CaseRedactionBatch() {
		this(null);
	}

	public CaseRedactionBatch(Id accountId) {
		this.accountId = accountId;
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		String query =
			'SELECT Id, AccountId, ClosedDate, RecordType.DeveloperName, Account.Name ' +
			'FROM Case ' +
			'WHERE ClosedDate < LAST_n_DAYS:' +
			DAYS_FOR_OTHER_DELETION +
			' AND Case_Redaction_Complete__c = false ' +
			' AND RecordType.DeveloperName = \'Support\'';
		if (accountId != null) {
			query += 'AND AccountId =\'' + accountId + '\' ';
		}
		return Database.getQueryLocator(query);
	}

	public void execute(Database.BatchableContext bc, List<Case> cases) {
		TriggerHandler.bypass(
			new List<String>{
				'CaseTriggerHandler',
				'FeedItemTriggerHandler',
				'AttachmentTriggerHandler'
			}
		);
		Set<Id> caseIds = (new Map<Id, Case>(cases)).keySet();
		Map<Id, Id> caseIdAccountIdMap = new Map<Id, Id>();
		String accountName;

		for (Case caseRecord : cases) {
			accountName = '' + caseRecord.Account.Name;
			if (!accountName.toLowerCase().contains('tanium')) {
				caseIdAccountIdMap.put(caseRecord.Id, caseRecord.AccountId);
			}
		}

		deleteFeedItem(caseIdAccountIdMap);
		deleteAttachment(caseIdAccountIdMap);
		deleteContentDocument(caseIdAccountIdMap);
		deleteEmailMessageAttachment(caseIdAccountIdMap);
		deleteEmailMessage(caseIdAccountIdMap);
	}

	@TestVisible
	private void deleteFeedItem(Map<Id, Id> caseIdAccountIdMap) {
		List<FeedItem> feedItemsToDelete = new List<FeedItem>();
		List<Case> casesToUpdate = new List<Case>();
		Set<Id> caseIdsForUpdate = new Set<Id>();
		Set<Id> caseIds = caseIdAccountIdMap.keyset();
		Map<Id, List<FeedItem>> accountIdFeedItemIdsMap = new Map<Id, List<FeedItem>>();
		Set<Id> partialRedactionCaseIds = new Set<Id>();

		List<FeedItem> feedItems = Database.query(
			'SELECT Id, Body, ParentId FROM FeedItem WHERE ParentId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_n_DAYS:' +
				DAYS_FOR_FEED_ITEM_AND_EMAIL_MESSAGE_DELETION +
				' AND Id IN :caseIds) ORDER BY ParentId'
		);

		for (FeedItem feedItem : feedItems) {
			if (
				Utility.isCase(feedItem.ParentId) &&
				(String.isBlank(feedItem.Body) || !feedItem.Body.containsIgnoreCase(CASE_CLOSE_SUMMARY))
			) {
				if (feedItemsToDelete.size() < MAX_LIST_SIZE) {
					feedItemsToDelete.add(feedItem);
				} else {
					partialRedactionCaseIds.add(feedItem.ParentId);
				}
			}
			caseIdsForUpdate.add(feedItem.ParentId);
		}

		for (FeedItem feedItemToDelete : feedItemsToDelete) {
			Id accountId = caseIdAccountIdMap.get(feedItemToDelete.ParentId);
			if (accountIdFeedItemIdsMap.containsKey(accountId)) {
				List<FeedItem> feedItemList = accountIdFeedItemIdsMap.get(accountId);
				feedItemList.add(feedItemToDelete);
				accountIdFeedItemIdsMap.put(accountId, feedItemList);
			} else {
				accountIdFeedItemIdsMap.put(accountId, new List<FeedItem>{ feedItemToDelete });
			}
		}

		for (Id accountId : accountIdFeedItemIdsMap.keySet()) {
			Log_Apex_Job_Details__c logApexJobDetail;
			if (accountIdLogApexJobDetailsMap.containsKey(accountId)) {
				logApexJobDetail = accountIdLogApexJobDetailsMap.get(accountId);
				logApexJobDetail.FeedItems_Deleted__c = accountIdFeedItemIdsMap.get(accountId).size();
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			} else {
				logApexJobDetail = new Log_Apex_Job_Details__c(
					Account__c = accountId,
					Account_18ID__c = accountId,
					FeedItems_Deleted__c = accountIdFeedItemIdsMap.get(accountId).size()
				);
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			}
		}

		List<Database.DeleteResult> deleteResults = Database.delete(feedItemsToDelete, false);
		logResults(null, deleteResults, 'CaseRedactionBatch.deleteFeedItem Errors');

		for (Id caseId : caseIdsForUpdate) {
			if (partialRedactionCaseIds.contains(caseId)) {
				continue;
			}
			Case caseRec = new Case();
			caseRec.Id = caseId;
			caseRec.Case_Redaction_Complete__c = true;
			caseRec.Description = 'Description text redacted';
			casesToUpdate.add(caseRec);
		}

		Database.SaveResult[] updateResults = Database.update(casesToUpdate, false);
		logResults(updateResults, null, 'CaseRedactionBatch.deleteFeedItem Errors');
	}

	@TestVisible
	private void deleteAttachment(Map<Id, Id> caseIdAccountIdMap) {
		Map<Id, List<Attachment>> accountIdToAttachmentsMap = new Map<Id, List<Attachment>>();
		Set<Id> caseIds = caseIdAccountIdMap.keyset();
		List<Attachment> attachmentsToDelete = Database.query(
			'SELECT Id, ParentId FROM Attachment WHERE ParentId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_n_DAYS:' +
				DAYS_FOR_OTHER_DELETION +
				' AND Id IN :caseIds) LIMIT ' +
				MAX_LIST_SIZE
		);

		for (Attachment attachmentToDelete : attachmentsToDelete) {
			Id accountId = caseIdAccountIdMap.get(attachmentToDelete.ParentId);
			if (accountIdToAttachmentsMap.containsKey(accountId)) {
				List<Attachment> attachments = accountIdToAttachmentsMap.get(accountId);
				attachments.add(attachmentToDelete);
				accountIdToAttachmentsMap.put(accountId, attachments);
			} else {
				accountIdToAttachmentsMap.put(accountId, new List<Attachment>{ attachmentToDelete });
			}
		}

		for (Id accountId : accountIdToAttachmentsMap.keySet()) {
			Log_Apex_Job_Details__c logApexJobDetail;
			if (accountIdLogApexJobDetailsMap.containsKey(accountId)) {
				logApexJobDetail = accountIdLogApexJobDetailsMap.get(accountId);
				logApexJobDetail.Attachments_Deleted__c = accountIdToAttachmentsMap.get(accountId)
					.size();
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			} else {
				logApexJobDetail = new Log_Apex_Job_Details__c(
					Account__c = accountId,
					Account_18ID__c = accountId,
					Attachments_Deleted__c = accountIdToAttachmentsMap.get(accountId).size()
				);
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			}
		}

		List<Database.DeleteResult> deleteResults = Database.delete(attachmentsToDelete, false);
		logResults(null, deleteResults, 'CaseRedactionBatch.deleteAttachment Errors');
	}

	@TestVisible
	private void deleteContentDocument(Map<Id, Id> caseIdAccountIdMap) {
		Set<Id> caseIds = caseIdAccountIdMap.keyset();
		Map<Id, List<ContentDocumentLink>> accountIdToAContentDocumentLinksMap = new Map<Id, List<ContentDocumentLink>>();

		List<ContentDocumentLink> contentDocLinksToDelete = Database.query(
			'SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocument.CreatedDate < LAST_N_DAYS:' +
				DAYS_FOR_OTHER_DELETION +
				' AND LinkedEntityId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_N_DAYS:' +
				DAYS_FOR_OTHER_DELETION +
				' AND Category__c != \'CLM\'' +
				' AND Id IN :caseIds) LIMIT ' +
				MAX_LIST_SIZE
		);

		for (ContentDocumentLink contentDocLinkToDelete : contentDocLinksToDelete) {
			Id accountId = caseIdAccountIdMap.get(contentDocLinkToDelete.LinkedEntityId);
			if (accountIdToAContentDocumentLinksMap.containsKey(accountId)) {
				List<ContentDocumentLink> contentDocLinks = accountIdToAContentDocumentLinksMap.get(
					accountId
				);
				contentDocLinks.add(contentDocLinkToDelete);
				accountIdToAContentDocumentLinksMap.put(accountId, contentDocLinks);
			} else {
				accountIdToAContentDocumentLinksMap.put(
					accountId,
					new List<ContentDocumentLink>{ contentDocLinkToDelete }
				);
			}
		}

		for (Id accountId : accountIdToAContentDocumentLinksMap.keySet()) {
			Log_Apex_Job_Details__c logApexJobDetail;
			if (accountIdLogApexJobDetailsMap.containsKey(accountId)) {
				logApexJobDetail = accountIdLogApexJobDetailsMap.get(accountId);
				logApexJobDetail.Content_Document_Links_Deleted__c = accountIdToAContentDocumentLinksMap.get(
						accountId
					)
					.size();
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			} else {
				logApexJobDetail = new Log_Apex_Job_Details__c(
					Account__c = accountId,
					Account_18ID__c = accountId,
					Content_Document_Links_Deleted__c = accountIdToAContentDocumentLinksMap.get(
							accountId
						)
						.size()
				);
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			}
		}
		Set<ContentDocument> contentDocumentsToDelete = new Set<ContentDocument>();
		for (ContentDocumentLink contentDocLinkToDelete : contentDocLinksToDelete) {
			contentDocumentsToDelete.add(
				new ContentDocument(Id = contentDocLinkToDelete.ContentDocumentId)
			);
		}
		List<Database.DeleteResult> deleteResults = Database.delete(
			new List<ContentDocument>(contentDocumentsToDelete),
			false
		);
		logResults(null, deleteResults, 'CaseRedactionBatch.deleteContentDocument Errors');
	}

	@TestVisible
	private void deleteEmailMessageAttachment(Map<Id, Id> caseIdAccountIdMap) {
		Map<Id, Id> emailMessageIdCaseIdMap = new Map<Id, Id>();
		Map<Id, List<Attachment>> accountIdToEmailMessageAttachmentsMap = new Map<Id, List<Attachment>>();
		Set<Id> caseIds = caseIdAccountIdMap.keyset();
		List<EmailMessage> emailMessages = Database.query(
			'SELECT Id, ParentId FROM EmailMessage WHERE Parent.ClosedDate < LAST_N_DAYS:' +
				DAYS_FOR_OTHER_DELETION +
				' AND Parent.Category__c != \'CLM\'' +
				' AND ParentId IN :caseIds LIMIT ' +
				MAX_LIST_SIZE
		);

		List<Attachment> attachmentsToDelete = Database.query(
			'SELECT Id, ParentId FROM Attachment WHERE Parent.Type = \'EmailMessage\'' +
				' AND ParentId IN :emailMessages LIMIT ' +
				MAX_LIST_SIZE
		);

		for (EmailMessage emailMessage : emailMessages) {
			emailMessageIdCaseIdMap.put(emailMessage.Id, emailMessage.ParentId);
		}

		for (Attachment attachmentToDelete : attachmentsToDelete) {
			Id caseId = emailMessageIdCaseIdMap.get(attachmentToDelete.ParentId);
			Id accountId = caseIdAccountIdMap.get(caseId);

			if (accountIdToEmailMessageAttachmentsMap.containsKey(accountId)) {
				List<Attachment> attachments = accountIdToEmailMessageAttachmentsMap.get(accountId);
				attachments.add(attachmentToDelete);
				accountIdToEmailMessageAttachmentsMap.put(accountId, attachments);
			} else {
				accountIdToEmailMessageAttachmentsMap.put(
					accountId,
					new List<Attachment>{ attachmentToDelete }
				);
			}
		}

		for (Id accountId : accountIdToEmailMessageAttachmentsMap.keySet()) {
			Log_Apex_Job_Details__c logApexJobDetail;
			if (accountIdLogApexJobDetailsMap.containsKey(accountId)) {
				logApexJobDetail = accountIdLogApexJobDetailsMap.get(accountId);
				logApexJobDetail.Email_Message_Attachments_Deleted__c = accountIdToEmailMessageAttachmentsMap.get(
						accountId
					)
					.size();
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			} else {
				logApexJobDetail = new Log_Apex_Job_Details__c(
					Account__c = accountId,
					Account_18ID__c = accountId,
					Email_Message_Attachments_Deleted__c = accountIdToEmailMessageAttachmentsMap.get(
							accountId
						)
						.size()
				);
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			}
		}

		Database.DeleteResult[] deleteResults = Database.delete(attachmentsToDelete, false);
		logResults(null, deleteResults, 'CaseRedactionBatch.deleteEmailMessageAttachment Errors');
	}

	@TestVisible
	private void deleteEmailMessage(Map<Id, Id> caseIdAccountIdMap) {
		Map<Id, List<EmailMessage>> accountIdToEmailMessagesMap = new Map<Id, List<EmailMessage>>();
		Set<Id> caseIds = caseIdAccountIdMap.keyset();
		List<EmailMessage> emailMessagesToDelete = Database.query(
			'SELECT Id, ParentId FROM EmailMessage WHERE Parent.ClosedDate < LAST_N_DAYS:' +
				DAYS_FOR_FEED_ITEM_AND_EMAIL_MESSAGE_DELETION +
				' AND Parent.Category__c != \'CLM\'' +
				' AND ParentId IN :caseIds LIMIT ' +
				MAX_LIST_SIZE
		);

		for (EmailMessage emailMessage : emailMessagesToDelete) {
			Id accountId = caseIdAccountIdMap.get(emailMessage.ParentId);

			if (accountIdToEmailMessagesMap.containsKey(accountId)) {
				List<EmailMessage> emailMessages = accountIdToEmailMessagesMap.get(accountId);
				emailMessages.add(emailMessage);
				accountIdToEmailMessagesMap.put(accountId, emailMessages);
			} else {
				accountIdToEmailMessagesMap.put(accountId, new List<EmailMessage>{ emailMessage });
			}
		}

		for (Id accountId : accountIdToEmailMessagesMap.keySet()) {
			Log_Apex_Job_Details__c logApexJobDetail;
			if (accountIdLogApexJobDetailsMap.containsKey(accountId)) {
				logApexJobDetail = accountIdLogApexJobDetailsMap.get(accountId);
				logApexJobDetail.Emails_Deleted__c = accountIdToEmailMessagesMap.get(accountId).size();
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			} else {
				logApexJobDetail = new Log_Apex_Job_Details__c(
					Account__c = accountId,
					Account_18ID__c = accountId,
					Emails_Deleted__c = accountIdToEmailMessagesMap.get(accountId).size()
				);
				accountIdLogApexJobDetailsMap.put(accountId, logApexJobDetail);
			}
		}

		Database.DeleteResult[] deleteResults = Database.delete(emailMessagesToDelete, false);
		logResults(null, deleteResults, 'CaseRedactionBatch.deleteEmailMessage Errors');
	}

	@TestVisible
	private void logResults(
		Database.SaveResult[] updateResults,
		Database.DeleteResult[] deleteResults,
		String message
	) {
		if (updateResults != null) {
			Logger.logDatabaseErrors(LoggingLevel.ERROR, message, updateResults)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}

		if (deleteResults != null) {
			Logger.logDatabaseErrors(LoggingLevel.ERROR, message, deleteResults)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}

	public void finish(Database.BatchableContext bc) {
		AsyncApexJob job = [
			SELECT
				Id,
				Status,
				NumberOfErrors,
				JobItemsProcessed,
				TotalJobItems,
				CreatedBy.Email,
				ExtendedStatus,
				ApexClassId,
				CompletedDate,
				JobType
			FROM AsyncApexJob
			WHERE Id = :BC.getJobId()
		];

		if (accountIdLogApexJobDetailsMap != null) {
			Log_Apex_Jobs__c logApexJobs = new Log_Apex_Jobs__c();
			logApexJobs.ApexClassId__c = job.ApexClassId;
			logApexJobs.CompletedDate__c = job.CompletedDate;
			logApexJobs.AsyncApexJobId__c = job.Id;
			logApexJobs.JobItemsProcessed__c = job.JobItemsProcessed;
			logApexJobs.JobType__c = job.JobType;
			logApexJobs.NumberOfErrors__c = job.NumberOfErrors;
			logApexJobs.Status__c = job.Status;
			Database.SaveResult saveResult = Database.insert(logApexJobs, false);
			if (!saveResult.isSuccess()) {
				Logger.error('CaseRedactionBatch.finish Errors', saveResult.getErrors()[0].getMessage())
					.addTag('apex');
				Logger.saveLog();
			}

			for (Log_Apex_Job_Details__c logApexJobDetail : accountIdLogApexJobDetailsMap.values()) {
				logApexJobDetail.Log_Apex_Jobs__c = logApexJobs.Id;
			}

			Database.SaveResult[] saveResults2 = Database.insert(
				accountIdLogApexJobDetailsMap.values(),
				false
			);

			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'CaseRedactionBatch.finish Errors',
					saveResults2
				)
				.addTag('apex');
			Logger.saveLog();
		}

		if ((job.Status == 'Completed' && job.NumberOfErrors > 0) || Test.isRunningTest()) {
			String results =
				'NumberOfErrors: ' +
				job.NumberOfErrors +
				'.' +
				' CaseRedactionBatch processed ' +
				job.TotalJobItems +
				' batches with ' +
				job.NumberOfErrors;
			if (job.ExtendedStatus != null) {
				results = results + ' failures.ExtendedStatus: ' + job.ExtendedStatus;
			}
			Logger.error('CaseRedactionBatch FAILURE STATISTICS:' + results);
			Logger.saveLog();
		}
	}

	public void execute(SchedulableContext sc) {
		CaseRedactionBatch batch = new CaseRedactionBatch();
		Database.executebatch(batch, 200);
	}
}