/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for BatchCreateBillingScheduleRecords
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13619   2026-08-18    Migrated to standard Quote/QuoteLineItem and deduplicated tests
 */
@isTest
private class BatchCreateBillingScheduleRecordsTest {
	private static User batchUser;
	private static String query = 'SELECT ' + 'Id ' + 'FROM Opportunity';
	private static final String FLAT_SKU_PRODUCT = 'Flat SKU Product';
	private static final String BUNDLE_PARENT_PRODUCT = 'Bundle Parent Hardware';
	private static final String ANNUAL_PAYMENT_TYPE = BillingScheduleService.ANNUAL_PAYMENT_TYPE;

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteLineTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();
		System.runAs(getBatchUser()) {
			TestFactory.seedRubySettings();

			Account account = TestFactory.buildAccount('Test Account 1');
			insert new List<Account>{ account };

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today() + 30,
				'Prospecting',
				account.Id
			);
			opportunity.CloseDate = Date.today();
			opportunity.BillingScheduleTotalAmountNew__c = 10;
			insert opportunity;

			Quote quote = TestFactory.buildQuote(
				'Test Quote 1',
				opportunity.Id,
				Date.newInstance(Date.today().year(), 1, 15),
				Date.newInstance(Date.today().year() + 3, 4, 15)
			);
			quote.ELV_PaymentTypeNew__c = 'Upfront';
			quote.Ruby__SellerTotalAmount__c = 10000;
			insert quote;

			opportunity.Ruby__PrimaryQuote__c = quote.Id;
			update opportunity;

			Product2 flatSKUProduct = new Product2(
				IsActive = true,
				Name = FLAT_SKU_PRODUCT,
				Description = 'test description',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = false,
				SBQQ__SubscriptionPricing__c = 'One-time'
			);

			Product2 bundleParentHardware = new Product2(
				IsActive = true,
				Name = BUNDLE_PARENT_PRODUCT,
				A_la_carte_Required_SKUs__c = true,
				Description = 'bundle parent description',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = true,
				Bundle_Component__c = 'myBundleComponentHardware',
				Bundle_List_Price__c = 4000,
				Ruby__ProductRecordType__c = 'Bundle'
			);

			Product2 myBundleComponentHardware = new Product2(
				IsActive = true,
				Name = 'myBundleComponentHardware',
				Description = 'bundle component description',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = true,
				Bundle_List_Price__c = 4000
			);

			insert new List<Product2>{ flatSKUProduct, bundleParentHardware, myBundleComponentHardware };

			List<PricebookEntry> pricebookEntries = new List<PricebookEntry>{
				TestFactory.buildPricebookEntry(flatSKUProduct.Id, 6000, Test.getStandardPricebookId()),
				TestFactory.buildPricebookEntry(bundleParentHardware.Id, 4000, Test.getStandardPricebookId()),
				TestFactory.buildPricebookEntry(
					myBundleComponentHardware.Id,
					4000,
					Test.getStandardPricebookId()
				)
			};
			insert pricebookEntries;
			PricebookEntry flatSKUProductPBE = pricebookEntries[0];
			PricebookEntry bundleParentHardwarePBE = pricebookEntries[1];
			PricebookEntry myBundleComponentHardwarePBE = pricebookEntries[2];

