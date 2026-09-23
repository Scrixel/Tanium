/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public class x7sEventsRegistrationTest {
	@IsTest
	static void test_eventRegistration() {
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(1001);
		System.assertEquals(eventList.size(), 1001);

		//Create Community user
		x7sEventsUtility.createUsers(1, x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER);

		//Create Community User
		User communityUser = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE
		);

		System.runAs(communityUser) {
			Test.startTest();

			try {
				X7S_Event_RSVP__c rsvpRec = new X7S_Event_RSVP__c();
				rsvpRec.Event__c = eventList[0].Id;
				//create RSVP Event record
				x7sEventsRegistration.createRegistration(rsvpRec, eventList[0].Id, 'Test Response');
			} catch (Exception e) {
				System.debug(e.getMessage());
			}

			//Delete RSVP Event
			x7sEventsRegistration.deleteRegistration(eventList[0].Id);
			X7S_Event_RSVP__c objhere;
			for (X7S_Event_RSVP__c obj : [SELECT Id FROM X7S_Event_RSVP__c WHERE Id = :eventList[0].Id]) {
				objhere = obj;
			}
			System.assertEquals(null, objhere);

			// get the RSVP count
			Decimal rsvpCount = x7sEventsRegistration.getAttendeeCount(eventList[0].Id);
			System.assertEquals(0, rsvpCount);

			//check if Event is RSVP or not
			x7sEventsRegistration.checkRegistration(eventList[0].Id);
			System.assertNotEquals(x7sEventsRegistration.checkRegistration(eventList[0].Id), null);

			//x7sEventsRegistration.getMemberAttendance(eventList[0].Id);
			x7sEventsRegistration.getMemberAttendance(eventList[0].Id);

			Test.stopTest();
		}
	}

	@IsTest
	static void test_RegFields() {
		Test.startTest();

		//Create fields
		x7sEventsUtility.setMetadata(
			'SELECT Id, developerName FROM X7S_Event_Reg_Field__mdt WHERE DeveloperName = \'Default\'',
			(List<X7S_Event_Reg_Field__mdt>) JSON.deserialize(
				'[{"Field_API_Name__c" : "Gender__c" , "Field_Label__c" : "Gender" , "Tooltip_Text__c" : "Gender","Type__c":"Picklist"}]',
				List<X7S_Event_Reg_Field__mdt>.class
			)
		);

		List<X7S_Event_Reg_Field__mdt> regfield = [
			SELECT Id, DeveloperName, Field_API_Name__c, Field_Label__c
			FROM X7S_Event_Reg_Field__mdt
			WHERE Field_API_Name__c = 'Gender__c'
			LIMIT 1
		];
		System.assertEquals(1, regfield.size(), 'No regfield Field found.');

		//Create X7S_Event_Reg_Field_Set__mdt
		x7sEventsUtility.setMetadata(
			'SELECT Id, developerName FROM X7S_Event_Reg_Field_Set__mdt WHERE DeveloperName = \'Default\'',
			(List<X7S_Event_Reg_Field_Set__mdt>) JSON.deserialize(
				'[{"All_Fields_Required__c" : "' +
				true +
				'"}]',
				List<X7S_Event_Reg_Field_Set__mdt>.class
			)
		);

		List<X7S_Event_Reg_Field_Set__mdt> set1 = [
			SELECT Id, DeveloperName
			FROM X7S_Event_Reg_Field_Set__mdt
			WHERE DeveloperName = 'Default'
			LIMIT 1
		];
		System.assertEquals(1, set1.size(), 'No Set1 found.');

		//Create X7S_Event_Reg_Field_Set_Assignment__mdt
		x7sEventsUtility.setMetadata(
			'SELECT Id, DeveloperName FROM X7S_Event_Reg_Field_Set_Assignment__mdt WHERE DeveloperName = \'Default\'',
			(List<X7S_Event_Reg_Field_Set_Assignment__mdt>) JSON.deserialize(
				'[{"X7S_Event_Field_Name__c" : "' +
				regfield[0].Id +
				'" , "X7S_Event_Field_Set_Name__c" : "' +
				set1[0].Id +
				'" , "Field_Label_Override__c" : "override custom", "Required__c" : "' +
				true +
				'"}]',
				List<X7S_Event_Reg_Field_Set_Assignment__mdt>.class
			)
		);

		List<X7S_Event_Reg_Field_Set_Assignment__mdt> assignment1 = [
			SELECT Id, DeveloperName
			FROM X7S_Event_Reg_Field_Set_Assignment__mdt
			WHERE DeveloperName = 'Default'
			LIMIT 1
		];
		System.assertEquals(1, assignment1.size(), 'No assignment1 found.');

		x7sEventsRegList eveReg = x7sEventsRegistration.getRegFields('Default');
		System.assertEquals(true, eveReg.listItem.size() > 0, 'No list found.');

		x7sEventsRegistrationFieldsModal recordModel = new x7sEventsRegistrationFieldsModal();
		recordModel.dumpModel('Test Record');

		Test.stopTest();
	}

	@IsTest
	static void testGetRegUrlAndStatus() {
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(1);
		System.assertEquals(eventList.size(), 1);
		X7S_Event_RSVP__c rsvp = x7sEventsUtility.createRSVPRecord(
			eventList[0].Id,
			UserInfo.getUserId(),
			'user1@email.com'
		);
		System.assertNotEquals(null, rsvp);
		insert rsvp;

		System.assertNotEquals(null, x7sEventsRegistration.getRegUrlAndStatus(eventList[0].Id));
	}
}