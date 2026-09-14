/*
 * Licensed Materials - Property of IBM
 * 6949-82X
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public class x7sGroupsUtility {
	/** 
	 * @description Create collaboration groups
	 * @return List of CollabrationGroup
	 * @param noOfGroups
	 */
	public static List<CollaborationGroup> createGroup(Integer noOfGroups) {
		List<CollaborationGroup> collGroupLst = new List<CollaborationGroup>();

		for (Integer i = 0; i < noOfGroups; i++) {
			CollaborationGroup c_group = new CollaborationGroup();
			c_group.Name = 'Test Group' + i;
			c_group.Description = 'Test Description';
			c_group.CollaborationType = 'Private';
			collGroupLst.add(c_group);
		}

		insert collGroupLst;
		return collGroupLst;
	}

	/** 
	 * @description Create collaboration group from a list of groups
	 * @return List of CollaborationGroup
	 * @param listGrp
	 */
	public static List<CollaborationGroup> createGroupFeature(List<String> listGrp) {
		Set<String> newGp = new Set<String>();
		List<CollaborationGroup> collGroupLst = new List<CollaborationGroup>();
		for (String s : listGrp) {
			newGp.add(s);
		}
		for (Integer i = 0; i < newGp.size(); i++) {
			CollaborationGroup c_group = new CollaborationGroup();
			c_group.Name = 'Feature' + i;
			c_group.Description = 'Feature Description';
			c_group.CollaborationType = 'Private';
			collGroupLst.add(c_group);
		}

		insert collGroupLst;
		return collGroupLst;
	}

	/** 
	 * @description Create user record
	 * @return a User object
	 */
	public static User createUser() {
		Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];

		User u = new User(Alias = 'stuser1',
			Email = 'standarduser123@testorg.com',
			EmailEncodingKey = 'UTF-8',
			LastName = 'standuser',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			ProfileId = p.Id,
			TimeZoneSidKey = 'America/Chicago',
			Username = 'x7s_groups_user1234@testorg.com');
		insert u;
		return u;
	}

	/** 
	 * @description Create admin user record
	 * @return a User object
	 */
	public static User createAdminUser() {
		UserRole portalRole = [SELECT Id FROM UserRole WHERE PortalType = 'None' LIMIT 1];

		Profile adminProfile = [
			SELECT Id
			FROM Profile
			WHERE Name = 'System Administrator'
			LIMIT 1
		];

		User admin = new User(LastName = 'test adminuser 1',
			Username = 'test.adminuser.1@example.com',
			Email = 'testadminuser.1@example.com',
			Alias = 'testu1',
			TimeZoneSidKey = 'GMT',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = adminProfile.Id,
			UserRoleId = portalRole.Id,
			LanguageLocaleKey = 'en_US');

		System.assertNotEquals(null, admin, 'Error creating admin user');

		insert admin;
		return admin;
	}
}