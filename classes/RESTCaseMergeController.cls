@RestResource(urlMapping='/CaseMerge/*')
global with sharing class RESTCaseMergeController {
	@HttpGet
	global static String doGet() {
		RestRequest req = RestContext.request;
		RestResponse res = RestContext.response;
		//String caseNumber = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
		//Case result = [SELECT Id, CaseNumber, Subject, Status FROM Case WHERE CaseNumber = :caseNumber];
		return 'OK';
	}

	@HttpPost
	global static String mergeIntoParentCase(String parentCaseNumber, String mergeCaseNumber) {
		System.debug('Parent Case: ' + parentCaseNumber);
		System.debug('Merging Case: ' + mergeCaseNumber);

		// What are the things we need to pull over / re-parent:
		// attachment
		// case contact role?
		// case team member?
		// email message(s) with attachments
		// chatter feed?
		// case comment
		// case solution
		// predefined case team record
		// event
		// task
		// Fun fact: some shit can't be re-parented .. it has to be copied.

		// Am i hitting all of these?
		// Attachment
		// CaseComment
		// EmailMessage (and attachments)
		// Task
		// Event
		// CaseFeed

		Case[] parentCaseList = [
			SELECT Id, CaseNumber, AccountId, OwnerId
			FROM case
			WHERE CaseNumber = :parentCaseNumber
		];
		Case parentCase = parentCaseList[0];
		Case[] mergeCaseList = [
			SELECT Id, CaseNumber, AccountId, Status, OwnerId
			FROM case
			WHERE CaseNumber = :mergeCaseNumber
		];
		Case mergeCase = mergeCaseList[0];

		// Get attachments and re-parent them
		// Duplicate all attachments
		List<Attachment> AttachmentsToBeCreated = new List<Attachment>();
		for (Attachment a : [
			SELECT Name, IsPrivate, Description, Body
			FROM Attachment
			WHERE ParentId = :mergeCase.Id AND IsDeleted = FALSE
		]) {
			AttachmentsToBeCreated.add(
				new Attachment(
					ParentId = parentCase.Id,
					Name = a.Name,
					IsPrivate = a.IsPrivate,
					Description = a.Description,
					Body = a.Body
				)
			);
			System.debug('cloning attachment:0:' + a.Name);
		}

		// Duplicate all comments
		List<CaseComment> CommentsToBeCreated = new List<CaseComment>();
		for (CaseComment cc : [
			SELECT IsPublished, CreatedDate, CommentBody
			FROM CaseComment
			WHERE ParentId = :mergeCase.Id AND IsDeleted = FALSE
		]) {
			CommentsToBeCreated.add(
				new CaseComment(
					ParentId = parentCase.Id,
					IsPublished = cc.IsPublished,
					CommentBody = 'This case comment was originally created on ' +
						cc.CreatedDate +
						' and was merged into this case.\r\r' +
						cc.CommentBody
				)
			);
		}
		if (!CommentsToBeCreated.IsEmpty()) {
			insert CommentsToBeCreated;
		}

		// Duplicate all emails and attachments
		List<EmailMessage> EmailsToBeCreated = new List<EmailMessage>();
		for (EmailMessage em : [
			SELECT
				FromName,
				FromAddress,
				ToAddress,
				ccAddress,
				bccAddress,
				Subject,
				TextBody,
				HtmlBody,
				MessageDate,
				Status,
				Incoming,
				Headers,
				ActivityId,
				HasAttachment
			FROM EmailMessage
			WHERE ParentId = :mergeCase.Id AND IsDeleted = FALSE
		]) {
			string mergeNotice = 'This email was recreated when it\'s parent case was merged. ';

			// if the email has an attachment, recreate all the attachments with the parentid set to the case id
			if (em.HasAttachment) {
				for (Attachment att : [
					SELECT Name, IsPrivate, Description, Body
					FROM Attachment
					WHERE ParentId = :em.Id AND IsDeleted = FALSE
				]) {
					AttachmentsToBeCreated.add(
						new Attachment(
							ParentId = ParentCase.Id,
							Name = att.Name,
							IsPrivate = att.IsPrivate,
							Body = att.Body,
							Description = 'This attachment was originally attached to a merged email titled ' +
								em.Subject +
								'.\r\r' +
								((att.Description != null) ? att.Description : '')
						)
					);
					System.debug('cloning attachment:1:' + att.Name);
				}
				mergeNotice += 'The original email attachments are now attached to the parent case.';
			}
			// now that the attachments are handled, add the actual email
			EmailsToBeCreated.add(
				new EmailMessage(
					ParentId = ParentCase.Id,
					FromName = em.FromName,
					FromAddress = em.FromAddress,
					ToAddress = em.toAddress,
					ccAddress = em.ccAddress,
					bccAddress = em.bccAddress,
					Subject = em.subject,
					TextBody = ((em.TextBody != null)
						? mergeNotice + '\r\rOriginal body:\r\r' + em.TextBody
						: null),
					HtmlBody = ((em.HtmlBody != null)
						? mergeNotice + '\r\rOriginal body:\r\r' + em.HtmlBody
						: null),
					MessageDate = em.MessageDate,
					Status = em.Status,
					Incoming = em.Incoming,
					Headers = em.Headers,
					ActivityId = em.ActivityId
				)
			);
		}
		if (!EmailsToBeCreated.IsEmpty())
			insert EmailsToBeCreated;

		// change the whatid for all tasks
		List<Task> allTasks = [
			SELECT Id, WhatId
			FROM Task
			WHERE WhatId = :mergeCase.Id AND IsDeleted = FALSE
		];
		if (!allTasks.isEmpty()) {
			for (integer i = 0; i < allTasks.size(); i++)
				allTasks[i].WhatId = ParentCase.Id;
			update allTasks;
		}

		// change the whatid for all events
		List<Event> allEvents = [
			SELECT Id, WhatId
			FROM Event
			WHERE WhatId = :mergeCase.Id AND IsDeleted = FALSE
		];
		if (!allEvents.isEmpty()) {
			for (integer i = 0; i < allEvents.size(); i++)
				allEvents[i].WhatId = ParentCase.Id;
			update allEvents;
		}

		// duplicate all the attachments (of the case and related emails)
		if (!AttachmentsToBeCreated.IsEmpty())
			insert AttachmentsToBeCreated;

		//select id, linkedentityid, contentdocumentid from contentdocumentlink where contentdocumentid='06918000000MfJwAAK'
		List<ContentDocumentLink> CDLsToBeCreated = new List<ContentDocumentLink>();
		//List<ContentDocumentLink> allCDLs = [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :mergeCase.Id AND IsDeleted=false];
		for (ContentDocumentLink aCDL : [
			SELECT Id, LinkedEntityId, ContentDocumentId
			FROM ContentDocumentLink
			WHERE LinkedEntityId = :mergeCase.Id AND IsDeleted = FALSE
		]) {
			CDLsToBeCreated.add(
				new ContentDocumentLink(
					LinkedEntityId = parentCase.Id,
					ShareType = 'V',
					ContentDocumentId = aCDL.ContentDocumentId
				)
			);
			//CDLsToBeCreated.add(new ContentDocumentLink(LinkedEntityId = parentCase.OwnerId, ShareType='I', ContentDocumentId = aCDL.ContentDocumentId));
			System.Debug('Creating CDLs: ' + aCDL.ContentDocumentId);
		}
		if (!CDLsToBeCreated.IsEmpty()) {
			insert CDLsToBeCreated;
		}

		// delete the original case and all it's related items
		//delete mergeCase;
		// Do I want to delete?
		// Or simply close and mark as dupe?
		// I think closing and marking as dupe is way better
		mergeCase.Status = 'Closed as Duplicate';
		mergeCase.OwnerId = parentCase.OwnerId;
		update mergeCase;

		return 'Done';
	} // end of createNewCase
} // end of RESTCaseMergeController