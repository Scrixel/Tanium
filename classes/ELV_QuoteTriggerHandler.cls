/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Handler for the standard Quote (Legacy Quote) trigger. It stamps the
 *            rollup fields the Nue UI Plugin depends on, because the plugin cannot
 *            query related records.
 *
 *            No rule evaluation happens here: per CPQ_Product_Rules_Grouped, all 43
 *            message-raising rules are UI Plugin rules and the remaining 20 are native
 *            Nue selection rules.
 */
public with sharing class ELV_QuoteTriggerHandler extends TriggerHandler {
	private List<Quote> quotes;
	private Map<Id, Quote> oldMap;

	/** Carries the Opportunity Ids from the before-delete pass into the after-delete pass. */
	@TestVisible
	private static Set<Id> deletedQuoteOpportunityIds = new Set<Id>();

	/** Guards the full ARR sync below; the sync's own DML re-enters this trigger. */
	@TestVisible
	private static Boolean isSyncingARR = false;

	/** One ARR pass per quote per transaction, however many trigger events arrive. */
	@TestVisible
	private static Set<Id> syncedQuoteIds = new Set<Id>();

	public ELV_QuoteTriggerHandler() {
		super('ELV_QuoteTriggerHandler');
		this.quotes = (List<Quote>) Trigger.new;
		this.oldMap = (Map<Id, Quote>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		if (new Set<Id>{ '005cc00000Ce5F0AAJ' }.contains(UserInfo.getUserId())) {
			ELV_QuoteRollupHelper.stampSubscriptionRollups(quotes);
		}
	}

	public override void beforeUpdate() {
		// TNCI-208. Re-evaluate Marketplace tier, percent, and dollars before save.
		ELV_MarketplaceImpactService.apply(quotes);
		List<Quote> reparented = new List<Quote>();
		List<Quote> quotesRequestedForRefresh = ELV_QuoteTriggerUtility.getQuotesRequestedForRefresh(
			quotes
		);

		ELV_QuoteTriggerUtility.stampQuoteLineRollups(quotes);
		ELV_QuoteTriggerUtility.calculateMargin(quotes, oldMap);
		ELV_QuoteTriggerUtility.clearQuoteRefreshRequest(quotesRequestedForRefresh);
		ELV_QuoteTriggerUtility.markCustomCalculationNeeded(quotes, oldMap);
		ELV_QuoteTriggerUtility.updateFlagColor(quotes, oldMap);

		for (Quote q : quotes) {
			Quote old = oldMap.get(q.Id);

			if (old != null && q.AccountId != old.AccountId) {
				reparented.add(q);
			}
		}

		if (
			!reparented.isEmpty() &&
			new Set<Id>{ '005cc00000Ce5F0AAJ' }.contains(UserInfo.getUserId())
		) {
			ELV_QuoteRollupHelper.stampSubscriptionRollups(reparented);
		}
	}

	/**
	 * TNCI-206 / ELV-DM-010 Layer 2. Carries the Day 1 ARR start date cascade onto the
	 * quote lines as stored data. After update, not before, because the ordering is forced:
	 * lines commit, then the Quote roll-ups recalculate, then the cascade resolves, and only
	 * then can the lines be stamped.
	 */
	public override void afterInsert() {
		// TNCI-206. A quote created with lines already attached - a clone, a renewal, or an
		// amendment - never sees an update, and a roll-up recalculating does not fire this
		// trigger, so without this call its lines are never stamped and every ARR figure on
		// the quote reads zero. This is the newly created quote anomaly.
		syncARR(new Map<Id, Quote>(quotes).keySet());

		ELV_SalesARRStampService.stampQuotes(new Map<Id, Quote>(quotes).keySet());

		// TNCI 139 / ELV-CPQ-036. A new quote can be primary from the outset, so the
		// Opportunity is refreshed on insert as well as on change.
		ELV_OpportunityARRService.recalculate(
			ELV_OpportunityARRService.opportunityIdsForChangedQuotes(quotes, null)
		);
	}

	public override void afterUpdate() {
		ELV_Day1ARRStampHelper.stampChangedQuotes(quotes, oldMap);

		// TNCI 139 / ELV-CPQ-036. Sales ARR is stamped after save because it depends on the
		// Day 1 ARR Unadjusted roll-up, which does not recalculate until the line save has
		// committed. The service suppresses its own re-entry and skips unchanged quotes.
		ELV_SalesARRStampService.stampQuotes(new Map<Id, Quote>(quotes).keySet());

		// TNCI 139 / ELV-CPQ-036. A refresh requested by the line trigger cannot rely on the
		// helper's change check: the quote is touched only after the roll-ups have already
		// recalculated, so the cascade may read the same value in Trigger.new and Trigger.old
		// while the lines are stale. For those quotes the stamp is recomputed from the stored
		// record instead. The dirty check still keeps a clean quote at zero DML.
		Set<Id> refreshRequested = new Set<Id>();
		for (Quote quote : quotes) {
			Quote oldQuote = oldMap == null ? null : oldMap.get(quote.Id);
			if (oldQuote != null && oldQuote.ELV_Refresh_Quote__c == true) {
				refreshRequested.add(quote.Id);
			}
		}

		if (!refreshRequested.isEmpty()) {
			syncARR(refreshRequested);
		}

		Set<Id> quotesWithChannelDiscountInputChanges =
			ELV_QuoteTriggerUtility.getQuoteIdsWithChannelDiscountInputsChanged(quotes, oldMap);
		requestChannelDiscountRefresh(quotesWithChannelDiscountInputChanges);
		ELV_CustomCalculationClearQueueable.enqueue(quotesWithChannelDiscountInputChanges);

		// TNCI 139 / ELV-CPQ-036. A quote-side recalculation raises no event on the
		// Opportunity, so the field-change test here - not an Opportunity trigger - is what
		// tells the ARR service to re-run.
		ELV_OpportunityARRService.recalculate(
			ELV_OpportunityARRService.opportunityIdsForChangedQuotes(quotes, oldMap)
		);
	}

	/**
	 * TNCI-206 / TNCI-139. One ordered ARR pass for a set of quotes.
	 *
	 *   1. Stamp the Day 1 ARR start date onto every line.
	 *   2. Derive Include in Exit ARR from the quote's max line end date - the port of CPQ
	 *      price rules 12, 8 and 16, which derived the flag and never left it to a user.
	 *   3. Stamp Day 1 again. Step 1 changes Include in Day 1 ARR, which moves the roll-up,
	 *      which can move the cascade one hop; the dirty check makes a settled quote free.
	 *   4. Stamp Sales ARR, which depends on the roll-up the steps above just moved.
	 *   5. Re-derive the parent Opportunity. A roll-up recalculating from line DML raises no
	 *      Quote event, so nothing else would tell the Opportunity service to run.
	 *
	 * The guard is required because every step commits DML that re-enters this trigger.
	 *
	 * Public because the quote line trigger calls it directly. The refresh-flag round trip
	 * cannot carry a new quote: the flag is written and cleared inside one update, so the
	 * after-update pass sees the old value as false and the branch never runs.
	 */
	public static void syncARR(Set<Id> quoteIds) {
		if (isSyncingARR || quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		Set<Id> toSync = new Set<Id>(quoteIds);
		toSync.removeAll(syncedQuoteIds);
		if (toSync.isEmpty()) {
			return;
		}
		syncedQuoteIds.addAll(toSync);

		// Deferred whenever it can be. Inside the saving transaction the Quote roll-ups have
		// not recalculated, so the Day 1 cascade still reads its pre-save value - blank on a
		// new quote. After the commit it resolves, and the stamp is right the first time.
		if (canEnqueue()) {
			System.enqueueJob(new ELV_ARRSyncQueueable(toSync));
			return;
		}

		runSync(toSync);
	}

	/** Already asynchronous, out of queueable slots, or in a context that forbids chaining. */
	private static Boolean canEnqueue() {
		return !System.isQueueable() &&
			!System.isBatch() &&
			!System.isFuture() &&
			Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
	}

	private static void requestChannelDiscountRefresh(Set<Id> quoteIds) {
		if (quoteIds == null || quoteIds.isEmpty()) {
			return;
		}

		Set<Id> quoteLineIds = new Set<Id>();
		for (QuoteLineItem quoteLine : [
			SELECT Id
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIds
			AND Ruby__LineType__c IN ('LineItem', 'RampItem')
		]) {
			quoteLineIds.add(quoteLine.Id);
		}

		ELV_QuoteLineTriggerUtility.requestDerivedValueRefresh(quoteLineIds);
	}

	/**
	 * The pass itself. Stamp, derive Include in Exit ARR, stamp again to settle the one-hop
	 * feedback, stamp Sales ARR, then re-derive the Opportunity - a roll-up recalculated by a
	 * line change raises no Quote event, so nothing else would tell the service to run.
	 */
	private static void runSync(Set<Id> quoteIds) {
		isSyncingARR = true;
		try {
			ELV_Day1ARRStampHelper.refreshAndSave(quoteIds);

			// GAP-07. Do not return when Exit ARR is already settled. OEM totals, Marketplace
			// values, and Opportunity ARR remain independent required calculations in this path.
			ELV_ExitARRHelper.refreshAndSave(quoteIds);
			ELV_Day1ARRStampHelper.refreshAndSave(quoteIds);
			ELV_SalesARRStampService.stampQuotes(quoteIds);
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
		} finally {
			isSyncingARR = false;
		}
	}

	/**
	 * TNCI 139 / ELV-CPQ-036. Deleting the primary quote clears Ruby__PrimaryQuote__c without
	 * firing any Opportunity trigger, so the Opportunity would otherwise keep quote-sourced
	 * ARR for a quote that no longer exists. The lookup has to be read while the quote still
	 * exists, so the Ids are captured before delete and the refresh runs after the delete
	 * commits, when the lookup reads as blank and precedence falls to the junction branch.
	 */
	public override void beforeDelete() {
		deletedQuoteOpportunityIds.addAll(
			ELV_OpportunityARRService.opportunityIdsFor(
				oldMap == null ? new List<Quote>() : oldMap.values()
			)
		);
	}

	public override void afterDelete() {
		if (deletedQuoteOpportunityIds.isEmpty()) {
			return;
		}

		Set<Id> toRefresh = new Set<Id>(deletedQuoteOpportunityIds);
		deletedQuoteOpportunityIds.clear();
		ELV_OpportunityARRService.recalculate(toRefresh);
	}
}