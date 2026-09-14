/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sExpContentObjectTest {

    @TestSetup
    static void testSetup() {
        x7sExpTestUtils.createTestContact();
    }

    @IsTest
    public static void test_x7sContentObject() {

        List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sExpTestConstants.STANDARD_EMAIL];

        User testUser = x7sExpTestUtils.createStandardUserNoContact();
        try {
            testUser.ContactId = testContacts[0].Id;
            insert testUser;
        } catch (Exception e) {
            testUser.ContactId = null;
            insert testUser;
        }

        Test.startTest();

        x7sExpContentObject contentObject = new x7sExpContentObject();
        contentObject.contentID = testUser.Id;
        contentObject.title = x7sExpTestConstants.FIRSTNAME;
        contentObject.description = x7sExpTestConstants.TEST_DESCRIPTION;
        contentObject.fullDescription = x7sExpTestConstants.TEST_DESCRIPTION;
        contentObject.attachments = new List<Attachment>();
        contentObject.url = x7sExpTestConstants.TEST_URL;
        contentObject.featured = false;
        contentObject.bannerImage = '';
        contentObject.avatar = '';
        contentObject.commentCount = 1;
        contentObject.commentUrl = '';
        contentObject.dateTimeField = Datetime.newInstance(2011, 11, 18, 3, 3, 3);
        contentObject.dateField = x7sExpTestConstants.TODAY;

        System.assertEquals(contentObject.title, x7sExpTestConstants.FIRSTNAME);
        Test.stopTest();
    }

}