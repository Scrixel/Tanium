/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sIdeasTriggerHelperTest {

	private static final String TEST_IDEA_NAME = 'test_dev_01';


	@IsTest
	static void testCreateIdeaExtensionRecord() {
		List<Idea> ideasToInsert = new List<Idea>();

		String metadataQuery = 'SELECT Id, DeveloperName, MasterLabel,Enable_Idea_Extension_Functionality__c FROM X7S_Ideas_Setting__mdt';
		metadataQuery = metadataQuery + ' WHERE DeveloperName = \'Default\'';
		List<X7S_Ideas_Setting__mdt> listOfIdeaSettings = (List<X7S_Ideas_Setting__mdt>) Database.query(metadataQuery);

		List<Community> community = [SELECT Id FROM Community LIMIT 1];
		if (!community.isEmpty()) {

			Idea currIdea = new Idea(Title = TEST_IDEA_NAME, Related_Topic_Name__c = 'Test 1', CommunityId = community[0].Id);
			ideasToInsert.add(currIdea);
			insert ideasToInsert;

			List<X7S_Ideas_Extension__c> listOfExtIdea = new List<X7S_Ideas_Extension__c>([SELECT Id,Idea__c FROM X7S_Ideas_Extension__c WHERE Idea__c = :ideasToInsert[0].Id]);
			if (listOfIdeaSettings[0].Enable_Idea_Extension_Functionality__c) {
				System.assertEquals(listOfExtIdea.size(), 1, 'Idea extension not inserted');
			}
			else {
				System.assertEquals(listOfExtIdea.size(), 0, 'Idea extension not inserted');
			}
		}
	}
}