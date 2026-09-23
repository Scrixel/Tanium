/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI-206 / TNCI-139. The deferred half of the quote ARR pass.
 *
 *            Ordering is the whole reason this class exists. Inside the transaction that
 *            inserts or edits quote lines, the Quote roll-up summaries have not recalculated
 *            yet, so ELV_Day_1_ARR_Start_Date__c - a formula over those roll-ups - still
 *            reads its pre-save value, and on a brand new quote that value is blank. Stamping
 *            from there writes blank onto every line, which is exactly the anomaly that left
 *            new quotes reporting zero ARR.
 *
 *            Running the stamp in a queueable moves it past the commit. The roll-ups are
 *            settled, the cascade resolves, and the stamp lands on the first attempt.
 */
public with sharing class ELV_ARRSyncQueueable implements Queueable {
	private final Set<Id> quoteIds;

	public ELV_ARRSyncQueueable(Set<Id> quoteIds) {
		this.quoteIds = quoteIds == null ? new Set<Id>() : new Set<Id>(quoteIds);
	}

	public void execute(QueueableContext context) {
		if (quoteIds.isEmpty()) {
			return;
		}

		// Stamp, derive, stamp again. The second stamp settles the one-hop feedback where
		// stamping moves Include in Day 1 ARR, which moves the roll-up, which moves the
		// cascade. The dirty check keeps a settled quote at zero DML.
		ELV_Day1ARRStampHelper.refreshAndSave(quoteIds);
		ELV_ExitARRHelper.refreshAndSave(quoteIds);
		ELV_Day1ARRStampHelper.refreshAndSave(quoteIds);
		ELV_SalesARRStampService.stampQuotes(quoteIds);
		// TNCI-208. Line fee values are settled before commit; reconcile the parent Quote total after commit.
		ELV_OEMFeeService.refreshQuoteTotals(quoteIds);
		ELV_MarketplaceImpactService.refreshAndSave(quoteIds);

		Set<Id> opportunityIds = new Set<Id>();
		for (Quote quote : [
			SELECT OpportunityId
			FROM Quote
			WHERE Id IN :quoteIds AND OpportunityId != NULL
		]) {
			opportunityIds.add(quote.OpportunityId);
		}

		if (!opportunityIds.isEmpty()) {
			ELV_OpportunityARRService.recalculate(opportunityIds);
		}
	}
}