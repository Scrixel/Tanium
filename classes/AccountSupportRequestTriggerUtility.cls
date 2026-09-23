/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: This is a utility class for AccountSupportRequestTrigger
 * @Date: 2024-01-18
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Comment
 * SS-7240    2024-01-18    Initial development
 * SS-7932    2024-04-11    Update clause to avoid locking errors on account for contract renewal quoted
 * SS-12847   2026-03-31    Added logic for new method processESOApprovedISR
 */
public with sharing class AccountSupportRequestTriggerUtility {
	public static final String ESO_APPROVED_STATUS = 'ESO Approved';
	public static final String ADVISOR_ENGAGEMENT_RECORDTYPE = 'Sr_Advisor_Engagement';
	private static Id accSupportRequestESORecordTypeId = Utility.getRecordTypeIdByAPIName(
		'Account_Support_Request__c',
		'ESO_Support_Request'
	);

	public static void computeAccountRollups(List<Account_Support_Request__c> listAcctSuppReq) {
		final Set<String> INAPPLICABLE_ACCT_STATUSES = new Set<String>{
			'Draft',
			'Request Completed'
		};
		Set<Id> accountIds = new Set<Id>();

		for (Account_Support_Request__c acctSupportReq : listAcctSuppReq) {
			accountIds.add(acctSupportReq.Account__c);
		}
		accountIds.remove(null);

		List<Account> advisorAccounts = [
			SELECT
				Id,
				(
					SELECT Id, Status__c
					FROM Account_Support_Requests__r
					WHERE
						Status__c NOT IN :INAPPLICABLE_ACCT_STATUSES
						AND RecordType.DeveloperName = :ADVISOR_ENGAGEMENT_RECORDTYPE
					ORDER BY CreatedDate DESC
					LIMIT 1
				)
			FROM Account
			WHERE Id IN :accountIds
		];

		List<Account> allAdvisorAccounts = [
			SELECT
				Id,
				(
					SELECT Id, CreatedDate
					FROM Account_Support_Requests__r
					WHERE RecordType.DeveloperName = :ADVISOR_ENGAGEMENT_RECORDTYPE
					ORDER BY CreatedDate DESC
					LIMIT 1
				)
			FROM Account
			WHERE Id IN :accountIds
			FOR UPDATE
		];

		Map<Id, Account> acctsToUpdate = new Map<Id, Account>();
		for (Account account : advisorAccounts) {
			if (!account.Account_Support_Requests__r.isEmpty()) {
				account.Sr_Advisor_Engagement__c = account.Account_Support_Requests__r[0].Status__c;
			} else {
				account.Sr_Advisor_Engagement__c = null;
			}
			acctsToUpdate.put(account.Id, account);
		}

		for (Account account : allAdvisorAccounts) {
			Account acctToUpdate = acctsToUpdate.containsKey(account.Id)
				? acctsToUpdate.get(account.Id)
				: account;

			if (!account.Account_Support_Requests__r.isEmpty()) {
				acctToUpdate.Last_Sr_Advisor_Engagement__c = account.Account_Support_Requests__r[0]
					.CreatedDate;
			} else {
				acctToUpdate.Last_Sr_Advisor_Engagement__c = null;
			}

			acctsToUpdate.put(acctToUpdate.Id, acctToUpdate);
		}

		List<Database.SaveResult> saveResults = Database.update(acctsToUpdate.values(), false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountSupportRequestTriggerUtility.computeAccountRollups ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void checkApprovedESOISR(List<Account_Support_Request__c> acctSuppRequests) {
		Set<Id> oppIds = new Set<Id>();

		for (Account_Support_Request__c accSupReq : acctSuppRequests) {
			if (accSupReq.RecordTypeId == accSupportRequestESORecordTypeId) {
				oppIds.add(accSupReq.Opportunity__c);
			}
		}

		if (!oppIds.isEmpty()) {
			List<Account_Support_Request__c> approvedISRs = [
				SELECT Id
				FROM Account_Support_Request__c
				WHERE
					RecordTypeId = :accSupportRequestESORecordTypeId
					AND Opportunity__c IN :oppIds
					AND Status__c = :ESO_APPROVED_STATUS
			];

			if (!approvedISRs.isEmpty()) {
				for (Account_Support_Request__c accSupReq : acctSuppRequests) {
					accSupReq.addError(System.Label.Approved_ESO_ISR_Exists);
				}
			}
		}
	}

	public static void checkApprovedESORequiredFields(
		List<Account_Support_Request__c> acctSuppRequests,
		Map<Id, Account_Support_Request__c> oldMap
	) {
		for (Account_Support_Request__c acctSuppRequest : acctSuppRequests) {
			Account_Support_Request__c oldSupportReq = oldMap.get(acctSuppRequest.Id);
			if (
				acctSuppRequest.RecordTypeId == accSupportRequestESORecordTypeId &&
				acctSuppRequest.Status__c == ESO_APPROVED_STATUS &&
				acctSuppRequest.Status__c != oldSupportReq.Status__c &&
				(String.isBlank(acctSuppRequest.ESO_Selection__c) ||
				String.isBlank(acctSuppRequest.Business_Unit__c))
			) {
				acctSuppRequest.addError(System.Label.Approved_ESO_Required_Field_Missing);
			}
		}
	}

	public static void processESOApprovedISR(
		List<Account_Support_Request__c> accountSupportRequests
	) {
		List<Account_Support_Request__c> approvedAccSupRequest = new List<Account_Support_Request__c>();
		for (Account_Support_Request__c accountSupportRequest : accountSupportRequests) {
			if (
				accountSupportRequest.RecordTypeId == accSupportRequestESORecordTypeId &&
				accountSupportRequest.Status__c == ESO_APPROVED_STATUS &&
				!accountSupportRequest.Kimble_Proposal_Created__c
			) {
				approvedAccSupRequest.add(accountSupportRequest);
			}
		}

		KimbleOne__Proposal__c newKimbleProposal;
		List<KimbleOne__Proposal__c> kimbleProposals = new List<KimbleOne__Proposal__c>();
		for (Account_Support_Request__c accountSupportRequest : approvedAccSupRequest) {
			newKimbleProposal = new KimbleOne__Proposal__c();
			newKimbleProposal.ESOISR__c = accountSupportRequest.Id;
			newKimbleProposal.KimbleOne__AcceptanceDate__c = accountSupportRequest.Opportunity__r.CloseDate;
			newKimbleProposal.KimbleOne__Account__c = accountSupportRequest.Account__c;
			newKimbleProposal.KimbleOne__BusinessUnit__c = accountSupportRequest.Business_Unit_ID_Formula__c;
			newKimbleProposal.KimbleOne__ExternalId__c = accountSupportRequest.Id;
			newKimbleProposal.KimbleOne__ForecastStatus__c = accountSupportRequest.Forecast_Status_Id_Formula__c;
			newKimbleProposal.KimbleOne__Opportunity__c = accountSupportRequest.Opportunity__c;
			newKimbleProposal.KimbleOne__Proposition__c = accountSupportRequest.ESO_Selection_ID_Formula__c;
			newKimbleProposal.KimbleOne__ShortName__c = accountSupportRequest.Name + ' ' + 'Proposal';
			newKimbleProposal.CreatedById = Constants.SALES_SYSTEMS_USER_ID;
			kimbleProposals.add(newKimbleProposal);
		}

		List<Database.SaveResult> saveResults = Database.insert(kimbleProposals, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountSupportRequestTriggerUtility.processESOApprovedISR.createKimbleProposals ERRORS',
				saveResults
			)
			.addTag('apex');

		List<Account_Support_Request__c> accSupRequestsToUpdate = new List<Account_Support_Request__c>();
		for (KimbleOne__Proposal__c kimbleProposal : kimbleProposals) {
			if (kimbleProposal.Id != null) {
				accSupRequestsToUpdate.add(
					new Account_Support_Request__c(
						Id = kimbleProposal.ESOISR__c,
						Kimble_Proposal_Created__c = true
					)
				);
			}
		}

		List<Database.SaveResult> updateResults = Database.update(accSupRequestsToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountSupportRequestTriggerUtility.processESOApprovedISR.updateAccSupRequests ERRORS',
				updateResults
			)
			.addTag('apex');
		Logger.saveLog();
	}
}