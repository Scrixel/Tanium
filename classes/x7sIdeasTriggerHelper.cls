/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasTriggerHelper {
	public static void addStatusCommentOnStatusUpdate(List<Idea> listOfIdeas, Map<Id, Idea> oldMapOfIdea) {
		List<x7sIdeasCommentsWrapper.CommentsModel> listOfSummaryWrapper;

		for (Idea ideaUpdate : listOfIdeas) {
			System.debug('Idea trigger - Status check: [' + ideaUpdate.Status + '], [' + oldMapOfIdea.get(ideaUpdate.Id).Status + ']');
			//System.debug('Status comment: [' + ideaUpdate.Status_Comment__c + '] length = ' + ideaUpdate.Status_Comment__c.length());

			if (ideaUpdate.Status != oldMapOfIdea.get(ideaUpdate.Id).Status) {
				if (!String.isEmpty(ideaUpdate.Status_Comment__c)) {
					String statusSummary = (oldMapOfIdea.get(ideaUpdate.Id).Status_Summary__c != null) ? oldMapOfIdea.get(ideaUpdate.Id).Status_Summary__c : '' ;

					if (statusSummary != null && statusSummary != '') {
						listOfSummaryWrapper = (List<x7sIdeasCommentsWrapper.CommentsModel>) JSON.deserialize(statusSummary, List<x7sIdeasCommentsWrapper.CommentsModel>.class);
					}
					else {
						listOfSummaryWrapper = new List<x7sIdeasCommentsWrapper.CommentsModel>();
					}

					x7sIdeasCommentsWrapper.CommentsModel commentsWrapper = new x7sIdeasCommentsWrapper.CommentsModel();

					commentsWrapper.newStatus = ideaUpdate.Status;
					commentsWrapper.changedBy = UserInfo.getFirstName() + ' ' + UserInfo.getLastName();
					commentsWrapper.changedById = UserInfo.getUserId();
					commentsWrapper.changedDate = Date.today();
					commentsWrapper.commentText = ideaUpdate.Status_Comment__c;

					if (listOfSummaryWrapper.size() > 0) { listOfSummaryWrapper.add(0, commentsWrapper); }
					else {
						listOfSummaryWrapper.add(commentsWrapper);
					}

					ideaUpdate.Status_Summary__c = JSON.serialize(listOfSummaryWrapper);
				}
			}
		}
	}

	public static void createIdeaExtensionRecord(List<Idea> listOfIdeas) {
		if (ideaExtensionEnabled()) {
			List<X7S_Ideas_Extension__c> listOExtensions = new List<X7S_Ideas_Extension__c>();

			List<Id> listOfIdeasIds = new List<Id>();
			List<Id> listOfExtensionIds = new List<Id>();

			//Create Idea Extension
			for (Idea idea : listOfIdeas) {
				if (String.isEmpty(idea.X7S_Ideas_Extension__c)) {
					String extName = idea.Title;

					if (extName.length() > 80) {
						extName = extName.substring(0, 79); extName += '…';
					}

					X7S_Ideas_Extension__c ideaExtension = new X7S_Ideas_Extension__c(Idea__c = idea.Id, Name = extName);
					listOExtensions.add(ideaExtension);
					listOfIdeasIds.add(idea.Id);
				}
			}

			try {
				if (!listOExtensions.isEmpty() && X7S_Ideas_Extension__c.SObjectType.getDescribe().isCreateable()) {
					insert listOExtensions;
				}
			}
			catch (Exception ex) {
				System.debug('ERROR createIdeaExtensionRecord ');
			}

			if (!listOExtensions.isEmpty()) {
				for (X7S_Ideas_Extension__c ids : listOExtensions) {
					listOfExtensionIds.add(ids.Id);
				}
			}

			System.debug('listOfExtensionIds: ' + listOfExtensionIds);
			System.debug('listOExtensions: ' + listOExtensions);

			if (!listOfIdeasIds.isEmpty() && !listOfExtensionIds.isEmpty()) {
				updateIdeaRecord(listOfIdeasIds, listOfExtensionIds);
			}
		}
	}

	public static void updateIdeaRecord(List<Id> listOfIdeasIds, List<Id> listOfExtensionIds) {
		List<Idea> updateIdeaList = new List<Idea>();

		//Update Idea with Extension Id
		if (Schema.SObjectType.Idea.isUpdateable() &&
			Schema.SObjectType.Idea.fields.X7S_Ideas_Extension__c.isUpdateable() &&
			Schema.SObjectType.Idea.fields.Idea_Extension_Status__c.isUpdateable()) {
			List<Idea> ideaList = [SELECT Id,Idea_Extension_Status__c,X7S_Ideas_Extension__c FROM Idea WHERE Id IN :listOfIdeasIds];
			List<X7S_Ideas_Extension__c> extensionList = [SELECT Id,Idea__c FROM X7S_Ideas_Extension__c WHERE Id IN :listOfExtensionIds];

			for (Idea idea : ideaList) {
				for (X7S_Ideas_Extension__c extension : extensionList) {
					if (idea.Id == extension.Idea__c) {
						idea.X7S_Ideas_Extension__c = extension.Id;
						idea.Idea_Extension_Status__c = 'Linked';

						updateIdeaList.add(idea);
					}
				}
			}
		}
		try {
			if (!updateIdeaList.isEmpty() && Idea.SObjectType.getDescribe().isUpdateable()) {
				update updateIdeaList;
			}
		}
		catch (Exception ex) {
			System.debug('ERROR x7sIdeasTriggerHelper.updateIdeaRecord : ' + ex.getMessage());
		}
	}

	public static void createExtensionWhenStatusPending(List<Idea> listOfIdeas) {
		if (ideaExtensionEnabled()) {
			List<Idea> listOfIdeasToUpdate = new List<Idea>();

			for (Idea idea : listOfIdeas) {
				if (idea.Idea_Extension_Status__c != null && idea.Idea_Extension_Status__c == 'Pending') { listOfIdeasToUpdate.add(idea); }
			}

			if (!listOfIdeasToUpdate.isEmpty()) { createIdeaExtensionRecord(listOfIdeasToUpdate); }
		}
	}

	private static Boolean ideaExtensionEnabled() {
		String metadataQuery = 'SELECT Id, DeveloperName, Enable_Idea_Extension_Functionality__c FROM X7S_Ideas_Setting__mdt';
		metadataQuery += ' WHERE DeveloperName = \'Default\' LIMIT 1';

		List<X7S_Ideas_Setting__mdt> ideasSettings = (List<X7S_Ideas_Setting__mdt>) Database.query(metadataQuery);

		return (!ideasSettings.isEmpty()) && (ideasSettings[0].Enable_Idea_Extension_Functionality__c);
	}
}