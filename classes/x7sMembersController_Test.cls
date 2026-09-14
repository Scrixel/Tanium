/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @Class Name		  : x7sMembersController_Test
 * @Description		 : Apex Test class for x7sMembersController
 */

@IsTest
private class x7sMembersController_Test {
	User objTestUser;
	static string sortByFirstName = 'Sort by First Name';
	static string sortByLastName = 'Sort by Last Name';
	static string testString = 'Test';
	static string debugString = 'Search: ';
	static string resultString = 'Result: ';
	static string networkIdNull = 'networkId is null';
	static string pageNumberNull = 'pageNumber is not matching';
	static string testUserNoMatch = 'testUsers size not matching';
	static string blankResult = 'result is blank';

	@TestSetup
	private static void setupTestData() {
		List<Topic> testTopics = new List<Topic>();

		for (Integer i = 0; i < x7sMembersTestConstants.TEST_TOPIC_COUNT; i++) {
			testTopics.add(new Topic(Name = 'Topic' + i, NetworkId = Network.getNetworkId()));
		}

		insert testTopics;
	}

	@IsTest
	private static void testAllMethods() {
		x7sMembersWrapper testWrapper = new x7sMembersWrapper();
		System.assertNotEquals(null, testWrapper, 'testWrapper is null');

		x7sMembersController_Test test1 = new x7sMembersController_Test();
		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			8,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);
		System.assertEquals(8, testUsers.size(), 'testUsers size not match');

		test1.objTestUser = testUsers[0];

