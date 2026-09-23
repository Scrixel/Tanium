/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Handler for CPQ Quote
 * @Date: 2018-11-08
 * @Author: Cumulus Vision, Tanium Dev TEAM
 * @Request: TAN-705
 * RequestId  ModifiedDate  Description
 * SS-2729    2023-12-14    When quote is approved, quote PDF is saved in Quote Documents section
 * SS-7083    2024-01-24    Deployment Provider conditions for quote
 * SS-7162    2024-02-02    Added call to method recalculateRenewalQuote, updated variables in line with Tanium's dev design pattern
 * SS-7665    2024-04-23    isMSP to use quote.Business_Motion_Oppty='MSP'
 * SS-7618    2024-05-08    Partner is required on  quote.Business_Motion_Oppty='MSP'
 * SS-7618    2024-05-16    Missing partner error
 * SS-8788    2024-09-13    Added setL1L2Provider()
 * SS-9803    2024-12-10    Added calls to method QuoteTrackerTriggerHandler.publishQuoteTrackerEvent
 * SS-10086   2025-01-27    Remove setL1L2Provider()
 * SS-11278   2025-07-10    Remove setPaymentTermOnBillingQuoteTerms()
 * SS-12364   2026-01-22    Renamed method recalculateRenewalQuote to processRenewalQuote, added call to method processAmendmentQuote
 * SS-12404   2026-02-27    Updated method calls determineLegalEntitiesBeforeInsert and determineLegalEntitiesBeforeUpdate
 * SS-12833   2026-03-16    Revert Identify New Modules related code
 * SS-12833   2026-03-16    Revert Identify New Modules related code
 * SS-12818   2026-03-17    Add processIdentifyNewModules()
 * SS-12886   2026-04-21    Removed call to method QuoteTrackerTriggerHandler.publishQuoteTrackerEvent
 * SS-13648   2026-08-03    Added call to method setAICredits
 */

public class QuoteCPQTriggerHandler extends TriggerHandler {
	private List<SBQQ__Quote__c> quotes;
	private Map<Id, SBQQ__Quote__c> oldMap;

	public QuoteCPQTriggerHandler() {
		super('QuoteCPQTriggerHandler');
		this.quotes = (List<SBQQ__Quote__c>) Trigger.new;
		this.oldMap = (Map<Id, SBQQ__Quote__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		QuoteCPQTriggerUtility.determineLegalEntitiesBeforeInsert(quotes);
		QuoteDefaultApproversUtility.assignDefaultApproversOnQuoteInsert(quotes);
		QuoteCPQTriggerUtility.quoteMidMarketValidations(quotes);
		QuoteCPQTriggerUtility.setPartnerAccreditationValues(quotes, null);
		QuoteCPQTriggerUtility.setLockInDates(quotes);
		QuoteCPQTriggerUtility.setBillingRelatedFieldsOnQuote(quotes);
		QuoteCPQTriggerUtility.checkDeploymentProvider(quotes, null);
	}

	public override void afterInsert() {
		QuoteCPQTriggerUtility.determineIfQuoteWasCloned(quotes);
		QuoteCPQTriggerUtility.processRenewalQuote(new Map<Id, SBQQ__Quote__c>(quotes));
	}

	public override void beforeUpdate() {
		QuoteCPQTriggerUtility.setIsPrimaryUpdated(quotes, oldMap);
		QuoteCPQTriggerUtility.determineLegalEntitiesBeforeUpdate(quotes, oldMap);
		QuoteCPQTriggerUtility.quoteMidMarketValidations(quotes);
		QuoteCPQTriggerUtility.setPartnerAccreditationValues(quotes, oldMap);
		QuoteCPQTriggerUtility.checkDeploymentProvider(quotes, oldMap);
		QuoteCPQTriggerUtility.checkPartner(quotes, oldMap);
		QuoteCPQTriggerUtility.setAICredits(quotes, oldMap);
	}

	public override void afterUpdate() {
		QuoteCPQTriggerUtility.processBillingScheduleOnOpportunity(quotes, oldMap);
		QuoteCPQTriggerUtility.updateBillingQuoteTerms(quotes, oldMap);
		QuoteCPQTriggerUtility.processQuoteDocuments(quotes, oldMap);
		QuoteCPQTriggerUtility.processIdentifyNewModules(quotes, oldMap);
	}

	public override void beforeDelete() {
		QuoteCPQTriggerUtility.handleDeletedQuotes(oldMap.values());
	}
}