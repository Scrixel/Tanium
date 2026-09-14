/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036, design section 4. Owns every ELV_ ARR figure on the
 *            Opportunity. Arbitrates between the Quote branch and the Opportunity
 *            Subscription branch, applies split and churn handling, and stamps the result.
 *
 *            All Opportunity-level arithmetic lives here. The junction service never writes
 *            an Opportunity field, and no roll-up summary backs these totals - aggregation is
 *            in Apex so that the figures can be field-history tracked and so that the
 *            currency and exit-ARR handling stay in one testable place.
 *
 *            The service re-derives absolutely: it reads the current inputs and writes the
 *            result, never a delta. A retry, a duplicate event or a delete-and-recreate is
 *            therefore harmless.
 *
 *            PERCENT CONVENTION. Apex reads a Percent field as its raw number - a 50 percent
 *            split arrives as 50 - so this class divides by 100. A formula field on the same
 *            object reads the same value as a fraction and must not divide. Both conventions
 *            are correct in their own context; see Opportunity.ELV_Incoming_ARR_after_Split__c.
 */
public with sharing class ELV_OpportunityARRService {
	@TestVisible
	private static Boolean isRecalculating = false;

	private static final String SOURCE_QUOTE = 'Quote';
	private static final String SOURCE_SUBSCRIPTION = 'Opportunity Subscription';
	private static final String SOURCE_NONE = 'None';
	private static final String CHURN_FULL = 'Full Churn';
	private static final String TYPE_SPLIT = 'Split';

	/**
	 * The single entry point. Every trigger passes Opportunity Ids and nothing else.
	 * The recursion guard is required because Opportunity carries eight active triggers with
	 * no ordering discipline, so this write can re-enter through a path we do not control.
	 */
	public static void recalculate(Set<Id> opportunityIds) {
		if (isRecalculating || opportunityIds == null || opportunityIds.isEmpty()) {
			return;
		}

		List<Opportunity> opportunities = [
			SELECT
				Id,
				IsClosed,
				IsWon,
				Type,
				CloseDate,
				RVP_CHURN_RISK_OVERIDE__c,
				Split_Percent__c,
				Ramped_Opportunity__c,
				Ramped_Opportunity__r.ELV_Sales_ARR_Before_Split__c,
				Incoming_ARR_Rollup__c,
				Incoming_ARR_Override__c,
				In_Year_ARR_Adjustment__c,
				Ruby__PrimaryQuote__c,
				Ruby__PrimaryQuote__r.ELV_Day_1_ARR__c,
				Ruby__PrimaryQuote__r.ELV_Exit_ARR__c,
				ELV_Sales_ARR_Before_Split__c,
				ELV_Sales_ARR__c,
				ELV_Exit_ARR__c,
				ELV_Incoming_ARR__c,
				ELV_Incoming_ARR_Baseline__c,
				ELV_Subscription_ARR__c,
				ELV_Subscription_Exit_ARR__c,
				ELV_Subscription_Row_Count__c,
				ELV_Subscription_Max_End_Date__c,
				ELV_ARR_Source__c,
				ELV_Primary_Quote_Stamp__c
			FROM Opportunity
			WHERE Id IN :opportunityIds
		];

		if (opportunities.isEmpty()) {
			return;
		}

		Map<Id, Opportunity> originals = new Map<Id, Opportunity>();
		for (Opportunity opp : opportunities) originals.put(opp.Id, opp.clone(true, false, false, false));
		applySubscriptionAggregates(opportunities);
		List<Opportunity> toUpdate = buildUpdates(opportunities, originals);

		if (toUpdate.isEmpty()) {
			return;
		}

		isRecalculating = true;
		try {
			update toUpdate;
		} finally {
			isRecalculating = false;
		}
	}

	/** Returns only the Opportunities whose stored figures have actually moved. */
	@TestVisible
	private static List<Opportunity> buildUpdates(List<Opportunity> opportunities) {
		Map<Id, Opportunity> originals = new Map<Id, Opportunity>();
		for (Opportunity opp : opportunities) originals.put(opp.Id, opp.clone(true, false, false, false));
		applySubscriptionAggregates(opportunities);
		return buildUpdates(opportunities, originals);
	}

	private static List<Opportunity> buildUpdates(
		List<Opportunity> opportunities,
		Map<Id, Opportunity> originals
	) {
		List<Opportunity> toUpdate = new List<Opportunity>();

		for (Opportunity opp : opportunities) {
			Opportunity result = calculate(opp);
			Opportunity original = originals.get(opp.Id);

			if (!hasChanged(original, result)) {
				continue;
			}

			result.ELV_ARR_Last_Synced__c = System.now();
			toUpdate.add(result);
		}

		return toUpdate;
	}

	/**
	 * Computes every stored figure for one Opportunity and returns it as an update shell.
	 * Pure arithmetic over the record passed in, so it is directly unit-testable without DML.
	 */
	@TestVisible
	private static Opportunity calculate(Opportunity opp) {
		Boolean hasQuote = opp.Ruby__PrimaryQuote__c != null;
		Boolean isZeroed = isZeroedOut(opp);

		Decimal subscriptionARR = zero(opp.ELV_Subscription_ARR__c);
		Decimal subscriptionExitARR = zero(opp.ELV_Subscription_Exit_ARR__c);
		Decimal rowCount = zero(opp.ELV_Subscription_Row_Count__c);

		Decimal salesBeforeSplit;
		Decimal exitARR;
		String source;

		if (hasQuote) {
			salesBeforeSplit = zero(opp.Ruby__PrimaryQuote__r.ELV_Day_1_ARR__c);
			exitARR = zero(opp.Ruby__PrimaryQuote__r.ELV_Exit_ARR__c);
			source = SOURCE_QUOTE;
		} else {
			salesBeforeSplit = subscriptionARR;
			exitARR = subscriptionExitARR;
			source = rowCount > 0 ? SOURCE_SUBSCRIPTION : SOURCE_NONE;
		}

		if (isZeroed) {
			salesBeforeSplit = 0;
			exitARR = 0;
		}

		return new Opportunity(
			Id = opp.Id,
			ELV_Subscription_ARR__c = zero(opp.ELV_Subscription_ARR__c),
			ELV_Subscription_Exit_ARR__c = zero(opp.ELV_Subscription_Exit_ARR__c),
			ELV_Subscription_Row_Count__c = zero(opp.ELV_Subscription_Row_Count__c),
			ELV_Subscription_Max_End_Date__c = opp.ELV_Subscription_Max_End_Date__c,
			ELV_Incoming_ARR_Baseline__c = zero(opp.ELV_Incoming_ARR_Baseline__c),
			ELV_Sales_ARR_Before_Split__c = salesBeforeSplit,
			ELV_Sales_ARR__c = applySplit(opp, salesBeforeSplit),
			ELV_Exit_ARR__c = exitARR,
			ELV_Incoming_ARR__c = incomingARR(opp),
			ELV_ARR_Source__c = source,
			ELV_Primary_Quote_Stamp__c = hasQuote ? String.valueOf(opp.Ruby__PrimaryQuote__c) : null
		);
	}

	/**
	 * Closed-lost, and open-with-a-Full-Churn call, both report zero ARR. This reproduces the
	 * zeroing the legacy Exit_ARR__c formula and the CPQ flows already apply, so the ELV
	 * figures agree with the CPQ figures on the cases that matter most to forecasting.
	 */
	private static Boolean isZeroedOut(Opportunity opp) {
		if (opp.IsClosed && !opp.IsWon) {
			return true;
		}

		return !opp.IsClosed && CHURN_FULL.equals(opp.RVP_CHURN_RISK_OVERIDE__c);
	}

	/**
	 * Mirrors Incoming_ARR_after_Split__c. A blank or zero split percent leaves the figure
	 * untouched rather than zeroing it, which is the legacy behaviour and the reason an
	 * unpopulated split cannot silently erase an Opportunity's ARR.
	 *
	 * On a Split Opportunity the parent's pre-split figure is the base, matching the legacy
	 * formula's use of Ramped_Opportunity__r. The ramp write-up performed by
	 * 'Opportunity - After Save - On Create or Update' is deliberately NOT reproduced here -
	 * see design section 6.19; reproducing it before the junction branch exists would write
	 * the same ARR twice.
	 */
	@TestVisible
	private static Decimal applySplit(Opportunity opp, Decimal beforeSplit) {
		Decimal splitPercent = opp.Split_Percent__c;

		if (splitPercent == null || splitPercent == 0) {
			return beforeSplit;
		}

		Decimal base = beforeSplit;

		if (TYPE_SPLIT.equals(opp.Type) && opp.Ramped_Opportunity__c != null) {
			base = zero(opp.Ramped_Opportunity__r.ELV_Sales_ARR_Before_Split__c);
		}

		// Apex reads a Percent field as its raw number, so 50 means 50 percent.
		return (base * splitPercent / 100).setScale(2, System.RoundingMode.HALF_UP);
	}

	/**
	 * Mirrors Incoming_ARR__c: the override replaces the roll-up, the in-year adjustment always
	 * applies. Extended 2026-08-24 (design section 3.3, issue 18) with a third source.
	 *
	 * PRECEDENCE: Incoming_ARR_Override__c, then Incoming_ARR_Rollup__c, then
	 * ELV_Incoming_ARR_Baseline__c. The roll-up is the CPQ Renewed Contracts junction and is
	 * structurally zero on a Nue-era renewal, which has no CPQ Contract behind it; the baseline
	 * is the Opportunity Subscription figure, which is the same quantity expressed Nue-side.
	 * Taking the baseline only when the roll-up is zero is what stops a record carrying both
	 * from double counting - the two are alternative expressions of one renewal, never a sum.
	 *
	 * The baseline deliberately follows term alignment: ruled 2026-08-24, an Opportunity whose
	 * Close Date has moved beyond the configured tolerance is no longer renewing that term and
	 * is reported as New business, so its baseline correctly falls to zero.
	 */
	@TestVisible
	private static Decimal incomingARR(Opportunity opp) {
		// GAP-06. Null means no override. A populated zero is an explicit override.
		Decimal baseline;
		if (opp.Incoming_ARR_Override__c != null) {
			baseline = opp.Incoming_ARR_Override__c;
		} else if (opp.Incoming_ARR_Rollup__c != null && opp.Incoming_ARR_Rollup__c != 0) {
			baseline = opp.Incoming_ARR_Rollup__c;
		} else {
			baseline = zero(opp.ELV_Incoming_ARR_Baseline__c);
		}

		return baseline + zero(opp.In_Year_ARR_Adjustment__c);
	}

	private static Boolean hasChanged(Opportunity current, Opportunity result) {
		return zero(current.ELV_Subscription_ARR__c) != result.ELV_Subscription_ARR__c ||
			zero(current.ELV_Subscription_Exit_ARR__c) != result.ELV_Subscription_Exit_ARR__c ||
			zero(current.ELV_Subscription_Row_Count__c) != result.ELV_Subscription_Row_Count__c ||
			current.ELV_Subscription_Max_End_Date__c != result.ELV_Subscription_Max_End_Date__c ||
			zero(current.ELV_Incoming_ARR_Baseline__c) != result.ELV_Incoming_ARR_Baseline__c ||
			zero(current.ELV_Sales_ARR_Before_Split__c) != result.ELV_Sales_ARR_Before_Split__c ||
			zero(current.ELV_Sales_ARR__c) != result.ELV_Sales_ARR__c ||
			zero(current.ELV_Exit_ARR__c) != result.ELV_Exit_ARR__c ||
			zero(current.ELV_Incoming_ARR__c) != result.ELV_Incoming_ARR__c ||
			current.ELV_ARR_Source__c != result.ELV_ARR_Source__c ||
			current.ELV_Primary_Quote_Stamp__c != result.ELV_Primary_Quote_Stamp__c;
	}

	/**
	 * Re-derives all four roll-up-free junction aggregates before branch arbitration, and
	 * stamps the renewal baseline from the same included rows. The baseline is derived on every
	 * pass irrespective of which branch wins, so it stays current after a Renewal Quote becomes
	 * primary and the reported ARR moves to the Quote branch.
	 */
	@TestVisible
	private static void applySubscriptionAggregates(List<Opportunity> opportunities) {
		Map<Id, Opportunity> byId = new Map<Id, Opportunity>(opportunities);
		Map<Id, List<Ruby__OpportunitySubscription__c>> rowsByOpportunity =
			new Map<Id, List<Ruby__OpportunitySubscription__c>>();
		for (Ruby__OpportunitySubscription__c row : [
			SELECT Ruby__Opportunity__c, ELV_ARR_Amount__c, ELV_Max_End_Date__c
			FROM Ruby__OpportunitySubscription__c
			WHERE Ruby__Opportunity__c IN :byId.keySet() AND ELV_Include_in_ARR__c = true
		]) {
			if (!rowsByOpportunity.containsKey(row.Ruby__Opportunity__c)) {
				rowsByOpportunity.put(row.Ruby__Opportunity__c, new List<Ruby__OpportunitySubscription__c>());
			}
			rowsByOpportunity.get(row.Ruby__Opportunity__c).add(row);
		}

		for (Opportunity opp : opportunities) {
			List<Ruby__OpportunitySubscription__c> rows = rowsByOpportunity.get(opp.Id);
			Decimal total = 0;
			Decimal exitTotal = 0;
			Date maxEnd;
			if (rows != null) {
				for (Ruby__OpportunitySubscription__c row : rows) {
					total += zero(row.ELV_ARR_Amount__c);
					if (row.ELV_Max_End_Date__c != null &&
						(maxEnd == null || row.ELV_Max_End_Date__c > maxEnd)) maxEnd = row.ELV_Max_End_Date__c;
				}
				for (Ruby__OpportunitySubscription__c row : rows) {
					if (row.ELV_Max_End_Date__c == maxEnd) exitTotal += zero(row.ELV_ARR_Amount__c);
				}
			}
			opp.ELV_Subscription_ARR__c = total;
			opp.ELV_Subscription_Exit_ARR__c = exitTotal;
			opp.ELV_Subscription_Row_Count__c = rows == null ? 0 : rows.size();
			opp.ELV_Subscription_Max_End_Date__c = maxEnd;
			opp.ELV_Incoming_ARR_Baseline__c = total;
		}
	}

	private static Decimal zero(Decimal value) {
		return value == null ? 0 : value;
	}

	/**
	 * Resolves the Opportunities behind a set of Quotes. Used by the quote entry points,
	 * including before delete, where the lookup has to be captured while the quote still exists.
	 */
	public static Set<Id> opportunityIdsFor(List<Quote> quotes) {
		Set<Id> opportunityIds = new Set<Id>();

		if (quotes == null) {
			return opportunityIds;
		}

		for (Quote quote : quotes) {
			if (quote.OpportunityId != null) {
				opportunityIds.add(quote.OpportunityId);
			}
		}

		return opportunityIds;
	}

	/**
	 * True when a quote change could move its Opportunity's ARR. A quote-side recalculation
	 * raises no event on the Opportunity, so this test - not an Opportunity trigger - is what
	 * tells the service to re-run.
	 */
	public static Set<Id> opportunityIdsForChangedQuotes(
		List<Quote> quotes,
		Map<Id, Quote> oldMap
	) {
		Set<Id> opportunityIds = new Set<Id>();

		if (quotes == null) {
			return opportunityIds;
		}

		for (Quote quote : quotes) {
			if (quote.OpportunityId == null) {
				continue;
			}

			Quote oldQuote = oldMap == null ? null : oldMap.get(quote.Id);

			if (oldQuote == null || isArrRelevantChange(quote, oldQuote)) {
				opportunityIds.add(quote.OpportunityId);
			}
		}

		return opportunityIds;
	}

	private static Boolean isArrRelevantChange(Quote quote, Quote oldQuote) {
		return quote.Ruby__IsPrimaryQuote__c != oldQuote.Ruby__IsPrimaryQuote__c ||
			quote.ELV_Day_1_ARR__c != oldQuote.ELV_Day_1_ARR__c ||
			quote.ELV_Exit_ARR__c != oldQuote.ELV_Exit_ARR__c ||
			quote.ELV_ARR_Adjustment__c != oldQuote.ELV_ARR_Adjustment__c ||
			quote.ELV_Exit_ARR_Adjustment__c != oldQuote.ELV_Exit_ARR_Adjustment__c;
	}
}