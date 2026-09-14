/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Tests for ELV_QuoteTriggerUtility.
 */
@IsTest
private class ELV_QuoteTriggerUtilityTest {
	// @IsTest
	// static void getLowArrFlagColor_UsesArrMarginThresholds() {
	// 	System.assertEquals(
	// 		'Red',
	// 		ELV_QuoteTriggerUtility.getLowArrFlagColor(72.99),
	// 		'Margins below 73 should be red.'
	// 	);
	// 	System.assertEquals(
	// 		'Yellow',
	// 		ELV_QuoteTriggerUtility.getLowArrFlagColor(73),
	// 		'Margins at 73 should be yellow.'
	// 	);
	// 	System.assertEquals(
	// 		'Yellow',
	// 		ELV_QuoteTriggerUtility.getLowArrFlagColor(85),
	// 		'Margins at 85 should be yellow.'
	// 	);
	// 	System.assertEquals(
	// 		'Green',
	// 		ELV_QuoteTriggerUtility.getLowArrFlagColor(85.01),
	// 		'Margins above 85 should be green.'
	// 	);
	// }

	// @IsTest
	// static void getDiscountHealthFlagColor_MatchesStrictSettingsRanges() {
	// 	List<Quote_Health_Indicator_Settings__c> healthSettings = new List<Quote_Health_Indicator_Settings__c>{
	// 		buildHealthSetting(1, 100, 1000, 5, 15, 'Yellow'),
	// 		buildHealthSetting(2, 1000, 5000, 15, 30, 'Green')
	// 	};

	// 	System.assertEquals(
	// 		'Yellow',
	// 		ELV_QuoteTriggerUtility.getDiscountHealthFlagColor(500, 10, healthSettings)
	// 	);
	// 	System.assertEquals(
	// 		null,
	// 		ELV_QuoteTriggerUtility.getDiscountHealthFlagColor(100, 10, healthSettings),
	// 		'Endpoint minimum is a strict greater-than match.'
	// 	);
	// 	System.assertEquals(
	// 		null,
	// 		ELV_QuoteTriggerUtility.getDiscountHealthFlagColor(500, 15, healthSettings),
	// 		'Discount maximum is a strict less-than match.'
	// 	);
	// }

	// @IsTest
	// static void getQuotesToUpdateFlagColor_ReturnsOnlyChangedInputs() {
	// 	Id changedQuoteId = Id.valueOf('0Q0000000000001');
	// 	Id unchangedQuoteId = Id.valueOf('0Q0000000000002');

	// 	Quote changedQuote = buildQuoteWithFormulaEndpoint(
	// 		changedQuoteId,
	// 		300000,
	// 		74,
	// 		null,
	// 		10
	// 	);
	// 	Quote unchangedQuote = buildQuoteWithFormulaEndpoint(
	// 		unchangedQuoteId,
	// 		300000,
	// 		74,
	// 		null,
	// 		10
	// 	);

	// 	Map<Id, Quote> oldMap = new Map<Id, Quote>{
	// 		changedQuoteId => buildQuoteWithFormulaEndpoint(
	// 			changedQuoteId,
	// 			300000,
	// 			74,
	// 			null,
	// 			5
	// 		),
	// 		unchangedQuoteId => buildQuoteWithFormulaEndpoint(
	// 			unchangedQuoteId,
	// 			300000,
	// 			74,
	// 			null,
	// 			10
	// 		)
	// 	};

	// 	List<Quote> result = ELV_QuoteTriggerUtility.getQuotesToUpdateFlagColor(
	// 		new List<Quote>{ changedQuote, unchangedQuote },
	// 		oldMap
	// 	);

	// 	System.assertEquals(1, result.size());
	// 	System.assertEquals(changedQuoteId, result[0].Id);
	// }

	// @IsTest
	// static void updateFlagColor_StampsLowArrQuotes() {
	// 	Quote quote = buildQuoteWithFormulaEndpoint(null, 250000, 86, null, 10);

	// 	ELV_QuoteTriggerUtility.updateFlagColor(new List<Quote>{ quote }, null);

	// 	System.assertEquals('Green', quote.ELV_Flag_Color__c);
	// }

	// @IsTest
	// static void updateFlagColor_QueriesHealthSettingsForHighArrQuotes() {
	// 	insert buildHealthSetting(1, 100, 1000, 5, 15, 'Yellow');

	// 	Quote quote = buildQuoteWithFormulaEndpoint(null, 400000, null, 500, 10);

