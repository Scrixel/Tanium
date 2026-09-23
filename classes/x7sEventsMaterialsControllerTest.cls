/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsMaterialsControllerTest {
	private static final String EVENT_MATERIAL_NAME = 'Test Material';
	private static final String FILE_LITERAL = 'file';
	private static final String SUCCESS = 'Success';

	@TestSetup
	static void testSetup() {
		x7sEventsUtility.createEventsRecords(1);
	}

	@IsTest
	static void test_materialPickListGetter() {
		String materialTypes = x7sEventsMaterialsController.getMaterialTypeList();
		System.assertNotEquals(0, materialTypes.length());

		String materialUsageList = x7sEventsMaterialsController.getMaterialUsageList();
		System.assertNotEquals(0, materialUsageList.length());

		String materialApplicability = x7sEventsMaterialsController.getMaterialApplicability();
		System.assertNotEquals(0, materialApplicability.length());
	}

	@IsTest
	static void test_materialList() {
		Test.startTest();

		List<X7S_Event__c> eventList = [SELECT Id FROM X7S_Event__c LIMIT 1];
		System.assertNotEquals(0, eventList.size());

		List<x7sEventsMaterialsWrapper> materialWrapperList = new List<x7sEventsMaterialsWrapper>();

		for (Integer i = 0; i < 2; i++) {
			x7sEventsMaterialsWrapper materialWrapper = new x7sEventsMaterialsWrapper();
			materialWrapper.materialType = 'Link/URL';
			materialWrapper.name = EVENT_MATERIAL_NAME + i;
			materialWrapper.description = 'This is test event material' + i;
			materialWrapper.requiredPreWork = true;
			materialWrapper.applicability = 'All';
			materialWrapper.link = 'https://www.x7seventmateriallink.com';
			materialWrapper.usage = 'Pre-Event';
			materialWrapper.uniqueKey = x7sEventsMaterialsController.generateUniqueId();
			materialWrapper.eventId = eventList[0].Id;
			materialWrapperList.add(materialWrapper);
		}

		x7sEventsMaterialsWrapper materialWrapper = new x7sEventsMaterialsWrapper();
		materialWrapper.materialType = 'File';
		materialWrapper.name = EVENT_MATERIAL_NAME + FILE_LITERAL;
		materialWrapper.description = 'This is test event material' + FILE_LITERAL;
		materialWrapper.requiredPreWork = false;
		materialWrapper.applicability = 'Hybrid: In-Person';
		materialWrapper.usage = 'Pre-Event;Post-Event';
		materialWrapper.uniqueKey = x7sEventsMaterialsController.generateUniqueId();
		materialWrapper.eventId = eventList[0].Id;
		Blob bodyBlob = Blob.valueOf('Unit Test Attachment Body');

		materialWrapper.file.fileContent = EncodingUtil.base64Encode(bodyBlob);
		materialWrapper.file.fileName = 'materialAttachment.jpg';
		materialWrapperList.add(materialWrapper);

		//Add event materials
		System.assertEquals(SUCCESS, x7sEventsMaterialsController.saveMaterials(materialWrapperList));

		//Get event material list for the event
		List<x7sEventsMaterialsWrapper> materials = x7sEventsMaterialsController.getMaterialsForEvent(
			eventList[0].Id
		);
		System.assertEquals(3, materials.size());

		List<X7S_Event_Material__c> materialList = [
			SELECT Id
			FROM X7S_Event_Material__c
			WHERE Name = :EVENT_MATERIAL_NAME + 1
		];
		System.assertEquals(1, materialList.size());

		//Delete Event Material
		String deleteResult = x7sEventsMaterialsController.deleteMaterial(materialList[0].Id);
		System.assertEquals(SUCCESS, deleteResult);

		//Check for invalid material Id
		System.assertEquals(SUCCESS, x7sEventsMaterialsController.deleteMaterial(materialList[0].Id));
		System.assertEquals(
			2,
			[SELECT COUNT() FROM X7S_Event_Material__c LIMIT 100],
			'Incorrect material count.'
		);

		List<X7S_Event_Material__c> materialList1 = [
			SELECT Id
			FROM X7S_Event_Material__c
			WHERE Name = :EVENT_MATERIAL_NAME + FILE_LITERAL
		];
		System.assertEquals(1, materialList1.size());

		//Update Event Material
		x7sEventsMaterialsWrapper materialWrapperToUpdate = new x7sEventsMaterialsWrapper();
		materialWrapperToUpdate.id = materialList1[0].Id;
		materialWrapperToUpdate.materialType = 'File';
		materialWrapperToUpdate.name = EVENT_MATERIAL_NAME + 'file1';
		materialWrapperToUpdate.description = 'This is test event material' + FILE_LITERAL;
		materialWrapperToUpdate.requiredPreWork = true;
		materialWrapperToUpdate.applicability = 'Hybrid: In-Person';
		materialWrapperToUpdate.usage = 'Pre-Event';

		materialWrapperToUpdate.file.fileContent = EncodingUtil.base64Encode(bodyBlob);
		materialWrapperToUpdate.file.fileName = 'materialAttachmentUpdated.pdf';
		String response = x7sEventsMaterialsController.updateMaterial(materialWrapperToUpdate);
		System.assertNotEquals('', response);

		List<X7S_Event_Material__c> updatedMaterialList = [
			SELECT Id
			FROM X7S_Event_Material__c
			WHERE Name = :EVENT_MATERIAL_NAME + 'file1'
		];
		System.assertEquals(1, updatedMaterialList.size());

		//Delete files related to the material
		System.assertEquals(
			SUCCESS,
			x7sEventsMaterialsController.deleteMaterialRelatedFiles(updatedMaterialList[0].Id)
		);
		Test.stopTest();
	}

	@IsTest
	static void test_checkMaterialAccess() {
		x7sEventsMaterialsController.materialAccessWrapper accessWrapper = x7sEventsMaterialsController.checkMaterialAccess();
		System.assertEquals(true, accessWrapper.hasEditAccses);
		System.assertEquals(true, accessWrapper.hasDeleteAccess);
	}
}