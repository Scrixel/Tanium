/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for Account Entitlement Trigger Utility, part of Trigger Framework
 * @Date: 2026-01-12
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2026-01-12      Initial development
 * SS-12494     2026-01-27      Update methods with different key value pairs
 * SS-12914     2026-03-31      Added 3 test methods to improve code coverage
 */
@IsTest
private class AccountEntitlementTriggerUtilityTest {
	private static Id taniumCloudRecTypeId = Utility.getRecordTypeIdByAPIName(
		'Server_Deployment__c',
		'TaaS'
	);
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
			products.add(new Product2(Name = 'Core Product', ProductCode = 'Core', IsActive = true));
			products.add(
				new Product2(Name = 'Discover Product', ProductCode = 'Discover', IsActive = true)
			);
			products.add(new Product2(Name = 'Core Plus', ProductCode = 'Core Plus', IsActive = true));
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
				new Product_Module__c(
					Product__c = products[2].Id,
					Module__c = modules[0].Id,
					Module_Product__c = products[0].Id
				)
			);
			productModules.add(
				new Product_Module__c(
					Product__c = products[2].Id,
					Module__c = modules[1].Id,
					Module_Product__c = products[1].Id
				)
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
				subscriptions[i].SBQQ__Contract__c = contract.Id;
			}
			insert subscriptions;
			delete [SELECT Id FROM Account_Entitlements__c];
			delete [SELECT Id FROM Server_Deployment_Subscriptions__c];

			List<NFR__c> nfrs = new List<NFR__c>();
			nfrs.add(TestFactory.buildNFR(account.Id, 'Core'));
			nfrs.add(TestFactory.buildNFR(account.Id, 'Discover'));
			insert nfrs;

			List<POC_Request__c> pocRequests = new List<POC_Request__c>();
			POC_Request__c pocRequest = TestFactory.buildPOCRequest(opp);
			pocRequest.Approved__c = true;
			pocRequest.Deployment_Country__c = 'Canada';
			insert pocRequest;
		}
	}

	@IsTest
	static void testCreateAccountEntitlementsManyServerDeps_Always_CreateAccountEntitlements() {
		Product2 product = [SELECT Id FROM Product2 LIMIT 1];
		List<SBQQ__Subscription__c> subscriptions = [
			SELECT
				Id,
				SBQQ__StartDate__c,
				SBQQ__EndDate__c,
				SBQQ__Account__c,
				SBQQ__Product__c,
				SBQQ__Quantity__c
			FROM SBQQ__Subscription__c
			WHERE SBQQ__Product__c = :product.Id
		];

		Map<SBQQ__Subscription__c, Id> subscriptionToProductId = new Map<SBQQ__Subscription__c, Id>();
		for (SBQQ__Subscription__c subscription : subscriptions) {
			subscriptionToProductId.put(subscription, product.Id);
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountEntitlementTriggerUtility.createAccountEntitlementsManyServerDeps(
				subscriptionToProductId
			);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];
		Assert.isTrue(accountEntitlements.size() > 0);
		Assert.isTrue(serverDeploymentSubscriptions.isEmpty());
	}

	@IsTest
	static void testCreateAccountEntitlementsOneServDep_Always_CreateAccountEntitlementsServerDeploymentSubscriptions() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Server_Deployment__c serverDeployment = [
			SELECT Id, Account__c, Server_Device_Type__c, Cloud_Provider__c, Type__c
			FROM Server_Deployment__c
			WHERE Account__c = :account.Id
			LIMIT 1
		];
		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();
		accountIdToServerDeployment.put(account.Id, serverDeployment);

		Product2 product = [SELECT Id, Name, ProductCode FROM Product2 LIMIT 1];
		List<SBQQ__Subscription__c> subscriptions = [
			SELECT
				Id,
				SBQQ__StartDate__c,
				SBQQ__EndDate__c,
				SBQQ__Account__c,
				SBQQ__Product__c,
				SBQQ__Quantity__c
			FROM SBQQ__Subscription__c
			WHERE SBQQ__Product__c = :product.Id
		];

		Map<SBQQ__Subscription__c, Id> subscriptionToProductId = new Map<SBQQ__Subscription__c, Id>();
		for (SBQQ__Subscription__c subscription : subscriptions) {
			subscriptionToProductId.put(subscription, product.Id);
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountEntitlementTriggerUtility.createAccountEntitlementsOneServDep(
				subscriptionToProductId,
				accountIdToServerDeployment
			);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];
		Assert.isTrue(accountEntitlements.size() > 0);
		Assert.isTrue(serverDeploymentSubscriptions.size() > 0);
	}

	@IsTest
	static void testCreateAccountEntitlementsNFR_Always_CreateAccountEntitlementsServerDeploymentSubscriptions() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Server_Deployment__c serverDeployment = [
			SELECT Id, Account__c, Server_Device_Type__c, Cloud_Provider__c, Type__c
			FROM Server_Deployment__c
			WHERE Account__c = :account.Id
			LIMIT 1
		];
		List<Module__c> modules = [SELECT Id FROM Module__c];
		Map<Id, NFR__c> nfrMap = new Map<Id, NFR__c>(
			[
				SELECT
					Id,
					Account__c,
					NFR_Issued_Date__c,
					NFR_Expiration_Date__c,
					Number_of_Endpoints__c
				FROM NFR__c
			]
		);
		Map<Id, List<Module__c>> nfrIdToModules = new Map<Id, List<Module__c>>();
		for (Id nfrId : nfrMap.keySet()) {
			nfrIdToModules.put(nfrId, modules);
		}

		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();
		accountIdToServerDeployment.put(account.Id, serverDeployment);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountEntitlementTriggerUtility.createAccountEntitlementsNFR(
				nfrMap,
				nfrIdToModules,
				accountIdToServerDeployment
			);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		Assert.isFalse(accountEntitlements.isEmpty());
	}

	@IsTest
	static void testCreateAccountEntitlementsPOCRequestModules_Always_CreateAccountEntitlementsServerDeploymentSubscriptions() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Server_Deployment__c serverDeployment = [
			SELECT Id, Account__c, Server_Device_Type__c, Cloud_Provider__c, Type__c
			FROM Server_Deployment__c
			WHERE Account__c = :account.Id
			LIMIT 1
		];
		Map<Id, POC_Request__c> pocRequestMap = new Map<Id, POC_Request__c>(
			[
				SELECT Id, Account__c, Start_Date__c, End_Date__c, Quantity__c
				FROM POC_Request__c
				LIMIT 1
			]
		);
		Map<Id, Module__c> moduleIdToModule = new Map<Id, Module__c>([SELECT Id FROM Module__c]);
		Map<Id, List<Id>> pocRequestIdToModuleIds = new Map<Id, List<Id>>();
		for (Id pocRequestId : pocRequestMap.keySet()) {
			pocRequestIdToModuleIds.put(pocRequestId, new List<Id>(moduleIdToModule.keySet()));
		}

		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();
		accountIdToServerDeployment.put(account.Id, serverDeployment);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountEntitlementTriggerUtility.createAccountEntitlementsPOCRequestModules(
				pocRequestMap,
				pocRequestIdToModuleIds,
				accountIdToServerDeployment
			);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];
		Assert.isFalse(accountEntitlements.isEmpty());
		Assert.isFalse(serverDeploymentSubscriptions.isEmpty());
	}

	@IsTest
	static void testCreateAccountEntitlementsPOCRequestSolutions_Always_CreateAccountEntitlementsServerDeploymentSubscriptions() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Server_Deployment__c serverDeployment = [
			SELECT Id, Account__c, Server_Device_Type__c, Cloud_Provider__c, Type__c
			FROM Server_Deployment__c
			WHERE Account__c = :account.Id
			LIMIT 1
		];
		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();
		accountIdToServerDeployment.put(account.Id, serverDeployment);

		List<Product2> products = [SELECT Id FROM Product2 LIMIT 1];
		POC_Request__c pocRequest = [
			SELECT Id, Account__c, Start_Date__c, End_Date__c, Quantity__c
			FROM POC_Request__c
			LIMIT 1
		];
		Map<Id, POC_Request__c> productIdToPOCRequest = new Map<Id, POC_Request__c>();
		for (Product2 product : products) {
			productIdToPOCRequest.put(product.Id, pocRequest);
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountEntitlementTriggerUtility.createAccountEntitlementsPOCRequestSolutions(
				productIdToPOCRequest,
				accountIdToServerDeployment
			);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];
		Assert.isFalse(accountEntitlements.isEmpty());
		Assert.isFalse(serverDeploymentSubscriptions.isEmpty());
	}
}