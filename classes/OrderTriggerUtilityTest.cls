/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OrderTriggerHandler and OrderTriggerUtility
 * @Date: 2023-08-04
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7566    2024-03-01    Updated test class
 * SS-7583    2024-03-21    Removing BoomiRestService code references
 * SS-12400   2026-01-22    Removed CAM_Name__c field from test class
 * SS-13646   2026-08-12    Moved OrderTriggerHandlerTest coverage here
 */
@IsTest
private class OrderTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);

		Id currentUserId = UserInfo.getUserId();
		System.runAs(TestUserFactory.getAdminUser()) {
			TestFactory.seedRubySettings();

			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Global Pricebook description.',
				IsActive = true
			);
			String fieldApiName = 'Ruby__PriceAttributes__c';
			Map<String, Schema.SObjectField> pricebookFields = Schema.SObjectType.Pricebook2.fields.getMap();
			if (pricebookFields.containsKey(fieldApiName)) {
				globalPriceBook.put(fieldApiName, 'Currency;UOM');
			}
			insert globalPriceBook;

			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				'Prospecting',
				acct.Id
			);
			opp.OwnerId = currentUserId;
			insert opp;

			SBQQ__Quote__c quote = new SBQQ__Quote__c(
				SBQQ__StartDate__c = Date.today(),
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = opp.Id,
				SBQQ__PriceBook__c = globalPriceBook.Id,
				SBQQ__Account__c = acct.Id,
				SBQQ__Status__c = 'Accepted',
				SBQQ__Type__c = 'Quote',
				SBQQ__SubscriptionTerm__c = 30,
				PaymentTypeNew__c = BillingScheduleConfiguratorController.ANNUAL_PAYMENT_TYPE,
				First_Billing_Override__c = false,
				No_of_Installments__c = 2,
				SBQQ__Primary__c = true
			);
			insert quote;

			Quote nueQuote = new Quote(
				Name = 'Test NUE Quote',
				OpportunityId = opp.Id,
				Pricebook2Id = globalPriceBook.Id,
				BillingCity = 'Kirkland'
			);
			insert nueQuote;

			Order sbqqOrder = new Order(
				AccountId = acct.Id,
				OpportunityId = opp.Id,
				SBQQ__Quote__c = quote.Id,
				Pricebook2Id = globalPriceBook.Id,
				EffectiveDate = System.today(),
				Status = 'Draft'
			);
			insert sbqqOrder;

			Order nueOrder = new Order(
				AccountId = acct.Id,
				OpportunityId = opp.Id,
				QuoteId = nueQuote.Id,
				Pricebook2Id = globalPriceBook.Id,
				EffectiveDate = System.today(),
				Status = 'Draft'
			);
			insert nueOrder;

			Product2 product = TestFactory.buildProduct('Test Product', 'TEST-PROD-1');
			insert product;

			PricebookEntry standardPricebookEntry = TestFactory.buildPricebookEntry(
				product.Id,
				10.00,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			insert standardPricebookEntry;

			PricebookEntry globalPricebookEntry = TestFactory.buildPricebookEntry(
				product.Id,
				10.00,
				globalPriceBook.Id
			);
			insert globalPricebookEntry;

			insert new OrderItem(
				OrderId = nueOrder.Id,
				PricebookEntryId = globalPricebookEntry.Id,
				Quantity = 1,
				UnitPrice = 10.00
			);
		}
	}

	@IsTest
	static void testPublishOrders_Always_PublishOrders() {
		List<Order> orders = [
			SELECT
				Id,
				CreatedDate,
				AccountId,
				Entity_ID__c,
				OpportunityId,
				SBQQ__Quote__c,
				OrderNumber,
				Owner_Department_ID__c,
				Owner_Location_ID__c,
				Owner_NS_ID__c,
				Reseller_NS__c,
				Subsidiary__c,
				Subsidiary_NS__c,
				TotalAmount
			FROM Order
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OrderTriggerUtility.publishOrders(orders);
			Test.stopTest();
		}
		List<Integration_Callout__c> callouts = [SELECT Id FROM Integration_Callout__c];
		Assert.isFalse(callouts.isEmpty());
	}

	@IsTest
	static void testPublishNueOrderEvents_OrderNewlyActivated_PublishOrders() {
		List<Order> orders = [
			SELECT
				Id,
				CreatedDate,
				AccountId,
				Entity_ID__c,
				OpportunityId,
				QuoteId,
				OrderNumber,
				Owner_Department_ID__c,
				Owner_Location_ID__c,
				Owner_NS_ID__c,
				Reseller_NS__c,
				Status,
				Subsidiary__c,
				Subsidiary_NS__c,
				TotalAmount
			FROM Order
			WHERE QuoteId != null
		];
		Map<Id, Order> oldOrderMap = new Map<Id, Order>(orders.deepClone(true, true, true));
		for (Order order : orders) {
			order.Status = 'Activated';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OrderTriggerUtility.publishNueOrderEvents(orders, oldOrderMap);
			Test.stopTest();
		}
		List<Integration_Callout__c> callouts = [
			SELECT Id
			FROM Integration_Callout__c
			WHERE Name LIKE 'ELV_Order_Event__e%'
		];
		Assert.isFalse(callouts.isEmpty());
	}

	@IsTest
	static void testAfterUpdate_OrderActivatedViaDml_PublishesNueOrderEvent() {
		List<Order> orders = [SELECT Id, Status FROM Order WHERE QuoteId != null];
		for (Order order : orders) {
			order.Status = 'Activated';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update orders;
			Test.stopTest();
		}

		List<Integration_Callout__c> callouts = [
			SELECT Id
			FROM Integration_Callout__c
			WHERE Name LIKE 'ELV_Order_Event__e%'
		];
		Assert.isFalse(callouts.isEmpty());
	}
}