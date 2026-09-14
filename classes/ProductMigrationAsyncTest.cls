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
			insert new List<Opportunity>{ opp };

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

			SBQQ__ProductOption__c productOption = new SBQQ__ProductOption__c(
				SBQQ__ConfiguredSKU__c = product3.Id,
				SBQQ__OptionalSKU__c = product4.Id,
				Allocation__c = 1,
				SBQQ__UnitPrice__c = 4.56,
				SBQQ__Number__c = 1
			);
			insert productOption;

			SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				account.Id,
				'Draft',
				'',
				null,
				null,
				null
			);
			insert new List<SBQQ__Quote__c>{ quote };

			SBQQ__QuoteLine__c quoteLine1 = TestFactory.buildSBQQ_QuoteLine(quote.Id, product1.Id, 1);
			quoteLine1.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine2 = TestFactory.buildSBQQ_QuoteLine(quote.Id, product2.Id, 1);
			quoteLine2.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine3 = TestFactory.buildSBQQ_QuoteLine(quote.Id, product3.Id, 50);
			quoteLine3.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine4 = TestFactory.buildSBQQ_QuoteLine(quote.Id, product4.Id, 40);
			quoteLine4.SBQQ__StartDate__c = System.today();

			insert new List<SBQQ__QuoteLine__c>{ quoteLine1, quoteLine2, quoteLine3, quoteLine4 };

			SBQQ__Subscription__c subscription1 = buildSubscription(
				account.Id,
				product1.Id,
				1.00,
				quoteLine1.Id
			);
			subscription1.SBQQ__Contract__c = contract.Id;
			subscription1.SBQQ__ProrateMultiplier__c = 1;
			subscription1.SBQQ__ListPrice__c = 99;
			subscription1.SBQQ__NetPrice__c = 99;

			SBQQ__Subscription__c subscription2 = buildSubscription(
				account.Id,
				product2.Id,
				1.00,
				quoteLine2.Id
			);
			subscription2.SBQQ__Contract__c = contract.Id;
			subscription2.SBQQ__ProrateMultiplier__c = 1;
			subscription2.SBQQ__ListPrice__c = 49;
			subscription2.SBQQ__NetPrice__c = 49;

			SBQQ__Subscription__c subscription3 = buildSubscription(
				account.Id,
				product3.Id,
				1.00,
				quoteLine3.Id
			);
			subscription3.SBQQ__Contract__c = contract.Id;
			subscription3.SBQQ__ProrateMultiplier__c = 1;
			subscription3.SBQQ__ListPrice__c = 19;
			subscription3.SBQQ__NetPrice__c = 19;

			SBQQ__Subscription__c subscription4 = buildSubscription(
				account.Id,
				product4.Id,
				1.00,
				quoteLine4.Id
			);
			subscription4.SBQQ__Contract__c = contract.Id;
			subscription4.SBQQ__ProductOption__c = productOption.Id;
			subscription4.SBQQ__ListPrice__c = 19;
			subscription4.SBQQ__NetPrice__c = 19;
			subscription4.SBQQ__ProrateMultiplier__c = 1;

			insert new List<SBQQ__Subscription__c>{
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
				Potential_AEM_Migration_ARR__c
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
				Potential_AEM_Migration_ARR__c
			FROM Opportunity
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ProductMigrationAsync async = new ProductMigrationAsync(renewalOpps);
			async.execute(null);
			Test.stopTest();
		}

		Contract contract = [SELECT Id, Tanium_Software_ARR__c FROM Contract LIMIT 1];
		Assert.isTrue(contract.Tanium_Software_ARR__c != null);
	}

	static SBQQ__Subscription__c buildSubscription(
		Id accountId,
		Id productId,
		Decimal quantity,
		Id quoteLineId
	) {
		SBQQ__Subscription__c sub = new SBQQ__Subscription__c();
		sub.SBQQ__Account__c = (accountId != null ? accountId : null);
		sub.SBQQ__Product__c = (productId != null ? productId : null);
		sub.SBQQ__Quantity__c = quantity;
		sub.SBQQ__SubscriptionStartDate__c = System.today().addDays(-30);
		sub.SBQQ__SubscriptionEndDate__c = System.today().addDays(90);
		sub.Exclude_from_Seats_Roll_up__c = false;
		sub.SBQQ__QuoteLine__c = quoteLineId;
		return sub;
	}
}