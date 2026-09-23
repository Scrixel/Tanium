/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for BatchBillingScheduleQuoteDeleteImpact
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-13619     2026-08-18      Migrated to ELV_Quote__c and simplified test setup
 */
@isTest
private class BatchBillingScheduleQuoteDeleteTest {
	private static String query = 'SELECT ' + 'Id ' + 'FROM Billing_Schedule__c';
	private static final String ANNUAL_PAYMENT_TYPE = BillingScheduleService.ANNUAL_PAYMENT_TYPE;

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteLineTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();

		System.runAs(TestUserFactory.getAdminUser()) {
			TestFactory.seedRubySettings();

			Account account = TestFactory.buildAccount('Test Account 1');
			insert new List<Account>{ account };

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today() + 30,
				'Prospecting',
				account.Id
			);
			opportunity.CloseDate = Date.today();
			opportunity.BillingScheduleTotalAmountNew__c = 10;
			insert opportunity;

			Quote quote = TestFactory.buildQuote('Test Quote 1', opportunity.Id, null, null);
			insert quote;

			Billing_Schedule__c billing1 = TestFactory.buildBillingSchedule(opportunity.Id);
			billing1.Billing_Order__c = 1;
			billing1.Billing_Amount__c = 10.00;
			billing1.Billing_Date__c = System.today();
			billing1.Opportunity__c = opportunity.Id;
			billing1.ELV_Quote__c = null;
			Billing_Schedule__c billing2 = TestFactory.buildBillingSchedule(opportunity.Id);
			billing2.Billing_Order__c = 1;
			billing2.Billing_Amount__c = 10.00;
			billing2.Billing_Date__c = System.today();
			billing2.Opportunity__c = opportunity.Id;
			billing2.ELV_Quote__c = quote.Id;
			insert new List<Billing_Schedule__c>{ billing1, billing2 };

			BillingByQuoteLine__c billingFlatSKU1 = new BillingByQuoteLine__c(
				BillAmount__c = 10.00,
				BillingScheduleOrder__c = '1',
				BillingSchedule__c = billing1.Id,
				Opportunity__c = opportunity.Id
			);
			BillingByQuoteLine__c billingFlatSKU2 = new BillingByQuoteLine__c(
				BillAmount__c = 10.00,
				BillingScheduleOrder__c = '1',
				BillingSchedule__c = billing2.Id,
				Opportunity__c = opportunity.Id,
				ELV_Quote__c = quote.Id
			);
			insert new List<BillingByQuoteLine__c>{ billingFlatSKU1, billingFlatSKU2 };

			insert new Invoice__c(Name = 'Test Invoice');
		}
	}

	@isTest
	static void testBatch_whenBatchRunsSuccessfully_billingsWithNoQuotesAreDeletedSuccessfully() {
		List<Billing_Schedule__c> billingsToDelete = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = NULL AND Opportunity__r.isClosed = FALSE
		];
		Assert.areEqual(1, billingsToDelete.size(), 'billings delete criteria are met');

		List<BillingByQuoteLine__c> billingsByQuoteLinesToDelete = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE BillingSchedule__c IN :billingsToDelete
		];
		Assert.areEqual(1, billingsByQuoteLinesToDelete.size(), 'delete criteria are met');

		User adminUser = TestUserFactory.getAdminUser();
		TestingUtility.assignPermissionSet(adminUser.Id, 'BillingScheduleConfigurator');

		System.runAs(adminUser) {
			Test.startTest();
			BatchBillingScheduleQuoteDeleteImpact.executeBatch();
			Test.stopTest();
		}

		billingsToDelete = [SELECT Id FROM Billing_Schedule__c WHERE ID IN :billingsToDelete];
		Assert.areEqual(0, billingsToDelete.size(), 'billings deleted by batch');

		billingsByQuoteLinesToDelete = [
			SELECT Id
			FROM BillingByQuoteLine__c
			WHERE BillingSchedule__c IN :billingsToDelete
		];
		Assert.areEqual(
			0,
			billingsByQuoteLinesToDelete.size(),
			'deleted by trigger after billing schedule delete'
		);
	}

	@isTest
	static void testBatch_whenFails_createsEventLogRecords() {
		List<Invoice__c> invoices = [SELECT Id FROM Invoice__c];
		for (Billing_Schedule__c billing : [
			SELECT Invoice__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = NULL
		]) {
			billing.Invoice__c = invoices[0].Id;
			update billing;
		}
		String query = 'SELECT Id FROM Billing_Schedule__c WHERE ELV_Quote__c = null';
		Test.startTest();
		try {
			BatchBillingScheduleQuoteDeleteImpact.executeBatch(query);
		} catch (Exception e) {
			List<LogEntry__c> logs = [
				SELECT Id, Message__c
				FROM LogEntry__c
				WHERE
					ApexClassName__c = 'BatchBillingScheduleQuoteDeleteImpact'
					AND ApexMethodName__c = 'execute'
			];
			Assert.areEqual(
				1,
				logs.size(),
				'billing schedule delete when invoice attached not allowed'
			);
		}
		Test.stopTest();
		List<LogEntry__c> logs = [
			SELECT Id, Message__c
			FROM LogEntry__c
			WHERE
				ApexClassName__c = 'BatchBillingScheduleQuoteDeleteImpact'
				AND ApexMethodName__c = 'finish'
		];
		Assert.areEqual(1, logs.size(), 'billing schedule delete when invoice attached not allowed');
	}

	@isTest
	static void testScheduleBatch() {
		Test.startTest();
		String chron = '0 0 23 * * ?';
		String jobid = System.schedule(
			'testScheduledApex-BatchBillingScheduleQuoteDeleteImpact',
			chron,
			new BatchBillingScheduleQuoteDeleteImpact()
		);
		Test.stopTest();

		CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];

		Assert.areEqual(chron, ct.CronExpression);
	}
}