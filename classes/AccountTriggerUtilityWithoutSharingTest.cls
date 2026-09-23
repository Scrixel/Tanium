/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test methods for class AccountTriggerUtilityWithoutSharing
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12514   2026-02-28    Created the test class
 * SS-13234   2026-06-04    Add test method to cover setContactLeadSDROwner method
 * SS-12811   2026-06-17    Deleted setOpportunityManager and added setOpportunityOwnerFromAccount test
 */
@IsTest
private class AccountTriggerUtilityWithoutSharingTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'UserTriggerHandler',
				'LeadTriggerHandler',
				'DealRegistrationTriggerHandler'
			}
		);
		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			User standardUser = TestUserFactory.getStandardUser();
			standardUser.ManagerId = adminUser.Id;
			update standardUser;

			Account account = TestFactory.buildAccount('Test Account');
			account.OwnerId = adminUser.Id;
			account.Active__c = 'Active';
			account.TAM_Sales_SME__c = adminUser.Id;
			account.CSM__c = adminUser.Id;
			account.Named_Account__c = true;
			Account partnerAccount = TestFactory.buildAccount('Test Partner Account');
			partnerAccount.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			partnerAccount.Active__c = 'Active';
			insert new List<Account>{ account, partnerAccount };
			update new List<Account>{ account, partnerAccount };

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today(),
				'Prospecting',
				account.Id
			);
			opp.OwnerId = account.OwnerId;
			insert opp;

			Contact contact = TestFactory.buildContact(account.Id);
			insert contact;

			Lead lead = TestFactory.buildLead('Test', 'Lead', 'TestLead@test.com', 'Test Account');
			lead.Account__c = account.Id;
			insert lead;

			Deal_Registration__c dealReg = TestFactory.buildDealReg(
				'First',
				'Last',
				'firstlast@test.com',
				'Test Account'
			);
			dealReg.Account__c = account.Id;
			insert dealReg;
		}
	}

	@IsTest
	static void testGetSegment_WhenSalesSegmentOverride_ReturnSalesSegmentOverrideValue() {
		String accountSegment = null;
		List<Account> accounts = [
			SELECT Id, Name, Sales_Segment_Override__c
			FROM Account
			WHERE Name = 'Test Account'
		];

		for (Account account : accounts) {
			account.Sales_Segment_Override__c = 'Public Sector';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountSegment = AccountTriggerUtilityWithoutSharing.getSegment(accounts[0]);
			Test.stopTest();
		}

		Assert.areEqual('Public Sector', accountSegment);
	}

	@IsTest
	static void testGetSegment_WhenSalesSegmentOverrideIsNull_ReturnSegmentFromMapping() {
		String accountSegment = null;
		Account account = [
			SELECT
				Id,
				Name,
				Sales_Segment_Override__c,
				Segment__c,
				Geo__c,
				Sales_Ops_Derived_EP__c,
				Region__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];

		account.Geo__c = 'USPS Federal';
		account.Region__c = 'US Federal';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountSegment = AccountTriggerUtilityWithoutSharing.getSegment(account);
			Test.stopTest();
		}

		Assert.areEqual('Public Sector', accountSegment);
	}

	@IsTest
	static void testSetSegment_WhenSalesSegmentOverride_SetSalesSegmentOverrideValueOnAccount() {
		List<Account> accounts = [
			SELECT Id, Name, Sales_Segment_Override__c
			FROM Account
			WHERE Name = 'Test Account'
		];

		for (Account account : accounts) {
			account.Sales_Segment_Override__c = 'Public Sector';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setSegment(accounts);
			Test.stopTest();
		}

		Assert.areEqual('Public Sector', accounts[0].Segment__c);
	}

	@IsTest
	static void testSetSupportModel_WhenFederalAccount_SetSupportModelToSupportCenter() {
		List<Account> accounts = [
			SELECT Id, Name, Sales_Segment_Override__c, Support_Model__c, Segment__c
			FROM Account
			WHERE Name = 'Test Account'
		];

		for (Account account : accounts) {
			account.Geo__c = 'USPS Federal';
			account.Region__c = 'US Federal';
			account.Segment__c = 'Public Sector';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setSupportModel(accounts);
			Test.stopTest();
		}

		Assert.areEqual('Support Center', accounts[0].Support_Model__c);
	}

	@IsTest
	static void testPartnerInfluencePickListProcess_WhenPartnerAccount_InitiatePartnerInfluencePickListProcess() {
		List<Account> accounts = [SELECT Id, Name, RecordTypeId, Active__c FROM Account];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.partnerInfluencePickListProcess(accounts);
			Test.stopTest();
		}
	}

	@IsTest
	static void testPartnerInfluencePickListProcess_WhenDeactivatePartnerAccount_InitiatePartnerInfluencePickListProcess() {
		List<Account> accounts = [SELECT Id, Name, RecordTypeId, Active__c FROM Account];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));

		for (Account account : accounts) {
			account.Active__c = 'Inactive';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.partnerInfluencePickListProcess(accounts, oldMap);
			Test.stopTest();
		}
	}

	@IsTest
	static void testPartnerInfluencePickListProcess_WhenActivatePartnerAccount_InitiatePartnerInfluencePickListProcess() {
		List<Account> accounts = [SELECT Id, Name, RecordTypeId, Active__c FROM Account];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));

		for (Account account : oldMap.values()) {
			account.Active__c = 'Inactive';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.partnerInfluencePickListProcess(accounts, oldMap);
			Test.stopTest();
		}
	}

	@IsTest
	static void testSetOpportunityCsmAccountOwner_WhenCsmChanged_UpdateOpportunityCsmAccountOwner() {
		List<Account> accounts = [SELECT Id, Name, CSM__c FROM Account WHERE Name = 'Test Account'];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));

		for (Account account : oldMap.values()) {
			account.CSM__c = UserInfo.getUserId();
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setOpportunityCsmAccountOwner(accounts, oldMap);
			Test.stopTest();
		}
		List<Opportunity> opps = [
			SELECT Id, CSM_Account_Owner__c
			FROM Opportunity
			WHERE AccountId = :accounts[0].Id
		];
		Assert.areEqual(accounts[0].CSM__c, opps[0].CSM_Account_Owner__c);
	}

	@IsTest
	static void testSetOpportunityTSEOwner_WhenAccountTSEOwnerChanged_UpdateOpportunityTSEOwner() {
		List<Account> accounts = [
			SELECT Id, Name, TAM_Sales_SME__c
			FROM Account
			WHERE Name = 'Test Account'
		];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));

		for (Account account : oldMap.values()) {
			account.TAM_Sales_SME__c = UserInfo.getUserId();
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setOpportunityTSEOwner(accounts, oldMap);
			Test.stopTest();
		}
		List<Opportunity> opps = [
			SELECT Id, TAM_Sales_SME_Owner__c
			FROM Opportunity
			WHERE AccountId = :accounts[0].Id
		];
		Assert.areEqual(accounts[0].TAM_Sales_SME__c, opps[0].TAM_Sales_SME_Owner__c);
	}

	@IsTest
	static void testSetContactOwnerFromAccount_WhenAccountOwnerChanged_SetContactOwnerFromAccount() {
		List<Account> accounts = [SELECT Id, OwnerId, Named_Account__c FROM Account ORDER BY Name];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));

		for (Account account : accounts) {
			account.OwnerId = UserInfo.getUserId();
			account.Named_Account__c = false;
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setContactOwnerFromAccount(accounts, oldMap);
			Test.stopTest();
		}

		Contact contact = [SELECT Id, OwnerId FROM Contact WHERE AccountId = :accounts[0].Id];
		Assert.areEqual(
			accounts[0].OwnerId,
			contact.OwnerId,
			'Contact Owner should be the same with Account Owner'
		);
	}

	@IsTest
	static void testSetDealRegistrationAccountSegment_WhenAccountSegmentChanged_UpdateDealRegistrationAccountSegment() {
		List<Account> accounts = [
			SELECT Id, Name, Segment__c, Named_Account__c
			FROM Account
			WHERE Name = 'Test Account'
		];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));

		for (Account account : accounts) {
			account.Segment__c = 'Public Sector';
			account.Named_Account__c = false;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setDealRegistrationAccountSegment(accounts, oldMap);
			Test.stopTest();
		}

		Deal_Registration__c dealRegistration = [
			SELECT Id, Account__c, End_Customer_Account_Segment__c
			FROM Deal_Registration__c
			WHERE Account__c = :accounts[0].Id
		];
		Assert.areEqual('Public Sector', dealRegistration.End_Customer_Account_Segment__c);
	}

	@IsTest
	static void testSetOpportunityOwnerFromAccount_WhenAccountOwnerChanged_UpdateOpportunityOwnerFromAccount() {
		User standardUser = TestUserFactory.getStandardUser();
		List<Account> accounts = [SELECT Id, OwnerId FROM Account WHERE Name = 'Test Account'];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));
		accounts[0].OwnerId = standardUser.Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setOpportunityOwnerFromAccount(accounts, oldMap);
			Test.stopTest();
		}
	}

	static void testSetContactLeadSDROwner_WhenAccountSDRChanged_UpdateContactLeadSDR() {
		List<Account> accounts = [
			SELECT Id, Name, BDR__c, SDR_Manager__c
			FROM Account
			WHERE Name = 'Test Account'
		];
		Map<Id, Account> oldMap = new Map<Id, Account>(accounts.deepClone(true, true, true));

		for (Account account : accounts) {
			account.BDR__c = UserInfo.getUserId();
			account.SDR_Manager__c = UserInfo.getUserId();
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountTriggerUtilityWithoutSharing.setContactLeadSDROwner(accounts, oldMap);
			Test.stopTest();
		}

		List<AsyncApexJob> jobs = [
			SELECT ApexClass.Name, Status, JobType
			FROM AsyncApexJob
			WHERE JobType = 'BatchApex'
		];

		Set<String> classNames = new Set<String>();
		for (AsyncApexJob j : jobs) {
			classNames.add(j.ApexClass.Name);
		}

		System.assertEquals(2, jobs.size(), 'Expected two batch jobs');
		System.assert(classNames.contains('ContactSDRBatch'), 'ContactSDRBatch should run');
		System.assert(classNames.contains('LeadSDRBatch'), 'LeadSDRBatch should run');
	}
}