/**
 * @Business: This is a Test class for AccountSupportRequestTriggerHandler
 * @Date: 2020-01-06
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description.
 * TAN-834   2020-01-06     Initial development
 * SS-7240   2024-01-18		Remove ESO_Support_Request_Approved. This record type will be decommissioned.
							Rewrote test class moving several test methods to class AccountSupportRequestTriggerUtilityTest
 */
@IsTest
private class AccountSupportRequestTriggerHandlerTest {
	private static Id advisorEngagementRecordTypeId = Utility.getRecordTypeIdByAPIName(
		'Account_Support_Request__c',
		'Sr_Advisor_Engagement'
	);
	private static final String ESO_DRAFT_STATUS = 'ESO Draft';

	@TestSetup
	private static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler', 'UserTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today(),
				Utility.PROSPECTING,
				account.Id
			);
			insert opp;

			Account_Support_Request__c internalSupportReq = TestFactory.buildAccountSupportRequest(
				account.Id,
				opp.Id,
				ESO_DRAFT_STATUS,
				advisorEngagementRecordTypeId
			);
			insert internalSupportReq;
		}
	}

	@IsTest
	private static void testAccountSupportRequestTriggerHandler() {
		List<Account_Support_Request__c> internalSupportReq = [
			SELECT Id
			FROM Account_Support_Request__c
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();

			update internalSupportReq;
			delete internalSupportReq;
			undelete internalSupportReq;

			Assert.isTrue(internalSupportReq.size() > 0);

			Test.stopTest();
		}
	}
}