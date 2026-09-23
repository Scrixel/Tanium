/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class for populating SDR fields on Lead object.
 * @Description: This class is called from the AccountSDRBatch class after Account
 * SDR fields have been updated. There is no scheduled.
 * @Date: 2026-06-02
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-13234     2026-06-02       Initial development
 */
public without sharing class LeadSDRBatch implements Database.Batchable<sObject>, Database.Stateful {
	private Set<Id> accountIds;
	private Id oppRegRecordTypeId = System.Label.Lead_Record_Type_Opportunity_Registration;

	private String leadQuery =
		'SELECT Id, Account__c, SDR_Owner__c, SDR_Manager__c, ' +
		'Account__r.BDR__c, Account__r.SDR_Manager__c ' +
		'FROM Lead ' +
		'WHERE Account__c IN :accountIds ' +
		'AND RecordTypeId != :oppRegRecordTypeId ' +
		'AND IsConverted = false ' +
		'AND Status != \'New - Converted\' ' +
		'AND Email_Status__c != \'Invalid\'';

	public LeadSDRBatch(Set<Id> accountIds) {
		this.accountIds = accountIds;
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(leadQuery);
	}

	public void execute(Database.BatchableContext bc, List<Lead> leads) {
		List<Lead> leadsToUpdate = new List<Lead>();
		for (Lead lead : leads) {
			if (
				lead.SDR_Owner__c != lead.Account__r.BDR__c ||
				lead.SDR_Manager__c != lead.Account__r.SDR_Manager__c
			) {
				lead.SDR_Owner__c = lead.Account__r.BDR__c;
				lead.SDR_Manager__c = lead.Account__r.SDR_Manager__c;
				leadsToUpdate.add(lead);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(leadsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'LeadSDRBatch.execute ERRORS', saveResults)
			.addTag('apex');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'LeadSDRBatch');
	}
}