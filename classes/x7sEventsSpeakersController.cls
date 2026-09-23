/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description This class handles operations for the event speakers
 */
public with sharing class x7sEventsSpeakersController {
	public static final Integer SEARCH_LIMIT = 500;
	public final static Integer MAX_RESULTS = 500;
	/**
	 * @description :  Method to create speakers
	 * @param createSpeakers : list of speakers to insert
	 * @param removeSpeakers : list of speakers to remove
	 * @return List of speakers
	 */
	@AuraEnabled
	public static String createSpeakers(
		List<x7sEventsSpeakerWrapper> createSpeakers,
		List<x7sEventsSpeakerWrapper> removeSpeakers
	) {
		// Handle errors
		List<String> errors = new List<String>();
		Map<String, x7sEventsSpeakerWrapper> uniqueIdToWrapper = new Map<String, x7sEventsSpeakerWrapper>();

		if (
			!X7S_Event_Speakers__c.SObjectType.getDescribe().isCreateable() ||
			!X7S_Event_Speakers__c.SObjectType.getDescribe().isUpdateable() ||
			!X7S_Event_Speakers__c.SObjectType.getDescribe().isDeletable()
		) {
			errors.add('Access error.  X7S_Event_Speakers__c');

			return errors[0];
		}

		Savepoint savepoint = Database.setSavepoint();

		List<X7S_Event_Speakers__c> needsToUpdate = new List<X7S_Event_Speakers__c>();
		List<X7S_Event_Speakers__c> needsToInsert = new List<X7S_Event_Speakers__c>();
		List<Id> needsToRemove = new List<Id>();

		if (!createSpeakers.isEmpty()) {
			for (x7sEventsSpeakerWrapper eveSpeaker : createSpeakers) {
				X7S_Event_Speakers__c speaker = new X7S_Event_Speakers__c();

				if (String.isNotBlank(eveSpeaker.EventId)) {
					speaker.X7S_Event__c = eveSpeaker.EventId;
					speaker.Name = eveSpeaker.Name;
					speaker.Image_Type__c = eveSpeaker.imageType;
					speaker.User__c = String.isNotBlank(eveSpeaker.userId) ? eveSpeaker.userId : null;
					speaker.Contact__c = String.isNotBlank(eveSpeaker.contactId)
						? eveSpeaker.contactId
						: null;
					speaker.Speaker_URL__c = eveSpeaker.speakerUrl;
					speaker.Speaker_URL_Label__c = eveSpeaker.speakerUrlLabel;
					speaker.Session_Title__c = eveSpeaker.sessionTitle;
					speaker.Session_Location__c = eveSpeaker.sessionLocation;
					speaker.Session_Start_Date__c = eveSpeaker.sessionStartDate;
					speaker.Session_End_Date__c = eveSpeaker.sessionEndDate;
					speaker.External_URL__c = eveSpeaker.externalUrl;
					speaker.Speaker_Bio__c = eveSpeaker.speakerBio;
					speaker.Unique_Reference_Id__c = eveSpeaker.speakerNumber;

					if (String.isEmpty(eveSpeaker.Id)) {
						needsToInsert.add(speaker);
						if (eveSpeaker.imageType == 'Related File') {
							uniqueIdToWrapper.put(eveSpeaker.speakerNumber, eveSpeaker);
						}
					} else {
						speaker.Id = eveSpeaker.Id;

						if (eveSpeaker.imageType == 'None') {
							speaker.External_URL__c = '';
							deleteSpeakerRelatedFiles(eveSpeaker.Id);
						} else if (eveSpeaker.imageType == 'External URL' && eveSpeaker.imageId != null) {
							deleteSpeakerRelatedFiles(eveSpeaker.Id);
						} else if (eveSpeaker.imageType == 'Related File') {
							speaker.External_URL__c = '';
							if (eveSpeaker.file.fileContent != null && eveSpeaker.imageId != null) {
								deleteSpeakerRelatedFiles(eveSpeaker.Id);
							}
							uniqueIdToWrapper.put(eveSpeaker.speakerNumber, eveSpeaker);
						}

						needsToUpdate.add(speaker);
					}
				}
			}
		}

		try {
			insert needsToInsert;
			update needsToUpdate;
		} catch (Exception e) {
			errors.add(e.getMessage());
			// That didn't work.
		}

		if (!uniqueIdToWrapper.isEmpty() && !needsToInsert.isEmpty()) {
			insertImage(uniqueIdToWrapper, needsToInsert);
		}

		if (!uniqueIdToWrapper.isEmpty() && !needsToUpdate.isEmpty()) {
			insertImage(uniqueIdToWrapper, needsToUpdate);
		}

		if (!removeSpeakers.isEmpty()) {
			for (x7sEventsSpeakerWrapper delSpeaker : removeSpeakers) {
				if (String.isNotEmpty(delSpeaker.Id)) {
					deleteSpeakerRelatedFiles(delSpeaker.Id);
					needsToRemove.add(delSpeaker.Id);
				}
			}
		}

		if (!needsToRemove.isEmpty()) {
			List<X7S_Event_Speakers__c> deleteSpeakers = [
				SELECT Id
				FROM X7S_Event_Speakers__c
				WHERE Id = :needsToRemove
			];
			try {
				delete deleteSpeakers;
			} catch (Exception e) {
				System.debug('Error deleting speaker record:' + e.getMessage());
			}
		}

		// If there were errors, roll back DB
		if (errors.isEmpty()) {
			return 'Success';
		} else {
			Database.rollback(savepoint);
		}
		return '';
	}

	public static String insertImage(
		Map<String, x7sEventsSpeakerWrapper> uniqueIdToWrapper,
		List<X7S_Event_Speakers__c> speakerIds
	) {
		Map<String, x7sEventsSpeakerWrapper> idToFileMap = new Map<String, x7sEventsSpeakerWrapper>();

		if (!uniqueIdToWrapper.isEmpty() && !speakerIds.isEmpty()) {
			for (String key : uniqueIdToWrapper.keySet()) {
				for (X7S_Event_Speakers__c speaker : speakerIds) {
					if (speaker.Unique_Reference_Id__c == key) {
						idToFileMap.put(speaker.Id, uniqueIdToWrapper.get(key));
					}
				}
			}

			if (
				!idToFileMap.isEmpty() &&
				ContentVersion.SObjectType.getDescribe().isCreateable() &&
				Schema.SObjectType.ContentVersion.fields.Title.isCreateable() &&
				Schema.SObjectType.ContentVersion.fields.PathOnClient.isCreateable() &&
				Schema.SObjectType.ContentVersion.fields.ContentLocation.isCreateable() &&
				Schema.SObjectType.ContentVersion.fields.VersionData.isCreateable() &&
				ContentDocumentLink.SObjectType.getDescribe().isCreateable() &&
				Schema.SObjectType.ContentDocumentLink.fields.ContentDocumentId.isCreateable() &&
				Schema.SObjectType.ContentDocumentLink.fields.LinkedEntityId.isCreateable() &&
				Schema.SObjectType.ContentDocumentLink.fields.ShareType.isCreateable() &&
				Schema.SObjectType.ContentDocumentLink.fields.Visibility.isCreateable()
			) {
				Map<String, String> speakerToContent = new Map<String, String>();
				Map<String, String> speakerToContentId = new Map<String, String>();

				for (String speakerId : idToFileMap.keySet()) {
					ContentVersion content = new ContentVersion();
					x7sEventsSpeakerWrapper wrapper = idToFileMap.get(speakerId);
					if (wrapper.file.fileContent != null) {
						content.Title = wrapper.file.fileName;
						content.PathOnClient = '/' + wrapper.file.fileName;
						content.ContentLocation = 'S';
						content.VersionData = EncodingUtil.base64Decode(wrapper.file.fileContent);
						insert content; //NOPMD - ContentVersion can not be bulkified, because we lose link between speaker & the document, So need to keep this DML in a loop

						speakerToContentId.put(content.Id, speakerId);
					}
				}

				List<ContentVersion> insertedContent = [
					SELECT Id, ContentDocumentId
					FROM ContentVersion
					WHERE Id IN :speakerToContentId.keySet()
				];
				for (ContentVersion content : insertedContent) {
					if (speakerToContentId.containsKey(content.Id)) {
						speakerToContent.put(speakerToContentId.get(content.Id), content.ContentDocumentId);
					}
				}

				List<ContentDocumentLink> relatedLinks = new List<ContentDocumentLink>();
				for (String speakerId : speakerToContent.keySet()) {
					ContentDocumentLink relatedLink = new ContentDocumentLink();
					relatedLink.ContentDocumentId = speakerToContent.get(speakerId);
					relatedLink.LinkedEntityId = speakerId;
					relatedLink.ShareType = 'I';
					relatedLink.Visibility = 'AllUsers';
					relatedLinks.add(relatedLink);
				}

				if (!relatedLinks.isEmpty()) {
					insert relatedLinks;
				}

				if (relatedLinks.isEmpty()) {
					return 'Error inserting images.';
				} else {
					return 'Success';
				}
			}
		}
		return null;
	}
	/**
	 * @description :  Method to search contacts and display for the dropdown of "Users"
	 *
	 * @param searchString search string
	 * @param searchContacts search contacts, if false will only search users
	 * @param searchByObject object name
	 *
	 * @return Map contactId, contact
	 */
	@AuraEnabled(Cacheable=true)
	public static List<SObject> searchLookup(
		String searchString,
		Boolean searchContacts,
		String searchByObject
	) {
		try {
			List<Contact> contactList = new List<Contact>();
			List<User> userList = new List<User>();
			List<SObject> sObjectList = new List<SObject>();

			if (String.isNotBlank(searchString) && searchByObject == null) {
				if (searchContacts) {
					String sQuery =
						'Select Id,Name From Contact Where (Name LIKE \'%' +
						String.escapeSingleQuotes(String.valueOf(searchString)) +
						'%\')';
					sQuery += ' LIMIT ' + SEARCH_LIMIT;

					List<Contact> Contacts = Database.query(sQuery);
					contactList.addAll(Contacts);
				}

				if (contactList.isEmpty()) {
					String queryUser =
						'Select Id,Name From User Where (Name LIKE \'%' +
						String.escapeSingleQuotes(String.valueOf(searchString)) +
						'%\')';
					queryUser += ' LIMIT ' + SEARCH_LIMIT;

					for (User u : Database.query(queryUser)) {
						//NOPMD
						userList.add(u);
					}
					return userList;
				} else {
					return contactList;
				}
			}

			if (String.isNotBlank(searchByObject)) {
				String queryRecords =
					'SELECT Id,Name FROM ' +
					String.escapeSingleQuotes(searchByObject) +
					' WHERE (Name LIKE \'%' +
					String.escapeSingleQuotes(String.valueOf(searchString)) +
					'%\')';
				queryRecords += ' LIMIT ' + SEARCH_LIMIT;
				List<SObject> uList = Database.query(queryRecords);
				sObjectList.addAll(uList);
			}

			if (!sObjectList.isEmpty()) {
				return sObjectList;
			}

			return new List<SObject>();
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Get List of Image Types from Speaker Object
	 * @return List of Image Types
	 */
	@AuraEnabled
	public static Map<String, String> getImageTypes() {
		try {
			Map<String, String> options = new Map<String, String>();

			Schema.DescribeFieldResult fieldResult = X7S_Event_Speakers__c.Image_Type__c.getDescribe();
			List<Schema.PicklistEntry> imageTypes = fieldResult.getPicklistValues();

			for (Schema.PicklistEntry type : imageTypes) {
				options.put(type.getValue(), type.getLabel());
			}
			return options;
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description: Get List of Image Types from Speaker Object
	 * @param eventIdString Event ID
	 * @return List of Image Types
	 * */
	@AuraEnabled
	public static List<x7sEventsSpeakerWrapper> initSpeakers(String eventIdString) {
		List<x7sEventsSpeakerWrapper> speakerWrapper = new List<x7sEventsSpeakerWrapper>();

		try {
			if (String.isNotBlank(eventIdString)) {
				List<X7S_Event_Speakers__c> eventSpeakers = [
					SELECT
						Name,
						Id,
						CreatedDate,
						Contact__c,
						User__c,
						External_URL__c,
						Image_Type__c,
						Session_Start_Date__c,
						Session_End_Date__c,
						Session_Title__c,
						Session_Location__c,
						Speaker_Bio__c,
						Speaker_URL__c,
						Speaker_URL_Label__c,
						Contact__r.Name,
						User__r.Name,
						X7S_Event__c,
						Unique_Reference_Id__c
					FROM X7S_Event_Speakers__c
					WHERE X7S_Event__c = :Id.valueOf(eventIdString)
					WITH SECURITY_ENFORCED
					ORDER BY CreatedDate
				];
				if (!eventSpeakers.isEmpty()) {
					for (X7S_Event_Speakers__c item : eventSpeakers) {
						x7sEventsSpeakerWrapper sWrapper = new x7sEventsSpeakerWrapper();
						sWrapper.Id = item.Id;
						sWrapper.Name = item.Name;
						sWrapper.EventId = item.X7S_Event__c;
						sWrapper.contact = item.Contact__r.Name;
						sWrapper.user = item.User__r.Name;
						sWrapper.contactId = item.Contact__c;
						sWrapper.userId = item.User__c;
						sWrapper.imageType = item.Image_Type__c;
						sWrapper.speakerUrl = item.Speaker_URL__c;
						sWrapper.speakerUrlLabel = item.Speaker_URL_Label__c;
						sWrapper.sessionTitle = item.Session_Title__c;
						sWrapper.sessionLocation = item.Session_Location__c;
						sWrapper.sessionStartDate = item.Session_Start_Date__c;
						sWrapper.sessionEndDate = item.Session_End_Date__c;
						sWrapper.externalUrl = item.External_URL__c;
						sWrapper.speakerBio = item.Speaker_Bio__c;
						sWrapper.speakerNumber = item.Unique_Reference_Id__c;

						//When Image Type = Related File
						if (String.isNotBlank(item.Id) && item.Image_Type__c == 'Related File') {
							List<Id> listIds = new List<Id>();
							listIds.add(Id.valueOf(item.Id));

							//Get All document links for event having Image Type = Related File only
							List<ContentDocumentLink> documentLinkList = x7sEventsContentDocument.getContentDocumentLinks(
								listIds
							);
							String communityURL = x7sEventsBaseController.getCommunityUrl();
							Id imageId;
							String imageURL;
							String imageName;
							List<ContentDocumentLink> links = x7sEventsContentDocument.containsEntityId(
								documentLinkList,
								item.Id
							);

							//Get the Image Reference field value
							String imageRef = item.Id;
							if (!links.isEmpty()) {
								for (ContentDocumentLink docLink : links) {
									if (docLink.ContentDocument.LatestPublishedVersionId == imageRef) {
										imageId = docLink.ContentDocument.LatestPublishedVersionId;
										break;
									}
								}
								imageURL =
									communityURL +
									x7sEventsContentDocument.FILE_LOCATION +
									links[0].ContentDocument.LatestPublishedVersionId;
								imageName = links[0].ContentDocument.Title;
								imageId = links[0].ContentDocument.LatestPublishedVersionId;
							}

							sWrapper.file.imageUrl = (String) imageURL;
							sWrapper.file.contentDocId = (String) imageId;
							sWrapper.file.fileName = (String) imageName;
						}
						speakerWrapper.add(sWrapper);
					}
				}
			}
			// Default to nothing
			return speakerWrapper;
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static String deleteSpeakerRelatedFiles(String speakerId) {
		try {
			if (String.isNotBlank(speakerId) && ContentDocument.SObjectType.getDescribe().isDeletable()) {
				List<ContentDocumentLink> contentDocLinks = [
					SELECT Id, ContentDocumentId
					FROM ContentDocumentLink
					WHERE LinkedEntityId = :speakerId
				];
				if (!contentDocLinks.isEmpty()) {
					List<String> contentDocIds = new List<String>();

					for (ContentDocumentLink contentLink : contentDocLinks) {
						contentDocIds.add(contentLink.ContentDocumentId);
					}
					List<ContentDocument> contentDoc = [
						SELECT Id
						FROM ContentDocument
						WHERE Id IN :contentDocIds
						WITH SECURITY_ENFORCED
					];

					if (!contentDoc.isEmpty()) {
						try {
							delete contentDoc;
						} catch (Exception e) {
							System.debug(
								'Error deleting file associated with event speaker record:' + e.getMessage()
							);
							return 'Error occurred while deleting contentDocument record. ' + e.getMessage();
						}
					}
				}
			} else {
				return 'You do not have delete access for the ContentDocument object.';
			}
			return 'Success';
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}
}