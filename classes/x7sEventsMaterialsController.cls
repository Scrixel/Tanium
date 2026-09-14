/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsMaterialsController {
	private static final Integer MATERIAL_LIST_LIMIT = 1000;
	private static final String MATERIAL_TYPE_FILE = 'File';
	private static final String SUCCESS = 'Success';

	/**
	 * @description Used to return Event Material Type picklist values to Lightning component
	 * @return List of Event Material Type
	 */
	@AuraEnabled(cacheable=true)
	public static String getMaterialTypeList() {
		try {
			return x7sEventsBaseController.buildPicklistValuesJSON(
				'X7S_Event_Material__c',
				'Material_Type__c'
			);
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Used to return Event Material Usage picklist values to Lightning component
	 * @return List of Event Material Usage
	 */
	@AuraEnabled(cacheable=true)
	public static String getMaterialUsageList() {
		try {
			return x7sEventsBaseController.buildPicklistValuesJSON('X7S_Event_Material__c', 'Usage__c');
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Used to return Event Material Usage picklist values to Lightning component
	 * @return List of Event Material Applicability
	 */
	@AuraEnabled(cacheable=true)
	public static String getMaterialApplicability() {
		try {
			return x7sEventsBaseController.buildPicklistValuesJSON(
				'X7S_Event_Material__c',
				'Applicability__c'
			);
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Used to add/remove materials to the event
	 * @return Event Id
	 */
	@AuraEnabled
	public static String saveMaterials(List<x7sEventsMaterialsWrapper> materialsToAdd) {
		List<X7S_Event_Material__c> materialList = new List<X7S_Event_Material__c>();
		Map<String, x7sEventsMaterialsWrapper> uniqueIdToWrapper = new Map<String, x7sEventsMaterialsWrapper>();
		Map<String, x7sEventsMaterialsWrapper> idtoFileMap = new Map<String, x7sEventsMaterialsWrapper>();

		try {
			if (
				!materialsToAdd.isEmpty() && X7S_Event_Material__c.SObjectType.getDescribe().isCreateable()
			) {
				for (x7sEventsMaterialsWrapper mWrapper : materialsToAdd) {
					X7S_Event_Material__c material = new X7S_Event_Material__c();
					material.Event__c = mWrapper.eventId;
					material.Material_Type__c = mWrapper.materialType;
					material.Usage__c = mWrapper.usage;
					material.Name = mWrapper.name;
					material.Description__c = mWrapper.description;
					if (String.isNotBlank(mWrapper.applicability)) {
						material.Applicability__c = mWrapper.applicability;
					}
					material.Required__c = mWrapper.requiredPreWork;
					material.Unique_Reference_Id__c = mWrapper.uniqueKey;

					if (mWrapper.materialType == 'Link/URL') {
						material.Link_URL__c = mWrapper.link;
					} else if (mWrapper.materialType == MATERIAL_TYPE_FILE) {
						uniqueIdToWrapper.put(mWrapper.uniqueKey, mWrapper);
					}

					materialList.add(material);
				}
			}

			if (!materialList.isEmpty()) {
				insert materialList;
			}

			Map<String, String> materialToContent = new Map<String, String>();
			Map<String, String> materialToContentId = new Map<String, String>();

			if (!uniqueIdToWrapper.isEmpty()) {
				for (String key : uniqueIdToWrapper.keySet()) {
					for (X7S_Event_Material__c meterial : materialList) {
						if (meterial.Unique_Reference_Id__c == key) {
							idtoFileMap.put(meterial.Id, uniqueIdToWrapper.get(key));
						}
					}
				}
			}

			if (
				!idtoFileMap.isEmpty() &&
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
				for (String materialId : idtoFileMap.keySet()) {
					ContentVersion content = new ContentVersion();
					x7sEventsMaterialsWrapper wrapper = idtoFileMap.get(materialId);
					content.Title = wrapper.file.fileName;
					content.PathOnClient = '/' + wrapper.file.fileName;
					content.ContentLocation = 'S';
					content.VersionData = EncodingUtil.base64Decode(wrapper.file.fileContent);
					insert content; //NOPMD : ContentVersion insertion can not be bulkified as It will lose the link between material & the content related to that material,
					//So need to keep this insert statement in a loop

					materialToContentId.put(content.Id, materialId);
				}

				List<ContentVersion> insertedContent = [
					SELECT Id, ContentDocumentId
					FROM ContentVersion
					WHERE Id IN :materialToContentId.keySet()
				];
				for (ContentVersion content : insertedContent) {
					if (materialToContentId.containsKey(content.Id)) {
						materialToContent.put(materialToContentId.get(content.Id), content.ContentDocumentId);
					}
				}

				List<ContentDocumentLink> relatedLinks = new List<ContentDocumentLink>();
				for (String materialId : materialToContent.keySet()) {
					ContentDocumentLink relatedLink = new ContentDocumentLink();
					relatedLink.ContentDocumentId = materialToContent.get(materialId);
					relatedLink.LinkedEntityId = materialId;
					relatedLink.ShareType = 'I';
					relatedLink.Visibility = 'AllUsers';
					relatedLinks.add(relatedLink);
				}

				if (!relatedLinks.isEmpty()) {
					insert relatedLinks;
				}
			}

			if (materialList.size() == 1) {
				JSONGenerator gen = JSON.createGenerator(true);
				gen.writeStartObject();
				gen.writeStringField('materialId', materialList[0].Id);
				if (materialList[0].Material_Type__c == MATERIAL_TYPE_FILE) {
					gen.writeStringField('contentId', materialToContent.get(materialList[0].Id));
				}
				gen.writeEndObject();
				return gen.getAsString();
			}
		} catch (Exception ex) {
			System.debug(
				'Error adding/removing event material:' +
				ex.getMessage() +
				',Line number : ' +
				ex.getLineNumber()
			);
			throw new AurahandledException(ex.getMessage());
		}

		return SUCCESS;
	}

	/**
	 * @description Used to create unique id
	 * @return Unique Id
	 */
	@AuraEnabled
	public static String generateUniqueId() {
		try {
			Blob generatedKey = Crypto.generateAesKey(128);
			return EncodingUtil.convertToHex(generatedKey);
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	public static List<x7sEventsMaterialsWrapper> getMaterialsForEvent(String eventId) {
		List<x7sEventsMaterialsWrapper> materialWrapper = new List<x7sEventsMaterialsWrapper>();
		List<String> materialsWithFile = new List<String>();
		List<X7S_Event_Material__c> materialList = new List<X7S_Event_Material__c>();

		if (String.isNotBlank(eventId)) {
			materialList = [
				SELECT
					Id,
					Name,
					Applicability__c,
					Description__c,
					Event__c,
					Link_URL__c,
					Material_Type__c,
					Required__c,
					Unique_Reference_Id__c,
					Usage__c
				FROM X7S_Event_Material__c
				WHERE Event__c = :eventId
				WITH SECURITY_ENFORCED
				LIMIT :MATERIAL_LIST_LIMIT
			];
		}

		if (!materialList.isEmpty()) {
			for (X7S_Event_Material__c material : materialList) {
				x7sEventsMaterialsWrapper mWrapper = new x7sEventsMaterialsWrapper();
				mWrapper.id = material.Id;
				mWrapper.eventId = material.Event__c;
				mWrapper.materialType = material.Material_Type__c;
				mWrapper.usage = material.Usage__c;
				mWrapper.name = material.Name;
				mWrapper.description = material.Description__c;
				mWrapper.applicability = material.Applicability__c;
				mWrapper.requiredPreWork = material.Required__c;
				mWrapper.uniqueKey = material.Unique_Reference_Id__c;

				if (material.Material_Type__c == 'Link/URL') {
					mWrapper.link = material.Link_URL__c;
				} else if (material.Material_Type__c == MATERIAL_TYPE_FILE) {
					materialsWithFile.add(material.Id);
				}
				materialWrapper.add(mWrapper);
			}
		}

		if (!materialsWithFile.isEmpty()) {
			List<ContentDocumentLink> fileList = [
				SELECT
					contentDocumentId,
					ContentDocumentLink.LinkedEntityId,
					ContentDocument.LatestPublishedVersionId,
					ContentDocument.Title,
					ContentDocument.FileExtension,
					ContentDocument.ContentSize
				FROM ContentDocumentLink
				WHERE LinkedEntityId IN :materialsWithFile
			];
			for (ContentDocumentLink contentDoc : fileList) {
				for (x7sEventsMaterialsWrapper mWrapper : materialWrapper) {
					if (contentDoc.LinkedEntityId == mWrapper.id) {
						x7sEventsMaterialsWrapper.fileWrapper file = new x7sEventsMaterialsWrapper.fileWrapper();
						file.fileName = contentDoc.ContentDocument.Title;
						file.fileSize = contentDoc.ContentDocument.ContentSize;
						file.fileExtension = contentDoc.ContentDocument.FileExtension;
						file.contentDocId = contentDoc.contentDocumentId;
						mWrapper.file = file;
					}
				}
			}
		}

		return materialWrapper;
	}

	public class materialAccessWrapper {
		@AuraEnabled
		public Boolean hasEditAccses { get; set; }
		@AuraEnabled
		public Boolean hasDeleteAccess { get; set; }
	}

	/**
	 * @description Used to create unique id
	 * @return Unique Id
	 */
	@AuraEnabled
	public static materialAccessWrapper checkMaterialAccess() {
		try {
			materialAccessWrapper accessWrapper = new materialAccessWrapper();
			accessWrapper.hasEditAccses = X7S_Event_Material__c.SObjectType.getDescribe().isUpdateable();
			accessWrapper.hasDeleteAccess = X7S_Event_Material__c.SObjectType.getDescribe().isDeletable();
			return accessWrapper;
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Used to delete event material
	 * @param id Material Id
	 * @return Unique Id
	 */
	@AuraEnabled
	public static String deleteMaterial(String id) {
		if (String.isNotBlank(id) && X7S_Event_Material__c.SObjectType.getDescribe().isDeletable()) {
			List<X7S_Event_Material__c> materialToDelete = [
				SELECT Id, Name
				FROM X7S_Event_Material__c
				WHERE Id = :id
				LIMIT 1
			];

			if (materialToDelete.isEmpty()) {
				return SUCCESS;
			} else {
				try {
					delete materialToDelete;
				} catch (Exception e) {
					System.debug('Error deleting material record:' + e.getMessage());
					throw new AurahandledException(e.getMessage());
				}
			}
		} else {
			return 'You do not have delete access for the X7S_Event_Material__c object.';
		}
		return SUCCESS;
	}

	/**
	 * @description Used to update event material
	 * @param materialWrapper Materials Wrapper
	 * @return success message
	 */
	@AuraEnabled
	public static String updateMaterial(x7sEventsMaterialsWrapper materialWrapper) {
		JSONGenerator gen = JSON.createGenerator(true);
		gen.writeStartObject();

		if (
			String.isNotBlank(materialWrapper.id) &&
			X7S_Event_Material__c.SObjectType.getDescribe().isCreateable() &&
			X7S_Event_Material__c.SObjectType.getDescribe().isUpdateable()
		) {
			List<X7S_Event_Material__c> materialToUpdate = [
				SELECT Id, Name, Material_Type__c, Required__c, Description__c, Applicability__c, Usage__c
				FROM X7S_Event_Material__c
				WHERE Id = :materialWrapper.id
				LIMIT 1
			];
			if (!materialToUpdate.isEmpty()) {
				materialToUpdate[0].Material_Type__c = materialWrapper.materialType;
				materialToUpdate[0].Usage__c = materialWrapper.usage;
				materialToUpdate[0].Name = materialWrapper.name;
				materialToUpdate[0].Description__c = materialWrapper.description;
				materialToUpdate[0].Applicability__c = materialWrapper.applicability;
				materialToUpdate[0].Required__c = materialWrapper.requiredPreWork;
				materialToUpdate[0].Link_URL__c = materialWrapper.link;

				try {
					upsert materialToUpdate;

					if (
						materialWrapper.materialType == MATERIAL_TYPE_FILE &&
						String.isNotBlank(materialWrapper.file.fileContent) &&
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
						ContentVersion content = new ContentVersion();

						content.Title = materialWrapper.file.fileName;
						content.PathOnClient = '/' + materialWrapper.file.fileName;
						content.ContentLocation = 'S';
						content.VersionData = EncodingUtil.base64Decode(materialWrapper.file.fileContent);
						insert content;

						List<ContentVersion> insertedContent = [
							SELECT Id, ContentDocumentId
							FROM ContentVersion
							WHERE Id = :content.Id
							LIMIT 1
						];

						if (!insertedContent.isEmpty()) {
							ContentDocumentLink relatedLink = new ContentDocumentLink();
							relatedLink.ContentDocumentId = insertedContent[0].ContentDocumentId;
							relatedLink.LinkedEntityId = materialToUpdate[0].Id;
							relatedLink.ShareType = 'I';
							relatedLink.Visibility = 'AllUsers';
							insert relatedLink;
						}
						gen.writeStringField('contentId', insertedContent[0].ContentDocumentId);
					}
				} catch (Exception e) {
					System.debug('Error updating material record:' + e.getMessage());
					throw new AurahandledException(e.getMessage());
				}
			}
			gen.writeStringField('Message', SUCCESS);
		} else {
			gen.writeStringField(
				'Message',
				'You do not have update access for the X7S_Event_Material__c object.'
			);
		}

		gen.writeEndObject();
		return gen.getAsString();
	}

	/**
	 * Used to update event material
	 * @return success message
	 */
	@AuraEnabled
	public static String deleteMaterialRelatedFiles(String materialId) {
		if (String.isNotBlank(materialId) && ContentDocument.SObjectType.getDescribe().isDeletable()) {
			List<ContentDocumentLink> contentDocLinks = [
				SELECT Id, contentDocumentId
				FROM ContentDocumentLink
				WHERE LinkedEntityId = :materialId
			];
			if (!contentDocLinks.isEmpty()) {
				List<String> contentDocIds = new List<String>();

				for (ContentDocumentLink contentLink : contentDocLinks) {
					contentDocIds.add(contentLink.contentDocumentId);
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
							'Error deleting file associated with event material record:' + e.getMessage()
						);
						return 'Error occurred while deleting contentDocument record. ' + e.getMessage();
					}
				}
			}
		} else {
			return 'You do not have delete access for the ContentDocument object.';
		}
		return SUCCESS;
	}
}