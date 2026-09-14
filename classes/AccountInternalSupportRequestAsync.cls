/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Sync Account Support Request fields from Account Owner hierarchy
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * @Request:
 * RequestId  ModifiedDate  Description
 * SS-13176   2026-05-27    Replaced Level_4__c with Region__c for LATAM RVP detection
 */
public without sharing class AccountInternalSupportRequestAsync implements Queueable {
	private List<Account> accounts;
	private List<Account> overflowAccounts = null;
	private Set<Id> recTypeIds;
	private Set<String> statuses;
	private Boolean async;

	@TestVisible
	private static Integer maxBatchSize = !Test.isRunningTest() ? 100 : 1;

	public AccountInternalSupportRequestAsync(List<Account> accounts, Boolean async) {
		this(async);
		this.accounts = accounts;
	}

	public AccountInternalSupportRequestAsync(Boolean async) {
		this.async = async;
		recTypeIds = new Set<Id>();
		recTypeIds.add(
			Utility.getRecordTypeIdByAPIName('Account_Support_Request__c', 'Sr_Advisor_Engagement')
		);
		recTypeIds.add(
			Utility.getRecordTypeIdByAPIName('Account_Support_Request__c', 'Tanium_Estaff_Engagement')
		);

		statuses = new Set<String>{
			'Draft',
			'Submitted and Under Review',
			'Approved and Under Review',
			'Sent to Sr. Advisor/E-Staff',
			'Request sent to contact',
			'Acknowledged by Contact',
			'Call or Meeting Completed',
			'Recalled'
		};
	}

	// override interface execute method
	public void execute(QueueableContext context) {
		if (accounts.isEmpty()) {
			return;
		}

		if (accounts.size() >= maxBatchSize) {
			overflowAccounts = new List<Account>();
			for (Integer i = maxBatchSize; i < accounts.size(); i++) {
				overflowAccounts.add(accounts.remove(i));
			}
		}

		syncSupportRequests(getSupportRequestsToSync());

		if (overflowAccounts != null) {
			Id jobId = !Test.isRunningTest()
				? System.enqueueJob(new AccountInternalSupportRequestAsync(overflowAccounts, async))
				: null;
		}
	}

	public Account_Support_Request__c[] getSupportRequestsToSync() {
		Map<Id, Account> accountsMap = new Map<Id, Account>(accounts);
		List<Account_Support_Request__c> requestsToSync = new List<Account_Support_Request__c>();
		Account_Support_Request__c requestToSync;
		Id ownerId;
		Id accountOwnerId;
		Id avpUserId;
		Id accountOwnerIdAvp;
		Id rvpUserId;
		Id accountRvpUserId;
		Set<Id> accountOwnerIds = new Set<Id>();

		Account_Support_Request__c[] requests = [
			SELECT Id, Account__c, OwnerId, AVP__c, RVP__c
			FROM Account_Support_Request__c
			WHERE
				Account__c IN :accountsMap.keySet()
				AND RecordTypeId IN :recTypeIds
				AND Status__c IN :statuses
		];

		for (Account account : accountsMap.values()) {
			accountOwnerIds.add(account.OwnerId);
		}

		Map<Id, User> usersMap = new Map<Id, User>(
			[
				SELECT Id, Area_VP__c, Full_Name__c, Manager.Id, Manager.Full_Name__c
				FROM User
				WHERE Id IN :accountOwnerIds
			]
		);

		for (Account_Support_Request__c request : requests) {
			accountOwnerId = accountsMap.get(request.Account__c).OwnerId;
			accountOwnerIdAvp = usersMap.get(accountsMap.get(request.Account__c).OwnerId).Area_VP__c;
			accountRvpUserId = getAccountRvpUserId(accountsMap.get(request.Account__c).OwnerId, accountsMap.get(request.Account__c).Region__c, usersMap);

			ownerId = (request.OwnerId != accountOwnerId) ? accountOwnerId : request.OwnerId;
			avpUserId = (request.AVP__c != accountOwnerIdAvp) ? accountOwnerIdAvp : request.AVP__c;
			rvpUserId = (request.RVP__c != accountRvpUserId) ? accountRvpUserId : request.RVP__c;

			if (
				ownerId != request.OwnerId ||
				avpUserId != request.AVP__c ||
				rvpUserId != request.RVP__c
			) {
				requestToSync = new Account_Support_Request__c(
					Id = request.Id,
					OwnerId = ownerId,
					AVP__c = avpUserId,
					RVP__c = rvpUserId,
					Account_Owner__c = accountOwnerId
				);
				requestsToSync.add(requestToSync);
			}
		}
		return requestsToSync;
	}

	public void syncSupportRequests(Account_Support_Request__c[] requestsToSync) {
		if (requestsToSync.isEmpty()) {
			return;
		}

		if (async) {
			SBQQ.TriggerControl.disable();
			TriggerHandler.bypass(
				new List<String>{
					'AccountTriggerHandler',
					'ContactTriggerHandler',
					'OpportunityTriggerHandler',
					'QuoteCPQTriggerHandler'
				}
			);
		}

		Database.SaveResult[] srList = Database.update(requestsToSync, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountInternalSupportRequestAsync.syncSupportRequests ERRORS',
				srList
			)
			.addTag('apex');
		Logger.saveLog();
	}

	@TestVisible
	private Id getAccountRvpUserId(Id accountOwnerId, String accountRegion, Map<Id, User> usersMap) {
		Id rvpUserId;
		User user = (usersMap.containsKey(accountOwnerId)) ? usersMap.get(accountOwnerId) : null;

		if (user == null) {
			return null;
		}
		rvpUserId = (accountRegion == 'LATAM' &&
			user.Role_Category__c == 'RVP')
			? user.Id
			: user.Manager.Id;

		return rvpUserId;
	}
}