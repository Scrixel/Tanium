/**
 * @Business: Test class for ContractTriggerHandler
 * @Date: 2025-07-01
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11112   2025-07-01    Created the Test class
 */
@IsTest
private class ContractTriggerHandlerTest {
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

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Contract contract = new Contract(
				Name = 'Active Contract',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Contract', 'Account_Contracts'),
				StartDate = System.today().addDays(-1),
				EndDate = System.today().addDays(30),
				AccountId = account.Id,
				ContractTerm = 12
			);
			insert contract;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				System.today().addDays(120),
				'New',
				account.Id
			);
			insert opp;
		}
	}

	@IsTest
	static void testPopulateProductMigrationData_WhenScenario_ReturnSomething() {
		Contract[] contracts = [SELECT Id, SBQQ__RenewalOpportunity__c FROM Contract];
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

		Map<Id, Contract> oldMap = new Map<Id, Contract>(contracts.deepClone(true, true, true));
		for (Contract contract : contracts) {
			contract.SBQQ__RenewalOpportunity__c = opp.Id;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ContractTriggerHandler.populateProductMigrationData(contracts, oldMap);
			Test.stopTest();
		}


		// Nothing to assert since test of ProductMigrationAsync has its own test class.
	}
}