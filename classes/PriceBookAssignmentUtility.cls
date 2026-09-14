/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: class for Picebook assignment
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * Modified   ModifiedDate   Description
 * SS-7665    2024-04-23     isMSP to use quote.Business_Motion_Oppty='MSP'
 * SS-7620    2024-04-18     Deactivating MSP Pricebook
 * SS-12676   2026-03-25     Deleted depreciated fields (Absorb_Transaction_ID__c), deleted isAbsorb method, deleted reference in prefillPriceBook method
 * SS-13176   2026-05-27     Removed Level_2__c reference
 */
public with sharing class PriceBookAssignmentUtility {
	public static final Id PARTNER_RECORD_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Account',
		'Partner'
	);

	public static void determinePricebookId(List<Opportunity> newOpportunities) {
		Set<Id> uniqueAccounts = new Set<Id>();
		Map<Id, Account> accountMap = new Map<Id, Account>();
		List<Opportunity> opportunitiesToAdjust = new List<Opportunity>();

		for (Opportunity newOpportunity : newOpportunities) {
			if (newOpportunity.AccountId != null) {
				uniqueAccounts.add(newOpportunity.AccountId);
				opportunitiesToAdjust.add(newOpportunity);
			}
		}

		if (!opportunitiesToAdjust.isEmpty()) {
			prefillPriceBook(opportunitiesToAdjust, uniqueAccounts, getPricebookNameIdMap());
		}
	}

	@TestVisible
	private static Map<String, Id> getPricebookNameIdMap() {
		Map<String, Id> pricebookNameIdMap = new Map<String, Id>();

		for (Pricebook_Assignments__mdt pricebookAssignment : [
			SELECT MasterLabel, Pricebook_Id__c
			FROM Pricebook_Assignments__mdt
		]) {
			pricebookNameIdMap.put(
				pricebookAssignment.MasterLabel,
				pricebookAssignment.Pricebook_Id__c
			);
		}

		return pricebookNameIdMap;
	}

	@TestVisible
	private static void prefillPriceBook(
		List<Opportunity> opportunitiesToAdjust,
		Set<Id> uniqueAccounts,
		Map<String, Id> pricebookNameIdMap
	) {
		Map<Id, Account> accountOwnerMap = new Map<Id, Account>(
			[
				SELECT
					Id,
					RecordTypeId,
					Type,
					Segment__c
				FROM Account
				WHERE Id IN :uniqueAccounts
			]
		);

		for (Opportunity opportunity : opportunitiesToAdjust) {
			Account ownerAccount = accountOwnerMap.get(opportunity.AccountId);

			if (isPOC(opportunity)) {
				opportunity.Pricebook2Id = pricebookNameIdMap.get('POC');
			} else if (isIRAssessment(opportunity)) {
				opportunity.Pricebook2Id = pricebookNameIdMap.get('IR Assessment');
			} else {
				opportunity.Pricebook2Id = pricebookNameIdMap.get('Default');
			}
		}
	}

	@TestVisible
	private static Boolean isPOC(Opportunity opportunity) {
		return (opportunity?.Type == 'POC');
	}

	@TestVisible
	private static Boolean isIRAssessment(Opportunity opportunity) {
		return (opportunity?.Type == 'Consulting');
	}
}