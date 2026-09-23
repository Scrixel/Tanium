/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Factory utility for creating test Users with various profiles, roles, and permission sets
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13159   2026-05-07    Fixed UNABLE_TO_LOCK_ROW in getAdminUser() by deferring UserRoleId assignment to a separate update
 * SS-13349   2026-06-17    Added getStandardUser method
 */
@IsTest
public class TestUserFactory {
	private static Map<String, User> createdUserMap = new Map<String, User>();
	public static final String TANIUM_STANDARD_USER = 'TaniumStandardUser';
	public static final String SALES_OPS_USER = 'SalesOpsUser';
	public static final String AUTOMATION_ADMIN_USER = 'AutomationAdminUser';
	public static final String TANIUM_ADMIN_USER = 'TaniumAdminUser';
	public static final String DEAL_DESK_USER = 'DealDeskUser';
	public static final String ADVANCED_APPROVALS_USER = 'AdvancedApprovalsUser';
	public static final String CONGA_CUSTOM_PERMISSIONSET = 'Apttus_READ_WRITE_Permission';
	public static final String CONGA_PACKAGE_NAMESPACE = 'Apttus';

	public static User createUser(
		String lastName,
		String email,
		String alias,
		Id profileId,
		Id userRoleId
	) {
		return new User(
			UserName = email,
			Email = email,
			LastName = lastName,
			ProfileId = profileId,
			UserRoleId = userRoleId,
			Alias = alias,
			UserPermissionsKnowledgeUser = true,
			IsActive = true,
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'America/Los_Angeles'
		);
	}

	public static User createBasicUser(String userType, Id profileId) {
		User basicUser = createdUserMap.get(userType);

		if (basicUser == null) {
			basicUser = TestUserFactory.createUser(
				userType,
				userType + '@TestTanium.com',
				userType.left(8),
				profileId,
				Utility.getCorporateRoleId()
			);

			createdUserMap.put(userType, basicUser);
		}

		return basicUser;
	}

	public static User createTaniumStandardUser() {
		return createTaniumStandardUser(false);
	}

	public static User createTaniumStandardUser(Boolean doInsert) {
		User taniumStandardUser = TestUserFactory.createBasicUser(
			TANIUM_STANDARD_USER,
			Utility.getTaniumStandardUserProfileId()
		);

		if (doInsert) {
			insert taniumStandardUser;
		}

		return taniumStandardUser;
	}

	public static User createSalesOpsUser() {
		return TestUserFactory.createBasicUser(SALES_OPS_USER, Utility.getSuperUserProfileId());
	}

	public static User createAutomationAdminUser() {
		return createAutomationAdminUser(false);
	}

	public static User createAutomationAdminUser(Boolean doInsert) {
		User automationAdminUser = TestUserFactory.createBasicUser(
			AUTOMATION_ADMIN_USER,
			Utility.getAdminUserProfileId()
		);
		automationAdminUser.DisableTaniumCustomTriggers__c = 'All';
		automationAdminUser.Closed_Won_Enabled__c = true;

		if (doInsert) {
			insert automationAdminUser;
		}

		return automationAdminUser;
	}

	public static User createTaniumAdminUser() {
		return createTaniumAdminUser(false);
	}

	public static User createTaniumAdminUser(Boolean doInsert) {
		User taniumAdminUser = TestUserFactory.createBasicUser(
			TANIUM_ADMIN_USER,
			Utility.getAdminUserProfileId()
		);
		taniumAdminUser.Closed_Won_Enabled__c = true;

		if (doInsert) {
			insert taniumAdminUser;
		}

		return taniumAdminUser;
	}

	public static User createDealDeskUser() {
		User dealDeskUser = TestUserFactory.createBasicUser(
			DEAL_DESK_USER,
			Utility.getTaniumDealsDeskProfileId()
		);
		dealDeskUser.Closed_Won_Enabled__c = true;
		insert dealDeskUser;

		TestingUtility.assignCustomPermission(
			dealDeskUser.Id,
			OpportunityQuoteLineLockUtility.CUSTOM_UNLOCK_PERMISSION
		);
		TestingUtility.assignPermissionSet(
			dealDeskUser.Id,
			TestUserFactory.CONGA_CUSTOM_PERMISSIONSET
		);
		TestingUtility.assignPackageLicense(dealDeskUser.Id, TestUserFactory.CONGA_PACKAGE_NAMESPACE);

		return dealDeskUser;
	}

	public static User createAdvancedApprovalsUser() {
		User advancedApprovalsUser = TestUserFactory.createBasicUser(
			ADVANCED_APPROVALS_USER,
			Utility.getAdminUserProfileId()
		);
		advancedApprovalsUser.Closed_Won_Enabled__c = true;
		insert advancedApprovalsUser;

		TestingUtility.assignPermSetLicense(advancedApprovalsUser.Id, 'SalesforceCPQ_CPQAAPerm');
		TestingUtility.assignPermissionSet(advancedApprovalsUser.Id, 'AdvancedApprovalsAdmin');
		TestingUtility.assignPermissionSet(advancedApprovalsUser.Id, 'AdvancedApprovalsUser');

		return advancedApprovalsUser;
	}

	public static User getAdminUser() {
		List<User> adminUsers;
		User adminUser;

		adminUsers = [SELECT Id FROM User WHERE LastName = :TANIUM_ADMIN_USER];

		if (!adminUsers.isEmpty()) {
			adminUser = adminUsers[0];
		} else {
			adminUser = insertAdminUser();
		}

		return adminUser;
	}

	private static User insertAdminUser() {
		User adminUser;
		User taniumAdminUser = createTaniumAdminUser(false);
		Id targetUserRoleId = taniumAdminUser.UserRoleId;
		taniumAdminUser.UserRoleId = null;
		Database.SaveResult insertResult = Database.insert(taniumAdminUser, false);

		if (insertResult.isSuccess()) {
			if (targetUserRoleId != null) {
				taniumAdminUser.UserRoleId = targetUserRoleId;
				Database.update(taniumAdminUser, false);
			}
			TestingUtility.assignPermissionSet(taniumAdminUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(taniumAdminUser.Id, 'DisableFlows');
			adminUser = taniumAdminUser;
		} else {
			List<User> adminUsers = [SELECT Id FROM User WHERE LastName = :TANIUM_ADMIN_USER];
			if (adminUsers.isEmpty()) {
				throw new DmlException(insertResult.getErrors()[0].getMessage());
			}
			adminUser = adminUsers[0];
		}

		return adminUser;
	}

	public static User getStandardUser() {
		List<User> standardUsers = [
			SELECT Id
			FROM User
			WHERE LastName = :TestUserFactory.TANIUM_STANDARD_USER
		];
		if (standardUsers.isEmpty()) {
			User standardUser = createTaniumStandardUser(true);
			return standardUser;
		}
		return standardUsers[0];
	}
}