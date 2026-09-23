/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Tests for ELV_QuoteLineRollupHelper.
 *
 * The aggregation is exercised against in-memory QuoteLineItem records built with
 * JSON.deserialize, because several filter fields cannot be assigned directly: some are
 * formula fields (ELV_LicenseMetric__c, ELV_Product_Promotion_Name__c) and several specs
 * filter on the parent product (Product2.Product_Type__c and friends), which is a related
 * record rather than a field on the line. The line() helper below nests a Product2 so the
 * parent hops in ELV_QuoteLineRollupHelper.readPath resolve.
 */
@IsTest
private class ELV_QuoteLineRollupHelperTest {
	private static Id fakeQuoteId = Quote.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA';

	/**
	 * Builds a QuoteLineItem carrying formula and managed fields that cannot be set
	 * through the constructor.
	 */
	private static QuoteLineItem line(Map<String, Object> values) {
		Map<String, Object> record = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
			'QuoteId' => fakeQuoteId
		};
		Map<String, Object> product = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'Product2' }
		};

		// Keys written as 'Product2.Field__c' are nested onto the parent product, so the
		// specs that filter on the product read the same shape they see in production.
		for (String key : values.keySet()) {
			if (key.startsWith('Product2.')) {
				product.put(key.substringAfter('Product2.'), values.get(key));
			} else {
				record.put(key, values.get(key));
			}
		}
		if (product.size() > 1) {
			record.put('Product2', product);
		}

		return (QuoteLineItem) JSON.deserialize(JSON.serialize(record), QuoteLineItem.class);
	}

	@IsTest
	static void sumsQuantityForSkuMatches() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'TAN-PREM-ESR-PGA', 'Ruby__ActualQuantity__c' => 10 }),
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'TAN-PREM-ESR-PGA', 'Ruby__ActualQuantity__c' => 5 }),
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'SOMETHING-ELSE', 'Ruby__ActualQuantity__c' => 99 })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(15, result.get(fakeQuoteId).get('ELV_TotalPGA__c'), 'Sum should cover only matching SKUs.');
	}

	@IsTest
	static void countsLinesRatherThanUnits() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'TAN-TRN-TIER1BUNDLE', 'Ruby__ActualQuantity__c' => 40 }),
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'TAN-TRN-TIER1BUNDLE', 'Ruby__ActualQuantity__c' => 60 })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(
			2,
			result.get(fakeQuoteId).get('ELV_CountTANTRNTIER1BUNDLE__c'),
			'Count specs count lines, not quantity.'
		);
	}

	@IsTest
	static void matchesAnyValueInAMultiValueList() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'ELV_Product_Code__c' => 'TAN-CORE-OT-CLOUD', 'Ruby__ActualQuantity__c' => 3 }),
			line(new Map<String, Object>{ 'ELV_Product_Code__c' => 'TAN-EXPMGMT-OT-S', 'Ruby__ActualQuantity__c' => 4 }),
			line(new Map<String, Object>{ 'ELV_Product_Code__c' => 'TAN-EMM-CLOUD', 'Ruby__ActualQuantity__c' => 7 })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(
			7,
			result.get(fakeQuoteId).get('ELV_SUMOTSatelliteSKUs__c'),
			'Both OT satellite SKUs should be summed.'
		);
		System.assertEquals(
			7,
			result.get(fakeQuoteId).get('ELV_SUMTANEMMCLOUD__c'),
			'The EMM Cloud line should be summed by its own spec.'
		);
	}

	@IsTest
	static void matchesPicklistListAsSeparateValues() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'Product2.Product_Type__c' => 'Subscription', 'Ruby__ActualQuantity__c' => 2 }),
			line(new Map<String, Object>{ 'Product2.Product_Type__c' => 'Perpetual', 'Ruby__ActualQuantity__c' => 3 }),
			line(new Map<String, Object>{ 'Product2.Product_Type__c' => 'TaaS', 'Ruby__ActualQuantity__c' => 9 })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(
			5,
			result.get(fakeQuoteId).get('ELV_CountProductTypeSubPerpetual__c'),
			'"Subscription, Perpetual" is a two-value list, not one literal value.'
		);
		System.assertEquals(
			1,
			result.get(fakeQuoteId).get('ELV_CountProductTypeTaniumCloud__c'),
			'TaaS lines feed the Tanium Cloud count.'
		);
	}

	@IsTest
	static void matchesSubstringForContainsSpecs() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'TAN-CORE-CONVERSION-CLOUDGOV-US', 'Ruby__ActualQuantity__c' => 1 })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(
			1,
			result.get(fakeQuoteId).get('ELV_CountCloudGovSKUs__c'),
			'CONVERSION-CLOUDGOV-US is a substring match.'
		);
		System.assertEquals(
			1,
			result.get(fakeQuoteId).get('ELV_CountCONVERSIONCLOUDSKU__c'),
			'CONVERSION-CLOUD is also a substring of the Gov Cloud SKU. This mirrors CPQ.'
		);
	}

	@IsTest
	static void matchesBooleanFilter() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'Product2.Is_ESR_Product__c' => true, 'Ruby__ActualQuantity__c' => 6 }),
			line(new Map<String, Object>{ 'Product2.Is_ESR_Product__c' => false, 'Ruby__ActualQuantity__c' => 100 })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(6, result.get(fakeQuoteId).get('ELV_SumESRProduct__c'), 'Only ESR lines count.');
	}

	@IsTest
	static void matchesFormulaFilterFields() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'ELV_LicenseMetric__c' => 'Managed OS', 'Ruby__ActualQuantity__c' => 8 }),
			line(new Map<String, Object>{ 'ELV_LicenseMetric__c' => 'Active User', 'Ruby__ActualQuantity__c' => 2 }),
			line(new Map<String, Object>{ 'ELV_Product_Promotion_Name__c' => 'FOC', 'Ruby__ActualQuantity__c' => 4 })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(8, result.get(fakeQuoteId).get('ELV_CountLicenseMetricManageOS__c'), 'Managed OS lines.');
		System.assertEquals(2, result.get(fakeQuoteId).get('ELV_CountLicenseMetricActiveUser__c'), 'Active User lines.');
		System.assertEquals(4, result.get(fakeQuoteId).get('ELV_SumPromoFOC__c'), 'FOC promo lines.');
	}

	@IsTest
	static void countsEveryLineForTheUnfilteredSpec() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'A' }),
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'B' }),
			line(new Map<String, Object>{ 'Ruby__ProductSKU__c' => 'C' })
		};

		Map<Id, Map<String, Decimal>> result = ELV_QuoteLineRollupHelper.aggregate(lines);

		System.assertEquals(
			3,
			result.get(fakeQuoteId).get('ELV_SumEffectiveQuantity__c'),
			'The unfiltered spec counts every line on the quote.'
		);
	}

	@IsTest
	static void stampsZeroWhenNothingMatches() {
		Quote q = new Quote();

		Test.startTest();
		ELV_QuoteLineRollupHelper.stampLineRollups(new List<Quote>{ q });
		Test.stopTest();

		System.assertEquals(0, q.get('ELV_TotalPGA__c'), 'Sum fields default to zero, never null.');
		System.assertEquals(0, q.get('ELV_CountProductLineAppliance__c'), 'Count fields default to zero.');
	}

	@IsTest
	static void handlesEmptyAndNullInput() {
		System.assertEquals(null, ELV_QuoteLineRollupHelper.stampLineRollups(null), 'Null in, null out.');
		System.assert(
			ELV_QuoteLineRollupHelper.refreshAndSave(new Set<Id>()).isEmpty(),
			'An empty id set does no work.'
		);
		ELV_QuoteLineRollupHelper.refreshQuoteLineRollups(null);
	}

	@IsTest
	static void queriesEveryFieldTheSpecsRead() {
		Set<String> fields = ELV_QuoteLineRollupHelper.lineFieldsToQuery();

		System.assert(fields.contains('QuoteId'), 'Grouping needs QuoteId.');
		System.assert(fields.contains('Ruby__ProductSKU__c'), 'SKU filters are queried.');
		System.assert(fields.contains('ELV_LicenseMetric__c'), 'The new License Metric formula is queried.');
		System.assert(fields.contains('Ruby__ActualQuantity__c'), 'The quantity field is queried.');
	}

	/*
	 * NOTE: there is deliberately no end-to-end DML test.
	 *
	 * Inserting a Product2 in this org fails the Nue managed package's "Please enter a
	 * product category" check, and ELV_NueTestFactory cannot be compiled against while
	 * Ruby.OrderItemService is in an invalid state. The aggregation, matching and stamping
	 * are covered above against in-memory records; refreshAndSave is a thin query-and-save
	 * wrapper around stampLineRollups.
	 */
}