/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Coverage for ELV_ExitARRHelper - the Apex refactor of legacy price rules #16, #12 and #8.
 *
 * SeeAllData is required: the Nue managed QuoteTrigger throws a null-pointer on Quote insert
 * inside an isolated test context, so the suite exercises existing quote data instead of
 * building its own. All DML is rolled back when the test finishes.
 *
 * ELV_End_Date__c ("End Date Comp") is a read-only formula, so scenarios are driven by
 * setting Ruby__SubscriptionEndDate__c and letting the formula resolve.
 */
@IsTest(SeeAllData=true)
private class ELV_ExitARRHelperTest {
	/** A quote that has at least two lines with differing end dates. */
	private static Id findUsableQuoteId() {
		for (AggregateResult ar : [
			SELECT QuoteId qid, COUNT(Id) cnt
			FROM QuoteLineItem
			WHERE ELV_End_Date__c != NULL
			GROUP BY QuoteId
			HAVING COUNT(Id) > 2
			LIMIT 5
		]) {
			Id candidate = (Id) ar.get('qid');
			Integer distinctDates = [
				SELECT COUNT_DISTINCT(ELV_End_Date__c) d
				FROM QuoteLineItem
				WHERE QuoteId = :candidate
			][0].get('d') != null
				? (Integer) [
						SELECT COUNT_DISTINCT(ELV_End_Date__c) d
						FROM QuoteLineItem
						WHERE QuoteId = :candidate
					][0].get('d')
				: 0;
			if (distinctDates > 1) {
				return candidate;
			}
		}
		return null;
	}

	@IsTest
	static void stampsMaxEndDateAndFlagsOnlyMatchingLines() {
		Id quoteId = findUsableQuoteId();
		if (quoteId == null) {
			return;
		}

		Test.startTest();
		ELV_ExitARRHelper.refreshAndSave(quoteId);
		Test.stopTest();

		Quote saved = [SELECT ELV_Max_End_Date_Quote_Line__c FROM Quote WHERE Id = :quoteId];

		Date expectedMax = null;
		for (QuoteLineItem line : [
			SELECT ELV_End_Date__c FROM QuoteLineItem WHERE QuoteId = :quoteId AND ELV_End_Date__c != NULL
		]) {
			if (expectedMax == null || line.ELV_End_Date__c > expectedMax) {
				expectedMax = line.ELV_End_Date__c;
			}
		}
		System.assertEquals(expectedMax, saved.ELV_Max_End_Date_Quote_Line__c,
			'The quote carries the latest line end date (legacy #16).');

		Integer flaggedAwayFromMax = [
			SELECT COUNT() FROM QuoteLineItem
			WHERE QuoteId = :quoteId
			  AND ELV_Include_in_Exit_ARR__c = true
			  AND ELV_End_Date__c != :saved.ELV_Max_End_Date_Quote_Line__c
		];
		System.assertEquals(0, flaggedAwayFromMax,
			'Only lines at the max end date may be flagged (legacy #8 resets the rest).');

		Integer flaggedButExcluded = [
			SELECT COUNT() FROM QuoteLineItem
			WHERE QuoteId = :quoteId
			  AND ELV_Include_in_Exit_ARR__c = true
			  AND ELV_Exclude_from_ARR__c = true
		];
		System.assertEquals(0, flaggedButExcluded,
			'Lines excluded from ARR are never flagged.');
	}

