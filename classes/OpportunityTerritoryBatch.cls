/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class to update the Territory field on the Opportunity object based on the Account's Primary Sales Territory Id
 * @Date: 2026-04-22
 * @Author: Tanium Dev Team
 * RequestId   ModifiedDate   Description
 * SS-12951    2026-05-26     Initial development
 */
public without sharing class OpportunityTerritoryBatch implements Database.Batchable<sObject>, Schedulable {
	private Map<Id, Object> accountIdToPrimarySalesTerritoryId;
	private Set<Id> accountIds;
	private DateTime oneHourAgo = DateTime.now().addHours(-1);
	private Date fy26StartDate = Date.newInstance(2025, 2, 1);
	private String accountHistoryQuery =
		'SELECT ' +
		'Id, ' +
		'NewValue, ' +
		'AccountId ' +
		'FROM AccountHistory ' +
		'WHERE Field = \'Primary_Sales_Territory_Id__c\' ' +
		'AND CreatedDate >= :oneHourAgo ' +
		'ORDER BY CreatedDate DESC ' +
		(Test.isRunningTest() ? 'LIMIT 1' : '');
	private String oppQuery =
		'SELECT ' +
		'Id, ' +
		'Territory2Id, ' +
		'End_User_Account__c, ' +
		'AccountId ' +
		'FROM Opportunity ' +
		'WHERE Type != \'Split\' ' +
		'AND CloseDate >= :fy26StartDate ' +
		'AND (End_User_Account__c IN :accountIds ' +
		'OR AccountId IN :accountIds) ' +
		(Test.isRunningTest() ? 'LIMIT 1' : '');

	public OpportunityTerritoryBatch() {
		initializeBatchData();
	}

	public OpportunityTerritoryBatch(
		String customAccountHistoryQuery,
		String customOpportunityQuery
	) {
		if (String.isNotBlank(customAccountHistoryQuery)) {
			this.accountHistoryQuery = customAccountHistoryQuery;
		}
		if (String.isNotBlank(customOpportunityQuery)) {
			this.oppQuery = customOpportunityQuery;
		}
		initializeBatchData();
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(oppQuery);
	}

	public void execute(Database.BatchableContext bc, List<Opportunity> opps) {
		TriggerHandler.bypass(new List<String>{ 'OpportunityTriggerHandler' });
		List<Opportunity> oppsToUpdate = new List<Opportunity>();

		for (Opportunity opp : opps) {
			if (opp.End_User_Account__c != null) {
				if (
					this.accountIdToPrimarySalesTerritoryId.containsKey(opp.End_User_Account__c) &&
					this.accountIdToPrimarySalesTerritoryId.get(opp.End_User_Account__c) !=
					opp.Territory2Id
				) {
					opp.Territory2Id = (Id) this.accountIdToPrimarySalesTerritoryId.get(
						opp.End_User_Account__c
					);
					oppsToUpdate.add(opp);
				}
			} else if (
				opp.AccountId != null &&
				this.accountIdToPrimarySalesTerritoryId.containsKey(opp.AccountId) &&
				this.accountIdToPrimarySalesTerritoryId.get(opp.AccountId) != opp.Territory2Id
			) {
				opp.Territory2Id = (Id) this.accountIdToPrimarySalesTerritoryId.get(opp.AccountId);
				oppsToUpdate.add(opp);
			}
		}

		List<Database.SaveResult> results = Database.update(oppsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'OpportunityTerritoryBatch ERRORS', results)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'OpportunityTerritoryBatch');
	}

	public void execute(SchedulableContext ctx) {
		Database.executeBatch(new OpportunityTerritoryBatch());
	}

	private void initializeBatchData() {
		this.accountIdToPrimarySalesTerritoryId = new Map<Id, Object>();
		this.accountIds = new Set<Id>();

		List<AccountHistory> accountHistories = Database.query(accountHistoryQuery);
		for (AccountHistory accountHistory : accountHistories) {
			if (!this.accountIdToPrimarySalesTerritoryId.containsKey(accountHistory.AccountId)) {
				this.accountIdToPrimarySalesTerritoryId.put(
					accountHistory.AccountId,
					accountHistory.NewValue
				);
			}
		}
		this.accountIds = this.accountIdToPrimarySalesTerritoryId.keySet();
	}
}