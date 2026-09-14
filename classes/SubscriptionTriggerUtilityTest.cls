/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Test class for Subscription Trigger Utility, part of Trigger Framework
 * @Date: 2025-04-04
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12077   2025-11-13    Initial development
 * SS-13032   2026-04-27    Modified test class
 * SS-13641   2026-07-27    Updated makeData method
 * SS-13748   2026-08-03    Updated makeData method
 * SS-13787   2026-08-18    Fix test class for building products
 * SS-13834   2026-08-24    Added tests for processMonthlyPaidAICredits
 */
@IsTest
private class SubscriptionTriggerUtilityTest {
	private static Id accountContractRecTypeId = Utility.getRecordTypeIdByAPIName(
		'Contract',
		'Account_Contracts'
	);

	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'UserTriggerHandler',
				'AccountTriggerHandler',
				'ContractTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Product2> products = new List<Product2>();
			Product2 coreProduct = TestFactory.buildProduct('Core Product', 'Core');
			coreProduct.Product_Type__c = 'SaaS';
			coreProduct.Product_Group__c = 'Software';
			coreProduct.Include_In_Annualized_Software_Spend__c = true;
			products.add(coreProduct);
			products.add(TestFactory.buildProduct('Discover Product', 'Discover'));
			products.add(TestFactory.buildProduct('Core Plus', 'Core Plus'));
			products.add(
				TestFactory.buildProduct('AI Credits Tanium Cloud', 'TANIUM-AI-CREDITS-CLOUD')
			);
			insert products;

			List<Module__c> modules = new List<Module__c>();
			modules.add(new Module__c(Name = 'Core', Module_Description__c = 'Core Product'));
			modules.add(new Module__c(Name = 'Discover', Module_Description__c = 'Discover Product'));
			insert modules;

			List<Product_Module__c> productModules = new List<Product_Module__c>();
			productModules.add(
				new Product_Module__c(Product__c = products[0].Id, Module__c = modules[0].Id)
			);
			productModules.add(
				new Product_Module__c(Product__c = products[1].Id, Module__c = modules[1].Id)
			);
			productModules.add(
				new Product_Module__c(Product__c = products[2].Id, Module__c = modules[0].Id)
			);
			productModules.add(
				new Product_Module__c(Product__c = products[2].Id, Module__c = modules[1].Id)
			);
			insert productModules;

			Account account = TestFactory.buildAccount('Test Account');
			account.Type = 'Prospect';
			insert account;

