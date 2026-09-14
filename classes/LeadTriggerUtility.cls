/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Trigger Utility class on Lead object
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12496   2026-02-25    Created class based on LeadTriggerHandler class, removed methods createCampaignMember,
 * SS-13499   2026-07-08    Removed SPIFF/Vertical/Matched Contact field references
 */
public with sharing class LeadTriggerUtility {
	private static final Id OPP_REG_RECORD_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Lead',
		'Opportunity_Registration'
	);
	private static final Set<String> EXCLUDED_STATUSES = new Set<String>{
		'Reject',
		'Sales Qualified Appointment',
		'Pending SQA Approval',
		'Qualified'
	};
	private static final Set<String> PROFILES_ALLOWED_TO_DELETE_OPP_REG = new Set<String>{
		'Tanium System Administrator',
		'System Administrator'
	};

	public static void assignOppManager(List<Lead> leads) {
		Map<Id, Id> leadIdToOppId = new Map<Id, Id>();

		for (Lead lead : leads) {
			if (lead.IsConverted && lead.ConvertedOpportunityId != null) {
				leadIdToOppId.put(lead.Id, lead.ConvertedOpportunityId);
			}
		}
		if (leadIdToOppId.isEmpty()) {
			assignOppManager(leadIdToOppId);
		}
	}

	public static void assignOppManager(Map<Id, Id> leadIdToOppId) {
		Set<Id> oppOwnerIds = new Set<Id>();
		Map<Id, Id> userIdsManagerIdsMap = new Map<Id, Id>();
		List<Opportunity> opps = [
			SELECT Id, Name, OwnerId, Opportunity_Manager__c, Probability
			FROM Opportunity
			WHERE Id IN :leadIdToOppId.values()
		];
		for (Opportunity opp : opps) {
			oppOwnerIds.add(opp.OwnerId);
		}
		for (User user : [SELECT Id, ManagerId FROM User WHERE Id IN :oppOwnerIds]) {
			if (user.ManagerId != null) {
				userIdsManagerIdsMap.put(user.id, user.ManagerId);
			}
		}
		for (Opportunity opp : opps) {
			if (userIdsManagerIdsMap.get(opp.OwnerId) != null) {
				opp.Opportunity_Manager__c = userIdsManagerIdsMap.get(opp.OwnerId);
				opp.Probability = 1;
			}
		}
		List<Database.SaveResult> saveResults = Database.update(opps, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'LeadTriggerUtility.assignOppManager ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void updateOwnerBasedOnTerritory(List<Lead> leads, Map<Id, Lead> oldMap) {
		Set<Id> leadIds = new Set<Id>();

		for (Lead lead : leads) {
			if (String.isNotBlank(lead.Country)) {
				if (
					((lead.State != null &&
					lead.State != oldMap.get(lead.Id).State) ||
					(lead.Country != null &&
					lead.Country != oldMap.get(lead.Id).Country)) &&
					!EXCLUDED_STATUSES.contains(lead.Status)
				) {
					leadIds.add(lead.Id);
				}
			}
		}
		if (!leadIds.isEmpty()) {
			runAccountMatch(leadIds);
		}
	}

	public static void checkDeletePermission(List<Lead> leads) {
		String userProfile = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name;

		for (Lead lead : leads) {
			if (!FeatureManagement.checkPermission(Constants.DELETE_LEADS_AND_CONTACTS_PERMISSION)) {
				lead.addError(System.Label.Lead_Deletion_Restricted);
			}
		}
	}

	@TestVisible
	@future
	private static void runAccountMatch(Set<Id> leadIds) {
		List<Lead> leads = [
			SELECT
				Id,
				Email,
				Company,
				Account__c,
				RecordTypeId,
				IsConverted,
				Status,
				Country,
				State
			FROM Lead
			WHERE Id IN :leadIds
		];
		LeadAccountMatchInvocable.buildLeadToMatchingAccountMap(leads);
	}
}