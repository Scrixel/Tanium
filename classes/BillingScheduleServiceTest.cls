/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for BillingScheduleService
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-13619     2026-08-18      Migrated to standard Quote/QuoteLineItem and reduced duplication
 */
@isTest
private class BillingScheduleServiceTest {
	private static User adminUser;
	public static final String FLAT_SKU_PRODUCT = 'Flat SKU Product';
	public static final String FLAT_SKU_PRODUCT_CUSTOM_BILLING = 'Flat SKU Product for Custom Billing';
	public static final String BUNDLE_PARENT_PRODUCT = 'Bundle Parent Hardware';
	public static final String UPFRONT_PAYMENT_TYPE = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE;
	public static final String ANNUAL_PAYMENT_TYPE = BillingScheduleConfiguratorController.ANNUAL_PAYMENT_TYPE;
	public static final String CUSTOM_PAYMENT_TYPE = BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE;
	public static final String QUARTERLY_PAYMENT_TYPE = BillingScheduleConfiguratorController.QUARTERLY_PAYMENT_TYPE;
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
		System.runAs(getAdminUser()) {
			TestFactory.seedRubySettings();

			Account account = TestFactory.buildAccount('Test Account 1');
			insert new List<Account>{ account };

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today() + 30,
				'Prospecting',
				account.Id
			);
			opportunity.CloseDate = Date.today() + 60;
			opportunity.BillingScheduleTotalAmountNew__c = 10;

			insert new List<Opportunity>{ opportunity };

			Quote quote = TestFactory.buildQuote(
				'Test Quote 1',
				opportunity.Id,
				Date.today().addMonths(2),
				Date.today().addMonths(2).addYears(3).addMonths(3)
			);
			quote.ELV_isReverseBilling__c = true;
			quote.ELV_PaymentTypeNew__c = UPFRONT_PAYMENT_TYPE;

			insert new List<Quote>{ quote };

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

			Product2 flatSKUProductForCustomBilling = new Product2(
				IsActive = true,
				Name = FLAT_SKU_PRODUCT_CUSTOM_BILLING,
				Description = 'test description for custom billing',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = true,
				SBQQ__SubscriptionPricing__c = 'Fixed Price'
			);

			insert new List<Product2>{
				flatSKUProduct,
				bundleParentHardware,
				myBundleComponentHardware,
				flatSKUProductForCustomBilling
			};

			List<PricebookEntry> pricebookEntries = new List<PricebookEntry>{
				TestFactory.buildPricebookEntry(flatSKUProduct.Id, 6000, Test.getStandardPricebookId()),
				TestFactory.buildPricebookEntry(bundleParentHardware.Id, 4000, Test.getStandardPricebookId()),
				TestFactory.buildPricebookEntry(
					myBundleComponentHardware.Id,
					4000,
					Test.getStandardPricebookId()
				),
				TestFactory.buildPricebookEntry(
					flatSKUProductForCustomBilling.Id,
					0,
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
			quoteLineFlatSKU.Ruby__SubscriptionStartDate__c = Date.today().addMonths(2);
			quoteLineFlatSKU.Ruby__SubscriptionEndDate__c = Date.today()
				.addMonths(2)
				.addYears(3)
				.addMonths(3)
				.addDays(29);
			quoteLineFlatSKU.Ruby__TotalAmount__c = 6000;

			QuoteLineItem quoteLineFlatSKUZeroNet = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				0,
				flatSKUProductPBE.Id
			);
			quoteLineFlatSKUZeroNet.ELV_Bundled_Product__c = false;
			quoteLineFlatSKUZeroNet.Ruby__SubscriptionStartDate__c = Date.today().addMonths(2);
			quoteLineFlatSKUZeroNet.Ruby__SubscriptionEndDate__c = Date.today()
				.addMonths(2)
				.addYears(3)
				.addMonths(3);
			quoteLineFlatSKUZeroNet.Ruby__TotalAmount__c = 0;

			QuoteLineItem quoteLineParentBundleHardware = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				4000,
				bundleParentHardwarePBE.Id
			);
			quoteLineParentBundleHardware.ELV_Bundled_Product__c = false;
			quoteLineParentBundleHardware.Ruby__SubscriptionStartDate__c = Date.today().addMonths(2);
			quoteLineParentBundleHardware.Ruby__SubscriptionEndDate__c = Date.today()
				.addMonths(2)
				.addYears(3)
				.addMonths(3)
				.addDays(30);
			quoteLineParentBundleHardware.Ruby__TotalAmount__c = 4000;
			quoteLineParentBundleHardware.Ruby__TotalPrice__c = 4000;

