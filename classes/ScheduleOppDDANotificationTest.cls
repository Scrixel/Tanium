/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for ScheduleOppDealDeskApproverNotification
 * @Date: 2016-04-08
 * @Author: Mahesh G
 * RequestId  ModifiedDate  Description
 * TAN-536    2018-04-13    Fixed issue due to the Country_Restriction validation rule on the Opportunity
 * SS-13176   2026-05-27    Removed Level_4__c references
 * SS-13636   2026-09-11    Covered pre-commit Renewal and Order Drafted stage exclusion
 */
@IsTest
private class ScheduleOppDDANotificationTest {
	private static final List<String> EXCLUDED_STAGES = new List<String>{
		Utility.ACCOUNT_ASSESSMENT,
		Utility.CUSTOMER_ENGAGED,
		Utility.PROPOSAL_SENT,
		Utility.COMMIT_STAGE,
		'Committed Renewal',
		Utility.ORDER_DRAFTED
	};

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);
		User adminUser = getAdminUser();
		System.runAs(adminUser) {
			Account excludedStagesAccount = TestFactory.buildAccount('Excluded Stages Account');
			excludedStagesAccount.Country_Restrictions__c = 'Business Allowed';
			excludedStagesAccount.Type = 'Analyst';
			insert excludedStagesAccount;

			List<Opportunity> opps = new List<Opportunity>();
			for (String excludedStage : EXCLUDED_STAGES) {
				Opportunity opp = TestFactory.buildOpportunity(
					excludedStage,
					System.today(),
					excludedStage,
					excludedStagesAccount.Id
				);
				opps.add(opp);
			}
			insert opps;

			for (Opportunity opp : opps) {
				opp.CloseDate = System.today();
				opp.Deal_Desk_Approver__c = adminUser.Id;
				opp.Commit__c = 1;
			}
			update opps;
		}
	}

	private static User buildUser(String lastName, String alias, String email, Id profileId) {
		User newUser = new User(ProfileId = profileId);
		newUser.LastName = lastName;
		newUser.Alias = alias;
		newUser.Email = email;
		newUser.Username = email;
		newUser.Emailencodingkey = 'UTF-8';
		newUser.Languagelocalekey = 'en_US';
		newUser.Localesidkey = 'en_US';
		newUser.Timezonesidkey = 'America/Los_Angeles';

		return newUser;
	}

	@IsTest
	static void testFunctionality() {
		Profile profile = [SELECT Id FROM profile WHERE Name = 'Tanium System Administrator'];
		UserRole userRole = [SELECT Id, Name FROM UserRole WHERE PortalType = 'None' LIMIT 1];
		System.runAs(getAdminUser()) {
			list<Sales_Heirarchy__c> listSalesHeiarchy = new List<Sales_Heirarchy__c>();
			for (Integer i = 0; i < 10; i++) {
				listSalesHeiarchy.add(new Sales_Heirarchy__c(Role__c = userRole.Name));
			}
			insert listSalesHeiarchy;
		}
		User user1 = buildUser('User1', 'user1', 'test.user1@org.com', profile.Id);
		insert user1;
		TestingUtility.assignPermissionSet(user1.Id, 'DisableValidationRules');
		User level4User = buildUser('l4User', 'l4user', 'test.level4user@org.com', profile.Id);
		level4User.UserRoleId = userRole.Id;
		level4User.Deals_Desk_Approver__c = user1.Id;
		insert level4User;
		TestingUtility.assignPermissionSet(level4User.Id, 'DisableValidationRules');

		System.runAs(user1) {
			Account testAccount = TestFactory.buildAccount('Test Account');
			testAccount.Country_Restrictions__c = 'Business Allowed';
			testAccount.Type = 'Analyst';
			insert testAccount;

			Opportunity opp1 = TestFactory.buildOpportunity(
				'Opportunity 1',
				System.today(),
				'Pending',
				testAccount.Id
			);
			opp1.seats__c = 1;
			insert opp1;

			Date scheduleDate = Date.today().addDays(1);
			Integer day = scheduleDate.day();
			Integer month = scheduleDate.month();
			Integer year = scheduleDate.year();
			String cronExp = '0 0 0 ' + day + ' ' + month + ' ? ' + year;

			Test.startTest();
			System.schedule(
				'DDA Notifications',
				cronExp,
				new ScheduleOppDealDeskApproverNotification()
			);
			Test.stopTest();
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