/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Standard trigger handler for Opportunity_Partners__c object.
 * @Date: 2015-07-09
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * TAN-719    2018-12-20    Test class optimization and issue fix - Updated calcPartnerCommissionAmount() function to resolve NPE error
 * SS-8013	  2024-08-01	Add Nebula logger on existing DMLs
 * SS-13498   2026-07-10    Removed deprecated Opportunity.Distributor_Opportunity_Partner__c field reference
 */
public class OpportunityPartnerTriggerHandler extends TriggerHandler {
	private List<Opportunity_Partners__c> newOppPartners;

	public OpportunityPartnerTriggerHandler() {
		super('OpportunityPartnerTriggerHandler');
		this.newOppPartners = (List<Opportunity_Partners__c>) Trigger.new;
	}

	public override void beforeInsert() {
		updatePartnerRoleFlags(newOppPartners);
	}

	public override void afterInsert() {
		List<Opportunity> populatedOpps = populateOpportunityPartners(newOppPartners);
		try{
			update populatedOpps;
		} catch (Exception e) {
			Logger.error('OpportunityPartnerTriggerHandler.afterInsert ERRORS', e);
			Logger.saveLog();
		}
	}

	private List<Opportunity_Partners__c> updatePartnerRoleFlags(
		List<Opportunity_Partners__c> oppPartners
	) {
		for (Opportunity_Partners__c oppPartner : oppPartners) {
			if (oppPartner.Partner_Role__c == 'Reseller') {
				oppPartner.Reseller_Opportunity_Partner__c = true;
			} else if (oppPartner.Partner_Role__c == 'Distributor') {
				oppPartner.Distributor_Opportunity_Partner__c = true;
			}
		}

		return oppPartners;
	}

	private List<Opportunity> populateOpportunityPartners(List<Opportunity_Partners__c> oppPartners) {
		Map<Id, Opportunity> updatedOpportunities = new Map<Id, Opportunity>();
		Map<Id, String> accountNameMap = getPartnerAccountNames(newOppPartners);

		for (Opportunity_Partners__c oppPartner : oppPartners) {
			Opportunity relatedOpp = updatedOpportunities.get(oppPartner.Opportunity__c);
			if (relatedOpp == null) {
				relatedOpp = new Opportunity(Id = oppPartner.Opportunity__c);
				updatedOpportunities.put(relatedOpp.Id, relatedOpp);
			}

			String partnerName = accountNameMap.get(oppPartner.Account__c);

			if (oppPartner.Reseller_Opportunity_Partner__c) {
				relatedOpp.Reseller_Opportunity_Partner__c = partnerName;
			}
		}

		return updatedOpportunities.values();
	}

	private Map<Id, String> getPartnerAccountNames(List<Opportunity_Partners__c> oppPartners) {
		Map<Id, String> accountNameMap = new Map<Id, String>();
		Set<Id> accountIdSet = new Set<Id>();

		for (Opportunity_Partners__c oppPartner : oppPartners) {
			accountIdSet.add(oppPartner.Account__c);
		}

		for (Account partnerAccount : [SELECT Id, Name FROM Account WHERE Id IN :accountIdSet]) {
			accountNameMap.put(partnerAccount.Id, partnerAccount.Name);
		}

		return accountNameMap;
	}
}