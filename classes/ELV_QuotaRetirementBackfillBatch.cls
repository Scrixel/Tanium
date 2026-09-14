/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. One-time backfill for the quota retirement chain, which
 *            the triggers maintain only going forward.
 *
 *            The two stamps run in order within a scope, because the second depends on the
 *            first: the eligibility flag feeds ELV_Quota_Retirement_ARR__c, and the EDW copy
 *            reads that formula. The lines are re-queried between the two so the formula is
 *            read after the eligibility save rather than from a stale in-memory record.
 *
 *            Scope is small because the Nue managed package consumes SOQL queries on every
 *            quote line update.
 */
public with sharing class ELV_QuotaRetirementBackfillBatch implements Database.Batchable<SObject>, Database.Stateful {
	@TestVisible
	private Integer recordsProcessed = 0;
	@TestVisible
	private Integer eligibilityUpdated = 0;
	@TestVisible
	private Integer edwUpdated = 0;

	public Database.QueryLocator start(Database.BatchableContext context) {
		return Database.getQueryLocator(
			'SELECT Id, Product2Id, ELV_Quota_Retirement_Eligible__c FROM QuoteLineItem'
		);
	}

	public void execute(Database.BatchableContext context, List<SObject> scope) {
		this.recordsProcessed += scope.size();
		this.eligibilityUpdated += stampEligibility((List<QuoteLineItem>) scope);

		Integer before = Limits.getDmlRows();
		ELV_QuotaRetirementStampService.stampLines(new Map<Id, SObject>(scope).keySet());
		this.edwUpdated += Limits.getDmlRows() - before;
	}

	public void finish(Database.BatchableContext context) {
		System.debug(
			LoggingLevel.INFO,
			'ELV_QuotaRetirementBackfillBatch finished. recordsProcessed=' +
				this.recordsProcessed +
				', eligibilityUpdated=' +
				this.eligibilityUpdated +
				', edwUpdated=' +
				this.edwUpdated
		);
	}

	/**
	 * Twins the product's quota retirement flag onto the line, joining to Product2 rather than
	 * trusting the line so a line whose product changed before the trigger existed is corrected.
	 */
	@TestVisible
	private static Integer stampEligibility(List<QuoteLineItem> lines) {
		Set<Id> productIds = new Set<Id>();
		for (QuoteLineItem line : lines) {
			if (line.Product2Id != null) {
				productIds.add(line.Product2Id);
			}
		}

		Map<Id, Boolean> eligibleByProductId = new Map<Id, Boolean>();
		for (Product2 product : [
			SELECT Id, Quota_Retirement_Eligible__c
			FROM Product2
			WHERE Id IN :productIds
		]) {
			eligibleByProductId.put(product.Id, product.Quota_Retirement_Eligible__c == true);
		}

		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();
		for (QuoteLineItem line : lines) {
			Boolean target = eligibleByProductId.get(line.Product2Id) == true;
			if (line.ELV_Quota_Retirement_Eligible__c == target) {
				continue;
			}

			linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Quota_Retirement_Eligible__c = target)
			);
		}

		if (!linesToUpdate.isEmpty()) {
			update linesToUpdate;
		}

		return linesToUpdate.size();
	}
}