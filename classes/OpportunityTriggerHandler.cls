/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Trigger handler on Opportunity Object
 * @Date: 2014-08
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-2729	  2023-11-14    When opp is closed won, save the most recent approved primary quote PDF in opportunity Notes and Attachments
 * SS-7595	  2024-05-17    Primary Quote Partner and Downstream partner validations
 * SS-8740	  2024-08-14    Add handleBusinessMotionChange
 * SS-8994    2024-10-02    Class cleanup
 * SS-9803    2024-12-09    Added call to method QuoteTrackerTriggerHandler.publishQuoteTrackerEvent
 * SS-10261   2025-05-01	Added methods to update the territory field on Opps basedon primary sales territory on the Acct/End user account
 * SS-12843   2026-03-18    Added method to check if territory needs update
 * SS-12971   2026-04-07    Sync Original_Territory2_ID__c until Opportunity is closed
 * SS-12886   2026-04-21    Removed call to method QuoteTrackerTriggerHandler.publishQuoteTrackerEvent
 * SS-13712   2026-07-30    Removed HFPOC logic
 */
public class OpportunityTriggerHandler extends TriggerHandler {
	private Opportunity[] opps;
	private Map<Id, Opportunity> oppsMap;
	private Map<Id, Opportunity> oldMap;

	public OpportunityTriggerHandler() {
		super('OpportunityTriggerHandler');
		this.opps = (Opportunity[]) Trigger.new;
		this.oppsMap = (Map<Id, Opportunity>) Trigger.newMap;
		this.oldMap = (Map<Id, Opportunity>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		OpportunityTriggerUtility.defaultRelatedAccountOwnerToOppOwner(opps);
		QuoteDefaultApproversUtility.assignAreaVPonOpps(opps);
		OpportunityTriggerUtility.handleOwnerChange(opps);
		OpportunityTriggerUtility.handleBusinessMotionChange(opps);
		PriceBookAssignmentUtility.determinePricebookId(opps);
		OpportunityTriggerUtility.updatePrimarySalesTerritoryId(opps, null);
		OpportunityTriggerUtility.syncOriginalTerritory2Id(opps, null);
	}

	public override void afterInsert() {
		OpportunityTriggerUtility.filterRecordsForMarketingAndPartnerSync(opps, null);
	}

	public override void beforeUpdate() {
		QuoteDefaultApproversUtility.assignAreaVPonOpps(opps);
		OpportunityTriggerUtility.handleOwnerChange(opps, oldMap);
		OpportunityTriggerUtility.handleBusinessMotionChange(opps, oldMap);
		OpportunityTriggerUtility.processPrimaryQuote(oppsMap, oldMap);
		OpportunityTriggerUtility.processOppPartners(oppsMap, oldMap);
		OpportunityTriggerUtility.updatePrimarySalesTerritoryId(opps, oldMap);
		OpportunityTriggerUtility.syncOriginalTerritory2Id(opps, oldMap);
	}

	public override void afterUpdate() {
		OpportunityTriggerUtility.filterRecordsForMarketingAndPartnerSync(opps, oldMap);
		BillingScheduleUtility.updateEstimatedInvoiceDate(oppsMap, oldMap);
		OpportunityRenewalUtility.updateQuotesAndLinesStartDates(opps, oldMap);
		QuoteDefaultApproversUtility.assignDefaultApproversOnOppUpdate(opps, oldMap);
		AccountTriggerUtility.publishAccounts(opps, oldMap);
		QuoteCPQTriggerUtility.processAutoGenerationQuotePDFOnOpportunityAttachments(opps, oldMap);
	}
}