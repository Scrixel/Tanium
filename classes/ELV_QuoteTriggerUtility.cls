/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Utility for the standard Quote trigger.
 */
public with sharing class ELV_QuoteTriggerUtility {
	@TestVisible
	private static final String DEPLOYMENT_TYPE_ON_PREM = 'OnPrem';
	@TestVisible
	private static final String DEPLOYMENT_TYPE_CLOUD = 'Cloud';
	@TestVisible
	private static final String DEPLOYMENT_TYPE_HYBRID = 'Hybrid';
	@TestVisible
	private static final String DEPLOYMENT_TYPE_GOV_CLOUD = 'Tanium Cloud for US Government';
	private static final String DEPLOYMENT_METHOD_ON_PREM_LINE = 'On-Prem';
	private static final String LINE_TYPE_LINE_ITEM = 'LineItem';
	private static final String LINE_TYPE_RAMP_ITEM = 'RampItem';
	private static final String QUOTE_STATUS_DRAFT = 'Draft';
	private static final String QUOTE_STATUS_NEEDS_REVIEW = 'Needs Review';
	private static final String GOV_CLOUD_SKU_TEXT = '-CLOUDGOV';
	private static final String GOV_CLOUD_US_SKU_TEXT = '-CLOUDGOV-US';
	private static final String HUNTIQ_SKU_TEXT = 'HUNTIQ';

	@TestVisible
	private static final String COST_TYPE_SUPPORT = 'Support';
	@TestVisible
	private static final String COST_TYPE_HOSTING = 'Hosting';
	@TestVisible
	private static final String COST_TYPE_HUNTIQ = 'HuntIQ';
	@TestVisible
	private static final Decimal GOV_CLOUD_HOSTING_MULTIPLIER = 1.25;
	@TestVisible
	private static final Decimal DAY_1_ARR_DISCOUNT_HEALTH_THRESHOLD = 400000;
	@TestVisible
	private static final Decimal LOW_ARR_RED_MARGIN_THRESHOLD = 73;
	@TestVisible
	private static final Decimal LOW_ARR_GREEN_MARGIN_THRESHOLD = 85;
	@TestVisible
	private static final String FLAG_COLOR_RED = 'Red';
	@TestVisible
	private static final String FLAG_COLOR_YELLOW = 'Yellow';
	@TestVisible
	private static final String FLAG_COLOR_GREEN = 'Green';

	private class QuoteLineRollupValues {
		private Set<String> deploymentTypes = new Set<String>();
		private Decimal coreQuantity = 0;
		private Decimal govCloudFedRampProductCount = 0;
		private Decimal huntIQProductCount = 0;

		public void addDeploymentType(String deploymentType) {
			if (String.isNotBlank(deploymentType)) {
				deploymentTypes.add(deploymentType);
			}
		}

		public void addGovCloudFedRampProductCount(Decimal quantity) {
			govCloudFedRampProductCount += quantity == null ? 0 : quantity;
		}

		public void addHuntIQProductCount(Decimal quantity) {
			huntIQProductCount += quantity == null ? 0 : quantity;
		}

		public void addCoreQuantity(Decimal quantity) {
			coreQuantity += quantity == null ? 0 : quantity;
		}

		public String getDeploymentType() {
			if (deploymentTypes.isEmpty()) {
				return null;
			}

			return deploymentTypes.size() == 1
				? getOnlyValue(deploymentTypes)
				: DEPLOYMENT_TYPE_HYBRID;
		}

		public Decimal getGovCloudFedRampProductCount() {
			return govCloudFedRampProductCount;
		}

		public Decimal getHuntIQProductCount() {
			return huntIQProductCount;
		}

		public Decimal getCoreQuantity() {
			return coreQuantity;
		}
	}

	public static List<Quote> stampQuoteLineRollups(List<Quote> quotes) {
		if (quotes == null || quotes.isEmpty()) {
			return quotes;
		}

		Map<Id, QuoteLineRollupValues> quoteIdToRollups = buildQuoteLineRollups(
			getQuoteIds(quotes)
		);

		for (Quote quote : quotes) {
			QuoteLineRollupValues rollups = quoteIdToRollups.get(quote.Id);
			stampQuoteLineRollups(
				quote,
				rollups == null ? new QuoteLineRollupValues() : rollups
			);
		}

		return quotes;
	}

	public static List<Quote> getQuotesRequestedForRefresh(List<Quote> quotes) {
		List<Quote> quotesRequestedForRefresh = new List<Quote>();
		if (quotes == null || quotes.isEmpty()) {
			return quotesRequestedForRefresh;
		}

		for (Quote quote : quotes) {
			if (quote.ELV_Refresh_Quote__c == true) {
				quotesRequestedForRefresh.add(quote);
			}
		}

		return quotesRequestedForRefresh;
	}

	public static Set<Id> getQuoteIdsWithChannelDiscountInputsChanged(
		List<Quote> quotes,
		Map<Id, Quote> oldMap
	) {
		Set<Id> quoteIds = new Set<Id>();
		if (quotes == null || quotes.isEmpty() || oldMap == null) {
			return quoteIds;
		}

		for (Quote quote : quotes) {
			Quote oldQuote = oldMap.get(quote.Id);
			if (
				quote.Id != null &&
				isChannelDiscountQuoteStatus(quote) &&
				hasChannelDiscountInputChanged(quote, oldQuote)
			) {
				quoteIds.add(quote.Id);
			}
		}

		return quoteIds;
	}

	public static void clearQuoteRefreshRequest(List<Quote> quotes) {
		if (quotes == null || quotes.isEmpty()) {
			return;
		}

		for (Quote quote : quotes) {
			quote.ELV_Refresh_Quote__c = false;
		}
	}

	public static void calculateMargin(List<Quote> quotes, Map<Id, Quote> oldMap) {
		List<Quote> quotesToCalculate = getQuotesToCalculate(quotes, oldMap);
		if (quotesToCalculate.isEmpty()) {
			return;
		}

		Map<String, List<Margin_Costs__c>> costsByType = getMarginCostsByType();
		for (Quote quote : quotesToCalculate) {
			stampMarginCosts(quote, costsByType);
		}
	}

	public static void updateFlagColor(List<Quote> quotes, Map<Id, Quote> oldMap) {
		List<Quote> quotesToUpdate = getQuotesToUpdateFlagColor(quotes, oldMap);
		if (quotesToUpdate.isEmpty()) {
			return;
		}

		List<Quote_Health_Indicator_Settings__c> healthSettings = new List<Quote_Health_Indicator_Settings__c>();
		if (needsDiscountHealth(quotesToUpdate)) {
			healthSettings = getQuoteHealthIndicatorSettings();
		}

		for (Quote quote : quotesToUpdate) {
			quote.ELV_Flag_Color__c = getFlagColor(quote, healthSettings);
		}
	}

	@TestVisible
	private static List<Quote> getQuotesToCalculate(List<Quote> quotes, Map<Id, Quote> oldMap) {
		List<Quote> quotesToCalculate = new List<Quote>();
		if (quotes == null || quotes.isEmpty()) {
			return quotesToCalculate;
		}

		for (Quote quote : quotes) {
			Quote oldQuote = oldMap == null ? null : oldMap.get(quote.Id);
			if (
				oldQuote == null ||
				quote.ELV_Refresh_Quote__c == true ||
				quote.ELV_Deployment_Method__c != oldQuote.ELV_Deployment_Method__c ||
				quote.ELV_Core_Quantity__c != oldQuote.ELV_Core_Quantity__c ||
				quote.ELV_HuntIQ_Product_Count__c != oldQuote.ELV_HuntIQ_Product_Count__c ||
				quote.ELV_ARR_Margin_Override__c != oldQuote.ELV_ARR_Margin_Override__c
			) {
				quotesToCalculate.add(quote);
			}
		}

		return quotesToCalculate;
	}

	@TestVisible
	private static List<Quote> getQuotesToUpdateFlagColor(
		List<Quote> quotes,
		Map<Id, Quote> oldMap
	) {
		List<Quote> quotesToUpdate = new List<Quote>();
		if (quotes == null || quotes.isEmpty()) {
			return quotesToUpdate;
		}

		for (Quote quote : quotes) {
			Quote oldQuote = oldMap == null ? null : oldMap.get(quote.Id);
			if (hasFlagColorInputChanged(quote, oldQuote)) {
				quotesToUpdate.add(quote);
			}
		}

		return quotesToUpdate;
	}

	private static Boolean hasFlagColorInputChanged(Quote quote, Quote oldQuote) {
		return oldQuote == null ||
			quote.ELV_Day_1_ARR__c != oldQuote.ELV_Day_1_ARR__c ||
			quote.ELV_ARR_Margin__c != oldQuote.ELV_ARR_Margin__c ||
			quote.ELV_No_of_End_Points_Quote_Score__c !=
			oldQuote.ELV_No_of_End_Points_Quote_Score__c ||
			quote.Ruby__Discount__c != oldQuote.Ruby__Discount__c;
	}

	@TestVisible
	private static Boolean hasChannelDiscountInputChanged(Quote quote, Quote oldQuote) {
		return oldQuote != null &&
			(quote.Status != oldQuote.Status ||
			quote.AccountId != oldQuote.AccountId ||
			quote.ELV_Partner__c != oldQuote.ELV_Partner__c ||
			quote.ELV_Downstream_Reseller__c != oldQuote.ELV_Downstream_Reseller__c ||
			quote.ELV_Partner_Program_Tier__c != oldQuote.ELV_Partner_Program_Tier__c ||
			quote.ELV_Partner_Program_Bucket__c != oldQuote.ELV_Partner_Program_Bucket__c ||
			quote.ELV_Partner_is_Incumbent__c != oldQuote.ELV_Partner_is_Incumbent__c ||
			quote.ELV_Eligible_for_Distributor_Discount__c !=
			oldQuote.ELV_Eligible_for_Distributor_Discount__c ||
			quote.ELV_Business_Motion_Oppty__c != oldQuote.ELV_Business_Motion_Oppty__c ||
			quote.ELV_Marketplace_Partner__c != oldQuote.ELV_Marketplace_Partner__c ||
			quote.ELV_New_Opportunity_Type__c != oldQuote.ELV_New_Opportunity_Type__c ||
			quote.ELV_No_of_End_Points_Quote_Score__c !=
			oldQuote.ELV_No_of_End_Points_Quote_Score__c);
	}

	private static Boolean isChannelDiscountQuoteStatus(Quote quote) {
		return quote != null &&
			(quote.Status == QUOTE_STATUS_DRAFT ||
			quote.Status == QUOTE_STATUS_NEEDS_REVIEW);
	}

	private static Boolean needsDiscountHealth(List<Quote> quotes) {
		for (Quote quote : quotes) {
			if (
				quote.ELV_Day_1_ARR__c != null &&
				quote.ELV_Day_1_ARR__c >= DAY_1_ARR_DISCOUNT_HEALTH_THRESHOLD
			) {
				return true;
			}
		}

		return false;
	}

	@TestVisible
	private static String getFlagColor(
		Quote quote,
		List<Quote_Health_Indicator_Settings__c> healthSettings
	) {
		if (quote.ELV_Day_1_ARR__c == null) {
			return null;
		}

		if (quote.ELV_Day_1_ARR__c < DAY_1_ARR_DISCOUNT_HEALTH_THRESHOLD) {
			return getLowArrFlagColor(quote.ELV_ARR_Margin__c);
		}

		return getDiscountHealthFlagColor(
			quote.ELV_No_of_End_Points_Quote_Score__c,
			quote.Ruby__Discount__c,
			healthSettings
		);
	}

	@TestVisible
	private static String getLowArrFlagColor(Decimal arrMargin) {
		if (arrMargin == null) {
			return null;
		}

		if (arrMargin < LOW_ARR_RED_MARGIN_THRESHOLD) {
			return FLAG_COLOR_RED;
		}

		if (arrMargin <= LOW_ARR_GREEN_MARGIN_THRESHOLD) {
			return FLAG_COLOR_YELLOW;
		}

		return FLAG_COLOR_GREEN;
	}

	@TestVisible
	private static String getDiscountHealthFlagColor(
		Decimal endpoints,
		Decimal discount,
		List<Quote_Health_Indicator_Settings__c> healthSettings
	) {
		if (
			endpoints == null ||
			discount == null ||
			healthSettings == null ||
			healthSettings.isEmpty()
		) {
			return null;
		}

		for (Quote_Health_Indicator_Settings__c healthSetting : healthSettings) {
			if (matchesDiscountHealth(healthSetting, endpoints, discount)) {
				return healthSetting.Flag_Color__c;
			}
		}

		return null;
	}

	private static Boolean matchesDiscountHealth(
		Quote_Health_Indicator_Settings__c healthSetting,
		Decimal endpoints,
		Decimal discount
	) {
		return matchesLowerInclusiveRange(
				endpoints,
				healthSetting.Endpoints_Min__c,
				healthSetting.Endpoints_Max__c
			) &&
			matchesLowerInclusiveRange(
				discount,
				healthSetting.Additional_Discount_Min__c,
				healthSetting.Additional_Discount_Max__c
			);
	}

	private static Boolean matchesLowerInclusiveRange(Decimal value, Decimal min, Decimal max) {
		return value != null &&
			(min == null || value >= min) &&
			(max == null || value < max);
	}

	private static List<Quote_Health_Indicator_Settings__c> getQuoteHealthIndicatorSettings() {
		return [
			SELECT
				Endpoints_Min__c,
				Endpoints_Max__c,
				Additional_Discount_Min__c,
				Additional_Discount_Max__c,
				Flag_Color__c
			FROM Quote_Health_Indicator_Settings__c
			WHERE Volume_Discount__c = false
			ORDER BY Endpoints_Min__c, Additional_Discount_Min__c
		];
	}

	private static Set<Id> getQuoteIds(List<Quote> quotes) {
		Set<Id> quoteIds = new Set<Id>();

		for (Quote quote : quotes) {
			if (quote.Id != null) {
				quoteIds.add(quote.Id);
			}
		}

		return quoteIds;
	}

	@TestVisible
	private static Map<Id, QuoteLineRollupValues> buildQuoteLineRollups(Set<Id> quoteIds) {
		Map<Id, QuoteLineRollupValues> quoteIdToRollups = new Map<Id, QuoteLineRollupValues>();
		Set<String> rollupLineTypes = new Set<String>{ LINE_TYPE_LINE_ITEM, LINE_TYPE_RAMP_ITEM };

		if (quoteIds == null || quoteIds.isEmpty()) {
			return quoteIdToRollups;
		}

		for (QuoteLineItem quoteLine : [
			SELECT
				QuoteId,
				Quantity,
				ELV_Deployment_Method__c,
				ELV_IncludeInSeatsPurchased__c,
				Product2.ProductCode
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIds
			AND Ruby__LineType__c IN :rollupLineTypes
		]) {
			QuoteLineRollupValues rollups = getOrCreateRollups(
				quoteIdToRollups,
				quoteLine.QuoteId
			);
			String productCode = quoteLine.Product2?.ProductCode;

			rollups.addDeploymentType(
				normalizeDeploymentType(quoteLine.ELV_Deployment_Method__c)
			);

			if (isGovCloudFedRampSku(productCode)) {
				rollups.addGovCloudFedRampProductCount(quoteLine.Quantity);
			}
			if (isHuntIQSku(productCode)) {
				rollups.addHuntIQProductCount(quoteLine.Quantity);
			}
			if (quoteLine.ELV_IncludeInSeatsPurchased__c) {
				rollups.addCoreQuantity(quoteLine.Quantity);
			}
		}

		return quoteIdToRollups;
	}

	private static QuoteLineRollupValues getOrCreateRollups(
		Map<Id, QuoteLineRollupValues> quoteIdToRollups,
		Id quoteId
	) {
		if (!quoteIdToRollups.containsKey(quoteId)) {
			quoteIdToRollups.put(quoteId, new QuoteLineRollupValues());
		}

		return quoteIdToRollups.get(quoteId);
	}

	private static void stampQuoteLineRollups(
		Quote quote,
		QuoteLineRollupValues rollups
	) {
		quote.ELV_Deployment_Method__c = rollups.getDeploymentType();
		quote.ELV_Core_Quantity__c = rollups.getCoreQuantity();
		quote.ELV_GovCloud_FedRamp_Product_Count__c = rollups.getGovCloudFedRampProductCount();
		quote.ELV_HuntIQ_Product_Count__c = rollups.getHuntIQProductCount();
	}

	private static String getOnlyValue(Set<String> values) {
		for (String value : values) {
			return value;
		}

		return null;
	}

	private static String normalizeDeploymentType(String deploymentMethod) {
		if (String.isBlank(deploymentMethod)) {
			return null;
		}

		return deploymentMethod == DEPLOYMENT_METHOD_ON_PREM_LINE
			? DEPLOYMENT_TYPE_ON_PREM
			: deploymentMethod;
	}

	private static Boolean isGovCloudFedRampSku(String sku) {
		return containsIgnoreCase(sku, GOV_CLOUD_US_SKU_TEXT) ||
			containsIgnoreCase(sku, GOV_CLOUD_SKU_TEXT);
	}

	private static Boolean isHuntIQSku(String sku) {
		return containsIgnoreCase(sku, HUNTIQ_SKU_TEXT);
	}

	private static Boolean containsIgnoreCase(String value, String searchText) {
		return String.isNotBlank(value) &&
			value.toUpperCase().contains(searchText.toUpperCase());
	}

	private static Map<String, List<Margin_Costs__c>> getMarginCostsByType() {
		Set<String> costTypes = new Set<String>{
			COST_TYPE_SUPPORT,
			COST_TYPE_HOSTING,
			COST_TYPE_HUNTIQ
		};
		Map<String, List<Margin_Costs__c>> costsByType = new Map<String, List<Margin_Costs__c>>();

		for (Margin_Costs__c marginCost : [
			SELECT
				Cost_Type__c,
				Deployment_Type__c,
				ELV_Cost__c,
				Min_Endpoint_Count__c,
				Max_Endpoint_Count__c
			FROM Margin_Costs__c
			WHERE Cost_Type__c IN :costTypes
			AND ELV_Cost__c != NULL
			ORDER BY Cost_Type__c, Deployment_Type__c, Min_Endpoint_Count__c, Max_Endpoint_Count__c
		]) {
			if (!costsByType.containsKey(marginCost.Cost_Type__c)) {
				costsByType.put(marginCost.Cost_Type__c, new List<Margin_Costs__c>());
			}
			costsByType.get(marginCost.Cost_Type__c).add(marginCost);
		}

		return costsByType;
	}

	private static void stampMarginCosts(
		Quote quote,
		Map<String, List<Margin_Costs__c>> costsByType
	) {
		Decimal coreQuantity = quote.ELV_Core_Quantity__c;
		String deploymentType = quote.ELV_Deployment_Method__c;
		String marginCostDeploymentType = getMarginCostDeploymentType(deploymentType);

		Decimal supportCost;
		Decimal hostingCost;

		if (deploymentType == DEPLOYMENT_TYPE_ON_PREM) {
			supportCost = getCostForEndpointCount(
				costsByType.get(COST_TYPE_SUPPORT),
				coreQuantity,
				marginCostDeploymentType
			);
		} else if (deploymentType == DEPLOYMENT_TYPE_CLOUD) {
			supportCost = getCostForEndpointCount(
				costsByType.get(COST_TYPE_SUPPORT),
				coreQuantity,
				marginCostDeploymentType
			);
			hostingCost = getCostForEndpointCount(
				costsByType.get(COST_TYPE_HOSTING),
				coreQuantity,
				marginCostDeploymentType
			);
		} else if (deploymentType == DEPLOYMENT_TYPE_GOV_CLOUD) {
			supportCost = getCostForEndpointCount(
				costsByType.get(COST_TYPE_SUPPORT),
				coreQuantity,
				marginCostDeploymentType
			);
			hostingCost = getCostForEndpointCount(
				costsByType.get(COST_TYPE_HOSTING),
				coreQuantity,
				marginCostDeploymentType
			);
			if (hostingCost != null) {
				hostingCost *= GOV_CLOUD_HOSTING_MULTIPLIER;
			}
		} else if (deploymentType == DEPLOYMENT_TYPE_HYBRID) {
			supportCost = null;
			hostingCost = null;
		}

		quote.ELV_Support_Costs__c = supportCost;
		quote.ELV_Hosting_Costs__c = hostingCost;
		quote.ELV_HuntIQ_Costs__c = hasHuntIQProducts(quote)
			? getCostForEndpointCount(costsByType.get(COST_TYPE_HUNTIQ), coreQuantity, null)
			: null;
	}

	private static Decimal getCostForEndpointCount(
		List<Margin_Costs__c> marginCosts,
		Decimal endpointCount,
		String deploymentType
	) {
		if (marginCosts == null || marginCosts.isEmpty() || endpointCount == null) {
			return null;
		}

		for (Margin_Costs__c marginCost : marginCosts) {
			if (
				matchesDeploymentType(marginCost, deploymentType) &&
				matchesEndpointCount(marginCost, endpointCount)
			) {
				return marginCost.ELV_Cost__c;
			}
		}

		return null;
	}

	private static String getMarginCostDeploymentType(String deploymentType) {
		return deploymentType == DEPLOYMENT_TYPE_GOV_CLOUD
			? DEPLOYMENT_TYPE_CLOUD
			: deploymentType;
	}

	private static Boolean matchesDeploymentType(
		Margin_Costs__c marginCost,
		String deploymentType
	) {
		return marginCost.Deployment_Type__c == deploymentType;
	}

	private static Boolean matchesEndpointCount(
		Margin_Costs__c marginCost,
		Decimal endpointCount
	) {
		return (marginCost.Min_Endpoint_Count__c == null ||
			endpointCount >= marginCost.Min_Endpoint_Count__c) &&
			(marginCost.Max_Endpoint_Count__c == null ||
			endpointCount < marginCost.Max_Endpoint_Count__c);
	}

	private static Boolean hasHuntIQProducts(Quote quote) {
		return quote.ELV_HuntIQ_Product_Count__c != null &&
			quote.ELV_HuntIQ_Product_Count__c > 0;
	}
}