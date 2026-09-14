/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: CPQ Quote Default Approvers Utility
 * @Date: 2024-02-20
 * @Author: Tanium Dev Team
 * Modified  ModifiedDate  Description
 * SS-7487   2024-02-20    Duplicate Id Exception
 * SS-7766   2024-05-15    Added Nebula Logger func.
 * SS-9255   2024-12-21    Deal Desk Approver blank bug when Opp Owner is changed
 * SS-9640   2024-01-16    Remove Deal Desk Approver logic
 * SS-7504   2025-07-23    Delete Role Based Quote Approver Management metadata reference
 * SS-10186  2026-02-27    Removed reference to Level fields in User object
 * SS-13829  2026-08-11    Populate Quote Customer_SuccessRVP__c from Opportunity Customer_Success_RVP__c
 */
public with sharing class QuoteDefaultApproversUtility {
	public static void assignDefaultApproversOnOppUpdate(
		List<Opportunity> updatedOpportunityList,
		Map<Id, Opportunity> oldOpportunityMap
	) {
		List<SBQQ__Quote__c> quotesToUpdate = new List<SBQQ__Quote__c>();
		List<Opportunity> opportunityToUpdateDefaultApprover = new List<Opportunity>();

		for (Opportunity updatedOpportunity : updatedOpportunityList) {
			Opportunity oldOpportunity = oldOpportunityMap.get(updatedOpportunity.Id);
			if (
				(updatedOpportunity.AreaVP__c != oldOpportunity.AreaVP__c ||
				updatedOpportunity.Opportunity_Manager__c != oldOpportunity.Opportunity_Manager__c ||
				updatedOpportunity.VP__c != oldOpportunity.VP__c ||
				updatedOpportunity.Customer_Success_RVP__c != oldOpportunity.Customer_Success_RVP__c) &&
				!opportunityToUpdateDefaultApprover.contains(updatedOpportunity)
			) {
				opportunityToUpdateDefaultApprover.add(updatedOpportunity);
			}
		}

		if (!opportunityToUpdateDefaultApprover.isEmpty()) {
			List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>(
				[
					SELECT
						Id,
						AreaVP__c,
						Opp_OwnerManager__c,
						Deal_Desk_Approver__c,
						SBQQ__Opportunity2__c,
						SVP__c,
						Customer_SuccessRVP__c
					FROM SBQQ__Quote__c
					WHERE
						SBQQ__Opportunity2__c IN :opportunityToUpdateDefaultApprover
						AND SBQQ__Status__c = 'Draft'
				]
			);

			quotesToUpdate = getQuoteDefaultApprovers(opportunityToUpdateDefaultApprover, quotes);
			try {
				update quotesToUpdate;
			} catch (Exception e) {
				Logger.error(
					'QuoteDefaultApproversUtility.assignDefaultApproversOnOppUpdate ERRORS',
					e
				);
				Logger.saveLog();
			}
		}
	}

	public static void assignDefaultApproversOnQuoteInsert(List<SBQQ__Quote__c> newQuotes) {
		Set<Id> setOpptIds = new Set<Id>();

		for (SBQQ__Quote__c quote : newQuotes) {
			if (quote.SBQQ__Status__c == 'Draft')
				setOpptIds.add(quote.SBQQ__Opportunity2__c);
		}

		List<Opportunity> parentOpportunities = new List<Opportunity>(
			[
				SELECT
					Id,
					Type,
					Pricebook2Id,
					OwnerId,
					AreaVP__c,
					Opportunity_Manager__c,
					VP__c,
					Customer_Success_RVP__c
				FROM Opportunity
				WHERE Id IN :setOpptIds
			]
		);

		getQuoteDefaultApprovers(parentOpportunities, newQuotes);
	}

	private static List<SBQQ__Quote__c> getQuoteDefaultApprovers(
		List<Opportunity> parentOpportunities,
		List<SBQQ__Quote__c> quotes
	) {
		List<SBQQ__Quote__c> quoteUpdateList = new List<SBQQ__Quote__c>();
		Map<Id, Opportunity> opportunityIdMap = new Map<Id, Opportunity>();
		Map<Id, Id> opportunityIdDealDeskApproverMap = new Map<Id, Id>();
		Map<Id, Id> ownerIdOpportunityIdMap = new Map<Id, Id>();
		Map<Id, User> opportunityIdOwnerMap = new Map<Id, User>();

		for (Opportunity opportunity : parentOpportunities) {
			opportunityIdMap.put(opportunity.Id, opportunity);
			ownerIdOpportunityIdMap.put(opportunity.OwnerId, opportunity.Id);
		}

		for (User opportunityOwner : [
			SELECT Id, ManagerId
			FROM User
			WHERE Id IN :ownerIdOpportunityIdMap.keySet()
		]) {
			Id opportunityId = ownerIdOpportunityIdMap.get(opportunityOwner.Id);
			opportunityIdOwnerMap.put(opportunityId, opportunityOwner);
		}

		for (SBQQ__Quote__c quote : quotes) {
			Opportunity parentOpportunity = opportunityIdMap.get(quote.SBQQ__Opportunity2__c);
			User opportunityOwner = opportunityIdOwnerMap.get(quote.SBQQ__Opportunity2__c);
			assignOppApprovers(quote, parentOpportunity);
			quoteUpdateList.add(quote);
		}

		return quoteUpdateList;
	}

	@TestVisible
	private static SBQQ__Quote__c assignOppApprovers(
		SBQQ__Quote__c quote,
		Opportunity parentOpportunity
	) {
		quote.AreaVP__c = parentOpportunity?.AreaVP__c;
		quote.Opp_OwnerManager__c = parentOpportunity?.Opportunity_Manager__c;
		quote.SVP__c = parentOpportunity?.VP__c;
		quote.Customer_SuccessRVP__c = parentOpportunity?.Customer_Success_RVP__c;

		return quote;
	}

	public static void assignAreaVPonOpps(List<Opportunity> newOpportunities) {
		Set<Id> ownerIds = new Set<Id>();
		for (Opportunity newOpp : newOpportunities) {
			ownerIds.add(newOpp.OwnerId);
		}

		Map<Id, User> mapOwnerIds = new Map<Id, User>(
			[SELECT Id, Area_VP__c, VP__c FROM User WHERE Id IN :ownerIds]
		);

		for (Opportunity newOpp : newOpportunities) {
			if (mapOwnerIds.containsKey(newOpp.OwnerId)) {
				if (newOpp.AreaVP__c != mapOwnerIds.get(newOpp.OwnerId).Area_VP__c) {
					newOpp.AreaVP__c = mapOwnerIds.get(newOpp.OwnerId).Area_VP__c;
				}
				if (newOpp.VP__c != mapOwnerIds.get(newOpp.OwnerId).VP__c) {
					newOpp.VP__c = mapOwnerIds.get(newOpp.OwnerId).VP__c;
				}
			}
		}
	}
}