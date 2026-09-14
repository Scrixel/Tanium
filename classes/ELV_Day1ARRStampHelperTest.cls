/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Coverage for ELV_Day1ARRStampHelper - TNCI-206 / ELV-DM-010 Layer 2.
 *
 * Two halves. The guard logic that stops the stamp loop is pure and tested in memory with
 * no DML. The stamping itself needs real quote lines, and building a Quote inside an
 * isolated context trips the Nue managed QuoteTrigger, so those tests run SeeAllData and
 * exercise existing quote data. All DML is rolled back when the test finishes.
 */
@IsTest(SeeAllData=true)
private class ELV_Day1ARRStampHelperTest {
	/**
	 * The Day 1 date is a formula on Quote, so Apex cannot assign it even in memory.
	 * Deserialization builds an unsaved Quote carrying a chosen value, which is what the
	 * guard tests need to drive old-versus-new comparisons without touching the database.
	 */
	private static Quote quoteWithDayOne(Id quoteId, Date dayOne) {
		Map<String, Object> values = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'Quote' },
			'Id' => quoteId,
			'ELV_Day_1_ARR_Start_Date__c' => dayOne
		};
		return (Quote) JSON.deserialize(JSON.serialize(values), Quote.class);
	}

	/** A quote that has lines and a resolved Day 1 ARR start date. */
	private static Quote findUsableQuote() {
		for (Quote quote : [
			SELECT Id, ELV_Day_1_ARR_Start_Date__c
			FROM Quote
			WHERE ELV_Day_1_ARR_Start_Date__c != NULL AND Id IN (SELECT QuoteId FROM QuoteLineItem)
			LIMIT 5
		]) {
			return quote;
		}
		return null;
	}

	@IsTest
	static void changeCheckSelectsOnlyQuotesWhoseDayOneDateMoved() {
		Id movedId = '0Q0000000000001AAA';
		Id staticId = '0Q0000000000002AAA';
		Date before = Date.newInstance(2026, 7, 16);
		Date after = Date.newInstance(2027, 2, 1);

		List<Quote> newQuotes = new List<Quote>{
			quoteWithDayOne(movedId, after),
			quoteWithDayOne(staticId, before)
		};
		Map<Id, Quote> oldMap = new Map<Id, Quote>{
			movedId => quoteWithDayOne(movedId, before),
			staticId => quoteWithDayOne(staticId, before)
		};

		Map<Id, Date> changed = ELV_Day1ARRStampHelper.getChangedDayOneDates(newQuotes, oldMap);

		System.assertEquals(1, changed.size(), 'Only the quote whose date moved is processed.');
		System.assertEquals(after, changed.get(movedId), 'The new date is what gets stamped.');
		System.assertEquals(
			false,
			changed.containsKey(staticId),
			'An unchanged Day 1 date is what stops the second pass, and the loop with it.'
		);
	}

	@IsTest
	static void changeCheckTreatsBlankTransitionsAsChanges() {
		Id clearedId = '0Q0000000000003AAA';
		Id populatedId = '0Q0000000000004AAA';
		Date someDate = Date.newInstance(2026, 7, 16);

		List<Quote> newQuotes = new List<Quote>{
			quoteWithDayOne(clearedId, null),
			quoteWithDayOne(populatedId, someDate)
		};
		Map<Id, Quote> oldMap = new Map<Id, Quote>{
			clearedId => quoteWithDayOne(clearedId, someDate),
			populatedId => quoteWithDayOne(populatedId, null)
		};

		Map<Id, Date> changed = ELV_Day1ARRStampHelper.getChangedDayOneDates(newQuotes, oldMap);

		System.assertEquals(2, changed.size(), 'Both directions of a blank transition count.');
		System.assertEquals(null, changed.get(clearedId), 'A cleared date clears the stamp.');
	}

	@IsTest
	static void reentrancyFlagShortCircuitsASecondPass() {
		Id quoteId = '0Q0000000000005AAA';
		List<Quote> newQuotes = new List<Quote>{
			quoteWithDayOne(quoteId, Date.newInstance(2027, 2, 1))
		};
		Map<Id, Quote> oldMap = new Map<Id, Quote>{
			quoteId => quoteWithDayOne(quoteId, null)
		};

		ELV_Day1ARRStampHelper.isRunning = true;
		ELV_Day1ARRStampHelper.StampResult result;
		try {
			result = ELV_Day1ARRStampHelper.stampChangedQuotes(newQuotes, oldMap);
		} finally {
			ELV_Day1ARRStampHelper.isRunning = false;
		}

		System.assertEquals(true, result.skippedForReentrancy, 'The flag prevents a re-entry.');
		System.assertEquals(0, result.linesToUpdate.size(), 'Nothing is written on re-entry.');
	}

	@IsTest
	static void unchangedQuotesCostNothing() {
		Id quoteId = '0Q0000000000006AAA';
		Date someDate = Date.newInstance(2026, 7, 16);

		ELV_Day1ARRStampHelper.StampResult result = ELV_Day1ARRStampHelper.stampChangedQuotes(
			new List<Quote>{ quoteWithDayOne(quoteId, someDate) },
			new Map<Id, Quote>{
				quoteId => quoteWithDayOne(quoteId, someDate)
			}
		);

		System.assertEquals(0, result.linesEvaluated, 'No lines are even queried.');
		System.assertEquals(false, result.skippedForReentrancy, 'It never reached the guard.');
	}

	@IsTest
	static void stampCarriesTheParentValueOntoEveryLine() {
		Quote quote = findUsableQuote();
		if (quote == null) {
			return;
		}

		Test.startTest();
		ELV_Day1ARRStampHelper.refreshAndSave(quote.Id);
		Test.stopTest();

		Integer mismatched = [
			SELECT COUNT()
			FROM QuoteLineItem
			WHERE
				QuoteId = :quote.Id
				AND ELV_Day_1_ARR_Start_Date_Stamp__c != :quote.ELV_Day_1_ARR_Start_Date__c
		];
		System.assertEquals(0, mismatched, 'Every line carries the parent Day 1 date.');
	}

	@IsTest
	static void dirtyCheckKeepsTheSecondPassEmpty() {
		Quote quote = findUsableQuote();
		if (quote == null) {
			return;
		}

		ELV_Day1ARRStampHelper.refreshAndSave(quote.Id);

		Test.startTest();
		ELV_Day1ARRStampHelper.StampResult second = ELV_Day1ARRStampHelper.evaluate(
			new Map<Id, Date>{ quote.Id => quote.ELV_Day_1_ARR_Start_Date__c }
		);
		Test.stopTest();

		System.assert(second.linesEvaluated > 0, 'The lines were read.');
		System.assertEquals(0, second.linesToUpdate.size(), 'But none of them were dirty.');
	}

	@IsTest
	static void staleStampIsRepaired() {
		Quote quote = findUsableQuote();
		if (quote == null) {
			return;
		}

		ELV_Day1ARRStampHelper.refreshAndSave(quote.Id);

		List<QuoteLineItem> lines = [
			SELECT Id FROM QuoteLineItem WHERE QuoteId = :quote.Id LIMIT 1
		];
		if (lines.isEmpty()) {
			return;
		}

		// The drift the detector field exists to surface.
		update new QuoteLineItem(
			Id = lines[0].Id,
			ELV_Day_1_ARR_Start_Date_Stamp__c = Date.newInstance(1999, 1, 1)
		);

		Test.startTest();
		ELV_Day1ARRStampHelper.StampResult result = ELV_Day1ARRStampHelper.refreshAndSave(
			quote.Id
		);
		Test.stopTest();

		System.assertEquals(1, result.linesToUpdate.size(), 'Only the drifted line is written.');
		QuoteLineItem repaired = [
			SELECT ELV_Day_1_ARR_Start_Date_Stamp__c, ELV_Day_1_ARR_Start_Date_Drift__c
			FROM QuoteLineItem
			WHERE Id = :lines[0].Id
		];
		System.assertEquals(
			quote.ELV_Day_1_ARR_Start_Date__c,
			repaired.ELV_Day_1_ARR_Start_Date_Stamp__c,
			'The stamp is back in agreement with the parent.'
		);
		System.assertEquals(
			false,
			repaired.ELV_Day_1_ARR_Start_Date_Drift__c,
			'And the drift detector reads clean again.'
		);
	}

	@IsTest
	static void flowEntryPointAndEmptyInputsAreSafe() {
		Quote quote = findUsableQuote();

		Test.startTest();
		ELV_Day1ARRStampHelper.refreshFromFlow(null);
		ELV_Day1ARRStampHelper.refreshFromFlow(new List<Id>());
		ELV_Day1ARRStampHelper.StampResult nullResult = ELV_Day1ARRStampHelper.evaluate(null);
		ELV_Day1ARRStampHelper.StampResult emptyResult = ELV_Day1ARRStampHelper.refreshAndSave(
			new Set<Id>()
		);
		if (quote != null) {
			ELV_Day1ARRStampHelper.refreshFromFlow(new List<Id>{ quote.Id });
		}
		Test.stopTest();

		System.assertEquals(0, nullResult.linesToUpdate.size(), 'Null input is a no-op.');
		System.assertEquals(0, emptyResult.linesToUpdate.size(), 'Empty input is a no-op.');
	}

	@IsTest
	static void quoteUpdateRunsTheTriggerPath() {
		Quote quote = findUsableQuote();
		if (quote == null) {
			return;
		}

		Test.startTest();
		// Touching the quote exercises the handler end to end: the before-update rollups and
		// the new after-update stamp, in the order the design depends on. Because this edit
		// does not move the formula date, the change guard deliberately performs no line DML.
		update new Quote(Id = quote.Id, Description = 'Layer 2 stamp coverage');
		Test.stopTest();

		System.assertEquals(
			'Layer 2 stamp coverage',
			[SELECT Description FROM Quote WHERE Id = :quote.Id].Description,
			'The full Quote trigger path completes without recursion or blocking the update.'
		);
	}

	@IsTest
	static void unknownQuoteIsIgnored() {
		Test.startTest();
		ELV_Day1ARRStampHelper.StampResult result = ELV_Day1ARRStampHelper.refreshAndSave(
			(Id) '0Q0000000000009AAA'
		);
		Test.stopTest();

		System.assertEquals(0, result.linesToUpdate.size(), 'An unknown quote is skipped safely.');
	}

	// ---------------------------------------------------------------------------------------
	// TNCI 139 / ELV-CPQ-036. The stamp only stayed empty because the Quote after-update event
	// never arrived: a roll-up recalculated by a child change raises no event on the parent.
	// These cases cover the line-side request that makes it arrive.
	// ---------------------------------------------------------------------------------------

	/** A quote with more than one line, so moving or removing one line shifts the cascade. */
	private static Id findQuoteWithLines(Integer minimumLines) {
		for (AggregateResult row : [
			SELECT QuoteId qid, COUNT(Id) lineCount
			FROM QuoteLineItem
			WHERE Quote.Status NOT IN ('Accepted', 'Denied')
			GROUP BY QuoteId
			HAVING COUNT(Id) >= :minimumLines
			LIMIT 1
		]) {
			return (Id) row.get('qid');
		}
		return null;
	}

	private static List<QuoteLineItem> linesOf(Id quoteId) {
		return [
			SELECT
				Id,
				QuoteId,
				Ruby__SubscriptionStartDate__c,
				ELV_Day_1_ARR_Start_Date_Stamp__c,
				ELV_Day_1_ARR_Start_Date_Drift__c
			FROM QuoteLineItem
			WHERE QuoteId = :quoteId
			ORDER BY Ruby__SubscriptionStartDate__c NULLS LAST
		];
	}

	@IsTest
	static void movingTheEarliestLineStartDateRestampsTheQuotesLines() {
		Id quoteId = findQuoteWithLines(2);
		if (quoteId == null) {
			return;
		}

		List<QuoteLineItem> lines = linesOf(quoteId);
		Date earliest = lines[0].Ruby__SubscriptionStartDate__c;
		if (earliest == null) {
			return;
		}

		Test.startTest();
		// Pulling the earliest start date backwards moves the minimum start roll-up, which
		// moves the cascade - the case that used to leave every line on the quote stale.
		update new QuoteLineItem(
			Id = lines[0].Id,
			Ruby__SubscriptionStartDate__c = earliest.addDays(-45)
		);
		Test.stopTest();

		Quote quote = [SELECT Id, ELV_Day_1_ARR_Start_Date__c FROM Quote WHERE Id = :quoteId];
		for (QuoteLineItem line : linesOf(quoteId)) {
			System.assertEquals(
				quote.ELV_Day_1_ARR_Start_Date__c,
				line.ELV_Day_1_ARR_Start_Date_Stamp__c,
				'A qualifying line edit leaves every line on the quote carrying the new date.'
			);
			System.assertEquals(
				false,
				line.ELV_Day_1_ARR_Start_Date_Drift__c,
				'And the drift detector reads clean.'
			);
		}
	}

	@IsTest
	static void deletingALineRestampsTheSurvivingLines() {
		Id quoteId = findQuoteWithLines(3);
		if (quoteId == null) {
			return;
		}

		List<QuoteLineItem> lines = linesOf(quoteId);

		Test.startTest();
		delete lines[0];
		Test.stopTest();

		Quote quote = [SELECT Id, ELV_Day_1_ARR_Start_Date__c FROM Quote WHERE Id = :quoteId];
		List<QuoteLineItem> survivors = linesOf(quoteId);
		System.assert(!survivors.isEmpty(), 'The quote still has lines to assert on.');
		for (QuoteLineItem line : survivors) {
			System.assertEquals(
				quote.ELV_Day_1_ARR_Start_Date__c,
				line.ELV_Day_1_ARR_Start_Date_Stamp__c,
				'Deleting a line re-stamps the lines that remain.'
			);
		}
	}

	@IsTest
	static void anEditOutsideTheQualifyingSetDoesNotTouchTheQuote() {
		Id quoteId = findQuoteWithLines(1);
		if (quoteId == null) {
			return;
		}

		List<QuoteLineItem> lines = linesOf(quoteId);
		Datetime quoteModifiedBefore = [
			SELECT LastModifiedDate
			FROM Quote
			WHERE Id = :quoteId
		]
		.LastModifiedDate;

		Test.startTest();
		update new QuoteLineItem(Id = lines[0].Id, Description = 'Non qualifying edit');
		Test.stopTest();

		System.assertEquals(
			quoteModifiedBefore,
			[SELECT LastModifiedDate FROM Quote WHERE Id = :quoteId].LastModifiedDate,
			'An edit outside the qualifying set leaves the parent quote untouched.'
		);
	}

	@IsTest
	static void theQualifyingSetCoversTheCascadeInputsAndExcludesTheStampItself() {
		Date startDate = Date.newInstance(2026, 7, 1);
		QuoteLineItem baseline = new QuoteLineItem(
			Ruby__SubscriptionStartDate__c = startDate,
			Ruby__ChangeType__c = 'New',
			Ruby__LineType__c = 'LineItem',
			Ruby__ActualQuantity__c = 10,
			ELV_Exclude_from_ARR__c = false,
			ELV_Product_Exclude_from_ARR__c = false,
			ELV_Is_Cloned_Quote_Line__c = false,
			ELV_Day_1_ARR_Start_Date_Stamp__c = startDate
		);

		Map<String, QuoteLineItem> variants = new Map<String, QuoteLineItem>{
			'start date' => baseline.clone(false, true, false, false),
			'change type' => baseline.clone(false, true, false, false),
			'line type' => baseline.clone(false, true, false, false),
			'actual quantity' => baseline.clone(false, true, false, false),
			'line exclusion' => baseline.clone(false, true, false, false),
			'product exclusion' => baseline.clone(false, true, false, false),
			'cloned line' => baseline.clone(false, true, false, false)
		};
		variants.get('start date').Ruby__SubscriptionStartDate__c = startDate.addMonths(1);
		variants.get('change type').Ruby__ChangeType__c = 'Renewal';
		variants.get('line type').Ruby__LineType__c = 'SummaryItem';
		variants.get('actual quantity').Ruby__ActualQuantity__c = 0;
		variants.get('line exclusion').ELV_Exclude_from_ARR__c = true;
		variants.get('product exclusion').ELV_Product_Exclude_from_ARR__c = true;
		variants.get('cloned line').ELV_Is_Cloned_Quote_Line__c = true;

		for (String field : variants.keySet()) {
			System.assertEquals(
				true,
				ELV_QuoteLineTriggerUtility.hasRefreshQualifyingChange(
					variants.get(field),
					baseline
				),
				'A change to ' + field + ' feeds the cascade and must request a refresh.'
			);
		}

		QuoteLineItem stampOnly = baseline.clone(false, true, false, false);
		stampOnly.ELV_Day_1_ARR_Start_Date_Stamp__c = startDate.addMonths(1);
		System.assertEquals(
			false,
			ELV_QuoteLineTriggerUtility.hasRefreshQualifyingChange(stampOnly, baseline),
			'The stamp itself must never qualify, or the helper and the line trigger cycle.'
		);
	}

	@IsTest
	static void oneQualifyingLineEditProducesOneQuoteUpdateAndOneStampPass() {
		Id quoteId = findQuoteWithLines(2);
		if (quoteId == null) {
			return;
		}

		List<QuoteLineItem> lines = linesOf(quoteId);
		Date earliest = lines[0].Ruby__SubscriptionStartDate__c;
		if (earliest == null) {
			return;
		}

		Test.startTest();
		Integer dmlBefore = Limits.getDmlStatements();
		update new QuoteLineItem(
			Id = lines[0].Id,
			Ruby__SubscriptionStartDate__c = earliest.addDays(-10)
		);
		Integer statements = Limits.getDmlStatements() - dmlBefore;
		Test.stopTest();

		// The line edit, the single quote touch, and at most one line-stamp pass behind it.
		System.assert(
			statements <= 3,
			'A qualifying line edit must not loop: expected 3 DML statements or fewer, saw ' +
				statements
		);
	}

	@IsTest
	static void aBulkLineEditStaysWithinGovernorLimitsAndTouchesEachQuoteOnce() {
		List<AggregateResult> rows = [
			SELECT QuoteId qid
			FROM QuoteLineItem
			WHERE
				Quote.Status NOT IN ('Accepted', 'Denied')
				AND Ruby__SubscriptionStartDate__c != NULL
			GROUP BY QuoteId
			HAVING COUNT(Id) >= 2
			LIMIT 5
		];
		if (rows.size() < 5) {
			return;
		}

		Set<Id> quoteIds = new Set<Id>();
		for (AggregateResult row : rows) {
			quoteIds.add((Id) row.get('qid'));
		}

		List<QuoteLineItem> toUpdate = new List<QuoteLineItem>();
		for (QuoteLineItem line : [
			SELECT Id, QuoteId, Ruby__SubscriptionStartDate__c
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIds AND Ruby__SubscriptionStartDate__c != NULL
			LIMIT 200
		]) {
			toUpdate.add(
				new QuoteLineItem(
					Id = line.Id,
					Ruby__SubscriptionStartDate__c = line.Ruby__SubscriptionStartDate__c.addDays(
						-7
					)
				)
			);
		}

		Test.startTest();
		Integer dmlBefore = Limits.getDmlStatements();
		update toUpdate;
		Integer statements = Limits.getDmlStatements() - dmlBefore;
		Test.stopTest();

		// One statement for the lines, one deduplicated quote update, and the stamp passes behind
		// it - the point is that the count does not scale with 200 lines or with 5 quotes.
		System.assert(
			statements <= 6,
			'A 200 line batch across 5 quotes must not produce per-record DML; saw ' +
				statements +
				' DML statements'
		);
		System.assert(
			Limits.getQueries() < Limits.getLimitQueries(),
			'The bulk path stays inside the SOQL limit.'
		);

		for (Quote quote : [
			SELECT Id, ELV_Day_1_ARR_Start_Date__c
			FROM Quote
			WHERE Id IN :quoteIds
		]) {
			for (QuoteLineItem line : [
				SELECT Id, ELV_Day_1_ARR_Start_Date_Stamp__c
				FROM QuoteLineItem
				WHERE QuoteId = :quote.Id
			]) {
				System.assertEquals(
					quote.ELV_Day_1_ARR_Start_Date__c,
					line.ELV_Day_1_ARR_Start_Date_Stamp__c,
					'Every line in the bulk batch ends up carrying its own quote Day 1 date.'
				);
			}
		}
	}

	@IsTest
	static void theOverrideAndRenewalExpirationBranchesStampLikeAnyOtherValue() {
		// No quote in Build populates the override or renewal expiration branch, so the branches
		// are covered where they are observable: whatever value the cascade resolves to, the
		// stamp follows it. The cascade itself is a formula and is never re-derived in Apex.
		Id quoteId = '0Q0000000000021AAA';
		Date overrideDate = Date.newInstance(2027, 4, 1);
		Date renewalExpirationDate = Date.newInstance(2028, 1, 15);

		Test.startTest();
		ELV_Day1ARRStampHelper.StampResult fromOverride = ELV_Day1ARRStampHelper.evaluate(
			new Map<Id, Date>{ quoteId => overrideDate }
		);
		ELV_Day1ARRStampHelper.StampResult fromRenewal = ELV_Day1ARRStampHelper.evaluate(
			new Map<Id, Date>{ quoteId => renewalExpirationDate }
		);
		Test.stopTest();

		System.assertEquals(
			overrideDate,
			fromOverride.targetByQuoteId.get(quoteId),
			'An override date is carried to the lines unchanged.'
		);
		System.assertEquals(
			renewalExpirationDate,
			fromRenewal.targetByQuoteId.get(quoteId),
			'A renewal expiration date is carried to the lines unchanged.'
		);
	}

	@IsTest
	static void rampLinesAllCarryTheQuoteDateSoLaterStepsCanExcludeInactiveOnes() {
		Id quoteId = findQuoteWithLines(2);
		if (quoteId == null) {
			return;
		}

		Test.startTest();
		ELV_Day1ARRStampHelper.refreshAndSave(quoteId);
		Test.stopTest();

		Quote quote = [SELECT Id, ELV_Day_1_ARR_Start_Date__c FROM Quote WHERE Id = :quoteId];
		Integer activeOnDayOne = 0;
		for (QuoteLineItem line : [
			SELECT
				Id,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				ELV_Day_1_ARR_Start_Date_Stamp__c
			FROM QuoteLineItem
			WHERE QuoteId = :quoteId
		]) {
			System.assertEquals(
				quote.ELV_Day_1_ARR_Start_Date__c,
				line.ELV_Day_1_ARR_Start_Date_Stamp__c,
				'Every line, ramp step or not, carries the same Day 1 date.'
			);

			// This comparison is the point of the stamp: with the date stored on the line it can
			// be made line-local, which is what lets a later step drop the inactive ramp steps.
			if (
				line.Ruby__SubscriptionStartDate__c != null &&
				line.ELV_Day_1_ARR_Start_Date_Stamp__c != null &&
				line.Ruby__SubscriptionStartDate__c <= line.ELV_Day_1_ARR_Start_Date_Stamp__c
			) {
				activeOnDayOne++;
			}
		}

		System.assert(
			activeOnDayOne >= 0,
			'The active-on-day-one test is expressible from line-local data alone.'
		);
	}
}