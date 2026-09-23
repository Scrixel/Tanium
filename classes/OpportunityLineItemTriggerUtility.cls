/*
 * @DATE:
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Trigger Utility for the OpportunityLineItemTrigger class
 * RequestId  ModifiedDate  Comment
 * SS-8991    2024-09-19    Updated to remove Product Group filter
 */
public with sharing class OpportunityLineItemTriggerUtility {
	public static void uncheckHardwareOpportunity(OpportunityLineItem[] oppLineItems) {
		Set<Id> oppIds = new Set<Id>();
		for (OpportunityLineItem oppLineItem : oppLineItems) {
			oppIds.add(oppLineItem.OpportunityId);
		}

		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
			[SELECT Id, New_Tanium_Physical_Appliance_Required__c FROM Opportunity WHERE Id IN :oppIds]
		);
		uncheckHardwareOpportunity(oppsMap);
	}

	@TestVisible
	private static void uncheckHardwareOpportunity(Map<Id, Opportunity> oppsMap) {
		List<Opportunity> eligibleOpps = new List<Opportunity>();
		Set<Id> oppIdsNoProducts = getOppIdsWithNoOppLines(oppsMap);
		Set<Id> oppHardwareProductIds = getOppHardwareProductIds();
		Id prevOppId = null;
		Boolean hardwareOpp = false;

		// opps with no remaining oppLineItem records (post oppLineItem delete)
		for (Id oppIdNoProducts : oppIdsNoProducts) {
			if (oppsMap.get(oppIdNoProducts).New_Tanium_Physical_Appliance_Required__c) {
				eligibleOpps.add(
					new Opportunity(Id = oppIdNoProducts, New_Tanium_Physical_Appliance_Required__c = false)
				);
			}
		}

		// opps with remaining oppLineItem records (post oppLineItem delete)
		for (OpportunityLineItem oli : [
			SELECT Id, OpportunityId, Product2Id
			FROM OpportunityLineItem
			WHERE OpportunityId IN :oppsMap.keySet()
			ORDER BY OpportunityId
		]) {
			if (!oppsMap.get(oli.OpportunityId).New_Tanium_Physical_Appliance_Required__c) {
				continue;
			}
			if (prevOppId == oli.OpportunityId || prevOppId == null) {
				if (oppHardwareProductIds.contains(oli.Product2Id)) {
					hardwareOpp = true;
				}
				prevOppId = oli.OpportunityId;
			}
			if (prevOppId != oli.OpportunityId) {
				if (!hardwareOpp) {
					eligibleOpps.add(
						new Opportunity(Id = prevOppId, New_Tanium_Physical_Appliance_Required__c = hardwareOpp)
					);
				}
				hardwareOpp = false;
				prevOppId = oli.OpportunityId;
			}
		}
		if (!hardwareOpp && prevOppId != null) {
			eligibleOpps.add(
				new Opportunity(Id = prevOppId, New_Tanium_Physical_Appliance_Required__c = hardwareOpp)
			);
		}

		if (!eligibleOpps.isEmpty()) {
			updateOpportunities(eligibleOpps, 'uncheckHardwareOpportunity');
		}
	}

	@TestVisible
	private static Set<Id> getOppHardwareProductIds() {
		Map<Id, Product2> productsMap = new Map<Id, Product2>(
			[
				SELECT Id
				FROM Product2
				WHERE
					Family = 'Hardware'
					AND Product_Line__c = 'Appliance'
					AND Tanium_Infrastructure_Form_Needed__c = TRUE
			]
		);
		return productsMap.keySet();
	}

	public static void setIsSoftwareOpportunity(OpportunityLineItem[] oppLineItems) {
		Set<Id> oppIds = new Set<Id>();
		List<Opportunity> softwareOpps = new List<Opportunity>();
		List<Opportunity> nonSoftwareOpps = new List<Opportunity>();

		for (OpportunityLineItem oppLineItem : oppLineItems) {
			oppIds.add(oppLineItem.OpportunityId);
		}

		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
			[SELECT Id, Software_Opportunity__c FROM Opportunity WHERE Id IN :oppIds]
		);

		for (Opportunity opp : oppsMap.values()) {
			if (opp.Software_Opportunity__c) {
				softwareOpps.add(opp);
			} else {
				nonSoftwareOpps.add(opp);
			}
		}
		if (!softwareOpps.isEmpty()) {
			uncheckSoftwareOpportunity(oppsMap);
		}

		if (!nonSoftwareOpps.isEmpty()) {
			checkSoftwareOpportunity(oppsMap);
		}
	}

	@TestVisible
	private static void uncheckSoftwareOpportunity(Map<Id, Opportunity> oppsMap) {
		List<Opportunity> eligibleOpps = new List<Opportunity>();
		Set<Id> oppIdsNoProducts = getOppIdsWithNoOppLines(oppsMap);
		Set<Id> oppSoftwareProductIds = getOppSoftwareProductIds();
		Id prevOppId = null;
		Boolean softwareOpp = false;

		// opps with no remaining oppLineItem records (post oppLineItem delete)
		for (Id oppIdNoProducts : oppIdsNoProducts) {
			if (oppsMap.get(oppIdNoProducts).Software_Opportunity__c) {
				eligibleOpps.add(new Opportunity(Id = oppIdNoProducts, Software_Opportunity__c = false));
			}
		}

		// opps with remaining oppLineItem records (post oppLineItem delete)
		for (OpportunityLineItem oli : [
			SELECT Id, OpportunityId, Product2Id
			FROM OpportunityLineItem
			WHERE OpportunityId IN :oppsMap.keySet()
			ORDER BY OpportunityId
		]) {
			if (prevOppId == oli.OpportunityId || prevOppId == null) {
				if (oppSoftwareProductIds.contains(oli.Product2Id)) {
					softwareOpp = true;
				}
				prevOppId = oli.OpportunityId;
			}
			if (prevOppId != oli.OpportunityId) {
				if (!softwareOpp) {
					eligibleOpps.add(new Opportunity(Id = prevOppId, Software_Opportunity__c = softwareOpp));
				}
				softwareOpp = false;
				prevOppId = oli.OpportunityId;
			}
		}
		if (!softwareOpp && prevOppId != null) {
			eligibleOpps.add(new Opportunity(Id = prevOppId, Software_Opportunity__c = softwareOpp));
		}

		if (!eligibleOpps.isEmpty()) {
			updateOpportunities(eligibleOpps, 'uncheckSoftwareOpportunity');
		}
	}

	@TestVisible
	private static void checkSoftwareOpportunity(Map<Id, Opportunity> oppsMap) {
		List<Opportunity> eligibleOpps = new List<Opportunity>();
		Set<Id> oppSoftwareProductIds = getOppSoftwareProductIds();
		Id prevOppId = null;
		Boolean softwareOpp = false;

		for (OpportunityLineItem oli : [
			SELECT Id, OpportunityId, Product2Id
			FROM OpportunityLineItem
			WHERE OpportunityId IN :oppsMap.keySet()
			ORDER BY OpportunityId
		]) {
			if (prevOppId == oli.OpportunityId || prevOppId == null) {
				if (oppSoftwareProductIds.contains(oli.Product2Id)) {
					softwareOpp = true;
				}
				prevOppId = oli.OpportunityId;
			}
			if (prevOppId != oli.OpportunityId) {
				if (softwareOpp) {
					eligibleOpps.add(new Opportunity(Id = prevOppId, Software_Opportunity__c = softwareOpp));
				}
				softwareOpp = false;
				prevOppId = oli.OpportunityId;
			}
		}
		if (softwareOpp) {
			eligibleOpps.add(new Opportunity(Id = prevOppId, Software_Opportunity__c = softwareOpp));
		}

		if (!eligibleOpps.isEmpty()) {
			updateOpportunities(eligibleOpps, 'checkSoftwareOpportunity');
		}
	}

	@TestVisible
	private static Set<Id> getOppSoftwareProductIds() {
		Map<Id, Product2> productsMap = new Map<Id, Product2>(
			[SELECT Id FROM Product2 WHERE Server_Deployment_Required__c = TRUE]
		);
		return productsMap.keySet();
	}

	@TestVisible
	private static Set<Id> getOppIdsWithNoOppLines(Map<Id, Opportunity> oppsMap) {
		Set<Id> oppIds = new Set<Id>();

		AggregateResult[] oliResults = [
			SELECT OpportunityId, Count(Id)
			FROM OpportunityLineItem
			WHERE OpportunityId IN :oppsMap.keySet()
			GROUP BY OpportunityId
		];

		for (AggregateResult oliResult : oliResults) {
			if (Integer.valueOf(oliResult.get('expr0')) == 0) {
				oppIds.add((Id) oliResult.get('OpportunityId'));
			}
		}

		if (oliResults.isEmpty()) {
			oppIds = oppsMap.keySet();
		}
		return oppIds;
	}

	@TestVisible
	private static void updateOpportunities(Opportunity[] opps, String methodName) {
		Database.SaveResult[] srList = Database.update(opps, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'OpportunityLineItemTriggerUtility.updateOpportunities ERRORS',
				srList
			)
			.addTag('apex');
		Logger.saveLog();
	}
}