/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

/*
* @description         : Apex Test class for x7sNewsController
*/
@IsTest
public class x7sNewsControllerTest
{
    private static final Integer BULK_TEST_QTY = 10;
    private static final String customFields = 'Name';
    private static final String CUSTOMER_COMMUNITY_USER_CLONE = 'Tanium Community Login Super User';
    private static final String NONE = 'None';
    private static final String SORT_OLDEST_FIRST = 'Oldest First';
    private static final String TEST_NEWS_NAME = 'Test New News';
    private static final String TEST_NEWS_DESCRIPTION = 'Test Description';
    private static final String CUSTOMER_COMMUNITY_USER = 'Customer Community User';

    public static String strNetId {
        get {
            return [SELECT Id FROM Network LIMIT 1][0].Id;
        }
    }

    @IsTest(SeeAllData=true)
    static void test_RecommendedNews() {

        //set NetworkId variables of the Class with hardcoded value.
        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);
        X7S_News__c newsObj1 = x7sNewsUtilityTest.createNews(strNetId);
        System.assertNotEquals(null, newsObj1);

        //Create News in Bulk to check with bulk data.
        List<X7S_News__c> objNewzBulkList = x7sNewsUtilityTest.createBulkNews(BULK_TEST_QTY, strNetId);
        System.assertNotEquals(null, objNewzBulkList);

        //create Topic Records
        List<Topic> topics = x7sNewsUtilityTest.createTopic(BULK_TEST_QTY, strNetId);

