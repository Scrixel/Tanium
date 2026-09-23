public with sharing class ELV_IndependentProductAutoAddService {
	@TestVisible
	private static Set<Id> evaluatedQuoteIdsThisTransaction = new Set<Id>();

	private static final String ESR_TIER1_SKU = 'TAN-PREM-ESR-TIER1-1D/M';
	private static final String ESR_TIER2_SKU = 'TAN-PREM-ESR-TIER2-1D/M';
	private static final String ESR_TIER3_SKU = 'TAN-PREM-ESR-TIER3-1D/M';

	private static final Set<String> TIER1_COUNTRIES = new Set<String>{
		'AU', 'US', 'CA'
	};
	private static final Set<String> TIER2_COUNTRIES = new Set<String>{
		'BE', 'DK', 'FI', 'FR', 'DE', 'IS', 'IE', 'LU', 'NL', 'NO', 'SE', 'CH', 'GB'
	};
	private static final Set<String> TIER3_COUNTRIES = new Set<String>{
		'AT', 'BR', 'BG', 'HR', 'CY', 'CZ', 'GR', 'HU', 'IL', 'IT', 'KR', 'MT',
		'MX', 'NZ', 'PL', 'PT', 'RO', 'SG', 'SK', 'SI', 'ES'
	};
	private static final Set<String> MSP_BUSINESS_MOTION = new Set<String>{ 'MSP' };

	private static final String ESO_PARTNER_NAME = 'Tanium ESO';

	public static void autoAddEsrLines(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		Set<Id> unevaluatedQuoteIds = new Set<Id>();
		for (Id quoteId : quoteIds) {
			if (!evaluatedQuoteIdsThisTransaction.contains(quoteId)) {
				unevaluatedQuoteIds.add(quoteId);
			}
		}
		if (unevaluatedQuoteIds.isEmpty()) {
			return;
		}
		evaluatedQuoteIdsThisTransaction.addAll(unevaluatedQuoteIds);
		quoteIds = unevaluatedQuoteIds;

		Id esoPartnerId = getEsoPartnerId();

		Map<Id, Quote> quotesById = new Map<Id, Quote>([
			SELECT
				Id, Pricebook2Id, ELV_Opportunity_Type__c, ELV_Deployment_Partner__c,
				ShippingCountryCode, ELV_Sales_Ops_Derived_EP__c, ELV_Business_Motion_Oppty__c,
				ELV_Account_Segment__c, ELV_Region__c, ELV_Dont_Run_Product_Rule__c
			FROM Quote
			WHERE Id IN :quoteIds
		]);
		if (quotesById.isEmpty()) {
			return;
		}

		Map<String, Id> esrProductIdBySku = getProductIdsBySku(
			new Set<String>{ ESR_TIER1_SKU, ESR_TIER2_SKU, ESR_TIER3_SKU }
		);
		Set<Id> allEsrProductIds = new Set<Id>(esrProductIdBySku.values());

		Set<Id> quoteIdsWithEsrLine = new Set<Id>();
		for (QuoteLineItem line : [
			SELECT QuoteId
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIds AND Product2Id IN :allEsrProductIds
		]) {
			quoteIdsWithEsrLine.add(line.QuoteId);
		}

		Map<Id, Id> pricebookIdByQuoteId = new Map<Id, Id>();
		for (Quote q : quotesById.values()) {
			if (q.Pricebook2Id != null) {
				pricebookIdByQuoteId.put(q.Id, q.Pricebook2Id);
			}
		}
		Map<String, PricebookEntry> pricebookEntryByKey = getPricebookEntries(
			allEsrProductIds,
			new Set<Id>(pricebookIdByQuoteId.values())
		);

		List<QuoteLineItem> linesToInsert = new List<QuoteLineItem>();
		for (Quote quote : quotesById.values()) {
			if (quoteIdsWithEsrLine.contains(quote.Id) || quote.ELV_Dont_Run_Product_Rule__c == true) {
				continue;
			}

			String sku = resolveQualifyingEsrTierSku(quote, esoPartnerId);
			if (sku == null) {
				continue;
			}

			Id productId = esrProductIdBySku.get(sku);
			Id pricebookId = pricebookIdByQuoteId.get(quote.Id);
			if (productId == null || pricebookId == null) {
				continue;
			}

			PricebookEntry pbe = pricebookEntryByKey.get(productId + ':' + pricebookId);
			if (pbe == null) {
				continue;
			}

			linesToInsert.add(buildIndependentLine(quote.Id, pbe, 1));
		}

		insertAndRecalculate(linesToInsert);
	}

	private static String resolveQualifyingEsrTierSku(Quote quote, Id esoPartnerId) {
		Boolean isMsp = MSP_BUSINESS_MOTION.contains(quote.ELV_Business_Motion_Oppty__c);
		String country = quote.ShippingCountryCode;
		Double ep = quote.ELV_Sales_Ops_Derived_EP__c;

		if (
			quote.ELV_Opportunity_Type__c != 'New Customer' ||
			quote.ELV_Deployment_Partner__c != esoPartnerId ||
			ep == null || ep > 50000 ||
			isMsp
		) {
			return null;
		}

		if (
			TIER1_COUNTRIES.contains(country) &&
			quote.ELV_Account_Segment__c != 'Major' &&
			!isFederalRegion(quote.ELV_Region__c)
		) {
			return ESR_TIER1_SKU;
		}
		if (
			TIER2_COUNTRIES.contains(country) &&
			!isMajorsOrPublicSector(quote.ELV_Account_Segment__c)
		) {
			return ESR_TIER2_SKU;
		}
		if (
			TIER3_COUNTRIES.contains(country) &&
			!isMajorsOrPublicSector(quote.ELV_Account_Segment__c)
		) {
			return ESR_TIER3_SKU;
		}

		return null;
	}

	private static Boolean isFederalRegion(String region) {
		if (region == null) {
			return false;
		}
		return region == 'US Federal' || region == 'Channel_Federal' || region == 'USPS Federal HA';
	}

	private static Boolean isMajorsOrPublicSector(String segment) {
		return segment == 'Majors' || segment == 'Public Sector';
	}

	private static QuoteLineItem buildIndependentLine(Id quoteId, PricebookEntry pbe, Decimal quantity) {
		Decimal listPrice = pbe.UnitPrice == null ? 0 : pbe.UnitPrice;
		Decimal listTotal = listPrice * quantity;

		return new QuoteLineItem(
			QuoteId = quoteId,
			Product2Id = pbe.Product2Id,
			PricebookEntryId = pbe.Id,
			Quantity = quantity,
			UnitPrice = 0,
			Ruby__ListPrice__c = listPrice,
			Ruby__ListTotalPrice__c = listTotal,
			Ruby__Subtotal__c = listTotal,
			Ruby__SalesPrice__c = listPrice,
			Ruby__NetSalesPrice__c = listPrice,
			Ruby__TotalPrice__c = listTotal,
			Ruby__Uom__c = pbe.Ruby__Uom__c,
			ELV_Auto_Added_Maintenance__c = false,
			ELV_Independent_Auto_Added__c = true
		);
	}

	private static void insertAndRecalculate(List<QuoteLineItem> linesToInsert) {
		if (linesToInsert.isEmpty()) {
			return;
		}

		insert linesToInsert;

		Set<Id> quoteIds = new Set<Id>();
		for (QuoteLineItem line : linesToInsert) {
			quoteIds.add(line.QuoteId);
		}

		for (Id quoteId : quoteIds) {
			try {
				new Ruby.GlobalQuoteService().recalculate(quoteId);
			} catch (Exception e) {
				System.debug(
					LoggingLevel.WARN,
					'ELV_IndependentProductAutoAddService: recalculate failed for ' + quoteId + ': ' + e.getMessage()
				);
			}
		}
	}

	private static Map<String, Id> getProductIdsBySku(Set<String> skus) {
		Map<String, Id> productIdBySku = new Map<String, Id>();
		if (skus == null || skus.isEmpty()) {
			return productIdBySku;
		}

		for (Product2 product : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :skus]) {
			productIdBySku.put(product.ProductCode, product.Id);
		}

		return productIdBySku;
	}

	private static Id getEsoPartnerId() {
		List<Account> accounts = [
			SELECT Id FROM Account WHERE Name = :ESO_PARTNER_NAME LIMIT 1
		];
		return accounts.isEmpty() ? null : accounts[0].Id;
	}

	private static Map<String, PricebookEntry> getPricebookEntries(Set<Id> productIds, Set<Id> pricebookIds) {
		Map<String, PricebookEntry> pricebookEntryByKey = new Map<String, PricebookEntry>();
		if (productIds.isEmpty() || pricebookIds.isEmpty()) {
			return pricebookEntryByKey;
		}

		for (PricebookEntry entry : [
			SELECT Id, Product2Id, Pricebook2Id, UnitPrice, Ruby__Uom__c
			FROM PricebookEntry
			WHERE Product2Id IN :productIds AND Pricebook2Id IN :pricebookIds AND IsActive = TRUE
		]) {
			pricebookEntryByKey.put(entry.Product2Id + ':' + entry.Pricebook2Id, entry);
		}

		return pricebookEntryByKey;
	}
}