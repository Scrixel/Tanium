/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: POCRequest Trigger Utility, part of Trigger Framework
 * @Date: 2025-11-13
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Initial development
 */
public class POCRequestTriggerUtility {
	public static void handleApprovedPOCRequests(
		List<POC_Request__c> pocRequests,
		Map<Id, POC_Request__c> oldMap
	) {
		List<POC_Request__c> approvedPOCRequestsSolutions = new List<POC_Request__c>();
		List<POC_Request__c> approvedPOCRequestsModules = new List<POC_Request__c>();
		Map<Id, Server_Deployment__c> accountIdToServerDeployment = new Map<Id, Server_Deployment__c>();
		Set<Id> accountIds = new Set<Id>();

		for (POC_Request__c pocRequest : pocRequests) {
			if (
				pocRequest.Approval_Stage__c != oldMap.get(pocRequest.Id).Approval_Stage__c &&
				pocRequest.Approval_Stage__c == 'Fully Approved' &&
				String.isNotBlank(pocRequest.Deployment_Method__c)
			) {
				if (String.isNotBlank(pocRequest.Selected_Modules__c)) {
					approvedPOCRequestsModules.add(pocRequest);
					accountIds.add(pocRequest.Account__c);
				}
				if (String.isNotBlank(pocRequest.Selected_Solutions__c)) {
					approvedPOCRequestsSolutions.add(pocRequest);
					accountIds.add(pocRequest.Account__c);
				}
			}
		}

		for (Server_Deployment__c serverDeployment : [
			SELECT Id, Account__c
			FROM Server_Deployment__c
			WHERE Account__c IN :accountIds
		]) {
			accountIdToServerDeployment.put(serverDeployment.Account__c, serverDeployment);
		}

		if (!approvedPOCRequestsModules.isEmpty()) {
			handleApprovedPOCRequestModules(approvedPOCRequestsModules, accountIdToServerDeployment);
		}

		if (!approvedPOCRequestsSolutions.isEmpty()) {
			handleApprovedPOCRequestSolutions(
				approvedPOCRequestsSolutions,
				accountIdToServerDeployment
			);
		}
	}

	private static void handleApprovedPOCRequestModules(
		List<POC_Request__c> approvedPOCRequestModules,
		Map<Id, Server_Deployment__c> accountIdToServerDeployment
	) {
		Map<Id, POC_Request__c> pocRequestMap = new Map<Id, POC_Request__c>();
		Map<Id, List<Id>> pocRequestIdToModuleIds = new Map<Id, List<Id>>();

		for (POC_Request__c pocRequest : approvedPOCRequestModules) {
			pocRequestMap.put(pocRequest.Id, pocRequest);
			pocRequestIdToModuleIds.put(pocRequest.Id, buildModuleIds(pocRequest));
		}

		if (!pocRequestIdToModuleIds.isEmpty()) {
			AccountEntitlementTriggerUtility.createAccountEntitlementsPOCRequestModules(
				pocRequestMap,
				pocRequestIdToModuleIds,
				accountIdToServerDeployment
			);
		}
	}

	private static void handleApprovedPOCRequestSolutions(
		List<POC_Request__c> approvedPOCRequestsSolutions,
		Map<Id, Server_Deployment__c> accountIdToServerDeployment
	) {
		Map<Id, POC_Request__c> productIdToPOCRequest = new Map<Id, POC_Request__c>();

		for (POC_Request__c pocRequest : approvedPOCRequestsSolutions) {
			productIdToPOCRequest.putAll(buildProductIdToPOCRequestMap(pocRequest));
		}

		if (!productIdToPOCRequest.isEmpty()) {
			AccountEntitlementTriggerUtility.createAccountEntitlementsPOCRequestSolutions(
				productIdToPOCRequest,
				accountIdToServerDeployment
			);
		}
	}

	private static List<Id> buildModuleIds(POC_Request__c pocRequest) {
		List<Id> moduleIds = new List<Id>();
		List<String> selectedModules = pocRequest.Selected_Modules__c.split(',');

		for (POC_Request_Solution_and_Module_Map__c pocRequestSolutionAndModuleMap : [
			SELECT Id, POC_Field_Label__c, Module__c
			FROM POC_Request_Solution_and_Module_Map__c
			WHERE Module__c != NULL AND POC_Field_Label__c IN :selectedModules
		]) {
			moduleIds.add(pocRequestSolutionAndModuleMap.Module__c);
		}

		return moduleIds;
	}

	private static Map<Id, POC_Request__c> buildProductIdToPOCRequestMap(POC_Request__c pocRequest) {
		Map<Id, POC_Request__c> productIdToPOCRequest = new Map<Id, POC_Request__c>();
		List<String> selectedSolutions = pocRequest.Selected_Solutions__c.split(',');

		for (POC_Request_Solution_and_Module_Map__c pocRequestSolutionAndModuleMap : [
			SELECT Id, POC_Field_Label__c, Product_Cloud__c, Product_On_Prem__c
			FROM POC_Request_Solution_and_Module_Map__c
			WHERE POC_Field_Label__c IN :selectedSolutions
		]) {
			if (pocRequest.Deployment_Method__c == 'Cloud') {
				productIdToPOCRequest.put(pocRequestSolutionAndModuleMap.Product_Cloud__c, pocRequest);
			} else if (pocRequest.Deployment_Method__c == 'On-Prem') {
				productIdToPOCRequest.put(
					pocRequestSolutionAndModuleMap.Product_On_Prem__c,
					pocRequest
				);
			}
		}

		return productIdToPOCRequest;
	}
}