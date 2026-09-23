/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description : Utility class for test data creation
 */
@IsTest
public with sharing class x7sEventsUtility {
	private static Map<String, Account> createdAccountMap = new Map<String, Account>();
	private static final String TEST_USERNAME = 'testtestCommunity@test.com';
	public static final String TEST_EMAIL = 'testtest@test.com';
	private static final String TEST_LITERAL = 'Test';
	private static final String LANGUAGE = 'en_US';
	private static final String USER_TYPE = 'com';
	private static final String EMAIL_ENCODING_KEY = 'UTF-8';
	private static final String TIMEZONE_SID_KEY = 'America/Los_Angeles';

	public static String strNetworkId {
		get {
			Map<Id, Network> networks = new Map<Id, Network>([SELECT Id FROM Network]);

			if (networks.get(x7sEventsTestConstants.TEST_COMMUNITY_ID) != null) {
				return x7sEventsTestConstants.TEST_COMMUNITY_ID;
			}
			return networks.values()[0].Id;
		}
	}

	public static List<Topic> createTopic(Integer noOfEvents) {
		List<Topic> topicList = new List<Topic>();

		for (Integer i = 0; i < noOfEvents; i++) {
			Topic topicObj = new Topic(Name = 'Test00' + i, Description = TEST_LITERAL);
			topicList.add(topicObj);
		}
		insert topicList;

		return topicList;
	}

	public static List<X7S_Event__c> createEventRecord(String name) {
		return createEventRecord(name, null);
	}

	public static List<X7S_Event__c> createEventRecord(String name, String organizerId) {
		List<X7S_Event__c> eventList = new List<X7S_Event__c>();
		X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = name;
		objEvent.Start_DateTime__c = Datetime.now();
		objEvent.End_DateTime__c = Datetime.now().addDays(1);
		objEvent.Details__c = name + ' Event Details etc.';
		objEvent.Location_Name__c = 'Location1';
		objEvent.Enable_RSVP__c = false;

		if (String.isNotBlank(organizerId)) {
			objEvent.Event_Organizer__c = organizerId;
		}

		eventList.add(objEvent);
		insert eventList;

		//create 	NewsTranslation__c record
		createTranslationRecord(eventList);

		return eventList;
	}

	public static List<X7S_Event__c> createEventsRecords(Integer noOfEvents) {
		List<X7S_Event__c> eventList = new List<X7S_Event__c>();

		for (Integer i = 0; i < noOfEvents; i++) {
			X7S_Event__c objEvent = new X7S_Event__c();

			objEvent.Name = 'event' + i;
			objEvent.Start_DateTime__c = Datetime.now();
			objEvent.End_DateTime__c = Datetime.now().addDays(1);
			objEvent.Details__c = 'Event Details is here.';
			objEvent.Location_Name__c = 'Location' + i;
			objEvent.Enable_RSVP__c = false;
			objEvent.Event_Format__c = '';

			eventList.add(objEvent);
		}
		insert eventList;

		//create 	NewsTranslation__c record
		createTranslationRecord(eventList);

		return eventList;
	}

	public static List<X7S_Event__c> createEventsRecordsWithStartDate(
		Integer noOfEvents,
		Datetime startDate,
		Integer duration
	) {
		List<X7S_Event__c> eventList = new List<X7S_Event__c>();

		for (Integer i = 0; i < noOfEvents; i++) {
			X7S_Event__c objEvent = new X7S_Event__c();

			objEvent.Name = 'event' + i;
			objEvent.Start_DateTime__c = startDate;
			objEvent.End_DateTime__c = startDate.addDays(duration);
			objEvent.Details__c = 'Event Details is here.';
			objEvent.Location_Name__c = 'Location' + i;
			objEvent.Enable_RSVP__c = false;
			objEvent.Event_Format__c = '';

			eventList.add(objEvent);
		}
		insert eventList;

		return eventList;
	}

	private static void createTranslationRecord(List<X7S_Event__c> eventList) {
		List<X7S_Event_Translation__c> eventTranslation = new List<X7S_Event_Translation__c>();
		for (X7S_Event__c record : eventList) {
			X7S_Event_Translation__c eventTranslationObj = new X7S_Event_Translation__c(
				Name = 'Test Events Translate',
				Detail__c = 'Detail Test',
				Parent__c = record.Id,
				Language__c = LANGUAGE,
				Title__c = 'Test Title'
			);
			eventTranslation.add(eventTranslationObj);
		}
		insert eventTranslation;
	}

	public static TopicAssignment createTopicAssignment(String strTopicId, String strEntityId) {
		TopicAssignment topicAssignment = new TopicAssignment(
			EntityId = strEntityId,
			TopicId = strTopicId
		);

		insert topicAssignment;
		return topicAssignment;
	}

	public static List<X7S_Event_RSVP__c> createRSVPRecords(
		Integer noOfEvents,
		List<X7S_Event__c> eventList
	) {
		List<X7S_Event_RSVP__c> eventRSVPList = new List<X7S_Event_RSVP__c>();

		for (Integer i = 0; i < noOfEvents; i++) {
			X7S_Event_RSVP__c objEventRSVP = new X7S_Event_RSVP__c();

			objEventRSVP.Event__c = eventList[0].Id;
			objEventRSVP.Response__c = 'Attending';
			objEventRSVP.Email__c = 'x7s_test_user' + i + '@email.com';
			objEventRSVP.User__c = UserInfo.getUserId();

			eventRSVPList.add(objEventRSVP);
		}
		insert eventRSVPList;

		return eventRSVPList;
	}

	public static List<X7S_Event_RSVP__c> createMultipleRSVPRecords(
		Integer noOfEvents,
		Integer numberOfChildren,
		List<X7S_Event__c> eventList
	) {
		List<X7S_Event_RSVP__c> eventRSVPList = new List<X7S_Event_RSVP__c>();

		for (Integer i = 0; i < noOfEvents; i++) {
			x7sEventsUtility.createChildRsvpRecords(numberOfChildren, eventList[i], eventRSVPList);
		}

		insert eventRSVPList;

		return eventRSVPList;
	}

	public static void createChildRsvpRecords(
		Integer numberOfRsvps,
		X7S_Event__c event,
		List<X7S_Event_RSVP__c> eventRSVPList
	) {
		for (Integer i = 0; i < numberOfRsvps; i++) {
			X7S_Event_RSVP__c objEventRSVP = new X7S_Event_RSVP__c();

			objEventRSVP.Event__c = event.Id;
			objEventRSVP.Response__c = 'Attending';
			objEventRSVP.Email__c = 'x7s_test_user' + i + '@email.com';
			objEventRSVP.User__c = UserInfo.getUserId();

			eventRSVPList.add(objEventRSVP);
		}
	}

	public static X7S_Event_RSVP__c createRSVPRecord(
		String eventId,
		String userId,
		String userEmail
	) {
		X7S_Event_RSVP__c objRSVP = new X7S_Event_RSVP__c();

		objRSVP.Event__c = eventId;
		objRSVP.Response__c = 'Attending';
		objRSVP.Email__c = userEmail;
		objRSVP.User__c = userId;

		return objRSVP;
	}

	public static List<X7S_Event_RSVP__c> deleteRSVPRecords(List<X7S_Event_RSVP__c> eventRSVPList) {
		delete eventRSVPList;
		return eventRSVPList;
	}

	static final public String COMPANY_COMMUNITY_PROFILE_NAME = x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER;

	static public Id COMPANY_COMMUNITY_PROFILE_Id {
		get {
			if (COMPANY_COMMUNITY_PROFILE_Id == null) {
				List<Profile> profiles = [
					SELECT Id
					FROM Profile
					WHERE Name = :COMPANY_COMMUNITY_PROFILE_NAME
				];
				COMPANY_COMMUNITY_PROFILE_Id = profiles[0].Id;
			}
			System.assert(COMPANY_COMMUNITY_PROFILE_Id != null);
			return COMPANY_COMMUNITY_PROFILE_Id;
		}
		set {
			COMPANY_COMMUNITY_PROFILE_Id = value;
			System.assertEquals(value, COMPANY_COMMUNITY_PROFILE_Id);
		}
	}

	static public String THIS_COMMUNITY_NAME {
		get {
			String commName = '';
			commName = [SELECT Id, Name FROM Network LIMIT 1][0].Name;
			System.assertNotEquals(null, commName);
			return commName;
		}
	}

	static public String DEFAULT_PROFILE_NAME {
		get {
			List<X7S_Events_Setting__mdt> eventsSetting = [
				SELECT Id, Default_Test_Profile__c
				FROM X7S_Events_Setting__mdt
				WHERE DeveloperName = 'Default'
			];
			if (eventsSetting != null && !eventsSetting.isEmpty()) {
				return eventsSetting[0].Default_Test_Profile__c;
			}
			return null;
		}
	}

	//Create User with given Profile name
	public static List<User> createUsers(Integer howMany, String profileName) {
		Account a = createAccount('x7sTestAccount123');

		List<Contact> listOfContacts = new List<Contact>();
		Map<Integer, Contact> mapCont = new Map<Integer, Contact>();

		for (Integer i = 0; i < howMany; i++) {
			Contact c = new Contact(LastName = 'testCon' + i, AccountId = a.Id, Email = TEST_EMAIL);
			listOfContacts.add(c);
			mapCont.put(i, c);
		}
		insert listOfContacts;

		// by default bidders
		Id profileId;
		// to make user unique
		String type = USER_TYPE;

		Boolean useContact = true;

		if (profileName == COMPANY_COMMUNITY_PROFILE_NAME) {
			System.debug(
				'createCommunityUsers - Create user with ' +
				COMPANY_COMMUNITY_PROFILE_NAME +
				' profile'
			);
			profileId = COMPANY_COMMUNITY_PROFILE_Id;
			type = USER_TYPE;
		} else if (DEFAULT_PROFILE_NAME == null) {
			System.debug('createCommunityUsers - Create user with ' + profileName + ' profile');
			Profile p = [SELECT Id, Name FROM Profile WHERE Name = :profileName];
			profileId = p.Id;
		} else {
			System.debug('createCommunityUsers - Create user with ' + DEFAULT_PROFILE_NAME + ' profile');
			Profile p = [SELECT Id, Name FROM Profile WHERE Name = :DEFAULT_PROFILE_NAME];
			profileId = p.Id;
			useContact = false;
		}

		List<User> listOfUsers = new List<User>();
		User usr;

		for (Integer key : mapCont.keySet()) {
			if (useContact) {
				usr = new User(
					Alias = type + key,
					Email = key + TEST_EMAIL,
					CommunityNickname = key + mapCont.get(key).LastName,
					EmailEncodingKey = EMAIL_ENCODING_KEY,
					LastName = TEST_LITERAL + type + key,
					LanguageLocaleKey = LANGUAGE,
					LocaleSidKey = LANGUAGE,
					ProfileId = profileId,
					ContactId = mapCont.get(key).Id,
					TimeZoneSidKey = TIMEZONE_SID_KEY,
					Username = key + type + '@test.com'
				);
			} else {
				usr = new User(
					Alias = type + key,
					Email = key + 'testtest@test.com',
					CommunityNickname = key + mapCont.get(key).LastName,
					EmailEncodingKey = EMAIL_ENCODING_KEY,
					LastName = TEST_LITERAL + type + key,
					LanguageLocaleKey = LANGUAGE,
					LocaleSidKey = LANGUAGE,
					ProfileId = profileId,
					TimeZoneSidKey = TIMEZONE_SID_KEY,
					Username = key + type + '@test.com'
				);
			}
			listOfUsers.add(usr);
		}

		insert listOfUsers;
		return listOfUsers;
	}

	public static User createCommunityUsers(String profileName) {
		return createCommunityUsers(profileName, TEST_USERNAME, false);
	}

	//Create Community User
	//As we are using custom object Events, created a user with the custom Community Profile,
	//As standard community profiles do not allow to give permissions to such custom objects.
	public static User createCommunityUsers(
		String profileName,
		String userName,
		Boolean enableChatter
	) {
		if (DEFAULT_PROFILE_NAME == null) {
			Account a = createAccount('TestAccount123');

			Contact c = new Contact(LastName = 'testCon', AccountId = a.Id);
			insert c;

			Profile p = [SELECT Id, Name FROM Profile WHERE Name = :profileName];

			User u = new User(
				Alias = USER_TYPE,
				Email = 'testtestCommunity@test.com',
				CommunityNickname = c.LastName,
				EmailEncodingKey = EMAIL_ENCODING_KEY,
				LastName = TEST_LITERAL,
				LanguageLocaleKey = LANGUAGE,
				LocaleSidKey = LANGUAGE,
				ProfileId = p.Id,
				ContactId = c.Id,
				TimeZoneSidKey = TIMEZONE_SID_KEY,
				Username = userName,
				X7S_Event_Feed_Notification_Chatter__c = enableChatter
			);

			insert u;
			return u;
		} else {
			Profile p = [SELECT Id, Name FROM Profile WHERE Name = :DEFAULT_PROFILE_NAME];

			User u = new User(
				Alias = USER_TYPE,
				Email = 'testtestCommunity@test.com',
				EmailEncodingKey = EMAIL_ENCODING_KEY,
				LastName = TEST_LITERAL,
				LanguageLocaleKey = LANGUAGE,
				LocaleSidKey = LANGUAGE,
				ProfileId = p.Id,
				TimeZoneSidKey = TIMEZONE_SID_KEY,
				Username = userName,
				X7S_Event_Feed_Notification_Chatter__c = enableChatter
			);

			insert u;
			return u;
		}
	}

	public static Account createAccount(String name) {
		Account acc = createdAccountMap.get(name);

		if (acc == null) {
			acc = new Account(Name = name, NumberOfEmployees = 10);
			createdAccountMap.put(name, acc);
			insert acc;
		}

		return acc;
	}

	public static Contact createContact(String email) {
		Account testAccount = createAccount('x7sEvents_TestAccount123');

		Contact testContact = new Contact(
			LastName = 'testContact1',
			AccountId = testAccount.Id,
			Email = email
		);
		insert testContact;

		return testContact;
	}

	public static Lead createLead(String email) {
		Lead newLead = new Lead(
			Email = email,
			FirstName = 'Lead_First',
			LastName = 'Lead_Last',
			Status = 'Open - Not Contacted',
			Company = 'Acme'
		);
		insert newLead;

		return newLead;
	}

	public static Id createTestGroup(String groupName) {
		CollaborationGroup myGroup = new CollaborationGroup();

		myGroup.Name = groupName;
		myGroup.CollaborationType = 'Public'; //can be 'Public' or 'Private'
		myGroup.NetworkId = strNetworkId;
		System.assertNotEquals(null, myGroup);

		insert myGroup;
		return myGroup.Id;
	}

	public static void addTestGroupMember(String groupId, String userId) {
		CollaborationGroupMember groupMember = new CollaborationGroupMember();

		groupMember.CollaborationGroupId = groupId;
		groupMember.MemberId = userId;
		System.assertNotEquals(null, groupMember);

		insert groupMember;
	}

	//Utility Method
	public static void setMetadata(String query, List<SObject> records) {
		x7sEventsRegistration.MetadataCoverageRecordMap.put(query, records);
	}
}