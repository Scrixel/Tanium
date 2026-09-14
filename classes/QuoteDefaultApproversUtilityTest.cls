/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: CPQ Quote Default Approvers Utility Test Class
 * @Date: 2024-02-21
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7487   2024-02-21	   Duplicate Ids exception - Remove code related to custom metadata Role Based Quote Approver Management
 * SS-9640   2025-01-21	   Remove Deal Desk Approver assignment code
 * SS-7504   2025-08-14    Delete Role Based Quote Approver metadata reference and whitespace cleanup
 * SS-13176  2026-05-27    Removed Level_1__c references
 * SS-13829  2026-08-11    Added coverage for Quote Customer_SuccessRVP__c 
 */
@IsTest
private class QuoteDefaultApproversUtilityTest {
	private static Map<String, User> userMap = new Map<String, User>();

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'UserTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			User approverUser = TestUserFactory.createUser(
				'approver 1',
				'sales@testTanium.com',
				'ap1',
				Utility.getSuperUserProfileId(),
				null
			);

			User testUser = TestUserFactory.createUser(
				'test user 1',
				'TUser@testTanium.com',
				'tu1',
				Utility.getSuperUserProfileId(),
				null
			);

			User usSouthEastUser = TestUserFactory.createUser(
				'Guy',
				'OtherTest@example.com',
				'seUser',
				UserInfo.getProfileId(),
				null
			);
			User usSLEDUser = TestUserFactory.createUser(
				'OtherGuy',
				'OtherGuy@example.com',
				'sledUser',
				UserInfo.getProfileId(),
				null
			);
			insert new List<User>{ approverUser, testUser, usSouthEastUser, usSLEDUser };

			Legal_Entity__c legalEntity = new Legal_Entity__c(Name = 'Test Legal');
			insert legalEntity;

			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Price Book 2009 Products',
				IsActive = true
			);

			String fieldApiName = 'Ruby__PriceAttributes__c';

			Map<String, Schema.SObjectField> pricebookFields =
				Schema.SObjectType.Pricebook2.fields.getMap();

			if (pricebookFields.containsKey(fieldApiName)) {
				globalPriceBook.put(fieldApiName, 'Currency;UOM');
			}
			insert globalPriceBook;

			Account acc = TestFactory.buildAccount('Existing Account');
			acc.Type = 'Analyst';
			acc.Country_Restrictions__c = 'Business Allowed';
			acc.LegalEntity__c = legalEntity.Id;
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'Existing Opportunity',
				Date.today() + 90,
				Utility.PROSPECTING,
				acc.Id
			);
			opp.Pricebook2Id = globalPriceBook.Id;
			opp.OwnerId = usSouthEastUser.Id;
			insert opp;
		}
	}

	static {
		for (User user : [
			SELECT Id, Alias
			FROM User
			WHERE Alias IN ('ap1', 'tu1', 'seUser')
		]) {
			userMap.put(user.Alias, user);
		}
	}

	/**
	 * Test class: set the Area VP field on the Opportunities
	 * @author Luan Pereira
	 * @date   2017-07-18
	 */
	@IsTest
	public static void testAssignVPAndAreaVPonOpps_WithoutQuote() {
		SBQQ.TriggerControl.disable();
		Opportunity opp;
		Account acct = [SELECT Id FROM Account LIMIT 1];
		Id legalEntityId = [SELECT Id FROM Legal_Entity__c LIMIT 1].Id;

		User testUser = userMap.get('tu1');
		System.runAs(TestUserFactory.getAdminUser()) {
			testUser.Area_VP__c = userMap.get('ap1').Id;
			testUser.VP__c = userMap.get('ap1').Id;
			update testUser;
		}

		System.runAs(testUser) {
			Test.startTest();

			opp = TestFactory.buildOpportunity(
				'test Opportunity',
				Date.today() + 90,
				Utility.PROSPECTING,
				acct.Id
			);
			insert opp;

			Test.stopTest();

			opp = [SELECT Id, OwnerId, AreaVP__c, VP__c FROM Opportunity WHERE Id = :opp.Id];
		}

		Assert.areEqual(
			testUser.Id,
			opp.OwnerId,
			'Confirm that the OwnerId field was populated with the right user id.'
		);

		Assert.areEqual(
			testUser.Area_VP__c,
			opp.AreaVP__c,
			'Confirm that the AreaVP field was populated with the right user id.'
		);

		Assert.areEqual(
			testUser.VP__c,
			opp.VP__c,
			'Confirm that the VP field was populated with the right user id.'
		);
	}

	/**
	 * Test class: set the Area VP field on the Opportunities and update related SBQQ__Quote record
	 * @author Luan Pereira
	 * @date   2017-07-18
	 */

	@IsTest
	public static void testAssignVPAndAreaVPonOpps_WithQuote() {
		SBQQ.TriggerControl.disable();

		Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Existing Opportunity'];
		Id legalEntityId = [SELECT Id FROM Legal_Entity__c LIMIT 1].Id;
		SBQQ__Quote__c quote;

		User testUser = userMap.get('tu1');
		User csRvpUser = userMap.get('seUser');
		System.runAs(TestUserFactory.getAdminUser()) {
			testUser.Area_VP__c = userMap.get('ap1').Id;
			testUser.VP__c = userMap.get('ap1').Id;
			update testUser;

			opp.OwnerId = testUser.Id;
			opp.Customer_Success_RVP__c = csRvpUser.Id;
			update opp;

			Test.startTest();

			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				opp.AccountId,
				'Draft',
				null,
				null,
				null,
				null
			);
			insert quote;

			Test.stopTest();

			opp = [
				SELECT Id, OwnerId, AreaVP__c, VP__c, Customer_Success_RVP__c
				FROM Opportunity
				WHERE Id = :opp.Id
			];
			quote = [
				SELECT Id, AreaVP__c, SVP__c, Customer_SuccessRVP__c
				FROM SBQQ__Quote__c
				WHERE Id = :quote.Id
			];
		}

		Assert.areEqual(
			testUser.Id,
			opp.OwnerId,
			'Confirm that the OwnerId field was populated with the right user id.'
		);

		Assert.areEqual(
			testUser.Area_VP__c,
			opp.AreaVP__c,
			'Confirm that the AreaVP field was populated with the right user id.'
		);

		Assert.areEqual(
			testUser.Area_VP__c,
			quote.AreaVP__c,
			'Confirm that the AreaVP field on the quote was populated with the right user id.'
		);

		Assert.areEqual(
			testUser.VP__c,
			opp.VP__c,
			'Confirm that the VP field was populated with the right user id.'
		);

		Assert.areEqual(
			testUser.VP__c,
			quote.SVP__c,
			'Confirm that the SVP field on the quote was populated with the right user id.'
		);

		Assert.areEqual(
			csRvpUser.Id,
			opp.Customer_Success_RVP__c,
			'Confirm that the Customer Success RVP field was populated with the right user id.'
		);

		Assert.areEqual(
			csRvpUser.Id,
			quote.Customer_SuccessRVP__c,
			'Confirm that the Customer Success RVP field on the quote was populated with the right user id.'
		);
	}

	/**
	 * Test class: set the Area VP field on the Opportunities and update related SBQQ__Quote record
	 * @author Luan Pereira
	 * @date   2017-07-18
	 */

	@IsTest
	public static void testAssignVPAndAreaVPonOpps_WithQuoteOnUpdate() {
		SBQQ.TriggerControl.disable();

		Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Existing Opportunity'];
		Id legalEntityId = [SELECT Id FROM Legal_Entity__c LIMIT 1].Id;
		SBQQ__Quote__c quote;

		User testUser = userMap.get('tu1');
		User newOppOwner = new User();

		System.runAs(TestUserFactory.getAdminUser()) {
			testUser.Area_VP__c = userMap.get('ap1').Id;
			testUser.VP__c = userMap.get('ap1').Id;
			update testUser;

			newOppOwner = TestUserFactory.createUser(
				'l4_2',
				'level4_2user@test.com',
				'sa3',
				Utility.getSuperUserProfileId(),
				null
			);
			newOppOwner.Area_VP__c = testUser.Id;
			newOppOwner.VP__c = testUser.Id;
			insert newOppOwner;

			quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				opp.AccountId,
				'Draft',
				null,
				null,
				null,
				null
			);
			quote.OwnerId = testUser.Id;
			insert quote;
		}

		//SBQQ__Quote__c insertion caused Opportunity Update
		TriggerHandler.resetRecursionLimits();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			opp.OwnerId = newOppOwner.Id;
			update opp;
			Test.stopTest();
		}

		opp = [SELECT Id, OwnerId, AreaVP__c, VP__c FROM Opportunity WHERE Id = :opp.Id];

		quote = [SELECT Id, AreaVP__c, SVP__c FROM SBQQ__Quote__c WHERE Id = :quote.Id];

		Assert.areEqual(
			newOppOwner.Id,
			opp.OwnerId,
			'Confirm that the OwnerId field was populated with the right user id.'
		);

		Assert.areEqual(
			newOppOwner.Area_VP__c,
			opp.AreaVP__c,
			'Confirm that the AreaVP field was populated with the right user id.'
		);

		Assert.areEqual(
			newOppOwner.Area_VP__c,
			quote.AreaVP__c,
			'Confirm that the AreaVP field on the quote was populated with the right user id.'
		);

		Assert.areEqual(
			newOppOwner.VP__c,
			opp.VP__c,
			'Confirm that the VP field was populated with the right user id.'
		);

		Assert.areEqual(
			newOppOwner.VP__c,
			quote.SVP__c,
			'Confirm that the SVP field on the quote was populated with the right user id.'
		);
	}

	@IsTest
	public static void testapprovers_WhenQuoteInserted_AssignsDefaultApprovers() {
		Opportunity opp = [
			SELECT Id, AccountId, Pricebook2Id
			FROM Opportunity
			WHERE Name = 'Existing Opportunity'
		];

		SBQQ__Quote__c testQuote = new SBQQ__Quote__c();
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();

			testQuote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				opp.AccountId,
				'Draft',
				null,
				null,
				null,
				null
			);
			testQuote.SBQQ__PricebookId__c = opp.Pricebook2Id;
			insert testQuote;
			Test.stopTest();
		}

		testQuote = [
			SELECT
				Opp_OwnerManager__c,
				SBQQ__Opportunity2__r.Opportunity_Manager__c,
				SBQQ__Opportunity2__r.AreaVP__c
			FROM SBQQ__Quote__c
			WHERE Id = :testQuote.Id
		];
		Assert.areEqual(testQuote.Opp_OwnerManager__c, testQuote.SBQQ__Opportunity2__r.AreaVP__c);
		Assert.areEqual(
			testQuote.SBQQ__Opportunity2__r.Opportunity_Manager__c,
			testQuote.Opp_OwnerManager__c
		);
	}

	@IsTest
	public static void testApprovers_WhenOppManagerUpdated_AssignsDefaultApprovers() {
		User usSouthEastUser = userMap.get('seUser');

		Opportunity opp = [
			SELECT Id, AccountId, Pricebook2Id
			FROM Opportunity
			WHERE Name = 'Existing Opportunity'
		];

		SBQQ__Quote__c testQuote = new SBQQ__Quote__c();
		System.runAs(TestUserFactory.getAdminUser()) {
			testQuote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				opp.AccountId,
				'Draft',
				null,
				null,
				null,
				null
			);
			testQuote.SBQQ__PricebookId__c = opp.Pricebook2Id;
			insert testQuote;

			//SBQQ__Quote__c insertion caused Opportunity Update
			TriggerHandler.resetRecursionLimits();

			Test.startTest();
			opp.OwnerId = usSouthEastUser.Id;
			opp.Opportunity_Manager__c = usSouthEastUser.Id;
			opp.Type = 'New Customer';
			update opp;
			Test.stopTest();
		}

		testQuote = [
			SELECT
				Opp_OwnerManager__c,
				SBQQ__Opportunity2__r.AreaVP__c,
				SBQQ__Opportunity2__r.Opportunity_Manager__c
			FROM SBQQ__Quote__c
			WHERE Id = :testQuote.Id
		];
		Assert.areEqual(
			testQuote.SBQQ__Opportunity2__r.Opportunity_Manager__c,
			testQuote.Opp_OwnerManager__c
		);
	}
}