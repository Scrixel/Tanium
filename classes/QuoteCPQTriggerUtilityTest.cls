/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Test class for QuoteCPQTriggerUtility
 * @Author: Cumulus Vision
 * RequestId  ModifiedDate  Description
 * SS-6987    2024-02-20    Updated test class
 * SS-8788    2024-09-13    Removed irrelavant method for deployment provider, added methods for amendment and renewal quotes
 * SS-10736   2025-07-05    Use new Verification object and new Account fields
 * SS-11278   2025-07-10    Update getAdminUser and getDealDeskUser
 * SS-12364   2026-01-23    Added testmethod testIdentifyNewModules_WhenNewModulesOnQuote_PopulateNewlyQuotedModulesFieldOnQuote
 * SS-12404   2026-02-20    Updated makeData method
 * SS-12404   2026-02-27    Updated and renamed testDetermineLegalEntitiesBeforeUpdate to testDetermineLegalEntitiesBeforeUpdate_WhenNotFederalAndNotCloned_UseBillingCountry
 * SS-12833   2026-03-16    Fix method testCloneBillingSchedules_whenPaymentTypeIsCustom_clonesBillingSchedulesSuccessfully
 * SS-12818   2026-03-18    Updated makeData method to include software product check
 * SS-13648   2026-08-04    Updated makeData method, added testmethod testSetAICredits_WhenRenewalAnnualizedSoftwareSpend_SetAICreditsOnQuote
 */
