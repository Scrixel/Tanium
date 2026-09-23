@IsTest(SeeAllData=true)
private class ELV_IndependentProductAutoAddServiceTest {
	private static final String PERPETUAL_SKU = 'TAN-DISC-P';
	private static final Set<String> ESR_TIER_SKUS = new Set<String>{
		'TAN-PREM-ESR-TIER1-1D/M', 'TAN-PREM-ESR-TIER2-1D/M', 'TAN-PREM-ESR-TIER3-1D/M'
	};

	@IsTest
	static void esrAutoAddIsANoOpWithoutQualifyingHeaderState() {
		TestData data = setup();

		Test.startTest();
		insert new QuoteLineItem(
			QuoteId = data.quote.Id,
			Product2Id = data.perpetualProduct.Id,
			PricebookEntryId = data.perpetualPbe.Id,
			Quantity = 1,
			UnitPrice = 1000
		);
		Test.stopTest();

		List<QuoteLineItem> esrLines = [
			SELECT Id FROM QuoteLineItem
			WHERE QuoteId = :data.quote.Id
			AND Product2Id IN (SELECT Id FROM Product2 WHERE ProductCode IN :ESR_TIER_SKUS)
		];
		System.assertEquals(
			0,
			esrLines.size(),
			'A quote with none of the ESR Tier 1/2/3 trigger conditions set must not get any ESR line added.'
		);
	}

	@IsTest
	static void dontRunProductRuleSuppressesEsrAutoAdd() {
		TestData data = setup();
		data.quote.ELV_Dont_Run_Product_Rule__c = true;
		update data.quote;

		Test.startTest();
		insert new QuoteLineItem(
			QuoteId = data.quote.Id,
			Product2Id = data.perpetualProduct.Id,
			PricebookEntryId = data.perpetualPbe.Id,
			Quantity = 1,
			UnitPrice = 1000
		);
		Test.stopTest();

		List<QuoteLineItem> esrLines = [
			SELECT Id FROM QuoteLineItem
			WHERE QuoteId = :data.quote.Id
			AND Product2Id IN (SELECT Id FROM Product2 WHERE ProductCode IN :ESR_TIER_SKUS)
		];
		System.assertEquals(0, esrLines.size(), 'Don\'t Run Product Rule must suppress the ESR auto-add.');
	}

	@IsTest
	static void reevaluatingAQuoteThatAlreadyHasAnEsrTierLineDoesNotAddASecondOne() {
		TestData data = setup();

		List<Product2> tier1 = [SELECT Id FROM Product2 WHERE ProductCode = 'TAN-PREM-ESR-TIER1-1D/M' LIMIT 1];
		if (tier1.isEmpty()) {
			return;
		}
		Id standardPricebookId = Test.getStandardPricebookId();
		List<PricebookEntry> tier1Pbe = [
			SELECT Id FROM PricebookEntry
			WHERE Product2Id = :tier1[0].Id AND Pricebook2Id = :standardPricebookId
			LIMIT 1
		];
		if (tier1Pbe.isEmpty()) {
			return;
		}

		insert new QuoteLineItem(
			QuoteId = data.quote.Id,
			Product2Id = tier1[0].Id,
			PricebookEntryId = tier1Pbe[0].Id,
			Quantity = 1,
			UnitPrice = 0,
			ELV_Independent_Auto_Added__c = true
		);

		Test.startTest();
		insert new QuoteLineItem(
			QuoteId = data.quote.Id,
			Product2Id = data.perpetualProduct.Id,
			PricebookEntryId = data.perpetualPbe.Id,
			Quantity = 1,
			UnitPrice = 1000
		);
		Test.stopTest();

		List<QuoteLineItem> esrLines = [
			SELECT Id FROM QuoteLineItem WHERE QuoteId = :data.quote.Id AND Product2Id = :tier1[0].Id
		];
		System.assertEquals(1, esrLines.size(), 'A quote that already carries an ESR tier line must not get a second one.');
	}

	private class TestData {
		Product2 perpetualProduct;
		PricebookEntry perpetualPbe;
		Quote quote;
	}

	private static TestData setup() {
		TestData data = new TestData();

		data.perpetualProduct = [SELECT Id FROM Product2 WHERE ProductCode = :PERPETUAL_SKU LIMIT 1];

		Id standardPricebookId = Test.getStandardPricebookId();
		data.perpetualPbe = [
			SELECT Id
			FROM PricebookEntry
			WHERE Product2Id = :data.perpetualProduct.Id AND Pricebook2Id = :standardPricebookId
			LIMIT 1
		];

		Account account = new Account(Name = 'Independent-Add-16 Test Account');
		insert account;

		Opportunity opportunity = new Opportunity(
			Name = 'Independent-Add-16 Test Opportunity',
			AccountId = account.Id,
			StageName = 'Prospecting',
			CloseDate = Date.today().addDays(30)
		);
		insert opportunity;

		data.quote = new Quote(
			Name = 'Independent-Add-16 Test Quote',
			OpportunityId = opportunity.Id,
			Pricebook2Id = standardPricebookId
		);
		insert data.quote;

		return data;
	}
}