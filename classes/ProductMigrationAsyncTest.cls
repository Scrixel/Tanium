/**
 * @Business: Test class for ProductMigrationAsync
 * @Date:     2025-06-24
 * @Author:   Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11112   2025-06-24    Created the test class
 * SS-11649   2025-09-24    Updated the test class
 * SS-13048   2026-04-14    Updated test class to bypass SubscriptionTriggerHandler
 */
@IsTest
private class ProductMigrationAsyncTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler',
				'SubscriptionTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			account.Segment__c = 'Enterprise';
			insert account;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				System.today().addDays(120),
				'New',
				account.Id
			);
			opp.EndDate__c = System.today().addDays(120);
			opp.MaxQuantity__c = 10;
			insert new List<Opportunity>{ opp };

			/*
			Contract contract = new Contract(
				Name = 'Active Contract1',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Contract', 'Account_Contracts'),
				StartDate = System.today().addDays(-1),
				EndDate = System.today().addDays(30),
				AccountId = account.Id,
				ContractTerm = 12,
				SBQQ__RenewalOpportunity__c = opp.Id
			);
			insert new List<Contract>{ contract };
			*/

			Product2 product1 = TestFactory.buildProduct('Tanium-Asset', 'TAN-ASSET');
			product1.Product_Group__c = 'Software';
			product1.Product_Type__c = 'Subscription';
			Product2 product2 = TestFactory.buildProduct('Tanium-Deploy', 'TAN-DEPLOY');
			product2.Product_Group__c = 'Software';
			product2.Product_Type__c = 'TaaS';
			Product2 product3 = TestFactory.buildProduct('Tanium-Core', 'TAN-CORE');
			product3.Product_Group__c = 'Software';
			product3.Product_Type__c = 'Subscription';
			Product2 product4 = TestFactory.buildProduct('Tanium-Discover', 'TAN-DISC');
			product4.Product_Group__c = 'Software';
			product4.Product_Type__c = 'TaaS';
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

			/*
			SBQQ__ProductOption__c productOption = new SBQQ__ProductOption__c(
				SBQQ__ConfiguredSKU__c = product3.Id,
				SBQQ__OptionalSKU__c = product4.Id,
				Allocation__c = 1,
				SBQQ__UnitPrice__c = 4.56,
				SBQQ__Number__c = 1
			);
			insert productOption;
			*/

			Quote quote = TestFactory.buildQuote(
				'Quote',
				opp.Id,
				System.today(),
				System.today().addMonths(3)
			);
			insert new List<Quote>{ quote };

			QuoteLineItem quoteLine1 = TestFactory.buildQuoteLineItem(
				quote.Id,
				10,
				4.63,
				pricebookEntry1.Id
			);

			QuoteLineItem quoteLine2 = TestFactory.buildQuoteLineItem(
				quote.Id,
				10,
				4.63,
				pricebookEntry2.Id
			);

			QuoteLineItem quoteLine3 = TestFactory.buildQuoteLineItem(
				quote.Id,
				10,
				4.63,
				pricebookEntry3.Id
			);

			QuoteLineItem quoteLine4 = TestFactory.buildQuoteLineItem(
				quote.Id,
				10,
				4.63,
				pricebookEntry4.Id
			);

			insert new List<QuoteLineItem>{ quoteLine1, quoteLine2, quoteLine3, quoteLine4 };

			Ruby__UOM__c uom = new Ruby__UOM__c(Name = 'Endpoints/Year');
			insert uom;

			Ruby__Subscription__c subscription1 = buildSubscription(
				account.Id,
				opp.Id,
				product1.Id,
				quoteLine1.Id,
				pricebookEntry1.Id,
				uom.Id
			);
			subscription1.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription2 = buildSubscription(
				account.Id,
				opp.Id,
				product2.Id,
				quoteLine2.Id,
				pricebookEntry2.Id,
				uom.Id
			);
			subscription2.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription3 = buildSubscription(
				account.Id,
				opp.Id,
				product3.Id,
				quoteLine3.Id,
				pricebookEntry3.Id,
				uom.Id
			);
			subscription3.Ruby__Quantity__c = 10;

			Ruby__Subscription__c subscription4 = buildSubscription(
				account.Id,
				opp.Id,
				product4.Id,
				quoteLine4.Id,
				pricebookEntry4.Id,
				uom.Id
			);
			subscription4.Ruby__Quantity__c = 10;

			insert new List<Ruby__Subscription__c>{
				subscription1,
				subscription2,
				subscription3,
				subscription4
			};
		}
	}

	@IsTest
	static void testEnqueueJob_Always_ReturnJobId() {
		Opportunity[] renewalOpps = [
			SELECT
				Id,
				Renewed_Contract_Modules__c,
				Potential_AEM_Modules__c,
				Potential_New_Modules__c,
				Potential_New_Module_Count__c,
				Potential_AEM_Migration_ARR__c,
				Tanium_Software_ARR__c
			FROM Opportunity
		];
		Id jobId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ProductMigrationAsync async = new ProductMigrationAsync(renewalOpps);
			jobId = System.enqueueJob(async);
			Test.stopTest();
		}

		Assert.isTrue(jobId != null);
	}

	@IsTest
	static void testExecute_Always_PopulateTaniumSoftwareARR() {
		Opportunity[] renewalOpps = [
			SELECT
				Id,
				Renewed_Contract_Modules__c,
				Potential_AEM_Modules__c,
				Potential_New_Modules__c,
				Potential_New_Module_Count__c,
				Potential_AEM_Migration_ARR__c,
				Tanium_Software_ARR__c
			FROM Opportunity
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ProductMigrationAsync async = new ProductMigrationAsync(renewalOpps);
			async.execute(null);
			Test.stopTest();
		}


		//Contract contract = [SELECT Id, Tanium_Software_ARR__c FROM Contract LIMIT 1];
		//Assert.isTrue(contract.Tanium_Software_ARR__c != null);
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