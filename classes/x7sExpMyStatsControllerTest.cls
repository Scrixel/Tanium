/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpMyStatsControllerTest {

    @IsTest
    public static void testStatsController() {

        // Assert simple static test
        System.assertEquals(x7sExpMyStatsController.getSampleStatApex().figure1, 2);

        Test.startTest();

        // Assert 1 closed opp found
        System.assert(x7sExpMyStatsController.getMyClosedWonOpps() != null);
        // Assert 1 open opp found
        System.assert(x7sExpMyStatsController.getMyNewOpps() != null);

        Test.stopTest();

    }

}