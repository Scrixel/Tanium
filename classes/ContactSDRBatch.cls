/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class for populating SDR fields on Contact object.
 * @Description: This class is called from the AccountSDRBatch class after Account
 * SDR fields have been updated. There is no scheduled.
 * @Date: 2026-06-02
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13234     2026-06-02       Initial development
 * SS-13541     2026-07-16       Added SDR_Owner_Override__c check to skip records
 */
public without sharing class ContactSDRBatch implements Database.Batchable<sObject>, Database.Stateful {
	private Set<Id> accountIds;
	private String contactQuery =
		'SELECT Id, SDR_Owner__c, SDR_Manager__c, ' +
		'Account.BDR__c, Account.SDR_Manager__c ' +
		'FROM Contact ' +
		'WHERE AccountId IN :accountIds ' +
		'AND Status__c != \'Inactive\' ' +
		'AND Email != null ' +
		'AND SDR_Owner_Override__c != true';

	public ContactSDRBatch(Set<Id> accountIds) {
		this.accountIds = accountIds;
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(contactQuery);
	}

	public void execute(Database.BatchableContext bc, List<Contact> contacts) {
		List<Contact> contactsToUpdate = new List<Contact>();
		for (Contact con : contacts) {
			if (
				con.SDR_Owner__c != con.Account.BDR__c ||
				con.SDR_Manager__c != con.Account.SDR_Manager__c
			) {
				con.SDR_Owner__c = con.Account.BDR__c;
				con.SDR_Manager__c = con.Account.SDR_Manager__c;
				contactsToUpdate.add(con);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(contactsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'ContactSDRBatch.execute ERRORS', saveResults)
			.addTag('apex');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'ContactSDRBatch');
	}
}