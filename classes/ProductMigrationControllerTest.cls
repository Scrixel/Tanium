/**
 *  Copyright (c) 2025 Tanium
 *
 * @Business: Test class for ProductMigrationController
 * @Authors:  Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-10411   2025-03-08    Created the test class
 * SS-11649   2025-09-24    Updated the test class
 * SS-11576   2025-12-11    Added test method testGetOtherRenewableProducts_WhenNoRenewableProducts_ReturnEmptyList
 * SS-13048   2026-04-14    Updated test class to bypass SubscriptionTriggerHandler
 * SS-13771   2026-08-18    Updated class as part of Elevate project
 */
@IsTest
private class ProductMigrationControllerTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'ELV_QuoteTriggerHandler',
				'ELV_QuoteLineTriggerHandler',
				'QuoteTriggerHandler',
				'QuoteLineTriggerHandler',
				'SubscriptionTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			account.Segment__c = 'Enterprise';
			account.Ineligible_for_Migration_Calculation__c = false;
			Account invalidAemAccount = TestFactory.buildAccount('Test Account');
			invalidAemAccount.Segment__c = 'Enterprise';
			invalidAemAccount.Ineligible_for_Migration_Calculation__c = true;
			invalidAemAccount.Ineligible_for_Migration_Calc_Reason__c = 'Account is ineligible for migration calculation.';
			insert new List<Account>{ account, invalidAemAccount };

			Opportunity opp1 = TestFactory.buildOpportunity(
				'Test Opportunity1',
				System.today().addDays(120),
				'New',
				account.Id
			);

			opp1.EndDate__c = System.today().addDays(120);
			opp1.MaxQuantity__c = 10;

			Opportunity opp2 = TestFactory.buildOpportunity(
				'Test Opportunity2',
				System.today().addDays(120),
				'New',
				account.Id
			);

			Opportunity opp3 = TestFactory.buildOpportunity(
				'Invalid Opportunity For AEM Migration',
				System.today().addDays(120),
				'New',
				invalidAemAccount.Id
			);

			insert new List<Opportunity>{ opp1, opp2, opp3 };

			Product2 product1 = TestFactory.buildProduct('Tanium-Asset', 'TAN-ASSET');
			product1.Product_Group__c = 'Software';
			product1.Product_Type__c = 'Subscription';
			product1.Family = 'None';
			Product2 product2 = TestFactory.buildProduct('Tanium-Deploy', 'TAN-DEPLOY');
			product2.Product_Group__c = 'Software';
			product2.Product_Type__c = 'TaaS';
			product2.Family = 'None';
			Product2 product3 = TestFactory.buildProduct('Tanium-Core', 'TAN-CORE');
			product3.Product_Group__c = 'Software';
			product3.Product_Type__c = 'Subscription';
			product3.Family = 'None';
			Product2 product4 = TestFactory.buildProduct('Tanium-Discover', 'TAN-DISC');
			product4.Product_Group__c = 'Software';
			product4.Product_Type__c = 'TaaS';
			product4.Family = 'None';
			insert new List<Product2>{ product1, product2, product3, product4 };

			PricebookEntry pricebookEntry1 = TestFactory.buildPricebookEntry(
				product1.Id,
				99.00,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			PricebookEntry pricebookEntry2 = TestFactory.buildPricebookEntry(
				product2.Id,
				49.00,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			PricebookEntry pricebookEntry3 = TestFactory.buildPricebookEntry(
				product3.Id,
				19.00,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			PricebookEntry pricebookEntry4 = TestFactory.buildPricebookEntry(
				product4.Id,
				19.00,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			insert new List<PricebookEntry>{
				pricebookEntry1,
				pricebookEntry2,
				pricebookEntry3,
				pricebookEntry4
			};

			Module__c assetModule = new Module__c(Name = 'Asset', Module_Description__c = 'Asset');
			Module__c deployModule = new Module__c(Name = 'Deploy', Module_Description__c = 'Deploy');
			Module__c coreModule = new Module__c(Name = 'Core', Module_Description__c = 'Core');
			Module__c discoverModule = new Module__c(
				Name = 'Discover',
				Module_Description__c = 'Discover'
			);
			insert new List<Module__c>{ assetModule, deployModule, coreModule, discoverModule };

			Product_Module__c assetProductModule = new Product_Module__c(
				Product__c = product1.Id,
				Module__c = assetModule.Id
			);
			Product_Module__c deployProductModule = new Product_Module__c(
				Product__c = product2.Id,
				Module__c = deployModule.Id
			);
			Product_Module__c coreProductModule = new Product_Module__c(
				Product__c = product3.Id,
				Module__c = coreModule.Id
			);
			Product_Module__c discoverProductModule = new Product_Module__c(
				Product__c = product4.Id,
				Module__c = discoverModule.Id
			);
			insert new List<Product_Module__c>{
				assetProductModule,
				deployProductModule,
				coreProductModule,
				discoverProductModule
			};

			Quote quote1 = TestFactory.buildQuote(
				'Quote1',
				opp1.Id,
				System.today(),
				System.today().addMonths(3)
			);
			Quote quote2 = TestFactory.buildQuote(
				'Quote2',
				opp2.Id,
				System.today(),
				System.today().addMonths(3)
			);
			insert new List<Quote>{ quote1, quote2 };

			QuoteLineItem quoteLine1a_1 = TestFactory.buildQuoteLineItem(
				quote1.Id,
				10,
				4.63,
				pricebookEntry1.Id
			);

			QuoteLineItem quoteLine1b_1 = TestFactory.buildQuoteLineItem(
				quote1.Id,
				10,
				4.63,
				pricebookEntry1.Id
			);

			QuoteLineItem quoteLine2_1 = TestFactory.buildQuoteLineItem(
				quote1.Id,
				10,
				4.63,
				pricebookEntry2.Id
			);

			QuoteLineItem quoteLine3a_1 = TestFactory.buildQuoteLineItem(
				quote1.Id,
				10,
				4.63,
				pricebookEntry3.Id
			);

			QuoteLineItem quoteLine3b_1 = TestFactory.buildQuoteLineItem(
				quote1.Id,
				10,
				4.63,
				pricebookEntry3.Id
			);

			QuoteLineItem quoteLine4_1 = TestFactory.buildQuoteLineItem(
				quote1.Id,
				10,
				4.63,
				pricebookEntry4.Id
			);

			QuoteLineItem quoteLine1_2 = TestFactory.buildQuoteLineItem(
				quote2.Id,
				10,
				4.63,
				pricebookEntry1.Id
			);

			QuoteLineItem quoteLine2_2 = TestFactory.buildQuoteLineItem(
				quote2.Id,
				10,
				4.63,
				pricebookEntry2.Id
			);

			QuoteLineItem quoteLine3_2 = TestFactory.buildQuoteLineItem(
				quote2.Id,
				10,
				4.63,
				pricebookEntry3.Id
			);

			QuoteLineItem quoteLine4_2 = TestFactory.buildQuoteLineItem(
				quote2.Id,
				10,
				4.63,
				pricebookEntry4.Id
			);

			insert new List<QuoteLineItem>{
				quoteLine1a_1,
				quoteLine1b_1,
				quoteLine2_1,
				quoteLine3a_1,
				quoteLine3b_1,
				quoteLine4_1,
				quoteLine1_2,
				quoteLine2_2,
				quoteLine3_2,
				quoteLine4_2
			};

			Ruby__UOM__c uom = new Ruby__UOM__c(Name = 'Endpoints/Year');
			insert uom;

			Ruby__Subscription__c subscription1a_1 = buildSubscription(
				account.Id,
				opp1.Id,
				product1.Id,
				quoteLine1a_1.Id,
				pricebookEntry1.Id,
				uom.Id
			);
			subscription1a_1.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription1b_1 = buildSubscription(
				account.Id,
				opp1.Id,
				product1.Id,
				quoteLine1b_1.Id,
				pricebookEntry1.Id,
				uom.Id
			);
			subscription1b_1.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription2_1 = buildSubscription(
				account.Id,
				opp1.Id,
				product2.Id,
				quoteLine2_1.Id,
				pricebookEntry2.Id,
				uom.Id
			);
			subscription2_1.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription3a_1 = buildSubscription(
				account.Id,
				opp1.Id,
				product3.Id,
				quoteLine3a_1.Id,
				pricebookEntry3.Id,
				uom.Id
			);
			subscription3a_1.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription3b_1 = buildSubscription(
				account.Id,
				opp1.Id,
				product3.Id,
				quoteLine3b_1.Id,
				pricebookEntry3.Id,
				uom.Id
			);
			subscription3b_1.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription4_1 = buildSubscription(
				account.Id,
				opp1.Id,
				product4.Id,
				quoteLine4_1.Id,
				pricebookEntry4.Id,
				uom.Id
			);
			subscription4_1.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription1_2 = buildSubscription(
				account.Id,
				opp2.Id,
				product1.Id,
				quoteLine1_2.Id,
				pricebookEntry1.Id,
				uom.Id
			);
			subscription1_2.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription2_2 = buildSubscription(
				account.Id,
				opp2.Id,
				product2.Id,
				quoteLine2_2.Id,
				pricebookEntry2.Id,
				uom.Id
			);
			subscription2_2.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription3_2 = buildSubscription(
				account.Id,
				opp2.Id,
				product3.Id,
				quoteLine3_2.Id,
				pricebookEntry3.Id,
				uom.Id
			);
			subscription3_2.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription4_2 = buildSubscription(
				account.Id,
				opp2.Id,
				product4.Id,
				quoteLine4_2.Id,
				pricebookEntry4.Id,
				uom.Id
			);
			subscription4_2.Ruby__Quantity__c = 10;

			insert new List<Ruby__Subscription__c>{
				subscription1a_1,
				subscription1b_1,
				subscription2_1,
				subscription3a_1,
				subscription3b_1,
				subscription4_1,
				subscription1_2,
				subscription2_2,
				subscription3_2,
				subscription4_2
			};
		}
	}

	@IsTest
	static void testIsValidOpportunity_WhenInvalidOpportunity_ReturnInvalidOpportunityMessage() {
		Opportunity opp = [
			SELECT Id
			FROM Opportunity
			WHERE Name = 'Invalid Opportunity For AEM Migration'
		];
		EnhancedReturnType rt = new EnhancedReturnType(false);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = ProductMigrationController.isValidOpportunity(opp.Id);
			Test.stopTest();
		}
		Assert.isTrue(rt.retData.startsWith('This account cannot be calculated due to'));
	}

	@IsTest
	static void testIsValidOpportunity_WhenValidOpportunity_ReturnOpportunityName() {
		Opportunity opp = [SELECT Id, Name FROM Opportunity WHERE Name = 'Test Opportunity1'];
		EnhancedReturnType rt = new EnhancedReturnType(false);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = ProductMigrationController.isValidOpportunity(opp.Id);
			Test.stopTest();
		}
		Assert.isTrue(rt.retData.subStringBefore('***') == opp.Name);
	}

	@IsTest
	static void testStartCalculation_WhenValidOpportunity_FinishCalculation() {
		Boolean finishedCalculation = false;
		Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity1'];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			finishedCalculation = ProductMigrationController.startCalculation(opp.Id);
			Test.stopTest();
		}
		Assert.isTrue(finishedCalculation);
	}

	@IsTest
	static void testGetMigrationTotalBaseLine_WhenValidOpportunity_UpdateMigrationTotalBaseline() {
		Boolean finishedCalculation = false;
		EnhancedReturnType rt;
		Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity1'];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			finishedCalculation = ProductMigrationController.startCalculation(opp.Id);
			rt = ProductMigrationController.getMigrationTotalBaseLine(opp.Id);
			Test.stopTest();
		}

		Assert.isTrue(Decimal.valueOf(rt.retData) > 0);
	}

	@IsTest
	static void testGetSubscription_Migrations_WhenValidContract_ReturnSubscription_Migrations() {
		Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity1'];
		Subscription_Migration__c[] subscription_Migrations;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			if (ProductMigrationController.startCalculation(opp.Id)) {
				subscription_Migrations = ProductMigrationController.getSubscription_Migrations(opp.Id);
			}
			Test.stopTest();
		}
		Assert.isFalse(subscription_Migrations.isEmpty());
	}

	@IsTest
	static void testGetOtherRenewableProducts_WhenNoRenewableProducts_ReturnEmptyList() {
		Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity1'];
		List<Subscription_Migration__c> otherRenewableProducts = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			if (ProductMigrationController.startCalculation(opp.Id)) {
				otherRenewableProducts = ProductMigrationController.getOtherRenewableProducts(opp.Id);
			}
			Test.stopTest();
		}
		Assert.isTrue(otherRenewableProducts.isEmpty());
	}

	@IsTest
	static void testGetSolution_Migrations_WhenValidOpportunity_ReturnSolution_Migrations() {
		Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity1'];
		List<Solution_Migration__c> solution_Migrations = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			if (ProductMigrationController.startCalculation(opp.Id)) {
				solution_Migrations = ProductMigrationController.getSolution_Migrations(opp.Id);
			}
			Test.stopTest();
		}
		Assert.isNotNull(solution_Migrations);
	}

	static Ruby__Subscription__c buildSubscription(
		Id accountId,
		Id opportunityId,
		Id productId,
		Id quoteLineId,
		Id priceBookEntryId,
		Id uomId
	) {
		Ruby__Subscription__c subscription = new Ruby__Subscription__c();
		subscription.Ruby__BillingAccount__c = accountId;
		subscription.Ruby__RenewalOpportunity__c = opportunityId;
		subscription.Ruby__Product__c = productId;
		subscription.Ruby__Quantity__c = 10;
		subscription.ELV_QuoteLine__c = quoteLineId;
		subscription.Ruby__ListPrice__c = 99;
		subscription.Ruby__NetSellerPrice__c = 99;
		subscription.Ruby__SubscriptionStartDate__c = System.today();
		subscription.Ruby__SubscriptionEndDate__c = System.today().addMonths(12);
		subscription.Ruby__PriceBookEntry__c = priceBookEntryId;
		subscription.Ruby__ActualSubscriptionTerm__c = 12;
		subscription.Ruby__SubscriptionVersion__c = 1;
		subscription.Ruby__TaxAmount__c = 0;
		subscription.Ruby__TotalAmount__c =
			subscription.Ruby__NetSellerPrice__c *
			subscription.Ruby__Quantity__c *
			subscription.Ruby__ActualSubscriptionTerm__c;
		subscription.Ruby__TotalPrice__c =
			subscription.Ruby__NetSellerPrice__c * subscription.Ruby__Quantity__c;
		subscription.Ruby__Uom__c = uomId;
		return subscription;
	}
}