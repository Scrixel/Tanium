/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. Maintains Quote.ELV_Day_1_ARR__c (Sales ARR) as stored
 *            data. Sales ARR stays a stamped field rather than a formula so its history is
 *            tracked and so it can be corrected; the arithmetic is a verbatim port of the CPQ
 *            before-save flow element formula_Day1PlusAdjustment:
 *
 *              IF(ISNULL(Day 1 ARR Unadjusted (Rollup)), 0,
 *                 (Rollup + ARR Adjustment + In Year ARR Adjustment)
 *                 - (Rollup * (Marketplace ARR Impact Percent / 100))
 *                 - Partner Referral Fee)
 *
 *            The partner rebate term present in the field's inline help was removed from the
 *            CPQ flow under SS-12832 and is deliberately not carried over. In Year ARR
 *            Adjustment and Partner Referral Fee both originate on the Opportunity and reach
 *            the Quote through existing cross-object formulas.
 *
 *            Stamping happens after save, not before, because the value depends on a roll-up
 *            summary and roll-ups do not recalculate until the line save has committed. The
 *            recursion guard keeps the resulting Quote update from re-entering the trigger,
 *            and an unchanged quote costs no DML.
 */
public with sharing class ELV_SalesARRStampService {
	@TestVisible
	private static Boolean isStamping = false;

	/**
	 * Recomputes and saves Sales ARR for the given quotes. Safe to call from an after-save
	 * context; re-entry is suppressed.
	 */
	public static void stampQuotes(Set<Id> quoteIds) {
		if (isStamping || quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		List<Quote> quotesToUpdate = buildUpdates(
			[
				SELECT
					Id,
					ELV_Day_1_ARR__c,
					ELV_Day_1_ARR_Unadjusted_Rollup__c,
					ELV_ARR_Adjustment__c,
					ELV_In_Year_ARR_Adjustment__c,
					ELV_Marketplace_ARR_Impact_Percent__c,
					ELV_Partner_Referral_Fee_Dollars__c
				FROM Quote
				WHERE Id IN :quoteIds
			]
		);

		if (quotesToUpdate.isEmpty()) {
			return;
		}

		isStamping = true;
		try {
			update quotesToUpdate;
		} finally {
			isStamping = false;
		}
	}

	/**
	 * Returns only the quotes whose stored Sales ARR differs from the calculated value, so a
	 * quote that is already correct costs no DML.
	 */
	@TestVisible
	private static List<Quote> buildUpdates(List<Quote> quotes) {
		List<Quote> quotesToUpdate = new List<Quote>();

		for (Quote quote : quotes) {
			Decimal target = calculate(quote);
			if (quote.ELV_Day_1_ARR__c != null && quote.ELV_Day_1_ARR__c == target) {
				continue;
			}

			quotesToUpdate.add(new Quote(Id = quote.Id, ELV_Day_1_ARR__c = target));
		}

		return quotesToUpdate;
	}

	/**
	 * The CPQ arithmetic. A quote with no unadjusted roll-up is zero, exactly as the flow's
	 * ISNULL guard returns zero rather than applying adjustments to nothing.
	 */
	@TestVisible
	private static Decimal calculate(Quote quote) {
		if (quote.ELV_Day_1_ARR_Unadjusted_Rollup__c == null) {
			return 0;
		}

		Decimal rollup = quote.ELV_Day_1_ARR_Unadjusted_Rollup__c;
		Decimal arrAdjustment = zeroIfNull(quote.ELV_ARR_Adjustment__c);
		Decimal inYearAdjustment = zeroIfNull(quote.ELV_In_Year_ARR_Adjustment__c);
		Decimal marketplacePercent = zeroIfNull(quote.ELV_Marketplace_ARR_Impact_Percent__c);
		Decimal referralFee = zeroIfNull(quote.ELV_Partner_Referral_Fee_Dollars__c);

		Decimal result =
			(rollup + arrAdjustment + inYearAdjustment) -
			(rollup * (marketplacePercent / 100)) -
			referralFee;

		return result.setScale(2, System.RoundingMode.HALF_UP);
	}

	private static Decimal zeroIfNull(Decimal value) {
		return value == null ? 0 : value;
	}
}