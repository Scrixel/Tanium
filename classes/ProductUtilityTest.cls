/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Test class for ProductUtility
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12364   2026-01-22    Created the class
 * SS-12818   2026-03-18    Updated test method for getProductIdToProductModuleNames
 */
@IsTest
private class ProductUtilityTest {
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
				'ProductTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Product2> products = new List<Product2>();
			products.add(new Product2(Name = 'Core Product', ProductCode = 'Core', IsActive = true));
			products.add(
				new Product2(Name = 'Discover Product', ProductCode = 'Discover', IsActive = true)
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
			insert productModules;
		}
	}

	@IsTest
	static void testGetProductModuleNames_WhenProductWithProductModules_ReturnsProductModuleNames() {
		Map<Id, Product2> productMap = new Map<Id, Product2>([SELECT Id FROM Product2]);
		Map<Id, Set<String>> productIdToProductModuleNames;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			productIdToProductModuleNames = ProductUtility.getProductIdToProductModuleNames(
				productMap.keySet()
			);
			Test.stopTest();
		}

		Assert.areEqual(2, productIdToProductModuleNames.size(), 'Expected 2 product module names');
	}
}