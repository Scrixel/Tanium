/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpFeaturedGroupsControllerTest {

    // Note: For Group Membership, ensure that the type of user matches the type of group. Salesforce prevents
    // Internal Chatter Group (No Network Id) <=> Internal User (Has Standard/Internal Profile)
    // Community Chatter Group (Has Network Id) <=> Community User (Has Community/Partner profile)


    @IsTest
    public static void testGetFeaturedGroups() {

        // Insert a collab group
        CollaborationGroup testGroup = x7sExpTestUtils.createChatterGroup(x7sExpTestConstants.TEST_GROUPNAME, 'Public');
        insert testGroup;


        // Call action and cast result as Collab Group
        x7sExpResponse expResponse = x7sExpFeaturedGroupsController.getFeaturedGroups((String) testGroup.Id);
        CollaborationGroup foundGroup = (CollaborationGroup) expResponse.results[0];

        // Test that the collab group name is accurate
        System.assertEquals(foundGroup.Name, x7sExpTestConstants.TEST_GROUPNAME);
    }


    @IsTest
    public static void testGetPrefix() {
        system.assert(x7sExpFeaturedGroupsController.getSitePrefix() != null);
    }


}