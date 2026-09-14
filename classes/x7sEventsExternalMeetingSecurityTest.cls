/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sEventsExternalMeetingSecurityTest {

    @IsTest
    static void testGenerateToken() {
        x7sEventsExternalMeetingSecurity meetingSecurity = new x7sEventsExternalMeetingSecurity();
        String testToken = meetingSecurity.generateToken('');

        System.assertNotEquals('', testToken);

    }
}