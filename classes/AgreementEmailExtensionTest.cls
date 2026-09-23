/**
 *
 * Copyright (c) 2026 Tanium
 *
 @Business: Test class for AgreementEmailExtension class
 * @Date: 2018-04-20
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * TAN-719    2019-01-01    Issue fix for "Apttus Agreement Creation Flows" Opportunity.Contract_Owner__c field on should not be null
 * SS-7266    2025-12-30    Rewrite test class to not use discontinued TestFactory class method
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */

@IsTest
private class AgreementEmailExtensionTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Id userId = UserInfo.getUserId();

			Account account = TestFactory.buildAccount('Test Account', 'Partner');
			insert account;

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addDays(30),
				'Test',
				account.Id
			);
			opportunity.Deal_Desk_Approver__c = userId;
			opportunity.Contract_Owner__c = userId;
			insert opportunity;

			Apttus__APTS_Agreement__c agreement = new Apttus__APTS_Agreement__c(
				Name = 'Testing',
				Apttus__Related_Opportunity__c = opportunity.Id
			);
			insert agreement;

			Apttus_Approval__Approval_Request__c approvalRequest = new Apttus_Approval__Approval_Request__c(
				Apttus_Approval__Related_Agreement__c = agreement.Id,
				Apttus_Approval__Initial_Submitter__c = UserInfo.getUserId()
			);
			insert approvalRequest;
		}
	}

	@IsTest
	static void testControllerExtension() {
		Apttus_Approval__Approval_Request__c approvalRequest = [
			SELECT Id
			FROM Apttus_Approval__Approval_Request__c
			LIMIT 1
		];
		AgreementEmailExtension agreementEmailExtension;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Apttus_Approval.AgreementApprovalEmailController controller = new Apttus_Approval.AgreementApprovalEmailController();
			controller.setRequestSO(approvalRequest);
			agreementEmailExtension = new AgreementEmailExtension(controller);
			agreementEmailExtension.approvalRequestId = approvalRequest.Id;
			Test.stopTest();
		}
		Assert.areEqual(approvalRequest.Id, agreementEmailExtension.approvalRequestId);
	}
}