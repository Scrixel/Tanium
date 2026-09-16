/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: One-time backfill for the QuoteLineItem.ELV_Product_Group__c formula-to-text
 *            migration. Future saves are handled by ELV_QuoteLineTriggerUtility and future
 *            Product2 changes are handled by ELV_ProductGroupStampService.
 */
public with sharing class ELV_ProductGroupStampBackfillBatch implements Database.Batchable<SObject>, Database.Stateful {
	@TestVisible
	private Integer recordsProcessed = 0;
	@TestVisible
	private Integer recordsUpdated = 0;

	public Database.QueryLocator start(Database.BatchableContext context) {
		return Database.getQueryLocator(
			[
				SELECT
					Id,
					ELV_Product_Group__c,
					Product2.Product_Group__c,
					Product2.Ruby__OriginalProduct__c,
					Product2.Ruby__OriginalProduct__r.Product_Group__c
				FROM QuoteLineItem
			]
		);
	}

	public void execute(Database.BatchableContext context, List<SObject> scope) {
		this.recordsProcessed += scope.size();

		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();
		for (QuoteLineItem line : (List<QuoteLineItem>) scope) {
			String target = ELV_QuoteLineTriggerUtility.resolveProductGroupStamp(
				line.Product2
			);
			if (line.ELV_Product_Group__c == target) {
				continue;
			}

			linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Product_Group__c = target)
			);
		}

		if (!linesToUpdate.isEmpty()) {
			update linesToUpdate;
		}

		this.recordsUpdated += linesToUpdate.size();
	}

	public void finish(Database.BatchableContext context) {
		System.debug(
			LoggingLevel.INFO,
			'ELV_ProductGroupStampBackfillBatch finished. recordsProcessed=' +
				this.recordsProcessed +
				', recordsUpdated=' +
				this.recordsUpdated
		);
	}
}