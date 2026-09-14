/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036 backfill. The triggers only maintain records going forward,
 *            so both stamps need a one-time pass over existing data.
 *
 *            Build carries 117 quotes and would run in a single execution, but production is
 *            roughly 110,000 quotes, so this is a batch. Both stamps are covered by one job so
 *            the ordering is not left to whoever runs it: the product flag is stamped first,
 *            because a line's ARR eligibility depends on it, then the Day 1 date.
 *
 *            The per-line dirty check lives in the helper, so a clean quote costs no DML.
 */
public with sharing class ELV_ARRStampBackfillBatch implements Database.Batchable<SObject>, Database.Stateful {
	public enum Mode {
		PRODUCT_FLAG,
		DAY_ONE_DATE
	}

	private final Mode mode;

	@TestVisible
	private Integer recordsProcessed = 0;
	@TestVisible
	private Integer recordsUpdated = 0;

	public ELV_ARRStampBackfillBatch(Mode mode) {
		this.mode = mode;
	}

	public Database.QueryLocator start(Database.BatchableContext context) {
		if (this.mode == ELV_ARRStampBackfillBatch.Mode.PRODUCT_FLAG) {
			return Database.getQueryLocator(
				'SELECT Id, Product2Id, ELV_Product_Exclude_from_ARR__c FROM QuoteLineItem'
			);
		}

		return Database.getQueryLocator('SELECT Id FROM Quote');
	}

	public void execute(Database.BatchableContext context, List<SObject> scope) {
		this.recordsProcessed += scope.size();

		if (this.mode == ELV_ARRStampBackfillBatch.Mode.PRODUCT_FLAG) {
			this.recordsUpdated += stampProductFlag((List<QuoteLineItem>) scope);
			return;
		}

		ELV_Day1ARRStampHelper.StampResult result = ELV_Day1ARRStampHelper.refreshAndSave(
			new Map<Id, SObject>(scope).keySet()
		);
		this.recordsUpdated += result.linesToUpdate.size();
	}

	public void finish(Database.BatchableContext context) {
		System.debug(
			LoggingLevel.INFO,
			'ELV_ARRStampBackfillBatch finished. Mode=' +
				this.mode +
				', recordsProcessed=' +
				this.recordsProcessed +
				', recordsUpdated=' +
				this.recordsUpdated
		);
	}

	/**
	 * Stamps the product exclusion flag on a scope of lines. Joins to Product2 rather than
	 * trusting the line, so a line whose product changed before the trigger existed is corrected.
	 */
	@TestVisible
	private static Integer stampProductFlag(List<QuoteLineItem> lines) {
		Set<Id> productIds = new Set<Id>();
		for (QuoteLineItem line : lines) {
			if (line.Product2Id != null) {
				productIds.add(line.Product2Id);
			}
		}

		Map<Id, Boolean> excludeByProductId = new Map<Id, Boolean>();
		for (Product2 product : [
			SELECT Id, Exclude_from_ARR__c
			FROM Product2
			WHERE Id IN :productIds
		]) {
			excludeByProductId.put(product.Id, product.Exclude_from_ARR__c == true);
		}

		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();
		for (QuoteLineItem line : lines) {
			Boolean target = excludeByProductId.get(line.Product2Id) == true;
			if (line.ELV_Product_Exclude_from_ARR__c == target) {
				continue;
			}

			linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Product_Exclude_from_ARR__c = target)
			);
		}

		if (!linesToUpdate.isEmpty()) {
			update linesToUpdate;
		}

		return linesToUpdate.size();
	}
}