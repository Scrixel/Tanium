/*
 * Licensed Materials - Property of IBM
 * 6949-82X
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Apex Test class for x7sGroupsController
 */
@IsTest
public class x7sGroupsControllerTest
{
	@IsTest
	static void test_Groups()
	{
		//Create Groups
		List<CollaborationGroup> cgroup = x7sGroupsUtility.createGroup(8);
		List<String> listGrp = new List<String>();
		for (Integer cnt = 0; cnt < 3; ++cnt)
		{
			listGrp.add(cgroup[cnt].Id);
		}

		x7sGroupsUtility.createGroupFeature(listGrp);

		//Fetch Groups with sort by as 'Latest Group Activity'
		x7sGroupsWrapper groupsWrapper = x7sGroupsController.getGroups(listGrp, 10, 'Latest Group Activity', null, null, null);
		System.assertEquals(listGrp.size(), 3, 'Error getting the correct list of groups');
		System.assertEquals(11, groupsWrapper.groupMembership.size(), 'Error getting the correct group membership size');

		//Fetch Groups with sort by as 'Date Created : Oldest'
		x7sGroupsWrapper groupsWrapper1 = x7sGroupsController.getGroups(listGrp, 10, 'Date Created : Oldest', null, null, null);
		System.assertEquals(groupsWrapper1.groupsList.size(), 3, 'Error when sorting groups by Date Created: Oldest');

		//Fetch Groups with Search Term as 'Test' and sort by as 'Date Created : Newest'
		x7sGroupsWrapper groupsWrapper2 = x7sGroupsController.getGroups(listGrp, 10, 'Date Created : Newest', null, 'Test', null);
		System.assertEquals(groupsWrapper2.groupsList.size(), 3, 'Error when sorting groups by Date Created: Newest');

		//Fetch My Groups
		x7sGroupsWrapper groupsWrapper3 = x7sGroupsController.getGroups(listGrp, 10, 'Date Created : Newest', 'My Groups', null, null);
		System.assertEquals(groupsWrapper3.groupsList.size(), 3, 'Error when fetching groups by name');

        //Fetch Groups with sort by as 'Most Number Of Members'
		x7sGroupsWrapper groupsWrapper4 = x7sGroupsController.getGroups(listGrp, 10, 'Most Number Of Members', null, null, null);
		System.assertEquals(groupsWrapper4.groupsList.size(), 3, 'Error when sorting groups by Most Number of Members');
        
        //Fetch Groups with sort by as 'Least Number Of Members'
		x7sGroupsWrapper groupsWrapper5 = x7sGroupsController.getGroups(listGrp, 10, 'Least Number Of Members', null, null, null);
		System.assertEquals(groupsWrapper5.groupsList.size(), 3, 'Error when sorting groups by Least Number Of Members');
            
        //Fetch Groups with sort by as 'Name A to Z'
		x7sGroupsWrapper groupsWrapper6 = x7sGroupsController.getGroups(listGrp, 10, 'Name A to Z', null, null, null);
		System.assertEquals(groupsWrapper6.groupsList.size(), 3, 'Error when sorting groups by Name A to Z');

        //Fetch Groups with sort by as 'Name Z to A'
		x7sGroupsWrapper groupsWrapper7 = x7sGroupsController.getGroups(listGrp, 10, 'Name Z to A', null, null, null);
		System.assertEquals(groupsWrapper7.groupsList.size(), 3, 'Error when sorting groups by Name Z to A');
        
		//Fetch Groups with filter of 'search term' and sort by as 'Date Created : Newest'
		x7sGroupsWrapper groupsWrapperSearch1 = x7sGroupsController.getGroups(listGrp, 10, null, null, 'Test Group1', null, null, false);
		System.assertEquals(1, groupsWrapperSearch1.groupsList.size(), 'Error when filtering groups by Name');

        //Fetch Groups with filter of 'search term' and sort by as 'Date Created : Newest'
		x7sGroupsWrapper groupsWrapperSearch2 = x7sGroupsController.getGroups(listGrp, 10, null, null, null, 'Private', null, false);
		System.assertEquals(3, groupsWrapperSearch2.groupsList.size(), 'Error when filtering groups by Group Type');

		//Fetch Groups to process next for pagination
		x7sGroupsWrapper groupsWrapperNext = x7sGroupsController.nextPage(listGrp, 2, 1, 'Recently Viewed', null, null, null, null, false);
		System.assertEquals(2, groupsWrapperNext.pageNumber, 'Error getting the correct next page number');

		//Fetch Groups to process next for pagination
		x7sGroupsWrapper groupsWrapperNext1 = x7sGroupsController.nextPage(listGrp, 2, 2, 'Recently Viewed', null, null, null, null, false);
		System.assertEquals(1, groupsWrapperNext1.pageNumber, 'Error getting the correct next page number');

		//Fetch Groups to process Previous for pagination
		x7sGroupsWrapper groupsWrapperPrev = x7sGroupsController.previousPage(listGrp, 2, 2, 'Number Of Members', null, null, null, null, false);
		System.assertEquals(1, groupsWrapperPrev.pageNumber, 'Error getting the correct previous page number');

		//Fetch Groups to process next for pagination
		x7sGroupsWrapper groupsWrapperCurrent1 = x7sGroupsController.currentPage(listGrp, 2, 1, 'Recently Viewed', null, null, null, null, false);
		System.assertEquals(1, groupsWrapperCurrent1.pageNumber, 'Error getting the correct current page number');

		//Fetch Groups to process next for pagination
		x7sGroupsWrapper groupsWrapperCurrent2 = x7sGroupsController.currentPage(listGrp, 2, 2, 'Recently Viewed', null, null, null, null, false);
		System.assertEquals(2, groupsWrapperCurrent2.pageNumber, 'Error getting the correct current page number');

		//call method to get site Prefix
		String strSitePathPrefix = x7sGroupsController.getSitePrefix();
		System.assertEquals(strSitePathPrefix, System.Site.getPathPrefix(), 'Error getting the site prefix');

		//call method to check if "display community nick name" is true or false in community
		x7sGroupsController.isNicknameDisplayEnabled();

		//call method to check if object is creatable to show hide "Add new" button on header in list view page
		x7sGroupsController.isObjectCreatable();
		x7sGroupsController.canCreateCheckProfile();
		x7sGroupsController.canCreateCheckPermissionSet();
		x7sGroupsController.canCreateCheckCMT();

		//Fetch Featured Groups
		x7sGroupsWrapper featuredGroupsWrapper = x7sGroupsController.getFeaturedGroups(cgroup[0].Id, cgroup[1].Id, cgroup[2].Id, cgroup[3].Id, cgroup[4].Id, cgroup[5].Id, cgroup[6].Id, cgroup[7].Id);
		System.assertEquals(featuredGroupsWrapper.groupsList.size(), 8, 'Error getting the correct group size');

		//Fetch Featured Groups with one invalid id
		x7sGroupsWrapper featuredGroupsWrapper1 = x7sGroupsController.getFeaturedGroups(cgroup[0].Id, cgroup[1].Id, cgroup[2].Id, cgroup[3].Id, cgroup[4].Id, cgroup[5].Id, cgroup[6].Id, '13212324');
		System.assertEquals(featuredGroupsWrapper1.groupsList.size(), 7, 'Error getting the correct group size');

		x7sGroupsWrapper msgTest = new x7sGroupsWrapper('message 1');
		System.assertEquals('message 1', msgTest.errorMsg, 'Error getting the correct error message');
	}

