/**
 * @Business: Testclass for SBQQ_QuoteCalculator
 * @Authors:  Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-6987    2024-01-04    Created the class
 */
@IsTest
private class SBQQ_QuoteCalculatorTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Global Pricebook description.',
				IsActive = true
			);
			insert globalPriceBook;
			Account account = TestFactory.buildAccount('Test Account');
			account.Seats_Purchased1__c = 26000;
			account.Total_Addressable_Seats__c = 5000;
			insert account;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				'Prospecting',
				account.Id
			);
			opp.Type = 'New Customer';
			insert opp;

			SBQQ__Quote__c quote = new SBQQ__Quote__c(
				SBQQ__Account__c = account.Id,
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = opp.Id,
				SBQQ__PaymentTerms__c = 'Net 30',
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Primary__c = true,
				SBQQ__StartDate__c = Date.today(),
				SBQQ__Status__c = 'Accepted',
				SBQQ__SubscriptionTerm__c = 30,
				SBQQ__Type__c = 'Quote'
			);
			insert quote;

			Product2 product = new Product2(
				IsActive = true,
				Name = 'FLAT_SKU_PRODUCT',
				Description = 'Flat SKU Product',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = false,
				SBQQ__SubscriptionPricing__c = 'One-time'
			);
			insert product;

			SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c(
				SBQQ__Bundle__c = false,
				Bundled_Product__c = false,
				SBQQ__StartDate__c = Date.today() + 100,
				SBQQ__Quantity__c = 1,
				SBQQ__Quote__c = quote.Id,
				SBQQ__Product__c = product.Id,
				SBQQ__SubscriptionTerm__c = 40,
				SBQQ__NetPrice__c = 1000
			);
			insert quoteLine;
		}
	}

	@IsTest
	static void testSBQQ_QuoteCalculator() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);
		SBQQ_ApiDataModels.QuoteModel quoteModel;
		SBQQ_QuoteCalculator calculator = new SBQQ_QuoteCalculator();
		SBQQ_QuoteReader reader = new SBQQ_QuoteReader();
		SBQQ__Quote__c[] quotes = [SELECT Id FROM SBQQ__Quote__c];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			quoteModel = reader.read(String.valueOf(quotes[0].Id));
			quoteModel.lineItems[0].record.SBQQ__Quantity__c = 2;
			calculator.calculate(quoteModel, 'SBQQ_CalculateCallback');
			Test.stopTest();
		}
	}
}