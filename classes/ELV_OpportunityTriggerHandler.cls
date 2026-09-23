/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. Entry-point handler for Opportunity-side changes that
 *            can move the ELV ARR figures. Opportunity already has multiple active triggers,
 *            so the service owns recursion control and re-reads committed data rather than
 *            relying on this trigger to run first or last.
 */
public with sharing class ELV_OpportunityTriggerHandler extends TriggerHandler {
	private List<Opportunity> opportunities;
	private Map<Id, Opportunity> oldMap;

	public ELV_OpportunityTriggerHandler() {
		super('ELV_OpportunityTriggerHandler');
		this.opportunities = (List<Opportunity>) Trigger.new;
		this.oldMap = (Map<Id, Opportunity>) Trigger.oldMap;
	}

	public override void afterInsert() {
		ELV_OpportunityARRService.recalculate(new Map<Id, Opportunity>(opportunities).keySet());
	}

	public override void afterUpdate() {
		Set<Id> changed = new Set<Id>();

		for (Opportunity opp : opportunities) {
			Opportunity oldOpp = oldMap == null ? null : oldMap.get(opp.Id);

			if (oldOpp == null || hasRelevantChange(opp, oldOpp)) {
				changed.add(opp.Id);
			}
		}

		ELV_OpportunityARRService.recalculate(changed);
	}

	@TestVisible
	private static Boolean hasRelevantChange(Opportunity opp, Opportunity oldOpp) {
		return opp.Ruby__PrimaryQuote__c != oldOpp.Ruby__PrimaryQuote__c ||
			opp.Split_Percent__c != oldOpp.Split_Percent__c ||
			opp.StageName != oldOpp.StageName ||
			opp.Type != oldOpp.Type ||
			opp.RVP_CHURN_RISK_OVERIDE__c != oldOpp.RVP_CHURN_RISK_OVERIDE__c ||
			opp.In_Year_ARR_Adjustment__c != oldOpp.In_Year_ARR_Adjustment__c ||
			opp.Incoming_ARR_Override__c != oldOpp.Incoming_ARR_Override__c ||
			opp.Incoming_ARR_Rollup__c != oldOpp.Incoming_ARR_Rollup__c ||
			opp.Ramped_Opportunity__c != oldOpp.Ramped_Opportunity__c;
	}
}