/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for DealDeskApproverOpportunitiesController
 * @Date: 2016-04-08
 * @Author: Mahesh G
 * RequestId  ModifiedDate  Description
 * TAN-536    2018-04-14    Modified Account creation as per "Country_Restriction" validation rule on opportunity
 * SS-13636   2026-09-11    Covered pre-commit Renewal and Order Drafted stage exclusion
 */
@IsTest
private class DealDeskApproverOpportunitiesContTest {
	private static final List<String> EXCLUDED_STAGES = new List<String>{
		Utility.ACCOUNT_ASSESSMENT,
		Utility.CUSTOMER_ENGAGED,
		Utility.PROPOSAL_SENT,
		Utility.COMMIT_STAGE,
		Utility.ORDER_DRAFTED
	};

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);
		Id currentUserId = UserInfo.getUserId();
		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			account.Country_Restrictions__c = 'Business Allowed';
			account.Type = 'Analyst';
			account.Country_Exception_Approved__c = true;
			insert account;

			List<Opportunity> opps = new List<Opportunity>{
				TestFactory.buildOpportunity(
					'Opportunity 1',
					System.today(),
					Utility.PROSPECTING,
					account.Id
				)
			};
			for (String excludedStage : EXCLUDED_STAGES) {
				opps.add(
					TestFactory.buildOpportunity(
						excludedStage,
						System.today(),
						excludedStage,
						account.Id
					)
				);
			}
			for (Opportunity opp : opps) {
				opp.Seats__c = 1;
			}
			insert opps;

			for (Opportunity opp : opps) {
				opp.CloseDate = System.today();
				opp.Deal_Desk_Approver__c = currentUserId;
			}
			update opps;
		}
	}

	@IsTest
	static void testGetOpportunities_UserIdBlank_ReturnsNull() {
		DealDeskApproverOpportunitiesController controller = new DealDeskApproverOpportunitiesController();
		List<Opportunity> opps;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			opps = controller.getOpportunities();
			Test.stopTest();
		}

		Assert.isNull(opps, 'Blank userId => null');
	}

	@IsTest
	static void testGetOpportunities_PreCommitRenewalAndOrderDraftedStages_ReturnsOtherStagesOnly() {
		DealDeskApproverOpportunitiesController controller = new DealDeskApproverOpportunitiesController();
		controller.userId = UserInfo.getUserId();
		List<Opportunity> opps;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			opps = controller.getOpportunities();
			Test.stopTest();
		}

		Assert.areEqual(1, opps.size(), 'Only the Prospecting Opportunity is returned');
		Assert.areEqual(
			Utility.PROSPECTING,
			opps[0].StageName,
			'Renewal and Order Drafted stages are excluded'
		);
	}
}