/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test methods for class ServerDeploymentController
 * @Date:     2024-05-01
 * @Author:   Tanium Dev Team
 * ReuqestId  ModifiedDate  Description
 * SS-8070    2024-05-01    Created the class
 * SS-13032   2026-04-27    Modified test class
 * SS-13337   2026-06-04	Added test method testGetCompany_Always_ReturnCompanyName
 * SS-13457   2026-06-16	Updated makeData method
 * SS-13748   2026-08-03    Updated makeData method
 * SS-13814   2026-08-09    Updated makeData method
 */
@IsTest
private class ServerDeploymentControllerTest {
	@TestSetup
	static void makeData() {
		Id accountContractRecTypeId = Utility.getRecordTypeIdByAPIName(
			'Contract',
			'Account_Contracts'
		);
		Id taniumCloudRecTypeId = Utility.getRecordTypeIdByAPIName('Server_Deployment__c', 'TaaS');
		Id pocCloudRecTypeId = Utility.getRecordTypeIdByAPIName(
			'POC_Request__c',
			'Partner_Tanium_Cloud'
		);
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'ContractTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteLineTriggerHandler',
				'QuoteCPQTriggerHandler',
				'POCRequestTriggerHandler',
				'SubscriptionTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			account.Type = 'Prospect';
			insert account;

			Contract contract = new Contract(
				AccountId = account.Id,
				RecordTypeId = accountContractRecTypeId
			);
			insert contract;

			Contact contact = TestFactory.buildContact(account.Id);
			insert contact;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today(),
				Utility.PROSPECTING,
				account.Id
			);
			insert opp;

			List<Product2> products = new List<Product2>();
			products.add(
				new Product2(
					Name = 'Core Product',
					ProductCode = 'Core',
					IsActive = true,
					Family = 'None'
				)
			);
			products.add(
				new Product2(
					Name = 'Discover Product',
					ProductCode = 'Discover',
					IsActive = true,
					Family = 'None'
				)
			);
			insert products;

			List<Module__c> modules = new List<Module__c>();
			modules.add(new Module__c(Name = 'Core', Module_Description__c = 'Core Product'));
			modules.add(new Module__c(Name = 'Discover', Module_Description__c = 'Discover Product'));
			insert modules;

			List<Product_Module__c> productModules = new List<Product_Module__c>();
			productModules.add(
				new Product_Module__c(Product__c = products[0].Id, Module__c = modules[0].Id)
			);
			productModules.add(
				new Product_Module__c(Product__c = products[1].Id, Module__c = modules[1].Id)
			);
			insert productModules;

			SBQQ__Quote__c quote = new SBQQ__Quote__c(
				SBQQ__Opportunity2__c = opp.Id,
				SBQQ__Account__c = account.Id,
				SBQQ__Type__c = 'Quote',
				SBQQ__Primary__c = true,
				SBQQ__PaymentTerms__c = 'Net 30'
			);
			insert quote;
			List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();

			for (Product2 product : products) {
				quoteLines.add(
					new SBQQ__QuoteLine__c(
						SBQQ__Product__c = product.Id,
						SBQQ__Quantity__c = 10,
						SBQQ__Quote__c = quote.Id,
						SBQQ__StartDate__c = System.today().toStartofMonth(),
						SBQQ__EndDate__c = System.today().addMonths(1).toStartofMonth().addDays(-1),
						SBQQ__SubscriptionPricing__c = null,
						SBQQ__NetPrice__c = 1000
					)
				);
			}

			List<SBQQ__Subscription__c> subscriptions = new List<SBQQ__Subscription__c>();
			for (Integer i = 0; i < quoteLines.size(); i++) {
				subscriptions.add(buildSubscription(account.Id, products[i].Id, 100, quoteLines[i].Id));
			}
			insert subscriptions;

			Account_Entitlements__c accountEntitlement = new Account_Entitlements__c(
				Account__c = account.Id,
				Product__c = products[0].Id,
				Start_Date__c = System.today().addDays(-10),
				End_Date__c = System.today().addDays(10)
			);
			insert accountEntitlement;

			List<Server_Deployment__c> serverDeployments = new List<Server_Deployment__c>();
			serverDeployments.add(
				new Server_Deployment__c(
					Account__c = account.Id,
					RecordTypeId = taniumCloudRecTypeId,
					Server_Device_Type__c = 'Tanium as a Service',
					Cloud_Provider__c = 'AWS'
				)
			);
			serverDeployments.add(
				new Server_Deployment__c(
					Account__c = account.Id,
					RecordTypeId = taniumCloudRecTypeId,
					Server_Device_Type__c = 'Tanium as a Service',
					Cloud_Provider__c = 'Azure'
				)
			);
			insert serverDeployments;

