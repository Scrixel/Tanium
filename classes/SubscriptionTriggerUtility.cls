/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Subscription Trigger Utility, part of Trigger Framework
 * @Date: 2025-04-04
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Initial development
 * SS-12494     2026-01-27      Update processSubscriptionAccountEntitlements with different key value pairs
 * SS-13497     2026-07-07      Remove deprecated fields for project kondo group 2
 * SS-13641     2026-07-27      Added method setAnnualizedSoftwareSpendOnAccount
 * SS-13787     2026-08-18      Removed contract-dependent methods
 * SS-13834     2026-08-24      Added method processMonthlyPaidAICredits, broadened spend check
 */
public class SubscriptionTriggerUtility {
	public static void processSubscriptionAccountEntitlements(
		List<SBQQ__Subscription__c> subscriptions
	) {
		List<SBQQ__Subscription__c> validSubscriptions = new List<SBQQ__Subscription__c>();
		Set<Id> accountIds = new Set<Id>();
		Map<SBQQ__Subscription__c, Id> subscriptionToProductIdManyServerDeps = new Map<SBQQ__Subscription__c, Id>();
		Map<SBQQ__Subscription__c, Id> subscriptionToProductIdOneServerDep = new Map<SBQQ__Subscription__c, Id>();
		Set<Id> accountIdsWithManyServerDeps = new Set<Id>();
		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();

		for (SBQQ__Subscription__c subscription : subscriptions) {
			if (subscription.SBQQ__EndDate__c >= Date.today()) {
				validSubscriptions.add(subscription);
				accountIds.add(subscription.SBQQ__Account__c);
			}
		}

		for (Server_Deployment__c serverDeployment : [
			SELECT Id, Account__c
			FROM Server_Deployment__c
			WHERE Account__c IN :accountIds
		]) {
			if (!accountIdsWithManyServerDeps.contains(serverDeployment.Account__c)) {
				if (!accountIdToServerDeployment.containsKey(serverDeployment.Account__c)) {
					accountIdToServerDeployment.put(serverDeployment.Account__c, serverDeployment);
				} else {
					accountIdToServerDeployment.remove(serverDeployment.Account__c);
					accountIdsWithManyServerDeps.add(serverDeployment.Account__c);
				}
			}
		}

		for (SBQQ__Subscription__c subscription : validSubscriptions) {
			if (accountIdsWithManyServerDeps.contains(subscription.SBQQ__Account__c)) {
				subscriptionToProductIdManyServerDeps.put(subscription, subscription.SBQQ__Product__c);
			} else {
				subscriptionToProductIdOneServerDep.put(subscription, subscription.SBQQ__Product__c);
			}
		}

		if (!subscriptionToProductIdManyServerDeps.isEmpty()) {
			AccountEntitlementTriggerUtility.createAccountEntitlementsManyServerDeps(
				subscriptionToProductIdManyServerDeps
			);
		}

		if (!subscriptionToProductIdOneServerDep.isEmpty()) {
			AccountEntitlementTriggerUtility.createAccountEntitlementsOneServDep(
				subscriptionToProductIdOneServerDep,
				accountIdToServerDeployment
			);
		}
	}

	public static void setAnnualizedSoftwareSpendAndAiCreditsOnAccount(
		List<SBQQ__Subscription__c> subscriptions,
		Map<Id, SBQQ__Subscription__c> oldMap
	) {
		Set<Id> paidAICreditProductIds = getPaidAICreditProductIds();
		Set<Id> accountIds = new Set<Id>();
		for (SBQQ__Subscription__c subscription : subscriptions) {
			if (
				subscription.Include_In_Annualized_Software_Spend__c ||
				paidAICreditProductIds.contains(subscription.SBQQ__Product__c)
			) {
				accountIds.add(subscription.SBQQ__Account__c);
			}
		}

		if (!accountIds.isEmpty()) {
			Id jobId = Test.isRunningTest()
				? null
				: Database.executeBatch(
						new AccountSetSwSpendAndAiCreditsBatch(accountIds),
						accountIds.size() > 100 ? 100 : accountIds.size()
				  );
		}
	}

	public static void processMonthlyPaidAICredits(List<SBQQ__Subscription__c> subscriptions) {
		Set<Id> paidAICreditProductIds = getPaidAICreditProductIds();
		Set<Id> accountIds = new Set<Id>();
		for (SBQQ__Subscription__c subscription : subscriptions) {
			if (paidAICreditProductIds.contains(subscription.SBQQ__Product__c)) {
				accountIds.add(subscription.SBQQ__Account__c);
			}
		}

		if (!accountIds.isEmpty() && !Test.isRunningTest()) {
			Database.executeBatch(
				new AccountSetSwSpendAndAiCreditsBatch(accountIds),
				accountIds.size() > 100 ? 100 : accountIds.size()
			);
		}
	}

	private static Set<Id> getPaidAICreditProductIds() {
		Set<Id> paidAICreditProductIds = new Set<Id>();
		for (Product2 product : [
			SELECT Id
			FROM Product2
			WHERE ProductCode IN :Constants.PAID_AI_CREDIT_PRODUCT_CODES
		]) {
			paidAICreditProductIds.add(product.Id);
		}
		return paidAICreditProductIds;
	}
}