	// 	Test.startTest();
	// 	ELV_QuoteTriggerUtility.updateFlagColor(new List<Quote>{ quote }, null);
	// 	Test.stopTest();

	// 	System.assertEquals('Yellow', quote.ELV_Flag_Color__c);
	// }

	// @IsTest
	// static void stampQuoteLineRollups_NoQuoteLines_StampsDefaultValues() {
	// 	Quote quote = new Quote();

	// 	ELV_QuoteTriggerUtility.stampQuoteLineRollups(new List<Quote>{ quote });

	// 	System.assertEquals(null, quote.ELV_Deployment_Method__c);
	// 	System.assertEquals(0, quote.ELV_Core_Quantity__c);
	// 	System.assertEquals(0, quote.ELV_GovCloud_FedRamp_Product_Count__c);
	// 	System.assertEquals(0, quote.ELV_HuntIQ_Product_Count__c);
	// }

	// @IsTest
	// static void stampQuoteLineRollups_SumsIncludedSeatsPurchasedLines() {
	// 	SBQQ.TriggerControl.disable();
	// 	TriggerHandler.bypass(
	// 		new List<String>{
	// 			'AccountTriggerHandler',
	// 			'OpportunityTriggerHandler',
	// 			'QuoteCPQTriggerHandler',
	// 			'QuoteLineItemTriggerHandler'
	// 		}
	// 	);

	// 	System.runAs(TestUserFactory.getAdminUser()) {
	// 		Quote quote = createTestQuote('Seats Rollup Quote');
	// 		Product2 includedProduct = createProduct(
	// 			'Included Seats Product',
	// 			'TAN-CORE-CLOUD',
	// 			true
	// 		);
	// 		Product2 excludedProduct = createProduct(
	// 			'Excluded Seats Product',
	// 			'TAN-EXCLUDED-CLOUD',
	// 			false
	// 		);
	// 		Product2 huntIQProduct = createProduct(
	// 			'HuntIQ Product',
	// 			'ELV-TAN-SUPP-HUNTIQ-CLOUD',
	// 			false
	// 		);
	// 		Product2 govCloudProduct = createProduct(
	// 			'GovCloud Product',
	// 			'TAN-CORE-STND-CLOUDGOV-US',
	// 			false
	// 		);
	// 		PricebookEntry includedPricebookEntry = createPricebookEntry(includedProduct.Id);
	// 		PricebookEntry excludedPricebookEntry = createPricebookEntry(excludedProduct.Id);
	// 		PricebookEntry huntIQPricebookEntry = createPricebookEntry(huntIQProduct.Id);
	// 		PricebookEntry govCloudPricebookEntry = createPricebookEntry(govCloudProduct.Id);

	// 		insert new List<QuoteLineItem>{
	// 			new QuoteLineItem(
	// 				QuoteId = quote.Id,
	// 				PricebookEntryId = includedPricebookEntry.Id,
	// 				Quantity = 25,
	// 				UnitPrice = 10,
	// 				ELV_Deployment_Method__c = ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD
	// 			),
	// 			new QuoteLineItem(
	// 				QuoteId = quote.Id,
	// 				PricebookEntryId = excludedPricebookEntry.Id,
	// 				Quantity = 10,
	// 				UnitPrice = 10,
	// 				ELV_Deployment_Method__c = ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD
	// 			),
	// 			new QuoteLineItem(
	// 				QuoteId = quote.Id,
	// 				PricebookEntryId = huntIQPricebookEntry.Id,
	// 				Quantity = 7,
	// 				UnitPrice = 10,
	// 				ELV_Deployment_Method__c = ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD
	// 			),
	// 			new QuoteLineItem(
	// 				QuoteId = quote.Id,
	// 				PricebookEntryId = govCloudPricebookEntry.Id,
	// 				Quantity = 12,
	// 				UnitPrice = 10,
	// 				ELV_Deployment_Method__c = ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD
	// 			)
	// 		};

	// 		Quote quoteToStamp = [SELECT Id FROM Quote WHERE Id = :quote.Id];

	// 		ELV_QuoteTriggerUtility.stampQuoteLineRollups(new List<Quote>{ quoteToStamp });

	// 		System.assertEquals(
	// 			ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD,
	// 			quoteToStamp.ELV_Deployment_Method__c
	// 		);
	// 		System.assertEquals(25, quoteToStamp.ELV_Core_Quantity__c);
	// 		System.assertEquals(12, quoteToStamp.ELV_GovCloud_FedRamp_Product_Count__c);
	// 		System.assertEquals(7, quoteToStamp.ELV_HuntIQ_Product_Count__c);
	// 	}
	// }

