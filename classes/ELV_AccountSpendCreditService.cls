/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * TNCI-175 / ELV-CPQ-134. Calculates Applicable Account Spend on the Quote and on each
 * Quote Line Item, and calculates or copies down AI Credits onto QuoteLineItem.ELV_UsageQuantity__c.
 *
 * Spend basis for a given period (a Quote's own Ruby Subscription Start/End Date, or a single
 * Quote Line's own Ruby Subscription Start/End Date) is the annualized contribution of every
 * eligible overlapping source: sibling Quote Lines on the same quote, and existing
 * Ruby__Subscription__c records on the same Account. A source is eligible only when its
 * Product2.Include_In_Annualized_Software_Spend__c = true. Annualization divides Total Amount
 * by ELV_ProrateMultiplier__c.
 *
 * Credit resolution for a Quote Line:
 *   1. Product2.ELV_UsageQuantity__c already set (static credit quantity) -> copy straight to
 *      QuoteLineItem.ELV_UsageQuantity__c. No spend calculation for this line.
 *   2. Otherwise, when QuoteLineItem.ELV_PoT_PricePercent__c > 0 OR
 *      Product2.ELV_Calculate_Credits_From_Spend__c = true -> calculate Applicable Account
 *      Spend, then run the AI_Credit_Tier__c marginal bands against it for base Credits.
 *      ELV_PoT_PricePercent__c is NOT a credit formula input here - it only gates whether a
 *      spend calculation runs, because a later price plugin (out of this service's scope)
 *      consumes ELV_Applicable_Account_Spend__c to derive Final Price for percent-of-total
 *      lines. Credits are always the tiered result, never the percent multiplier.
 *      When Product2.ELV_UsageMultiplier__c is set, the booster multiplier adds that many
 *      extra multiples of the base tiered credits on top: Credits = Tiered Credits +
 *      (Tiered Credits * ELV_UsageMultiplier__c).
 *   A line matching neither of the above is left untouched.
 */
public with sharing class ELV_AccountSpendCreditService {
	private static final Set<String> ELIGIBLE_SUBSCRIPTION_STATUSES = new Set<String>{
		'Active',
		'ScheduledForCancel'
	};

	/** One recalculation pass per quote per transaction, however many trigger events arrive. */
	@TestVisible
	private static Set<Id> recalculatedQuoteIds = new Set<Id>();

	/** TNCI-175 / ELV-CPQ-134. Entry point: recalculates Quote and Quote Line spend/credits. */
	public static void recalculateForQuotes(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		Set<Id> toRun = new Set<Id>(quoteIds);
		toRun.removeAll(recalculatedQuoteIds);
		if (toRun.isEmpty()) {
			return;
		}
		recalculatedQuoteIds.addAll(toRun);

		List<Quote> quotes = [
			SELECT Id, AccountId, Ruby__SubscriptionStartDate__c, Ruby__SubscriptionEndDate__c
			FROM Quote
			WHERE Id IN :toRun
		];
		if (quotes.isEmpty()) {
			return;
		}

		Map<Id, Id> accountIdByQuoteId = new Map<Id, Id>();
		for (Quote q : quotes) {
			accountIdByQuoteId.put(q.Id, q.AccountId);
		}

		List<QuoteLineItem> lines = [
			SELECT
				Id,
				QuoteId,
				Product2Id,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				Ruby__TotalAmount__c,
				ELV_ProrateMultiplier__c,
				ELV_PoT_PricePercent__c,
				ELV_UsageQuantity__c,
				Product2.Include_In_Annualized_Software_Spend__c,
				Product2.ELV_PoT_PricePercent__c,
				Product2.ELV_UsageQuantity__c,
				Product2.ELV_Calculate_Credits_From_Spend__c,
				Product2.ELV_UsageMultiplier__c
			FROM QuoteLineItem
			WHERE QuoteId IN :toRun
		];

		Map<Id, List<QuoteLineItem>> linesByQuoteId = new Map<Id, List<QuoteLineItem>>();
		for (QuoteLineItem line : lines) {
			if (!linesByQuoteId.containsKey(line.QuoteId)) {
				linesByQuoteId.put(line.QuoteId, new List<QuoteLineItem>());
			}
			linesByQuoteId.get(line.QuoteId).add(line);
		}

		Set<Id> accountIds = new Set<Id>(accountIdByQuoteId.values());
		accountIds.remove(null);
		List<Ruby__Subscription__c> subscriptions = accountIds.isEmpty()
			? new List<Ruby__Subscription__c>()
			: [
				SELECT
					Ruby__Customer__c,
					Ruby__Product__c,
					Ruby__SubscriptionStartDate__c,
					Ruby__SubscriptionEndDate__c,
					Ruby__TotalAmount__c,
					ELV_ProrateMultiplier__c,
					Ruby__Product__r.Include_In_Annualized_Software_Spend__c
				FROM Ruby__Subscription__c
				WHERE
					Ruby__Customer__c IN :accountIds
					AND Ruby__Status__c IN :ELIGIBLE_SUBSCRIPTION_STATUSES
					AND Ruby__Product__r.Include_In_Annualized_Software_Spend__c = TRUE
			];

		Map<Id, List<Ruby__Subscription__c>> subscriptionsByAccountId = new Map<Id, List<Ruby__Subscription__c>>();
		for (Ruby__Subscription__c sub : subscriptions) {
			if (!subscriptionsByAccountId.containsKey(sub.Ruby__Customer__c)) {
				subscriptionsByAccountId.put(sub.Ruby__Customer__c, new List<Ruby__Subscription__c>());
			}
			subscriptionsByAccountId.get(sub.Ruby__Customer__c).add(sub);
		}

		List<AI_Credit_Tier__c> tiers = [
			SELECT Lower_Band__c, Upper_Band__c, Marginal_Rate_Percent__c
			FROM AI_Credit_Tier__c
			ORDER BY Tier__c ASC
		];

		List<Quote> quotesToUpdate = new List<Quote>();
		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();

		for (Quote q : quotes) {
			List<Ruby__Subscription__c> accountSubs = subscriptionsByAccountId.get(q.AccountId);
			Decimal quoteSpend = calculateApplicableSpend(
				q.Ruby__SubscriptionStartDate__c,
				q.Ruby__SubscriptionEndDate__c,
				linesByQuoteId.get(q.Id),
				accountSubs
			);
			quotesToUpdate.add(new Quote(Id = q.Id, ELV_Applicable_Account_Spend__c = quoteSpend));
		}

		for (QuoteLineItem line : lines) {
			// TNCI-175 / ELV-CPQ-134. A line's own spend basis is its ELIGIBLE SIBLINGS, not
			// itself - excluded here so a line never contributes to its own spend figure.
			List<QuoteLineItem> siblings = new List<QuoteLineItem>();
			for (QuoteLineItem candidate : linesByQuoteId.get(line.QuoteId)) {
				if (candidate.Id != line.Id) {
					siblings.add(candidate);
				}
			}

			QuoteLineItem lineUpdate = resolveLine(
				line,
				siblings,
				subscriptionsByAccountId.get(accountIdByQuoteId.get(line.QuoteId)),
				tiers
			);
			if (lineUpdate != null) {
				linesToUpdate.add(lineUpdate);
			}
		}

		if (!quotesToUpdate.isEmpty()) {
			update quotesToUpdate;
		}
		if (!linesToUpdate.isEmpty()) {
			update linesToUpdate;
		}
	}

	/**
	 * TNCI-175 / ELV-CPQ-134. Applicable Account Spend for one period: the annualized
	 * contribution of every eligible sibling Quote Line and every eligible existing
	 * Ruby__Subscription__c whose own subscription window overlaps the given period.
	 */
	private static Decimal calculateApplicableSpend(
		Date periodStart,
		Date periodEnd,
		List<QuoteLineItem> siblingLines,
		List<Ruby__Subscription__c> accountSubscriptions
	) {
		Decimal total = 0;

		if (siblingLines != null) {
			for (QuoteLineItem sibling : siblingLines) {
				if (sibling.Product2.Include_In_Annualized_Software_Spend__c != true) {
					continue;
				}
				if (
					!overlaps(
						periodStart,
						periodEnd,
						sibling.Ruby__SubscriptionStartDate__c,
						sibling.Ruby__SubscriptionEndDate__c
					)
				) {
					continue;
				}
				total += annualizedContribution(sibling.Ruby__TotalAmount__c, sibling.ELV_ProrateMultiplier__c);
			}
		}

		if (accountSubscriptions != null) {
			for (Ruby__Subscription__c sub : accountSubscriptions) {
				if (
					!overlaps(
						periodStart,
						periodEnd,
						sub.Ruby__SubscriptionStartDate__c,
						sub.Ruby__SubscriptionEndDate__c
					)
				) {
					continue;
				}
				total += annualizedContribution(sub.Ruby__TotalAmount__c, sub.ELV_ProrateMultiplier__c);
			}
		}

		return total;
	}

	/** TNCI-175 / ELV-CPQ-134. Annualized Contribution = Total Amount / ELV_ProrateMultiplier__c. */
	private static Decimal annualizedContribution(Decimal totalAmount, Decimal prorateMultiplier) {
		if (totalAmount == null) {
			return 0;
		}
		if (prorateMultiplier == null || prorateMultiplier == 0) {
			return totalAmount;
		}
		return totalAmount / prorateMultiplier;
	}

	/** Two date windows overlap when each starts on or before the other's end (open end = ongoing). */
	private static Boolean overlaps(Date aStart, Date aEnd, Date bStart, Date bEnd) {
		if (aStart == null || bStart == null) {
			return false;
		}
		Boolean startsBeforeOtherEnds = bEnd == null || aStart <= bEnd;
		Boolean otherStartsBeforeThisEnds = aEnd == null || bStart <= aEnd;
		return startsBeforeOtherEnds && otherStartsBeforeThisEnds;
	}

	/**
	 * TNCI-175 / ELV-CPQ-134. Resolves one Quote Line's credit path and, when the path requires
	 * it, its own Applicable Account Spend. Returns null when the line matches neither path and
	 * nothing needs to change.
	 *
	 * ELV_PoT_PricePercent__c is NOT a credit formula input - it feeds a separate, later price
	 * plugin step that derives Final Price from Applicable Account Spend. Credits are always
	 * resolved from the AI Credit Tier bands whenever a spend calculation runs, regardless of
	 * which condition gated it in.
	 */
	private static QuoteLineItem resolveLine(
		QuoteLineItem line,
		List<QuoteLineItem> siblingLines,
		List<Ruby__Subscription__c> accountSubscriptions,
		List<AI_Credit_Tier__c> tiers
	) {
		// Path 1: product-level static credit quantity. Straight copy, no spend calculation.
		if (line.Product2.ELV_UsageQuantity__c != null) {
			return new QuoteLineItem(Id = line.Id, ELV_UsageQuantity__c = line.Product2.ELV_UsageQuantity__c);
		}

		Decimal potPercent = line.ELV_PoT_PricePercent__c;
		Boolean calculateFromSpend = line.Product2.ELV_Calculate_Credits_From_Spend__c == true;

		// Gate: a percent-of-total line still needs its own spend calculated - the later price
		// plugin consumes ELV_Applicable_Account_Spend__c to derive Final Price - but that
		// percent plays no part in the credit result below.
		if ((potPercent == null || potPercent <= 0) && !calculateFromSpend) {
			return null;
		}

		Decimal lineSpend = calculateApplicableSpend(
			line.Ruby__SubscriptionStartDate__c,
			line.Ruby__SubscriptionEndDate__c,
			siblingLines,
			accountSubscriptions
		);

		// Path 2: tiered AI Credit bands against the calculated spend - the base credit formula.
		Decimal tierCredits = creditsFromTiers(lineSpend, tiers);

		// TNCI-175 / ELV-CPQ-134. Booster multiplier: Product2.ELV_UsageMultiplier__c, when set,
		// adds that many extra multiples of the base tiered credits on top of the base amount -
		// Credits = Tiered Credits + (Tiered Credits * ELV_UsageMultiplier__c).
		Decimal usageMultiplier = line.Product2.ELV_UsageMultiplier__c;
		Decimal totalCredits = (usageMultiplier == null || usageMultiplier == 0)
			? tierCredits
			: tierCredits + (tierCredits * usageMultiplier);

		return new QuoteLineItem(
			Id = line.Id,
			ELV_Applicable_Account_Spend__c = lineSpend,
			ELV_UsageQuantity__c = totalCredits
		);
	}

	/** TNCI-175 / ELV-CPQ-134. Marginal, banded credits: each band earns only its own slice. */
	private static Decimal creditsFromTiers(Decimal spend, List<AI_Credit_Tier__c> tiers) {
		if (spend == null || spend <= 0 || tiers == null) {
			return 0;
		}

		Decimal credits = 0;
		for (AI_Credit_Tier__c tier : tiers) {
			if (tier.Lower_Band__c == null || spend <= tier.Lower_Band__c) {
				continue;
			}
			Decimal bandTop = tier.Upper_Band__c == null || spend < tier.Upper_Band__c
				? spend
				: tier.Upper_Band__c;
			Decimal bandSpend = bandTop - tier.Lower_Band__c;
			if (bandSpend <= 0) {
				continue;
			}
			// Marginal_Rate_Percent__c is a Percent field, stored as e.g. 15 for 15%.
			Decimal rate = tier.Marginal_Rate_Percent__c == null ? 0 : tier.Marginal_Rate_Percent__c / 100;
			credits += bandSpend * rate;
		}
		return credits;
	}
}