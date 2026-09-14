/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: NFR Trigger Utility, part of Trigger Framework
 * @Date: 2025-11-13
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Initial development
 */
public class NFRTriggerUtility {
	public static void handleApprovedNFRs(List<NFR__c> NFRs, Map<Id, NFR__c> oldMap) {
		Map<Id, NFR__c> nfrMap = new Map<Id, NFR__c>();
		Map<Id, String> nfrIdToModuleNames = new Map<Id, String>();
		Map<Id, List<Module__c>> nfrIdToModules = new Map<Id, List<Module__c>>();
		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();
		Set<Id> accountIds = new Set<Id>();
		String moduleNames = '';

		for (NFR__c nfr : NFRs) {
			if (
				oldMap != null &&
				nfr.Status__c != oldMap?.get(nfr.Id).Status__c &&
				nfr.Status__c == 'Approved' &&
				String.isNotBlank(nfr.Select_Tanium_Product__c) &&
				nfr.Number_of_Endpoints__c != null &&
				nfr.NFR_Issued_Date__c != null &&
				nfr.NFR_Expiration_Date__c != null
			) {
				nfrMap.put(nfr.Id, nfr);
				nfrIdToModuleNames.put(nfr.Id, nfr.Select_Tanium_Product__c);
				moduleNames += nfr.Select_Tanium_Product__c + ';';
				accountIds.add(nfr.Account__c);
			}
		}

		Map<String, Module__c> moduleNameToModule = new Map<String, Module__c>();
		for (Module__c module : [
			SELECT Id, Name
			FROM Module__c
			WHERE Name IN :moduleNames.split(';')
		]) {
			moduleNameToModule.put(module.Name, module);
		}

		for (Id nfrId : nfrIdToModuleNames.keySet()) {
			List<Module__c> modules = new List<Module__c>();
			for (String moduleName : nfrIdToModuleNames.get(nfrId).split(';')) {
				modules.add(moduleNameToModule.get(moduleName));
			}
			nfrIdToModules.put(nfrId, modules);
		}

		for (Server_Deployment__c serverDeployment : [
			SELECT Id, Account__c
			FROM Server_Deployment__c
			WHERE Account__c IN :accountIds
		]) {
			accountIdToServerDeployment.put(serverDeployment.Account__c, serverDeployment);
		}

		if (!nfrIdToModules.isEmpty()) {
			AccountEntitlementTriggerUtility.createAccountEntitlementsNFR(
				nfrMap,
				nfrIdToModules,
				accountIdToServerDeployment
			);
		}
	}
}