	// @IsTest
	// static void calculateMargin_StampsCostsByDeploymentType() {
	// 	insert new List<Margin_Costs__c>{
	// 		buildMarginCost(ELV_QuoteTriggerUtility.COST_TYPE_SUPPORT, 0, 1000, 11),
	// 		buildMarginCost(ELV_QuoteTriggerUtility.COST_TYPE_HOSTING, 0, 1000, 22),
	// 		buildMarginCost(ELV_QuoteTriggerUtility.COST_TYPE_HUNTIQ, 0, 1000, 33)
	// 	};

	// 	Quote quote = buildMarginQuote(
	// 		ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD,
	// 		500,
	// 		1
	// 	);

	// 	ELV_QuoteTriggerUtility.calculateMargin(new List<Quote>{ quote }, null);

	// 	System.assertEquals(11, quote.ELV_Support_Costs__c);
	// 	System.assertEquals(22, quote.ELV_Hosting_Costs__c);
	// 	System.assertEquals(33, quote.ELV_HuntIQ_Costs__c);
	// }

	// @IsTest
	// static void calculateMargin_HandlesOtherDeploymentTypes() {
	// 	insert new List<Margin_Costs__c>{
	// 		buildMarginCost(ELV_QuoteTriggerUtility.COST_TYPE_SUPPORT, 0, 1000, 11),
	// 		buildMarginCost(ELV_QuoteTriggerUtility.COST_TYPE_HOSTING, 0, 1000, 22),
	// 		buildMarginCost(ELV_QuoteTriggerUtility.COST_TYPE_HUNTIQ, 0, 1000, 33)
	// 	};

	// 	Quote onPremQuote = buildMarginQuote(
	// 		ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_ON_PREM,
	// 		500,
	// 		0
	// 	);
	// 	Quote govCloudQuote = buildMarginQuote(
	// 		ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_GOV_CLOUD,
	// 		500,
	// 		0
	// 	);
	// 	Quote hybridQuote = buildMarginQuote(
	// 		ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_HYBRID,
	// 		500,
	// 		0
	// 	);

	// 	ELV_QuoteTriggerUtility.calculateMargin(
	// 		new List<Quote>{ onPremQuote, govCloudQuote, hybridQuote },
	// 		null
	// 	);

	// 	System.assertEquals(11, onPremQuote.ELV_Support_Costs__c);
	// 	System.assertEquals(null, onPremQuote.ELV_Hosting_Costs__c);
	// 	System.assertEquals(11, govCloudQuote.ELV_Support_Costs__c);
	// 	System.assertEquals(
	// 		22 * ELV_QuoteTriggerUtility.GOV_CLOUD_HOSTING_MULTIPLIER,
	// 		govCloudQuote.ELV_Hosting_Costs__c
	// 	);
	// 	System.assertEquals(null, hybridQuote.ELV_Support_Costs__c);
	// 	System.assertEquals(null, hybridQuote.ELV_Hosting_Costs__c);
	// }

	// @IsTest
	// static void utilities_SkipWhenInputsAreUnchangedOrMissing() {
	// 	Id quoteId = Id.valueOf('0Q0000000000003');
	// 	Quote quote = buildQuoteWithFormulaEndpoint(quoteId, 250000, 86, null, 10);
	// 	quote.ELV_Flag_Color__c = 'Green';

	// 	Map<Id, Quote> oldMap = new Map<Id, Quote>{
	// 		quoteId => buildQuoteWithFormulaEndpoint(quoteId, 250000, 86, null, 10)
	// 	};

	// 	ELV_QuoteTriggerUtility.updateFlagColor(new List<Quote>{ quote }, oldMap);
	// 	System.assertEquals('Green', quote.ELV_Flag_Color__c);
	// 	System.assertEquals(
	// 		0,
	// 		ELV_QuoteTriggerUtility.getQuotesToCalculate(
	// 			new List<Quote>{ buildMarginQuoteWithId(quoteId, ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD, 500, 1) },
	// 			new Map<Id, Quote>{
	// 				quoteId => buildMarginQuoteWithId(
	// 					quoteId,
	// 					ELV_QuoteTriggerUtility.DEPLOYMENT_TYPE_CLOUD,
	// 					500,
	// 					1
	// 				)
	// 			}
	// 		)
	// 			.size()
	// 	);
	// 	System.assertEquals(null, ELV_QuoteTriggerUtility.stampQuoteLineRollups(null));
	// 	System.assertEquals(0, ELV_QuoteTriggerUtility.getQuotesToCalculate(null, null).size());
	// 	System.assertEquals(0, ELV_QuoteTriggerUtility.getQuotesToUpdateFlagColor(null, null).size());
	// 	System.assertEquals(null, ELV_QuoteTriggerUtility.getFlagColor(new Quote(), null));
	// 	System.assertEquals(null, ELV_QuoteTriggerUtility.getLowArrFlagColor(null));
	// 	System.assertEquals(
	// 		null,
	// 		ELV_QuoteTriggerUtility.getDiscountHealthFlagColor(null, 10, new List<Quote_Health_Indicator_Settings__c>())
	// 	);
	// }

