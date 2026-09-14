/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Featured User Controller Test
 */
@IsTest
public with sharing class x7sExpFeaturedUserControllerTest {

    @TestSetup
    static void testSetup() {
        x7sExpTestUtils.createTestContact();
    }

    // Test getting the user
    @IsTest
    public static void testFeaturedUser() {
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

        User queryUser = x7sExpFeaturedUserController.getUserInformation(testUser.Id);
        System.assertEquals(x7sExpTestConstants.FIRSTNAME + ' ' + x7sExpTestConstants.LASTNAME, queryUser.Name);

        List<Id> userIds = new List<Id> {testUser.Id};
        System.assertNotEquals(null, x7sExpFeaturedUserController.getUserListInformation(userIds), 'List expected');
    }

    // Test getting the site prefix
    @IsTest
    public static void testSitePrefix() {
        String prefix = x7sExpFeaturedUserController.getSitePrefix();
        System.assertNotEquals(null, prefix);
    }
}