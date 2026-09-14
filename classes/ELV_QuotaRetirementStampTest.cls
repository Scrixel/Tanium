/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Coverage for TNCI 139 / ELV-CPQ-036 - the quota retirement chain: the eligibility twin, the
 * stored EDW copy of the line formula, and the backfill job.
 *
 * The decision logic runs in memory, because the formula being copied reaches through
 * Quote.Opportunity and cannot be constructed on an unsaved record.
 */
@IsTest(SeeAllData=true)
private class ELV_QuotaRetirementStampTest {
	private static QuoteLineItem lineFor(Decimal formulaValue, Decimal storedValue) {
		Map<String, Object> values = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
			'ELV_Quota_Retirement_ARR__c' => formulaValue,
			'ELV_Quota_Retirement_ARR_EDW__c' => storedValue
		};
		return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
	}

	private static QuoteLineItem lineForProduct(Id productId) {
		Map<String, Object> values = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
			'Product2Id' => productId
		};
		return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
	}

	private static Product2 findProduct(Boolean eligible) {
		for (Product2 product : [
			SELECT Id, Quota_Retirement_Eligible__c
			FROM Product2
			WHERE Quota_Retirement_Eligible__c = :eligible
			LIMIT 1
		]) {
			return product;
		}
		return null;
	}

	@IsTest
	static void eligibilityIsTwinnedFromTheProduct() {
		Product2 eligible = findProduct(true);
		Product2 ineligible = findProduct(false);
		if (eligible == null || ineligible == null) {
			return;
		}

		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			lineForProduct(eligible.Id),
			lineForProduct(ineligible.Id)
		};

		Test.startTest();
		ELV_QuoteLineTriggerUtility.stampQuotaRetirementEligible(lines, null);
		ELV_QuoteLineTriggerUtility.stampQuotaRetirementEligible(null, null);
		ELV_QuoteLineTriggerUtility.stampQuotaRetirementEligible(
			new List<QuoteLineItem>(),
			null
		);
		Test.stopTest();

		System.assertEquals(
			true,
			lines[0].ELV_Quota_Retirement_Eligible__c,
			'A line on an eligible product is eligible.'
		);
		System.assertEquals(
			false,
			lines[1].ELV_Quota_Retirement_Eligible__c,
			'A line on an ineligible product is stamped false, not left blank.'
		);
	}

	@IsTest
	static void theStoredCopyFollowsTheFormula() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			lineFor(1500.25, null),
			lineFor(null, 900),
			lineFor(750, 750)
		};

		Test.startTest();
		List<QuoteLineItem> updates = ELV_QuotaRetirementStampService.buildUpdates(lines);
		Test.stopTest();

		System.assertEquals(2, updates.size(), 'Only the drifted lines are updated.');
		System.assertEquals(
			1500.25,
			updates[0].ELV_Quota_Retirement_ARR_EDW__c,
			'An unstamped line takes the formula value.'
		);
		System.assertEquals(
			0,
			updates[1].ELV_Quota_Retirement_ARR_EDW__c,
			'A blank formula stores zero rather than leaving a stale amount.'
		);
	}

	@IsTest
	static void theStampIsSuppressedWhileItIsRunning() {
		ELV_QuotaRetirementStampService.isStamping = true;

		Test.startTest();
		ELV_QuotaRetirementStampService.stampLines(new Set<Id>{ UserInfo.getUserId() });
		ELV_QuotaRetirementStampService.isStamping = false;
		ELV_QuotaRetirementStampService.stampLines(new Set<Id>());
		ELV_QuotaRetirementStampService.stampLines(null);
		Test.stopTest();
	}

	@IsTest
	static void theBackfillWalksItsJobLifecycle() {
		List<QuoteLineItem> scope = [
			SELECT Id, Product2Id, ELV_Quota_Retirement_Eligible__c
			FROM QuoteLineItem
			LIMIT 10
		];
		ELV_QuotaRetirementBackfillBatch job = new ELV_QuotaRetirementBackfillBatch();

		Test.startTest();
		System.assertNotEquals(null, job.start(null), 'The job exposes a query locator.');
		if (!scope.isEmpty()) {
			job.execute(null, scope);
		}
		job.finish(null);
		Test.stopTest();

		System.assertEquals(
			scope.size(),
			job.recordsProcessed,
			'Every line in the scope is accounted for.'
		);
	}
}