/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sExpProfileProgressControllerTest {

    @TestSetup
    static void methodName() {
        Contact testContact = x7sExpTestUtils.createTestContact();
        System.assertNotEquals(null, testContact);
    }

    // Test the dynamic query builder
    @IsTest
    public static void testDynamicQueryBuilder() {
        // Set up and run as a standard user
        String[] fields = new List<String>();
        fields.add('FirstName');

        List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sExpTestConstants.STANDARD_EMAIL];

        User testUser = x7sExpTestUtils.createStandardUserNoContact();
        try {
            testUser.ContactId = testContacts[0].Id;
            insert testUser;
        } catch (Exception e) {
            testUser.ContactId = null;
            insert testUser;
        }

        // The following code runs as user 'testUser'
        String builtQuery = x7sExpProfileProgressController.dynamicQueryBuilder('User', testUser.Id, fields);
        System.assertEquals('SELECT Id, FirstName FROM User WHERE Id = \'' + testUser.Id + '\'', builtQuery);
    }
    // Test getting the user
    @IsTest
    public static void testGetUser() {
        // Set up and run as a standard user
        List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sExpTestConstants.STANDARD_EMAIL];

        User testUser = x7sExpTestUtils.createStandardUserNoContact();
        try {
            testUser.ContactId = testContacts[0].Id;
            insert testUser;
        } catch (Exception e) {
            testUser.ContactId = null;
            insert testUser;
        }

        System.runAs(testUser) {
            // The following code runs as user 'testUser'
            User queryUser = x7sExpProfileProgressController.getUser();
            System.assertEquals(x7sExpTestConstants.FIRSTNAME + ' ' + x7sExpTestConstants.LASTNAME, queryUser.Name);
        }
    }
    @IsTest
    public static void testGetUserById() {
        // Set up and run as a standard user
        List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :x7sExpTestConstants.STANDARD_EMAIL];

        User testUser = x7sExpTestUtils.createStandardUser();
        try {
            testUser.ContactId = testContacts[0].Id;
            insert testUser;
        } catch (Exception e) {
            testUser.ContactId = null;
            insert testUser;
        }

        String[] fields = new List<String>();
        fields.add('FirstName');
        fields.add('LastName');
        fields.add('Email');

        Integer progress = x7sExpProfileProgressController.getUserById(testUser.Id, fields);
        System.debug('profile progress: ' + progress);
        System.assertNotEquals(null, progress);
    }
    // Test getting the site prefix
    @IsTest
    public static void testSitePrefix() {
        String prefix = x7sExpProfileProgressController.getSitePrefix();
        System.assertNotEquals(null, prefix);
    }
}