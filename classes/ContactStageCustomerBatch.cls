/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class to update the Contact Stage field to Customer on the Contact object.
 * @Date: 2026-01-30
 * @Author: Tanium Dev Team
 * RequestId   ModifiedDate   Description
 * SS-12167    2026-01-30     Initial development
 */
public without sharing class ContactStageCustomerBatch implements Database.Batchable<sObject>, Schedulable {
	private static final Integer DEFAULT_BATCH_SIZE = 5;
	private Integer batchSize;
	private Set<Id> accountIds;
	private Set<Id> oppIds;
	private Set<Id> contactIds;
	private String contactQuery =
		'SELECT ' +
		'Id, ' +
		'Contact_Stage__c ' +
		'FROM Contact ' +
		'WHERE Contact_Stage__c != \'Customer\' ' +
		'AND AccountId IN :accountIds ' +
		(Test.isRunningTest() ? 'LIMIT 1' : '');
	private String accountHistoryQuery =
		'SELECT ' +
		'Id, ' +
		'NewValue, ' +
		'AccountId ' +
		'FROM AccountHistory ' +
		'WHERE Field = \'Type\' ' +
		'AND CreatedDate = LAST_N_DAYS:1 ' +
		'AND Account.Type = \'Customer\' ' +
		(Test.isRunningTest() ? 'LIMIT 1' : '');
	private String oppQuery =
		'SELECT ' +
		'Id ' +
		'FROM Opportunity ' +
		'WHERE Type = \'Expansion\' ' +
		'AND AccountId IN :accountIds ' +
		(Test.isRunningTest() ? 'LIMIT 1' : '');
	private String oppContactQuery =
		'SELECT ' +
		'Id, ' +
		'ContactId ' +
		'FROM OpportunityContactRole ' +
		'WHERE OpportunityId IN :oppIds ' +
		(Test.isRunningTest() ? 'LIMIT 1' : '');

	public ContactStageCustomerBatch() {
		initializeBatchData();
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(contactQuery);
	}

	public void execute(Database.BatchableContext bc, List<Contact> contacts) {
		TriggerHandler.bypass(new List<String>{ 'ContactTriggerHandler' });
		List<Contact> contactsToUpdate = new List<Contact>();

		for (Contact contact : contacts) {
			if (!this.contactIds.contains(contact.Id)) {
				contact.Contact_Stage__c = 'Customer';
				contactsToUpdate.add(contact);
			}
		}

		List<Database.SaveResult> results = Database.update(contactsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'ContactStageCustomerBatch ERRORS', results)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'ContactStageCustomerBatch');
	}

	public void execute(SchedulableContext ctx) {
		Database.executeBatch(new ContactStageCustomerBatch(), batchSize);
	}

	private void initializeBatchData() {
		this.batchSize = Test.isRunningTest() ? 1 : DEFAULT_BATCH_SIZE;

		this.accountIds = new Set<Id>();
		List<AccountHistory> accountHistories = Database.query(accountHistoryQuery);
		for (AccountHistory accountHistory : accountHistories) {
			if (accountHistory.NewValue == 'Customer') {
				this.accountIds.add(accountHistory.AccountId);
			}
		}

		List<Opportunity> opps = Database.query(oppQuery);
		this.oppIds = new Map<Id, Opportunity>(opps).keySet();

		this.contactIds = new Set<Id>();
		List<OpportunityContactRole> oppContactRoles = Database.query(oppContactQuery);
		for (OpportunityContactRole oppContactRole : oppContactRoles) {
			this.contactIds.add(oppContactRole.ContactId);
		}
	}
}