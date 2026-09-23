/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OpportunityLineItemTriggerUtility
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12400   2026-01-22    Removed Primary_Contact__c field from test class
 */
@IsTest
private with sharing class OpportunityLineItemTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler',
				'BillingScheduleTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Account> accounts = new List<Account>();
			accounts.add(TestFactory.buildAccount('Test Account'));
			accounts[0].Active_Account__c = true;
			insert accounts;

			Contact con = TestFactory.buildContact(accounts[0].Id);
			insert con;

			List<Opportunity> opps = new List<Opportunity>();
			opps.add(
				TestFactory.buildOpportunity(
					'Hardware Opportunity 1',
					Date.today() + 30,
					'Prospecting',
					accounts[0].Id
				)
			);
			opps[0].OwnerId = UserInfo.getUserId();
			opps[0].New_Tanium_Physical_Appliance_Required__c = true;

			opps.add(
				TestFactory.buildOpportunity(
					'Hardware and Software Opportunity 2',
					Date.today() + 30,
					'Prospecting',
					accounts[0].Id
				)
			);
			opps[1].OwnerId = UserInfo.getUserId();
			opps[1].New_Tanium_Physical_Appliance_Required__c = true;
			opps[1].Software_Opportunity__c = true;

			opps.add(
				TestFactory.buildOpportunity(
					'Not Hardware nor Software Opportunity 3',
					Date.today() + 30,
					'Prospecting',
					accounts[0].Id
				)
			);
			opps[2].OwnerId = UserInfo.getUserId();
			opps[2].New_Tanium_Physical_Appliance_Required__c = false;
			opps[2].Software_Opportunity__c = false;

			opps.add(
				TestFactory.buildOpportunity(
					'No OppLineItems Opportunity 4',
					Date.today() + 30,
					'Prospecting',
					accounts[0].Id
				)
			);
			opps[3].OwnerId = UserInfo.getUserId();
			opps[3].New_Tanium_Physical_Appliance_Required__c = true;
			opps[3].Software_Opportunity__c = true;
			insert opps;

			List<Product2> products = new List<Product2>();
			products.add(TestFactory.buildProduct('HW Appliance 1', 'HWA1'));
			products[0].Family = 'Hardware';
			products[0].Product_Line__c = 'Appliance';

			products.add(TestFactory.buildProduct('Cloud Product 1', 'CP1'));
			products.add(TestFactory.buildProduct('Cloud Product 2', 'CP2'));
			products.add(TestFactory.buildProduct('SW Product 1', 'SW1'));
			products[3].Product_Group__c = 'Software';
			products[3].Server_Deployment_Required__c = true;
			products.add(TestFactory.buildProduct('Cloud Product 3', 'CP3'));
			insert products;

			Id pricebookId = Test.getStandardPricebookId();
			List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
			pricebookEntries.add(TestFactory.buildPricebookEntry(products[0].Id, 1.0, pricebookId));
			pricebookEntries.add(TestFactory.buildPricebookEntry(products[1].Id, 1.0, pricebookId));
			pricebookEntries.add(TestFactory.buildPricebookEntry(products[2].Id, 1.0, pricebookId));
			pricebookEntries.add(TestFactory.buildPricebookEntry(products[3].Id, 1.0, pricebookId));
			pricebookEntries.add(TestFactory.buildPricebookEntry(products[4].Id, 1.0, pricebookId));
			insert pricebookEntries;

			List<OpportunityLineItem> oppLineItems = new List<OpportunityLineItem>();
			oppLineItems.add(
				TestFactory.buildOpportunityLineItem(opps[0].Id, 1, 100, pricebookEntries[0].Id)
			);
			oppLineItems[0].Product2Id = products[0].Id;

			oppLineItems.add(
				TestFactory.buildOpportunityLineItem(opps[0].Id, 1, 100, pricebookEntries[1].Id)
			);
			oppLineItems[1].Product2Id = products[1].Id;

			oppLineItems.add(
				TestFactory.buildOpportunityLineItem(opps[1].Id, 1, 100, pricebookEntries[2].Id)
			);
			oppLineItems[2].Product2Id = products[2].Id;

			oppLineItems.add(
				TestFactory.buildOpportunityLineItem(opps[1].Id, 1, 100, pricebookEntries[2].Id)
			);
			oppLineItems[2].Product2Id = products[2].Id;

			oppLineItems.add(
				TestFactory.buildOpportunityLineItem(opps[1].Id, 1, 100, pricebookEntries[3].Id)
			);
			oppLineItems[3].Product2Id = products[3].Id;

			oppLineItems.add(
				TestFactory.buildOpportunityLineItem(opps[2].Id, 1, 100, pricebookEntries[4].Id)
			);
			oppLineItems[4].Product2Id = products[4].Id;
			insert oppLineItems;
		}
	}

	@IsTest
	private static void testUncheckHardwareOpportunity_WhenNoOppLines_UncheckHardwareOpportunity() {
		OpportunityLineItem[] oppLineItems = [
			SELECT Id, OpportunityId, Product2Id
			FROM OpportunityLineItem
		];
		OpportunityLineItem oppLineItem = oppLineItems.remove(0);

		Test.startTest();
		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityLineItemTriggerUtility.uncheckHardwareOpportunity(oppLineItems);
		}
		Test.stopTest();

		List<Opportunity> opps = [
			SELECT Id, New_Tanium_Physical_Appliance_Required__c
			FROM Opportunity
		];
		Assert.isFalse(opps[0].New_Tanium_Physical_Appliance_Required__c);
	}

	@IsTest
	private static void testSetIsSoftwareOpportunity_WhenSoftwareOppLines_CheckSoftwareOpportunity() {
		Opportunity opp = [
			SELECT Id
			FROM Opportunity
			WHERE Name = 'Hardware and Software Opportunity 2'
			LIMIT 1
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			TriggerHandler.bypass(new List<String>{ 'OpportunityTriggerHandler' });
			update opp;
			opp.Software_Opportunity__c = false;
		}
		OpportunityLineItem[] oppLineItems = [
			SELECT Id, OpportunityId, Product2Id
			FROM OpportunityLineItem
			WHERE OpportunityId = :opp.Id
		];

		Test.startTest();
		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityLineItemTriggerUtility.setIsSoftwareOpportunity(oppLineItems);
		}
		Test.stopTest();

		List<Opportunity> opps = [
			SELECT Id, Software_Opportunity__c
			FROM Opportunity
			WHERE Name = 'Hardware and Software Opportunity 2'
		];
		Assert.isTrue(opps[0].Software_Opportunity__c);
	}

	@IsTest
	private static void testSetIsSoftwareOpportunity_WhenNoSoftwareOppLines_UncheckSoftwareOpportunity() {
		Opportunity softwareOpp = [
			SELECT Id
			FROM Opportunity
			WHERE Name = 'Hardware and Software Opportunity 2'
			LIMIT 1
		];
		OpportunityLineItem[] oppLineItems = [
			SELECT Id, OpportunityId, Product2Id
			FROM OpportunityLineItem
			WHERE OpportunityId = :softwareOpp.Id
		];
		Map<Id, Product2> productsMap = new Map<Id, Product2>(
			[SELECT Id, Product_Group__c FROM Product2]
		);
		List<OpportunityLineItem> oppLineItemsToDelete = new List<OpportunityLineItem>();
		for (Integer i = 0; i < oppLineItems.size(); i++) {
			if (productsMap.get(oppLineItems[i].Product2Id).Product_Group__c == 'Software') {
				oppLineItemsToDelete.add(oppLineItems.remove(i));
			}
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			TriggerHandler.bypass(new List<String>{ 'OpportunityLineItemTriggerHandler' });
			delete oppLineItemsToDelete;
		}

		Test.startTest();
		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityLineItemTriggerUtility.setIsSoftwareOpportunity(oppLineItems);
		}
		Test.stopTest();

		List<Opportunity> opps = [
			SELECT Id, Software_Opportunity__c
			FROM Opportunity
			WHERE Name = 'Hardware and Software Opportunity 2'
		];
		Assert.isFalse(opps[0].Software_Opportunity__c);
	}
}