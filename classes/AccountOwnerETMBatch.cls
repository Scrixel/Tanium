/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class for populating Owner field on Account object.
 * @Description: This class is called from the UserTerritoryAssocTriggerUtility class when a
 * UserTerritory2Association record is inserted, updated, or deleted. There is no scheduled
 * job that calls this batch class directly.
 * @Date: 2026-06-17
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-12811     2026-06-17       Initial development
 */
public without sharing class AccountOwnerETMBatch implements Database.Batchable<sObject>, Database.Stateful {
	private final Integer OWNER_BATCH_SIZE = 100;
	private Map<Id, Id> accountIdToUserId;
	private Set<Id> accountIds;
	private Set<Id> successfulAccountIds;

	public AccountOwnerETMBatch(Map<Id, Id> accountIdToUserId) {
		this.accountIdToUserId = accountIdToUserId;
		this.accountIds = accountIdToUserId.keySet();
		this.successfulAccountIds = new Set<Id>();
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator([SELECT Id, OwnerId FROM Account WHERE Id IN :accountIds]);
	}

	public void execute(Database.BatchableContext bc, List<Account> accounts) {
		TriggerHandler.bypass('AccountTriggerHandler');
		List<Account> accountsToUpdate = new List<Account>();
		for (Account acc : accounts) {
			if (acc.OwnerId != accountIdToUserId.get(acc.Id)) {
				acc.OwnerId = accountIdToUserId.get(acc.Id);
				accountsToUpdate.add(acc);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(accountsToUpdate, false);
		for (Integer i = 0; i < saveResults.size(); i++) {
			if (saveResults[i].isSuccess()) {
				successfulAccountIds.add(accountsToUpdate[i].Id);
			}
		}

		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountOwnerETMBatch.execute ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		if (!successfulAccountIds.isEmpty()) {
			Database.executeBatch(
				new OpportunityOwnerETMBatch(successfulAccountIds),
				OWNER_BATCH_SIZE
			);
		}
		Utility.logBatchErrors(bc, 'AccountOwnerETMBatch');
	}
}