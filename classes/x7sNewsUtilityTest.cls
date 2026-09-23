/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

/*
@description         : Apex Utility class used for creating test records
*/
@IsTest
public class x7sNewsUtilityTest
{
    public static final String COMPANY_COMMUNITY_PROFILE_NAME = 'System Administrator';
    public static final String TEST_NEWS_NAME = 'Test News';
    public static final String TEST_NEWS_TXLATE = 'Test News Translate';
    private static final String LANGUAGE_KEY = 'en_US';

    @TestVisible private static User userObj = createUser();

    public static String strNetworkId
    {
        get
        {
            return [SELECT Id FROM Network LIMIT 1][0].Id;
        }
    }

    //create X7S_News__c record
    public static X7S_News__c createNews()
    {
        X7S_News__c newsObj = new X7S_News__c(
            Name = TEST_NEWS_NAME,
            Publish_DateTime__c = System.today().addDays(-5),
            Author__c = userObj.Id,
            NetworkId__c = strNetworkId);

        System.assertNotEquals(null, newsObj);
        insert newsObj;

        //create    X7S_News_Translation__c record
        X7S_News_Translation__c newsTranslationObj = new X7S_News_Translation__c(
            Name = TEST_NEWS_TXLATE,
            Detail__c = 'Detail Test',
            Parent_X7S_News__c = newsObj.Id,
            Language__c = LANGUAGE_KEY,
            Title__c = 'Test Title');
        
        System.assertNotEquals(null, newsTranslationObj);
        insert newsTranslationObj;
        

        return newsObj;
    }   

    //create X7S_News__c record with the NetworkID
    public static X7S_News__c createNews(String strNetId)
    {
        X7S_News__c newsObj = new X7S_News__c(Name = TEST_NEWS_NAME, Publish_DateTime__c = System.today().addDays(-5),
            Author__c = userObj.Id, NetworkId__c = strNetId);

        System.assertNotEquals(null, newsObj);
        insert newsObj;

        //create    X7S_News_Translation__c record
        X7S_News_Translation__c newsTranslationObj = new X7S_News_Translation__c(
            Name = TEST_NEWS_TXLATE,
            Detail__c = 'Detail Test',
            Parent_X7S_News__c = newsObj.Id,
            Language__c = LANGUAGE_KEY,
            Title__c = 'Test Title');
        
        System.assertNotEquals(null, newsTranslationObj);
        insert newsTranslationObj;

        return newsObj;
    }

    public static X7S_News__c createNewsWithGroup(String strNetId, String groupId)
    {
        X7S_News__c newsObj = new X7S_News__c(Name = TEST_NEWS_NAME, Publish_DateTime__c = System.today().addDays(-5),
            Author__c = userObj.Id, NetworkId__c = strNetId, GroupId__c = groupId);

        System.assertNotEquals(null, newsObj);
        insert newsObj;

        return newsObj;
    }

    public static X7S_News__c createNewsWithGroupPrivate(String strNetId, String groupId)
    {
        X7S_News__c newsObj = new X7S_News__c(
            Name = TEST_NEWS_NAME,
            Publish_DateTime__c = System.today().addDays(-5),
            Author__c = userObj.Id,
            NetworkId__c = strNetId,
            GroupId__c = groupId,
            Private_Group__c = true);

        System.assertNotEquals(null, newsObj);
        insert newsObj;

        return newsObj;
    }

    //create X7S_News__c record for the Bulk Insertion check
    public static List<X7S_News__c> createBulkNews(Integer howMany, String strNetId)
    {
        List<X7S_News__c> objNewsList = new List<X7S_News__c>();
    

        for (Integer i = 0; i < howMany; i++)
        {
            X7S_News__c newsObj = new X7S_News__c(Name = TEST_NEWS_NAME + i, Publish_DateTime__c = System.today().addDays(-5),
                Author__c = userObj.Id, NetworkId__c = strNetId);
                objNewsList.add(newsObj);
            
            
        }

        System.assertNotEquals(null, objNewsList);
        insert objNewsList; 
        return objNewsList;
    }

    //create Topic record
    public static Topic createTopic()
    {

        return null;
    }

    //Create Topics in Bulk with the Network Id
    public static List<Topic> createTopic(Integer howMany, String strNetId)
    {
        List<Topic> topics = new List<Topic>();

        for (Integer i = 0; i < howMany; i++)
        {
            Topic topicObj = new Topic(Name = 'Test Topic' + i, Description = 'Test Topic', NetworkId = strNetId);
            topics.add(topicObj);
        }

        if (!topics.isEmpty())
        {
            insert topics;
        }
        System.assertNotEquals(null, topics);
        return topics;
    }

