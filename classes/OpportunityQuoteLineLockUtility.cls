/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: OpportunityQuoteLineLockUtility class
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * Modified   ModifiedDate   Description
 * SS-7583	  2024-03-21 	 Removing BoomiRestService code references
 * SS-12676   2026-03-25     Deleted depreciated fields (Absorb_Transaction_ID__c)
 */

public with sharing class OpportunityQuoteLineLockUtility {
	public static final String CUSTOM_UNLOCK_PERMISSION = 'Allow_Closed_Quote_Editing';
	@TestVisible
	private static final List<String> LOCKED_OPPORTUNITY_STAGES = new List<String>{
		Utility.CLOSED_WON
	};
	@TestVisible
	private static final List<String> LOCKED_QUOTE_STATUSES = new List<String>{ 'Approved' };

	public static Set<Id> checkLockedOpportunityProducts(
		List<OpportunityLineItem> opportunityProductList
	) {
		Set<Id> lockedOpportunityProductIdSet = new Set<Id>();

		if (FeatureManagement.checkPermission(CUSTOM_UNLOCK_PERMISSION)) {
			return lockedOpportunityProductIdSet;
		}

		for (OpportunityLineItem opportunityProduct : [
			SELECT Id
			FROM OpportunityLineItem
			WHERE Id IN :opportunityProductList AND Opportunity.StageName IN :LOCKED_OPPORTUNITY_STAGES
		]) {
			lockedOpportunityProductIdSet.add(opportunityProduct.Id);
		}

		for (OpportunityLineItem opportunityProduct : opportunityProductList) {
			if (lockedOpportunityProductIdSet.contains(opportunityProduct.Id)) {
				opportunityProduct.addError(System.Label.Opportunity_Product_Locked);
			}
		}
		return lockedOpportunityProductIdSet;
	}

	public static Set<Id> checkLockedQuoteLines(List<SBQQ__QuoteLine__c> quoteLineList) {
		Set<Id> lockedQuoteLinesIdSet = new Set<Id>();

		if (FeatureManagement.checkPermission(CUSTOM_UNLOCK_PERMISSION)) {
			return lockedQuoteLinesIdSet;
		}

		for (SBQQ__QuoteLine__c quoteLine : [
			SELECT Id
			FROM SBQQ__QuoteLine__c
			WHERE
				Id IN :quoteLineList
				AND (SBQQ__Quote__r.SBQQ__Status__c IN :LOCKED_QUOTE_STATUSES
				OR SBQQ__Quote__r.ApprovalStatus__c IN :LOCKED_QUOTE_STATUSES)
				AND SBQQ__Quote__r.Unlock_Quote__c = FALSE
				AND SBQQ__Quote__r.Primary_Updated_and_Approved__c = FALSE
		]) {
			lockedQuoteLinesIdSet.add(quoteLine.Id);
		}

		for (SBQQ__QuoteLine__c quoteLine : quoteLineList) {
			if (lockedQuoteLinesIdSet.contains(quoteLine.Id)) {
				quoteLine.addError(System.Label.Quote_Line_Locked);
			}
		}
		return lockedQuoteLinesIdSet;
	}

	public static void setIsPrimaryUpdated(List<SBQQ__QuoteLine__c> quoteLineList) {
		List<SBQQ__Quote__c> quotesToUpdate = new List<SBQQ__Quote__c>();
		for (SBQQ__Quote__c quote : [
			SELECT Id, Primary_Updated_and_Approved__c
			FROM SBQQ__Quote__c
			WHERE
				SBQQ__Opportunity2__c = :quoteLineList[0].OpportunityId__c
				AND Primary_Updated_and_Approved__c = TRUE
		]) {
			quote.Primary_Updated_and_Approved__c = false;
			quotesToUpdate.add(quote);
		}

		Database.SaveResult[] srList = Database.update(quotesToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'OpportunityQuoteLineLockUtility.setIsPrimaryUpdated ERRORS',
				srList
			)
			.addTag('apex');
		Logger.saveLog();
	}
}