	@IsTest
	static void resetsStaleTrueWhenLineNoLongerQualifies() {
		Id quoteId = findUsableQuoteId();
		if (quoteId == null) {
			return;
		}

		ELV_ExitARRHelper.refreshAndSave(quoteId);
		Quote q = [SELECT ELV_Max_End_Date_Quote_Line__c FROM Quote WHERE Id = :quoteId];

		List<QuoteLineItem> notAtMax = [
			SELECT Id FROM QuoteLineItem
			WHERE QuoteId = :quoteId
			  AND ELV_Exclude_from_ARR__c = false
			  AND ELV_End_Date__c != :q.ELV_Max_End_Date_Quote_Line__c
			LIMIT 1
		];
		if (notAtMax.isEmpty()) {
			return;
		}

		// Simulate the stale state that the false branch exists to correct.
		update new QuoteLineItem(Id = notAtMax[0].Id, ELV_Include_in_Exit_ARR__c = true);

		Test.startTest();
		ELV_ExitARRHelper.refreshAndSave(quoteId);
		Test.stopTest();

		QuoteLineItem after = [
			SELECT ELV_Include_in_Exit_ARR__c FROM QuoteLineItem WHERE Id = :notAtMax[0].Id
		];
		System.assertEquals(false, after.ELV_Include_in_Exit_ARR__c,
			'A stale true must be cleared or the roll-up overcounts.');
	}

	@IsTest
	static void secondPassMakesNoChanges() {
		Id quoteId = findUsableQuoteId();
		if (quoteId == null) {
			return;
		}

		ELV_ExitARRHelper.refreshAndSave(quoteId);

		Test.startTest();
		ELV_ExitARRHelper.ExitARRResult second = ELV_ExitARRHelper.evaluate(new Set<Id>{ quoteId });
		Test.stopTest();

		System.assertEquals(0, second.quotesToUpdate.size(), 'The quote is already correct.');
		System.assertEquals(0, second.linesToUpdate.size(), 'The lines are already correct.');
	}

	@IsTest
	static void reportsCountsForEvaluatedLines() {
		Id quoteId = findUsableQuoteId();
		if (quoteId == null) {
			return;
		}

		Integer totalLines = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId];

		Test.startTest();
		ELV_ExitARRHelper.ExitARRResult result = ELV_ExitARRHelper.evaluate(new Set<Id>{ quoteId });
		Test.stopTest();

		System.assertEquals(
			totalLines,
			result.includedCount + result.excludedCount + result.skippedExcludedFromARR,
			'Every line is either included, excluded, or skipped - never unaccounted for.'
		);
		System.assertNotEquals(null, result.maxEndDateByQuoteId.get(quoteId),
			'A quote with dated lines resolves a max end date.');
	}

	@IsTest
	static void flowEntryPointStamps() {
		Id quoteId = findUsableQuoteId();
		if (quoteId == null) {
			return;
		}

		Test.startTest();
		ELV_ExitARRHelper.refreshFromFlow(new List<Id>{ quoteId });
		Test.stopTest();

		Quote saved = [SELECT ELV_Max_End_Date_Quote_Line__c FROM Quote WHERE Id = :quoteId];
		System.assertNotEquals(null, saved.ELV_Max_End_Date_Quote_Line__c,
			'The invocable entry point performs the same stamp.');
	}

	@IsTest
	static void handlesEmptyAndNullInput() {
		Test.startTest();
		ELV_ExitARRHelper.ExitARRResult nullResult = ELV_ExitARRHelper.evaluate(null);
		ELV_ExitARRHelper.ExitARRResult emptyResult = ELV_ExitARRHelper.evaluate(new Set<Id>());
		ELV_ExitARRHelper.refreshFromFlow(null);
		ELV_ExitARRHelper.refreshFromFlow(new List<Id>());
		Test.stopTest();

		System.assertEquals(0, nullResult.linesToUpdate.size(), 'Null input is a no-op.');
		System.assertEquals(0, emptyResult.linesToUpdate.size(), 'Empty input is a no-op.');
	}

	@IsTest
	static void ignoresQuotesThatDoNotExist() {
		Test.startTest();
		ELV_ExitARRHelper.ExitARRResult result = ELV_ExitARRHelper.evaluate(
			new Set<Id>{ '0Q0000000000000AAA' }
		);
		Test.stopTest();

		System.assertEquals(0, result.quotesToUpdate.size(), 'An unknown quote is skipped safely.');
	}
}