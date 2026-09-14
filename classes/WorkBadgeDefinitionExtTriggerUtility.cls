/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: This is a utility class for WorkBadgeDefinitionExtensionTrigger
 * RequestId  ModifiedDate  Comment
 * SS-8303    2024-09-06    Assign points to badges
 * SS-9838    2025-01-16    Changed method name getWorkBadgeDefinitionNames to getWorkBadgeNameDefinitionMap
 */
public with sharing class WorkBadgeDefinitionExtTriggerUtility {
	public static void validateBadges(
		List<WorkBadgeDefinitionExtension__c> workBadgeDefinitionExtensions,
		Map<Id, WorkBadgeDefinitionExtension__c> oldMap
	) {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = getWorkBadgeNameDefinitionMap();
		for (
			WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension : workBadgeDefinitionExtensions
		) {
			if (!workBadgeNameDefinitionMap.keySet().contains(workBadgeDefinitionExtension.Name)) {
				workBadgeDefinitionExtension.addError('Badge doesn\'t exist');
			}
		}
	}

	public static void validateDuplicateBadgeDefinition(
		List<WorkBadgeDefinitionExtension__c> workBadgeDefinitionExtensions
	) {
		Set<String> badgeNames = new Set<String>();
		Map<String, WorkBadgeDefinitionExtension__c> workBadgeNameToExtensionMap = new Map<String, WorkBadgeDefinitionExtension__c>();

		for (
			WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension : workBadgeDefinitionExtensions
		) {
			badgeNames.add(workBadgeDefinitionExtension.Name);
		}

		for (WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension : [
			SELECT Id, Name
			FROM WorkBadgeDefinitionExtension__c
			WHERE Name IN :badgeNames
		]) {
			workBadgeNameToExtensionMap.put(
				workBadgeDefinitionExtension.Name,
				workBadgeDefinitionExtension
			);
		}

		for (
			WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension : workBadgeDefinitionExtensions
		) {
			if (workBadgeNameToExtensionMap.containsKey(workBadgeDefinitionExtension.Name)) {
				workBadgeDefinitionExtension.addError('Badge already exist');
			}
		}
	}

	public static void setSourceId(
		List<WorkBadgeDefinitionExtension__c> workBadgeDefinitionExtensions
	) {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = getWorkBadgeNameDefinitionMap();
		for (
			WorkBadgeDefinitionExtension__c workBadgeDefinitionExtension : workBadgeDefinitionExtensions
		) {
			if (workBadgeNameDefinitionMap.containsKey(workBadgeDefinitionExtension.Name)) {
				workBadgeDefinitionExtension.SourceId__c = workBadgeNameDefinitionMap.get(
						workBadgeDefinitionExtension.Name
					)
					.Id;
			}
		}
	}

	public static Map<String, WorkBadgeDefinition> getWorkBadgeNameDefinitionMap() {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = new Map<String, WorkBadgeDefinition>();
		for (WorkBadgeDefinition workBadgeDefinition : [
			SELECT Id, Name, Description, IsActive
			FROM WorkBadgeDefinition
		]) {
			workBadgeNameDefinitionMap.put(workBadgeDefinition.Name, workBadgeDefinition);
		}
		return workBadgeNameDefinitionMap;
	}
}