	// @IsTest
	// static void quoteBeforeUpdate_InvokesFlagColorUtility() {
	// 	SBQQ.TriggerControl.disable();
	// 	TriggerHandler.bypass(
	// 		new List<String>{
	// 			'AccountTriggerHandler',
	// 			'OpportunityTriggerHandler',
	// 			'QuoteCPQTriggerHandler'
	// 		}
	// 	);

	// 	System.runAs(TestUserFactory.getAdminUser()) {
	// 		Account account = TestFactory.buildAccount('Flag Color Account');
	// 		insert account;

	// 		Opportunity opportunity = TestFactory.buildOpportunity(
	// 			'Flag Color Opportunity',
	// 			Date.today().addDays(30),
	// 			'Prospecting',
	// 			account.Id
	// 		);
	// 		opportunity.OwnerId = UserInfo.getUserId();
	// 		insert opportunity;

	// 		Quote quote = new Quote(
	// 			Name = 'Flag Color Quote',
	// 			OpportunityId = opportunity.Id,
	// 			Pricebook2Id = Test.getStandardPricebookId(),
	// 			ExpirationDate = Date.today().addYears(1),
	// 			Ruby__SubscriptionStartDate__c = Date.today(),
	// 			Ruby__SubscriptionTerm__c = 12,
	// 			Ruby__PaymentTerm__c = 'Net 30',
	// 			ELV_Day_1_ARR__c = 250000,
	// 			BillingStreet = '123 Main St',
	// 			BillingCity = 'San Francisco',
	// 			BillingPostalCode = '94105',
	// 			ShippingStreet = '123 Main St',
	// 			ShippingCity = 'San Francisco',
	// 			ShippingPostalCode = '94105'
	// 		);
	// 		setCaliforniaAddressFields(quote, 'Billing');
	// 		setCaliforniaAddressFields(quote, 'Shipping');
	// 		insert quote;

	// 		quote.Ruby__Discount__c = 1;
	// 		update quote;

	// 		System.assertNotEquals(null, quote.Id);
	// 	}
	// }

	// private static Quote_Health_Indicator_Settings__c buildHealthSetting(
	// 	Integer sequence,
	// 	Decimal endpointsMin,
	// 	Decimal endpointsMax,
	// 	Decimal discountMin,
	// 	Decimal discountMax,
	// 	String flagColor
	// ) {
	// 	return new Quote_Health_Indicator_Settings__c(
	// 		Endpoints_Min__c = endpointsMin,
	// 		Endpoints_Max__c = endpointsMax,
	// 		Additional_Discount_Min__c = discountMin,
	// 		Additional_Discount_Max__c = discountMax,
	// 		Flag_Color__c = flagColor
	// 	);
	// }

	// private static Margin_Costs__c buildMarginCost(
	// 	String costType,
	// 	Decimal minEndpointCount,
	// 	Decimal maxEndpointCount,
	// 	Decimal cost
	// ) {
	// 	return new Margin_Costs__c(
	// 		Name = costType + ' Cost',
	// 		Cost_Type__c = costType,
	// 		Min_Endpoint_Count__c = minEndpointCount,
	// 		Max_Endpoint_Count__c = maxEndpointCount,
	// 		ELV_Cost__c = cost
	// 	);
	// }

	// private static Quote buildMarginQuote(
	// 	String deploymentType,
	// 	Decimal coreQuantity,
	// 	Decimal huntIQProductCount
	// ) {
	// 	return new Quote(
	// 		ELV_Deployment_Method__c = deploymentType,
	// 		ELV_Core_Quantity__c = coreQuantity,
	// 		ELV_HuntIQ_Product_Count__c = huntIQProductCount
	// 	);
	// }

	// private static Quote buildMarginQuoteWithId(
	// 	Id quoteId,
	// 	String deploymentType,
	// 	Decimal coreQuantity,
	// 	Decimal huntIQProductCount
	// ) {
	// 	Quote quote = buildMarginQuote(deploymentType, coreQuantity, huntIQProductCount);
	// 	quote.Id = quoteId;
	// 	return quote;
	// }