    //Assign Topic , create TopicAssignment with TopicId and entittId to which topic is to be assigned
    public static TopicAssignment createTopicAssignment(String strTopicId, String strEntityId)
    {
        TopicAssignment topicAssigmnt = new TopicAssignment(EntityId = strEntityId, TopicId = strTopicId);

        System.assertNotEquals(null, topicAssigmnt);

        insert topicAssigmnt ;
        return topicAssigmnt ;
    }

    //create user record
    public static User createUser()
    {
        Profile p = [SELECT Id FROM Profile WHERE Name = :COMPANY_COMMUNITY_PROFILE_NAME];

        User u = new User(Alias = 'standt', Email = 'standarduser123@testorg.com',
            EmailEncodingKey = 'UTF-8', LastName = 'stand user', LanguageLocaleKey = LANGUAGE_KEY,
            LocaleSidKey = LANGUAGE_KEY, ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles', Username = 'x7sNewsStandardUser@testorg.com');

        System.assertNotEquals(null, u);

        insert u;
        return u;
    }

    //Create User with given Profile name
    public static List<User> createUsers(Integer howMany, String profileName)
    {        
        
        //Account a = new Account(Name = 'TestAccount123') ;
        Account a = TestFactory.buildAccount('TestAccount123');
        insert a;

        List<Contact> listOfContacts = new List<Contact>();
        Map<Integer, Contact> mapCont = new Map<Integer, Contact>();

        for (Integer i = 0; i < howMany; i++)
        {
            Contact c = new Contact(Email='7sTestCon' + i + '@x7stesting.com', LastName = '7sTestCon' + i, AccountId = a.Id);
            listOfContacts.add(c);
            mapCont.put(i, c);
        }
        insert listOfContacts;

        // by default bidders
        Id profileId;
        // to make user unique
        String type = 'com';
        Boolean useContact = true;

        if(DEFAULT_PROFILE_NAME != null)
        {
            Profile p  = [SELECT Id, Name FROM Profile WHERE Name = :DEFAULT_PROFILE_NAME];
            profileId  = p.Id;
            useContact = false;
        }
        else if (profileName == COMPANY_COMMUNITY_PROFILE_NAME) {            
            profileId = COMPANY_COMMUNITY_PROFILE_Id;
            type = 'com';
        } else {

            Profile p = [SELECT Id, Name FROM Profile WHERE Name = :profileName];
            profileId = p.Id;
        }

        List<User> listOfUsers = new List<User>();
        User usr;

        for (Integer key : mapCont.keySet()) {
            usr = new User(Alias = type + key,
                Email = key + 'testtest@test.com',
                CommunityNickname = key + mapCont.get(key).LastName,
                EmailEncodingKey = 'UTF-8',
                LastName = 'Test' + type + key,
                LanguageLocaleKey = LANGUAGE_KEY,
                LocaleSidKey = LANGUAGE_KEY,
                ProfileId = profileId,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = key + type + '@test.com');

            if (useContact)
            {
                usr.ContactId = mapCont.get(key).Id;
            }
            listOfUsers.add(usr);
        }
        insert listOfUsers;
        return listOfUsers;
    }

    public static User createAdminUser()
    {
        UserRole portalRole = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];

        Profile adminProfile =
        [
            SELECT Id
            FROM Profile
            WHERE Name = :COMPANY_COMMUNITY_PROFILE_NAME
            LIMIT 1
        ];

        User admin = new User(LastName = 'test user 1',
            Username = 'test.user.1@example.com',
            Email = 'test.1@example.com',
            Alias = 'testu1',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = LANGUAGE_KEY,
            EmailEncodingKey = 'ISO-8859-1',
            ProfileId = adminProfile.Id,
            UserRoleId = portalRole.Id,
            LanguageLocaleKey = LANGUAGE_KEY);

        System.assertNotEquals(null, admin);

        insert admin;
        return admin;
    }