		System.runAs(test1.objTestUser) {
			Test.startTest();

			x7sMembersController.networkId = x7sMembersUtilityTest.NETWORK_ID;
			System.assertNotEquals(x7sMembersController.networkId, null, networkIdNull);
			String cmtTest = x7sMembersController.getMetaDataMemberList('Default');
			System.assertNotEquals(null, cmtTest, 'cmtTest is null');

			x7sMembersWrapper featuredMembers = x7sMembersController.getFeaturedMembersLwc(
				new List<String>(),
				true
			);
			System.assertNotEquals(null, featuredMembers, 'featuredMembers is null');
			try {
				x7sMembersController.followRecord(testUsers[1].Id);
			} catch (Exception e) {
				System.debug(e.getMessage());
			}

			List<String> listNickNames = new List<String>{
				testUsers[0].CommunityNickname,
				testUsers[1].CommunityNickname,
				testUsers[2].CommunityNickname,
				testUsers[3].CommunityNickname
			};
			x7sMembersWrapper featuredMembers1 = x7sMembersController.getFeaturedMembersLwc(
				listNickNames,
				false
			);
			System.assertNotEquals(null, featuredMembers1, 'featuredMembers1 is null');

			//To test the methods in members controller class
			//on load default values & to check only the test records.
			x7sMembersWrapper membrs = x7sMembersController.getMembers(
				8,
				sortByFirstName,
				'',
				testString
			);
			System.assertNotEquals(membrs.membersList, null, 'membersList is null');
			System.assertEquals(membrs.listSizeValue, 8, 'listSizeValue not match');

			x7sMembersWrapper nxtmembrs = x7sMembersController.nextPage(
				4,
				1,
				sortByFirstName,
				'',
				testString
			);
			System.assertEquals(2, nxtmembrs.pageNumber, pageNumberNull);
			System.assertEquals(4, nxtmembrs.listSizeValue, 'listSizeValue is not matching');
			System.assert(nxtmembrs.totalResults > 0, 'totalResults is null');

			x7sMembersWrapper prevmembrs = x7sMembersController.previousPage(
				4,
				2,
				sortByFirstName,
				'',
				testString
			);
			System.assertEquals(1, prevmembrs.pageNumber, pageNumberNull);
			System.assertEquals(4, prevmembrs.listSizeValue, pageNumberNull);
			System.assert(prevmembrs.totalResults > 0, pageNumberNull);

			x7sMembersController.getSitePrefix();

			x7sMembersWrapper membrs1 = x7sMembersController.getMembers(
				7,
				sortByLastName,
				'Members I Follow',
				testString
			);
			System.assertEquals(membrs1.membersList[6].Name, '7Test 7Test');

			x7sMembersWrapper membrs2 = x7sMembersController.getMembers(
				8,
				sortByFirstName,
				'',
				testString
			);
			System.assertNotEquals(membrs2.membersList[0].Name, null, 'membrs2 is null');

			x7sMembersWrapper membrs3 = x7sMembersController.getMembers(
				8,
				sortByLastName,
				'',
				testString
			);
			System.assertEquals(8, membrs3.membersList.size(), 'membrs3 size not matching');

			Test.stopTest();
		}
	}

	@IsTest
	private static void testCount() {
		x7sMembersController_Test test1 = new x7sMembersController_Test();
		x7sMembersController.networkId = x7sMembersUtilityTest.NETWORK_ID;
		System.assertNotEquals(x7sMembersController.networkId, null, networkIdNull);

		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			8,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);
		System.assertEquals(8, testUsers.size(), testUserNoMatch);

		test1.objTestUser = testUsers[0];

		System.runAs(test1.objTestUser) {
			Test.startTest();

			// total count
			Decimal memberCount = x7sMembersController.getMemberCount();
			System.debug('Member count = ' + memberCount);
			System.assert(memberCount > 0, 'memberCount equal 0');

			Test.stopTest();
		}
	}

	@IsTest
	private static void testExcludedMembers() {
		x7sMembersController_Test test1 = new x7sMembersController_Test();
		x7sMembersController.networkId = x7sMembersUtilityTest.NETWORK_ID;
		System.assertNotEquals(x7sMembersController.networkId, null, networkIdNull);

		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			8,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);
		System.assertEquals(8, testUsers.size(), testUserNoMatch);

		test1.objTestUser = testUsers[0];

		System.runAs(test1.objTestUser) {
			Decimal memberCount = x7sMembersController.getMemberCount();

			List<String> excluded = new List<String>();
			Set<String> included = new Set<String>();
			// test with excluded IDs
			x7sMembersWrapper members = x7sMembersController.getMembers(
				8,
				sortByLastName,
				'',
				testString
			);
			excluded.add(members.membersList[0].Id);
			excluded.add(members.membersList[1].Id);
			included.add(members.membersList[0].Id);
			included.add(members.membersList[1].Id);
			x7sMembersWrapper membersSortByLastName = x7sMembersController.getMembersEx(
				6,
				sortByLastName,
				'',
				testString,
				excluded
			);
			System.assertEquals(
				6,
				membersSortByLastName.membersList.size(),
				'membersList size not matching'
			);
			System.assertEquals(membersSortByLastName.membersList[0].Name, '2Test 2Test');

			x7sMembersWrapper membersNextPage = x7sMembersController.nextPageEx(
				4,
				1,
				sortByLastName,
				'Members I Follow',
				testString,
				excluded
			);
			System.assertNotEquals(null, membersNextPage, 'membersNextPage is null');

			x7sMembersWrapper membersPreviousPage = x7sMembersController.previousPageEx(
				4,
				2,
				sortByLastName,
				'Members I Follow',
				testString,
				excluded
			);
			System.assertNotEquals(null, membersPreviousPage, 'membersPreviousPage is null');

			//get memberCount
			Decimal featuredMember = x7sMembersController.getMemberCount('test', included);
			System.assertEquals(0, featuredMember, 'memberCount is not 0');

			// total excluding Ids
			Decimal exMemberCount = x7sMembersController.getMemberCountEx(excluded);
			System.debug('Member count (Ex) = ' + exMemberCount);
			System.assert(memberCount > exMemberCount, 'memberCount is less than or equal exMemberCount');
		}
	}

	@IsTest
	private static void testGetMembersList() {
		x7sMembersController_Test test1 = new x7sMembersController_Test();
		x7sMembersController.networkId = x7sMembersUtilityTest.NETWORK_ID;
		System.assertNotEquals(x7sMembersController.networkId, null, networkIdNull);

		//TestSetupData
		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			8,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);
		System.assertEquals(8, testUsers.size(), 'testUsers is not matching');

		test1.objTestUser = testUsers[0];

		System.runAs(test1.objTestUser) {
			Test.startTest();

			try {
				x7sMembersWrapper members = x7sMembersController.getMemberList(
					100,
					1,
					'Date Joined Newest',
					'',
					testString,
					'',
					false,
					new List<String>(),
					new List<String>()
				);
				System.assert(members.membersList.size() > 0, 'membersList size is empty');
				System.debug('testGetMembersList - total found ' + members.membersList.size());
				// next page
				x7sMembersWrapper membersPage2 = x7sMembersController.getMemberList(
					6,
					2,
					'Date Joined Oldest',
					'',
					testString,
					'',
					new List<String>(),
					new List<String>()
				);
				System.assert(membersPage2.membersList.size() > 0, 'membersList size is empty');
				// text excluded members
				List<String> excluded = new List<String>();

				excluded.add(members.membersList[0].Id);
				excluded.add(members.membersList[1].Id);

				x7sMembersWrapper members1 = x7sMembersController.getMemberList(
					100,
					1,
					sortByLastName,
					'',
					testString,
					'',
					excluded,
					new List<String>()
				);
				System.debug('testGetMembersList - total excluded found ' + members1.membersList.size());
				System.assertEquals(
					2,
					members.membersList.size() - members1.membersList.size(),
					'membersList size is not 2'
				);

				x7sMembersWrapper members3 = x7sMembersController.getMemberList(
					100,
					1,
					'Sort by First Name',
					'',
					testString,
					new List<String>(),
					new List<String>()
				);
				System.assertNotEquals(null, members3, 'members3 is not null');
			} catch (Exception e) {
				System.debug(e.getMessage());
			}

			Test.stopTest();
		}
	}

	@IsTest
	private static void searchMembersTest() {
		x7sMembersController_Test test1 = new x7sMembersController_Test();
		x7sMembersController.networkId = x7sMembersUtilityTest.NETWORK_ID;
		System.assertNotEquals(x7sMembersController.networkId, null, networkIdNull);

		//TestSetupData
		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			8,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);
		System.assertEquals(8, testUsers.size(), testUserNoMatch);

		test1.objTestUser = testUsers[0];

		System.runAs(test1.objTestUser) {
			Test.startTest();

			String searchString = '0Test';

			x7sMembersWrapper members = x7sMembersController.getMemberListC(
				100,
				1,
				sortByLastName,
				'',
				searchString,
				'',
				false,
				null,
				null,
				null
			);
			try {
				System.assert(members.membersList.size() > 0, 'membersList is empty');
			} catch (Exception e) {
				System.debug(e.getMessage());
			}

			searchString = '54:phone;';
			members = x7sMembersController.getMemberListC(
				100,
				1,
				sortByFirstName,
				'',
				searchString,
				'',
				false,
				null,
				null,
				null
			);
			try {
				System.assert(members.membersList.size() > 0, 'membersList size null');
			} catch (Exception e) {
				System.debug(e.getMessage());
			}

			Test.stopTest();
		}
	}

	@IsTest
	private static void testGetFilterMemberPickLists() {
		Test.startTest();

		x7sMembersController_Test test1 = new x7sMembersController_Test();
		System.assertNotEquals(null, test1, 'test1 should not be null');

		x7sMembersController.networkId = x7sMembersUtilityTest.NETWORK_ID;
		System.assertNotEquals(x7sMembersController.networkId, null, networkIdNull);

		//TestSetupData
		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			8,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);
		System.assertEquals(8, testUsers.size(), testUserNoMatch);

		List<String> countries = x7sMembersController.getMemberPicklist('Contact.MailingCountry', '');
		System.debug('Countries ' + countries);
		System.assertNotEquals(null, countries, 'countries is null');

		List<String> cities = x7sMembersController.getMemberPicklist('Contact.MailingCity', '');
		System.debug('Cities:   ' + cities);
		System.assertNotEquals(null, cities, 'cities is null');

		List<String> states = x7sMembersController.getMemberPicklist('Contact.MailingState', '');
		System.debug('States:   ' + states);
		System.assertNotEquals(null, states, 'states is null');

		Test.stopTest();
	}

	@IsTest
	private static void testWhereClause() {
		// No database involved
		String search = 'apple';
		String result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);

		search = 'apple:;';
		result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);

		search = 'apple:phone,email;Contact.MailingCountry:US';
		result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);

		search = 'apple:phone,email;Contact.MailingCountry:US;Contact.MailingCity:Lawrence';
		result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);

		search = ':;Contact.MailingCountry:US;Contact.MailingCity:Lawrence';
		result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);

		search = 'apple:;Contact.MailingCountry:US;Contact.MailingCity:Lawrence';
		result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);
	}

	@IsTest
	private static void testWhereCustomField() {
		String search = 'apple';
		String result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);

		search = ':;Contact.Budget__c:Yes';
		result = x7sMembersController.getWhereClause(search, null);
		System.debug(debugString + search);
		System.debug(resultString + result);
		System.assertNotEquals('', result, blankResult);
	}

	@IsTest
	private static void testsetTopicMembers() {
		Test.startTest();

		Boolean result = x7sMembersController.setTopicMembers('123456789');
		System.assertEquals(false, result, 'result is false');

		Test.stopTest();
	}

	@IsTest
	private static void testGetTopicValues() {
		Test.startTest();

		Map<String, String> topics = x7sMembersController.getTopicValues();
		System.assertNotEquals(null, topics, 'topics is null');

		Test.stopTest();
	}

	@IsTest
	private static void testGetMemberIdList() {
		Set<String> testItems = new Set<String>{ '1', '2', '3' };

		String testString1 = x7sMembersController.getMemberIdList(testItems);
		System.assertNotEquals(null, testString1, 'testString is null');
	}

	@IsTest
	private static void testSetCustomFields() {
		List<String> customFieldList = new List<String>{ 'field1', 'field2', 'field3' };
		x7sMembersController.setCustomFields(customFieldList);
		System.assertNotEquals(null, x7sMembersController.customFieldList, 'customFieldList is null');
	}

	@IsTest
	static void testGetFieldType() {
		System.assertNotEquals(
			null,
			x7sMembersController.getFieldType('Contact', 'LeadSource'),
			'FieldType is null'
		);
	}

	@IsTest
	static void testGetPickListValues() {
		System.assertNotEquals(
			null,
			x7sMembersController.getPicklistValues('Contact', 'LeadSource', ''),
			'PicklistValues empty'
		);
	}

	@IsTest
	static void testUnfollowRecord() {
		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			2,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);

		EntitySubscription entitySub = new EntitySubscription(
			ParentId = testUsers[1].Id,
			SubscriberId = testUsers[0].Id,
			NetworkId = System.Network.getNetworkId()
		);
		insert entitySub;

		System.runAs(testUsers[0]) {
			Test.startTest();
			try {
				x7sMembersController.unfollowRecord(testUsers[1].Id);
			} catch (Exception e) {
			}
			Test.stopTest();
		}
	}

	@IsTest
	static void testUpdateWrapperContent() {
		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			2,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);

		System.runAs(testUsers[0]) {
			Test.startTest();
			try {
				EntitySubscription entitySub = new EntitySubscription(
					ParentId = testUsers[1].Id,
					SubscriberId = testUsers[0].Id,
					NetworkId = Network.getNetworkId()
				);
				insert entitySub;

				FeedItem fi1 = new FeedItem(
					Body = 'Test PostBody',
					Type = 'ContentPost',
					ParentId = testUsers[1].Id,
					Visibility = 'AllUsers'
				);
				insert fi1;
				FeedItem fi2 = new FeedItem(
					Body = 'Test PostBody',
					Type = 'ContentPost',
					ParentId = testUsers[0].Id,
					Visibility = 'AllUsers'
				);
				insert fi2;
				FeedLike fl = new FeedLike(FeedItemId = fi1.Id);
				insert fl;
				FeedComment tanFc = new FeedComment(
					FeedItemId = fi1.Id,
					CommentBody = 'ROSCOTESTCASE-Tanium',
					CommentType = 'TextComment',
					Status = 'Published'
				);
				insert tanFc;

				x7sMembersWrapper model = new x7sMembersWrapper();
				model.membersList = testUsers;
				model.updateWrapperContent(model.membersList);
			} catch (Exception e) {
			}
			Test.stopTest();
		}
	}

	@IsTest
	static void testUpdateControllerAttributes() {
		List<User> testUsers = x7sMembersUtilityTest.createUsers(
			2,
			x7sMembersTestConstants.COMPANY_COMMUNITY_PROFILE_NAME
		);
		testUsers[0].CommunityNickname = 'Nickname1';
		testUsers[1].CommunityNickname = 'Nickname2';
		update testUsers;

		Test.startTest();
		x7sMembersWrapper model = new x7sMembersWrapper();
		model.setController = new ApexPages.StandardSetController(
			Database.getQueryLocator(
				'SELECT Id, Name, CommunityNickname, Email, Title, Phone, CreatedDate, FullPhotoUrl, UserPreferencesShowTitleToExternalUsers, UserPreferencesShowTitleToGuestUsers, UserPreferencesShowMobilePhoneToExternalUsers, UserPreferencesShowMobilePhoneToGuestUsers, UserPreferencesShowEmailToExternalUsers, UserPreferencesShowCountryToExternalUsers, UserPreferencesShowCountryToGuestUsers, UserPreferencesShowEmailToGuestUsers FROM USER  WHERE Id IN :testUsers'
			)
		);
		model.updateControllerAttributes(
			true,
			new List<String>{ testUsers[0].CommunityNickname, testUsers[1].CommunityNickname }
		);
		Test.stopTest();
	}
}