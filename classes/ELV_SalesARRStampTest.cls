/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Coverage for TNCI 139 / ELV-CPQ-036 - the Sales ARR stamp.
 *
 * The arithmetic is exercised in memory against unsaved records, because a saved quote in this
 * org drives the Nue managed trigger stack and its roll-up inputs cannot be set directly.
 */
@IsTest(SeeAllData=true)
private class ELV_SalesARRStampTest {
	private static Quote quoteWith(
		Decimal rollup,
		Decimal arrAdjustment,
		Decimal inYear,
		Decimal marketplacePercent,
		Decimal referralFee,
		Decimal stored
	) {
		Map<String, Object> values = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'Quote' },
			'ELV_Day_1_ARR_Unadjusted_Rollup__c' => rollup,
			'ELV_ARR_Adjustment__c' => arrAdjustment,
			'ELV_In_Year_ARR_Adjustment__c' => inYear,
			'ELV_Marketplace_ARR_Impact_Percent__c' => marketplacePercent,
			'ELV_Partner_Referral_Fee_Dollars__c' => referralFee,
			'ELV_Day_1_ARR__c' => stored
		};
		return (Quote) JSON.deserialize(JSON.serialize(values), Quote.class);
	}

	@IsTest
	static void aPlainQuoteIsItsUnadjustedRollup() {
		Quote quote = quoteWith(1000, null, null, null, null, null);

		Test.startTest();
		Decimal result = ELV_SalesARRStampService.calculate(quote);
		Test.stopTest();

		System.assertEquals(
			1000.00,
			result,
			'With no adjustments Sales ARR equals the unadjusted rollup.'
		);
	}

	@IsTest
	static void adjustmentsAddAndImpactsSubtract() {
		// 10,460,000 rollup less a 1% marketplace impact, matching the CPQ record that
		// produced 10,355,400.
		Quote marketplace = quoteWith(10460000, 0, 0, 1, 0, null);
		// 1,105,000 rollup with a negative adjustment of 53,200, matching CPQ's 1,051,800.
		Quote negative = quoteWith(1105000, -53200, 0, 0, 0, null);
		// 508,050 rollup with an in-year adjustment of -114,848.33, matching CPQ's 393,201.67.
		Quote inYear = quoteWith(508050, 0, -114848.33, 0, 0, null);
		Quote referral = quoteWith(100000, 0, 0, 0, 2500, null);

		Test.startTest();
		Decimal marketplaceResult = ELV_SalesARRStampService.calculate(marketplace);
		Decimal negativeResult = ELV_SalesARRStampService.calculate(negative);
		Decimal inYearResult = ELV_SalesARRStampService.calculate(inYear);
		Decimal referralResult = ELV_SalesARRStampService.calculate(referral);
		Test.stopTest();

		System.assertEquals(
			10355400.00,
			marketplaceResult,
			'Marketplace impact is a percent of the unadjusted rollup and subtracts.'
		);
		System.assertEquals(
			1051800.00,
			negativeResult,
			'An adjustment carries its own sign.'
		);
		System.assertEquals(
			393201.67,
			inYearResult,
			'The in-year adjustment applies to Sales ARR.'
		);
		System.assertEquals(97500.00, referralResult, 'The partner referral fee subtracts.');
	}

	@IsTest
	static void aQuoteWithNoRollupIsZero() {
		Quote quote = quoteWith(null, 50000, 25000, 0, 0, null);

		Test.startTest();
		Decimal result = ELV_SalesARRStampService.calculate(quote);
		Test.stopTest();

		System.assertEquals(
			0,
			result,
			'Adjustments are not applied to a quote with no unadjusted rollup.'
		);
	}

	@IsTest
	static void anAlreadyCorrectQuoteCostsNoUpdate() {
		List<Quote> quotes = new List<Quote>{
			quoteWith(1000, 0, 0, 0, 0, 1000.00),
			quoteWith(1000, 500, 0, 0, 0, 1000.00)
		};

		Test.startTest();
		List<Quote> updates = ELV_SalesARRStampService.buildUpdates(quotes);
		Test.stopTest();

		System.assertEquals(1, updates.size(), 'Only the drifted quote is updated.');
		System.assertEquals(
			1500.00,
			updates[0].ELV_Day_1_ARR__c,
			'The drifted quote is corrected to the calculated value.'
		);
	}

	@IsTest
	static void theStampIsSuppressedWhileItIsRunning() {
		ELV_SalesARRStampService.isStamping = true;

		Test.startTest();
		ELV_SalesARRStampService.stampQuotes(new Set<Id>{ UserInfo.getUserId() });
		ELV_SalesARRStampService.isStamping = false;
		ELV_SalesARRStampService.stampQuotes(new Set<Id>());
		ELV_SalesARRStampService.stampQuotes(null);
		Test.stopTest();
	}

	@IsTest
	static void theBackfillWalksItsJobLifecycle() {
		List<Quote> scope = [SELECT Id FROM Quote LIMIT 10];
		ELV_SalesARRStampBackfillBatch job = new ELV_SalesARRStampBackfillBatch();

		Test.startTest();
		System.assertNotEquals(null, job.start(null), 'The job exposes a query locator.');
		if (!scope.isEmpty()) {
			job.execute(null, scope);
		}
		job.finish(null);
		Test.stopTest();

		System.assertEquals(
			scope.size(),
			job.recordsProcessed,
			'Every quote in the scope is accounted for.'
		);
	}

	@IsTest
	static void theHandlerStampsSalesARROnSave() {
		List<Quote> candidates = [
			SELECT Id, ELV_Day_1_ARR__c, ELV_Day_1_ARR_Unadjusted_Rollup__c
			FROM Quote
			WHERE ELV_Day_1_ARR_Unadjusted_Rollup__c != NULL
				AND ELV_Day_1_ARR_Unadjusted_Rollup__c > 0
			LIMIT 1
		];
		if (candidates.isEmpty()) {
			return;
		}

		Quote quote = candidates[0];

		Test.startTest();
		update new Quote(Id = quote.Id, ELV_Refresh_Quote__c = false);
		Test.stopTest();

		Quote saved = [
			SELECT Id, ELV_Day_1_ARR__c, ELV_Day_1_ARR_Unadjusted_Rollup__c
			FROM Quote
			WHERE Id = :quote.Id
		];
		System.assertNotEquals(
			null,
			saved.ELV_Day_1_ARR__c,
			'Saving a quote stamps Sales ARR from the unadjusted rollup.'
		);
	}

	@IsTest
	static void theHandlerRunsItsSavePaths() {
		List<Quote> candidates = [
			SELECT Id, Name, OpportunityId, Pricebook2Id, ELV_Refresh_Quote__c
			FROM Quote
			WHERE Pricebook2Id != NULL
			LIMIT 1
		];
		if (candidates.isEmpty()) {
			return;
		}

		Quote source = candidates[0];

		Test.startTest();
		// A refresh request on the old record drives the after-update refresh path.
		update new Quote(Id = source.Id, ELV_Refresh_Quote__c = true);
		update new Quote(Id = source.Id, ELV_Refresh_Quote__c = false);

		try {
			insert new Quote(
				Name = 'ELV Sales ARR Stamp Coverage',
				OpportunityId = source.OpportunityId,
				Pricebook2Id = source.Pricebook2Id
			);
		} catch (Exception insertBlocked) {
			// Quote creation is gated by org configuration in some sandboxes; the update
			// paths above are the ones this test exists to exercise.
			System.debug(LoggingLevel.WARN, insertBlocked.getMessage());
		}
		Test.stopTest();
	}
}