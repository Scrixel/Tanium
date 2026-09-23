/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasVotersControllerTest {
	public static Network currNetwork;
	public static List<Community> currCommunity;
	public static List<Idea> currIdeaList;

	static void testSetupQuery() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdeaList = [SELECT Id FROM Idea WHERE Title = 'test' ORDER BY CreatedDate DESC];
	}

	@TestSetup
	static void testSetupData() {
		x7sIdeasVotersControllerTest.testSetupQuery();
		System.assertNotEquals(null, x7sIdeasVotersControllerTest.currCommunity);
		System.assert(x7sIdeasVotersControllerTest.currCommunity.size() > 0);
		Idea currIdea = new Idea(CommunityId = currCommunity[0].Id, Title = 'test', Related_Topic_Name__c = 'test');
		Idea currIdea2 = new Idea(CommunityId = currCommunity[0].Id, Title = 'test', Related_Topic_Name__c = 'test');
		List<Idea> tmpIdeaList = new List<Idea>();
		tmpIdeaList.add(currIdea);
		tmpIdeaList.add(currIdea2);
		insert tmpIdeaList;
		System.assertNotEquals(null, tmpIdeaList[0].Id);
		System.assertNotEquals(null, tmpIdeaList[1].Id);
	}

	@IsTest
	static void test_isAuthenticated() {
		System.assert(true, x7sIdeasVotersController.isAuthenticated());
	}

	@IsTest
	static void test_isNicknameDisplayEnabled() {
		System.assertEquals(true, x7sIdeasVotersController.isNicknameDisplayEnabled());
	}

	@IsTest
	static void test_getSitePrefix() {
		System.assertEquals('', x7sIdeasVotersController.getSitePrefix());
	}

	@IsTest
	static void test_getZoneId() {
		x7sIdeasVotersControllerTest.testSetupQuery();
		System.assertNotEquals('', x7sIdeasVotersController.getZoneId(x7sIdeasVotersControllerTest.currCommunity[0].Name));
		System.assertEquals('', x7sIdeasVotersController.getZoneId('______'));
		System.assertEquals('', x7sIdeasVotersController.getZoneId(''));
	}

	@IsTest
	static void test_isValidIdeaId() {
		x7sIdeasVotersControllerTest.testSetupQuery();
		Boolean isValid = x7sIdeasVotersController.isValidIdeaId(x7sIdeasVotersControllerTest.currIdeaList[0].Id, x7sIdeasVotersControllerTest.currCommunity[0].Id);
		System.assertEquals(true, isValid);

		Id tmpId = x7sIdeasVotersControllerTest.currIdeaList[0].Id;
		delete x7sIdeasVotersControllerTest.currIdeaList[0];
		isValid = x7sIdeasVotersController.isValidIdeaId(tmpId, x7sIdeasVotersControllerTest.currCommunity[0].Id);
		System.assertEquals(false, isValid);

		isValid = x7sIdeasVotersController.isValidIdeaId('sdfsdfsd', x7sIdeasVotersControllerTest.currCommunity[0].Id);
		System.assertEquals(false, isValid);
	}

	@IsTest
	static void test_getTotalVoterCount() {
		x7sIdeasVotersControllerTest.testSetupQuery();
		System.assertEquals(1, x7sIdeasVotersController.getTotalVoterCount(x7sIdeasVotersControllerTest.currIdeaList[0].Id));
	}

	@IsTest
	static void test_getIdeaVoters() {
		x7sIdeasVotersControllerTest.testSetupQuery();
		System.assertEquals(1, x7sIdeasVotersController.getIdeaVoters(x7sIdeasVotersControllerTest.currIdeaList[0].Id, 10).size());
	}
}