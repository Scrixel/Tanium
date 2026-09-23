/*
 * @BUSINESS: SubmitForApprovalForFlow class
 * @DATE: 2024-07-12
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  	ModifiedDate  Comment
 * SS-8407    	2024-07-12    Submit for advanced approval called from flow - "Quote - Required for Approval"
 * SS-9651    	2024-11-12    Class enhancements
 */
@IsTest
private class SubmitForApprovalForFlowTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'BillingByQuoteLineTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);
		System.runAs(getAdvanceApprovalUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			acct.type = 'Analyst';
			acct.Country_Restrictions__c = 'Business Allowed';
			insert acct;
			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				'Prospecting',
				acct.Id
			);
			oppty.CloseDate = Date.today() + 60;
			//oppty.Deal_Desk_Approver__c = getDealsDeskUser().Id;
			insert oppty;

			SBQQ__Quote__c testQuote = new SBQQ__Quote__c(
				PaymentTypeNew__c = 'Annual Installment',
				SBQQ__StartDate__c = Date.today(),
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = oppty.Id,
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Account__c = acct.Id,
				SBQQ__Status__c = 'Accepted',
				SBQQ__Type__c = 'Quote',
				SBQQ__SubscriptionTerm__c = 30,
				SBQQ__Primary__c = true
			);
			insert testQuote;
		}
	}

	@IsTest
	static void testSubmit_whenSuccess_returnsSUCCESS() {
		List<SubmitForApprovalForFlow.RequestDataFromFlow> requests = new List<SubmitForApprovalForFlow.RequestDataFromFlow>();
		SubmitForApprovalForFlow.RequestDataFromFlow request = new SubmitForApprovalForFlow.RequestDataFromFlow();
		request.recordId = [SELECT Id FROM SBQQ__Quote__c LIMIT 1].Id;
		requests.add(request);
		List<SubmitForApprovalForFlow.SendDataToFlow> results = new List<SubmitForApprovalForFlow.SendDataToFlow>();
		System.runAs(getAdvanceApprovalUser()) {
			Test.startTest();
			try {
				results = SubmitForApprovalForFlow.submit(requests);
			} catch (Exception e) {
			}
			Test.stopTest();
		}
		System.assertEquals(results[0].msgToUser, 'SUCCESS', 'valid record Id');
	}

	@IsTest
	static void testSubmit_whenException_returnsException() {
		List<SubmitForApprovalForFlow.RequestDataFromFlow> requests = new List<SubmitForApprovalForFlow.RequestDataFromFlow>();
		SubmitForApprovalForFlow.RequestDataFromFlow request = new SubmitForApprovalForFlow.RequestDataFromFlow();
		request.recordId = null;
		requests.add(request);
		List<SubmitForApprovalForFlow.SendDataToFlow> results = new List<SubmitForApprovalForFlow.SendDataToFlow>();

		System.runAs(getAdvanceApprovalUser()) {
			Test.startTest();
			try {
				results = SubmitForApprovalForFlow.submit(requests);
			} catch (Exception e) {
			}
			Test.stopTest();
		}
		System.assertNotEquals(results[0].msgToUser, 'SUCCESS', 'invalid record Id');
		System.assertEquals(
			true,
			[SELECT Id FROM LogEntry__c].size() > 0,
			'exception logged in Nebula'
		);
		for (LogEntry__c eachLogEntry : [SELECT Message__c FROM LogEntry__c]) {
			System.assertEquals(
				true,
				eachLogEntry.Message__c.contains('SubmitForApprovalForFlow.submit'),
				'exception logged in Nebula'
			);
		}
	}

	static User getAdvanceApprovalUser() {
		List<User> testUsers = [
			SELECT Id
			FROM User
			WHERE LastName = :TestUserFactory.ADVANCED_APPROVALS_USER
		];
		if (testUsers.isEmpty()) {
			User advanceApprovalUser = TestUserFactory.createAdvancedApprovalsUser();
			assignAdminPermissions(advanceApprovalUser.Id);
			return advanceApprovalUser;
		} else {
			return testUsers[0];
		}
	}

	static void assignAdminPermissions(Id userId) {
		TestingUtility.assignPermissionSet(userId, 'DisableFlows');
		TestingUtility.assignPermissionSet(userId, 'DisableValidationRules');
	}
}