@IsTest
private class QuoteCPQTriggerUtilityTest {
	static User taniumAdminUser;
	static User dealDeskUser;
	static final String CUSTOM_PAYMENT_TYPE = BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE;
	static final String FLAT_SKU_PRODUCT = 'Flat SKU Product';
	static final String BUNDLE_PARENT_PRODUCT = 'Bundle Parent Hardware';
	static final String ON_PREM_DEPLOYMENT = QuoteCPQTriggerUtility.ON_PREM_DEPLOYMENT;
	static final String TAAS_DEPLOYMENT = QuoteCPQTriggerUtility.TAAS_DEPLOYMENT;
	private static final String TEST_COUNTRY_1 = 'Canada';
	private static final String TEST_COUNTRY_2 = 'United States';
	private static final String testAccountName = 'testAccountName';
	private static final String testLegalEntityName = 'testLegalEntity';
	private static final String testOppName = 'Test Opportunity 1';
	private static final String testBillingQuoteTerm = '<ul><li>USD 47.00 invoiced upon the Order Date and due Net 40 days from the invoice date;</li></ul>';

	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler',
				'BillingScheduleTriggerHandler'
			}
		);
		Account account;
		Account partnerAccount1;
		Opportunity oppty;
		System.runAs(TestUserFactory.getAdminUser()) {
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
			account = TestFactory.buildAccount(testAccountName);
			account.Seats_Purchased1__c = 26000;
			account.Total_Addressable_Seats__c = 5000;
			partnerAccount1 = TestFactory.buildAccount('Partner Account 1');
			partnerAccount1.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			partnerAccount1.Support_Verified__c = true;
			partnerAccount1.Cloud_Deployment_Verified__c = true;
			partnerAccount1.On_Prem_Deployment_Verified__c = true;
			partnerAccount1.Total_Addressable_Seats__c = 5000;

			Account partnerAccount2 = TestFactory.buildAccount('Partner Account 2');
			partnerAccount2.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			partnerAccount2.Support_Verified__c = false;
			partnerAccount2.Cloud_Deployment_Verified__c = false;
			partnerAccount2.On_Prem_Deployment_Verified__c = false;
			partnerAccount2.Total_Addressable_Seats__c = 5000;
			insert new List<Account>{ account, partnerAccount1, partnerAccount2 };

			List<Verification__c> verifications = new List<Verification__c>();
			verifications.addAll(
				TestFactory.buildVerifications(
					partnerAccount1.Id,
					new List<String>{ 'Cloud Deployment', 'Support L1/L2', 'On-Prem Deployment' },
					Date.today().addDays(30)
				)
			);
			verifications.addAll(
				TestFactory.buildVerifications(
					partnerAccount2.Id,
					new List<String>{ 'Cloud Deployment', 'Support L1/L2', 'On-Prem Deployment' },
					Date.today().addDays(-30)
				)
			);
			insert verifications;

			oppty = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today() + 30,
				'Prospecting',
				account.Id
			);
			oppty.CloseDate = Date.today() + 60;
			oppty.BillingScheduleTotalAmountNew__c = 10;
			oppty.Type = 'New Customer';
			insert new List<Opportunity>{ oppty };

			SBQQ__Quote__c testQuote1 = new SBQQ__Quote__c(
				Bypass_Partner_Requirement__c = true,
				Deployment_Exception_Granted__c = true,
				Deployment_Method__c = TAAS_DEPLOYMENT,
				Deployment_Partner__c = partnerAccount1.Id,
				L1_L2_Support_Partner__c = partnerAccount1.Id,
				SBQQ__Account__c = account.Id,
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = oppty.Id,
				SBQQ__PaymentTerms__c = 'Net 30',
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Primary__c = true,
				SBQQ__StartDate__c = Date.today(),
				SBQQ__Status__c = 'Accepted',
				SBQQ__SubscriptionTerm__c = 30,
				SBQQ__Type__c = 'Quote'
			);
			insert new List<SBQQ__Quote__c>{ testQuote1 };

			SBQQ__QuoteTerm__c quoteTerm = new SBQQ__QuoteTerm__c(
				SBQQ__Quote__c = testQuote1.Id,
				SBQQ__Status__c = 'Approved',
				SBQQ__PrintOrder__c = 1.00
			);
			insert quoteTerm;

			Product2 flatSKUProduct = new Product2(
				IsActive = true,
				Name = FLAT_SKU_PRODUCT,
				Description = 'test description',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = false,
				SBQQ__SubscriptionPricing__c = 'One-time',
				Family = 'None'
			);

			Product2 bundleParentHardware = new Product2(
				IsActive = true,
				Name = BUNDLE_PARENT_PRODUCT,
				A_la_carte_Required_SKUs__c = true,
				Description = 'bundle parent description',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = true,
				Bundle_Component__c = 'myBundleComponentHardware',
				Bundle_List_Price__c = 2000,
				Family = 'None'
			);

			Product2 myBundleComponentHardware = new Product2(
				IsActive = true,
				Name = 'myBundleComponentHardware',
				Description = 'bundle component description',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = true,
				Bundle_List_Price__c = 2000,
				Family = 'None'
			);

			Product2 softwareProduct = new Product2(
				IsActive = true,
				Name = 'softwareProduct',
				Description = 'software description',
				Product_Group__c = 'Software',
				Prorate_Billing__c = true,
				Bundle_List_Price__c = 2000,
				Family = 'None'
			);

			insert new List<Product2>{
				flatSKUProduct,
				bundleParentHardware,
				myBundleComponentHardware,
				softwareProduct
			};

			SBQQ__QuoteLine__c qLineFlatSKU = new SBQQ__QuoteLine__c(
				SBQQ__Bundle__c = false,
				Bundled_Product__c = false,
				SBQQ__StartDate__c = Date.today() + 100,
				SBQQ__Quantity__c = 1,
				SBQQ__Quote__c = testQuote1.Id,
				SBQQ__Product__c = flatSKUProduct.Id,
				SBQQ__SubscriptionTerm__c = 40,
				SBQQ__NetPrice__c = 1000
			);

			SBQQ__QuoteLine__c qLineParentBundleHardware = new SBQQ__QuoteLine__c(
				SBQQ__Bundle__c = true,
				Bundled_Product__c = false,
				SBQQ__StartDate__c = Date.today() + 100,
				SBQQ__Quantity__c = 1,
				SBQQ__Quote__c = testQuote1.Id,
				SBQQ__Product__c = bundleParentHardware.Id,
				SBQQ__SubscriptionTerm__c = 40,
				SBQQ__NetPrice__c = 2000
			);

			SBQQ__QuoteLine__c qLineBundleComponentHardware = new SBQQ__QuoteLine__c(
				SBQQ__Bundle__c = false,
				Bundled_Product__c = true,
				SBQQ__StartDate__c = Date.today() + 100,
				SBQQ__Quantity__c = 1,
				SBQQ__Quote__c = testQuote1.Id,
				SBQQ__Product__c = myBundleComponentHardware.Id,
				SBQQ__SubscriptionTerm__c = 40,
				SBQQ__NetPrice__c = 2000
			);

			SBQQ__QuoteLine__c qLineSoftwareProduct = new SBQQ__QuoteLine__c(
				SBQQ__Bundle__c = false,
				Bundled_Product__c = false,
				SBQQ__StartDate__c = Date.today() + 100,
				SBQQ__Quantity__c = 1,
				SBQQ__Quote__c = testQuote1.Id,
				SBQQ__Product__c = softwareProduct.Id,
				SBQQ__SubscriptionTerm__c = 40,
				SBQQ__NetPrice__c = 2000
			);

			insert new List<SBQQ__QuoteLine__c>{
				qLineFlatSKU,
				qLineParentBundleHardware,
				qLineBundleComponentHardware,
				qLineSoftwareProduct
			};

			Module__c assetModule = new Module__c(Name = 'Asset', Module_Description__c = 'Asset');
			Module__c coreModule = new Module__c(Name = 'Core', Module_Description__c = 'Core');
			Module__c softwareAssetModule = new Module__c(
				Name = 'Software Asset',
				Module_Description__c = 'Software Asset'
			);
			insert new List<Module__c>{ assetModule, coreModule, softwareAssetModule };

			Product_Module__c assetProductModule = new Product_Module__c(
				Product__c = flatSKUProduct.Id,
				Module__c = assetModule.Id
			);
			Product_Module__c coreProductModule = new Product_Module__c(
				Product__c = bundleParentHardware.Id,
				Module__c = coreModule.Id
			);
			Product_Module__c softwareAssetProductModule = new Product_Module__c(
				Product__c = softwareProduct.Id,
				Module__c = softwareAssetModule.Id
			);
			insert new List<Product_Module__c>{
				assetProductModule,
				coreProductModule,
				softwareAssetProductModule
			};

			Account_Entitlements__c accountEntitlement = new Account_Entitlements__c(
				Account__c = account.Id,
				Module__c = coreModule.Id
			);
			insert accountEntitlement;

			Billing_Schedule__c billingSchedule1 = new Billing_Schedule__c(
				Billing_Order__c = 1,
				isReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingSchedule1.Billing_Date__c = oppty.CloseDate;
			billingSchedule1.Billing_Amount__c = 1500;
			billingSchedule1.Opportunity__c = oppty.Id;
			billingSchedule1.Quote__c = testQuote1.Id;
			billingSchedule1.EstimatedInvoiceDateOrder1__c = Date.today();
			insert billingSchedule1;

			Billing_Schedule__c billingSchedule2 = new Billing_Schedule__c(
				Billing_Order__c = 2,
				isReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingSchedule2.Billing_Date__c = oppty.CloseDate;
			billingSchedule2.Billing_Amount__c = 1500;
			billingSchedule2.Opportunity__c = oppty.Id;
			billingSchedule2.Quote__c = testQuote1.Id;
			billingSchedule2.EstimatedInvoiceDateOrder1__c = Date.today();
			insert billingSchedule2;

			BillingByQuoteLine__c billingFlatSKU1 = new BillingByQuoteLine__c(
				BillAmount__c = 500,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingFlatSKU1.BillingSchedule__c = billingSchedule1.Id;
			billingFlatSKU1.Opportunity__c = oppty.Id;
			billingFlatSKU1.Quote__c = testQuote1.Id;
			billingFlatSKU1.QuoteLine__c = qLineFlatSKU.Id;
			billingFlatSKU1.BillDate__c = oppty.CloseDate;

			BillingByQuoteLine__c billingFlatSKU2 = new BillingByQuoteLine__c(
				BillAmount__c = 500,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingFlatSKU2.BillingSchedule__c = billingSchedule2.Id;
			billingFlatSKU2.Opportunity__c = oppty.Id;
			billingFlatSKU2.Quote__c = testQuote1.Id;
			billingFlatSKU2.QuoteLine__c = qLineFlatSKU.Id;
			billingFlatSKU2.BillDate__c = oppty.CloseDate;

			BillingByQuoteLine__c billingHardwareBundle1 = new BillingByQuoteLine__c(
				BillAmount__c = 1000,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingHardwareBundle1.BillingSchedule__c = billingSchedule1.Id;
			billingHardwareBundle1.Opportunity__c = oppty.Id;
			billingHardwareBundle1.Quote__c = testQuote1.Id;
			billingHardwareBundle1.QuoteLine__c = qLineParentBundleHardware.Id;
			billingHardwareBundle1.BillDate__c = oppty.CloseDate;

			BillingByQuoteLine__c billingHardwareBundle2 = new BillingByQuoteLine__c(
				BillAmount__c = 1000,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingHardwareBundle2.BillingSchedule__c = billingSchedule2.Id;
			billingHardwareBundle2.Opportunity__c = oppty.Id;
			billingHardwareBundle2.Quote__c = testQuote1.Id;
			billingHardwareBundle2.QuoteLine__c = qLineParentBundleHardware.Id;
			billingHardwareBundle2.BillDate__c = oppty.CloseDate;
			insert new List<BillingByQuoteLine__c>{
				billingFlatSKU1,
				billingHardwareBundle1,
				billingFlatSKU2,
				billingHardwareBundle2
			};

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

			List<AI_Credit_Tier__c> aiCreditTiers = new List<AI_Credit_Tier__c>();
			AI_Credit_Tier__c tier1 = new AI_Credit_Tier__c(
				Name = 'Tier 1',
				Lower_Band__c = 0,
				Upper_Band__c = 10000,
				Marginal_Rate_Percent__c = 5,
				Tanium_Cost_Per_Credit__c = 0.05
			);
			aiCreditTiers.add(tier1);

			AI_Credit_Tier__c tier2 = new AI_Credit_Tier__c(
				Name = 'Tier 2',
				Lower_Band__c = 10001,
				Upper_Band__c = 50000,
				Marginal_Rate_Percent__c = 3,
				Tanium_Cost_Per_Credit__c = 0.05
			);
			aiCreditTiers.add(tier2);

			AI_Credit_Tier__c tier3 = new AI_Credit_Tier__c(
				Name = 'Tier 3',
				Lower_Band__c = 50001,
				Upper_Band__c = 10000000,
				Marginal_Rate_Percent__c = 1,
				Tanium_Cost_Per_Credit__c = 0.05
			);
			aiCreditTiers.add(tier3);
			insert aiCreditTiers;
		}

		User salesSystemsUser;
		try {
			salesSystemsUser = [SELECT Id FROM User WHERE Alias = 'ssystems' LIMIT 1];
		} catch (Exception e) {
			salesSystemsUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
		}

		TestingUtility.assignPermissionSet(salesSystemsUser.Id, 'DisableFlows');

		System.runAs(salesSystemsUser) {
			SBQQ__Quote__c renewalQuote = new SBQQ__Quote__c(
				Bypass_Partner_Requirement__c = true,
				Deployment_Exception_Granted__c = true,
				Deployment_Method__c = TAAS_DEPLOYMENT,
				Deployment_Partner__c = partnerAccount1.Id,
				L1_L2_Support_Partner__c = partnerAccount1.Id,
				SBQQ__Account__c = account.Id,
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = oppty.Id,
				SBQQ__PaymentTerms__c = 'Net 30',
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Primary__c = true,
				SBQQ__StartDate__c = Date.today(),
				SBQQ__Status__c = 'Accepted',
				SBQQ__SubscriptionTerm__c = 30,
				SBQQ__Type__c = 'Renewal',
				OwnerId = salesSystemsUser.Id
			);
			insert renewalQuote;
		}
	}

	@IsTest
	static void testdeleteQuote_whenBillingSchedulesAttached_deletesAttachedBillingSchedulesSuccessfully() {
		SBQQ__Quote__c testQuote1 = [
			SELECT Id, (SELECT Id FROM Billing_Schedules__r)
			FROM SBQQ__Quote__c
			WHERE SBQQ__Type__c = 'Quote'
			LIMIT 1
		];
		List<Billing_Schedule__c> billingsBefore = new List<Billing_Schedule__c>();
		for (Billing_Schedule__c eachBilling : testQuote1.Billing_Schedules__r) {
			billingsBefore.add(eachBilling);
		}
		System.assertEquals(true, !billingsBefore.isEmpty());
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			delete testQuote1;
			Test.stopTest();
		}
		List<Billing_Schedule__c> billingsAfter = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE ID IN :billingsBefore
		];
		System.assertEquals(true, billingsAfter.isEmpty());
	}

	@IsTest
	static void testCloneBillingSchedules_whenPaymentTypeIsCustom_clonesBillingSchedulesSuccessfully() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity oppty = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1'];
			SBQQ__Quote__c testQuote1 = [
				SELECT
					Id,
					Do_Not_Show_Dates__c,
					BillingQuoteTerms__c,
					SBQQ__PaymentTerms__c,
					SBQQ__PriceBook__c
				FROM SBQQ__Quote__c
				WHERE SBQQ__Opportunity2__c = :oppty.Id AND SBQQ__Type__c = 'Quote'
			];
			testQuote1.PaymentTypeNew__c = 'Custom';
			update testQuote1;
			List<BillingByQuoteLine__c> originalBillingsByQL = new List<BillingByQuoteLine__c>();
			for (BillingByQuoteLine__c eachBillingByQL : [
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE Quote__c = :testQuote1.Id
			]) {
				eachBillingByQL.PaymentType__c = 'Custom';
				originalBillingsByQL.add(eachBillingByQL);
			}
			update originalBillingsByQL;
			List<Billing_Schedule__c> originalBillings = new List<Billing_Schedule__c>();
			for (Billing_Schedule__c eachBilling : [
				SELECT Id, Billing_Amount__c, Billing_Order__c, Invoice_Date__c, PaymentType__c
				FROM Billing_Schedule__c
				WHERE Quote__c = :testQuote1.Id
				ORDER BY Billing_Order__c ASC
			]) {
				eachBilling.PaymentType__c = 'Custom';
				originalBillings.add(eachBilling);
			}
			update originalBillings;
			SBQQ__Quote__c testClonedQuote;
			Map<Id, Id> customBillingQuotesWithNewlyClonedQuotes = new Map<Id, Id>();
			System.runAs(TestUserFactory.getAdminUser()) {
				Test.startTest();
				testClonedQuote = testQuote1.clone();
				customBillingQuotesWithNewlyClonedQuotes.put(testQuote1.Id, testClonedQuote.Id);
				QuoteCPQTriggerUtility.cloneBillingSchedules(customBillingQuotesWithNewlyClonedQuotes);
				Test.stopTest();
			}
			for (SBQQ__Quote__c eachClonedQuote : [
				SELECT
					Id,
					SBQQ__Source__c,
					(
						SELECT Id, Billing_Amount__c, Billing_Order__c, Invoice_Date__c, PaymentType__c
						FROM Billing_Schedules__r
						ORDER BY Billing_Order__c ASC
					),
					(
						SELECT
							Id,
							BillAmount__c,
							BillDate__c,
							BillingScheduleOrder__c,
							isReverseBilling__c,
							PaymentType__c
						FROM BillingsByQuoteLines__r
					)
				FROM SBQQ__Quote__c
				WHERE Id = :testClonedQuote.Id
			]) {
				System.assertEquals(testQuote1.Id, eachClonedQuote.SBQQ__Source__c);
				System.assertEquals(true, !eachClonedQuote.Billing_Schedules__r.isEmpty());
				System.assertEquals(true, !eachClonedQuote.BillingsByQuoteLines__r.isEmpty());
				for (Billing_Schedule__c eachBilling : eachClonedQuote.Billing_Schedules__r) {
					System.assertEquals(
						originalBillings[0].Billing_Amount__c,
						eachBilling.Billing_Amount__c
					);
					System.assertEquals(
						originalBillings[0].Billing_Order__c,
						eachBilling.Billing_Order__c
					);
					System.assertEquals(
						originalBillings[0].Invoice_Date__c,
						eachBilling.Invoice_Date__c
					);
					System.assertEquals(
						originalBillings[0].isReverseBilling__c,
						eachBilling.isReverseBilling__c
					);
					System.assertEquals(originalBillings[0].PaymentType__c, eachBilling.PaymentType__c);
				}
				for (BillingByQuoteLine__c eachBillingByQL : eachClonedQuote.BillingsByQuoteLines__r) {
					System.assertEquals(
						originalBillingsByQL[0].BillAmount__c,
						eachBillingByQL.BillAmount__c
					);
					System.assertEquals(
						originalBillingsByQL[0].BillDate__c,
						eachBillingByQL.BillDate__c
					);
					System.assertEquals(
						originalBillingsByQL[0].BillingScheduleOrder__c,
						eachBillingByQL.BillingScheduleOrder__c
					);
					System.assertEquals(
						originalBillingsByQL[0].isReverseBilling__c,
						eachBillingByQL.isReverseBilling__c
					);
					System.assertEquals(
						originalBillingsByQL[0].PaymentType__c,
						eachBillingByQL.PaymentType__c
					);
				}
			}
		}
	}

	@IsTest
	static void testDeploymentProviderValidation_whenUpdateDeloymentMethodIsTaaSAndNotCloudAccreditated_firesValidationErrorSuccessfully() {
		HiddenFeatures__mdt hiddenFeatureDeploymentAccred = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentAccred'
		);
		hiddenFeatureDeploymentAccred.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';

		Boolean exceptionThrown = false;
		String exceptionMessage = '';
		SBQQ__Quote__c testQuote;
		Pricebook2 midMarketPriceBook = [
			SELECT Id
			FROM Pricebook2
			WHERE Name = 'Global Pricebook'
			LIMIT 1
		];
		Opportunity oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];

		Account partnerAcct = [
			SELECT Cloud_Deployment_Verified__c
			FROM Account
			WHERE RecordType.Name = 'Partner' AND Cloud_Deployment_Verified__c = TRUE
		];
		Account acct = [
			SELECT Total_Addressable_Seats__c, Seats_Purchased1__c
			FROM Account
			WHERE Id = :oppty.AccountId
		];
		System.assertEquals(true, partnerAcct.Cloud_Deployment_Verified__c);
		System.runAs(TestUserFactory.getAdminUser()) {
			acct.Total_Addressable_Seats__c = 5000;
			acct.Seats_Purchased1__c = 5000;
			update acct;
			oppty.Pricebook2Id = midMarketPriceBook.Id;
			update oppty;
			testQuote = new SBQQ__Quote__c(
				SBQQ__Account__c = oppty.AccountId,
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = oppty.Id,
				SBQQ__Partner__c = partnerAcct.Id,
				SBQQ__PaymentTerms__c = 'Net 30',
				SBQQ__PriceBook__c = midMarketPriceBook.Id,
				SBQQ__Primary__c = true,
				SBQQ__StartDate__c = Date.today(),
				SBQQ__Status__c = 'Accepted',
				SBQQ__SubscriptionTerm__c = 30,
				SBQQ__Type__c = 'Quote'
			);
			testQuote.Bypass_Partner_Requirement__c = false;
			testQuote.Deployment_Exception_Granted__c = false;
			testQuote.Deployment_Method__c = null;
			testQuote.L1_L2_Support_Partner__c = partnerAcct.Id;
			testQuote.Deployment_Partner__c = partnerAcct.Id;
			insert testQuote;
			partnerAcct.Cloud_Deployment_Verified__c = false;
			update partnerAcct;
		}
		partnerAcct = [
			SELECT Cloud_Deployment_Verified__c
			FROM Account
			WHERE RecordType.Name = 'Partner' AND Id = :partnerAcct.Id
		];
		System.assertEquals(false, partnerAcct.Cloud_Deployment_Verified__c);
		User dealDeskuser = getDealDeskUser();
		System.runAs(dealDeskuser) {
			Test.startTest();
			try {
				testQuote.ApprovalStatus__c = null;
				testQuote.Deployment_Method__c = TAAS_DEPLOYMENT;
				testQuote.Bypass_Partner_Requirement__c = false;
				testQuote.Deployment_Exception_Granted__c = false;
				testQuote.Deployment_Partner__c = partnerAcct.Id;
				update testQuote;
				testQuote = [
					SELECT
						Id,
						ApprovalStatus__c,
						Bypass_Partner_Requirement__c,
						Deployment_Exception_Granted__c,
						Deployment_Method__c,
						Deployment_Partner__r.Cloud_Deployment_Verified__c,
						Opportunity_Type__c,
						Sales_Ops_Derived_EP__c,
						SBQQ__PricebookId__c,
						SBQQ__Type__c
					FROM SBQQ__Quote__c
					WHERE Id = :testQuote.Id
					LIMIT 1
				];
				System.assertEquals(
					true,
					QuoteCPQTriggerUtility.isDeploymentProviderRequired(testQuote)
				);
				System.assertNotEquals(null, testQuote.Deployment_Partner__c);
				System.assertEquals(
					false,
					testQuote.Deployment_Partner__r.Cloud_Deployment_Verified__c
				);
				System.assertEquals(TAAS_DEPLOYMENT, testQuote.Deployment_Method__c);
				System.assertEquals(null, testQuote.ApprovalStatus__c);
			} catch (Exception myException) {
				exceptionThrown = true;
				exceptionMessage = myException.getMessage();
			}
			Test.stopTest();
			System.assertEquals(
				true,
				exceptionThrown,
				'TaaS deployment method should have partnerAcct.Cloud_Deployment_Verified__c true but was false when quote was updated'
			);
			System.assertNotEquals(
				'',
				exceptionMessage,
				'Exception message contains the custom label'
			);
			System.assertEquals(
				true,
				exceptionMessage.contains(System.Label.DeploymentProviderApexValidationError),
				'Exception message contains the custom label'
			);
		}
	}

	@isTest
	static void testDeploymentProviderValidation_whenUpdateDeloymentMethodIsOnPremAndNotOnPremAccreditated_firesValidationErrorSuccessfully() {
		HiddenFeatures__mdt hiddenFeatureDeploymentAccred = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentAccred'
		);
		hiddenFeatureDeploymentAccred.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';

		Boolean exceptionThrown = false;
		String exceptionMessage = '';
		SBQQ__Quote__c testQuote1;
		Opportunity oppty;
		Pricebook2 midMarketPriceBook;
		Account partnerAcct;
		System.runAs(TestUserFactory.getAdminUser()) {
			midMarketPriceBook = [SELECT Id FROM Pricebook2 WHERE Name = 'Global Pricebook' LIMIT 1];
			oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
			oppty.Pricebook2Id = midMarketPriceBook.Id;
			update oppty;
			Account acct = [
				SELECT Total_Addressable_Seats__c, Seats_Purchased1__c
				FROM Account
				WHERE Id = :oppty.AccountId
			];
			acct.Total_Addressable_Seats__c = 5000;
			acct.Seats_Purchased1__c = 5000;
			update acct;
			partnerAcct = [
				SELECT Cloud_Deployment_Verified__c, On_Prem_Deployment_Verified__c
				FROM Account
				WHERE RecordType.Name = 'Partner' AND Cloud_Deployment_Verified__c = TRUE
			];
			testQuote1 = new SBQQ__Quote__c(
				SBQQ__Account__c = oppty.AccountId,
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = oppty.Id,
				SBQQ__Partner__c = partnerAcct.Id,
				SBQQ__PaymentTerms__c = 'Net 30',
				SBQQ__PriceBook__c = midMarketPriceBook.Id,
				SBQQ__Primary__c = true,
				SBQQ__StartDate__c = Date.today(),
				SBQQ__Status__c = 'Accepted',
				SBQQ__SubscriptionTerm__c = 30,
				SBQQ__Type__c = 'Quote'
			);
			testQuote1.Bypass_Partner_Requirement__c = false;
			testQuote1.Deployment_Exception_Granted__c = false;
			testQuote1.Deployment_Method__c = null;
			testQuote1.L1_L2_Support_Partner__c = partnerAcct.Id;
			testQuote1.Deployment_Partner__c = partnerAcct.Id;
			insert testQuote1;

			System.assertEquals(true, partnerAcct.On_Prem_Deployment_Verified__c);
			partnerAcct.On_Prem_Deployment_Verified__c = false;
			update partnerAcct;
			partnerAcct = [
				SELECT On_Prem_Deployment_Verified__c
				FROM Account
				WHERE RecordType.Name = 'Partner' AND Id = :partnerAcct.Id
			];
			System.assertEquals(false, partnerAcct.On_Prem_Deployment_Verified__c);
		}
	}

	@IsTest
	static void testDeploymentProviderValidation_whenUpdateDeloymentProviderIsChangedForTaaSAndNotTaaSAccreditated_firesValidationErrorSuccessfully() {
		HiddenFeatures__mdt hiddenFeatureDeploymentAccred = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentAccred'
		);
		hiddenFeatureDeploymentAccred.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';

		Boolean exception1Thrown = false;
		SBQQ__Quote__c testQuote1;
		Opportunity oppty;
		Pricebook2 midMarketPriceBook;
		Account partnerAcct;
		System.runAs(TestUserFactory.getAdminUser()) {
			midMarketPriceBook = [SELECT Id FROM Pricebook2 WHERE Name = 'Global Pricebook' LIMIT 1];
			oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
			oppty.Pricebook2Id = midMarketPriceBook.Id;
			update oppty;
			Account acct = [
				SELECT Total_Addressable_Seats__c, Seats_Purchased1__c
				FROM Account
				WHERE Id = :oppty.AccountId
			];
			acct.Total_Addressable_Seats__c = 5000;
			acct.Seats_Purchased1__c = 5000;
			update acct;
			Account nonAccredPartnerAcct = [
				SELECT Id, Cloud_Deployment_Verified__c, On_Prem_Deployment_Verified__c
				FROM Account
				WHERE RecordType.Name = 'Partner' AND Cloud_Deployment_Verified__c = FALSE
			];
			SBQQ__Quote__c testQuote = [
				SELECT Deployment_Partner__c
				FROM SBQQ__Quote__c
				WHERE
					Deployment_Partner__r.Cloud_Deployment_Verified__c = TRUE
					AND SBQQ__Type__c = 'Quote'
			];
			try {
				testQuote.Deployment_Partner__c = nonAccredPartnerAcct.Id;
				update partnerAcct;
			} catch (Exception e) {
				exception1Thrown = true;
			}
			System.assertEquals(true, exception1Thrown);
		}
	}

	@IsTest
	static void testDeploymentProviderValidation_whenUpdateDeloymentProviderIsChangedForOnPremAndNotOnPremAccreditated_firesValidationErrorSuccessfully() {
		HiddenFeatures__mdt hiddenFeatureDeploymentAccred = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentAccred'
		);
		hiddenFeatureDeploymentAccred.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';

		Boolean exception1Thrown = false;
		SBQQ__Quote__c testQuote1;
		Opportunity oppty;
		Pricebook2 midMarketPriceBook;
		Account partnerAcct;
		TestingUtility.removePermissionSet(
			TestUserFactory.getAdminUser().Id,
			'DisableValidationRules'
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			midMarketPriceBook = [SELECT Id FROM Pricebook2 WHERE Name = 'Global Pricebook' LIMIT 1];
			oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
			oppty.Pricebook2Id = midMarketPriceBook.Id;
			update oppty;
			Account acct = [
				SELECT Total_Addressable_Seats__c, Seats_Purchased1__c
				FROM Account
				WHERE Id = :oppty.AccountId
			];
			acct.Total_Addressable_Seats__c = 5000;
			acct.Seats_Purchased1__c = 5000;
			update acct;
			Account nonAccredPartnerAcct = [
				SELECT Id, Cloud_Deployment_Verified__c, On_Prem_Deployment_Verified__c
				FROM Account
				WHERE RecordType.Name = 'Partner' AND On_Prem_Deployment_Verified__c = FALSE
			];
			SBQQ__Quote__c testQuote = [
				SELECT Deployment_Partner__c
				FROM SBQQ__Quote__c
				WHERE
					Deployment_Partner__r.On_Prem_Deployment_Verified__c = TRUE
					AND SBQQ__Type__c = 'Quote'
			];
			try {
				testQuote.Deployment_Method__c = '';
				testQuote.Deployment_Partner__c = nonAccredPartnerAcct.Id;
				update partnerAcct;
			} catch (Exception e) {
				exception1Thrown = true;
			}
			System.assertEquals(true, exception1Thrown);
		}
	}

	@IsTest
	static void testDeploymentProviderValidation_whenNonPrimaryQuoteInsertDeloymentMethodIsTaaSOrOnPremAndBlankDeploymentProvider_doesNOTfiresValidationError() {
		HiddenFeatures__mdt hiddenFeatureDeploymentAccred = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentAccred'
		);
		hiddenFeatureDeploymentAccred.isActive__c = 'False';
		HiddenFeatures__mdt hiddenFeatureDeploymentVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		hiddenFeatureDeploymentVR.isActive__c = 'False';
		Pricebook2 midMarketPriceBook = [
			SELECT Id
			FROM Pricebook2
			WHERE Name = 'Global Pricebook'
			LIMIT 1
		];
		Boolean exceptionThrown1 = false, exceptionThrown2 = false;
		String exceptionMessage1 = '', exceptionMessage2 = '';
		Opportunity oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
		Account acct = [
			SELECT On_Prem_Deployment_Verified__c, Cloud_Deployment_Verified__c
			FROM Account
			WHERE Id = :oppty.AccountId
		];
		System.assertEquals(false, acct.On_Prem_Deployment_Verified__c);
		System.assertEquals(false, acct.Cloud_Deployment_Verified__c);
		Account partner = [SELECT Id FROM Account WHERE RecordType.Name = 'Partner' LIMIT 1];

		System.runAs(getDealDeskUser()) {
			oppty.Pricebook2Id = midMarketPriceBook.Id;
			update oppty;
			Test.startTest();
			try {
				SBQQ__Quote__c testQuote1 = new SBQQ__Quote__c(
					SBQQ__Account__c = oppty.AccountId,
					SBQQ__EndDate__c = Date.today().addDays(30),
					SBQQ__Opportunity2__c = oppty.Id,
					SBQQ__Partner__c = partner.Id,
					SBQQ__PaymentTerms__c = 'Net 30',
					SBQQ__PriceBook__c = midMarketPriceBook.Id,
					SBQQ__Primary__c = false,
					SBQQ__StartDate__c = Date.today(),
					SBQQ__Status__c = 'Accepted',
					SBQQ__SubscriptionTerm__c = 30,
					SBQQ__Type__c = 'Quote'
				);
				testQuote1.Bypass_Partner_Requirement__c = false;
				testQuote1.Deployment_Exception_Granted__c = false;
				testQuote1.Deployment_Method__c = TAAS_DEPLOYMENT;
				testQuote1.L1_L2_Support_Partner__c = partner.Id;
				insert testQuote1;
				testQuote1 = [
					SELECT SBQQ__priceBook__c, SBQQ__PricebookId__c, Sales_Ops_Derived_EP__c
					FROM SBQQ__Quote__c
					WHERE Id = :testQuote1.Id
				];
				System.assertEquals(
					true,
					testQuote1.Sales_Ops_Derived_EP__c > 0 && testQuote1.Sales_Ops_Derived_EP__c < 10000
				);
				System.assertEquals(true, testQuote1.SBQQ__PricebookId__c == midMarketPriceBook.Id);

				System.assertEquals(
					true,
					QuoteCPQTriggerUtility.isMidMarket(testQuote1),
					'is MidMarket'
				);
			} catch (Exception myException) {
				exceptionThrown1 = true;
				exceptionMessage1 = myException.getMessage();
			}
			try {
				SBQQ__Quote__c testQuote2 = new SBQQ__Quote__c(
					SBQQ__Account__c = oppty.AccountId,
					SBQQ__EndDate__c = Date.today().addDays(30),
					SBQQ__Opportunity2__c = oppty.Id,
					SBQQ__Partner__c = partner.Id,
					SBQQ__PaymentTerms__c = 'Net 30',
					SBQQ__PriceBook__c = midMarketPriceBook.Id,
					SBQQ__Primary__c = false,
					SBQQ__StartDate__c = Date.today(),
					SBQQ__Status__c = 'Accepted',
					SBQQ__SubscriptionTerm__c = 30,
					SBQQ__Type__c = 'Quote'
				);
				testQuote2.Bypass_Partner_Requirement__c = false;
				testQuote2.Deployment_Exception_Granted__c = false;
				testQuote2.Deployment_Method__c = ON_PREM_DEPLOYMENT;
				testQuote2.L1_L2_Support_Partner__c = partner.Id;
				testQuote2.SBQQ__PriceBook__c = midMarketPriceBook.Id;
				insert testQuote2;
				testQuote2 = [
					SELECT
						Opportunity_Type__c,
						SBQQ__PriceBook__c,
						SBQQ__PricebookId__c,
						Sales_Ops_Derived_EP__c
					FROM SBQQ__Quote__c
					WHERE Id = :testQuote2.Id
				];
				System.assertEquals(true, testQuote2.SBQQ__PricebookId__c == midMarketPriceBook.Id);
				System.assertEquals(
					true,
					QuoteCPQTriggerUtility.isMidMarket(testQuote2),
					'is MidMarket'
				);
				System.assertEquals('New Customer', testQuote2.Opportunity_Type__c, 'is New Customer');
				System.assertEquals(
					'',
					exceptionMessage1,
					'Exception message with blank deployment provider'
				);
				System.assertEquals(
					false,
					exceptionMessage1.contains('Deployment provider'),
					'Exception message with blank deployment provider'
				);
			} catch (Exception myException) {
				exceptionThrown2 = true;
				exceptionMessage2 = myException.getMessage();
			}
			System.assertEquals(
				false,
				exceptionThrown2,
				'non primary quote does not show validation error'
			);
		}
	}

	@IsTest
	static void testDeploymentProviderValidation_whenInsertDeloymentMethodIsTaaSOrOnPrem_doesNotfireValidationError() {
		Boolean exceptionThrown1 = false;
		String exceptionMessage1 = '';
		Opportunity oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
		Account partner = [
			SELECT Id
			FROM Account
			WHERE RecordType.Name = 'Partner' AND Cloud_Deployment_Verified__c = TRUE
			LIMIT 1
		];
		SBQQ__Quote__c testQuote1 = [
			SELECT Id, Deployment_Method__c, Deployment_Partner__c
			FROM SBQQ__Quote__c
			WHERE Deployment_Method__c = :TAAS_DEPLOYMENT AND SBQQ__Type__c = 'Quote'
		];
		System.assertNotEquals(null, testQuote1);
		PriceBook2 globalPriceBook = [SELECT Id FROM PriceBook2 WHERE Name LIKE 'Global%' LIMIT 1];
		SBQQ__Quote__c testQuote2, testQuote3;
		System.runAs(getDealDeskUser()) {
			Test.startTest();
			try {
				testQuote2 = new SBQQ__Quote__c(
					SBQQ__Account__c = oppty.AccountId,
					SBQQ__EndDate__c = Date.today().addDays(30),
					SBQQ__Opportunity2__c = oppty.Id,
					SBQQ__PaymentTerms__c = 'Net 30',
					SBQQ__PriceBook__c = globalPriceBook.Id,
					SBQQ__StartDate__c = Date.today(),
					SBQQ__Status__c = 'Accepted',
					SBQQ__SubscriptionTerm__c = 30,
					SBQQ__Type__c = 'Quote'
				);
				testQuote2.Deployment_Method__c = ON_PREM_DEPLOYMENT;
				testQuote2.Deployment_Partner__c = partner.Id;
				testQuote2.L1_L2_Support_Partner__c = partner.Id;
				//following 3 conditions make Deployment provider as NOT required field
				testQuote2.Bypass_Partner_Requirement__c = true;
				testQuote2.Deployment_Exception_Granted__c = true;
				testQuote2.SBQQ__Primary__c = false;
				insert testQuote2;
			} catch (Exception myException) {
				exceptionThrown1 = true;
				exceptionMessage1 = myException.getMessage();
			}
			System.assertEquals(
				false,
				QuoteCPQTriggerUtility.isDeploymentProviderRequired(testQuote2),
				'deployment provider is not required'
			);
			System.assertEquals(
				'',
				exceptionMessage1,
				'Exception message is blank indicating no exception was thrown'
			);
			System.assertEquals(false, exceptionThrown1, 'no exception thrown');
		}
	}

	@IsTest
	static void testDeploymentProviderValidation_whenNonPrimaryQuoteInsertDeloymentMethodIsTaaSOrOnPrem_doesNotfireValidationError() {
		Boolean exceptionThrown1 = false;
		String exceptionMessage1 = '';
		Opportunity oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
		Account partner = [
			SELECT Id
			FROM Account
			WHERE RecordType.Name = 'Partner' AND Cloud_Deployment_Verified__c = TRUE
			LIMIT 1
		];
		SBQQ__Quote__c testQuote1 = [
			SELECT Id, Deployment_Method__c, Deployment_Partner__c
			FROM SBQQ__Quote__c
			WHERE Deployment_Method__c = :TAAS_DEPLOYMENT AND SBQQ__Type__c = 'Quote'
		];
		System.assertNotEquals(null, testQuote1);
		PriceBook2 globalPriceBook = [SELECT Id FROM PriceBook2 WHERE Name LIKE 'Global%' LIMIT 1];
		SBQQ__Quote__c testQuote2, testQuote3;
		System.runAs(getDealDeskUser()) {
			Test.startTest();
			try {
				testQuote2 = new SBQQ__Quote__c(
					SBQQ__Account__c = oppty.AccountId,
					SBQQ__EndDate__c = Date.today().addDays(30),
					SBQQ__Opportunity2__c = oppty.Id,
					SBQQ__PaymentTerms__c = 'Net 30',
					SBQQ__PriceBook__c = globalPriceBook.Id,
					SBQQ__StartDate__c = Date.today(),
					SBQQ__Status__c = 'Accepted',
					SBQQ__SubscriptionTerm__c = 30,
					SBQQ__Type__c = 'Quote'
				);
				testQuote2.Deployment_Method__c = ON_PREM_DEPLOYMENT;
				testQuote2.Deployment_Partner__c = partner.Id;
				testQuote2.L1_L2_Support_Partner__c = partner.Id;
				//following 3 conditions make Deployment provider as NOT required field
				testQuote2.Bypass_Partner_Requirement__c = true;
				testQuote2.Deployment_Exception_Granted__c = true;
				testQuote2.SBQQ__Primary__c = false;
				insert testQuote2;
			} catch (Exception myException) {
				exceptionThrown1 = true;
				exceptionMessage1 = myException.getMessage();
			}
			System.assertEquals(
				false,
				QuoteCPQTriggerUtility.isDeploymentProviderRequired(testQuote2),
				'deployment provider is not required'
			);
			System.assertEquals(
				'',
				exceptionMessage1,
				'Exception message is blank indicating no exception was thrown'
			);
			System.assertEquals(false, exceptionThrown1, 'no exception thrown');
		}
	}

	@IsTest
	static void testCheckPartner_whenPartnerMissing_firesValidationError() {
		Boolean exceptionThrown1 = false;
		String exceptionMessage1 = '';
		Opportunity oppty = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
		SBQQ__Quote__c testQuote1;
		System.runAs(TestUserFactory.getAdminUser()) {
			oppty.Business_Motion__c = 'MSP';
			update oppty;
			Account partner = [
				SELECT Id
				FROM Account
				WHERE RecordType.Name = 'Partner' AND Cloud_Deployment_Verified__c = TRUE
				LIMIT 1
			];
			testQuote1 = [
				SELECT Id, SBQQ__Partner__c
				FROM SBQQ__Quote__c
				WHERE
					Business_Motion_Oppty__c = 'MSP'
					AND SBQQ__Partner__c = NULL
					AND SBQQ__Type__c != 'Renewal'
					AND SBQQ__Type__c != 'Amendment'
				LIMIT 1
			];
			testQuote1.ApprovalStatus__c = null;
			update testQuote1;
		}

		Boolean exceptionThrown = false;
		String exceptionMessage = '';

		TriggerHandler.resetRecursionLimits();
		System.runAs(getDealDeskUser()) {
			Test.startTest();
			try {
				testQuote1 = [
					SELECT Id, SBQQ__Partner__c
					FROM SBQQ__Quote__c
					WHERE
						Business_Motion_Oppty__c = 'MSP'
						AND SBQQ__Partner__c = NULL
						AND SBQQ__Type__c != 'Renewal'
						AND SBQQ__Type__c != 'Amendment'
						AND ApprovalStatus__c = NULL
					LIMIT 1
				];
				System.assertNotEquals(null, testQuote1);

				testQuote1.SBQQ__PaymentTerms__c = 'Net 60';
				testQuote1.Do_Not_Show_Dates__c = false;
				update testQuote1;
			} catch (Exception e) {
				exceptionThrown = true;
				exceptionMessage = e.getMessage();
			}
			Test.stopTest();
			System.assertEquals(true, exceptionThrown);
			System.assertEquals(true, exceptionMessage.contains(System.Label.Partner_Required));
		}
	}

	@IsTest
	static void setPaymentTermOnBillingQuoteTerms_WhenPaymentTermOverride_UpdateBillingQuoteTerm() {
		SBQQ__Quote__c quote = [
			SELECT Id, Name, SBQQ__PaymentTerms__c, BillingQuoteTerms__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			quote.BillingQuoteTerms__c = testBillingQuoteTerm;
			update quote;

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			quote.SBQQ__PaymentTerms__c = 'Net 15';
			quote.Payment_Term_Override__c = true;
			update quote;
			Test.stopTest();
		}

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

	@IsTest
	static void testIdentifyNewModules_WhenNewModulesOnQuote_PopulateNewlyQuotedModulesFieldOnQuote() {
		Account account = [SELECT Id FROM Account WHERE Name = :testAccountName LIMIT 1];
		List<SBQQ__Quote__c> quotes = [
			SELECT Id, SBQQ__Account__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Account__c = :account.Id
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteCPQTriggerUtility.identifyNewModules(quotes);
			Test.stopTest();
		}

		SBQQ__Quote__c updatedQuote = [
			SELECT Id, Newly_Quoted_Modules__c
			FROM SBQQ__Quote__c
			WHERE Id = :quotes[0].Id
		];

		Assert.isTrue(updatedQuote.Newly_Quoted_Modules__c != null);
	}

	@IsTest
	static void testDetermineLegalEntitiesBeforeInsert() {
		Account testAccount = [SELECT Id FROM Account WHERE Name = :testAccountName LIMIT 1];
		Opportunity testOpportunity = [SELECT Id FROM Opportunity WHERE Name = :testOppName LIMIT 1];
		Contracting_Entity__c contractingEntity = [
			SELECT Id, Legal_Entity__c, Legal_Entity__r.Name
			FROM Contracting_Entity__c
			WHERE Country__c = :TEST_COUNTRY_2
			LIMIT 1
		];
		SBQQ__Quote__c quote = [
			SELECT Id, PaymentTypeNew__c, Legal_Entity__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];
		String desiredLegalEntityName = contractingEntity.Legal_Entity__r.Name;
		SBQQ__Quote__c clonedQuote;

		System.runAs(TestUserFactory.getAdminUser()) {
			testAccount.BillingCountry = TEST_COUNTRY_2;
			update testAccount;

			quote.Legal_Entity__c = contractingEntity.Legal_Entity__c;
			update quote;

			Test.startTest();
			clonedQuote = quote.clone(false, true, false, false);
			clonedQuote.SBQQ__Opportunity2__c = testOpportunity.Id;
			clonedQuote.SBQQ__BillingCountry__c = TEST_COUNTRY_2;
			clonedQuote.Legal_Entity_Override__c = false;
			clonedQuote.SBQQ__Primary__c = true;
			insert clonedQuote;

			Test.stopTest();
		}

		clonedQuote = [
			SELECT Id, SBQQ__BillingCountry__c, Legal_Entity__r.Name
			FROM SBQQ__Quote__c
			WHERE Id = :clonedQuote.Id
		];
		System.assertEquals(
			desiredLegalEntityName,
			clonedQuote.Legal_Entity__r.Name,
			'Our quote\'s legal entity should have been ' + testLegalEntityName
		);
	}

	@IsTest
	static void testDetermineLegalEntitiesBeforeInsert_NoLegalEntity() {
		Account testAccount = [SELECT Id FROM Account WHERE Name = :testAccountName LIMIT 1];
		Opportunity testOpportunity = [SELECT Id FROM Opportunity WHERE Name = :testOppName LIMIT 1];
		Legal_Entity__c legalEntity = [
			SELECT Id, Name
			FROM Legal_Entity__c
			WHERE Name = :testLegalEntityName
			LIMIT 1
		];
		Legal_Entity__c desiredLegalEntity = legalEntity;
		SBQQ__Quote__c testQuote;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
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
			testQuote.Legal_Entity_Override__c = true;
			testQuote.SBQQ__Primary__c = true;
			insert testQuote;
			Test.stopTest();
		}

		testQuote = [
			SELECT Id, SBQQ__BillingCountry__c, Legal_Entity__c
			FROM SBQQ__Quote__c
			WHERE Id = :testQuote.Id
		];
		System.assertEquals(
			null,
			testQuote.Legal_Entity__c,
			'Our quote\'s legal entity should have been overridden with ' + testLegalEntityName + 2
		);
	}

	@IsTest
	static void testDetermineLegalEntitiesBeforeUpdate_NoLegalEntity() {
		Account testAccount = [SELECT Id FROM Account WHERE Name = :testAccountName LIMIT 1];
		Opportunity testOpportunity = [SELECT Id FROM Opportunity WHERE Name = :testOppName LIMIT 1];
		Legal_Entity__c legalEntity = [
			SELECT Id, Name
			FROM Legal_Entity__c
			WHERE Name = :testLegalEntityName
			LIMIT 1
		];
		Legal_Entity__c desiredLegalEntity = legalEntity;
		SBQQ__Quote__c testQuote;

		System.runAs(TestUserFactory.getAdminUser()) {
			testQuote = TestFactory.buildSBQQ_Quote(
				testOpportunity.Id,
				testAccount.Id,
				'Draft',
				'Quote',
				Date.today(),
				Date.today().addDays(30),
				null
			);
			testQuote.Legal_Entity_Override__c = true;
			testQuote.SBQQ__Primary__c = true;
			insert testQuote;

			Test.startTest();
			testQuote.SBQQ__BillingCountry__c = TEST_COUNTRY_1;
			testQuote.Legal_Entity_Override__c = true;
			testQuote.Legal_Entity__c = legalEntity.Id;
			update testQuote;
			Test.stopTest();
		}

		testQuote = [
			SELECT Id, SBQQ__BillingCountry__c, Legal_Entity__c
			FROM SBQQ__Quote__c
			WHERE Id = :testQuote.Id
		];
		System.assertEquals(
			desiredLegalEntity.Id,
			testQuote.Legal_Entity__c,
			'Our quote\'s legal entity should have been ' + testLegalEntityName
		);
	}

	@IsTest
	static void testDetermineLegalEntitiesBeforeUpdate_WhenNotFederalAndNotCloned_UseBillingCountry() {
		List<SBQQ__Quote__c> quotes = [
			SELECT
				Id,
				Legal_Entity__c,
				SBQQ__Partner__c,
				SBQQ__Opportunity2__c,
				SBQQ__BillingCountry__c,
				Legal_Entity_Override__c
			FROM SBQQ__Quote__c
		];
		Map<Id, SBQQ__Quote__c> oldMap = new Map<Id, SBQQ__Quote__c>(
			quotes.deepClone(true, true, true)
		);

		for (SBQQ__Quote__c quote : quotes) {
			quote.SBQQ__BillingCountry__c = TEST_COUNTRY_2;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteCPQTriggerUtility.determineLegalEntitiesBeforeUpdate(quotes, oldMap);
			Test.stopTest();
		}

		for (SBQQ__Quote__c quote : quotes) {
			Assert.isTrue(
				quote.Legal_Entity__c != null,
				'Our quote\'s legal entity should have been set'
			);
		}
	}

	@IsTest
	static void testSetAICredits_WhenCalculatedAnnualizedSoftwareSpendIsUpdated_SetCalculatedAICreditsOnQuote() {
		List<SBQQ__Quote__c> quotes = [
			SELECT Id, SBQQ__Account__c, Calculated_Annualized_Software_Spend__c
			FROM SBQQ__Quote__c
			WHERE SBQQ__Type__c = 'Renewal'
		];

		Map<Id, SBQQ__Quote__c> oldMap = new Map<Id, SBQQ__Quote__c>(
			quotes.deepClone(true, true, true)
		);

		for (SBQQ__Quote__c quote : quotes) {
			quote.Calculated_Annualized_Software_Spend__c = 150000;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteCPQTriggerUtility.setAICredits(quotes, oldMap);
			Test.stopTest();
		}

		Boolean quotesWithAICredits = false;

		for (SBQQ__Quote__c quote : quotes) {
			if (quote.Calculated_AI_Credits__c != 0 && quote.Calculated_AI_Credits__c != null) {
				quotesWithAICredits = true;
			}
		}

		Assert.isTrue(quotesWithAICredits, 'At least one quote should have AI Credits set');
	}

	@IsTest
	static void testDetermineIfQuoteWasCloned() {
		System.runAs(TestUserFactory.getAdminUser()) {
			TriggerHandler.bypass('QuoteCPQTriggerHandler');
			SBQQ__Quote__c quote = [SELECT Id, PaymentTypeNew__c FROM SBQQ__Quote__c LIMIT 1];

			SBQQ__Quote__c clonedQuote = quote.clone(false, true, false, false);
			clonedQuote.PaymentTypeNew__c = BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE;
			insert clonedQuote;

			Test.startTest();
			QuoteCPQTriggerUtility.determineIfQuoteWasCloned(new List<SBQQ__Quote__c>{ clonedQuote });
			Test.stopTest();

			List<SBQQ__QuoteTerm__c> quoteTerms = [
				SELECT Id
				FROM SBQQ__QuoteTerm__c
				WHERE SBQQ__Quote__c = :clonedQuote.Id
			];

			Assert.isFalse(quoteTerms.isEmpty(), 'Quote Terms should be cloned');
		}
	}

	static User getDealDeskUser() {
		User[] dealDeskUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.DEAL_DESK_USER];
		if (dealDeskUsers.isEmpty()) {
			dealDeskUser = TestUserFactory.createDealDeskUser();
			TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableFlows');
			return dealDeskUser;
		}
		return dealDeskUsers[0];
	}
}