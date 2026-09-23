/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Handler for standard Quote (Nue)
 * @Description: Ports a subset of QuoteCPQTriggerUtility's SBQQ__Quote__c behaviors onto standard Quote; quote cloning moved to a separate ticket.
 * @Date: 2026-09-09
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13958   2026-09-15    Added AI credits calc, billing quote terms sync
 */
public class QuoteTriggerHandler extends TriggerHandler {
	private List<Quote> quotes;
	private Map<Id, Quote> oldMap;

	public QuoteTriggerHandler() {
		super('QuoteTriggerHandler');
		this.quotes = (List<Quote>) Trigger.new;
		this.oldMap = (Map<Id, Quote>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		QuoteTriggerUtility.setPartnerAccreditationValues(quotes, null);
		QuoteTriggerUtility.setBillingRelatedFieldsOnQuote(quotes);
	}

	public override void beforeUpdate() {
		QuoteTriggerUtility.setPartnerAccreditationValues(quotes, oldMap);
		QuoteTriggerUtility.setAICredits(quotes, oldMap);
	}

	public override void afterUpdate() {
		QuoteTriggerUtility.processBillingScheduleOnOpportunity(quotes, oldMap);
		QuoteTriggerUtility.updateBillingQuoteTerms(quotes, oldMap);
		QuoteTriggerUtility.processIdentifyNewModules(quotes, oldMap);
	}

	public override void beforeDelete() {
		QuoteTriggerUtility.handleDeletedQuotes(oldMap.values());
	}
}