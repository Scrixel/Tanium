/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for BillingScheduleUtility. makeData covers BillingScheduleTriggerHandler.
 * @Date: 2020-01-18
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7583    2024-03-21    Removing BoomiRestService code references
 * SS-13619   2026-08-18    Migrated to standard Quote/QuoteLineItem and deduped tests
 */

@isTest
private class BillingScheduleUtilityTest {
	static BillingScheduleTriggerHandler billingHndlr = new BillingScheduleTriggerHandler();
	static User dealsDeskUser;
	static final String CUSTOM_PAYMENT_TYPE = BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE;
	static final String QUARTERLY_PAYMENT_TYPE = BillingScheduleConfiguratorController.QUARTERLY_PAYMENT_TYPE;
	static final String UPFRONT_PAYMENT_TYPE = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE;
	static final String ANNUAL_PAYMENT_TYPE = BillingScheduleConfiguratorController.ANNUAL_PAYMENT_TYPE;

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

		System.runAs(getAdminUser()) {
			TestFactory.seedRubySettings();
			
			Account acct = TestFactory.buildAccount('Test Account');
			acct.type = 'Analyst';
			acct.Country_Restrictions__c = 'Business Allowed';
			insert acct;
			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				'Prospecting',
				acct.Id
			);
			opportunity.CloseDate = Date.today() + 60;
			opportunity.Deal_Desk_Approver__c = getDealsDeskUser().Id;
			insert opportunity;

			Quote quote = TestFactory.buildQuote('Test Quote', opportunity.Id, null, null);
			insert quote;

			Product2 flatSKUProduct = new Product2(
				IsActive = true,
				Name = 'Flat SKU Product',
				Description = 'test description',
				Product_Category__c = 'Hardware',
				Prorate_Billing__c = false,
				SBQQ__SubscriptionPricing__c = 'One-time'
			);
			insert flatSKUProduct;

			PricebookEntry flatSKUPricebookEntry = TestFactory.buildPricebookEntry(
				flatSKUProduct.Id,
				1000,
				Test.getStandardPricebookId()
			);
			insert flatSKUPricebookEntry;

