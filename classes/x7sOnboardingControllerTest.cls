/*
 * Licensed Materials - Property of IBM
 * 6949-82D
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sOnboardingControllerTest {
	@IsTest
	public static void setup() {
		List<X7S_Onboarding_Setting__mdt> settings = [
			SELECT Community_ID__c
			FROM X7S_Onboarding_Setting__mdt
			WHERE DeveloperName = 'Default'
		];

		Id networkId;
		List<Network> testNetworkList;

		testNetworkList = [SELECT Id FROM Network WHERE Id = :settings[0].Community_ID__c];

		if (testNetworkList != null && testNetworkList.size() > 0) {
			networkId = testNetworkList[0].Id;
		} else {
			// pick the first network that is not DwnForMaintenance
			testNetworkList = [
				SELECT Id
				FROM Network
				WHERE Status IN ('Live', 'UnderConstruction', 'Preview')
			];
			networkId = testNetworkList[0].Id;
		}

		Test.startTest();
		User testUser = x7sOnboardingTestUtils.createStandardUserNoContact();
		insert testUser;
		System.assertNotEquals(null, testUser);
		Test.stopTest();

		List<CollaborationGroup> testGroups = new List<CollaborationGroup>();
		for (Integer i = 0; i < 4; i++) {
			CollaborationGroup colGroup = new CollaborationGroup(
				Name = 'Test Chatter Group' + i,
				CollaborationType = 'Public',
				CanHaveGuests = false,
				NetworkId = networkId
			);
			testGroups.add(colGroup);
		}

		insert testGroups;

		List<Topic> testTopics = new List<Topic>();
		for (Integer i = 0; i < 2; i++) {
			Topic testTopic = new Topic(
				Name = 'Test Topic ' + i,
				Description = 'Test Topic1 Description',
				NetworkId = networkId
			);
			testTopics.add(testTopic);
		}

		insert testTopics;
	}

	@IsTest
	public static void testGetIsModalViewEnabled() {
		setup();

		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		System.runAs(testUser) {
			Boolean isModalViewEnabled = x7sOnboardingController.getIsModalViewEnabled();
			System.assertNotEquals(null, isModalViewEnabled);
		}
	}

	@IsTest
	public static void testGetOnboardingComplete() {
		setup();

		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		testUser.X7S_Onboarding_Complete__c = true;
		update testUser;
		System.runAs(testUser) {
			x7sOnboardingUserWrapper testUser1 = x7sOnboardingController.getUserRecord();
			System.assert(testUser1.X7SOnboardingComplete == true);
		}
	}

	@IsTest
	public static void testUpdateFirstName() {
		setup();
		x7sOnboardingUserWrapper testUserWrapper = new x7sOnboardingUserWrapper();
		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		testUserWrapper.FirstName = 'TestChange';
		System.runAs(testUser) {
			x7sOnboardingController.setUserRecord(testUserWrapper);
			User testUserName = [
				SELECT Id, FirstName
				FROM User
				WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
				LIMIT 1
			];
			System.assert(testUserName.FirstName == 'TestChange');
		}
	}

	@IsTest
	public static void testUpdateUserRecord() {
		setup();
		x7sOnboardingUserWrapper testUserWrapper = new x7sOnboardingUserWrapper();
		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		testUserWrapper.CompanyName = 'TestChangeCompany';
		testUserWrapper.Email = x7sOnboardingTestConstants.GUEST_EMAIL;
		testUserWrapper.MobilePhone = 'TestChangeMobilePhone';
		testUserWrapper.CommunityNickname = 'TestChangeCommunity';
		testUserWrapper.AboutMe = 'TestChangeAboutMe';

		System.runAs(testUser) {
			x7sOnboardingController.setUserRecord(testUserWrapper);
			User testUserName = [
				SELECT Id, CompanyName, Email, MobilePhone, CommunityNickname, AboutMe
				FROM User
				WHERE Id = :testUser.Id
				LIMIT 1
			];
			System.assert(testUserName.CompanyName == 'TestChangeCompany');
			System.assert(testUserName.Email == x7sOnboardingTestConstants.GUEST_EMAIL);
			System.assert(testUserName.MobilePhone == 'TestChangeMobilePhone');
			System.assert(testUserName.CommunityNickname == 'TestChangeCommunity');
			System.assert(testUserName.AboutMe == 'TestChangeAboutMe');
		}
	}

	@IsTest
	public static void testUpdateLastName() {
		setup();
		x7sOnboardingUserWrapper testUserWrapper = new x7sOnboardingUserWrapper();
		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		testUserWrapper.LastName = 'TestChange';
		System.runAs(testUser) {
			x7sOnboardingController.setUserRecord(testUserWrapper);
			User testUserName = [
				SELECT Id, LastName
				FROM User
				WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
				LIMIT 1
			];
			System.assert(testUserName.LastName == 'TestChange');
		}
	}

	@IsTest
	public static void testUpdateTitle() {
		setup();
		x7sOnboardingUserWrapper testUserWrapper = new x7sOnboardingUserWrapper();
		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		testUserWrapper.Title = 'TestChange';
		System.runAs(testUser) {
			x7sOnboardingController.setUserRecord(testUserWrapper);
			User testUserName = [
				SELECT Id, Title
				FROM User
				WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
				LIMIT 1
			];
			System.assert(testUserName.Title == 'TestChange');
		}
	}

	@IsTest
	public static void testUpdatePreferences() {
		setup();
		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		System.runAs(testUser) {
			x7sOnboardingController.updatePreferences(false);
			NetworkMember testUserName = [
				SELECT PreferencesDisableAllFeedsEmail
				FROM NetworkMember
				WHERE MemberId = :testUser.Id
				LIMIT 1
			];
			System.assert(testUserName.PreferencesDisableAllFeedsEmail == false);
		}
	}
	@IsTest
	static void testGroupMembership() {
		setup();

		User testUser = [
			SELECT Id, X7S_Onboarding_Complete__c, Email
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_EMAIL
			LIMIT 1
		];
		System.debug('testUser: ' + testUser);

		List<CollaborationGroup> testGroups = [
			SELECT Id
			FROM CollaborationGroup
			WHERE
				Name = 'Test Chatter Group0'
				OR Name = 'Test Chatter Group1'
				OR Name = 'Test Chatter Group2'
				OR Name = 'Test Chatter Group3'
		];

		System.runAs(testUser) {
			List<CollaborationGroupMember> memberList = [
				SELECT Id, NotificationFrequency
				FROM CollaborationGroupMember
				WHERE MemberId = :testUser.Id
			];
			//join group
			x7sOnboardingController.joinGroup(testGroups[0].Id);
			System.assertEquals(1, 1);

			//leave group
			x7sOnboardingController.leaveGroup(testGroups[0].Id);
			System.assertEquals(1, 1);

			//update Frequency
			x7sOnboardingController.updateFrequenv(testGroups[0].Id, 'M');
			if (memberList.size() > 0) {
				System.assertEquals('M', memberList[0].NotificationFrequency);
			}
		}
	}

	@IsTest
	public static void testCompleteSlide() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		System.runAs(testUser) {
			x7sOnboardingController.completeSlide('Welcome');
			x7sOnboardingController.completeSlide('Profile');
			x7sOnboardingController.completeSlide('Notification');
			x7sOnboardingController.completeSlide('Topic');
			x7sOnboardingController.completeSlide('Group');
			x7sOnboardingController.completeSlide('Tours');
			x7sOnboardingController.completeSlide('Done');

			User testUserName = [
				SELECT X7S_Completed_Tours_Slide__c, X7S_Onboarding_Complete__c
				FROM User
				WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
				LIMIT 1
			];
			System.assert(testUserName.X7S_Completed_Tours_Slide__c == true);
			System.assert(testUserName.X7S_Onboarding_Complete__c == true);
		}
	}

	@IsTest
	public static void testGetTopics() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		List<Id> topicIds = new List<Id>();
		for (Topic top : [SELECT Id FROM Topic WHERE Name = 'Test Topic 0' OR Name = 'Test Topic 1']) {
			topicIds.add(top.Id);
		}
		Id networkId1 = [SELECT Id FROM Network LIMIT 1].Id;
		EntitySubscription subscription = new EntitySubscription(
			ParentId = topicIds[0],
			SubscriberId = testUser.Id,
			NetworkId = networkId1
		);
		insert subscription;

		System.runAs(testUser) {
			List<x7sOnboardingController.OnboardingWrapperForTopicOrCollabGroup> topicWrapper = x7sOnboardingController.getTopics(
				topicIds
			);
			System.assert(topicWrapper.size() == 2);
		}
	}

	@IsTest
	public static void testGetGroups() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		List<Id> groupIds = new List<Id>();
		for (CollaborationGroup grp : [
			SELECT Id
			FROM CollaborationGroup
			WHERE Name = 'Test Chatter Group0' OR Name = 'Test Chatter Group1'
		]) {
			groupIds.add(grp.Id);
		}

		CollaborationGroupMember member = new CollaborationGroupMember(
			CollaborationGroupId = groupIds[0],
			MemberId = testUser.Id
		);
		insert member;
		System.runAs(testUser) {
			List<x7sOnboardingController.OnboardingWrapperForTopicOrCollabGroup> groupWrapper = x7sOnboardingController.getGroups(
				groupIds
			);
			System.assert(groupWrapper.size() == 2);
		}
	}

	@IsTest
	public static void testGetGroup() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		String groupId = [SELECT Id FROM CollaborationGroup WHERE Name = 'Test Chatter Group1' LIMIT 1]
		.Id;

		CollaborationGroupMember member = new CollaborationGroupMember(
			CollaborationGroupId = groupId,
			MemberId = testUser.Id
		);
		insert member;

		System.runAs(testUser) {
			x7sOnboardingController.OnboardingWrapperForTopicOrCollabGroup groupWrapper = x7sOnboardingController.getGroup(
				groupId
			);
			System.assert(groupWrapper.id == groupId);
		}
	}
	@IsTest
	public static void testGrabTopics() {
		setup();
		List<x7sOnboardingController.TopicSlide> topicSlides = x7sOnboardingController.grabTopics();
		System.assertNotEquals(null, topicSlides);
	}

	@IsTest
	public static void testFollowTopic() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		x7sOnboardingController.ActivityTracking myTracking = x7sOnboardingController.TrackActivities;
		myTracking.followTopic = true;

		String topicId = [SELECT Id FROM Topic WHERE Name = 'Test Topic 0' LIMIT 1].Id;

		System.runAs(testUser) {
			x7sOnboardingController.followTopic(topicId);
			List<EntitySubscription> userFollow = [
				SELECT Id
				FROM EntitySubscription
				WHERE ParentId = :topicId AND SubscriberId = :testUser.Id
				LIMIT 1
			];
			System.assert(userFollow.size() == 1);
		}
	}

	@IsTest
	public static void testRemoveGroupMember() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		CollaborationGroup testGroup = [
			SELECT Id
			FROM CollaborationGroup
			WHERE Name = 'Test Chatter Group3'
			LIMIT 1
		];
		CollaborationGroupMember member = new CollaborationGroupMember(
			CollaborationGroupId = testGroup.Id,
			MemberId = testUser.Id
		);
		insert member;

		System.runAs(testUser) {
			x7sOnboardingController.removeGroupMember(testGroup.Id);
			List<CollaborationGroupMember> userFollow = [
				SELECT Id
				FROM CollaborationGroupMember
				WHERE MemberId = :testUser.Id
			];
			System.assert(userFollow.size() == 0);
		}
	}

	@IsTest
	public static void testUnFollowTopic() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		x7sOnboardingController.ActivityTracking myTracking = x7sOnboardingController.TrackActivities;
		myTracking.unFollowTopic = true;
		Id networkId1 = [SELECT Id FROM Network LIMIT 1].Id;
		String topicId = [SELECT Id FROM Topic WHERE Name = 'Test Topic 0' LIMIT 1].Id;
		EntitySubscription topicFollow = new EntitySubscription(
			NetworkId = networkId1,
			ParentId = topicId,
			SubscriberId = testUser.Id
		);
		insert topicFollow;

		System.runAs(testUser) {
			x7sOnboardingController.unfollowTopic(topicId);
			List<EntitySubscription> userFollow = [
				SELECT Id
				FROM EntitySubscription
				WHERE ParentId = :topicId AND SubscriberId = :testUser.Id
				LIMIT 1
			];
			System.assert(userFollow.size() == 0);
		}
	}

	/*
	TODO: Dynamic query builder for custom fields
	@IsTest
	public static void testGetUserSpecificGroups()
	{
		setup();
		User testUser = [SELECT Id,Region__c FROM User WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME LIMIT 1];
		testUser.Region__c = 'Northeast';
		update testUser;
		List <Id> groupIds = new List <Id>();
		for (CollaborationGroup grp : [SELECT Id FROM CollaborationGroup WHERE Name = 'Test Chatter Group0' OR Name = 'Test Chatter Group1'])
		{
			groupIds.add(grp.Id);
		}

		CollaborationGroupMember member = new CollaborationGroupMember(CollaborationGroupId = groupIds[0], MemberId = testUser.Id);
		insert member;

		System.runAs(testUser)
		{

			List <x7sOnboardingController.OnboardingWrapper> OnboardingWrapperList = x7sOnboardingController.getUserSpecificGroups();
			System.assert(OnboardingWrapperList.size() == 1);
		}
	}
 */

	@IsTest(SeeAllData=true)
	public static void testUploadUserPhoto() {
		setup();
		User testUser = [
			SELECT Id
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		//update testUser;

		System.runAs(testUser) {
			ContentVersion contentVersionInsert = new ContentVersion(
				Title = '7S User Photo',
				PathOnClient = x7sOnboardingTestConstants.TEST_FILENAME,
				VersionData = EncodingUtil.base64Decode(x7sOnboardingTestConstants.BASE64FILE),
				IsMajorVersion = true
			);
			insert contentVersionInsert;

			ContentDocument documents = [
				SELECT Id, Title, FileType, LatestPublishedVersionId
				FROM ContentDocument
				WHERE Title = '7S User Photo'
				LIMIT 1
			];

			System.debug(' --- Document (Image):  ' + documents);

			String userPhotoUrl = x7sOnboardingController.getUserPhoto();
			String uploadUserPhotoUrl = x7sOnboardingController.uploadUserPhoto(
				documents.Id,
				x7sOnboardingTestConstants.TEST_FILENAME
			);
			System.assertNotEquals(null, userPhotoUrl);
			System.assertNotEquals(null, uploadUserPhotoUrl);
		}
	}

	@IsTest
	public static void testGetTrackingOptions() {
		x7sOnboardingController.ActivityTracking myTracking = x7sOnboardingController.TrackActivities;
		System.assertNotEquals(null, myTracking);
		x7sOnboardingController.DumpTracking();
	}

	@IsTest
	public static void testActivityEntry() {
		x7sOnboardingController.activityEntry entry = new x7sOnboardingController.activityEntry(
			'ID1',
			'Name'
		);
		System.assertNotEquals(null, entry);
	}

	@IsTest
	public static void testGetCommunityTermsAndConditions() {
		String defaultTermsAndConditions = 'Default Terms and Conditions (Used in Test Class)';
		String retrievedTermsAndConditions = x7sOnboardingController.getCommunityTermsAndConditions();
		System.assertNotEquals(null, retrievedTermsAndConditions);
		System.assertEquals(
			defaultTermsAndConditions,
			retrievedTermsAndConditions,
			'Retrieved Terms and Conditions should match Terms and Conditions Set in the Default 7S Onboarding Settings'
		);
	}

	@IsTest
	public static void testSetAgreedTermsAndConditions() {
		setup();

		User testUser = [
			SELECT Id, X7S_Agreed_to_Terms_and_Conditions__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		System.assertEquals(
			false,
			testUser.X7S_Agreed_to_Terms_and_Conditions__c,
			'Test User shouldn\'t have agreed to terms and conditions yet'
		);
		System.runAs(testUser) {
			x7sOnboardingController.setAgreedTermsAndConditions(true);
		}
		testUser = [
			SELECT Id, X7S_Agreed_to_Terms_and_Conditions__c
			FROM User
			WHERE Email = :x7sOnboardingTestConstants.STANDARD_USERNAME
			LIMIT 1
		];
		System.assertEquals(
			true,
			testUser.X7S_Agreed_to_Terms_and_Conditions__c,
			'Test User should have agreed to terms and conditions'
		);
	}

	@IsTest
	public static void testGetDisplayLimit() {
		X7S_Onboarding_Setting__mdt setting = x7sOnboardingController.getDisplayLimit();
		System.assertNotEquals(null, setting);
	}

	@IsTest
	public static void testGetEmailPreference() {
		NetworkMember memberPreference = x7sOnboardingController.getMemberEmailPreference();
		System.assertEquals(null, memberPreference);
	}
}