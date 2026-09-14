/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Part of Trigger Framework for the User object
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-9255    2024-12-23	Removed updateOpportunityNQuoteDDA
 * SS-10173	  2025-02-05    Removed L1 thru L6 references
 * SS-10186   2026-02-27    Removed updateAccountQuoteOpportunityInfo, updateAccountsOwnerAndSegment, updateOppManagerNQuoteRegionalDirector
 * SS-13176   2026-05-27    Added Region__c to Account SOQL for LATAM RVP detection
 * SS-12811   2026-07-10    Added method processDeactivatedUsers
 */
public class UserTriggerUtility {
	private static final Boolean ASYNCHRONOUS_PROCESSING = true;
	private static final Integer OWNER_ACCOUNT_BATCH_SIZE = 100;

	public class UserTriggerUtilityException extends Exception {
	}

	public static void syncInternalSupportRequests(List<User> users, Map<Id, User> oldMap) {
		Set<Id> userIds = new Set<Id>();

		for (User user : users) {
			if (user.ManagerId != oldMap.get(user.Id).ManagerId) {
				userIds.add(user.Id);
			}
		}

		if (!userIds.isEmpty()) {
			syncInternalSupportRequests(userIds);
		}
	}

	private static void syncInternalSupportRequests(Set<Id> userIds) {
		List<Account> accounts = [
			SELECT Id, OwnerId, Area_VP__c, Region__c
			FROM Account
			WHERE OwnerId IN :userIds
		];
		Id jobId;

		if (!accounts.isEmpty()) {
			jobId = System.enqueueJob(
				new AccountInternalSupportRequestAsync(accounts, ASYNCHRONOUS_PROCESSING),
				1
			);
		}
	}

	public static void processDeactivatedUsers(List<User> users, Map<Id, User> oldMap) {
		Map<Id, Id> userIdToManagerId = new Map<Id, Id>();

		for (User user : users) {
			if (user.IsActive == false && oldMap.get(user.Id).IsActive == true) {
				if (user.RVP_Override__c != null) {
					userIdToManagerId.put(user.Id, user.RVP_Override__c);
				} else if (user.ManagerId != null) {
					userIdToManagerId.put(user.Id, user.ManagerId);
				}
			}
		}

		Map<Id, Id> accountIdToUserId = new Map<Id, Id>();
		for (Account acc : [
			SELECT Id, OwnerId
			FROM Account
			WHERE OwnerId IN :userIdToManagerId.keySet()
		]) {
			if (userIdToManagerId.get(acc.OwnerId) != null) {
				accountIdToUserId.put(acc.Id, userIdToManagerId.get(acc.OwnerId));
			}
		}

		if (!accountIdToUserId.isEmpty() && !Test.isRunningTest()) {
			Database.executeBatch(
				new AccountOwnerETMBatch(accountIdToUserId),
				OWNER_ACCOUNT_BATCH_SIZE
			);
		}
	}
}