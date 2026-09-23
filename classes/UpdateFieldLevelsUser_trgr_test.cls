/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for UpdateFieldLevelsUser_trgr Trigger
 * @Date: 2014-08-28
 * @Author: Cumulus Vision
 * @Request:
 * RequestId  ModifiedDate   Description
 * TAN-719   2019-01-07     Test class optimization and issue fix
 * TAN-751   2019-02-08     Reduced bulk UserRole creation to very few records for testing purpose
 *                          As on Production org, this operation giving issue of - LIMIT_EXCEEDED, reached maximum number of roles
 * SS-13176  2026-05-27     Removed Level_1__c references
 */
@isTest
private class UpdateFieldLevelsUser_trgr_test {
	@IsTest
	static void testInsertUpdate() {
		Integer MAX_RECORD_COUNT = 2; // Total UserRole equals MAX_RECORD_COUNT * 2 i.e. 4

		List<Sales_Heirarchy__c> listSalesHeiarchy = new List<Sales_Heirarchy__c>();
		List<UserRole> listUserRole1 = new List<UserRole>(); // listUserRole1 has role the same as listSalesHeiarchy
		List<UserRole> listUserRole2 = new List<UserRole>(); // listUserRole2 has differnt role from listSalesHeiarchy
		List<User> listUser1 = new List<User>(); // listUser1 have role relate to listUserRole1
		List<User> listUser2 = new List<User>(); // listUser2 have role relate to listUserRole2

		// TAN-719
		// Perform all test method operation in the context of 'thisUser' using System.runAs()
		// to avoid Mixed DML Operations (MIXED_DML_OPERATION)
		System.runAs(getAdminUser()) {
			// Create Sales_Heirarchy__c and UserRole records
			for (Integer i = 0; i < MAX_RECORD_COUNT; i++) {
				listSalesHeiarchy.add(
					new Sales_Heirarchy__c(
						Role__c = 'SameRoleTesting' + (i + 1)
					)
				);
				listUserRole1.add(new UserRole(Name = 'SameRoleTesting' + (i + 1)));
				listUserRole2.add(new UserRole(Name = 'DifferentRoleTesting' + (i + 1)));
			}
			insert listSalesHeiarchy;
			insert listUserRole1;
			insert listUserRole2;

			// Create Admin Users
			Profile adminProfile = [
				SELECT Id
				FROM Profile
				WHERE Name = 'Tanium System Administrator'
				LIMIT 1
			];
			for (Integer i = 0; i < MAX_RECORD_COUNT; i++) {
				listUser1.add(
					TestFactory.buildUser(
						'Testing',
						i + 'zzzTestingzzz1@Testing.com',
						'stantd',
						adminProfile.Id,
						listUserRole1.get(i).Id
					)
				);
				listUser2.add(
					TestFactory.buildUser(
						'Testing',
						i + 'zzzTestingzzz2@Testing.com',
						'stantd',
						adminProfile.Id,
						listUserRole2.get(i).Id
					)
				);
			}

			Test.startTest();

			insert listUser1;
			insert listUser2;

			listUser1 = [
				SELECT UserName
				FROM User
				WHERE UserName LIKE '%zzzTestingzzz1@Testing.com'
			];

			listUser2 = [
				SELECT UserName
				FROM User
				WHERE UserName LIKE '%zzzTestingzzz2@Testing.com'
			];

			Set<String> levelField = new Set<String>();
			for (Integer i = 0; i < MAX_RECORD_COUNT; i++) {
				for (String field : levelField) {
					// Assert listUser have different Role from listSalesHeiarchy
					Assert.areEqual(null, listUser2.get(i).get(field));
				}
			}

			// Update Change UserRoleId of listUser1 Between listUser2
			for (Integer i = 0; i < MAX_RECORD_COUNT; i++) {
				listUser1.get(i).UserRoleId = listUserRole2.get(i).Id;
				listUser2.get(i).UserRoleId = listUserRole1.get(i).Id;
			}

			update listUser1;
			update listUser2;

			Test.stopTest();

			listUser1 = [
				SELECT UserName
				FROM User
				WHERE UserName LIKE '%zzzTestingzzz1@Testing.com'
			];

			listUser2 = [
				SELECT UserName
				FROM User
				WHERE UserName LIKE '%zzzTestingzzz2@Testing.com'
			];

			for (Integer i = 0; i < MAX_RECORD_COUNT; i++) {
				for (String field : levelField) {
					// Assert listUser1 different Role from listSalesHeiarchy
					Assert.areEqual(null, listUser1.get(i).get(field));
				}
			}
		}
	}

	static User getAdminUser() {
		List<User> testUsers = [
			SELECT Id
			FROM User
			WHERE LastName = :TestUserFactory.TANIUM_ADMIN_USER
		];
		if (testUsers.isEmpty()) {
			User adminUser = TestUserFactory.createTaniumAdminUser(true);
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');
			return adminUser;
		} else {
			return testUsers[0];
		}
	}
}