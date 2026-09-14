/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: This is a handler class for AccountSupportRequestTrigger
 * @Date: 2020-01-06
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Comment
 * TAN-834    2020-01-06    Initial development
 * SS-7240    2024-01-18    Remove ESO_Support_Request_Approved
 * SS-12847   2026-03-31    Added method processESOApprovedISR
 */
public class AccountSupportRequestTriggerHandler extends TriggerHandler {
	private List<Account_Support_Request__c> accountSupportRequests;
	private Map<Id, Account_Support_Request__c> oldMap;

	public AccountSupportRequestTriggerHandler() {
		super('AccountSupportRequestTriggerHandler');
		this.accountSupportRequests = (List<Account_Support_Request__c>) Trigger.new;
		this.oldMap = (Map<Id, Account_Support_Request__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		AccountSupportRequestTriggerUtility.checkApprovedESOISR(accountSupportRequests);
	}

	public override void afterInsert() {
		AccountSupportRequestTriggerUtility.computeAccountRollups(accountSupportRequests);
		AccountSupportRequestTriggerUtility.processESOApprovedISR(accountSupportRequests);
	}

	public override void beforeUpdate() {
		AccountSupportRequestTriggerUtility.checkApprovedESORequiredFields(
			accountSupportRequests,
			oldMap
		);
	}

	public override void afterUpdate() {
		AccountSupportRequestTriggerUtility.computeAccountRollups(accountSupportRequests);
		AccountSupportRequestTriggerUtility.processESOApprovedISR(accountSupportRequests);
	}

	public override void afterDelete() {
		AccountSupportRequestTriggerUtility.computeAccountRollups(oldMap.values());
	}

	public override void afterUndelete() {
		AccountSupportRequestTriggerUtility.computeAccountRollups(accountSupportRequests);
	}
}