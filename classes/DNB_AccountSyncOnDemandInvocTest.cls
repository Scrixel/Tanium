/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for DNB_AccountSyncOnDemandInvoc class
 * @Date: 2026-07-07
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13353   2026-07-07    Initial development
 */
@IsTest
private class DNB_AccountSyncOnDemandInvocTest {
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

		System.runAs(TestUserFactory.getAdminUser()) {
			DNBConnect__D_B_Connect_Company_Profile__c companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
				'D&B Test Profile',
				new Map<String, Object>{
					DNB_TestFactory.ENTITY_CITY => 'Austin'
				}
			);
			insert companyProfile;

			Account account = TestFactory.buildAccount('D&B Test Account');
			DNB_TestFactory.linkAccounts(new List<Account>{ account }, companyProfile.Id);
			account.BillingCountry = 'United States';
			account.BillingState = 'California';
			account.ShippingCountry = 'United States';
			account.ShippingState = 'California';
			insert account;

			companyProfile.Sync_to_Account__c = true;
			update companyProfile;
		}
	}

	@IsTest
	static void testSyncOnDemand_FlaggedAccount_EnqueuesBatchAndAccountEnriched() {
		Account account = [SELECT Id FROM Account WHERE Name = 'D&B Test Account'];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			DNB_AccountSyncOnDemandInvoc.syncOnDemand(new List<Id>{ account.Id });
			Test.stopTest();
		}

		Account enrichedAccount = [
			SELECT
				Id,
				HQ_City__c,
				D_B_Last_Synced_Date__c,
				DNBConnect__D_B_Connect_Company_Profile__r.Sync_to_Account__c
			FROM Account
			WHERE Name = 'D&B Test Account'
		];
		Assert.areEqual('Austin', enrichedAccount.HQ_City__c, 'HQ City should be enriched');
		Assert.isNotNull(enrichedAccount.D_B_Last_Synced_Date__c, 'Last Synced should be stamped');
		Assert.isFalse(
			enrichedAccount.DNBConnect__D_B_Connect_Company_Profile__r.Sync_to_Account__c,
			'Sync flag must be cleared after processing'
		);
	}
}