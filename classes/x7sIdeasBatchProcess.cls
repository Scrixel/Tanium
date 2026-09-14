/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

global class x7sIdeasBatchProcess implements Database.Batchable<SObject> {

	private static final Integer MAX_IDEAS = 50000;
	private static final String PENDING = 'Pending';
	private static final String NONE = 'None' ;
	private static Integer ideaCount = 0;

	global Database.QueryLocator start(Database.BatchableContext BC) {
		String query = 'SELECT Id, Idea_Extension_Status__c FROM Idea WHERE Idea_Extension_Status__c =: NONE';
		if (Test.isRunningTest()) {
			query = 'SELECT Id, Idea_Extension_Status__c FROM Idea LIMIT :MAX_IDEAS';
		}
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<Idea> ideaList) {
		for (Idea idea : ideaList) {
			if (idea.Idea_Extension_Status__c == NONE) {
				idea.Idea_Extension_Status__c = PENDING;
				++ideaCount;
			}
		}
		try {
			update ideaList;
		}
		catch (Exception e) { System.debug('x7sIdeasBatchProcess exception: ' + e.getMessage()); }
	}

	global void finish(Database.BatchableContext BC) {
		System.debug('Updated ideas count: ' + ideaCount);
	}
}