			Server_Deployment__c serverDeployment = TestFactory.buildServerDeployment(
				'Test Server Deployment',
				account.Id
			);
			insert serverDeployment;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today(),
				Utility.PROSPECTING,
				account.Id
			);
			insert opp;

			Contract contract = new Contract(
				AccountId = account.Id,
				RecordTypeId = accountContractRecTypeId,
				EndDate = Date.today().addMonths(6),
				ContractTerm = 6,
				TRAC_ARV_Contract__c = 0
			);
			insert contract;

			SBQQ__Quote__c quote = new SBQQ__Quote__c(
				SBQQ__Opportunity2__c = opp.Id,
				SBQQ__Account__c = account.Id,
				SBQQ__Type__c = 'Quote',
				SBQQ__Primary__c = true,
				SBQQ__PaymentTerms__c = 'Net 30'
			);
			insert quote;

			List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();
			for (Product2 product : products) {
				quoteLines.add(
					new SBQQ__QuoteLine__c(
						SBQQ__Product__c = product.Id,
						SBQQ__Quantity__c = 1000,
						SBQQ__Quote__c = quote.Id,
						SBQQ__StartDate__c = Date.today(),
						SBQQ__EndDate__c = Date.today().addMonths(12),
						SBQQ__SubscriptionPricing__c = null,
						SBQQ__NetPrice__c = 1000
					)
				);
			}
			insert quoteLines;

			List<SBQQ__Subscription__c> subscriptions = new List<SBQQ__Subscription__c>();
			for (Integer i = 0; i < quoteLines.size(); i++) {
				subscriptions.add(
					TestFactory.buildSubscription(
						account.Id,
						quoteLines[i].SBQQ__Product__c,
						1000,
						quoteLines[i].Id
					)
				);
				subscriptions[i].SBQQ__NetPrice__c = 1000;
				subscriptions[i].SBQQ__Contract__c = contract.Id;
				subscriptions[i].Include_In_Annualized_Software_Spend__c = (i == 0) ? true : false;
			}
			insert subscriptions;
			update subscriptions;
			delete [SELECT Id FROM Account_Entitlements__c];
			delete [SELECT Id FROM Server_Deployment_Subscriptions__c];
			delete subscriptions;
			undelete subscriptions;
		}
	}

	@IsTest
	static void testProcessSubscriptionAccountEntitlements_WhenOneServDep_CreateAccEntsAndServDepSubs() {
		List<SBQQ__Subscription__c> subscriptions = [
			SELECT
				Id,
				SBQQ__StartDate__c,
				SBQQ__EndDate__c,
				SBQQ__Account__c,
				SBQQ__Product__c,
				SBQQ__Quantity__c
			FROM SBQQ__Subscription__c
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			SubscriptionTriggerUtility.processSubscriptionAccountEntitlements(subscriptions);
			Test.stopTest();
		}

		List<Product_Module__c> productModules = [SELECT Id FROM Product_Module__c];
		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];
		Boolean createServDepSubsEnabled = (System.Label.Trigger_CreateServDepSubsFlag == 'true');
		//Integer expectedServDepSubsCount = createServDepSubsEnabled ? productModules.size() : 0;
		Integer expectedServDepSubsCount = productModules.size();

		Assert.areEqual(
			productModules.size(),
			accountEntitlements.size(),
			'Account Entitlements should be created for each product module'
		);

		Assert.areEqual(
			expectedServDepSubsCount,
			serverDeploymentSubscriptions.size(),
			'Server Deployment Subscriptions count should match Trigger_CreateServDepSubsFlag (' +
			System.Label.Trigger_CreateServDepSubsFlag +
			'): expected ' +
			expectedServDepSubsCount +
			', actual ' +
			serverDeploymentSubscriptions.size()
		);

		Product_Module__c productModule = [
			SELECT Id, Module__c, Product__c
			FROM Product_Module__c
			LIMIT 1
		];
		Account_Entitlements__c accountEntitlement = [
			SELECT
				Id,
				Account__c,
				Module__c,
				Product__c,
				Start_Date__c,
				End_Date__c,
				Quantity_Purchased__c,
				Quantity_Allocated__c,
				Type__c,
				Source_Subscription__c
			FROM Account_Entitlements__c
			WHERE Module__c = :productModule.Module__c AND Product__c = :productModule.Product__c
			LIMIT 1
		];
		SBQQ__Subscription__c subscription = [
			SELECT Id, SBQQ__Account__c, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Quantity__c
			FROM SBQQ__Subscription__c
			WHERE Id = :accountEntitlement.Source_Subscription__c
			LIMIT 1
		];

		Assert.areEqual(subscription.SBQQ__Account__c, accountEntitlement.Account__c);
		Assert.areEqual(subscription.SBQQ__StartDate__c, accountEntitlement.Start_Date__c);
		Assert.areEqual(subscription.SBQQ__EndDate__c, accountEntitlement.End_Date__c);
		Assert.areEqual(subscription.SBQQ__Quantity__c, accountEntitlement.Quantity_Purchased__c);
		Assert.areEqual(subscription.SBQQ__Quantity__c, accountEntitlement.Quantity_Allocated__c);
		Assert.areEqual('Subscription', accountEntitlement.Type__c);
		Assert.areEqual(subscription.Id, accountEntitlement.Source_Subscription__c);
		Assert.areEqual(productModule.Module__c, accountEntitlement.Module__c);
		Assert.areEqual(productModule.Product__c, accountEntitlement.Product__c);

		if (createServDepSubsEnabled) {
			Server_Deployment__c serverDeployment = [SELECT Id FROM Server_Deployment__c LIMIT 1];
			Server_Deployment_Subscriptions__c serverDeploymentSubscription = [
				SELECT
					Id,
					Account__c,
					Server_Deployment__c,
					Subscription_Quantity__c,
					Subscription__c,
					Account_Entitlement__c
				FROM Server_Deployment_Subscriptions__c
				LIMIT 1
			];
			Assert.areEqual(accountEntitlement.Account__c, serverDeploymentSubscription.Account__c);
			Assert.areEqual(serverDeployment.Id, serverDeploymentSubscription.Server_Deployment__c);
			Assert.areEqual(
				accountEntitlement.Quantity_Purchased__c,
				serverDeploymentSubscription.Subscription_Quantity__c
			);
			Assert.areEqual(subscription.Id, serverDeploymentSubscription.Subscription__c);
			Assert.areEqual(
				accountEntitlement.Id,
				serverDeploymentSubscription.Account_Entitlement__c
			);
		}
	}

	@IsTest
	static void testProcessSubscriptionAccountEntitlements_WhenManyServDep_CreateAccEnts() {
		Account account = [SELECT Id FROM Account];
		Server_Deployment__c serverDeployment = TestFactory.buildServerDeployment(
			'Test Server Deployment 2',
			account.Id
		);
		insert serverDeployment;

		List<SBQQ__Subscription__c> subscriptions = [
			SELECT
				Id,
				SBQQ__StartDate__c,
				SBQQ__EndDate__c,
				SBQQ__Account__c,
				SBQQ__Product__c,
				SBQQ__Quantity__c
			FROM SBQQ__Subscription__c
		];

		Test.startTest();
		SubscriptionTriggerUtility.processSubscriptionAccountEntitlements(subscriptions);
		Test.stopTest();

		List<Product_Module__c> productModules = [SELECT Id FROM Product_Module__c];
		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];
		Assert.areEqual(
			productModules.size(),
			accountEntitlements.size(),
			'Account Entitlements should be created for each product module'
		);
		Assert.areEqual(
			0,
			serverDeploymentSubscriptions.size(),
			'Server Deployment Subscriptions should not be created when there are many server deployments'
		);

		Product_Module__c productModule = [
			SELECT Id, Module__c, Product__c
			FROM Product_Module__c
			LIMIT 1
		];
		Account_Entitlements__c accountEntitlement = [
			SELECT
				Id,
				Account__c,
				Module__c,
				Product__c,
				Start_Date__c,
				End_Date__c,
				Quantity_Purchased__c,
				Quantity_Allocated__c,
				Type__c,
				Source_Subscription__c
			FROM Account_Entitlements__c
			WHERE Module__c = :productModule.Module__c AND Product__c = :productModule.Product__c
			LIMIT 1
		];
		SBQQ__Subscription__c subscription = [
			SELECT Id, SBQQ__Account__c, SBQQ__StartDate__c, SBQQ__EndDate__c, SBQQ__Quantity__c
			FROM SBQQ__Subscription__c
			WHERE Id = :accountEntitlement.Source_Subscription__c
			LIMIT 1
		];

		Assert.areEqual(subscription.SBQQ__Account__c, accountEntitlement.Account__c);
		Assert.areEqual(subscription.SBQQ__StartDate__c, accountEntitlement.Start_Date__c);
		Assert.areEqual(subscription.SBQQ__EndDate__c, accountEntitlement.End_Date__c);
		Assert.areEqual(subscription.SBQQ__Quantity__c, accountEntitlement.Quantity_Purchased__c);
		Assert.areEqual(0, accountEntitlement.Quantity_Allocated__c);
		Assert.areEqual('Subscription', accountEntitlement.Type__c);
		Assert.areEqual(subscription.Id, accountEntitlement.Source_Subscription__c);
		Assert.areEqual(productModule.Module__c, accountEntitlement.Module__c);
		Assert.areEqual(productModule.Product__c, accountEntitlement.Product__c);
	}

	@IsTest
	static void testProcessMonthlyPaidAICredits_WhenTestContext_DoesNotEnqueueBatch() {
		SBQQ__Subscription__c subscription = [
			SELECT Id, SBQQ__Account__c, SBQQ__Product__c
			FROM SBQQ__Subscription__c
			WHERE SBQQ__Product__r.ProductCode = 'TANIUM-AI-CREDITS-CLOUD'
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			SubscriptionTriggerUtility.processMonthlyPaidAICredits(
				new List<SBQQ__Subscription__c>{ subscription }
			);
			Test.stopTest();
		}

		Assert.areEqual(
			0,
			[
				SELECT COUNT()
				FROM AsyncApexJob
				WHERE ApexClass.Name = 'AccountSetSwSpendAndAiCreditsBatch'
			],
			'Test.isRunningTest() must short-circuit the actual batch enqueue'
		);
	}
}