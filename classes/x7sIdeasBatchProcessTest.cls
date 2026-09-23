/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sIdeasBatchProcessTest {
	public static List<Community> currCommunity;
	final static Integer TEST_MAX = 1;

	@IsTest
	static void test() {
		// Create test records to be updated by batch
		currCommunity = [SELECT Id, Name FROM Community WHERE IsActive = TRUE];
		List<Idea> ideaList = new List<Idea>();
		for (Integer i = 0; i < TEST_MAX; i++) {
			Idea ideas = new Idea(CommunityId = currCommunity[0].Id, Title = 'test ' + i, Idea_Extension_Status__c = 'None');
			ideaList.add(ideas);
		}
		insert ideaList;
		List<Idea> ideaInsertList = [SELECT Id, Idea_Extension_Status__c FROM Idea WHERE Idea_Extension_Status__c = 'None'];
		System.debug('Final idea list: ' + ideaInsertList);

		Test.startTest(); {
			System.debug('Running batch');
			x7sIdeasBatchProcess BatchObject = new x7sIdeasBatchProcess();
			Id batchProcessId = Database.executeBatch(BatchObject);
			System.assertNotEquals(null, batchProcessId);
		}
		Test.stopTest();

		// Verify
		List<Idea> ideaUpdatedList = [SELECT Id, Idea_Extension_Status__c FROM Idea WHERE Idea_Extension_Status__c = 'Linked'];
		System.assertEquals(TEST_MAX, ideaUpdatedList.size());
		System.debug('Final idea list: ' + ideaUpdatedList);
	}
}