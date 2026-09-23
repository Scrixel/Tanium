/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class for User Territory Association Trigger Handler
 * @Date: 2025-09-30
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-11284     2025-09-30       Initial development
 * SS-12985     2026-04-22       Added Customer to valid account types in populateAccountSDR method
 * SS-13234     2026-06-02       Updated futurePopulateAccountSDR method to update Account's SDR Manager
 * SS-12811     2026-07-10       Created populateAccountOwner
 * SS-13545     2026-07-27       Created populateSalesPlanTerritoryFields
 */
public with sharing class UserTerritoryAssocTriggerUtility {
	private static final Integer SDR_ACCOUNT_BATCH_SIZE = 100;
	private static final Integer OWNER_ACCOUNT_BATCH_SIZE = 100;
	private static List<String> validAccountTypes = new List<String>{
		'Prospect',
		'Former Customer',
		'Customer'
	};

	public static void populateAccountSDR(
		List<UserTerritory2Association> userTerrAssociations,
		Map<Id, UserTerritory2Association> oldMap
	) {
		Map<Id, UserTerritory2Association> territoryIdToUserTerrAssociation = new Map<Id, UserTerritory2Association>();
		for (UserTerritory2Association userTerrAssociation : userTerrAssociations) {
			if (
				userTerrAssociation.RoleInTerritory2 == 'SDR' &&
				userTerrAssociation.IsActive == true &&
				(oldMap == null ||
				(oldMap != null &&
				oldMap.get(userTerrAssociation.Id).RoleInTerritory2 != 'SDR'))
			) {
				territoryIdToUserTerrAssociation.put(
					userTerrAssociation.Territory2Id,
					userTerrAssociation
				);
			}
		}

		if (territoryIdToUserTerrAssociation.isEmpty()) {
			return;
		}

		Map<Id, Id> accountIdToUserId = new Map<Id, Id>();
		for (Account acc : [
			SELECT Id, Primary_Sales_Territory_Id__c, BDR__c
			FROM Account
			WHERE
				Primary_Sales_Territory_Id__c IN :territoryIdToUserTerrAssociation.keySet()
				AND Type IN :validAccountTypes
		]) {
			accountIdToUserId.put(
				acc.Id,
				territoryIdToUserTerrAssociation.get(acc.Primary_Sales_Territory_Id__c).UserId
			);
		}

		Map<Id, Id> userIdToUserManagerId = Utility.getUserIdToUserManagerId(
			accountIdToUserId.values()
		);
		if (!accountIdToUserId.isEmpty() && !Test.isRunningTest()) {
			Database.executeBatch(
				new AccountSDRBatch(accountIdToUserId, userIdToUserManagerId),
				SDR_ACCOUNT_BATCH_SIZE
			);
		}
	}

	public static void removeAccountSDR(List<UserTerritory2Association> oldUserTerrAssociations) {
		Map<Id, UserTerritory2Association> territoryIdToUserTerrAssociation = new Map<Id, UserTerritory2Association>();
		for (UserTerritory2Association oldUserTerrAssociation : oldUserTerrAssociations) {
			if (
				oldUserTerrAssociation.RoleInTerritory2 == 'SDR' &&
				oldUserTerrAssociation.IsActive == true
			) {
				territoryIdToUserTerrAssociation.put(
					oldUserTerrAssociation.Territory2Id,
					oldUserTerrAssociation
				);
			}
		}

		if (territoryIdToUserTerrAssociation.isEmpty()) {
			return;
		}

		Id dsaUserId = [SELECT Id FROM User WHERE Alias = 'dsa' LIMIT 1].Id;
		Map<Id, Id> accountIdToUserId = new Map<Id, Id>();

		for (Account acc : [
			SELECT Id, Primary_Sales_Territory_Id__c, BDR__c
			FROM Account
			WHERE
				Primary_Sales_Territory_Id__c IN :territoryIdToUserTerrAssociation.keySet()
				AND Type IN :validAccountTypes
		]) {
			accountIdToUserId.put(acc.Id, dsaUserId);
		}

		Map<Id, Id> userIdToUserManagerId = new Map<Id, Id>{ dsaUserId => dsaUserId };

		if (!accountIdToUserId.isEmpty() && !Test.isRunningTest()) {
			Database.executeBatch(
				new AccountSDRBatch(accountIdToUserId, userIdToUserManagerId),
				SDR_ACCOUNT_BATCH_SIZE
			);
		}
	}

	public static void populateAccountOwner(
		List<UserTerritory2Association> userTerrAssociations,
		Map<Id, UserTerritory2Association> oldMap
	) {
		Map<Id, UserTerritory2Association> territoryIdToUserTerrAssociation = new Map<Id, UserTerritory2Association>();
		for (UserTerritory2Association userTerrAssociation : userTerrAssociations) {
			if (
				userTerrAssociation.RoleInTerritory2 == 'Sales' &&
				userTerrAssociation.IsActive == true &&
				(oldMap == null ||
				(oldMap != null &&
				oldMap.get(userTerrAssociation.Id).RoleInTerritory2 != 'Sales'))
			) {
				territoryIdToUserTerrAssociation.put(
					userTerrAssociation.Territory2Id,
					userTerrAssociation
				);
			}
		}

		if (territoryIdToUserTerrAssociation.isEmpty()) {
			return;
		}

		Map<Id, Id> accountIdToUserId = new Map<Id, Id>();
		for (Account acc : [
			SELECT Id, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE
				Primary_Sales_Territory_Id__c IN :territoryIdToUserTerrAssociation.keySet()
				AND Type IN :validAccountTypes
		]) {
			accountIdToUserId.put(
				acc.Id,
				territoryIdToUserTerrAssociation.get(acc.Primary_Sales_Territory_Id__c).UserId
			);
		}

		if (!accountIdToUserId.isEmpty() && !Test.isRunningTest()) {
			Database.executeBatch(
				new AccountOwnerETMBatch(accountIdToUserId),
				OWNER_ACCOUNT_BATCH_SIZE
			);
		}
	}

	/*
	public static void populateSalesPlanTerritoryFields(
		List<UserTerritory2Association> userTerrAssociations,
		Map<Id, UserTerritory2Association> oldMap
	) {
		Map<Id, Id> userIdToTerritoryId = new Map<Id, Id>();
		for (UserTerritory2Association userTerrAssociation : userTerrAssociations) {
			if (
				userTerrAssociation.RoleInTerritory2 == 'Sales' &&
				userTerrAssociation.IsActive == true &&
				(oldMap == null ||
				(oldMap != null &&
				oldMap.get(userTerrAssociation.Id).RoleInTerritory2 != 'Sales'))
			) {
				userIdToTerritoryId.put(userTerrAssociation.UserId, userTerrAssociation.Territory2Id);
			}
		}

		if (userIdToTerritoryId.isEmpty()) {
			return;
		}

		Map<Id, Id> salesPlanIdToTerritoryId = new Map<Id, Id>();
		Set<Id> skipUserIds = new Set<Id>();
		for (Sales_Plan__c salesPlan : [
			SELECT Id, Sales_User__c
			FROM Sales_Plan__c
			WHERE Sales_User__c IN :userIdToTerritoryId.keySet()
			ORDER BY CreatedDate DESC
		]) {
			if (!skipUserIds.contains(salesPlan.Sales_User__c)) {
				salesPlanIdToTerritoryId.put(
					salesPlan.Id,
					userIdToTerritoryId.get(salesPlan.Sales_User__c)
				);
				skipUserIds.add(salesPlan.Sales_User__c);
			}
		}

		if (!salesPlanIdToTerritoryId.isEmpty()) {
			populateSalesPlanTerritoryFields(salesPlanIdToTerritoryId);
		}
	}

	@future
	private static void populateSalesPlanTerritoryFields(Map<Id, Id> salesPlanIdToTerritoryId) {
		Map<Id, Sales_Plan__c> salesPlanMap = new Map<Id, Sales_Plan__c>(
			[
				SELECT Id, Geo__c, Region_Territory__c, Sub_Region__c, Territory_Name__c
				FROM Sales_Plan__c
				WHERE Id IN :salesPlanIdToTerritoryId.keySet()
			]
		);
		Map<Id, Territory2> territoryMap = new Map<Id, Territory2>(
			[
				SELECT Id, Name, Geo__c, Region__c, Sub_Region__c
				FROM Territory2
				WHERE Id IN :salesPlanIdToTerritoryId.values()
			]
		);

		Territory2 territory;
		for (Sales_Plan__c salesPlan : salesPlanMap.values()) {
			territory = territoryMap?.get(salesPlanIdToTerritoryId?.get(salesPlan.Id));
			if (territory != null) {
				salesPlan.Territory_Name__c = territory.Name;
				salesPlan.Geo__c = territory.Geo__c;
				salesPlan.Region_Territory__c = territory.Region__c;
				salesPlan.Sub_Region__c = territory.Sub_Region__c;
			}
		}

		List<Database.SaveResult> saveResults = Database.update(salesPlanMap.values(), false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'UserTerritoryAssocTriggerUtility.populateSalesPlanTerritoryFields ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}
    */
}