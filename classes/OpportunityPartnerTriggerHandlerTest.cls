/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test Class for OpportunityPartnerTriggerHandler
 * @Date: 2019-05-22
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request: TAN-463
 * RequestId  ModifiedDate   Description
 * TAN-463    2019-05-22     Created the class
 * TAN-1225   2021-06-18     Updated test class for changes in triggerahandler
 * SS-9223    2024-09-27     Updated method makeData
 * SS-9056    2024-10-10     Add accountId on Opportunity records
 * SS-13498   2026-07-10     Removed deprecated Opportunity.Distributor_Opportunity_Partner__c field reference
 */

@IsTest
private class OpportunityPartnerTriggerHandlerTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account partnerAccount = TestFactory.buildAccount('Partner Account');
			partnerAccount.recordtypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
			partnerAccount.Partner_Maturity__c = 'Active';

			Account acc = TestFactory.buildAccount('Test Account');
			insert new List<Account>{ acc, partnerAccount };

			Opportunity opportunity = TestFactory.buildOpportunity(
				'Opportunity',
				System.today(),
				Utility.PROSPECTING,
				acc.Id
			);
			insert opportunity;
		}
	}

	@IsTest
	static void shouldUpdateOpportunityPartnerFieldsOnInsert() {
		Account partnerAccount = [SELECT Id FROM Account WHERE Name = 'Partner Account' LIMIT 1];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];

		List<Opportunity_Partners__c> oppPartnerList = new List<Opportunity_Partners__c>();

		Opportunity_Partners__c oppPartner1 = TestFactory.buildOpportunityPartner(
			opportunity.Id,
			partnerAccount.Id,
			10
		);
		oppPartner1.Partner_Role__c = 'Reseller';
		oppPartnerList.add(oppPartner1);

		Opportunity_Partners__c oppPartner2 = TestFactory.buildOpportunityPartner(
			opportunity.Id,
			partnerAccount.Id,
			10
		);
		oppPartner2.Partner_Role__c = 'Distributor';
		oppPartnerList.add(oppPartner2);

		Test.startTest();
		insert oppPartnerList;
		Test.stopTest();

		List<Opportunity_Partners__c> updatedOppPartners = [
			SELECT
				Partner_Role__c,
				Reseller_Opportunity_Partner__c,
				Distributor_Opportunity_Partner__c,
				Account__r.Name,
				Opportunity__r.Reseller_Opportunity_Partner__c
			FROM Opportunity_Partners__c
		];
		System.assertEquals(2, updatedOppPartners.size());
		for (Opportunity_Partners__c oppPartner : updatedOppPartners) {
			if (oppPartner.Partner_Role__c == 'Reseller') {
				System.assert(
					oppPartner.Reseller_Opportunity_Partner__c,
					'Reseller Checkbox should be checked'
				);
				System.assertEquals(
					oppPartner.Account__r.Name,
					oppPartner.Opportunity__r.Reseller_Opportunity_Partner__c,
					'Opportunity Reseller Partner should match Account Name on Opportunity Partner'
				);
			}
		}
	}
}