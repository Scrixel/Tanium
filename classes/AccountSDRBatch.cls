/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class for populating SDR fields on Account object.
 * @Description: This class is called from the UserTerritoryAssocTriggerUtility class when a
 * UserTerritory2Association record is inserted, updated, or deleted. There is no scheduled
 * job that calls this batch class directly.
 * @Date: 2026-06-02
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13234     2026-06-02       Initial development
 */
public without sharing class AccountSDRBatch implements Database.Batchable<sObject>, Database.Stateful {
	private final Integer SDR_BATCH_SIZE = 100;
	private Map<Id, Id> accountIdToUserId;
	private Map<Id, Id> userIdToUserManagerId;
	private Set<Id> accountIds;
	private Set<Id> successfulAccountIds;
	private String accountQuery = 'SELECT Id, BDR__c, SDR_Manager__c, AutomationBypassDateTime__c FROM Account WHERE Id IN :accountIds';

	public AccountSDRBatch(Map<Id, Id> accountIdToUserId, Map<Id, Id> userIdToUserManagerId) {
		this.accountIdToUserId = accountIdToUserId;
		this.userIdToUserManagerId = userIdToUserManagerId;
		this.accountIds = accountIdToUserId.keySet();
		this.successfulAccountIds = new Set<Id>();
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(accountQuery);
	}

	public void execute(Database.BatchableContext bc, List<Account> accounts) {
		TriggerHandler.bypass('AccountTriggerHandler');
		List<Account> accountsToUpdate = new List<Account>();
		for (Account acc : accounts) {
			if (
				acc.BDR__c != accountIdToUserId.get(acc.Id) ||
				acc.SDR_Manager__c != userIdToUserManagerId.get(accountIdToUserId.get(acc.Id))
			) {
				acc.BDR__c = accountIdToUserId.get(acc.Id);
				acc.SDR_Manager__c = userIdToUserManagerId.get(accountIdToUserId.get(acc.Id));
				acc.AutomationBypassDateTime__c = System.now();
				accountsToUpdate.add(acc);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(accountsToUpdate, false);
		for (Integer i = 0; i < saveResults.size(); i++) {
			if (saveResults[i].isSuccess()) {
				successfulAccountIds.add(accountsToUpdate[i].Id);
			}
		}

		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'AccountSDRBatch.execute ERRORS', saveResults)
			.addTag('apex');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		if (!successfulAccountIds.isEmpty()) {
			Database.executeBatch(new ContactSDRBatch(successfulAccountIds), SDR_BATCH_SIZE);
			Database.executeBatch(new LeadSDRBatch(successfulAccountIds), SDR_BATCH_SIZE);
		}
		Utility.logBatchErrors(bc, 'AccountSDRBatch');
	}
}