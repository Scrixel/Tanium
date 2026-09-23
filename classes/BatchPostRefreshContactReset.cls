/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Batch class to reset contact emails in a sandbox after a refresh
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12777   2026-03-19    Fix class and best practice updates
 */
public without sharing class BatchPostRefreshContactReset implements Database.Batchable<sObject> {
	@TestVisible
	private static final String SANDBOX_EMAIL_POSTFIX = '.invalid';
	private static final String INVALID_EMAIL = 'not.a.valid.email@notvalid.com';
	private static final String EMAIL_POSTFIX_IDENTIFIER = '%' + SANDBOX_EMAIL_POSTFIX;
	private static Id contactRecordTypeId = Utility.getRecordTypeIdByAPIName('Contact', 'Contact');
	private String contactQuery =
		'SELECT Id, Email ' +
		'FROM Contact ' +
		'WHERE Email NOT IN (NULL, :INVALID_EMAIL) ' +
		'AND (NOT Email LIKE :EMAIL_POSTFIX_IDENTIFIER) ' +
		'AND RecordTypeId = :contactRecordTypeId';

	public BatchPostRefreshContactReset() {
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(contactQuery);
	}

	public void execute(Database.BatchableContext bc, List<Contact> contacts) {
		TriggerHandler.bypass(new List<String>{ 'ContactTriggerHandler', 'AccountTriggerHandler' });

		List<Contact> contactsToUpdate = new List<Contact>();

		for (Contact contact : contacts) {
			if (String.isNotBlank(contact.Email)) {
				contact.Email += SANDBOX_EMAIL_POSTFIX;
				contactsToUpdate.add(contact);
			}
		}

		List<Database.SaveResult> results = Database.update(contactsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'BatchPostRefreshContactReset ERRORS', results)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'BatchPostRefreshContactReset');
	}
}