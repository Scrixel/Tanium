/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for POCRequest Trigger Utility, part of Trigger Framework
 * @Date: 2026-01-12
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2026-01-12      Initial development
 */
@IsTest
private class POCRequestTriggerUtilityTest {
	private static Id customerOnPremRecTypeId = Utility.getRecordTypeIdByAPIName(
		'POC_Request__c',
		'Standard'
	);
	private static Id customerCloudRecTypeId = Utility.getRecordTypeIdByAPIName(
		'POC_Request__c',
		'TaaS'
	);
	private static Id taniumCloudRecTypeId = Utility.getRecordTypeIdByAPIName(
		'Server_Deployment__c',
		'TaaS'
	);
	private static Id onPremRecTypeId = Utility.getRecordTypeIdByAPIName(
		'Server_Deployment__c',
		'OnPrem'
	);

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'UserTriggerHandler',
				'AccountTriggerHandler',
				'ContractTriggerHandler',
				'OpportunityTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Module__c> modules = new List<Module__c>();
			modules.add(new Module__c(Name = 'Comply', Module_Description__c = 'Comply Product'));
			modules.add(new Module__c(Name = 'Core', Module_Description__c = 'Core Product'));
			modules.add(new Module__c(Name = 'Deploy', Module_Description__c = 'Deploy Product'));
			insert modules;

			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				Date.today(),
				Utility.PROSPECTING,
				acc.Id
			);
			insert opp;

			List<Server_Deployment__c> serverDeployments = new List<Server_Deployment__c>();
			serverDeployments.add(
				new Server_Deployment__c(
					Name = 'On-Prem Server',
					Account__c = acc.Id,
					RecordTypeId = onPremRecTypeId,
					Server_Device_Type__c = 'On-Prem',
					Type__c = 'Lab'
				)
			);
			serverDeployments.add(
				new Server_Deployment__c(
					Account__c = acc.Id,
					RecordTypeId = taniumCloudRecTypeId,
					Server_Device_Type__c = 'Tanium as a Service',
					Cloud_Provider__c = 'Azure',
					Type__c = 'Lab'
				)
			);
			insert serverDeployments;

			List<POC_Request__c> pocRequests = new List<POC_Request__c>();
			pocRequests.add(
				TestFactory.buildPOCRequest(
					acc.Id,
					opp.Id,
					customerOnPremRecTypeId,
					serverDeployments[0].Id
				)
			);
			pocRequests[0].Tanium_Infrastructure__c = 'On-Prem';
			pocRequests[0].Comply__c = true;
			pocRequests[0].Deploy__c = true;

			pocRequests.add(
				TestFactory.buildPOCRequest(
					acc.Id,
					opp.Id,
					customerCloudRecTypeId,
					serverDeployments[1].Id
				)
			);
			pocRequests[1].Core__c = true;
			pocRequests[1].Comply__c = true;
			pocRequests[1].Deploy__c = true;
			pocRequests[1].Business_Justification__c = 'Test Modules';

			pocRequests.add(
				TestFactory.buildPOCRequest(
					acc.Id,
					opp.Id,
					customerCloudRecTypeId,
					serverDeployments[1].Id
				)
			);
			pocRequests[2].Core_Standard__c = true;
			pocRequests[2].Business_Justification__c = 'Test Solutions';
			insert pocRequests;
			update pocRequests;

			List<POC_Module__c> pocModules = new List<POC_Module__c>();
			for (Module__c module : modules) {
				pocModules.add(
					TestFactory.buildPOCModule(pocRequests[1].Account__c, pocRequests[1].Id, module.Id)
				);
				if (module.Name != 'Core') {
					pocModules.add(
						TestFactory.buildPOCModule(
							pocRequests[0].Account__c,
							pocRequests[0].Id,
							module.Id
						)
					);
				}
			}
			insert pocModules;

			List<Product2> products = new List<Product2>();
			products.add(
				TestFactory.buildProduct('Tanium Core Standard - Tanium Cloud', 'TAN-CORE-STND-CLOUD')
			);
			insert products;

			List<Product_Module__c> productModules = new List<Product_Module__c>();
			for (Module__c module : modules) {
				productModules.add(TestFactory.buildProductModule(products[0].Id, module.Id));
			}
			insert productModules;

			List<POC_Request_Solution_and_Module_Map__c> pocRequestSolutionAndModuleMaps = new List<POC_Request_Solution_and_Module_Map__c>();
			for (Module__c module : modules) {
				pocRequestSolutionAndModuleMaps.add(
					TestFactory.buildPOCRequestSolutionAndModuleMap(
						module.Name,
						module.Name + '__c',
						null,
						null,
						module.Id
					)
				);
			}
			pocRequestSolutionAndModuleMaps.add(
				TestFactory.buildPOCRequestSolutionAndModuleMap(
					'Core Standard',
					'Core_Standard__c',
					products[0].Id,
					null,
					null
				)
			);
			insert pocRequestSolutionAndModuleMaps;
		}
	}

	@IsTest
	static void testHandleApprovedPOCRequests_WhenFullyApprovedModules_CreateAccountEntitlementsAndServerDeploymentSubscriptions() {
		List<POC_Request__c> pocRequests = [
			SELECT
				Id,
				Approval_Stage__c,
				Account__c,
				Deployment_Method__c,
				Selected_Modules__c,
				Selected_Solutions__c,
				Start_Date__c,
				End_Date__c,
				Quantity__c
			FROM POC_Request__c
			WHERE Business_Justification__c = 'Test Modules'
		];
		Assert.areEqual(1, pocRequests.size());

		Map<Id, POC_Request__c> oldMap = new Map<Id, POC_Request__c>(
			pocRequests.deepClone(true, true, true)
		);

		for (POC_Request__c pocRequest : pocRequests) {
			pocRequest.Approval_Stage__c = 'Fully Approved';
			pocRequest.Approved__c = true;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			POCRequestTriggerUtility.handleApprovedPOCRequests(pocRequests, oldMap);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [
			SELECT Id
			FROM Account_Entitlements__c
			WHERE Type__c = 'POC Request'
		];

		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];

		Assert.areEqual(
			3,
			accountEntitlements.size(),
			'3 Account Entitlements should be created for each module'
		);
		Assert.areEqual(
			3,
			serverDeploymentSubscriptions.size(),
			'3 Server Deployment Subscriptions should be created for each module'
		);

		Account_Entitlements__c accountEntitlement = [
			SELECT
				Id,
				Account__c,
				Start_Date__c,
				End_Date__c,
				Quantity_Purchased__c,
				Quantity_Allocated__c,
				Type__c,
				Source_POC_Request__c
			FROM Account_Entitlements__c
			LIMIT 1
		];
		POC_Request__c pocRequest = [
			SELECT Id, Account__c, Start_Date__c, End_Date__c, Quantity__c
			FROM POC_Request__c
			WHERE Id = :accountEntitlement.Source_POC_Request__c
		];
		Assert.areEqual(pocRequest.Account__c, accountEntitlement.Account__c);
		Assert.areEqual(pocRequest.Start_Date__c, accountEntitlement.Start_Date__c);
		Assert.areEqual(pocRequest.End_Date__c, accountEntitlement.End_Date__c);
		Assert.areEqual(pocRequest.Quantity__c, accountEntitlement.Quantity_Purchased__c);
		Assert.areEqual(pocRequest.Quantity__c, accountEntitlement.Quantity_Allocated__c);
		Assert.areEqual('POC Request', accountEntitlement.Type__c);
		Assert.areEqual(pocRequest.Id, accountEntitlement.Source_POC_Request__c);

		Server_Deployment__c serverDeployment = [
			SELECT Id
			FROM Server_Deployment__c
			WHERE Server_Device_Type__c = 'Tanium as a Service'
		];
		Server_Deployment_Subscriptions__c serverDeploymentSubscription = [
			SELECT
				Id,
				Account__c,
				Server_Deployment__c,
				Subscription_Quantity__c,
				Subscription__c,
				Account_Entitlement__c
			FROM Server_Deployment_Subscriptions__c
			LIMIT 1
		];
		Assert.areEqual(accountEntitlement.Account__c, serverDeploymentSubscription.Account__c);
		Assert.areEqual(serverDeployment.Id, serverDeploymentSubscription.Server_Deployment__c);
		Assert.areEqual(
			accountEntitlement.Quantity_Purchased__c,
			serverDeploymentSubscription.Subscription_Quantity__c
		);
		Assert.areEqual(null, serverDeploymentSubscription.Subscription__c);
		Assert.areEqual(accountEntitlement.Id, serverDeploymentSubscription.Account_Entitlement__c);
	}

	@IsTest
	static void testHandleApprovedPOCRequests_WhenFullyApprovedSolutions_CreateAccountEntitlementsAndServerDeploymentSubscriptions() {
		List<POC_Request__c> pocRequests = [
			SELECT
				Id,
				Approval_Stage__c,
				Account__c,
				Deployment_Method__c,
				Selected_Modules__c,
				Selected_Solutions__c,
				Start_Date__c,
				End_Date__c,
				Quantity__c
			FROM POC_Request__c
			WHERE Business_Justification__c = 'Test Solutions'
		];
		Assert.areEqual(1, pocRequests.size());

		Map<Id, POC_Request__c> oldMap = new Map<Id, POC_Request__c>(
			pocRequests.deepClone(true, true, true)
		);

		for (POC_Request__c pocRequest : pocRequests) {
			pocRequest.Approval_Stage__c = 'Fully Approved';
			pocRequest.Approved__c = true;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			POCRequestTriggerUtility.handleApprovedPOCRequests(pocRequests, oldMap);
			Test.stopTest();
		}

		Product_Module__c productModule = [
			SELECT Id, Module__c, Product__c
			FROM Product_Module__c
			LIMIT 1
		];

		List<Account_Entitlements__c> accountEntitlements = [
			SELECT Id
			FROM Account_Entitlements__c
			WHERE Type__c = 'POC Request'
		];

		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];

		Assert.areEqual(
			3,
			accountEntitlements.size(),
			'3 Account Entitlements should be created for each module on the Product'
		);
		Assert.areEqual(
			accountEntitlements.size(),
			serverDeploymentSubscriptions.size(),
			'A Server Deployment Subscriptions should be created for each account entitlement'
		);

		Account_Entitlements__c accountEntitlement = [
			SELECT
				Id,
				Account__c,
				Start_Date__c,
				End_Date__c,
				Quantity_Purchased__c,
				Quantity_Allocated__c,
				Type__c,
				Source_POC_Request__c,
				Product__c,
				Module__c
			FROM Account_Entitlements__c
			WHERE Product__c = :productModule.Product__c AND Module__c = :productModule.Module__c
			LIMIT 1
		];
		POC_Request__c pocRequest = [
			SELECT Id, Account__c, Start_Date__c, End_Date__c, Quantity__c
			FROM POC_Request__c
			WHERE Id = :accountEntitlement.Source_POC_Request__c
		];
		Assert.areEqual(pocRequest.Account__c, accountEntitlement.Account__c);
		Assert.areEqual(pocRequest.Start_Date__c, accountEntitlement.Start_Date__c);
		Assert.areEqual(pocRequest.End_Date__c, accountEntitlement.End_Date__c);
		Assert.areEqual(pocRequest.Quantity__c, accountEntitlement.Quantity_Purchased__c);
		Assert.areEqual(pocRequest.Quantity__c, accountEntitlement.Quantity_Allocated__c);
		Assert.areEqual(productModule.Product__c, accountEntitlement.Product__c);
		Assert.areEqual(productModule.Module__c, accountEntitlement.Module__c);
		Assert.areEqual('POC Request', accountEntitlement.Type__c);
		Assert.areEqual(pocRequest.Id, accountEntitlement.Source_POC_Request__c);

		Server_Deployment__c serverDeployment = [
			SELECT Id
			FROM Server_Deployment__c
			WHERE Server_Device_Type__c = 'Tanium as a Service'
		];
		Server_Deployment_Subscriptions__c serverDeploymentSubscription = [
			SELECT
				Id,
				Account__c,
				Server_Deployment__c,
				Subscription_Quantity__c,
				Subscription__c,
				Account_Entitlement__c
			FROM Server_Deployment_Subscriptions__c
			LIMIT 1
		];
		Assert.areEqual(accountEntitlement.Account__c, serverDeploymentSubscription.Account__c);
		Assert.areEqual(serverDeployment.Id, serverDeploymentSubscription.Server_Deployment__c);
		Assert.areEqual(
			accountEntitlement.Quantity_Purchased__c,
			serverDeploymentSubscription.Subscription_Quantity__c
		);
		Assert.areEqual(null, serverDeploymentSubscription.Subscription__c);
		Assert.areEqual(accountEntitlement.Id, serverDeploymentSubscription.Account_Entitlement__c);
	}
}