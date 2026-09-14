/**
 * @Business: Test class for QuoteLineTrigger
 * @Date: 2018-03-26
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request: TAN-494
 * RequestId  ModifiedDate  Description
 * TAN-494    2018-03-26    Initial Development
 * TAN-715    2018-11-14    Added trigger management for QuoteLineTrigger.
 * TAN-750    2019-02-06    Added new test methods for Code Coverage
 * SS-7632    2024-03-26    Remove test method for checkRenewedSubscriptionQuoteLines from beforeDelete method.
 * SS-7665    2024-04-23    isMSP to use quote.Business_Motion_Oppty='MSP'
 * SS-11167   2025-06-19    Removed instantiation of TestFactory class, replaced with Global Pricebook record
 * SS-8074    2025-07-18    Removed field check from test method which will be deprecated
 * SS-12886   2026-04-28    Added running makeData() as admin user
 */
@IsTest
private class QuoteLineTriggerHandlerTest {
	private static User standardUser;

	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()){
			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Global Pricebook description.',
				IsActive = true
			);
			insert globalPriceBook;

			Account acc = TestFactory.buildAccount('testAccountName');
			acc.Type = 'Partner';
			acc.Country_Exception_Approved__c = true;
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'testOppName',
				System.today().addDays(30),
				Utility.DISCOVERY,
				acc.Id
			);
			opp.Pricebook2Id = Test.getStandardPricebookId();
			insert opp;

			SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				'Quote',
				System.today(),
				System.today().addDays(30),
				Test.getStandardPricebookId()
			);
			quote.SBQQ__SubscriptionTerm__c = 30;
			quote.Unlock_Quote__c = false;
			insert quote;

			Product2 pd1 = buildProduct('Product-1', false);
			pd1.Product_Group__c = 'Software';
			pd1.Product_Category__c = '';
			insert pd1;

			SBQQ__QuoteLine__c qLine1 = buildQuoteLineNew(pd1.Id, quote.Id, true);
			qLine1.Product_Group__c = 'Software';
			qLine1.SBQQ__Bundle__c = true;
			insert qLine1;
		}
	}

	@IsTest
	static void beforeUpdate_WhenQuoteHasLockedStatus_ShowsError() {
		SBQQ__Quote__c testQuote = [
			SELECT Id, SBQQ__Status__c, ApprovalStatus__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];
		List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();

		System.runAs(TestUserFactory.getAdminUser()) {
			Product2 product = buildProduct('Test Product ', false);
			insert product;

			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Core-LTD'));
			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Asset'));
			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Comply'));
			insert quoteLineList;

			//SBQQ__Quote__c rollup update was called on SBQQ__QuoteLine__c insert
			TriggerHandler.resetRecursionLimits();
			testQuote.SBQQ__Status__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			testQuote.ApprovalStatus__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			update testQuote;
		}

		String actualErrorMessage = '';

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			try {
				for (SBQQ__QuoteLine__c quoteLine : quoteLineList) {
					quoteLine.SBQQ__Discount__c++;
				}
				update quoteLineList;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}
		System.assert(actualErrorMessage.contains(System.Label.Quote_Line_Locked));
	}

	@IsTest
	static void afterUpdate_WhenApprovedNonPrimaryQuoteIsSetToPrimaryWithOtherFields_ReturnsError() {
		SBQQ__Quote__c testQuote = [
			SELECT
				Id,
				SBQQ__Status__c,
				ApprovalStatus__c,
				SBQQ__Opportunity2__c,
				SBQQ__Opportunity2__r.AccountId,
				SBQQ__Opportunity2__r.Pricebook2Id,
				SBQQ__Pricebook__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];
		SBQQ__Quote__c approveNonPrimaryQuote = new SBQQ__Quote__c();
		List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();

		System.runAs(TestUserFactory.getAdminUser()) {
			TriggerHandler.bypass(
				new List<String>{ 'QuoteCPQTriggerHandler', 'QuoteLineTriggerHandler' }
			);
			approveNonPrimaryQuote = buildQuote(
				testQuote.SBQQ__Opportunity2__c,
				testQuote.SBQQ__Opportunity2__r.Pricebook2Id,
				testQuote.SBQQ__Opportunity2__r.AccountId
			);
			approveNonPrimaryQuote.SBQQ__Primary__c = false;
			approveNonPrimaryQuote.SBQQ__SubscriptionTerm__c = 12;
			approveNonPrimaryQuote.SBQQ__Status__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			approveNonPrimaryQuote.ApprovalStatus__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			insert approveNonPrimaryQuote;

			Product2 product = buildProduct('Test Product ', false);
			insert product;

			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Core-LTD'));
			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Asset'));
			quoteLineList.add(buildQuoteLine(approveNonPrimaryQuote.Id, product.Id, 'Comply'));
			insert quoteLineList;
		}

		String actualErrorMessage = '';

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			TriggerHandler.clearAllBypasses();
			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			try {
				approveNonPrimaryQuote.SBQQ__Primary__c = true;
				approveNonPrimaryQuote.SBQQ__SubscriptionTerm__c = 36;
				update approveNonPrimaryQuote;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}

		SBQQ__Quote__c primaryQuote = [
			SELECT Id, Primary_Updated_and_Approved__c, SBQQ__Primary__c
			FROM SBQQ__Quote__c
			WHERE Id = :approveNonPrimaryQuote.Id
		];
		System.assertEquals(false, String.isBlank(actualErrorMessage), 'Error should occur');
		System.assert(actualErrorMessage.contains(System.Label.Quote_Line_Locked));
	}

	@IsTest
	static void beforeDelete_WhenQuoteHasLockedStatus_ShowsError() {
		SBQQ__Quote__c testQuote = [
			SELECT Id, SBQQ__Status__c, ApprovalStatus__c, SBQQ__PriceBook__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];
		List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();

		System.runAs(TestUserFactory.getAdminUser()) {
			Product2 product = buildProduct('Test Product ', false);
			insert product;

			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Core-LTD'));
			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Asset'));
			quoteLineList.add(buildQuoteLine(testQuote.Id, product.Id, 'Comply'));
			insert quoteLineList;

			//SBQQ__Quote__c rollup update was called on SBQQ__QuoteLine__c insert
			TriggerHandler.resetRecursionLimits();

			testQuote.SBQQ__Status__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			testQuote.ApprovalStatus__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			update testQuote;
		}

		String actualErrorMessage = '';

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			try {
				delete quoteLineList;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(actualErrorMessage.contains(System.Label.Quote_Line_Locked));
	}

	@IsTest
	static void populateRollupSummaryFields_WhenQuoteLinesInserted_UpdatesParentQuote() {
		SBQQ__Quote__c testQuote = [SELECT Id, SBQQ__PriceBook__c FROM SBQQ__Quote__c LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Product2 product = buildProduct('Test Product ', false);
			insert product;

			Test.startTest();
			list<SBQQ__QuoteLine__c> listQuoteLine = buildQuoteLines(testQuote.Id, product.Id);
			insert listQuoteLine;
			Test.stopTest();
		}

		testQuote = [
			SELECT
				Id,
				Appliance_SKUs__c,
				HardwareSupport__c,
				Bursting_Count__c,
				IRProductDescription__c,
				IR_Use_Only__c,
				Managed_OS__c,
				MediaTypeOnTemplate__c,
				OnsiteTAMCount__c,
				PromotionExist__c,
				Selling_Core_Subparts__c,
				TaniumAssetDefinitions__c,
				TaniumComplyDefinitions__c,
				TaniumCoreDefinition__c,
				TaniumDiscoverDefinition__c,
				TaniumIMDefinitions__c,
				TaniumIOCDetectDef__c,
				TaniumPatchDefinitions__c,
				TaniumProtectDefinitions__c,
				TaniumSecuritySuiteDef__c,
				TaniumThreatResponseDef__c,
				TaniumTraceDefinitions__c
			FROM SBQQ__Quote__c
			WHERE Id = :testQuote.Id
		];

		System.assertEquals(1, testQuote.Appliance_SKUs__c);
		System.assertEquals(1, testQuote.Bursting_Count__c);
		System.assertEquals(1, testQuote.HardwareSupport__c);
		System.assertEquals(1, testQuote.IRProductDescription__c);
		System.assertEquals(1, testQuote.IR_Use_Only__c);
		System.assertEquals(1, testQuote.Managed_OS__c);
		System.assertEquals(1, testQuote.MediaTypeOnTemplate__c);
		System.assertEquals(1, testQuote.OnsiteTAMCount__c);
		System.assertEquals(1, testQuote.PromotionExist__c);
		System.assertEquals(1, testQuote.Selling_Core_Subparts__c);
		System.assertEquals(1, testQuote.TaniumAssetDefinitions__c);
		System.assertEquals(1, testQuote.TaniumComplyDefinitions__c);
		System.assertEquals(1, testQuote.TaniumCoreDefinition__c);
		System.assertEquals(1, testQuote.TaniumDiscoverDefinition__c);
		System.assertEquals(1, testQuote.TaniumIMDefinitions__c);
		System.assertEquals(1, testQuote.TaniumIOCDetectDef__c);
		System.assertEquals(1, testQuote.TaniumPatchDefinitions__c);
		System.assertEquals(1, testQuote.TaniumProtectDefinitions__c);
		System.assertEquals(1, testQuote.TaniumSecuritySuiteDef__c);
		System.assertEquals(1, testQuote.TaniumThreatResponseDef__c);
		System.assertEquals(1, testQuote.TaniumTraceDefinitions__c);
	}

	@IsTest
	static void populateRollupSummaryFields_WhenQuoteLinesUpdated_UpdatesParentQuote() {
		SBQQ__Quote__c testQuote = [SELECT Id, SBQQ__PriceBook__c FROM SBQQ__Quote__c LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Product2 product = buildProduct('product 1 ', false);
			insert product;

			list<SBQQ__QuoteLine__c> listQuoteLine = buildQuoteLines(testQuote.Id, product.Id);
			insert listQuoteLine;

			SBQQ__QuoteLine__c quoteLine = [
				SELECT Id, Product_Line__c
				FROM SBQQ__QuoteLine__c
				WHERE Product_Line__c = 'Appliance' AND SBQQ__Quote__c = :testQuote.Id
				LIMIT 1
			];

			//SBQQ__Quote__c rollup update was called on SBQQ__QuoteLine__c insert
			TriggerHandler.resetRecursionLimits();
			SBQQ.TriggerControl.disable();

			Test.startTest();
			quoteLine.Product_Line__c = 'IR';
			update quoteLine;
			Test.stopTest();
		}

		testQuote = [
			SELECT Id, Appliance_SKUs__c, HardwareSupport__c, IRProductDescription__c
			FROM SBQQ__Quote__c
			WHERE Id = :testQuote.Id
		];

		System.assertEquals(2, testQuote.IRProductDescription__c, '2 quotelines with IR product lines');
		System.assertEquals(0, testQuote.Appliance_SKUs__c, 'No more appliance product lines');
		System.assertEquals(0, testQuote.HardwareSupport__c, 'No more appliance product lines');
	}

	@IsTest
	static void populateRollupSummaryFields_WhenQuoteLinesDeleted_UpdatesParentQuote() {
		SBQQ__Quote__c testQuote = [SELECT Id, SBQQ__PriceBook__c FROM SBQQ__Quote__c LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Product2 product = buildProduct('product 1 ', false);
			insert product;

			list<SBQQ__QuoteLine__c> listQuoteLine = buildQuoteLines(testQuote.Id, product.Id);
			insert listQuoteLine;

			//SBQQ__Quote__c rollup update was called on SBQQ__QuoteLine__c insert
			TriggerHandler.resetRecursionLimits();

			Test.startTest();
			delete [SELECT Id FROM SBQQ__QuoteLine__c WHERE Promotion__c = 'Burst'];
			Test.stopTest();
		}

		testQuote = [SELECT Id, Bursting_Count__c FROM SBQQ__Quote__c WHERE Id = :testQuote.Id];

		System.assertEquals(0, testQuote.Bursting_Count__c);
	}

	@IsTest
	static void billingDatesAndAmountsTest() {
		Account testAccount = [SELECT Id FROM Account LIMIT 1];

		Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];

		SBQQ__Quote__c testQuote1 = new SBQQ__Quote__c(
			PaymentTypeNew__c = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE,
			First_Billing_Override__c = false,
			SBQQ__StartDate__c = Date.today(),
			SBQQ__EndDate__c = Date.today().addDays(30),
			SBQQ__Opportunity2__c = testOpportunity.Id,
			SBQQ__PriceBook__c = Test.getStandardPricebookId(),
			SBQQ__Account__c = testAccount.Id,
			SBQQ__Status__c = 'Accepted',
			SBQQ__Type__c = 'Quote',
			SBQQ__SubscriptionTerm__c = 30
		);
		insert testQuote1;

		Product2 product = buildProduct('product 1 ', false);

		Product2 bundleParentHardware = buildProduct('Bundle Parent Hardware', true);
		bundleParentHardware.A_la_carte_Required_SKUs__c = true;
		bundleParentHardware.Bundle_Component__c = 'myBundleComponentHardware';
		bundleParentHardware.Bundle_List_Price__c = 1000;

		Product2 myBundleComponentHardware = buildProduct('myBundleComponentHardware', true);
		myBundleComponentHardware.Bundle_List_Price__c = 1000;

		Product2 bundleParentSoftware = buildProduct('Bundle Parent Software', true);
		bundleParentSoftware.A_la_carte_Required_SKUs__c = true;
		bundleParentSoftware.Bundle_Component__c = 'myBundleComponentSoftware';
		bundleParentSoftware.Bundle_List_Price__c = 1000;

		Product2 myBundleComponentSoftware = buildProduct('myBundleComponentSoftware', true);
		myBundleComponentSoftware.Bundle_List_Price__c = 1000;

		List<Product2> products = new List<Product2>{
			product,
			bundleParentHardware,
			myBundleComponentHardware,
			bundleParentSoftware,
			myBundleComponentSoftware
		};
		insert products;

		Test.startTest();
		SBQQ__QuoteLine__c qLineFlatSKU = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[0].Id,
			SBQQ__Quantity__c = 10,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			Product_Group__c = null,
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineParentBundleHardware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[1].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			SBQQ__Bundle__c = true,
			Product_Group__c = 'Hardware',
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineBundleComponentHardware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[2].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			Bundled_Product__c = true,
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineParentBundleSoftware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[3].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			SBQQ__Bundle__c = true,
			Product_Group__c = 'Software',
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineBundleComponentSoftware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[4].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			SBQQ__Bundle__c = false,
			Product_Group__c = 'Software',
			SBQQ__NetPrice__c = 1000,
			Bundled_Product__c = true
		);
		insert new List<SBQQ__QuoteLine__c>{
			qLineFlatSKU,
			qLineParentBundleSoftware,
			qLineBundleComponentSoftware,
			qLineParentBundleHardware,
			qLineBundleComponentHardware
		};
		Test.stopTest();
	}

	@IsTest
	static void billingDatesAndAmountsTestReverse() {
		Account testAccount = [SELECT Id FROM Account LIMIT 1];
		Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];

		SBQQ__Quote__c testQuote1 = new SBQQ__Quote__c(
			SBQQ__StartDate__c = Date.today(),
			SBQQ__EndDate__c = Date.today().addDays(30),
			SBQQ__Opportunity2__c = testOpportunity.Id,
			SBQQ__PriceBook__c = Test.getStandardPricebookId(),
			SBQQ__Account__c = testAccount.Id,
			SBQQ__Status__c = 'Accepted',
			SBQQ__Type__c = 'Quote',
			SBQQ__SubscriptionTerm__c = 30,
			PaymentTypeNew__c = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE,
			First_Billing_Override__c = false
		);
		insert testQuote1;

		Product2 product = buildProduct('product 1 ', true);

		Product2 bundleParentHardware = buildProduct('Bundle Parent Hardware', true);
		bundleParentHardware.A_la_carte_Required_SKUs__c = true;
		bundleParentHardware.Bundle_Component__c = 'myBundleComponentHardware';
		bundleParentHardware.Bundle_List_Price__c = 1000;

		Product2 myBundleComponentHardware = buildProduct('myBundleComponentHardware', true);
		myBundleComponentHardware.Bundle_List_Price__c = 1000;

		Product2 bundleParentSoftware = buildProduct('Bundle Parent Software', true);
		bundleParentSoftware.A_la_carte_Required_SKUs__c = true;
		bundleParentSoftware.Bundle_Component__c = 'myBundleComponentSoftware';
		bundleParentSoftware.Bundle_List_Price__c = 1000;

		Product2 myBundleComponentSoftware = buildProduct('myBundleComponentSoftware', true);
		myBundleComponentSoftware.Bundle_List_Price__c = 1000;

		List<Product2> products = new List<Product2>{
			product,
			bundleParentHardware,
			myBundleComponentHardware,
			bundleParentSoftware,
			myBundleComponentSoftware
		};
		insert products;

		Test.startTest();
		SBQQ__QuoteLine__c qLineFlatSKU = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[0].Id,
			SBQQ__Quantity__c = 10,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			Product_Group__c = null,
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineParentBundleHardware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[1].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			SBQQ__Bundle__c = true,
			Product_Group__c = 'Hardware',
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineBundleComponentHardware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[2].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			Bundled_Product__c = true,
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineParentBundleSoftware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[3].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			SBQQ__Bundle__c = true,
			Product_Group__c = 'Software',
			SBQQ__NetPrice__c = 1000
		);

		SBQQ__QuoteLine__c qLineBundleComponentSoftware = new SBQQ__QuoteLine__c(
			SBQQ__Product__c = products[4].Id,
			SBQQ__Quantity__c = 1,
			SBQQ__Quote__c = testQuote1.Id,
			SBQQ__StartDate__c = System.today() + 30,
			SBQQ__Bundle__c = false,
			Product_Group__c = 'Software',
			SBQQ__NetPrice__c = 1000,
			Bundled_Product__c = true
		);
		insert new List<SBQQ__QuoteLine__c>{
			qLineFlatSKU,
			qLineParentBundleSoftware,
			qLineBundleComponentSoftware,
			qLineParentBundleHardware,
			qLineBundleComponentHardware
		};
		Test.stopTest();
	}

	@IsTest
	static void billingDatesAndAmountsWithoutReverse() {
		Account act = [SELECT Id FROM Account LIMIT 1];
		Opportunity oppo = [SELECT Id FROM Opportunity LIMIT 1];
		Id pricebookId = Test.getStandardPricebookId();

		SBQQ__Quote__c qt1 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt1.SBQQ__StartDate__c = Date.today();
		qt1.SBQQ__EndDate__c = Date.today().addYears(1);
		qt1.No_of_Installments__c = 2;

		SBQQ__Quote__c qt2 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt2.SBQQ__StartDate__c = Date.today();
		qt2.SBQQ__EndDate__c = Date.today().addYears(2);
		qt2.First_Billing_Override__c = true;
		qt2.No_of_Installments__c = 1;

		SBQQ__Quote__c qt3 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt3.SBQQ__StartDate__c = Date.today();
		qt3.SBQQ__EndDate__c = Date.today().addYears(5);

		SBQQ__Quote__c qt4 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt4.SBQQ__StartDate__c = Date.today();
		qt4.SBQQ__EndDate__c = Date.today().addYears(10);

		insert new List<SBQQ__Quote__c>{ qt1, qt2, qt3, qt4 };

		Product2 pd1 = buildProduct('Product-123', false);
		Product2 pd2 = buildProduct('Product-124', true);
		insert new List<Product2>{ pd1, pd2 };

		Test.startTest();

		List<SBQQ__QuoteLine__c> listQuoteLines = new List<SBQQ__QuoteLine__c>();

		SBQQ__QuoteLine__c qLine1 = buildQuoteLineNew(pd1.Id, qt1.Id, false);
		listQuoteLines.add(qLine1);

		SBQQ__QuoteLine__c qLine2 = buildQuoteLineNew(pd2.Id, qt2.Id, false);
		listQuoteLines.add(qLine2);

		SBQQ__QuoteLine__c qLine3 = buildQuoteLineNew(pd2.Id, qt1.Id, false);
		listQuoteLines.add(qLine3);

		SBQQ__QuoteLine__c qLine4 = buildQuoteLineNew(pd1.Id, qt3.Id, false);
		qLine4.SBQQ__Bundle__c = true;
		qLine4.SBQQ__ComponentTotal__c = 1000;
		listQuoteLines.add(qLine4);

		SBQQ__QuoteLine__c qLine5 = buildQuoteLineNew(pd2.Id, qt4.Id, false);
		qLine5.Bundled_Product__c = true;
		qLine5.SBQQ__ComponentTotal__c = null;
		listQuoteLines.add(qLine5);

		insert listQuoteLines;
		Test.stopTest();
	}

	@IsTest
	static void billingDatesAndAmountsWithReverse() {
		Account act = [SELECT Id FROM Account LIMIT 1];
		Opportunity oppo = [SELECT Id FROM Opportunity LIMIT 1];
		Id pricebookId = Test.getStandardPricebookId();

		SBQQ__Quote__c qt1 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt1.SBQQ__StartDate__c = Date.today();
		qt1.SBQQ__EndDate__c = Date.today().addDays(60);
		qt1.No_of_Installments__c = 2;

		SBQQ__Quote__c qt2 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt2.First_Billing_Override__c = true;
		qt2.SBQQ__StartDate__c = Date.today();
		qt2.SBQQ__EndDate__c = Date.today().addDays(15);
		qt2.No_of_Installments__c = 1;

		SBQQ__Quote__c qt3 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt3.SBQQ__StartDate__c = Date.today();
		qt3.SBQQ__EndDate__c = Date.today().addYears(5);

		SBQQ__Quote__c qt4 = buildQuote(oppo.Id, pricebookId, act.Id);
		qt4.SBQQ__StartDate__c = Date.today();
		qt4.SBQQ__EndDate__c = Date.today().addYears(10);

		insert new List<SBQQ__Quote__c>{ qt1, qt2, qt3, qt4 };

		Product2 pd1 = buildProduct('Product-123', false);
		Product2 pd2 = buildProduct('Product-123', true);
		insert new List<Product2>{ pd1, pd2 };

		Test.startTest();

		List<SBQQ__QuoteLine__c> listQuoteLines = new List<SBQQ__QuoteLine__c>();

		SBQQ__QuoteLine__c qLine1 = buildQuoteLineNew(pd1.Id, qt1.Id, true);
		listQuoteLines.add(qLine1);

		SBQQ__QuoteLine__c qLine2 = buildQuoteLineNew(pd2.Id, qt2.Id, true);
		listQuoteLines.add(qLine2);

		SBQQ__QuoteLine__c qLine3 = buildQuoteLineNew(pd2.Id, qt1.Id, true);
		listQuoteLines.add(qLine3);

		SBQQ__QuoteLine__c qLine4 = buildQuoteLineNew(pd1.Id, qt3.Id, false);
		qLine4.SBQQ__Bundle__c = true;
		qLine4.SBQQ__ComponentTotal__c = 1000;
		listQuoteLines.add(qLine4);

		SBQQ__QuoteLine__c qLine5 = buildQuoteLineNew(pd2.Id, qt4.Id, false);
		qLine5.Bundled_Product__c = true;
		listQuoteLines.add(qLine5);

		insert listQuoteLines;
		Test.stopTest();
	}

	@IsTest
	static void beforeUpdate_WhenNonMSPProspectAccount_CannotQuoteMultipleSoftwareBundle_ShowsError() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler'
			}
		);

		String actualErrorMessage = '';
		PriceBook2 pricebook = [SELECT Id FROM PriceBook2 WHERE Name = 'Global Pricebook' LIMIT 1];
		SBQQ__Quote__c testQuote = new SBQQ__Quote__c();
		List<SBQQ__QuoteLine__c> listQuoteLines = new List<SBQQ__QuoteLine__c>();
		Product2 pd2 = new Product2();

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [SELECT Id, Type FROM Account LIMIT 1];
			acc.Type = 'Prospect';
			update acc;

			Opportunity opp = [SELECT Id, Name, Pricebook2Id FROM Opportunity LIMIT 1];
			opp.Pricebook2Id = pricebook.Id;
			update opp;

			testQuote = [
				SELECT Id, SBQQ__Account__c, SBQQ__PriceBook__c, SBQQ__PricebookId__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			testQuote.SBQQ__PriceBook__c = pricebook.Id;
			testQuote.SBQQ__PricebookId__c = pricebook.Id;
			testQuote.SBQQ__Account__c = acc.Id;
			update testQuote;

			pd2 = buildProduct('Product-2', true);
			pd2.Product_Group__c = 'Software';
			pd2.Product_Category__c = '';
			insert new List<Product2>{ pd2 };
		}

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			try {
				TriggerHandler.resetRecursionLimits();

				SBQQ__QuoteLine__c qLine2 = buildQuoteLineNew(pd2.Id, testQuote.Id, true);
				qLine2.Product_Group__c = 'Software';
				qLine2.SBQQ__Bundle__c = true;

				insert qLine2;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}
		System.assert(actualErrorMessage.contains(System.Label.Multiple_Software_Bundle_Error));
	}

	@IsTest
	static void beforeUpdate_WhenNonMSPProspectAccount_QuoteMultipleSoftwareBundleWithDex_DontShowsError() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler'
			}
		);

		String actualErrorMessage = '';
		PriceBook2 pricebook = [SELECT Id FROM PriceBook2 WHERE Name = 'Global Pricebook' LIMIT 1];
		SBQQ__Quote__c testQuote = new SBQQ__Quote__c();
		List<SBQQ__QuoteLine__c> listQuoteLines = new List<SBQQ__QuoteLine__c>();
		Product2 pd2 = new Product2();

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [SELECT Id, Type FROM Account LIMIT 1];
			acc.Type = 'Prospect';
			update acc;

			Opportunity opp = [SELECT Id, Name, Pricebook2Id FROM Opportunity LIMIT 1];
			opp.Pricebook2Id = pricebook.Id;
			update opp;

			testQuote = [
				SELECT Id, SBQQ__Account__c, SBQQ__PriceBook__c, SBQQ__PricebookId__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			testQuote.SBQQ__PriceBook__c = pricebook.Id;
			testQuote.SBQQ__PricebookId__c = pricebook.Id;
			testQuote.SBQQ__Account__c = acc.Id;
			update testQuote;

			pd2 = buildProduct('Product-2', true);
			pd2.Product_Group__c = 'Software';
			pd2.Product_Category__c = '';
			pd2.Digital_Employee_Experience_Bundle__c = true;
			insert new List<Product2>{ pd2 };
		}

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			try {
				TriggerHandler.resetRecursionLimits();

				SBQQ__QuoteLine__c qLine2 = buildQuoteLineNew(pd2.Id, testQuote.Id, true);
				qLine2.Product_Group__c = 'Software';
				qLine2.SBQQ__Bundle__c = true;

				insert qLine2;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}
		System.assert(!actualErrorMessage.contains(System.Label.Multiple_Software_Bundle_Error));
	}

	@IsTest
	static void beforeUpdate_WhenNonMSPNonProspectAccount_CanQuoteMultipleSoftwareBundle() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler'
			}
		);

		String actualErrorMessage = '';
		PriceBook2 pricebook = [SELECT Id FROM PriceBook2 WHERE Name = 'Global Pricebook' LIMIT 1];
		SBQQ__Quote__c testQuote = new SBQQ__Quote__c();
		List<SBQQ__QuoteLine__c> listQuoteLines = new List<SBQQ__QuoteLine__c>();
		Product2 pd2 = new Product2();

		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [SELECT Id, Name, Pricebook2Id, AccountId FROM Opportunity LIMIT 1];
			opp.Pricebook2Id = pricebook.Id;
			update opp;

			testQuote = [
				SELECT Id, SBQQ__Account__c, SBQQ__PriceBook__c, SBQQ__PricebookId__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			testQuote.SBQQ__Account__c = opp.AccountId;
			update testQuote;

			pd2 = buildProduct('Product-2', true);
			pd2.Product_Group__c = 'Software';
			pd2.Product_Category__c = '';
			insert new List<Product2>{ pd2 };
		}
		System.runAs(getStandardUser()) {
			Test.startTest();
			try {
				TriggerHandler.resetRecursionLimits();

				SBQQ__QuoteLine__c qLine2 = buildQuoteLineNew(pd2.Id, testQuote.Id, true);
				qLine2.Product_Group__c = 'Software';
				qLine2.SBQQ__Bundle__c = true;

				insert qLine2;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}
		List<SBQQ__QuoteLine__c> quoteLines = [
			SELECT Id
			FROM SBQQ__QuoteLine__c
			WHERE Product_Group__c = :QuoteLineTriggerHandler.SOFTWARE_PRODUCT_GROUP
		];
		System.assertEquals('', actualErrorMessage, 'No error should occur.');
		System.assertEquals(2, quoteLines.size(), 'Two software bundles should be created.');
	}

	@IsTest
	static void beforeUpdate_WhenMSPQuote_CanQuoteMultipleSoftwareBundle() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler'
			}
		);

		String actualErrorMessage = '';
		SBQQ__Quote__c testQuote = new SBQQ__Quote__c();
		List<SBQQ__QuoteLine__c> listQuoteLines = new List<SBQQ__QuoteLine__c>();
		Product2 pd2 = new Product2();

		System.runAs(TestUserFactory.getAdminUser()) {
			Account parentAccount = new Account(
				Name = 'Parent Account',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner'),
				NumberOfEmployees = 1,
				Active_Account__c = true
			);
			insert parentAccount;

			Opportunity opp = [
				SELECT Id, Name, Business_Motion__c, Pricebook2Id, AccountId
				FROM Opportunity
				LIMIT 1
			];
			opp.Business_Motion__c = 'MSP';
			opp.End_User_Account__c = opp.AccountId;
			update opp;

			testQuote = [
				SELECT Id, SBQQ__Account__c, SBQQ__PriceBook__c, SBQQ__PricebookId__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			testQuote.SBQQ__Account__c = opp.AccountId;
			testQuote.SBQQ__Partner__c = parentAccount.Id;
			update testQuote;

			pd2 = buildProduct('Product-2', true);
			pd2.Product_Group__c = 'Software';
			pd2.Product_Category__c = '';
			insert new List<Product2>{ pd2 };
		}

		System.runAs(getStandardUser()) {
			Test.startTest();
			try {
				TriggerHandler.resetRecursionLimits();

				SBQQ__QuoteLine__c qLine2 = buildQuoteLineNew(pd2.Id, testQuote.Id, true);
				qLine2.Product_Group__c = 'Software';
				qLine2.SBQQ__Bundle__c = true;

				insert qLine2;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}
		List<SBQQ__QuoteLine__c> quoteLines = [
			SELECT Id
			FROM SBQQ__QuoteLine__c
			WHERE Product_Group__c = :QuoteLineTriggerHandler.SOFTWARE_PRODUCT_GROUP
		];

		System.assertEquals('', actualErrorMessage, 'No error should occur.');
		System.assertEquals(2, quoteLines.size(), 'Two software bundles should be created.');
	}

	@IsTest
	static void testAfterUndelete() {
		SBQQ__QuoteLine__c quoteLine = [
			SELECT Id, SBQQ__Quote__r.SBQQ__PriceBook__c
			FROM SBQQ__QuoteLine__c
			LIMIT 1
		];
		delete quoteLine;
		Test.startTest();
		undelete quoteLine;
		Test.stopTest();
		List<SBQQ__QuoteLine__c> quoteLineTest = [
			SELECT Id
			FROM SBQQ__QuoteLine__c
			WHERE Id = :quoteLine.Id
		];
		System.assertEquals(true, !quoteLineTest.isEmpty(), 'QuoteLine should be recreated.');
	}

	@IsTest
	static void testGetDexBundleProductIds() {
		Product2[] products = [SELECT Id, Digital_Employee_Experience_Bundle__c FROM Product2];
		products[0].Digital_Employee_Experience_Bundle__c = true;

		Test.startTest();
		update products;
		Set<Id> dexProductIds = QuoteLineTriggerHandler.getDexBundleProductIds();
		Test.stopTest();

		Assert.isTrue(dexProductIds.size() > 0);
	}

	static Product2 buildProduct(String name, Boolean prorateBilling) {
		return new Product2(
			IsActive = true,
			Name = name,
			Description = 'test description',
			Product_Category__c = 'Hardware',
			Prorate_Billing__c = prorateBilling,
			SBQQ__SubscriptionPricing__c = 'Fixed Price'
		);
	}

	static SBQQ__Quote__c buildQuote(Id opportunityId, Id pricebookId, Id accountId) {
		return new SBQQ__Quote__c(
			SBQQ__StartDate__c = Date.today(),
			SBQQ__EndDate__c = Date.today().addDays(180),
			SBQQ__Opportunity2__c = opportunityId,
			SBQQ__PriceBook__c = pricebookId,
			SBQQ__Account__c = accountId,
			SBQQ__Status__c = 'Accepted',
			SBQQ__Type__c = 'Quote',
			PaymentTypeNew__c = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE,
			First_Billing_Override__c = false
		);
	}

	static list<SBQQ__QuoteLine__c> buildQuoteLines(Id quoteId, Id prodId) {
		list<SBQQ__QuoteLine__c> listQuoteLine = new List<SBQQ__QuoteLine__c>();

		SBQQ__QuoteLine__c quoteLine = buildQuoteLine(quoteId, prodId, 'Appliance');
		quoteLine.Promotion__c = 'Burst';
		quoteLine.LicenseMetric__c = 'Managed OS';
		quoteLine.Media_Type__c = 'Copper';
		quoteLine.PremiumSupport__c = true; //  for Premium_Product_Discounted__c
		quoteLine.SBQQ__Discount__c = 2;
		quoteLine.Promotion__c = 'Burst';
		listQuoteLine.add(quoteLine);
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'IR'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Core-LTD'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Onsite Support'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Foundation'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Asset'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Comply'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Discover'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'FIM'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'IOC Detect'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Patch'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Protect'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Security Suite'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Tanium Threat Response'));
		listQuoteLine.add(buildQuoteLine(quoteId, prodId, 'Trace'));
		return listQuoteLine;
	}

	static SBQQ__QuoteLine__c buildQuoteLine(Id quoteId, Id prodId, String productLine) {
		return new SBQQ__QuoteLine__c(
			SBQQ__Quote__c = quoteId,
			SBQQ__Product__c = prodId,
			SBQQ__Quantity__c = 4,
			Product_Line__c = productLine,
			SBQQ__Discount__c = 1
		);
	}

	static SBQQ__QuoteLine__c buildQuoteLineNew(Id productId, Id quoteId, Boolean reverseBilling) {
		return new SBQQ__QuoteLine__c(
			SBQQ__StartDate__c = Date.today(),
			SBQQ__Product__c = productId,
			SBQQ__Quantity__c = 10,
			SBQQ__NetPrice__c = 10,
			SBQQ__Quote__c = quoteId
		);
	}

	static User getStandardUser() {
		if (standardUser == null) {
			List<User> testUsers = [
				SELECT Id
				FROM User
				WHERE LastName = :TestUserFactory.TANIUM_STANDARD_USER
			];
			if (testUsers.isEmpty()) {
				standardUser = TestUserFactory.createTaniumStandardUser();
				insert standardUser;
				TestingUtility.assignPermissionSet(standardUser.Id, 'DisableFlows');
			} else {
				standardUser = testUsers[0];
			}
		}
		return standardUser;
	}
}