/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Replaces legacy price rules #16, #12 and #8 as a single ordered Apex stamp.
 *
 *            Legacy behaviour being refactored:
 *              #16 Set Max End Date ARR
 *                  stamps Quote.ELV_Max_End_Date_Quote_Line__c with the latest line end date.
 *              #12 Set Include in Exit ARR Sum Field if True
 *                  ELV_Exclude_from_ARR__c = false AND ELV_End_Date__c  = max end date
 *                  -> ELV_Include_in_Exit_ARR__c = true
 *              #8  Set Include in Exit ARR Sum Field if False
 *                  ELV_Exclude_from_ARR__c = false AND ELV_End_Date__c != max end date
 *                  -> ELV_Include_in_Exit_ARR__c = false
 *
 *            ELV_Include_in_Exit_ARR__c must be a STORED checkbox, not a formula, because
 *            Quote roll-up summaries cannot summarise a formula and a line-level formula
 *            cannot see a cross-line aggregate (the max end date).
 *
 *            Ordering is enforced in one pass: the max end date is computed for every quote
 *            before any line is evaluated, so no line is ever compared to a stale value.
 *
 *            Lines with ELV_Exclude_from_ARR__c = true are deliberately left untouched,
 *            matching the legacy gate - they are neither set true nor reset to false.
 *
 *            ELV_End_Date__c ("End Date Comp") is a formula Date and is read-only. It is
 *            only ever compared here, never written.
 */
public with sharing class ELV_ExitARRHelper {
	/** Result of one evaluation pass, so callers and tests can assert without re-querying. */
	public class ExitARRResult {
		public Map<Id, Date> maxEndDateByQuoteId = new Map<Id, Date>();
		public List<Quote> quotesToUpdate = new List<Quote>();
		public List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();
		public Integer includedCount = 0;
		public Integer excludedCount = 0;
		public Integer skippedExcludedFromARR = 0;
	}

	/**
	 * Computes the max line end date per quote and the resulting Include in Exit ARR flag
	 * for every line. Performs no DML. Only records whose value actually changes are
	 * returned, so repeated runs converge and do not churn rows.
	 */
	public static ExitARRResult evaluate(Set<Id> quoteIds) {
		ExitARRResult result = new ExitARRResult();

		if (quoteIds == null || quoteIds.isEmpty()) {
			return result;
		}

		List<QuoteLineItem> lines = [
			SELECT Id, QuoteId, ELV_End_Date__c, ELV_Exclude_from_ARR__c, ELV_Include_in_Exit_ARR__c
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIds
			ORDER BY QuoteId
		];

		// Pass 1 - establish the aggregate for every quote before judging any line.
		// Legacy rule #16 considered all lines, including those excluded from ARR.
		for (QuoteLineItem line : lines) {
			if (line.ELV_End_Date__c == null) {
				continue;
			}
			Date current = result.maxEndDateByQuoteId.get(line.QuoteId);
			if (current == null || line.ELV_End_Date__c > current) {
				result.maxEndDateByQuoteId.put(line.QuoteId, line.ELV_End_Date__c);
			}
		}

		// Sparse Quote records - Id plus the one owned field. A full-record update fails
		// with "fields being inaccessible on Sobject Quote" on this org.
		Map<Id, Quote> existingQuotes = new Map<Id, Quote>(
			[SELECT Id, ELV_Max_End_Date_Quote_Line__c FROM Quote WHERE Id IN :quoteIds]
		);

		for (Id quoteId : quoteIds) {
			Quote existing = existingQuotes.get(quoteId);
			if (existing == null) {
				continue;
			}
			Date computed = result.maxEndDateByQuoteId.get(quoteId);
			if (existing.ELV_Max_End_Date_Quote_Line__c != computed) {
				result.quotesToUpdate.add(new Quote(Id = quoteId, ELV_Max_End_Date_Quote_Line__c = computed));
			}
		}

		// Pass 2 - both branches always write, so a line that stops qualifying is reset.
		// Without the false branch a stale true survives and the roll-up overcounts.
		for (QuoteLineItem line : lines) {
			if (line.ELV_Exclude_from_ARR__c == true) {
				result.skippedExcludedFromARR++;
				continue;
			}

			Date maxEnd = result.maxEndDateByQuoteId.get(line.QuoteId);
			Boolean shouldInclude = maxEnd != null &&
				line.ELV_End_Date__c != null &&
				line.ELV_End_Date__c == maxEnd;

			if (shouldInclude) {
				result.includedCount++;
			} else {
				result.excludedCount++;
			}

			if (line.ELV_Include_in_Exit_ARR__c != shouldInclude) {
				result.linesToUpdate.add(
					new QuoteLineItem(Id = line.Id, ELV_Include_in_Exit_ARR__c = shouldInclude)
				);
			}
		}

		return result;
	}

	/**
	 * Evaluates and persists. The Quote max end date is saved first so that anything
	 * reacting to the line update already sees the current aggregate.
	 */
	public static ExitARRResult refreshAndSave(Set<Id> quoteIds) {
		ExitARRResult result = evaluate(quoteIds);

		if (!result.quotesToUpdate.isEmpty()) {
			update result.quotesToUpdate;
		}
		if (!result.linesToUpdate.isEmpty()) {
			update result.linesToUpdate;
		}

		return result;
	}

	/** Convenience overload for a single quote. */
	public static ExitARRResult refreshAndSave(Id quoteId) {
		return refreshAndSave(new Set<Id>{ quoteId });
	}

	/** Flow / button entry point. */
	@InvocableMethod(
		label='Refresh Include in Exit ARR'
		description='Stamps Quote max line end date and the Include in Exit ARR flag on each quote line.'
	)
	public static void refreshFromFlow(List<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}
		refreshAndSave(new Set<Id>(quoteIds));
	}
}