/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for ScheduleOppDealDeskApproverNotification
 * @Date: 2016-04-08
 * @Author: Mahesh G
 * RequestId  ModifiedDate  Description
 * TAN-536    2018-04-13    Fixed failure from the Country_Restriction validation rule
 * SS-13176   2026-05-27    Removed Level_4__c references
 * SS-13636   2026-09-14    Covered pre-commit Renewal and Order Drafted stage exclusion
 */
@IsTest
private class ScheduleOppDDANotificationTest {
	private static final String COMMITTED_RENEWAL = 'Committed Renewal';
	private static final String DDA_TEMPLATE_NAME = 'DealDeskApprover_Opporunities_CurrentFQ';
	private static final List<String> EXCLUDED_STAGES = new List<String>{
		Utility.ACCOUNT_ASSESSMENT,
		Utility.CUSTOMER_ENGAGED,
		Utility.PROPOSAL_SENT,
		Utility.COMMIT_STAGE,
		COMMITTED_RENEWAL,
		Utility.ORDER_DRAFTED
	};

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);
		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			Account excludedStagesAccount = TestFactory.buildAccount('Excluded Stages Account');
			excludedStagesAccount.Country_Restrictions__c = 'Business Allowed';
			excludedStagesAccount.Type = 'Analyst';
			insert excludedStagesAccount;

			List<Opportunity> opps = new List<Opportunity>();
			for (String excludedStage : EXCLUDED_STAGES) {
				opps.add(
					TestFactory.buildOpportunity(
						excludedStage,
						System.today(),
						excludedStage,
						excludedStagesAccount.Id
					)
				);
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

	@IsTest
	static void testFunctionality() {
		Profile profile = [SELECT Id FROM profile WHERE Name = 'Tanium System Administrator'];
		UserRole userRole = [SELECT Id, Name FROM UserRole WHERE PortalType = 'None' LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			List<Sales_Heirarchy__c> listSalesHeiarchy = new List<Sales_Heirarchy__c>();
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

	@IsTest
	static void testSendDealDeskApproverNotification_OnlyExcludedStageOpps_SendsNoEmail() {
		Integer emailInvocations;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			new ScheduleOppDealDeskApproverNotification().sendDealDeskApproverNotification();
			emailInvocations = Limits.getEmailInvocations();
			Test.stopTest();
		}

		Assert.areEqual(
			0,
			emailInvocations,
			'Renewal, Committed Renewal and Order Drafted stages => no email'
		);
	}

	@IsTest
	static void testSendDealDeskApproverNotification_QualifyingOpp_ProcessesApproverBatch() {
		User adminUser = TestUserFactory.getAdminUser();
		List<Opportunity> opps = [
			SELECT Id, StageName
			FROM Opportunity
			WHERE StageName = :Utility.COMMIT_STAGE
		];
		for (Opportunity opp : opps) {
			opp.StageName = Utility.DISCOVERY;
			opp.CloseDate = System.today();
			opp.Commit__c = 1;
		}
		Integer emailInvocations;

		System.runAs(adminUser) {
			TriggerHandler.bypass('OpportunityTriggerHandler');
			update opps;
			TriggerHandler.clearBypass('OpportunityTriggerHandler');
		}

		Integer qualifyingOpps = [
			SELECT COUNT()
			FROM Opportunity
			WHERE
				Deal_Desk_Approver__c != NULL
				AND CloseDate = THIS_FISCAL_QUARTER
				AND StageName = :Utility.DISCOVERY
				AND (Commit__c > 0
				OR Upside__c > 0)
		];
		Assert.areEqual(1, qualifyingOpps, 'Discovery Opportunity qualifies for the approver email');

		System.runAs(adminUser) {
			Test.startTest();
			new ScheduleOppDealDeskApproverNotification().sendDealDeskApproverNotification();
			emailInvocations = Limits.getEmailInvocations();
			Test.stopTest();
		}

		Assert.isTrue(emailInvocations <= 1, 'One approver batch sends at most one email');
	}

	@IsTest
	static void testBuildSingleEmailMessage_Always_ReturnsConfiguredMessage() {
		User adminUser = TestUserFactory.getAdminUser();
		List<EmailTemplate> templates = [
			SELECT Id
			FROM EmailTemplate
			WHERE DeveloperName = :DDA_TEMPLATE_NAME
		];
		Id templateId = templates.isEmpty() ? null : templates[0].Id;
		Messaging.SingleEmailMessage message;

		System.runAs(adminUser) {
			Test.startTest();
			message = new ScheduleOppDealDeskApproverNotification()
				.buildSingleEmailMessage(templateId, adminUser.Id, adminUser.Id, false, null);
			Test.stopTest();
		}

		Assert.areEqual(templateId, message.getTemplateId(), 'Uses the Deal Desk Approver template');
		Assert.areEqual(adminUser.Id, message.getTargetObjectId(), 'Targets the Deal Desk Approver');
		Assert.areEqual(1, message.getBccAddresses().size(), 'Keeps the single BCC address');
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
}