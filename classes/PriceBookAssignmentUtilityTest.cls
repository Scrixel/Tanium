/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for PriceBookAssignmentUtility
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * Modified    ModifiedDate    Description
 * SS-7665	   2024-04-23	   isMSP to use quote.Business_Motion_Oppty='MSP'
 * SS-12676    2026-03-25      Renamed class, deleted depreciated fields (Absorb_Transaction_ID__c)
 */
@isTest
private class PriceBookAssignmentUtilityTest {
	private static final String TEST_USERNAME = 'TaniumTestGuy@example.com';

	private static final Map<String, Id> pricebookNameIdMap = new Map<String, Id>{
		'IR Assessment' => '01s0e00000073H0BBC',
		'Default' => '01s0e00000003H0BBC'
	};

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;
			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today() + 60,
				Utility.PROSPECTING,
				acct.Id
			);
			oppty.Type = 'Concession';
			insert oppty;
		}
	}

	@isTest
	private static void prefillPriceBook_WhenAccountDoesNotFitCategory_SetsOpportunityPricebookToDefault() {
		Id expectedPricebookId = priceBookNameIdMap.get('Default');
		Opportunity opportunity = [
			SELECT Id, AccountId, Type, Pricebook2Id
			FROM Opportunity
			LIMIT 1
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			PriceBookAssignmentUtility.prefillPriceBook(
				new List<Opportunity>{ opportunity },
				new Set<Id>{ opportunity.AccountId },
				pricebookNameIdMap
			);
			Test.stopTest();

			System.assertEquals(expectedPricebookId, opportunity.Pricebook2Id);
		}
	}

	@isTest
	private static void prefillPriceBook_WhenOpportunityTypeConsulting_SetsOpportunityPricebookToIRAssessment() {
		Id expectedPricebookId = priceBookNameIdMap.get('IR Assessment');
		Map<String, Id> emptySubAreaMap = new Map<String, Id>();
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opportunity = [
				SELECT Id, AccountId, Type, Pricebook2Id
				FROM Opportunity
				LIMIT 1
			];
			opportunity.Type = 'Consulting';
			update opportunity;

			Test.startTest();
			PriceBookAssignmentUtility.prefillPriceBook(
				new List<Opportunity>{ opportunity },
				new Set<Id>{ opportunity.AccountId },
				pricebookNameIdMap
			);
			Test.stopTest();

			System.assertEquals(expectedPricebookId, opportunity.Pricebook2Id);
		}
	}

	@isTest
	private static void prefillPriceBook_WhenOwnerIsMissing_SetsOpportunityPricebookToDefault() {
		Id expectedPricebookId = priceBookNameIdMap.get('Default');
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opportunity = [
				SELECT Id, AccountId, Type, Pricebook2Id
				FROM Opportunity
				LIMIT 1
			];

			Test.startTest();
			PriceBookAssignmentUtility.prefillPriceBook(
				new List<Opportunity>{ opportunity },
				new Set<Id>{ opportunity.AccountId },
				pricebookNameIdMap
			);
			Test.stopTest();

			System.assertEquals(expectedPricebookId, opportunity.Pricebook2Id);
		}
	}

	@isTest
	private static void isIRAssessment_WhenOpportunityTypeConsulting_ReturnsTrue() {
		Account acct = [SELECT Id FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today() + 60,
				Utility.PROSPECTING,
				acct.Id
			);
			oppty.Type = 'Consulting';
			insert oppty;

			Test.startTest();
			Boolean isIRAssessment = PriceBookAssignmentUtility.isIRAssessment(oppty);
			Test.stopTest();

			System.assertEquals(true, isIRAssessment);
		}
	}

	@isTest
	private static void isPOC_WhenOpportunityTypePOC_ReturnsTrue() {
		Account acct = [SELECT Id FROM Account LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today() + 60,
				Utility.PROSPECTING,
				acct.Id
			);
			oppty.Type = 'POC';
			insert oppty;

			Test.startTest();
			Boolean isPOC = PriceBookAssignmentUtility.isPOC(oppty);
			Test.stopTest();

			System.assertEquals(true, isPOC);
		}
	}
}