			QuoteLineItem quoteLineFlatSKU = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				1000,
				flatSKUPricebookEntry.Id
			);
			insert quoteLineFlatSKU;

			Billing_Schedule__c billingSchedule = TestFactory.buildBillingSchedule(opportunity.Id);
			billingSchedule.Billing_Amount__c = 100;
			billingSchedule.Billing_Amount_Net_Rollup__c = 100;
			billingSchedule.Billing_Order__c = 1;
			billingSchedule.ELV_Quote__c = quote.Id;
			billingSchedule.Opportunity__c = opportunity.Id;
			insert billingSchedule;

			BillingByQuoteLine__c billingByQuoteLine = new BillingByQuoteLine__c(
				BillingSchedule__c = billingSchedule.Id,
				BillAmount__c = 100,
				BillDate__c = Date.today() + 60,
				BillingScheduleOrder__c = '1',
				Opportunity__c = billingSchedule.Opportunity__c,
				PaymentType__c = UPFRONT_PAYMENT_TYPE,
				ELV_Quote__c = billingSchedule.ELV_Quote__c,
				ELV_QuoteLine__c = quoteLineFlatSKU.Id
			);
			insert billingByQuoteLine;

			insert new Invoice__c(Name = 'Test Invoice');
		}
	}

	@IsTest
	static void testEstimatedInvoiceDate_whenOppIsClosedWon_EstimatedDateSameAsOppCloseDate() {
		SBQQ.TriggerControl.disable();
		Billing_Schedule__c billing = [
			SELECT Id, Billing_Date__c, Opportunity__c, Opportunity__r.CloseDate, PaymentType__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1
			LIMIT 1
		];
		System.assertEquals(null, billing.PaymentType__c);
		Opportunity opp = [
			SELECT Id, BillingScheduleTotalAmountNew__c, BillingScheduleTotalCount__c, CloseDate, StageName
			FROM Opportunity
			WHERE Id = :billing.Opportunity__c
		];
		System.assertEquals(billing.Opportunity__r.CloseDate, billing.Billing_Date__c);
		System.assertEquals(1, opp.BillingScheduleTotalCount__c);
		System.runAs(getAdminUser()) {
			Test.startTest();
			opp.StageName = Utility.CLOSED_WON;
			update opp;
			Test.stopTest();
		}
		billing = [
			SELECT
				Id,
				Billing_Date__c,
				Opportunity__c,
				Opportunity__r.BillingScheduleTotalCount__c,
				Opportunity__r.CloseDate
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opp.Id
		];
		System.assertEquals(1, billing.Opportunity__r.BillingScheduleTotalCount__c);
		System.assertEquals(
			billing.Opportunity__r.CloseDate,
			billing.Billing_Date__c,
			'When Opp in closed won, the opp close date will be passed on to Billing Order 1 Billing Date only'
		);
	}

	@IsTest
	static void testEstimatedInvoiceDate_whenOppCloseDateIsUpdated_OppCloseDateDoesNotChangeBillingDate() {
		SBQQ.TriggerControl.disable();
		Billing_Schedule__c billing = [
			SELECT Id, Billing_Date__c, Opportunity__c, Opportunity__r.CloseDate, PaymentType__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1
			LIMIT 1
		];
		Date oldBillingDate = billing.Billing_Date__c;
		Opportunity opp = [
			SELECT Id, BillingScheduleTotalCount__c, CloseDate
			FROM Opportunity
			WHERE Id = :billing.Opportunity__c
		];
		System.assertEquals(billing.Opportunity__r.CloseDate, billing.Billing_Date__c);
		System.assertEquals(1, opp.BillingScheduleTotalCount__c);
		Test.startTest();
		System.runAs(BillingScheduleUtilityTest.getDealsDeskUser()) {
			opp.CloseDate = opp.CloseDate + 100;
			update opp;
			Test.stopTest();
			billing = [
				SELECT
					Id,
					Billing_Date__c,
					Opportunity__c,
					Opportunity__r.BillingScheduleTotalCount__c,
					Opportunity__r.CloseDate,
					PaymentType__c
				FROM Billing_Schedule__c
				WHERE Opportunity__c = :opp.Id
			];
			System.assertEquals(1, billing.Opportunity__r.BillingScheduleTotalCount__c);
			System.assertEquals(
				oldBillingDate,
				billing.Billing_Date__c,
				'When Opp Close Date is updated, the change will be NOT passed on to Billing Order 1'
			);
		}
	}

	@IsTest
	static void testProcessRollUpFieldsOnOpp_whenBillingUpsert_RollUpFldsAreAccurate() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass('QuoteTriggerHandler');
		Billing_Schedule__c billing1 = [
			SELECT Id, Billing_Amount__c, Billing_Amount_Net_Rollup__c, Billing_Date__c, Opportunity__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1
		];
		Opportunity opp = [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			WHERE Id = :billing1.Opportunity__c
		];
		System.assertEquals(billing1.Billing_Amount__c, opp.BillingScheduleTotalAmountNew__c);
		System.assertEquals(1, opp.BillingScheduleTotalCount__c);
		System.assertEquals(billing1.Billing_Date__c, opp.InitialBillingDateNew__c);
		System.assertEquals(billing1.Billing_Amount__c, opp.InitialGrossBillingAmountNew__c);
		System.assertEquals(billing1.Billing_Amount_Net_Rollup__c, opp.InitialNetBillingAmountNew__c);
		System.assertEquals(0, opp.BillingScheduleTotalNetAmountPaidNew__c);

		Billing_Schedule__c billing2;
		Test.startTest();
		System.runAs(BillingScheduleUtilityTest.getDealsDeskUser()) {
			billing1.Billing_Date__c = Date.today() + 100;
			billing1.Billing_Amount__c = 101;
			billing1.Billing_Amount_Net_Rollup__c = 175;
			billing1.Invoice_Status__c = 'Paid';
			billing1.Billing_Order__c = 1;
			update billing1;
			billing2 = TestFactory.buildBillingSchedule(opp.Id);
			billing2.Billing_Amount__c = 200;
			billing2.Billing_Date__c = Date.today() + 90;
			billing2.Billing_Amount_Net_Rollup__c = 275;
			billing2.Billing_Order__c = 2;
			insert billing2;
		}
		Test.stopTest();
		billing1 = [
			SELECT Id, Billing_Amount__c, Billing_Amount_Net_Rollup__c, Billing_Date__c, Opportunity__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1
		];
		opp = [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			WHERE Id = :billing1.Opportunity__c
		];
		System.assertEquals(
			billing1.Billing_Amount__c + billing2.Billing_Amount__c,
			opp.BillingScheduleTotalAmountNew__c,
			'Total amount rollup'
		);
		System.assertEquals(
			billing1.Billing_Amount_Net_Rollup__c,
			opp.BillingScheduleTotalNetAmountPaidNew__c,
			'only billing 1 is in Paid status'
		);
		System.assertEquals(2, opp.BillingScheduleTotalCount__c);
		System.assertEquals(
			billing2.Billing_Date__c,
			opp.InitialBillingDateNew__c,
			'InitialBillingDate will be MIN(Billing_Date__c)'
		);
		System.assertEquals(
			billing1.Billing_Amount__c,
			opp.InitialGrossBillingAmountNew__c,
			'InitialGrossBillingAmountNew will be Billing_Amount__c of Billing Order 1'
		);
		System.assertEquals(
			billing1.Billing_Amount_Net_Rollup__c,
			opp.InitialNetBillingAmountNew__c,
			'InitialNetBillingAmountNew will be Billing_Amount_Net_Rollup__c of Billing Order 1'
		);
	}

	@IsTest
	static void testProcessRollUpFieldsOnOpp_whenBillingDeletedInPrimaryQuote_RollupFieldsAreAccurate() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.resetRecursionLimits();
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' });
		Opportunity opp;
		List<Billing_Schedule__c> primaryBillings = [
			SELECT Opportunity__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__r.Ruby__IsPrimaryQuote__c = TRUE
		];
		System.assertEquals(1, primaryBillings.size());
		System.assertNotEquals(null, primaryBillings[0].Opportunity__c);
		opp = [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			WHERE Id = :primaryBillings[0].Opportunity__c
		];
		System.assertNotEquals(0, opp.BillingScheduleTotalAmountNew__c);
		System.assertEquals(
			0,
			opp.BillingScheduleTotalNetAmountPaidNew__c,
			'BillingScheduleTotalNetAmountPaidNew adds Billing_Amount__c for Paid Invoice Status only'
		);
		System.assertEquals(
			0,
			opp.BillingScheduleTotalNetAmountPaidNew__c,
			'BillingScheduleTotalNetAmountPaidNew adds Billing_Amount_Net_Rollup__c for Paid Invoice Status only'
		);
		System.assertEquals(1, opp.BillingScheduleTotalCount__c);
		System.assertNotEquals(null, opp.InitialBillingDateNew__c);
		System.assertNotEquals(null, opp.InitialGrossBillingAmountNew__c);
		System.assertNotEquals(null, opp.InitialNetBillingAmountNew__c);

		Test.startTest();
		TriggerHandler.resetRecursionLimits();
		delete primaryBillings;
		Test.stopTest();
		opp = [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			WHERE Id = :opp.Id
		];
		System.assertEquals(
			0,
			opp.BillingScheduleTotalAmountNew__c,
			'Primary quote billings impact opp rollup'
		);
		System.assertEquals(
			0,
			opp.BillingScheduleTotalNetAmountPaidNew__c,
			'Primary quote billings impact opp rollup'
		);
		System.assertEquals(
			0,
			opp.BillingScheduleTotalCount__c,
			'Primary quote billings impact opp rollup'
		);
		System.assertEquals(
			null,
			opp.InitialBillingDateNew__c,
			'Primary quote billings impact opp rollup'
		);
		System.assertEquals(
			0,
			opp.InitialGrossBillingAmountNew__c,
			'Primary quote billings impact opp rollup'
		);
		System.assertEquals(
			0,
			opp.InitialNetBillingAmountNew__c,
			'Primary quote billings impact opp rollup'
		);
	}

	@IsTest
	static void testProcessRollUpFieldsOnOpp_whenBillingDeletedInNonPrimaryQuote_RollupFieldsAreAccurate() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.resetRecursionLimits();
		Opportunity oppBefore = [
			SELECT
				Id,
				AccountId,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			LIMIT 1
		];
		System.assertNotEquals(0, oppBefore.BillingScheduleTotalAmountNew__c);
		System.assertEquals(
			0,
			oppBefore.BillingScheduleTotalNetAmountPaidNew__c,
			'BillingScheduleTotalNetAmountPaidNew adds Billing_Amount__c for Paid Invoice Status only'
		);
		System.assertEquals(
			0,
			oppBefore.BillingScheduleTotalNetAmountPaidNew__c,
			'BillingScheduleTotalNetAmountPaidNew adds Billing_Amount_Net_Rollup__c for Paid Invoice Status only'
		);
		System.assertEquals(1, oppBefore.BillingScheduleTotalCount__c);
		System.assertNotEquals(null, oppBefore.InitialBillingDateNew__c);
		System.assertNotEquals(null, oppBefore.InitialGrossBillingAmountNew__c);
		System.assertNotEquals(null, oppBefore.InitialNetBillingAmountNew__c);

		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' });
		Quote quote = TestFactory.buildQuote('Test Non-Primary Quote', oppBefore.Id, null, null);
		quote.Ruby__IsPrimaryQuote__c = false;
		insert quote;

		Billing_Schedule__c billingSchedule = TestFactory.buildBillingSchedule(oppBefore.Id);
		billingSchedule.Billing_Amount__c = 100;
		billingSchedule.Billing_Amount_Net_Rollup__c = 100;
		billingSchedule.Billing_Order__c = 1;
		billingSchedule.ELV_Quote__c = quote.Id;
		billingSchedule.Opportunity__c = null;
		insert billingSchedule;

		List<Billing_Schedule__c> nonPrimaryBillings = [
			SELECT Opportunity__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__r.Ruby__IsPrimaryQuote__c = FALSE
		];
		System.assertEquals(1, nonPrimaryBillings.size());
		System.assertEquals(null, nonPrimaryBillings[0].Opportunity__c);

		Test.startTest();
		TriggerHandler.resetRecursionLimits();
		delete nonPrimaryBillings;
		Test.stopTest();
		Opportunity oppAfter = [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			WHERE Id = :oppBefore.Id
		];
		System.assertEquals(
			oppBefore.BillingScheduleTotalAmountNew__c,
			oppAfter.BillingScheduleTotalAmountNew__c,
			'Non primary quote billings have no impact on opp rollup'
		);
		System.assertEquals(
			oppBefore.BillingScheduleTotalNetAmountPaidNew__c,
			oppAfter.BillingScheduleTotalNetAmountPaidNew__c,
			'Non primary quote billings have no impact on opp rollup'
		);
		System.assertEquals(
			oppBefore.BillingScheduleTotalCount__c,
			oppAfter.BillingScheduleTotalCount__c,
			'Non primary quote billings have no impact on opp rollup'
		);
		System.assertEquals(
			oppBefore.InitialBillingDateNew__c,
			oppAfter.InitialBillingDateNew__c,
			'Non primary quote billings have no impact on opp rollup'
		);
		System.assertEquals(
			oppBefore.InitialGrossBillingAmountNew__c,
			oppAfter.InitialGrossBillingAmountNew__c,
			'Non primary quote billings have no impact on opp rollup'
		);
		System.assertEquals(
			oppBefore.InitialNetBillingAmountNew__c,
			oppAfter.InitialNetBillingAmountNew__c,
			'Non primary quote billings have no impact on opp rollup'
		);
	}

	@IsTest
	static void testProcessRollUpFieldsOnOpp_whenBillingUpdatedWithExceptions_ExceptionIsThrown() {
		Boolean exceptionThrown = false;
		String errorMessage;
		Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
		Billing_Schedule__c billing1 = [
			SELECT Id, Billing_Amount__c
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opp.Id
			LIMIT 1
		];

		Test.startTest();
		try {
			System.runAs(BillingScheduleUtilityTest.getDealsDeskUser()) {
				Account acct = [SELECT Id, Type FROM Account WHERE Id = :opp.AccountId];
				acct.Type = 'Protected';
				update acct;
				billing1.Billing_Amount__c = 101;
				update billing1;
			}
		} catch (Exception e) {
			exceptionThrown = true;
			errorMessage = e.getMessage();
		}
		Test.stopTest();

		System.assertEquals(true, exceptionThrown, 'Exception should be thrown.');
		System.assertEquals(
			true,
			errorMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'),
			'Exception shown to user'
		);
	}

	@IsTest
	static void testProcessRollUpFieldsOnOpp_whenBillingDeletedWithExceptions_ExceptionIsThrown() {
		Boolean exceptionThrown = false;
		String errorMessage;
		Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
		Billing_Schedule__c billing1 = [
			SELECT Id, Billing_Amount__c
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opp.Id
			LIMIT 1
		];
		Test.startTest();
		System.runAs(BillingScheduleUtilityTest.getDealsDeskUser()) {
			try {
				Account acct = [SELECT Id, Type FROM Account WHERE Id = :opp.AccountId];
				acct.Type = 'Protected';
				update acct;
				delete billing1;
			} catch (Exception e) {
				exceptionThrown = true;
				errorMessage = e.getMessage();
			}
		}
		Test.stopTest();

		System.assertEquals(true, exceptionThrown, 'Exception should be thrown.');
		System.assertEquals(
			true,
			errorMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'),
			'Exception is caught'
		);
	}

	@IsTest
	static void testProcessRollUpFieldsOnOpp_whenYouHaveBillingOrder1On2Records_calculatesRollupAccurately() {
		Billing_Schedule__c billing1_dup;
		Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
		Billing_Schedule__c billing1 = [
			SELECT Id, Billing_Amount__c, Billing_Amount_Net_Rollup__c, Billing_Date__c, Opportunity__c
			FROM Billing_Schedule__c
			WHERE Opportunity__c = :opp.Id
			LIMIT 1
		];
		Test.startTest();
		System.runAs(BillingScheduleUtilityTest.getDealsDeskUser()) {
			billing1_dup = TestFactory.buildBillingSchedule(billing1.Opportunity__c);
			billing1_dup.Billing_Amount__c = 150;
			billing1_dup.Billing_Order__c = 1;
			billing1_dup.Billing_Amount_Net_Rollup__c = 150;
			billing1_dup.Billing_Date__c = billing1.Billing_Date__c - 10;
			insert billing1_dup;
		}
		Test.stopTest();
		opp = [
			SELECT
				Id,
				BillingScheduleTotalAmountNew__c,
				BillingScheduleTotalNetAmountPaidNew__c,
				BillingScheduleTotalCount__c,
				InitialBillingDateNew__c,
				InitialGrossBillingAmountNew__c,
				InitialNetBillingAmountNew__c
			FROM Opportunity
			WHERE Id = :opp.Id
		];
		System.assertEquals(
			billing1.Billing_Amount__c + billing1_dup.Billing_Amount__c,
			opp.BillingScheduleTotalAmountNew__c
		);
		System.assertEquals(0, opp.BillingScheduleTotalNetAmountPaidNew__c);
		System.assertEquals(2, opp.BillingScheduleTotalCount__c);
		System.assertEquals(billing1_dup.Billing_Date__c, opp.InitialBillingDateNew__c);
		System.assertEquals(
			billing1.Billing_Amount__c + billing1_dup.Billing_Amount__c,
			opp.InitialGrossBillingAmountNew__c,
			'SUM(Billing_Amount__c) for billing Order 1'
		);
		System.assertEquals(
			billing1.Billing_Amount_Net_Rollup__c + billing1_dup.Billing_Amount_Net_Rollup__c,
			opp.InitialNetBillingAmountNew__c,
			'SUM(Billing_Amount_Net_Rollup__c) for billing Order 1'
		);
	}

	@isTest
	static void testBillingsByQuoteLinesAfterBillingScheduleDelete_whenException_throwsException() {
		Boolean exceptionThrown = false;
		String errorMessage;
		List<Id> billingsByQuoteLinesToDelete = new List<Id>();
		billingsByQuoteLinesToDelete.add('a0U8N000000XXXwYYY');
		Test.startTest();
		try {
			BillingScheduleUtility.processBillingsByQuoteLinesAfterBillingScheduleDelete(null);
		} catch (Exception e) {
			exceptionThrown = true;
			errorMessage = e.getMessage();
		}
		Test.stopTest();

		System.assertEquals(true, exceptionThrown, 'Exception should be thrown.');
		System.assertEquals(true, !String.isBlank(errorMessage), 'Exception is caught');
	}

	@isTest
	static void testProcessRollupsOnBillingSchedules_whenBillingsByQuoteLinesEdited_calculatesRollupFldsOnBillingSchedules() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);

		System.runAs(getDealsDeskUser()) {
			BillingByQuoteLine__c billingsByQL = [
				SELECT BillAmount__c, PaymentType__c, Opportunity__c
				FROM BillingByQuoteLine__c
				LIMIT 1
			];
			billingsByQL.OwnerId = getDealsDeskUser().Id;
			update billingsByQL;
		}

		System.runAs(getDealsDeskUser()) {
			TriggerHandler.resetRecursionLimits();
			BillingByQuoteLine__c billingByQuoteLine = [
				SELECT BillAmount__c, PaymentType__c, Opportunity__c
				FROM BillingByQuoteLine__c
				LIMIT 1
			];

			Test.startTest();
			billingByQuoteLine.BillAmount__c = 500;
			update billingByQuoteLine;
			Billing_Schedule__c billingSchedule = [
				SELECT Billing_Amount__c, PaymentType__c, Opportunity__c
				FROM Billing_Schedule__c
				WHERE Opportunity__c = :billingByQuoteLine.Opportunity__c
				LIMIT 1
			];
			System.assertEquals(
				billingByQuoteLine.BillAmount__c,
				billingSchedule.Billing_Amount__c,
				'Single Billing By Quote Line tied to Billing Schedule'
			);
			TriggerHandler.resetRecursionLimits();
			billingByQuoteLine.PaymentType__c = 'Custom';
			update billingByQuoteLine;
			Test.stopTest();
			billingSchedule = [
				SELECT Billing_Amount__c, PaymentType__c, Opportunity__c
				FROM Billing_Schedule__c
				WHERE Opportunity__c = :billingByQuoteLine.Opportunity__c
				LIMIT 1
			];
			System.assertEquals(
				billingByQuoteLine.PaymentType__c,
				billingSchedule.PaymentType__c,
				'Single Billing By Quote Line tied to Billing Schedule'
			);
		}
	}

	@isTest
	static void testProcessRollupsOnBillingSchedules_whenBillingsByQuoteLinesDeleted_calculatesRollupFldsOnBillingSchedules() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);
		Billing_Schedule__c billingSchedule = [
			SELECT Id, Billing_Amount__c, Opportunity__c, Opportunity__r.AccountId, PaymentType__c
			FROM Billing_Schedule__c
			LIMIT 1
		];
		System.assertEquals(
			100,
			billingSchedule.Billing_Amount__c,
			'Billing Amount when billing schedule was created'
		);

		BillingByQuoteLine__c billingByQuoteLine = [
			SELECT BillAmount__c, PaymentType__c, Opportunity__c
			FROM BillingByQuoteLine__c
			LIMIT 1
		];
		Test.startTest();
		delete billingByQuoteLine;
		Test.stopTest();
		billingSchedule = [
			SELECT Billing_Amount__c, PaymentType__c, Opportunity__c
			FROM Billing_Schedule__c
			WHERE Id = :billingSchedule.Id
		];
		System.assertEquals(
			0,
			billingSchedule.Billing_Amount__c,
			'Zero billings by quote lines tied to Billing Schedule'
		);
		System.assertEquals(
			null,
			billingSchedule.PaymentType__c,
			'Zero billings by quote lines tied to Billing Schedule'
		);
	}

	@IsTest
	static void testEditPermissionWithInvoice_whenNoCustomPermission_ThrowException() {
		assertInvoicePermission(false, false);
	}

	@IsTest
	static void testEditPermissionWithInvoice_whenWithCustomPermission_ExceptionNotThrown() {
		assertInvoicePermission(true, false);
	}

	@IsTest
	static void testDeletePermissionWithInvoice_whenNoCustomPermission_ThrowException() {
		assertInvoicePermission(false, true);
	}

	@IsTest
	static void testDeletePermissionWithInvoice_whenWithCustomPermission_ExceptionNotThrown() {
		assertInvoicePermission(true, true);

		List<Billing_Schedule__c> billingSchedules = [SELECT Id, Invoice__c FROM Billing_Schedule__c];
		System.assertEquals(0, billingSchedules.size(), 'Billing Schedule should be deleted.');
	}

	@IsTest
	static void processRollupsOnQuoteForUpsert_whenBillingUpsert_RollUpFieldsAreAccurate() {
		TriggerHandler.bypass('QuoteTriggerHandler');
		Billing_Schedule__c billing1 = [
			SELECT Id, Billing_Amount__c, ELV_Quote__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1
		];
		Billing_Schedule__c billing2 = new Billing_Schedule__c();

		Test.startTest();
		System.runAs(BillingScheduleUtilityTest.getDealsDeskUser()) {
			SBQQ.TriggerControl.disable();
			billing2.Billing_Amount__c = 200;
			billing2.Billing_Date__c = Date.today() + 90;
			billing2.Billing_Amount_Net_Rollup__c = 275;
			billing2.Billing_Order__c = 2;
			billing2.ELV_Quote__c = billing1.ELV_Quote__c;
			insert billing2;
		}
		Test.stopTest();

		billing1 = [
			SELECT Id, Billing_Amount__c, ELV_Quote__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1
		];

		Quote quote = [
			SELECT Id, ELV_Billing_Schedule_Total_Amount__c
			FROM Quote
			WHERE Id = :billing1.ELV_Quote__c
		];

		System.assertEquals(
			billing1.Billing_Amount__c + billing2.Billing_Amount__c,
			quote.ELV_Billing_Schedule_Total_Amount__c,
			'ELV_Billing_Schedule_Total_Amount__c should be equal to sum of Billing Amounts'
		);
	}

	@IsTest
	static void processRollupsOnQuoteForDelete_whenBillingDeleted_RollupFieldsAreAccurate() {
		TriggerHandler.bypass('QuoteTriggerHandler');
		Billing_Schedule__c billing1 = [
			SELECT Id, Billing_Amount__c, ELV_Quote__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 1
		];

		Billing_Schedule__c billingSched = new Billing_Schedule__c();
		billingSched.Billing_Amount__c = 105;
		billingSched.Billing_Amount_Net_Rollup__c = 100;
		billingSched.Billing_Order__c = 2;
		billingSched.ELV_Quote__c = billing1.ELV_Quote__c;
		billingSched.Opportunity__c = null;
		insert billingSched;

		Quote quoteBeforeDelete = [
			SELECT Id, ELV_Billing_Schedule_Total_Amount__c
			FROM Quote
			WHERE Id = :billing1.ELV_Quote__c
		];

		System.assertEquals(
			billing1.Billing_Amount__c + billingSched.Billing_Amount__c,
			quoteBeforeDelete.ELV_Billing_Schedule_Total_Amount__c,
			'ELV_Billing_Schedule_Total_Amount__c should be equal to sum of Billing Amounts'
		);

		Test.startTest();
		System.runAs(BillingScheduleUtilityTest.getDealsDeskUser()) {
			delete billing1;
		}
		Test.stopTest();
		billing1 = [
			SELECT Id, Billing_Amount__c, ELV_Quote__c
			FROM Billing_Schedule__c
			WHERE Billing_Order__c = 2
		];

		Quote quoteAfterDelete = [
			SELECT Id, ELV_Billing_Schedule_Total_Amount__c
			FROM Quote
			WHERE Id = :billing1.ELV_Quote__c
		];

		System.assertEquals(
			billingSched.Billing_Amount__c,
			quoteAfterDelete.ELV_Billing_Schedule_Total_Amount__c,
			'ELV_Billing_Schedule_Total_Amount__c should be equal to the remaining Billing Amounts'
		);
	}

	static void assertInvoicePermission(Boolean hasCustomPermission, Boolean isDelete) {
		TriggerHandler.bypass('QuoteTriggerHandler');
		Boolean exceptionThrown = false;
		String errorMsg = '';
		User dealDeskUser = getDealsDeskUser();
		if (hasCustomPermission) {
			TestingUtility.assignCustomPermission(
				dealDeskUser.Id,
				BillingScheduleUtility.CUSTOM_UPDATE_DELETE_PERMISSION
			);
		}

		System.runAs(dealDeskUser) {
			Invoice__c invoice = [SELECT Id FROM Invoice__c LIMIT 1];
			Billing_Schedule__c billingSchedule = [
				SELECT Id, Invoice__c
				FROM Billing_Schedule__c
				LIMIT 1
			];
			billingSchedule.Invoice__c = invoice.Id;
			update billingSchedule;

			Test.startTest();
			try {
				if (isDelete) {
					delete billingSchedule;
				} else {
					billingSchedule.PaymentType__c = 'Annual Installment';
					update billingSchedule;
				}
			} catch (Exception e) {
				exceptionThrown = true;
				errorMsg = e.getMessage();
			}
			Test.stopTest();
		}

		if (hasCustomPermission) {
			System.assertEquals(false, exceptionThrown, 'Exception should not be thrown.');
		} else {
			System.assertEquals(true, exceptionThrown, 'Exception should be thrown.');
			System.assertEquals(true, errorMsg.contains(BillingScheduleUtility.UPDATE_DELETE_NOT_ALLOWED));
		}
	}

	static User getDealsDeskUser() {
		if (BillingScheduleUtilityTest.dealsDeskUser == null) {
			List<User> testUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.DEAL_DESK_USER];
			if (testUsers.isEmpty()) {
				BillingScheduleUtilityTest.dealsDeskUser = TestUserFactory.createDealDeskUser();
				TestingUtility.assignPermissionSet(
					BillingScheduleUtilityTest.dealsDeskUser.Id,
					'DisableFlows'
				);
				TestingUtility.assignPermissionSet(
					BillingScheduleUtilityTest.dealsDeskUser.Id,
					'BillingScheduleConfigurator'
				);
			} else {
				BillingScheduleUtilityTest.dealsDeskUser = testUsers[0];
			}
		}
		return BillingScheduleUtilityTest.dealsDeskUser;
	}

	static User getAdminUser() {
		List<User> testUsers = [
			SELECT Id
			FROM User
			WHERE LastName = :TestUserFactory.TANIUM_ADMIN_USER
		];
		if (testUsers.isEmpty()) {
			User adminUser = TestUserFactory.createTaniumAdminUser(true);
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');
			TestingUtility.assignPermissionSet(adminUser.Id, 'BillingScheduleConfigurator');

			return adminUser;
		} else {
			return testUsers[0];
		}
	}
}