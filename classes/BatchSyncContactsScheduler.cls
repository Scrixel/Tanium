/**
 * @Business: Sync Contact owner with Account Owner
 * @Date: 2017-08-07
 * @Author: Cumulus Vision
 * @Request: TAN-434
 * Modified  ModifiedDate   Description
 * TAN-434   2017-08-07     Initial Development
 * TAN-435   2017-08-14     Exclude contacts with no Account
 * SS-13159  2026-05-14     Add class back to fix deployment
 */
global class BatchSyncContactsScheduler implements Database.Batchable<sObject>, Schedulable {
	global Database.QueryLocator start(Database.BatchableContext BC) {
		String query = 'Select Id, OwnerId, Contact_Owner_Diff__c, AccountId, Account.OwnerId FROM Contact WHERE Contact_Owner_Diff__c = True AND AccountId != null';

		return Database.getQueryLocator(query);
	}

	global void execute(SchedulableContext sc) {
		database.executebatch(new BatchSyncContactsScheduler());
	}

	global void execute(Database.BatchableContext BC, List<Contact> scope) {
		List<Contact> cons = new List<Contact>();

		for (Contact c : scope) {
			c.OwnerId = c.Account.OwnerId;
			cons.add(c);
		}

		if (!cons.isEmpty()) {
			update cons;
		}
	}

	global void finish(Database.BatchableContext BC) {
	}
}