/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Test Utility Navigation Controller
 */
@IsTest
public with sharing class x7sExpUtilityNavigationControllerTest {

    @TestSetup
    static void testSetup() {
        Contact testContact = x7sExpTestUtils.createTestContact();
        System.assertNotEquals(null, testContact);
    }

    // Test finding a user
    @IsTest
    public static void testUser() {
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
            System.assertEquals(false, x7sExpUtilityNavigationController.isGuestUser());
        }

    }

    // Test running as a guest
    @IsTest
    public static void testGuest() {
        // Set up and run as guest user
        User guestUser = x7sExpTestUtils.createGuestUser();

        System.runAs(guestUser) {
            System.assertEquals(true, x7sExpUtilityNavigationController.isGuestUser());
        }
    }
}