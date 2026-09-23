/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for Server Deployment Subscription Trigger Utility, part of Trigger Framework
 * @Date: 2026-01-12
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2026-01-12      Initial development
 */
@IsTest
private class ServerDeploymentSubTriggerUtilityTest {
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

			List<Account_Entitlements__c> accountEntitlements = new List<Account_Entitlements__c>();
			accountEntitlements.add(
				TestFactory.buildAccountEntitlement(account.Id, 'Subscription', modules[0].Id, 5000.00)
			);
			insert accountEntitlements;
		}
	}

	@IsTest
	static void testCreateServerDeploymentSubscriptions_Always_CreateServerDeploymentSubscriptions() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Server_Deployment__c serverDeployment = [
			SELECT Id, Account__c
			FROM Server_Deployment__c
			WHERE Account__c = :account.Id
		];
		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();
		accountIdToServerDeployment.put(account.Id, serverDeployment);

		List<Account_Entitlements__c> accountEntitlements = [
			SELECT
				Id,
				Account__c,
				Source_Subscription__c,
				Quantity_Purchased__c,
				Quantity_Allocated__c,
				Type__c,
				Module__c,
				Product__c,
				Start_Date__c,
				End_Date__c
			FROM Account_Entitlements__c
			WHERE Account__c = :account.Id
		];

		Test.startTest();
		ServerDeploymentSubTriggerUtility.createServerDeploymentSubscriptions(
			accountEntitlements,
			accountIdToServerDeployment,
			true
		);
		Test.stopTest();

		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];
		Assert.isTrue(serverDeploymentSubscriptions.size() > 0);
	}
}