/**
 * @Business: Test class for QuoteCPQTriggerHandler
 * @Date: 2021-12-17
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-10736   2025-07-05    Use new Verification object and new Account fields
 */
@IsTest
private class QuoteCPQTriggerHandler_MidMarket_Test {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityContractsProcess',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Global Pricebook description.',
				IsActive = true
			);
			insert globalPriceBook;

			List<Account> accounts = new List<Account>();
			accounts.add(TestFactory.buildAccount('GenericPartnerAccount'));
			accounts[0].RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			accounts[0]
				.Partner_Accreditations__c = 'Fully Verified - Support L1/L2;Proxy Approval - Cloud Deployment;';
			accounts[0].Support_Verified__c = true;
			accounts[0].Cloud_Deployment_Verified__c = true;
			accounts[0].On_Prem_Deployment_Verified__c = true;

			accounts.add(TestFactory.buildAccount('MidMarketAccount'));
			accounts[1].Segment__c = 'Enterprise';
			accounts[1].Total_Addressable_Seats__c = 5000;
			accounts[1].RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Prospect');
			insert accounts;

			List<Verification__c> verifications = new List<Verification__c>();
			verifications.addAll(
				TestFactory.buildVerifications(
					accounts[0].Id,
					new List<String>{ 'Cloud Deployment', 'Support L1/L2', 'On-Prem Deployment' },
					Date.today().addDays(30)
				)
			);
			insert verifications;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addDays(51),
				Utility.PROSPECTING,
				accounts[1].Id
			);
			opp.Type = 'New Customer';
			insert opp;

			SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				accounts[1].Id,
				'Accepted',
				'Quote',
				System.today(),
				System.today().addDays(30),
				globalPriceBook.Id
			);
			quote.Deployment_Exception_Granted__c = false;
			quote.L1_L2_Support_Exception_Granted__c = false;
			quote.SBQQ__Partner__c = accounts[0].Id;
			quote.L1_L2_Support_Partner__c = accounts[0].Id;
			quote.Deployment_Partner__c = accounts[0].Id;
			quote.SBQQ__PricebookId__c = globalPriceBook.Id;
			quote.SBQQ__Primary__c = true;
			insert quote;

			SBQQ__Quote__c nonPrimaryQuote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				accounts[1].Id,
				'Accepted',
				'Quote',
				System.today(),
				System.today().addDays(30),
				globalPriceBook.Id
			);
			nonPrimaryQuote.Deployment_Exception_Granted__c = false;
			nonPrimaryQuote.L1_L2_Support_Exception_Granted__c = false;
			nonPrimaryQuote.SBQQ__Partner__c = accounts[0].Id;
			nonPrimaryQuote.L1_L2_Support_Partner__c = accounts[0].Id;
			nonPrimaryQuote.Deployment_Partner__c = accounts[0].Id;
			nonPrimaryQuote.SBQQ__PricebookId__c = globalPriceBook.Id;
			nonPrimaryQuote.SBQQ__Primary__c = false;
			insert nonPrimaryQuote;
		}
	}

	@IsTest
	static void testPartnerValidation_whenSupportPartnerEmptiedOnPrimaryQuote_returnException() {
		TriggerHandler.resetRecursionLimits();
		HiddenFeatures__mdt hiddenFeatureL1L2SupportProvVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_L1L2SupportProvVR'
		);
		hiddenFeatureL1L2SupportProvVR.isActive__c = 'False';
		SBQQ__Quote__c quote = [
			SELECT Id, L1_L2_Support_Partner__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];

		Test.startTest();
		String testException = '';
		User dealDesk = getDealDeskUser();
		try {
			System.runAs(dealDesk) {
				quote.L1_L2_Support_Partner__c = null;
				update quote;
			}
		} catch (Exception ex) {
			testException = ex.getMessage();
		}
		Test.stopTest();

		System.assert(
			testException != '',
			'Mid Market Quote is not validating support partner as expected.'
		);
	}

	@IsTest
	static void testPartnerValidation_whenSupportPartnerEmptiedOnNONPrimaryQuote_returnNoException() {
		TriggerHandler.resetRecursionLimits();
		HiddenFeatures__mdt hiddenFeatureL1L2SupportProvVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_L1L2SupportProvVR'
		);
		hiddenFeatureL1L2SupportProvVR.isActive__c = 'False';
		SBQQ__Quote__c quote = [
			SELECT Id, L1_L2_Support_Partner__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = FALSE
			LIMIT 1
		];

		Test.startTest();
		String testException = '';
		User dealDesk = getDealDeskUser();
		try {
			System.runAs(dealDesk) {
				quote.L1_L2_Support_Partner__c = null;
				update quote;
			}
		} catch (Exception ex) {
			testException = ex.getMessage();
		}
		Test.stopTest();

		System.assert(testException == '', 'No exception thrown.');
	}

	@IsTest
	static void testPartnerValidation_whenDeploymentPartnerEmptiedOnPrimaryQuote_returnException() {
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';
		TriggerHandler.resetRecursionLimits();
		SBQQ__Quote__c quote = [
			SELECT Id, Deployment_Partner__c, L1_L2_Support_Partner__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];

		User dealDesk = getDealDeskUser();
		Test.startTest();
		String testException = '';
		try {
			System.runAs(dealDesk) {
				quote.Deployment_Partner__c = null;
				update quote;
			}
		} catch (Exception ex) {
			testException = ex.getMessage();
		}

		Test.stopTest();
		System.assert(
			testException != '',
			'Mid Market Quote is not validating deployment partner as expected.'
		);
	}

	@IsTest
	static void testPartnerValidation_whenDeploymentPartnerEmptiedOnNONPrimaryQuote_returnsNoException() {
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';
		TriggerHandler.resetRecursionLimits();
		SBQQ__Quote__c quote = [
			SELECT Id, Deployment_Partner__c, L1_L2_Support_Partner__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = FALSE
			LIMIT 1
		];

		User dealDesk = getDealDeskUser();
		Test.startTest();
		String testException = '';
		try {
			System.runAs(dealDesk) {
				quote.Deployment_Partner__c = null;
				update quote;
			}
		} catch (Exception ex) {
			testException = ex.getMessage();
		}

		Test.stopTest();
		System.assert(testException == '', 'No validation error thrown');
	}

	@IsTest
	static void testPartnerValidation_whenStdPartnerEmptiedOnPrimaryQuote_returnException() {
		TriggerHandler.resetRecursionLimits();
		SBQQ__Quote__c quote = [
			SELECT Id, L1_L2_Support_Partner__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];
		User dealDesk = getDealDeskUser();
		Test.startTest();
		String testException = '';
		try {
			System.runAs(dealDesk) {
				quote.SBQQ__Partner__c = null;
				update quote;
			}
		} catch (Exception ex) {
			testException = ex.getMessage();
		}
		Test.stopTest();
		System.assert(
			testException != '',
			'Mid Market Quote is not validating standard partner as expected.'
		);
	}

	@IsTest
	static void testPartnerValidation_whenStdPartnerEmptiedOnNONPrimaryQuote_returnsNoException() {
		TriggerHandler.resetRecursionLimits();
		SBQQ__Quote__c quote = [
			SELECT Id, L1_L2_Support_Partner__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = FALSE
			LIMIT 1
		];
		User dealDesk = getDealDeskUser();
		Test.startTest();
		String testException = '';
		try {
			System.runAs(dealDesk) {
				quote.SBQQ__Partner__c = null;
				update quote;
			}
		} catch (Exception ex) {
			testException = ex.getMessage();
		}
		Test.stopTest();
		System.assert(testException == '', 'No Validation error thrown.');
	}

	static User getDealDeskUser() {
		List<User> testUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.DEAL_DESK_USER];
		if (testUsers.isEmpty()) {
			User dealDeskUser = TestUserFactory.createDealDeskUser();
			TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableFlows');
			return dealDeskUser;
		} else {
			return testUsers[0];
		}
	}

	static User getAdminUser() {
		User[] adminUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.TANIUM_ADMIN_USER];
		if (adminUsers.isEmpty()) {
			User adminUser = TestUserFactory.createTaniumAdminUser(false);
			adminUser.DisableTaniumCustomTriggers__c = 'AccountTriggerHandler;OpportunityTriggerHandler';
			insert adminUser;
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');
			return adminUser;
		}
		return adminUsers[0];
	}
}