/*
 * @BUSINESS: Test class for CaseRoscoAccountFlashMsgController
 * @DATE: 2024-01-29
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-9787    2024-01-29    Initial creation
 */
@IsTest
private class CaseRoscoAccountFlashMsgControllerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'CaseTriggerHandler' });
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Contact con = TestFactory.buildContact(acc.Id);
			insert con;

			Case testCase = TestFactory.buildCase(acc.Id, con.Id);
			testCase.Status = 'New';

			Rosco_Account__c roscoAcc = new Rosco_Account__c(
				Name = 'Test Rosco Account',
				case_flash__c = 'Case Flash',
				Case_Flash_Persist__c = 'Case Flash Persist',
				account__c = acc.Id
			);

			insert new List<SObject>{ testCase, roscoAcc };
		}
	}

	@IsTest
	static void testGetRoscoAccountDetails_WhenCaseStatusIsNew_ReturnCaseFlash() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String accountId = [SELECT Id FROM Account LIMIT 1].Id;
			String caseStatus = [SELECT Status FROM Case LIMIT 1].Status;

			Test.startTest();
			String flashMsg = CaseRoscoAccountFlashMsgController.getRoscoAccountDetails(
				accountId,
				caseStatus
			);
			Test.stopTest();

			Rosco_Account__c roscoAcc = [
				SELECT case_flash__c, Case_Flash_Persist__c
				FROM Rosco_Account__c
			];
			Assert.areEqual(roscoAcc.case_flash__c, flashMsg);
		}
	}

	@IsTest
	static void testGetRoscoAccountDetails_WhenCaseStatusIsNotNew_ReturnCaseFlashPersist() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String accountId = [SELECT Id FROM Account LIMIT 1].Id;
			String caseStatus = 'In Progress - Troubleshooting';

			Test.startTest();
			String flashMsg = CaseRoscoAccountFlashMsgController.getRoscoAccountDetails(
				accountId,
				caseStatus
			);
			Test.stopTest();

			Rosco_Account__c roscoAcc = [
				SELECT case_flash__c, Case_Flash_Persist__c
				FROM Rosco_Account__c
			];
			Assert.areEqual(roscoAcc.Case_Flash_Persist__c, flashMsg);
		}
	}
}