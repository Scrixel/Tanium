/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OpportunityQuoteLineLockUtility
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * Modified   ModifiedDate   Description
 * SS-12676   2026-03-25     Deleted depreciated fields (Absorb_Transaction_ID__c)
 */

@IsTest
private class OpportunityQuoteLineLockUtilityTest {
	@TestSetup
	static void insertTestData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addDays(30),
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Type = 'New Customer';
			opp.BillingScheduleTotalAmountNew__c = 100;
			insert opp;

			SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				'Quote',
				System.today(),
				System.today().addDays(30),
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			quote.Unlock_Quote__c = false;
			insert quote;

			Product2 product = TestFactory.buildProduct('Test Product', 'TEST-PROD-1');
			insert product;

			PricebookEntry pricebookEntry = TestFactory.buildPricebookEntry(
				product.Id,
				10.00,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			insert pricebookEntry;

			List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();
			quoteLines.add(TestFactory.buildSBQQ_QuoteLine(quote.Id, product.Id, 1));
			quoteLines.add(TestFactory.buildSBQQ_QuoteLine(quote.Id, product.Id, 1));
			quoteLines.add(TestFactory.buildSBQQ_QuoteLine(quote.Id, product.Id, 1));
			insert quoteLines;
		}
	}

	@IsTest
	static void checkLockedOpportunityProducts_WhenOpportunityNotInLockedStage_ReturnsEmptyIdSet() {
		List<OpportunityLineItem> opportunityProductList = [SELECT Id FROM OpportunityLineItem];

		Test.startTest();
		Set<Id> actual = OpportunityQuoteLineLockUtility.checkLockedOpportunityProducts(
			opportunityProductList
		);
		Test.stopTest();

		System.assertEquals(0, actual.size(), 'Baseline Test, nothing should be locked here');
	}

	@IsTest
	static void checkLockedOpportunityProducts_WhenOpportunityIsAbsorb_ReturnsEmptyIdSet() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity testOpportunity = [
				SELECT Id, StageName
				FROM Opportunity
				LIMIT 1
			];
			testOpportunity.StageName = OpportunityQuoteLineLockUtility.LOCKED_OPPORTUNITY_STAGES[0];
			update testOpportunity;
		}

		List<OpportunityLineItem> opportunityProductList = [SELECT Id FROM OpportunityLineItem];
		Set<Id> actual = new Set<Id>();

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			actual = OpportunityQuoteLineLockUtility.checkLockedOpportunityProducts(
				opportunityProductList
			);
		}
		Test.stopTest();

		System.assertEquals(0, actual.size(), 'Absorb unlocks even Restricted stage');
	}

	@IsTest
	static void checkLockedOpportunityProducts_WhenUserHasUnlockPermission_ReturnsEmptyIdSet() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity testOpportunity = [
				SELECT Id, StageName
				FROM Opportunity
				LIMIT 1
			];
			testOpportunity.StageName = OpportunityQuoteLineLockUtility.LOCKED_OPPORTUNITY_STAGES[0];
			update testOpportunity;
		}

		List<OpportunityLineItem> opportunityProductList = [SELECT Id FROM OpportunityLineItem];

		Set<Id> actual = new Set<Id>();

		System.runAs(TestUserFactory.createDealDeskUser()) {
			Test.startTest();

			actual = OpportunityQuoteLineLockUtility.checkLockedOpportunityProducts(
				opportunityProductList
			);
			Test.stopTest();
		}

		System.assertEquals(
			0,
			actual.size(),
			'Custom Unlock Permission unlocks even Restricted stage'
		);
	}

	@IsTest
	static void checkLockedOpportunityProducts_WhenOpportunityHasLockedStage_ReturnsLockedOpportunityProductIdSet() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity testOpportunity = [SELECT Id, StageName FROM Opportunity LIMIT 1];
			testOpportunity.StageName = OpportunityQuoteLineLockUtility.LOCKED_OPPORTUNITY_STAGES[0];
			update testOpportunity;
		}

		List<OpportunityLineItem> opportunityProductList = [SELECT Id FROM OpportunityLineItem];
		Set<Id> actual = new Set<Id>();

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			actual = OpportunityQuoteLineLockUtility.checkLockedOpportunityProducts(
				opportunityProductList
			);
			Test.stopTest();
		}

		System.assertEquals(
			opportunityProductList.size(),
			actual.size(),
			'Locked Stage will lock opportunity products'
		);
	}

	@IsTest
	static void checkLockedQuoteLines_WhenUserHasUnlockPermission_ReturnsEmptyIdSet() {
		System.runAs(TestUserFactory.getAdminUser()) {
			SBQQ__Quote__c testQuote = [
				SELECT Id, SBQQ__Status__c, ApprovalStatus__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			testQuote.SBQQ__Status__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			testQuote.ApprovalStatus__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			update testQuote;
		}

		List<SBQQ__QuoteLine__c> quoteLineList = [SELECT Id FROM SBQQ__QuoteLine__c];
		Set<Id> actual = new Set<Id>();

		System.runAs(TestUserFactory.createDealDeskUser()) {
			Test.startTest();
			actual = OpportunityQuoteLineLockUtility.checkLockedQuoteLines(quoteLineList);
			Test.stopTest();
		}

		System.assertEquals(
			0,
			actual.size(),
			'Custom Unlock Permission unlocks even Restricted status'
		);
	}

	@IsTest
	static void checkLockedQuoteLines_WhenQuoteIsUnlocked_ReturnsEmptyIdSet() {
		System.runAs(TestUserFactory.getAdminUser()) {
			SBQQ__Quote__c testQuote = [
				SELECT Id, ApprovalStatus__c, SBQQ__Status__c, Unlock_Quote__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			testQuote.SBQQ__Status__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			testQuote.ApprovalStatus__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			testQuote.Unlock_Quote__c = true;
			update testQuote;
		}

		List<SBQQ__QuoteLine__c> quoteLineList = [SELECT Id FROM SBQQ__QuoteLine__c];
		Set<Id> actual = new Set<Id>();

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			actual = OpportunityQuoteLineLockUtility.checkLockedQuoteLines(quoteLineList);
			Test.stopTest();
		}

		System.assertEquals(
			0,
			actual.size(),
			'Unlock Quote checkbox unlocks even Locked Quote Status'
		);
	}

	@IsTest
	static void checkLockedQuoteLines_WhenOpportunityHasLockedStage_ReturnsEmptyIdSet() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity testOpportunity = [SELECT Id, StageName FROM Opportunity LIMIT 1];
			testOpportunity.StageName = OpportunityQuoteLineLockUtility.LOCKED_OPPORTUNITY_STAGES[0];
			update testOpportunity;
		}

		List<SBQQ__QuoteLine__c> quoteLineList = [SELECT Id FROM SBQQ__QuoteLine__c];
		Set<Id> actual = new Set<Id>();

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			actual = OpportunityQuoteLineLockUtility.checkLockedQuoteLines(quoteLineList);
			Test.stopTest();
		}

		System.assertEquals(
			0,
			actual.size(),
			'Locked Opportunity stage has no impact on Quote Lines'
		);
	}

	@IsTest
	static void checkLockedQuoteLines_WhenQuoteHasLockedStatus_ReturnsLockedQuoteLinesIdSet() {
		System.runAs(TestUserFactory.getAdminUser()) {
			SBQQ__Quote__c testQuote = [
				SELECT Id, ApprovalStatus__c, SBQQ__Status__c
				FROM SBQQ__Quote__c
				LIMIT 1
			];
			testQuote.SBQQ__Status__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			testQuote.ApprovalStatus__c = OpportunityQuoteLineLockUtility.LOCKED_QUOTE_STATUSES[0];
			testQuote.Unlock_Quote__c = false;
			testQuote.Primary_Updated_and_Approved__c = false;
			TriggerHandler.bypass('QuoteCPQTriggerHandler');
			update testQuote;
			TriggerHandler.clearBypass('QuoteCPQTriggerHandler');
		}

		List<SBQQ__QuoteLine__c> quoteLineList = [SELECT Id FROM SBQQ__QuoteLine__c];
		Set<Id> actual = new Set<Id>();

		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			Test.startTest();
			actual = OpportunityQuoteLineLockUtility.checkLockedQuoteLines(quoteLineList);
			Test.stopTest();
		}

		System.assertEquals(
			quoteLineList.size(),
			actual.size(),
			'Locked Quote status will lock quote lines'
		);
	}

	@IsTest
	static void testSetIsPrimaryUpdated() {
		SBQQ__QuoteLine__c[] quoteLines = [SELECT Id, OpportunityId__c FROM SBQQ__QuoteLine__c];

		Test.startTest();
		OpportunityQuoteLineLockUtility.setIsPrimaryUpdated(quoteLines);
		Test.stopTest();

		SBQQ__Quote__c[] quotes = [SELECT Id, Primary_Updated_and_Approved__c FROM SBQQ__Quote__c];
		Assert.isTrue(quotes[0].Primary_Updated_and_Approved__c == false);
	}
}