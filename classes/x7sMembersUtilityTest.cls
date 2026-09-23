/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
    Name : x7sMembersTestUtil
    Description: Utility class for creating the test records.
*/
@IsTest
public class x7sMembersUtilityTest {
	// Profiles - moved to Test Constants but cannot be removed from managed pkg
	private static final String testString = 'Test';
	private static final String locale = 'en_US';

	private static Id COMPANY_COMMUNITY_PROFILE_Id {
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
	private static String DEFAULT_PROFILE_NAME {
		get {
			if (DEFAULT_PROFILE_NAME == null) {
				List<X7S_Members_Filter_Setting__mdt> memberSetting = [
					SELECT Id, Applied_Test_Profile__c
					FROM X7S_Members_Filter_Setting__mdt
					WHERE DeveloperName = 'Default'
				];
				if (memberSetting != null && !memberSetting.isEmpty()) {
					DEFAULT_PROFILE_NAME = memberSetting[0].Applied_Test_Profile__c;
				}
			}
			return DEFAULT_PROFILE_NAME;
		}
		set {
			DEFAULT_PROFILE_NAME = value;
		}
	}

	private static String THIS_COMMUNITY_NAME {
		get {
			String commName = '';
			commName = [SELECT Id, Name FROM Network LIMIT 1][0].Name;
			System.assertNotEquals(null, commName);
			return commName;
		}
	}

	// this is for standard user to know
	public static String NETWORK_ID {
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

	public static List<User> createUsers(Integer howMany, String profileName) {
		List<User> listOfUsers = new List<User>();
		Map<Integer, User> mapUser = new Map<Integer, User>();

		//create account
		Account a = new Account(Name = 'TestAccount123', NumberOfEmployees = 10);
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
					FirstName = key + testString,
					LastName = key + testString,
					LanguageLocaleKey = locale,
					LocaleSidKey = locale,
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
					LastName = i + testString,
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
					FirstName = key + testString,
					LastName = key + testString,
					Phone = mapCont.get(key).Phone,
					LanguageLocaleKey = locale,
					LocaleSidKey = locale,
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
			subscriptions.add(e);
		}
		System.assertNotEquals(null, subscriptions);
		insert subscriptions;

		//To create the likes
		List<FeedItem> feedItems = new List<FeedItem>();
		Map<Integer, FeedItem> mapFeedItem = new Map<Integer, FeedItem>();
		for (Integer key : mapUser.keySet()) {
			FeedItem fi = new FeedItem(
				Body = testString + mapUser.get(key).CommunityNickname,
				Type = 'ContentPost',
				ParentId = listOfUsers[key].Id,
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

		return listOfUsers;
	}
}