/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CongaService class.
 * @Date: 2022-03-28
 * @Author: Tanium Dev Team
 * @Request:
 * RequestId  ModifiedDate  Description
 * SS-7583    2024-03-21    Removing BoomiRestService code references
 * SS-8934    2024-12-03    Create user interface in LWC.
 * SS-10174   2025-07-23    Click Through Template name change and whitespace cleanup.
 */

@IsTest
private class CongaServiceTest {
	private static User dealDeskUser;
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();
		User adminUser = TestUserFactory.getAdminUser();
		TestingUtility.assignPermissionSet(adminUser.Id, 'BillingScheduleConfigurator');
		TestingUtility.assignPackageLicense(adminUser.Id, 'Apttus');

		System.runAs(adminUser) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today() + 30,
				Utility.PROSPECTING,
				acct.Id
			);
			opp.Amount = 5000;
			opp.First_Interaction_Date__c = Date.today() - 60;
			opp.BillingScheduleTotalAmountNew__c = opp.Amount;
			insert opp;

			SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acct.Id,
				'Draft',
				null,
				null,
				null,
				null
			);
			quote.Unlock_Quote__c = false;
			quote.SBQQ__Primary__c = true;
			insert quote;

			Apttus__APTS_Template__c templateEULA = new Apttus__APTS_Template__c(
				Name = CongaService.TEMPLATE_EULA
			);
			Apttus__APTS_Template__c templateTaaS = new Apttus__APTS_Template__c(
				Name = CongaService.TEMPLATE_TAAS
			);
			insert new List<SObject>{ templateTaaS, templateEULA };
		}
	}

	@IsTest
	static void getOppDetails_StageNameNotClosedWon_returnsAgreementNotCreatedMsg() {
		CongaService.OpportunityDetails oppDetails;
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			oppDetails = CongaService.getOppDetails(opp.Id);
			Test.stopTest();
		}
		Assert.isTrue(oppDetails?.errorMessage?.contains(Label.CongaAgreementClosedWonError));
	}

	@IsTest
	static void getOppDetails_AgreementTypeNotClickThru_returnsAgreementNotCreatedMsg() {
		CongaService.OpportunityDetails oppDetails;

		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

		System.runAs(getDealDeskUser()) {
			opp.StageName = Utility.CLOSED_WON;
			opp.Customer_Agreement_Type_Required__c = '';
			update opp;

			Test.startTest();
			oppDetails = CongaService.getOppDetails(opp.Id);
			Test.stopTest();
		}

		Assert.isTrue(oppDetails?.errorMessage?.contains(Label.CongaAgreementClickThruError));
	}

	@IsTest
	static void getOppDetails_UserDoesNotHaveApttusLicense_returnsErrorMsgInformingUserAboutMissingLicense() {
		CongaService.OpportunityDetails oppDetails;

		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		User dealDeskUser = getDealDeskUser();
		TestingUtility.removePackageLicense(dealDeskUser.Id, TestUserFactory.CONGA_PACKAGE_NAMESPACE);

		System.runAs(dealDeskUser) {
			oppDetails = CongaService.getOppDetails(opp.Id);

			Assert.isTrue(oppDetails?.errorMessage?.contains('license'));
		}
	}

	@IsTest
	static void getOppDetails_WhenOpportunityIdIsFake_ReturnsDMLError() {
		CongaService.OpportunityDetails oppDetails;
		Id oppId = '0067V00001ABCXYZBA';

		System.runAs(getDealDeskUser()) {
			Test.startTest();
			oppDetails = CongaService.getOppDetails(oppId);
			Test.stopTest();
		}

		System.assertEquals(true, oppDetails?.errorMessage?.containsIgnoreCase('no rows'));
	}

	@IsTest
	static void createAgreement_AgreementTypeClickThruStageClosedWon_returnsSuccessMsgAndCreatesAgreementWithDefaultAgreementOwner() {
		CongaService.OpportunityDetails oppDetails;
		CongaService.SaveResult createAgreementResult;
		Opportunity opp;

		System.runAs(getDealDeskUser()) {
			opp = [
				SELECT
					Id,
					AccountId,
					Account.Name,
					CloseDate,
					Contract_Owner__c,
					Customer_Agreement_Type_Required__c,
					StageName
				FROM Opportunity
				WHERE Name = 'Test Opportunity'
			];
			opp.Customer_Agreement_Type_Required__c = CongaService.AGREEMENT_TYPE_CLICK_THRU;
			opp.StageName = Utility.CLOSED_WON;
			opp.Contract_Owner__c = null;
			update opp;

			Test.startTest();
			oppDetails = CongaService.getOppDetails(opp.Id);
			createAgreementResult = CongaService.createAgreement(
				JSON.serialize(oppDetails),
				CongaService.TEMPLATE_EULA
			);
			Test.stopTest();
		}

		Apttus__APTS_Agreement__c agreement = [
			SELECT
				ID,
				Name,
				Apttus_Approval__Approval_Status__c,
				Agreement_Effective_Date__c,
				Agreement_Owner__c,
				Agreement_Owner__r.Alias,
				Apttus__Account__c,
				Apttus_ff_Clause_Certification__c,
				Apttus__Related_Opportunity__c,
				Apttus__Requestor__c,
				Apttus__Owner_Expiration_Notice__c,
				Apttus__Workflow_Trigger_Viewed_Final__c,
				Evergreen__c,
				Include_License_Schedule__c,
				MLA_Template_Type__c,
				Payment_Terms__c,
				RecordTypeId,
				Tanium_Legal_Name__c
			FROM Apttus__APTS_Agreement__c agreement
			WHERE Apttus__Related_Opportunity__c = :opp.Id
			LIMIT 1
		];
		System.assertEquals(true, createAgreementResult.isSuccess, 'Agreement created successfully');
		System.assertNotEquals(null, agreement);
		System.assertEquals('Approved', agreement.Apttus_Approval__Approval_Status__c);
		System.assertEquals(opp.Account.Name + ' Click Thru MLA', agreement.Name);
		System.assertEquals(null, opp.Contract_Owner__c);
		if (Label.CongaDefaultAgreementOwnerAlias != null) {
			System.assertEquals(
				Label.CongaDefaultAgreementOwnerAlias,
				agreement.Agreement_Owner__r.Alias
			);
		}
		System.assertEquals(opp.AccountId, agreement.Apttus__Account__c);
		System.assertEquals('Yes', agreement.Apttus_ff_Clause_Certification__c);
		System.assertEquals(opp.Id, agreement.Apttus__Related_Opportunity__c);
		System.assertEquals(agreement.Agreement_Owner__c, agreement.Apttus__Requestor__c);
		System.assertEquals(null, agreement.Apttus__Owner_Expiration_Notice__c);
		System.assertEquals(false, agreement.Apttus__Workflow_Trigger_Viewed_Final__c);
		System.assertEquals(true, agreement.Evergreen__c);
		System.assertEquals('No', agreement.Include_License_Schedule__c);
		System.assertEquals('Click Thru', agreement.MLA_Template_Type__c);
		System.assertEquals(true, agreement.Payment_Terms__c);
		System.assertEquals(CongaService.MLA_RECORDTYPE_ID, agreement.RecordTypeId);
		System.assertEquals('Tanium Inc.', agreement.Tanium_Legal_Name__c);
	}

	@IsTest
	static void createAgreement_AgreementTypeClickThruStageClosedWon_AccountisCreated() {
		CongaService.OpportunityDetails oppDetails;
		CongaService.SaveResult createAgreementResult;
		Opportunity opp;

		System.runAs(getDealDeskUser()) {
			opp = [
				SELECT
					Id,
					AccountId,
					Account.Name,
					CloseDate,
					Contract_Owner__c,
					Customer_Agreement_Type_Required__c,
					StageName
				FROM Opportunity
				WHERE Name = 'Test Opportunity'
			];
			opp.Customer_Agreement_Type_Required__c = CongaService.AGREEMENT_TYPE_CLICK_THRU;
			opp.StageName = Utility.CLOSED_WON;
			opp.Contract_Owner__c = null;
			update opp;

			Test.startTest();
			oppDetails = CongaService.getOppDetails(opp.Id);
			createAgreementResult = CongaService.createAgreement(
				JSON.serialize(oppDetails),
				CongaService.TEMPLATE_EULA
			);
			Test.stopTest();
		}

		Apttus__APTS_Agreement__c agreement = [
			SELECT ID, Apttus__Account__c, Apttus_Approval__Approval_Status__c
			FROM Apttus__APTS_Agreement__c agreement
			WHERE Apttus__Related_Opportunity__c = :opp.Id
			LIMIT 1
		];

		Account acc = [SELECT Id, Payment_Terms__c FROM Account WHERE Id = :opp.accountId];

		System.assertEquals(acc.Payment_Terms__c, 'Net 30');
		System.assertEquals(acc.Id, agreement.Apttus__Account__c);
		System.assertEquals('Approved', agreement.Apttus_Approval__Approval_Status__c);
	}

	@IsTest
	static void createAgreement_AgreementTypeClickThruStageClosedWon_returnsSuccessMsgAndCreatesAgreementWithAgreementOwnerSameAsContractOwner() {
		CongaService.OpportunityDetails oppDetails;
		CongaService.SaveResult createAgreementResult;
		Opportunity opp;

		System.runAs(getDealDeskUser()) {
			opp = [
				SELECT
					Id,
					AccountId,
					Account.Name,
					CloseDate,
					Contract_Owner__c,
					Customer_Agreement_Type_Required__c,
					StageName
				FROM Opportunity
				WHERE Name = 'Test Opportunity'
			];
			opp.Customer_Agreement_Type_Required__c = CongaService.AGREEMENT_TYPE_CLICK_THRU;
			opp.StageName = Utility.CLOSED_WON;
			opp.Contract_Owner__c = UserInfo.getUserId();
			opp.TaaS_Opportunity__c = 'Yes';
			update opp;

			Test.startTest();
			oppDetails = CongaService.getOppDetails(opp.Id);
			createAgreementResult = CongaService.createAgreement(
				JSON.serialize(oppDetails),
				CongaService.TEMPLATE_TAAS
			);
			Test.stopTest();
		}

		Apttus__APTS_Agreement__c agreement = [
			SELECT
				ID,
				Name,
				Apttus_Approval__Approval_Status__c,
				Agreement_Effective_Date__c,
				Agreement_Owner__c,
				Agreement_Owner__r.Alias,
				Apttus__Account__c,
				Apttus_ff_Clause_Certification__c,
				Apttus__Related_Opportunity__c,
				Apttus__Requestor__c,
				Apttus__Owner_Expiration_Notice__c,
				Apttus__Workflow_Trigger_Viewed_Final__c,
				Evergreen__c,
				Include_License_Schedule__c,
				MLA_Template_Type__c,
				Payment_Terms__c,
				RecordTypeId,
				Tanium_Legal_Name__c
			FROM Apttus__APTS_Agreement__c agreement
			WHERE Apttus__Related_Opportunity__c = :opp.Id
			LIMIT 1
		];
		System.assertEquals(true, createAgreementResult.isSuccess, 'Agreement created successfully');
		System.assertNotEquals(null, agreement);
		System.assertEquals('Approved', agreement.Apttus_Approval__Approval_Status__c);
		System.assertEquals(opp.Account.Name + ' Click Thru MLA', agreement.Name);
		System.assertNotEquals(null, opp.Contract_Owner__c);
		System.assertEquals(opp.AccountId, agreement.Apttus__Account__c);
		System.assertEquals('Yes', agreement.Apttus_ff_Clause_Certification__c);
		System.assertEquals(opp.Id, agreement.Apttus__Related_Opportunity__c);
		System.assertEquals(agreement.Agreement_Owner__c, agreement.Apttus__Requestor__c);
		System.assertEquals(opp.Contract_Owner__c, agreement.Agreement_Owner__c);
		System.assertEquals(opp.AccountId, agreement.Apttus__Account__c);
		System.assertEquals(null, agreement.Apttus__Owner_Expiration_Notice__c);
		System.assertEquals(false, agreement.Apttus__Workflow_Trigger_Viewed_Final__c);
		System.assertEquals(true, agreement.Evergreen__c);
		System.assertEquals('No', agreement.Include_License_Schedule__c);
		System.assertEquals('Click Thru', agreement.MLA_Template_Type__c);
		System.assertEquals(true, agreement.Payment_Terms__c);
		System.assertEquals(CongaService.MLA_RECORDTYPE_ID, agreement.RecordTypeId);
		System.assertEquals('Tanium Inc.', agreement.Tanium_Legal_Name__c);
	}

	@IsTest
	static void createAgreement_WhenExceptionOccur_ReturnErrorMessage() {
		CongaService.OpportunityDetails oppDetails;
		CongaService.SaveResult createAgreementResult;
		Opportunity opp;

		System.runAs(CongaServiceTest.getDealDeskUser()) {
			opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity'];

			Test.startTest();
			oppDetails = CongaService.getOppDetails(opp.Id);
			createAgreementResult = CongaService.createAgreement(
				JSON.serialize(oppDetails),
				'test template'
			);
			Test.stopTest();
		}
		Assert.isFalse(createAgreementResult.isSuccess);
		Assert.isTrue(createAgreementResult.errorMessage.contains('no row'));
	}

	@IsTest
	static void createAgreement_WhenInsertAgreementFailed_ReturnErrorMessage() {
		CongaService.OpportunityDetails oppDetails;
		Database.SaveResult createAgreementResult;
		Opportunity opp;

		System.runAs(CongaServiceTest.getDealDeskUser()) {
			opp = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity'];

			Test.startTest();
			oppDetails = CongaService.getOppDetails(opp.Id);
			oppDetails.Id = '0067V00001ABCXYZBA';
			createAgreementResult = CongaService.generateAgreement(oppDetails);
			Test.stopTest();
		}
		Assert.isFalse(createAgreementResult.isSuccess());
	}

	@IsTest
	static void updateClauseAction_WhenAgreementId_UpdatesClauseAction() {
		Opportunity opp = [
			SELECT
				Id,
				AccountId,
				Account.Name,
				CloseDate,
				Contract_Owner__c,
				Customer_Agreement_Type_Required__c,
				StageName,
				TaaS_Opportunity__c
			FROM Opportunity
			LIMIT 1
		];
		Apttus__Agreement_Clause__c clause = new Apttus__Agreement_Clause__c();
		CongaService.OpportunityDetails oppDetails = CongaService.getOppDetails(opp.Id);

		System.runAs(CongaServiceTest.getDealDeskUser()) {
			opp.Customer_Agreement_Type_Required__c = CongaService.AGREEMENT_TYPE_CLICK_THRU;
			opp.StageName = Utility.CLOSED_WON;
			update opp;

			Database.SaveResult agreement = CongaService.generateAgreement(oppDetails);
			clause.Apttus__Agreement__c = agreement.getId();
			insert clause;

			Test.startTest();
			CongaService.updateClauseAction(agreement.getId());
			Test.stopTest();
		}

		clause = [SELECT Id, Apttus__Action__c FROM Apttus__Agreement_Clause__c LIMIT 1];
		System.assertEquals('Final', clause.Apttus__Action__c);
	}

	static User getDealDeskUser() {
		if (dealDeskUser == null) {
			List<User> testUsers = [SELECT Id FROM User WHERE LastName LIKE '%DealDeskUser'];
			if (testUsers.isEmpty()) {
				dealDeskUser = TestUserFactory.createDealDeskUser();
				TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableFlows');
				TestingUtility.assignPermissionSet(dealDeskUser.Id, 'DisableValidationRules');
			} else {
				dealDeskUser = testUsers[0];
			}
		}
		return dealDeskUser;
	}
}