/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Handler for the standard Quote Line Item (QuoteLineItem) trigger.
 */
public with sharing class ELV_QuoteLineTriggerHandler extends TriggerHandler {
	private static final String QUOTE_STATUS_DRAFT = 'Draft';
	private static final String QUOTE_STATUS_NEEDS_REVIEW = 'Needs Review';

	private List<QuoteLineItem> quoteLines;
	private Map<Id, QuoteLineItem> oldMap;

	public ELV_QuoteLineTriggerHandler() {
		super('ELV_QuoteLineTriggerHandler');
		quoteLines = (List<QuoteLineItem>) Trigger.new;
		oldMap = (Map<Id, QuoteLineItem>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		System.debug(
			LoggingLevel.INFO,
			'ELV_QuoteLineTriggerHandler.beforeInsert fired. QuoteLineItem count=' + quoteLines.size()
		);
		logBeforeInsertQuoteLines();
		ELV_QuoteLineTriggerUtility.populateChangedSubscription(quoteLines);
		ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(quoteLines, null);
		ELV_QuoteLineTriggerUtility.stampHasTaniumPricingSchedule(quoteLines);
		ELV_QuoteLineTriggerUtility.stampIsRenewalTransaction(quoteLines);
		ELV_QuoteLineTriggerUtility.stampQuotaRetirementEligible(quoteLines, null);
		// TNCI-208. Calculate OEM fee from the discounted Legacy Quote Line Total Price before save.
		ELV_OEMFeeService.apply(quoteLines);
		ELV_QuoteLineTriggerUtility.stampChannelDiscounts(quoteLines, null);
	}

	public override void beforeUpdate() {
		ELV_QuoteLineTriggerUtility.stampProductExcludeFromARR(quoteLines, oldMap);
		ELV_QuoteLineTriggerUtility.stampQuotaRetirementEligible(quoteLines, oldMap);
		// TNCI-208. Re-evaluate OEM fee from the discounted Legacy Quote Line Total Price before save.
		ELV_OEMFeeService.apply(quoteLines);
		ELV_QuoteLineTriggerUtility.stampHasTaniumPricingSchedule(quoteLines);
		ELV_QuoteLineTriggerUtility.stampIsRenewalTransaction(quoteLines);
		ELV_QuoteLineTriggerUtility.stampChannelDiscounts(quoteLines, oldMap);
	}

	public override void afterUpdate() {
		List<QuoteLineItem> unlockedQuoteLines = getLinesForUnlockedQuotes(quoteLines);
		if (unlockedQuoteLines.isEmpty()) {
			return;
		}

		ELV_QuoteRecalculationService.requestRecalculation(unlockedQuoteLines, oldMap);
		ELV_QuoteLineTriggerUtility.requestQuoteRefreshOnQualifyingChange(unlockedQuoteLines, oldMap);

		// TNCI 139 / ELV-CPQ-036. The quota retirement copy is taken after save because the
		// formula it mirrors reaches through Quote.Opportunity and is not resolved in memory.
		ELV_QuotaRetirementStampService.stampLines(new Map<Id, QuoteLineItem>(unlockedQuoteLines).keySet());

		QuoteTriggerHandler.syncARR(quoteIds(unlockedQuoteLines));
	}

	/** A new line always moves the roll-ups, so no field comparison is possible or needed. */
	public override void afterInsert() {
		List<QuoteLineItem> unlockedQuoteLines = getLinesForUnlockedQuotes(quoteLines);
		ELV_QuoteRecalculationService.requestRecalculationForStampedDiscounts(unlockedQuoteLines);
		ELV_QuoteLineTriggerUtility.requestQuoteRefresh(quoteLines);
		ELV_QuotaRetirementStampService.stampLines(new Map<Id, QuoteLineItem>(quoteLines).keySet());

		// TNCI-206. The refresh request alone cannot stamp a quote whose lines have just been
		// inserted: the request writes and clears the flag inside a single update, so the
		// after-update branch reads the old value as false. The ARR pass is therefore invoked
		// from here, where the parent ids are known and the lines have committed.
		QuoteTriggerHandler.syncARR(quoteIds(quoteLines));
	}

	/** Deleting the earliest line shifts the cascade for every surviving line on the quote. */
	public override void afterDelete() {
		List<QuoteLineItem> deleted = oldMap == null
			? new List<QuoteLineItem>()
			: oldMap.values();
		ELV_QuoteLineTriggerUtility.requestQuoteRefresh(deleted);
		QuoteTriggerHandler.syncARR(quoteIds(deleted));
	}

	public override void afterUndelete() {
		ELV_QuoteLineTriggerUtility.requestQuoteRefresh(quoteLines);
		QuoteTriggerHandler.syncARR(quoteIds(quoteLines));
	}

	/** The distinct parent quotes behind a set of lines. */
	private static Set<Id> quoteIds(List<QuoteLineItem> lines) {
		Set<Id> ids = new Set<Id>();

		if (lines == null) {
			return ids;
		}

		for (QuoteLineItem line : lines) {
			if (line.QuoteId != null) {
				ids.add(line.QuoteId);
			}
		}

		return ids;
	}

	private static List<QuoteLineItem> getLinesForUnlockedQuotes(List<QuoteLineItem> lines) {
		List<QuoteLineItem> unlockedQuoteLines = new List<QuoteLineItem>();
		if (lines == null || lines.isEmpty()) {
			return unlockedQuoteLines;
		}

		Set<Id> quoteIds = quoteIds(lines);
		if (quoteIds.isEmpty()) {
			return unlockedQuoteLines;
		}

		Set<String> unlockedStatuses = new Set<String>{
			QUOTE_STATUS_DRAFT,
			QUOTE_STATUS_NEEDS_REVIEW
		};
		Set<Id> unlockedQuoteIds = new Set<Id>();
		for (Quote quote : [
			SELECT Id
			FROM Quote
			WHERE Id IN :quoteIds AND Status IN :unlockedStatuses
		]) {
			unlockedQuoteIds.add(quote.Id);
		}

		for (QuoteLineItem line : lines) {
			if (unlockedQuoteIds.contains(line.QuoteId)) {
				unlockedQuoteLines.add(line);
			}
		}

		return unlockedQuoteLines;
	}

	private void logBeforeInsertQuoteLines() {
		Integer index = 0;
		for (QuoteLineItem quoteLine : quoteLines) {
			System.debug(
				LoggingLevel.INFO,
				'ELV_QuoteLineTriggerHandler.beforeInsert QuoteLineItem[' +
					index +
					'] Id=' +
					quoteLine.Id +
					', QuoteId=' +
					quoteLine.QuoteId +
					', Ruby__LineType__c=' +
					quoteLine.Ruby__LineType__c +
					', Ruby__ChangeType__c=' +
					quoteLine.Ruby__ChangeType__c
			);
			index++;
		}
	}
}