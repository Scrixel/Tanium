/**
 * @Business: Test class for  QuoteRequestTriggerUtility
 * @Date: 2024-12-09
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11140   2024-12-10    Created the Utility class
 * SS-12876   2026-04-01    Removed test method for updating quote request
 */
@IsTest
private class QuoteRequestTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				System.today().addDays(120),
				'New',
				acc.Id
			);
			insert opp;

			Deal_Registration__c dealRegistration = TestFactory.buildDealReg(
				'First',
				'Last',
				'first.last@testcompany.io',
				'Test Company'
			);
			dealRegistration.Mapped_Opportunity__c = opp.Id;
			dealRegistration.or_New_Opp_Reg__c = true;
			dealRegistration.or_Create_Opportunity_upon_Approval__c = true;
			dealRegistration.or_Opportunity_Registration__c = 'Partner Sourced';
			dealRegistration.or_Opp_Reg_Status__c = 'Approved';
			insert dealRegistration;

			Quote_Request__c quoteRequest = new Quote_Request__c();
			quoteRequest.Deal_Registration__c = dealRegistration.Id;
			quoteRequest.Submitter_Role__c = 'Distributor';
			quoteRequest.Multi_Tier_Transaction__c = false;
			quoteRequest.Subscription_Term__c = 12;
			quoteRequest.Partner_Email__c = 'partner@email.com';
			insert quoteRequest;

			Product2 product = new Product2(
				Name = 'Product',
				Description = 'Product description',
				IsActive = true
			);
			insert product;

			Quote_Request_Products__c quoteRequestProduct = new Quote_Request_Products__c();
			quoteRequestProduct.Quote_Request__c = quoteRequest.Id;
			quoteRequestProduct.Product__c = product.Id;
			quoteRequestProduct.Quantity__c = 100;
			quoteRequestProduct.Term__c = 12;
			insert quoteRequestProduct;

			delete quoteRequestProduct;
		}
	}

	@IsTest
	static void testProcessQuoteRequestEvent_WhenValidQuoteRequestEvent_InsertQuoteRequest() {
		Deal_Registration__c dealRegistration = [SELECT Id FROM Deal_Registration__c LIMIT 1];

		List<QuoteRequest_Event__e> quoteRequestEvents = new List<QuoteRequest_Event__e>();
		QuoteRequest_Event__e quoteRequestEvent;

		System.runAs(TestUserFactory.getAdminUser()) {
			quoteRequestEvent = new QuoteRequest_Event__e();
			quoteRequestEvent.DealRegId__c = dealRegistration.Id;
			quoteRequestEvent.SubmitterRole__c = 'Reseller';
			quoteRequestEvent.MultiTierTransaction__c = false;
			quoteRequestEvent.SubscriptionTerm__c = 12;
			quoteRequestEvent.PartnerContactEmail__c = 'partnercontact@partner.io';
			quoteRequestEvent.DML_Operation__c = 'INSERT';
			quoteRequestEvents.add(quoteRequestEvent);

			Test.startTest();
			Database.SaveResult result = EventBus.publish(quoteRequestEvent);
			QuoteRequestTriggerUtility.processQuoteRequestEvent(quoteRequestEvents);
			Test.stopTest();

			Quote_Request__c[] quoteRequests = [
				SELECT Id
				FROM Quote_Request__c
				WHERE Submitter_Role__c = 'Reseller'
			];

			Assert.isFalse(quoteRequests.isEmpty());
		}
	}

	@IsTest
	static void testProcessQuoteRequestProductEvent_WhenValidQuoteRequestProductEvent_InsertQuoteRequestProduct() {
		Deal_Registration__c dealRegistration = [SELECT Id FROM Deal_Registration__c LIMIT 1];
		Quote_Request__c quoteRequest = [
			SELECT Id
			FROM Quote_Request__c
			WHERE Deal_Registration__c = :dealRegistration.Id
			LIMIT 1
		];

		List<QuoteRequest_Product_Event__e> quoteRequestProductEvents = new List<QuoteRequest_Product_Event__e>();
		QuoteRequest_Product_Event__e quoteRequestProductEvent;

		System.runAs(TestUserFactory.getAdminUser()) {
			quoteRequestProductEvent = new QuoteRequest_Product_Event__e();
			quoteRequestProductEvent.QuoteRequestId__c = quoteRequest.Id;
			quoteRequestProductEvent.DealRegId__c = dealRegistration.Id;
			quoteRequestProductEvent.Quantity__c = 500;
			quoteRequestProductEvent.SubscriptionTerm__c = 12;
			quoteRequestProductEvents.add(quoteRequestProductEvent);

			Test.startTest();
			Database.SaveResult[] results = EventBus.publish(quoteRequestProductEvents);
			QuoteRequestTriggerUtility.processQuoteRequestProductEvent(quoteRequestProductEvents);
			Test.stopTest();

			Quote_Request_Products__c[] quoteRequestProducts = [
				SELECT Id
				FROM Quote_Request_Products__c
			];

			Assert.isFalse(quoteRequestProducts.isEmpty());
		}
	}
}