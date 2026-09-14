/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * Coverage for TNCI 139 / ELV-CPQ-036 - the renewal stamp backfill batch.
 *
 * The decision logic is exercised in memory, and the job lifecycle is walked directly rather
 * than through Database.executeBatch, because a test method may only enqueue one batch and the
 * Nue managed trigger stack already consumes limits on every quote line update.
 */
@IsTest(SeeAllData=true)
private class ELV_RenewalStampBackfillTest {
	/** An unsaved line carrying a chosen change type, for the in-memory stamp cases. */
	private static QuoteLineItem lineFor(String changeType, Boolean stamped) {
		Map<String, Object> values = new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'QuoteLineItem' },
			'Ruby__ChangeType__c' => changeType,
			'ELV_Is_Renewal_Transaction__c' => stamped
		};
		return (QuoteLineItem) JSON.deserialize(JSON.serialize(values), QuoteLineItem.class);
	}

	@IsTest
	static void theStampFollowsTheContainsRenewRule() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			lineFor('Renew', false),
			lineFor('RenewWithQuantityUpdate', false),
			lineFor('NewProduct', false),
			lineFor(null, false)
		};

		Test.startTest();
		ELV_QuoteLineTriggerUtility.stampIsRenewalTransaction(lines);
		Test.stopTest();

		System.assertEquals(true, lines[0].ELV_Is_Renewal_Transaction__c, 'Renew is a renewal.');
		System.assertEquals(
			true,
			lines[1].ELV_Is_Renewal_Transaction__c,
			'RenewWithQuantityUpdate is a renewal.'
		);
		System.assertEquals(
			false,
			lines[2].ELV_Is_Renewal_Transaction__c,
			'A new product line is stamped false, not left blank.'
		);
		System.assertEquals(
			false,
			lines[3].ELV_Is_Renewal_Transaction__c,
			'A blank change type is not a renewal.'
		);
	}

	@IsTest
	static void anAlreadyCorrectLineCostsNoUpdate() {
		List<QuoteLineItem> lines = new List<QuoteLineItem>{
			lineFor('Renew', true),
			lineFor('NewProduct', false)
		};

		Test.startTest();
		Integer updated = ELV_RenewalStampBackfillBatch.stampRenewalFlag(lines);
		Test.stopTest();

		System.assertEquals(0, updated, 'Lines already carrying the correct stamp are skipped.');
	}

	@IsTest
	static void theBackfillWalksItsJobLifecycle() {
		List<QuoteLineItem> scope = [
			SELECT Id, Ruby__ChangeType__c, ELV_Is_Renewal_Transaction__c
			FROM QuoteLineItem
			LIMIT 20
		];

		ELV_RenewalStampBackfillBatch job = new ELV_RenewalStampBackfillBatch();

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