/**
 * @Business: Controller for the devPortalCreateCase lwc
 * @Date: 2025-02-15
 * @Author: Tanium Dev Team
 * @Request: SS-7142
 * RequestId  ModifiedDate  Description
 * SS-7142    2025-02-15    Created controller
 * SS-10401   2025-03-06    Update Case ContactId
 * SS-10433   2025-03-12    Create CaseContactRole to allow email replies
 * SS-10617   2025-06-12    Updated method createCase
 * SS-10693   2025-07-29    Added AccountId field to createCase method
 */
public without sharing class DevPortalCaseController {
	@AuraEnabled
	public static Case createCase(Case caseRecord, List<String> documentIds) {
		try {
			Id techPartnershipsAcctId = [SELECT Id FROM Group WHERE Name = 'Technical Partnerships']
			.Id;
			User currentUser = [
				SELECT Id, ContactId, AccountId
				FROM User
				WHERE Id = :UserInfo.getUserId()
			];
			List<ContentDocumentLink> contentDocLinks = new List<ContentDocumentLink>();

			caseRecord.OwnerId = techPartnershipsAcctId;
			caseRecord.ContactId = currentUser.ContactId;
			caseRecord.AccountId = currentUser.AccountId;
			caseRecord.Type = 'Problem';
			caseRecord.Component__c = 'Other: Product not listed';
			if (caseRecord.Subject == 'Request Lab') {
				caseRecord.Subject += ' ' + UserInfo.getName();
			}

			Database.SaveResult saveResult = Database.insert(caseRecord, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'DevPortalCaseController.createCase ERRORS',
					new List<Database.SaveResult>{ saveResult }
				)
				.addTag('apex');
			Logger.saveLog();

			for (String documentId : documentIds) {
				contentDocLinks.add(
					new ContentDocumentLink(
						ContentDocumentId = documentId,
						LinkedEntityId = caseRecord.Id,
						ShareType = 'V',
						Visibility = 'AllUsers'
					)
				);
			}
			insert contentDocLinks;

			Database.SaveResult[] saveResultsContentDocLinks = Database.insert(contentDocLinks, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'DevPortalCaseController.createCase Errors',
					saveResultsContentDocLinks
				)
				.addTag('apex');
			Logger.saveLog();

			CaseContactRole caseContactRole = new CaseContactRole(
				CasesId = caseRecord.Id,
				ContactId = currentUser.ContactId
			);

			Database.SaveResult saveResultCaseContactRole = Database.insert(caseContactRole, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'DevPortalCaseController.createCase Errors',
					new List<Database.SaveResult>{ saveResultCaseContactRole }
				)
				.addTag('apex');
			Logger.saveLog();

			return caseRecord;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}
}