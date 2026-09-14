/**
 * @Business: Test class for the DealRegistrationTriggerHandler class
 * @Date: 2024-09-13
 * @Author: Tanium Dev Team
 * Modified  ModifiedDate   Description
 * SS-8999   2024-09-12     Initial development - Opp Reg to Deal Reg Migration
 */
@IsTest
private class DealRegistrationTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Deal_Registration__c deal = TestFactory.buildDealReg(
				'First',
				'Last',
				'firstlast@test.com',
				'Test Company'
			);
			deal.Mapped_Opportunity__c = null;
			deal.or_New_Opp_Reg__c = true;
			deal.or_Create_Opportunity_upon_Approval__c = true;
			deal.or_Opportunity_Registration__c = 'Partner Sourced';
			deal.or_Opp_Reg_Status__c = 'Pending';
			insert deal;
		}
	}

	@IsTest
	static void testDealRegistrationHandler() {
		Deal_Registration__c[] deals = [SELECT Id FROM Deal_Registration__c];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();

			update deals;
			delete deals;
			Test.stopTest();
		}
	}
}