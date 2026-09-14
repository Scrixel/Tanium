/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI-206 / ELV-DM-010 Layer 2 - the line-level Day 1 ARR start date stamp.
 *
 *            Layer 1 is the Quote cascade, Quote.ELV_Day_1_ARR_Start_Date__c, a formula
 *            evaluated top down with first match winning: override, renewal expiration
 *            date, renewal latest start date when the quote carries renewal lines, then
 *            the earliest ARR-eligible line start with an unfiltered minimum fallback.
 *
 *            This class carries that value onto each quote line as STORED data in
 *            ELV_Day_1_ARR_Start_Date_Stamp__c. A cross-object formula cannot be used as
 *            roll-up summary filter criteria; a stored field can. With the stamp in place
 *            Sales ARR can be expressed as SUM(line ARR) WHERE Include in Day 1 ARR, and
 *            ramp items stop double counting because only the ramp lines active on the
 *            Day 1 date qualify.
 *
 *            Ordering is forced and cannot be collapsed into a before-context stamp on the
 *            line: lines commit, then the Quote roll-ups recalculate, then the cascade
 *            produces the new date, and only then can the lines be stamped. Hence an
 *            after-update trigger on Quote.
 *
 *            Three guards, in order of importance:
 *              1. Change check - only quotes whose Day 1 date actually moved are processed.
 *                 This is what stops the loop: stamping lines changes Include in Day 1 ARR,
 *                 which changes the Sales ARR roll-up, which updates the Quote again - but
 *                 on that second pass the Day 1 date is unchanged, so nothing fires.
 *              2. Dirty check - only lines whose stamp differs are included in the DML. On
 *                 an 84 line renewal quote where one line moved, one row is updated.
 *              3. Re-entrancy flag - belt and braces for anything else in the same
 *                 transaction updating the Quote before the first pass settles.
 *
 *            The stamp is correct because the trigger ran, not because the platform
 *            guarantees it. ELV_Day_1_ARR_Start_Date_Drift__c makes staleness reportable.
 */
public with sharing class ELV_Day1ARRStampHelper {
	/** Guard 3. Static, so it lives for the transaction and no longer. */
	@TestVisible
	private static Boolean isRunning = false;

	/** Result of one pass, so callers and tests can assert without re-querying. */
	public class StampResult {
		public Map<Id, Date> targetByQuoteId = new Map<Id, Date>();
		public List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();
		public Integer linesEvaluated = 0;
		public Boolean skippedForReentrancy = false;
	}

	/**
	 * Trigger entry point. After update on Quote.
	 */
	public static StampResult stampChangedQuotes(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
		StampResult result = new StampResult();

		if (newQuotes == null || newQuotes.isEmpty()) {
			return result;
		}

		// Guard 1 - the change check. Everything downstream depends on this being narrow.
		Map<Id, Date> changed = getChangedDayOneDates(newQuotes, oldMap);
		if (changed.isEmpty()) {
			return result;
		}

		if (isRunning) {
			result.skippedForReentrancy = true;
			return result;
		}

		isRunning = true;
		try {
			result = evaluate(changed);
			if (!result.linesToUpdate.isEmpty()) {
				update result.linesToUpdate;
			}
		} finally {
			isRunning = false;
		}

		return result;
	}

	/**
	 * Computes the stamp updates for an explicit quote-to-date map. No DML, so tests and
	 * callers can inspect the decision without writing.
	 */
	public static StampResult evaluate(Map<Id, Date> targetByQuoteId) {
		StampResult result = new StampResult();

		if (targetByQuoteId == null || targetByQuoteId.isEmpty()) {
			return result;
		}

		result.targetByQuoteId = targetByQuoteId;

		for (QuoteLineItem line : [
			SELECT Id, QuoteId, ELV_Day_1_ARR_Start_Date_Stamp__c
			FROM QuoteLineItem
			WHERE QuoteId IN :targetByQuoteId.keySet()
		]) {
			result.linesEvaluated++;
			Date target = targetByQuoteId.get(line.QuoteId);

			// Guard 2 - the dirty check. Unchanged rows never enter the DML.
			if (line.ELV_Day_1_ARR_Start_Date_Stamp__c == target) {
				continue;
			}

			result.linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Day_1_ARR_Start_Date_Stamp__c = target)
			);
		}

		return result;
	}

	/**
	 * Re-stamps the given quotes unconditionally - the backfill and repair path, used for
	 * existing quotes that predate the trigger and for drift found by the detector field.
	 * The dirty check still applies, so a clean quote costs no DML.
	 */
	public static StampResult refreshAndSave(Set<Id> quoteIds) {
		StampResult result = new StampResult();

		if (quoteIds == null || quoteIds.isEmpty()) {
			return result;
		}

		Map<Id, Date> targetByQuoteId = new Map<Id, Date>();
		for (Quote quote : [
			SELECT Id, ELV_Day_1_ARR_Start_Date__c FROM Quote WHERE Id IN :quoteIds
		]) {
			targetByQuoteId.put(quote.Id, quote.ELV_Day_1_ARR_Start_Date__c);
		}

		if (targetByQuoteId.isEmpty()) {
			return result;
		}

		Boolean wasRunning = isRunning;
		isRunning = true;
		try {
			result = evaluate(targetByQuoteId);
			if (!result.linesToUpdate.isEmpty()) {
				update result.linesToUpdate;
			}
		} finally {
			isRunning = wasRunning;
		}

		return result;
	}

	/** Convenience overload for a single quote. */
	public static StampResult refreshAndSave(Id quoteId) {
		return refreshAndSave(new Set<Id>{ quoteId });
	}

	/** Flow / button entry point, for backfill and for clearing reported drift. */
	@InvocableMethod(
		label='Refresh Day 1 ARR Start Date Stamp'
		description='Copies the quote Day 1 ARR start date onto every quote line that does not already carry it.'
	)
	public static void refreshFromFlow(List<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		refreshAndSave(new Set<Id>(quoteIds));
	}

	/**
	 * Guard 1 in isolation, so the loop-stopping condition is unit testable without DML.
	 * A quote with no old record (should not occur on after update) is treated as changed.
	 */
	@TestVisible
	private static Map<Id, Date> getChangedDayOneDates(
		List<Quote> newQuotes,
		Map<Id, Quote> oldMap
	) {
		Map<Id, Date> changed = new Map<Id, Date>();

		for (Quote quote : newQuotes) {
			Quote oldQuote = oldMap == null ? null : oldMap.get(quote.Id);

			if (
				oldQuote == null ||
				quote.ELV_Day_1_ARR_Start_Date__c != oldQuote.ELV_Day_1_ARR_Start_Date__c
			) {
				changed.put(quote.Id, quote.ELV_Day_1_ARR_Start_Date__c);
			}
		}

		return changed;
	}
}