			QuoteLineItem quoteLineFlatSKU = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				6000,
				flatSKUProductPBE.Id
			);
			quoteLineFlatSKU.ELV_Bundled_Product__c = false;
			quoteLineFlatSKU.Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 1, 15);
			quoteLineFlatSKU.Ruby__SubscriptionEndDate__c = Date.newInstance(Date.today().year() + 3, 5, 15);
			quoteLineFlatSKU.Ruby__TotalAmount__c = 6000;

			QuoteLineItem quoteLineFlatSKUZeroNet = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				0,
				flatSKUProductPBE.Id
			);
			quoteLineFlatSKUZeroNet.ELV_Bundled_Product__c = false;
			quoteLineFlatSKUZeroNet.Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 1, 1);
			quoteLineFlatSKUZeroNet.Ruby__SubscriptionEndDate__c = Date.newInstance(
				Date.today().year() + 2,
				12,
				30
			);
			quoteLineFlatSKUZeroNet.Ruby__TotalAmount__c = 0;

			QuoteLineItem quoteLineParentBundleHardware = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				4000,
				bundleParentHardwarePBE.Id
			);
			quoteLineParentBundleHardware.ELV_Bundled_Product__c = false;
			quoteLineParentBundleHardware.Ruby__SubscriptionStartDate__c = Date.newInstance(
				Date.today().year(),
				1,
				15
			);
			quoteLineParentBundleHardware.Ruby__SubscriptionEndDate__c = Date.newInstance(
				Date.today().year() + 3,
				5,
				15
			);
			quoteLineParentBundleHardware.Ruby__TotalAmount__c = 4000;
			quoteLineParentBundleHardware.Ruby__TotalPrice__c = 4000;

			QuoteLineItem quoteLineBundleComponentHardware = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				4000,
				myBundleComponentHardwarePBE.Id
			);
			quoteLineBundleComponentHardware.ELV_Bundled_Product__c = true;
			quoteLineBundleComponentHardware.Ruby__SubscriptionStartDate__c = Date.newInstance(
				Date.today().year(),
				1,
				15
			);
			quoteLineBundleComponentHardware.Ruby__SubscriptionEndDate__c = Date.newInstance(
				Date.today().year() + 3,
				5,
				15
			);
			quoteLineBundleComponentHardware.Ruby__TotalAmount__c = 4000;

			insert new List<QuoteLineItem>{
				quoteLineFlatSKU,
				quoteLineFlatSKUZeroNet,
				quoteLineParentBundleHardware,
				quoteLineBundleComponentHardware
			};

			Billing_Schedule__c billing1 = TestFactory.buildBillingSchedule(opportunity.Id);
			billing1.Billing_Order__c = 1;
			billing1.Billing_Amount__c = 10.00;
			billing1.Billing_Date__c = System.today();
			billing1.Opportunity__c = opportunity.Id;
			billing1.ELV_Quote__c = quote.Id;

			insert new List<Billing_Schedule__c>{ billing1 };
			BillingByQuoteLine__c billingFlatSKU = new BillingByQuoteLine__c(
				BillAmount__c = 9.00,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = BillingScheduleService.UPFRONT_PAYMENT_TYPE
			);
			billingFlatSKU.BillingSchedule__c = billing1.Id;
			billingFlatSKU.Opportunity__c = opportunity.Id;
			billingFlatSKU.ELV_Quote__c = quote.Id;
			billingFlatSKU.ELV_QuoteLine__c = quoteLineFlatSKU.Id;
			billingFlatSKU.BillDate__c = opportunity.CloseDate;

			BillingByQuoteLine__c billingHardwareBundle = new BillingByQuoteLine__c(
				BillAmount__c = 1.00,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = BillingScheduleService.UPFRONT_PAYMENT_TYPE
			);
			billingHardwareBundle.BillingSchedule__c = billing1.Id;
			billingHardwareBundle.Opportunity__c = opportunity.Id;
			billingHardwareBundle.ELV_Quote__c = quote.Id;
			billingHardwareBundle.ELV_QuoteLine__c = quoteLineParentBundleHardware.Id;
			billingHardwareBundle.BillDate__c = opportunity.CloseDate;

			insert new List<BillingByQuoteLine__c>{ billingFlatSKU, billingHardwareBundle };
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForUpfront_billingsAreCreated() {
		List<Billing_Schedule__c> oldBillings = [SELECT Id FROM Billing_Schedule__c];
		System.assertEquals(true, oldBillings.size() > 0, 'Old billings exist');

		List<BillingByQuoteLine__c> oldBillingsByQuoteLines = [SELECT Id FROM BillingByQuoteLine__c];
		System.assertEquals(
			true,
			oldBillingsByQuoteLines.size() > 0,
			'Old billings by quote lines exist'
		);

		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];

		System.runAs(getBatchUser()) {
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
		}

		oldBillings = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :oldBillings];
		System.assertEquals(0, oldBillings.size(), 'old billings deleted by batch');

		oldBillingsByQuoteLines = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE ID IN :oldBillingsByQuoteLines
		];
		System.assertEquals(
			0,
			oldBillingsByQuoteLines.size(),
			'old billings by quote lines deleted by batch'
		);

		List<Billing_Schedule__c> newBillings = [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				isReverseBilling__c,
				Opportunity__r.CloseDate,
				PaymentType__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opportunity.Id
		];
		System.assertEquals(1, newBillings.size(), 'single upfront payment type');
		for (Billing_Schedule__c eachBilling : newBillings) {
			System.assertEquals(10000, eachBilling.Billing_Amount__c, '6000+4000');
			System.assertEquals(
				eachBilling.Opportunity__r.CloseDate,
				eachBilling.Billing_Date__c,
				'Bill Date aligned with Opportunity Close Date'
			);
			System.assertEquals(false, eachBilling.isReverseBilling__c, 'reverse is false');
			System.assertEquals(
				BillingScheduleService.UPFRONT_PAYMENT_TYPE,
				eachBilling.PaymentType__c,
				'single upfront payment type'
			);
			System.assertEquals(
				eachBilling.PaymentType__c,
				eachBilling.ELV_Quote__r.ELV_PaymentTypeNew__c,
				'payment type copied from billing to quote'
			);
			System.assertEquals(
				eachBilling.isReverseBilling__c,
				eachBilling.ELV_Quote__r.ELV_isReverseBilling__c,
				'reverse billing copied from billing to quote'
			);
			System.assertNotEquals(
				null,
				eachBilling.ELV_Quote__r.ELV_BillingQuoteTerms__c,
				'billing quote terms are generated based off billing schedules data'
			);
		}
		List<BillingByQuoteLine__c> billingByQuoteLines = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE Opportunity__c = :opportunity.Id
		];

		System.assertEquals(
			2,
			billingByQuoteLines.size(),
			'should equal to the number of quotelines that are not bundled components nor have NetTotal zero on flat SKUs'
		);
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualNoReverseWithExistingBillings_billingsAreReCreated() {
		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];
		List<Billing_Schedule__c> oldBillings = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opportunity.Id
		];
		System.assertEquals(true, oldBillings.size() > 0);
		QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();
		Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
		System.assertEquals(40, noOfMonths.intValue());
		Decimal installmentPerMonth = quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths;
		System.assertEquals(100, installmentPerMonth.round());

		Decimal annualPayment = 12 * installmentPerMonth;
		System.assertEquals(1199, annualPayment.round());
		Decimal residuePayment =
			quoteLineBundleParent.ELV_PackageTotal__c - (12 * installmentPerMonth * 3);
		System.assertEquals(402.70, residuePayment.setScale(2));

		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			Quote quote = setQuoteToAnnualNonReverseBilling(opportunity.Id);
			List<BillingByQuoteLine__c> existingBillings = new List<BillingByQuoteLine__c>(
				[SELECT isReverseBilling__c, PaymentType__c FROM BillingByQuoteLine__c]
			);
			for (BillingByQuoteLine__c eachBilling : existingBillings) {
				eachBilling.PaymentType__c = ANNUAL_PAYMENT_TYPE;
				eachBilling.isReverseBilling__c = false;
			}
			update existingBillings;
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
		}
		oldBillings = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :oldBillings];
		System.assertEquals(0, oldBillings.size(), 'old billings are deleted by batch');

		List<Billing_Schedule__c> newBillings = [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				isReverseBilling__c,
				Opportunity__r.CloseDate,
				PaymentType__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c,
				ELV_Quote__r.Ruby__SubscriptionStartDate__c,
				(
					SELECT
						Id,
						ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
						ELV_QuoteLine__r.ELV_Term_Computed__c
					FROM BillingsByQuoteLines__r
				)
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opportunity.Id
		];
		System.assertEquals(4, newBillings.size(), 'Annual Installments payment type');
		for (Billing_Schedule__c eachBilling : newBillings) {
			System.assertEquals(
				BillingScheduleService.ANNUAL_PAYMENT_TYPE,
				eachBilling.PaymentType__c,
				'annual payment type billed in 4 billing schedules'
			);
			System.assertEquals(false, eachBilling.isReverseBilling__c, 'reverse is false');
			System.assertEquals(
				eachBilling.PaymentType__c,
				eachBilling.ELV_Quote__r.ELV_PaymentTypeNew__c,
				'payment type copied from billing to quote'
			);
			System.assertEquals(
				eachBilling.isReverseBilling__c,
				eachBilling.ELV_Quote__r.ELV_isReverseBilling__c,
				'reverse billing copied from billing to quote'
			);
			System.assertNotEquals(
				null,
				eachBilling.ELV_Quote__r.ELV_BillingQuoteTerms__c,
				'billing quote terms are generated based off billing schedules data'
			);

			switch on String.valueOf(eachBilling.Billing_Order__c) {
				when '1' {
					System.assertEquals(
						eachBilling.ELV_Quote__r.Ruby__SubscriptionStartDate__c,
						eachBilling.Billing_Date__c,
						'trigger updates 1st billing BillDate to opp close date'
					);
					System.assertEquals(
						2,
						eachBilling.BillingsByQuoteLines__r.size(),
						'6000 + annual payment of bundle product'
					);
					System.assertEquals(
						7199.10,
						eachBilling.Billing_Amount__c,
						'6000 (non-prorated product; billed upfront) + 1200 (pro-rated; billed annually)'
					);
				}
				when '2' {
					System.assertEquals(
						1199.10,
						eachBilling.Billing_Amount__c,
						'1199.10 from bundle parent hardware'
					);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addYears(1),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'$1170.73 from parent bundle hardware'
					);
				}
				when '3' {
					System.assertEquals(
						1199.10,
						eachBilling.Billing_Amount__c,
						'from bundle parent hardware'
					);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addYears(2),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'1170.73 from parent bundle hardware'
					);
				}
				when '4' {
					System.assertEquals(402.70, eachBilling.Billing_Amount__c, 'balance payment');
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addYears(3),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(1, eachBilling.BillingsByQuoteLines__r.size(), 'balance payment');
				}
			}
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualNonReverseWithNoExistingBillings_billingsAreCreated() {
		List<PermissionSetAssignment> psa = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = 'DisableFlows'
		];
		if (psa.isEmpty()) {
			TestingUtility.assignPermissionSet(UserInfo.getUserId(), 'DisableFlows');
		}

		Opportunity opportunity = new Opportunity();
		List<Billing_Schedule__c> oldBillings;
		QuoteLineItem quoteLineBundleParent = new QuoteLineItem();

		System.runAs(new User(Id = UserInfo.getUserId())) {
			opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];
			Quote quote = setQuoteToAnnualNonReverseBilling(opportunity.Id);
			quoteLineBundleParent = getBundleParentQuoteLine();
			Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
			System.assertEquals(40, noOfMonths.intValue());
			Decimal installmentPerMonth = quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths;
			System.assertEquals(100, installmentPerMonth.round());

			Decimal annualPayment = 12 * installmentPerMonth;
			System.assertEquals(1199, annualPayment.round());
			Decimal residuePayment =
				quoteLineBundleParent.ELV_PackageTotal__c - (12 * installmentPerMonth * 3);
			System.assertEquals(402.70, residuePayment.setScale(2));
		}

		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			oldBillings = [SELECT Id FROM Billing_Schedule__c];
			delete oldBillings;
			List<BillingByQuoteLine__c> oldBillingsByQuoteLines = [SELECT Id FROM BillingByQuoteLine__c];
			delete oldBillingsByQuoteLines;
			Quote quoteToRebill = [SELECT Id FROM Quote WHERE OpportunityId = :opportunity.Id];
			quoteToRebill.Ruby__SellerTotalAmount__c = 10000;
			update quoteToRebill;
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
		}
		oldBillings = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :oldBillings];
		System.assertEquals(0, oldBillings.size(), 'old billings are deleted by batch');

		List<Billing_Schedule__c> newBillings = [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				isReverseBilling__c,
				Opportunity__r.CloseDate,
				PaymentType__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c,
				ELV_Quote__r.Ruby__SubscriptionStartDate__c,
				(
					SELECT
						Id,
						ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
						ELV_QuoteLine__r.ELV_Term_Computed__c
					FROM BillingsByQuoteLines__r
				)
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opportunity.Id
		];
		System.assertEquals(4, newBillings.size(), 'Annual Installments payment type');
		List<BillingByQuoteLine__c> billingByQuoteLines = [
			SELECT
				Id,
				BillAmount__c,
				BillDate__c,
				BillingScheduleOrder__c,
				ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
				ELV_QuoteLine__r.Ruby__TotalAmount__c,
				ELV_QuoteLine__r.Product2.Name
			FROM BillingByQuoteLine__c
			WHERE Opportunity__c = :opportunity.Id
		];
		for (BillingByQuoteLine__c eachBillingByQuoteLine : billingByQuoteLines) {
			if (eachBillingByQuoteLine.ELV_QuoteLine__r.Product2.Name == FLAT_SKU_PRODUCT) {
				System.assertEquals(
					eachBillingByQuoteLine.BillAmount__c,
					eachBillingByQuoteLine.ELV_QuoteLine__r.Ruby__TotalAmount__c
				);
				System.assertEquals(
					eachBillingByQuoteLine.BillDate__c,
					eachBillingByQuoteLine.ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c
				);
			} else if (
				eachBillingByQuoteLine.ELV_QuoteLine__r.Product2.Name == BUNDLE_PARENT_PRODUCT &&
				(eachBillingByQuoteLine.BillingScheduleOrder__c == '1' ||
				eachBillingByQuoteLine.BillingScheduleOrder__c == '2' ||
				eachBillingByQuoteLine.BillingScheduleOrder__c == '3')
			) {
				System.assertEquals(1199.10, eachBillingByQuoteLine.BillAmount__c, 'annual payment');
				if (eachBillingByQuoteLine.BillingScheduleOrder__c == '1') {
					System.assertEquals(
						eachBillingByQuoteLine.ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
						eachBillingByQuoteLine.BillDate__c,
						'Bill date aligned with start date'
					);
				} else {
					System.assertEquals(
						eachBillingByQuoteLine.BillDate__c,
						eachBillingByQuoteLine.ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c.addYears(
							Integer.valueOf(eachBillingByQuoteLine.BillingScheduleOrder__c) - 1
						),
						'Bill date aligned with start date'
					);
				}
			} else if (
				eachBillingByQuoteLine.ELV_QuoteLine__r.Product2.Name == BUNDLE_PARENT_PRODUCT &&
				eachBillingByQuoteLine.BillingScheduleOrder__c == '4'
			) {
				System.assertEquals(402.70, eachBillingByQuoteLine.BillAmount__c, 'residue payment');
				System.assertEquals(
					eachBillingByQuoteLine.BillDate__c,
					eachBillingByQuoteLine.ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c.addYears(
						Integer.valueOf(eachBillingByQuoteLine.BillingScheduleOrder__c) - 1
					),
					'Bill date aligned with start date'
				);
			}
		}
		for (Billing_Schedule__c eachBilling : newBillings) {
			System.assertEquals(
				BillingScheduleService.ANNUAL_PAYMENT_TYPE,
				eachBilling.PaymentType__c,
				'annual payment type billed in 4 billing schedules'
			);
			System.assertEquals(false, eachBilling.isReverseBilling__c, 'reverse is false');
			System.assertEquals(
				eachBilling.PaymentType__c,
				eachBilling.ELV_Quote__r.ELV_PaymentTypeNew__c,
				'payment type copied from billing to quote'
			);
			System.assertEquals(
				eachBilling.isReverseBilling__c,
				eachBilling.ELV_Quote__r.ELV_isReverseBilling__c,
				'reverse billing copied from billing to quote'
			);
			System.assertNotEquals(
				null,
				eachBilling.ELV_Quote__r.ELV_BillingQuoteTerms__c,
				'billing quote terms are generated based off billing schedules data'
			);

			switch on String.valueOf(eachBilling.Billing_Order__c) {
				when '1' {
					System.assertEquals(
						eachBilling.ELV_Quote__r.Ruby__SubscriptionStartDate__c,
						eachBilling.Billing_Date__c,
						'trigger updates 1st billing BillDate to opp close date'
					);
					System.assertEquals(
						2,
						eachBilling.BillingsByQuoteLines__r.size(),
						'6000 + annual payment of bundle product'
					);
					System.assertEquals(
						7199.10,
						eachBilling.Billing_Amount__c,
						'6000 (non-prorated product; billed upfront) + 1170.73 (pro-rated; billed annually)'
					);
				}
				when '2' {
					System.assertEquals(
						1199.10,
						eachBilling.Billing_Amount__c,
						'from bundle parent hardware'
					);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addYears(1),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'$from parent bundle hardware'
					);
				}
				when '3' {
					System.assertEquals(
						1199.10,
						eachBilling.Billing_Amount__c,
						'from bundle parent hardware'
					);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addYears(2),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'1170.73 from parent bundle hardware'
					);
				}
				when '4' {
					System.assertEquals(402.70, eachBilling.Billing_Amount__c, 'balance payment');
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addYears(3),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(1, eachBilling.BillingsByQuoteLines__r.size(), 'balance payment');
				}
			}
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualNonReverseWithExistingBillings_billingsAreCreated() {
		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];
		QuoteLineItem quoteLineForBundle = [
			SELECT Ruby__SubscriptionStartDate__c, ELV_Term_Computed__c
			FROM QuoteLineItem
			WHERE Product2.Name = :BUNDLE_PARENT_PRODUCT
		];

		List<BillingByQuoteLine__c> existingBillings;
		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			for (Quote quote : [
				SELECT Id, ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
				FROM Quote
				WHERE OpportunityId = :opportunity.Id
			]) {
				quote.ELV_PaymentTypeNew__c = BillingScheduleService.ANNUAL_PAYMENT_TYPE;
				quote.ELV_isReverseBilling__c = false;
				update quote;
			}
			existingBillings = [SELECT PaymentType__c, isReverseBilling__c FROM BillingByQuoteLine__c];
			for (BillingByQuoteLine__c eachBilling : existingBillings) {
				eachBilling.PaymentType__c = BillingScheduleService.ANNUAL_PAYMENT_TYPE;
				eachBilling.isReverseBilling__c = false;
			}
			update existingBillings;
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
		}
		existingBillings = [SELECT Id FROM BillingByQuoteLine__c WHERE Id IN :existingBillings];
		System.assertEquals(0, existingBillings.size());

		List<Billing_Schedule__c> newBillings = [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				isReverseBilling__c,
				Opportunity__r.CloseDate,
				PaymentType__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c,
				ELV_Quote__r.Ruby__SubscriptionStartDate__c,
				(
					SELECT
						Id,
						ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
						ELV_QuoteLine__r.ELV_Term_Computed__c
					FROM BillingsByQuoteLines__r
				)
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opportunity.Id
		];
		System.assertEquals(4, newBillings.size(), 'Annual Installments payment type');
		for (Billing_Schedule__c eachBilling : newBillings) {
			System.assertEquals(false, eachBilling.isReverseBilling__c, 'reverse is false');
			System.assertEquals(
				BillingScheduleService.ANNUAL_PAYMENT_TYPE,
				eachBilling.PaymentType__c,
				'annual payment type billed in 4 billing schedules'
			);
			System.assertEquals(
				eachBilling.PaymentType__c,
				eachBilling.ELV_Quote__r.ELV_PaymentTypeNew__c,
				'payment type copied from billing to quote'
			);
			System.assertEquals(
				eachBilling.isReverseBilling__c,
				eachBilling.ELV_Quote__r.ELV_isReverseBilling__c,
				'reverse billing copied from billing to quote'
			);
			System.assertNotEquals(
				null,
				eachBilling.ELV_Quote__r.ELV_BillingQuoteTerms__c,
				'billing quote terms are generated based off billing schedules data'
			);

			switch on String.valueOf(eachBilling.Billing_Order__c) {
				when '1' {
					System.assertEquals(
						7199.10,
						eachBilling.Billing_Amount__c,
						'6000 (non-prorated product; billed upfront)+1200 (pro-rated; billed annually)'
					);
					System.assertEquals(
						eachBilling.ELV_Quote__r.Ruby__SubscriptionStartDate__c,
						eachBilling.Billing_Date__c,
						'trigger updates 1st billing BillDate to opp close date'
					);
					System.assertEquals(2, eachBilling.BillingsByQuoteLines__r.size(), '6000 + 1200');
				}
				when '2' {
					System.assertEquals(
						1199.10,
						eachBilling.Billing_Amount__c,
						'1199.10 from bundle parent hardware'
					);
					System.assertEquals(
						quoteLineForBundle.Ruby__SubscriptionStartDate__c.addYears(1),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'1170.73 from bundle parent hardware'
					);
				}
				when '3' {
					System.assertEquals(
						1199.10,
						eachBilling.Billing_Amount__c,
						'from bundle parent hardware'
					);
					System.assertEquals(
						quoteLineForBundle.Ruby__SubscriptionStartDate__c.addYears(2),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'1170.73 from bundle parent hardware'
					);
				}
				when '4' {
					System.assertEquals(402.70, eachBilling.Billing_Amount__c, 'balance payment');
					System.assertEquals(
						quoteLineForBundle.Ruby__SubscriptionStartDate__c.addYears(3),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'balance for bundle parent hardware'
					);
				}
			}
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualReverseWithNoExistingBillingsAnd2PaymentsSameYear_billingsAreCreated() {
		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];
		QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();
		Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
		System.assertEquals(40, noOfMonths.intValue());
		Decimal installmentPerMonth = quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths;
		System.assertEquals(100, installmentPerMonth.round());

		Decimal annualPayment = 12 * installmentPerMonth;
		System.assertEquals(1199, annualPayment.round());
		Decimal residuePayment =
			quoteLineBundleParent.ELV_PackageTotal__c - (12 * installmentPerMonth * 3);
		System.assertEquals(402.70, residuePayment.setScale(2));
		List<Billing_Schedule__c> oldBillings;

		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			oldBillings = [SELECT Id FROM Billing_Schedule__c];
			delete oldBillings;
			List<BillingByQuoteLine__c> oldBillingsByQL = [SELECT Id FROM BillingByQuoteLine__c];
			delete oldBillingsByQL;
			Quote quote = setQuoteToAnnualReverseBilling(opportunity.Id);
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
		}

		oldBillings = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :oldBillings];
		System.assertEquals(0, oldBillings.size(), 'old billings are deleted by batch');

		List<Billing_Schedule__c> newBillings = [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				isReverseBilling__c,
				Opportunity__r.CloseDate,
				PaymentType__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c,
				ELV_Quote__r.Ruby__SubscriptionStartDate__c,
				(
					SELECT
						Id,
						ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
						ELV_QuoteLine__r.ELV_Term_Computed__c
					FROM BillingsByQuoteLines__r
				)
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opportunity.Id
		];
		System.assertEquals(4, newBillings.size(), 'Annual Installments payment type');
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualReverseWithNoExistingBillingsAndZeroResiduePayment_billingsAreCreated() {
		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];

		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			opportunity.CloseDate = Date.newInstance(Date.today().year(), 1, 14);
			update opportunity;
			List<Billing_Schedule__c> oldBillings = [SELECT Id FROM Billing_Schedule__c];
			delete oldBillings;
			Quote quote = setQuoteToAnnualReverseBilling(opportunity.Id);
			List<QuoteLineItem> existingQuoteLines = [
				SELECT Ruby__SubscriptionEndDate__c, ELV_Term_Computed__c
				FROM QuoteLineItem
				WHERE QuoteId = :quote.Id
			];
			for (QuoteLineItem eachQuoteLine : existingQuoteLines) {
				eachQuoteLine.Ruby__SubscriptionEndDate__c = Date.newInstance(Date.today().year() + 4, 1, 14);
			}
			update existingQuoteLines;

			QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();

			Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
			System.assertEquals(48, noOfMonths);
			Decimal annualPayment = quoteLineBundleParent.ELV_PackageTotal__c / 4;
			Decimal residuePayment = 0;
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
			oldBillings = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :oldBillings];
			System.assertEquals(0, oldBillings.size(), 'old billings are deleted by batch');

			List<Billing_Schedule__c> newBillings = [
				SELECT
					Id,
					Billing_Amount__c,
					Billing_Date__c,
					Billing_Order__c,
					isReverseBilling__c,
					Opportunity__r.CloseDate,
					PaymentType__c,
					(
						SELECT
							Id,
							ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
							ELV_QuoteLine__r.ELV_Term_Computed__c
						FROM BillingsByQuoteLines__r
					)
				FROM Billing_Schedule__c
				WHERE Opportunity__c = :opportunity.Id
			];
			System.assertEquals(4, newBillings.size(), 'Annual Installments payment type at opp level');
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualReverseWithExistingBillingsAndZeroResiduePayment_billingsAreReCreated() {
		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];

		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			opportunity.CloseDate = Date.newInstance(Date.today().year(), 1, 14);
			update opportunity;
			List<Billing_Schedule__c> oldBillings = [SELECT Id FROM Billing_Schedule__c];
			System.assertEquals(true, oldBillings.size() > 0);
			Quote quote = [
				SELECT ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
				FROM Quote
				WHERE OpportunityId = :opportunity.Id
			];
			quote.ELV_PaymentTypeNew__c = 'Upfront';
			quote.ELV_PaymentTypeNew__c = 'Annual Installment';
			quote.ELV_isReverseBilling__c = true;
			update quote;
			List<BillingByQuoteLine__c> existingBillings = [
				SELECT PaymentType__c, isReverseBilling__c
				FROM BillingByQuoteLine__c
			];
			for (BillingByQuoteLine__c eachBilling : existingBillings) {
				eachBilling.PaymentType__c = ANNUAL_PAYMENT_TYPE;
				eachBilling.isReverseBilling__c = true;
			}
			update existingBillings;
			List<QuoteLineItem> existingQuoteLines = [
				SELECT Ruby__SubscriptionEndDate__c, ELV_Term_Computed__c
				FROM QuoteLineItem
				WHERE QuoteId = :quote.Id
			];
			for (QuoteLineItem eachQuoteLine : existingQuoteLines) {
				eachQuoteLine.Ruby__SubscriptionEndDate__c = Date.newInstance(Date.today().year() + 4, 1, 14);
			}
			update existingQuoteLines;

			QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();

			Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
			System.assertEquals(48, noOfMonths);
			Decimal annualPayment = quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths;
			Decimal residuePayment = 0;
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
			oldBillings = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :oldBillings];
			System.assertEquals(0, oldBillings.size(), 'old billings are deleted by batch');

			List<Billing_Schedule__c> newBillings = [
				SELECT
					Id,
					Billing_Amount__c,
					Billing_Date__c,
					Billing_Order__c,
					isReverseBilling__c,
					Opportunity__r.CloseDate,
					PaymentType__c,
					ELV_Quote__r.ELV_BillingQuoteTerms__c,
					ELV_Quote__r.ELV_isReverseBilling__c,
					ELV_Quote__r.ELV_PaymentTypeNew__c,
					(
						SELECT
							Id,
							ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
							ELV_QuoteLine__r.ELV_Term_Computed__c
						FROM BillingsByQuoteLines__r
					)
				FROM Billing_Schedule__c
				WHERE Opportunity__c = :opportunity.Id
			];
			System.assertEquals(4, newBillings.size(), 'Annual Installments payment type at opp level');
			Date billDate2, billDate3, billDate4;

			for (Billing_Schedule__c eachBilling : newBillings) {
				System.assertEquals(
					BillingScheduleService.ANNUAL_PAYMENT_TYPE,
					eachBilling.PaymentType__c,
					'annual payment type billed in 4 billing schedules'
				);
				System.assertEquals(true, eachBilling.isReverseBilling__c, 'reverse is true');
				System.assertEquals(
					eachBilling.PaymentType__c,
					eachBilling.ELV_Quote__r.ELV_PaymentTypeNew__c,
					'payment type copied from billing to quote'
				);
				System.assertEquals(
					eachBilling.isReverseBilling__c,
					eachBilling.ELV_Quote__r.ELV_isReverseBilling__c,
					'reverse billing copied from billing to quote'
				);
				System.assertNotEquals(
					null,
					eachBilling.ELV_Quote__r.ELV_BillingQuoteTerms__c,
					'billing quote terms are generated based off billing schedules data'
				);
				switch on String.valueOf(eachBilling.Billing_Order__c) {
					when '1' {
						System.assertEquals(
							quoteLineBundleParent.Ruby__SubscriptionStartDate__c,
							eachBilling.Billing_Date__c,
							'trigger updates 1st billing BillDate to opp close date'
						);
						System.assertEquals(
							2,
							eachBilling.BillingsByQuoteLines__r.size(),
							'6000 + annual payment of bundle product'
						);
						System.assertEquals(
							7000.00,
							eachBilling.Billing_Amount__c,
							'6045.31 (non-prorated product; billed upfront)'
						);
					}
					when '2' {
						System.assertEquals(
							1000,
							eachBilling.Billing_Amount__c,
							'1000 from bundle parent hardware'
						);
						billDate2 = Date.newInstance(
							quoteLineBundleParent.Ruby__SubscriptionStartDate__c.year() + 1,
							quoteLineBundleParent.Ruby__SubscriptionEndDate__c.month(),
							quoteLineBundleParent.Ruby__SubscriptionEndDate__c.day()
						);
						billDate2 = billdate2.addDays(1);
						System.assertEquals(
							billdate2,
							eachBilling.Billing_Date__c,
							'Bill Date aligned with quote line end date + 1 day'
						);
						System.assertEquals(
							1,
							eachBilling.BillingsByQuoteLines__r.size(),
							'$1000 from parent bundle hardware'
						);
					}
					when '3' {
						System.assertEquals(
							1000,
							eachBilling.Billing_Amount__c,
							'1000 from bundle parent hardware'
						);
						billDate3 = billDate2.addYears(1);
						System.assertEquals(
							billDate3,
							eachBilling.Billing_Date__c,
							'Bill Date aligned with quote line end date + 1 day'
						);
						System.assertEquals(
							1,
							eachBilling.BillingsByQuoteLines__r.size(),
							'1000 from parent bundle hardware'
						);
					}
					when '4' {
						System.assertEquals(
							1000,
							eachBilling.Billing_Amount__c,
							'1000 from bundle parent hardware'
						);
						billDate4 = billDate3.addYears(1);
						System.assertEquals(
							billDate4,
							eachBilling.Billing_Date__c,
							'Bill Date aligned with prior bill date'
						);
						System.assertEquals(
							1,
							eachBilling.BillingsByQuoteLines__r.size(),
							'1000 from parent bundle hardware'
						);
					}
				}
			}
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualReverseWithNoExistingBillingsAndResiduePayment_billingsAreCreated() {
		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];

		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			opportunity.CloseDate = Date.newInstance(Date.today().year(), 6, 15);
			update opportunity;
			List<Billing_Schedule__c> oldBillings = [SELECT Id FROM Billing_Schedule__c];
			delete oldBillings;
			Quote quote = setQuoteToAnnualReverseBilling(opportunity.Id);
			List<QuoteLineItem> existingQuoteLines = [
				SELECT Ruby__SubscriptionEndDate__c, ELV_Term_Computed__c
				FROM QuoteLineItem
				WHERE QuoteId = :quote.Id
			];
			for (QuoteLineItem eachQuoteLine : existingQuoteLines) {
				eachQuoteLine.Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 6, 15);
				eachQuoteLine.Ruby__SubscriptionEndDate__c = Date.newInstance(Date.today().year() + 3, 2, 15);
			}
			update existingQuoteLines;

			QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();
			Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
			System.assertEquals(32, noOfMonths.intValue());
			Decimal installmentPerMonth = (quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths);
			Decimal annualPayment = 12 * installmentPerMonth;
			Decimal residuePayment =
				quoteLineBundleParent.ELV_PackageTotal__c - (12 * installmentPerMonth * 2);
			System.assertNotEquals(0, residuePayment);
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
			oldBillings = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :oldBillings];
			System.assertEquals(0, oldBillings.size(), 'old billings are deleted by batch');

			List<Billing_Schedule__c> newBillings = [
				SELECT
					Id,
					Billing_Amount__c,
					Billing_Date__c,
					Billing_Order__c,
					isReverseBilling__c,
					Opportunity__r.CloseDate,
					PaymentType__c,
					(
						SELECT
							Id,
							ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
							ELV_QuoteLine__r.ELV_Term_Computed__c
						FROM BillingsByQuoteLines__r
					)
				FROM Billing_Schedule__c
				WHERE Opportunity__c = :opportunity.Id
			];
			System.assertEquals(3, newBillings.size(), 'Annual Installments payment type');
			List<BillingByQuoteLine__c> billingByQuoteLines = [
				SELECT
					Id,
					BillAmount__c,
					BillDate__c,
					BillingScheduleOrder__c,
					ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
					ELV_QuoteLine__r.Ruby__SubscriptionEndDate__c,
					ELV_QuoteLine__r.Ruby__TotalAmount__c,
					ELV_QuoteLine__r.ELV_PackageTotal__c,
					ELV_QuoteLine__r.Product2.Name
				FROM BillingByQuoteLine__c
				WHERE Opportunity__c = :opportunity.Id AND ELV_QuoteLine__c = :quoteLineBundleParent.Id
			];
			System.assertEquals(3, billingByQuoteLines.size(), 'Annual Installments payment type');
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForAnnualReverseAndFirstBillingOverride_billingsAreCreated() {
		TriggerHandler.resetRecursionLimits();
		List<BillingByQuoteLine__c> existingBillings = new List<BillingByQuoteLine__c>();
		List<QuoteLineItem> existingQuoteLines = new List<QuoteLineItem>();

		System.runAs(getBatchUser()) {
			Product2 flatSKUProduct = [SELECT Id FROM Product2 WHERE Name = :BUNDLE_PARENT_PRODUCT];
			PricebookEntry flatSKUProductPBE = [
				SELECT Id
				FROM PricebookEntry
				WHERE Product2Id = :flatSKUProduct.Id AND Pricebook2Id = :Test.getStandardPricebookId()
			];
			Date earliestEstimatedBillDate = Date.newInstance(Date.today().year(), 2, 1);

			Quote quote1 = [
				SELECT
					Id,
					ELV_isReverseBilling__c,
					ELV_First_Billing_Override__c,
					OpportunityId,
					Ruby__IsPrimaryQuote__c
				FROM Quote
				LIMIT 1
			];
			quote1.Ruby__IsPrimaryQuote__c = false;

			Quote quote2 = new Quote(
				Name = 'Test Quote First Billing Override',
				Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 2, 1),
				OpportunityId = quote1.OpportunityId,
				Pricebook2Id = Test.getStandardPricebookId(),
				ELV_Type__c = 'Quote',
				ELV_PaymentTypeNew__c = ANNUAL_PAYMENT_TYPE,
				Ruby__IsPrimaryQuote__c = true,
				ELV_isReverseBilling__c = false,
				ELV_First_Billing_Override__c = true
			);
			upsert new List<Quote>{ quote2, quote1 };

			TriggerHandler.resetRecursionLimits();
			QuoteLineItem quoteLineNoDiscount = TestFactory.buildQuoteLineItem(
				quote2.Id,
				1,
				5000,
				flatSKUProductPBE.Id
			);
			quoteLineNoDiscount.Ruby__SubscriptionTerm__c = 24;
			quoteLineNoDiscount.Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 2, 1);
			quoteLineNoDiscount.Ruby__TotalAmount__c = 5000;
			quoteLineNoDiscount.Ruby__TotalPrice__c = 5000;

			QuoteLineItem quoteLine100Discount = TestFactory.buildQuoteLineItem(
				quote2.Id,
				1,
				2000,
				flatSKUProductPBE.Id
			);
			quoteLine100Discount.Ruby__SubscriptionTerm__c = 3;
			quoteLine100Discount.Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 2, 1);
			quoteLine100Discount.Ruby__TotalAmount__c = 0;
			quoteLine100Discount.Ruby__TotalPrice__c = 0;

			QuoteLineItem quoteLine21Months = TestFactory.buildQuoteLineItem(
				quote2.Id,
				1,
				4000,
				flatSKUProductPBE.Id
			);
			quoteLine21Months.Ruby__SubscriptionTerm__c = 21;
			quoteLine21Months.Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 5, 1);
			quoteLine21Months.Ruby__TotalAmount__c = 4000;
			quoteLine21Months.Ruby__TotalPrice__c = 4000;
			insert new List<QuoteLineItem>{ quoteLineNoDiscount, quoteLine100Discount, quoteLine21Months };

			existingQuoteLines = [
				SELECT Id, Ruby__SubscriptionTerm__c, UnitPrice
				FROM QuoteLineItem
				WHERE QuoteId = :quote2.Id
			];

			quote1.Ruby__SellerTotalAmount__c = 10000;
			update quote1;
			quote2.Ruby__SellerTotalAmount__c = 9000;
			update quote2;

			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();

			for (BillingByQuoteLine__c billingByQL : [
				SELECT
					Id,
					BillAmount__c,
					BillDate__c,
					BillingScheduleOrder__c,
					ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
					ELV_QuoteLine__r.Ruby__SubscriptionEndDate__c,
					ELV_QuoteLine__r.Ruby__TotalAmount__c,
					ELV_QuoteLine__r.ELV_PackageTotal__c,
					ELV_QuoteLine__r.Product2.Name,
					ELV_QuoteLine__r.Ruby__SubscriptionTerm__c,
					PaymentType__c,
					IsReverseBilling__c
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote2.Id
			]) {
				if (billingByQL.BillingScheduleOrder__c == '1') {
					Assert.isTrue(
						billingByQL.BillDate__c == earliestEstimatedBillDate,
						'BillingByQuoteLines with order 1 should have the earliest estimated bill date.'
					);
				}
				Assert.isTrue(
					billingByQL.IsReverseBilling__c == true,
					'ReverseBilling should be true if First Billing Override is true.'
				);
			}

			List<Billing_Schedule__c> billingScheds = [
				SELECT Id, Billing_Order__c, Billing_Date__c
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote2.Id AND Billing_Order__c = 1
			];
			Assert.isTrue(
				billingScheds[0].Billing_Date__c == earliestEstimatedBillDate,
				'Billing Schedule Order 1 should have the earliest estimated bill date.'
			);
		}
	}

	@isTest
	static void testBatch_whenFails_createsEventLogRecords() {
		SBQQ.TriggerControl.disable();
		query = 'SELECT ' + 'Id ' + 'FROM Opportunity WHERE Id IN (\'0067V0000237WWJQA2\')';
		Test.startTest();
        try {
            BatchCreateBillingScheduleRecords.executeBatch(query);
        } catch (Exception e) {
            List<LogEntry__c> logs = [
                SELECT Id, Message__c
                FROM LogEntry__c
                WHERE ApexClassName__c = 'BatchCreateBillingScheduleRecords'
                AND ApexMethodName__c = 'execute'
			];
            System.assertEquals(1, logs.size());
        }
		Test.stopTest();
	}

	@isTest
	static void testScheduleBatch() {
		Test.startTest();
		String chron = '0 0 23 * * ?';
		String jobid = System.schedule(
			'testScheduledApex-BatchCreateBillingScheduleRecords',
			chron,
			new BatchCreateBillingScheduleRecords()
		);
		Test.stopTest();

		CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];

		System.assertEquals(chron, ct.CronExpression);
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfullyForQuarterlyNonReverseWithExistingBillings_billingsAreCreated() {
		Opportunity opportunity = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1' LIMIT 1];
		QuoteLineItem quoteLineForBundle = [
			SELECT Ruby__SubscriptionStartDate__c, ELV_PackageTotal__c, ELV_Term_Computed__c
			FROM QuoteLineItem
			WHERE Product2.Name = :BUNDLE_PARENT_PRODUCT
		];

		List<BillingByQuoteLine__c> existingBillings;
		System.runAs(getBatchUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteLineTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
			for (Quote quote : [
				SELECT Id, ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
				FROM Quote
				WHERE OpportunityId = :opportunity.Id
			]) {
				quote.ELV_PaymentTypeNew__c = BillingScheduleService.QUARTERLY_PAYMENT_TYPE;
				quote.ELV_isReverseBilling__c = false;
				update quote;
			}
			existingBillings = [SELECT PaymentType__c, isReverseBilling__c FROM BillingByQuoteLine__c];
			for (BillingByQuoteLine__c eachBilling : existingBillings) {
				eachBilling.PaymentType__c = BillingScheduleService.QUARTERLY_PAYMENT_TYPE;
				eachBilling.isReverseBilling__c = false;
			}
			update existingBillings;
			Test.startTest();
			BatchCreateBillingScheduleRecords.executeBatch();
			Test.stopTest();
		}
		existingBillings = [SELECT Id FROM BillingByQuoteLine__c WHERE Id IN :existingBillings];
		System.assertEquals(0, existingBillings.size());

		List<Billing_Schedule__c> newBillings = [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				isReverseBilling__c,
				Opportunity__r.CloseDate,
				PaymentType__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c,
				ELV_Quote__r.Ruby__SubscriptionStartDate__c,
				(
					SELECT
						Id,
						ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
						ELV_QuoteLine__r.ELV_PackageTotal__c,
						ELV_QuoteLine__r.ELV_Term_Computed__c
					FROM BillingsByQuoteLines__r
				)
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opportunity.Id
		];
		System.assertEquals(14, newBillings.size(), 'Quarterly Installments payment type');
		for (Billing_Schedule__c eachBilling : newBillings) {
			System.assertEquals(false, eachBilling.isReverseBilling__c, 'reverse is false');
			System.assertEquals(
				BillingScheduleService.QUARTERLY_PAYMENT_TYPE,
				eachBilling.PaymentType__c,
				'quarterly payment type billed in 14 billing schedules'
			);
			System.assertEquals(
				eachBilling.PaymentType__c,
				eachBilling.ELV_Quote__r.ELV_PaymentTypeNew__c,
				'payment type copied from billing to quote'
			);
			System.assertEquals(
				eachBilling.isReverseBilling__c,
				eachBilling.ELV_Quote__r.ELV_isReverseBilling__c,
				'reverse billing copied from billing to quote'
			);
			System.assertNotEquals(
				null,
				eachBilling.ELV_Quote__r.ELV_BillingQuoteTerms__c,
				'billing quote terms are generated based off billing schedules data'
			);

			switch on String.valueOf(eachBilling.Billing_Order__c) {
				when '1' {
					System.assertEquals(
						6299.78,
						eachBilling.Billing_Amount__c,
						'6000 (non-prorated product; billed upfront)+1200 (pro-rated; billed quarterly)'
					);
					System.assertEquals(
						eachBilling.ELV_Quote__r.Ruby__SubscriptionStartDate__c,
						eachBilling.Billing_Date__c,
						'trigger updates 1st billing BillDate to opp close date'
					);
					System.assertEquals(2, eachBilling.BillingsByQuoteLines__r.size(), '6000 + 1200');
				}
				when '2' {
					System.assertEquals(
						299.78,
						eachBilling.Billing_Amount__c,
						'299.78 from bundle parent hardware'
					);
					System.assertEquals(
						quoteLineForBundle.Ruby__SubscriptionStartDate__c.addMonths(3),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'299.78 from bundle parent hardware'
					);
				}
				when '3' {
					System.assertEquals(299.78, eachBilling.Billing_Amount__c, 'from bundle parent hardware');
					System.assertEquals(
						quoteLineForBundle.Ruby__SubscriptionStartDate__c.addMonths(6),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'299.78 from bundle parent hardware'
					);
				}
				when '14' {
					Decimal residuePayment = quoteLineForBundle.ELV_PackageTotal__c - (299.78 * 13);
					System.assertEquals(residuePayment, eachBilling.Billing_Amount__c, 'balance payment');
					System.assertEquals(
						quoteLineForBundle.Ruby__SubscriptionStartDate__c.addMonths(13 * 3),
						eachBilling.Billing_Date__c,
						'Bill Date aligned with quote line start date'
					);
					System.assertEquals(
						1,
						eachBilling.BillingsByQuoteLines__r.size(),
						'balance for bundle parent hardware'
					);
				}
			}
		}
		for (BillingByQuoteLine__c eachBillingByQL : [
			SELECT
				BillingScheduleOrder__c,
				BillAmount__c,
				BillDate__c,
				ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
				ELV_QuoteLine__r.ELV_PackageTotal__c
			FROM BillingByQuoteLine__c
			WHERE ELV_QuoteLine__r.Product2.Name = :BUNDLE_PARENT_PRODUCT
		]) {
			switch on eachBillingByQL.BillingScheduleOrder__c {
				when '1' {
					System.assertEquals(299.78, eachBillingByQL.BillAmount__c, 'from bundle parent hardware');
					System.assertEquals(
						eachBillingByQL.ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c,
						eachBillingByQL.BillDate__c,
						'Bill Date aligned with quote line start date'
					);
				}
				when '14' {
					Decimal residuePayment =
						eachBillingByQL.ELV_QuoteLine__r.ELV_PackageTotal__c - (299.78 * 13);

					System.assertEquals(
						residuePayment,
						eachBillingByQL.BillAmount__c,
						'from bundle parent hardware'
					);
					System.assertEquals(
						eachBillingByQL.ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c.addMonths(3 * 13),
						eachBillingByQL.BillDate__c,
						'Bill Date aligned with quote line start date'
					);
				}
				when else {
					System.assertEquals(299.78, eachBillingByQL.BillAmount__c, 'from bundle parent hardware');
					System.assertEquals(
						eachBillingByQL.ELV_QuoteLine__r.Ruby__SubscriptionStartDate__c.addMonths(
							(Integer.valueOf(eachBillingByQL.BillingScheduleOrder__c) - 1) * 3
						),
						eachBillingByQL.BillDate__c,
						'Bill Date aligned with quote line start date'
					);
				}
			}
		}
	}

	static QuoteLineItem getBundleParentQuoteLine() {
		return [
			SELECT Ruby__SubscriptionStartDate__c, Ruby__SubscriptionEndDate__c, ELV_PackageTotal__c, ELV_Term_Computed__c
			FROM QuoteLineItem
			WHERE Product2.Name = :BUNDLE_PARENT_PRODUCT
		];
	}

	static Quote setQuoteToAnnualNonReverseBilling(Id opportunityId) {
		Quote quote = [
			SELECT ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
			FROM Quote
			WHERE OpportunityId = :opportunityId
		];
		quote.ELV_PaymentTypeNew__c = ANNUAL_PAYMENT_TYPE;
		quote.ELV_isReverseBilling__c = false;
		update quote;
		return quote;
	}

	static Quote setQuoteToAnnualReverseBilling(Id opportunityId) {
		Quote quote = [
			SELECT ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
			FROM Quote
			WHERE OpportunityId = :opportunityId
		];
		quote.ELV_PaymentTypeNew__c = ANNUAL_PAYMENT_TYPE;
		quote.ELV_isReverseBilling__c = true;
		quote.Ruby__SellerTotalAmount__c = 10000;
		update quote;
		return quote;
	}

	static User getBatchUser() {
		if (BatchCreateBillingScheduleRecordsTest.batchUser == null) {
			List<User> testUsers = [SELECT Id FROM User WHERE LastName LIKE 'TaniumAdminUser%'];
			if (testUsers.isEmpty()) {
				BatchCreateBillingScheduleRecordsTest.batchUser = TestFactory.getTaniumAdminUser(true);
				TestingUtility.assignPermissionSet(
					BatchCreateBillingScheduleRecordsTest.batchUser.Id,
					'DisableFlows'
				);
				TestingUtility.assignPermissionSet(
					BatchCreateBillingScheduleRecordsTest.batchUser.Id,
					'DisableValidationRules'
				);
				TestingUtility.assignPermissionSet(
					BatchCreateBillingScheduleRecordsTest.batchUser.Id,
					'BillingScheduleConfigurator'
				);
			} else {
				BatchCreateBillingScheduleRecordsTest.batchUser = testUsers[0];
			}
		}
		return BatchCreateBillingScheduleRecordsTest.batchUser;
	}
}