/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for POCRequestTriggerHandler
 * @Date: 2018-03-15
 * @Author: Cumulus Vision
 * @Request: TAN-487
 * Modified  ModifiedDate   Description
 * TAN-551   2018-04-26     Updated test class to trigger process builder and avoid failure
 * TAN-588   2018-05-22     Updated test class to trigger process builder and avoid failure
 * TAN-621   2018-07-20     Updated test method to support for addition of "OpportunitLineItem" record.
 * TAN-890   2020-07-15     Fixed test class issue due to update in the POC_Request's License_Type__c field's definition
 * TAN-1190  2021-04-13     Updated to increase coverage and avoid failure
 * TAN-1318  2021-10-01     Added new method createNewPOCOppRequirement for New changes
 * SS-7583	 2024-03-21     Removing BoomiRestService code references
 * SS-12077  2025-11-13     Updated test class with best practices for trigger framework
 * SS-10294  2026-02-12     Remove TAM_Assigned_GS__c reference	from the test class
 */
@IsTest
private class POCRequestTriggerHandlerTest {
	static final String RESTRICTED_COUNTRY = 'France';
	static final String COUNTRY_CODE = 'FR';
	static final String NON_RESTRICTED_COUNTRY = 'United States';
	static final String APPROVED_ISR_COUNTRY = 'India';

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'LeadTriggerHandler',
				'QuoteCPQTriggerHandler',
				'OpportunityTeamMemberTriggerHandler',
				'OpportunityPartnerTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Test Account');
			acc.Type = 'Partner';
			acc.Country_Exception_Approved__c = true;
			acc.Country_Restrictions__c = 'Unrestricted';
			insert acc;

			Id pricebookId = Test.getStandardPricebookId();

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp1',
				Date.today() + 30,
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Pricebook2Id = pricebookId;
			opp.Seats__c = 1000;
			opp.Amount = 1000;
			insert opp;

			Country_For_Export__c countryExport = TestFactory.buildCountryForExport('France', 'FR');
			insert countryExport;

			List<String> pocSKUs = new List<String>();
			pocSKUs.addAll(POCRequestOpportunityUtility.POC_SKUS);
			List<Product2> products = new List<Product2>();
			List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
			for (Integer i = 0; i < pocSKUs.size(); i++) {
				Product2 prod = TestFactory.buildProduct(
					'Tanium ' + pocSKUs + ' - Subscription',
					pocSKUs[i]
				);
				products.add(prod);
			}
			insert products;
			for (Product2 eachProduct : [SELECT Id FROM Product2 WHERE ID IN :products]) {
				PricebookEntry priceBookEntry1 = TestFactory.buildPricebookEntry(
					eachProduct.Id,
					10000,
					pricebookId
				);
				PricebookEntry priceBookEntry2 = TestFactory.buildPricebookEntry(
					eachProduct.Id,
					12000,
					System.Label.POC_PriceBookId
				);
				pricebookEntries.add(priceBookEntry1);
				pricebookEntries.add(priceBookEntry2);
			}
			insert pricebookEntries;

			POC_Request__c pocRequest = TestFactory.buildPOCRequest(opp);
			pocRequest.Approved__c = true;
			pocRequest.Deployment_Country__c = 'Canada';
			insert pocRequest;
			Account_Support_Request__c accountSupportRequest = TestFactory.buildAccountSupportRequest(
				acc.Id
			);
			insert accountSupportRequest;
		}
	}

	@IsTest
	static void testCreateNewPOCOppRequirement() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [
				SELECT Id, Name, CloseDate, StageName, AccountId, Amount, Seats__c, Pricebook2Id
				FROM Opportunity
				LIMIT 1
			];
			POC_Request__c pocr1 = TestFactory.buildPOCRequest(opp);
			POC_Request__c pocr2 = TestFactory.buildPOCRequest(opp);
			pocr2.POC_Type__c = 'Extension';
			POC_Request__c poc3 = TestFactory.buildPOCRequest(opp);
			poc3.TAN_320_S_Copper_Quantity__c = '0';
			poc3.TAN_320_S_Fiber_Quantity__c = '0';
			poc3.TAN_420_M_Fiber_Quantity__c = '0';
			poc3.TAN_420_M_Copper_Quantity__c = '0';
			poc3.TAN_220_DEV_Copper_Quantity__c = '0';
			poc3.TAN_220_DEV_Fiber_Quantity__c = '0';
			poc3.TAN_720_L_Fiber_Quantity__c = '0';
			poc3.TAN_720_L_Copper_Quantity__c = '0';
			poc3.TAN_920_XL_Copper_Quantity__c = '0';
			poc3.TAN_920_XL_Fiber_Quantity__c = '0';
			poc3.TAN_VIRTUAL_Quantity__c = '0';
			poc3.TAN_CLOUD_Quantity__c = '0';
			poc3.TAN_L_730_CP_Quantity__c = '0';
			poc3.TAN_L_735_FB_Quantity__c = '0';
			poc3.TAN_M_430_CP_Quantity__c = '0';
			poc3.TAN_M_435_FB_Quantity__c = '0';
			poc3.TAN_S_330_CP_Quantity__c = '0';
			poc3.TAN_S_335_FB_Quantity__c = '0';
			poc3.TAN_XL_930_CP_Quantity__c = '0';
			poc3.TAN_XL_935_FB_Quantity__c = '0';

			List<POC_Request__c> pocList = new List<POC_Request__c>{ pocr1, pocr2, poc3 };
			insert pocList;

			TriggerHandler.resetRecursionLimits();

			Test.startTest();
			for (POC_Request__c poc : pocList) {
				poc.Approved__c = true;
			}
			update pocList;
			Test.stopTest();

			List<Opportunity> pocOpps = [
				SELECT ID, Parent_Opportunity__c
				FROM Opportunity
				WHERE AccountID = :opp.AccountId AND StageName = :Utility.POC AND Type = 'POC'
			];
			Assert.areEqual(
				1,
				pocOpps.size(),
				'Opportunity is not created for pocr2 and pocr3 POC Request, because in pocr2 POC_Type__c is Extension(not New) and in pocr3 All Quantities are zero value.'
			);
		}
	}

	@IsTest
	static void testOnCreateUpdatePOC_WhenApprovedISRRecordNotExistOnAccount_ShowErrorMessage() {
		String actualErrorMessage = '';

		System.runAs(TestUserFactory.getAdminUser()) {
			POC_Request__c pocRequest = [SELECT Deployment_Country__c FROM POC_Request__c LIMIT 1];

			Test.startTest();
			try {
				pocRequest.Deployment_Country__c = RESTRICTED_COUNTRY;
				update pocRequest;
			} catch (Exception ex) {
				actualErrorMessage = ex.getMessage();
			}
			Test.stopTest();
		}

		Assert.isTrue(
			actualErrorMessage.containsIgnoreCase(label.POC_Request_Restricted_Country_Validation_Msg)
		);
	}

	@IsTest
	static void testOnCreateUpdatePOC_WhenApprovedISRRecordExistOnAccount_DontShowErrorMessage() {
		String actualErrorMessage = 'NoError';
		POC_Request__c pocRequest = [SELECT Deployment_Country__c FROM POC_Request__c LIMIT 1];
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			try {
				pocRequest.Deployment_Country__c = NON_RESTRICTED_COUNTRY;
				update pocRequest;
			} catch (Exception ex) {
				actualErrorMessage = ex.getMessage();
			}
			Test.stopTest();
			Assert.areEqual('NoError', actualErrorMessage);
		}
	}

	@IsTest
	static void testOnCreateUpdatePOC_WhenApprovedISRRecordExistOnAccountButNotForPOCsCountry_ShowErrorMessage() {
		String actualErrorMessage = '';

		System.runAs(TestUserFactory.getAdminUser()) {
			Opportunity opp = [
				SELECT AccountId, Amount, Closedate, Seats__c, StageName
				FROM Opportunity
				LIMIT 1
			];
			Account_Support_Request__c accountSupportRequest = TestFactory.buildAccountSupportRequest(
				opp.AccountID
			);
			accountSupportRequest.Status__c = 'Approved';
			accountSupportRequest.Exception_Country__c = APPROVED_ISR_COUNTRY;
			insert accountSupportRequest;

			POC_Request__c pocRequest = TestFactory.buildPOCRequest(opp);
			pocRequest.Deployment_Country__c = APPROVED_ISR_COUNTRY;
			insert pocRequest;

			TriggerHandler.resetRecursionLimits();

			Test.startTest();
			try {
				pocRequest.Deployment_Country__c = RESTRICTED_COUNTRY;
				update pocRequest;
			} catch (Exception ex) {
				actualErrorMessage = ex.getMessage();
			}
			Test.stopTest();
		}

		Assert.isTrue(
			actualErrorMessage.containsIgnoreCase(label.POC_Request_Restricted_Country_Validation_Msg)
		);
	}
}