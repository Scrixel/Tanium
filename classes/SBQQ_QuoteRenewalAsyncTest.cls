/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business:	Testclass for SBQQ_QuoteRenewalAsync
 * @Author:    	Tanium Dev team
 * Modified    	ModifiedDate    Description
 * SS-6987	   	2024-01-04	   	Created the test class
 * SS-12364	   	2026-01-22	   	Added testmethod testIdentifyNewModules_WhenNewModules_ReturnNewModules
 * SS-13086	   	2026-05-19	   	Drop Level_3_Sub_Area__c from SOQL; seed Geo__c/Region__c for federal-quote detection
 * SS-13176    2026-05-27    Removed Level_3__c reference
 */
@IsTest
private class SBQQ_QuoteRenewalAsyncTest {
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
				'SubscriptionTriggerHandler',
				'UserTriggerHandler'
			}
		);
		User fedAdminUser = TestUserFactory.getAdminUser();
		update fedAdminUser;

		System.runAs(fedAdminUser) {
			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Global Pricebook description.',
				IsActive = true
			);
			insert globalPriceBook;
			List<Account> accounts = new List<Account>();
			accounts.add(TestFactory.buildAccount('Test Account 1'));
			accounts[0].Seats_Purchased1__c = 26000;
			accounts[0].Total_Addressable_Seats__c = 5000;
			accounts[0].Geo__c = 'USPS Federal';
			accounts[0].Region__c = 'US Federal';
			accounts.add(TestFactory.buildAccount('Test Account 2'));
			accounts[1].Seats_Purchased1__c = 26000;
			accounts[1].Total_Addressable_Seats__c = 5000;
			insert accounts;

			List<Opportunity> opps = new List<Opportunity>();
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity 1',
					Date.today() + 30,
					'Prospecting',
					accounts[0].Id
				)
			);
			opps[0].Type = 'New Customer';
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity 2',
					Date.today() + 30,
					'Prospecting',
					accounts[1].Id
				)
			);
			opps[1].Type = 'New Customer';
			insert opps;

			List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();
			quotes.add(
				new SBQQ__Quote__c(
					SBQQ__Account__c = accounts[0].Id,
					SBQQ__EndDate__c = Date.today().addDays(30),
					SBQQ__Opportunity2__c = opps[0].Id,
					SBQQ__PaymentTerms__c = 'Net 30',
					SBQQ__PriceBook__c = Test.getStandardPricebookId(),
					SBQQ__Primary__c = true,
					SBQQ__StartDate__c = Date.today(),
					SBQQ__Status__c = 'Accepted',
					SBQQ__SubscriptionTerm__c = 30,
					SBQQ__Type__c = 'Quote'
				)
			);
			quotes.add(
				new SBQQ__Quote__c(
					SBQQ__Account__c = accounts[1].Id,
					SBQQ__EndDate__c = Date.today().addDays(30),
					SBQQ__Opportunity2__c = opps[1].Id,
					SBQQ__PaymentTerms__c = 'Net 30',
					SBQQ__PriceBook__c = Test.getStandardPricebookId(),
					SBQQ__Primary__c = true,
					SBQQ__StartDate__c = Date.today(),
					SBQQ__Status__c = 'Accepted',
					SBQQ__SubscriptionTerm__c = 30,
					SBQQ__Type__c = 'Quote'
				)
			);
			insert quotes;

			List<Product2> products = new List<Product2>();
			products.add(
				new Product2(
					IsActive = true,
					Name = 'FLAT_SKU_PRODUCT',
					Description = 'Flat SKU Product',
					Product_Category__c = 'Hardware',
					Prorate_Billing__c = false,
					SBQQ__SubscriptionPricing__c = 'One-time'
				)
			);
			products.add(
				new Product2(
					IsActive = true,
					Name = 'PRODUCT_TO_EXCLUDE',
					Description = 'Product To Exclude',
					Product_Category__c = 'Hardware',
					Prorate_Billing__c = false,
					SBQQ__SubscriptionPricing__c = 'One-time',
					Bypass_Recalc_Batch_Job__c = true
				)
			);
			insert products;

			SBQQ__Subscription__c subscription = buildSubscription(
				accounts[0].Id,
				1,
				products[0].Id,
				1000,
				Date.today() + 100
			);
			insert subscription;
			subscription.SBQQ__AdditionalDiscountAmount__c = 5;
			update subscription;

			List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();
			quoteLines.add(
				new SBQQ__QuoteLine__c(
					SBQQ__Bundle__c = false,
					Bundled_Product__c = false,
					SBQQ__StartDate__c = Date.today() + 100,
					SBQQ__Quantity__c = 1,
					SBQQ__Quote__c = quotes[0].Id,
					SBQQ__Product__c = products[0].Id,
					SBQQ__SubscriptionTerm__c = 40,
					SBQQ__NetPrice__c = 1000,
					SBQQ__RenewedSubscription__c = subscription.Id
				)
			);
			quoteLines.add(
				new SBQQ__QuoteLine__c(
					SBQQ__Bundle__c = false,
					Bundled_Product__c = false,
					SBQQ__StartDate__c = Date.today() + 100,
					SBQQ__Quantity__c = 1,
					SBQQ__Quote__c = quotes[1].Id,
					SBQQ__Product__c = products[1].Id,
					SBQQ__SubscriptionTerm__c = 40,
					SBQQ__NetPrice__c = 1000,
					SBQQ__Discount__c = 1
				)
			);
			insert quoteLines;
		}
	}

	@IsTest
	static void testQueueableJob_WhenEmptyListOfQuotes_DoNothing() {
		List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();
		SBQQ_QuoteRenewalAsync async = new SBQQ_QuoteRenewalAsync(quotes);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			async.execute(null);
			Test.stopTest();
		}

		SBQQ__QuoteLine__c[] recalcQuoteLines = [
			SELECT Id, SBQQ__Discount__c, Uplift_Output__c
			FROM SBQQ__QuoteLine__c
		];
		Assert.isTrue(recalcQuoteLines[1].SBQQ__Discount__c != recalcQuoteLines[1].Uplift_Output__c);
	}

	@IsTest
	static void testExecute_WhenOneQuoteFirstIteration_SetSubmitSecondIterationToTrueInTestContext() {
		SBQQ__Quote__c[] quotes = [
			SELECT Id, SBQQ__Account__c
			FROM SBQQ__Quote__c
			LIMIT 1
		];
		SBQQ_QuoteRenewalAsync async = new SBQQ_QuoteRenewalAsync(quotes);
		async.doChainJob = false;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			async.execute(null);
			Test.stopTest();
		}

		Assert.isTrue(async.submitSecondIteration);
	}

	@IsTest
	static void testExecute_WhenMultipleQuotesSecondIteration_SetSubmitSecondIterationToFalseInTestContext() {
		SBQQ__Quote__c[] quotes = [
			SELECT Id, SBQQ__Account__c
			FROM SBQQ__Quote__c
		];
		SBQQ_QuoteRenewalAsync async = new SBQQ_QuoteRenewalAsync(quotes, false);
		async.doChainJob = false;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			async.execute(null);
			Test.stopTest();
		}

		Assert.isFalse(async.submitSecondIteration);
	}

	@IsTest
	static void testRecalculateQuote_WhenNonFederalQuote_ReturnDiscountEqualsUplift() {
		Account account = [SELECT Id FROM Account WHERE Name = 'Test Account 1' LIMIT 1];
		SBQQ__Quote__c quote = [
			SELECT Id
			FROM SBQQ__Quote__c
			WHERE SBQQ__Account__c = :account.Id
			LIMIT 1
		];
		Boolean isFederalQuote = false;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			SBQQ_QuoteRenewalAsync.recalculateQuote1stIteration(
				quote.Id,
				isFederalQuote,
				new Set<Id>()
			);
			SBQQ_QuoteRenewalAsync.recalculateQuote2ndIteration(quote.Id);
			Test.stopTest();
		}

		SBQQ__QuoteLine__c[] recalcQuoteLines = [
			SELECT Id, SBQQ__Discount__c, Uplift_Output__c
			FROM SBQQ__QuoteLine__c
			WHERE SBQQ__Quote__c = :quote.Id
		];
		Assert.isTrue(recalcQuoteLines[0].SBQQ__Discount__c == recalcQuoteLines[0].Uplift_Output__c);
	}

	@IsTest
	static void testRecalculateQuote_WhenFederalQuote_ReturnAdditionalDiscountAmountEquals() {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });
		Account account = [SELECT Id, OwnerId FROM Account WHERE Name = 'Test Account 1' LIMIT 1];
		SBQQ__Quote__c quote = [
			SELECT Id
			FROM SBQQ__Quote__c
			WHERE SBQQ__Account__c = :account.Id
			LIMIT 1
		];
		Boolean isFederalQuote = true;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			SBQQ_QuoteRenewalAsync.recalculateQuote1stIteration(
				quote.Id,
				isFederalQuote,
				new Set<Id>()
			);
			SBQQ_QuoteRenewalAsync.recalculateQuote2ndIteration(quote.Id);
			Test.stopTest();
		}

		SBQQ__QuoteLine__c[] recalcQuoteLines = [
			SELECT
				Id,
				SBQQ__Discount__c,
				SBQQ__RenewedSubscription__r.SBQQ__AdditionalDiscountAmount__c,
				SBQQ__AdditionalDiscountAmount__c
			FROM SBQQ__QuoteLine__c
			WHERE SBQQ__Quote__c = :quote.Id
		];
		Assert.isTrue(
			recalcQuoteLines[0].SBQQ__AdditionalDiscountAmount__c ==
			recalcQuoteLines[0].SBQQ__RenewedSubscription__r.SBQQ__AdditionalDiscountAmount__c
		);
	}

	@IsTest
	static void testRecalculateQuote_WhenOnlyExcludedProducts_DoNothing() {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });
		Account account = [SELECT Id, OwnerId FROM Account WHERE Name = 'Test Account 2' LIMIT 1];
		SBQQ__Quote__c quote = [
			SELECT Id
			FROM SBQQ__Quote__c
			WHERE SBQQ__Account__c = :account.Id
			LIMIT 1
		];
		Map<Id, Product2> productsToExcludeMap = new Map<Id, Product2>(
			[SELECT Id FROM Product2 WHERE Bypass_Recalc_Batch_Job__c = TRUE]
		);
		Boolean isFederalQuote = false;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			SBQQ_QuoteRenewalAsync.recalculateQuote1stIteration(
				quote.Id,
				isFederalQuote,
				productsToExcludeMap.keySet()
			);
			SBQQ_QuoteRenewalAsync.recalculateQuote2ndIteration(quote.Id);
			Test.stopTest();
		}

		SBQQ__QuoteLine__c[] recalcQuoteLines = [
			SELECT Id, SBQQ__Discount__c, Uplift_Output__c
			FROM SBQQ__QuoteLine__c
		];
		Assert.isTrue(recalcQuoteLines[1].SBQQ__Discount__c != recalcQuoteLines[1].Uplift_Output__c);
	}

	static SBQQ__Subscription__c buildSubscription(
		Id accountId,
		Integer qty,
		Id productId,
		Decimal netPrice,
		Date startDate
	) {
		return new SBQQ__Subscription__c(
			SBQQ__Account__c = accountId,
			SBQQ__Quantity__c = qty,
			SBQQ__Product__c = productId,
			SBQQ__NetPrice__c = netPrice,
			SBQQ__SubscriptionStartDate__c = startDate
		);
	}
}