/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class for Server Deployment Subscription trigger
 * @Date: 2026-01-12
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2026-01-12      Initial development
 */
public class ServerDeploymentSubTriggerUtility {
	public static void createServerDeploymentSubscriptions(
		List<Account_Entitlements__c> accountEntitlements,
		Map<Id, Server_Deployment__c> accountIdToServerDeployment,
		Boolean hasSubscription
	) {
		List<Server_Deployment_Subscriptions__c> newServerDeploymentSubscriptions = new List<Server_Deployment_Subscriptions__c>();

		for (Account_Entitlements__c accountEntitlement : accountEntitlements) {
			newServerDeploymentSubscriptions.add(
				buildServerDeploymentSubscription(
					accountIdToServerDeployment.get(accountEntitlement.Account__c),
					accountEntitlement,
					hasSubscription
				)
			);
		}

		Database.SaveResult[] saveResults = Database.insert(newServerDeploymentSubscriptions, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'ServerDeploymentSubTriggerUtility.createServerDeploymentSubscriptions ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	private static Server_Deployment_Subscriptions__c buildServerDeploymentSubscription(
		Server_Deployment__c serverDeployment,
		Account_Entitlements__c accountEntitlement,
		Boolean hasSubscription
	) {
		Server_Deployment_Subscriptions__c serverDeploymentSubscription = new Server_Deployment_Subscriptions__c(
			Account__c = serverDeployment.Account__c,
			Server_Deployment__c = serverDeployment.Id,
			Subscription_Quantity__c = accountEntitlement.Quantity_Purchased__c,
			Account_Entitlement__c = accountEntitlement.Id
		);
		if (hasSubscription) {
			serverDeploymentSubscription.Subscription__c = accountEntitlement.Source_Subscription__c;
		}
		return serverDeploymentSubscription;
	}
}