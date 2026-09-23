/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for BillingScheduleConfigurator
 * @Date: 12/12/2024
 * @Author: Savita Mirpuri
 * RequestId  ModifiedDate  Description
 * SS-9339    2024-12-24    IsQuarterlyBillingAllowed__c allowed is tested
 * SS-10925   2025-05-20    Test more than 100 Quote Lines
 * SS-11278   2025-07-10    Remove unused method
 * SS-13619   2026-08-18    Migrated to standard Quote/QuoteLineItem and simplified test setup
 * SS-14038   2026-09-22    Test Usage exclusion and pre-tax line totals
 */
@IsTest
private class BillingScheduleConfiguratorTest {
	private static User adminUser;
	private static final String NUE_ADMIN_PERMISSION_SET = 'Nue_System_Administrations';
	static final String ANNUAL_PAYMENT_TYPE = BillingScheduleConfiguratorController.ANNUAL_PAYMENT_TYPE;
	static final String CUSTOM_PAYMENT_TYPE = BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE;
	static final String QUARTERLY_PAYMENT_TYPE = BillingScheduleConfiguratorController.QUARTERLY_PAYMENT_TYPE;
	static final String UPFRONT_PAYMENT_TYPE = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE;
	static final String FOC = BillingScheduleConfiguratorController.FOC;
	static final String FLAT_SKU_PRODUCT = 'Flat SKU Product';
	static final String BUNDLE_PARENT_PRODUCT = 'Bundle Parent Hardware';
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteTriggerHandler',
				'QuoteLineTriggerHandler',
				'BillingScheduleTriggerHandler',
				'UserTriggerHandler',
				'ELV_QuoteTriggerHandler'
			}
		);

		User adminUser = TestUserFactory.getAdminUser();
		TestingUtility.assignPermissionSet(adminUser.Id, NUE_ADMIN_PERMISSION_SET);

		System.runAs(adminUser) {
			Account account = TestFactory.buildAccount('Test Account 1');
			Account partnerAcctWithQuarterlyBillingAllowed = TestFactory.buildAccount(
				'Partner Account 1 With Quarterly Billing Allowed'
			);
			partnerAcctWithQuarterlyBillingAllowed.recordTypeId = Utility.getRecordTypeIdByAPIName(
				'Account',
				'Partner'
			);
			partnerAcctWithQuarterlyBillingAllowed.IsQuarterlyBillingAllowed__c = true;
			Account partnerAcctWithQuarterlyBillingNotAllowed = TestFactory.buildAccount(
				'Partner Account 1 With Quarterly Billing Not Allowed'
			);
			partnerAcctWithQuarterlyBillingNotAllowed.recordTypeId = Utility.getRecordTypeIdByAPIName(
				'Account',
				'Partner'
			);
			partnerAcctWithQuarterlyBillingNotAllowed.IsQuarterlyBillingAllowed__c = false;
			insert new List<Account>{
				account,
				partnerAcctWithQuarterlyBillingAllowed,
				partnerAcctWithQuarterlyBillingNotAllowed
			};

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today() + 30,
				'Prospecting',
				account.Id
			);
			opportunity.CloseDate = Date.today() + 60;
			opportunity.BillingScheduleTotalAmountNew__c = 10;
			opportunity.Business_Motion__c = 'MSP';
			insert new List<Opportunity>{ opportunity };

			Quote quote = TestFactory.buildQuote(
				'Test Quote 1',
				opportunity.Id,
				Date.today(),
				Date.today().addDays(30)
			);
			quote.Status = 'Accepted';
			quote.Ruby__PaymentTerm__c = 'Net 30';
			quote.ELV_Partner__c = partnerAcctWithQuarterlyBillingNotAllowed.Id;

			insert new List<Quote>{ quote };

			Product2 esrProduct = new Product2(
				IsActive = true,
				Name = 'ESR Product',
				Description = 'ESR Product',
				Product_Group__c = 'ESR',
				Prorate_Billing__c = false,
				SBQQ__SubscriptionPricing__c = 'Fixed Price',
				Family = 'None'
			);

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
				Ruby__ProductRecordType__c = 'Bundle',
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

			insert new List<Product2>{
				flatSKUProduct,
				bundleParentHardware,
				myBundleComponentHardware,
				esrProduct
			};

			List<PricebookEntry> pricebookEntries = new List<PricebookEntry>{
				TestFactory.buildPricebookEntry(esrProduct.Id, 0, Test.getStandardPricebookId()),
				TestFactory.buildPricebookEntry(flatSKUProduct.Id, 1000, Test.getStandardPricebookId()),
				TestFactory.buildPricebookEntry(
					bundleParentHardware.Id,
					2000,
					Test.getStandardPricebookId()
				),
				TestFactory.buildPricebookEntry(
					myBundleComponentHardware.Id,
					2000,
					Test.getStandardPricebookId()
				)
			};
			insert pricebookEntries;
			PricebookEntry esrProductPBE = pricebookEntries[0];
			PricebookEntry flatSKUProductPBE = pricebookEntries[1];
			PricebookEntry bundleParentHardwarePBE = pricebookEntries[2];
			PricebookEntry myBundleComponentHardwarePBE = pricebookEntries[3];

			Product_Promotion__c burstProductPromo = new Product_Promotion__c(
				Name = 'Burst',
				Promo_Product_Line__c = 'Client',
				Discount__c = 10,
				Start_Date__c = System.today(),
				Type__c = 'All'
			);
			Product_Promotion__c focProductPromo = new Product_Promotion__c(
				Name = FOC,
				Promo_Product_Line__c = 'Client',
				Discount__c = 10,
				Start_Date__c = System.today(),
				Type__c = 'All'
			);
			insert new List<Product_Promotion__c>{ burstProductPromo, focProductPromo };

			QuoteLineItem quoteLineFocESR = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				0,
				esrProductPBE.Id
			);
			quoteLineFocESR.Ruby__SubscriptionStartDate__c = Date.today() + 100;
			quoteLineFocESR.Ruby__SubscriptionTerm__c = 3;
			quoteLineFocESR.Ruby__TotalAmount__c = 0;
			quoteLineFocESR.Ruby__TotalPrice__c = 0;
			quoteLineFocESR.ELV_SubscriptionPricing__c = esrProduct.SBQQ__SubscriptionPricing__c;
			quoteLineFocESR.ELV_Product_Promotion__c = focProductPromo.Id;

			QuoteLineItem quoteLineBurstESR = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				0,
				esrProductPBE.Id
			);
			quoteLineBurstESR.Ruby__SubscriptionStartDate__c = Date.today() + 100;
			quoteLineBurstESR.Ruby__SubscriptionTerm__c = 3;
			quoteLineBurstESR.Ruby__TotalAmount__c = 0;
			quoteLineBurstESR.Ruby__TotalPrice__c = 0;
			quoteLineBurstESR.ELV_SubscriptionPricing__c = esrProduct.SBQQ__SubscriptionPricing__c;
			quoteLineBurstESR.ELV_Product_Promotion__c = burstProductPromo.Id;

			QuoteLineItem quoteLineFlatSKU = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				1000,
				flatSKUProductPBE.Id
			);
			quoteLineFlatSKU.ELV_Bundled_Product__c = false;
			quoteLineFlatSKU.Ruby__SubscriptionStartDate__c = Date.today() + 100;
			quoteLineFlatSKU.Ruby__SubscriptionTerm__c = 40;
			quoteLineFlatSKU.Ruby__TotalAmount__c = 1000;
			quoteLineFlatSKU.Ruby__TotalPrice__c = 1000;

			QuoteLineItem quoteLineParentBundleHardware = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				2000,
				bundleParentHardwarePBE.Id
			);
			quoteLineParentBundleHardware.ELV_Bundled_Product__c = false;
			quoteLineParentBundleHardware.Ruby__SubscriptionStartDate__c = Date.today() + 100;
			quoteLineParentBundleHardware.Ruby__SubscriptionTerm__c = 40;

			QuoteLineItem quoteLineBundleComponentHardware = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				2000,
				myBundleComponentHardwarePBE.Id
			);
			quoteLineBundleComponentHardware.ELV_Bundled_Product__c = true;
			quoteLineBundleComponentHardware.Ruby__SubscriptionStartDate__c = Date.today() + 100;
			quoteLineBundleComponentHardware.Ruby__SubscriptionTerm__c = 40;
			quoteLineBundleComponentHardware.Ruby__TotalAmount__c = 2000;
			quoteLineBundleComponentHardware.Ruby__TotalPrice__c = 2000;

			insert new List<QuoteLineItem>{
				quoteLineFocESR,
				quoteLineBurstESR,
				quoteLineFlatSKU,
				quoteLineParentBundleHardware,
				quoteLineBundleComponentHardware
			};

			Billing_Schedule__c billingSchedule1 = new Billing_Schedule__c(
				Billing_Order__c = 1,
				isReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingSchedule1.Billing_Date__c = opportunity.CloseDate;
			billingSchedule1.Billing_Amount__c = 1500;
			billingSchedule1.Opportunity__c = opportunity.Id;
			billingSchedule1.ELV_Quote__c = quote.Id;
			insert billingSchedule1;

			Billing_Schedule__c billingSchedule2 = new Billing_Schedule__c(
				Billing_Order__c = 2,
				isReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingSchedule2.Billing_Date__c = opportunity.CloseDate;
			billingSchedule2.Billing_Amount__c = 1500;
			billingSchedule2.Opportunity__c = opportunity.Id;
			billingSchedule2.ELV_Quote__c = quote.Id;
			insert billingSchedule2;

			BillingByQuoteLine__c billingFlatSKU1 = new BillingByQuoteLine__c(
				BillAmount__c = 500,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingFlatSKU1.BillingSchedule__c = billingSchedule1.Id;
			billingFlatSKU1.Opportunity__c = opportunity.Id;
			billingFlatSKU1.ELV_Quote__c = quote.Id;
			billingFlatSKU1.ELV_QuoteLine__c = quoteLineFlatSKU.Id;
			billingFlatSKU1.BillDate__c = opportunity.CloseDate;

			BillingByQuoteLine__c billingFlatSKU2 = new BillingByQuoteLine__c(
				BillAmount__c = 500,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingFlatSKU2.BillingSchedule__c = billingSchedule2.Id;
			billingFlatSKU2.Opportunity__c = opportunity.Id;
			billingFlatSKU2.ELV_Quote__c = quote.Id;
			billingFlatSKU2.ELV_QuoteLine__c = quoteLineFlatSKU.Id;
			billingFlatSKU2.BillDate__c = opportunity.CloseDate;

			BillingByQuoteLine__c billingHardwareBundle1 = new BillingByQuoteLine__c(
				BillAmount__c = 1000,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingHardwareBundle1.BillingSchedule__c = billingSchedule1.Id;
			billingHardwareBundle1.Opportunity__c = opportunity.Id;
			billingHardwareBundle1.ELV_Quote__c = quote.Id;
			billingHardwareBundle1.ELV_QuoteLine__c = quoteLineParentBundleHardware.Id;
			billingHardwareBundle1.BillDate__c = opportunity.CloseDate;

			BillingByQuoteLine__c billingHardwareBundle2 = new BillingByQuoteLine__c(
				BillAmount__c = 1000,
				BillingScheduleOrder__c = '1',
				IsReverseBilling__c = false,
				PaymentType__c = CUSTOM_PAYMENT_TYPE
			);
			billingHardwareBundle2.BillingSchedule__c = billingSchedule2.Id;
			billingHardwareBundle2.Opportunity__c = opportunity.Id;
			billingHardwareBundle2.ELV_Quote__c = quote.Id;
			billingHardwareBundle2.ELV_QuoteLine__c = quoteLineParentBundleHardware.Id;
			billingHardwareBundle2.BillDate__c = opportunity.CloseDate;
			insert new List<BillingByQuoteLine__c>{
				billingFlatSKU1,
				billingHardwareBundle1,
				billingFlatSKU2,
				billingHardwareBundle2
			};
		}
	}

	@IsTest
	static void testSaveBillingsData_whenBillingsDataJSONForUpfront_createsBillingScheduleAndRelatedRecordsForUpfront() {
		Quote quote1 = [
			SELECT
				Id,
				ELV_Do_Not_Show_Dates__c,
				ELV_BillingQuoteTerms__c,
				Ruby__PaymentTerm__c,
				OpportunityId
			FROM Quote
			WHERE Opportunity.Name = 'Test Opportunity 1'
			LIMIT 1
		];
		System.runAs(getAdminUser()) {
			quote1.ELV_Do_Not_Show_Dates__c = false;
			quote1.Ruby__PaymentTerm__c = 'Net 30';
			update quote1;
			QuoteLineItem quoteLineParentBundleHardware = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = 'Bundle Parent Hardware'
			];
			QuoteLineItem quoteLineFlatSKU = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = :FLAT_SKU_PRODUCT
			];

			List<BillingByQuoteLine__c> oldBillings = [
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote1.Id
			];
			Assert.areEqual(true, !oldBillings.isEmpty());
			List<Billing_Schedule__c> oldBillingSchedules = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote1.Id
			];
			Assert.areEqual(true, !oldBillingSchedules.isEmpty());
			String billingsDataJSON =
				'[{"billingsByQuoteLines":[{"BillAmount__c":"2000","BillDate__c":"2025-02-07","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote1.OpportunityId +
				'","Id":null,"PaymentType__c":"Upfront","ELV_Quote__c":"' +
				quote1.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2021-08-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Hardware","quoteName":"Q-38761","quoteNetAmount":3000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Hardware -  $2000","firstBillingOverride":false,"hasFOCQuoteLine":true},{"billingsByQuoteLines":[{"BillAmount__c":"1000","BillDate__c":"2025-02-07","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote1.OpportunityId +
				'","Id":null,"PaymentType__c":"Upfront","ELV_Quote__c":"' +
				quote1.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineFlatSKU.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":3000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000.00","firstBillingOverride":false,"hasFOCQuoteLine":true}]';

			Test.startTest();
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Test.stopTest();
			Assert.areEqual(true, sr.isSuccess);
			Assert.areEqual(true, String.isBlank(sr.errorMessage));
			Assert.areEqual(true, String.isBlank(sr.warningMessage));
			oldBillings = [
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillings
			];
			Assert.areEqual(true, oldBillings.isEmpty());
			List<BillingByQuoteLine__c> newBillings = [
				SELECT
					Id,
					BillAmount__c,
					BillDate__c,
					BillingSchedule__c,
					BillingScheduleOrder__c,
					isBundledProduct__c,
					isBundleParent__c,
					isFlatSKU__c,
					isReverseBilling__c,
					PaymentType__c,
					ELV_Quote__c,
					ELV_Quote__r.ELV_BillingQuoteTerms__c,
					ELV_QuoteLine__c
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote1.Id
			];
			Assert.areEqual(true, !newBillings.isEmpty());
			oldBillingSchedules = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillingSchedules
			];
			Assert.areEqual(true, oldBillings.isEmpty(), 'old billings are deleted');
			List<Billing_Schedule__c> newBillingSchedules = [
				SELECT
					Id,
					Billing_Amount__c,
					Billing_Date__c,
					Billing_Order__c,
					Invoice_Date__c,
					isReverseBilling__c,
					PaymentType__c,
					ELV_Quote__c,
					ELV_Quote__r.ELV_BillingQuoteTerms__c,
					ELV_Quote__r.ELV_isReverseBilling__c,
					ELV_Quote__r.ELV_PaymentTypeNew__c
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote1.Id
			];
			Assert.areEqual(true, !newBillingSchedules.isEmpty());
			for (BillingByQuoteLine__c eachBilling : newBillings) {
				if (eachBilling.ELV_QuoteLine__c == quoteLineParentBundleHardware.Id) {
					Assert.areEqual(2000, eachBilling.BillAmount__c, 'Same as in JSON');
				} else if (eachBilling.ELV_QuoteLine__c == quoteLineFlatSKU.Id) {
					Assert.areEqual(1000, eachBilling.BillAmount__c, 'Same as in JSON');
				}
				Assert.areEqual(
					date.newInstance(2025, 2, 7),
					eachBilling.BillDate__c,
					'Same as in JSON'
				);
				Assert.areEqual(
					newBillingSchedules[0].Id,
					eachBilling.BillingSchedule__c,
					'Child and parent are linked'
				);
				Assert.areEqual('1', eachBilling.BillingScheduleOrder__c, 'Same as in JSON');
				Assert.areEqual(UPFRONT_PAYMENT_TYPE, eachBilling.PaymentType__c, 'Same as in JSON');
				Assert.areEqual(quote1.Id, eachBilling.ELV_Quote__c, 'Same as in JSON');
			}
			for (Billing_Schedule__c eachBillingSchedule : newBillingSchedules) {
				Assert.areEqual(3000, eachBillingSchedule.Billing_Amount__c, 'Same as in JSON');
				Assert.areEqual(
					Date.newInstance(2025, 2, 7),
					eachBillingSchedule.Billing_Date__c,
					'Same as in JSON'
				);
				Assert.areEqual(1, eachBillingSchedule.Billing_Order__c);
				Assert.areEqual(
					Date.newInstance(2025, 2, 7),
					eachBillingSchedule.Invoice_Date__c,
					'Same as in JSON'
				);
				Assert.areEqual(false, eachBillingSchedule.isReverseBilling__c, 'Same as in JSON');
				Assert.areEqual(
					UPFRONT_PAYMENT_TYPE,
					eachBillingSchedule.PaymentType__c,
					'Same as in JSON'
				);
				Assert.areEqual(quote1.Id, eachBillingSchedule.ELV_Quote__c, 'Same as in JSON');
				Assert.areEqual(
					true,
					eachBillingSchedule.ELV_Quote__r.ELV_BillingQuoteTerms__c.contains(
						'' + eachBillingSchedule.Billing_Amount__c.format()
					),
					'Quote terms includes billing amount'
				);
				Assert.areEqual(
					eachBillingSchedule.isReverseBilling__c,
					eachBillingSchedule.ELV_Quote__r.ELV_isReverseBilling__c,
					'isReverse copied from billing schedule to attached quote'
				);
				Assert.areEqual(
					eachBillingSchedule.PaymentType__c,
					eachBillingSchedule.ELV_Quote__r.ELV_PaymentTypeNew__c,
					'PaymentType copied from billing schedule to attached quote'
				);
			}
			for (Quote quote2 : [
				SELECT ELV_BillingQuoteTerms__c, ELV_Do_Not_Show_Dates__c, ELV_First_Billing_Override__c
				FROM Quote
				WHERE Id = :quote1.Id
			]) {
				Assert.areNotEqual(null, quote2.ELV_BillingQuoteTerms__c);
				Assert.areNotEqual(true, quote2.ELV_Do_Not_Show_Dates__c);
				Assert.areEqual(true, !quote2.ELV_BillingQuoteTerms__c.contains('second anniversary'));
				Assert.areEqual(true, !quote2.ELV_BillingQuoteTerms__c.contains('third anniversary'));
				Assert.areEqual(
					false,
					quote2.ELV_First_Billing_Override__c,
					'First Billing Override is always false for Upfront'
				);
				Assert.areEqual(
					true,
					quote2.ELV_BillingQuoteTerms__c.contains(
						BillingScheduleConfiguratorUtility.getQuoteTermsForFirstBilling()
							.split('\\+')
							.get(2)
					)
				);
				Assert.areEqual(
					true,
					quote2.ELV_BillingQuoteTerms__c.contains(
						BillingScheduleConfiguratorUtility.getQuoteTermsForFirstBilling()
							.split('\\+')
							.get(2)
					)
				);
			}
		}
	}

	@IsTest
	static void testSaveBillingsData_whenBillingsDataJSONForAnnualReverse_createsBillingScheduleAndRelatedRecordsForAnnualReverse() {
		Quote quote1 = [
			SELECT Id, ELV_Do_Not_Show_Dates__c, Ruby__PaymentTerm__c, OpportunityId
			FROM Quote
			WHERE Opportunity.Name = 'Test Opportunity 1'
			LIMIT 1
		];
		System.runAs(getAdminUser()) {
			quote1.ELV_Do_Not_Show_Dates__c = true;
			quote1.Ruby__PaymentTerm__c = 'Net 30';
			update quote1;
			QuoteLineItem quoteLineParentBundleHardware = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = 'Bundle Parent Hardware'
			];
			QuoteLineItem quoteLineFlatSKU = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = :FLAT_SKU_PRODUCT
			];

			List<BillingByQuoteLine__c> oldBillings = [
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote1.Id
			];
			Assert.areEqual(true, !oldBillings.isEmpty());
			List<Billing_Schedule__c> oldBillingSchedules = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote1.Id
			];
			Assert.areEqual(true, !oldBillingSchedules.isEmpty());
			String billingsDataJSON =
				'[{"billingsByQuoteLines":[{"BillAmount__c":"666.00","BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":true,"Opportunity__c":"' +
				quote1.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote1.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"},{"BillAmount__c":"666.00","BillDate__c":"2022-08-01","BillingScheduleOrder__c":2,"isReverseBilling__c":true,"Opportunity__c":"' +
				quote1.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote1.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"},{"BillAmount__c":"666.00","BillDate__c":"2023-08-01","BillingScheduleOrder__c":3,"isReverseBilling__c":true,"Opportunity__c":"' +
				quote1.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote1.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":true,"isBundledProduct":false,"isProrateBilling":true,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Product","quoteName":"Q-38761","quoteNetAmount":2000.00,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Product -  $2000.00","firstBillingOverride":false,"hasFOCQuoteLine":false},{"billingsByQuoteLines":[{"BillAmount__c":1000,"BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":true,"Opportunity__c":"' +
				quote1.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote1.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Opportunity Test 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":1000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000","firstBillingOverride":false,"hasFOCQuoteLine":false}]';

			Test.startTest();
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Test.stopTest();

			Assert.areEqual(true, sr.isSuccess);
			Assert.areEqual(true, String.isBlank(sr.errorMessage));
			Assert.areEqual(true, String.isBlank(sr.warningMessage));
			oldBillings = [
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillings
			];
			Assert.areEqual(
				true,
				oldBillings.isEmpty(),
				'Old/existing billings by quote lines are deleted when saveBillingsData called'
			);

			oldBillingSchedules = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillingSchedules
			];
			Assert.areEqual(
				true,
				oldBillingSchedules.isEmpty(),
				'Old/existing billings by quote lines are deleted when saveBillingsData called'
			);

			for (BillingByQuoteLine__c eachBilling : [
				SELECT
					Id,
					BillAmount__c,
					BillDate__c,
					BillingSchedule__c,
					BillingScheduleOrder__c,
					isBundledProduct__c,
					isBundleParent__c,
					isFlatSKU__c,
					isReverseBilling__c,
					PaymentType__c,
					ELV_Quote__c,
					ELV_QuoteLine__c
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote1.Id
			]) {
				Integer billingOrder = Integer.valueOf(eachBilling.BillingScheduleOrder__c);
				switch on billingOrder {
					when 1 {
						Assert.areEqual(
							Date.newInstance(2021, 8, 1),
							eachBilling.BillDate__c,
							'Same as in JSON'
						);
						break;
					}
					when 2 {
						Assert.areEqual(
							Date.newInstance(2022, 8, 1),
							eachBilling.BillDate__c,
							'Same as in JSON'
						);
						break;
					}
					when 3 {
						Assert.areEqual(
							Date.newInstance(2023, 8, 1),
							eachBilling.BillDate__c,
							'Same as in JSON'
						);
						break;
					}
				}
				if (eachBilling.isBundleParent__c) {
					Assert.areEqual(
						true,
						eachBilling.ELV_QuoteLine__c == quoteLineParentBundleHardware.Id
					);
					Assert.areEqual(666, eachBilling.BillAmount__c, 'Same as in JSON');
				} else {
					Assert.areEqual(
						true,
						eachBilling.ELV_QuoteLine__c == quoteLineFlatSKU.Id,
						'Same as in JSON'
					);
					Assert.areEqual(1000, eachBilling.BillAmount__c, 'Same as in JSON');
				}
				Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Child always has a parent');
				Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Part of JSON');
				Assert.areEqual(true, eachBilling.isReverseBilling__c, 'Same as in JSON');
				Assert.areEqual(ANNUAL_PAYMENT_TYPE, eachBilling.PaymentType__c, 'Same as in JSON');
				Assert.areEqual(quote1.Id, eachBilling.ELV_Quote__c, 'Same as in JSON');
			}
			for (Billing_Schedule__c eachBillingSchedule : [
				SELECT
					Id,
					Billing_Amount__c,
					Billing_Date__c,
					Billing_Order__c,
					Invoice_Date__c,
					isReverseBilling__c,
					PaymentType__c,
					ELV_Quote__c,
					ELV_Quote__r.ELV_BillingQuoteTerms__c,
					ELV_Quote__r.ELV_isReverseBilling__c,
					ELV_Quote__r.ELV_PaymentTypeNew__c
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote1.Id
			]) {
				Integer billingOrder = eachBillingSchedule.Billing_Order__c.intValue();
				switch on billingOrder {
					when 1 {
						Assert.areEqual(
							eachBillingSchedule.Billing_Date__c,
							eachBillingSchedule.Invoice_Date__c,
							'Invoice date updated by Billing Schedule trigger'
						);
						Assert.areEqual(
							1666,
							eachBillingSchedule.Billing_Amount__c,
							'calculated by adding all Bill Amounts for billing order 1'
						);
						break;
					}
					when 2 {
						Assert.areEqual(
							Date.newInstance(2022, 8, 1),
							eachBillingSchedule.Billing_Date__c,
							'Same as in JSON'
						);
						Assert.areEqual(
							eachBillingSchedule.Billing_Date__c,
							eachBillingSchedule.Invoice_Date__c,
							'Invoice date updated by billing schedule trigger'
						);
						Assert.areEqual(
							667,
							eachBillingSchedule.Billing_Amount__c,
							'calculated by adding all Bill Amounts for billing order 2'
						);
						break;
					}
					when 3 {
						Assert.areEqual(
							Date.newInstance(2023, 8, 1),
							eachBillingSchedule.Billing_Date__c,
							'Same as in JSON'
						);
						Assert.areEqual(
							eachBillingSchedule.Billing_Date__c,
							eachBillingSchedule.Invoice_Date__c,
							'Invoce date updated via billing schedule trigger'
						);
						Assert.areEqual(
							666,
							eachBillingSchedule.Billing_Amount__c,
							'calculated by adding all Bill Amounts for billing order 3'
						);
						break;
					}
				}
				Assert.areEqual(true, eachBillingSchedule.isReverseBilling__c);
				Assert.areEqual(ANNUAL_PAYMENT_TYPE, eachBillingSchedule.PaymentType__c);
				Assert.areEqual(quote1.Id, eachBillingSchedule.ELV_Quote__c);
				Assert.areEqual(
					true,
					eachBillingSchedule.ELV_Quote__r.ELV_BillingQuoteTerms__c.contains(
						'' + eachBillingSchedule.Billing_Amount__c
					),
					'Quote terms includes billing amount'
				);
				Assert.areEqual(
					eachBillingSchedule.isReverseBilling__c,
					eachBillingSchedule.ELV_Quote__r.ELV_isReverseBilling__c,
					'isReverse copied from billing schedule to attached quote'
				);
				Assert.areEqual(
					eachBillingSchedule.PaymentType__c,
					eachBillingSchedule.ELV_Quote__r.ELV_PaymentTypeNew__c,
					'PaymentType copied from billing schedule to attached quote'
				);
			}
			for (Quote quote2 : [
				SELECT ELV_BillingQuoteTerms__c, ELV_Do_Not_Show_Dates__c, ELV_First_Billing_Override__c
				FROM Quote
				WHERE Id = :quote1.Id
			]) {
				Assert.areNotEqual(null, quote2.ELV_BillingQuoteTerms__c);
				Assert.areEqual(true, quote2.ELV_Do_Not_Show_Dates__c);
				Assert.areEqual(false, quote2.ELV_First_Billing_Override__c, 'Same as in JSON');
				Assert.areEqual(true, !quote2.ELV_BillingQuoteTerms__c.contains('anniversary'));
				Assert.areEqual(
					true,
					quote2.ELV_BillingQuoteTerms__c.contains('invoiced upon the Order Date and due')
				);
			}
		}

	}

	@IsTest
	static void testSaveBillingsData_whenBillingsDataJSONForAnnualNonReverse_createsBillingScheduleAndRelatedRecordsForAnnualNonReverse() {
		System.runAs(getAdminUser()) {
			Quote quote = [
				SELECT Id, OpportunityId
				FROM Quote
				WHERE Opportunity.Name = 'Test Opportunity 1'
				LIMIT 1
			];
			QuoteLineItem quoteLineParentBundleHardware = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = 'Bundle Parent Hardware'
			];
			QuoteLineItem quoteLineFlatSKU = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = :FLAT_SKU_PRODUCT
			];

			List<BillingByQuoteLine__c> oldBillings = [
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote.Id
			];
			Assert.areEqual(true, !oldBillings.isEmpty());
			List<Billing_Schedule__c> oldBillingSchedules = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote.Id
			];
			Assert.areEqual(true, !oldBillingSchedules.isEmpty());
			String billingsDataJSON =
				'[{"billingsByQuoteLines":[{"BillAmount__c":"666.00","BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"},{"BillAmount__c":"666.00","BillDate__c":"2022-08-01","BillingScheduleOrder__c":2,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"},{"BillAmount__c":"666.00","BillDate__c":"2023-08-01","BillingScheduleOrder__c":3,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":true,"isBundledProduct":false,"isProrateBilling":true,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Product","quoteName":"Q-38761","quoteNetAmount":2000.00,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Product -  $2000.00","firstBillingOverride":false,"hasFOCQuoteLine":false},{"billingsByQuoteLines":[{"BillAmount__c":1000,"BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote.OpportunityId +
				'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
				quote.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Opportunity Test 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":1000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000","firstBillingOverride":false,"hasFOCQuoteLine":false}]';

			Test.startTest();
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Test.stopTest();

			Assert.areEqual(true, sr.isSuccess);
			Assert.areEqual(true, String.isBlank(sr.errorMessage));
			Assert.areEqual(true, String.isBlank(sr.warningMessage));
			oldBillings = [
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote.Id AND Id IN :oldBillings
			];
			Assert.areEqual(
				true,
				oldBillings.isEmpty(),
				'Old/existing billings by quote lines are deleted when saveBillingsData called'
			);

			oldBillingSchedules = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote.Id AND Id IN :oldBillingSchedules
			];
			Assert.areEqual(
				true,
				oldBillingSchedules.isEmpty(),
				'Old/existing billings by quote lines are deleted when saveBillingsData called'
			);

			for (BillingByQuoteLine__c eachBilling : [
				SELECT
					Id,
					BillAmount__c,
					BillDate__c,
					BillingSchedule__c,
					BillingScheduleOrder__c,
					isBundledProduct__c,
					isBundleParent__c,
					isFlatSKU__c,
					isReverseBilling__c,
					PaymentType__c,
					ELV_Quote__c,
					ELV_QuoteLine__c
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quote.Id
			]) {
				Integer billingOrder = Integer.valueOf(eachBilling.BillingScheduleOrder__c);
				switch on billingOrder {
					when 1 {
						Assert.areEqual(
							Date.newInstance(2021, 8, 1),
							eachBilling.BillDate__c,
							'Same as in JSON'
						);
						break;
					}
					when 2 {
						Assert.areEqual(
							Date.newInstance(2022, 8, 1),
							eachBilling.BillDate__c,
							'Same as in JSON'
						);
						break;
					}
					when 3 {
						Assert.areEqual(
							Date.newInstance(2023, 8, 1),
							eachBilling.BillDate__c,
							'Same as in JSON'
						);
						break;
					}
				}
				if (eachBilling.isBundleParent__c) {
					Assert.areEqual(
						true,
						eachBilling.ELV_QuoteLine__c == quoteLineParentBundleHardware.Id
					);
					Assert.areEqual(666, eachBilling.BillAmount__c, 'Same as in JSON');
				} else {
					Assert.areEqual(
						true,
						eachBilling.ELV_QuoteLine__c == quoteLineFlatSKU.Id,
						'Same as in JSON'
					);
					Assert.areEqual(1000, eachBilling.BillAmount__c, 'Same as in JSON');
				}
				Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Child always has a parent');
				Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Part of JSON');
				Assert.areEqual(false, eachBilling.isReverseBilling__c, 'Same as in JSON');
				Assert.areEqual(ANNUAL_PAYMENT_TYPE, eachBilling.PaymentType__c, 'Same as in JSON');
				Assert.areEqual(quote.Id, eachBilling.ELV_Quote__c, 'Same as in JSON');
			}
			for (Billing_Schedule__c eachBillingSchedule : [
				SELECT
					Id,
					Billing_Amount__c,
					Billing_Date__c,
					Billing_Order__c,
					Invoice_Date__c,
					isReverseBilling__c,
					PaymentType__c,
					ELV_Quote__c,
					ELV_Quote__r.ELV_BillingQuoteTerms__c,
					ELV_Quote__r.ELV_isReverseBilling__c,
					ELV_Quote__r.ELV_PaymentTypeNew__c,
					ELV_Quote__r.ELV_First_Billing_Override__c
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote.Id
			]) {
				Integer billingOrder = eachBillingSchedule.Billing_Order__c.intValue();
				switch on billingOrder {
					when 1 {
						Assert.areEqual(
							eachBillingSchedule.Billing_Date__c,
							eachBillingSchedule.Invoice_Date__c,
							'Invoice date updated by Billing Schedule trigger'
						);
						Assert.areEqual(
							1666,
							eachBillingSchedule.Billing_Amount__c,
							'calculated by adding all Bill Amounts for billing order 1'
						);
						break;
					}
					when 2 {
						Assert.areEqual(
							Date.newInstance(2022, 8, 1),
							eachBillingSchedule.Billing_Date__c,
							'Same as in JSON'
						);
						Assert.areEqual(
							eachBillingSchedule.Billing_Date__c,
							eachBillingSchedule.Invoice_Date__c,
							'Invoice date updated by billing schedule trigger'
						);
						Assert.areEqual(
							667,
							eachBillingSchedule.Billing_Amount__c,
							'calculated by adding all Bill Amounts for billing order 2'
						);
						break;
					}
					when 3 {
						Assert.areEqual(
							Date.newInstance(2023, 8, 1),
							eachBillingSchedule.Billing_Date__c,
							'Same as in JSON'
						);
						Assert.areEqual(
							eachBillingSchedule.Billing_Date__c,
							eachBillingSchedule.Invoice_Date__c,
							'Invoce date updated via billing schedule trigger'
						);
						Assert.areEqual(
							666,
							eachBillingSchedule.Billing_Amount__c,
							'calculated by adding all Bill Amounts for billing order 3'
						);
						break;
					}
				}
				Assert.areEqual(
					false,
					eachBillingSchedule.isReverseBilling__c,
					'Same as in Billing by quote lines'
				);
				Assert.areEqual(
					ANNUAL_PAYMENT_TYPE,
					eachBillingSchedule.PaymentType__c,
					'Same as in Billing by quote lines'
				);
				Assert.areEqual(quote.Id, eachBillingSchedule.ELV_Quote__c, 'Same as in JSON');
				Assert.areEqual(
					true,
					eachBillingSchedule.ELV_Quote__r.ELV_BillingQuoteTerms__c.contains(
						'' + eachBillingSchedule.Billing_Amount__c
					),
					'Quote terms includes billing amount'
				);
				Assert.areEqual(
					eachBillingSchedule.isReverseBilling__c,
					eachBillingSchedule.ELV_Quote__r.ELV_isReverseBilling__c,
					'isReverse copied from billing schedule to attached quote'
				);
				Assert.areEqual(
					eachBillingSchedule.PaymentType__c,
					eachBillingSchedule.ELV_Quote__r.ELV_PaymentTypeNew__c,
					'PaymentType copied from billing schedule to attached quote'
				);
				Assert.areEqual(
					false,
					eachBillingSchedule.ELV_Quote__r.ELV_First_Billing_Override__c,
					'Same as in JSON'
				);
			}
		}
	}

	@IsTest
	static void testSaveBillingsData_whenBillingsDataJSONForCustom_createsBillingScheduleAndRelatedRecordsForCustom() {
		Quote quote1 = [
			SELECT Id, OpportunityId
			FROM Quote
			WHERE Opportunity.Name = 'Test Opportunity 1'
			LIMIT 1
		];
		QuoteLineItem quoteLineParentBundleHardware = [
			SELECT Id
			FROM QuoteLineItem
			WHERE Product2.Name = 'Bundle Parent Hardware'
		];
		QuoteLineItem quoteLineFlatSKU = [
			SELECT Id
			FROM QuoteLineItem
			WHERE Product2.Name = :FLAT_SKU_PRODUCT
		];

		List<BillingByQuoteLine__c> oldBillings = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE ELV_Quote__c = :quote1.Id
		];
		Assert.areEqual(true, !oldBillings.isEmpty());
		List<Billing_Schedule__c> oldBillingSchedules = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote1.Id
		];
		Assert.areEqual(true, !oldBillingSchedules.isEmpty());
		String billingsDataJSON =
			'[{"billingsByQuoteLines":[{"BillAmount__c":"666.00","BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Custom","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2022-08-01","BillingScheduleOrder__c":2,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Custom","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2023-08-01","BillingScheduleOrder__c":3,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Custom","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":true,"isBundledProduct":false,"isProrateBilling":true,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Product","quoteName":"Q-38761","quoteNetAmount":2000.00,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Product -  $2000.00","firstBillingOverride":false,"hasFOCQuoteLine":false},{"billingsByQuoteLines":[{"BillAmount__c":1000,"BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Custom","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Opportunity Test 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":1000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000","firstBillingOverride":false,"hasFOCQuoteLine":false}]';
		System.runAs(getAdminUser()) {
			Test.startTest();
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Test.stopTest();
			Assert.areEqual(true, sr.isSuccess);
			Assert.areEqual(true, String.isBlank(sr.errorMessage));
			Assert.areEqual(true, String.isBlank(sr.warningMessage));
		}

		oldBillings = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillings
		];
		Assert.areEqual(
			true,
			oldBillings.isEmpty(),
			'Old/existing billings by quote lines are deleted when saveBillingsData called'
		);

		oldBillingSchedules = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillingSchedules
		];
		Assert.areEqual(
			true,
			oldBillingSchedules.isEmpty(),
			'Old/existing billings by quote lines are deleted when saveBillingsData called'
		);

		for (BillingByQuoteLine__c eachBilling : [
			SELECT
				Id,
				BillAmount__c,
				BillDate__c,
				BillingSchedule__c,
				BillingScheduleOrder__c,
				isBundledProduct__c,
				isBundleParent__c,
				isFlatSKU__c,
				isReverseBilling__c,
				PaymentType__c,
				ELV_Quote__c,
				ELV_QuoteLine__c
			FROM BillingByQuoteLine__c
			WHERE ELV_Quote__c = :quote1.Id
		]) {
			Integer billingOrder = Integer.valueOf(eachBilling.BillingScheduleOrder__c);
			switch on billingOrder {
				when 1 {
					Assert.areEqual(
						Date.newInstance(2021, 8, 1),
						eachBilling.BillDate__c,
						'Same as in JSON'
					);
					break;
				}
				when 2 {
					Assert.areEqual(
						Date.newInstance(2022, 8, 1),
						eachBilling.BillDate__c,
						'Same as in JSON'
					);
					break;
				}
				when 3 {
					Assert.areEqual(
						Date.newInstance(2023, 8, 1),
						eachBilling.BillDate__c,
						'Same as in JSON'
					);
					break;
				}
			}
			if (eachBilling.isBundleParent__c) {
				Assert.areEqual(true, eachBilling.ELV_QuoteLine__c == quoteLineParentBundleHardware.Id);
				Assert.areEqual(666, eachBilling.BillAmount__c, 'Same as in JSON');
			} else {
				Assert.areEqual(
					true,
					eachBilling.ELV_QuoteLine__c == quoteLineFlatSKU.Id,
					'Same as in JSON'
				);
				Assert.areEqual(1000, eachBilling.BillAmount__c, 'Same as in JSON');
			}
			Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Child always has a parent');
			Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Part of JSON');
			Assert.areEqual(false, eachBilling.isReverseBilling__c, 'Same as in JSON');
			Assert.areEqual(CUSTOM_PAYMENT_TYPE, eachBilling.PaymentType__c, 'Same as in JSON');
			Assert.areEqual(quote1.Id, eachBilling.ELV_Quote__c, 'Same as in JSON');
		}
		for (Billing_Schedule__c eachBillingSchedule : [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				Invoice_Date__c,
				isReverseBilling__c,
				PaymentType__c,
				ELV_Quote__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote1.Id
		]) {
			Integer billingOrder = eachBillingSchedule.Billing_Order__c.intValue();
			switch on billingOrder {
				when 1 {
					Assert.areEqual(
						Date.newInstance(2021, 8, 1),
						eachBillingSchedule.Billing_Date__c,
						'Bill date is not same as Opp Close Date; instead it is same as BillingByQuoteLine Order 1'
					);
					Assert.areEqual(
						eachBillingSchedule.Billing_Date__c,
						eachBillingSchedule.Invoice_Date__c,
						'Invoice date updated by Billing Schedule trigger'
					);
					Assert.areEqual(
						1666,
						eachBillingSchedule.Billing_Amount__c,
						'calculated by adding all Bill Amounts for billing order 1'
					);
					break;
				}
				when 2 {
					Assert.areEqual(
						Date.newInstance(2022, 8, 1),
						eachBillingSchedule.Billing_Date__c,
						'Same as in JSON'
					);
					Assert.areEqual(
						eachBillingSchedule.Billing_Date__c,
						eachBillingSchedule.Invoice_Date__c,
						'Invoice date updated by billing schedule trigger'
					);
					Assert.areEqual(
						667,
						eachBillingSchedule.Billing_Amount__c,
						'calculated by adding all Bill Amounts for billing order 2'
					);
					break;
				}
				when 3 {
					Assert.areEqual(
						Date.newInstance(2023, 8, 1),
						eachBillingSchedule.Billing_Date__c,
						'Same as in JSON'
					);
					Assert.areEqual(
						eachBillingSchedule.Billing_Date__c,
						eachBillingSchedule.Invoice_Date__c,
						'Invoce date updated via billing schedule trigger'
					);
					Assert.areEqual(
						666,
						eachBillingSchedule.Billing_Amount__c,
						'calculated by adding all Bill Amounts for billing order 3'
					);
					break;
				}
			}
			Assert.areEqual(
				false,
				eachBillingSchedule.isReverseBilling__c,
				'Same as in billing by quote line'
			);
			Assert.areEqual(
				CUSTOM_PAYMENT_TYPE,
				eachBillingSchedule.PaymentType__c,
				'Same as in billing by quote line'
			);
			Assert.areEqual(quote1.Id, eachBillingSchedule.ELV_Quote__c, 'Same as in JSON');
			Assert.areEqual(
				true,
				eachBillingSchedule.ELV_Quote__r.ELV_BillingQuoteTerms__c.contains(
					'' + eachBillingSchedule.Billing_Amount__c
				),
				'Quote terms includes billing amount'
			);
			Assert.areEqual(
				true,
				eachBillingSchedule.ELV_Quote__r.ELV_BillingQuoteTerms__c.contains(
					'invoiced upon the Order Date'
				)
			);
			Assert.areEqual(
				eachBillingSchedule.isReverseBilling__c,
				eachBillingSchedule.ELV_Quote__r.ELV_isReverseBilling__c,
				'Same as in billing schedule'
			);
			Assert.areEqual(
				eachBillingSchedule.PaymentType__c,
				eachBillingSchedule.ELV_Quote__r.ELV_PaymentTypeNew__c,
				'Same as in billing schedule'
			);
		}
		for (Quote quote2 : [
			SELECT ELV_BillingQuoteTerms__c, ELV_Do_Not_Show_Dates__c
			FROM Quote
			WHERE Id = :quote1.Id
		]) {
			Assert.areNotEqual(null, quote2.ELV_BillingQuoteTerms__c);
			Assert.areEqual(false, quote2.ELV_Do_Not_Show_Dates__c);
			Assert.areEqual(
				true,
				quote2.ELV_BillingQuoteTerms__c.contains('invoiced upon the Order Date')
			);
			Assert.areEqual(true, quote2.ELV_BillingQuoteTerms__c.contains('on or around'));
		}
	}

	@IsTest
	static void testSaveBillingsData_whenBillingsDataJSONForQuarterly_createsBillingScheduleAndRelatedRecordsForQuarterly() {
		Quote quote1 = [
			SELECT Id, OpportunityId
			FROM Quote
			WHERE Opportunity.Name = 'Test Opportunity 1'
			LIMIT 1
		];
		QuoteLineItem quoteLineParentBundleHardware = [
			SELECT Id
			FROM QuoteLineItem
			WHERE Product2.Name = 'Bundle Parent Hardware'
		];
		QuoteLineItem quoteLineFlatSKU = [
			SELECT Id
			FROM QuoteLineItem
			WHERE Product2.Name = :FLAT_SKU_PRODUCT
		];

		List<BillingByQuoteLine__c> oldBillings = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE ELV_Quote__c = :quote1.Id
		];
		Assert.areEqual(true, !oldBillings.isEmpty());
		List<Billing_Schedule__c> oldBillingSchedules = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote1.Id
		];
		Assert.areEqual(true, !oldBillingSchedules.isEmpty());
		String billingsDataJSON =
			'[{"billingsByQuoteLines":[{"BillAmount__c":"666.00","BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Quarterly Installment","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2022-08-01","BillingScheduleOrder__c":2,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Quarterly Installment","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2023-08-01","BillingScheduleOrder__c":3,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Quarterly Installment","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":true,"isBundledProduct":false,"isProrateBilling":true,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Product","quoteName":"Q-38761","quoteNetAmount":2000.00,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Product -  $2000.00","firstBillingOverride":false,"hasFOCQuoteLine":false},{"billingsByQuoteLines":[{"BillAmount__c":1000,"BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote1.OpportunityId +
			'","Id":null,"PaymentType__c":"Quarterly Installment","ELV_Quote__c":"' +
			quote1.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Opportunity Test 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":1000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000","firstBillingOverride":false,"hasFOCQuoteLine":false}]';

		System.runAs(getAdminUser()) {
			Test.startTest();
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Test.stopTest();

			Assert.areEqual(true, sr.isSuccess);
			Assert.areEqual(true, String.isBlank(sr.errorMessage));
			Assert.areEqual(true, String.isBlank(sr.warningMessage));
		}

		oldBillings = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillings
		];
		Assert.areEqual(
			true,
			oldBillings.isEmpty(),
			'Old/existing billings by quote lines are deleted when saveBillingsData called'
		);

		oldBillingSchedules = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote1.Id AND Id IN :oldBillingSchedules
		];
		Assert.areEqual(
			true,
			oldBillingSchedules.isEmpty(),
			'Old/existing billings by quote lines are deleted when saveBillingsData called'
		);

		for (BillingByQuoteLine__c eachBilling : [
			SELECT
				Id,
				BillAmount__c,
				BillDate__c,
				BillingSchedule__c,
				BillingScheduleOrder__c,
				isBundledProduct__c,
				isBundleParent__c,
				isFlatSKU__c,
				isReverseBilling__c,
				PaymentType__c,
				ELV_Quote__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_QuoteLine__c
			FROM BillingByQuoteLine__c
			WHERE ELV_Quote__c = :quote1.Id
		]) {
			Integer billingOrder = Integer.valueOf(eachBilling.BillingScheduleOrder__c);
			switch on billingOrder {
				when 1 {
					Assert.areEqual(
						Date.newInstance(2021, 8, 1),
						eachBilling.BillDate__c,
						'Same as in JSON'
					);
					break;
				}
				when 2 {
					Assert.areEqual(
						Date.newInstance(2022, 8, 1),
						eachBilling.BillDate__c,
						'Same as in JSON'
					);
					break;
				}
				when 3 {
					Assert.areEqual(
						Date.newInstance(2023, 8, 1),
						eachBilling.BillDate__c,
						'Same as in JSON'
					);
					break;
				}
			}
			if (eachBilling.isBundleParent__c) {
				Assert.areEqual(true, eachBilling.ELV_QuoteLine__c == quoteLineParentBundleHardware.Id);
				Assert.areEqual(666, eachBilling.BillAmount__c, 'Same as in JSON');
			} else {
				Assert.areEqual(
					true,
					eachBilling.ELV_QuoteLine__c == quoteLineFlatSKU.Id,
					'Same as in JSON'
				);
				Assert.areEqual(1000, eachBilling.BillAmount__c, 'Same as in JSON');
			}
			Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Child always has a parent');
			Assert.areNotEqual(null, eachBilling.BillingSchedule__c, 'Part of JSON');
			Assert.areEqual(false, eachBilling.isReverseBilling__c, 'Same as in JSON');
			Assert.areEqual(QUARTERLY_PAYMENT_TYPE, eachBilling.PaymentType__c, 'Same as in JSON');
			Assert.areEqual(quote1.Id, eachBilling.ELV_Quote__c, 'Same as in JSON');
		}
		for (Billing_Schedule__c eachBillingSchedule : [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Date__c,
				Billing_Order__c,
				Invoice_Date__c,
				isReverseBilling__c,
				PaymentType__c,
				ELV_Quote__c,
				ELV_Quote__r.ELV_BillingQuoteTerms__c,
				ELV_Quote__r.ELV_isReverseBilling__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote1.Id
		]) {
			Integer billingOrder = eachBillingSchedule.Billing_Order__c.intValue();
			switch on billingOrder {
				when 1 {
					Assert.areEqual(
						Date.newInstance(2021, 8, 1),
						eachBillingSchedule.Billing_Date__c,
						'Bill date is not same as Opp Close Date; instead it is same as BillingByQuoteLine Order 1'
					);
					Assert.areEqual(
						eachBillingSchedule.Billing_Date__c,
						eachBillingSchedule.Invoice_Date__c,
						'Invoice date updated by Billing Schedule trigger'
					);
					Assert.areEqual(
						1666,
						eachBillingSchedule.Billing_Amount__c,
						'calculated by adding all Bill Amounts for billing order 1'
					);
					break;
				}
				when 2 {
					Assert.areEqual(
						Date.newInstance(2022, 8, 1),
						eachBillingSchedule.Billing_Date__c,
						'Same as in JSON'
					);
					Assert.areEqual(
						eachBillingSchedule.Billing_Date__c,
						eachBillingSchedule.Invoice_Date__c,
						'Invoice date updated by billing schedule trigger'
					);
					Assert.areEqual(
						667,
						eachBillingSchedule.Billing_Amount__c,
						'calculated by adding all Bill Amounts for billing order 2'
					);
					break;
				}
				when 3 {
					Assert.areEqual(
						Date.newInstance(2023, 8, 1),
						eachBillingSchedule.Billing_Date__c,
						'Same as in JSON'
					);
					Assert.areEqual(
						eachBillingSchedule.Billing_Date__c,
						eachBillingSchedule.Invoice_Date__c,
						'Invoce date updated via billing schedule trigger'
					);
					Assert.areEqual(
						666,
						eachBillingSchedule.Billing_Amount__c,
						'calculated by adding all Bill Amounts for billing order 3'
					);
					break;
				}
			}
			Assert.areEqual(
				false,
				eachBillingSchedule.isReverseBilling__c,
				'Same as in billing by quote line'
			);
			Assert.areEqual(
				QUARTERLY_PAYMENT_TYPE,
				eachBillingSchedule.PaymentType__c,
				'Same as in billing by quote line'
			);
			Assert.areEqual(quote1.Id, eachBillingSchedule.ELV_Quote__c, 'Same as in JSON');
			Assert.areEqual(
				true,
				eachBillingSchedule.ELV_Quote__r.ELV_BillingQuoteTerms__c.contains(
					'' + eachBillingSchedule.Billing_Amount__c
				),
				'Quote terms includes billing amount'
			);
			Assert.areEqual(
				true,
				eachBillingSchedule.ELV_Quote__r.ELV_BillingQuoteTerms__c.contains(
					'invoiced upon the Order Date'
				)
			);
			Assert.areEqual(
				eachBillingSchedule.isReverseBilling__c,
				eachBillingSchedule.ELV_Quote__r.ELV_isReverseBilling__c,
				'Billing schedule isReverseBilling copied to quote'
			);
			Assert.areEqual(
				eachBillingSchedule.PaymentType__c,
				eachBillingSchedule.ELV_Quote__r.ELV_PaymentTypeNew__c,
				'Billing schedule Payment Type copied to quote'
			);
		}
		for (Quote quote2 : [
			SELECT ELV_BillingQuoteTerms__c, ELV_Do_Not_Show_Dates__c
			FROM Quote
			WHERE Id = :quote1.Id
		]) {
			Assert.areNotEqual(null, quote2.ELV_BillingQuoteTerms__c);
			Assert.areEqual(false, quote2.ELV_Do_Not_Show_Dates__c);
			Assert.areEqual(
				true,
				quote2.ELV_BillingQuoteTerms__c.contains('invoiced upon the Order Date')
			);
			Assert.areEqual(true, quote2.ELV_BillingQuoteTerms__c.contains('on or around'));
		}
	}

	@IsTest
	static void testGetBillingByQuoteLines_whenCalledFromQuote_returnsBillingData() {
		TriggerHandler.bypass('QuoteTriggerHandler');
		TriggerHandler.bypass('ELV_QuoteTriggerHandler');
		List<BillingScheduleConfiguratorController.BillingData> billingData;
		Opportunity opportunity = [
			SELECT Id, Name, CloseDate
			FROM Opportunity
			WHERE Name = 'Test Opportunity 1'
		];
		Quote quote = [
			SELECT Id, Name, Ruby__SellerTotalAmount__c, ELV_Partner__c, Ruby__SubscriptionStartDate__c
			FROM Quote
			WHERE OpportunityId = :opportunity.Id
		];
		QuoteLineItem quoteLineParentBundleHardware = [
			SELECT
				Id,
				LineNumber,
				Ruby__TotalAmount__c,
				ELV_BillingQuoteLineNetTotal__c,
				ELV_PackageTotal__c,
				Product2.Name,
				ELV_End_Date__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				(SELECT Id FROM ELV_BillingByQuoteLines__r)
			FROM QuoteLineItem
			WHERE Product2.Name = 'Bundle Parent Hardware'
		];
		QuoteLineItem quoteLineBundedProduct = [
			SELECT
				Id,
				LineNumber,
				Ruby__TotalAmount__c,
				ELV_BillingQuoteLineNetTotal__c,
				ELV_PackageTotal__c,
				Product2.Name,
				ELV_End_Date__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				(SELECT Id FROM ELV_BillingByQuoteLines__r)
			FROM QuoteLineItem
			WHERE Product2.Name = :FLAT_SKU_PRODUCT
		];
		QuoteLineItem quoteLineFlatSKU = [
			SELECT
				Id,
				LineNumber,
				Ruby__TotalAmount__c,
				ELV_BillingQuoteLineNetTotal__c,
				ELV_PackageTotal__c,
				Product2.Name,
				Quote.ELV_Partner__r.IsQuarterlyBillingAllowed__c,
				ELV_End_Date__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				(SELECT Id FROM ELV_BillingByQuoteLines__r)
			FROM QuoteLineItem
			WHERE
				Product2.Name = :FLAT_SKU_PRODUCT
				AND Quote.ELV_Partner__r.IsQuarterlyBillingAllowed__c = FALSE
		];

		Test.startTest();
		System.runAs(getSalesUser()) {
			billingData = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				'' + quote.Id,
				'Quote'
			);
			Boolean hasAccess = BillingScheduleConfiguratorUtility.isSalesRepEligibleToAccessQuarterlyPayment(
				quoteLineFlatSKU
			);
			Assert.areEqual(
				hasAccess,
				false,
				'Quote.ELV_Partner__r.IsQuarterlyBillingAllowed__c is false'
			);
			quote.ELV_Partner__c = [
				SELECT Id
				FROM Account
				WHERE IsQuarterlyBillingAllowed__c = FALSE AND RecordType.Name = 'Partner'
			]
			.Id;
			update quote;
			hasAccess = BillingScheduleConfiguratorUtility.isSalesRepEligibleToAccessQuarterlyPayment(
				quoteLineFlatSKU
			);
			Assert.areEqual(
				hasAccess,
				false,
				'Quote.ELV_Partner__r.IsQuarterlyBillingAllowed__c is false'
			);
		}
		Test.stopTest();

		for (BillingScheduleConfiguratorController.BillingData eachBillingData : billingData) {
			Assert.areEqual(2, eachBillingData.billingsByQuoteLines.size(), 'default Billing Data');
			Assert.areEqual(opportunity.Name, eachBillingData.oppName, 'default Billing Data');
			Assert.areEqual(
				opportunity.CloseDate,
				eachBillingData.oppCloseDate,
				'default Billing Data'
			);
			Assert.areEqual(quote.Name, eachBillingData.quoteName, 'default Billing Data');
			Assert.areEqual(
				quote.Ruby__SellerTotalAmount__c,
				eachBillingData.quoteNetAmount,
				'default Billing Data'
			);
			Assert.areEqual(
				quote.Ruby__SubscriptionStartDate__c,
				eachBillingData.quoteStartDate,
				'default Billing Data'
			);
			if (eachBillingData.quoteLineProduct == FLAT_SKU_PRODUCT) {
				Assert.areEqual(false, eachBillingData.isBundle, 'default Billing Data');
				Assert.areEqual(false, eachBillingData.isBundledProduct, 'default Billing Data');
				Assert.areEqual(false, eachBillingData.isProrateBilling, 'default Billing Data');
				Assert.areEqual(
					quoteLineFlatSKU.ELV_BillingQuoteLineNetTotal__c,
					eachBillingData.quoteLineNetTotal,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineFlatSKU.ELV_PackageTotal__c,
					eachBillingData.quoteLinePackageTotal,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineFlatSKU.Ruby__SubscriptionStartDate__c,
					eachBillingData.quoteLineEffectiveStartDate,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineFlatSKU.Ruby__SubscriptionEndDate__c,
					eachBillingData.quoteLineEffectiveEndDate,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineFlatSKU.ELV_End_Date__c,
					eachBillingData.quoteLineEndDate,
					'default Billing Data'
				);
				String rowLabel =
					quoteLineFlatSKU.LineNumber +
					' - ' +
					quoteLineFlatSKU.Product2.Name +
					' - ' +
					' $' +
					BillingScheduleConfiguratorUtility.formatBillingAmount(
						quoteLineFlatSKU.ELV_BillingQuoteLineNetTotal__c
					);
				Assert.areEqual(rowLabel, eachBillingData.rowLabel, 'default Billing Data');
			} else if (eachBillingData.quoteLineProduct == 'Bundle Parent Hardware') {
				Assert.areEqual(false, eachBillingData.isBundledProduct, 'default Billing Data');
				Assert.areEqual(true, eachBillingData.isProrateBilling, 'default Billing Data');
				Assert.areEqual(
					quoteLineParentBundleHardware.ELV_PackageTotal__c,
					eachBillingData.quoteLineNetTotal,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineParentBundleHardware.ELV_PackageTotal__c,
					eachBillingData.quoteLinePackageTotal,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineParentBundleHardware.Ruby__SubscriptionStartDate__c,
					eachBillingData.quoteLineEffectiveStartDate,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineParentBundleHardware.Ruby__SubscriptionEndDate__c,
					eachBillingData.quoteLineEffectiveEndDate,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineParentBundleHardware.ELV_End_Date__c,
					eachBillingData.quoteLineEndDate,
					'default Billing Data'
				);
				String rowLabel =
					quoteLineParentBundleHardware.LineNumber +
					' - ' +
					quoteLineParentBundleHardware.Product2.Name +
					' - ' +
					' $' +
					BillingScheduleConfiguratorUtility.formatBillingAmount(
						quoteLineParentBundleHardware.ELV_PackageTotal__c
					);
				Assert.areEqual(
					true,
					eachBillingData.rowLabel.contains(quoteLineParentBundleHardware.LineNumber),
					'default Billing Data'
				);
				Assert.areEqual(
					true,
					eachBillingData.rowLabel.contains(quoteLineParentBundleHardware.Product2.Name),
					'default Billing Data'
				);
				Assert.areEqual(
					true,
					eachBillingData.rowLabel.contains(
						quoteLineParentBundleHardware.ELV_PackageTotal__c.format()
					),
					'default Billing Data'
				);
			} else {
				Assert.areEqual(
					false,
					eachBillingData.hasMisconfiguredBundledProduct,
					'default Billing Data'
				);
				Assert.areEqual(false, eachBillingData.isBundle, 'default Billing Data');
				Assert.areEqual(true, eachBillingData.isBundledProduct, 'default Billing Data');
				Assert.areEqual(false, eachBillingData.isProrateBilling, 'default Billing Data');
				Assert.areEqual(
					quoteLineBundedProduct.ELV_BillingQuoteLineNetTotal__c,
					eachBillingData.quoteLineNetTotal,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineBundedProduct.ELV_PackageTotal__c,
					eachBillingData.quoteLinePackageTotal,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineBundedProduct.Ruby__SubscriptionStartDate__c,
					eachBillingData.quoteLineEffectiveStartDate,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineBundedProduct.Ruby__SubscriptionEndDate__c,
					eachBillingData.quoteLineEffectiveEndDate,
					'default Billing Data'
				);
				Assert.areEqual(
					quoteLineBundedProduct.ELV_End_Date__c,
					eachBillingData.quoteLineEndDate,
					'default Billing Data'
				);
				Assert.areEqual(
					true,
					String.isBlank(eachBillingData.errorMessage),
					'default Billing Data'
				);
			}
			Assert.areNotEqual(null, eachBillingData.quoteLineName, 'default Billing Data');
			Assert.areEqual(false, eachBillingData.hasOptionType, 'default Billing Data');
			Assert.areEqual(
				true,
				String.isBlank(eachBillingData.errorMessage),
				'default Billing Data'
			);
			Assert.areEqual(
				true,
				eachBillingData.hasFOCQuoteLine,
				'One of the quote lines have FOC Product Promotion'
			);
		}
	}

	@IsTest
	static void testGetBillingByQuoteLines_whenQuoteHasNoQuoteLines_returnsErrorMessage() {
		List<BillingScheduleConfiguratorController.BillingData> billingDataNoLineItems,
			billingDataNonPrimary;
		Opportunity opportunity = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
		System.runAs(getAdminUser()) {
			Quote quoteNoLineItems = TestFactory.buildQuote(
				'Test Quote No Line Items',
				opportunity.Id,
				Date.today(),
				Date.today().addDays(365)
			);
			insert quoteNoLineItems;

			Quote quoteNonPrimary = [
				SELECT
					Id,
					Name,
					Ruby__SellerTotalAmount__c,
					Ruby__IsPrimaryQuote__c,
					Ruby__SubscriptionStartDate__c
				FROM Quote
				WHERE Ruby__SubscriptionEndDate__c != :quoteNoLineItems.Ruby__SubscriptionEndDate__c
			];
			quoteNonPrimary.Ruby__IsPrimaryQuote__c = false;
			update quoteNonPrimary;

			Test.startTest();
			billingDataNoLineItems = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				quoteNoLineItems.Id,
				'Quote'
			);
			billingDataNonPrimary = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				quoteNonPrimary.Id,
				'Quote'
			);
			Test.stopTest();
		}
		Assert.areEqual(
			System.Label.Billing_Schedule_Configurator_no_quotes_lines_error,
			billingDataNoLineItems[0].errorMessage,
			'Quotes with no quote lines should return error.'
		);
		Assert.areEqual(
			true,
			String.isBlank(billingDataNonPrimary[0].errorMessage),
			'Non-Primary Quotes allowed and should not return error.'
		);
	}

	@IsTest
	static void testGetBillingByQuoteLines_whenQuoteHasZeroNetAmount_returnsErrorMessage() {
		List<BillingScheduleConfiguratorController.BillingData> billingDataNoLineItems,
			billingDataNonPrimary;
		Opportunity opportunity = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
		System.runAs(getAdminUser()) {
			Quote quoteZeroDollar = TestFactory.buildQuote(
				'Test Quote Zero Dollar',
				opportunity.Id,
				Date.today(),
				Date.today().addDays(365)
			);
			insert quoteZeroDollar;

			Product2 flatSKUProduct = [SELECT Id FROM Product2 WHERE Name = :FLAT_SKU_PRODUCT];
			PricebookEntry flatSKUProductPBE = [
				SELECT Id
				FROM PricebookEntry
				WHERE Product2Id = :flatSKUProduct.Id AND Pricebook2Id = :Test.getStandardPricebookId()
			];
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'BillingByQuoteLineTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteCPQTriggerHandler',
					'QuoteTriggerHandler',
					'QuoteLineTriggerHandler'
				}
			);
			QuoteLineItem quoteLineFlatSKUZeroDollar = new QuoteLineItem(
				ELV_Bundled_Product__c = false,
				Ruby__SubscriptionStartDate__c = Date.today() + 100,
				Quantity = 1,
				UnitPrice = 0,
				QuoteId = quoteZeroDollar.Id,
				PricebookEntryId = flatSKUProductPBE.Id,
				Ruby__SubscriptionTerm__c = 0,
				Ruby__NetSalesPrice__c = 0
			);
			insert quoteLineFlatSKUZeroDollar;

			quoteZeroDollar.Ruby__SellerTotalAmount__c = 0;
			update quoteZeroDollar;

			Test.startTest();
			billingDataNoLineItems = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				quoteZeroDollar.Id,
				'Quote'
			);
			Test.stopTest();
		}
		Assert.areEqual(
			System.Label.Billing_Schedule_Configurator_Zero_Dollar_Quote_Error,
			billingDataNoLineItems[0].errorMessage,
			'Quotes with zero dollar net amount should return error.'
		);
	}

	@IsTest
	static void testGetBillingByQuoteLines_whenQuoteHasZeroNetAmountAndBillingExists_returnsErrorMessageAndDeleteBilling() {
		List<BillingScheduleConfiguratorController.BillingData> billingDataNoLineItems;
		Quote quote = [SELECT Id FROM Quote LIMIT 1];
		System.runAs(getAdminUser()) {
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'BillingByQuoteLineTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteCPQTriggerHandler',
					'QuoteTriggerHandler',
					'QuoteLineTriggerHandler'
				}
			);
			List<QuoteLineItem> quoteLines = [
				SELECT Id, Ruby__NetSalesPrice__c
				FROM QuoteLineItem
				WHERE QuoteId = :quote.Id
			];
			for (QuoteLineItem quoteLine : quoteLines) {
				quoteLine.Ruby__NetSalesPrice__c = 0;
			}
			update quoteLines;

			Quote quoteToZero = [SELECT Id FROM Quote WHERE Id = :quote.Id];
			quoteToZero.Ruby__SellerTotalAmount__c = 0;
			update quoteToZero;

			List<Billing_Schedule__c> billings = [
				SELECT Id, ELV_Quote__r.Ruby__SellerTotalAmount__c
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote.Id
			];
			Assert.isFalse(billings.isEmpty(), 'Billing Schedules should exists');
			Assert.isTrue(
				billings[0].ELV_Quote__r.Ruby__SellerTotalAmount__c == 0,
				'Quote Net Amount should be 0'
			);
		}
		Test.startTest();
		System.runAs(getAdminUser()) {
			billingDataNoLineItems = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				quote.Id,
				'Quote'
			);
		}
		Test.stopTest();

		List<Billing_Schedule__c> billingsAfter = [
			SELECT Id, ELV_Quote__r.Ruby__SellerTotalAmount__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote.Id
		];
		Assert.isTrue(billingsAfter.isEmpty(), 'Billing Schedules should be deleted.');
		Assert.isTrue(
			System.Label.Billing_Schedule_Configurator_Zero_Dollar_Quote_Error ==
			billingDataNoLineItems[0].errorMessage,
			'Quotes with zero dollar net amount should return error.'
		);
	}

	@IsTest
	static void testSaveBillingsData_whenException_returnsException() {
		String exceptionMsg = '';
		BillingScheduleConfiguratorController.SaveResult sr = new BillingScheduleConfiguratorController.SaveResult();
		Test.startTest();
		try {
			BillingScheduleConfiguratorController.saveBillingsData('');
		} catch (Exception e) {
			Assert.areEqual(
				true,
				BillingScheduleConfiguratorController.getErrorMessage(e).contains(e.getMessage())
			);
		}
		Test.stopTest();
	}

	@IsTest
	static void testGetBillingsData_whenException_returnsException() {
		Test.startTest();
		try {
			List<BillingScheduleConfiguratorController.BillingData> billingData = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				'',
				''
			);
		} catch (Exception e) {
			Assert.areEqual(
				true,
				BillingScheduleConfiguratorController.getErrorMessage(e).contains(e.getMessage())
			);
		}
		Test.stopTest();
	}

	@IsTest
	static void testCreateBillingScheduleAndRelatedRecords_whenException_returnsException() {
		List<BillingByQuoteLine__c> billingsByQuoteLines = new List<BillingByQuoteLine__c>(
			[SELECT Id FROM BillingByQuoteLine__c]
		);
		Test.startTest();
		try {
			BillingScheduleConfiguratorController.createBillingScheduleAndRelatedRecords(
				billingsByQuoteLines,
				Date.newInstance(2025, 2, 31),
				false
			);
		} catch (Exception e) {
			Assert.areEqual(true, e.getTypeName().contains('BillingScheduleConfigurator'));
		}
		Test.stopTest();
	}

	@IsTest
	static void testMisConfiguredBundle_whenProductMisconfigured_hasMisconfiguredBundledProductIsTrue() {
		Quote quote = [SELECT Id FROM Quote LIMIT 1];
		Product2 flatSKUProduct = [SELECT Id FROM Product2 WHERE Name = :FLAT_SKU_PRODUCT];
		PricebookEntry flatSKUProductPBE = [
			SELECT Id
			FROM PricebookEntry
			WHERE Product2Id = :flatSKUProduct.Id AND Pricebook2Id = :Test.getStandardPricebookId()
		];

		System.runAs(getAdminUser()) {
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'BillingByQuoteLineTriggerHandler',
					'OpportunityTriggerHandler',
					'OpportunityLineItemTriggerHandler',
					'QuoteCPQTriggerHandler',
					'QuoteTriggerHandler',
					'QuoteLineTriggerHandler'
				}
			);
			QuoteLineItem quoteLineWithMisconfiguredBundledProduct = new QuoteLineItem(
				ELV_Bundled_Product__c = false,
				Ruby__SubscriptionStartDate__c = Date.today() + 100,
				Quantity = 1,
				UnitPrice = 1000,
				QuoteId = quote.Id,
				PricebookEntryId = flatSKUProductPBE.Id,
				Ruby__SubscriptionTerm__c = 40,
				Ruby__NetSalesPrice__c = 1000,
				Ruby__TotalAmount__c = 1000,
				Ruby__TotalPrice__c = 1000,
				ELV_OptionType__c = 'Related Product'
			);
			insert quoteLineWithMisconfiguredBundledProduct;
			quoteLineWithMisconfiguredBundledProduct = [
				SELECT
					Id,
					LineNumber,
					ELV_Bundled_Product__c,
					ELV_End_Date__c,
					ELV_Bundle__c,
					Ruby__LineType__c,
					Ruby__TotalAmount__c,
					ELV_BillingQuoteLineNetTotal__c,
					ELV_OptionType__c,
					ELV_PackageTotal__c,
					Ruby__ProductName__c,
					Ruby__SubscriptionStartDate__c,
					Ruby__SubscriptionEndDate__c,
					Product2.Name,
					Product2.Prorate_Billing__c,
					Product2.Billing_Type__c,
					ELV_Term_Computed__c,
					QuoteId,
					Quote.Name,
					Quote.Ruby__SellerTotalAmount__c,
					Quote.OpportunityId,
					Quote.Opportunity.Name,
					Quote.Opportunity.CloseDate,
					Quote.Opportunity.Business_Motion__c,
					Quote.Ruby__IsPrimaryQuote__c,
					Quote.Ruby__SubscriptionStartDate__c,
					Quote.ELV_First_Billing_Override__c,
					Quote.ELV_Partner__r.IsQuarterlyBillingAllowed__c
				FROM QuoteLineItem
				WHERE Id = :quoteLineWithMisconfiguredBundledProduct.Id
			];
			Test.startTest();
			BillingScheduleConfiguratorController.BillingData billingData = new BillingScheduleConfiguratorController.BillingData(
				new List<BillingByQuoteLine__c>{},
				quoteLineWithMisconfiguredBundledProduct,
				quote.Id
			);
			Test.stopTest();
			Assert.areEqual(
				true,
				billingData.hasMisconfiguredBundledProduct,
				'not bundle; not bundled product; but has option type and Net Total > 0'
			);
		}
	}

	@IsTest
	static void testflatSKUs_whenQuoteLineNetTotalIsZeroOrBundledProductOrPackageTotalZeroForBundle_returnsNullOpportunityName() {
		Quote quote = [SELECT Id FROM Quote LIMIT 1];
		Product2 flatSKUProduct = [SELECT Id FROM Product2 WHERE Name = :FLAT_SKU_PRODUCT];
		Product2 bundleParentProduct = [SELECT Id FROM Product2 WHERE Name = :BUNDLE_PARENT_PRODUCT];
		PricebookEntry flatSKUProductPBE = [
			SELECT Id
			FROM PricebookEntry
			WHERE Product2Id = :flatSKUProduct.Id AND Pricebook2Id = :Test.getStandardPricebookId()
		];
		PricebookEntry bundleParentProductPBE = [
			SELECT Id
			FROM PricebookEntry
			WHERE
				Product2Id = :bundleParentProduct.Id
				AND Pricebook2Id = :Test.getStandardPricebookId()
		];
		QuoteLineItem quoteLineWithZeroNetTotal = new QuoteLineItem(
			ELV_Bundled_Product__c = false,
			Ruby__SubscriptionStartDate__c = Date.today() + 100,
			Quantity = 1,
			QuoteId = quote.Id,
			PricebookEntryId = flatSKUProductPBE.Id,
			Ruby__SubscriptionTerm__c = 40,
			Ruby__NetSalesPrice__c = 1000
		);
		QuoteLineItem quoteLineWithBundledProduct = new QuoteLineItem(
			ELV_Bundled_Product__c = true,
			Ruby__SubscriptionStartDate__c = Date.today() + 100,
			Quantity = 1,
			QuoteId = quote.Id,
			PricebookEntryId = flatSKUProductPBE.Id,
			Ruby__SubscriptionTerm__c = 40,
			Ruby__NetSalesPrice__c = 0
		);
		QuoteLineItem quoteLineParentBundleHardware = new QuoteLineItem(
			ELV_Bundled_Product__c = false,
			Ruby__SubscriptionStartDate__c = Date.today() + 100,
			Quantity = 1,
			QuoteId = quote.Id,
			PricebookEntryId = bundleParentProductPBE.Id,
			Ruby__SubscriptionTerm__c = 40,
			Ruby__NetSalesPrice__c = 0
		);
		QuoteLineItem quoteLineUsage = new QuoteLineItem(
			ELV_Bundled_Product__c = false,
			Ruby__SubscriptionStartDate__c = Date.today() + 100,
			Quantity = 1,
			QuoteId = quote.Id,
			PricebookEntryId = flatSKUProductPBE.Id,
			Ruby__SubscriptionTerm__c = 40,
			Ruby__NetSalesPrice__c = 1000,
			Ruby__TotalAmount__c = 1000,
			Product2 = new Product2(
				Billing_Type__c = BillingScheduleConfiguratorController.USAGE_BILLING_TYPE
			)
		);
		QuoteLineItem quoteLineSummary = new QuoteLineItem(
			ELV_Bundled_Product__c = false,
			Ruby__SubscriptionStartDate__c = Date.today() + 100,
			Quantity = 1,
			QuoteId = quote.Id,
			PricebookEntryId = flatSKUProductPBE.Id,
			Ruby__SubscriptionTerm__c = 40,
			Ruby__NetSalesPrice__c = 1000,
			Ruby__TotalAmount__c = 1000,
			Ruby__LineType__c = BillingScheduleConfiguratorController.SUMMARY_LINE_TYPE
		);
		System.runAs(getAdminUser()) {
			Test.startTest();
			BillingScheduleConfiguratorController.BillingData billingData = new BillingScheduleConfiguratorController.BillingData(
				null,
				quoteLineWithZeroNetTotal,
				quote.Id
			);
			Test.stopTest();
			Assert.areEqual(
				null,
				billingData.oppName,
				'this billingData will not be returned to user in Configurator'
			);

			billingData = new BillingScheduleConfiguratorController.BillingData(
				null,
				quoteLineWithBundledProduct,
				quote.Id
			);
			Assert.areEqual(
				null,
				billingData.oppName,
				'this billingData will not be returned to user in Configurator'
			);

			billingData = new BillingScheduleConfiguratorController.BillingData(
				null,
				quoteLineParentBundleHardware,
				quote.Id
			);
			Assert.areEqual(
				null,
				billingData.oppName,
				'this billingData will not be returned to user in Configurator'
			);

			billingData = new BillingScheduleConfiguratorController.BillingData(
				null,
				quoteLineUsage,
				quote.Id
			);
			Assert.areEqual(null, billingData.oppName, 'Usage SKU is excluded from Configurator');

			billingData = new BillingScheduleConfiguratorController.BillingData(
				null,
				quoteLineSummary,
				quote.Id
			);
			Assert.areEqual(null, billingData.oppName, 'Summary line is excluded from Configurator');
		}
	}

	@IsTest
	static void profileHasAccessToConfiguratorTool_whenOppStageIsRestrictedAndProfileIsNotAllowed_ReturnFalse() {
		TriggerHandler.bypass(new List<String>{ 'OpportunityTriggerHandler', 'UserTriggerHandler' });

		Opportunity opp;
		User salesUser = TestUserFactory.createTaniumStandardUser();
		insert salesUser;

		System.runAs(getAdminUser()) {
			opp = [SELECT Id, StageName, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
			opp.StageName = 'Closed Won';
			opp.BillingScheduleTotalAmountNew__c = 10;
			opp.Amount = 10;
			opp.OwnerId = salesUser.Id;
			update opp;
		}

		System.runAs(salesUser) {
			Test.startTest();
			opp = [SELECT Id, StageName, AccountId FROM Opportunity WHERE Name = 'Test Opportunity 1'];
			Boolean actual = BillingScheduleConfiguratorController.profileHasAccessToConfiguratorTool(
				opp.StageName
			);

			Test.stopTest();
			Assert.areEqual(false, actual, 'Sales Rep not allowed to access tool for closed won opp');
		}
	}

	@IsTest
	static void profileHasAccessToConfiguratorTool_whenOppStageIsRestrictedAndProfileIsAllowed_ReturnTrue() {
		TriggerHandler.bypass('OpportunityTriggerHandler');

		System.runAs(getAdminUser()) {
			Opportunity opp = [
				SELECT Id, StageName
				FROM Opportunity
				WHERE Name = 'Test Opportunity 1'
			];
			opp.StageName = 'Closed Won';
			opp.BillingScheduleTotalAmountNew__c = 10;
			opp.Amount = 10;
			update opp;

			Test.startTest();
			Boolean actual = BillingScheduleConfiguratorController.profileHasAccessToConfiguratorTool(
				opp.StageName
			);
			Test.stopTest();

			Assert.areEqual(true, actual, 'Admin profile has access to tool on closed won opp');
		}
	}

	@IsTest
	static void profileHasRestrictedPaymentAccess_whenProfileIsInMetadata_ReturnTrue() {
		TriggerHandler.bypass('UserTriggerHandler');
		System.runAs(getAdminUser()) {
			Test.startTest();
			Boolean actual = BillingScheduleConfiguratorController.profileHasRestrictedPaymentAccess();
			Assert.areEqual(true, actual);
			Test.stopTest();
		}
	}

	@IsTest
	static void profileHasRestrictedPaymentAccess_whenProfileIsNotInMetadata_ReturnFalse() {
		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			Boolean actual = BillingScheduleConfiguratorController.profileHasRestrictedPaymentAccess();
			Assert.areEqual(false, actual);
			Test.stopTest();
		}
	}

	@IsTest
	static void hasUserFacingErrorMessage_whenTrue_ReturnsErrorMessageCustomLabelsAccurately() {
		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			Assert.areEqual(
				System.Label.Billing_Schedule_Configurator_locking_error,
				BillingScheduleConfiguratorController.getUserFacingErrorMessage('UNABLE_TO_LOCK_ROW')
			);
			Assert.areEqual(
				System.Label.Billing_Schedule_Configurator_Retry_Error_Message,
				BillingScheduleConfiguratorController.getUserFacingErrorMessage('ENTITY_IS_DELETED')
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void getBillingByQuoteLines_WhenQuoteLineHasBlankStartDate_ReturnCustomLabelMessage() {
		SBQQ.TriggerControl.disable();
		List<BillingScheduleConfiguratorController.BillingData> allBillingsData;
		Quote quote = [SELECT Id, Ruby__SubscriptionStartDate__c FROM Quote LIMIT 1];
		quote.Ruby__SubscriptionStartDate__c = null;
		update quote;
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteTriggerHandler',
				'QuoteLineTriggerHandler',
				'BillingScheduleTriggerHandler',
				'UserTriggerHandler'
			}
		);
		List<QuoteLineItem> quoteLines = [
			SELECT Id, Ruby__SubscriptionStartDate__c, QuoteId, Quote.Ruby__SubscriptionStartDate__c
			FROM QuoteLineItem
			WHERE QuoteId = :quote.Id AND ELV_Product_Promotion__c = NULL
		];
		quoteLines[0].Ruby__SubscriptionStartDate__c = null;
		update quoteLines;

		Test.startTest();
		System.runAs(getAdminUser()) {
			allBillingsData = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				quote.Id,
				'Quote'
			);
		}
		Test.stopTest();

		Assert.areEqual(
			System.Label.Billing_Schedule_Configurator_Blank_Dates_Error,
			allBillingsData[0].errorMessage,
			'Quote Line with blank start date should return error'
		);
	}

	@IsTest
	static void getBillingByQuoteLines_WhenQuoteLineHasFOCProductPromo_ReturnTrue() {
		SBQQ.TriggerControl.disable();
		List<BillingScheduleConfiguratorController.BillingData> allBillingsData;
		Quote quote = [SELECT Id FROM Quote LIMIT 1];

		Test.startTest();
		System.runAs(getAdminUser()) {
			allBillingsData = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				quote.Id,
				'Quote'
			);
		}
		Test.stopTest();

		Assert.areEqual(true, allBillingsData[0].hasFOCQuoteLine, 'hasFOCQuoteLine should be true.');
	}

	@IsTest
	static void getBillingByQuoteLines_WhenQuoteLineHasNoFOCProductPromo_ReturnFalse() {
		SBQQ.TriggerControl.disable();
		List<BillingScheduleConfiguratorController.BillingData> allBillingsData;
		Quote quote = [SELECT Id FROM Quote LIMIT 1];

		List<QuoteLineItem> quoteLines = [
			SELECT Id
			FROM QuoteLineItem
			WHERE ELV_Product_Promotion__r.Name = :FOC
		];
		delete quoteLines;

		Test.startTest();
		System.runAs(getAdminUser()) {
			allBillingsData = BillingScheduleConfiguratorController.getBillingByQuoteLines(
				quote.Id,
				'Quote'
			);
		}
		Test.stopTest();

		Assert.areEqual(
			false,
			allBillingsData[0].hasFOCQuoteLine,
			'hasFOCQuoteLine should be false.'
		);
	}

	@IsTest
	static void testGetErrorsInQuote_whenQuoteLineHasBlankComputedValue_ReturnErrorMessageForBlankComputedValue() {
		System.runAs(getAdminUser()) {
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'UserTriggerHandler',
					'QuoteCPQTriggerHandler',
					'QuoteLineTriggerHandler'
				}
			);
			Quote quote = [
				SELECT Id, Opportunity.StageName
				FROM Quote
				LIMIT 1
			];
			quote.Ruby__SubscriptionEndDate__c = null;
			update quote;
			QuoteLineItem quoteLine = [
				SELECT Id, Ruby__SubscriptionEndDate__c, Ruby__SubscriptionTerm__c
				FROM QuoteLineItem
				LIMIT 1
			];
			quoteLine.Ruby__SubscriptionEndDate__c = null;
			quoteLine.Ruby__SubscriptionTerm__c = null;
			update quoteLine;
			quoteLine = [
				SELECT
					Id,
					Ruby__SubscriptionStartDate__c,
					Ruby__SubscriptionEndDate__c,
					Quote.Ruby__SubscriptionStartDate__c,
					Quote.Ruby__SubscriptionEndDate__c,
					Quote.Ruby__SellerTotalAmount__c,
					Quote.ELV_PaymentTypeNew__c,
					Quote.OpportunityId,
					Quote.Opportunity.StageName,
					ELV_Term_Computed__c
				FROM QuoteLineItem
				WHERE Id = :quoteLine.Id
			];
			Assert.areEqual(0, quoteLine.ELV_Term_Computed__c);
			Test.startTest();
			Boolean valueForNullComputedTermError = BillingScheduleConfiguratorController.hasBlankTermComputed(
				new List<QuoteLineItem>{ quoteLine }
			);
			List<BillingScheduleConfiguratorController.BillingData> allBillingsData = BillingScheduleConfiguratorController.getErrorsInQuote(
				new List<QuoteLineItem>{ quoteLine }
			);
			Test.stopTest();
			Assert.areEqual(
				true,
				valueForNullComputedTermError,
				'Error shown to user due to Null Term Computed'
			);
			Assert.areEqual(
				System.Label.Billing_Schedule_Configurator_Blank_Term_Computed,
				allBillingsData[0].errorMessage,
				'Error shown to user due to Disable Validation Rules permission set'
			);
		}
	}

	@IsTest
	static void testSaveBillingsData_whenBillingsDataJSONForAnnualFirstBillingOverride_createRecordsForAnnualReverse() {
		Quote quote = [
			SELECT Id, ELV_isReverseBilling__c, ELV_First_Billing_Override__c, OpportunityId
			FROM Quote
			WHERE Opportunity.Name = 'Test Opportunity 1'
			LIMIT 1
		];
		Assert.isTrue(
			quote.ELV_First_Billing_Override__c == false,
			'First Billing Override is false initially.'
		);
		Assert.isTrue(quote.ELV_isReverseBilling__c == false, 'Reverse Billing is false initially.');

		QuoteLineItem quoteLineParentBundleHardware = [
			SELECT Id
			FROM QuoteLineItem
			WHERE Product2.Name = 'Bundle Parent Hardware'
		];
		String billingsDataJSON =
			'[{"billingsByQuoteLines":[{"BillAmount__c":"666.00","BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":true,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2022-08-01","BillingScheduleOrder__c":2,"isReverseBilling__c":true,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2023-08-01","BillingScheduleOrder__c":3,"isReverseBilling__c":true,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":true,"isBundledProduct":false,"isProrateBilling":true,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Product","quoteName":"Q-38761","quoteNetAmount":2000.00,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Product -  $2000.00","firstBillingOverride":true,"hasFOCQuoteLine":false},{"billingsByQuoteLines":[{"BillAmount__c":1000,"BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":true,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Opportunity Test 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":1000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000","firstBillingOverride":true,"hasFOCQuoteLine":false}]';

		Test.startTest();
		System.runAs(getAdminUser()) {
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Assert.isTrue(sr.isSuccess, 'saveBillingsData should succeed.');
			Assert.isTrue(String.isBlank(sr.errorMessage), 'No error message should be returned.');
			Assert.isTrue(String.isBlank(sr.warningMessage), 'No warning message should be returned.');
		}
		Test.stopTest();

		Quote updatedQuote = [
			SELECT ELV_isReverseBilling__c, ELV_First_Billing_Override__c
			FROM Quote
			WHERE Id = :quote.Id
		];
		Assert.isTrue(
			updatedQuote.ELV_First_Billing_Override__c == true,
			'First Billing Override should be true. Same as JSON.'
		);
		Assert.isTrue(
			updatedQuote.ELV_isReverseBilling__c == true,
			'Reverse Billing should be true. Same as JSON.'
		);
	}

	@IsTest
	static void testSaveBillingsData_whenBillingsDataJSONForAnnualNotFirstBillingOverride_createRecordsForAnnual_ReverseBillingDependsOnJSON() {
		Quote quote = [
			SELECT Id, ELV_isReverseBilling__c, ELV_First_Billing_Override__c, OpportunityId
			FROM Quote
			WHERE Opportunity.Name = 'Test Opportunity 1'
			LIMIT 1
		];
		quote.ELV_isReverseBilling__c = true;
		update quote;

		Assert.isTrue(
			quote.ELV_First_Billing_Override__c == false,
			'First Billing Override is false initially.'
		);
		Assert.isTrue(quote.ELV_isReverseBilling__c == true, 'Reverse Billing is true initially.');

		QuoteLineItem quoteLineParentBundleHardware = [
			SELECT Id
			FROM QuoteLineItem
			WHERE Product2.Name = 'Bundle Parent Hardware'
		];

		String billingsDataJSON =
			'[{"billingsByQuoteLines":[{"BillAmount__c":"666.00","BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2022-08-01","BillingScheduleOrder__c":2,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"},{"BillAmount__c":"666.00","BillDate__c":"2023-08-01","BillingScheduleOrder__c":3,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":true,"isBundledProduct":false,"isProrateBilling":true,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Product","quoteName":"Q-38761","quoteNetAmount":2000.00,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Product -  $2000.00","firstBillingOverride":false,"hasFOCQuoteLine":false},{"billingsByQuoteLines":[{"BillAmount__c":1000,"BillDate__c":"2021-08-01","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
			quote.OpportunityId +
			'","Id":null,"PaymentType__c":"Annual Installment","ELV_Quote__c":"' +
			quote.Id +
			'","ELV_QuoteLine__c":"' +
			quoteLineParentBundleHardware.Id +
			'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Opportunity Test 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":1000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000","firstBillingOverride":false,"hasFOCQuoteLine":false}]';

		System.runAs(getAdminUser()) {
			Test.startTest();
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Assert.isTrue(sr.isSuccess, 'saveBillingsData should succeed.');
			Assert.isTrue(String.isBlank(sr.errorMessage), 'No error message should be returned.');
			Assert.isTrue(String.isBlank(sr.warningMessage), 'No warning message should be returned.');
			Test.stopTest();
		}

		Quote updatedQuote = [
			SELECT ELV_isReverseBilling__c, ELV_First_Billing_Override__c
			FROM Quote
			WHERE Id = :quote.Id
		];
		Assert.isTrue(
			updatedQuote.ELV_First_Billing_Override__c == false,
			'First Billing Override still should be false. Same as JSON.'
		);
		Assert.isTrue(
			updatedQuote.ELV_isReverseBilling__c == false,
			'Reverse Billing should be false. Same as JSON.'
		);
	}

	@IsTest
	static void testSaveBillingsData_whenExistingBillingIsRestricted_SalesCanUpdateToUpfrontOrAnnual() {
		Quote quote;
		User salesUser = TestUserFactory.createTaniumStandardUser();
		insert salesUser;
		TestingUtility.assignPermissionSet(salesUser.Id, 'BillingScheduleConfigurator');
		TestingUtility.assignPermissionSet(salesUser.Id, 'DisableFlows');
		TestingUtility.assignPermissionSet(salesUser.Id, 'DisableValidationRules');
		QuoteLineItem quoteLineParentBundleHardware, quoteLineFlatSKU;
		System.runAs(getAdminUser()) {
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'UserTriggerHandler',
					'QuoteCPQTriggerHandler',
					'QuoteTriggerHandler',
					'ELV_QuoteTriggerHandler'
				}
			);

			Opportunity opp = new Opportunity();
			System.runAs(getAdminUser()) {
				opp = [SELECT Id, Type, StageName FROM Opportunity WHERE Name = 'Test Opportunity 1'];
				opp.Type = 'Renewal';
				opp.StageName = 'Uncommitted Renewal';
				update opp;
			}

			quote = [SELECT Id, OpportunityId FROM Quote LIMIT 1];
			List<Billing_Schedule__c> existingBillingScheds = [
				SELECT Id, ELV_Quote__c, PaymentType__c
				FROM Billing_Schedule__c
				WHERE ELV_Quote__c = :quote.Id
			];

			quoteLineParentBundleHardware = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = 'Bundle Parent Hardware'
			];
			quoteLineFlatSKU = [
				SELECT Id
				FROM QuoteLineItem
				WHERE Product2.Name = :FLAT_SKU_PRODUCT
			];

			Assert.areEqual(
				CUSTOM_PAYMENT_TYPE,
				existingBillingScheds[0].PaymentType__c,
				'Existing Billing Config should be Custom'
			);
		}

		System.runAs(salesUser) {
			String billingsDataJSON =
				'[{"billingsByQuoteLines":[{"BillAmount__c":"2000","BillDate__c":"2025-02-07","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote.OpportunityId +
				'","Id":null,"PaymentType__c":"Upfront","ELV_Quote__c":"' +
				quote.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineParentBundleHardware.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2021-08-31","quoteLineName":"QL-0492793","quoteLineNetTotal":2000,"quoteLinePackageTotal":2000,"quoteLineProduct":"Bundle Parent Hardware","quoteName":"Q-38761","quoteNetAmount":3000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0492793 - Bundle Parent Hardware -  $2000","firstBillingOverride":false,"hasFOCQuoteLine":false},{"billingsByQuoteLines":[{"BillAmount__c":"1000","BillDate__c":"2025-02-07","BillingScheduleOrder__c":1,"isReverseBilling__c":false,"Opportunity__c":"' +
				quote.OpportunityId +
				'","Id":null,"PaymentType__c":"Upfront","ELV_Quote__c":"' +
				quote.Id +
				'","ELV_QuoteLine__c":"' +
				quoteLineFlatSKU.Id +
				'"}],"errorMessage":"","hasMisconfiguredBundledProduct":false,"hasOptionType":false,"isBundle":false,"isBundledProduct":false,"isProrateBilling":false,"oppCloseDate":"2025-02-07","oppName":"Test Opportunity 1","quoteLineEffectiveStartDate":"2021-08-01","quoteLineEndDate":"2024-07-31","quoteLineName":"QL-0493566","quoteLineNetTotal":1000,"quoteLinePackageTotal":1000,"quoteLineProduct":"Flat SKU Product","quoteName":"Q-38761","quoteNetAmount":3000,"quoteStartDate":"2021-08-01","rowLabel":"QL-0493566 - Flat SKU Product -  $1000.00", "firstBillingOverride":false,"hasFOCQuoteLine":false}]';

			Test.startTest();
			BillingScheduleConfiguratorController.SaveResult sr = BillingScheduleConfiguratorController.saveBillingsData(
				billingsDataJSON
			);
			Test.stopTest();
			Assert.areEqual('', sr.errorMessage);
			Assert.areEqual(true, sr.isSuccess);
			Assert.areEqual(true, String.isBlank(sr.errorMessage));
			Assert.areEqual(true, String.isBlank(sr.warningMessage));
		}

		List<Billing_Schedule__c> newBillingSchedules = [
			SELECT Id, PaymentType__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quote.Id
		];
		Assert.areEqual(false, newBillingSchedules.isEmpty());

		for (Billing_Schedule__c eachBillingSchedule : newBillingSchedules) {
			Assert.areEqual(
				UPFRONT_PAYMENT_TYPE,
				eachBillingSchedule.PaymentType__c,
				'Same as in JSON'
			);
		}
	}

	@IsTest
	static void testgetBillingByQuoteLines_WhenQuoteHasHundredPlusQuoteLines_returnBillingData() {
		List<BillingScheduleConfiguratorController.BillingData> billingData;
		Quote quote = [SELECT Id FROM Quote LIMIT 1];
		Product2 product = [SELECT Id FROM Product2 LIMIT 1];
		PricebookEntry productPBE = [
			SELECT Id
			FROM PricebookEntry
			WHERE Product2Id = :product.Id AND Pricebook2Id = :Test.getStandardPricebookId()
		];
		Boolean exceptionThrown = false;

		System.runAs(getAdminUser()) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass('QuoteLineTriggerHandler');
			List<QuoteLineItem> quoteLines = new List<QuoteLineItem>();
			for (Integer i = 1; i <= 120; i++) {
				quoteLines.add(
					new QuoteLineItem(
						QuoteId = quote.Id,
						PricebookEntryId = productPBE.Id,
						Quantity = 100,
						UnitPrice = 100
					)
				);
			}
			insert quoteLines;

			Test.startTest();
			try {
				billingData = BillingScheduleConfiguratorController.getBillingByQuoteLines(
					'' + quote.Id,
					'Quote'
				);
			} catch (Exception e) {
				exceptionThrown = true;
			}
			Test.stopTest();
		}

		Assert.isFalse(exceptionThrown);
	}

	static User getAdminUser() {
		User[] adminUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.TANIUM_ADMIN_USER];
		if (adminUsers.isEmpty()) {
			adminUser = TestUserFactory.createTaniumAdminUser(false);
			insert adminUser;
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');
			TestingUtility.assignPermissionSet(adminUser.Id, 'BillingScheduleConfigurator');
			return adminUser;
		}
		return adminUsers[0];
	}

	static User getSalesUser() {
		User taniumSalesUser = TestFactory.getTaniumSalesUser();
		insert taniumSalesUser;
		TestingUtility.assignPermissionSet(taniumSalesUser.Id, 'DisableFlows');
		TestingUtility.assignPermissionSet(taniumSalesUser.Id, 'DisableValidationRules');
		return taniumSalesUser;
	}
}