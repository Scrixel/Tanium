/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. The Quote Line trigger maintains
 *            ELV_Is_Renewal_Transaction__c going forward only, so existing lines need a
 *            one-time pass. The renewal test is the approved rule: Ruby__ChangeType__c
 *            contains 'Renew', which matches Renew and RenewWithQuantityUpdate.
 *
 *            Scope is deliberately small because the Nue managed package consumes SOQL
 *            queries on every Quote Line update, which is what makes a single bulk pass fail.
 *
 *            A line already carrying the correct value costs no DML.
 */
public with sharing class ELV_RenewalStampBackfillBatch implements Database.Batchable<SObject>, Database.Stateful {
	@TestVisible
	private Integer recordsProcessed = 0;
	@TestVisible
	private Integer recordsUpdated = 0;

	public Database.QueryLocator start(Database.BatchableContext context) {
		return Database.getQueryLocator(
			'SELECT Id, Ruby__ChangeType__c, ELV_Is_Renewal_Transaction__c FROM QuoteLineItem'
		);
	}

	public void execute(Database.BatchableContext context, List<SObject> scope) {
		this.recordsProcessed += scope.size();
		this.recordsUpdated += stampRenewalFlag((List<QuoteLineItem>) scope);
	}

	public void finish(Database.BatchableContext context) {
		System.debug(
			LoggingLevel.INFO,
			'ELV_RenewalStampBackfillBatch finished. recordsProcessed=' +
				this.recordsProcessed +
				', recordsUpdated=' +
				this.recordsUpdated
		);
	}

	/**
	 * Aligns the stored renewal stamp with the authoritative change type on a scope of lines.
	 */
	@TestVisible
	private static Integer stampRenewalFlag(List<QuoteLineItem> lines) {
		List<QuoteLineItem> linesToUpdate = new List<QuoteLineItem>();

		for (QuoteLineItem line : lines) {
			Boolean target =
				line.Ruby__ChangeType__c != null && line.Ruby__ChangeType__c.contains('Renew');

			if (line.ELV_Is_Renewal_Transaction__c == target) {
				continue;
			}

			linesToUpdate.add(
				new QuoteLineItem(Id = line.Id, ELV_Is_Renewal_Transaction__c = target)
			);
		}

		if (!linesToUpdate.isEmpty()) {
			update linesToUpdate;
		}

		return linesToUpdate.size();
	}
}