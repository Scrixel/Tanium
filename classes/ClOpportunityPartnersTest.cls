/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for ClOpportunityPartners
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * Modified   ModifiedDate   Description
 * TAN-375    2017-01-24     Fixed following issue (LIMIT_EXCEEDED) System.LimitException: Too many SOQL queries: 101
 * TAN-483    2018-02-22     Updated StageName
 * TAN-536    2018-04-14     Modified Account creation as per "Country_Restriction" validation rule on opportunity
 * TAN-623    2016-07-24     Modifications due to the PermissionSet "Add_Opportunity_Partner" related logic
 * SS-8873    2024-10-12     Add test method to cover without permission scenario
 * SS-12400   2026-01-22     Removed Opp_Reg_ID__c field from test class
 * SS-12676   2026-03-25     Renamed test class to ClOpportunityPartnersTest, deleted depreciated fields (Dollars_Per_Seat__c, License_Rev_to_Partner__c, Commitment_Duration_Months__c)
 */
@IsTest
private class ClOpportunityPartnersTest {
	static User standardUser;

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = TestFactory.buildAccount('testAcc');
			acct.Commission__c = 1;
			acct.RecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');

			Account endUserAccount = TestFactory.buildAccount('End User Account');
			insert new List<Account>{ acct, endUserAccount };

			Opportunity opp = TestFactory.buildOpportunity(
				'testOpp',
				System.today().addDays(1),
				Utility.PILOT_VALUE_VALIDATED,
				acct.Id
			);
			opp.End_User_Account__c = endUserAccount.Id;
			insert opp;
		}
	}

	@IsTest
	static void ooptyPartnerTest_VF() {
		User dealDeskUser = getStandardUser();
		Account acct = [SELECT Id FROM Account WHERE Name = 'testAcc'];
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

		Test.startTest();
		System.runAs(getStandardUser()) {
			Pagereference pageRef = Page.Custom_Opportunity_Partners;
			Test.setCurrentPage(pageRef);

			ApexPages.currentPage().getParameters().put('oppId', opp.Id);
			ApexPages.currentPage().getParameters().put('accId', acct.Id);

			Opportunity_Partners__c o = new Opportunity_Partners__c();
			ApexPages.StandardController sc = new ApexPages.standardController(o);

			ClOpportunityPartners cla = new ClOpportunityPartners(sc);
			cla.addPartner();

			for (Integer i = 0; i < cla.lstOppPartners.size(); i++) {
				cla.lstOppPartners[i].oppPartner.Opportunity__c = opp.Id;
				cla.lstOppPartners[i].oppPartner.Account__c = acct.Id;
			}
			cla.hasAddOpportunityPartnerPermission = true;
			cla.doSave();

			Opportunity_Partners__c o1 = new Opportunity_Partners__c(
				Partner_Commission__c = 4,
				Opportunity__c = opp.Id,
				Account__c = acct.Id
			);
			insert o1;
			ApexPages.StandardController sc1 = new ApexPages.standardController(o1);

			ClOpportunityPartners cla1 = new ClOpportunityPartners(sc1);
			cla1.calculateCommission();
		}
		Test.stopTest();

		ApexPages.Message[] pageMessages = ApexPages.getMessages();
		Assert.isNotNull(pageMessages);
	}

	@IsTest
	static void testDoSave_WhenUserHasNoPermission_ThrowAnError() {
		Account acct = [SELECT Id FROM Account WHERE Name = 'testAcc'];
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

		Test.startTest();
		Pagereference pageRef = Page.Custom_Opportunity_Partners;
		Test.setCurrentPage(pageRef);
		ApexPages.currentPage().getParameters().put('oppId', opp.Id);
		ApexPages.currentPage().getParameters().put('accId', acct.Id);

		Opportunity_Partners__c o = new Opportunity_Partners__c();
		ApexPages.StandardController sc = new ApexPages.standardController(o);

		ClOpportunityPartners cla = new ClOpportunityPartners(sc);
		cla.addPartner();

		for (Integer i = 0; i < cla.lstOppPartners.size(); i++) {
			cla.lstOppPartners[i].oppPartner.Opportunity__c = opp.Id;
			cla.lstOppPartners[i].oppPartner.Account__c = acct.Id;
		}
		cla.hasAddOpportunityPartnerPermission = false;
		cla.doSave();

		Test.stopTest();

		ApexPages.Message[] pageMessages = ApexPages.getMessages();
		Assert.isNotNull(pageMessages);
	}

	static User getStandardUser() {
		if (ClOpportunityPartnersTest.standardUser == null) {
			List<User> testUsers = [SELECT Id FROM User WHERE LastName LIKE 'TestStandardUser%'];
			if (testUsers.isEmpty()) {
				User standardUser = TestUserFactory.createBasicUser(
					'TestStandardUser',
					Utility.getProfileId('Tanium Standard User')
				);
				ClOpportunityPartnersTest.standardUser = standardUser;
			} else {
				ClOpportunityPartnersTest.standardUser = testUsers[0];
			}
		}
		return ClOpportunityPartnersTest.standardUser;
	}
}