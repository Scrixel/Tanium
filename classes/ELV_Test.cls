@IsTest
public with sharing class ELV_Test {

    // @TestSetup
    // static void setup() {
    //     NueTestFactory.createNewQuoteScenario();
    // }


    

     @IsTest
	static void testOrderCreation() {

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

            Ruby.RubySettingService.globalSeedSystemSettings();
            Ruby.RubySettingService.globalSeedObjectMappings();

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
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Account__c = acct.Id,
				SBQQ__Status__c = 'Accepted',
				SBQQ__Type__c = 'Quote',
				SBQQ__SubscriptionTerm__c = 30,
				PaymentTypeNew__c = 'Annual Installment',
				First_Billing_Override__c = false,
				No_of_Installments__c = 2,
				SBQQ__Primary__c = true
			);
			insert quote;

			Order order = new Order(
				AccountId = acct.Id,
				OpportunityId = opp.Id,
				SBQQ__Quote__c = quote.Id,
				EffectiveDate = System.today(),
				Status = 'Draft'
			);
			insert order;
			update order;
		}
	}


}