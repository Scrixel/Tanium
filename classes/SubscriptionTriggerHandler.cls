/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Trigger handler on Subscription Object
 * @Date: 2022-12-15
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12077   2025-11-13    Added trigger framework best practices and new method call for Account Entitlements
 * SS-13641   2026-07-27    Added call to method setAnnualizedSoftwareSpendAndAiCreditsOnAccount
 * SS-13787   2026-08-18    Removed contract-dependent methods
 * SS-13834   2026-08-24    Added afterInsert call to processMonthlyPaidAICredits, broadened afterUpdate spend check.
 */
public class SubscriptionTriggerHandler extends TriggerHandler {
	private List<SBQQ__Subscription__c> subscriptions;
	private Map<Id, SBQQ__Subscription__c> oldMap;

	public SubscriptionTriggerHandler() {
		super('SubscriptionTriggerHandler');
		subscriptions = (List<SBQQ__Subscription__c>) Trigger.new;
		oldMap = (Map<Id, SBQQ__Subscription__c>) Trigger.oldMap;
	}

	public override void afterInsert() {
		SubscriptionTriggerUtility.processSubscriptionAccountEntitlements(subscriptions);
		SubscriptionTriggerUtility.processMonthlyPaidAICredits(subscriptions);
	}

	public override void afterUpdate() {
		SubscriptionTriggerUtility.setAnnualizedSoftwareSpendAndAiCreditsOnAccount(
			subscriptions,
			oldMap
		);
	}
}