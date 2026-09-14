/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OpportunityRenewalUtility class
 * @Date: 2024-03-21
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-7583      2024-03-21      Removing BoomiRestService code references
 * SS-7996      2024-07-20      Fix test class issues
 * SS-8984      2024-08-27      Remove Event Logs
 * SS-13034     2026-04-30      Fixed test methods by bypassing flows
 */
@IsTest
private class OpportunityRenewalUtilityTest {
	private final static Date opportunityCloseDate = System.today();
	private final static Date quoteInitialStartDate = System.today().addDays(100);
	private static Integer daysDelta = -10;

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteLineTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();

		User adminUser = TestUserFactory.createTaniumAdminUser(true);
		TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
		TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');

		System.runAs(adminUser) {
			Product2 product = TestFactory.buildProduct('Test Product', 'TAN-XXXX');

			Account acc = new Account(
				Name = 'Test Account',
				Total_Addressable_Seats__c = 1000,
				Type = 'Analyst',
				Active_Account__c = true
			);

			insert new List<Sobject>{ acc, product };

			Opportunity opp = new Opportunity(
				Name = 'Test Opp',
				CloseDate = opportunityCloseDate,
				StageName = Utility.CLOSED_WON,
				AccountId = acc.Id,
				Pricebook2Id = Test.getStandardPricebookId()
			);

			PricebookEntry pricebookEntry = TestFactory.buildPricebookEntry(
				product.Id,
				10.00,
				Test.getStandardPricebookId()
			);

			insert new List<Sobject>{ opp, pricebookEntry };

			SBQQ__Quote__c testQuote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				null,
				null,
				null,
				null
			);
			testQuote.SBQQ__StartDate__c = quoteInitialStartDate;
			testQuote.SBQQ__EndDate__c = quoteInitialStartDate.addDays(10);
			insert testQuote;

			SBQQ__QuoteLine__c quoteLine1 = TestFactory.buildSBQQ_QuoteLine(
				testQuote.Id,
				pricebookEntry.Product2Id,
				2
			);
			quoteLine1.SBQQ__StartDate__c = opportunityCloseDate;
			quoteLine1.SBQQ__EndDate__c = quoteLine1.SBQQ__StartDate__c.addDays(20);

			SBQQ__QuoteLine__c quoteLine2 = TestFactory.buildSBQQ_QuoteLine(
				testQuote.Id,
				pricebookEntry.Product2Id,
				2
			);
			quoteLine2.SBQQ__StartDate__c = opportunityCloseDate.addDays(daysDelta);
			quoteLine2.SBQQ__EndDate__c = quoteLine2.SBQQ__StartDate__c.addDays(20);