			List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = new List<Server_Deployment_Subscriptions__c>();
			for (Integer i = 0; i < subscriptions.size(); i++) {
				serverDeploymentSubscriptions.add(
					new Server_Deployment_Subscriptions__c(
						Account__c = account.Id,
						Server_Deployment__c = serverDeployments[0].Id,
						Subscription__c = subscriptions[i].Id,
						Subscription_Quantity__c = subscriptions[i].SBQQ__Quantity__c,
						Account_Entitlement__c = accountEntitlement.Id
					)
				);
			}
			insert serverDeploymentSubscriptions;

			POC_Request__c pocRequest = TestFactory.buildPOCRequest(opp);
			pocRequest.Approved__c = true;
			pocRequest.Deployment_Country__c = 'Canada';
			pocRequest.Server_Deployment__c = serverDeployments[0].Id;
			pocRequest.RecordTypeId = pocCloudRecTypeId;
			pocRequest.POC_Type__c = 'New';
			pocRequest.License_Type__c = 'Production';
			insert pocRequest;

			List<POC_Module__c> pocModules = new List<POC_Module__c>();
			for (Module__c module : modules) {
				pocModules.add(
					new POC_Module__c(POC_Request__c = pocRequest.Id, Module__c = module.Id)
				);
			}
			insert pocModules;
		}
	}

	@IsTest
	static void testPublishPlatformEvent_WhenChildRecords_PublishEvent() {
		Server_Deployment__c serverDeployment = [
			SELECT Id
			FROM Server_Deployment__c
			WHERE Cloud_Provider__c = 'AWS'
			LIMIT 1
		];
		EnhancedReturnType rt;
		String jsonResult;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jsonResult = ServerDeploymentController.generateLicensingEvent(serverDeployment.Id);
			rt = (EnhancedReturnType) JSON.deserialize(jsonResult, EnhancedReturnType.class);
			Test.stopTest();
		}

		Assert.isTrue(rt.retResult);
	}

	@IsTest
	static void testPublishPlatformEvent_WhenNoChildRecords_ReturnNoRecordsFoundMsg() {
		Server_Deployment__c serverDeployment = [
			SELECT Id
			FROM Server_Deployment__c
			WHERE Cloud_Provider__c = 'Azure'
			LIMIT 1
		];
		EnhancedReturnType rt;
		String jsonResult;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jsonResult = ServerDeploymentController.publishLicensingEvent(serverDeployment.Id);
			rt = (EnhancedReturnType) JSON.deserialize(jsonResult, EnhancedReturnType.class);
			Test.stopTest();
		}

		Assert.isTrue(rt.retData == 'There are no Server Deployment Subscription records to publish');
	}

	@IsTest
	static void testGenerateLicensingEvent_WhenPocChildRecords_PublishEvent() {
		POC_Request__c[] pocRequests = [
			SELECT Id, Server_Deployment__c, RecordTypeId, POC_Type__c, Account__r.Type
			FROM POC_Request__c
		];
		EnhancedReturnType rt;
		String[] jsonResult;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jsonResult = ServerDeploymentController.generateLicensingEvent(pocRequests);
			rt = (EnhancedReturnType) JSON.deserialize(jsonResult[0], EnhancedReturnType.class);
			Test.stopTest();
		}

		Assert.isTrue(rt.retResult);
	}

	static SBQQ__Subscription__c buildSubscription(
		Id accountId,
		Id productId,
		Decimal quantity,
		Id quoteLineId
	) {
		SBQQ__Subscription__c subscription = new SBQQ__Subscription__c();
		subscription.SBQQ__Account__c = accountId;
		subscription.SBQQ__Product__c = productId;
		subscription.SBQQ__Quantity__c = quantity;
		subscription.SBQQ__SubscriptionStartDate__c = System.today().addDays(-30);
		subscription.SBQQ__SubscriptionEndDate__c = System.today().addDays(90);
		subscription.Exclude_from_Seats_Roll_up__c = false;
		subscription.SBQQ__QuoteLine__c = quoteLineId;
		return subscription;
	}

	@IsTest
	static void testGetCompany_WhenNoServiceNowOrSalesforceProducts_ReturnTanium() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		String company;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			company = ServerDeploymentController.getCompany(account.Id);
			Test.stopTest();
		}

		Assert.isTrue(company == 'Tanium');
	}
}