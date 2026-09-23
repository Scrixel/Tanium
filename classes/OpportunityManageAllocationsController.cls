/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller for the opportunityManageAllocations LWC.
 * @Date:     2026-09-22
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate  Description
 * SS-13901   2026-09-22    Initial development
 */
public with sharing class OpportunityManageAllocationsController {
	private static final String SERVER_DEPLOYMENT_STATUS_ACTIVE = 'Active';
	private static final String SERVER_DEPLOYMENT_TYPE_PRODUCTION = 'Production';

	private static final Decimal STAGE_NUMBER_LOCKED = 170;

	private static Map<String, String> usagePeriodLabelsByValue;

	private static final String READ_ONLY_CLOSED = 'CLOSED';
	private static final String READ_ONLY_NO_DEPLOYMENTS = 'NO_DEPLOYMENTS';

	@AuraEnabled(cacheable=true)
	public static AllocationScreenData getAllocationScreenData(Id opportunityId) {
		try {
			AllocationScreenData data = new AllocationScreenData();

			Opportunity opportunity = getOpportunity(opportunityId);
			data.opportunityName = opportunity.Name;
			data.accountName = opportunity.Account != null ? opportunity.Account.Name : null;
			data.primaryQuoteName = opportunity.Ruby__PrimaryQuote__r != null
				? opportunity.Ruby__PrimaryQuote__r.Name
				: null;
			data.accountId = opportunity.AccountId;
			data.primaryQuoteId = opportunity.Ruby__PrimaryQuote__c;

			data.quoteLineOptions = getQuoteLineOptions(opportunity.Ruby__PrimaryQuote__c);
			data.serverDeploymentOptions = getServerDeploymentOptions(opportunity.AccountId);
			data.rows = getAllocationRows(opportunityId);

			data.readOnlyReason = resolveReadOnlyReason(
				opportunity,
				data.serverDeploymentOptions.size()
			);
			data.isEditable = data.readOnlyReason == null;

			return data;
		} catch (Exception e) {
			Logger.error('Failed to load Manage Allocations screen data', e).addTag('apex');
			Logger.saveLog();
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static Opportunity getOpportunity(Id opportunityId) {
		if (opportunityId == null) {
			throw new IllegalArgumentException('No Opportunity was provided.');
		}

		if (opportunityId.getSObjectType() != Opportunity.SObjectType) {
			throw new IllegalArgumentException('Record Id is not an Opportunity.');
		}

		List<Opportunity> opportunities = [
			SELECT
				Id,
				Name,
				AccountId,
				Account.Name,
				IsClosed,
				StageNumber__c,
				Ruby__PrimaryQuote__c,
				Ruby__PrimaryQuote__r.Name
			FROM Opportunity
			WHERE Id = :opportunityId
			LIMIT 1
		];

		if (opportunities.isEmpty()) {
			throw new IllegalArgumentException('No Opportunity was found.');
		}

		return opportunities[0];
	}

	private static String resolveReadOnlyReason(Opportunity opportunity, Integer deploymentCount) {
		Boolean pastAllocationWindow =
			opportunity.IsClosed == true ||
			(opportunity.StageNumber__c != null &&
			opportunity.StageNumber__c >= STAGE_NUMBER_LOCKED);

		if (pastAllocationWindow) {
			return READ_ONLY_CLOSED;
		}

		if (deploymentCount == 0) {
			return READ_ONLY_NO_DEPLOYMENTS;
		}

		return null;
	}

	private static List<QuoteLineOption> getQuoteLineOptions(Id primaryQuoteId) {
		List<QuoteLineOption> options = new List<QuoteLineOption>();

		if (primaryQuoteId == null) {
			return options;
		}

		for (QuoteLineItem quoteLine : [
			SELECT
				Id,
				Product2.Name,
				ELV_Opportunity_Server_Deployment_Type__c,
				ELV_Opp_Server_Deployment_Quantity__c,
				ELV_UsagePeriod__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c
			FROM QuoteLineItem
			WHERE
				QuoteId = :primaryQuoteId
				AND ELV_Opportunity_Server_Deployment_Type__c != ''
				AND ELV_Opp_Server_Deployment_Quantity__c > 0
			ORDER BY Product2.Name
		]) {
			QuoteLineOption option = new QuoteLineOption();
			option.value = quoteLine.Id;
			option.label = quoteLine.Product2 != null ? quoteLine.Product2.Name : quoteLine.Id;
			option.quantity = quoteLine.ELV_Opp_Server_Deployment_Quantity__c;
			option.derivedType = quoteLine.ELV_Opportunity_Server_Deployment_Type__c;
			option.usagePeriod = usagePeriodLabel(quoteLine.ELV_UsagePeriod__c);
			option.startDate = quoteLine.Ruby__SubscriptionStartDate__c;
			option.endDate = quoteLine.Ruby__SubscriptionEndDate__c;
			options.add(option);
		}

		return options;
	}

	private static String usagePeriodLabel(String apiValue) {
		if (String.isBlank(apiValue)) {
			return apiValue;
		}

		if (usagePeriodLabelsByValue == null) {
			usagePeriodLabelsByValue = new Map<String, String>();

			for (
				Schema.PicklistEntry entry : QuoteLineItem.ELV_UsagePeriod__c.getDescribe()
					.getPicklistValues()
			) {
				usagePeriodLabelsByValue.put(entry.getValue(), entry.getLabel());
			}
		}

		return usagePeriodLabelsByValue.containsKey(apiValue)
			? usagePeriodLabelsByValue.get(apiValue)
			: apiValue;
	}

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

	private static List<AllocationRow> getAllocationRows(Id opportunityId) {
		List<AllocationRow> rows = new List<AllocationRow>();

		for (Opportunity_Server_deployment__c allocation : [
			SELECT
				Id,
				Account__c,
				Opportunity__c,
				ELV_QuoteLineItem__c,
				ELV_QuoteLineItem__r.Product2.Name,
				Server_Deployment__c,
				Server_Deployment__r.Name,
				ELV_Type__c,
				ELV_UsagePeriod__c,
				ELV_AllocationQuantity__c,
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

	@AuraEnabled
	public static SaveResponse saveAllocations(Id opportunityId, String rowsJson) {
		SaveResponse response = new SaveResponse();

		try {
			List<AllocationInput> rows = String.isBlank(rowsJson)
				? new List<AllocationInput>()
				: (List<AllocationInput>) JSON.deserialize(rowsJson, List<AllocationInput>.class);

			Opportunity opportunity = getOpportunity(opportunityId);

			String readOnlyReason = resolveReadOnlyReason(
				opportunity,
				getServerDeploymentOptions(opportunity.AccountId).size()
			);

			if (readOnlyReason != null) {
				throw new IllegalArgumentException(
					'Allocations can no longer be changed for this Opportunity (' +
					readOnlyReason +
					').'
				);
			}

			if (rows.isEmpty()) {
				response.savedRows = getAllocationRows(opportunityId);
				return response;
			}

			List<AllocationInput> toUpsert = new List<AllocationInput>();
			List<AllocationInput> toDelete = new List<AllocationInput>();
			Set<Id> supersededRecordIds = new Set<Id>();

			for (AllocationInput row : rows) {
				if (row.recordId != null) {
					supersededRecordIds.add(row.recordId);
				}

				if (row.isMarkedForDeletion == true) {
					if (row.recordId != null) {
						toDelete.add(row);
					}
				} else {
					toUpsert.add(row);
				}
			}

			Map<String, String> rejections = validateAgainstQuoteLines(toUpsert, supersededRecordIds);

			List<AllocationInput> writable = new List<AllocationInput>();
			for (AllocationInput row : toUpsert) {
				if (rejections.containsKey(row.key)) {
					response.results.add(buildRowResult(row.key, false, null, rejections.get(row.key)));
				} else {
					writable.add(row);
				}
			}

			applyUpserts(writable, opportunity, response);
			applyDeletes(toDelete, response);

			Logger.saveLog();

			for (RowResult result : response.results) {
				if (result.success) {
					response.successCount++;
				} else {
					response.failureCount++;
				}
			}

			response.savedRows = getAllocationRows(opportunityId);

			return response;
		} catch (Exception e) {
			Logger.error('Failed to save Manage Allocations rows', e).addTag('apex');
			Logger.saveLog();
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static Map<String, String> validateAgainstQuoteLines(
		List<AllocationInput> rows,
		Set<Id> supersededRecordIds
	) {
		Map<String, String> rejections = new Map<String, String>();

		Set<Id> quoteLineIds = new Set<Id>();
		for (AllocationInput row : rows) {
			if (row.quoteLineItemId != null) {
				quoteLineIds.add(row.quoteLineItemId);
			}
		}

		if (quoteLineIds.isEmpty()) {
			return rejections;
		}

		Map<Id, QuoteLineItem> quoteLines = new Map<Id, QuoteLineItem>(
			[
				SELECT Id, ELV_Opp_Server_Deployment_Quantity__c, Product2.Name
				FROM QuoteLineItem
				WHERE Id IN :quoteLineIds
			]
		);

		// TODO Jason - check the org-wide default on Opportunity_Server_deployment__c.
		// This class runs with sharing, so if that object is Private this query can miss
		// allocations the running user cannot see, under-count the total, and let an
		// over-allocation through. If it is Private, move just this query into a
		// without-sharing inner class.
		Map<Id, Decimal> plannedTotals = new Map<Id, Decimal>();
		for (Opportunity_Server_deployment__c existing : [
			SELECT Id, ELV_QuoteLineItem__c, ELV_AllocationQuantity__c
			FROM Opportunity_Server_deployment__c
			WHERE ELV_QuoteLineItem__c IN :quoteLineIds
		]) {
			if (supersededRecordIds.contains(existing.Id)) {
				continue;
			}
			addToTotal(
				plannedTotals,
				existing.ELV_QuoteLineItem__c,
				existing.ELV_AllocationQuantity__c
			);
		}

		for (AllocationInput row : rows) {
			if (row.quoteLineItemId == null) {
				continue;
			}
			addToTotal(plannedTotals, row.quoteLineItemId, row.quantity);
		}

		for (AllocationInput row : rows) {
			if (row.quoteLineItemId == null) {
				continue;
			}

			QuoteLineItem quoteLine = quoteLines.get(row.quoteLineItemId);
			if (quoteLine == null || quoteLine.ELV_Opp_Server_Deployment_Quantity__c == null) {
				continue;
			}

			Decimal purchased = quoteLine.ELV_Opp_Server_Deployment_Quantity__c;
			Decimal planned = plannedTotals.get(row.quoteLineItemId);

			if (planned != null && planned > purchased) {
				String productName = quoteLine.Product2 != null
					? quoteLine.Product2.Name
					: 'this product';

				rejections.put(
					row.key,
					'Allocations for ' +
					productName +
					' total ' +
					planned +
					', which exceeds the ' +
					purchased +
					' purchased.'
				);
			}
		}

		return rejections;
	}

	private static void addToTotal(Map<Id, Decimal> totals, Id key, Decimal amount) {
		Decimal running = totals.containsKey(key) ? totals.get(key) : 0;
		totals.put(key, running + (amount == null ? 0 : amount));
	}

	private static void applyUpserts(
		List<AllocationInput> rows,
		Opportunity opportunity,
		SaveResponse response
	) {
		if (rows.isEmpty()) {
			return;
		}

		List<Opportunity_Server_deployment__c> records = new List<Opportunity_Server_deployment__c>();
		for (AllocationInput row : rows) {
			records.add(buildAllocationRecord(row, opportunity));
		}

		List<Database.UpsertResult> results = Database.upsert(records, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'OpportunityManageAllocationsController.applyUpserts ERRORS',
				results
			)
			.addTag('apex');

		for (Integer i = 0; i < results.size(); i++) {
			Database.UpsertResult result = results[i];

			response.results.add(
				buildRowResult(
					rows[i].key,
					result.isSuccess(),
					result.isSuccess() ? result.getId() : null,
					result.isSuccess() ? null : firstErrorMessage(result.getErrors())
				)
			);
		}
	}

	private static void applyDeletes(List<AllocationInput> rows, SaveResponse response) {
		if (rows.isEmpty()) {
			return;
		}

		List<Opportunity_Server_deployment__c> records = new List<Opportunity_Server_deployment__c>();
		for (AllocationInput row : rows) {
			records.add(new Opportunity_Server_deployment__c(Id = row.recordId));
		}

		List<Database.DeleteResult> results = Database.delete(records, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'OpportunityManageAllocationsController.applyDeletes ERRORS',
				results
			)
			.addTag('apex');

		for (Integer i = 0; i < results.size(); i++) {
			Database.DeleteResult result = results[i];

			response.results.add(
				buildRowResult(
					rows[i].key,
					result.isSuccess(),
					null,
					result.isSuccess() ? null : firstErrorMessage(result.getErrors())
				)
			);
		}
	}

	private static Opportunity_Server_deployment__c buildAllocationRecord(
		AllocationInput row,
		Opportunity opportunity
	) {
		return new Opportunity_Server_deployment__c(
			Id = row.recordId,
			Account__c = opportunity.AccountId,
			Opportunity__c = opportunity.Id,
			ELV_QuoteLineItem__c = row.quoteLineItemId,
			Server_Deployment__c = row.serverDeploymentId,
			ELV_AllocationQuantity__c = row.quantity
		);
	}

	private static String firstErrorMessage(List<Database.Error> errors) {
		return errors != null && !errors.isEmpty()
			? errors[0].getMessage()
			: 'The record could not be saved.';
	}

	private static RowResult buildRowResult(
		String key,
		Boolean success,
		Id recordId,
		String message
	) {
		RowResult result = new RowResult();
		result.key = key;
		result.success = success;
		result.recordId = recordId;
		result.message = message;
		return result;
	}

	public class AllocationScreenData {
		@AuraEnabled
		public Boolean isEditable = true;
		@AuraEnabled
		public String readOnlyReason;
		@AuraEnabled
		public String opportunityName;
		@AuraEnabled
		public String accountName;
		@AuraEnabled
		public String primaryQuoteName;
		@AuraEnabled
		public Id accountId;
		@AuraEnabled
		public Id primaryQuoteId;
		@AuraEnabled
		public List<AllocationRow> rows = new List<AllocationRow>();
		@AuraEnabled
		public List<QuoteLineOption> quoteLineOptions = new List<QuoteLineOption>();
		@AuraEnabled
		public List<Option> serverDeploymentOptions = new List<Option>();
	}

	public class AllocationRow {
		@AuraEnabled
		public Id recordId;
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
		public String usagePeriod;
		@AuraEnabled
		public Decimal quantity;
		@AuraEnabled
		public Date startDate;
		@AuraEnabled
		public Date endDate;

		public AllocationRow(Opportunity_Server_deployment__c allocation) {
			this.recordId = allocation.Id;
			this.quoteLineItemId = allocation.ELV_QuoteLineItem__c;
			this.productName = allocation.ELV_QuoteLineItem__r != null &&
				allocation.ELV_QuoteLineItem__r.Product2 != null
				? allocation.ELV_QuoteLineItem__r.Product2.Name
				: null;
			this.serverDeploymentId = allocation.Server_Deployment__c;
			this.serverDeploymentName = allocation.Server_Deployment__r != null
				? allocation.Server_Deployment__r.Name
				: null;
			this.type = allocation.ELV_Type__c;
			this.usagePeriod = usagePeriodLabel(allocation.ELV_UsagePeriod__c);
			this.quantity = allocation.ELV_AllocationQuantity__c;
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

	public class AllocationInput {
		@AuraEnabled
		public String key;
		@AuraEnabled
		public Id recordId;
		@AuraEnabled
		public Id quoteLineItemId;
		@AuraEnabled
		public Id serverDeploymentId;
		@AuraEnabled
		public Decimal quantity;
		@AuraEnabled
		public Boolean isMarkedForDeletion;
	}

	public class SaveResponse {
		@AuraEnabled
		public List<RowResult> results = new List<RowResult>();
		@AuraEnabled
		public Integer successCount = 0;
		@AuraEnabled
		public Integer failureCount = 0;
		@AuraEnabled
		public List<AllocationRow> savedRows = new List<AllocationRow>();
	}

	public class RowResult {
		@AuraEnabled
		public String key;
		@AuraEnabled
		public Boolean success;
		@AuraEnabled
		public Id recordId;
		@AuraEnabled
		public String message;
	}

	public class QuoteLineOption {
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String value;
		@AuraEnabled
		public Decimal quantity;

		@AuraEnabled
		public String derivedType;
		@AuraEnabled
		public String usagePeriod;
		@AuraEnabled
		public Date startDate;
		@AuraEnabled
		public Date endDate;
	}
}