			QuoteLineItem quoteLineBundleComponentHardware = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				4000,
				myBundleComponentHardwarePBE.Id
			);
			quoteLineBundleComponentHardware.ELV_Bundled_Product__c = true;
			quoteLineBundleComponentHardware.Ruby__SubscriptionStartDate__c = Date.today().addMonths(2);
			quoteLineBundleComponentHardware.Ruby__SubscriptionEndDate__c = Date.today()
				.addMonths(2)
				.addYears(3)
				.addMonths(3);
			quoteLineBundleComponentHardware.Ruby__TotalAmount__c = 4000;

			insert new List<QuoteLineItem>{
				quoteLineFlatSKU,
				quoteLineFlatSKUZeroNet,
				quoteLineParentBundleHardware,
				quoteLineBundleComponentHardware
			};

			Billing_Schedule__c billingSchedule = new Billing_Schedule__c(
				isReverseBilling__c = false,
				PaymentType__c = BillingScheduleService.UPFRONT_PAYMENT_TYPE
			);
			billingSchedule.Billing_Date__c = opportunity.CloseDate;
			billingSchedule.Billing_Amount__c = 10;
			billingSchedule.Opportunity__c = opportunity.Id;
			billingSchedule.ELV_Quote__c = quote.Id;
			insert billingSchedule;

			BillingByQuoteLine__c billingFlatSKU = new BillingByQuoteLine__c(
				BillAmount__c = 5,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = BillingScheduleService.UPFRONT_PAYMENT_TYPE
			);
			billingFlatSKU.BillingSchedule__c = billingSchedule.Id;
			billingFlatSKU.Opportunity__c = opportunity.Id;
			billingFlatSKU.ELV_Quote__c = quote.Id;
			billingFlatSKU.ELV_QuoteLine__c = quoteLineFlatSKU.Id;
			billingFlatSKU.BillDate__c = opportunity.CloseDate;

			BillingByQuoteLine__c billingHardwareBundle = new BillingByQuoteLine__c(
				BillAmount__c = 5,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = BillingScheduleService.UPFRONT_PAYMENT_TYPE
			);
			billingHardwareBundle.BillingSchedule__c = billingSchedule.Id;
			billingHardwareBundle.Opportunity__c = opportunity.Id;
			billingHardwareBundle.ELV_Quote__c = quote.Id;
			billingHardwareBundle.ELV_QuoteLine__c = quoteLineParentBundleHardware.Id;
			billingHardwareBundle.BillDate__c = opportunity.CloseDate;

			insert new List<BillingByQuoteLine__c>{ billingFlatSKU, billingHardwareBundle };
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenNoExistingBillingsByQuoteLines_ReturnsUpfrontBillingByQuoteLines() {
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		List<Billing_Schedule__c> existingBillings = [SELECT Id FROM Billing_Schedule__c];
		delete existingBillings;
		List<BillingByQuoteLine__c> billingLines = [SELECT Id FROM BillingByQuoteLine__c];
		System.assertEquals(0, billingLines.size());
		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();
		Integer validQuoteLinesCount = [
			SELECT COUNT()
			FROM QuoteLineItem
			WHERE ELV_Bundled_Product__c = FALSE AND (Ruby__TotalAmount__c != 0 OR ELV_Bundle__c = TRUE)
		];
		System.assertEquals(
			validQuoteLinesCount,
			billingByQuoteLines.size(),
			'Ignoring Quotelines that are bundled and that have net total of zero'
		);
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			System.assertEquals(
				BillingScheduleService.UPFRONT_PAYMENT_TYPE,
				billingByQuoteLine.PaymentType__c
			);
			System.assertEquals(false, billingByQuoteLine.isReverseBilling__c);
			System.assertEquals(opportunity.CloseDate, billingByQuoteLine.BillDate__c);
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenOpportunityProvided_ReturnsUpfrontBillingByQuoteLines() {
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();
		Integer validQuoteLinesCount = [
			SELECT COUNT()
			FROM QuoteLineItem
			WHERE ELV_Bundled_Product__c = FALSE AND (Ruby__TotalAmount__c != 0 OR ELV_Bundle__c = TRUE)
		];
		System.assertEquals(
			validQuoteLinesCount,
			billingByQuoteLines.size(),
			'Ignoring Quotelines that are bundled and that have net total of zero'
		);
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			System.assertEquals(
				BillingScheduleService.UPFRONT_PAYMENT_TYPE,
				billingByQuoteLine.PaymentType__c
			);
			System.assertEquals(false, billingByQuoteLine.isReverseBilling__c);
			System.assertEquals(opportunity.CloseDate, billingByQuoteLine.BillDate__c);
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenExistingBillingsPaymentTypeIsCustom_DoesNotReturnBillingByQuoteLines() {
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		List<BillingByQuoteLine__c> existingBillings = [
			SELECT PaymentType__c
			FROM BillingByQuoteLine__c
			WHERE Opportunity__c = :opportunity.Id
		];
		for (BillingByQuoteLine__c eachBilling : existingBillings) {
			eachBilling.PaymentType__c = BillingScheduleService.CUSTOM_PAYMENT_TYPE;
		}
		update existingBillings;

		SBQQ.TriggerControl.disable();
		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();

		System.assertEquals(
			0,
			billingByQuoteLines.size(),
			'No billingByQuoteLines returned due to Custom payment type - restricted from automation'
		);
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenQuotePaymentTypeIsCustom_DoesNotReturnBillingByQuoteLines() {
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		System.assertEquals(0, [SELECT Id FROM BillingByQuoteLine__c].size());

		SBQQ.TriggerControl.disable();
		List<QuoteLineItem> quoteLines = new List<QuoteLineItem>();
		for (Quote quote : [
			SELECT ELV_PaymentTypeNew__c
			FROM Quote
			WHERE OpportunityId = :opportunity.Id
		]) {
			quote.ELV_PaymentTypeNew__c = BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE;
			update quote;
		}
		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();

		System.assertEquals(
			0,
			billingByQuoteLines.size(),
			'No billingByQuoteLines returned due to Custom payment type - restricted from automation'
		);
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenQuoteFirstBillingOverrideIsTrue_ReturnsBillingByQuoteLines() {
		SBQQ.TriggerControl.disable();
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		System.assertEquals(0, [SELECT Id FROM BillingByQuoteLine__c].size());

		for (Quote quote : [
			SELECT ELV_First_Billing_Override__c
			FROM Quote
			WHERE OpportunityId = :opportunity.Id
		]) {
			quote.ELV_First_Billing_Override__c = true;
			update quote;
		}

		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();

		System.assertEquals(
			2,
			billingByQuoteLines.size(),
			'No billingByQuoteLines returned due to First Billing Override being true on quote'
		);
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenOpportunityProvided_ReturnsAnnualNonReverseBillingByQuoteLines() {
		SBQQ.TriggerControl.disable();
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		updateQuotePaymentType(opportunity.Id, 'Annual Installment', false);

		QuoteLineItem quoteLineFlatSKU = getFlatSKUQuoteLine(opportunity.Id);
		QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();

		Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
		System.assertEquals(true, noOfMonths > 39);

		Decimal installmentPerMonth = quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths;
		Decimal annualPayment = (12 * installmentPerMonth).setScale(2);
		Decimal residuePayment = quoteLineBundleParent.ELV_PackageTotal__c - (annualPayment * 3);
		System.assertEquals(4000 - (annualPayment * 3), residuePayment);

		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			System.assertEquals(
				BillingScheduleService.ANNUAL_PAYMENT_TYPE,
				billingByQuoteLine.PaymentType__c,
				'Annual Installment shows accurately'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.isReverseBilling__c,
				'Reverse billing is false on QuoteLine'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundled_Product__c,
				'Bundled products cannot have billings'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.Ruby__TotalAmount__c == 0 &&
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundle__c == false,
				'Flat SKUs with NetTotal zero cannot have billings'
			);
			System.assertEquals(
				true,
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) > 0,
				'Orders are shown accurately'
			);

			if (billingByQuoteLine.ELV_QuoteLine__c == quoteLineFlatSKU.Id) {
				System.assertEquals(
					6000,
					billingByQuoteLine.BillAmount__c,
					'Non-Prorated product billed upfront'
				);
				System.assertEquals(
					quoteLineFlatSKU.Ruby__SubscriptionStartDate__c,
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			} else if (
				billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id &&
				(billingByQuoteLine.BillingScheduleOrder__c == '1' ||
				billingByQuoteLine.BillingScheduleOrder__c == '2' ||
				billingByQuoteLine.BillingScheduleOrder__c == '3')
			) {
				System.assertEquals(annualPayment, billingByQuoteLine.BillAmount__c, 'Billed annually');
				if (billingByQuoteLine.BillingScheduleOrder__c == '1') {
					System.assertEquals(
						BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent)
							.addYears(Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) - 1),
						billingByQuoteLine.BillDate__c,
						'Bill Date aligned with Start Date'
					);
				} else {
					System.assertEquals(
						BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent)
							.addYears(Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) - 1),
						billingByQuoteLine.BillDate__c,
						'Bill Date aligned with Start Date'
					);
				}
			} else if (billingByQuoteLine.BillingScheduleOrder__c == '4') {
				System.assertEquals(residuePayment, billingByQuoteLine.BillAmount__c, 'Residue payment');
				System.assertEquals(
					BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent)
						.addYears(Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) - 1),
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			}
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenOpportunityProvided_ReturnsAnnualNotReverseBillingByQuoteLines() {
		SBQQ.TriggerControl.disable();
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		Quote quote = updateQuotePaymentType(opportunity.Id, ANNUAL_PAYMENT_TYPE, false);

		QuoteLineItem quoteLineFlatSKU = getFlatSKUQuoteLine(opportunity.Id);
		QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();
		Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
		System.assertEquals(true, noOfMonths > 39);

		Decimal installmentPerMonth = quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths;
		Decimal annualPayment = (12 * installmentPerMonth).setScale(2);
		Decimal residuePayment = quoteLineBundleParent.ELV_PackageTotal__c - (annualPayment * 3);
		System.assertEquals(4000 - (annualPayment * 3), residuePayment);

		Product2 flatSKUProduct2 = new Product2(
			IsActive = true,
			Name = 'Flat SKU Product 2',
			Description = 'test description 2',
			Product_Category__c = 'Hardware',
			Prorate_Billing__c = true
		);
		insert flatSKUProduct2;
		PricebookEntry flatSKUProduct2PBE = TestFactory.buildPricebookEntry(
			flatSKUProduct2.Id,
			3100,
			Test.getStandardPricebookId()
		);
		insert flatSKUProduct2PBE;
		QuoteLineItem quoteLineFlatSKU2 = TestFactory.buildQuoteLineItem(
			quote.Id,
			1,
			3100,
			flatSKUProduct2PBE.Id
		);
		quoteLineFlatSKU2.ELV_Bundled_Product__c = false;
		quoteLineFlatSKU2.Ruby__SubscriptionStartDate__c = Date.newInstance(Date.today().year(), 7, 15);
		quoteLineFlatSKU2.Ruby__SubscriptionEndDate__c = Date.newInstance(Date.today().year() + 3, 2, 14);
		quoteLineFlatSKU2.Ruby__TotalAmount__c = 3100;
		insert quoteLineFlatSKU2;
		quoteLineFlatSKU2 = [
			SELECT
				ELV_End_Date__c,
				ELV_Bundle__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				Quote.Ruby__SubscriptionStartDate__c,
				Ruby__TotalAmount__c,
				ELV_PackageTotal__c,
				ELV_Term_Computed__c
			FROM QuoteLineItem
			WHERE Product2.Name = 'Flat SKU Product 2'
		];

		Decimal noOfMonthsForFlatSKU2 = BillingScheduleService.getQuoteLineTermComputed(quoteLineFlatSKU2);
		System.assertEquals(31, noOfMonthsForFlatSKU2);
		Decimal installmentPerMonthForFlatSKU2 =
			quoteLineFlatSKU2.Ruby__TotalAmount__c / noOfMonthsForFlatSKU2;
		System.assertEquals(100, installmentPerMonthForFlatSKU2);

		Decimal annualPaymentForFlatSKU2 = 12 * installmentPerMonthForFlatSKU2;
		System.assertEquals(1200, annualPaymentForFlatSKU2);
		Decimal residuePaymentForFlatSKU2 =
			quoteLineFlatSKU2.Ruby__TotalAmount__c - (12 * installmentPerMonthForFlatSKU2 * 2);
		System.assertEquals(700, residuePaymentForFlatSKU2);
		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			System.assertEquals(
				BillingScheduleService.ANNUAL_PAYMENT_TYPE,
				billingByQuoteLine.PaymentType__c,
				'Annual Installment shows accurately'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.isReverseBilling__c,
				'Reverse billing is false on QuoteLine'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundled_Product__c,
				'Bundled products cannot have billings'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.Ruby__TotalAmount__c == 0 &&
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundle__c == false,
				'Flat SKUs with NetTotal zero cannot have billings'
			);
			System.assertEquals(
				true,
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) > 0,
				'Orders are shown accurately'
			);

			if (billingByQuoteLine.ELV_QuoteLine__c == quoteLineFlatSKU.Id) {
				System.assertEquals(
					6000,
					billingByQuoteLine.BillAmount__c,
					'Non-Prorated product billed upfront'
				);
			} else if (billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id) {
				switch on billingByQuoteLine.BillingScheduleOrder__c {
					when '1' {
						Date billdate = Date.newInstance(
							BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent).year(),
							BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent).month(),
							BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent).day()
						);
						System.assertEquals(billdate, billingByQuoteLine.BillDate__c, 'Billed annually');

						System.assertEquals(
							(installmentPerMonth * 12).setScale(2),
							billingByQuoteLine.BillAmount__c,
							'Bill date aligned with end date'
						);
					}
					when '2' {
						System.assertEquals(
							(installmentPerMonth * 12).setScale(2),
							billingByQuoteLine.BillAmount__c,
							'Billed annually'
						);
						System.assertEquals(
							BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent).addYears(1),
							billingByQuoteLine.BillDate__c,
							'Bill date aligned with end date'
						);
					}
					when '3' {
						System.assertEquals(
							(installmentPerMonth * 12).setScale(2),
							billingByQuoteLine.BillAmount__c,
							'Billed annually'
						);
						System.assertEquals(
							BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent).addYears(2),
							billingByQuoteLine.BillDate__c,
							'Bill date aligned with end date'
						);
					}
					when '4' {
						System.assertEquals(
							residuePayment,
							billingByQuoteLine.BillAmount__c,
							'Billed for 4 months'
						);
						System.assertEquals(
							BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent).addYears(3),
							billingByQuoteLine.BillDate__c,
							'Bill date aligned with start date'
						);
					}
				}
			} else if (billingByQuoteLine.ELV_QuoteLine__c == quoteLineFlatSKU2.Id) {
				switch on billingByQuoteLine.BillingScheduleOrder__c {
					when '1' {
						System.assertEquals(
							installmentPerMonthForFlatSKU2 * 12,
							billingByQuoteLine.BillAmount__c,
							'Billed annually'
						);
						System.assertEquals(
							true,
							BillingScheduleService.getQuoteLineEndDate(quoteLineFlatSKU2).month() <
							BillingScheduleService.getQuoteLineStartDate(quoteLineFlatSKU2).month(),
							'End month is less'
						);
						System.assertEquals(
							BillingScheduleService.getQuoteLineStartDate(quoteLineFlatSKU2),
							billingByQuoteLine.BillDate__c,
							'Bill date aligned with start date'
						);
					}
					when '2' {
						System.assertEquals(
							installmentPerMonthForFlatSKU2 * 12,
							billingByQuoteLine.BillAmount__c,
							'Billed annually'
						);
						System.assertEquals(
							BillingScheduleService.getQuoteLineStartDate(quoteLineFlatSKU2).addYears(1),
							billingByQuoteLine.BillDate__c,
							'Bill date aligned with end date'
						);
					}
					when '3' {
						System.assertEquals(
							installmentPerMonthForFlatSKU2 * 7,
							billingByQuoteLine.BillAmount__c,
							'Billed for 7 months'
						);
						System.assertEquals(
							BillingScheduleService.getQuoteLineStartDate(quoteLineFlatSKU2).addYears(2),
							billingByQuoteLine.BillDate__c,
							'Bill date aligned with end date'
						);
					}
				}
			}
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenOpportunityProvided_ReturnsAnnualReverseBillingByQuoteLines() {
		SBQQ.TriggerControl.disable();
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		updateQuotePaymentType(opportunity.Id, 'Annual Installment', true);

		QuoteLineItem quoteLineFlatSKU = getFlatSKUQuoteLine(opportunity.Id);
		QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();

		Decimal noOfMonths = BillingScheduleService.getQuoteLineTermComputed(quoteLineBundleParent);
		System.assertEquals(true, noOfMonths > 39);

		Decimal installmentPerMonth = quoteLineBundleParent.ELV_PackageTotal__c / noOfMonths;
		Decimal annualPayment = (12 * installmentPerMonth).setScale(2);
		Decimal residuePayment = quoteLineBundleParent.ELV_PackageTotal__c - (annualPayment * 3);
		System.assertEquals(4000 - (annualPayment * 3), residuePayment);

		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			System.assertEquals(
				BillingScheduleService.ANNUAL_PAYMENT_TYPE,
				billingByQuoteLine.PaymentType__c,
				'Annual Installment shows accurately'
			);
			System.assertEquals(
				true,
				billingByQuoteLine.isReverseBilling__c,
				'Reverse billing is true on QuoteLine'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundled_Product__c,
				'Bundled products cannot have billings'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.Ruby__TotalAmount__c == 0 &&
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundle__c == false,
				'Flat SKUs with NetTotal zero cannot have billings'
			);
			System.assertEquals(
				true,
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) > 0,
				'Orders are shown accurately'
			);

			if (billingByQuoteLine.ELV_QuoteLine__c == quoteLineFlatSKU.Id) {
				System.assertEquals(
					6000,
					billingByQuoteLine.BillAmount__c,
					'Non-Prorated product billed upfront'
				);
				System.assertEquals(
					quoteLineFlatSKU.Ruby__SubscriptionStartDate__c,
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			} else if (
				billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id &&
				(billingByQuoteLine.BillingScheduleOrder__c == '2' ||
				billingByQuoteLine.BillingScheduleOrder__c == '3' ||
				billingByQuoteLine.BillingScheduleOrder__c == '4')
			) {
				System.assertEquals(
					Integer.valueOf(annualPayment),
					Integer.valueOf(billingByQuoteLine.BillAmount__c),
					'Billed annually'
				);
			} else if (billingByQuoteLine.BillingScheduleOrder__c == '1') {
				System.assertEquals(residuePayment, billingByQuoteLine.BillAmount__c, 'Residue payment');
				Date billDate = BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent);
				System.assertEquals(
					billDate,
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			}
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_whenReverseBilling_returnsEmptyList() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);
		List<PermissionSetAssignment> psa = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSet.Name = 'DisableFlows'
		];
		if (psa.isEmpty()) {
			TestingUtility.assignPermissionSet(UserInfo.getUserId(), 'DisableFlows');
		}
		System.runAs(new User(Id = UserInfo.getUserId())) {
			List<Billing_Schedule__c> existingBillingSchedules = [SELECT Id FROM Billing_Schedule__c];
			delete existingBillingSchedules;
			Quote quote = [
				SELECT Id, ELV_PaymentTypeNew__c, OpportunityId
				FROM Quote
				WHERE Ruby__IsPrimaryQuote__c = TRUE
				LIMIT 1
			];
			quote.ELV_PaymentTypeNew__c = null;
			update quote;
			Product2 product = [SELECT Id FROM Product2 WHERE Name = :FLAT_SKU_PRODUCT_CUSTOM_BILLING];
			PricebookEntry productPBE = [
				SELECT Id
				FROM PricebookEntry
				WHERE Product2Id = :product.Id AND Pricebook2Id = :Test.getStandardPricebookId()
			];
			QuoteLineItem quoteLineFlatSKU = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				10000,
				productPBE.Id
			);
			quoteLineFlatSKU.ELV_Bundled_Product__c = false;
			quoteLineFlatSKU.Ruby__SubscriptionStartDate__c = Date.today().addMonths(2);
			quoteLineFlatSKU.Ruby__SubscriptionEndDate__c = Date.today().addMonths(2).addYears(3).addMonths(3);
			quoteLineFlatSKU.Ruby__TotalAmount__c = 10000;
			insert quoteLineFlatSKU;
			Boolean exceptionThrown = false;
			TriggerHandler.clearAllBypasses();
			Test.startTest();
			try {
				BillingScheduleService.getPrimaryQuoteLinesData(quote.OpportunityId, 'Opportunity');
			} catch (Exception e) {
				exceptionThrown = true;
			}
			Test.stopTest();
			System.assertEquals(false, exceptionThrown, 'Exception should not be thrown');
			List<Billing_Schedule__c> billings = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote.Id
			];
			System.assertEquals(
				0,
				billings.size(),
				'No billings should be created since Custom Billing is true on one of the line items'
			);
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenNoQuoteLines_ErrorShouldNotOccur() {
		Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];

		Quote quote = TestFactory.buildQuote(
			'Test Quote No Lines',
			opp.Id,
			Date.today().addMonths(2),
			Date.today().addMonths(2).addYears(3).addMonths(3)
		);
		quote.ELV_PaymentTypeNew__c = UPFRONT_PAYMENT_TYPE;

		insert quote;

		Boolean exceptionThrown = false;

		Test.startTest();
		try {
			BillingScheduleService.getPrimaryQuoteLinesData(opp.Id, 'Opportunity');
		} catch (Exception e) {
			exceptionThrown = true;
		}
		Test.stopTest();

		System.assertEquals(false, exceptionThrown, 'Exception should not be thrown');
	}

	@IsTest
	static void getPrimaryQuoteLinesData_whenZeroNetAmountAndBillingsExsts_returnsEmptyList() {
		Quote quote = [SELECT Id, OpportunityId FROM Quote LIMIT 1];
		List<QuoteLineItem> quoteLines = [
			SELECT Id, Ruby__NetSalesPrice__c
			FROM QuoteLineItem
			WHERE QuoteId = :quote.Id
		];
		for (QuoteLineItem quoteLine : quoteLines) {
			quoteLine.Ruby__NetSalesPrice__c = 0;
		}
		update quoteLines;

		quote.Ruby__SellerTotalAmount__c = 0;
		update quote;

		List<Billing_Schedule__c> existingbillings = [
			SELECT Id, ELV_Quote__r.Ruby__SellerTotalAmount__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote.Id
		];
		Assert.isFalse(existingbillings.isEmpty(), 'Billing Schedules should exists');
		Assert.isTrue(
			existingbillings[0].ELV_Quote__r.Ruby__SellerTotalAmount__c == 0,
			'Quote Net Amount should be 0'
		);

		Test.startTest();
		List<BillingByQuoteLine__c> billings = BillingScheduleService.getPrimaryQuoteLinesData(
			quote.OpportunityId,
			'Opportunity'
		);

		Test.stopTest();

		List<Billing_Schedule__c> billingsAfter = [
			SELECT Id, ELV_Quote__r.Ruby__SellerTotalAmount__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote.Id
		];
		Assert.isTrue(billingsAfter.isEmpty(), 'Billing Schedules should be deleted.');
		Assert.isTrue(billings.isEmpty(), 'Should return empty list.');
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenOpportunityProvided_ReturnsQuarterlyNonReverseBillingByQuoteLines() {
		SBQQ.TriggerControl.disable();
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		updateQuotePaymentType(opportunity.Id, 'Quarterly Installment', false);

		QuoteLineItem quoteLineFlatSKU = getFlatSKUQuoteLine(opportunity.Id);
		QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();

		Decimal monthsBetweenQuoteStartEndDate = BillingScheduleService.getQuoteLineTermComputed(
			quoteLineBundleParent
		);
		System.assertEquals(true, monthsBetweenQuoteStartEndDate.intValue() == 40);

		Integer noOfInstallmentsWithoutResidual = Math.floor(monthsBetweenQuoteStartEndDate / 3)
			.intValue();
		System.assertEquals(13, noOfInstallmentsWithoutResidual);
		Integer noOfInstallmentsWithResidual = 0;
		if (Math.mod(noOfInstallmentsWithoutResidual, 3) > 0) {
			noOfInstallmentsWithResidual = noOfInstallmentsWithoutResidual + 1;
		}
		System.assertEquals(14, noOfInstallmentsWithResidual);

		Decimal installmentPerMonth =
			quoteLineBundleParent.ELV_PackageTotal__c / monthsBetweenQuoteStartEndDate;
		Decimal quarterlyPayment = (3 * installmentPerMonth).setScale(2);
		Decimal residuePayment = ((installmentPerMonth * monthsBetweenQuoteStartEndDate) -
			(quarterlyPayment * noOfInstallmentsWithoutResidual))
			.setScale(2);
		System.assertEquals(true, residuePayment > 0 && residuePayment < quarterlyPayment);

		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			System.assertEquals(
				BillingScheduleService.QUARTERLY_PAYMENT_TYPE,
				billingByQuoteLine.PaymentType__c,
				'Quarterly Installment shows accurately'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.isReverseBilling__c,
				'Reverse billing is false on QuoteLine'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundled_Product__c,
				'Bundled products cannot have billings'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.Ruby__TotalAmount__c == 0 &&
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundle__c == false,
				'Flat SKUs with NetTotal zero cannot have billings'
			);
			System.assertEquals(
				true,
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) > 0,
				'Orders are shown accurately'
			);

			if (billingByQuoteLine.ELV_QuoteLine__c == quoteLineFlatSKU.Id) {
				System.assertEquals(
					6000,
					billingByQuoteLine.BillAmount__c,
					'Non-Prorated product billed upfront'
				);
				System.assertEquals(
					quoteLineFlatSKU.Ruby__SubscriptionStartDate__c,
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			} else if (
				billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id &&
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) == 1
			) {
				System.assertEquals(quarterlyPayment, billingByQuoteLine.BillAmount__c, 'Billed quarterly');
				System.assertEquals(
					BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent),
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			} else if (
				billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id &&
				(Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) > 1 &&
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) < 14)
			) {
				System.assertEquals(quarterlyPayment, billingByQuoteLine.BillAmount__c, 'Billed quarterly');
				System.assertEquals(
					BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent)
						.addMonths((Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) - 1) * 3),
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Quarterly Start Date'
				);
			} else if (billingByQuoteLine.BillingScheduleOrder__c == '14') {
				System.assertEquals(residuePayment, billingByQuoteLine.BillAmount__c, 'Residue payment');
				System.assertEquals(
					BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent)
						.addMonths((Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) - 1) * 3),
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Quarterly Start Date'
				);
			}
		}
	}

	@isTest
	static void getPrimaryQuoteLinesData_WhenOpportunityProvided_ReturnsQuarterlyReverseBillingByQuoteLines() {
		SBQQ.TriggerControl.disable();
		Opportunity opportunity = [SELECT Id, CloseDate FROM Opportunity LIMIT 1];
		deleteExistingBillingSchedules(opportunity.Id);
		Quote quote = [
			SELECT ELV_First_Billing_Override__c, ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
			FROM Quote
			WHERE OpportunityId = :opportunity.Id
		];
		quote.ELV_PaymentTypeNew__c = QUARTERLY_PAYMENT_TYPE;
		quote.ELV_First_Billing_Override__c = true;
		quote.ELV_isReverseBilling__c = true;
		update quote;

		QuoteLineItem quoteLineFlatSKU = getFlatSKUQuoteLine(opportunity.Id);
		QuoteLineItem quoteLineBundleParent = getBundleParentQuoteLine();

		Decimal monthsBetweenQuoteStartEndDate = BillingScheduleService.getQuoteLineTermComputed(
			quoteLineBundleParent
		);
		System.assertEquals(true, monthsBetweenQuoteStartEndDate.intValue() == 40);

		Integer noOfInstallmentsWithoutResidual = Math.floor(monthsBetweenQuoteStartEndDate / 3)
			.intValue();
		System.assertEquals(13, noOfInstallmentsWithoutResidual);
		Integer noOfInstallmentsWithResidual = 0;
		if (Math.mod(noOfInstallmentsWithoutResidual, 3) > 0) {
			noOfInstallmentsWithResidual = noOfInstallmentsWithoutResidual + 1;
		}
		System.assertEquals(14, noOfInstallmentsWithResidual);

		Decimal installmentPerMonth =
			quoteLineBundleParent.ELV_PackageTotal__c / monthsBetweenQuoteStartEndDate;
		Decimal quarterlyPayment = (3 * installmentPerMonth).setScale(2);
		Decimal residuePayment = ((installmentPerMonth * monthsBetweenQuoteStartEndDate) -
			(quarterlyPayment * noOfInstallmentsWithoutResidual))
			.setScale(2);
		System.assertEquals(true, residuePayment > 0 && residuePayment < quarterlyPayment);

		Test.startTest();
		List<BillingByQuoteLine__c> billingByQuoteLines = BillingScheduleService.getPrimaryQuoteLinesData(
			opportunity.Id,
			'Opportunity'
		);
		Test.stopTest();
		BillingByQuoteLine__c priorBilling;
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			System.assertEquals(
				BillingScheduleService.QUARTERLY_PAYMENT_TYPE,
				billingByQuoteLine.PaymentType__c,
				'Quarterly Installment shows accurately'
			);
			System.assertEquals(
				true,
				billingByQuoteLine.isReverseBilling__c,
				'Reverse billing is false on QuoteLine'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundled_Product__c,
				'Bundled products cannot have billings'
			);
			System.assertEquals(
				false,
				billingByQuoteLine.ELV_QuoteLine__r.Ruby__TotalAmount__c == 0 &&
				billingByQuoteLine.ELV_QuoteLine__r.ELV_Bundle__c == false,
				'Flat SKUs with NetTotal zero cannot have billings'
			);
			System.assertEquals(
				true,
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) > 0,
				'Orders are shown accurately'
			);

			if (billingByQuoteLine.ELV_QuoteLine__c == quoteLineFlatSKU.Id) {
				System.assertEquals(
					6000,
					billingByQuoteLine.BillAmount__c,
					'Non-Prorated product billed upfront'
				);
				System.assertEquals(
					quoteLineFlatSKU.Ruby__SubscriptionStartDate__c,
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			} else if (
				billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id &&
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) == 1
			) {
				System.assertEquals(residuePayment, billingByQuoteLine.BillAmount__c, 'Residue payment');
				System.assertEquals(
					BillingScheduleService.getQuoteLineStartDate(quoteLineBundleParent),
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with Start Date'
				);
			} else if (
				billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id &&
				(Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) == 2)
			) {
				Date billDate = Date.newInstance(
					quoteLineBundleParent.Ruby__SubscriptionStartDate__c.year(),
					quoteLineBundleParent.Ruby__SubscriptionEndDate__c.month(),
					quoteLineBundleParent.Ruby__SubscriptionEndDate__c.day()
				);
				Integer diff = quoteLineBundleParent.Ruby__SubscriptionStartDate__c.monthsBetween(billDate);
				if (diff < 0) {
					billDate = Date.newInstance(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.year() + 1,
						quoteLineBundleParent.Ruby__SubscriptionEndDate__c.month(),
						quoteLineBundleParent.Ruby__SubscriptionEndDate__c.day()
					);
					diff = quoteLineBundleParent.Ruby__SubscriptionStartDate__c.monthsBetween(billDate);
				}
				diff++;

				if (diff > 0 && diff <= 3) {
					billDate = quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff),
						billingByQuoteLine.BillDate__c,
						'Billed with difference'
					);
					System.assertEquals(
						diff * installmentPerMonth,
						billingByQuoteLine.BillAmount__c,
						'quarterly payment'
					);
				} else if (diff > 3 && diff <= 6) {
					billDate = quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff - 3);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff - 3),
						billingByQuoteLine.BillDate__c,
						'Billed with difference'
					);
					System.assertEquals(
						quarterlyPayment,
						billingByQuoteLine.BillAmount__c,
						'quarterly payment'
					);
				} else if (diff > 6 && diff <= 9) {
					billDate = quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff - 6);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff - 6),
						billingByQuoteLine.BillDate__c,
						'Billed with difference'
					);
					System.assertEquals(
						quarterlyPayment,
						billingByQuoteLine.BillAmount__c,
						'quarterly payment'
					);
				} else if (diff > 9) {
					billDate = quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff - 9);
					System.assertEquals(
						quoteLineBundleParent.Ruby__SubscriptionStartDate__c.addMonths(diff - 9),
						billingByQuoteLine.BillDate__c,
						'Billed with difference'
					);
					System.assertEquals(
						quarterlyPayment,
						billingByQuoteLine.BillAmount__c,
						'quarterly payment'
					);
				}
			} else if (
				billingByQuoteLine.ELV_QuoteLine__c == quoteLineBundleParent.Id &&
				(Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) > 2 &&
				Integer.valueOf(billingByQuoteLine.BillingScheduleOrder__c) < 14)
			) {
				System.assertEquals(quarterlyPayment, billingByQuoteLine.BillAmount__c, 'Billed quarterly');
				System.assertEquals(
					priorBilling.BillDate__c.addMonths(3),
					billingByQuoteLine.BillDate__c,
					'Bill Date aligned with prior bill Date'
				);
			}
			priorBilling = billingByQuoteLine;
		}
	}

	static void deleteExistingBillingSchedules(Id opportunityId) {
		delete [SELECT Id FROM Billing_Schedule__c WHERE Opportunity__c = :opportunityId];
	}

	static Quote updateQuotePaymentType(
		Id opportunityId,
		String paymentType,
		Boolean isReverseBilling
	) {
		Quote quote = [
			SELECT ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
			FROM Quote
			WHERE OpportunityId = :opportunityId
		];
		quote.ELV_PaymentTypeNew__c = paymentType;
		quote.ELV_isReverseBilling__c = isReverseBilling;
		update quote;
		return quote;
	}

	static QuoteLineItem getFlatSKUQuoteLine(Id opportunityId) {
		return [
			SELECT
				ELV_End_Date__c,
				ELV_Bundle__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				Quote.Ruby__SubscriptionStartDate__c,
				Ruby__TotalAmount__c,
				ELV_PackageTotal__c,
				ELV_Term_Computed__c
			FROM QuoteLineItem
			WHERE
				Product2.Name = :FLAT_SKU_PRODUCT
				AND Ruby__TotalAmount__c > 0
				AND Quote.OpportunityId = :opportunityId
		];
	}

	static QuoteLineItem getBundleParentQuoteLine() {
		return [
			SELECT
				ELV_End_Date__c,
				ELV_Bundle__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				Quote.Ruby__SubscriptionStartDate__c,
				Ruby__TotalAmount__c,
				ELV_PackageTotal__c,
				ELV_Term_Computed__c
			FROM QuoteLineItem
			WHERE Product2.Name = :BUNDLE_PARENT_PRODUCT
		];
	}

	static User getAdminUser() {
		if (adminUser == null) {
			List<User> testUsers = [
				SELECT Id
				FROM User
				WHERE LastName = :TestUserFactory.TANIUM_ADMIN_USER
			];
			if (testUsers.isEmpty()) {
				adminUser = TestUserFactory.createTaniumAdminUser(true);
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