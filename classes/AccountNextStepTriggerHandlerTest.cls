/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: see Account_Next_Step__c Trigger Handler
 * @Date: 2016-03-02
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request: TAN-101
 * Modified   ModifiedDate   Description
 * TAN-483    2018-02-22     Updated StageName
 * TAN-536    2018-04-14     Modified Account creation as per "Country_Restriction" validation rule on opportunity
 * SS-13497   2026-07-07     Remove deprecated fields for project kondo group 2
 */
@IsTest
private class AccountNextStepTriggerHandlerTest {
	@TestSetup
	private static void makeData() {
		List<Account_Next_Step__c> accountNextStepList = new List<Account_Next_Step__c>();
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;
			for (Integer i = 0; i < 10; i++) {
				Account_Next_Step__c acctNextStep = TestFactory.buildAccountNextStep(acct.Id);
				acctNextStep.RecordTypeId = Utility.getRecordTypeIdByAPIName(
					'Account_Next_Step__c',
					'CSM_Next_Steps'
				);
				accountNextStepList.add(acctNextStep);
				acctNextStep = TestFactory.buildAccountNextStep(acct.Id);
				acctNextStep.RecordTypeId = Utility.getRecordTypeIdByAPIName(
					'Account_Next_Step__c',
					'TAM_Next_Step'
				);
				accountNextStepList.add(acctNextStep);
			}
			insert accountNextStepList;
			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				Utility.UNCOMMITTED_RENEWAL,
				acct.Id
			);
			insert oppty;
		}
	}

	@IsTest
	static void generateAccountUpdateMap_WhenAccountNextStepHasTAMRecordType_ReturnAccountMapToUpdate() {
		Account acct = [SELECT Id FROM Account LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<Id, Account> generatedAccountMap = AccountNextStepTriggerHandler.generateAccountUpdateMap(
				[
					SELECT Id, RecordTypeId, Account__c, TAM_Owner_Name__c, TAM_Next_Steps__c
					FROM Account_Next_Step__c
				]
			);
			Test.stopTest();

			System.assert(generatedAccountMap.size() > 0);
		}
	}

	@IsTest
	static void generateAccountUpdateMap_WhenAccountNextStepDoesNotHaveTAMRecordType_ReturnEmptyMap() {
		Account acct = [SELECT Id FROM Account LIMIT 1];
		Id csmNextStepRecordId = Utility.getRecordTypeIdByAPIName(
			'Account_Next_Step__c',
			'CSM_Next_Steps'
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Account_Next_Step__c acctNextStep = TestFactory.buildAccountNextStep(acct.Id);
			acctNextStep.recordTypeId = csmNextStepRecordId;
			insert acctNextStep;
			Map<Id, Account> generatedAccountMap = AccountNextStepTriggerHandler.generateAccountUpdateMap(
				[
					SELECT Id, RecordTypeId, Account__c, TAM_Owner_Name__c, TAM_Next_Steps__c
					FROM Account_Next_Step__c
					WHERE RecordTypeId = :csmNextStepRecordId
				]
			);
			Test.stopTest();

			System.assert(generatedAccountMap.size() == 0);
		}
	}

	@IsTest
	static void generateTAMNextStepInsertList_WhenAccountNextStepMatchesExistingRenewalOpportunityAccount_ReturnTAMNextStepList() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = [SELECT Id, Country_Exception_Approved__c FROM Account LIMIT 1];
			acct.Country_Exception_Approved__c = true;
			update acct;

			Opportunity oppty = [SELECT Id FROM Opportunity LIMIT 1];

			Test.startTest();
			List<TAM_Next_Steps__c> generatedTAMNextSteps = AccountNextStepTriggerHandler.generateTAMNextStepInsertList(
				[
					SELECT
						Id,
						RecordTypeId,
						Account__c,
						TAM_Owner__c,
						TAM_Owner_Name__c,
						TAM_Next_Steps__c
					FROM Account_Next_Step__c
				],
				new Set<Id>{ acct.Id }
			);
			Test.stopTest();

			System.assert(generatedTAMNextSteps.size() > 0);
		}
	}

	@IsTest
	static void generateTAMNextStepInsertList_WhenAccountNextStepDoesNotMatchRenewalOpportunity_ReturnEmptyList() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct1 = TestFactory.buildAccount('Test Account X');
			acct1.Country_Exception_Approved__c = true;
			Account acct2 = TestFactory.buildAccount('Test Account Y');
			acct2.Country_Exception_Approved__c = true;
			List<Account> accountList = new List<Account>{ acct1, acct2 };
			insert accountList;
			Set<Id> accountIdSet = (new Map<Id, Account>(accountList)).keySet();

			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				Utility.UNCOMMITTED_RENEWAL,
				accountList[0].Id
			);
			insert oppty;
			List<Account_Next_Step__c> accountNextStepList = new List<Account_Next_Step__c>();
			for (Integer i = 0; i < 10; i++) {
				Account_Next_Step__c acctNextStep = TestFactory.buildAccountNextStep(accountList[1].Id);
				accountNextStepList.add(acctNextStep);
			}
			insert accountNextStepList;
			Test.startTest();
			List<TAM_Next_Steps__c> generatedTAMNextSteps = AccountNextStepTriggerHandler.generateTAMNextStepInsertList(
				accountNextStepList,
				accountIdSet
			);
			Test.stopTest();

			System.assert(generatedTAMNextSteps.size() == 0);
		}
	}
}