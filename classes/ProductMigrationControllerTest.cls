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
				'QuoteCPQTriggerHandler',
				'SubscriptionTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			account.Segment__c = 'Enterprise';
			insert account;

			Contract contract1 = new Contract(
				Name = 'Active Contract1',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Contract', 'Account_Contracts'),
				StartDate = System.today().addDays(-1),
				EndDate = System.today().addDays(30),
				AccountId = account.Id,
				ContractTerm = 12
			);
			Contract contract2 = new Contract(
				Name = 'Active Contract2',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Contract', 'Account_Contracts'),
				StartDate = System.today().addDays(-1),
				EndDate = System.today().addDays(30),
				AccountId = account.Id,
				ContractTerm = 12
			);
			insert new List<Contract>{ contract1, contract2 };

			Opportunity opp1 = TestFactory.buildOpportunity(
				'Test Opportunity1',
				System.today().addDays(120),
				'New',
				account.Id
			);
			Opportunity opp2 = TestFactory.buildOpportunity(
				'Test Opportunity2',
				System.today().addDays(120),
				'New',
				account.Id
			);
			opp2.SBQQ__RenewedContract__c = contract2.Id;
			insert new List<Opportunity>{ opp1, opp2 };

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

			SBQQ__Quote__c quote1 = TestFactory.buildSBQQ_Quote(
				opp1.Id,
				account.Id,
				'Draft',
				'',
				null,
				null,
				null
			);
			SBQQ__Quote__c quote2 = TestFactory.buildSBQQ_Quote(
				opp2.Id,
				account.Id,
				'Draft',
				'',
				null,
				null,
				null
			);
			insert new List<SBQQ__Quote__c>{ quote1, quote2 };

			SBQQ__QuoteLine__c quoteLine1a_1 = TestFactory.buildSBQQ_QuoteLine(
				quote1.Id,
				product1.Id,
				1
			);
			quoteLine1a_1.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine1b_1 = TestFactory.buildSBQQ_QuoteLine(
				quote1.Id,
				product1.Id,
				1
			);
			quoteLine1b_1.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine2_1 = TestFactory.buildSBQQ_QuoteLine(
				quote1.Id,
				product2.Id,
				1
			);
			quoteLine2_1.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine3a_1 = TestFactory.buildSBQQ_QuoteLine(
				quote1.Id,
				product3.Id,
				50
			);
			quoteLine3a_1.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine3b_1 = TestFactory.buildSBQQ_QuoteLine(
				quote1.Id,
				product3.Id,
				40
			);
			quoteLine3b_1.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine4_1 = TestFactory.buildSBQQ_QuoteLine(
				quote1.Id,
				product4.Id,
				50
			);
			quoteLine4_1.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine1_2 = TestFactory.buildSBQQ_QuoteLine(
				quote2.Id,
				product1.Id,
				1
			);
			quoteLine1_2.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine2_2 = TestFactory.buildSBQQ_QuoteLine(
				quote2.Id,
				product2.Id,
				1
			);
			quoteLine2_2.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine3_2 = TestFactory.buildSBQQ_QuoteLine(
				quote2.Id,
				product3.Id,
				50
			);
			quoteLine3_2.SBQQ__StartDate__c = System.today();

			SBQQ__QuoteLine__c quoteLine4_2 = TestFactory.buildSBQQ_QuoteLine(
				quote2.Id,
				product4.Id,
				50
			);
			quoteLine4_2.SBQQ__StartDate__c = System.today();

			insert new List<SBQQ__QuoteLine__c>{
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

			SBQQ__Subscription__c subscription1a_1 = buildSubscription(
				account.Id,
				product1.Id,
				1.00,
				quoteLine1a_1.Id
			);
			subscription1a_1.SBQQ__Contract__c = contract1.Id;
			subscription1a_1.SBQQ__ProrateMultiplier__c = 1;
			subscription1a_1.SBQQ__ListPrice__c = 99;
			subscription1a_1.SBQQ__NetPrice__c = 99;

			SBQQ__Subscription__c subscription1b_1 = buildSubscription(
				account.Id,
				product1.Id,
				1.00,
				quoteLine1b_1.Id
			);
			subscription1b_1.SBQQ__Contract__c = contract1.Id;
			subscription1b_1.SBQQ__ProrateMultiplier__c = 2;
			subscription1b_1.SBQQ__ListPrice__c = 99;
			subscription1b_1.SBQQ__NetPrice__c = 99;

			SBQQ__Subscription__c subscription2_1 = buildSubscription(
				account.Id,
				product2.Id,
				1.00,
				quoteLine2_1.Id
			);
			subscription2_1.SBQQ__Contract__c = contract1.Id;
			subscription2_1.SBQQ__ProrateMultiplier__c = 1;
			subscription2_1.SBQQ__ListPrice__c = 49;
			subscription2_1.SBQQ__NetPrice__c = 49;

			SBQQ__Subscription__c subscription3a_1 = buildSubscription(
				account.Id,
				product3.Id,
				1.00,
				quoteLine3a_1.Id
			);
			subscription3a_1.SBQQ__Contract__c = contract1.Id;
			subscription3a_1.SBQQ__ProrateMultiplier__c = 1;
			subscription3a_1.SBQQ__ListPrice__c = 19;
			subscription3a_1.SBQQ__NetPrice__c = 19;

			SBQQ__Subscription__c subscription3b_1 = buildSubscription(
				account.Id,
				product3.Id,
				2.00,
				quoteLine3b_1.Id
			);
			subscription3b_1.SBQQ__Contract__c = contract1.Id;
			subscription3b_1.SBQQ__ProrateMultiplier__c = 1;
			subscription3b_1.SBQQ__ListPrice__c = 20;
			subscription3b_1.SBQQ__NetPrice__c = 20;

			SBQQ__Subscription__c subscription4_1 = buildSubscription(
				account.Id,
				product4.Id,
				1.00,
				quoteLine4_1.Id
			);
			subscription4_1.SBQQ__Contract__c = contract1.Id;
			subscription4_1.SBQQ__ProductOption__c = productOption.Id;
			subscription4_1.SBQQ__ListPrice__c = 19;
			subscription4_1.SBQQ__NetPrice__c = 19;
			subscription4_1.SBQQ__ProrateMultiplier__c = 1;

			SBQQ__Subscription__c subscription1_2 = buildSubscription(
				account.Id,
				product1.Id,
				1.00,
				quoteLine1_2.Id
			);
			subscription1_2.SBQQ__Contract__c = contract2.Id;
			subscription1_2.SBQQ__ProrateMultiplier__c = 1;
			subscription1_2.SBQQ__ListPrice__c = 99;
			subscription1_2.SBQQ__NetPrice__c = 99;

			SBQQ__Subscription__c subscription2_2 = buildSubscription(
				account.Id,
				product2.Id,
				1.00,
				quoteLine2_2.Id
			);
			subscription2_2.SBQQ__Contract__c = contract2.Id;
			subscription2_2.SBQQ__ProrateMultiplier__c = 1;
			subscription2_2.SBQQ__ListPrice__c = 49;
			subscription2_2.SBQQ__NetPrice__c = 49;

			SBQQ__Subscription__c subscription3_2 = buildSubscription(
				account.Id,
				product3.Id,
				1.00,
				quoteLine3_2.Id
			);
			subscription3_2.SBQQ__Contract__c = contract2.Id;
			subscription3_2.SBQQ__ProrateMultiplier__c = 1;
			subscription3_2.SBQQ__ListPrice__c = 19;
			subscription3_2.SBQQ__NetPrice__c = 19;

			SBQQ__Subscription__c subscription4_2 = buildSubscription(
				account.Id,
				product4.Id,
				1.00,
				quoteLine4_2.Id
			);
			subscription4_2.SBQQ__Contract__c = contract2.Id;
			subscription4_2.SBQQ__ProductOption__c = productOption.Id;
			subscription4_2.SBQQ__ListPrice__c = 19;
			subscription4_2.SBQQ__NetPrice__c = 19;
			subscription4_2.SBQQ__ProrateMultiplier__c = 1;

			insert new List<SBQQ__Subscription__c>{
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
		Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity1'];
		EnhancedReturnType rt = new EnhancedReturnType(false);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = ProductMigrationController.isValidOpportunity(opp.Id);
			Test.stopTest();
		}
		Assert.isTrue(rt.retData == 'This Opportunity is not linked to a renewed contract.');
	}

	@IsTest
	static void testIsValidOpportunity_WhenValidOpportunity_ReturnOpportunityName() {
		Opportunity opp = [SELECT Id, Name FROM Opportunity WHERE Name = 'Test Opportunity2'];
		EnhancedReturnType rt = new EnhancedReturnType(false);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = ProductMigrationController.isValidOpportunity(opp.Id);
			Test.stopTest();
		}
		Assert.isTrue(rt.retData.subStringBefore('***') == opp.Name);
	}

	@IsTest
	static void testStartCalculation_WhenValidAmendContract_FinishCalculation() {
		Boolean finishedCalculation = false;
		Contract contract = [
			SELECT Id, ContractNumber
			FROM Contract
			WHERE Name = 'Active Contract1'
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			finishedCalculation = ProductMigrationController.startCalculation(contract.ContractNumber);
			Test.stopTest();
		}
		Assert.isTrue(finishedCalculation);
	}

	@IsTest
	static void testStartCalculation_WhenValidContract_FinishCalculation() {
		Boolean finishedCalculation = false;
		Contract contract = [
			SELECT Id, ContractNumber
			FROM Contract
			WHERE Name = 'Active Contract2'
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			finishedCalculation = ProductMigrationController.startCalculation(contract.ContractNumber);
			Test.stopTest();
		}
		Assert.isTrue(finishedCalculation);
	}

	@IsTest
	static void testStartCalculation_WhenInvalidOpportunity_DoNotFinishCalculation() {
		Boolean finishedCalculation = false;
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			finishedCalculation = ProductMigrationController.startCalculation(opp.Id);
			ProductMigrationController.updateAemMigrationFields(opp.Id);
			Test.stopTest();
		}
		Assert.isFalse(finishedCalculation);
	}

	@IsTest
	static void testGetMigrationTotalBaseLine_WhenValidContract_UpdateMigrationTotalBaseline() {
		Boolean finishedCalculation = false;
		EnhancedReturnType rt;
		Contract contract = [
			SELECT Id, ContractNumber, Migration_Total_Baseline__c
			FROM Contract
			WHERE Name = 'Active Contract2'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			finishedCalculation = ProductMigrationController.startCalculation(contract.ContractNumber);
			rt = ProductMigrationController.getMigrationTotalBaseLine(contract.ContractNumber);
			Test.stopTest();
		}

		Assert.isTrue(Decimal.valueOf(rt.retData) > 0);
	}

	@IsTest
	static void testGetSubscription_Migrations_WhenValidContract_ReturnSubscription_Migrations() {
		Contract contract = [SELECT Id, ContractNumber FROM Contract LIMIT 1];
		Subscription_Migration__c[] subscription_Migrations;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			if (ProductMigrationController.startCalculation(contract.ContractNumber)) {
				subscription_Migrations = ProductMigrationController.getSubscription_Migrations(
					contract.ContractNumber
				);
			}
			Test.stopTest();
		}
		Assert.isFalse(subscription_Migrations.isEmpty());
	}

	@IsTest
	static void testGetOtherRenewableProducts_WhenNoRenewableProducts_ReturnEmptyList() {
		Contract contract = [SELECT Id, ContractNumber FROM Contract LIMIT 1];
		List<Subscription_Migration__c> otherRenewableProducts = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			if (ProductMigrationController.startCalculation(contract.ContractNumber)) {
				otherRenewableProducts = ProductMigrationController.getOtherRenewableProducts(
					contract.ContractNumber
				);
			}
			Test.stopTest();
		}
		Assert.isTrue(otherRenewableProducts.isEmpty());
	}

	@IsTest
	static void testGetSolution_Migrations_WhenValidContract_ReturnSolution_Migrations() {
		Contract contract = [SELECT Id, ContractNumber FROM Contract LIMIT 1];
		List<Solution_Migration__c> solution_Migrations = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			if (ProductMigrationController.startCalculation(contract.ContractNumber)) {
				solution_Migrations = ProductMigrationController.getSolution_Migrations(
					contract.ContractNumber
				);
			}
			Test.stopTest();
		}
		Assert.isNotNull(solution_Migrations);
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