/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Test for x7sExpErrorLogger
 */
@IsTest
public with sharing class x7sExpErrorLoggerTest {
    private static Integer ERROR_LOG_QUERY_LIMIT = 1;

    @IsTest
    public static void testLogError() {

        // Set a bad ID
        String fakeIdString = '123';

        // New contact
        Contact newContact = new Contact();

        // Try assigning User Id to a Contact insert, that'll fail!
        try {
            newContact.Id = fakeIdString;
            insert newContact;
        } catch (Exception e) {
            // Log error
            x7sExpErrorLogger.logError(e);
        }

        // Now query X7S_Error_Log__c for that stack trace!
        List<X7S_Error_Log__c> errorLogs = [SELECT Name, Type__c, Message__c, Stack_Trace__c FROM X7S_Error_Log__c LIMIT :ERROR_LOG_QUERY_LIMIT];

        // Assert it's found and properties exist
        System.assertEquals(errorLogs.size(), 1);
        System.assert(errorLogs[0].Type__c != null);
        System.assert(errorLogs[0].Stack_Trace__c != null);
        System.assert(errorLogs[0].Message__c != null);
    }

}