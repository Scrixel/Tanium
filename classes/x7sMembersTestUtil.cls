/*
 * Copyright (c) 2021. 7Summits, an IBM company. All rights reserved.
 */

/**
    Name : x7sMembersTestUtil
    Description: Utility class for creating the test records.
*/
@IsTest
global with sharing class x7sMembersTestUtil {
	// Profiles - moved to Test Constants but cannot be removed from managed pkg
	static final global String COMPANY_COMMUNITY_PROFILE_NAME = 'Customer Community User';
	static final global String PARTNER_COMMUNITY_PROFILE_NAME = 'Partner Community User';

	/**
    date        5/17/2016
    description: create list of test users
    */

	// MyId
	static final global Id userId = UserInfo.getUserId();

	static global Id COMPANY_COMMUNITY_PROFILE_Id {
		get {
			if (COMPANY_COMMUNITY_PROFILE_Id == null) {
				List<Profile> profiles = [
					SELECT Id
					FROM Profile
					WHERE
						Name = :x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
						OR Name = :x7sMembersTestConstants.PARTNER_COMMUNITY_PROFILE_NAME
				];
				COMPANY_COMMUNITY_PROFILE_Id = profiles[0].Id;
			}
			System.assertNotEquals(null, COMPANY_COMMUNITY_PROFILE_Id);
			return COMPANY_COMMUNITY_PROFILE_Id;
		}
		set {
			COMPANY_COMMUNITY_PROFILE_Id = value;
			System.assertEquals(value, COMPANY_COMMUNITY_PROFILE_Id);
		}
	}

	//by sachin kadian to get profile name from custom metadata
	static global String DEFAULT_PROFILE_NAME {
		get {
			if (DEFAULT_PROFILE_NAME == null) {
				List<X7S_Members_Filter_Setting__mdt> memberSetting = [
					SELECT Id, Applied_Test_Profile__c
					FROM X7S_Members_Filter_Setting__mdt
					WHERE DeveloperName = 'Default'
				];
				if (memberSetting != null && memberSetting.size() > 0) {
					DEFAULT_PROFILE_NAME = memberSetting[0].Applied_Test_Profile__c;
				}
			}
			return DEFAULT_PROFILE_NAME;
		}
		set {
			DEFAULT_PROFILE_NAME = value;
		}
	}

	static global String THIS_COMMUNITY_NAME {
		get {
			String commName = '';
			commName = [SELECT Id, Name FROM Network][0].Name;
			System.assertNotEquals(null, commName);
			return commName;
		}
	}

	// this is for standard user to know
	static global String NETWORK_ID {
		get {
			if (NETWORK_ID == null) {
				NETWORK_ID = [SELECT Id FROM Network WHERE Name = :THIS_COMMUNITY_NAME][0].Id;
			}
			System.assertNotEquals(null, NETWORK_ID);
			return NETWORK_ID;
		}
		set {
			NETWORK_ID = value;
			System.assertEquals(value, NETWORK_ID);
		}
	}

	global static List<User> createUsers(Integer howMany, String profileName) {
		List<User> listOfUsers = new List<User>();
		Map<Integer, User> mapUser = new Map<Integer, User>();

		//create account
		Account a = new Account(Name = 'TestAccount123');
		insert a;

		//change by  sachin kadian. if profile name exist in custom metadata, create standard users
		//otherwise create community users
		if (DEFAULT_PROFILE_NAME != null) {
			Profile profile = [SELECT Id, Name FROM Profile WHERE Name = :DEFAULT_PROFILE_NAME];
			for (Integer key = 0; key < howMany; key++) {
				User u = new User(
					Alias = 'com' + key,
					Email = key + 'testtest@test.com',
					EmailEncodingKey = 'UTF-8',
					FirstName = key + 'Test',
					LastName = key + 'Test',
					LanguageLocaleKey = 'en_US',
					LocaleSidKey = 'en_US',
					ProfileId = profile.Id,
					TimeZoneSidKey = 'America/Los_Angeles',
					Username = key + 'com' + '@test.com',
					Department = key < (howMany / 2) ? 'abc' : 'def',
					Phone = '(5' + key + '5) 555-555 ' + (key * key),
					X7S_Featured__c = true,
					IsActive = true
				);
				mapUser.put(key, u);
				listOfUsers.add(u);
			}
		} else {
			//create contacts
			List<Contact> listOfContacts = new List<Contact>();
			Map<Integer, Contact> mapCont = new Map<Integer, Contact>();

			for (Integer i = 0; i < howMany; i++) {
				Contact c = new Contact(
					LastName = i + 'Test',
					Phone = '(5' + i + '5) 555-555 ' + (i * i),
					AccountId = a.Id
				);
				listOfContacts.add(c);
				mapCont.put(i, c);
			}
			System.assertNotEquals(null, listOfContacts);
			System.assertEquals(howMany, listOfContacts.size());
			insert listOfContacts;

			// by default bidders
			Id profileId;
			// to make user unique
			String type;
			if (profileName == x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME) {
				profileId = COMPANY_COMMUNITY_PROFILE_Id;
				type = 'com';
			}

			for (Integer key : mapCont.keySet()) {
				User u = new User(
					Alias = type + key,
					Email = key + 'testtest@test.com',
					CommunityNickname = key + mapCont.get(key).LastName,
					EmailEncodingKey = 'UTF-8',
					FirstName = key + 'Test',
					LastName = key + 'Test',
					Phone = mapCont.get(key).Phone,
					LanguageLocaleKey = 'en_US',
					LocaleSidKey = 'en_US',
					ProfileId = profileId,
					ContactId = mapCont.get(key).Id,
					TimeZoneSidKey = 'America/Los_Angeles',
					Username = key + type + '@test.com',
					Department = key < (howMany / 2) ? 'abc' : 'def',
					IsActive = true
				);
				mapUser.put(key, u);
				listOfUsers.add(u);
			}

			System.assertNotEquals(null, listOfUsers);
		}

		insert listOfUsers;
		//To create the Members I follow
		List<EntitySubscription> subscriptions = new List<EntitySubscription>();

		for (Integer i = 1; i < howMany; i++) {
			EntitySubscription e = new EntitySubscription(
				ParentId = listOfUsers[i].Id,
				SubscriberId = listOfUsers[0].Id,
				NetworkId = NETWORK_ID
			);
			System.debug(e);
			subscriptions.add(e);
		}
		System.assertNotEquals(null, subscriptions);
		insert subscriptions;

		//To create the likes
		List<FeedItem> feedItems = new List<FeedItem>();
		Map<Integer, FeedItem> mapFeedItem = new Map<Integer, FeedItem>();
		for (Integer key : mapUser.keySet()) {
			FeedItem fi = new FeedItem(
				Body = 'Test' + mapUser.get(key).CommunityNickname,
				Type = 'ContentPost',
				ParentId = a.Id,
				Visibility = 'AllUsers'
			);

			mapFeedItem.put(key, fi);
			feedItems.add(fi);
		}
		System.assertNotEquals(null, feedItems);
		insert feedItems;

		List<FeedLike> feedLikes = new List<FeedLike>();
		for (Integer key : mapFeedItem.keySet()) {
			FeedLike fl = new FeedLike(FeedItemId = mapFeedItem.get(key).Id);
			feedLikes.add(fl);
		}
		System.assertNotEquals(null, feedLikes);
		insert feedLikes;

		System.debug('Created ' + listOfUsers.size() + ' users');
		//system.debug('Users:  ' + listOfUsers);

		return listOfUsers;
	}

	global static void createTestTopics() {
		List<Topic> testTopics = new List<Topic>();

		// TODO add network ID
		for (Integer i = 0; i < 3; i++) {
			testTopics.add(new Topic(Name = 'Topic' + i, NetworkId = NETWORK_ID));
		}

		insert testTopics;
	}
}