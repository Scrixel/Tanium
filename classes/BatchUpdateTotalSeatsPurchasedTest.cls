/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test methods for BatchUpdateTotalSeatsPurchased
 * @Date: 2021-05-13
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7608    2024-08-10    Populate Max Subscription End Date and MSP Max Subscription End Date
 * SS-10969   2025-05-29    Updated test class
 * SS-12650   2026-02-23    Updated batch logic to check for quantity in subscriptions
 * SS-13669   2026-08-25    Updated class to repoint to NUE objects and fields
 */
@IsTest
private class BatchUpdateTotalSeatsPurchasedTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'SubscriptionTriggerHandler',
				'QuoteLineTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert new List<Account>{ acct };

			Opportunity opp = TestFactory.buildOpportunity(
				'Test opp name',
				System.today().addDays(120),
				'New',
				acct.id
			);
			insert opp;

			Product2 prodWithSeatsPurchased = TestFactory.buildProduct('Test Prod', '12345');
			prodWithSeatsPurchased.IncludeInSeatsPurchased__c = true;
			Product2 prodWithSeatsPurchased1 = TestFactory.buildProduct('Test Management', '23456');
			prodWithSeatsPurchased1.IncludeInSeatsPurchased__c = true;
			Product2 prodWithoutSeatsPurchased3 = TestFactory.buildProduct('Test Core UPG', 'SS-RMT');
			prodWithoutSeatsPurchased3.IncludeInSeatsPurchased__c = false;
			Product2 remoteScreenShareProduct = TestFactory.buildProduct(
				'Remote Screen Share',
				'SS-RMT'
			);
			insert new List<Product2>{
				prodWithSeatsPurchased,
				prodWithSeatsPurchased1,
				prodWithoutSeatsPurchased3,
				remoteScreenShareProduct
			};

			Product_Promotion__c burstProductPromo = new Product_Promotion__c(
				Name = 'Burst',
				Promo_Product_Line__c = 'Client',
				Discount__c = 10,
				Start_Date__c = System.today(),
				Type__c = 'All'
			);
			Product_Promotion__c FOCProductPromo = new Product_Promotion__c(
				Name = 'FOC',
				Promo_Product_Line__c = 'Client',
				Discount__c = 10,
				Start_Date__c = System.today(),
				Type__c = 'All'
			);
			insert new List<Product_Promotion__c>{ burstProductPromo, FOCProductPromo };

			PricebookEntry pricebookEntry = TestFactory.buildPricebookEntry(
				prodWithSeatsPurchased.Id,
				6000,
				Test.getStandardPricebookId()
			);
			insert pricebookEntry;

			Ruby__UOM__c rubyUOM = TestFactory.buildRubyUOM('Test UOM', 1, 'Test Dimension');
			insert rubyUOM;

			Quote quote = TestFactory.buildQuote(opp.Id, 'Draft', '', null, null, null);
			insert quote;

			QuoteLineItem quoteLineBurst = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				100,
				pricebookEntry.Id
			);
			quoteLineBurst.Product2Id = prodWithSeatsPurchased.Id;
			quoteLineBurst.ELV_Product_Promotion__c = burstProductPromo.Id;

			QuoteLineItem quoteLineFOC = TestFactory.buildQuoteLineItem(
				quote.Id,
				1,
				100,
				pricebookEntry.Id
			);
			quoteLineFOC.Product2Id = prodWithSeatsPurchased1.Id;
			quoteLineFOC.ELV_Product_Promotion__c = FOCProductPromo.Id;

			QuoteLineItem quoteLineRemoteSS = TestFactory.buildQuoteLineItem(
				quote.Id,
				50,
				100,
				pricebookEntry.Id
			);
			quoteLineRemoteSS.Product2Id = remoteScreenShareProduct.Id;
			insert new List<QuoteLineItem>{ quoteLineBurst, quoteLineFOC, quoteLineRemoteSS };

			Ruby__Subscription__c subBurst = TestFactory.buildRubySubscription(
				acct.Id,
				prodWithSeatsPurchased.Id,
				1.00,
				quoteLineBurst.Id,
				rubyUOM.Id,
				pricebookEntry.Id
			);
			subBurst.ELV_Include_in_Seats_Purchased__c = true;
			subBurst.ELV_End_User_Account__c = acct.Id;

			Ruby__Subscription__c subEarlier = TestFactory.buildRubySubscription(
				acct.Id,
				prodWithSeatsPurchased.Id,
				1.00,
				quoteLineBurst.Id,
				rubyUOM.Id,
				pricebookEntry.Id
			);
			subEarlier.ELV_Include_in_Seats_Purchased__c = true;
			subEarlier.Ruby__SubscriptionEndDate__c = System.today().addDays(30);

			Ruby__Subscription__c subFOC1 = TestFactory.buildRubySubscription(
				acct.Id,
				prodWithSeatsPurchased1.Id,
				1.00,
				quoteLineFOC.Id,
				rubyUOM.Id,
				pricebookEntry.Id
			);
			subFOC1.ELV_Include_in_Seats_Purchased__c = true;
			subFOC1.ELV_End_User_Account__c = acct.Id;

			Ruby__Subscription__c subFOC2 = TestFactory.buildRubySubscription(
				acct.Id,
				prodWithSeatsPurchased1.Id,
				1.00,
				quoteLineFOC.Id,
				rubyUOM.Id,
				pricebookEntry.Id
			);
			subFOC2.ELV_Include_in_Seats_Purchased__c = true;

			Ruby__Subscription__c subFOC3 = TestFactory.buildRubySubscription(
				null,
				prodWithoutSeatsPurchased3.Id,
				1.00,
				quoteLineFOC.Id,
				rubyUOM.Id,
				pricebookEntry.Id
			);
			subFOC3.ELV_End_User_Account__c = acct.Id;
			subFOC3.ELV_Exclude_from_Seats_Roll_up__c = true;
			subFOC3.Ruby__Customer__c = acct.Id;
			subFOC3.ELV_Sold_by_Operators_versus_Endpoints__c = true;

			Ruby__Subscription__c subRemoteScreenShare = TestFactory.buildRubySubscription(
				null,
				remoteScreenShareProduct.Id,
				50.00,
				quoteLineRemoteSS.Id,
				rubyUOM.Id,
				pricebookEntry.Id
			);
			subRemoteScreenShare.Ruby__Customer__c = acct.Id;
			subRemoteScreenShare.ELV_Sold_by_Operators_versus_Endpoints__c = true;

			insert new List<Ruby__Subscription__c>{
				subBurst,
				subEarlier,
				subFOC1,
				subFOC2,
				subFOC3,
				subRemoteScreenShare
			};
		}
	}

	@IsTest
	static void testBatchForNonMSPClients_whenHasProductsWithSeatsIncludedAndSubscriptionsNotExcludedFromRollup_seatsPurchasedIsAccurate() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [
				SELECT Id, Active_Subscriptions__c, Active_Packages__c, Seats_Purchased1__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];
			Assert.areEqual(0, acc.Seats_Purchased1__c);
			Assert.isNull(acc.Active_Subscriptions__c);
			Assert.isNull(acc.Active_Packages__c);

			Test.startTest();
			Database.executeBatch(new BatchUpdateTotalSeatsPurchased());
			Test.stopTest();

			acc = [
				SELECT Id, Seats_Purchased1__c, Active_Subscriptions__c, Active_Packages__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];

			Assert.areEqual(3, acc.Seats_Purchased1__c);
			Assert.areEqual(2, acc.Active_Subscriptions__c);
			Assert.areEqual(1, acc.Active_Packages__c);
		}
	}

	@IsTest
	static void testBatchForMSPClients_whenContractActiveAndTaasOrOnPremBundleType_seatsPurchasedAndActivePackageAreAccurate() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [
				SELECT Id, Active_Subscriptions__c, Active_Packages__c, Seats_Purchased1__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];
			Assert.areEqual(0, acc.Seats_Purchased1__c);
			Assert.isNull(acc.Active_Subscriptions__c);
			Assert.isNull(acc.Active_Packages__c);

			List<Ruby__Subscription__c> subscriptionsBefore = new List<Ruby__Subscription__c>();
			for (Ruby__Subscription__c each : [SELECT ELV_Bundle_Type__c FROM Ruby__Subscription__c]) {
				each.ELV_Bundle_Type__c = 'Taas';
				subscriptionsBefore.add(each);
			}
			update subscriptionsBefore;

			List<Ruby__Subscription__c> subscriptionsMeetingBatchCriteria = [
				SELECT Id, ELV_End_User_Account__c, Ruby__Quantity__c
				FROM Ruby__Subscription__c
				WHERE
					ELV_End_User_Account__c = :acc.Id
					AND ELV_Status__c = 'Active'
					AND ELV_Bundle_Type__c IN ('Taas', 'On Premise')
			];

			Assert.areEqual(3, subscriptionsMeetingBatchCriteria.size());

			Test.startTest();
			Database.executeBatch(new BatchUpdateTotalSeatsPurchased());
			Test.stopTest();

			acc = [
				SELECT Id, Seats_Purchased1__c, Active_Subscriptions__c, Active_Packages__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];

			Assert.areEqual(0, acc.Seats_Purchased1__c);
			Assert.areEqual(0, acc.Active_Subscriptions__c);
			Assert.areEqual(0, acc.Active_Packages__c);
		}
	}

	@IsTest
	static void testBatch_WhenScreenShareProduct_ActiveOperatorIsAccurate() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [
				SELECT Id, Name, Active_Operators_Screen_Share__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];

			Assert.isNull(
				acc.Active_Operators_Screen_Share__c,
				'Active Operator should be null before running the batch'
			);

			Test.startTest();
			Database.executeBatch(new BatchUpdateTotalSeatsPurchased());
			Test.stopTest();

			acc = [
				SELECT Id, Name, Active_Operators_Screen_Share__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];

			Assert.areEqual(
				51,
				acc.Active_Operators_Screen_Share__c,
				'Active Operator should be equal to 51'
			);
		}
	}

	@IsTest
	static void batchUpdateTotalSeatsPurchased_WhenScheduled_ReturnsBatchJobId() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			BatchUpdateTotalSeatsPurchased batch = new BatchUpdateTotalSeatsPurchased();
			String sch = '0 0 2 * * ?';
			Id jobID = System.schedule('Test Batch update Total Seats', sch, batch);
			Assert.isTrue(jobId != null);
			Test.stopTest();
		}
	}
}