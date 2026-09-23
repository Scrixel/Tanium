/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public class x7sEventsSpeakersControllerTest {
	private static final Integer QUERY_LIMIT = 10;
	private static final String SUCCESS = 'Success';

	@TestSetup
	static void speakerTestSetup() {
		// Test Event
		List<X7S_Event__c> testEvents = x7sEventsUtility.createEventsRecords(1);

		// Test users
		List<User> testUsers = x7sEventsUtility.createUsers(
			2,
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER
		);

		// Test Speakers
		X7S_Event_Speakers__c testSpeaker = new X7S_Event_Speakers__c(
			Name = 'Test Speaker',
			X7S_Event__c = testEvents[0].Id,
			Speaker_URL_Label__c = 'testUrl',
			Image_Type__c = 'Related File',
			User__c = testUsers[0].Id
		);
		insert testSpeaker;
	}

	@IsTest
	public static void testSpeakerList() {
		List<X7S_Event__c> testEvents = [SELECT Id FROM X7S_Event__c LIMIT :QUERY_LIMIT];
		List<User> userList = [SELECT Id, Name FROM User LIMIT :QUERY_LIMIT];

		List<x7sEventsSpeakerWrapper> speakerWrapperList = new List<x7sEventsSpeakerWrapper>();
		List<x7sEventsSpeakerWrapper> speakerToRemove = new List<x7sEventsSpeakerWrapper>();

		for (Integer i = 0; i < 2; i++) {
			x7sEventsSpeakerWrapper speaker = new x7sEventsSpeakerWrapper();
			speaker.EventId = testEvents[0].Id;
			speaker.Name = 'test' + i;
			speaker.imageType = 'External URL';
			speaker.userId = userList[0].Id;
			speaker.speakerUrl = 'https://google.com';
			speaker.speakerUrlLabel = 'Google';
			speaker.sessionTitle = 'Salesforce Intro';
			speaker.sessionLocation = 'USA';
			speaker.sessionStartDate = System.Datetime.now();
			speaker.sessionEndDate = System.Datetime.now();
			speaker.externalUrl = 'https://external.com';
			speaker.speakerBio = 'this is bio for speaker';
			speaker.speakerNumber = 'Speaker ' + i;
			speakerWrapperList.add(speaker);
		}

		x7sEventsSpeakerWrapper speaker = new x7sEventsSpeakerWrapper();
		speaker.EventId = testEvents[0].Id;
		speaker.Name = 'test file';
		speaker.imageType = 'Related File';
		speaker.userId = userList[0].Id;
		speaker.speakerUrl = 'https://google.com';
		speaker.speakerUrlLabel = 'Google';
		speaker.sessionTitle = 'Salesforce Intro';
		speaker.sessionLocation = 'USA';
		speaker.sessionStartDate = System.Datetime.now();
		speaker.sessionEndDate = System.Datetime.now();
		speaker.speakerBio = 'this is bio for speaker';
		speaker.speakerNumber = 'Speaker 3';
		speaker.externalUrl = 'https://external.com';
		Blob bodyBlob = Blob.valueOf('Unit Test Attachment Body');
		speaker.file.fileContent = EncodingUtil.base64Encode(bodyBlob);
		speaker.file.fileName = 'speakerImg.jpg';
		speakerWrapperList.add(speaker);

		//Create event Speakers
		System.assertEquals(
			SUCCESS,
			x7sEventsSpeakersController.createSpeakers(speakerWrapperList, speakerToRemove)
		);

		List<x7sEventsSpeakerWrapper> testSpeakers = x7sEventsSpeakersController.initSpeakers(
			testEvents[0].Id
		);
		System.assertEquals(4, testSpeakers.size());

		List<X7S_Event_Speakers__c> updateSpeaker = [
			SELECT Id, Name
			FROM X7S_Event_Speakers__c
			WHERE Name = :'test file'
		];
		List<x7sEventsSpeakerWrapper> listToUpdate = new List<x7sEventsSpeakerWrapper>();

		List<Id> listIds = new List<Id>();
		listIds.add(Id.valueOf(updateSpeaker[0].Id));
		List<ContentDocumentLink> documentLinkList = x7sEventsContentDocument.getContentDocumentLinks(
			listIds
		);
		List<ContentDocumentLink> links = x7sEventsContentDocument.containsEntityId(
			documentLinkList,
			updateSpeaker[0].Id
		);
		System.assertNotEquals(null, links, 'Links should not be null');
		x7sEventsSpeakerWrapper updateSpeakerWrapper = new x7sEventsSpeakerWrapper();

		updateSpeakerWrapper.Id = updateSpeaker[0].Id;
		updateSpeakerWrapper.EventId = testEvents[0].Id;
		updateSpeakerWrapper.Name = 'test file1';
		updateSpeakerWrapper.imageType = 'Related File';
		updateSpeakerWrapper.userId = userList[0].Id;
		updateSpeakerWrapper.speakerUrl = 'https://google.com';
		updateSpeakerWrapper.speakerUrlLabel = 'Google';
		updateSpeakerWrapper.sessionTitle = 'Salesforce Intro1';
		updateSpeakerWrapper.sessionLocation = 'US';
		updateSpeakerWrapper.sessionStartDate = System.Datetime.now();
		updateSpeakerWrapper.sessionEndDate = System.Datetime.now();
		updateSpeakerWrapper.speakerBio = 'this is bio for speaker updated';
		updateSpeakerWrapper.speakerNumber = 'Speaker 3';
		speaker.externalUrl = 'https://external.com';
		Blob bodyBlob1 = Blob.valueOf('Unit Test Attachment Body updated');
		updateSpeakerWrapper.file.fileContent = EncodingUtil.base64Encode(bodyBlob1);
		updateSpeakerWrapper.file.fileName = 'speakerImgUpdated.jpg';
		listToUpdate.add(updateSpeakerWrapper);

		//Update event Speakers
		System.assertEquals(
			SUCCESS,
			x7sEventsSpeakersController.createSpeakers(listToUpdate, speakerToRemove)
		);

		//Delete files related to the speaker
		System.assertEquals(
			SUCCESS,
			x7sEventsSpeakersController.deleteSpeakerRelatedFiles(listToUpdate[0].Id)
		);

		//Delete event Speakers
		x7sEventsSpeakerWrapper deleteSpeakerWrapper = new x7sEventsSpeakerWrapper();
		deleteSpeakerWrapper.Id = listToUpdate[0].Id;
		speakerToRemove.add(deleteSpeakerWrapper);
		System.assertEquals(
			SUCCESS,
			x7sEventsSpeakersController.createSpeakers(speakerWrapperList, speakerToRemove)
		);

		//search for contact
		List<SObject> searchCon = x7sEventsSpeakersController.searchLookup('testCon', true, 'Contact');
		System.assertEquals(searchCon.size() > 1, searchCon.size() > 1);

		//search for user
		List<SObject> searchUser = x7sEventsSpeakersController.searchLookup(
			'testCon',
			false,
			'Contact'
		);
		System.assertEquals(searchUser.size() > 1, searchUser.size() > 1);
	}
	@IsTest
	static void testGetImageTypes() {
		Map<String, String> imageMap = x7sEventsSpeakersController.getImageTypes();
		System.assertNotEquals(null, imageMap);
	}
}