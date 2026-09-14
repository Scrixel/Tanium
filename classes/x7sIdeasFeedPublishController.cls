/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasFeedPublishController {

	@AuraEnabled (Cacheable=true)
	public static IdeaExtension getExtensionId(String ideaId) {
		IdeaExtension ideaExtension = new IdeaExtension();

		try {
			List<X7S_Ideas_Extension__c> extensionList = [SELECT Id,Idea__c FROM X7S_Ideas_Extension__c WHERE Idea__c = :ideaId LIMIT 1];
			if (!extensionList.isEmpty()) {
				System.debug('Got extension list');
				ideaExtension.extension = extensionList[0].Id;
			}

			System.debug('Idea extension: ' + ideaExtension);
		}
		catch (Exception ex) { System.debug('getExtensionId() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber()); }

		return ideaExtension;
	}

	@AuraEnabled
	public static List<ContentDocument> getAllRelatedFilesDetails(String ideaId, Boolean isExtension, String visibility, String maxLength) {
		// check maxLength value and max sure it is valid and greater than 0 and less than 1000
		Integer intMaxLength = (maxLength != null) ? Integer.valueOf(maxLength) : 20;
		Integer queryLimit = (intMaxLength != null && intMaxLength > 0 && intMaxLength <= 1000) ? intMaxLength : 20;

		List<Id> listOfContentIds = new List<Id>();
		List<ContentDocumentLink> listOfContent = new List<ContentDocumentLink>();
		List<ContentDocument> contentDocuments = new List<ContentDocument>();
		IdeaExtension idea;

		if (!isExtension) {
			idea = getExtensionId(ideaId);
		}

		String linkedId = (isExtension) ? ideaId : idea.extension;
		try {
			if (!String.isEmpty(linkedId) &&
				ContentDocumentLink.SObjectType.getDescribe().isCreateable() &&
				ContentDocumentLink.SObjectType.getDescribe().isUpdateable()) {
				for (ContentDocumentLink contDocLink : [
					SELECT Id,ContentDocumentId,LinkedEntityId,ShareType,Visibility
					FROM ContentDocumentLink
					WHERE LinkedEntityId = :linkedId
				]) {
					if (contDocLink.ContentDocumentId != null) { listOfContentIds.add(contDocLink.ContentDocumentId);if (visibility != null) { contDocLink.Visibility = visibility;listOfContent.add(contDocLink); } }
				}

				upsert listOfContent;

				// get the actual files from the ids we found above
				contentDocuments = [SELECT Id, Title, LastModifiedDate, ContentSize, FileExtension FROM ContentDocument WHERE Id = :listOfContentIds ORDER BY LastModifiedDate DESC LIMIT :queryLimit];
			}
		}
		catch (Exception ex) { System.debug('getAllRelatedFilesDetails() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber()); }
		return contentDocuments;
	}

	public class IdeaExtension {
		@AuraEnabled public Id extension;
	}
}