			insert new List<SBQQ__QuoteLine__c>{ quoteLine1, quoteLine2 };
		}
	}

	@IsTest
	static void updateQuotesAndLinesStartDates_WhenOpportunityStageNameChangedToCloseWon_UpdatesStartDatesOnQuote() {
		SBQQ__Quote__c quote = [
			SELECT Id, SBQQ__Primary__c, SBQQ__Opportunity2__r.CloseDate
			FROM SBQQ__Quote__c
			LIMIT 1
		];
		System.runAs(getDealDeskUser()) {
			SBQQ.TriggerControl.disable();
			quote.SBQQ__Primary__c = true;
			update quote;

			Opportunity newOpportunity = [SELECT Id, StageName FROM Opportunity LIMIT 1];
			List<Opportunity> newOpportunityList = new List<Opportunity>{ newOpportunity };
			Map<Id, Opportunity> oldOpportunityMap = new Map<Id, Opportunity>{
				newOpportunity.Id => new Opportunity(StageName = Utility.PROSPECTING)
			};

			Test.startTest();
			OpportunityRenewalUtility.updateQuotesAndLinesStartDates(
				newOpportunityList,
				oldOpportunityMap
			);
			Test.stopTest();
		}

		SBQQ__Quote__c actualQuote = [SELECT Id, SBQQ__StartDate__c FROM SBQQ__Quote__c LIMIT 1];
		Assert.areEqual(quote.SBQQ__Opportunity2__r.CloseDate, actualQuote.SBQQ__StartDate__c);
	}

	@IsTest
	static void updateQuotesAndLinesStartDates_WhenOpportunityStageNameDidNotChange_DoesNotChange() {
		Opportunity newOpportunity = [SELECT Id, StageName FROM Opportunity LIMIT 1];
		List<Opportunity> newOpportunityList = new List<Opportunity>{ newOpportunity };
		Map<Id, Opportunity> oldOpportunityMap = new Map<Id, Opportunity>{
			newOpportunity.Id => newOpportunity
		};

		System.runAs(TestUserFactory.createDealDeskUser()) {
			Test.startTest();
			OpportunityRenewalUtility.updateQuotesAndLinesStartDates(
				newOpportunityList,
				oldOpportunityMap
			);
			Test.stopTest();
		}

		SBQQ__Quote__c actualQuote = [SELECT Id, SBQQ__StartDate__c FROM SBQQ__Quote__c LIMIT 1];
		Assert.areEqual(quoteInitialStartDate, actualQuote.SBQQ__StartDate__c);
	}

	@IsTest
	static void generateRenewalDataWrapperMap_WhenQuoteIsPrimary_ReturnsRenewalDataWrapperMap() {
		Map<Id, OpportunityRenewalUtility.RenewalDataWrapper> dataWrapperMap;
		SBQQ__Quote__c quote = [SELECT Id, SBQQ__Primary__c FROM SBQQ__Quote__c LIMIT 1];

		System.runAs(getDealDeskUser()) {
			quote.SBQQ__Primary__c = true;
			update quote;

			Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];

			Test.startTest();
			dataWrapperMap = OpportunityRenewalUtility.generateRenewalDataWrapperMap(
				new Set<Id>{ testOpportunity.Id }
			);
			Test.stopTest();
		}

		Assert.areEqual(
			quote.Id,
			dataWrapperMap.values()[0].quote.Id,
			'Primary Quote should be affected'
		);
	}

	@IsTest
	static void generateRenewalDataWrapperMap_WhenQuoteIsNotPrimary_ReturnsEmptyMap() {
		Map<Id, OpportunityRenewalUtility.RenewalDataWrapper> dataWrapperMap;
		SBQQ__Quote__c quote = [SELECT Id, SBQQ__Primary__c FROM SBQQ__Quote__c LIMIT 1];

		System.runAs(getDealDeskUser()) {
			quote.SBQQ__Primary__c = false;

			update quote;

			Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];

			Test.startTest();
			dataWrapperMap = OpportunityRenewalUtility.generateRenewalDataWrapperMap(
				new Set<Id>{ testOpportunity.Id }
			);
			Test.stopTest();
		}

		Assert.areEqual(0, dataWrapperMap.size(), 'Non primary quotes should not be affected');
	}

	@IsTest
	static void generateRenewalDataWrapperMap_WhenQuoteLockInDates_ReturnsEmptyMap() {
		Map<Id, OpportunityRenewalUtility.RenewalDataWrapper> dataWrapperMap;
		SBQQ__Quote__c quote = [SELECT Id, Do_Not_Show_Dates__c FROM SBQQ__Quote__c LIMIT 1];

		System.runAs(getDealDeskUser()) {
			quote.Do_Not_Show_Dates__c = true;
			quote.SBQQ__Primary__c = true;

			TriggerHandler.bypass('QuoteCPQTriggerHandler');
			update quote;
			TriggerHandler.clearBypass('QuoteCPQTriggerHandler');

			Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];

			Test.startTest();
			dataWrapperMap = OpportunityRenewalUtility.generateRenewalDataWrapperMap(
				new Set<Id>{ testOpportunity.Id }
			);
			Test.stopTest();
		}

		Assert.areEqual(
			0,
			dataWrapperMap.size(),
			'Quotes with Lock in Dates & Display on Quote checked should not be affected'
		);
	}

	@IsTest
	static void renewalDataWrapperConstructor_Always_UpdatesStartDatesOnQuoteAndQuoteLines() {
		OpportunityRenewalUtility.RenewalDataWrapper dataWrapper;
		SBQQ__Quote__c quote = [
			SELECT
				Id,
				SBQQ__StartDate__c,
				SBQQ__Opportunity2__r.CloseDate,
				(SELECT Id, SBQQ__StartDate__c FROM SBQQ__LineItems__r ORDER BY SBQQ__StartDate__c ASC)
			FROM SBQQ__Quote__c
			LIMIT 1
		];

		System.runAs(TestUserFactory.createDealDeskUser()) {
			Test.startTest();
			dataWrapper = new OpportunityRenewalUtility.RenewalDataWrapper(quote);
			Test.stopTest();
		}

		Assert.areEqual(
			quote.SBQQ__Opportunity2__r.CloseDate,
			dataWrapper.quote.SBQQ__StartDate__c,
			'Quote start date should match opportunity close date'
		);
		Assert.areEqual(
			quote.SBQQ__Opportunity2__r.CloseDate,
			dataWrapper.quoteLines[0].SBQQ__StartDate__c,
			'Earliest Quote Line start date should match opportunity close date'
		);
		Assert.areEqual(
			quote.SBQQ__Opportunity2__r.CloseDate,
			dataWrapper.quoteLines[1].SBQQ__StartDate__c.addDays(daysDelta),
			'Other Quote Line start date should be offset by Days Delta'
		);
	}

	static User getDealDeskUser() {
		User[] dealDeskUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.DEAL_DESK_USER];
		if (dealDeskUsers.isEmpty()) {
			User dealDeskUser = TestUserFactory.createDealDeskUser();
			TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableFlows');
			return dealDeskUser;
		}
		return dealDeskUsers[0];
	}
}