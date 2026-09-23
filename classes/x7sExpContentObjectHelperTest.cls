/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpContentObjectHelperTest {

    @IsTest
    public static void testFormatFromString() {
        // Create a x7sExp Content Object from helper
        x7sExpContentObjectHelper contentObjectHelper = new x7sExpContentObjectHelper();
        x7sExpContentObject testObject = contentObjectHelper.formatFromString(x7sExpTestConstants.TEST_GROUPNAME);

        // Assert its name property was set
        System.assertEquals(testObject.title, x7sExpTestConstants.TEST_GROUPNAME);
    }
}