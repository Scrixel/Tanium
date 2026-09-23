/**
 * @Business: Test class for BatchBillingScheduleRollUp2
 * @Author: Tanium Dev Team
 * Modified  ModifiedDate  Description
 * SS-7996   2024-07-26    Fix test class issues
 */
@IsTest
private class BatchBillingScheduleRollup2Test {
	private static User batchUser;

	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		System.runAs(BatchBillingScheduleRollUp2Test.getBatchUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;
			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				Utility.PROSPECTING,
				acct.Id
			);
			oppty.CloseDate = Date.today() + 60;
			insert oppty;

			Billing_Schedule__c billing1 = TestFactory.buildBillingSchedule(oppty.Id);
			billing1.Billing_Amount__c = 100;
			billing1.Billing_Amount_Net_Rollup__c = 175;
			billing1.Billing_Date__c = Date.today() + 30;
			billing1.Billing_Order__c = 1;

			Billing_Schedule__c billing1_dup = TestFactory.buildBillingSchedule(oppty.Id);
			billing1_dup.Billing_Amount__c = 150;
			billing1_dup.Billing_Amount_Net_Rollup__c = 195;
			billing1_dup.Billing_Date__c = Date.today() + 60;
			billing1_dup.Billing_Order__c = 1;

			Billing_Schedule__c billing2 = TestFactory.buildBillingSchedule(oppty.Id);
			billing2.Billing_Amount__c = 200;
			billing2.Billing_Amount_Net_Rollup__c = 275;
			billing2.Billing_Date__c = billing1.Billing_Date__c - 10;
			billing2.Invoice_Status__c = 'Paid';
			billing2.Billing_Order__c = 2;
			insert new List<Billing_Schedule__c>{ billing1, billing1_dup, billing2 };
		}
	}

	@IsTest
	static void testBatch_whenSuccessful_updatesOpptyRollUpFieldsAccurately() {
		SBQQ.TriggerControl.disable();
		Account acct;
		Opportunity oppty;
		Billing_Schedule__c billing1 = [
			SELECT
				Billing_Amount__c,
				Billing_Amount_Net_Rollup__c,
				Billing_Date__c,
				Billing_Order__c,
				Invoice_Status__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1 AND Billing_Amount__c = 100
		];
		Billing_Schedule__c billing1_dup = [
			SELECT
				Billing_Amount__c,
				Billing_Amount_Net_Rollup__c,
				Billing_Date__c,
				Billing_Order__c,
				Invoice_Status__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1 AND Billing_Amount__c = 150
		];
		Billing_Schedule__c billing2 = [
			SELECT
				Billing_Amount__c,
				Billing_Amount_Net_Rollup__c,
				Billing_Date__c,
				Billing_Order__c,
				Invoice_Status__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 2
		];
		oppty = [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			LIMIT 1
		];
		oppty.BillingScheduleTotalAmountNew__c = 0;
		oppty.BillingScheduleTotalNetAmountPaidNew__c = 0;
		oppty.BillingScheduleTotalCount__c = 0;
		oppty.InitialBillingDateNew__c = null;
		oppty.InitialGrossBillingAmountNew__c = 0;
		oppty.InitialNetBillingAmountNew__c = 0;
		update oppty;
		Test.startTest();
		System.runAs(BatchBillingScheduleRollUp2Test.getBatchUser()) {
			String query =
				'SELECT ' +
				'Id, ' +
				'BillingScheduleTotalAmountNew__c, ' +
				'BillingScheduleTotalNetAmountPaidNew__c, ' +
				'BillingScheduleTotalCount__c, ' +
				'InitialBillingDateNew__c, ' +
				'InitialGrossBillingAmountNew__c, ' +
				'InitialNetBillingAmountNew__c ' +
				'FROM Opportunity';
			BatchBillingScheduleRollUp2 batch = new BatchBillingScheduleRollUp2(query);
			Database.executeBatch(batch);
		}
		Test.stopTest();
		for (Opportunity opp : [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c
			FROM Opportunity
			WHERE Id = :oppty.Id
		]) {
			System.assertEquals(
				billing1.Billing_Amount__c + billing1_dup.Billing_Amount__c + billing2.Billing_Amount__c,
				opp.BillingScheduleTotalAmountNew__c
			);
			System.assertEquals(
				billing2.Billing_Amount_Net_Rollup__c,
				opp.BillingScheduleTotalNetAmountPaidNew__c
			);
			System.assertEquals(3, opp.BillingScheduleTotalCount__c);
			System.assertEquals(billing2.Billing_Date__c, opp.InitialBillingDateNew__c);
		}
	}

	@IsTest
	static void testBatch_whenFails_createsEventLogRecords() {
		SBQQ.TriggerControl.disable();
		Account acct;
		Opportunity oppty;
		Billing_Schedule__c billing1, billing2;
		System.runAs(BatchBillingScheduleRollUp2Test.getBatchUser()) {
			oppty = [
				SELECT
					Id,
					BillingScheduleTotalAmountNew__c,
					BillingScheduleTotalNetAmountPaidNew__c,
					BillingScheduleTotalCount__c,
					InitialBillingDateNew__c,
					InitialGrossBillingAmountNew__c,
					InitialNetBillingAmountNew__c,
					Type,
					StageName
				FROM Opportunity
				LIMIT 1
			];
			// Type and StageName updated in a way that would trigger validation rule for others when batch is run
			oppty.Type = 'Renewal';
			oppty.StageName = Utility.UNCOMMITTED_RENEWAL;
			oppty.BillingScheduleTotalAmountNew__c = 0;
			oppty.BillingScheduleTotalNetAmountPaidNew__c = 0;
			oppty.BillingScheduleTotalCount__c = 0;
			oppty.InitialBillingDateNew__c = null;
			oppty.InitialGrossBillingAmountNew__c = 0;
			oppty.InitialNetBillingAmountNew__c = 0;
			update oppty;
		}
		// take away validation rules related permissions so validation rules can fire and batch fails
		BatchBillingScheduleRollUp2Test.batchUser.Account_Admin__c = false;
		BatchBillingScheduleRollUp2Test.batchUser.ProfileId = Utility.getTaniumDealsDeskProfileId();
		update BatchBillingScheduleRollUp2Test.batchUser;
		System.runAs(BatchBillingScheduleRollUp2Test.batchUser) {
			BatchBillingScheduleRollUp2 batch = new BatchBillingScheduleRollUp2('');
			String chron = '0 0 23 * * ?';
			String jobid = System.schedule('testScheduledApex-BatchBillingScheduleRollup2', chron, batch);
			CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
			System.assertEquals(chron, ct.CronExpression);
			Database.executeBatch(batch);
		}
		for (Opportunity opp : [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c
			FROM Opportunity
			WHERE Id = :oppty.Id
		]) {
			System.assertEquals(0, opp.BillingScheduleTotalAmountNew__c);
			System.assertEquals(0, opp.BillingScheduleTotalNetAmountPaidNew__c);
			System.assertEquals(0, opp.BillingScheduleTotalCount__c);
			System.assertEquals(null, opp.InitialBillingDateNew__c);
		}
		for (LogEntry__c each : [
			SELECT Message__c
			FROM LogEntry__c
			WHERE ApexClassName__c = 'BatchBillingScheduleRollUp2'
			AND ApexMethodName__c = 'execute'
		]) {
			System.assertEquals(true, each.Message__c.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
		}
		for (LogEntry__c each : [
			SELECT Message__c
			FROM LogEntry__c
			WHERE ApexClassName__c = 'BatchBillingScheduleRollUp1'
			AND ApexMethodName__c = 'finish'
		]) {
			System.assertEquals(true, each.Message__c.contains('NumberOfErrors: 1'));
		}
	}

	static User getBatchUser() {
		for (User user : [
			SELECT Id
			FROM User
			WHERE UserName = 'testBatchForRollUp@tanium.com'
			LIMIT 1
		]) {
			BatchBillingScheduleRollUp2Test.batchUser = user;
			return BatchBillingScheduleRollUp2Test.batchUser;
		}
		if (BatchBillingScheduleRollUp2Test.batchUser == null) {
			BatchBillingScheduleRollUp2Test.batchUser = TestUserFactory.createTaniumAdminUser(false);
			BatchBillingScheduleRollUp2Test.batchUser.UserName = 'testBatchForRollUp@tanium.com';
			// do not want triggers to run
			BatchBillingScheduleRollUp2Test.batchUser.DisableTaniumCustomTriggers__c = 'All';
			// following permission needed to bypass some legacy account related validation rules
			BatchBillingScheduleRollUp2Test.batchUser.Account_Admin__c = true;
			insert BatchBillingScheduleRollUp2Test.batchUser;
            TestingUtility.assignPermissionSet(BatchBillingScheduleRollUp2Test.batchUser.Id, 'DisableValidationRules');
		}
		return BatchBillingScheduleRollUp2Test.batchUser;
	}
}