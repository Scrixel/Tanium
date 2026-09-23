/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Test methods for AccountTriggerUtility
 * @Date: 2015-01-18
 * @Author: Cumulus Vision, Tanium Dev team
 * @Request: TAN-147
 * RequestId  ModifiedDate  Description
 * SS-7583    2024-03-21    Nebula Logger
 * SS-7764    2024-05-23    Class cleanup
 * SS-8481    2024-06-22    PublishAccounts test methods update
 * SS-7935    2024-06-26    Change publishAccount trigger to Purchasing Model and Partner Status
 * SS-10897   2025-06-03    Updated test class
 * SS-12027   2025-12-02    Added test method for populateAccountSDR
 * SS-12200   2025-12-03    Added test method for assignTerritoryInformation
 * SS-13234   2026-06-04    Fix test class failures
 * SS-12811   2026-06-17    Added test method for setOwnerFromSalesTerritory
 */
@IsTest
private class AccountTriggerUtilityTest {
	private static User adminUser;

	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'UserTriggerHandler'
			}
		);
		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			User standardUser = TestUserFactory.getStandardUser();
			standardUser.ManagerId = adminUser.Id;
			update standardUser;

			List<Territory2> testSalesTerritories = [
				SELECT Id, Name
				FROM Territory2
				WHERE Territory2Model.State = 'Active' AND Territory2Type.MasterLabel = 'Sales'
				ORDER BY Id
				LIMIT 2
			];
			Set<Id> territoryIds = new Map<Id, Territory2>(testSalesTerritories).keySet();
			delete [SELECT Id FROM UserTerritory2Association WHERE Territory2Id IN :territoryIds];

			testSalesTerritories[0].Name = 'L1 Test Sales Territory';
			testSalesTerritories[0].DeveloperName = 'L1_Test_Sales_Territory';
			testSalesTerritories[1].Name = 'L2 Test Sales Territory2';
			testSalesTerritories[1].DeveloperName = 'L2_Test_Sales_Territory';
			update testSalesTerritories;

			UserTerritory2Association userTerritoryAssociation1 = new UserTerritory2Association();
			userTerritoryAssociation1.UserId = adminUser.Id;
			userTerritoryAssociation1.Territory2Id = testSalesTerritories[0].Id;
			userTerritoryAssociation1.RoleInTerritory2 = 'SDR';
			UserTerritory2Association userTerritoryAssociation2 = new UserTerritory2Association();
			userTerritoryAssociation2.UserId = standardUser.Id;
			userTerritoryAssociation2.Territory2Id = testSalesTerritories[0].Id;
			userTerritoryAssociation2.RoleInTerritory2 = 'Sales';
			UserTerritory2Association userTerritoryAssociation3 = new UserTerritory2Association();
			userTerritoryAssociation3.UserId = adminUser.Id;
			userTerritoryAssociation3.Territory2Id = testSalesTerritories[1].Id;
			userTerritoryAssociation3.RoleInTerritory2 = 'Sales';
			UserTerritory2Association userTerritoryAssociation4 = new UserTerritory2Association();
			userTerritoryAssociation4.UserId = standardUser.Id;
			userTerritoryAssociation4.Territory2Id = testSalesTerritories[1].Id;
			userTerritoryAssociation4.RoleInTerritory2 = 'SDR';
			insert new List<UserTerritory2Association>{
				userTerritoryAssociation1,
				userTerritoryAssociation2,
				userTerritoryAssociation3,
				userTerritoryAssociation4
			};

			List<Account> accounts = new List<Account>();
			Account account;
			for (Integer i = 0; i < 3; i++) {
				account = TestFactory.buildAccount('Test Account' + i);
				account.Name = (i == 0) ? 'Test Account' : account.Name;
				account.OwnerId = adminUser.Id;
				account.Global_Account__c = (i == 0) ? true : false;
				account.Area_VP__c = adminUser.Id;
				accounts.add(account);
			}
			accounts[2].Type = 'Prospect';
			insert accounts;
			update accounts;

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				Utility.TECH_WIN_NEGOTIATIONS,
				accounts[0].Id
			);
			insert opportunity;

			Contact contact = TestFactory.buildContact(accounts[0].Id);
			insert contact;

			List<Account_Support_Request__c> requests = new List<Account_Support_Request__c>();
			Account_Support_Request__c request;
			for (Integer i = 0; i < 2; i++) {
				request = new Account_Support_Request__c();
				request.Account__c = accounts[0].Id;
				request.OwnerId = (i == 0) ? standardUser.Id : adminUser.Id;
				request.AVP__c = (i == 0) ? standardUser.Id : adminUser.Id;
				request.RVP__c = (i == 0) ? standardUser.Id : adminUser.Id;
				request.Status__c = 'Draft';
				requests.add(request);
			}
			insert requests;
		}
	}

	@IsTest
	static void testSyncInternalSupportRequests_WhenAccountsUpdated_SyncInternalSupportRequests() {
		User standardUser = TestUserFactory.getStandardUser();
		List<Account> accounts = [SELECT Id, OwnerId, Area_VP__c, RVP__c, Region__c FROM Account];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));
		Boolean async = true;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtility.syncInternalSupportRequests(accounts, oldMap);
			for (Account account : oldMap.values()) {
				account.OwnerId = standardUser.Id;
				account.Area_VP__c = standardUser.Id;
			}
			AccountTriggerUtility.syncInternalSupportRequests(accounts, oldMap);
			AccountTriggerUtility.syncInternalSupportRequests(accounts, async);
			Test.stopTest();

			List<Account_Support_Request__c> requests = [
				SELECT Id, AVP__c
				FROM Account_Support_Request__c
			];
			Assert.isTrue(requests[0].AVP__c != standardUser.Id);
		}
	}

	@IsTest
	static void testPublishAccounts_WhenEventPublishSuccessful_NoLogsCreated() {
		Id partnerAccountRecTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
		Map<Id, Account> oldMap;
		List<Account> accounts = [
			SELECT
				Id,
				OwnerId,
				Credit_Limit__c,
				Industry,
				MCN__c,
				Name,
				NS_Subsidiary_ID__c,
				Partner_Agreement__c,
				Payment_Terms__c,
				RecordTypeId,
				Sector__c,
				Segment__c,
				Tax_Reg_Number__c,
				Primary_Bill_to_email__c,
				Invoice_Inquiry_Email__c,
				Sales_Model__c,
				Partner_Maturity__c
			FROM Account
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			accounts[1].RecordTypeId = partnerAccountRecTypeId;
			accounts[1].Sales_Model__c = 'Direct';
			accounts[1].Partner_Maturity__c = 'Active';
			oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));
			for (Account account : oldMap.values()) {
				account.Segment__c = 'Enterprise';
			}
			List<Opportunity> opps = [SELECT Id, AccountId, Probability FROM Opportunity];
			Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));
			for (Opportunity opp : oppsMap.values()) {
				opp.StageName = Utility.PROSPECTING;
			}

			Test.startTest();
			AccountTriggerUtility.publishAccounts(accounts, oldMap);
			AccountTriggerUtility.publishAccounts(accounts);
			AccountTriggerUtility.isAccountToPublish(
				accounts[0],
				oldMap.get(accounts[0].Id),
				partnerAccountRecTypeId
			);
			AccountTriggerUtility.publishAccounts(opps, oppsMap);
			Test.stopTest();
		}

		List<LogEntry__c> logEntries = [SELECT Id, Message__c FROM LogEntry__c];
		Assert.isTrue(logEntries.isEmpty(), 'Successful event publish will not create log record.');
	}

	@IsTest
	static void testPublishAccounts_WhenEventPublishFailed_CreateLogs() {
		Id partnerAccountRecTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
		Map<Id, Account> oldMap;
		List<Account> accounts = [
			SELECT
				Id,
				OwnerId,
				Credit_Limit__c,
				Industry,
				MCN__c,
				Name,
				NS_Subsidiary_ID__c,
				Partner_Agreement__c,
				Payment_Terms__c,
				RecordTypeId,
				Sector__c,
				Segment__c,
				Tax_Reg_Number__c,
				Primary_Bill_to_email__c,
				Invoice_Inquiry_Email__c,
				Sales_Model__c,
				Partner_Maturity__c
			FROM Account
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			accounts[1].RecordTypeId = partnerAccountRecTypeId;
			accounts[1].Sales_Model__c = 'Direct';
			accounts[1].Partner_Maturity__c = 'Active';
			accounts[1]
				.Industry = 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ';
			oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));
			for (Account account : oldMap.values()) {
				account.Invoice_Inquiry_Email__c = 'test@test.com';
			}

			Test.startTest();
			AccountTriggerUtility.publishAccounts(accounts, oldMap);
			Test.stopTest();
		}

		List<LogEntry__c> logEntries = [SELECT Id, Message__c FROM LogEntry__c];
		Assert.isFalse(logEntries.isEmpty(), 'Failed event publish will create log record.');
		Assert.isTrue(
			logEntries[0].Message__c.contains('AccountTriggerUtility.publishAccounts() ERRORS')
		);
	}

	@IsTest
	static void testInsertTerritoryAssociation_WhenAccountWithSalesTerritory_InsertTerritoryAssociation() {
		Map<Id, Account> accountMap = new Map<Id, Account>(
			[
				SELECT Id, OwnerId, Area_VP__c, RVP__c, Primary_Sales_Territory_Id__c
				FROM Account
				WHERE Primary_Sales_Territory_Id__c != NULL
			]
		);

		Territory2 testSalesTerritoryL1 = [
			SELECT Id, Name
			FROM Territory2
			WHERE Name = 'L1 Test Sales Territory'
		];
		for (Account account : accountMap.values()) {
			account.Primary_Sales_Territory_Id__c = testSalesTerritoryL1.Id;
			account.Primary_Sales_Territory_Name__c = testSalesTerritoryL1.Name;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtility.insertTerritoryAssociation(accountMap.values());
			Test.stopTest();
		}
		List<ObjectTerritory2Association> accountTerritoryAssociations = [
			SELECT Id
			FROM ObjectTerritory2Association
			WHERE ObjectId IN :accountMap.keyset()
		];
		Assert.isTrue(accountTerritoryAssociations != null);
	}

	@IsTest
	static void testSetSDR_WhenAccountWithSalesTerritoryUpdated_SetSDR() {
		UserTerritory2Association userTerritoryAssociation = [
			SELECT Id, UserId, Territory2Id, RoleInTerritory2, IsActive
			FROM UserTerritory2Association
			WHERE RoleInTerritory2 = 'SDR'
			LIMIT 1
		];

		Map<Id, Account> accountMap = new Map<Id, Account>(
			[
				SELECT Id, Primary_Sales_Territory_Id__c, BDR__c, Type, OwnerId
				FROM Account
				WHERE Type = 'Prospect'
			]
		);
		Map<Id, Account> oldMap = new Map<Id, Account>(accountMap.deepClone());
		accountMap.values()[0].Primary_Sales_Territory_Id__c = userTerritoryAssociation.Territory2Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtility.setSDR(accountMap.values(), oldMap);
			Test.stopTest();
		}

		Assert.areEqual(
			userTerritoryAssociation.UserId,
			accountMap.values()[0].BDR__c,
			'Account SDR should be updated to SDR on new territory'
		);
	}

	@IsTest
	static void testAssignTerritoryInformation_WhenNoActiveTerritoryModel_DoNotAssignTerritoryInformation() {
		List<Account> accounts = [SELECT Id, OwnerId FROM Account];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtility.assignTerritoryInformation(accounts);
			Test.stopTest();
		}

		Assert.isTrue(accounts[0].Primary_Sales_Territory_Id__c != null);
	}

	@IsTest
	static void testSetOwnerFromSalesTerritory_WhenTerritoryChanged_SetOwnerFromSalesTerritory() {
		User standardUser = TestUserFactory.getStandardUser();
		Territory2 testSalesTerritoryL1 = [
			SELECT Id, Name
			FROM Territory2
			WHERE DeveloperName = 'L1_Test_Sales_Territory'
		];
		UserTerritory2Association userTerritoryAssociation = [
			SELECT Id, UserId, Territory2Id
			FROM UserTerritory2Association
			WHERE
				RoleInTerritory2 = 'Sales'
				AND Territory2Id = :testSalesTerritoryL1.Id
				AND UserId = :standardUser.Id
			LIMIT 1
		];

		List<Account> accounts = [
			SELECT Id, OwnerId, Primary_Sales_Territory_Id__c, Primary_Sales_Territory_Name__c
			FROM Account
			LIMIT 1
		];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));
		oldMap.get(accounts[0].Id).Primary_Sales_Territory_Id__c = null;
		oldMap.get(accounts[0].Id).Primary_Sales_Territory_Name__c = null;
		accounts[0].Primary_Sales_Territory_Id__c = testSalesTerritoryL1.Id;
		accounts[0].Primary_Sales_Territory_Name__c = testSalesTerritoryL1.Name;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtility.setOwnerFromSalesTerritory(accounts, oldMap);
			Test.stopTest();
		}

		Assert.areEqual(
			userTerritoryAssociation.UserId,
			accounts[0].OwnerId,
			'Account owner should be updated to user associated to new territory'
		);
	}
}