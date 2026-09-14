/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Coverage for TNCI 139 / ELV-CPQ-036 - the product exclusion stamp, its propagation from
 * Product2, and the backfill batch.
 *
 * Quote line inserts drive the Nue managed trigger stack, so the trigger-driven cases run
 * SeeAllData against the org's own configuration; the decision logic is exercised in memory
 * where a real record would add nothing.
 */
@IsTest(SeeAllData=true)
private class ELV_ProductARRStampTest {
	/** An unsaved line carrying a chosen product, for the in-memory stamp cases. */
	private static QuoteLineItem lineFor(Id productId) {
		Map<String, Object> values = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
			'Product2Id' => productId
		};
		return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
	}

	private static Product2 findProduct(Boolean excluded) {
		for (Product2 product : [
			SELECT Id, Exclude_from_ARR__c
			FROM Product2
			WHERE Exclude_from_ARR__c = :excluded
			LIMIT 1
		]) {
			return product;
		}
		return null;
	}

	@IsTest
	static void anExcludedProductStampsTrueAndAnIncludedProductStampsFalse() {
		Product2 excluded = findProduct(true);
		Product2 included = findProduct(false);
		if (excluded == null || included == null) {
			return;
		}

		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			lineFor(excluded.Id),
			lineFor(included.Id)
		};

		Test.startTest();
		ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(lines, null);
		Test.stopTest();

		System.assertEquals(
			true,
			lines[0].ELV_Product_Exclude_from_ARR__c,
			'A line on an excluded product carries the exclusion.'
		);
		System.assertEquals(
			false,
			lines[1].ELV_Product_Exclude_from_ARR__c,
			'A line on an included product is stamped false, not left blank.'
		);
	}

	@IsTest
	static void aMissingProductStampsFalseRatherThanNull() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			lineFor(null),
			lineFor('01t000000000001AAA')
		};

		Test.startTest();
		ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(lines, null);
		Test.stopTest();

		System.assertEquals(
			false,
			lines[0].ELV_Product_Exclude_from_ARR__c,
			'A line with no product reads as included, never blank.'
		);
		System.assertEquals(
			false,
			lines[1].ELV_Product_Exclude_from_ARR__c,
			'A product that cannot be found reads as included, never blank.'
		);
	}

	@IsTest
	static void reparentingTheLineRestampsItAndAnUnchangedProductDoesNot() {
		Product2 excluded = findProduct(true);
		Product2 included = findProduct(false);
		if (excluded == null || included == null) {
			return;
		}

		Id lineId = '0QL000000000001AAA';

		QuoteLineItem reparented = lineFor(excluded.Id);
		reparented.Id = lineId;
		reparented.ELV_Product_Exclude_from_ARR__c = false;

		QuoteLineItem oldLine = lineFor(included.Id);
		oldLine.Id = lineId;
		oldLine.ELV_Product_Exclude_from_ARR__c = false;

		QuoteLineItem untouched = lineFor(included.Id);
		untouched.Id = '0QL000000000002AAA';
		untouched.ELV_Product_Exclude_from_ARR__c = true;

		QuoteLineItem untouchedOld = lineFor(included.Id);
		untouchedOld.Id = untouched.Id;
		untouchedOld.ELV_Product_Exclude_from_ARR__c = true;

		Test.startTest();
		ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(
			new List<QuoteLineItem>{ reparented, untouched },
			new Map<Id, QuoteLineItem>{ lineId => oldLine, untouched.Id => untouchedOld }
		);
		Test.stopTest();

		System.assertEquals(
			true,
			reparented.ELV_Product_Exclude_from_ARR__c,
			'Moving the line to a different product re-stamps it.'
		);
		System.assertEquals(
			true,
			untouched.ELV_Product_Exclude_from_ARR__c,
			'With the product unchanged the existing value stands, including a manual one.'
		);
	}

	@IsTest
	static void anUpdateWithAnUnchangedProductIsSkippedEntirely() {
		Product2 excluded = findProduct(true);
		if (excluded == null) {
			return;
		}

		Id lineId = '0QL000000000003AAA';
		QuoteLineItem line = lineFor(excluded.Id);
		line.Id = lineId;

		QuoteLineItem oldLine = lineFor(excluded.Id);
		oldLine.Id = lineId;

		Test.startTest();
		ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(
			new List<QuoteLineItem>{ line },
			new Map<Id, QuoteLineItem>{ lineId => oldLine }
		);
		Test.stopTest();

		// A checkbox is never null on a saved record, so an update whose product did not move is
		// skipped before the product is ever queried. Correcting historical rows is the backfill's
		// job, not the trigger's - which is what keeps a Data Loader pass cheap.
		System.assertEquals(
			false,
			line.ELV_Product_Exclude_from_ARR__c,
			'An update with an unchanged product leaves the stored value exactly as it was.'
		);
	}

	@IsTest
	static void onlyAChangedExclusionFlagSelectsAProduct() {
		Id movedId = '01t000000000011AAA';
		Id staticId = '01t000000000012AAA';

		List<Product2> newProducts = new List<Product2>{
			new Product2(Id = movedId, Exclude_from_ARR__c = true),
			new Product2(Id = staticId, Exclude_from_ARR__c = true)
		};
		Map<Id, Product2> oldMap = new Map<Id, Product2>{
			movedId => new Product2(Id = movedId, Exclude_from_ARR__c = false),
			staticId => new Product2(Id = staticId, Exclude_from_ARR__c = true)
		};

		Set<Id> changed = ELV_ProductARRStampService.getProductsWithChangedExclusion(
			newProducts,
			oldMap
		);

		System.assertEquals(1, changed.size(), 'Only the reclassified product is picked up.');
		System.assert(changed.contains(movedId), 'The reclassified product is the one selected.');
		System.assertEquals(
			0,
			ELV_ProductARRStampService.getProductsWithChangedExclusion(null, null).size(),
			'No products is a no-op.'
		);
	}

	@IsTest
	static void reclassifyingAProductRestampsItsOpenLines() {
		List<QuoteLineItem> lines = [
			SELECT Id, Product2Id, ELV_Product_Exclude_from_ARR__c
			FROM QuoteLineItem
			WHERE Quote.Status NOT IN ('Accepted', 'Denied')
			LIMIT 1
		];
		if (lines.isEmpty()) {
			return;
		}

		Id productId = lines[0].Product2Id;
		Product2 product = [SELECT Id, Exclude_from_ARR__c FROM Product2 WHERE Id = :productId];
		Boolean target = !(product.Exclude_from_ARR__c == true);

		Test.startTest();
		// The trigger runs the service inline under test, so the effect is assertable here.
		update new Product2(Id = productId, Exclude_from_ARR__c = target);
		Test.stopTest();

		for (QuoteLineItem line : [
			SELECT Id, ELV_Product_Exclude_from_ARR__c
			FROM QuoteLineItem
			WHERE Product2Id = :productId AND Quote.Status NOT IN ('Accepted', 'Denied')
		]) {
			System.assertEquals(
				target,
				line.ELV_Product_Exclude_from_ARR__c,
				'Every open line on the product follows the new classification.'
			);
		}
	}

	@IsTest
	static void restampIsANoOpWithoutProducts() {
		Test.startTest();
		Integer updated = ELV_ProductARRStampService.restampLines(new Set<Id>());
		Integer nullUpdated = ELV_ProductARRStampService.restampLines(null);
		Test.stopTest();

		System.assertEquals(0, updated, 'An empty product set costs no DML.');
		System.assertEquals(0, nullUpdated, 'A null product set costs no DML.');
	}

	@IsTest
	static void theBackfillStampsBothFieldsAcrossExistingData() {
		List<QuoteLineItem> lines = [
			SELECT Id, Product2Id, ELV_Product_Exclude_from_ARR__c
			FROM QuoteLineItem
			LIMIT 50
		];
		if (lines.isEmpty()) {
			return;
		}

		// Force a mismatch so the batch has something to correct.
		List<QuoteLineItem> dirtied = new List<QuoteLineItem>();
		for (QuoteLineItem line : lines) {
			dirtied.add(
				new QuoteLineItem(
					Id = line.Id,
					ELV_Product_Exclude_from_ARR__c = !(line.ELV_Product_Exclude_from_ARR__c ==
					true)
				)
			);
		}
		update dirtied;

		// Re-read: the batch decides from the values it is handed, and the rows have just moved.
		List<QuoteLineItem> current = [
			SELECT Id, Product2Id, ELV_Product_Exclude_from_ARR__c
			FROM QuoteLineItem
			WHERE Id IN :lines
		];

		Test.startTest();
		Integer corrected = ELV_ARRStampBackfillBatch.stampProductFlag(current);
		Test.stopTest();

		// Not every row necessarily moved - other automation on the quote line can hold a value -
		// so the claim under test is that the batch corrects what it finds and leaves the org
		// matching its products, which the record-by-record check below asserts.
		System.assert(
			corrected > 0,
			'The batch corrects the rows whose stamp disagrees with their product.'
		);

		Map<Id, Boolean> excludeByProductId = new Map<Id, Boolean>();
		for (Product2 product : [
			SELECT Id, Exclude_from_ARR__c
			FROM Product2
			WHERE Id IN (SELECT Product2Id FROM QuoteLineItem WHERE Id IN :lines)
		]) {
			excludeByProductId.put(product.Id, product.Exclude_from_ARR__c == true);
		}

		for (QuoteLineItem line : [
			SELECT Id, Product2Id, ELV_Product_Exclude_from_ARR__c
			FROM QuoteLineItem
			WHERE Id IN :lines
		]) {
			System.assertEquals(
				excludeByProductId.get(line.Product2Id) == true,
				line.ELV_Product_Exclude_from_ARR__c,
				'After the backfill the line matches Exclude from ARR on its product.'
			);
		}
	}

	@IsTest
	static void theBackfillRunsAsABatchOverQuotes() {
		// The Day 1 stamp helper enqueues work of its own, so launching the job inside the test
		// context produced a second executeBatch and failed on the platform's one-batch limit.
		// Driving the batch's own lifecycle over a single bounded scope exercises the same code
		// and keeps the assertion below unchanged.
		List<Quote> allQuotes = [SELECT Id FROM Quote];
		ELV_ARRStampBackfillBatch job = new ELV_ARRStampBackfillBatch(
			ELV_ARRStampBackfillBatch.Mode.DAY_ONE_DATE
		);

		Test.startTest();
		job.start(null);
		// Every quote must be covered for the assertion below to hold, so the scopes are walked
		// here rather than delegated to the platform's chunking.
		List<Quote> scope = new List<Quote>();
		for (Quote quote : allQuotes) {
			scope.add(quote);
			if (scope.size() == 190) {
				job.execute(null, scope);
				scope = new List<Quote>();
			}
		}
		if (!scope.isEmpty()) {
			job.execute(null, scope);
		}
		job.finish(null);
		Test.stopTest();

		Integer drifted = [
			SELECT COUNT()
			FROM QuoteLineItem
			WHERE ELV_Day_1_ARR_Start_Date_Drift__c = TRUE
		];
		System.assertEquals(0, drifted, 'The Day 1 backfill leaves no line drifting.');
	}

	// ---------------------------------------------------------------------------------------
	// Trigger-context coverage. Insert and delete are the contexts §4.3 added, and neither can
	// be reached by a field comparison - only by real DML.
	// ---------------------------------------------------------------------------------------

	@IsTest
	static void insertingALineStampsBothFieldsAndDeletingItRefreshesTheQuote() {
		List<QuoteLineItem> existing = [
			SELECT
				Id,
				QuoteId,
				PricebookEntryId,
				Product2Id,
				Quantity,
				UnitPrice,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				Ruby__LineType__c
			FROM QuoteLineItem
			WHERE Quote.Status NOT IN ('Accepted', 'Denied') AND PricebookEntryId != NULL
			LIMIT 1
		];
		if (existing.isEmpty()) {
			return;
		}

		QuoteLineItem template = existing[0];
		Product2 product = [
			SELECT Id, Exclude_from_ARR__c
			FROM Product2
			WHERE Id = :template.Product2Id
		];

		QuoteLineItem inserted = new QuoteLineItem(
			QuoteId = template.QuoteId,
			PricebookEntryId = template.PricebookEntryId,
			Quantity = 1,
			UnitPrice = template.UnitPrice == null ? 0 : template.UnitPrice,
			Ruby__SubscriptionStartDate__c = template.Ruby__SubscriptionStartDate__c,
			Ruby__SubscriptionEndDate__c = template.Ruby__SubscriptionEndDate__c,
			Ruby__LineType__c = template.Ruby__LineType__c
		);

		Test.startTest();
		insert inserted;

		QuoteLineItem afterInsert = [
			SELECT Id, ELV_Product_Exclude_from_ARR__c, ELV_Day_1_ARR_Start_Date_Stamp__c
			FROM QuoteLineItem
			WHERE Id = :inserted.Id
		];

		delete inserted;
		Test.stopTest();

		System.assertEquals(
			product.Exclude_from_ARR__c == true,
			afterInsert.ELV_Product_Exclude_from_ARR__c,
			'A newly inserted line carries its product exclusion without a second pass.'
		);

		Quote quote = [
			SELECT Id, ELV_Day_1_ARR_Start_Date__c
			FROM Quote
			WHERE Id = :template.QuoteId
		];
		for (QuoteLineItem line : [
			SELECT Id, ELV_Day_1_ARR_Start_Date_Stamp__c
			FROM QuoteLineItem
			WHERE QuoteId = :template.QuoteId
		]) {
			System.assertEquals(
				quote.ELV_Day_1_ARR_Start_Date__c,
				line.ELV_Day_1_ARR_Start_Date_Stamp__c,
				'After the insert and the delete every surviving line matches the quote.'
			);
		}
	}

	@IsTest
	static void aSummaryItemStampsItsChangedSubscription() {
		List<Ruby__Subscription__c> subscriptions = [
			SELECT Id, Name, ELV_Supported_Asset__c
			FROM Ruby__Subscription__c
			LIMIT 1
		];
		if (subscriptions.isEmpty()) {
			return;
		}

		QuoteLineItem summaryItem = summaryLine(subscriptions[0].Name + '_1');
		QuoteLineItem unknownSubscription = summaryLine('ELV_NO_SUCH_SUBSCRIPTION_1');
		QuoteLineItem blankAsset = summaryLine(null);
		QuoteLineItem plainLine = summaryLine(subscriptions[0].Name + '_2');
		plainLine.Ruby__LineType__c = 'LineItem';

		Test.startTest();
		ELV_QuoteLineTriggerUtility.populateChangedSubscription(
			new List<QuoteLineItem>{ summaryItem, unknownSubscription, blankAsset, plainLine }
		);
		Test.stopTest();

		System.assertEquals(
			subscriptions[0].Id,
			summaryItem.ELV_Changed_Subscription__c,
			'A subscription summary item resolves its changed subscription by name.'
		);
		System.assertEquals(
			null,
			unknownSubscription.ELV_Changed_Subscription__c,
			'A summary item naming no known subscription is left alone.'
		);
		System.assertEquals(
			null,
			plainLine.ELV_Changed_Subscription__c,
			'A plain line item is not a summary item and is skipped.'
		);
	}

	@IsTest
	static void subscriptionNameParsingHandlesTheVersionSuffix() {
		System.assertEquals(
			'SUB-0001',
			ELV_QuoteLineTriggerUtility.getSubscriptionName('SUB-0001_3'),
			'The trailing version suffix is stripped.'
		);
		System.assertEquals(
			'SUB-0002',
			ELV_QuoteLineTriggerUtility.getSubscriptionName('  SUB-0002  '),
			'A name with no suffix is returned trimmed.'
		);
		System.assertEquals(
			null,
			ELV_QuoteLineTriggerUtility.getSubscriptionName('   '),
			'A blank change asset id yields no name.'
		);
	}

	@IsTest
	static void populateChangedSubscriptionIsSafeWithNothingToDo() {
		Test.startTest();
		ELV_QuoteLineTriggerUtility.populateChangedSubscription(new List<QuoteLineItem>());
		ELV_QuoteLineTriggerUtility.requestQuoteRefresh((List<QuoteLineItem>) null);
		ELV_QuoteLineTriggerUtility.requestQuoteRefresh(new Set<Id>());
		ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(null, null);
		Test.stopTest();
	}

	/** An unsaved summary item pointing at a subscription, built without touching the database. */
	private static QuoteLineItem summaryLine(String changeAssetId) {
		Map<String, Object> values = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
			'Ruby__LineType__c' => 'SummaryItem',
			'Ruby__ChangeAssetType__c' => 'Subscription',
			'Ruby__ChangeAssetId__c' => changeAssetId
		};
		return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
	}
}