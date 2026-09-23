/**
 * @Business: Test class of Trigger on Tool Displacement i.e.ToolDisplacementTrigger
 * @Date: 2019-10-16
 * @Author: Cumulus Vision
 * @Request: TAN-820
 * Modified  ModifiedDate   Description
 * TAN-820   2019-10-21     Initial Development
 */

@isTest
private class ToolDisplacementTriggerTest {
	@TestSetup
	static void makeData() {
		List<Account> accList = new List<Account>();
		accList.add(TestFactory.buildAccount('Test1'));
		accList.add(TestFactory.buildAccount('Test2'));
		insert accList;
	}

	@isTest
	private static void integration_WhenToolDisplacementInsert_UpdateAccountStage() {
		List<Account> accList = [SELECT Id FROM Account];
		Tool_Displacement__c tdRec1 = new Tool_Displacement__c(
			Account__c = accList[0].Id,
			Displacement_Stage__c = 'Evaluating'
		);
		Tool_Displacement__c tdRec2 = new Tool_Displacement__c(
			Account__c = accList[0].Id,
			Displacement_Stage__c = 'Evaluating'
		);

		Test.startTest();
		insert new List<Tool_Displacement__c>{ tdRec1, tdRec2 };
		Test.stopTest();

		Account acc1 = [
			SELECT Tool_Displacement_Stage__c
			FROM Account
			WHERE Id = :tdRec1.Account__c
			LIMIT 1
		];
		System.assertEquals('2 Evaluating.', acc1.Tool_Displacement_Stage__c);
	}

	@isTest
	private static void integration_WhenToolDisplacementUpdate_UpdateAccountStage() {
		List<Account> accList = [SELECT Id FROM Account];

		Tool_Displacement__c tdRec1 = new Tool_Displacement__c(
			Account__c = accList[0].Id,
			Displacement_Stage__c = 'Evaluating'
		);
		insert tdRec1;

		TriggerHandler.resetRecursionLimits();

		Test.startTest();
		tdRec1.Displacement_Stage__c = 'Implementing';
		update tdRec1;
		Test.stopTest();

		Account acc1 = [
			SELECT Tool_Displacement_Stage__c
			FROM Account
			WHERE Id = :tdRec1.Account__c
			LIMIT 1
		];
		System.assertEquals('1 Implementing.', acc1.Tool_Displacement_Stage__c);
	}

	@isTest
	private static void integration_WhenToolDisplacementDeleted_UpdateAccountStage() {
		List<Account> accList = [SELECT Id FROM Account];

		Tool_Displacement__c tdRec1 = new Tool_Displacement__c(
			Account__c = accList[0].Id,
			Displacement_Stage__c = 'Evaluating'
		);
		insert tdRec1;

		TriggerHandler.resetRecursionLimits();

		Test.startTest();
		delete tdRec1;
		Test.stopTest();

		Account acc1 = [
			SELECT Tool_Displacement_Stage__c
			FROM Account
			WHERE Id = :tdRec1.Account__c
			LIMIT 1
		];
		System.assertEquals(null, acc1.Tool_Displacement_Stage__c);
	}

	@isTest
	private static void integration_WhenToolDisplacementUndeleted_UpdateAccountStage() {
		List<Account> accList = [SELECT Id FROM Account];

		Tool_Displacement__c tdRec1 = new Tool_Displacement__c(
			Account__c = accList[0].Id,
			Displacement_Stage__c = 'Evaluating'
		);
		insert tdRec1;

		TriggerHandler.resetRecursionLimits();

		delete tdRec1;

		TriggerHandler.resetRecursionLimits();

		Test.startTest();
		undelete tdRec1;
		Test.stopTest();

		Account acc1 = [
			SELECT Tool_Displacement_Stage__c
			FROM Account
			WHERE Id = :tdRec1.Account__c
			LIMIT 1
		];
		System.assertEquals('1 Evaluating.', acc1.Tool_Displacement_Stage__c);
	}
}