/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for LeadTriggerHandler and LeadTriggerUtility
 * @Date: 2015-04-07
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * TAN-1185   2021-05-24    Test class update
 * SS-7569    2024-04-02    Updated test class
 * SS-9056    2024-10-10    Add accountId on Opportunity records
 * SS-11384   2025-10-28    Updated test class
 * SS-12400   2026-01-22    Removed OpportunityRegistrationUtility class and related methods
 * SS-12496   2026-02-25    Renamed class to LeadTriggerUtilityTest
 * SS-13499   2026-07-08    Removed SPIFF test and Vertical__c reference
 */
@IsTest
private class LeadTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'UserTriggerHandler'
			}
		);
		Group group1 = new Group(Name = 'CA Lead Queue #TAN-791-1', Type = 'Queue');
		Group group2 = new Group(Name = 'MNC Queue #TAN-799-1', Type = 'Queue');
		insert new List<Group>{ group1, group2 };

		QueuesObject queue1 = new QueueSObject(QueueId = group1.Id, SobjectType = 'Lead');
		QueuesObject queue2 = new QueueSObject(QueueId = group2.Id, SobjectType = 'Lead');
		insert new List<QueuesObject>{ queue1, queue2 };

		User adminUser = getAdminUser();
		adminUser.ManagerId = UserInfo.getUserId();
		update adminUser;

		System.runAs(adminUser) {
			Campaign campaign = new Campaign(Name = 'Test Campaign');
			campaign.Geo__c = 'EMEA';
			campaign.Region2__c = 'EMEA';
			campaign.Sub_Region__c = 'EMEA';
			campaign.Key_Tanium_Contributor__c = 'Test User';
			campaign.Campaign_Focus__c = 'Awareness';

			Automation_Management__c automationManagement = new Automation_Management__c();
			automationManagement.Default_Opp_Reg_Owner_LATAM__c = TestUserFactory.createDealDeskUser()
				.Id;

			insert new List<SObject>{ campaign, automationManagement };

			Id partnerAccountRecordType = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			Account partnerAccount = TestFactory.buildAccount('Partner Account');
			partnerAccount.RecordTypeId = partnerAccountRecordType;
			Account account = TestFactory.buildAccount('Test Account');
			insert new List<Account>{ account, partnerAccount };

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addDays(30),
				Utility.DISCOVERY,
				partnerAccount.Id
			);
			insert opp;

			Lead lead = TestFactory.buildLead('Some', 'Lead', 'some.lead@somecorp.io', 'SomeCorp');
			lead.Status = 'Marketing Qualified';
			insert lead;
			update lead;
		}
	}

	@IsTest
	static void testLeadConversion_WhenValidLead_ConvertLeadSuccessfully() {
		Account acc = [SELECT Id FROM Account WHERE Name = 'Partner Account'];
		Lead lead = [SELECT Id FROM Lead LIMIT 1];
		Database.LeadConvert leadConvert;

		System.runAs(getAdminUser()) {
			leadConvert = new Database.LeadConvert();
			leadConvert.setAccountId(acc.Id);
			leadConvert.setDoNotCreateOpportunity(false);
			leadConvert.setLeadId(lead.Id);
			leadConvert.setConvertedStatus(getConvertedLeadStatus());

			Test.startTest();
			Database.LeadConvertResult leadConvertResult = Database.convertLead(leadConvert);
			Test.stopTest();

			Assert.isTrue(leadConvertResult.isSuccess());
		}
	}

	@IsTest
	static void testAssignOppManager_WhenLeadConverted_OppManagerPopulated() {
		Lead lead = [SELECT Id FROM Lead LIMIT 1];
		Account account = [SELECT Id FROM Account WHERE Name = 'Test Account'];
		Opportunity opportunity = [SELECT Id, OwnerId FROM Opportunity WHERE Name = 'Test Opp'];
		User oppOwner = [SELECT Id FROM User WHERE Id = :opportunity.OwnerId];

		System.runAs(oppOwner) {
			account.OwnerId = UserInfo.getUserId();
			update account;
			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			LeadTriggerUtility.assignOppManager(new Map<Id, Id>{ lead.Id => opportunity.Id });
			Test.stopTest();
		}

		oppOwner = [SELECT ManagerId FROM User WHERE Id = :oppOwner.Id];
		opportunity = [SELECT Opportunity_Manager__c FROM Opportunity LIMIT 1];
		Assert.areEqual(
			oppOwner.ManagerId,
			opportunity.Opportunity_Manager__c,
			'The opportunity should be updated with Owner\'s Manager'
		);
	}

	@IsTest
	static void testUpdateOwnerBasedOnTerritory_WhenLeadUpdated_OwnerUpdated() {
		List<Lead> leads = [SELECT Id, State, Country FROM Lead];
		Map<Id, Lead> oldMap = new Map<Id, Lead>(leads.deepClone(true, true, true));
		for (Lead lead : leads) {
			lead.Country = 'United States';
		}

		System.runAs(getAdminUser()) {
			Test.startTest();
			LeadTriggerUtility.updateOwnerBasedOnTerritory(leads, oldMap);
			Test.stopTest();
		}

		leads = [SELECT Id, OwnerId FROM Lead];
		Assert.areEqual(getAdminUser().Id, leads[0].OwnerId, 'The owner should be updated');
	}

	@IsTest
	static void testDeleteLead_withDeletePermission_DeleteLeadSuccessfully() {
		User adminUser = getAdminUser();
		TestingUtility.assignCustomPermission(
			adminUser.Id,
			Constants.DELETE_LEADS_AND_CONTACTS_PERMISSION
		);

		Lead lead = [SELECT Id FROM Lead LIMIT 1];
		String expectedError;
		System.runAs(adminUser) {
			Test.startTest();
			try {
				delete lead;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
			Test.stopTest();

			Assert.isTrue(String.isBlank(expectedError), 'Lead was deleted, no exception thrown');
		}
	}

	static String getConvertedLeadStatus() {
		return [
			SELECT MasterLabel
			FROM LeadStatus
			WHERE IsConverted = TRUE
			ORDER BY SortOrder
			LIMIT 1
		]
		.MasterLabel;
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