/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpBaseControllerTest {
    @TestSetup static void testSetup() {
        String now = String.valueOfGmt(Datetime.now().date()).split(' ')[0];
        Account testAccount = new Account(
            Type = 'Customer',
            Name = 'TestAccount' + now,
            NumberOfEmployees = 5000
        );
        insert testAccount;
        
        Contact testContact = new Contact(
            FirstName = 'Test' + now,
            LastName = 'Test' + now,
            Email = 'Test' + now + '@testdomain.com',
            AccountId = testAccount.Id
        );

        insert testContact;

        System.assertNotEquals(null, testContact);
    }

    @IsTest
    public static void testGetSitePrefix() {
        System.assert(x7sExpBaseController.getSitePrefix() != null);
    }

    @IsTest
    public static void testGetSiteUrl() {
        System.assert(x7sExpBaseController.getSiteUrl() != null);
    }

    // Test finding a user
    @IsTest
    public static void testUser() {
        String now = String.valueOfGmt(Datetime.now().date()).split(' ')[0];
        String testName = 'Test' + now;
        String testEmail = testName + '@testdomain.com';
        List<Contact> testContacts = [SELECT Id FROM Contact WHERE Email = :testEmail];

        List<Profile> standardProfileList = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated Case'];
        User testUser;
        if (!standardProfileList.isEmpty()) {
            Profile standardProfile = standardProfileList[0];
            testUser = new User(
                Alias = testName.substring(0, 8),
                Email = testEmail,
                FirstName = testName,
                LastName = testName,
                ProfileId = standardProfile.Id,
                Username = testEmail,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
        }

        try {
            testUser.ContactId = testContacts[0].Id;
            insert testUser;
        } catch (Exception e) {
            testUser.ContactId = null;
            insert testUser;
        }

        Test.startTest();

        System.runAs(testUser) {
            System.assertEquals(false, x7sExpBaseController.isGuestUser());
        }

        Test.stopTest();

    }

    // Test running as a guest
    @IsTest
    public static void testGuest() {
        String now = String.valueOfGmt(Datetime.now().date()).split(' ')[0];
        // Set up and run as guest user 
        String testName = 'Test' + now;
        String testEmail = testName + '@testdomain.com';
        List<Profile> standardProfileList;
        User guestUser;

        try {
            standardProfileList = [SELECT Id FROM Profile WHERE Name = 'Tanium Customer Community Profile'];
        } catch (DmlException e) {
            System.debug(e);
        }

        if (!standardProfileList.isEmpty()) {
            Profile standardProfile = standardProfileList[0];
            guestUser = new User(
                Alias = testName.substring(0, 8),
                Email = testEmail,
                FirstName = testName,
                LastName = testName,
                ProfileId = standardProfile.Id,
                Username = testEmail,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
        }

        System.runAs(guestUser) {
            System.assertEquals(true, x7sExpBaseController.isGuestUser());
        }
    }

}