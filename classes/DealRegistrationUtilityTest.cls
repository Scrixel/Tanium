/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for the DealRegistrationUtility class
 * @Date: 2024-09-13
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate   Description
 * SS-8999    2024-09-12     Initial development - Opp Reg to Deal Reg Migration
 * SS-9432    2025-02-22     New test methods for deal approval and duplicates
 * SS-11723   2025-09-23     Populate PFS fields on Deal Registration from related Account
 * SS-12040   2025-11-17     Updated test method assignEndCutestAssignEndCustomerAccount_WhenNoAccountWithSameDomainAndHqCountry_DoNotAssignDealRegWithAccountstomerAccount
 * SS-13176   2026-05-27     Removed Level_1__c references
 */
@IsTest
private class DealRegistrationUtilityTest {
	static final Id ACCOUNT_PARTNER_RECORDTYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Account',
		'Partner'
	);
	static final Id ACCOUNT_PROSPECT_RECORDTYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Account',
		'Prospect'
	);
	static User userUS = DealRegistrationUtilityTest.getUserUS();
	static User userMexico = DealRegistrationUtilityTest.getUserMexico();
	static User adminUser;

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityPartnerTriggerHandler',
				'UserTriggerHandler',
				'ContactTriggerHandler',
				'DealRegistrationTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Territory2Model territoryModel = new Territory2Model(
				Name = 'Test Territory Model',
				DeveloperName = 'Test_Territory_Model'
			);
			insert territoryModel;

			Territory2Type pfsTerritoryType = [
				SELECT Id
				FROM Territory2Type
				WHERE MasterLabel = 'PFS'
				LIMIT 1
			];

			Territory2 testPFSTerritoryL1 = new Territory2(
				Name = 'L1 Test PFS Territory',
				Territory2TypeId = pfsTerritoryType.Id,
				Territory2ModelId = territoryModel.Id,
				DeveloperName = 'L1_Test_PFS_Territory'
			);
			insert testPFSTerritoryL1;

			UserTerritory2Association userTerrAssoc = new UserTerritory2Association();
			userTerrAssoc.UserId = UserInfo.getUserId();
			userTerrAssoc.Territory2Id = testPFSTerritoryL1.Id;
			userTerrAssoc.RoleInTerritory2 = 'PFS';
			insert userTerrAssoc;

			Account baseAcc = TestFactory.buildAccount('Base Account');

			Account partnerAcc = TestFactory.buildAccount('Partner Account');
			partnerAcc.RecordTypeId = ACCOUNT_PARTNER_RECORDTYPE_ID;
			partnerAcc.Partner_Maturity__c = 'Active';
			partnerAcc.Sales_Model__c = 'Indirect';
			partnerAcc.Business_Motion__c = 'Distribute';

			Account distributorAcc = TestFactory.buildAccount('Distributor Account');
			distributorAcc.RecordTypeId = ACCOUNT_PARTNER_RECORDTYPE_ID;
			distributorAcc.Partner_Maturity__c = 'Active';
			distributorAcc.Sales_Model__c = 'Indirect';
			distributorAcc.Business_Motion__c = 'Distribute';

			Account partnerAccUS = TestFactory.buildAccount('US Partner Account');
			partnerAccUS.RecordTypeId = ACCOUNT_PARTNER_RECORDTYPE_ID;
			partnerAccUS.HQ_Country__c = 'United States';
			partnerAccUS.OwnerId = DealRegistrationUtilityTest.userUS.Id;

			Account partnerAccCanada = TestFactory.buildAccount('Canada Partner Account');
			partnerAccCanada.RecordTypeId = ACCOUNT_PARTNER_RECORDTYPE_ID;
			partnerAccCanada.HQ_Country__c = 'Canada';
			partnerAccCanada.OwnerId = DealRegistrationUtilityTest.userUS.Id;

			Account prospectAcc = TestFactory.buildAccount('Prospect Account');
			prospectAcc.Sales_Model__c = 'Indirect';
			prospectAcc.HQ_Country__c = '';
			prospectAcc.RecordTypeId = ACCOUNT_PROSPECT_RECORDTYPE_ID;

			Account pfsAcc = TestFactory.buildAccount('PFS Account');
			pfsAcc.Primary_PFS_Territory_Id__c = testPFSTerritoryL1.Id.toString();
			pfsAcc.Primary_PFS_Territory_Name__c = testPFSTerritoryL1.Name;
			pfsAcc.RecordTypeId = ACCOUNT_PARTNER_RECORDTYPE_ID;
			pfsAcc.Partner_Maturity__c = 'Active';
			pfsAcc.Sales_Model__c = 'Indirect';
			pfsAcc.Business_Motion__c = 'Distribute';

			insert new List<Account>{
				partnerAcc,
				partnerAccUS,
				partnerAccCanada,
				prospectAcc,
				distributorAcc,
				baseAcc,
				pfsAcc
			};

			Opportunity opp = TestFactory.buildOpportunity(
				'Opportunity',
				System.today(),
				'Prospecting',
				null
			);
			insert opp;

			Deal_Registration__c deal = TestFactory.buildDealReg(
				'First',
				'Last',
				'firstlast@test.com',
				'Test Company'
			);
			deal.wi_Associated_Partner__c = partnerAcc.Id;
			deal.Distributor__c = partnerAcc.Id;
			deal.Account__c = prospectAcc.Id;
			deal.Mapped_Opportunity__c = null;
			deal.or_New_Opp_Reg__c = true;
			deal.or_Create_Opportunity_upon_Approval__c = true;
			deal.or_Opportunity_Registration__c = 'Partner Sourced';
			deal.or_Opp_Reg_Status__c = 'Pending';

			Deal_Registration__c dealWithoutAccount = TestFactory.buildDealReg(
				'First',
				'Last',
				'first.last@testaccount.io',
				'Test Account'
			);
			deal.wi_Associated_Partner__c = partnerAcc.Id;
			deal.Distributor__c = partnerAcc.Id;
			deal.Mapped_Opportunity__c = null;
			deal.or_New_Opp_Reg__c = true;
			deal.or_Create_Opportunity_upon_Approval__c = true;
			deal.or_Opportunity_Registration__c = 'Partner Sourced';
			deal.or_Opp_Reg_Status__c = 'Pending';

			Contact contact = TestFactory.buildContact(prospectAcc.Id);

			Opportunity_Partners__c oppPartner = TestFactory.buildOpportunityPartner(
				opp.Id,
				partnerAcc.Id,
				10
			);

			Sales_Heirarchy__c salesHierarchy = new Sales_Heirarchy__c(
				Role__c = 'Corporate'
			);

			User manager = TestUserFactory.createBasicUser(
				'User_Manager',
				Utility.getAdminUserProfileId()
			);

			Automation_Management__c am = new Automation_Management__c();
			am.Default_Opp_Reg_Owner_LATAM__c = TestUserFactory.createDealDeskUser().Id;
			insert new List<SObject>{
				deal,
				dealWithoutAccount,
				contact,
				oppPartner,
				salesHierarchy,
				manager,
				am
			};
		}
	}

	@IsTest
	static void handleApprovedOppRegTest_VP() {
		TriggerHandler.resetRecursionLimits();
		SBQQ.TriggerControl.disable();

		Deal_Registration__c deal = [SELECT Id FROM Deal_Registration__c LIMIT 1];
		User manager = [SELECT Id FROM User WHERE LastName = 'User_Manager'];
		Account partnerAcc = [
			SELECT Id, Name, Sales_Model__c
			FROM Account
			WHERE Name = 'Partner Account'
			LIMIT 1
		];
		User adminUser = TestUserFactory.getAdminUser();
		adminUser.ManagerId = manager.Id;
		adminUser.Role_Category__c = 'VP';
		adminUser.Tanium_Employee_ID__c = '999';
		adminUser.VP__c = manager.Id;
		adminUser.RVP_Override__c = manager.Id;
		adminUser.Area_VP__c = manager.Id;
		update adminUser;

		System.runAs(adminUser) {
			partnerAcc.Business_Motion__c = '';
			update partnerAcc;

			Test.startTest();
			deal.wi_Associated_Partner__c = partnerAcc.Id;
			deal.Account__c = partnerAcc.Id;
			deal.or_Create_Opportunity_upon_Approval__c = true;
			deal.or_Date_Approved__c = Date.today();
			deal.or_Opp_Reg_Status__c = 'Approved';
			update deal;
			Test.stopTest();
		}

		deal = [SELECT Id, Opp_Reg_Owner_is_AVP_RVP__c FROM Deal_Registration__c WHERE Id = :deal.Id];
		Assert.isTrue(deal.Opp_Reg_Owner_is_AVP_RVP__c);

		List<Opportunity> opp = [SELECT Id FROM Opportunity WHERE Deal_Reg_ID__c = :deal.Id];
		Assert.isTrue(
			opp.size() == 1,
			'New opportunity should be created when or_Create_Opportunity_upon_Approval__c is true'
		);
	}

	@IsTest
	static void handleApprovedOppRegTest_NonVP() {
		TriggerHandler.resetRecursionLimits();
		SBQQ.TriggerControl.disable();

		Deal_Registration__c deal = [SELECT Id FROM Deal_Registration__c LIMIT 1];
		User manager = [SELECT Id FROM User WHERE LastName = 'User_Manager'];
		manager.FirstName = 'Manager';
		manager.LastName = 'Manager';
		User adminUser = TestUserFactory.getAdminUser();
		adminUser.ManagerId = manager.Id;
		adminUser.Tanium_Employee_ID__c = '999';
		adminUser.VP__c = manager.Id;
		adminUser.RVP_Override__c = manager.Id;
		adminUser.Area_VP__c = manager.Id;
		update new List<User>{ manager, adminUser };

		System.runAs(adminUser) {
			Account acc = [SELECT Id FROM Account WHERE Name = 'Base Account'];
			Account partnerAccount = TestFactory.buildAccount('Partner Account 2');
			partnerAccount.recordTypeId = ACCOUNT_PARTNER_RECORDTYPE_ID;
			partnerAccount.Partner_Maturity__c = 'Active';
			partnerAccount.Sales_Model__c = 'Indirect';
			insert partnerAccount;

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Opportunity',
				System.today(),
				'Prospecting',
				acc.Id
			);
			insert opportunity;

			Opportunity_Partners__c oppPartner = TestFactory.buildOpportunityPartner(
				opportunity.Id,
				partnerAccount.Id,
				10
			);
			insert oppPartner;

			Test.startTest();
			deal = TestFactory.buildDealReg('Ricky1', 'Ponting', 'test@test.com', 'LeadTest-101');
			deal.wi_Associated_Partner__c = partnerAccount.Id;
			deal.or_Create_Opportunity_upon_Approval__c = true;
			deal.or_Date_Approved__c = Date.today();
			deal.or_Opp_Reg_Status__c = 'Approved';
			insert deal;
			Test.stopTest();
		}

		deal = [SELECT Id, Opp_Reg_Owner_is_AVP_RVP__c FROM Deal_Registration__c WHERE Id = :deal.Id];
		Assert.isFalse(deal.Opp_Reg_Owner_is_AVP_RVP__c);
	}

	@IsTest
	static void handleApprovedDealTestNoCreateOpp() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Deal_Registration__c deal = [SELECT Id FROM Deal_Registration__c LIMIT 1];
			Account acc = [SELECT Id FROM Account WHERE Name = 'Base Account'];

			Account partnerAccount = [SELECT Id FROM Account WHERE Name = 'Distributor Account'];
			partnerAccount.Partner_Maturity__c = 'Active';
			partnerAccount.Sales_Model__c = 'Indirect';
			partnerAccount.Business_Motion__c = 'Distribute';
			update partnerAccount;

			Opportunity opp = TestFactory.buildOpportunity(
				'Opportunity',
				System.today(),
				Utility.PROSPECTING,
				acc.Id
			);
			insert opp;

			deal.Mapped_Opportunity__c = opp.Id;
			deal.or_Create_Opportunity_upon_Approval__c = false;
			deal.Account__c = partnerAccount.Id;
			update deal;

			//Lead After Insert also updates Lead
			TriggerHandler.resetRecursionLimits();

			Test.startTest();

			deal.or_Opp_Reg_Status__c = 'Approved';
			deal.or_Date_Approved__c = System.today();
			deal.or_Expiry_Date_New_Opp_Reg__c = System.today() + 180;
			deal.or_Opp_Reg_Approval_Flow_Status__c = 'Approvals complete';
			deal.or_New_Opp_Reg__c = false;
			deal.or_Expiry_Date_Extension_Opp_Reg__c = System.today() + 180;
			update deal;

			Test.stopTest();

			Opportunity oppty = [SELECT Id, Deal_Reg_ID__c FROM Opportunity WHERE Id = :opp.Id];
			List<Opportunity_Partners__c> oppPartnerResult = [SELECT Id FROM Opportunity_Partners__c];
			deal = [SELECT Id FROM Deal_Registration__c WHERE Id = :deal.Id];

			Assert.areEqual(
				deal.Id,
				oppty.Deal_Reg_ID__c,
				'Opportunity\'s Approved Deal Reg ID should be the deal Id'
			);
			Assert.isTrue(oppPartnerResult.size() > 0);
		}
	}

	@IsTest
	static void testUpdateOppRegApprovalAssignment_whenLeadCreatedAndEndUserAccountHasHQCountry_LeadDistributorSelectedAccurately() {
		Account partnerAccountUS = [
			SELECT ID, OwnerId
			FROM Account
			WHERE HQ_Country__c = 'United States'
			LIMIT 1
		];
		Account partnerAccountCanada = [
			SELECT ID, OwnerID
			FROM Account
			WHERE HQ_Country__c = 'Canada'
			LIMIT 1
		];

		Test.startTest();
		for (Opp_Registration_Approval_Assignment__mdt metadataUS : [
			SELECT Partner_Account_ID__c
			FROM Opp_Registration_Approval_Assignment__mdt
			WHERE DeveloperName = 'Assignment_01a'
		]) {
			for (Account partnerAcctUS : [
				SELECT Id
				FROM Account
				WHERE Id = :metadataUS.Partner_Account_ID__c
			]) {
				Deal_Registration__c testDealUS = TestFactory.buildDealReg(
					'Test',
					'US Deal_Registration__c',
					'testuslead@test.com',
					'Test Company'
				);
				testDealUS.Account__c = partnerAccountUS.Id;
				testDealUS.or_Opp_Reg_Status__c = 'Pending';
				testDealUS.OwnerId = userUS.Id;
				insert testDealUS;

				Deal_Registration__c dealUS = [
					SELECT
						Account__c,
						Distributor__c,
						Opp_Reg_Approval_Assignment__c,
						OwnerId,
						Account__r.OwnerId
					FROM Deal_Registration__c
					WHERE Account__r.HQ_Country__c = 'United States'
					LIMIT 1
				];
				Assert.areEqual(metadataUS.Partner_Account_ID__c, dealUS.Distributor__c);
				Assert.areEqual(
					metadataUS.Approval_Assignment__c,
					dealUS.Opp_Reg_Approval_Assignment__c
				);
			}
		}
		for (Opp_Registration_Approval_Assignment__mdt metadataCanada : [
			SELECT Partner_Account_ID__c
			FROM Opp_Registration_Approval_Assignment__mdt
			WHERE DeveloperName = 'Assignment_01b'
		]) {
			for (Account partnerAcctCanada : [
				SELECT Id
				FROM Account
				WHERE Id = :metadataCanada.Partner_Account_ID__c
			]) {
				Deal_Registration__c testDealCanada = TestFactory.buildDealReg(
					'Test',
					'Canada Deal_Registration__c',
					'testcanadalead@test.com',
					'Test Company'
				);
				testDealCanada.Account__c = partnerAccountCanada.Id;
				testDealCanada.or_Opp_Reg_Status__c = 'Pending';
				testDealCanada.OwnerId = userUS.Id;
				insert testDealCanada;

				Deal_Registration__c dealCanada = [
					SELECT Account__c, Distributor__c, Opp_Reg_Approval_Assignment__c
					FROM Deal_Registration__c
					WHERE Account__r.HQ_Country__c = 'Canada'
					LIMIT 1
				];
				Assert.areEqual(metadataCanada.Partner_Account_ID__c, dealCanada.Distributor__c);
				Assert.areEqual(
					metadataCanada.Approval_Assignment__c,
					dealCanada.Opp_Reg_Approval_Assignment__c
				);
			}
		}
		Test.stopTest();
	}

	@IsTest
	static void testUpdateOppRegApprovalAssignment_whenLeadUpdatedAndEndUserAccountHasHQCountry_LeadDistributorSelectedAccurately() {
		Deal_Registration__c dealUS;
		Account partnerAccountUS = [
			SELECT ID, OwnerId
			FROM Account
			WHERE HQ_Country__c = 'United States'
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Account partnerAccountPeru = TestFactory.buildAccount('Peru Partner Account');
			partnerAccountPeru.recordTypeId = ACCOUNT_PARTNER_RECORDTYPE_ID;
			partnerAccountPeru.HQ_Country__c = 'Peru';
			partnerAccountPeru.OwnerId = DealRegistrationUtilityTest.userMexico.Id;
			insert partnerAccountPeru;

			for (Opp_Registration_Approval_Assignment__mdt metadataUS : [
				SELECT Partner_Account_ID__c
				FROM Opp_Registration_Approval_Assignment__mdt
				WHERE DeveloperName = 'Assignment_01a'
			]) {
				for (Account partnerAcctUS : [
					SELECT Id
					FROM Account
					WHERE Id = :metadataUS.Partner_Account_ID__c
				]) {
					dealUS = TestFactory.buildDealReg(
						'Test',
						'US Deal_Registration__c',
						'testuslead@test.com',
						'Test Company'
					);
					dealUS.Account__c = partnerAccountUS.Id;
					dealUS.or_Opp_Reg_Status__c = 'Pending';
					dealUS.Countries__c = 'United States';
					dealUS.OwnerId = userUS.Id;
					insert dealUS;

					dealUS = [
						SELECT Account__c, Distributor__c, Opp_Reg_Approval_Assignment__c
						FROM Deal_Registration__c
						WHERE Account__r.HQ_Country__c = 'United States'
						LIMIT 1
					];
				}
			}

			// Scenario : Update US lead to point to Peru End User Account
			for (Opp_Registration_Approval_Assignment__mdt metadataPeru : [
				SELECT Partner_Account_ID__c
				FROM Opp_Registration_Approval_Assignment__mdt
				WHERE DeveloperName = 'Assignment_12e'
			]) {
				for (Account partnerAcctPeru : [
					SELECT Id
					FROM Account
					WHERE Id = :metadataPeru.Partner_Account_ID__c
				]) {
					Test.startTest();
					dealUS.Account__c = partnerAccountPeru.Id;
					update dealUS;
					Test.stopTest();
					Deal_Registration__c dealPeru = [
						SELECT Account__c, Distributor__c, Opp_Reg_Approval_Assignment__c
						FROM Deal_Registration__c
						WHERE Account__r.HQ_Country__c = 'Peru'
					];
					Assert.areEqual(metadataPeru.Partner_Account_ID__c, dealPeru.Distributor__c);
					Assert.areEqual(
						metadataPeru.Approval_Assignment__c,
						dealPeru.Opp_Reg_Approval_Assignment__c
					);
				}
			}
		}
	}

	@IsTest
	static void addToOpportunityPartners_WhenOppRegApprovedByRVP_CreatesOppPartners() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'OpportunityTriggerHandler',
				'AccountTriggerHandler',
				'UserTriggerHandler'
			}
		);

		Account partnerAcc = [SELECT Id FROM Account WHERE Name = 'Partner Account'];
		Account prospectAcc = [SELECT Id FROM Account WHERE Name = 'Prospect Account'];
		Deal_Registration__c newDeal = [
			SELECT Id
			FROM Deal_Registration__c
			WHERE Email__c = 'firstlast@test.com'
		];

		User taniumStandardUser = TestUserFactory.createTaniumStandardUser();
		insert taniumStandardUser;
		TestingUtility.assignPermissionSet(taniumStandardUser.Id, 'DisableValidationRules');
		TestingUtility.assignPermissionSet(taniumStandardUser.Id, 'DisableFlows');
		System.runAs(taniumStandardUser) {
			TriggerHandler.resetRecursionLimits();
			Test.startTest();
			newDeal.or_Opp_Reg_Status__c = 'Approved';
			update newDeal;
			Test.stopTest();
		}

		Deal_Registration__c dealResult = [
			SELECT Id, Mapped_Opportunity__c, Mapped_Opportunity__r.Name
			FROM Deal_Registration__c
			WHERE Email__c = 'firstlast@test.com'
		];
		List<Opportunity_Partners__c> oppPartners = [
			SELECT Id, isRecordManuallyCreated__c
			FROM Opportunity_Partners__c
			WHERE Opportunity__c = :dealResult.Mapped_Opportunity__c
		];
		Assert.isTrue(oppPartners.size() > 0);
		for (Opportunity_Partners__c eachOppPartner : oppPartners) {
			Assert.areEqual(
				false,
				eachOppPartner.isRecordManuallyCreated__c,
				'Opportunity Partner created by automation'
			);
		}
	}

	@IsTest
	static void testUpdateDistributor_WhenSegmentPublicSector_BasedOnCustomMetadata() {
		Account partnerAcc = [SELECT Id FROM Account WHERE Name = 'Partner Account' LIMIT 1];
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		Deal_Registration__c deal = [SELECT Id FROM Deal_Registration__c LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			deal.Account__c = partnerAcc.Id;
			deal.Mapped_Opportunity__c = opp.Id;
			deal.Distributor__c = null;
			deal.Select_Your_Distributor__c = 'Carahsoft';
			deal.End_Customer_Account_Segment__c = DealRegistrationUtility.PUBLIC_SECTOR_SEGMENT;
			deal.or_Create_Opportunity_upon_Approval__c = false;
			update deal;
		}

		System.runAs(getDealDeskUser()) {
			OppReg_Distributor_Partner__mdt metadataCarahSoft = [
				SELECT Distributor_Account_Id__c
				FROM OppReg_Distributor_Partner__mdt
				WHERE DeveloperName = 'Carahsoft'
			];

			List<Account> accMetadata = [
				SELECT Id
				FROM Account
				WHERE Id = :metadataCarahSoft.Distributor_Account_Id__c
				LIMIT 1
			];
			if (!accMetadata.isEmpty()) {
				Test.startTest();

				deal.or_Opp_Reg_Status__c = 'Approved';
				update deal;

				Test.stopTest();

				Deal_Registration__c dealAfterUpdate = [
					SELECT Id, Distributor__c
					FROM Deal_Registration__c
					WHERE Id = :deal.Id
				];
				Assert.areEqual(
					metadataCarahSoft.Distributor_Account_Id__c,
					dealAfterUpdate.Distributor__c
				);
			}
		}
	}

	@IsTest
	static void testDistPartners_WhenOppRegApproved_OppPartnerResultsAccountUpdatedAccurately() {
		Account partnerAcc = [SELECT Id FROM Account WHERE Name = 'Partner Account' LIMIT 1];
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		Deal_Registration__c deal = [SELECT Id FROM Deal_Registration__c LIMIT 1];

		Opportunity_Partners__c oppPartner = [
			SELECT Id, Deal_Registration__c, Partner_Role__c
			FROM Opportunity_Partners__c
			WHERE Opportunity__c = :opp.Id
		];
		System.runAs(TestUserFactory.getAdminUser()) {
			oppPartner.Partner_Role__c = DealRegistrationUtility.SUPPLY_CHAIN_PROCUREMENT;
			oppPartner.Deal_Registration__c = deal.Id;
			update oppPartner;
		}

		User salesUser = TestUserFactory.createSalesOpsUser();
		insert salesUser;
		TestingUtility.assignPermissionSet(salesUser.Id, 'DisableFlows');
		TestingUtility.assignPermissionSet(salesUser.Id, 'DisableValidationRules');

		System.runAs(salesUser) {
			Test.startTest();
			deal.or_Create_Opportunity_upon_Approval__c = false;
			deal.or_Opp_Reg_Status__c = 'Approved';
			deal.Distributor__c = partnerAcc.Id;
			deal.Account__c = partnerAcc.Id;
			deal.Mapped_Opportunity__c = opp.Id;
			update deal;

			Test.stopTest();
		}

		Opportunity_Partners__c oppPartnerResult = [
			SELECT Id, Account__c
			FROM Opportunity_Partners__c
			WHERE Deal_Registration__c = :deal.Id
			LIMIT 1
		];
		Assert.areEqual(partnerAcc.Id, oppPartnerResult.Account__c);
	}

	@IsTest
	static void testPartnerCreatorOppRegsExist_WhenOppPartnerRecordExists_DoNotCreateAnotherOppPartnerRecord() {
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		List<Deal_Registration__c> dealRegistrations = [
			SELECT
				Id,
				wi_Associated_Partner__c,
				Mapped_Opportunity__c,
				or_Opportunity_Registration__c,
				or_Opp_Reg_Status__c,
				or_Opp_Reg_Approval_Flow_Status__c
			FROM Deal_Registration__c
		];
		Id oppPartnerId;
		List<Opportunity_Partners__c> oppPartners = [
			SELECT Id, Account__c, Partner_Role__c, Opportunity__c
			FROM Opportunity_Partners__c
		];

		for (Opportunity_Partners__c oppPartner : oppPartners) {
			oppPartner.Partner_Role__c = 'Partner Created';
			oppPartnerId = oppPartner.Id;
		}
		Test.setCreatedDate(oppPartnerId, System.now().addMinutes(-15));

		Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
			dealRegistrations.deepClone(true, true, true)
		);
		for (Deal_Registration__c dealRegistration : dealRegistrations) {
			dealRegistration.or_Opp_Reg_Approval_Flow_Status__c = 'Approvals in progress';
			dealRegistration.Mapped_Opportunity__c = opp.Id;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			update oppPartners;
			Test.startTest();
			DealRegistrationUtility.partnerCreatorDealRegsExist(dealRegistrations, oldMap);
			Test.stopTest();
		}
		List<Opportunity_Partners__c> opportunityPartners = [SELECT Id FROM Opportunity_Partners__c];
		Assert.isTrue(opportunityPartners.size() == 1);
	}

	@IsTest
	static void testUpsertOpportunityPartner_DistributorExists_CreateSupplyChainOppPartner() {
		Account distributorAccount = [
			SELECT Id
			FROM Account
			WHERE Name = 'Distributor Account'
			LIMIT 1
		];
		List<Deal_Registration__c> dealRegistrations = [
			SELECT
				Id,
				wi_Associated_Partner__c,
				Mapped_Opportunity__c,
				or_Opportunity_Registration__c,
				or_Opp_Reg_Status__c,
				or_Opp_Reg_Approval_Flow_Status__c,
				Distributor__c
			FROM Deal_Registration__c
		];
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
			dealRegistrations.deepClone(true, true, true)
		);
		for (Deal_Registration__c dealRegistration : dealRegistrations) {
			dealRegistration.or_Opp_Reg_Status__c = 'Approved';
			dealRegistration.Mapped_Opportunity__c = opp.Id;
			dealRegistration.Distributor__c = distributorAccount.Id;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			DealRegistrationUtility.upsertOpportunityPartner(dealRegistrations, oldMap);
			Test.stopTest();
		}
		List<Opportunity_Partners__c> oppPartners = [
			SELECT Id, Account__c, Partner_Role__c
			FROM Opportunity_Partners__c
			WHERE Partner_Role__c = 'Supply chain/Procurement'
		];
		Assert.isFalse(oppPartners.isEmpty());
	}

	@IsTest
	static void testInsertOpportunityPartner_Always_CreateOppPartnerRecord() {
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		List<Opportunity_Partners__c> existingOppPartners = [SELECT Id FROM Opportunity_Partners__c];
		List<Deal_Registration__c> dealRegistrations = [
			SELECT
				Id,
				wi_Associated_Partner__c,
				Mapped_Opportunity__c,
				or_Opportunity_Registration__c,
				or_Opp_Reg_Status__c,
				or_Opp_Reg_Approval_Flow_Status__c,
				Distributor__c
			FROM Deal_Registration__c
		];
		for (Deal_Registration__c dealRegistration : dealRegistrations) {
			dealRegistration.Mapped_Opportunity__c = opp.Id;
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			delete existingOppPartners;
			update dealRegistrations;
			Test.startTest();
			DealRegistrationUtility.insertOpportunityPartner(
				new Map<Id, Deal_Registration__c>(dealRegistrations).keySet()
			);
			Test.stopTest();
		}

		List<Opportunity_Partners__c> oppPartners = [
			SELECT Id, Account__c, Partner_Role__c
			FROM Opportunity_Partners__c
		];
		Assert.isFalse(oppPartners.isEmpty());
	}

	@IsTest
	static void testUpdateDeal_RingLeadUser() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Deal_Registration__c dealReg = [SELECT Id FROM Deal_Registration__c LIMIT 1];

			Account partnerAccount = [SELECT Id FROM Account WHERE Name = 'Partner Account'];
			partnerAccount.Partner_Maturity__c = 'Active';
			partnerAccount.Sales_Model__c = 'Indirect';
			update partnerAccount;

			Integration_User__c integUser = new Integration_User__c(
				SetupOwnerId = UserInfo.getOrganizationId(),
				RingLead__c = System.UserInfo.getUserId().left(15)
			);
			insert integUser;

			Test.startTest();
			Boolean expectedExceptionThrown = false;
			try {
				dealReg.LastName__c = 'TestUpdate';
				update dealReg;
			} catch (Exception e) {
				expectedExceptionThrown = (e.getMessage().contains('Cannot edit a Deal Registration'));
			}
			Test.stopTest();

			Assert.areEqual(true, expectedExceptionThrown);
		}
	}

	@IsTest
	static void handleLatinAmericaCustomLogic() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [SELECT Id FROM Account WHERE Name = 'Base Account'];
			Account partnerAccount = [SELECT Id FROM Account WHERE Name = 'Partner Account'];
			partnerAccount.Partner_Maturity__c = 'Active';
			partnerAccount.Sales_Model__c = 'Indirect';
			partnerAccount.Partner_Geo_Region__c = 'LatAm';
			update partnerAccount;

			Opportunity opp = TestFactory.buildOpportunity(
				'Opportunity',
				System.today(),
				Utility.PROSPECTING,
				acc.Id
			);
			insert opp;

			Opportunity_Partners__c oppPartner = TestFactory.buildOpportunityPartner(
				opp.Id,
				partnerAccount.Id,
				10
			);
			insert oppPartner;

			Deal_Registration__c newDeal = TestFactory.buildDealReg(
				'Ricky1',
				'Ponting',
				'test@test.com',
				'LeadTest-101'
			);
			newDeal.wi_Associated_Partner__c = partnerAccount.Id;
			newDeal.Account__c = null;

			Test.startTest();
			insert newDeal;
			Test.stopTest();

			Automation_Management__c am = [
				SELECT Id, Default_Opp_Reg_Owner_LATAM__c
				FROM Automation_Management__c
			];

			Deal_Registration__c deal = [
				SELECT Id, OwnerId
				FROM Deal_Registration__c
				WHERE Id = :newDeal.Id
			];

			Assert.isTrue(
				am.Default_Opp_Reg_Owner_LATAM__c == deal.OwnerId,
				'Lead Owner should be LATAM Owner from Automation Management Object'
			);
		}
	}

	@IsTest
	static void test_updateFieldsOnOppRegStatusExtensionPending() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Deal_Registration__c testDeal = [SELECT Id FROM Deal_Registration__c LIMIT 1];
			testDeal.or_Opp_Reg_Status__c = 'Extension Pending';

			Test.startTest();
			update testDeal;
			Test.stopTest();

			Deal_Registration__c updatedDeal = [
				SELECT Id, Date_Approved_Extension__c, Opp_Reg_Ext_Request_Date_Time__c
				FROM Deal_Registration__c
				LIMIT 1
			];
			Assert.areEqual(
				null,
				updatedDeal.Date_Approved_Extension__c,
				'if Opp_Reg_Status is Extension Pending, Date_Approved_Extension should update to null'
			);
			Assert.areEqual(
				Date.valueOf(System.now()),
				Date.valueOf(updatedDeal.Opp_Reg_Ext_Request_Date_Time__c),
				'if Opp_Reg_Status is Extension Pending, Opp_Reg_Ext_Request_Date_Time should update to today date'
			);
		}
	}

	@IsTest
	static void test_businessDays_between_RegExtRequestDate_DateApprovedExtension() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Deal_Registration__c testDeal = [SELECT Id FROM Deal_Registration__c LIMIT 1];
			testDeal.Opp_Reg_Ext_Request_Date_Time__c = Date.newInstance(2021, 12, 15);
			testDeal.Date_Approved_Extension__c = Date.newInstance(2021, 12, 25);

			Test.startTest();
			update testDeal;
			Test.stopTest();

			Deal_Registration__c updatedDeal = [
				SELECT Id, Opp_Reg_EXT_Bus_Days_Clone__c
				FROM Deal_Registration__c
				LIMIT 1
			];
			Assert.areEqual(
				9,
				updatedDeal.Opp_Reg_EXT_Bus_Days_Clone__c,
				'Calculate Business Days between RegExtRequestDate & DateApprovedExtension'
			);
		}
	}

	@IsTest
	static void testDeleteOppReg_NonAdminUser() {
		Deal_Registration__c deal = [SELECT Id FROM Deal_Registration__c LIMIT 1];

		User nonAdminUser = TestUserFactory.createSalesOpsUser();
		insert nonAdminUser;
		TestingUtility.assignPermissionSet(nonAdminUser.Id, 'DisableValidationRules');

		System.runAs(TestUserFactory.getAdminUser()) {
			deal.OwnerId = nonAdminUser.Id;
			update deal;
		}

		System.runAs(nonAdminUser) {
			String expectedError;

			Test.startTest();
			try {
				delete deal;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
			Test.stopTest();

			Assert.isTrue(
				expectedError.contains(System.Label.Deal_Reg_Deletion_Restricted),
				'Non-Admin users are not allowed to delete Opp Reg'
			);
		}
	}

	@IsTest
	static void testSetFailure_Always_SetErrorMessage() {
		Integer i;
		DealRegistrationUtility.ActionResult ar = new DealRegistrationUtility.ActionResult();
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				i = (1 / 0);
			} catch (Exception e) {
				ar.setFailure(e);
			}
			ar.setFailure('ErrorMessage');
			Test.stopTest();
		}
		Assert.isTrue(ar.error == 'ErrorMessage');
	}

	@IsTest
	static void testHandleMappedOpportunityChange_WhenCLosedWonOppIsMapped_ReturnError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
			opp.StageName = Utility.CLOSED_WON;
			update opp;

			List<Deal_Registration__c> dealRegistrations = [
				SELECT Id, Mapped_Opportunity__c
				FROM Deal_Registration__c
			];

			Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
				dealRegistrations.deepClone(true, true, true)
			);
			for (Deal_Registration__c dealRegistration : dealRegistrations) {
				dealRegistration.or_Create_Opportunity_upon_Approval__c = false;
				dealRegistration.Mapped_Opportunity__c = opp.Id;
			}

			Test.startTest();
			DealRegistrationUtility.handleMappedOpportunityChange(dealRegistrations, oldMap);
			Test.stopTest();

			Assert.isTrue(
				dealRegistrations[0].getErrors()[0]
					.getMessage()
					.contains(Label.Deal_Reg_Map_Closed_Won_Opp_Restricted)
			);
		}
	}

	@IsTest
	static void testHandleMappedOpportunityChange_WhenRenewalTypeOppIsMapped_ReturnError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
			opp.StageName = Utility.FAILED_RENEWAL;
			update opp;

			List<Deal_Registration__c> dealRegistrations = [
				SELECT Id, Mapped_Opportunity__c
				FROM Deal_Registration__c
			];

			Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
				dealRegistrations.deepClone(true, true, true)
			);
			for (Deal_Registration__c dealRegistration : dealRegistrations) {
				dealRegistration.or_Create_Opportunity_upon_Approval__c = false;
				dealRegistration.Mapped_Opportunity__c = opp.Id;
			}

			Test.startTest();
			DealRegistrationUtility.handleMappedOpportunityChange(dealRegistrations, oldMap);
			Test.stopTest();

			Assert.isTrue(
				dealRegistrations[0].getErrors()[0]
					.getMessage()
					.contains(Label.Deal_Reg_Map_Closed_Won_Opp_Restricted)
			);
		}
	}

	@IsTest
	static void testHandleMappedOpportunityChange_WhenOpenOppIsMapped_NoError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
			List<Deal_Registration__c> dealRegistrations = [
				SELECT Id, Mapped_Opportunity__c
				FROM Deal_Registration__c
			];

			Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
				dealRegistrations.deepClone(true, true, true)
			);
			for (Deal_Registration__c dealRegistration : dealRegistrations) {
				dealRegistration.or_Create_Opportunity_upon_Approval__c = false;
				dealRegistration.Mapped_Opportunity__c = opp.Id;
			}

			Test.startTest();
			DealRegistrationUtility.handleMappedOpportunityChange(dealRegistrations, oldMap);
			Test.stopTest();

			Assert.isTrue(dealRegistrations[0].getErrors().isEmpty());
		}
	}

	@IsTest
	static void preApprovalChecks_WhenMappedOppisClosedWon_ReturnClosedWonApprovalRestrictedError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
			opp.StageName = Utility.CLOSED_WON;
			update opp;

			List<Deal_Registration__c> dealRegistrations = [
				SELECT Id, Mapped_Opportunity__c, or_Opp_Reg_Status__c
				FROM Deal_Registration__c
			];

			Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
				dealRegistrations.deepClone(true, true, true)
			);
			for (Deal_Registration__c dealRegistration : dealRegistrations) {
				dealRegistration.or_Create_Opportunity_upon_Approval__c = false;
				dealRegistration.Mapped_Opportunity__c = opp.Id;
				dealRegistration.or_Opp_Reg_Status__c = 'Approved';
			}

			Test.startTest();
			DealRegistrationUtility.preApprovalChecks(dealRegistrations, oldMap);
			Test.stopTest();

			Assert.isTrue(
				dealRegistrations[0].getErrors()[0]
					.getMessage()
					.contains(Label.Deal_Reg_Approval_Restricted_Closed_Won_Opp)
			);
		}
	}

	@IsTest
	static void preApprovalChecks_WhenMappedOppHasExpiredOrExtensionPendingDeal_ReturnDuplicateErrorApprovalRestrictedError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

			List<Deal_Registration__c> dealRegistrations = [
				SELECT
					Id,
					Mapped_Opportunity__c,
					or_Opp_Reg_Status__c,
					wi_Associated_Partner__c,
					Account__c
				FROM Deal_Registration__c
			];

			Deal_Registration__c deal = TestFactory.buildDealReg(
				'First',
				'Last',
				'firstlast@test.com',
				'Test Company'
			);
			deal.wi_Associated_Partner__c = dealRegistrations[0].wi_Associated_Partner__c;
			deal.Account__c = dealRegistrations[0].Account__c;
			deal.Mapped_Opportunity__c = opp.Id;
			deal.or_Opp_Reg_Status__c = 'Extension Pending';
			insert deal;

			Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
				dealRegistrations.deepClone(true, true, true)
			);
			for (Deal_Registration__c dealRegistration : dealRegistrations) {
				dealRegistration.or_Create_Opportunity_upon_Approval__c = false;
				dealRegistration.Mapped_Opportunity__c = opp.Id;
				dealRegistration.or_Opp_Reg_Status__c = 'Approved';
			}

			Test.startTest();
			DealRegistrationUtility.preApprovalChecks(dealRegistrations, oldMap);
			Test.stopTest();

			String recordLink = URL.getOrgDomainURL().toExternalForm() + '/' + dealRegistrations[0].Id;
			Assert.isTrue(
				dealRegistrations[0].getErrors()[0]
					.getMessage()
					.contains(
						Label.Deal_Reg_Approval_Restricted_Expired_Extended_Exists.replace(
							'{recordLink}',
							recordLink
						)
					)
			);
		}
	}

	@IsTest
	static void testAssignEndCustomerAccount_WhenNoAccountWithSameDomainAndHqCountry_DoNotAssignDealRegWithAccount() {
		List<Deal_Registration__c> dealRegistrations = [
			SELECT Id, Account__c, Countries__c, Email__c
			FROM Deal_Registration__c
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			DealRegistrationUtility.assignEndCustomerAccount(dealRegistrations);
			Test.stopTest();
		}

		List<Deal_Registration__c> dealRegistrationsWithoutAccounts = [
			SELECT Id
			FROM Deal_Registration__c
			WHERE Account__c != NULL
		];

		Assert.isTrue(dealRegistrationsWithoutAccounts.size() == 1);
	}

	@IsTest
	static void testProcessDealRegEndCustomerAccount_WhenEndCustomerAccountPopulated_SuccessAutoPopulatePFSFields() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [
				SELECT Id, Name, Primary_PFS_Territory_Name__c, Primary_PFS_Territory_Id__c
				FROM Account
				WHERE Name = 'PFS Account'
			];

			Map<Id, Account> accountIdToAccount = new Map<Id, Account>();
			accountIdToAccount.put(acc.Id, acc);

			Deal_Registration__c deal = [
				SELECT
					Id,
					Primary_PFS_Territory_Name__c,
					Primary_PFS_Territory_Owner__c,
					Account__c,
					Account__r.Primary_PFS_Territory_Id__c,
					Account__r.Primary_PFS_Territory_Name__c
				FROM Deal_Registration__c
				LIMIT 1
			];
			List<Deal_Registration__c> deals = new List<Deal_Registration__c>{ deal };

			Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
				deals.deepClone(true, true, true)
			);

			Test.startTest();
			deal.Account__c = acc.Id;
			DealRegistrationUtility.processDealRegEndCustomerAccount(
				deals,
				oldMap,
				accountIdToAccount
			);
			Test.stopTest();

			Territory2 territory = [
				SELECT Id, Name
				FROM Territory2
				WHERE Name = 'L1 Test PFS Territory'
				LIMIT 1
			];

			Assert.areEqual(
				territory.Name,
				deal.Primary_PFS_Territory_Name__c,
				'Primary PFS Territory Name does not match on Deal Reg'
			);
			Assert.areEqual(
				UserInfo.getUserId(),
				deal.Primary_PFS_Territory_Owner__c,
				'Primary PFS Territory Owner does not match on Deal Reg'
			);
			Assert.areEqual(
				acc.Id,
				deal.Account__c,
				'End Customer Account should have been updated on Deal Reg'
			);
		}
	}

	@IsTest
	static void testProcessDealRegEndCustomerAccount_WhenEndCustomerAccountPopulated_FailAutoPopulatePFSFields() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Territory2 territory = [
				SELECT Id, Name
				FROM Territory2
				WHERE Name = 'L1 Test PFS Territory'
				LIMIT 1
			];

			User manager = [SELECT Id FROM User WHERE LastName = 'User_Manager' LIMIT 1];
			UserTerritory2Association dupUserTerrAssoc = new UserTerritory2Association();
			dupUserTerrAssoc.UserId = manager.Id;
			dupUserTerrAssoc.Territory2Id = territory.Id;
			dupUserTerrAssoc.RoleInTerritory2 = 'PFS';
			insert dupUserTerrAssoc;

			Account acc = [
				SELECT Id, Name, Primary_PFS_Territory_Name__c, Primary_PFS_Territory_Id__c
				FROM Account
				WHERE Name = 'PFS Account'
			];

			Map<Id, Account> accountIdToAccount = new Map<Id, Account>();
			accountIdToAccount.put(acc.Id, acc);

			Deal_Registration__c deal = [
				SELECT
					Id,
					Primary_PFS_Territory_Name__c,
					Primary_PFS_Territory_Owner__c,
					Account__c,
					Account__r.Primary_PFS_Territory_Id__c,
					Account__r.Primary_PFS_Territory_Name__c
				FROM Deal_Registration__c
				LIMIT 1
			];
			List<Deal_Registration__c> deals = new List<Deal_Registration__c>{ deal };

			Map<Id, Deal_Registration__c> oldMap = new Map<Id, Deal_Registration__c>(
				deals.deepClone(true, true, true)
			);

			Test.startTest();
			deal.Account__c = acc.Id;
			DealRegistrationUtility.processDealRegEndCustomerAccount(
				deals,
				oldMap,
				accountIdToAccount
			);
			Test.stopTest();

			Assert.isNull(
				deal.Primary_PFS_Territory_Name__c,
				'Primary PFS Territory Name should remain blank on Deal Reg'
			);
			Assert.isNull(
				deal.Primary_PFS_Territory_Owner__c,
				'Primary PFS Territory Owner should remain blank on Deal Reg'
			);
			Assert.areEqual(
				acc.Id,
				deal.Account__c,
				'End Customer Account should have been updated on Deal Reg'
			);
		}
	}

	static User getUserUS() {
		if (DealRegistrationUtilityTest.userUS == null) {
			User[] US_Users = [SELECT Id FROM User WHERE IsActive = TRUE AND Alias = 'userUS' LIMIT 1];
			if (US_Users.isEmpty()) {
				User userUS = TestUserFactory.createUser(
					'UserUS',
					'userUS@tanium.com.test',
					'userUS',
					Utility.getAdminUserProfileId(),
					null
				);
				insert userUS;

				return userUS;
			} else {
				return US_Users[0];
			}
		}
		return DealRegistrationUtilityTest.userUS;
	}

	static User getUserMexico() {
		if (DealRegistrationUtilityTest.userMexico == null) {
			User[] mexico_Users = [
				SELECT Id
				FROM User
				WHERE IsActive = TRUE AND Alias = 'uMexico'
				LIMIT 1
			];
			if (mexico_Users.isEmpty()) {
				User userMexico = TestUserFactory.createUser(
					'UserMexico',
					'userMexico@tanium.com.test',
					'uMexico',
					Utility.getAdminUserProfileId(),
					null
				);
				insert userMexico;

				return userMexico;
			} else {
				return mexico_Users[0];
			}
		}
		return DealRegistrationUtilityTest.userMexico;
	}

	static User getDealDeskUser() {
		User[] dealDeskUsers = [SELECT Id FROM User WHERE LastName = :TestUserFactory.DEAL_DESK_USER];
		if (dealDeskUsers.isEmpty()) {
			User dealDeskUser = TestUserFactory.createDealDeskUser();
			TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableFlows');
			return dealDeskUser;
		}
		return dealDeskUsers[0];
	}
}