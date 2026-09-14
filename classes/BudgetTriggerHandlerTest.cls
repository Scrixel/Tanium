/**
 * @Business: Test class for Budget Trigger Handler
 * @Date: 2018-02-16
 * @Author: Cumulus Vision
 * @Request: TAN-480
 * Modified  ModifiedDate   Description
 * TAN-480   2018-02-16     Initial Development
 * TAN-662   2018-09-07     Fixed issues in the test methods
 */
@isTest
private class BudgetTriggerHandlerTest {
	static testMethod void assignApproversTest() {
		//Get 4 users for approvers
		List<User> users = [SELECT Id, isActive FROM User WHERE isActive = TRUE LIMIT 4];

		//Insert the Budget Approver Record
		Budget_Approver__c ba = new Budget_Approver__c(
			Budget_Owner__c = users[1].Id,
			Budget_E_Staff__c = users[2].Id,
			Budget_Finance_Approver__c = users[3].Id,
			Business_Region__c = 'Global',
			Business_Department__c = 'Cost of Sales'
		);

		insert ba;

		//Insert the Budget Record
		Budget__c b = new Budget__c(
			Business_Region__c = 'Global',
			Business_Department__c = 'Cost of Sales',
			Program_Name__c = 'Test Budget',
			Status__c = 'New',
			Program_Description__c = 'Test',
			Program_Start_Date__c = system.today(),
			Requestor__c = users[0].Id,
			Budget_Amount__c = 100,
			Approximate_Amount_In_USD__c = 10
		);

		Test.startTest();

		insert b;

		Test.stopTest();

		Budget__c newB = [
			SELECT Id, Budget_Owner__c, Procurement_E_Staff_Approver__c, Finance_Approver__c
			FROM Budget__c
			WHERE Id = :b.Id
		];

		//check if the approvers from the budget approver record were added to the new budget record
		system.assertEquals(users[1].Id, newB.Budget_Owner__c);
		system.assertEquals(users[2].Id, newB.Procurement_E_Staff_Approver__c);
		system.assertEquals(users[3].Id, newB.Finance_Approver__c);
	}

	static testMethod void assignApproversUpdateTest() {
		//Get 8 users for approvers
		List<User> users = [SELECT Id, isActive FROM User WHERE isActive = TRUE LIMIT 8];

		//Insert the Budget Approver Records
		Budget_Approver__c ba = new Budget_Approver__c(
			Budget_Owner__c = users[1].Id,
			Budget_E_Staff__c = users[2].Id,
			Budget_Finance_Approver__c = users[3].Id,
			Business_Region__c = 'Global',
			Business_Department__c = 'Cost of Sales'
		);

		insert ba;

		Budget_Approver__c ba1 = new Budget_Approver__c(
			Budget_Owner__c = users[5].Id,
			Budget_E_Staff__c = users[6].Id,
			Budget_Finance_Approver__c = users[7].Id,
			Business_Region__c = 'HQ',
			Business_Department__c = 'Cost of Sales'
		);

		insert ba1;

		//Insert the Budget Record
		Budget__c b = new Budget__c(
			Business_Region__c = 'Global',
			Business_Department__c = 'Cost of Sales',
			Program_Name__c = 'Test Budget',
			Status__c = 'New',
			Program_Description__c = 'Test',
			Program_Start_Date__c = system.today(),
			Requestor__c = users[0].Id,
			Budget_Amount__c = 100,
			Approximate_Amount_In_USD__c = 10
		);
		insert b;

		Test.startTest();
		//Update the budget record to a new region
		b.Business_Region__c = 'HQ';
		update b;

		Test.stopTest();

		Budget__c newB = [
			SELECT Id, Budget_Owner__c, Procurement_E_Staff_Approver__c, Finance_Approver__c
			FROM Budget__c
			WHERE Id = :b.Id
		];

		//check if the approvers from the 2nd budget approver record were added to the udated budget record
		system.assertEquals(users[5].Id, newB.Budget_Owner__c);
		system.assertEquals(users[6].Id, newB.Procurement_E_Staff_Approver__c);
		system.assertEquals(users[7].Id, newB.Finance_Approver__c);
	}
}