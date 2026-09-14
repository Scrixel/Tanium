/**
 * @Business: ContentDocumentLink Utility class
 * @Date: 2025-10-28
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-6810    2024-01-15	Created the class
 * SS-11875   2025-10-29    Added method notifyCaseOwnerOnFileUpload
 */
public with sharing class ContentDocumentLinkTriggerUtility {
	public static void setKlarityDateOnOpportunity(ContentDocumentLink[] contentDocumentLinks) {
		List<ContentDocumentLink> oppContentDocumentLinks = new List<ContentDocumentLink>();
		Map<Id, Opportunity> oppsMap;
		Map<Id, ContentDocument> contentDocumentsMap;
		Map<Id, DateTime> oppIdsContentDocumentCreatedDateMap = new Map<Id, DateTime>();
		Set<Id> oppIds = new Set<Id>();
		Set<Id> contentDocumentIds = new Set<Id>();
		String linkedEntityId;

		for (ContentDocumentLink contentDocumentLink : contentDocumentLinks) {
			linkedEntityId = String.valueOf(contentDocumentLink.LinkedEntityId);
			if (linkedEntityId.substring(0, 3) == '006') {
				oppContentDocumentLinks.add(contentDocumentLink);
				oppIds.add(linkedEntityId);
				contentDocumentIds.add(contentDocumentLink.ContentDocumentId);
			}
		}

		if (oppIds.isEmpty()) {
			return;
		}

		contentDocumentsMap = new Map<Id, ContentDocument>(
			[SELECT Id, CreatedDate FROM ContentDocument WHERE Id IN :contentDocumentIds]
		);

		oppsMap = new Map<Id, Opportunity>(
			[SELECT Id, CloseDate FROM Opportunity WHERE Id IN :oppIds]
		);

		for (Opportunity opp : oppsMap.values()) {
			if (getBizDaysDifference(System.today(), opp.CloseDate) > 2) {
				oppsMap.remove(opp.Id);
			}
		}

		for (ContentDocumentLink oppContentDocumentLink : oppContentDocumentLinks) {
			if (oppsMap.containsKey(oppContentDocumentLink.linkedEntityId)) {
				oppIdsContentDocumentCreatedDateMap.put(
					oppContentDocumentLink.linkedEntityId,
					contentDocumentsMap.get(oppContentDocumentLink.ContentDocumentId).CreatedDate
				);
			}
		}

		if (!oppIdsContentDocumentCreatedDateMap.isEmpty()) {
			setKlarityDateOnOpportunity(oppIdsContentDocumentCreatedDateMap);
		}
	}

	public static void setKlarityDateOnOpportunity(
		Map<Id, DateTime> oppIdsContentDocumentCreatedDateMap
	) {
		List<Opportunity> oppsToUpdate = new List<Opportunity>();
		Database.SaveResult[] saveResults;

		for (Id oppId : oppIdsContentDocumentCreatedDateMap.keySet()) {
			oppsToUpdate.add(
				new Opportunity(
					Id = oppId,
					Last_Update_Date_for_Klarity__c = oppIdsContentDocumentCreatedDateMap.get(oppId)
				)
			);
		}

		TriggerHandler.bypass(new List<String>{ 'OpportunityTriggerHandler' });
		saveResults = Database.update(oppsToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'ContentDocumentLinkTriggerUtility.setKlarityDateOnOpportunity ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void notifyCaseOwnerOnFileUpload(List<ContentDocumentLink> contentDocumentLinks) {
		List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
		Set<Id> caseIds = new Set<Id>();
		for (ContentDocumentLink contentDocumentLink : contentDocumentLinks) {
			if (Utility.isCase(contentDocumentLink.LinkedEntityId)) {
				caseIds.add(contentDocumentLink.LinkedEntityId);
			}
		}

		if (caseIds.isEmpty()) {
			return;
		}

		Id emailTemplateId = Utility.getEmailTemplateId('UploadFileToCaseNotification');
		Id doNotReplyEmailId = Utility.getNoReplyFromEmailId();

		for (Case cs : [SELECT Id, Owner.Email, Owner.Id FROM Case WHERE Id IN :caseIds]) {
			if (String.isNotEmpty(cs.Owner.Email)) {
				emails.add(
					Utility.buildEmailUsingTemplate(
						emailTemplateId,
						new List<String>{ cs.Owner.Email },
						cs.Id,
						cs.Owner.Id,
						false,
						doNotReplyEmailId
					)
				);
			}
		}
		try {
			Messaging.sendEmail(emails, false);
		} catch (Exception e) {
			Logger.Error('ContentDocumentLinkTriggerUtility.notifyCaseOwnerOnFileUpload ERRORS', e);
			Logger.saveLog();
		}
	}

	@TestVisible
	private static Integer getBizDaysDifference(Datetime startDate, Datetime endDate) {
		Datetime startDateTime = (DateTime) startDate;
		Datetime endDateTime = (DateTime) endDate;
		BusinessHours defaultBizHour = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE];
		Long inputMillisecs = BusinessHours.diff(defaultBizHour.Id, startDateTime, endDateTime);
		Integer totalDurationInSeconds = (inputMillisecs / 1000).intValue();
		return Math.mod(Math.floor(totalDurationInSeconds / 86400).intValue(), 365);
	}
}