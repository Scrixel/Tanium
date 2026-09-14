/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Update Account Seats Purchased, Active Subscriptions, Active Packages, Active Operatores (Screen Share) and Subscription Max End Date
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7608    2024-08-10    Populate Max Subscription End Date and MSP Max Subscription End Date
 * SS-10969   2025-05-29    Added constructor, updated method execute
 * SS-12650   2026-02-23    Updated batch logic to check for quantity in subscriptions
 * SS-13669   2026-08-25    Updated class to repoint to NUE objects and fields
 */
public without sharing class BatchUpdateTotalSeatsPurchased implements Database.Batchable<sObject>, Schedulable {
	private String accountQuery =
		'SELECT Id, ' +
		'Seats_Purchased1__c, ' +
		'Active_Subscriptions__c, ' +
		'Active_Packages__c, ' +
		'Active_Operators_Screen_Share__c, ' +
		'Max_Subscription_End_Date__c, ' +
		'Max_MSP_Managed_Subscription_End_Date__c, ' +
		'Type ' +
		'FROM Account';
	private List<String> excludedProductPromo = System.Label.Exclude_Product_Promo_in_Seat_Purchased_Update.split(
		','
	);

	public BatchUpdateTotalSeatsPurchased() {
	}

	public BatchUpdateTotalSeatsPurchased(String query) {
		this.accountQuery = String.isNotBlank(query) ? query : this.accountQuery;
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(this.accountQuery);
	}

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new BatchUpdateTotalSeatsPurchased());
	}

	public void execute(Database.BatchableContext bc, List<Account> accounts) {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler'
			}
		);

		Map<Id, Decimal> totalAccountSeatCountMap = new Map<Id, Decimal>();
		Map<Id, Decimal> activeSubscriptionCountMap = new Map<Id, Decimal>();
		Map<Id, Decimal> activeModulesMap = new Map<Id, Decimal>();
		Map<Id, Decimal> activeOperatorsMap = new Map<Id, Decimal>();
		Map<Id, Date> maxSubscriptionEndDateMap = new Map<Id, Date>();
		Map<Id, Date> mspMaxSubscriptionEndDateMap = new Map<Id, Date>();
		Decimal totalSeatCount;
		Decimal activeSubscriptionsCount;
		Decimal activeModuleCount;
		Decimal subscriptionQuantity;
		Decimal activeOperator;
		Date maxSubEndDate;
		Date mspMaxSubEndDate;
		Id mspAccount;
		Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

		for (Ruby__Subscription__c sub : [
			SELECT
				Id,
				Ruby__Customer__c,
				Ruby__Quantity__c,
				Ruby__SubscriptionStartDate__c,
				Ruby__SubscriptionEndDate__c,
				ELV_Bundle_Type__c,
				ELV_QuoteLine__r.ELV_Product_Promotion_Name__c,
				ELV_Include_in_Seats_Purchased__c,
				ELV_Exclude_from_Seats_Roll_up__c,
				ELV_Status__c,
				ELV_Sold_by_Operators_versus_Endpoints__c,
				ELV_Product_Code__c
			FROM Ruby__Subscription__c
			WHERE Ruby__Customer__c IN :accountIds
		]) {
			maxSubEndDate = maxSubscriptionEndDateMap.get(sub.Ruby__Customer__c);
			if (
				(sub.Ruby__Quantity__c == null || sub.Ruby__Quantity__c > 0) &&
				(maxSubEndDate == null ||
				(maxSubEndDate != null &&
				maxSubEndDate < sub.Ruby__SubscriptionEndDate__c))
			) {
				maxSubscriptionEndDateMap.put(sub.Ruby__Customer__c, sub.Ruby__SubscriptionEndDate__c);
			}

			if (
				sub.Ruby__SubscriptionStartDate__c <= Date.today() &&
				sub.Ruby__SubscriptionEndDate__c >= Date.today() &&
				String.isBlank(sub.ELV_Bundle_Type__c) &&
				!excludedProductPromo.contains(sub.ELV_QuoteLine__r.ELV_Product_Promotion_Name__c) &&
				sub.ELV_Include_in_Seats_Purchased__c == true &&
				sub.ELV_Exclude_from_Seats_Roll_up__c == false
			) {
				totalSeatCount = totalAccountSeatCountMap.get(sub.Ruby__Customer__c);

				if (totalSeatCount != null) {
					totalAccountSeatCountMap.put(
						sub.Ruby__Customer__c,
						totalSeatCount + sub.Ruby__Quantity__c
					);
				} else {
					totalAccountSeatCountMap.put(
						sub.Ruby__Customer__c,
						sub.Ruby__Quantity__c != null ? sub.Ruby__Quantity__c : 0.00
					);
				}
				activeSubscriptionsCount = activeSubscriptionCountMap.get(sub.Ruby__Customer__c);
				if (activeSubscriptionsCount != null) {
					activeSubscriptionCountMap.put(sub.Ruby__Customer__c, activeSubscriptionsCount + 1);
				} else {
					activeSubscriptionCountMap.put(sub.Ruby__Customer__c, 1);
				}
			}

			if (
				sub.Ruby__SubscriptionStartDate__c <= Date.today() &&
				sub.Ruby__SubscriptionEndDate__c >= Date.today() &&
				sub.ELV_Sold_by_Operators_versus_Endpoints__c == true &&
				sub.ELV_Product_Code__c == 'SS-RMT'
			) {
				activeOperator = activeOperatorsMap.get(sub.Ruby__Customer__c);

				if (activeOperator != null) {
					activeOperatorsMap.put(
						sub.Ruby__Customer__c,
						(activeOperator + sub.Ruby__Quantity__c)
					);
				} else {
					activeOperatorsMap.put(
						sub.Ruby__Customer__c,
						sub.Ruby__Quantity__c != null ? sub.Ruby__Quantity__c : 0.00
					);
				}
			}
		}

		Set<Id> productIds = new Set<Id>();
		Id prevAccountId = null;

		for (Ruby__Subscription__c subscription : [
			SELECT
				Id,
				ELV_End_User_Account__c,
				Ruby__Quantity__c,
				Ruby__Product__c,
				Ruby__SubscriptionEndDate__c,
				ELV_Include_in_Seats_Purchased__c,
				ELV_QuoteLine__r.ELV_Product_Promotion_Name__c,
				ELV_Exclude_from_Seats_Roll_up__c,
				ELV_Bundle_Type__c,
				ELV_Status__c
			FROM Ruby__Subscription__c
			WHERE ELV_End_User_Account__c IN :accountIds
			ORDER BY ELV_End_User_Account__c
		]) {
			mspMaxSubEndDate = mspMaxSubscriptionEndDateMap.get(subscription.ELV_End_User_Account__c);
			if (
				(subscription.Ruby__Quantity__c == null || subscription.Ruby__Quantity__c > 0) &&
				mspMaxSubEndDate == null ||
				(mspMaxSubEndDate != null &&
				mspMaxSubEndDate < subscription.Ruby__SubscriptionEndDate__c)
			) {
				mspMaxSubscriptionEndDateMap.put(
					subscription.ELV_End_User_Account__c,
					subscription.Ruby__SubscriptionEndDate__c
				);
			}

			if (
				subscription.ELV_Status__c == 'Active' &&
				String.isBlank(subscription.ELV_Bundle_Type__c) &&
				!excludedProductPromo.contains(
					subscription.ELV_QuoteLine__r.ELV_Product_Promotion_Name__c
				) &&
				subscription.ELV_Include_in_Seats_Purchased__c == true &&
				subscription.ELV_Exclude_from_Seats_Roll_up__c == false
			) {
				mspAccount = subscription.ELV_End_User_Account__c;
				totalSeatCount = totalAccountSeatCountMap.get(mspAccount);
				subscriptionQuantity = subscription.Ruby__Quantity__c != null
					? subscription.Ruby__Quantity__c
					: 0;
				if (totalSeatCount != null) {
					totalAccountSeatCountMap.put(mspAccount, totalSeatCount + subscriptionQuantity);
				} else {
					totalAccountSeatCountMap.put(mspAccount, subscriptionQuantity);
				}

				if (prevAccountId == mspAccount || prevAccountId == null) {
					productIds.add(subscription.Ruby__Product__c);
					prevAccountId = mspAccount;
				}
				if (prevAccountId != mspAccount) {
					activeModulesMap.put(prevAccountId, productIds.isEmpty() ? 0 : productIds.size());
					productIds.clear();
					productIds.add(subscription.Ruby__Product__c);
					prevAccountId = mspAccount;
				}
			}
		}
		activeModulesMap.put(mspAccount, productIds.isEmpty() ? 0 : productIds.size());

		List<Account> acctsToUpdate = new List<Account>();
		for (Account acc : accounts) {
			totalSeatCount = totalAccountSeatCountMap.get(acc.Id) != null
				? totalAccountSeatCountMap.get(acc.Id)
				: 0;
			subscriptionQuantity = activeSubscriptionCountMap.get(acc.Id) != null
				? activeSubscriptionCountMap.get(acc.Id)
				: 0;
			activeModuleCount = activeModulesMap.get(acc.Id) != null
				? activeModulesMap.get(acc.Id)
				: 0;
			activeOperator = activeOperatorsMap.get(acc.Id) != null
				? activeOperatorsMap.get(acc.Id)
				: 0;
			maxSubEndDate = maxSubscriptionEndDateMap.get(acc.Id);
			mspMaxSubEndDate = mspMaxSubscriptionEndDateMap.get(acc.Id);

			if (
				acc.Seats_Purchased1__c != totalSeatCount ||
				acc.Active_Subscriptions__c != subscriptionQuantity ||
				acc.Active_Packages__c != activeModuleCount ||
				acc.Active_Operators_Screen_Share__c != activeOperator ||
				acc.Max_Subscription_End_Date__c != maxSubEndDate ||
				acc.Max_MSP_Managed_Subscription_End_Date__c != mspMaxSubEndDate
			) {
				acc.Seats_Purchased1__c = totalSeatCount;
				acc.Active_Subscriptions__c = subscriptionQuantity;
				acc.Active_Packages__c = activeModuleCount;
				acc.Active_Operators_Screen_Share__c = activeOperator;
				acc.Max_Subscription_End_Date__c = maxSubEndDate;
				acc.Max_MSP_Managed_Subscription_End_Date__c = mspMaxSubEndDate;
				acctsToUpdate.add(acc);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(acctsToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'BatchUpdateTotalSeatsPurchased.execute ERRORS',
				saveResults
			)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'BatchUpdateTotalSeatsPurchased');
	}
}