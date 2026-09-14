/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OpportunityTriggerHandler
 * @Date: 2015-03-16
 * @Author: Cumulus Vision
 * RequestId  ModifiedDate  Description
 * TAN-390    2017-03-01    Added assertion for TAM fields
 * TAN-398    2017-03-09    updated deal desk approver methods to support new methodology
 * TAN-431    2017-07-21    Removed code coverage for contract portion of trigger, no longer necessary
 * TAN-439    2017-09-07    added opportunity team trigger management.
 * TAN-483    2018-02-22    Updated StageName
 * TAN-536    2018-04-19    solved issue in defaultRelatedAccountOwnerToOppOwner method that was failing
 * TAN-574    2018-05-11    Removed code coverage for code for old code
 * TAN-719    2019-01-07    Test class optimization and issue fix
 * TAN-798    2019-08-12    Fixed test class failure due to FIELD_CUSTOM_VALIDATION_EXCEPTION of Lead.Country field, also Used TestFactory methods to optimize the code
 * TAN-898    2020-07-16    Removed test method related to setting "Deal Desk Approver" field
 * SS-1688    2023-04-20    Rewrote test class moving several test methods to class OpportunityTriggerUtilityTest
 * SS-8994    2024-10-02    Updated test class
 * SS-11167   2025-06-19    Removed instantiation of TestFactory class
 * SS-12459   2026-01-22    Removed Lead Source fields then added back after field type change
 * SS-12400   2026-01-22    Removed Primary_Contact__c field from test class
 */
@IsTest
private class OpportunityTriggerHandlerTest {
	private static User adminUser;
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'BillingScheduleTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();

		System.runAs(getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			acc.Active_Account__c = true;
			insert acc;

			Contact con = new Contact(
				LastName = 'Test Con',
				AccountId = acc.Id,
				Original_Lead_Source__c = 'Marketing',
				Email = 'TestEmail@TestTanium.com'
			);
			insert con;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp1',
				System.today().addDays(30),
				'Discovery',
				acc.Id
			);
			opp.BillingScheduleTotalNetAmountPaidNew__c = opp.Amount;
			insert opp;

			insert new OpportunityContactRole(OpportunityId = opp.Id, ContactId = con.Id);

			SBQQ__Quote__c testQuote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				null,
				null,
				null,
				null
			);
			testQuote.SBQQ__Primary__c = true;
			testQuote.Unlock_Quote__c = false;
			insert testQuote;

			Billing_Schedule__c billing = TestFactory.buildBillingSchedule(opp.Id);
			billing.Billing_Amount__c = opp.Amount;
			billing.Invoice_Date__c = System.today().addDays(30);
			insert billing;
		}
	}

	@IsTest
	static void testOpportunityTriggerHandler() {
		Opportunity[] opps = [SELECT Id FROM Opportunity];

		System.runAs(getAdminUser()) {
			Test.startTest();
			update opps;
			delete opps;
			undelete opps;
			Test.stopTest();
		}

		Assert.isFalse(opps.isEmpty());
	}

	static User getAdminUser() {
		if (adminUser == null) {
			List<User> testUsers = [
				SELECT Id, DisableTaniumCustomTriggers__c
				FROM User
				WHERE LastName LIKE 'TaniumAdminUser%'
			];
			if (testUsers.isEmpty()) {
				adminUser = TestFactory.getTaniumAdminUser(false);
				adminUser.DisableTaniumCustomTriggers__c =
					'BillingScheduleTriggerHandler;' +
					'InvoiceTriggerHandler;' +
					'LeadTriggerHandler;' +
					'OrderTriggerHandler;' +
					'POCRequestTriggerHandler;' +
					'QuoteCPQTriggerHandler;' +
					'UserTriggerHandler';
				insert adminUser;
				adminUser = [
					SELECT Id, DisableTaniumCustomTriggers__c
					FROM User
					WHERE LastName LIKE 'TaniumAdminUser%'
					LIMIT 1
				];
				// No flows exist for Billing schedule related objects but those on acct and oppty block test class execution
				TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');
				TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
				TestingUtility.assignPermissionSet(adminUser.Id, 'BillingScheduleConfigurator');
			} else {
				adminUser = testUsers[0];
			}
		}
		return adminUser;
	}
}