	@IsTest
	static void testGroupMembership()
	{
		User adminUser = x7sGroupsUtility.createAdminUser();
		System.runAs(adminUser)
		{
			List<CollaborationGroup> testGroups = x7sGroupsUtility.createGroup(8);
			Map<String, String> groupList = x7sGroupsController.getMembershipGroups(adminUser.Id);
			System.assertNotEquals(null, groupList, 'The group list is empty');
			System.assertEquals(8, groupList.size(), 'Error getting the correct group size');

			CollaborationGroup testGroup = testGroups[0];
			User testUser = x7sGroupsUtility.createUser();

			// Join
			String collaborationId = x7sGroupsController.joinGroup(testGroup.Id, testUser.Id);
			System.assertNotEquals(null, collaborationId, 'Error joining group');
			groupList = x7sGroupsController.getMembershipGroups(testUser.Id);
			System.assertEquals(1, groupList.size(), 'Error getting membership groups');

			// Leave
			x7sGroupsController.leaveGroup(testGroup.Id, testUser.Id);
			groupList = x7sGroupsController.getMembershipGroups(testUser.Id);
			System.assertEquals(0, groupList.size(), 'Error when test user leaves group');
		}
	}

	@IsTest
	static void test_getMetaData()
	{
		String data = x7sGroupsController.getMetaDataGroupList('Default');
		System.assertNotEquals(null, data, 'Cannot get group list metadata');
	}

	@IsTest
	static void getFieldType()
	{
		String data = x7sGroupsController.getFieldType('name', 'Contains', 'bar');
		System.assertEquals('String', data, 'Error getting group name');
		String data1 = x7sGroupsController.getFieldType('name', 'Greater Than', 'bar');
		System.assertEquals('Invalid Operator', data1, 'Error when checking for invalid operator on group name');
		String data2 = x7sGroupsController.getFieldType('nameaa', 'Greater Than', 'bar');
		System.assertEquals('Invalid Field', data2, 'Error when checking for invalid field on group name');
		String data3 = x7sGroupsController.getFieldType('membercount', 'Greater Than', 'test');
		System.assertEquals('Bad Value', data3, 'Error when testing for bad values on membercount');
		String data4 = x7sGroupsController.getFieldType('membercount', 'Greater Than', '1');
		System.assertEquals('Integer', data4, 'Error getting membercount');
		String data5 = x7sGroupsController.getFieldType('membercount', 'Contains', '1');
		System.assertEquals('Invalid Operator', data5, 'Error when checking for invalid operation on membercount');
		String data6 = x7sGroupsController.getFieldType('id', 'Contains', '1');
		System.assertEquals('Invalid Operator', data6, 'Error when checking for invalid operation on group id');
		String data7 = x7sGroupsController.getFieldType('id', 'Equals', 'oofGTht');
		System.assertEquals('Bad Value', data7, 'Error when checking for bad value on group id');
		String data9 = x7sGroupsController.getFieldType('isarchived', 'Equals', 'true');
		System.assertEquals('Boolean', data9, 'Error when checking for group\'s archived status');
		String data10 = x7sGroupsController.getFieldType('isarchived', 'Contains', 'true');
		System.assertEquals('Invalid Operator', data10, 'Error when checking for invalid operator on isarchived');
		String data11 = x7sGroupsController.getFieldType('isarchived', 'Equals', 'test');
		System.assertEquals('Bad Value', data11, 'Error when checking for bad values on isarchived');
		String data12 = x7sGroupsController.getFieldType('createddate', 'Equals', 'THIS_WEEK');
		System.assertEquals('DateTime', data12, 'Error getting createdate');
		String data13 = x7sGroupsController.getFieldType('createddate', 'Contains', 'THIS_WEEK');
		System.assertEquals('Invalid Operator', data13, 'Error when testing for invalid operator on createdate');
	}
}