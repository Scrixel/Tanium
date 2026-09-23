/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for OpportunityTriggerUtility
 * @Date: 2014-08
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7583    03-21-2024    Removing BoomiRestService code references
 * SS-7749    05-14-2024    Remove Route to RVP or AVP
 * SS-7595    05-17-2024    Primary Quote Partner and Downstream partner validations
 * SS-8994    2024-10-03    Updated test class
 * SS-9872    2024-12-17    Use Geo, Region and Sub Region instead of Level 2, 3, and 4
 * SS-10261   2025-05-01    Test methods to Territory Assignment on opportunites
 * SS-10736   2025-07-05    Use new Verification object and new Account fields
 * SS-12459   2026-01-22    Removed Lead Source fields then added back after field type change
 * SS-12400   2026-01-22    Removed Primary_Contact__c field from class
 * SS-12843   2026-03-17    Adjusted test methods to cover new territory assignment logic
 * SS-12971   2026-04-07    Tests for Original_Territory2_ID__c sync vs Closed Won / Failed
 * SS-13218   2026-06-05    Updated makeData method to improve tests in async mode
 * SS-13500   2026-07-14    Remove deprecated fields for project kondo group 2 contact
 * SS-13712   2026-07-30    Removed HFPOC logic
 * SS-13636   2026-09-11    Tests for processOppPartners with new stage numbering
 */
