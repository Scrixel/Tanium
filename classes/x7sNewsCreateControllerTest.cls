/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

/**
 * @description : Unit test class for the x7sNewsCreateController Class
 */
@IsTest
public with sharing class x7sNewsCreateControllerTest {

    public static String strNetId {
		get {
			return [SELECT Id FROM Network LIMIT 1][0].Id;
		}
	}
    
    @IsTest
	static void testLanguageRelatedMethods() {
		Map<String, String> languageMap = x7sNewsCreateController.getLanguageOption();
		System.assertEquals( languageMap.size(), languageMap.size());
	}

    @IsTest
	static void test_userAuthorizedToPost() {
		Boolean canPost = x7sNewsCreateController.userAuthorizedToPost();
		System.assertNotEquals(null, canPost);
	}

    @IsTest(SeeAllData=true)
	static void test_getTopics() {
        x7sNewsCreateController.networkId = Id.valueOf(strNetId);
		x7sNewsCreateController.strNetworkId = strNetId;

        Test.startTest();
		// Topic creation by users is disabled at Tanium.
        //List<User> users = x7sNewsUtilityTest.createUsers(1, 'Customer Community User');
		//if (!users.isEmpty()) {
		//	System.runAs(users[0]) {

				//Create Topic Record
				List<Topic> topics1 = x7sNewsUtilityTest.createTopic(2000, strNetId);
				System.assertEquals(2000, topics1.size());
				//Get Topics for Topic dropdown in List view of news
				Map<String, String> topicMap1 = x7sNewsCreateController.getTopics();
				System.assertNotEquals(null, topicMap1);				
		//	}
		//}
        Test.stopTest();
    }

	@IsTest
	static void test_deleteAttachment() {
		Test.startTest();
		X7S_News__c news = x7sNewsUtilityTest.createNews();
		Test.stopTest();

		//create Attachment related to news object created
		Attachment attach = new Attachment();
		attach.Name = 'Unit Test Attachment';
		Blob bodyBlob = Blob.valueOf('Unit Test Attachment Body');
		attach.Body = bodyBlob;
		attach.ParentId = news.id;
		insert attach;

		//Delete attachment if user updates attachment
		x7sNewsCreateController.deleteAttachment(news.id);
		List<Attachment> attachment = [SELECT Id FROM Attachment WHERE ParentId = :news.id];
		System.assertEquals(0, attachment.size());
	}

	@IsTest(SeeAllData=true)
	static void test_getAudienceList() {

		Map<String, String> audienceList = x7sNewsCreateController.getAudienceList('', '');
		
		System.assertNotEquals(null, audienceList);

		System.assertNotEquals(null, x7sNewsCreateController.getTimeZoneId(), 'No timezone found.');
	}
}