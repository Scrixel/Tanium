/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for the BatchAccountStatusUpdate class
 * @Author: Cumulus Vision
 * Modified  ModifiedDate  Description
 * TAN-1198  2021-05-24    Initial development
 * SS-7608   2024-11-12    Account Type Updates
 * SS-12650  2026-02-23    File rename and best practices updates
 */
@IsTest
private class BatchAccountStatusUpdateTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);
		Id devRecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Account> accounts = new List<Account>();
			accounts.add(TestFactory.buildAccount('Account 1', 'Customer'));
			accounts[0].RecordTypeId = devRecordTypeId;
			accounts[0].Partner_Maturity__c = 'Active';

			accounts.add(TestFactory.buildAccount('Account 2', 'Partner'));
			accounts[1].RecordTypeId = devRecordTypeId;
			accounts[1].Partner_Maturity__c = 'Active';

			accounts.add(TestFactory.buildAccount('Account 3', 'Partner'));
			accounts[2].RecordTypeId = devRecordTypeId;
			accounts[2].Partner_Maturity__c = 'Inactive';
			accounts[2].Active_Account__c = true;
			insert accounts;

			List<Opportunity> opps = new List<Opportunity>();
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opp 1',
					System.today().addDays(30),
					Utility.DISCOVERY,
					accounts[0].Id
				)
			);
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opp 1',
					System.today().addDays(30),
					Utility.CLOSED_WON,
					accounts[0].Id
				)
			);
			insert opps;
		}
	}

	@IsTest
	static void testBatchAccountStatusUpdate() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			BatchAccountStatusUpdate batch = new BatchAccountStatusUpdate();
			Database.executeBatch(batch);
			Test.stopTest();

			List<Account> customerAccounts = [
				SELECT Id, Active_Account__c
				FROM Account
				WHERE Type = 'Customer'
			];
			Assert.isTrue(customerAccounts[0].Active_Account__c);

			List<Account> partnerActiveAccounts = [
				SELECT Id, Active_Account__c
				FROM Account
				WHERE Type = 'Partner' AND Partner_Maturity__c = 'Active'
			];
			Assert.isTrue(partnerActiveAccounts[0].Active_Account__c);

			List<Account> partnerArchivedAccounts = [
				SELECT Id, Active_Account__c
				FROM Account
				WHERE Type = 'Partner' AND Partner_Maturity__c = 'Inactive'
			];
			Assert.isFalse(PartnerArchivedAccounts[0].Active_Account__c);
		}
	}

	@IsTest
	static void testBatchAccountStatusUpdateScheduler() {
		String cronExpr = '0 0 0 ? * * *';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			BatchAccountStatusUpdate scheduler = new BatchAccountStatusUpdate();
			String jobId = System.schedule('myJobTestJobName', cronExpr, scheduler);
			scheduler.execute(null);
			Test.stopTest();
		}
	}

	@IsTest
	static void testBatchAccountTypeUpdate_WhenCustomerChurn_AlwaysUpdateToFormerCustomer() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [
				SELECT Id, Max_Subscription_End_Date__c
				FROM Account
				WHERE Type = 'Customer'
			];
			acc.Max_Subscription_End_Date__c = System.today().addDays(-7);

			Opportunity opp = [
				SELECT Id, StageName
				FROM Opportunity
				WHERE AccountId = :acc.Id AND StageName != :Utility.CLOSED_WON
				LIMIT 1
			];
			opp.StageName = Utility.CLOSED_WON;
			update new List<SObject>{ opp, acc };

			Test.startTest();
			BatchAccountStatusUpdate batch = new BatchAccountStatusUpdate();
			Database.executeBatch(batch);
			Test.stopTest();

			acc = [SELECT Id, Type, RecordType.Name FROM Account WHERE Id = :acc.Id];
			Assert.areEqual('Former Customer', acc.Type, 'Account Type should be Former Customer');
			Assert.areEqual('Prospect', acc.RecordType.Name, 'Record Type should be Prospect');
		}
	}

	@IsTest
	static void testBatchAccountTypeUpdate_WhenCustomerHasActiveSubscriptions_NoChange() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [
				SELECT Id, Max_Subscription_End_Date__c
				FROM Account
				WHERE Type = 'Customer'
			];
			acc.Max_Subscription_End_Date__c = System.today().addDays(30);
			update acc;

			Test.startTest();
			BatchAccountStatusUpdate batch = new BatchAccountStatusUpdate();
			Database.executeBatch(batch);
			Test.stopTest();

			acc = [SELECT Id, Type FROM Account WHERE Id = :acc.Id];
			Assert.areEqual('Customer', acc.Type, 'Account Type should still be Customer');
		}
	}

	@IsTest
	static void testBatchAccountTypeUpdate_WhenMSPEndUserChurn_AlwaysUpdateToProspect() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [
				SELECT Id, Type, Max_MSP_Managed_Subscription_End_Date__c
				FROM Account
				WHERE Type = 'Customer'
			];
			acc.Type = 'MSP End User';
			acc.Max_MSP_Managed_Subscription_End_Date__c = System.today().addDays(-30);

			Opportunity opp = [
				SELECT Id, StageName
				FROM Opportunity
				WHERE AccountId = :acc.Id AND StageName != :Utility.CLOSED_WON
				LIMIT 1
			];
			opp.StageName = Utility.CLOSED_WON;

			Opportunity oppfailed = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addMonths(1),
				Utility.FAILED,
				acc.Id
			);
			upsert new List<SObject>{ acc, opp, oppfailed };

			Test.startTest();
			BatchAccountStatusUpdate batch = new BatchAccountStatusUpdate();
			Database.executeBatch(batch);
			Test.stopTest();

			acc = [SELECT Id, Type, RecordType.Name FROM Account WHERE Id = :acc.Id];
			Assert.areEqual('Prospect', acc.Type, 'Account Type should be Prospect');
			Assert.areEqual('Prospect', acc.RecordType.Name, 'Record Type should be Prospect');
		}
	}
}