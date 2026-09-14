/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for User Territory Association Trigger Handler Utility
 * @Date: 2025-09-30
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-11284     2025-09-30       Initial development
 * SS-13234     2026-06-04       Moved assert statements from utility to batch test class
 * SS-12811     2026-07-10       Added test methods for populateAccountOwner
 * SS-13545     2026-07-27       Added test methods for populateSalesPlanTerritoryFields
 */
@IsTest
private class UserTerritoryAssocTriggerUtilityTest {
	static final Id ACCOUNT_PROSPECT_RECORDTYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Account',
		'Prospect'
	);

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
		System.runAs(TestUserFactory.getAdminUser()) {
			Territory2Model territoryModel = new Territory2Model(
				Name = 'Test Territory Model',
				DeveloperName = 'Test_Territory_Model'
			);
			insert territoryModel;

			Territory2Type salesTerritoryType = [
				SELECT Id
				FROM Territory2Type
				WHERE MasterLabel = 'Sales'
				LIMIT 1
			];

			Territory2 territory = new Territory2(
				Name = 'L1 Test Sales Territory',
				Territory2TypeId = salesTerritoryType.Id,
				Territory2ModelId = territoryModel.Id,
				DeveloperName = 'L1_Test_Sales_Territory'
			);
			insert territory;

			UserTerritory2Association userTerrAssocSDR = new UserTerritory2Association(
				UserId = UserInfo.getUserId(),
				Territory2Id = territory.Id,
				RoleInTerritory2 = 'SDR'
			);
			insert userTerrAssocSDR;
			update userTerrAssocSDR;

			User standardUser = TestUserFactory.getStandardUser();

			UserTerritory2Association userTerrAssocSales = new UserTerritory2Association(
				UserId = standardUser.Id,
				Territory2Id = territory.Id,
				RoleInTerritory2 = 'Sales'
			);
			insert userTerrAssocSales;
			update userTerrAssocSales;

			Account prospectAcc = TestFactory.buildAccount('Prospect Account');
			prospectAcc.Sales_Model__c = 'Indirect';
			prospectAcc.RecordTypeId = ACCOUNT_PROSPECT_RECORDTYPE_ID;
			prospectAcc.Type = 'Prospect';
			prospectAcc.Primary_Sales_Territory_Id__c = territory.Id;
			prospectAcc.Primary_Sales_Territory_Name__c = territory.Name;
			prospectAcc.OwnerId = standardUser.Id;
			insert prospectAcc;

			Sales_Plan__c salesPlan = new Sales_Plan__c();
			salesPlan.Sales_User__c = standardUser.Id;
			salesPlan.Sales_Ops_Owner__c = UserInfo.getUserId();
			insert salesPlan;
		}
	}

	@IsTest
	static void testPopulateAccountSDR_whenSDRUserTerrAssocInsert_PopulateAccSDRSuccessfully() {
		List<UserTerritory2Association> userTerrAssociations = [
			SELECT Id, UserId, Territory2Id, RoleInTerritory2, IsActive
			FROM UserTerritory2Association
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			UserTerritoryAssocTriggerUtility.populateAccountSDR(userTerrAssociations, null);
			Test.stopTest();
		}
	}

	@IsTest
	static void testRemoveAccountSDR_whenSDRUserTerrAssocDelete_PopulateAccSDRSuccessfully() {
		List<UserTerritory2Association> userTerrAssociations = [
			SELECT Id, UserId, Territory2Id, RoleInTerritory2, IsActive
			FROM UserTerritory2Association
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			UserTerritoryAssocTriggerUtility.removeAccountSDR(userTerrAssociations);
			Test.stopTest();
		}
	}

	@IsTest
	static void testPopulateAccountOwner_whenSalesUserTerrAssocInsert_PopulateAccOwnerSuccessfully() {
		List<UserTerritory2Association> userTerrAssociations = [
			SELECT Id, UserId, Territory2Id, RoleInTerritory2, IsActive
			FROM UserTerritory2Association
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			UserTerritoryAssocTriggerUtility.populateAccountOwner(userTerrAssociations, null);
			Test.stopTest();
		}
	}

	/*
	@IsTest
	static void testPopulateSalesPlanTerritoryFields_whenSalesUserTerrAssocInsert_PopulateSalesPlanFields() {
		Territory2 territory = [
			SELECT Id, Name, Geo__c, Region__c, Sub_Region__c
			FROM Territory2
			WHERE DeveloperName = 'L1_Test_Sales_Territory'
		];
		List<UserTerritory2Association> userTerrAssociations = [
			SELECT Id, UserId, Territory2Id, RoleInTerritory2, IsActive
			FROM UserTerritory2Association
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			UserTerritoryAssocTriggerUtility.populateSalesPlanTerritoryFields(
				userTerrAssociations,
				null
			);
			Test.stopTest();
		}

		Sales_Plan__c salesPlan = [
			SELECT Id, Territory_Name__c, Geo__c, Region_Territory__c, Sub_Region__c
			FROM Sales_Plan__c
		];
		Assert.isNotNull(salesPlan);
		Assert.areEqual(
			territory.Name,
			salesPlan.Territory_Name__c,
			'Territory Name does not match on Sales Plan'
		);
		Assert.areEqual(territory.Geo__c, salesPlan.Geo__c, 'Geo does not match on Sales Plan');
		Assert.areEqual(
			territory.Region__c,
			salesPlan.Region_Territory__c,
			'Region does not match on Sales Plan'
		);
		Assert.areEqual(
			territory.Sub_Region__c,
			salesPlan.Sub_Region__c,
			'Sub Region does not match on Sales Plan'
		);
	}*/
}