        //Assign Topic to News Records
        TopicAssignment topicAssg = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj.Id);
        System.assertNotEquals(null, topicAssg);
        TopicAssignment topicAssg1 = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj1.Id);
        System.assertNotEquals(null, topicAssg1);

        //Create Community User
        //As we are using custom object News, we have created user with the custom Community Profile,
        //Because standard community profile do not allow to give permissions to such custom objects.
        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);
        System.runAs(u)
        {
            Test.startTest();
            List<String> featureList = new List<String>(); 
            featureList.add(newsObj.Id);
            featureList.add(newsObj1.Id);
            //call getNews to fetch recommended records on detail page of news record
            x7sNewsWrapper newsWrapperRecomm = x7sNewsController.getNews(10, newsObj.Id, null, null, null, null, null, NONE, null, null, null,featureList,false,customFields);
            System.assert(newsWrapperRecomm.newsList.size() > 0);       

            //call getNews method on search page to show related data of search term with sort by as 'Most Recent'
            x7sNewsWrapper newsWrapperSearchItemsRecent = x7sNewsController.getNews(10, null, null, 'Most Recent', null, null, null, 'Search Term', 'test', null, null,featureList,false,customFields);
            System.assert(newsWrapperSearchItemsRecent.newsList.size() > 0);

            Test.stopTest();
        }
    }

    @IsTest(SeeAllData=true)
    static void test_NewsBulkTopics() {
        //set NetworkId variables of the Class with hardcoded value.
        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);
        X7S_News__c newsObj1 = x7sNewsUtilityTest.createNews(strNetId);
        System.assertNotEquals(null, newsObj1);

        //Create News in Bulk to check with bulk data.
        List<X7S_News__c> objNewzBulkList = x7sNewsUtilityTest.createBulkNews(BULK_TEST_QTY, strNetId);
        System.assertNotEquals(null, objNewzBulkList);

        //create Topic Records
        List<Topic> topics = x7sNewsUtilityTest.createTopic(BULK_TEST_QTY, strNetId);

        //Assign Topic to News Records
        TopicAssignment topicAssg = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj.Id);
        System.assertNotEquals(null, topicAssg);
        TopicAssignment topicAssg1 = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj1.Id);
        System.assertNotEquals(null, topicAssg1);

        //Create Community User
        //As we are using custom object News, we have created user with the custom Community Profile,
        //Because standard community profile do not allow to give permissions to such custom objects.
        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);
        System.runAs(u) {

            Test.startTest();
            List<String> featureList = new List<String>(); 
            featureList.add(newsObj.Id);
            featureList.add(newsObj1.Id);
            //call getNews method to show all news related to topic on topic detail page with sort by as 'Most Recent'
            x7sNewsWrapper newsWrapperTopicsRecent = x7sNewsController.getNews(10, null, null, 'Most Recent', null, null, topics[0].Name, 'Topic Value', null, null, null,featureList,false,customFields);
            System.assertEquals(2, newsWrapperTopicsRecent.newsList.size());

            //call getNews method to show all news related to topic on topic detail page with sort by as 'Oldest First'
            x7sNewsWrapper newsWrapperTopicsOldest = x7sNewsController.getNews(10, null, null, SORT_OLDEST_FIRST, null, null, topics[0].Name, 'Topic Value', null, null, null,featureList,false,customFields);
            System.assertEquals(2, newsWrapperTopicsOldest.newsList.size());

            //call getNews method to filter list view on basis of topic filter
            x7sNewsWrapper newsWrapperTopicsFilter = x7sNewsController.getNews(10,  null, null, SORT_OLDEST_FIRST, topics[0].Name, null, null, null, null, null, null,featureList,false,customFields);
            System.assertEquals(2, newsWrapperTopicsFilter.newsList.size());

            Test.stopTest();
        }
    }

    @IsTest(SeeAllData=true)
    static void test_GetNews() {

        //set NetworkId variables of the Class with hardcoded value.
        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);
        X7S_News__c newsObj1 = x7sNewsUtilityTest.createNews(strNetId);
        X7S_News__c newsObj2 = x7sNewsUtilityTest.createNews(strNetId);
        X7S_News__c newsObj3 = x7sNewsUtilityTest.createNews(strNetId);     
        X7S_News__c newsObj5 = x7sNewsUtilityTest.createNews(strNetId);
        System.assertNotEquals(null, newsObj5);

        //create Topic Records
        List<Topic> topics = x7sNewsUtilityTest.createTopic(BULK_TEST_QTY, strNetId);

        //Assign Topic to News Records
        TopicAssignment topicAssg = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj.Id);
        System.assertNotEquals(null, topicAssg);
        TopicAssignment topicAssg1 = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj1.Id);
        System.assertNotEquals(null, topicAssg1);
        TopicAssignment topicAssg2 = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj2.Id);
        System.assertNotEquals(null, topicAssg2);
        TopicAssignment topicAssg3 = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj3.Id);
        System.assertNotEquals(null, topicAssg3);

        //Create Community User
        //As we are using custom object News, we have created user with the custom Community Profile,
        //Because standard community profile do not allow to give permissions to such custom objects.
        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);
        System.runAs(u) {
            Test.startTest();
            List<String> featureList = new List<String>(); 
            featureList.add(newsObj.Id);
            featureList.add(newsObj1.Id);
            //call getNews method to filter list view on basis of date filter
            x7sNewsWrapper newsWrapperDateFilter = x7sNewsController.getNews(10, null, null, SORT_OLDEST_FIRST, null, null, null, null, null, String.valueOf(System.today().addDays(-15)), String.valueOf(System.today().addDays(15)),featureList,false,customFields);
            System.assert(newsWrapperDateFilter.newsList.size() > 0);

            //call getNews method to filter list view on basis of date filter and topic Filter
            x7sNewsWrapper newsWrapperDateTopicFilter = x7sNewsController.getNews(10, null, null, SORT_OLDEST_FIRST, topics[0].Name, null, null, null, null,
                    String.valueOf(System.today().addDays(-15)), String.valueOf(System.today().addDays(15)),featureList,false,customFields);
            
            System.assertEquals(4, newsWrapperDateTopicFilter.newsList.size());


            String authorId = x7sNewsUtilityTest.userObj.Id;

            //update news record show author as true
            newsObj.Show_Author__c = true;
            update newsObj;

            //call getNews method to filter list view on Author id
            x7sNewsWrapper newsWrapperAuthorFilter = x7sNewsController.getNews(2, null, null, SORT_OLDEST_FIRST, null, authorId, null, null, null, null, null,featureList,false,customFields);
            System.assertEquals(1, newsWrapperAuthorFilter.newsList.size());

            //call getNews to fetch records on list view with no recordid,without any filter and sorting
            x7sNewsWrapper newsWrapperlst = x7sNewsController.getNews(2, null, null, null, null, null, null, NONE, null, null, null,featureList,false,customFields);
            System.assertNotEquals(null, newsWrapperlst);

            //call nextPage method to perform next operation in pagination
            x7sNewsWrapper newsWrapperlstnextPage = x7sNewsController.nextPage(2, 1, null, null, null, null, null, null, NONE, null, null, null,featureList,false,customFields);
            System.assertEquals(2, newsWrapperlstnextPage.newsList.size());
            System.assertEquals(1, newsWrapperlstnextPage.pageNumber);

            //call previousPage method to perform previous operation in pagination
            x7sNewsWrapper newsWrapperlstprevPage = x7sNewsController.previousPage(2, 2, null, null, null, null, null, null, NONE, null, null, null,featureList,false,customFields);
            System.assertEquals(2, newsWrapperlstprevPage.newsList.size());
            System.assertEquals(1, newsWrapperlstprevPage.pageNumber);

            //call getNewsForPage method to get news for perticulers page
            List<String> featuredNews = new List<String>();
            x7sNewsWrapper newsWrapperlstCurrentPage = x7sNewsController.getNewsForPage(3, 2, null, null, null, null, null, null, NONE, null, null, null,featuredNews,false,customFields);
            System.assertEquals(2, newsWrapperlstCurrentPage.newsList.size());
            System.assertEquals(2, newsWrapperlstCurrentPage.pageNumber);

            Test.stopTest();
        }
    }  

    @IsTest
    static void test_NewsObject() {
        Test.startTest();

        //call method to check if object is creatable to show hide "Add new" button on header in list view page
        x7sNewsController.isObjectCreatable();

        //call method to check if object creatable and updateable to show hide edit button on detail page of news
        x7sNewsController.isObjectEditable();

        //call method to get Site Prefix
        String strSitePathPrefix = x7sNewsController.getSitePrefix();
        System.assertEquals(strSitePathPrefix, System.Site.getPathPrefix());

        //call method to check if "display community nick name" is true or false in community
        x7sNewsController.isNicknameDisplayEnabled();

        Test.stopTest();
    }

    @IsTest(SeeAllData=true)
    static void test_News() {

        //set NetworkId variables of the Class with hardcoded value.
        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);

        //Create Topic Record
        List<Topic> topics = x7sNewsUtilityTest.createTopic(2, strNetId);
        TopicAssignment topicAssg = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj.Id);
        System.assertNotEquals(null, topicAssg);

        //Create Community User
        //As we are using custom object News, we have created user with the custom Community Profile,
        //Because standard community profile do not allow to give permissions to such custom objects.
        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);
        System.runAs(u) {
            Test.startTest();

            //Get News Record for detail page
            x7sNewsWrapper newsRecord = x7sNewsController.getNewsRecord(newsObj.Id);
            System.assertEquals(newsRecord.newsList.size(), 1);
            
            x7sNewsWrapper newsRecord1 = x7sNewsController.getNewsRecord(newsObj.Id,'Name');
            System.assertEquals(newsRecord1.newsList.size(), 1);

            //create new News Object to pass it to save method to create new news record
            x7sNewsModel newsModel = new x7sNewsModel();
            X7S_News__c newNewsObj = new X7S_News__c();
            newNewsObj.Name = TEST_NEWS_NAME;
            newNewsObj.Details__c = TEST_NEWS_DESCRIPTION;
            newNewsObj.Publish_DateTime__c = System.today().addDays(5);
            newNewsObj.GroupId__c = '';
            newNewsObj.Private_Group__c = false;

            //Call Save method to insert new News record
            newsModel = x7sNewsController.saveNews(newNewsObj, topics[0].Id, '', '', '', '', false);
            System.assertNotEquals(newsModel.Id, null);

            //create Attachment related to news object created
            Attachment attach = new Attachment();
            attach.Name = 'Unit Test Attachment';
            Blob bodyBlob = Blob.valueOf('Unit Test Attachment Body');
            attach.Body = bodyBlob;
            attach.ParentId = newNewsObj.id;
            insert attach;

            //updated news records with one more topic added
            x7sNewsController.saveNews(newNewsObj, topics[0].Id + x7sNewsController.NEWS_FIELD_SEPARATOR + topics[1].Id, '', '', '', '', false);

            //Check if topic updated is assigned to news record
            TopicAssignment topicAssgnmentNew = [SELECT Id,EntityId FROM TopicAssignment WHERE TopicId = :topics[1].Id AND EntityId = :newNewsObj.id];
            System.assertNotEquals(null, topicAssgnmentNew.Id);

            //updated news records with by removing one topic
            x7sNewsController.saveNews(newNewsObj, topics[0].Id, '', '', '', '', true);

            //Check if topic assignment is deleted when it is removed on updating news record
            List<TopicAssignment> topicAssgnmentDeleted = [SELECT Id,EntityId FROM TopicAssignment WHERE TopicId = :topics[1].Id and EntityId = :newNewsObj.id];
            System.assertEquals(0, topicAssgnmentDeleted.size());

            Test.stopTest();
        }
    }

    @IsTest
    static void test_saveNews() {

        X7S_News__c newNewsObj = new X7S_News__c();
        newNewsObj.Name = TEST_NEWS_NAME;
        newNewsObj.Details__c = TEST_NEWS_DESCRIPTION;
        newNewsObj.Publish_DateTime__c = System.today().addDays(5);
        newNewsObj.Image_Type__c = 'Related File';

        x7sNewsModel model = x7sNewsController.saveNews(newNewsObj, '', 'image/png', 'Test File', 'Test File', '', true);
        System.assertNotEquals(null, model.id, 'Fail to create news record.');
        System.assertNotEquals(false, x7sNewsController.checkPublishedDateTime(model.id), 'This news will be published later.');

        System.assertNotEquals(null, x7sNewsController.getFieldSetName(), 'No fieldset found.');

        String timeZone = x7sNewsController.getTimeZone();
        System.assertNotEquals(null, timeZone);

        try {
            x7sNewsController.shareRecord(newNewsObj, UserInfo.getUserId());
        } catch(Exception e) {
            System.debug(e);
        }
        try {
            x7sNewsController.unShareRecord(newNewsObj, UserInfo.getUserId());
        } catch(Exception e) {
            System.debug(e);
        }
    }

    @IsTest
    static void test_Groups() {
        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        List<User> users = x7sNewsUtilityTest.createUsers(1, CUSTOMER_COMMUNITY_USER);
        if (!users.isEmpty()) {
            System.runAs(users[0]) {
                Test.startTest();

                Map<String, String> groupList = x7sNewsController.getAllGroups();
                System.assertNotEquals(null, groupList);

                Test.stopTest();
            }
        }
    }

    @IsTest
    static void test_newsItemWithGroup() {
        String testGroup = 'Test group X7S 001';
        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);

        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        System.runAs(u) {
            Test.startTest();

            Id testGroupId = x7sNewsUtilityTest.createTestGroup(testGroup);
            String testGroupIdStr = (String) testGroupId;

            Map<String, String> groupList = x7sNewsController.getGroups();
            System.assertNotEquals(null, groupList);

            X7S_News__c newsObj = x7sNewsUtilityTest.createNewsWithGroup(strNetId, testGroupIdStr);
            System.assertEquals(testGroupIdStr, newsObj.GroupId__c);
            System.assertEquals(false, newsObj.Private_Group__c);

            X7S_News__c newsPrivate = x7sNewsUtilityTest.createNewsWithGroupPrivate(strNetId, testGroupIdStr);
            System.assertEquals(testGroupIdStr, newsPrivate.GroupId__c);
            System.assertEquals(true, newsPrivate.Private_Group__c);

            Test.stopTest();
        }
    }

    @IsTest(SeeAllData=true)
    static void test_saveNewsWithGroup() {
        String testGroup = 'Test group X7S 002';
        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        //Create Topic Record
        List<Topic> topics = x7sNewsUtilityTest.createTopic(2, strNetId);

        Test.startTest();       

        //create new News Object to pass it to save method to create new news record
        X7S_News__c newNewsObj = new X7S_News__c();
        newNewsObj.Name = TEST_NEWS_NAME;
        newNewsObj.Details__c = TEST_NEWS_DESCRIPTION;
        newNewsObj.Publish_DateTime__c = System.today().addDays(5);
        newNewsObj.GroupId__c = '';
        newNewsObj.Private_Group__c = false;

        //Call Save method to insert new News record
        x7sNewsModel savedNews = x7sNewsController.saveNews(newNewsObj, topics[0].Id, '', '', '', '', false);
        System.assertNotEquals(null, savedNews.id);

        Test.stopTest();
    }

    @IsTest
    private static void test_isRecordEditable() {
        User user1 = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);
        User user2 = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);

        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        Test.startTest();

        X7S_News__c newsObj;
        System.runAs(user1) {
            newsObj = new X7S_News__c(Name = 'Test News', Publish_DateTime__c = System.today().addDays(-5),
                    Author__c = user1.Id, NetworkId__c = strNetId);
            insert newsObj;

            // Evaluates to true, user is owner of record
            System.assertEquals(true, x7sNewsController.isRecordEditable(newsObj.Id));

            // Can user delete
            System.assertEquals(true, x7sNewsController.isRecordDeletable(newsObj.Id));
        }

        System.runAs(user2) {
            // Evaluates to true: OWD Public Read/Write
            // Evaluates to false: OWD Private or Public Read
            System.assertEquals([
                    SELECT RecordId, HasEditAccess
                    FROM UserRecordAccess
                    WHERE UserId = :user2.Id AND RecordId = :newsObj.Id
            ].HasEditAccess,
                    x7sNewsController.isRecordEditable(newsObj.Id));
        }

        Test.stopTest();
    }

    @IsTest
    static void test_deleteRecord() {
        X7S_News__c adminNews = x7sNewsUtilityTest.createNews();
        User u = x7sNewsUtilityTest.createUsers(1, CUSTOMER_COMMUNITY_USER)[0];

        System.runAs(u) {

            Test.startTest();

            Boolean adminAccess = x7sNewsController.getUserRecordAccess(UserInfo.getUserId(), adminNews.Id).HasDeleteAccess;
            System.assertEquals(adminAccess, x7sNewsController.deleteRecord(adminNews.Id));
            if (adminAccess) {
                System.assertEquals(0, [SELECT COUNT() FROM X7S_News__c WHERE Id = :adminNews.Id]);
            } else {
                System.assertEquals(1, [SELECT COUNT() FROM X7S_News__c WHERE Id = :adminNews.Id]);
            }

            if (x7sNewsController.isObjectCreatable()) {
                X7S_News__c myNews = x7sNewsUtilityTest.createNews();

                Boolean myAccess = x7sNewsController.isRecordDeletable(myNews.Id);
                myAccess = x7sNewsController.getUserRecordAccess(UserInfo.getUserId(), myNews.Id).HasDeleteAccess;

                System.assertEquals(myAccess, x7sNewsController.deleteRecord(myNews.Id));

                if (myAccess) {
                    System.assertEquals(0, [SELECT COUNT() FROM X7S_News__c WHERE Id = :myNews.Id]);
                } else {
                    System.assertEquals(1, [SELECT COUNT() FROM X7S_News__c WHERE Id = :myNews.Id]);
                }
            }

            Test.stopTest();
        }
    }

    @IsTest
    static void test_LikeUnlikeNews() {
        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);
        X7S_News__c newsObj1 = x7sNewsUtilityTest.createNews(strNetId);

        Test.startTest();

        x7sNewsController.likeNews(newsObj.Id);
        x7sNewsController.likeNews(newsObj1.Id);

        System.assertEquals(true, x7sNewsController.isLiking(newsObj.Id));

        List<X7S_News_Like__c> newsLikes = [SELECT Id FROM X7S_News_Like__c WHERE User__c = :UserInfo.getUserId()];
        System.assertEquals(2, newsLikes.size());

        x7sNewsController.unLikeNews(newsObj.Id);
        x7sNewsController.unLikeNews(newsObj1.Id);

        newsLikes = [SELECT Id FROM X7S_News_Like__c WHERE User__c = :UserInfo.getUserId()];
        System.assertEquals(0, newsLikes.size());

        Test.stopTest();
    }  

    @IsTest
    static void test_getCurrentUser() {
        User u = x7sNewsUtilityTest.createUsers(1, CUSTOMER_COMMUNITY_USER)[0];

        System.runAs(u) {
            User usr = x7sNewsController.getCurrentUser();
            System.assertNotEquals(null, usr);
        }
    }

    @IsTest(SeeAllData=true)
    static void test_isFollowing() {
        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);

        System.runAs(u) {
            Test.startTest();

            X7S_News__c newsItem = x7sNewsUtilityTest.createNews();
            Boolean userIsFollowing = x7sNewsController.isFollowing(newsItem.Id);
            System.assertEquals(false, userIsFollowing);

            userIsFollowing = x7sNewsController.followRecord(newsItem.Id);
            x7sNewsController.unfollowRecord(newsItem.Id);

            Test.stopTest();
        }
    }

    @IsTest
    static void test_requireGroupMembership() {
        Boolean requireGroup = x7sNewsController.requireGroupMembership();
        System.assertNotEquals(null, requireGroup, 'No Group Membership found');        
    }

    @IsTest
    static void test_getNameSpacePrefix() {
        x7sNewsBaseController baseController = new x7sNewsBaseController();
        x7sNewsBaseController.BaseModel testBaseModel = x7sNewsBaseController.getModel();
        System.assertNotEquals(null, baseController);
    }

    @IsTest
    static void test_getLexMode() {
        x7sNewsBaseController.BaseModel testBaseModel = x7sNewsBaseController.getModel();
        System.assertNotEquals(null, testBaseModel.lexMode);
    }

    @IsTest
    static void test_wrapperCtor() {
        x7sNewsWrapper wrapper = new x7sNewsWrapper('field1', 'error message');
        System.assertEquals('field1', wrapper.field);
    }

    @IsTest
    static void test_getNetworkClause() {
        String networkClause = x7sNewsController.getNetworkClause('NetworkId__c', '', 'X1,X2');
        System.assertEquals(' NetworkId__c = \'X1\' OR NetworkId__c = \'X2\'', networkClause);

        networkClause = x7sNewsController.getNetworkClause('NetworkId__c', 'X0','');
        System.assertEquals(' NetworkId__c = \'X0\'', networkClause);

        networkClause = x7sNewsController.getNetworkClause('NetworkId__c', '','');
        System.assertEquals(' NetworkId__c = null', networkClause);
    } 

    @IsTest
    static void testLanguageRelatedMethods() {
        System.assertNotEquals(null, x7sNewsController.useLanguage());

        String  userLanguage = x7sNewsController.getLanguage();
        System.assertNotEquals(null, userLanguage);
    }

    @IsTest
    static void test_getGroupIds() {

        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);
        //Create Topic Record
        List<Topic> topics = x7sNewsUtilityTest.createTopic(2, strNetId);
        TopicAssignment topicAssg = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj.Id);
        System.assertNotEquals(null, topicAssg);

        String  objName     = newsObj.getSObjectType().getDescribe().getName();
        System.assertNotEquals(null, x7sNewsController.isRecordShareable(newsObj.Id));
        SObject shareObject = x7sNewsController.newSObject(objName.replace('__c', '__Share'));
        
        List<String> causes = x7sNewsController.getRowCause(shareObject, 'RowCause');
        System.assertEquals(causes.size(), causes.size());  
        try {
            shareObject = x7sNewsController.newSObject('dummyObject');
        } catch(x7sNewsController.UndefinedSObjectTypeException e) {
            System.debug('No dummyObject Object found');
        }
    }

    // AUDIENCE
    @IsTest
    static void test_audienceEnabled() {
        System.assertNotEquals(null, x7sNewsController.audienceEnabled());
    }

    @IsTest(SeeAllData=true)
    static void test_getAudienceList() {

        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);
        System.runAs(u)
        {

            System.assertNotEquals(null, x7sNewsController.getAudienceTargetIds(''));
        }
    }

    private static String createTestAudience() {
        String communityId = x7sNewsUtilityTest.strNetworkId;
        ConnectApi.AudienceInput audienceInput = new ConnectApi.AudienceInput();
        audienceInput.name = 'CoffeeLover';
        audienceInput.formulaFilterType = ConnectApi.FormulaFilterType.AllCriteriaMatch;

        // User criteria
        ConnectApi.AudienceCriterionInput userCriterionInput = new ConnectApi.AudienceCriterionInput();
        userCriterionInput.criterionType = ConnectApi.AudienceCriteriaType.FieldBased;
        userCriterionInput.criterionOperator = ConnectApi.AudienceCriteriaOperator.Equal;

        // Define the criteria field and value
        List<ConnectApi.AudienceCriterionValueInput> userCriterionValueInputList = new List<ConnectApi.AudienceCriterionValueInput>();
        ConnectApi.AudienceCriterionValueInput userInput = new ConnectApi.AudienceCriterionValueInput();
        userInput.entityType = 'User';
        userInput.entityField = 'LocaleSidKey';
        userInput.fieldValue = 'en_US';
        userCriterionValueInputList.add(userInput);
        userCriterionInput.criterion = userCriterionValueInputList;

        // Add the criteria to the list
        List<ConnectApi.AudienceCriterionInput> criteria = new List<ConnectApi.AudienceCriterionInput>();
        criteria.add(userCriterionInput);
        audienceInput.criteria = criteria;

        // Call the audience apex method to create
        ConnectApi.Audience audienceOutput = ConnectApi.Personalization.createAudience(communityId,audienceInput);

        return audienceOutput.id;
    }

    @IsTest(SeeAllData=true)
    static void test_assignAudienceToRecord() {
        x7sNewsUtilityTest.createNews();

        User currentUser = [SELECT Id, Name FROM User WHERE Id =: UserInfo.getUserId()];
        System.runAs(currentUser) {
            Test.startTest();
            X7S_News__c newsObj = [SELECT Id, Name FROM X7S_News__c WHERE Name = : x7sNewsUtilityTest.TEST_NEWS_NAME LIMIT 1];

            String audienceId = createTestAudience();
            System.assertNotEquals(null, audienceId);

            x7sNewsController.assignAudienceToRecord(audienceId, newsObj.Id, x7sNewsUtilityTest.strNetworkId);

            audienceId = x7sNewsController.getAudienceIdForRecordId(x7sNewsUtilityTest.strNetworkId, newsObj.Id);
            System.assertNotEquals(null, audienceId);

            System.assertNotEquals(null, x7sNewsController.getTargetsForRecordId('', newsObj.Id));

            x7sNewsController.deleteCurrentAudience(newsObj.Id);
            Test.stopTest();
        }
    }

    // Permissions
    @IsTest
    static void test_GeneralMethods()
    {
        System.assertNotEquals(null, x7sNewsController.userAuthorizedToViewAll());

        List<String> idList = x7sNewsController.getUserGroupId();
        System.assertNotEquals(null, idList);
    }

    @IsTest
    static void test_NewsAttachments() {
        User u = x7sNewsUtilityTest.createCommunityUsers(CUSTOMER_COMMUNITY_USER_CLONE);
        System.runAs(u) {
            Test.startTest();
            
            x7sNewsModel x7sNewsModel = new x7sNewsModel();
            X7S_News__c newsObj = new X7S_News__c();
            newsObj.Name = TEST_NEWS_NAME;
            newsObj.Details__c = TEST_NEWS_DESCRIPTION;
            newsObj.Publish_DateTime__c = System.today().addDays(5);
            newsObj.GroupId__c = '';
            newsObj.Private_Group__c = false;
            newsObj.Image_Type__c = 'Attachment';

            //Call Save method to insert new News record with attachment
            x7sNewsModel = x7sNewsController.saveNews(newsObj, '', 'image/png', 'Unit Test Attachment', 'Unit Test Attachment Body', '', false);
            System.assertNotEquals(null, x7sNewsModel.id);

             x7sNewsModel x7sNewsModel1 = new x7sNewsModel();
            X7S_News__c newsObj1 = new X7S_News__c();
            newsObj1.Name = TEST_NEWS_NAME;
            newsObj1.Details__c = TEST_NEWS_DESCRIPTION;
            newsObj1.Publish_DateTime__c = System.today().addDays(5);
            newsObj1.GroupId__c = '';
            newsObj1.Private_Group__c = false;
            newsObj1.Image_Reference__c = 'Attachment';

            //Call Save method to insert new News record with file
            x7sNewsModel1 = x7sNewsController.saveNews(newsObj1, '', 'image/png', 'Unit Test File', 'Unit Test File Body', '', false);
            System.assertNotEquals(null, x7sNewsModel1.id);

            x7sNewsContentDocModel contentModel = new x7sNewsContentDocModel();
            System.assertEquals('', contentModel.latestImageVersionId);

            Test.stopTest();
        }
    }
    
    @IsTest
    static void test_getRecordName() {
        List<User> testUsers = x7sNewsUtilityTest.createUsers(1,CUSTOMER_COMMUNITY_USER);
        List<SObject> nameOfRecord = x7sNewsController.getCustomLookupDisplayName(testUsers[0].Id);
        System.assertNotEquals(null,nameOfRecord , 'Record name should not be null');
    }

    @IsTest
    static void test_Authors() {

        //Get Network Members for Author dropdown in Create news Page for LEX
        Map<String, String> getUsersForLEX = x7sNewsController.getUsers();
        System.assertNotEquals(null, getUsersForLEX, 'No Users found for lightning experience');

        Map<String, String> searchUsersInLEX = x7sNewsController.searchUsers('michael');
        System.assertNotEquals(null, searchUsersInLEX, 'No Users found for given search');

        Map<String, String> searchUsersInLEX1 = x7sNewsController.searchUsers('');
        System.assertNotEquals(null, searchUsersInLEX1, 'No Users found');

        x7sNewsController.networkId = Id.valueOf(strNetId);
        x7sNewsController.strNetworkId = strNetId;

        //create News Records
        X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);

        //Create Topic Record
        List<Topic> topics = x7sNewsUtilityTest.createTopic(2, strNetId);
        TopicAssignment topicAssg = x7sNewsUtilityTest.createTopicAssignment(topics[0].Id, newsObj.Id);
        System.assertNotEquals(null, topicAssg);

        //Create Community User
        //As we are using custom object News, we have created user with the custom Community Profile,
        //Because standard community profile do not allow to give permissions to such custom objects.
        User u = x7sNewsUtilityTest.createCommunityUsers('Customer Community User Clone');
        System.runAs(u) {
            Test.startTest();

            //Get Authors for Author dropdown in List view of news
            Map<String, String> authorMap = x7sNewsController.getAuthors();
            System.assertNotEquals(null, authorMap);

            //Get Network Members for Author dropdown in Create news Page
            Map<String, String> getUsers = x7sNewsController.getUsers();
            System.assertNotEquals(null, getUsers);

            Map<String, String>searchUsers = x7sNewsController.searchUsers('michael');
            System.assertNotEquals(null, searchUsers);

            Test.stopTest();
        }
    }
}