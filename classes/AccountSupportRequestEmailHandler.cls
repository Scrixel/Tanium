/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Email handler class to create an Internal Support Request with record type Quopting Support
 * @Date: 2025-4-11
 * @Author: Nick Weeks, Tanium Dev Team
 * @Request: SS-10721
 * RequestId  ModifiedDate  Description
 * SS-10271   2025-04-11    Created the class
 * SS-10905   2025-05-15    Modified cretedBy functionality
 * SS-10924   2025-05-16    Modified email.plainTextBody vs htmlBody functionality
 * SS-10934   2025-05-20    Modified email.plainTextBody vs htmlBody functionality
 * SS-11706   2026-01-20    Added Account__c and Opportunity__c fields to the Account Support Request object
 */
public with sharing class AccountSupportRequestEmailHandler implements Messaging.InboundEmailHandler {
	public Messaging.InboundEmailResult handleInboundEmail(
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope env
	) {
		Id quotingSupportQueueId = Utility.getQueueId('Quoting Support');
		Id quotingSupportRecTypeId = Utility.getRecordTypeIdByAPIName(
			'Account_Support_Request__c',
			'Quoting_Support'
		);

		Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
		List<User> createdByUsers = [SELECT Id FROM User WHERE Email = :env.fromAddress];
		User salesSystemsUser;
		if (createdByUsers.isEmpty()) {
			salesSystemsUser = [SELECT Id FROM User WHERE Alias = 'ssystems'];
		}

		AccountSupportRequestEmailWrapper isrEmailWrapper = getISREmailWrapperFromEmail(email);
		Account_Support_Request__c accountSupportRequest = new Account_Support_Request__c(
			CreatedById = !createdByUsers.isEmpty() ? createdByUsers[0].Id : salesSystemsUser.Id,
			Description__c = isrEmailWrapper.description,
			OwnerId = quotingSupportQueueId,
			recordTypeId = quotingSupportRecTypeId,
			Status__c = 'Requested',
			Account__c = isrEmailWrapper.accountId,
			Opportunity__c = isrEmailWrapper.opportunityId
		);

		try {
			insert accountSupportRequest;
		} catch (Exception e) {
			Logger.Error('AccountSupportRequest.handleInboundEmail ERRORS', e);
			Logger.saveLog();
		}
		result.success = true;
		return result;
	}

	@TestVisible
	private static AccountSupportRequestEmailWrapper getISREmailWrapperFromEmail(
		Messaging.InboundEmail email
	) {
		String accountId;
		String opportunityId;
		String description = String.isNotBlank(email.plainTextBody)
			? email.plainTextBody
			: String.isNotBlank(email.htmlBody) ? email.htmlBody : 'Both plainText and html are empty';
		String emailBody = String.isNotBlank(email.plainTextBody)
			? email.plainTextBody
			: String.isNotBlank(email.htmlBody) ? email.htmlBody.stripHtmlTags() : '';

		if (emailBody.contains('Account Name:')) {
			String accountName = emailBody.substringBetween('Account Name:', '\n')?.normalizeSpace();
			List<Account> accounts = [SELECT Id FROM Account WHERE Name = :accountName];
			if (!accounts.isEmpty()) {
				accountId = accounts[0].Id;
			}
		}
		if (emailBody.contains('Opportunity Name:')) {
			String opportunityName = emailBody.substringBetween('Opportunity Name:', '\n')
				?.normalizeSpace();
			List<Opportunity> opportunities = [
				SELECT Id
				FROM Opportunity
				WHERE Name = :opportunityName
			];
			if (!opportunities.isEmpty()) {
				opportunityId = opportunities[0].Id;
			}
		}
		return new AccountSupportRequestEmailWrapper(accountId, opportunityId, description);
	}

	@TestVisible
	private class AccountSupportRequestEmailWrapper {
		@TestVisible
		private String accountId;
		@TestVisible
		private String opportunityId;
		@TestVisible
		private String description;

		@TestVisible
		private AccountSupportRequestEmailWrapper(
			String accountId,
			String opportunityId,
			String description
		) {
			this.accountId = accountId;
			this.opportunityId = opportunityId;
			this.description = description;
		}
	}
}