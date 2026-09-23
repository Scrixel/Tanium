/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpResponseTest {

    @IsTest
    public static void testExpReponse() {
        x7sExpResponse response = new x7sExpResponse();

        // Test success flag
        System.assertEquals(response.success, true);

        // Test messages
        response.messages.add(x7sExpTestConstants.TEST_MESSAGE);
        System.assertEquals(response.messages[0], x7sExpTestConstants.TEST_MESSAGE);

        // Test object list
        Account account = x7sExpTestUtils.createTestAccount();
        response.results.add(account);
        System.assertEquals(account, response.results[0]);
    }
}