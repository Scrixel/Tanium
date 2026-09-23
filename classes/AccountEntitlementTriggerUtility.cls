/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Utility class for Account Entitlement trigger
 * @Date: 2025-11-13
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Initial development
 * SS-12494     2026-01-27      Update createAccountEntitlement methods with different key value pairs
 * SS-12651     2026-02-16      Update createAccountEntitlementsOneServDep with null check
 * SS-12914     2026-03-31      Update createAccountEntitlementsOneServDep to always create server deployment subscriptions for testing
 */
public class AccountEntitlementTriggerUtility {
	public static void createAccountEntitlementsManyServerDeps(
		Map<SBQQ__Subscription__c, Id> subscriptionToProductId
	) {
		List<Account_Entitlements__c> newAccountEntitlements = new List<Account_Entitlements__c>();
		Map<Id, List<Product_Module__c>> productIdToProductModules = getProductIdToProductModules(
			subscriptionToProductId.values()
		);

		for (SBQQ__Subscription__c subscription : subscriptionToProductId.keySet()) {
			if (productIdToProductModules.containsKey(subscriptionToProductId.get(subscription))) {
				for (
					Product_Module__c productModule : productIdToProductModules.get(
						subscriptionToProductId.get(subscription)
					)
				) {
					newAccountEntitlements.add(
						buildAccountEntitlementSubscription(subscription, productModule)
					);
				}
			}
		}

		Database.SaveResult[] saveResults = Database.insert(newAccountEntitlements, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountEntitlementTriggerUtility.createAccountEntitlementsManyServerDeps ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void createAccountEntitlementsOneServDep(
		Map<SBQQ__Subscription__c, Id> subscriptionToProductId,
		Map<Id, Server_Deployment__c> accountIdToServerDeployment
	) {
		List<Account_Entitlements__c> newAccountEntitlements = new List<Account_Entitlements__c>();
		Map<Id, List<Product_Module__c>> productIdToProductModules = getProductIdToProductModules(
			subscriptionToProductId.values()
		);

		for (SBQQ__Subscription__c subscription : subscriptionToProductId.keySet()) {
			if (productIdToProductModules.containsKey(subscriptionToProductId.get(subscription))) {
				for (
					Product_Module__c productModule : productIdToProductModules.get(
						subscriptionToProductId.get(subscription)
					)
				) {
					Account_Entitlements__c newAccountEntitlement = buildAccountEntitlementSubscription(
						subscription,
						productModule
					);
					newAccountEntitlement.Quantity_Allocated__c = subscription.SBQQ__Quantity__c;
					newAccountEntitlements.add(newAccountEntitlement);
				}
			}
		}

		Database.SaveResult[] saveResults = Database.insert(newAccountEntitlements, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountEntitlementTriggerUtility.createAccountEntitlementsOneServDep ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();

		if (System.Label.Trigger_CreateServDepSubsFlag == 'true' || Test.isRunningTest()) {
			ServerDeploymentSubTriggerUtility.createServerDeploymentSubscriptions(
				newAccountEntitlements,
				accountIdToServerDeployment,
				true
			);
		}
	}

	public static void createAccountEntitlementsNFR(
		Map<Id, NFR__c> nfrMap,
		Map<Id, List<Module__c>> nfrIdToModules,
		Map<Id, Server_Deployment__c> accountIdToServerDeployment
	) {
		List<Account_Entitlements__c> newAccountEntitlements = new List<Account_Entitlements__c>();

		for (Id nfrId : nfrIdToModules.keySet()) {
			for (Module__c module : nfrIdToModules.get(nfrId)) {
				newAccountEntitlements.add(buildAccountEntitlementNFR(nfrMap.get(nfrId), module));
			}
		}

		Database.SaveResult[] saveResults = Database.insert(newAccountEntitlements, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountEntitlementTriggerUtility.createAccountEntitlementsNFR ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();

		if (System.Label.Trigger_CreateServDepSubsFlag == 'true' || Test.isRunningTest()) {
			ServerDeploymentSubTriggerUtility.createServerDeploymentSubscriptions(
				newAccountEntitlements,
				accountIdToServerDeployment,
				false
			);
		}
	}

	public static void createAccountEntitlementsPOCRequestModules(
		Map<Id, POC_Request__c> pocRequestMap,
		Map<Id, List<Id>> pocRequestIdToModuleIds,
		Map<Id, Server_Deployment__c> accountIdToServerDeployment
	) {
		List<Account_Entitlements__c> newAccountEntitlements = new List<Account_Entitlements__c>();

		for (Id pocRequestId : pocRequestIdToModuleIds.keySet()) {
			for (Id moduleId : pocRequestIdToModuleIds.get(pocRequestId)) {
				newAccountEntitlements.add(
					buildAccountEntitlementPOCRequestModule(pocRequestMap.get(pocRequestId), moduleId)
				);
			}
		}

		Database.SaveResult[] saveResults = Database.insert(newAccountEntitlements, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountEntitlementTriggerUtility.createAccountEntitlementsPOCRequestModules ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();

		if (System.Label.Trigger_CreateServDepSubsFlag == 'true' || Test.isRunningTest()) {
			ServerDeploymentSubTriggerUtility.createServerDeploymentSubscriptions(
				newAccountEntitlements,
				accountIdToServerDeployment,
				false
			);
		}
	}

	public static void createAccountEntitlementsPOCRequestSolutions(
		Map<Id, POC_Request__c> productIdToPOCRequest,
		Map<Id, Server_Deployment__c> accountIdToServerDeployment
	) {
		List<Account_Entitlements__c> newAccountEntitlements = new List<Account_Entitlements__c>();
		Map<Id, Product_Module__c> productModuleMap = new Map<Id, Product_Module__c>(
			[
				SELECT Id, Module__c, Product__c
				FROM Product_Module__c
				WHERE Product__c IN :productIdToPOCRequest.keySet()
			]
		);

		for (Product_Module__c productModule : productModuleMap.values()) {
			newAccountEntitlements.add(
				buildAccountEntitlementPOCRequestSolution(
					productIdToPOCRequest.get(productModule.Product__c),
					productModule
				)
			);
		}

		Database.SaveResult[] saveResults = Database.insert(newAccountEntitlements, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountEntitlementTriggerUtility.createAccountEntitlementsPOCRequestSolutions ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();

		if (System.Label.Trigger_CreateServDepSubsFlag == 'true' || Test.isRunningTest()) {
			ServerDeploymentSubTriggerUtility.createServerDeploymentSubscriptions(
				newAccountEntitlements,
				accountIdToServerDeployment,
				true
			);
		}
	}

	private static Map<Id, List<Product_Module__c>> getProductIdToProductModules(
		List<Id> productIds
	) {
		Map<Id, List<Product_Module__c>> productIdToProductModules = new Map<Id, List<Product_Module__c>>();

		for (Product_Module__c productModule : [
			SELECT Id, Module__c, Product__c
			FROM Product_Module__c
			WHERE Product__c IN :productIds
		]) {
			if (!productIdToProductModules.containsKey(productModule.Product__c)) {
				productIdToProductModules.put(productModule.Product__c, new List<Product_Module__c>());
			}
			productIdToProductModules.get(productModule.Product__c).add(productModule);
		}
		return productIdToProductModules;
	}

	private static Account_Entitlements__c buildAccountEntitlementSubscription(
		SBQQ__Subscription__c subscription,
		Product_Module__c productModule
	) {
		return new Account_Entitlements__c(
			Account__c = subscription.SBQQ__Account__c,
			Module__c = productModule.Module__c,
			Product__c = productModule.Product__c,
			Start_Date__c = subscription.SBQQ__StartDate__c,
			End_Date__c = subscription.SBQQ__EndDate__c,
			Quantity_Purchased__c = subscription.SBQQ__Quantity__c,
			Type__c = 'Subscription',
			Source_Subscription__c = subscription.Id
		);
	}

	private static Account_Entitlements__c buildAccountEntitlementNFR(NFR__c nfr, Module__c module) {
		return new Account_Entitlements__c(
			Account__c = nfr.Account__c,
			Module__c = module.Id,
			Start_Date__c = nfr.NFR_Issued_Date__c,
			End_Date__c = nfr.NFR_Expiration_Date__c,
			Quantity_Purchased__c = nfr.Number_of_Endpoints__c,
			Quantity_Allocated__c = nfr.Number_of_Endpoints__c,
			Type__c = 'NFR',
			Source_NFR__c = nfr.Id
		);
	}

	private static Account_Entitlements__c buildAccountEntitlementPOCRequestModule(
		POC_Request__c pocRequest,
		Id moduleId
	) {
		return new Account_Entitlements__c(
			Account__c = pocRequest.Account__c,
			Module__c = moduleId,
			Start_Date__c = pocRequest.Start_Date__c,
			End_Date__c = pocRequest.End_Date__c,
			Quantity_Purchased__c = pocRequest.Quantity__c,
			Quantity_Allocated__c = pocRequest.Quantity__c,
			Type__c = 'POC Request',
			Source_POC_Request__c = pocRequest.Id
		);
	}

	private static Account_Entitlements__c buildAccountEntitlementPOCRequestSolution(
		POC_Request__c pocRequest,
		Product_Module__c productModule
	) {
		return new Account_Entitlements__c(
			Account__c = pocRequest.Account__c,
			Module__c = productModule.Module__c,
			Product__c = productModule.Product__c,
			Start_Date__c = pocRequest.Start_Date__c,
			End_Date__c = pocRequest.End_Date__c,
			Quantity_Purchased__c = pocRequest.Quantity__c,
			Quantity_Allocated__c = pocRequest.Quantity__c,
			Type__c = 'POC Request',
			Source_POC_Request__c = pocRequest.Id
		);
	}
}