@IsTest
private class OpportunityTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		Id partnerAccountRecTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
		Id endUserRecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'MSSP_End_User');
		Id oppConOwnerMgmtRecTypeId = Utility.getRecordTypeIdByAPIName(
			'Assignment_Management__c',
			'Oppty_Contract_Partner_Owner_Management'
		);

		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler',
				'BillingScheduleTriggerHandler',
				'UserTriggerHandler'
			}
		);

		User runningUser = TestUserFactory.getAdminUser();
		runningUser.ManagerId = UserInfo.getUserId();
		update runningUser;

		System.runAs(runningUser) {
			Territory2 testSalesTerritory1;
			Territory2 testSalesTerritory2;
			List<Territory2> activeSalesTerritories = [
				SELECT Id, Name
				FROM Territory2
				WHERE Territory2Model.State = 'Active' AND Territory2Type.MasterLabel = 'Sales'
				ORDER BY Id
				LIMIT 2
			];
			if (activeSalesTerritories.size() >= 2) {
				testSalesTerritory1 = activeSalesTerritories[0];
				testSalesTerritory2 = activeSalesTerritories[1];
			} else if (activeSalesTerritories.size() == 1) {
				testSalesTerritory1 = activeSalesTerritories[0];
				testSalesTerritory2 = activeSalesTerritories[0];
			} else {
				Territory2Model territoryModel = new Territory2Model(
					Name = 'testTerritoryModel',
					DeveloperName = 'testTerritoryModel'
				);
				insert territoryModel;

				Territory2Type salesTerritoryType = [
					SELECT Id
					FROM Territory2Type
					WHERE MasterLabel = 'Sales'
					LIMIT 1
				];

				testSalesTerritory1 = new Territory2(
					Name = 'Test Sales Territory',
					Territory2TypeId = salesTerritoryType.Id,
					Territory2ModelId = territoryModel.Id,
					DeveloperName = 'Test_Sales_Territory'
				);
				testSalesTerritory2 = new Territory2(
					Name = 'Test Sales Territory2',
					Territory2TypeId = salesTerritoryType.Id,
					Territory2ModelId = territoryModel.Id,
					DeveloperName = 'Test_Sales_Territory2'
				);
				insert new List<Territory2>{ testSalesTerritory1, testSalesTerritory2 };

				territoryModel.State = 'Active';
				update territoryModel;
			}

			List<Account> accounts = new List<Account>();
			accounts.add(TestFactory.buildAccount('Test Account'));
			accounts[0].Active_Account__c = true;
			accounts[0].Geo__c = 'US and Canada';
			accounts[0].Region__c = 'US and Canada';
			accounts[0].Primary_Sales_Territory_Id__c = testSalesTerritory1.Id;
			accounts[0].Primary_Sales_Territory_Name__c = testSalesTerritory1.Name;

			accounts.add(TestFactory.buildAccount('Partner Account'));
			accounts[1].RecordTypeId = partnerAccountRecTypeId;
			accounts[1].Active_Account__c = true;
			accounts[1].Support_Verified__c = true;
			accounts[1].Cloud_Deployment_Verified__c = true;
			accounts[1].On_Prem_Deployment_Verified__c = true;
			accounts[1].Geo__c = 'EMEA';
			accounts[1].Region__c = 'EMEA';
			accounts[1].Primary_Sales_Territory_Id__c = testSalesTerritory1.Id;
			accounts[1].Primary_Sales_Territory_Name__c = testSalesTerritory1.Name;

			accounts.add(TestFactory.buildAccount('Downstream Partner Account'));
			accounts[2].RecordTypeId = partnerAccountRecTypeId;
			accounts[2].Active_Account__c = true;
			accounts[2].Support_Verified__c = true;
			accounts[2].Cloud_Deployment_Verified__c = true;
			accounts[2].On_Prem_Deployment_Verified__c = true;
			accounts[2].Primary_Sales_Territory_Id__c = testSalesTerritory2.Id;
			accounts[2].Primary_Sales_Territory_Name__c = testSalesTerritory2.Name;

			accounts.add(TestFactory.buildAccount('Test End User Account'));
			accounts[3].RecordTypeId = endUserRecordTypeId;
			accounts[3].Primary_Sales_Territory_Id__c = testSalesTerritory2.Id;
			accounts[3].Primary_Sales_Territory_Name__c = testSalesTerritory2.Name;

			accounts.add(TestFactory.buildAccount('Test End User Account2'));
			accounts[4].RecordTypeId = endUserRecordTypeId;
			accounts[4].Primary_Sales_Territory_Id__c = testSalesTerritory1.Id;
			accounts[4].Primary_Sales_Territory_Name__c = testSalesTerritory1.Name;
			insert accounts;

			List<Opportunity> opps = new List<Opportunity>();
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity',
					Date.today().addDays(30),
					Utility.PROSPECTING,
					accounts[0].Id
				)
			);
			opps[0].OwnerId = UserInfo.getUserId();
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity 2',
					Date.today().addDays(30),
					Utility.PROSPECTING,
					accounts[1].Id
				)
			);
			opps[1].OwnerId = UserInfo.getUserId();
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity - Territory Assignment-End User',
					Date.today().addDays(30),
					Utility.PROSPECTING,
					accounts[0].Id
				)
			);
			opps[2].End_User_Account__c = accounts[3].Id;
			opps[2].Type = 'Add-On';
			opps[2].Business_Motion__c = 'MSP';
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity - Territory Assignment-Account',
					Date.today().addDays(30),
					Utility.PROSPECTING,
					accounts[1].Id
				)
			);
			opps[3].End_User_Account__c = accounts[3].Id;
			opps[3].Type = 'Add-On';
			opps[3].Business_Motion__c = 'Direct';
			insert opps;

			Contact con = new Contact(
				LastName = 'SomeLastname',
				Email = 'SomeLastname@testaccount.io',
				AccountId = accounts[0].Id,
				MailingCountry = 'United States',
				Original_Lead_Source__c = 'Marketing'
			);
			insert con;

			List<Verification__c> verifications = new List<Verification__c>();
			verifications.addAll(
				TestFactory.buildVerifications(
					accounts[1].Id,
					new List<String>{ 'Cloud Deployment', 'Support L1/L2', 'On-Prem Deployment' },
					Date.today().addDays(30)
				)
			);
			verifications.addAll(
				TestFactory.buildVerifications(
					accounts[2].Id,
					new List<String>{ 'Cloud Deployment', 'Support L1/L2', 'On-Prem Deployment' },
					Date.today().addDays(30)
				)
			);
			insert verifications;

			insert new OpportunityContactRole(OpportunityId = opps[0].Id, ContactId = con.Id);

			List<SBQQ__Quote__c> quotes = new List<SBQQ__Quote__c>();
			quotes.add(
				TestFactory.buildSBQQ_Quote(
					opps[0].Id,
					accounts[0].Id,
					'Accepted',
					'Quote',
					Date.today(),
					Date.today().addDays(180),
					Test.getStandardPricebookId()
				)
			);
			quotes[0].SBQQ__Primary__c = true;
			quotes[0].SBQQ__Introduction__c = 'Test - SBQQ - #501';
			quotes[0].SBQQ__Partner__c = accounts[1].Id;
			quotes[0].L1_L2_Support_Partner__c = accounts[1].Id;

			quotes.add(
				TestFactory.buildSBQQ_Quote(
					opps[1].Id,
					accounts[0].Id,
					'Accepted',
					'Quote',
					Date.today(),
					Date.today().addDays(180),
					Test.getStandardPricebookId()
				)
			);
			quotes[1].SBQQ__Primary__c = true;
			quotes[1].SBQQ__Introduction__c = 'Test - SBQQ - #501';
			quotes[1].SBQQ__Partner__c = accounts[1].Id;
			quotes[1].Deployment_Partner__c = accounts[1].Id;
			quotes[1].Downstream_Reseller__c = accounts[2].Id;
			quotes[1].L1_L2_Support_Partner__c = accounts[1].Id;
			quotes[1].Deployment_Exception_Granted__c = true;
			quotes[1].Partner_Accreditation__c = 'Deployment';
			insert quotes;

			Billing_Schedule__c billing = TestFactory.buildBillingSchedule(opps[0].Id);
			billing.Billing_Amount__c = opps[0].Amount;
			billing.Invoice_Date__c = System.today().addDays(30);
			insert billing;

			User usCanadaVP = TestUserFactory.createUser(
				'usCanadaVP',
				'usCanadaVP@example.com',
				'USVPUser',
				UserInfo.getProfileId(),
				null
			);
			User EMEAVP = TestUserFactory.createUser(
				'EMEAVP',
				'EMEAVP@example.com',
				'emeavp',
				UserInfo.getProfileId(),
				null
			);
			User usCanadaUser = TestUserFactory.createUser(
				'usCanadaUser',
				'usCanadaUser@example.com',
				'USUser',
				UserInfo.getProfileId(),
				null
			);
			usCanadaUser.ManagerId = UserInfo.getUserId();

			User EMEAUser = TestUserFactory.createUser(
				'EMEAUser',
				'EMEA@example.com',
				'emeaUser',
				UserInfo.getProfileId(),
				null
			);
			EMEAUser.ManagerId = UserInfo.getUserId();
			insert new List<User>{ usCanadaVP, usCanadaUser, EMEAUser, EMEAVP };

			List<Assignment_Management__c> assignmentMgmt = new List<Assignment_Management__c>();
			assignmentMgmt.add(
				new Assignment_Management__c(
					Name = 'usCanada',
					Geo__c = 'US and Canada',
					Region__c = 'US and Canada',
					Route_Based_on_RVP_or_AVP__c = 'Opportunity Manager',
					Persona_Selection__c = UserInfo.getUserId(),
					Contract_Owner_Name__c = usCanadaVP.Id,
					Partner_Owner_Name__c = usCanadaVP.Id,
					RecordTypeId = oppConOwnerMgmtRecTypeId
				)
			);
			assignmentMgmt.add(
				new Assignment_Management__c(
					Name = 'Partner EMEA',
					Geo__c = 'EMEA',
					Region__c = 'EMEA',
					Contract_Owner_Name__c = EMEAVP.Id,
					Partner_Owner_Name__c = EMEAVP.Id,
					RecordTypeId = oppConOwnerMgmtRecTypeId
				)
			);
			insert assignmentMgmt;

			Opportunity_Partners__c partner1 = new Opportunity_Partners__c(
				Account__c = accounts[1].Id,
				Opportunity__c = opps[0].Id
			);
			Opportunity_Partners__c partner2 = new Opportunity_Partners__c(
				Account__c = accounts[2].Id,
				Opportunity__c = opps[0].Id
			);
			insert new List<Opportunity_Partners__c>{ partner1, partner2 };
		}
	}

	@IsTest
	static void testFilterRecordsForMarketingAndPartnerSync() {
		Opportunity[] opps = [SELECT Id, StageName, SBQQ__PrimaryQuote__c FROM Opportunity];
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));

		for (Opportunity opp : oldMap.values()) {
			opp.StageName = 'Pilot & Value Validated';
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.filterRecordsForMarketingAndPartnerSync(opps, null);
			OpportunityTriggerUtility.filterRecordsForMarketingAndPartnerSync(opps, oldMap);
			Test.stopTest();
		}
	}

	@IsTest
	static void testHandleOwnerChange_USandCanadaUser() {
		Opportunity[] opps = [
			SELECT
				Id,
				OwnerId,
				AccountId,
				Opportunity_Manager__c,
				Pricebook2Id,
				Type,
				Contract_Owner__c,
				Contract_Partner_Owner__c,
				AreaVP__c,
				Business_Motion__c
			FROM Opportunity
		];
		User usCanadaUser = [SELECT Id, ManagerId FROM User WHERE LastName = 'usCanadaUser' LIMIT 1];

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));

		for (Opportunity opp : opps) {
			opp.OwnerId = usCanadaUser.Id;
			opp.Opportunity_Manager__c = usCanadaUser.ManagerId;
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.handleOwnerChange(opps, oldMap);
			Test.stopTest();
		}
		Opportunity[] updatedOpps = opps;

		Assignment_Management__c assignment = [
			SELECT Id, Contract_Owner_Name__c, Partner_Owner_Name__c
			FROM Assignment_Management__c
			WHERE Geo__c = 'US and Canada'
			LIMIT 1
		];

		Assert.isFalse(
			oldMap.get(opps[0].Id).Opportunity_Manager__c == updatedOpps[0].Opportunity_Manager__c,
			'Opp Manager should not be the same with the old value.'
		);
		Assert.isTrue(
			updatedOpps[0].Contract_Owner__c == assignment.Contract_Owner_Name__c,
			'Contract Owner should be the same from Assignment Management object.'
		);
		Assert.isTrue(
			updatedOpps[0].Contract_Partner_Owner__c == assignment.Partner_Owner_Name__c,
			'Parent Contract Owner should be the same from Assignment Management object.'
		);
	}

	@IsTest
	static void testHandleOwnerChange_NonUSCanadaUser() {
		Opportunity[] opps = [
			SELECT
				Id,
				OwnerId,
				AccountId,
				Opportunity_Manager__c,
				Pricebook2Id,
				Type,
				Contract_Owner__c,
				Contract_Partner_Owner__c,
				AreaVP__c,
				Business_Motion__c
			FROM Opportunity
			WHERE Name = 'Test Opportunity 2'
		];
		User EMEAUser = [SELECT Id, ManagerId FROM User WHERE LastName = 'EMEAUser' LIMIT 1];

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));

		for (Opportunity opp : opps) {
			opp.OwnerId = EMEAUser.Id;
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.handleOwnerChange(opps, oldMap);
			Test.stopTest();
		}
		Opportunity[] updatedOpps = opps;

		Assignment_Management__c assignment = [
			SELECT Id, Contract_Owner_Name__c, Partner_Owner_Name__c
			FROM Assignment_Management__c
			WHERE Geo__c = 'EMEA'
		];

		Assert.isFalse(
			oldMap.get(opps[0].Id).Opportunity_Manager__c == updatedOpps[0].Opportunity_Manager__c,
			'Opp Manager should not be the same with the old value.'
		);
		Assert.isTrue(
			updatedOpps[0].Contract_Owner__c == assignment.Contract_Owner_Name__c,
			'Contract Owner should be the same from Assignment Management object for EMEA User.'
		);
		Assert.isTrue(
			updatedOpps[0].Contract_Partner_Owner__c == assignment.Partner_Owner_Name__c,
			'Parent Contract Owner should be the same from Assignment Management object for EMEA User.'
		);
	}

	@IsTest
	static void testBusinessMotionChange_NonMSPOpp() {
		Opportunity[] opps = [
			SELECT
				Id,
				OwnerId,
				AccountId,
				Opportunity_Manager__c,
				Pricebook2Id,
				Type,
				Contract_Owner__c,
				Contract_Partner_Owner__c,
				AreaVP__c,
				Business_Motion__c
			FROM Opportunity
		];
		User EMEAUser = [SELECT Id, ManagerId FROM User WHERE LastName = 'EMEAUser' LIMIT 1];
		Account acc = [SELECT Id FROM Account WHERE Name = 'Downstream Partner Account'];

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));

		for (Opportunity opp : opps) {
			opp.AccountId = acc.Id;
			opp.Business_Motion__c = 'Direct';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.handleBusinessMotionChange(opps, oldMap);
			Test.stopTest();
		}
		Opportunity[] updatedOpps = opps;

		Assignment_Management__c assignment = [
			SELECT Id, Contract_Owner_Name__c, Partner_Owner_Name__c
			FROM Assignment_Management__c
			LIMIT 1
		];

		Assert.areNotEqual(
			assignment.Contract_Owner_Name__c,
			updatedOpps[0].Contract_Owner__c,
			'Contract Owner should not be the same from Assignment Management object for EMEA User.'
		);
		Assert.areNotEqual(
			assignment.Partner_Owner_Name__c,
			updatedOpps[0].Contract_Partner_Owner__c,
			'Parent Contract Owner should not be the same from Assignment Management object for EMEA User.'
		);
	}

	@IsTest
	static void testBusinessMotionChange_MSPOpp() {
		Opportunity[] opps = [
			SELECT
				Id,
				OwnerId,
				AccountId,
				Opportunity_Manager__c,
				Pricebook2Id,
				Type,
				Contract_Owner__c,
				Contract_Partner_Owner__c,
				AreaVP__c,
				Business_Motion__c
			FROM Opportunity
		];
		User EMEAUser = [SELECT Id, ManagerId FROM User WHERE LastName = 'EMEAUser' LIMIT 1];

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));

		for (Opportunity opp : opps) {
			opp.OwnerId = EMEAUser.Id;
			opp.Business_Motion__c = 'MSP';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.handleBusinessMotionChange(opps, oldMap);
			Test.stopTest();
		}
		Opportunity[] updatedOpps = opps;

		Assert.isTrue(
			updatedOpps[0].Contract_Owner__c == null,
			'Contract Owner should be blank if Business Motion is MSP.'
		);
		Assert.isTrue(
			updatedOpps[0].Contract_Partner_Owner__c == null,
			'Parent Contract Owner should be blank if Business Motion is MSP.'
		);
	}

	@IsTest
	static void testSyncSupportPartners() {
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
			[SELECT Id FROM Opportunity WHERE NOT Name LIKE '%Territory%']
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.syncSupportPartners(oppsMap.keySet());
			Test.stopTest();
			List<Support_Partner__c> supportPartners = [
				SELECT Id, Partner_Accreditation__c, Partner_Business_Motion_Contains_Support__c
				FROM Support_Partner__c
				WHERE Opportunity__c IN :oppsMap.keySet()
			];
			System.assertEquals(
				3,
				supportPartners.size(),
				'Should create deployment and support partner'
			);
		}
	}

	@IsTest
	static void testDefaultRelatedAccountOwnerToOppOwner() {
		Opportunity[] opps = [
			SELECT
				Id,
				Type,
				AccountId,
				OwnerId,
				TAM_Sales_SME_Owner__c,
				CSM_Account_Owner__c,
				Opportunity_Manager__c,
				Business_Motion__c
			FROM Opportunity
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.defaultRelatedAccountOwnerToOppOwner(opps);
			Test.stopTest();
			Assert.isTrue(opps[0].Opportunity_Manager__c != null);
		}
	}

	@IsTest
	static void testProcessPrimaryQuote() {
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
			[SELECT Id, SBQQ__PrimaryQuote__c FROM Opportunity]
		);
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(
			oppsMap.values().deepClone(true, true, true)
		);

		SBQQ__Quote__c[] quotes = [SELECT Id FROM SBQQ__Quote__c];

		for (Integer i = 0; i < oppsMap.values().size(); i++) {
			oppsMap.values()[i].SBQQ__PrimaryQuote__c = (i == 0) ? quotes[1].Id : null;
		}
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.processPrimaryQuote(oppsMap, oldMap);
			Test.stopTest();
		}
	}

	@IsTest
	static void testDoesOppPartnerExistsForPartnerFieldOnPrimaryQuote_ifTrueOrIfFalse_returnsAccurateValue() {
		Opportunity opp = [
			SELECT Id, AccountId, PrimaryQuotePartner__c, PrimaryQuoteDownstreamPartner__c
			FROM Opportunity
			LIMIT 1
		];
		List<Account> partnerAccounts = [SELECT Id FROM Account WHERE RecordType.Name = 'Partner'];
		System.runAs(TestUserFactory.getAdminUser()) {
			SBQQ__Quote__c quote = new SBQQ__Quote__c(
				SBQQ__Opportunity2__c = opp.Id,
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Account__c = opp.AccountId,
				SBQQ__Primary__c = true,
				SBQQ__Introduction__c = 'Test Opp Partners',
				SBQQ__StartDate__c = Date.today(),
				SBQQ__EndDate__c = Date.today().addDays(180),
				SBQQ__Status__c = 'Accepted',
				SBQQ__Type__c = 'Quote',
				SBQQ__SubscriptionTerm__c = 5,
				Quantity_Config__c = 1,
				SBQQ__Partner__c = partnerAccounts[0].Id,
				Deployment_Partner__c = partnerAccounts[1].Id,
				Downstream_Reseller__c = partnerAccounts[1].Id,
				L1_L2_Support_Partner__c = partnerAccounts[1].Id,
				Deployment_Exception_Granted__c = true,
				Partner_Accreditation__c = 'Deployment'
			);
			insert quote;

			opp = [
				SELECT Id, AccountId, PrimaryQuotePartner__c, PrimaryQuoteDownstreamPartner__c
				FROM Opportunity
				LIMIT 1
			];
			System.assertNotEquals(null, opp.PrimaryQuotePartner__c);
			System.assertNotEquals(null, opp.PrimaryQuoteDownstreamPartner__c);

			List<Opportunity_Partners__c> oppPartners = [
				SELECT Id, Account__c, Account__r.Name
				FROM Opportunity_Partners__c
				WHERE Opportunity__c = :opp.Id
			];
			System.assertEquals(2, oppPartners.size());
			Map<Id, List<Opportunity_Partners__c>> oppsWithOppPartners = new Map<Id, List<Opportunity_Partners__c>>();
			oppsWithOppPartners.put(opp.Id, oppPartners);
			System.assertEquals(
				true,
				OpportunityTriggerUtility.doesOppPartnerExistsForPartnerFieldOnPrimaryQuote(
					opp,
					oppsWithOppPartners
				)
			);
			oppPartners = oppsWithOppPartners.get(opp.Id);
			Integer index = 0;
			for (Opportunity_Partners__c eachOppPartner : oppPartners) {
				if (eachOppPartner.Account__r.Name == 'Partner Account') {
					oppPartners.remove(index);
					break;
				}
				index++;
			}
			System.assertEquals(
				false,
				OpportunityTriggerUtility.doesOppPartnerExistsForPartnerFieldOnPrimaryQuote(
					opp,
					oppsWithOppPartners
				)
			);
		}
	}

	@IsTest
	static void testDoesOppPartnerExistsForDownstreamPartnerFieldOnPrimaryQuote_ifTrueOrIfFalse_returnsAccurateValue() {
		List<Opportunity_Partners__c> oppPartners = [
			SELECT Id, Account__c, Account__r.Name, Opportunity__c
			FROM Opportunity_Partners__c
			WHERE Opportunity__c != NULL
		];
		System.assertEquals(2, oppPartners.size());
		Map<Id, List<Opportunity_Partners__c>> oppsWithOppPartners = new Map<Id, List<Opportunity_Partners__c>>();
		oppsWithOppPartners.put(oppPartners[0].Opportunity__c, oppPartners);
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [
				SELECT Id, AccountId, PrimaryQuotePartner__c, PrimaryQuoteDownstreamPartner__c
				FROM Opportunity
				WHERE Id = :oppPartners[0].Opportunity__c
			];
			List<Account> partnerAccounts = [SELECT Id FROM Account WHERE RecordType.Name = 'Partner'];
			SBQQ__Quote__c quote = new SBQQ__Quote__c(
				SBQQ__Opportunity2__c = opp.Id,
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Account__c = opp.AccountId,
				SBQQ__Primary__c = true,
				SBQQ__Introduction__c = 'Test Opp Partners',
				SBQQ__StartDate__c = Date.today(),
				SBQQ__EndDate__c = Date.today().addDays(180),
				SBQQ__Status__c = 'Accepted',
				SBQQ__Type__c = 'Quote',
				SBQQ__SubscriptionTerm__c = 5,
				Quantity_Config__c = 1,
				SBQQ__Partner__c = partnerAccounts[0].Id,
				Deployment_Partner__c = partnerAccounts[1].Id,
				Downstream_Reseller__c = partnerAccounts[1].Id,
				L1_L2_Support_Partner__c = partnerAccounts[1].Id,
				Deployment_Exception_Granted__c = true,
				Partner_Accreditation__c = 'Deployment'
			);
			insert quote;
			opp = [
				SELECT Id, AccountId, PrimaryQuotePartner__c, PrimaryQuoteDownstreamPartner__c
				FROM Opportunity
				WHERE Id = :oppPartners[0].Opportunity__c
			];
			System.assertEquals(
				true,
				OpportunityTriggerUtility.doesOppPartnerExistsForDownstreamPartnerFieldOnPrimaryQuote(
					opp,
					oppsWithOppPartners
				)
			);
			oppPartners = oppsWithOppPartners.get(opp.Id);
			Integer index = 0;
			for (Opportunity_Partners__c eachOppPartner : oppPartners) {
				if (eachOppPartner.Account__r.Name == 'Downstream Partner Account') {
					oppPartners.remove(index);
					break;
				}
				index++;
			}
			System.assertEquals(
				false,
				OpportunityTriggerUtility.doesOppPartnerExistsForDownstreamPartnerFieldOnPrimaryQuote(
					opp,
					oppsWithOppPartners
				)
			);
		}
	}
	@IsTest
	static void testProcessOppPartners_ifHasPartnerAndDownstreamPartnerRecords_allowsWaitingForSignatureStageNameChange() {
		List<Opportunity_Partners__c> oppPartners = [
			SELECT Id, Account__c, Account__r.Name, Opportunity__c
			FROM Opportunity_Partners__c
			WHERE Opportunity__c != NULL
		];
		Opportunity opp = [
			SELECT Id, AccountId, PrimaryQuotePartner__c, PrimaryQuoteDownstreamPartner__c
			FROM Opportunity
			WHERE Id = :oppPartners[0].Opportunity__c
		];
		List<Account> partnerAccounts = [SELECT Id FROM Account WHERE RecordType.Name = 'Partner'];
		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			SBQQ__Quote__c quote = new SBQQ__Quote__c(
				SBQQ__Opportunity2__c = opp.Id,
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Account__c = opp.AccountId,
				SBQQ__Primary__c = true,
				SBQQ__Introduction__c = 'Test Opp Partners',
				SBQQ__StartDate__c = Date.today(),
				SBQQ__EndDate__c = Date.today().addDays(180),
				SBQQ__Status__c = 'Accepted',
				SBQQ__Type__c = 'Quote',
				SBQQ__SubscriptionTerm__c = 5,
				Quantity_Config__c = 1,
				SBQQ__Partner__c = partnerAccounts[0].Id,
				Deployment_Partner__c = partnerAccounts[1].Id,
				Downstream_Reseller__c = partnerAccounts[1].Id,
				L1_L2_Support_Partner__c = partnerAccounts[1].Id,
				Deployment_Exception_Granted__c = true,
				Partner_Accreditation__c = 'Deployment'
			);
			insert quote;
		}
		Boolean exceptionThrown = false;
		System.runAs(adminUser) {
			try {
				opp.StageName = Utility.WAITING_FOR_SIGNATURE;
				update opp;
			} catch (Exception e) {
				exceptionThrown = true;
			}
		}
		System.assertEquals(false, exceptionThrown);
		System.assertNotEquals(
			null,
			[
				SELECT Id
				FROM Opportunity
				WHERE StageName = :Utility.WAITING_FOR_SIGNATURE AND Id = :opp.Id
			]
		);
	}

	@IsTest
	static void testProcessOppPartners_CommitToSignedWithoutOppPartner_AddsPartnerError() {
		List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 2'];
		List<Account> partnerAccounts = [SELECT Id FROM Account WHERE Name = 'Partner Account'];
		List<User> standardUsers = [SELECT Id FROM User WHERE UserName = 'usCanadaUser@example.com'];
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
			opps[0].Id => buildOppWithStageNumber(
				opps[0].Id,
				Utility.COMMIT_STAGE,
				Utility.COMMIT_STAGE_NUMBER,
				null,
				null
			)
		};
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>{
			opps[0].Id => buildOppWithStageNumber(
				opps[0].Id,
				Utility.SIGNED_PAPERWORK_RECEIVED,
				Utility.SIGNED_PAPERWORK_RECEIVED_STAGE_NUMBER,
				partnerAccounts[0].Id,
				null
			)
		};

		System.runAs(standardUsers[0]) {
			Test.startTest();
			OpportunityTriggerUtility.processOppPartners(oppsMap, oldMap);
			Test.stopTest();
		}

		List<Database.Error> errors = oppsMap.get(opps[0].Id).getErrors();
		Assert.areEqual(1, errors.size(), 'Commit -> Signed without Opportunity Partner => error');
		Assert.areEqual(
			System.Label.Partner_error_on_Primary_Quote_And_Opp_Partners,
			errors[0].getMessage(),
			'Primary Quote Partner has no Opportunity Partner'
		);
	}

	@IsTest
	static void testProcessOppPartners_NewStageNumberNull_SkipsPartnerValidation() {
		List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 2'];
		List<Account> partnerAccounts = [SELECT Id FROM Account WHERE Name = 'Partner Account'];
		List<User> standardUsers = [SELECT Id FROM User WHERE UserName = 'usCanadaUser@example.com'];
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
			opps[0].Id => buildOppWithStageNumber(
				opps[0].Id,
				Utility.COMMIT_STAGE,
				Utility.COMMIT_STAGE_NUMBER,
				null,
				null
			)
		};
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>{
			opps[0].Id => buildOppWithStageNumber(
				opps[0].Id,
				'Stage Without Number',
				null,
				partnerAccounts[0].Id,
				null
			)
		};

		System.runAs(standardUsers[0]) {
			Test.startTest();
			OpportunityTriggerUtility.processOppPartners(oppsMap, oldMap);
			Test.stopTest();
		}

		Assert.isTrue(
			oppsMap.get(opps[0].Id).getErrors().isEmpty(),
			'Null StageNumber => no validation'
		);
	}

	@IsTest
	static void testProcessOppPartners_IntoExcludedStage_SkipsPartnerValidation() {
		List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 2'];
		List<Account> partnerAccounts = [SELECT Id FROM Account WHERE Name = 'Partner Account'];
		List<User> standardUsers = [SELECT Id FROM User WHERE UserName = 'usCanadaUser@example.com'];
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
			opps[0].Id => buildOppWithStageNumber(
				opps[0].Id,
				Utility.PROSPECTING,
				Utility.PROSPECTING_STAGE_NUMBER,
				null,
				null
			)
		};
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>{
			opps[0].Id => buildOppWithStageNumber(
				opps[0].Id,
				Utility.COMMIT_STAGE,
				Utility.COMMIT_STAGE_NUMBER,
				partnerAccounts[0].Id,
				null
			)
		};

		System.runAs(standardUsers[0]) {
			Test.startTest();
			OpportunityTriggerUtility.processOppPartners(oppsMap, oldMap);
			Test.stopTest();
		}

		Assert.isTrue(
			oppsMap.get(opps[0].Id).getErrors().isEmpty(),
			'Commit is listed in Stage_Numbers_to_Exclude_for_partner_validation => no validation'
		);
	}

	@IsTest
	static void testgetStageNumbersToExclude_ifNotNull_returnsValuesAccurately() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String oppStagesToExclude = System.Label.Stage_Numbers_to_Exclude_for_partner_validation;
			for (Integer eachOppStageNumber : OpportunityTriggerUtility.getStageNumbersToExclude()) {
				System.assertEquals(
					true,
					oppStagesToExclude.contains(String.valueOf(eachOppStageNumber))
				);
			}
		}
	}
	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeInsert_withEndUserAccount_populatesTerritoryFromEndUserAccount() {
		List<Account> accounts = [
			SELECT Id, Name, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name IN ('Test Account', 'Test End User Account')
		];
		Account testAccount = accounts[0].Name == 'Test Account' ? accounts[0] : accounts[1];
		Account endUserAccount = accounts[0].Name == 'Test End User Account'
			? accounts[0]
			: accounts[1];

		Opportunity newOpp = TestFactory.buildOpportunity(
			'Territory Test - Insert with End User',
			Date.today().addDays(30),
			Utility.PROSPECTING,
			testAccount.Id
		);
		newOpp.End_User_Account__c = endUserAccount.Id;
		newOpp.Type = 'Add-On';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ newOpp },
				null
			);
			Test.stopTest();
		}

		Assert.areEqual(
			endUserAccount.Primary_Sales_Territory_Id__c,
			newOpp.Territory2Id,
			'Territory should be populated from End User Account Primary Sales Territory Id on insert.'
		);
	}

	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeInsert_mspAccountEqualsEndUserAccount_populatesTerritory() {
		Account mspAccount = [
			SELECT Id, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test End User Account'
			LIMIT 1
		];

		Opportunity newOpp = TestFactory.buildOpportunity(
			'Territory Test - MSP Same Account and End User',
			Date.today().addDays(30),
			Utility.PROSPECTING,
			mspAccount.Id
		);
		newOpp.End_User_Account__c = mspAccount.Id;
		newOpp.Type = 'Add-On';
		newOpp.Business_Motion__c = 'MSP';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ newOpp },
				null
			);
			Test.stopTest();
		}

		Assert.areEqual(
			mspAccount.Primary_Sales_Territory_Id__c,
			newOpp.Territory2Id,
			'Territory should be populated when Account and End User Account are the same (MSP scenario).'
		);
	}

	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeInsert_withoutEndUserAccount_populatesTerritoryFromAccount() {
		Account testAccount = [
			SELECT Id, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];

		Opportunity newOpp = TestFactory.buildOpportunity(
			'Territory Test - Insert without End User',
			Date.today().addDays(30),
			Utility.PROSPECTING,
			testAccount.Id
		);
		newOpp.End_User_Account__c = null;
		newOpp.Type = 'New';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ newOpp },
				null
			);
			Test.stopTest();
		}

		Assert.areEqual(
			testAccount.Primary_Sales_Territory_Id__c,
			newOpp.Territory2Id,
			'Territory should be populated from Account Primary Sales Territory Id when End User Account is null on insert.'
		);
	}

	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeInsert_splitType_doesNotPopulateTerritory() {
		Account testAccount = [
			SELECT Id, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		];

		Opportunity newOpp = TestFactory.buildOpportunity(
			'Territory Test - Insert Split',
			Date.today().addDays(30),
			Utility.PROSPECTING,
			testAccount.Id
		);
		newOpp.Type = 'Split';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ newOpp },
				null
			);
			Test.stopTest();
		}

		Assert.isNull(
			newOpp.Territory2Id,
			'Split type opportunities should not have Territory populated on insert.'
		);
	}

	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeUpdate_endUserAccountChangedToExisting_updatesTerritoryFromEndUserAccount() {
		Account endUserAccount = [
			SELECT Id, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test End User Account2'
			LIMIT 1
		];
		Opportunity opp = [
			SELECT Id, AccountId, End_User_Account__c, Territory2Id, Type
			FROM Opportunity
			WHERE Name = 'Test Opportunity - Territory Assignment-Account'
			LIMIT 1
		];

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
			opp.Id => new Opportunity(
				Id = opp.Id,
				AccountId = opp.AccountId,
				End_User_Account__c = opp.End_User_Account__c,
				Territory2Id = opp.Territory2Id
			)
		};

		opp.End_User_Account__c = endUserAccount.Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ opp },
				oldMap
			);
			Test.stopTest();
		}

		Assert.areEqual(
			endUserAccount.Primary_Sales_Territory_Id__c,
			opp.Territory2Id,
			'Territory should be updated from End User Account when End User Account is changed on update.'
		);
	}

	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeUpdate_endUserAccountCleared_updatesTerritoryFromAccount() {
		Opportunity opp = [
			SELECT Id, AccountId, End_User_Account__c, Territory2Id, Type
			FROM Opportunity
			WHERE Name = 'Test Opportunity - Territory Assignment-End User'
			LIMIT 1
		];
		Account oppAccount = [
			SELECT Id, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Id = :opp.AccountId
			LIMIT 1
		];

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
			opp.Id => new Opportunity(
				Id = opp.Id,
				AccountId = opp.AccountId,
				End_User_Account__c = opp.End_User_Account__c,
				Territory2Id = opp.Territory2Id
			)
		};

		opp.End_User_Account__c = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ opp },
				oldMap
			);
			Test.stopTest();
		}

		Assert.areEqual(
			oppAccount.Primary_Sales_Territory_Id__c,
			opp.Territory2Id,
			'Territory should be updated from Account when End User Account is cleared on update.'
		);
	}

	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeUpdate_accountIdChanged_updatesTerritoryFromNewAccount() {
		Account newAccount = [
			SELECT Id, Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Downstream Partner Account'
			LIMIT 1
		];
		Opportunity opp = [
			SELECT Id, AccountId, End_User_Account__c, Territory2Id, Type
			FROM Opportunity
			WHERE Name = 'Test Opportunity - Territory Assignment-Account'
			LIMIT 1
		];

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
			opp.Id => new Opportunity(
				Id = opp.Id,
				AccountId = opp.AccountId,
				End_User_Account__c = opp.End_User_Account__c,
				Territory2Id = opp.Territory2Id
			)
		};

		opp.AccountId = newAccount.Id;
		opp.End_User_Account__c = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ opp },
				oldMap
			);
			Test.stopTest();
		}

		Assert.areEqual(
			newAccount.Primary_Sales_Territory_Id__c,
			opp.Territory2Id,
			'Territory should be updated from new Account when Account is changed on update.'
		);
	}

	@IsTest
	static void testUpdatePrimarySalesTerritoryId_beforeUpdate_splitType_doesNotUpdateTerritory() {
		Opportunity opp = [
			SELECT Id, AccountId, End_User_Account__c, Territory2Id, Type
			FROM Opportunity
			WHERE Name = 'Test Opportunity - Territory Assignment-End User'
			LIMIT 1
		];
		opp.Type = 'Split';

		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{
			opp.Id => new Opportunity(
				Id = opp.Id,
				AccountId = opp.AccountId,
				End_User_Account__c = opp.End_User_Account__c,
				Territory2Id = opp.Territory2Id,
				Type = 'Add-On'
			)
		};

		opp.End_User_Account__c = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			OpportunityTriggerUtility.updatePrimarySalesTerritoryId(
				new List<Opportunity>{ opp },
				oldMap
			);
			Test.stopTest();
		}

		Assert.isNull(
			opp.Territory2Id,
			'Split type opportunities should not have Territory updated even when End User Account or Account changes.'
		);
	}

	@IsTest
	static void testSyncOriginalTerritory2Id_openStage_updatesOriginalToMatchTerritory2Id() {
		Id territory1Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;
		Id territory2Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Downstream Partner Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;

		Opportunity seeded = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

		Opportunity oldOpp = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.PROSPECTING,
			Territory2Id = territory1Id
		);
		Opportunity newOpp = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.PROSPECTING,
			Territory2Id = territory2Id,
			Original_Territory2_ID__c = 'stale-should-be-replaced'
		);
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>{ oldOpp.Id => oldOpp };

		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityTriggerUtility.syncOriginalTerritory2Id(
				new List<Opportunity>{ newOpp },
				oldMap
			);
		}

		Assert.areEqual(
			String.valueOf(territory2Id),
			newOpp.Original_Territory2_ID__c,
			'Open Opportunity: Original_Territory2_ID__c should track Territory2Id.'
		);
	}

	@IsTest
	static void testSyncOriginalTerritory2Id_closedWonOrFailed_doesNotUpdateOriginal() {
		Id territory1Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;
		Id territory2Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Downstream Partner Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;

		Opportunity seeded = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

		final String frozenOriginal = 'frozen-after-close';

		Opportunity oldClosedWon = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.CLOSED_WON,
			Territory2Id = territory1Id
		);
		Opportunity newClosedWon = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.CLOSED_WON,
			Territory2Id = territory2Id,
			Original_Territory2_ID__c = frozenOriginal
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityTriggerUtility.syncOriginalTerritory2Id(
				new List<Opportunity>{ newClosedWon },
				new Map<Id, Opportunity>{ oldClosedWon.Id => oldClosedWon }
			);
		}
		Assert.areEqual(
			frozenOriginal,
			newClosedWon.Original_Territory2_ID__c,
			'Already Closed Won: Original_Territory2_ID__c must not change when Territory2Id changes.'
		);

		Opportunity oldFailed = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.FAILED,
			Territory2Id = territory1Id
		);
		Opportunity newFailed = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.FAILED,
			Territory2Id = territory2Id,
			Original_Territory2_ID__c = frozenOriginal
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityTriggerUtility.syncOriginalTerritory2Id(
				new List<Opportunity>{ newFailed },
				new Map<Id, Opportunity>{ oldFailed.Id => oldFailed }
			);
		}
		Assert.areEqual(
			frozenOriginal,
			newFailed.Original_Territory2_ID__c,
			'Already Failed: Original_Territory2_ID__c must not change when Territory2Id changes.'
		);
	}

	@IsTest
	static void testSyncOriginalTerritory2Id_closingWithTerritoryChange_updatesOriginalToFinalTerritory2Id() {
		Id territory1Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;
		Id territory2Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Downstream Partner Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;

		Opportunity seeded = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

		final String originalBeforeClose = String.valueOf(territory1Id);

		Opportunity oldOpp = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.PROSPECTING,
			Territory2Id = territory1Id
		);
		Opportunity newOpp = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.CLOSED_WON,
			Territory2Id = territory2Id,
			Original_Territory2_ID__c = originalBeforeClose
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityTriggerUtility.syncOriginalTerritory2Id(
				new List<Opportunity>{ newOpp },
				new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
			);
		}

		Assert.areEqual(
			String.valueOf(territory2Id),
			newOpp.Original_Territory2_ID__c,
			'Transition to Closed Won with Territory2Id change: Original_Territory2_ID__c should match final Territory2Id.'
		);
	}

	@IsTest
	static void testSyncOriginalTerritory2Id_closingWithoutTerritoryChange_updatesOriginalToTerritory2Id() {
		Id territory1Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;

		Opportunity seeded = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];

		final String staleOriginal = 'stale-before-close';

		Opportunity oldOpp = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.PROSPECTING,
			Territory2Id = territory1Id
		);
		Opportunity newOpp = new Opportunity(
			Id = seeded.Id,
			StageName = Utility.CLOSED_WON,
			Territory2Id = territory1Id,
			Original_Territory2_ID__c = staleOriginal
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityTriggerUtility.syncOriginalTerritory2Id(
				new List<Opportunity>{ newOpp },
				new Map<Id, Opportunity>{ oldOpp.Id => oldOpp }
			);
		}

		Assert.areEqual(
			String.valueOf(territory1Id),
			newOpp.Original_Territory2_ID__c,
			'Transition to Closed Won: Original_Territory2_ID__c should align to Territory2Id even when territory did not change.'
		);
	}

	@IsTest
	static void testSyncOriginalTerritory2Id_openStage_territoryUnchanged_originalOutOfSync_updatesOriginal() {
		Id territory1Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;

		List<Opportunity> opps = [
			SELECT Id, StageName, Territory2Id, Original_Territory2_ID__c
			FROM Opportunity
			WHERE Name = 'Test Opportunity'
			LIMIT 1
		];
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));

		for (Opportunity opp : opps) {
			opp.StageName = Utility.PROSPECTING;
			opp.Territory2Id = territory1Id;
			opp.Original_Territory2_ID__c = null;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityTriggerUtility.syncOriginalTerritory2Id(opps, oldMap);
		}

		Assert.areEqual(
			String.valueOf(territory1Id),
			opps[0].Original_Territory2_ID__c,
			'Open Opportunity: Original_Territory2_ID__c should match Territory2Id when blank even if Territory2Id did not change.'
		);
	}

	@IsTest
	static void testSyncOriginalTerritory2Id_openStage_territoryUnchanged_originalInSync_unchanged() {
		Id territory1Id = [
			SELECT Primary_Sales_Territory_Id__c
			FROM Account
			WHERE Name = 'Test Account'
			LIMIT 1
		]
		.Primary_Sales_Territory_Id__c;

		List<Opportunity> opps = [
			SELECT Id, StageName, Territory2Id, Original_Territory2_ID__c
			FROM Opportunity
			WHERE Name = 'Test Opportunity'
			LIMIT 1
		];
		Map<Id, Opportunity> oldMap = new Map<Id, Opportunity>(opps.deepClone(true, true, true));

		final String alreadySynced = String.valueOf(territory1Id);

		for (Opportunity opp : opps) {
			opp.StageName = Utility.PROSPECTING;
			opp.Territory2Id = territory1Id;
			opp.Original_Territory2_ID__c = alreadySynced;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			OpportunityTriggerUtility.syncOriginalTerritory2Id(opps, oldMap);
		}

		Assert.areEqual(
			alreadySynced,
			opps[0].Original_Territory2_ID__c,
			'Open Opportunity: Original_Territory2_ID__c should stay when it already matches Territory2Id and territory did not change.'
		);
	}

	private static Opportunity buildOppWithStageNumber(
		Id oppId,
		String stageName,
		Integer stageNumber,
		Id partnerAccountId,
		Id downstreamPartnerAccountId
	) {
		Map<String, Object> oppFields = new Map<String, Object>{
			'Id' => oppId,
			'StageName' => stageName,
			'StageNumber__c' => stageNumber,
			'PrimaryQuotePartner__c' => partnerAccountId,
			'PrimaryQuoteDownstreamPartner__c' => downstreamPartnerAccountId
		};
		return (Opportunity) JSON.deserialize(JSON.serialize(oppFields), Opportunity.class);
	}
}