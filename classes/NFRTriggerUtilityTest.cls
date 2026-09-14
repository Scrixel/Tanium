/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class forNFR Trigger Utility, part of Trigger Framework
 * @Date: 2026-01-12
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2026-01-12      Initial development
 */
@IsTest
private class NFRTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'UserTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Module__c> modules = new List<Module__c>();
			modules.add(new Module__c(Name = 'Comply', Module_Description__c = 'Comply Product'));
			modules.add(new Module__c(Name = 'Core', Module_Description__c = 'Core Product'));
			modules.add(new Module__c(Name = 'Deploy', Module_Description__c = 'Deploy Product'));
			modules.add(new Module__c(Name = 'Discover', Module_Description__c = 'Discover Product'));
			insert modules;

			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			List<Server_Deployment__c> serverDeployments = new List<Server_Deployment__c>();
			serverDeployments.add(TestFactory.buildServerDeployment('Test Server Deployment', acc.Id));
			insert serverDeployments;

			List<NFR__c> nfrs = new List<NFR__c>();
			nfrs.add(TestFactory.buildNFR(acc.Id, 'Comply;Core;Deploy;Discover'));
			nfrs[0].Server_Deployment_Links_From_Account__c = serverDeployments[0].Id;
			insert nfrs;
			update nfrs;
		}
	}

	@IsTest
	static void testHandleApprovedNFRs_WhenApproved_CreateAccEntAndServerDeploymentSubscriptions() {
		List<NFR__c> nfrs = [
			SELECT
				Id,
				Name,
				Select_Tanium_Product__c,
				NFR_Expiration_Date__c,
				NFR_Issued_Date__c,
				Status__c,
				Account__c,
				Number_of_Endpoints__c,
				Server_Deployment_Links_From_Account__c
			FROM NFR__c
		];
		Map<Id, NFR__c> oldMap = new Map<Id, NFR__c>(nfrs.deepClone(true, true, true));

		for (NFR__c nfr : nfrs) {
			nfr.Status__c = 'Approved';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			NFRTriggerUtility.handleApprovedNFRs(nfrs, oldMap);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];

		Assert.areEqual(
			4,
			accountEntitlements.size(),
			'4 Account Entitlements should be created for each module'
		);
		Assert.areEqual(
			4,
			serverDeploymentSubscriptions.size(),
			'4 Server Deployment Subscriptions should be created for each module'
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
				Source_NFR__c
			FROM Account_Entitlements__c
			LIMIT 1
		];
		NFR__c nfr = [
			SELECT Id, Account__c, NFR_Issued_Date__c, NFR_Expiration_Date__c, Number_of_Endpoints__c
			FROM NFR__c
			LIMIT 1
		];
		Assert.areEqual(nfr.Account__c, accountEntitlement.Account__c);
		Assert.areEqual(nfr.NFR_Issued_Date__c, accountEntitlement.Start_Date__c);
		Assert.areEqual(nfr.NFR_Expiration_Date__c, accountEntitlement.End_Date__c);
		Assert.areEqual(nfr.Number_of_Endpoints__c, accountEntitlement.Quantity_Purchased__c);
		Assert.areEqual(nfr.Number_of_Endpoints__c, accountEntitlement.Quantity_Allocated__c);
		Assert.areEqual('NFR', accountEntitlement.Type__c);
		Assert.areEqual(nfr.Id, accountEntitlement.Source_NFR__c);

		Server_Deployment__c serverDeployment = [SELECT Id FROM Server_Deployment__c LIMIT 1];
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
	static void testHandleApprovedNFRs_WhenNotApproved_DoNotCreateAccEntAndServerDeploymentSubscriptions() {
		List<NFR__c> nfrs = [
			SELECT
				Id,
				Name,
				Select_Tanium_Product__c,
				NFR_Expiration_Date__c,
				NFR_Issued_Date__c,
				Status__c,
				Account__c,
				Number_of_Endpoints__c,
				Server_Deployment_Links_From_Account__c
			FROM NFR__c
		];
		Map<Id, NFR__c> oldMap = new Map<Id, NFR__c>(nfrs.deepClone(true, true, true));

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			NFRTriggerUtility.handleApprovedNFRs(nfrs, oldMap);
			Test.stopTest();
		}

		List<Account_Entitlements__c> accountEntitlements = [SELECT Id FROM Account_Entitlements__c];
		List<Server_Deployment_Subscriptions__c> serverDeploymentSubscriptions = [
			SELECT Id
			FROM Server_Deployment_Subscriptions__c
		];

		Assert.areEqual(0, accountEntitlements.size(), 'No Account Entitlements should be created');
		Assert.areEqual(
			0,
			serverDeploymentSubscriptions.size(),
			'No Server Deployment Subscriptions should be created'
		);
	}
}