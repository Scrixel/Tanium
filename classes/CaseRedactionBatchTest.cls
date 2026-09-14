/*
 * Copyright (c) 2026 Tanium
 *
 * @BUSINESS: Test methods for class CaseRedactionBatch
 * @DATE: 2024-11-28
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-9696    2024-11-28    Created
 * SS-10213   2025-01-18    Added method to delete email messages
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-13494   2026-06-22    Updated test class
 */
@IsTest
private class CaseRedactionBatchTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'CaseTriggerHandler',
				'ContentDocumentLinkTriggerHandler',
				'FeedItemTriggerHandler'
			}
		);
		Id supportRecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Contact contact = TestFactory.buildContact(acc.Id);
			insert contact;

			List<Case> cases = new List<Case>();
			Case openCase = TestFactory.buildCase(acc.Id);
			openCase.RecordTypeId = supportRecordTypeId;
			openCase.Description = 'Open Case';
			openCase.Severity_Community__c = '3';
			cases.add(openCase);

			Case closedCaseOver90Days_1 = TestFactory.buildCase(acc.Id);
			closedCaseOver90Days_1.RecordTypeId = supportRecordTypeId;
			closedCaseOver90Days_1.Description = 'Closed Case 1';
			closedCaseOver90Days_1.Status = 'Closed';
			closedCaseOver90Days_1.ClosedDate = System.today().addDays(-91);
			closedCaseOver90Days_1.CreatedDate = System.today().addDays(-100);
			closedCaseOver90Days_1.Severity_Community__c = '1';
			cases.add(closedCaseOver90Days_1);

			Case closedCaseOver90Days_2 = TestFactory.buildCase(acc.Id);
			closedCaseOver90Days_2.RecordTypeId = supportRecordTypeId;
			closedCaseOver90Days_2.Description = 'Closed Case 2';
			closedCaseOver90Days_2.Status = 'Closed';
			closedCaseOver90Days_2.ClosedDate = System.today().addDays(-91);
			closedCaseOver90Days_2.CreatedDate = System.today().addDays(-100);
			closedCaseOver90Days_2.Severity_Community__c = '1';
			cases.add(closedCaseOver90Days_2);

			Case closedCaseUnder90Days = TestFactory.buildCase(acc.Id);
			closedCaseUnder90Days.RecordTypeId = supportRecordTypeId;
			closedCaseUnder90Days.Description = 'Closed Case Under 90 Days';
			closedCaseUnder90Days.Status = 'Closed';
			closedCaseUnder90Days.ClosedDate = System.today().addDays(-89);
			closedCaseUnder90Days.CreatedDate = System.today().addDays(-100);
			closedCaseUnder90Days.Severity_Community__c = '2';
			cases.add(closedCaseUnder90Days);

			Case closedCaseUnder365Days = TestFactory.buildCase(acc.Id);
			closedCaseUnder365Days.RecordTypeId = supportRecordTypeId;
			closedCaseUnder365Days.Description = 'Closed Case Under 365 Days';
			closedCaseUnder365Days.Status = 'Closed';
			closedCaseUnder365Days.ClosedDate = System.today().addDays(-364);
			closedCaseUnder365Days.CreatedDate = System.today().addDays(-380);
			closedCaseUnder365Days.Severity_Community__c = '2';
			cases.add(closedCaseUnder365Days);

			Case closedCaseOver365Days = TestFactory.buildCase(acc.Id);
			closedCaseOver365Days.RecordTypeId = supportRecordTypeId;
			closedCaseOver365Days.Description = 'Closed Case Over 365 Days';
			closedCaseOver365Days.Status = 'Closed';
			closedCaseOver365Days.ClosedDate = System.today().addDays(-366);
			closedCaseOver365Days.CreatedDate = System.today().addDays(-380);
			closedCaseOver365Days.Severity_Community__c = '2';
			cases.add(closedCaseOver365Days);
			insert cases;

			List<ContentVersion> contentVersions = new List<ContentVersion>();
			for (Case cs : cases) {
				contentVersions.add(
					new ContentVersion(
						Title = cs.Description,
						PathOnClient = '/' + cs.Description + '.csv',
						VersionData = Blob.valueOf(cs.Description),
						CreatedDate = System.today().addDays(-100)
					)
				);
			}
			insert contentVersions;

			List<ContentDocument> contentDocuments = [
				SELECT Id, Title, LatestPublishedVersionId
				FROM ContentDocument
			];

			List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = openCase.Id,
					ShareType = 'V',
					ContentDocumentId = contentDocuments[0].Id
				)
			);
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = closedCaseOver90Days_1.Id,
					ShareType = 'V',
					ContentDocumentId = contentDocuments[1].Id
				)
			);
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = closedCaseOver90Days_2.Id,
					ShareType = 'V',
					ContentDocumentId = contentDocuments[2].Id
				)
			);
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = closedCaseUnder90Days.Id,
					ShareType = 'V',
					ContentDocumentId = contentDocuments[3].Id
				)
			);
			insert contentDocumentLinks;

			List<EmailMessage> emailMessages = new List<EmailMessage>();
			emailMessages.add(
				TestFactory.buildEmailMessage('Test Open Case - Email', openCase.Id, openCase.Id)
			);
			emailMessages.add(
				TestFactory.buildEmailMessage(
					'Test Closed Case 1 - Email',
					closedCaseUnder90Days.Id,
					closedCaseUnder90Days.Id
				)
			);
			emailMessages.add(
				TestFactory.buildEmailMessage(
					'Test Closed Case 2 - Email',
					closedCaseOver90Days_1.Id,
					closedCaseOver90Days_1.Id
				)
			);
			emailMessages.add(
				TestFactory.buildEmailMessage(
					'Test Closed Case 3 - Email',
					closedCaseOver365Days.Id,
					closedCaseOver365Days.Id
				)
			);
			insert emailMessages;

			List<Attachment> attachments = new List<Attachment>();
			attachments.add(TestFactory.buildAttachment(emailMessages[0].Id));
			attachments.add(TestFactory.buildAttachment(emailMessages[1].Id));
			attachments.add(TestFactory.buildAttachment(emailMessages[2].Id));
			attachments.add(TestFactory.buildAttachment(emailMessages[3].Id));
			insert attachments;

			Attachment openCaseAttachment = TestFactory.buildAttachment(openCase.Id);
			Attachment closedCase1Attachment = TestFactory.buildAttachment(closedCaseOver90Days_1.Id);
			Attachment closedCase2Attachment = TestFactory.buildAttachment(closedCaseOver90Days_2.Id);
			Attachment closedCaseUnder90Attachment = TestFactory.buildAttachment(
				closedCaseUnder90Days.Id
			);
			insert new List<Attachment>{
				openCaseAttachment,
				closedCase1Attachment,
				closedCase2Attachment,
				closedCaseUnder90Attachment
			};

			FeedItem feed1ForCase1 = TestFactory.buildFeedItem(closedCaseUnder365Days.Id);
			feed1ForCase1.Body = 'test Case 1';
			FeedItem feed2ForCase1 = TestFactory.buildFeedItem(closedCaseUnder365Days.Id);
			feed2ForCase1.Body = 'Case Close Summary : XXXXX';
			FeedItem feed1ForCase2 = TestFactory.buildFeedItem(closedCaseOver365Days.Id);
			feed1ForCase2.Body = 'test Case 2';
			FeedItem feed2ForCase2 = TestFactory.buildFeedItem(closedCaseOver365Days.Id);
			feed2ForCase2.Body = 'Case Close Summary : XXXXX';
			insert new List<FeedItem>{ feed1ForCase1, feed2ForCase1, feed1ForCase2, feed2ForCase2 };
		}
	}

	@IsTest
	static void testBatchExecute_WhenMeetsCriteria_DeleteRecords() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = [SELECT Id FROM Account LIMIT 1];
			Test.startTest();
			Id jobId = Database.executeBatch(new CaseRedactionBatch(account.Id));
			Test.stopTest();

			List<ContentDocumentLink> contentDocLinks = [
				SELECT Id
				FROM ContentDocumentLink
				WHERE LinkedEntityId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_N_DAYS:90)
			];

			Assert.areEqual(
				0,
				contentDocLinks.size(),
				'Remaining Content Documents Links related to closed cases older than 90 days.'
			);

			List<Attachment> attachmentsFromEmailMessage = [
				SELECT Id
				FROM Attachment
				WHERE ParentId IN (SELECT Id FROM EmailMessage WHERE Parent.ClosedDate < LAST_n_DAYS:90)
			];
			Assert.areEqual(
				0,
				attachmentsFromEmailMessage.size(),
				'Remaining attachments related to email messages related to closed cases older than 90 days.'
			);

			List<Attachment> attachmentsFromCase = [
				SELECT Id
				FROM Attachment
				WHERE ParentId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_n_DAYS:90)
			];
			Assert.areEqual(
				0,
				attachmentsFromCase.size(),
				'Remaining Attachments related to closed cases older than 90 days.'
			);

			List<FeedItem> feedItems = [
				SELECT Id, Body
				FROM FeedItem
				WHERE ParentId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_n_DAYS:365)
			];
			Assert.areEqual(
				1,
				feedItems.size(),
				'Remaining Feed items related to closed cases older than 365 days. 1 item is retained due to missing Close Case Summary'
			);

			List<Log_Apex_Job_Details__c> logApexJobDetails = [
				SELECT
					Id,
					FeedItems_Deleted__c,
					Content_Document_Links_Deleted__c,
					Email_Message_Attachments_Deleted__c,
					Emails_Deleted__c
				FROM Log_Apex_Job_Details__c
			];
			Assert.areEqual(1, logApexJobDetails.size(), '1 Log Apex Job Details record created');

			List<Log_Apex_Jobs__c> logApexJobs = [
				SELECT
					Id,
					FeedItems_Deleted__c,
					Content_Document_Links_Deleted__c,
					Email_Message_Attachments_Deleted__c,
					Emails_Deleted__c
				FROM Log_Apex_Jobs__c
			];
			Assert.areEqual(1, logApexJobs.size(), '1 Log Apex Jobs record created');
			Assert.areEqual(
				2,
				logApexJobs[0].Content_Document_Links_Deleted__c,
				'2 Content Document Link records are deleted'
			);
			Assert.areEqual(
				2,
				logApexJobs[0].Email_Message_Attachments_Deleted__c,
				'2 EmailAttachment records are deleted'
			);
			Assert.areEqual(1, logApexJobs[0].Emails_Deleted__c, '1 Email record is deleted');
		}
	}

	@IsTest
	static void testDeleteFeedItem_WhenRecordsAreDeleted_CaseRedactionCompleteFlagIsSetToTrue() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String query =
				'SELECT Id, AccountId, ClosedDate ' +
				'FROM Case ' +
				'WHERE ClosedDate < LAST_n_DAYS:' +
				CaseRedactionBatch.DAYS_FOR_FEED_ITEM_AND_EMAIL_MESSAGE_DELETION +
				' AND Case_Redaction_Complete__c = false';

			List<Case> cases = Database.query(query);
			Map<Id, Id> caseIdToAccountId = new Map<Id, Id>();
			for (Case caseRecord : cases) {
				caseIdToAccountId.put(caseRecord.Id, caseRecord.AccountId);
			}

			Test.startTest();
			CaseRedactionBatch async = new CaseRedactionBatch();
			async.deleteFeedItem(caseIdToAccountId);
			Test.stopTest();

			List<FeedItem> feedItems = [
				SELECT Id, Body
				FROM FeedItem
				WHERE ParentId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_n_DAYS:365)
			];
			Assert.areEqual(
				1,
				feedItems.size(),
				'Feed items under a closed case over 90 days should be deleted. 1 item is retained due to missing Close Case Summary'
			);

			List<Case> casesAfterDeletion = [
				SELECT Id, Case_Redaction_Complete__c
				FROM Case
				WHERE Id IN :cases
			];

			for (Case caseRecord : casesAfterDeletion) {
				Assert.isTrue(
					caseRecord.Case_Redaction_Complete__c,
					'Case Redaction Complete flag should be set to true after records are deleted.'
				);
			}
		}
	}

	@IsTest
	static void testDeleteAttachment_WhenRecordsMeetCriteria_RecordsAreDeleted() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String query =
				'SELECT Id, AccountId, ClosedDate ' +
				'FROM Case ' +
				'WHERE ClosedDate < LAST_n_DAYS:' +
				CaseRedactionBatch.DAYS_FOR_OTHER_DELETION +
				' AND Case_Redaction_Complete__c = false';

			List<Case> cases = Database.query(query);
			Map<Id, Id> caseIdToAccountId = new Map<Id, Id>();
			for (Case caseRecord : cases) {
				caseIdToAccountId.put(caseRecord.Id, caseRecord.AccountId);
			}

			Test.startTest();
			CaseRedactionBatch async = new CaseRedactionBatch();
			async.deleteAttachment(caseIdToAccountId);
			Test.stopTest();

			List<Attachment> attachmentsFromCase = [
				SELECT Id
				FROM Attachment
				WHERE ParentId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_n_DAYS:90)
			];

			System.debug('CK22 attachmentsFromCase: ' + attachmentsFromCase);
			Assert.areEqual(
				0,
				attachmentsFromCase.size(),
				'Attachments related to closed cases older than 90 days should be deleted.'
			);
		}
	}

	@IsTest
	static void testDeleteContentDocument_WhenRecordsMeetCriteria_RecordsAreDeleted() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String query =
				'SELECT Id, AccountId, ClosedDate ' +
				'FROM Case ' +
				'WHERE ClosedDate < LAST_n_DAYS:' +
				CaseRedactionBatch.DAYS_FOR_OTHER_DELETION +
				' AND Case_Redaction_Complete__c = false';

			List<Case> cases = Database.query(query);
			Map<Id, Id> caseIdToAccountId = new Map<Id, Id>();
			for (Case caseRecord : cases) {
				caseIdToAccountId.put(caseRecord.Id, caseRecord.AccountId);
			}

			Test.startTest();
			CaseRedactionBatch async = new CaseRedactionBatch();
			async.deleteContentDocument(caseIdToAccountId);
			Test.stopTest();

			List<ContentDocumentLink> contentDocLinks = [
				SELECT Id
				FROM ContentDocumentLink
				WHERE LinkedEntityId IN (SELECT Id FROM Case WHERE ClosedDate < LAST_N_DAYS:90)
			];

			Assert.areEqual(
				0,
				contentDocLinks.size(),
				'Content Documents Links related to a closed case over 90 days should be deleted.'
			);
		}
	}

	@IsTest
	static void testDeleteEmailMessage_WhenRecordsMeetCriteria_RecordsAreDeleted() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String query =
				'SELECT Id, AccountId, ClosedDate ' +
				'FROM Case ' +
				'WHERE ClosedDate < LAST_n_DAYS:' +
				CaseRedactionBatch.DAYS_FOR_FEED_ITEM_AND_EMAIL_MESSAGE_DELETION +
				' AND Case_Redaction_Complete__c = false';
			List<Case> cases = Database.query(query);
			Map<Id, Id> caseIdToAccountId = new Map<Id, Id>();
			for (Case caseRecord : cases) {
				caseIdToAccountId.put(caseRecord.Id, caseRecord.AccountId);
			}

			List<EmailMessage> emailMessages = Database.query(
				'SELECT Id, ParentId FROM EmailMessage WHERE Parent.ClosedDate < LAST_N_DAYS:' +
					CaseRedactionBatch.DAYS_FOR_FEED_ITEM_AND_EMAIL_MESSAGE_DELETION +
					' AND Parent.Category__c != \'CLM\'' +
					' AND Parent.Recordtype.Name = \'Support\'' +
					' AND ParentId IN :cases'
			);

			Test.startTest();
			CaseRedactionBatch async = new CaseRedactionBatch();
			async.deleteEmailMessage(caseIdToAccountId);
			Test.stopTest();

			List<EmailMessage> emailMessagesPostRedaction = [
				SELECT Id
				FROM EmailMessage
				WHERE Parent.ClosedDate < LAST_n_DAYS:365
			];
			Assert.areEqual(
				0,
				emailMessagesPostRedaction.size(),
				'Remaining Email Messages related to closed cases older than 365 days.'
			);
		}
	}

	@IsTest
	static void testScheduleBatch() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String chron = '0 0 23 * * ?';
			String jobid = System.schedule(
				'testScheduledApex-CaseRedactionBatch',
				chron,
				new CaseRedactionBatch()
			);
			Test.stopTest();

			CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];

			Assert.areEqual(chron, ct.CronExpression);
		}
	}

	@IsTest
	static void testBatchExecute_WhenFails_CreatesNebulaEventLogRecords() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				Database.executeBatch(new CaseRedactionBatch('001VA00000CkSKSYA3'));
			} catch (Exception e) {
				LogEntry__c log = [SELECT Id, Message__c FROM LogEntry__c LIMIT 1];
				Assert.areEqual(true, log.Message__c.contains('NumberOfErrors: 1'));
			}
			Test.stopTest();
		}
	}
}