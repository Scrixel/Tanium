/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for InvoiceLinkToBillingSchedule.
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13124   2026-04-30    Updated test class
 * SS-13619   2026-08-19    Migrated to standard Quote/QuoteLineItem
 */

@IsTest
private class InvoiceLinkToBillingScheduleTest {
	static BillingScheduleTriggerHandler billingHndlr = new BillingScheduleTriggerHandler();
	static InvoiceTriggerHandler invoiceHndlr = new InvoiceTriggerHandler();
	static User taniumDealDeskUser;
	@TestSetup
	static void makeData() {
		User adminUser = TestUserFactory.createTaniumAdminUser(true);
		TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
		TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');

		System.runAs(adminUser) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'OpportunityTriggerHandler',
					'QuoteCPQTriggerHandler',
					'QuoteTriggerHandler'
				}
			);

			List<Billing_Schedule__c> billings = new List<Billing_Schedule__c>();
			List<Invoice__c> invoices = new List<Invoice__c>();

			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				Utility.PROSPECTING,
				acct.Id
			);
			insert opportunity;

			Quote quotePrimary = TestFactory.buildQuote(
				'Test Quote Primary',
				opportunity.Id,
				Date.today().addMonths(2),
				Date.today().addMonths(2).addYears(3).addMonths(3)
			);
			quotePrimary.ELV_PaymentTypeNew__c = 'Upfront';

			Quote quoteNonPrimary = TestFactory.buildQuote(
				'Test Quote Non-Primary',
				opportunity.Id,
				Date.today().addMonths(2),
				Date.today().addMonths(2).addYears(3).addMonths(3)
			);
			quoteNonPrimary.ELV_PaymentTypeNew__c = 'Upfront';
			quoteNonPrimary.Ruby__IsPrimaryQuote__c = false;
			insert new List<Quote>{ quotePrimary, quoteNonPrimary };

			Billing_Schedule__c billingNonPrimary = TestFactory.buildBillingSchedule(opportunity.Id);
			billingNonPrimary.Billing_Amount__c = 50;
			billingNonPrimary.Billing_Date__c = Date.today() + 90;
			billingNonPrimary.ELV_Quote__c = quoteNonPrimary.Id;

			Invoice__c invoiceNonPrimary = TestFactory.buildInvoice(opportunity.Id);
			invoiceNonPrimary.InvoiceStatus__c = 'Open';
			invoiceNonPrimary.Amount__c = billingNonPrimary.Billing_Amount__c;
			invoiceNonPrimary.InvoicePaymentTerm__c = 'Net 70';
			invoiceNonPrimary.Invoice_Date__c = billingNonPrimary.Billing_Date__c;
			billings.add(billingNonPrimary);
			invoices.add(invoiceNonPrimary);

			Billing_Schedule__c billingPrimary1 = TestFactory.buildBillingSchedule(opportunity.Id);
			billingPrimary1.Billing_Amount__c = 10;
			billingPrimary1.Invoice_Date__c = Date.today() + 90;
			billingPrimary1.Billing_Date__c = Date.today() + 90;
			billingPrimary1.ELV_Quote__c = quotePrimary.Id;

			Invoice__c invoicePrimary1 = TestFactory.buildInvoice(opportunity.Id);
			invoicePrimary1.InvoiceStatus__c = 'Open';
			invoicePrimary1.Amount__c = 11;
			invoicePrimary1.InvoicePaymentTerm__c = 'Net 70';
			invoicePrimary1.Invoice_Date__c = Date.newInstance(
				billingPrimary1.Invoice_Date__c.year(),
				billingPrimary1.Invoice_Date__c.month(),
				1
			);
			billings.add(billingPrimary1);
			invoices.add(invoicePrimary1);

			Billing_Schedule__c billingPrimary2 = TestFactory.buildBillingSchedule(opportunity.Id);
			billingPrimary2.Billing_Amount__c = 100;
			billingPrimary2.Billing_Date__c = Date.today() + 90;
			billingPrimary2.Invoice_Date__c = Date.today() + 90;
			billingPrimary2.ELV_Quote__c = quotePrimary.Id;

			Invoice__c invoicePrimary2 = TestFactory.buildInvoice(opportunity.Id);
			invoicePrimary2.Amount__c = 105;
			invoicePrimary2.Invoice_Date__c = Date.newInstance(
				billingPrimary2.Invoice_Date__c.year(),
				billingPrimary2.Invoice_Date__c.month(),
				2
			);
			invoicePrimary2.InvoiceStatus__c = 'Open';

			billings.add(billingPrimary2);
			invoices.add(invoicePrimary2);

			Billing_Schedule__c billingPrimary3 = TestFactory.buildBillingSchedule(opportunity.Id);
			billingPrimary3.Billing_Amount__c = 1000;
			billingPrimary3.Billing_Date__c = Date.today() + 90;
			billingPrimary3.Invoice_Date__c = Date.today() + 90;
			billingPrimary3.ELV_Quote__c = quotePrimary.Id;

			Invoice__c invoicePrimary3 = TestFactory.buildInvoice(opportunity.Id);
			invoicePrimary3.Amount__c = 999.50;
			invoicePrimary3.Invoice_Date__c = Date.newInstance(
				billingPrimary3.Invoice_Date__c.year(),
				billingPrimary3.Invoice_Date__c.month(),
				3
			);
			invoicePrimary3.InvoiceStatus__c = 'Paid in Full';
			invoicePrimary3.InvoicePaymentTerm__c = 'Not Applicable';

			billings.add(billingPrimary3);
			invoices.add(invoicePrimary3);

			Billing_Schedule__c billingPrimary4 = TestFactory.buildBillingSchedule(opportunity.Id);
			billingPrimary4.Billing_Amount__c = 10000;
			billingPrimary4.Invoice_Date__c = Date.today() + 90;
			billingPrimary4.Billing_Date__c = Date.today() + 45;
			billingPrimary4.ELV_Quote__c = quotePrimary.Id;

			Invoice__c invoicePrimary4 = TestFactory.buildInvoice(opportunity.Id);
			invoicePrimary4.Amount__c = 20000;
			invoicePrimary4.Invoice_Date__c = Date.newInstance(
				billingPrimary4.Invoice_Date__c.year(),
				billingPrimary4.Invoice_Date__c.month(),
				4
			);
			invoicePrimary4.InvoiceStatus__c = 'Some status';
			billings.add(billingPrimary4);
			invoices.add(invoicePrimary4);
			insert billings;
			insert invoices;
		}
	}

	@IsTest
	static void testUpdateLinksAndStatus_whenInvoiceFindsMatchForPrimaryQuote_returnsCorrectLinksStatusReconFlds() {
		List<Invoice__c> invoicesWithNoMatch = new List<Invoice__c>();
		User salesOpsUser = TestUserFactory.createUser(
			'Sales Ops',
			'salesOps@tanium.com',
			'salesOps',
			Utility.getSuperUserProfileId(),
			Utility.getCorporateRoleId()
		);
		TriggerHandler.resetRecursionLimits();

		System.runAs(salesOpsUser) {
			for (Billing_Schedule__c eachBilling : [
				SELECT
					Id,
					Billing_Amount__c,
					EstimatedPaymentDate__c,
					Invoice__c,
					Invoice_Date__c,
					Invoice_Number__c,
					Invoice_Status__c,
					Invoice__r.Amount__c,
					Invoice__r.Invoice_Date__c,
					Invoice__r.Name,
					Invoice__r.ReconciliationStatus__c,
					Invoice__r.ReconciliationSemiMatchReason__c
				FROM Billing_Schedule__c
				WHERE IsPrimaryQuote__c = TRUE
			]) {
				if (eachBilling.Billing_Amount__c == 10) {
					Assert.areEqual(11, eachBilling.Invoice__r.Amount__c);
					Assert.areEqual('Semi Match', eachBilling.Invoice__r.ReconciliationStatus__c);
					Assert.areEqual(
						'Amount mismatch',
						eachBilling.Invoice__r.ReconciliationSemiMatchReason__c
					);
					Assert.areEqual(eachBilling.Invoice_Date__c, eachBilling.Invoice__r.Invoice_Date__c);
					Assert.areEqual(
						'Invoiced',
						eachBilling.Invoice_Status__c,
						'Invoice Status when Open will be marked Invoiced on Billing Schedule'
					);
					Assert.areEqual(
						eachBilling.Invoice__r.Invoice_Date__c + 70,
						eachBilling.EstimatedPaymentDate__c,
						'Invoice Payment Term was Net 70'
					);
				}

				if (eachBilling.Billing_Amount__c == 100) {
					Assert.areEqual(
						null,
						eachBilling.Invoice__r.Amount__c,
						'Invoice didnt find a match with Billing Schedule'
					);
				}

				if (eachBilling.Billing_Amount__c == 1000) {
					Assert.areEqual(999.50, eachBilling.Invoice__r.Amount__c);
					Assert.areEqual('Semi Match', eachBilling.Invoice__r.ReconciliationStatus__c);
					Assert.areEqual(
						'Amount mismatch',
						eachBilling.Invoice__r.ReconciliationSemiMatchReason__c
					);
					Assert.areEqual(eachBilling.Invoice_Date__c, eachBilling.Invoice__r.Invoice_Date__c);
					Assert.areEqual(
						'Paid',
						eachBilling.Invoice_Status__c,
						'Invoice Status when Paid in Full will be marked Paid on Billing Schedule'
					);
					Assert.areEqual(
						eachBilling.Invoice__r.Invoice_Date__c + 30,
						eachBilling.EstimatedPaymentDate__c,
						'Invoice Payment Term was Not Applicable; hence default value; no Net calculation'
					);
				}

				if (eachBilling.Billing_Amount__c == 10000) {
					Assert.areEqual(null, eachBilling.Invoice__c);
					Assert.areEqual(null, eachBilling.Invoice__r.ReconciliationSemiMatchReason__c);
					Assert.areEqual(
						'Open',
						eachBilling.Invoice_Status__c,
						'No Match status keeps billing status as is'
					);
				}
				Assert.areEqual(eachBilling.Invoice_Number__c, eachBilling.Invoice__r.Name);
			}

			invoicesWithNoMatch = [
				SELECT Id, Amount__c, Invoice_Date__c, ReconciliationSemiMatchReason__c
				FROM Invoice__c
				WHERE ReconciliationStatus__c = 'No Match'
			];
			Assert.areEqual(3, invoicesWithNoMatch.size());
			for (Invoice__c each : invoicesWithNoMatch) {
				Assert.areEqual('None', each.ReconciliationSemiMatchReason__c);
			}

			Test.startTest();
			InvoiceTriggerHandler invoiceHndlr = new InvoiceTriggerHandler();
			invoicesWithNoMatch[0].Amount__c = 100;
			invoicesWithNoMatch[0].Invoice_Date__c = Date.newInstance(
				(Date.today() + 90).year(),
				(Date.today() + 90).month(),
				5
			);

			invoicesWithNoMatch[1].Amount__c = 10000;
			invoicesWithNoMatch[1].Amount__c = 10000.50;
			update invoicesWithNoMatch;
			Test.stopTest();
		}

		for (Billing_Schedule__c eachBilling : [
			SELECT
				Id,
				Billing_Amount__c,
				Invoice_Date__c,
				Invoice_Number__c,
				Invoice_Status__c,
				Invoice__r.Invoice_Date__c,
				Invoice__r.Name,
				Invoice__r.InvoiceStatus__c,
				Invoice__r.ReconciliationStatus__c,
				Invoice__r.ReconciliationSemiMatchReason__c
			FROM Billing_Schedule__c
			WHERE Invoice__c IN :invoicesWithNoMatch
		]) {
			if (eachBilling.Billing_Amount__c == 100) {
				Assert.areEqual('Exact Match', eachBilling.Invoice__r.ReconciliationStatus__c);
				Assert.areEqual('None', eachBilling.Invoice__r.ReconciliationSemiMatchReason__c);
				Assert.areEqual(
					'Invoiced',
					eachBilling.Invoice_Status__c,
					'Invoice Status when Open marked as Invoiced on Billing Schedule'
				);
			} else if (eachBilling.Billing_Amount__c == 10000) {
				Assert.areEqual('Semi Match', eachBilling.Invoice__r.ReconciliationStatus__c);
				Assert.areEqual(
					'Amount mismatch',
					eachBilling.Invoice__r.ReconciliationSemiMatchReason__c
				);
				Assert.areEqual(
					eachBilling.Invoice__r.InvoiceStatus__c,
					eachBilling.Invoice_Status__c,
					'Invoice Status same as on Billing Schedule except when Open and Paid in Full'
				);
			}
			Assert.areEqual(eachBilling.Invoice__r.Name, eachBilling.Invoice_Number__c);
			Assert.areEqual(eachBilling.Invoice_Date__c, eachBilling.Invoice__r.Invoice_Date__c);
		}
	}

	@IsTest
	static void testUpdateLinksAndStatus_whenQuoteIsNotPrimary_evenIfInvoiceFindsMatchItWontBeAttachedToBillingSchedule() {
		Opportunity opportunity = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
		User salesOpsUser = TestUserFactory.createUser(
			'Sales Ops',
			'salesOps@tanium.com',
			'salesOps',
			Utility.getSuperUserProfileId(),
			Utility.getCorporateRoleId()
		);

		System.runAs(salesOpsUser) {
			Billing_Schedule__c billing = [
				SELECT
					Id,
					Name,
					Billing_Amount__c,
					EstimatedPaymentDate__c,
					Invoice__c,
					Invoice_Date__c,
					Invoice_Number__c,
					Invoice_Status__c,
					Invoice__r.Amount__c,
					Invoice__r.Invoice_Date__c,
					Invoice__r.Name,
					Invoice__r.InvoiceStatus__c,
					Invoice__r.ReconciliationStatus__c,
					Invoice__r.ReconciliationSemiMatchReason__c,
					Opportunity__c
				FROM Billing_Schedule__c
				WHERE IsPrimaryQuote__c = FALSE
			];

			Assert.areEqual(
				null,
				billing.Invoice__c,
				'invoice met date and amount criteria but since billing was tied to non-primary quote invoice didnt get attached to this billing schedule'
			);

			Invoice__c invoicesWithNoMatch = [
				SELECT
					Id,
					Name,
					Amount__c,
					Invoice_Date__c,
					ReconciliationStatus__c,
					ReconciliationSemiMatchReason__c
				FROM Invoice__c
				WHERE
					Amount__c = :billing.Billing_Amount__c
					AND Invoice_Date__c = :billing.Invoice_Date__c
			];
			Assert.areEqual(
				'No Match',
				invoicesWithNoMatch.ReconciliationStatus__c,
				'invoice wasnt attached to billing schedule although amount and date criteria were met because it was tied to non primary quote'
			);
		}
	}

	@IsTest
	static void testBillingScheduleFldUpdates_whenInvoiceFldsChange_returnsCorrectValuesOnBillingSchedule() {
		List<Id> invoiceIdsToUpdate = new List<Id>();

		List<Invoice__c> invoicesToUpdate = [
			SELECT Id, Name, InvoiceStatus__c
			FROM Invoice__c
			WHERE Id IN (SELECT Invoice__c FROM Billing_Schedule__c WHERE Invoice__c != NULL)
		];

		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			for (Invoice__c each : invoicesToUpdate) {
				each.InvoiceStatus__c = 'Cancelled';
			}
			update invoicesToUpdate;
			Test.stopTest();

			for (Billing_Schedule__c each : [
				SELECT
					Id,
					Invoice_Date__c,
					Invoice_Number__c,
					Invoice_Status__c,
					Invoice__r.Invoice_Date__c,
					Invoice__r.InvoiceStatus__c,
					Invoice__r.Name
				FROM Billing_Schedule__c
				WHERE Invoice__c IN :invoicesToUpdate
			]) {
				Assert.areEqual(
					each.Invoice__r.InvoiceStatus__c,
					each.Invoice_Status__c,
					'Copy Invoice Status from invoice to billing except when Paid in Full and Open'
				);
				Assert.areEqual(
					each.Invoice__r.Name,
					each.Invoice_Number__c,
					'Copy Invoice Number from invoice to billing'
				);
				Assert.areEqual(
					each.Invoice__r.Invoice_Date__c,
					each.Invoice_Date__c,
					'Copy Invoice Date from invoice to billing'
				);
			}
		}
	}

	@IsTest
	static void testBillingScheduleInvoiceLinkChange_whenLinkIsUpdated_returnsCorrectValuesOnBillingSchedule() {
		Invoice__c newInvoice;
		Billing_Schedule__c billing = [
			SELECT Id, Invoice__c, Opportunity__c
			FROM Billing_Schedule__c
			WHERE Invoice__c != NULL
			LIMIT 1
		];

		User boomiUserForNetsuiteIntegration = TestUserFactory.createUser(
			'Boomi Integration User for Netsuite',
			'SFDCBoomiIntegrationUser@tanium.com',
			'Boomi',
			Utility.getAPIOnlyIntegrationAdminProfileId(),
			Utility.getCorporateRoleId()
		);

		System.runAs(boomiUserForNetsuiteIntegration) {
			newInvoice = TestFactory.buildInvoice(billing.Opportunity__c);
			newInvoice.Name = 'Invoice Name ABC';
			newInvoice.InvoiceStatus__c = 'Invoice Status ABC';
			newInvoice.InvoicePaymentTerm__c = 'SFDC Terms 365';
			newInvoice.Invoice_Date__c = Date.today() + 90;
			insert newInvoice;
		}

		TriggerHandler.resetRecursionLimits();
		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			billing.Invoice__c = newInvoice.Id;
			update billing;
			Test.stopTest();
		}

		billing = [
			SELECT
				Id,
				EstimatedPaymentDate__c,
				Invoice_Date__c,
				Invoice_Number__c,
				Invoice_Status__c,
				Invoice__r.Invoice_Date__c,
				Invoice__r.Name,
				Invoice__r.InvoiceStatus__c
			FROM Billing_Schedule__c
			WHERE Id = :billing.Id
		];

		Assert.areEqual(
			billing.Invoice__r.Name,
			billing.Invoice_Number__c,
			'Billing Invoice Number should always be same as attached invoice name'
		);
		Assert.areEqual(
			billing.Invoice__r.InvoiceStatus__c,
			billing.Invoice_Status__c,
			'Billing Invoice Status same as attached invoice status except for Paid in Full and Open'
		);
		Assert.areEqual(
			billing.Invoice__r.Invoice_Date__c,
			billing.Invoice_Date__c,
			'Billing Invoice Date should always be same as attached invoice date'
		);
		Assert.areEqual(
			billing.Invoice__r.Invoice_Date__c + 30,
			billing.EstimatedPaymentDate__c,
			'Payment Term is SFDC Terms 365 on the invoice; no Net calculation required'
		);
	}

	@IsTest
	static void testBillingScheduleInvoiceLinkChange_whenLinkIsMadeNull_returnsNullOnBillingScheduleFldsAndUpdatePriorInvoiceRecon() {
		TriggerHandler.bypass('QuoteTriggerHandler');
		Invoice__c newInvoice;
		Billing_Schedule__c billing = [
			SELECT Id, Invoice__c, Billing_Amount__c
			FROM Billing_Schedule__c
			WHERE Invoice__c != NULL AND Billing_Date__c != NULL
			LIMIT 1
		];
		Assert.areNotEqual(null, billing);

		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			billing.Billing_Amount__c = billing.Billing_Amount__c + 100;
			billing.Invoice__c = null;
			update billing;
			Test.stopTest();
		}

		for (Billing_Schedule__c each : [
			SELECT
				Id,
				Billing_Date__c,
				EstimatedPaymentDate__c,
				Invoice__c,
				Invoice_Date__c,
				Invoice_Number__c,
				Invoice_Status__c
			FROM Billing_Schedule__c
			WHERE Id = :billing.Id
		]) {
			Assert.areEqual(
				null,
				each.Invoice__c,
				'invoice was made null manually in operation above'
			);
			Assert.areEqual(
				null,
				each.Invoice_Number__c,
				'If no invoice is attached, Billing Invoice Number is null'
			);
			Assert.areEqual(
				null,
				each.Invoice_Status__c,
				'If no invoice is attached, Billing Invoice Status is null'
			);
			Assert.areEqual(
				each.Billing_Date__c,
				each.Invoice_Date__c,
				'invoice date reset to estimated billing date'
			);
			Assert.areEqual(
				each.Invoice_Date__c + 30,
				each.EstimatedPaymentDate__c,
				'estimated payment date set to default'
			);
		}
		for (Invoice__c each : [
			SELECT Id, ReconciliationSemiMatchReason__c, ReconciliationStatus__c
			FROM Invoice__c
			WHERE Id = :billing.Invoice__c
		]) {
			Assert.areEqual(
				'No Match',
				each.ReconciliationStatus__c,
				'If invoice is de-linked, Invoice Recon Status will be updated to No Match'
			);
			Assert.areEqual(
				'None',
				each.ReconciliationSemiMatchReason__c,
				'If invoice is de-linked, Invoice Recon Semi Match Reason will be updated to None'
			);
		}
	}

	@IsTest
	static void testInvoiceDateChange_whenInvoiceIsUpdated_copiesInvoiceDateOnBillingSchedule() {
		Invoice__c newInvoice;
		List<Invoice__c> invoices = [
			SELECT
				Id,
				Name,
				Invoice_Date__c,
				(SELECT Id, Name, Invoice_Date__c FROM BillingSchedules__r)
			FROM Invoice__c
			WHERE ReconciliationStatus__c IN ('Exact Match', 'Semi Match')
		];
		for (Invoice__c eachInvoice : invoices) {
			for (Billing_Schedule__c eachBilling : eachInvoice.BillingSchedules__r) {
				Assert.areEqual(eachBilling.Invoice_Date__c, eachInvoice.Invoice_Date__c);
			}
		}

		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			for (Invoice__c eachInvoice : invoices) {
				eachInvoice.Invoice_Date__c = eachInvoice.Invoice_Date__c - 5;
			}
			update invoices;
			Test.stopTest();
		}

		invoices = [
			SELECT
				Id,
				Name,
				Invoice_Date__c,
				(SELECT Id, Name, Invoice_Date__c FROM BillingSchedules__r)
			FROM Invoice__c
			WHERE ReconciliationStatus__c IN ('Exact Match', 'Semi Match')
		];
		for (Invoice__c eachInvoice : invoices) {
			for (Billing_Schedule__c eachBilling : eachInvoice.BillingSchedules__r) {
				Assert.areEqual(
					eachBilling.Invoice_Date__c,
					eachInvoice.Invoice_Date__c,
					'Invoice Date is copied over to Billing Schedule for Exact and Semi Match'
				);
			}
		}
	}

	@IsTest
	static void testBillingScheduleInvoiceDateAmtChange_whenLinkIsNullAndCriteriaAreMet_returnsMatchOnBillingSchedule() {
		TriggerHandler.bypass('QuoteTriggerHandler');
		Invoice__c newInvoice;
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Quote quote = [SELECT Id FROM Quote LIMIT 1];
		Invoice__c invoice1 = TestFactory.buildInvoice(opportunity.Id);
		invoice1.Amount__c = 50000;
		invoice1.Invoice_Date__c = Date.today() + 30;

		Billing_Schedule__c billing1 = TestFactory.buildBillingSchedule(opportunity.Id);
		billing1.Billing_Amount__c = 50000;
		billing1.Invoice_Date__c = Date.today() + 90;
		billing1.ELV_Quote__c = quote.Id;

		Invoice__c invoice2 = TestFactory.buildInvoice(opportunity.Id);
		invoice2.Amount__c = 60000;
		invoice2.Invoice_Date__c = Date.today() + 120;

		Billing_Schedule__c billing2 = TestFactory.buildBillingSchedule(opportunity.Id);
		billing2.Billing_Amount__c = 70000;
		billing2.Invoice_Date__c = Date.today() + 120;
		billing2.ELV_Quote__c = quote.Id;
		insert new List<Invoice__c>{ invoice1, invoice2 };
		insert new List<Billing_Schedule__c>{ billing1, billing2 };

		for (Billing_Schedule__c each : [
			SELECT Id, Billing_Amount__c, Invoice__c
			FROM Billing_Schedule__c
			WHERE Id = :billing1.Id OR Id = :billing2.Id
		]) {
			Assert.areEqual(null, each.Invoice__c, 'Date/Amt criteria not met; no invoice attached');
		}
		TriggerHandler.resetRecursionLimits();

		Test.startTest();
		billing1.Invoice_Date__c = Date.newInstance(
			invoice1.Invoice_Date__c.year(),
			invoice1.Invoice_Date__c.month(),
			15
		);
		billing2.Billing_Amount__c = invoice2.Amount__c - 1;
		update new List<Billing_Schedule__c>{ billing1, billing2 };
		Test.stopTest();

		for (Billing_Schedule__c eachBilling : [
			SELECT Id, Billing_Amount__c, Invoice__c
			FROM Billing_Schedule__c
			WHERE Id = :billing1.Id OR Id = :billing2.Id
		]) {
			if (eachBilling.Id == billing1.Id) {
				Assert.areEqual(
					invoice1.Id,
					eachBilling.Invoice__c,
					'Date criteria met; invoice attached'
				);
			}
			if (eachBilling.Id == billing2.Id) {
				Assert.areEqual(
					invoice2.Id,
					eachBilling.Invoice__c,
					'Amt criteria met; invoice attached'
				);
			}
		}
	}

	@IsTest
	static void testBillingScheduleEstimatedInvoiceDateChange_whenLinkIsNull_copiesSameDateToInvoiceDateOnBillingSchedule() {
		TriggerHandler.bypass('QuoteTriggerHandler');
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		Quote quote = [SELECT Id FROM Quote LIMIT 1];
		TriggerHandler.resetRecursionLimits();

		Test.startTest();
		Billing_Schedule__c newBilling = TestFactory.buildBillingSchedule(opp.Id);
		newBilling.Billing_Date__c = Date.today() + 500;
		newBilling.ELV_Quote__c = quote.Id;
		insert newBilling;
		Test.stopTest();

		for (Billing_Schedule__c eachBilling : [
			SELECT Id, Billing_Date__c, Invoice_Date__c, Invoice__c
			FROM Billing_Schedule__c
			WHERE Id = :newBilling.Id
		]) {
			Assert.areEqual(null, eachBilling.Invoice__c, 'invoice link null');
			Assert.areEqual(
				eachBilling.Invoice_Date__c,
				eachBilling.Billing_Date__c,
				'invoice link null; Estimated invoice date updated; Invoice Date & Estimated Invoice Date are same'
			);
		}

		TriggerHandler.resetRecursionLimits();
		newBilling.Billing_Date__c = Date.today() + 5;
		update newBilling;

		for (Billing_Schedule__c eachBilling : [
			SELECT Id, Billing_Date__c, Invoice_Date__c, Invoice__c
			FROM Billing_Schedule__c
			WHERE Id = :newBilling.Id
		]) {
			Assert.areEqual(
				eachBilling.Invoice_Date__c,
				eachBilling.Billing_Date__c,
				'invoice link null; Estimated invoice date updated; Invoice Date & Estimated Invoice Date are same'
			);
			Assert.areEqual(null, eachBilling.Invoice__c, 'invoice link null');
		}
	}

	@IsTest
	static void testBillingScheduleEstimatedInvoiceDateChange_whenLinkIsNotNull_InvoiceDateOnBillingScheduleStaysAsIs() {
		Billing_Schedule__c billing = [
			SELECT Id, Billing_Date__c, Invoice__c, Invoice_Date__c
			FROM Billing_Schedule__c
			WHERE Invoice__c != NULL
			LIMIT 1
		];

		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			billing.Billing_Date__c = Date.today() + 1000;
			update billing;
			Test.stopTest();
		}

		for (Billing_Schedule__c eachBilling : [
			SELECT Id, Billing_Date__c, Invoice_Date__c
			FROM Billing_Schedule__c
			WHERE Id = :billing.Id
		]) {
			Assert.areNotEqual(
				eachBilling.Invoice_Date__c,
				eachBilling.Billing_Date__c,
				'Invoice link NOT null; Estimated Invoice Date updated but Invoice Date remains AS IS'
			);
			Assert.areEqual(
				billing.Billing_Date__c,
				eachBilling.Billing_Date__c,
				'Estimated Invoice Date is updated'
			);
			Assert.areEqual(
				billing.Invoice_Date__c,
				eachBilling.Invoice_Date__c,
				'Invoice link NOT null; Invoice Date is NOT same as Estimated Invoice Date'
			);
		}
	}

	@IsTest
	static void testInvoicePaymentTermChange_whenLinkIsNotNull_calculatesEstimatedPaymentDateOnBillingSchedule() {
		List<Billing_Schedule__c> billings = new List<Billing_Schedule__c>();
		List<Id> invoiceIds = new List<Id>();
		List<Invoice__c> invoices = new List<Invoice__c>();

		for (Billing_Schedule__c eachBilling : [
			SELECT Id, Billing_Date__c, EstimatedPaymentDate__c, Invoice__c, Invoice_Date__c
			FROM Billing_Schedule__c
			WHERE Invoice__c != NULL
			LIMIT 4
		]) {
			billings.add(eachBilling);
			invoiceIds.add(eachBilling.Invoice__c);
		}

		Integer i = -1;

		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			for (Invoice__c eachInvoice : [
				SELECT Id, Invoice_Date__c, InvoicePaymentTerm__c
				FROM Invoice__c
				WHERE Id IN :invoiceIds
			]) {
				switch on (++i) {
					when 0 {
						eachInvoice.InvoicePaymentTerm__c = '2% 15 Net 45';
					}
					when 1 {
						eachInvoice.InvoicePaymentTerm__c = 'Net 120';
					}
					when 2 {
						eachInvoice.InvoicePaymentTerm__c = '* Net 30 from agreement';
					}
					when 3 {
						eachInvoice.InvoicePaymentTerm__c = 'Net 60, 3.5% 15 days';
					}
				}
				invoices.add(eachInvoice);
			}
			update invoices;
			Test.stopTest();
		}

		String paymentTerm;
		for (Billing_Schedule__c eachBilling : [
			SELECT
				Id,
				EstimatedPaymentDate__c,
				Invoice_Date__c,
				Invoice__r.Invoice_Date__c,
				Invoice__r.InvoicePaymentTerm__c
			FROM Billing_Schedule__c
			WHERE Id IN :billings
		]) {
			paymentTerm = eachBilling.Invoice__r.InvoicePaymentTerm__c;
			if (paymentTerm.contains('Net 45')) {
				Assert.areEqual(
					eachBilling.Invoice__r.Invoice_Date__c + 45,
					eachBilling.EstimatedPaymentDate__c
				);
			}
			if (paymentTerm.contains('Net 120')) {
				Assert.areEqual(
					eachBilling.Invoice__r.Invoice_Date__c + 120,
					eachBilling.EstimatedPaymentDate__c
				);
			}
			if (paymentTerm.contains('Net 30')) {
				Assert.areEqual(
					eachBilling.Invoice__r.Invoice_Date__c + 30,
					eachBilling.EstimatedPaymentDate__c
				);
			}
			if (paymentTerm.contains('Net 60')) {
				Assert.areEqual(
					eachBilling.Invoice__r.Invoice_Date__c + 60,
					eachBilling.EstimatedPaymentDate__c
				);
			}
		}
	}

	@IsTest
	static void testInvoiceDateChange_whenLinkIsNotNull_calculatesEstimatedPaymentDateOnBillingSchedule() {
		Invoice__c invoice = [
			SELECT Id, Invoice_Date__c, InvoicePaymentTerm__c
			FROM Invoice__c
			WHERE
				Invoice_Date__c != NULL
				AND ReconciliationStatus__c IN ('Exact Match', 'Semi Match')
				AND InvoicePaymentTerm__c LIKE 'Net%'
			LIMIT 1
		];

		Integer expectedPaymentDateSkew = Integer.valueOf(
			invoice.InvoicePaymentTerm__c.substringAfter('Net ')
		);

		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			invoice.Invoice_Date__c = Date.today() + 100;
			update invoice;
			Test.stopTest();
		}

		for (Billing_Schedule__c eachBilling : [
			SELECT
				Id,
				EstimatedPaymentDate__c,
				Invoice_Date__c,
				Invoice__r.Invoice_Date__c,
				Invoice__r.InvoicePaymentTerm__c
			FROM Billing_Schedule__c
			WHERE Invoice__c = :invoice.Id
			LIMIT 1
		]) {
			Assert.areEqual(
				eachBilling.Invoice__r.Invoice_Date__c + expectedPaymentDateSkew,
				eachBilling.EstimatedPaymentDate__c,
				'Invoice Payment term contains Net XX; EstimatedPaymentDate calculated accordingly'
			);
		}
	}

	@IsTest
	static void testBillingDelete_whenBillingIsDeleted_InvoiceReconStatusChangesToNone() {
		TriggerHandler.bypass('QuoteTriggerHandler');
		Set<Id> invoicesToUpdateReconStatus = new Set<Id>();

		List<Billing_Schedule__c> billingsToDelete = [
			SELECT Id, Invoice__c
			FROM Billing_Schedule__c
			WHERE Invoice__r.ReconciliationStatus__c IN ('Exact Match', 'Semi Match')
		];
		Assert.areEqual(true, !billingsToDelete.isEmpty());

		for (Billing_Schedule__c eachBilling : billingsToDelete) {
			invoicesToUpdateReconStatus.add(eachBilling.Invoice__c);
		}

		System.runAs(getTaniumDealDeskUser()) {
			Test.startTest();
			delete billingsToDelete;
			Test.stopTest();
		}

		for (Invoice__c eachInvoice : [
			SELECT Id, ReconciliationStatus__c, ReconciliationSemiMatchReason__c
			FROM Invoice__c
			WHERE ID IN :invoicesToUpdateReconStatus
		]) {
			Assert.areEqual(
				null,
				eachInvoice.ReconciliationStatus__c,
				'Invoice Recon status attached to deleted invoice is null'
			);
			Assert.areEqual(
				null,
				eachInvoice.ReconciliationSemiMatchReason__c,
				'Invoice Recon Semi Match Reason attached to deleted invoice is null'
			);
		}
	}

	@IsTest
	static void testBillingScheduleInsert_WhenNonPrimaryQuote_InvoiceDateSameAsBillingDate() {
		Billing_Schedule__c billingSched = [
			SELECT Id, Invoice_Date__c, Billing_Date__c
			FROM Billing_Schedule__c
			WHERE isPrimaryQuote__c = FALSE
			LIMIT 1
		];

		Assert.IsTrue(billingSched.Invoice_Date__c != null);
		Assert.IsTrue(billingSched.Invoice_Date__c == billingSched.Billing_Date__c);
	}

	static User getTaniumDealDeskUser() {
		if (InvoiceLinkToBillingScheduleTest.taniumDealDeskUser == null) {
			InvoiceLinkToBillingScheduleTest.taniumDealDeskUser = TestUserFactory.createDealDeskUser();
			TestingUtility.assignCustomPermission(
				InvoiceLinkToBillingScheduleTest.taniumDealDeskUser.Id,
				BillingScheduleUtility.CUSTOM_UPDATE_DELETE_PERMISSION
			);
			TestingUtility.assignPermissionSet(taniumDealDeskUser.Id, 'DisableFlows');
		}
		return InvoiceLinkToBillingScheduleTest.taniumDealDeskUser;
	}
}