    // Profiles
    static public Id COMPANY_COMMUNITY_PROFILE_Id
    {
        get
        {
            if (COMPANY_COMMUNITY_PROFILE_Id == null)
            {

                List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :COMPANY_COMMUNITY_PROFILE_NAME];
                COMPANY_COMMUNITY_PROFILE_Id = profiles[0].Id;
            }
            System.assertNotEquals(null, COMPANY_COMMUNITY_PROFILE_Id);
            return COMPANY_COMMUNITY_PROFILE_Id;
        }
        set
        {
            COMPANY_COMMUNITY_PROFILE_Id = value;
            System.assertEquals(value, COMPANY_COMMUNITY_PROFILE_Id);
        }
    }

    static public String THIS_COMMUNITY_NAME
    {
        get {
            if (THIS_COMMUNITY_NAME == null) {
                String commName = '';
                commName = [SELECT Id, Name FROM Network LIMIT 1][0].Name;
                System.assertNotEquals(null, commName);
                THIS_COMMUNITY_NAME = commName;
            }
            return THIS_COMMUNITY_NAME;
        }
        set {
            THIS_COMMUNITY_NAME = value;
        }
    }

    // this is for standard user to know
    static public String NETWORK_ID
    {
        get {
            if (NETWORK_ID == null) {
                NETWORK_ID = [SELECT Id FROM Network WHERE Name = :THIS_COMMUNITY_NAME][0].Id;
            }
            System.assertNotEquals(null, NETWORK_ID);
            return NETWORK_ID;

        }
        set {
            NETWORK_ID = value;
            System.assertEquals(value, NETWORK_ID);
        }
    }

    //by sachin kadian to get profile name from custom metadata
    static public String DEFAULT_PROFILE_NAME {
        get {
            if(DEFAULT_PROFILE_NAME == null) {
                List<X7S_News_Setting__mdt> newsSetting = [SELECT Id,Applied_Test_Profile__c,Enable_Multi_Language__c FROM X7S_News_Setting__mdt  WHERE DeveloperName='Default'];
                if(newsSetting != null && !newsSetting.isEmpty()) {
                    DEFAULT_PROFILE_NAME =  newsSetting[0].Applied_Test_Profile__c;
                }
            }

            return DEFAULT_PROFILE_NAME;
        }
        set {
            DEFAULT_PROFILE_NAME = value;
        }
    }

    // Used to create more than 1 user at a time...
    private static Integer userCount = 0;

    //Create Community User
    //As we are using custom object News, we have created user with the custom Community Profile,
    //Because standard community profile do not allow to give permissions to such custom objects.
    public static User createCommunityUsers(String profileName)
    {
        userCount++;

        if(DEFAULT_PROFILE_NAME != null) {            
            Profile p = [SELECT Id, Name FROM Profile WHERE Name = :DEFAULT_PROFILE_NAME];

            User u = new User(Alias = 'Com',
                    Email = 'testtestCommunity@test.com',
                    EmailEncodingKey = 'UTF-8',
                    LastName = 'Test',
                    LanguageLocaleKey = LANGUAGE_KEY,
                    LocaleSidKey = LANGUAGE_KEY,
                    ProfileId = p.Id,
                    TimeZoneSidKey = 'America/Los_Angeles',
                    Username = 'testCommunityNews'+userCount+'@test.com');

            insert u;
            return u;
        }else{
            //Account a = new Account(Name = 'TestAccount123') ;
            Account a = TestFactory.buildAccount('TestAccount123');
            insert a;

            Contact c = new Contact(
                LastName = 'testCon' + userCount,
                AccountId = a.Id,
                Email = 'testCon' + userCount + '@test.com'
            );
            insert c;            

            Profile p = [SELECT Id, Name FROM Profile WHERE Name = :profileName];

            User u = new User(Alias = 'Com',
                    Email = 'testtest1Community@test.com',
                    CommunityNickname = 'NickName'+userCount+'@test.com',
                    EmailEncodingKey = 'UTF-8',
                    LastName = 'Test',
                    LanguageLocaleKey = LANGUAGE_KEY,
                    LocaleSidKey = LANGUAGE_KEY,
                    ProfileId = p.Id,
                    ContactId = c.Id,
                    TimeZoneSidKey = 'America/Los_Angeles',
                    Username = 'testCommunityNews'+userCount+'@test.com');

            insert u;

            return u;
        }
    }

    public static Id createTestGroup(Id ownerId, String groupName, List<User> users)
    {
        CollaborationGroup g = new CollaborationGroup(Name = groupName, CollaborationType = 'Public');
        g.OwnerId = ownerId;

        insert g;

        List<CollaborationGroupMember> groupMembers = new List<CollaborationGroupMember>();

        for (User user : users)
        {
            CollaborationGroupMember member = new CollaborationGroupMember();
            member.MemberId = user.Id ;
            member.CollaborationGroupId = g.Id ;
            groupMembers.add(member);
        }

        System.assertNotEquals(null, groupMembers);

        insert groupMembers;
        return g.Id ;
    }

    public static Id createTestGroup(String groupName)
    {
        CollaborationGroup myGroup = new CollaborationGroup();
        myGroup.Name               = groupName;
        myGroup.NetworkId          = strNetworkId;
        myGroup.CollaborationType  = 'Public'; //can be 'Public' or 'Private'

        System.debug('strNetworkId:' + strNetworkId);

        System.assertNotEquals(null, myGroup);

        insert myGroup;
        return myGroup.Id;
    }

    public static void addTestGroupMember(String groupId, String userId)
    {
        CollaborationGroupMember groupMember = new CollaborationGroupMember();

        groupMember.CollaborationGroupId = groupId;
        groupMember.MemberId = userId;

        System.assertNotEquals(null, groupMember);

        insert groupMember;
    }
}