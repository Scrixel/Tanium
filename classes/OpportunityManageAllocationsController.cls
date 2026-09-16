/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller for the opportunityManageAllocations LWC.
 * @Date:     2026-09-14
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate  Description
 * SS-13901   2026-09-14    Initial development
 */
public without sharing class OpportunityManageAllocationsController {
	private static final String SERVER_DEPLOYMENT_STATUS_ACTIVE = 'Active';
	private static final String SERVER_DEPLOYMENT_TYPE_PRODUCTION = 'Production';
	private static final String ALLOCATION_TYPE_LICENSE = 'License';
	private static final String ALLOCATION_TYPE_USAGE = 'Usage';

	/**
	 * Single entry point for the screen. Returns everything the LWC needs to render in
	 * one round trip: header context, the saved allocation rows, and the three option
	 * lists that back the comboboxes.
	 */
	@AuraEnabled(cacheable=true)
	public static AllocationScreenData getAllocationScreenData(Id opportunityId) {
		try {
			AllocationScreenData data = new AllocationScreenData();

			Opportunity opportunity = getOpportunity(opportunityId);
			data.opportunityId = opportunity.Id;
			data.opportunityName = opportunity.Name;
			data.accountId = opportunity.AccountId;
			data.accountName = opportunity.Account != null ? opportunity.Account.Name : null;
			data.primaryQuoteId = opportunity.Ruby__PrimaryQuote__c;

			data.quoteLineOptions = getQuoteLineOptions(opportunity.Ruby__PrimaryQuote__c);
			data.serverDeploymentOptions = getServerDeploymentOptions(opportunity.AccountId);
			data.typeOptions = getTypeOptions();
			data.rows = getAllocationRows(opportunityId);

			return data;
		} catch (Exception e) {
			Logger.error('Failed to load Manage Allocations screen data', e).addTag('apex');
			Logger.saveLog();
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static Opportunity getOpportunity(Id opportunityId) {
		// TODO Jason - confirm Ruby__PrimaryQuote__c is a lookup to the standard Quote object.
		// If it points somewhere else, getQuoteLineOptions below needs to change with it.
		List<Opportunity> opportunities = [
			SELECT Id, Name, AccountId, Account.Name, Ruby__PrimaryQuote__c
			FROM Opportunity
			WHERE Id = :opportunityId
			LIMIT 1
		];

		if (opportunities.isEmpty()) {
			throw new IllegalArgumentException('Opportunity not found.');
		}

		return opportunities[0];
	}

	/**
	 * Quote lines from the Opportunity's Primary Quote only. Each option carries the
	 * quote line quantity plus its subscription start and end dates, so the LWC can
	 * compute Available Allocation and fill the date cells on a brand new row before
	 * the formula fields have anything to evaluate against.
	 */
	private static List<QuoteLineOption> getQuoteLineOptions(Id primaryQuoteId) {
		List<QuoteLineOption> options = new List<QuoteLineOption>();

		if (primaryQuoteId == null) {
			return options;
		}

		for (QuoteLineItem quoteLine : [
			SELECT
				Id,
				Quantity,
				Product2.Name,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c
			FROM QuoteLineItem
			WHERE QuoteId = :primaryQuoteId
			ORDER BY Product2.Name
		]) {
			QuoteLineOption option = new QuoteLineOption();
			option.value = quoteLine.Id;
			option.label = quoteLine.Product2 != null ? quoteLine.Product2.Name : quoteLine.Id;
			option.quantity = quoteLine.Quantity;
			option.startDate = quoteLine.Ruby__SubscriptionStartDate__c;
			option.endDate = quoteLine.Ruby__SubscriptionEndDate__c;
			options.add(option);
		}

		return options;
	}

	/**
	 * Only Active + Production deployments participate in the allocation process, so
	 * anything else must never reach the picklist - the subscription trigger would
	 * silently ignore an allocation made against it.
	 */
	private static List<Option> getServerDeploymentOptions(Id accountId) {
		List<Option> options = new List<Option>();

		if (accountId == null) {
			return options;
		}

		for (Server_Deployment__c serverDeployment : [
			SELECT Id, Name
			FROM Server_Deployment__c
			WHERE
				Account__c = :accountId
				AND Status__c = :SERVER_DEPLOYMENT_STATUS_ACTIVE
				AND Type__c = :SERVER_DEPLOYMENT_TYPE_PRODUCTION
			ORDER BY Name
		]) {
			options.add(new Option(serverDeployment.Name, serverDeployment.Id));
		}

		return options;
	}

	// TODO Jason - hardcoded rather than read from the ELV_Type__c picklist so the two
	// values stay pinned to what the subscription trigger actually filters on. Say the
	// word if you would rather this be describe-driven.
	private static List<Option> getTypeOptions() {
		return new List<Option>{
			new Option(ALLOCATION_TYPE_LICENSE, ALLOCATION_TYPE_LICENSE),
			new Option(ALLOCATION_TYPE_USAGE, ALLOCATION_TYPE_USAGE)
		};
	}

	private static List<AllocationRow> getAllocationRows(Id opportunityId) {
		List<AllocationRow> rows = new List<AllocationRow>();

		// TODO Jason - ELV_StartDate__c and ELV_EndDate__c are formula fields, so they are
		// queried for display only and never written back on save.
		for (Opportunity_Server_deployment__c allocation : [
			SELECT
				Id,
				Name,
				Account__c,
				Opportunity__c,
				ELV_Quote_Line_Item__c,
				ELV_Quote_Line_Item__r.Product2.Name,
				Server_Deployment__c,
				Server_Deployment__r.Name,
				ELV_Type__c,
				ELV_Quantity__c,
				ELV_StartDate__c,
				ELV_EndDate__c
			FROM Opportunity_Server_deployment__c
			WHERE Opportunity__c = :opportunityId
			ORDER BY CreatedDate
		]) {
			rows.add(new AllocationRow(allocation));
		}

		return rows;
	}

	/* ------------------------------------------------------------------ *
	 * Wrappers
	 * ------------------------------------------------------------------ */

	public class AllocationScreenData {
		@AuraEnabled
		public Id opportunityId;
		@AuraEnabled
		public String opportunityName;
		@AuraEnabled
		public Id accountId;
		@AuraEnabled
		public String accountName;
		@AuraEnabled
		public Id primaryQuoteId;
		@AuraEnabled
		public List<AllocationRow> rows = new List<AllocationRow>();
		@AuraEnabled
		public List<QuoteLineOption> quoteLineOptions = new List<QuoteLineOption>();
		@AuraEnabled
		public List<Option> serverDeploymentOptions = new List<Option>();
		@AuraEnabled
		public List<Option> typeOptions = new List<Option>();
	}

	public class AllocationRow {
		@AuraEnabled
		public Id recordId;
		@AuraEnabled
		public String name;
		@AuraEnabled
		public Id quoteLineItemId;
		@AuraEnabled
		public String productName;
		@AuraEnabled
		public Id serverDeploymentId;
		@AuraEnabled
		public String serverDeploymentName;
		@AuraEnabled
		public String type;
		@AuraEnabled
		public Decimal quantity;
		@AuraEnabled
		public Date startDate;
		@AuraEnabled
		public Date endDate;
		// TODO Jason - Parent Product field does not exist yet. Once it lands, add the
		// lookup here plus its resolved product name, and bind the column in the LWC.
		@AuraEnabled
		public Id parentQuoteLineItemId;
		@AuraEnabled
		public String parentProductName;

		public AllocationRow(Opportunity_Server_deployment__c allocation) {
			this.recordId = allocation.Id;
			this.name = allocation.Name;
			this.quoteLineItemId = allocation.ELV_Quote_Line_Item__c;
			this.productName = allocation.ELV_Quote_Line_Item__r != null &&
				allocation.ELV_Quote_Line_Item__r.Product2 != null
				? allocation.ELV_Quote_Line_Item__r.Product2.Name
				: null;
			this.serverDeploymentId = allocation.Server_Deployment__c;
			this.serverDeploymentName = allocation.Server_Deployment__r != null
				? allocation.Server_Deployment__r.Name
				: null;
			this.type = allocation.ELV_Type__c;
			this.quantity = allocation.ELV_Quantity__c;
			this.startDate = allocation.ELV_StartDate__c;
			this.endDate = allocation.ELV_EndDate__c;
		}
	}

	public class Option {
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String value;

		public Option(String label, String value) {
			this.label = label;
			this.value = value;
		}
	}

	public class QuoteLineOption {
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String value;
		@AuraEnabled
		public Decimal quantity;
		@AuraEnabled
		public Date startDate;
		@AuraEnabled
		public Date endDate;
	}
}