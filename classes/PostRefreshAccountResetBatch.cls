/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Batch class to reset account fields in a sandbox after a refresh
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12775   2026-03-24    Initial Development
 */
public without sharing class PostRefreshAccountResetBatch implements Database.Batchable<sObject> {
	@TestVisible
	private static String nonProdAccountSlackChannelId = System.Label.PostRefresh_NonProdAccountSlackChannelId;
	private String accountQuery =
		'SELECT Id, Slack_Channel_Id__c ' +
		'FROM Account ' +
		'WHERE Slack_Channel_Id__c != :nonProdAccountSlackChannelId ' +
		'AND Slack_Channel_Id__c != \'\'';

	public PostRefreshAccountResetBatch() {
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(accountQuery);
	}

	public void execute(Database.BatchableContext bc, List<Account> accounts) {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });

		List<Account> accountsToUpdate = new List<Account>();

		for (Account acc : accounts) {
			acc.Slack_Channel_Id__c = nonProdAccountSlackChannelId;
			accountsToUpdate.add(acc);
		}

		List<Database.SaveResult> results = Database.update(accountsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'Account Records Update Errors', results)
			.addTag('apex')
			.addTag('postrefresh');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'PostRefreshAccountResetBatch');
	}
}