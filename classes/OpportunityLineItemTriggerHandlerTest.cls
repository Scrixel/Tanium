/**
 * @Business: Test class for OpportunityLineItemTriggerHandler
 * @Date: 2017-12-11
 * @Author: Cumulus Vision
 * @Request: TAN-463
 * Modified  ModifiedDate   Description
 * TAN-463   2017-12-11     Initial Development
 * TAN-536   2018-04-14     Modified Account creation as per "Country_Restriction" validation rule on opportunity
 * SS-7583	 2024-03-21			Remove BoomiRestService class
 */
@IsTest
private class OpportunityLineItemTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteLineTriggerHandler',
				'QuoteCPQTriggerHandler',
				'UserTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();

		System.runAs(TestUserFactory.getAdminUser()) {
			Product2 product = TestFactory.buildProduct('Test Product', 'TEST-PROD-1');
			insert product;

			PricebookEntry pricebookEntry = TestFactory.buildPricebookEntry(
				product.Id,
				10.00,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			insert pricebookEntry;

			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addDays(30),
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Type = 'New Customer';
			opp.Deal_Reviewed_in_Workshop__c = true;
			insert opp;

			SBQQ__Quote__c testQuote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				'Quote',
				System.today(),
				System.today().addDays(30),
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			insert testQuote;

			SBQQ__QuoteLine__c quoteLine = TestFactory.buildSBQQ_QuoteLine(testQuote.Id, product.Id, 1);
			quoteLine.SBQQ__CustomerPrice__c = 100;

			List<OpportunityLineItem> oppLineItems = new List<OpportunityLineItem>();
			oppLineItems.add(TestFactory.buildOpportunityLineItem(opp.Id, 1, 100, pricebookEntry.Id));
			oppLineItems[0].Product2Id = product.Id;
			oppLineItems.add(TestFactory.buildOpportunityLineItem(opp.Id, 1, 100, pricebookEntry.Id));
			oppLineItems[1].Product2Id = product.Id;
			insert oppLineItems;

			Billing_Schedule__c billingSchedule = TestFactory.buildBillingSchedule(opp.Id);
			billingSchedule.Billing_Amount__c = 100;

			insert new List<SObject>{ quoteLine, billingSchedule };
			update oppLineItems;
			delete oppLineItems[1];
		}
	}

	@IsTest
	static void beforeUpdate_WhenOpportunityHasLockedStage_ShowsError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity testOpportunity = [SELECT Id, StageName FROM Opportunity LIMIT 1];
			testOpportunity.StageName = OpportunityQuoteLineLockUtility.LOCKED_OPPORTUNITY_STAGES[0];
			update testOpportunity;
		}

		List<OpportunityLineItem> opportunityProductList = [
			SELECT Id, Quantity
			FROM OpportunityLineItem
		];
		String actualErrorMessage = '';

		System.runAs(TestUserFactory.createSalesOpsUser()) {
			Test.startTest();
			try {
				for (OpportunityLineItem opportunityProduct : opportunityProductList) {
					opportunityProduct.Quantity++;
				}
				update opportunityProductList;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(actualErrorMessage.contains(System.Label.Opportunity_Product_Locked));
	}

	@IsTest
	static void beforeDelete_WhenOpportunityHasLockedStage_ShowsError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity testOpportunity = [SELECT Id, StageName FROM Opportunity LIMIT 1];
			testOpportunity.StageName = OpportunityQuoteLineLockUtility.LOCKED_OPPORTUNITY_STAGES[0];
			update testOpportunity;
		}

		List<OpportunityLineItem> opportunityProductList = [SELECT Id FROM OpportunityLineItem];
		String actualErrorMessage = '';

		System.runAs(TestUserFactory.createSalesOpsUser()) {
			Test.startTest();
			try {
				delete opportunityProductList;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}

		System.assert(actualErrorMessage.contains(System.Label.Opportunity_Product_Locked));
	}

	@IsTest
	static void afterDelete_WhenOppHasNoHardwareProduct_UncheckHardwareOpp() {
		List<OpportunityLineItem> opportunityProductList = [SELECT Id FROM OpportunityLineItem];
		String actualErrorMessage = '';

		System.runAs(TestUserFactory.createSalesOpsUser()) {
			Test.startTest();
			try {
				delete opportunityProductList;
			} catch (Exception error) {
				actualErrorMessage = error.getMessage();
			}
			Test.stopTest();
		}
		Opportunity opp = [
			SELECT Id, New_Tanium_Physical_Appliance_Required__c
			FROM Opportunity
			LIMIT 1
		];

		Assert.isTrue(
			opp.New_Tanium_Physical_Appliance_Required__c == false,
			'Hardware Opp field should be false.'
		);
		Assert.isTrue(String.isBlank(actualErrorMessage), 'No error should occur.');
	}
}