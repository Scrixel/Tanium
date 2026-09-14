/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class for populating Owner field on Opportunity object.
 * @Description: This class is called from the AccountOwnerETMBatch class after Account
 * Owner fields have been updated. There is no scheduled.
 * @Date: 2026-06-17
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13349     2026-06-17       Initial development
 */
public without sharing class OpportunityOwnerETMBatch implements Database.Batchable<sObject>, Database.Stateful {
	private Set<Id> accountIds;
	private List<String> closedStages = Utility.CLOSED_STAGES;

	public OpportunityOwnerETMBatch(Set<Id> accountIds) {
		this.accountIds = accountIds;
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(
			[
				SELECT Id, OwnerId, Account.OwnerId, StageName
				FROM Opportunity
				WHERE AccountId IN :accountIds AND Type != 'Split' AND StageName NOT IN :closedStages
			]
		);
	}

	public void execute(Database.BatchableContext bc, List<Opportunity> opportunities) {
		List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
		for (Opportunity opp : opportunities) {
			if (opp.OwnerId != opp.Account.OwnerId) {
				opp.OwnerId = opp.Account.OwnerId;
				opportunitiesToUpdate.add(opp);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(opportunitiesToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'OpportunityOwnerETMBatch.execute ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'OpportunityOwnerETMBatch');
	}
}