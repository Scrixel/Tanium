/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Utility for the standard Quote Line Item trigger. Stamps the changed
 *            Ruby subscription and supported hardware asset lookups when a summary
 *            item references a subscription change asset.
 */
public with sharing class ELV_QuoteLineTriggerUtility {
	private static final String LINE_ITEM_LINE_TYPE = 'LineItem';
	private static final String RAMP_ITEM_LINE_TYPE = 'RampItem';
	private static final String SUMMARY_ITEM_LINE_TYPE = 'SummaryItem';
	private static final String SUBSCRIPTION_CHANGE_ASSET_TYPE = 'Subscription';
	private static final String VERSION_SEPARATOR = '_';
	private static final String CHANGE_TYPE_NEW_PRODUCT = 'NewProduct';
	private static final String CHANGE_TYPE_UPDATE_QUANTITY = 'UpdateQuantity';
	private static final String CHANGE_TYPE_RENEW = 'Renew';
	private static final String CHANGE_TYPE_RENEW_WITH_QUANTITY_UPDATE = 'RenewWithQuantityUpdate';
	private static final String CHANGE_TYPE_CANCEL = 'Cancel';
	private static final String CHANGE_TYPE_ADJUST_PRICE = 'AdjustPrice';
	private static final String MATRIX_LINE_TYPE_NEW_CUSTOMER = 'New Customer';
	private static final String MATRIX_LINE_TYPE_UPSELL = 'Upsell';
	private static final String MATRIX_LINE_TYPE_ADD_ON = 'Add-On';
	private static final String MATRIX_LINE_TYPE_RENEWAL = 'Renewal';
	private static final String PRODUCT_GROUP_SOFTWARE = 'Software';
	private static final String BUSINESS_MOTION_MSP = 'MSP';
	private static final String QUOTE_STATUS_DRAFT = 'Draft';
	private static final String QUOTE_STATUS_NEEDS_REVIEW = 'Needs Review';
	private static final Decimal ENDPOINT_BAND_9999_MAX = 9999;
	private static final Decimal ENDPOINT_BAND_25K_MIN = 25000;
	private static final Decimal ENDPOINT_BAND_40K_MIN = 40000;

	public static void requestQuoteRefreshOnQualifyingChange(
		List<QuoteLineItem> quoteLines,
		Map<Id, QuoteLineItem> oldMap
	) {
		Set<Id> quoteIds = getQuoteIdsWithQualifyingChange(quoteLines, oldMap);
		if (quoteIds.isEmpty()) {
			return;
		}

		List<Quote> quotesToRefresh = new List<Quote>();
		for (Id quoteId : quoteIds) {
			quotesToRefresh.add(new Quote(Id = quoteId, ELV_Refresh_Quote__c = true));
		}

		update quotesToRefresh;
	}

	/**
	 * Insert, delete and undelete move the quote roll-ups exactly as an edit does, and none
	 * of them can be compared field by field - every record qualifies. Callers pass the rows
	 * they have; only the parent id is read.
	 */
	public static void requestQuoteRefresh(List<QuoteLineItem> quoteLines) {
		if (quoteLines == null || quoteLines.isEmpty()) {
			return;
		}

		Set<Id> quoteIds = new Set<Id>();
		for (QuoteLineItem quoteLine : quoteLines) {
			if (quoteLine.QuoteId != null) {
				quoteIds.add(quoteLine.QuoteId);
			}
		}

		requestQuoteRefresh(quoteIds);
	}

	/** One update per quote per transaction, whatever the batch shape. */
	public static void requestQuoteRefresh(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		List<Quote> quotesToRefresh = new List<Quote>();
		for (Id quoteId : quoteIds) {
			quotesToRefresh.add(new Quote(Id = quoteId, ELV_Refresh_Quote__c = true));
		}

		update quotesToRefresh;
	}

	public static void stampChannelDiscounts(
		List<QuoteLineItem> quoteLines,
		Map<Id, QuoteLineItem> oldMap
	) {
		if (quoteLines == null || quoteLines.isEmpty()) {
			return;
		}

		List<QuoteLineItem> linesToResolve = new List<QuoteLineItem>();
		Set<Id> quoteIds = new Set<Id>();

		for (QuoteLineItem quoteLine : quoteLines) {
			clearSummaryLineDiscounts(quoteLine);

			Boolean refreshRequested = quoteLine.ELV_Refresh_Derived_Values__c == true;
			if (refreshRequested) {
				quoteLine.ELV_Refresh_Derived_Values__c = false;
			}

			if (!shouldResolveChannelDiscounts(quoteLine, oldMap, refreshRequested)) {
				continue;
			}

			if (!isDirectChannelDiscountLine(quoteLine)) {
				continue;
			}

			linesToResolve.add(quoteLine);
			if (quoteLine.QuoteId != null) {
				quoteIds.add(quoteLine.QuoteId);
			}
		}

		if (linesToResolve.isEmpty()) {
			return;
		}

		Map<Id, Quote> quotesById = getChannelDiscountQuotes(quoteIds);
		List<QuoteLineItem> eligibleLinesToResolve = new List<QuoteLineItem>();
		for (QuoteLineItem quoteLine : linesToResolve) {
			if (isChannelDiscountQuoteStatus(quotesById.get(quoteLine.QuoteId))) {
				eligibleLinesToResolve.add(quoteLine);
			}
		}

		if (eligibleLinesToResolve.isEmpty()) {
			return;
		}

		Map<Id, Account> partnerAccountsById = getPartnerAccounts(quotesById.values());
		Map<String, List<Tanium_Partner_Discount__c>> partnerDiscountRowsByKey = getPartnerDiscountRowsByKey(
			eligibleLinesToResolve,
			quotesById
		);
		Boolean isInitialInsert = oldMap == null;

		for (QuoteLineItem quoteLine : eligibleLinesToResolve) {
			stampChannelDiscounts(
				quoteLine,
				quotesById.get(quoteLine.QuoteId),
				partnerAccountsById,
				partnerDiscountRowsByKey,
				isInitialInsert
			);
		}
	}

	public static void reconcilePricingRefreshRequired(List<QuoteLineItem> quoteLines) {
		if (quoteLines == null || quoteLines.isEmpty()) {
			return;
		}

		for (QuoteLineItem quoteLine : quoteLines) {
			if (!isDirectChannelDiscountLine(quoteLine)) {
				continue;
			}

			quoteLine.ELV_Pricing_Refresh_Required__c =
				!isCompoundedDiscountCurrent(quoteLine);
		}
	}

	public static void markQuoteCustomCalculationNeeded(
		List<QuoteLineItem> quoteLines,
		Map<Id, QuoteLineItem> oldMap
	) {
		Set<Id> quoteIds = new Set<Id>();
		if (quoteLines == null || quoteLines.isEmpty()) {
			return;
		}

		for (QuoteLineItem quoteLine : quoteLines) {
			QuoteLineItem oldQuoteLine = oldMap == null
				? null
				: oldMap.get(quoteLine.Id);
			if (
				quoteLine.QuoteId != null &&
				isDirectChannelDiscountLine(quoteLine) &&
				hasCustomCalculationInputChanged(quoteLine, oldQuoteLine)
			) {
				quoteIds.add(quoteLine.QuoteId);
			}
		}

		if (quoteIds.isEmpty()) {
			return;
		}

		List<Quote> quotesToMark = new List<Quote>();
		for (Quote quote : [
			SELECT Id
			FROM Quote
			WHERE Id IN :quoteIds
			AND (
				Status IN :getChannelDiscountQuoteStatuses()
				OR (
					ELV_Quote_Migrated_Record__c = TRUE
					AND ELV_Quote_Migration_External_Id__c != NULL
				)
			)
			AND Ruby__IsCustomCalculationNeeded__c = FALSE
		]) {
			quotesToMark.add(
				new Quote(
					Id = quote.Id,
					Ruby__IsCustomCalculationNeeded__c = true
				)
			);
		}

		if (!quotesToMark.isEmpty()) {
			update quotesToMark;
		}
	}

	public static void requestDerivedValueRefresh(Set<Id> quoteLineIds) {
		if (quoteLineIds == null || quoteLineIds.isEmpty()) {
			return;
		}

		List<QuoteLineItem> quoteLinesToRefresh = new List<QuoteLineItem>();
		Set<String> eligibleStatuses = getChannelDiscountQuoteStatuses();
		for (QuoteLineItem quoteLine : [
			SELECT Id
			FROM QuoteLineItem
			WHERE Id IN :quoteLineIds
			AND (
				Quote.Status IN :eligibleStatuses
				OR (
					Quote.ELV_Quote_Migrated_Record__c = TRUE
					AND Quote.ELV_Quote_Migration_External_Id__c != NULL
				)
			)
		]) {
			quoteLinesToRefresh.add(
				new QuoteLineItem(
					Id = quoteLine.Id,
					ELV_Refresh_Derived_Values__c = true
				)
			);
		}

		if (!quoteLinesToRefresh.isEmpty()) {
			update quoteLinesToRefresh;
		}
	}

	public static Boolean restampCurrentChannelDiscounts(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return false;
		}

		List<QuoteLineItem> quoteLines = [
			SELECT Id, QuoteId, Quantity, Ruby__LineType__c, Ruby__ChangeType__c,
				   Ruby__SubscriptionStartDate__c, ELV_Product_Group__c,
				   ELV_Customer_Discount__c, Ruby__Discount__c,
				   ELV_Partner_Discount_Override__c,
				   ELV_Distributor_Discount_Override__c,
				   ELV_PartnerDiscount__c, ELV_DistributorDiscount__c,
				   ELV_Pricing_Refresh_Required__c, ELV_Refresh_Derived_Values__c
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIds
			AND (
				Quote.Status IN :getChannelDiscountQuoteStatuses()
				OR (
					Quote.ELV_Quote_Migrated_Record__c = TRUE
					AND Quote.ELV_Quote_Migration_External_Id__c != NULL
				)
			)
			AND Ruby__LineType__c IN :new Set<String>{
				LINE_ITEM_LINE_TYPE,
				RAMP_ITEM_LINE_TYPE
			}
		];

		if (quoteLines.isEmpty()) {
			return false;
		}

		Map<Id, QuoteLineItem> originalLinesById = new Map<Id, QuoteLineItem>();
		for (QuoteLineItem quoteLine : quoteLines) {
			originalLinesById.put(quoteLine.Id, quoteLine.clone(true, false, false, false));
		}

		stampChannelDiscounts(quoteLines, null);
		reconcilePricingRefreshRequired(quoteLines);

		List<QuoteLineItem> updates = new List<QuoteLineItem>();
		for (QuoteLineItem quoteLine : quoteLines) {
			QuoteLineItem original = originalLinesById.get(quoteLine.Id);
			if (!hasRestampedChannelDiscountChange(quoteLine, original)) {
				continue;
			}

			updates.add(
				new QuoteLineItem(
					Id = quoteLine.Id,
					Ruby__Discount__c = quoteLine.Ruby__Discount__c,
					ELV_PartnerDiscount__c = quoteLine.ELV_PartnerDiscount__c,
					ELV_DistributorDiscount__c = quoteLine.ELV_DistributorDiscount__c,
					ELV_Pricing_Refresh_Required__c = quoteLine.ELV_Pricing_Refresh_Required__c,
					ELV_Refresh_Derived_Values__c = quoteLine.ELV_Refresh_Derived_Values__c
				)
			);
		}

		if (updates.isEmpty()) {
			return false;
		}

		update updates;
		return true;
	}

	private static Boolean isCompoundedDiscountCurrent(QuoteLineItem quoteLine) {
		Decimal current = quoteLine.Ruby__Discount__c == null
			? 0
			: quoteLine.Ruby__Discount__c;

		return current.setScale(5) == compoundedDiscount(quoteLine);
	}

	private static Decimal compoundedDiscount(QuoteLineItem quoteLine) {
		Decimal customer = quoteLine.ELV_Customer_Discount__c == null
			? 0
			: quoteLine.ELV_Customer_Discount__c;
		Decimal partner = quoteLine.ELV_PartnerDiscount__c == null
			? 0
			: quoteLine.ELV_PartnerDiscount__c;
		Decimal distributor = quoteLine.ELV_DistributorDiscount__c == null
			? 0
			: quoteLine.ELV_DistributorDiscount__c;

		return ((1 - ((1 - customer / 100) * (1 - partner / 100) *
			(1 - distributor / 100))) * 100).setScale(5);
	}

	private static Boolean shouldResolveChannelDiscounts(
		QuoteLineItem quoteLine,
		Map<Id, QuoteLineItem> oldMap,
		Boolean refreshRequested
	) {
		if (quoteLine == null) {
			return false;
		}

		if (oldMap == null || refreshRequested) {
			return true;
		}

		QuoteLineItem oldQuoteLine = oldMap.get(quoteLine.Id);
		return oldQuoteLine == null ||
			quoteLine.QuoteId != oldQuoteLine.QuoteId ||
			quoteLine.Quantity != oldQuoteLine.Quantity ||
			quoteLine.ELV_Product_Group__c != oldQuoteLine.ELV_Product_Group__c ||
			quoteLine.Ruby__ChangeType__c != oldQuoteLine.Ruby__ChangeType__c ||
			quoteLine.Ruby__LineType__c != oldQuoteLine.Ruby__LineType__c ||
			quoteLine.Ruby__SubscriptionStartDate__c !=
			oldQuoteLine.Ruby__SubscriptionStartDate__c ||
			quoteLine.ELV_Partner_Discount_Override__c !=
			oldQuoteLine.ELV_Partner_Discount_Override__c ||
			quoteLine.ELV_Distributor_Discount_Override__c !=
			oldQuoteLine.ELV_Distributor_Discount_Override__c;
	}

	private static Boolean hasCustomCalculationInputChanged(
		QuoteLineItem quoteLine,
		QuoteLineItem oldQuoteLine
	) {
		return oldQuoteLine == null ||
			quoteLine.QuoteId != oldQuoteLine.QuoteId ||
			quoteLine.Quantity != oldQuoteLine.Quantity ||
			quoteLine.ELV_Product_Group__c != oldQuoteLine.ELV_Product_Group__c ||
			quoteLine.Ruby__ChangeType__c != oldQuoteLine.Ruby__ChangeType__c ||
			quoteLine.Ruby__LineType__c != oldQuoteLine.Ruby__LineType__c ||
			quoteLine.Ruby__SubscriptionStartDate__c !=
			oldQuoteLine.Ruby__SubscriptionStartDate__c ||
			quoteLine.ELV_Partner_Discount_Override__c !=
			oldQuoteLine.ELV_Partner_Discount_Override__c ||
			quoteLine.ELV_Distributor_Discount_Override__c !=
			oldQuoteLine.ELV_Distributor_Discount_Override__c ||
			quoteLine.ELV_PartnerDiscount__c != oldQuoteLine.ELV_PartnerDiscount__c ||
			quoteLine.ELV_DistributorDiscount__c !=
			oldQuoteLine.ELV_DistributorDiscount__c;
	}

	private static Boolean hasRestampedChannelDiscountChange(
		QuoteLineItem quoteLine,
		QuoteLineItem original
	) {
		return original == null ||
			quoteLine.Ruby__Discount__c != original.Ruby__Discount__c ||
			quoteLine.ELV_PartnerDiscount__c != original.ELV_PartnerDiscount__c ||
			quoteLine.ELV_DistributorDiscount__c !=
			original.ELV_DistributorDiscount__c ||
			quoteLine.ELV_Pricing_Refresh_Required__c !=
			original.ELV_Pricing_Refresh_Required__c ||
			quoteLine.ELV_Refresh_Derived_Values__c !=
			original.ELV_Refresh_Derived_Values__c;
	}

	private static Boolean isDirectChannelDiscountLine(QuoteLineItem quoteLine) {
		return quoteLine.Ruby__LineType__c == LINE_ITEM_LINE_TYPE ||
			quoteLine.Ruby__LineType__c == RAMP_ITEM_LINE_TYPE;
	}

	private static void clearSummaryLineDiscounts(QuoteLineItem quoteLine) {
		if (quoteLine == null || quoteLine.Ruby__LineType__c != SUMMARY_ITEM_LINE_TYPE) {
			return;
		}

		quoteLine.Ruby__Discount__c = null;
		quoteLine.ELV_PartnerDiscount__c = null;
		quoteLine.ELV_DistributorDiscount__c = null;
	}

	private static void stampChannelDiscounts(
		QuoteLineItem quoteLine,
		Quote quote,
		Map<Id, Account> partnerAccountsById,
		Map<String, List<Tanium_Partner_Discount__c>> partnerDiscountRowsByKey,
		Boolean isInitialInsert
	) {
		Decimal priorPartnerDiscount = quoteLine.ELV_PartnerDiscount__c;
		Decimal priorDistributorDiscount = quoteLine.ELV_DistributorDiscount__c;
		Boolean preservePartnerDiscount = quoteLine.ELV_Partner_Discount_Override__c ==
			true;
		Boolean preserveDistributorDiscount = quoteLine.ELV_Distributor_Discount_Override__c ==
			true;

		if (quoteLine.Ruby__ChangeType__c == CHANGE_TYPE_CANCEL) {
			if (!preservePartnerDiscount) {
				quoteLine.ELV_PartnerDiscount__c = 0;
			}
			if (!preserveDistributorDiscount) {
				quoteLine.ELV_DistributorDiscount__c = 0;
			}
		} else if (quoteLine.Ruby__ChangeType__c != CHANGE_TYPE_ADJUST_PRICE) {
			String matrixLineType = getMatrixLineType(quoteLine, quote);

			if (String.isBlank(matrixLineType)) {
				if (!preservePartnerDiscount) {
					quoteLine.ELV_PartnerDiscount__c = 0;
				}
				if (!preserveDistributorDiscount) {
					quoteLine.ELV_DistributorDiscount__c = 0;
				}
			} else {
				if (!preservePartnerDiscount) {
					stampPartnerDiscount(
						quoteLine,
						quote,
						matrixLineType,
						partnerDiscountRowsByKey,
						isInitialInsert
					);
				}

				Account partnerAccount = quote == null || quote.ELV_Partner__c == null
					? null
					: partnerAccountsById.get(quote.ELV_Partner__c);

				if (!preserveDistributorDiscount) {
					stampDistributorDiscount(
						quoteLine,
						quote,
						partnerAccount,
						matrixLineType,
						isInitialInsert
					);
				}
			}
		}

		if (
			quoteLine.ELV_PartnerDiscount__c != priorPartnerDiscount ||
			quoteLine.ELV_DistributorDiscount__c != priorDistributorDiscount
		) {
			quoteLine.ELV_Pricing_Refresh_Required__c = true;
		}
	}

	// private static void stampChannelDiscounts(
	// 	QuoteLineItem quoteLine,
	// 	Quote quote,
	// 	Map<Id, Account> partnerAccountsById,
	// 	Map<String, List<Tanium_Partner_Discount__c>> partnerDiscountRowsByKey,
	// 	Boolean isInitialInsert
	// ) {
	// 	if (quoteLine.Ruby__ChangeType__c == CHANGE_TYPE_CANCEL) {
	// 		quoteLine.ELV_PartnerDiscount__c = 0;
	// 		quoteLine.ELV_DistributorDiscount__c = 0;
	// 		return;
	// 	}

	// 	if (quoteLine.Ruby__ChangeType__c == CHANGE_TYPE_ADJUST_PRICE) {
	// 		return;
	// 	}

	// 	String matrixLineType = getMatrixLineType(quoteLine, quote);
	// 	if (String.isBlank(matrixLineType)) {
	// 		return;
	// 	}

	// 	stampPartnerDiscount(
	// 		quoteLine,
	// 		quote,
	// 		matrixLineType,
	// 		partnerDiscountRowsByKey,
	// 		isInitialInsert
	// 	);

	// 	Account partnerAccount = quote == null || quote.ELV_Partner__c == null
	// 		? null
	// 		: partnerAccountsById.get(quote.ELV_Partner__c);
	// 	stampDistributorDiscount(
	// 		quoteLine,
	// 		quote,
	// 		partnerAccount,
	// 		matrixLineType,
	// 		isInitialInsert
	// 	);
	// }

	private static void stampPartnerDiscount(
		QuoteLineItem quoteLine,
		Quote quote,
		String matrixLineType,
		Map<String, List<Tanium_Partner_Discount__c>> partnerDiscountRowsByKey,
		Boolean isInitialInsert
	) {
		if (!hasCompletePartnerDiscountContext(quoteLine, quote, matrixLineType)) {
			quoteLine.ELV_PartnerDiscount__c = 0;
			return;
		}

		Tanium_Partner_Discount__c partnerDiscountRow = getPartnerDiscountRow(
			quoteLine,
			quote,
			matrixLineType,
			partnerDiscountRowsByKey
		);
		quoteLine.ELV_PartnerDiscount__c =
			partnerDiscountRow == null || partnerDiscountRow.Total_Discount__c == null
				? 0
				: partnerDiscountRow.Total_Discount__c;
	}

	private static void stampDistributorDiscount(
		QuoteLineItem quoteLine,
		Quote quote,
		Account partnerAccount,
		String matrixLineType,
		Boolean isInitialInsert
	) {
		if (!hasMinimumDistributorContext(quoteLine, quote, matrixLineType)) {
			quoteLine.ELV_DistributorDiscount__c = 0;
			return;
		}

		if (!isDistributorEligible(quoteLine, quote)) {
			quoteLine.ELV_DistributorDiscount__c = 0;
			return;
		}

		Decimal endpointCount = quote.ELV_No_of_End_Points_Quote_Score__c;
		if (partnerAccount == null || endpointCount == null) {
			quoteLine.ELV_DistributorDiscount__c = 0;
			return;
		}

		Decimal distributorDiscount = getDistributorDiscountRate(
			partnerAccount,
			endpointCount,
			matrixLineType == MATRIX_LINE_TYPE_RENEWAL
		);
		quoteLine.ELV_DistributorDiscount__c = distributorDiscount == null
			? 0
			: distributorDiscount;
	}

	private static Map<Id, Quote> getChannelDiscountQuotes(Set<Id> quoteIds) {
		return quoteIds == null || quoteIds.isEmpty()
			? new Map<Id, Quote>()
			: new Map<Id, Quote>(
					[
						SELECT
							Id,
							AccountId,
							Status,
							ELV_Quote_Migrated_Record__c,
							ELV_Quote_Migration_External_Id__c,
							ELV_Partner__c,
							ELV_Downstream_Reseller__c,
							ELV_Partner_Program_Tier__c,
							ELV_Partner_Program_Bucket__c,
							ELV_Partner_is_Incumbent__c,
							ELV_Eligible_for_Distributor_Discount__c,
							ELV_Business_Motion_Oppty__c,
							ELV_Marketplace_Partner__c,
							ELV_New_Opportunity_Type__c,
							ELV_No_of_End_Points_Quote_Score__c
						FROM Quote
						WHERE Id IN :quoteIds
					]
				);
	}

	private static Map<Id, Account> getPartnerAccounts(List<Quote> quotes) {
		Set<Id> partnerAccountIds = new Set<Id>();
		for (Quote quote : quotes) {
			if (quote.ELV_Partner__c != null) {
				partnerAccountIds.add(quote.ELV_Partner__c);
			}
		}

		return partnerAccountIds.isEmpty()
			? new Map<Id, Account>()
			: new Map<Id, Account>(
					[
						SELECT
							Id,
							Distributor_discount_1_9999_Endpoints__c,
							Distributor_discount_10_25k_Endpoints__c,
							Distributor_discount_25_40k_Endpoints__c,
							Distributor_discount_40K_Endpoints__c,
							Disti_Renewal_discount_1_9999_Endpoints__c,
							Disti_Renewal_discount_10_25k_Endpoints__c,
							Disti_Renewal_discount_25_40k_Endpoints__c,
							Disti_Renewal_discount_40K_Endpoints__c
						FROM Account
						WHERE Id IN :partnerAccountIds
					]
				);
	}

	private static Map<String, List<Tanium_Partner_Discount__c>> getPartnerDiscountRowsByKey(
		List<QuoteLineItem> quoteLines,
		Map<Id, Quote> quotesById
	) {
		Set<String> partnerLevels = new Set<String>();
		Set<String> programBuckets = new Set<String>();
		Set<String> productGroups = new Set<String>();
		Set<String> matrixLineTypes = new Set<String>();
		Set<Boolean> incumbentValues = new Set<Boolean>();
		Date minEffectiveDate;
		Date maxEffectiveDate;

		for (QuoteLineItem quoteLine : quoteLines) {
			Quote quote = quotesById.get(quoteLine.QuoteId);
			String matrixLineType = getMatrixLineType(quoteLine, quote);
			if (!hasCompletePartnerDiscountContext(quoteLine, quote, matrixLineType)) {
				continue;
			}

			partnerLevels.add(quote.ELV_Partner_Program_Tier__c);
			programBuckets.add(quote.ELV_Partner_Program_Bucket__c);
			productGroups.add(quoteLine.ELV_Product_Group__c);
			matrixLineTypes.add(matrixLineType);
			incumbentValues.add(quote.ELV_Partner_is_Incumbent__c);

			Date effectiveDate = getEffectiveDate(quoteLine);
			if (minEffectiveDate == null || effectiveDate < minEffectiveDate) {
				minEffectiveDate = effectiveDate;
			}
			if (maxEffectiveDate == null || effectiveDate > maxEffectiveDate) {
				maxEffectiveDate = effectiveDate;
			}
		}

		Map<String, List<Tanium_Partner_Discount__c>> rowsByKey = new Map<String, List<Tanium_Partner_Discount__c>>();
		if (
			partnerLevels.isEmpty() ||
			programBuckets.isEmpty() ||
			productGroups.isEmpty() ||
			matrixLineTypes.isEmpty() ||
			incumbentValues.isEmpty() ||
			minEffectiveDate == null ||
			maxEffectiveDate == null
		) {
			return rowsByKey;
		}

		for (Tanium_Partner_Discount__c partnerDiscount : [
			SELECT
				Id,
				Partner_Level__c,
				Program_Bucket__c,
				Product_Group__c,
				Quote_Line_Type__c,
				Partner_is_Incumbent__c,
				Start_Date__c,
				End_Date__c,
				Total_Discount__c
			FROM Tanium_Partner_Discount__c
			WHERE Active__c = TRUE
			AND Partner_Level__c IN :partnerLevels
			AND Program_Bucket__c IN :programBuckets
			AND Product_Group__c IN :productGroups
			AND Quote_Line_Type__c IN :matrixLineTypes
			AND Partner_is_Incumbent__c IN :incumbentValues
			AND (Start_Date__c = NULL OR Start_Date__c <= :maxEffectiveDate)
			AND (End_Date__c = NULL OR End_Date__c >= :minEffectiveDate)
			ORDER BY Start_Date__c DESC NULLS LAST, End_Date__c ASC NULLS LAST, CreatedDate DESC
		]) {
			String key = partnerDiscountKey(
				partnerDiscount.Partner_Level__c,
				partnerDiscount.Program_Bucket__c,
				partnerDiscount.Product_Group__c,
				partnerDiscount.Quote_Line_Type__c,
				partnerDiscount.Partner_is_Incumbent__c
			);
			if (!rowsByKey.containsKey(key)) {
				rowsByKey.put(key, new List<Tanium_Partner_Discount__c>());
			}
			rowsByKey.get(key).add(partnerDiscount);
		}

		return rowsByKey;
	}

	private static Tanium_Partner_Discount__c getPartnerDiscountRow(
		QuoteLineItem quoteLine,
		Quote quote,
		String matrixLineType,
		Map<String, List<Tanium_Partner_Discount__c>> partnerDiscountRowsByKey
	) {
		String key = partnerDiscountKey(
			quote.ELV_Partner_Program_Tier__c,
			quote.ELV_Partner_Program_Bucket__c,
			quoteLine.ELV_Product_Group__c,
			matrixLineType,
			quote.ELV_Partner_is_Incumbent__c
		);
		List<Tanium_Partner_Discount__c> partnerDiscountRows = partnerDiscountRowsByKey.get(
			key
		);
		if (partnerDiscountRows == null || partnerDiscountRows.isEmpty()) {
			return null;
		}

		Date effectiveDate = getEffectiveDate(quoteLine);
		for (Tanium_Partner_Discount__c partnerDiscount : partnerDiscountRows) {
			if (isEffective(partnerDiscount, effectiveDate)) {
				return partnerDiscount;
			}
		}

		return null;
	}

	private static Boolean hasCompletePartnerDiscountContext(
		QuoteLineItem quoteLine,
		Quote quote,
		String matrixLineType
	) {
		return quoteLine != null &&
			quote != null &&
			String.isNotBlank(quoteLine.ELV_Product_Group__c) &&
			String.isNotBlank(matrixLineType) &&
			String.isNotBlank(quote.ELV_Partner_Program_Tier__c) &&
			String.isNotBlank(quote.ELV_Partner_Program_Bucket__c) &&
			quote.ELV_Partner_is_Incumbent__c != null;
	}

	private static Boolean hasMinimumDistributorContext(
		QuoteLineItem quoteLine,
		Quote quote,
		String matrixLineType
	) {
		return quoteLine != null &&
			quote != null &&
			String.isNotBlank(quoteLine.ELV_Product_Group__c) &&
			String.isNotBlank(matrixLineType);
	}

	private static Boolean isDistributorEligible(QuoteLineItem quoteLine, Quote quote) {
		return quote.ELV_Eligible_for_Distributor_Discount__c == true &&
			quote.ELV_Partner__c != null &&
			quote.ELV_Downstream_Reseller__c != null &&
			quoteLine.ELV_Product_Group__c == PRODUCT_GROUP_SOFTWARE &&
			quote.ELV_Business_Motion_Oppty__c != BUSINESS_MOTION_MSP &&
			quote.ELV_Marketplace_Partner__c != true;
	}

	private static Boolean isChannelDiscountQuoteStatus(Quote quote) {
		return quote != null &&
			(getChannelDiscountQuoteStatuses().contains(quote.Status) ||
			isMigratedQuoteEligibleForChannelDiscounts(quote));
	}

	private static Set<String> getChannelDiscountQuoteStatuses() {
		return new Set<String>{ QUOTE_STATUS_DRAFT, QUOTE_STATUS_NEEDS_REVIEW };
	}

	private static Boolean isMigratedQuoteEligibleForChannelDiscounts(Quote quote) {
		return quote.ELV_Quote_Migrated_Record__c == true &&
			String.isNotBlank(quote.ELV_Quote_Migration_External_Id__c);
	}

	@TestVisible
	private static String getMatrixLineType(QuoteLineItem quoteLine, Quote quote) {
		if (quoteLine == null) {
			return null;
		}

		if (
			String.isBlank(quoteLine.Ruby__ChangeType__c) ||
			quoteLine.Ruby__ChangeType__c == CHANGE_TYPE_NEW_PRODUCT
		) {
			return quote != null && quote.ELV_New_Opportunity_Type__c == true
				? MATRIX_LINE_TYPE_NEW_CUSTOMER
				: MATRIX_LINE_TYPE_UPSELL;
		}
		if (quoteLine.Ruby__ChangeType__c == CHANGE_TYPE_UPDATE_QUANTITY) {
			return MATRIX_LINE_TYPE_ADD_ON;
		}
		if (
			quoteLine.Ruby__ChangeType__c == CHANGE_TYPE_RENEW ||
			quoteLine.Ruby__ChangeType__c == CHANGE_TYPE_RENEW_WITH_QUANTITY_UPDATE
		) {
			return MATRIX_LINE_TYPE_RENEWAL;
		}

		return null;
	}

	@TestVisible
	private static Decimal getDistributorDiscountRate(
		Account partnerAccount,
		Decimal endpointCount,
		Boolean useRenewalRate
	) {
		if (partnerAccount == null || endpointCount == null) {
			return null;
		}

		if (endpointCount <= ENDPOINT_BAND_9999_MAX) {
			return useRenewalRate
				? partnerAccount.Disti_Renewal_discount_1_9999_Endpoints__c
				: partnerAccount.Distributor_discount_1_9999_Endpoints__c;
		}
		if (endpointCount < ENDPOINT_BAND_25K_MIN) {
			return useRenewalRate
				? partnerAccount.Disti_Renewal_discount_10_25k_Endpoints__c
				: partnerAccount.Distributor_discount_10_25k_Endpoints__c;
		}
		if (endpointCount < ENDPOINT_BAND_40K_MIN) {
			return useRenewalRate
				? partnerAccount.Disti_Renewal_discount_25_40k_Endpoints__c
				: partnerAccount.Distributor_discount_25_40k_Endpoints__c;
		}

		return useRenewalRate
			? partnerAccount.Disti_Renewal_discount_40K_Endpoints__c
			: partnerAccount.Distributor_discount_40K_Endpoints__c;
	}

	private static Date getEffectiveDate(QuoteLineItem quoteLine) {
		return quoteLine.Ruby__SubscriptionStartDate__c == null
			? Date.today()
			: quoteLine.Ruby__SubscriptionStartDate__c;
	}

	private static Boolean isEffective(
		Tanium_Partner_Discount__c partnerDiscount,
		Date effectiveDate
	) {
		return (partnerDiscount.Start_Date__c == null ||
			partnerDiscount.Start_Date__c <= effectiveDate) &&
			(partnerDiscount.End_Date__c == null ||
			partnerDiscount.End_Date__c >= effectiveDate);
	}

	private static String partnerDiscountKey(
		String partnerLevel,
		String programBucket,
		String productGroup,
		String matrixLineType,
		Boolean partnerIsIncumbent
	) {
		return String.join(
			new List<String>{
				partnerLevel,
				programBucket,
				productGroup,
				matrixLineType,
				String.valueOf(partnerIsIncumbent)
			},
			'|'
		);
	}

	/**
	 * TNCI 139 / ELV-CPQ-036. Stores Product2.Exclude_from_ARR__c on the line so
	 * ELV_ARR_Amount__c can stop reaching through the product relationship - a cross-object
	 * formula cannot be summarized or filtered by a quote roll-up, a stored checkbox can.
	 *
	 * Called from before insert and before update, so the assignment costs no DML.
	 */
	/**
	 * TNCI-139 / ELV-CPQ-036. Twins Product2.Quota_Retirement_Eligible__c onto the line, the
	 * same twinning CPQ performs on SBQQ__QuoteLine__c.Quota_Retirement_Eligible__c. The flag
	 * gates ELV_Quota_Retirement_ARR__c, so it must be stamped before that formula is read.
	 */
	public static void stampQuotaRetirementEligible(
		List<QuoteLineItem> quoteLines,
		Map<Id, QuoteLineItem> oldMap
	) {
		if (quoteLines == null || quoteLines.isEmpty()) {
			return;
		}

		List<QuoteLineItem> linesToStamp = new List<QuoteLineItem>();
		Set<Id> productIds = new Set<Id>();

		for (QuoteLineItem quoteLine : quoteLines) {
			QuoteLineItem oldQuoteLine = oldMap == null ? null : oldMap.get(quoteLine.Id);

			// Only a product change can invalidate a stamp that is already present.
			if (oldQuoteLine != null && quoteLine.Product2Id == oldQuoteLine.Product2Id) {
				continue;
			}

			linesToStamp.add(quoteLine);
			if (quoteLine.Product2Id != null) {
				productIds.add(quoteLine.Product2Id);
			}
		}

		if (linesToStamp.isEmpty()) {
			return;
		}

		Map<Id, Product2> productsById = productIds.isEmpty()
			? new Map<Id, Product2>()
			: new Map<Id, Product2>(
					[
						SELECT Id, Quota_Retirement_Eligible__c
						FROM Product2
						WHERE Id IN :productIds
					]
				);

		for (QuoteLineItem quoteLine : linesToStamp) {
			Product2 product = productsById.get(quoteLine.Product2Id);
			quoteLine.ELV_Quota_Retirement_Eligible__c =
				product != null && product.Quota_Retirement_Eligible__c == true;
		}
	}

	public static void stampProductGroup(
		List<QuoteLineItem> quoteLines,
		Map<Id, QuoteLineItem> oldMap
	) {
		if (quoteLines == null || quoteLines.isEmpty()) {
			return;
		}

		List<QuoteLineItem> linesToStamp = new List<QuoteLineItem>();
		Set<Id> productIds = new Set<Id>();

		for (QuoteLineItem quoteLine : quoteLines) {
			QuoteLineItem oldQuoteLine = oldMap == null ? null : oldMap.get(quoteLine.Id);

			if (
				oldQuoteLine != null &&
				quoteLine.Product2Id != null &&
				quoteLine.Product2Id == oldQuoteLine.Product2Id &&
				quoteLine.ELV_Product_Group__c == oldQuoteLine.ELV_Product_Group__c &&
				String.isNotBlank(quoteLine.ELV_Product_Group__c)
			) {
				continue;
			}

			linesToStamp.add(quoteLine);
			if (quoteLine.Product2Id != null) {
				productIds.add(quoteLine.Product2Id);
			}
		}

		if (linesToStamp.isEmpty()) {
			return;
		}

		Map<Id, Product2> productsById = productIds.isEmpty()
			? new Map<Id, Product2>()
			: new Map<Id, Product2>(
					[
						SELECT
							Id,
							Product_Group__c,
							Ruby__OriginalProduct__c,
							Ruby__OriginalProduct__r.Product_Group__c
						FROM Product2
						WHERE Id IN :productIds
					]
				);

		for (QuoteLineItem quoteLine : linesToStamp) {
			Product2 product = quoteLine.Product2Id == null
				? null
				: productsById.get(quoteLine.Product2Id);
			quoteLine.ELV_Product_Group__c = resolveProductGroupStamp(product);
		}
	}

	public static void stampProductExcludeFromARR(
		List<QuoteLineItem> quoteLines,
		Map<Id, QuoteLineItem> oldMap
	) {
		if (quoteLines == null || quoteLines.isEmpty()) {
			return;
		}

		List<QuoteLineItem> linesToStamp = new List<QuoteLineItem>();
		Set<Id> productIds = new Set<Id>();

		for (QuoteLineItem quoteLine : quoteLines) {
			QuoteLineItem oldQuoteLine = oldMap == null ? null : oldMap.get(quoteLine.Id);

			// On update the product is the only thing that can invalidate the stamp. A manual
			// value is left alone unless the line was reparented, or was never stamped.
			if (
				oldQuoteLine != null &&
				quoteLine.Product2Id == oldQuoteLine.Product2Id &&
				quoteLine.ELV_Product_Exclude_from_ARR__c != null
			) {
				continue;
			}

			linesToStamp.add(quoteLine);
			if (quoteLine.Product2Id != null) {
				productIds.add(quoteLine.Product2Id);
			}
		}

		if (linesToStamp.isEmpty()) {
			return;
		}

		Map<Id, Product2> productsById = productIds.isEmpty()
			? new Map<Id, Product2>()
			: new Map<Id, Product2>(
					[SELECT Id, Exclude_from_ARR__c FROM Product2 WHERE Id IN :productIds]
				);

		for (QuoteLineItem quoteLine : linesToStamp) {
			Product2 product = quoteLine.Product2Id == null
				? null
				: productsById.get(quoteLine.Product2Id);

			// Never null. A null checkbox reads as false in a formula but reports as blank.
			quoteLine.ELV_Product_Exclude_from_ARR__c = product == null
				? false
				: product.Exclude_from_ARR__c == true;
		}
	}

	public static String resolveProductGroupStamp(Product2 product) {
		if (product == null) {
			return null;
		}

		if (product.Ruby__OriginalProduct__c == null) {
			return product.Product_Group__c;
		}

		return product.Ruby__OriginalProduct__r == null
			? null
			: product.Ruby__OriginalProduct__r.Product_Group__c;
	}

	/** TNCI 139 / ELV-CPQ-036. Line-local deterministic replacement for testing the lookup. */
	public static void stampHasTaniumPricingSchedule(List<QuoteLineItem> quoteLines) {
		if (quoteLines == null) return;
		for (QuoteLineItem line : quoteLines) {
			line.ELV_Has_Tanium_Pricing_Schedule__c = line.ELV_Tanium_Pricing_Schedule__c != null;
		}
	}

	/** TNCI-139 / ELV-CPQ-036. Deterministic line-local renewal predicate for roll-ups. */
	public static void stampIsRenewalTransaction(List<QuoteLineItem> quoteLines) {
		if (quoteLines == null) return;
		for (QuoteLineItem line : quoteLines) {
			line.ELV_Is_Renewal_Transaction__c = line.Ruby__ChangeType__c != null && line.Ruby__ChangeType__c.contains('Renew');
		}
	}

	public static void stampRenewalCustomerDiscountWithUplift(List<QuoteLineItem> quoteLines) {
		if (quoteLines == null) return;

		for (QuoteLineItem line : quoteLines) {
			if (!isRenewalWithUpliftCustomerDiscountLine(line)) {
				continue;
			}

			Decimal priorDiscount = line.ELV_Customer_Discount__c == null
				? 0
				: line.ELV_Customer_Discount__c;
			Decimal uplift = line.ELV_RenewalUpliftPercent__c == null
				? 0
				: line.ELV_RenewalUpliftPercent__c;

			Decimal adjustedNetFactor = (1 - priorDiscount / 100) *
				(1 + uplift / 100);
			line.ELV_Customer_Discount__c = ((1 - adjustedNetFactor) * 100).setScale(2);
		}
	}

	private static Boolean isRenewalWithUpliftCustomerDiscountLine(QuoteLineItem line) {
		return line != null &&
			!hasZeroRenewalUpliftOverride(line) &&
			(line.Ruby__ChangeType__c == CHANGE_TYPE_RENEW ||
			line.Ruby__ChangeType__c == CHANGE_TYPE_RENEW_WITH_QUANTITY_UPDATE);
	}

	private static Boolean hasZeroRenewalUpliftOverride(QuoteLineItem line) {
		Decimal uplift = line.ELV_RenewalUpliftPercent__c == null
			? 0
			: line.ELV_RenewalUpliftPercent__c;

		return line.ELV_Renewal_Uplift_Override__c == true && uplift == 0;
	}

	public static void populateChangedSubscription(List<QuoteLineItem> quoteLines) {
		System.debug(
			LoggingLevel.INFO,
			'ELV_QuoteLineTriggerUtility.populateChangedSubscription started. QuoteLineItem count=' +
				quoteLines.size()
		);

		Map<String, List<QuoteLineItem>> subscriptionNameToQuoteLines = getSubscriptionNameToQuoteLines(
			quoteLines
		);

		if (subscriptionNameToQuoteLines.isEmpty()) {
			System.debug(
				LoggingLevel.INFO,
				'ELV_QuoteLineTriggerUtility.populateChangedSubscription found no eligible subscription quote lines.'
			);
			return;
		}

		System.debug(
			LoggingLevel.INFO,
			'ELV_QuoteLineTriggerUtility.populateChangedSubscription querying Ruby subscriptions for names=' +
				subscriptionNameToQuoteLines.keySet()
		);

		Map<String, Ruby__Subscription__c> subscriptionNameToSub = getSubscriptionNameToSubscription(
			subscriptionNameToQuoteLines.keySet()
		);
		for (String subscriptionName : subscriptionNameToQuoteLines.keySet()) {
			Ruby__Subscription__c sub = subscriptionNameToSub.get(subscriptionName);
			if (sub == null) {
				System.debug(
					LoggingLevel.INFO,
					'ELV_QuoteLineTriggerUtility.populateChangedSubscription found no Ruby subscription for name=' +
						subscriptionName
				);
				continue;
			}

			for (QuoteLineItem quoteLine : subscriptionNameToQuoteLines.get(subscriptionName)) {
				quoteLine.ELV_Changed_Subscription__c = sub.Id;
				if (sub.ELV_Supported_Asset__c != null) {
					quoteLine.ELV_Supported_Hardware_Line_Asset__c = sub.ELV_Supported_Asset__c;
				}
				System.debug(
					LoggingLevel.INFO,
					'ELV_QuoteLineTriggerUtility.populateChangedSubscription stamped QuoteLineItem. ' +
						'Ruby subscription Id=' +
						sub.Id +
						', Supported Asset Id=' +
						sub.ELV_Supported_Asset__c
				);
			}
		}
	}

	private static Set<Id> getQuoteIdsWithQualifyingChange(
		List<QuoteLineItem> quoteLines,
		Map<Id, QuoteLineItem> oldMap
	) {
		Set<Id> quoteIds = new Set<Id>();
		if (quoteLines == null || quoteLines.isEmpty()) {
			return quoteIds;
		}

		for (QuoteLineItem quoteLine : quoteLines) {
			QuoteLineItem oldQuoteLine = oldMap == null ? null : oldMap.get(quoteLine.Id);
			if (
				quoteLine.QuoteId != null &&
				oldQuoteLine != null &&
				hasRefreshQualifyingChange(quoteLine, oldQuoteLine)
			) {
				quoteIds.add(quoteLine.QuoteId);
			}
		}

		return quoteIds;
	}

	/**
	 * TNCI 139 / ELV-CPQ-036. The Day 1 ARR start date cascade on the quote is a formula over
	 * roll-up summaries, and a roll-up recalculated by a child change raises no update event on
	 * the parent - so the Quote after-update stamp never fires on its own. Touching the quote
	 * from here is what makes the event arrive.
	 *
	 * Only fields feeding the cascade or its roll-up filters qualify. Note what is absent:
	 * ELV_Day_1_ARR_Start_Date_Stamp__c itself. The helper writes that field, which would fire
	 * this trigger, which would touch the quote again - and the helper's re-entrancy flag guards
	 * the quote side only, so the cycle has to be refused here.
	 */
	@TestVisible
	private static Boolean hasRefreshQualifyingChange(
		QuoteLineItem quoteLine,
		QuoteLineItem oldQuoteLine
	) {
		return quoteLine.Ruby__SubscriptionStartDate__c != oldQuoteLine.Ruby__SubscriptionStartDate__c ||
			quoteLine.Ruby__ChangeType__c != oldQuoteLine.Ruby__ChangeType__c ||
			quoteLine.Ruby__LineType__c != oldQuoteLine.Ruby__LineType__c ||
			quoteLine.Ruby__ActualQuantity__c != oldQuoteLine.Ruby__ActualQuantity__c ||
			quoteLine.ELV_Exclude_from_ARR__c != oldQuoteLine.ELV_Exclude_from_ARR__c ||
			quoteLine.ELV_Product_Exclude_from_ARR__c != oldQuoteLine.ELV_Product_Exclude_from_ARR__c ||
			quoteLine.ELV_Is_Cloned_Quote_Line__c != oldQuoteLine.ELV_Is_Cloned_Quote_Line__c;
	}

	@TestVisible
	private static Map<String, List<QuoteLineItem>> getSubscriptionNameToQuoteLines(
		List<QuoteLineItem> quoteLines
	) {
		Map<String, List<QuoteLineItem>> subscriptionNameToQuoteLines = new Map<String, List<QuoteLineItem>>();

		for (QuoteLineItem quoteLine : quoteLines) {
			System.debug(
				LoggingLevel.INFO,
				'ELV_QuoteLineTriggerUtility evaluating QuoteLineItem before insert. Id=' +
					quoteLine.Id +
					', Ruby__LineType__c=' +
					quoteLine.Ruby__LineType__c +
					', Ruby__ChangeAssetType__c=' +
					quoteLine.Ruby__ChangeAssetType__c +
					', Ruby__ChangeAssetId__c=' +
					quoteLine.Ruby__ChangeAssetId__c +
					', ELV_Changed_Subscription__c=' +
					quoteLine.ELV_Changed_Subscription__c +
					', ELV_Supported_Hardware_Line_Asset__c=' +
					quoteLine.ELV_Supported_Hardware_Line_Asset__c
			);

			if (!isSubscriptionSummaryItem(quoteLine)) {
				continue;
			}

			String subscriptionName = getSubscriptionName(quoteLine.Ruby__ChangeAssetId__c);
			System.debug(
				LoggingLevel.INFO,
				'ELV_QuoteLineTriggerUtility parsed subscription name=' +
					subscriptionName +
					' from Ruby__ChangeAssetId__c=' +
					quoteLine.Ruby__ChangeAssetId__c
			);
			if (String.isBlank(subscriptionName)) {
				continue;
			}

			if (!subscriptionNameToQuoteLines.containsKey(subscriptionName)) {
				subscriptionNameToQuoteLines.put(subscriptionName, new List<QuoteLineItem>());
			}
			subscriptionNameToQuoteLines.get(subscriptionName).add(quoteLine);
		}
		return subscriptionNameToQuoteLines;
	}

	@TestVisible
	private static String getSubscriptionName(String changeAssetId) {
		if (String.isBlank(changeAssetId)) {
			return null;
		}

		String trimmedChangeAssetId = changeAssetId.trim();
		Integer versionSeparatorIndex = trimmedChangeAssetId.lastIndexOf(VERSION_SEPARATOR);
		if (versionSeparatorIndex <= 0) {
			return trimmedChangeAssetId;
		}

		return trimmedChangeAssetId.substring(0, versionSeparatorIndex);
	}

	private static Boolean isSubscriptionSummaryItem(QuoteLineItem quoteLine) {
		return quoteLine.Ruby__LineType__c == SUMMARY_ITEM_LINE_TYPE &&
			quoteLine.Ruby__ChangeAssetType__c == SUBSCRIPTION_CHANGE_ASSET_TYPE &&
			String.isNotBlank(quoteLine.Ruby__ChangeAssetId__c);
	}

	private static Map<String, Ruby__Subscription__c> getSubscriptionNameToSubscription(
		Set<String> subscriptionNames
	) {
		Map<String, Ruby__Subscription__c> subscriptionNameToSub = new Map<String, Ruby__Subscription__c>();
		for (Ruby__Subscription__c sub : [
			SELECT Id, Name, ELV_Supported_Asset__c
			FROM Ruby__Subscription__c
			WHERE Name IN :subscriptionNames
		]) {
			subscriptionNameToSub.put(sub.Name, sub);
		}
		return subscriptionNameToSub;
	}
}