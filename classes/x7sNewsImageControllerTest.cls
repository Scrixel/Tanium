/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

@IsTest
public class x7sNewsImageControllerTest {

    private static final String RELATED_FILES = 'Related File';
    private static final String EXTERNAL_URL = 'External URL';
    private static final String STATIC_RESOURCE = 'Static Resource';    
    private static final String CMS_CONTENT = 'CMS Content';
    private static final String TEST_NEWS_NAME = 'Test New News';
    private static final String TEST_NEWS_DESCRIPTION = 'Test Description';
    private static final String MESSAGE_NULL_RECORD = 'record should not be null.';
    
    @IsTest
    static void testGetImageTypes() {
        User u = x7sNewsUtilityTest.createUsers(1, 'Customer Community User')[0];

		System.runAs(u) {
            Test.startTest();
            Map<String,String> imageTypes = x7sNewsImageController.getImageTypes();
            System.assertEquals(false, imageTypes.isEmpty(),'Image type should not be empty');

            Test.stopTest();
        }
    }

    @IsTest 
    static void testGetImageURL() {
        User u = x7sNewsUtilityTest.createUsers(1, 'Customer Community User')[0];

		System.runAs(u) {
            Test.startTest();

                x7sNewsModel newNewsObj2 = new x7sNewsModel();
                
                X7S_News__c newsObj2 = new X7S_News__c();
                newsObj2.Name = TEST_NEWS_NAME;
                newsObj2.Details__c = TEST_NEWS_DESCRIPTION;
                newsObj2.Publish_DateTime__c = System.today().addDays(5);
                newsObj2.GroupId__c = '';
                newsObj2.Private_Group__c = false;
                newsObj2.Image_Type__c = STATIC_RESOURCE;
                newsObj2.Image_Reference__c = 'https://unit.test.com';

                //Call Save method to insert new News record
                newNewsObj2 = x7sNewsController.saveNews(newsObj2, '','', '','', '', false);
                System.assertNotEquals(newNewsObj2.id, null, MESSAGE_NULL_RECORD);

                X7S_News__c news2 = [SELECT Id,Image_Type__c,Image_Reference__c FROM X7S_News__c WHERE Id= :newNewsObj2.id LIMIT 1];
            
             	x7sNewsModel newNewsObj3 = new x7sNewsModel();
            
                X7S_News__c newsObj3 = new X7S_News__c();
                newsObj3.Name = TEST_NEWS_NAME;
                newsObj3.Details__c = TEST_NEWS_DESCRIPTION;
                newsObj3.Publish_DateTime__c = System.today().addDays(5);
                newsObj3.GroupId__c = '';
                newsObj3.Private_Group__c = false;
                newsObj3.Image_Type__c = EXTERNAL_URL;
                newsObj3.Image_Reference__c = 'https://unit.test.com';

                //Call Save method to insert new News record
                newNewsObj3 = x7sNewsController.saveNews(newsObj3, '','', '','', '', false);
                System.assertNotEquals(newNewsObj3.id, null,MESSAGE_NULL_RECORD);

                X7S_News__c news3 = [SELECT Id,Image_Type__c,Image_Reference__c FROM X7S_News__c WHERE Id= :newNewsObj3.id LIMIT 1];

            ContentVersion cv = new ContentVersion(title = 'test content', PathOnClient ='TestDocument.jpg',VersionData =Blob.valueOf('Test Content'));          
                insert cv;
                Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cv.Id].ContentDocumentId;
                ContentDocument document = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument WHERE Id = :conDocId];

                x7sNewsModel newNewsObj4 = new x7sNewsModel();
            
                X7S_News__c newsObj4 = new X7S_News__c();
                newsObj4.Name = TEST_NEWS_NAME;
                newsObj4.Details__c = TEST_NEWS_DESCRIPTION;
                newsObj4.Publish_DateTime__c = System.today().addDays(5);
                newsObj4.GroupId__c = '';
                newsObj4.Private_Group__c = false;
                newsObj4.Image_Type__c = RELATED_FILES;
                newsObj4.Image_Reference__c = document.LatestPublishedVersionId;

                //Call Save method to insert new News record
                newNewsObj4 = x7sNewsController.saveNews(newsObj4, '','', '','', '', false);
                System.assertNotEquals(newNewsObj4.id, null,MESSAGE_NULL_RECORD);

                X7S_News__c news4 = [SELECT Id,Image_Type__c,Image_Reference__c FROM X7S_News__c WHERE Id= :newNewsObj4.id LIMIT 1];

                ContentDocumentLink contentlink=new ContentDocumentLink( LinkedEntityId = news4.id, ShareType= 'V',ContentDocumentId = conDocId);
                insert contentlink;             

            List<X7S_News__c> newsList = new List<X7S_News__c>();
            newsList.add(news2);
            newsList.add(news3);
            newsList.add(news4);
            Map<Id,String> newstoImageURLMap = x7sNewsImageController.getImageURL(newsList);
            System.assertEquals(3, newstoImageURLMap.size(),'There must be 3 image urls');
            Test.stopTest();
        }   
    }

    @isTest(SeeAllData=true)
	static void testsaveNewsWithCMSImage() 
	{
        Test.startTest();        
         	x7sNewsModel newNewsObj1 = new x7sNewsModel();
                
            X7S_News__c newsObj1 = new X7S_News__c();
            newsObj1.Name = TEST_NEWS_NAME;
            newsObj1.Details__c = TEST_NEWS_DESCRIPTION;
            newsObj1.Publish_DateTime__c = System.today().addDays(5);
            newsObj1.GroupId__c = '';
            newsObj1.Private_Group__c = false;
            newsObj1.Image_Type__c = CMS_CONTENT;
            newsObj1.Image_Reference__c = '20Y4x000TY04icCEAQ';

            newNewsObj1 = x7sNewsController.saveNews(newsObj1, '','', '','', '', false);
            System.assertNotEquals(newNewsObj1.id, null,MESSAGE_NULL_RECORD);

        Test.stopTest();
    }

    @isTest(SeeAllData=true)
	static void testGetCMSImageForCommunity() 
	{
        String contentId1  = '20Y4x000TY04icCEAQ';
        String contentId2  = '20Y4x000TY04icCEAQ';

        Test.startTest();
            List<String> contentIds = new List<String>();
            contentIds.add(contentId1);
            contentIds.add(contentId2);
            Map<Id,String> newsWithCMSImage = new Map<Id,String>();
            newsWithCMSImage.put((Id) '20Y4x0007804icCEAQ', contentId1);
            newsWithCMSImage.put((Id) '20Y4x0007804i78EAQ', contentId2);
            Map<String,String> imageURLMap = x7sNewsImageController.getCMSImageURL(newsWithCMSImage, contentIds);
            System.assertEquals(true, imageURLMap.isEmpty(),'url should not be empty');

            Map<String,String> imageURLMap2 = x7sNewsImageController.getCMSImageURLForCommunity(contentIds);
            System.assertEquals(true, imageURLMap2.isEmpty(),'url should not be empty');

            List<String> contentIds1 = new List<String>();
            Map<Id,String> newsWithCMSImage1 = new Map<Id,String>();

            Map<String,String> imageURLMap1 = x7sNewsImageController.getCMSImageURL(newsWithCMSImage1, contentIds1);
            System.assertEquals(true, imageURLMap1.isEmpty(),'url should not be empty');

        Test.stopTest();
    }
}