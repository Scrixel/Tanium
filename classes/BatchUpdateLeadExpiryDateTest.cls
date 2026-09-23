/**
 * Test class for BatchUpdateLeadExpiryDate
 * Modified  ModifiedDate   Description
 * SS-9000   2024-09-23     Opp Reg to Deal Reg Migration
 */
@IsTest
private class BatchUpdateLeadExpiryDateTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'DealRegistrationTriggerHandler', 'UserTriggerHandler' }
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Deal_Registration__c deal1 = TestFactory.buildDealReg(
				'Test FName1',
				'TestLname1',
				'test1@test.com',
				'My Company1'
			);
			deal1.or_Opp_Reg_Status__c = 'Approved';
			deal1.or_Expiry_Date_Extension_Opp_Reg__c = System.today();
			deal1.or_Expiry_Date_New_Opp_Reg__c = System.today().addDays(-30);

			Deal_Registration__c deal2 = TestFactory.buildDealReg(
				'Test FName2',
				'TestLname2',
				'test2@test.com',
				'My Company2'
			);
			deal2.or_Opp_Reg_Status__c = 'Approved';
			deal2.or_Expiry_Date_Extension_Opp_Reg__c = System.today().addDays(10);
			deal2.or_Expiry_Date_New_Opp_Reg__c = System.today().addDays(10);
			insert new List<Deal_Registration__c>{ deal1, deal2 };
		}
	}

	@IsTest
	static void testBatchUpdate() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new BatchUpdateLeadExpiryDate());
			Test.stopTest();
			Deal_Registration__c deal = [
				SELECT Id, or_Opp_Reg_Status__c
				FROM Deal_Registration__c
				WHERE FirstName__c = 'Test FName1'
				LIMIT 1
			];
			System.assertEquals('Expired', deal.or_Opp_Reg_Status__c);
		}
	}

	@IsTest
	static void testBatchScheduler() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			BatchUpdateLeadExpiryDate sh1 = new BatchUpdateLeadExpiryDate();

			String sch = '0 0 23 * * ?';
			String jobid = System.schedule('Test BatchUpdateLeadExpiryDate', sch, sh1);
			sh1.execute(null);

			Test.stopTest();
			Deal_Registration__c deal = [
				SELECT Id, or_Opp_Reg_Status__c
				FROM Deal_Registration__c
				WHERE FirstName__c = 'Test FName1'
				LIMIT 1
			];
			System.assertEquals('Expired', deal.or_Opp_Reg_Status__c);
		}
	}
}