	// private static Quote buildQuoteWithFormulaEndpoint(
	// 	Id quoteId,
	// 	Decimal day1Arr,
	// 	Decimal arrMargin,
	// 	Decimal endpoints,
	// 	Decimal discount
	// ) {
	// 	String quoteJson = '{"attributes":{"type":"Quote"}' +
	// 		(quoteId == null ? '' : ',"Id":"' + String.valueOf(quoteId) + '"') +
	// 		',"ELV_Day_1_ARR__c":' +
	// 		formatDecimal(day1Arr) +
	// 		',"ELV_ARR_Margin__c":' +
	// 		formatDecimal(arrMargin) +
	// 		',"ELV_No_of_End_Points_Quote_Score__c":' +
	// 		formatDecimal(endpoints) +
	// 		',"Ruby__Discount__c":' +
	// 		formatDecimal(discount) +
	// 		'}';

	// 	return (Quote) JSON.deserialize(quoteJson, Quote.class);
	// }

	// private static Quote createTestQuote(String quoteName) {
	// 	Account account = TestFactory.buildAccount(quoteName + ' Account');
	// 	insert account;

	// 	Opportunity opportunity = TestFactory.buildOpportunity(
	// 		quoteName + ' Opportunity',
	// 		Date.today().addDays(30),
	// 		'Prospecting',
	// 		account.Id
	// 	);
	// 	opportunity.OwnerId = UserInfo.getUserId();
	// 	insert opportunity;

	// 	Quote quote = new Quote(
	// 		Name = quoteName,
	// 		OpportunityId = opportunity.Id,
	// 		Pricebook2Id = Test.getStandardPricebookId(),
	// 		ExpirationDate = Date.today().addYears(1),
	// 		Ruby__SubscriptionStartDate__c = Date.today(),
	// 		Ruby__SubscriptionTerm__c = 12,
	// 		Ruby__PaymentTerm__c = 'Net 30',
	// 		BillingStreet = '123 Main St',
	// 		BillingCity = 'San Francisco',
	// 		BillingPostalCode = '94105',
	// 		ShippingStreet = '123 Main St',
	// 		ShippingCity = 'San Francisco',
	// 		ShippingPostalCode = '94105'
	// 	);
	// 	setCaliforniaAddressFields(quote, 'Billing');
	// 	setCaliforniaAddressFields(quote, 'Shipping');
	// 	insert quote;

	// 	return quote;
	// }

	// private static Product2 createProduct(
	// 	String productName,
	// 	String productCode,
	// 	Boolean includeInSeatsPurchased
	// ) {
	// 	Product2 product = new Product2(
	// 		Name = productName,
	// 		Family = 'None',
	// 		ProductCode = productCode,
	// 		IsActive = true,
	// 		Product_Type__c = 'Saas',
	// 		Product_Group__c = 'Software',
	// 		Include_In_Annualized_Software_Spend__c = true,
	// 		IncludeInSeatsPurchased__c = includeInSeatsPurchased,
	// 		Deployment_Method__c = 'Cloud'
	// 	);
	// 	insert product;

	// 	return product;
	// }

	// private static PricebookEntry createPricebookEntry(Id productId) {
	// 	PricebookEntry pricebookEntry = new PricebookEntry(
	// 		Pricebook2Id = Test.getStandardPricebookId(),
	// 		Product2Id = productId,
	// 		UnitPrice = 10,
	// 		IsActive = true
	// 	);
	// 	insert pricebookEntry;

	// 	return pricebookEntry;
	// }

	// private static String formatDecimal(Decimal value) {
	// 	return value == null ? 'null' : String.valueOf(value);
	// }

	// private static void setCaliforniaAddressFields(SObject record, String fieldPrefix) {
	// 	Map<String, Schema.SObjectField> fieldsByName = record.getSObjectType()
	// 		.getDescribe()
	// 		.fields.getMap();
	// 	String countryCodeField = fieldPrefix + 'CountryCode';
	// 	String stateCodeField = fieldPrefix + 'StateCode';

	// 	if (fieldsByName.containsKey(countryCodeField) && fieldsByName.containsKey(stateCodeField)) {
	// 		record.put(countryCodeField, 'US');
	// 		record.put(stateCodeField, 'CA');
	// 		return;
	// 	}

	// 	record.put(fieldPrefix + 'Country', 'United States');
	// 	record.put(fieldPrefix + 'State', 'CA');
	// }
}