/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. One-time backfill for Quote.ELV_Day_1_ARR__c, since the
 *            trigger maintains quotes only going forward. Scope is kept small because the Nue
 *            managed package consumes SOQL queries on every quote save.
 */
public with sharing class ELV_SalesARRStampBackfillBatch implements Database.Batchable<SObject>, Database.Stateful {
	@TestVisible
	private Integer recordsProcessed = 0;
	@TestVisible
	private Integer recordsUpdated = 0;

	public Database.QueryLocator start(Database.BatchableContext context) {
		return Database.getQueryLocator('SELECT Id FROM Quote');
	}

	public void execute(Database.BatchableContext context, List<SObject> scope) {
		this.recordsProcessed += scope.size();
		Integer before = Limits.getDmlRows();
		ELV_SalesARRStampService.stampQuotes(new Map<Id, SObject>(scope).keySet());
		this.recordsUpdated += Limits.getDmlRows() - before;
	}

	public void finish(Database.BatchableContext context) {
		System.debug(
			LoggingLevel.INFO,
			'ELV_SalesARRStampBackfillBatch finished. recordsProcessed=' +
				this.recordsProcessed +
				', recordsUpdated=' +
				this.recordsUpdated
		);
	}
}