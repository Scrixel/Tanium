/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Test class for QuoteCPQTriggerHandler
 * @Date: 2018-12-04
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request: TAN-717
 * RequestId  ModifiedDate  Description
 * TAN-717    2018-12-04    Initial development
 * TAN-739    2019-01-10    Test method for updateBillingScheduleOnOpportunity()
 * SS-7469    2024-02-19    Test method for testMidMarketQuotes_uponNonPrimaryQuoteInsert_PartnerFieldNOTRequired()
 * SS-7766    2024-05-15    Moved test method testhandleDeletedQuotes_whenException_EventIsLogged to QuoteCPQTriggerUtility, class cleanup
 * SS-11167   2025-06-19    Removed instantiation of TestFactory class, replaced with Global Pricebook record
 * SS-10736   2025-07-05    Use new Verification object and new Account fields
 * SS-11278   2025-07-10    Test Payment Term update
 * SS-12364   2026-01-28    Renamed class from QuoteCPQTriggerHandler_Test to QuoteCPQTriggerHandlerTest
 * SS-12833   2026-03-16    Fix method testNoTrigger
 * SS-13648   2026-08-04    Updated makeData method
 */
@IsTest
private class QuoteCPQTriggerHandlerTest {
	static User taniumAdminUser;
	private static final String TEST_COUNTRY_1 = 'Canada';
	private static final String TEST_COUNTRY_2 = 'United States';
	private static final String testAccountName = 'testAccountName';
	private static final String testLegalEntityName = 'testLegalEntity';
	private static final String testOppName = 'test opportunity';
	private static final String testBillingQuoteTerm = '<ul><li>USD 47.00 invoiced upon the Order Date and due Net 40 days from the invoice date;</li></ul>';

	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		System.runAs(getTaniumAdminUser()) {
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'QuoteLineTriggerHandler',
					'UserTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Global Pricebook description.',
				IsActive = true
			);
			String fieldApiName = 'Ruby__PriceAttributes__c';
			Map<String, Schema.SObjectField> pricebookFields = Schema.SObjectType.Pricebook2.fields.getMap();
			if (pricebookFields.containsKey(fieldApiName)) {
				globalPriceBook.put(fieldApiName, 'Currency;UOM');
			}
			insert globalPriceBook;

			Account enterpriseAccount = TestFactory.buildAccount('EnterpriseAccount');
			enterpriseAccount.Support_Verified__c = true;
			enterpriseAccount.Cloud_Deployment_Verified__c = true;
			enterpriseAccount.On_Prem_Deployment_Verified__c = true;

			Account partnerAccount = TestFactory.buildAccount('Partner Account');
			partnerAccount.Support_Verified__c = true;
			partnerAccount.Cloud_Deployment_Verified__c = true;
			partnerAccount.On_Prem_Deployment_Verified__c = true;
			partnerAccount.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');

			Account testAccount = TestFactory.buildAccount(testAccountName);
			testAccount.Type = 'Analyst';
			testAccount.Country_Restrictions__c = 'Business Allowed';
			testAccount.Total_Addressable_Seats__c = 5000;

			Account endUserAcct = TestFactory.buildAccount('End User Account Test');
			endUserAcct.Type = 'Analyst';
			endUserAcct.Country_Restrictions__c = 'Business Allowed';
			insert new List<Account>{ enterpriseAccount, partnerAccount, testAccount, endUserAcct };

			List<Verification__c> verifications = new List<Verification__c>();
			verifications.addAll(
				TestFactory.buildVerifications(
					partnerAccount.Id,
					new List<String>{ 'Cloud Deployment', 'Support L1/L2', 'On-Prem Deployment' },
					Date.today().addDays(60)
				)
			);
			insert verifications;

			Opportunity testOpportunity = TestFactory.buildOpportunity(
				testOppName,
				Date.today() + 90,
				Utility.DISCOVERY,
				testAccount.Id
			);
			insert testOpportunity;

			Legal_Entity__c testLegalEntity1 = trac_TestUtils.buildLegalEntity(testLegalEntityName);
			Legal_Entity__c testLegalEntity2 = trac_TestUtils.buildLegalEntity(
				testLegalEntityName + 2
			);
			insert new List<Legal_Entity__c>{ testLegalEntity1, testLegalEntity2 };

			Contracting_Entity__c testContractEntity1 = trac_TestUtils.buildContractingEntity(
				TEST_COUNTRY_1,
				testLegalEntity1.Id
			);
			Contracting_Entity__c testContractEntity2 = trac_TestUtils.buildContractingEntity(
				TEST_COUNTRY_2,
				testLegalEntity2.Id
			);
			insert new List<Contracting_Entity__c>{ testContractEntity1, testContractEntity2 };

