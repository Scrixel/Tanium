/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public class x7sIdeasListWrapperTest {
	public static Network currNetwork;
	public static List<Community> currCommunity;
	public static List<Idea> currIdeaList;

	private static final String TestIdeaName = 'test_X7__1';


	static void testSetupQuery() {
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		currIdeaList = [SELECT Id FROM Idea WHERE Title = 'test_X7__1' ORDER BY CreatedDate DESC];
	}

	@TestSetup
	static void testSetupData() {
		x7sIdeasListWrapperTest.testSetupQuery();

		System.assertNotEquals(null, x7sIdeasListWrapperTest.currCommunity);
		System.assert(x7sIdeasListWrapperTest.currCommunity.size() > 0);

		Idea currIdea = new Idea(CommunityId = currCommunity[0].Id, Title = TestIdeaName, Related_Topic_Name__c = 'test_X7__1');
		Idea currIdea2 = new Idea(CommunityId = currCommunity[0].Id, Title = TestIdeaName, Related_Topic_Name__c = 'test_X7__1');

		List<Idea> tmpIdeaList = new List<Idea>();
		tmpIdeaList.add(currIdea);
		tmpIdeaList.add(currIdea2);
		insert tmpIdeaList;

		System.assertNotEquals(null, tmpIdeaList[0].Id);
		System.assertNotEquals(null, tmpIdeaList[1].Id);
	}

	@IsTest
	static void test_X7S_ideaListWrapper() {

		Topic t = new Topic(Name = TestIdeaName);
		insert t;

		x7sIdeasListWrapperTest.testSetupQuery();

		Id ideaId1 = x7sIdeasListWrapperTest.currIdeaList[0].Id;
		Id ideaId2 = x7sIdeasListWrapperTest.currIdeaList[1].Id;

		String QUERY = 'SELECT Id, Title, Status, CreatedBy.Name, CreatedBy.Id, Related_Topic_Name__c,';
		QUERY += ' Body, CreatedDate, Categories, numComments, VoteTotal, attachmentName FROM Idea WHERE Id =\'' + ideaId1 + '\' OR Id =\'' + ideaId2 + '\' ORDER BY CreatedDate DESC';

		x7sIdeasListWrapper ilw = new x7sIdeasListWrapper(QUERY, 1);

		System.assertNotEquals(null, ilw);
		System.assertNotEquals(null, ilw.ideaList);
		System.assert(ilw.ideaList.size() == 1);
		System.assert(ilw.pageNumber == 1);
		System.assert(ilw.ideaList[0].Id == ideaId1);

		// custom settings
		System.assertNotEquals(null, ilw.debugMode);
		System.assertNotEquals(null, ilw.allowDownVoting);

		ilw.nextPage();
		System.assert(ilw.pageNumber == 2);
		System.assert(ilw.ideaList[0].Id == ideaId2);

		ilw.previousPage();
		System.assert(ilw.pageNumber == 1);
		System.assert(ilw.ideaList[0].Id == ideaId1);
	}
}