			SBQQ__Quote__c quotePrimary = new SBQQ__Quote__c(
				Do_not_Show_Dates__c = true,
				SBQQ__Opportunity2__c = testOpportunity.Id,
				SBQQ__Account__c = testAccount.Id,
				SBQQ__Type__c = 'Quote',
				SBQQ__Primary__c = true,
				SBQQ__PaymentTerms__c = 'Net 30',
				BillingQuoteTerms__c = ''
			);
			insert quotePrimary;
		}
	}

	@IsTest
	static void testBillingScheduleProcess_whenQuoteTurnedPrimaryOrNonPrimary_OpportunityLinkUpdatedOnBillingSchedules() {
		SBQQ__Quote__c quotePrimary = [
			SELECT Id, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.AccountId
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];
		System.runAs(getTaniumAdminUser()) {
			Billing_Schedule__c billingSchedOrder1 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 1,
				Quote__c = quotePrimary.Id,
				Opportunity__c = quotePrimary.SBQQ__Opportunity2__c
			);

			Billing_Schedule__c billingSchedOrder2 = new Billing_Schedule__c(
				Billing_Amount__c = 600,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 2,
				Quote__c = quotePrimary.Id,
				Opportunity__c = quotePrimary.SBQQ__Opportunity2__c
			);

			SBQQ__Quote__c quoteNonPrimary = new SBQQ__Quote__c(
				SBQQ__Opportunity2__c = quotePrimary.SBQQ__Opportunity2__c,
				SBQQ__Account__c = quotePrimary.SBQQ__Opportunity2__r.AccountId,
				SBQQ__Type__c = 'Quote',
				SBQQ__Primary__c = false
			);
			insert quoteNonPrimary;

			Billing_Schedule__c billingSchedOrder1NonPrimaryQuote = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 1,
				Quote__c = quoteNonPrimary.Id
			);

			insert new List<Billing_Schedule__c>{
				billingSchedOrder1,
				billingSchedOrder2,
				billingSchedOrder1NonPrimaryQuote
			};

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			quoteNonPrimary.SBQQ__Primary__c = true;
			update quoteNonPrimary;
			Test.stopTest();
		}

		for (Billing_Schedule__c eachBilling : [
			SELECT Id, Opportunity__c, Quote__r.SBQQ__Primary__c, Quote__r.SBQQ__Opportunity2__c
			FROM Billing_Schedule__c
		]) {
			if (eachBilling.Quote__r.SBQQ__Primary__c == true) {
				System.assertEquals(
					eachBilling.Quote__r.SBQQ__Opportunity2__c,
					eachBilling.Opportunity__c,
					'Primary quotes will have opp links on their billing schedules'
				);
			} else {
				System.assertEquals(
					null,
					eachBilling.Opportunity__c,
					'Non-Primary quotes will NOT have opp links on their billing schedules'
				);
			}
		}
	}

	@IsTest
	static void testBillingScheduleProcess_whenQuoteTurnedNonPrimary_OpportunityLinkUpdatedOnBillingSchedules() {
		SBQQ__Quote__c quotePrimary = [
			SELECT Id, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.AccountId
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];

		System.runAs(getTaniumAdminUser()) {
			Billing_Schedule__c billingSchedOrder1 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 1,
				Quote__c = quotePrimary.Id,
				Opportunity__c = quotePrimary.SBQQ__Opportunity2__c
			);

			Billing_Schedule__c billingSchedOrder2 = new Billing_Schedule__c(
				Billing_Amount__c = 600,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 2,
				Quote__c = quotePrimary.Id,
				Opportunity__c = quotePrimary.SBQQ__Opportunity2__c
			);

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			quotePrimary.SBQQ__Primary__c = false;
			update quotePrimary;
			Test.stopTest();
		}

		for (Billing_Schedule__c eachBilling : [
			SELECT Id, Opportunity__c, Quote__r.SBQQ__Primary__c, Quote__r.SBQQ__Opportunity2__c
			FROM Billing_Schedule__c
		]) {
			if (eachBilling.Quote__r.SBQQ__Primary__c == true) {
				System.assertEquals(
					eachBilling.Quote__r.SBQQ__Opportunity2__c,
					eachBilling.Opportunity__c,
					'Primary quotes will have opp links on their billing schedules'
				);
			} else {
				System.assertEquals(
					null,
					eachBilling.Opportunity__c,
					'Non-Primary quotes will NOT have opp links on their billing schedules'
				);
			}
		}
	}

	@IsTest
	static void testBillingScheduleProcess_whenException_CreateLogEntries() {
		Boolean exceptionThrown = false;
		SBQQ__Quote__c quote = [
			SELECT Id, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.AccountId
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];

		System.runAs(getTaniumAdminUser()) {
			Invoice__c invoice = new Invoice__c(Name = 'Test Invoice');
			insert invoice;
			Billing_Schedule__c billingSchedule = new Billing_Schedule__c(
				Quote__c = quote.Id,
				Billing_Amount__c = 100,
				Billing_Amount_Net_Rollup__c = 100,
				Billing_Order__c = 1,
				Invoice__c = invoice.Id
			);
			insert billingSchedule;

			Test.startTest();
			try {
				QuoteCPQTriggerUtility.updateBillingSchedules(
					new Set<Id>{ quote.SBQQ__Opportunity2__c }
				);
			} catch (Exception e) {
				exceptionThrown = true;
			}
			Test.stopTest();
		}

		List<LogEntry__c> logEntries = [SELECT Id FROM LogEntry__c];
		Assert.isFalse(logEntries.isEmpty());
	}

	@IsTest
	static void testQuoteDeletion_whenQuoteDeleted_AttachedBillingSchedulesAreDeleted() {
		SBQQ.TriggerControl.disable();
		List<SBQQ__Quote__c> quotes = [SELECT Id FROM SBQQ__Quote__c];

		System.runAs(getTaniumAdminUser()) {
			Billing_Schedule__c billingSchedOrder1 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 1,
				Quote__c = quotes[0].Id
			);
			Billing_Schedule__c billingSchedOrder2 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 2,
				Quote__c = quotes[0].Id
			);
			insert new List<Billing_Schedule__c>{ billingSchedOrder1, billingSchedOrder2 };

			Test.startTest();
			delete quotes;
			Test.stopTest();
		}

		List<Billing_Schedule__c> billingSchedules = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE Quote__c IN :quotes
		];
		System.assertEquals(0, billingSchedules.size(), 'attached billing schedules are deleted');
	}

	@IsTest
	static void testHandleDefaultPartnerAccreditation_whenExceptionGranted_returnNoDeploymentSupport() {
		Opportunity opp;
		SBQQ__Quote__c deploymentQuote;
		SBQQ__Quote__c supportQuote;
		Account supportPartner = [SELECT Id FROM Account WHERE Name = 'EnterpriseAccount' LIMIT 1];

		System.runAs(getTaniumAdminUser()) {
			opp = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today().addDays(51),
				Utility.PROSPECTING,
				supportPartner.Id
			);
			opp.Type = 'New Customer';
			insert opp;

			deploymentQuote = [
				SELECT Id, Deployment_Exception_Granted__c, L1_L2_Support_Exception_Granted__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			deploymentQuote.Deployment_Exception_Granted__c = false;
			deploymentQuote.L1_L2_Support_Exception_Granted__c = false;

			supportQuote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				supportPartner.Id,
				'Accepted',
				'Quote',
				System.today(),
				System.today().addDays(60),
				null
			);
			supportQuote.Deployment_Exception_Granted__c = false;
			supportQuote.L1_L2_Support_Exception_Granted__c = false;
			upsert new List<SBQQ__Quote__c>{ deploymentQuote, supportQuote };

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			deploymentQuote.Deployment_Exception_Granted__c = true;
			deploymentQuote.Partner_Accreditation__c = 'Deployment';
			supportQuote.L1_L2_Support_Exception_Granted__c = true;
			supportQuote.Partner_Accreditation__c = 'Support';
			update new List<SBQQ__Quote__c>{ deploymentQuote, supportQuote };
			Test.stopTest();
		}

		SBQQ__Quote__c quote_Deployment = [
			SELECT Partner_Accreditation__c
			FROM SBQQ__Quote__c
			WHERE Id = :deploymentQuote.Id
		];
		System.assertEquals(
			null,
			quote_Deployment.Partner_Accreditation__c,
			'Partner_Accreditation__c will be null as Deployment_Exception_Granted'
		);
		SBQQ__Quote__c quote_L1_L2_Support = [
			SELECT Partner_Accreditation__c
			FROM SBQQ__Quote__c
			WHERE Id = :supportQuote.Id
		];
		System.assertEquals(
			null,
			quote_L1_L2_Support.Partner_Accreditation__c,
			'Partner_Accreditation__c will be null as L1_L2_Support_Exception_Granted'
		);
	}

	@IsTest
	static void testHandleDefaultPartnerAccreditation_whenEnterpriseAccountSupportEmptied_returnsNull() {
		List<Account> accounts = [
			SELECT Id
			FROM Account
			WHERE Name IN ('Partner Account', 'EnterpriseAccount')
			ORDER BY Name ASC
		];
		Account enterpriseAcc = accounts[0];
		Account supportPartner = accounts[1];
		SBQQ__Quote__c quote;

		System.runAs(getTaniumAdminUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				System.today().addDays(51),
				Utility.PROSPECTING,
				enterpriseAcc.Id
			);
			opp.Type = 'New Customer';
			insert opp;

			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				enterpriseAcc.Id,
				'Draft',
				'Quote',
				System.today(),
				System.today().addDays(51),
				null
			);
			quote.Deployment_Exception_Granted__c = false;
			quote.L1_L2_Support_Exception_Granted__c = false;
			quote.SBQQ__Partner__c = supportPartner.Id;
			quote.L1_L2_Support_Partner__c = supportPartner.Id;
			quote.Deployment_Partner__c = supportPartner.Id;
			insert quote;

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			quote.L1_L2_Support_Partner__c = null;
			update quote;
			Test.stopTest();
		}

		SBQQ__Quote__c quote_Deployment = [
			SELECT Partner_Accreditation__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];

		Assert.isFalse(
			quote_Deployment.Partner_Accreditation__c.contains('Support'),
			'Partner_Accreditation__c should not contain Support'
		);
	}

	@IsTest
	static void testHandleDefaultPartnerAccreditation_with_NullSupportPartner() {
		SBQQ.TriggerControl.disable();
		List<Account> accounts = [
			SELECT Id
			FROM Account
			WHERE Name IN ('End User Account Test', 'Partner Account')
			ORDER BY Name ASC
		];
		Account endUserAcc = accounts[0];
		Account supportAcc = accounts[1];
		SBQQ__Quote__c quote;

		System.runAs(getTaniumAdminUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today().addDays(51),
				Utility.PROSPECTING,
				endUserAcc.Id
			);
			opp.Type = 'New Customer';
			opp.End_User_Account__c = endUserAcc.Id;
			insert opp;

			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				endUserAcc.Id,
				'Draft',
				'Quote',
				System.today(),
				System.today().addDays(51),
				null
			);
			quote.Deployment_Exception_Granted__c = false;
			quote.L1_L2_Support_Exception_Granted__c = false;
			quote.L1_L2_Support_Partner__c = supportAcc.Id;
			quote.Partner_Accreditation__c = 'Support';
			insert quote;

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			quote.L1_L2_Support_Partner__c = null;
			update quote;
			Test.stopTest();
		}

		SBQQ__Quote__c quote_Deployment = [
			SELECT Partner_Accreditation__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];
		System.assertEquals(
			null,
			quote_Deployment.Partner_Accreditation__c,
			'Partner_Accreditation__c will be null as Deployment_Exception_Granted'
		);
	}

	@IsTest
	static void testHandleDefaultPartnerAccreditation_whenEnterpriseAccountDeploymentEmptied_returnNull() {
		List<Account> accounts = [
			SELECT Id
			FROM Account
			WHERE Name IN ('Partner Account', 'EnterpriseAccount')
			ORDER BY Name ASC
		];
		Account enterpriseAcc = accounts[0];
		Account deploymentPartner = accounts[1];
		SBQQ__Quote__c quote;

		System.runAs(getTaniumAdminUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today().addDays(51),
				Utility.PROSPECTING,
				enterpriseAcc.Id
			);
			opp.Type = 'New Customer';
			insert opp;

			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				enterpriseAcc.Id,
				'Draft',
				'Quote',
				System.today(),
				System.today().addDays(51),
				null
			);
			quote.Deployment_Exception_Granted__c = false;
			quote.L1_L2_Support_Exception_Granted__c = false;
			quote.SBQQ__Partner__c = deploymentPartner.Id;
			quote.L1_L2_Support_Partner__c = deploymentPartner.Id;
			quote.Deployment_Partner__c = deploymentPartner.Id;
			insert quote;

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			quote.Deployment_Partner__c = null;
			update quote;
			Test.stopTest();
		}

		SBQQ__Quote__c quote_Deployment = [
			SELECT Partner_Accreditation__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];

		Assert.isFalse(
			quote_Deployment.Partner_Accreditation__c.contains('Deployment'),
			'Partner_Accreditation__c should not contain Deployment'
		);
	}

	@IsTest
	static void testMidMarketQuotes_uponPrimaryQuoteInsert_PartnerFieldRequired() {
		HiddenFeatures__mdt hiddenFeatureDeploymentAccred = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentAccred'
		);
		hiddenFeatureDeploymentAccred.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureL1L2VR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_L1L2SupportProvVR'
		);
		hiddenFeatureL1L2VR.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureSupportPartnerVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_SupportPartnerVR'
		);
		hiddenFeatureSupportPartnerVR.isActive__c = 'False';
		Boolean exceptionThrown = false;
		SBQQ.TriggerControl.disable();
		PriceBook2 pricebook = [SELECT Id FROM PriceBook2 WHERE Name = 'Global Pricebook' LIMIT 1];
		Account acc = [
			SELECT Id, Total_Addressable_Seats__c
			FROM Account
			WHERE RecordTypeId = :Utility.getRecordTypeIdByAPIName('Account', 'Partner')
			LIMIT 1
		];
		Pricebook2 midMarketPriceBook = [
			SELECT Id
			FROM Pricebook2
			WHERE Name = 'Global Pricebook'
			LIMIT 1
		];
		User adminuser = getTaniumAdminUser();
		TestingUtility.removePermissionSet(adminuser.Id, 'DisableValidationRules');

		System.runAs(adminUser) {
			acc.Total_Addressable_Seats__c = 100;
			update acc;
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today().addDays(51),
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Type = 'New Customer';
			opp.End_User_Account__c = acc.Id;
			opp.Pricebook2Id = midMarketPriceBook.Id;
			opp.Pooled_Instance__c = 'Yes';
			insert opp;

			Test.startTest();
			try {
				SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
					opp.Id,
					acc.Id,
					'Draft',
					'Quote',
					System.today(),
					System.today().addDays(51),
					null
				);
				quote.Deployment_Exception_Granted__c = false;
				quote.L1_L2_Support_Exception_Granted__c = false;
				quote.SBQQ__Pricebook__c = pricebook.Id;
				quote.End_User_Account__c = acc.Id;
				quote.SBQQ__Primary__c = true;
				quote.Bypass_Partner_Requirement__c = false;
				insert quote;
			} catch (Exception ex) {
				exceptionThrown = true;
			}
			Test.stopTest();
			System.assertEquals(true, exceptionThrown, 'Exception is thrown');
		}
	}

	@IsTest
	static void testMidMarketQuotes_uponNonPrimaryQuoteInsert_PartnerFieldNOTRequired() {
		SBQQ.TriggerControl.disable();
		Boolean exceptionThrown = false;
		PriceBook2 pricebook = [SELECT Id FROM PriceBook2 WHERE Name = 'Global Pricebook' LIMIT 1];
		Account acc = [
			SELECT Id, Total_Addressable_Seats__c
			FROM Account
			WHERE RecordTypeId = :Utility.getRecordTypeIdByAPIName('Account', 'Partner')
			LIMIT 1
		];
		User adminUser = getTaniumAdminUser();
		TestingUtility.removePermissionSet(adminUser.Id, 'DisableValidationRules');
		System.runAs(adminUser) {
			acc.Total_Addressable_Seats__c = 100;
			update acc;
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today().addDays(51),
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Type = 'New Customer';
			opp.End_User_Account__c = acc.Id;
			opp.PriceBook2Id = pricebook.Id;
			opp.Pooled_Instance__c = 'Yes';
			insert opp;

			Test.startTest();
			try {
				SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
					opp.Id,
					acc.Id,
					'Draft',
					'Quote',
					System.today(),
					System.today().addDays(51),
					null
				);
				quote.Deployment_Exception_Granted__c = false;
				quote.L1_L2_Support_Exception_Granted__c = false;
				quote.SBQQ__Pricebook__c = pricebook.Id;
				quote.End_User_Account__c = acc.Id;
				quote.SBQQ__Primary__c = false;
				insert quote;
			} catch (Exception ex) {
				exceptionThrown = true;
				System.assert(
					ex.getMessage().contains('Deployment Provider required for Mid Market Quotes')
				);
			}
			Test.stopTest();
		}
		System.assertEquals(false, exceptionThrown, 'No exception was thrown');
	}

	@IsTest
	static void setLockInDates_WhenOppTypeIsRenewal_setTrue() {
		Account acc = [
			SELECT Id
			FROM Account
			WHERE RecordTypeId = :Utility.getRecordTypeIdByAPIName('Account', 'Partner')
			LIMIT 1
		];
		SBQQ__Quote__c quote;

		System.runAs(getTaniumAdminUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today().addDays(51),
				Utility.DISCOVERY,
				acc.Id
			);
			opp.Type = 'Renewal';
			opp.End_User_Account__c = acc.Id;
			insert opp;

			Test.startTest();
			quote = TestFactory.buildSBQQ_Quote(opp.Id, acc.Id, '', '', null, null, '');
			insert quote;
			Test.stopTest();
		}

		SBQQ__Quote__c testQuote = [
			SELECT Id, Name, Do_Not_Show_Dates__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];
		System.assertEquals(true, testQuote.Do_Not_Show_Dates__c);
	}

	@IsTest
	static void setLockInDates_WhenOppTypeIsNotRenewal_setFalse() {
		Account acc = [
			SELECT Id
			FROM Account
			WHERE RecordTypeId = :Utility.getRecordTypeIdByAPIName('Account', 'Partner')
			LIMIT 1
		];
		SBQQ__Quote__c quote;

		System.runAs(getTaniumAdminUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today().addDays(51),
				Utility.DISCOVERY,
				acc.Id
			);
			opp.Type = 'New Customer';
			opp.End_User_Account__c = acc.Id;
			insert opp;

			Test.startTest();
			quote = TestFactory.buildSBQQ_Quote(opp.Id, acc.Id, '', '', null, null, '');
			insert quote;
			Test.stopTest();
		}

		SBQQ__Quote__c testQuote = [
			SELECT Id, Name, Do_Not_Show_Dates__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];
		System.assertEquals(false, testQuote.Do_Not_Show_Dates__c);
	}

	@IsTest
	static void updateBillingQuoteTerms_WhenQuoteIsCreated_useQuoteTermsForZeroDollars() {
		Account acc = [
			SELECT Id
			FROM Account
			WHERE RecordTypeId = :Utility.getRecordTypeIdByAPIName('Account', 'Partner')
			LIMIT 1
		];

		Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = :testOppName];
		SBQQ__Quote__c quote;

		System.runAs(getTaniumAdminUser()) {
			Test.startTest();
			quote = TestFactory.buildSBQQ_Quote(opp.Id, acc.Id, '', '', null, null, '');
			insert quote;
			Test.stopTest();
		}

		SBQQ__Quote__c testQuote = [
			SELECT Id, BillingQuoteTerms__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];
		String expected = BillingScheduleConfiguratorUtility.getQuoteTermsForZeroDollars();
		if (String.isNotBlank(expected)) {
			System.assert(
				testQuote.BillingQuoteTerms__c.containsIgnoreCase(expected),
				'BillingQuoteTerms__c should be same as BillingScheduleConfiguratorUtility.getQuoteTermsForZeroDollars'
			);
		} else {
			System.assert(String.isBlank(expected));
			System.assert(String.isBlank(testQuote.BillingQuoteTerms__c));
		}
	}

	@IsTest
	static void updateBillingQuoteTerms_WhenBillingSchedOrderIsOne_useQuoteTermsForFirstBilling() {
		SBQQ__Quote__c quote = [
			SELECT Id, Do_Not_Show_Dates__c, SBQQ__Opportunity2__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];

		System.runAs(getTaniumAdminUser()) {
			Billing_Schedule__c billingSchedOrder1 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 1,
				Quote__c = quote.Id,
				Opportunity__c = quote.SBQQ__Opportunity2__c
			);
			Billing_Schedule__c billingSchedOrder2 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addDays(5),
				Billing_Order__c = 2,
				Quote__c = quote.Id,
				Opportunity__c = quote.SBQQ__Opportunity2__c
			);
			insert new List<Billing_Schedule__c>{ billingSchedOrder1, billingSchedOrder2 };

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			quote.Do_Not_Show_Dates__c = false;
			update quote;
			Test.stopTest();
		}

		SBQQ__Quote__c testQuote = [SELECT Id, BillingQuoteTerms__c FROM SBQQ__Quote__c LIMIT 1];
		if (!String.isBlank(BillingScheduleConfiguratorUtility.getQuoteTermsForFirstBilling())) {
			String expectedBillingQuoteTerm = BillingScheduleConfiguratorUtility.getQuoteTermsForFirstBilling()
				.split('\\+')
				.get(2);

			System.assert(
				testQuote.BillingQuoteTerms__c.containsIgnoreCase(expectedBillingQuoteTerm),
				'BillingQuoteTerms__c should be same as BillingScheduleConfiguratorUtility.getQuoteTermsForFirstBilling'
			);
		}
	}

	@IsTest
	static void updateBillingQuoteTerms_WhenFalseLockInDates_useQuoteTermsForUnlockedDates() {
		SBQQ__Quote__c quote = [
			SELECT Id, Do_Not_Show_Dates__c, SBQQ__Opportunity2__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];

		System.runAs(getTaniumAdminUser()) {
			Billing_Schedule__c billingSchedOrder1 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today(),
				Billing_Order__c = 1,
				EstimatedInvoiceDateOrder1__c = System.today(),
				Quote__c = quote.Id,
				Opportunity__c = quote.SBQQ__Opportunity2__c
			);
			Billing_Schedule__c billingSchedOrder2 = new Billing_Schedule__c(
				Billing_Amount__c = 500,
				Billing_Date__c = System.today().addMonths(3),
				Billing_Order__c = 2,
				EstimatedInvoiceDateOrder1__c = System.today(),
				Quote__c = quote.Id,
				Opportunity__c = quote.SBQQ__Opportunity2__c
			);
			Billing_Schedule__c billingSchedOrder3 = new Billing_Schedule__c(
				Billing_Amount__c = 700,
				Billing_Date__c = System.today().addMonths(6),
				Billing_Order__c = 3,
				EstimatedInvoiceDateOrder1__c = System.today(),
				Quote__c = quote.Id,
				Opportunity__c = quote.SBQQ__Opportunity2__c
			);
			insert new List<Billing_Schedule__c>{
				billingSchedOrder1,
				billingSchedOrder2,
				billingSchedOrder3
			};

			Triggerhandler.resetRecursionLimits();
			quote.Do_Not_Show_Dates__c = true;
			update quote;

			Triggerhandler.resetRecursionLimits();
			Test.startTest();
			quote.Do_Not_Show_Dates__c = false;
			update quote;
			Test.stopTest();
		}

		quote = [
			SELECT Id, BillingQuoteTerms__c, Do_Not_Show_Dates__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];

		System.assertEquals(true, quote.BillingQuoteTerms__c.contains('3 months'));
		System.assertEquals(true, quote.BillingQuoteTerms__c.contains('6 months'));
	}

	@IsTest
	static void testCloneQuoteProcess() {
		Opportunity opp;
		Account acc;
		SBQQ__Quote__c quote;
		SBQQ__Quote__c clonedQuote = new SBQQ__Quote__c();

		System.runAs(getTaniumAdminUser()) {
			acc = TestFactory.buildAccount('test Account');
			acc.Type = 'Analyst';
			acc.Country_Restrictions__c = 'Business Allowed';
			insert acc;

			opp = TestFactory.buildOpportunity(
				'test Opportunity',
				Date.today() + 60,
				Utility.PROSPECTING,
				acc.Id
			);
			insert opp;
			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				'Quote',
				Date.today(),
				Date.today().addDays(30),
				null
			);
			quote.SBQQ__Primary__c = true;
			insert quote;

			SBQQ__QuoteTerm__c qt = new SBQQ__QuoteTerm__c(
				SBQQ__Quote__c = quote.Id,
				SBQQ__PrintOrder__c = 1,
				SBQQ__Status__c = 'Draft',
				SBQQ__ConditionsMet__c = 'Any'
			);
			insert qt;

			SBQQ__QuoteTerm__c subqt = new SBQQ__QuoteTerm__c(
				SBQQ__Quote__c = quote.Id,
				SBQQ__PrintOrder__c = 1,
				SBQQ__Status__c = 'Draft',
				SBQQ__ConditionsMet__c = 'Any',
				SBQQ__ParentTerm__c = qt.Id
			);
			insert subqt;

			SBQQ__TermCondition__c tc = new SBQQ__TermCondition__c(
				SBQQ__QuoteTerm__c = qt.Id,
				SBQQ__Operator__c = 'equals',
				SBQQ__TestedField__c = 'Additional_Terms__c'
			);
			insert tc;

			clonedQuote = quote.clone(false, false, false, false);

			TriggerHandler.resetRecursionLimits();

			Test.startTest();
			insert clonedQuote;
			Test.stopTest();
		}

		Integer quoteTermCount = [
			SELECT COUNT()
			FROM SBQQ__QuoteTerm__c
			WHERE SBQQ__ParentTerm__c = NULL
		];

		System.assertEquals(2, quoteTermCount, 'there should be 2 quote term records');
	}

	@IsTest
	static void testAssignDefaultApprovers_DraftQuote() {
		Opportunity opp;
		Account acc;
		SBQQ__Quote__c quote;
		User user1;
		User level4User;

		System.runAs(getTaniumAdminUser()) {
			user1 = TestUserFactory.createUser(
				'aliasSA',
				'emailSA@test.com',
				'SA1',
				Utility.getSuperUserProfileId(),
				null
			);
			insert user1;

			level4User = TestUserFactory.createUser(
				'l4',
				'test.level4user@test.com',
				'l4',
				Utility.getAdminUserProfileId(),
				null
			);
			level4user.Area_VP__c = user1.Id;
			level4user.ManagerId = user1.Id;
			insert level4User;
			TestingUtility.assignPermissionSet(level4User.Id, 'DisableValidationRules');
		}

		System.runAs(level4User) {
			acc = TestFactory.buildAccount('test Account');
			acc.Type = 'Analyst';
			acc.Country_Restrictions__c = 'Business Allowed';
			insert acc;

			opp = TestFactory.buildOpportunity(
				'test Opportunity',
				Date.today() + 90,
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Deal_Desk_Approver__c = user1.Id;
			insert opp;

			Test.startTest();
			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				'Quote',
				Date.today(),
				Date.today().addDays(30),
				null
			);
			quote.SBQQ__Primary__c = true;
			insert quote;
			Test.stopTest();
		}

		opp = [
			SELECT Id, AreaVP__c, Opportunity_Manager__c, Deal_Desk_Approver__c
			FROM Opportunity
			WHERE Id = :opp.Id
		];

		quote = [
			SELECT Id, AreaVP__c, Opp_OwnerManager__c, Deal_Desk_Approver__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];
		System.assertEquals(
			opp.AreaVP__c,
			quote.AreaVP__c,
			'Confirm that the AreaVP field on the quote was populated with the right user Id.'
		);
		System.assertEquals(
			opp.Opportunity_Manager__c,
			quote.Opp_OwnerManager__c,
			'Confirm that the Opp_OwnerManager field on the quote was populated with the right user Id.'
		);
	}

	@IsTest
	static void testAssignDefaultApprovers_NoDraftQuote() {
		Opportunity opp;
		Account acc;
		SBQQ__Quote__c quote;
		User level4User;

		System.runAs(getTaniumAdminUser()) {
			level4User = TestUserFactory.createUser(
				'l4',
				'test.level4user@test.com',
				'l4',
				Utility.getAdminUserProfileId(),
				null
			);
			insert level4User;
			TestingUtility.assignPermissionSet(level4User.Id, 'DisableValidationRules');
		}

		System.runAs(level4User) {
			Test.startTest();
			acc = TestFactory.buildAccount('test Account');
			acc.Type = 'Analyst';
			acc.Country_Restrictions__c = 'Business Allowed';
			insert acc;
			opp = TestFactory.buildOpportunity(
				'test Opportunity',
				Date.today() + 60,
				Utility.PROSPECTING,
				acc.Id
			);
			insert opp;
			opp = [
				SELECT Id, Deal_Desk_Approver__c, OwnerId, Owner.Name
				FROM Opportunity
				WHERE Id = :opp.Id
			];
			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				'Quote',
				Date.today(),
				Date.today().addDays(30),
				null
			);
			quote.SBQQ__Primary__c = true;
			insert quote;
			quote = [
				SELECT Id, AreaVP__c, Opp_OwnerManager__c, Deal_Desk_Approver__c
				FROM SBQQ__Quote__c
				WHERE Id = :quote.Id
			];
			Test.stopTest();
		}

		System.assertEquals(
			null,
			quote.AreaVP__c,
			'Confirm that the AreaVP field on the quote was NOT populated.'
		);
		System.assertEquals(
			null,
			quote.Opp_OwnerManager__c,
			'Confirm that the Opp_OwnerManager field on the quote was NOT populated.'
		);
	}

	@IsTest
	static void testNoTrigger() {
		TriggerHandler.bypass('QuoteCPQTriggerHandler');

		Account testAccount = [SELECT Id FROM Account WHERE Name = :testAccountName LIMIT 1];
		Opportunity testOpportunity = [SELECT Id FROM Opportunity WHERE Name = :testOppName LIMIT 1];

		Test.startTest();
		SBQQ__Quote__c testQuote;
		System.runAs(getTaniumAdminUser()) {
			testQuote = TestFactory.buildSBQQ_Quote(
				testOpportunity.Id,
				testAccount.Id,
				'Draft',
				'Quote',
				Date.today(),
				Date.today().addDays(30),
				null
			);
			testQuote.SBQQ__BillingCountry__c = TEST_COUNTRY_1;
			testQuote.Legal_Entity__c = null;
			testQuote.Legal_Entity_Override__c = false;
			testQuote.SBQQ__Primary__c = true;
			insert testQuote;
		}
		Test.stopTest();

		System.assertEquals(null, testQuote.Legal_Entity__c, 'Our trigger logic should not have run');
	}

	@IsTest
	static void setBillingRelatedFieldsOnQuote_whenQuoteIsCreated_BillingRelatedFieldsArePopulated() {
		Account acc = [
			SELECT Id
			FROM Account
			WHERE RecordTypeId = :Utility.getRecordTypeIdByAPIName('Account', 'Partner')
			LIMIT 1
		];
		SBQQ__Quote__c quote;

		System.runAs(getTaniumAdminUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today().addDays(51),
				Utility.DISCOVERY,
				acc.Id
			);

			opp.Type = 'New Customer';
			opp.End_User_Account__c = acc.Id;
			insert opp;

			Test.startTest();
			quote = TestFactory.buildSBQQ_Quote(opp.Id, acc.Id, '', '', null, null, '');
			insert quote;

			Test.stopTest();
		}

		SBQQ__Quote__c testQuote = [
			SELECT Id, Name, Billing_Schedule_Total_Amount__c
			FROM SBQQ__Quote__c
			WHERE Id = :quote.Id
		];
		System.assertEquals(
			0,
			testQuote.Billing_Schedule_Total_Amount__c,
			'Billing Schedule Total Amount is 0 upon quote creation.'
		);
	}

	@IsTest
	static void setPaymentTermOnBillingQuoteTerms_WhenPaymentTermOverride_UpdateBillingQuoteTerm() {
		System.runAs(getTaniumAdminUser()) {
			SBQQ__Quote__c quote = [
				SELECT Id, Name, SBQQ__PaymentTerms__c, BillingQuoteTerms__c, SBQQ__Opportunity2__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];

			TriggerHandler.bypass('BillingScheduleTriggerHandler');
			Billing_Schedule__c billingSchedule = new Billing_Schedule__c();
			billingSchedule.Billing_Order__c = 1;
			billingSchedule.isReverseBilling__c = false;
			billingSchedule.PaymentType__c = 'Annual Installment';
			billingSchedule.Billing_Date__c = Date.today().addDays(90);
			billingSchedule.Billing_Amount__c = 1500;
			billingSchedule.Opportunity__c = quote.SBQQ__Opportunity2__c;
			billingSchedule.Quote__c = quote.Id;
			billingSchedule.EstimatedInvoiceDateOrder1__c = Date.today().addDays(90);
			insert billingSchedule;

			Test.startTest();
			quote.SBQQ__PaymentTerms__c = 'Net 15';
			quote.Payment_Term_Override__c = true;
			update quote;
			Test.stopTest();

			SBQQ__Quote__c quoteAfter = [
				SELECT Id, Name, SBQQ__PaymentTerms__c, BillingQuoteTerms__c
				FROM SBQQ__Quote__c
				WHERE Id = :quote.Id
			];

			Assert.isTrue(
				quoteAfter.BillingQuoteTerms__c.contains('Net 15'),
				'BillingQuoteTerms should have Net 15 payment term.'
			);
			Assert.isFalse(
				quoteAfter.BillingQuoteTerms__c.equals(testBillingQuoteTerm),
				'BillingQuoteTerm should not be the same with the test value'
			);
		}
	}

	@IsTest
	static void testApexValidations_WhenPermissionNotAssigned_ReturnError() {
		SBQQ__Quote__c testQuote = [
			SELECT Id, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.AccountId
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];

		Id priceBookId = [SELECT Id FROM Pricebook2 WHERE Name = 'Global Pricebook' LIMIT 1].Id;

		System.runAs(TestUserFactory.createDealDeskUser()) {
			Boolean exceptionThrown = false;
			String errorMsg = '';
			Test.startTest();
			try {
				testQuote.SBQQ__PricebookId__c = priceBookId;
				update testQuote;
			} catch (Exception e) {
				exceptionThrown = true;
				errorMsg = e.getMessage();
			}
			Test.stopTest();

			Assert.isTrue(exceptionThrown);
			Assert.isTrue(
				errorMsg.contains(System.Label.Partner_Required),
				'Error Message should contain the value in custom label'
			);
		}
	}

	@IsTest
	static void testApexValidations_WhenPermissionIsAssigned_ByPassValidations() {
		SBQQ__Quote__c testQuote = [
			SELECT Id, SBQQ__Opportunity2__c, SBQQ__Opportunity2__r.AccountId
			FROM SBQQ__Quote__c
			WHERE SBQQ__Primary__c = TRUE
			LIMIT 1
		];
		Id priceBookId = [SELECT Id FROM Pricebook2 WHERE Name = 'Global Pricebook' LIMIT 1].Id;

		User dealDeskUser = TestUserFactory.createDealDeskUser();
		TestingUtility.assignCustomPermission(dealDeskUser.Id, 'DisableValidationRules');
		TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableFlows');

		System.runAs(dealDeskUser) {
			Boolean exceptionThrown = false;
			String errorMsg = '';
			Test.startTest();
			try {
				testQuote.SBQQ__PricebookId__c = priceBookId;
				update testQuote;
			} catch (Exception e) {
				exceptionThrown = true;
				errorMsg = e.getMessage();
			}
			Test.stopTest();

			Assert.isFalse(exceptionThrown);
			Assert.isTrue(String.isBlank(errorMsg));
		}
	}

	static User getTaniumAdminUser() {
		User[] adminUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.TANIUM_ADMIN_USER];
		if (adminUsers.isEmpty()) {
			taniumAdminUser = TestUserFactory.createTaniumAdminUser(false);
			insert taniumAdminUser;
			TestingUtility.assignPermissionSet(taniumAdminUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(taniumAdminUser.Id, 'DisableFlows');
			TestingUtility.assignPermissionSet(taniumAdminUser.Id, 'BillingScheduleConfigurator');
			return taniumAdminUser;
		}
		return adminUsers[0];
	}
}