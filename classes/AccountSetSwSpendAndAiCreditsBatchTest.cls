/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for AccountSetSwSpendAndAiCreditsBatch
 * @Date: 2026-07-27
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13641   2026-07-27    Created AccountSetSwSpendAndAiCreditsBatchTest class
 * SS-13815   2026-08-09    Updated method tesclass to include Booked_ARR_Exit__c field
 * SS-13834   2026-08-24    Added Monthly Paid AI Credits tests
 */
@IsTest
private class AccountSetSwSpendAndAiCreditsBatchTest {
    @TestSetup
    static void makeData() {
        SBQQ.TriggerControl.disable();
        TriggerHandler.bypass(
            new List<String>{
                'AccountTriggerHandler',
                'OpportunityTriggerHandler',
                'QuoteCPQTriggerHandler',
                'QuoteLineTriggerHandler',
                'SubscriptionTriggerHandler',
                'UserTriggerHandler'
            }
        );

        System.runAs(TestUserFactory.getAdminUser()) {
            Account account = new Account(Name = 'Test Account');
            insert account;

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
					Product_Type__c = 'SaaS',
					Product_Group__c = 'Software',
					Include_In_Annualized_Software_Spend__c = true,
					Deployment_Method__c = 'Cloud',
					Family = 'None'
				)
			);
			products.add(
				new Product2(
					Name = 'Discover Product',
					ProductCode = 'Discover',
					IsActive = true,
					Product_Type__c = 'SaaS',
					Product_Group__c = 'Software',
					Include_In_Annualized_Software_Spend__c = false,
					Deployment_Method__c = 'Cloud',
					Family = 'None'
				)
			);
			insert products;

            List<AI_Credit_Tier__c> aiCreditTiers = new List<AI_Credit_Tier__c>();
            AI_Credit_Tier__c tier1 = new AI_Credit_Tier__c(
                Name = 'Tier 1',
                Lower_Band__c = 0,
                Upper_Band__c = 10000,
                Marginal_Rate_Percent__c = 5,
                Tanium_Cost_Per_Credit__c = 0.05
            );
            aiCreditTiers.add(tier1);

            AI_Credit_Tier__c tier2 = new AI_Credit_Tier__c(
                Name = 'Tier 2',
                Lower_Band__c = 10001,
                Upper_Band__c = 50000,
                Marginal_Rate_Percent__c = 3,
                Tanium_Cost_Per_Credit__c = 0.05
            );
            aiCreditTiers.add(tier2);

            AI_Credit_Tier__c tier3 = new AI_Credit_Tier__c(
                Name = 'Tier 3',
                Lower_Band__c = 50001,
                Upper_Band__c = 10000000,
                Marginal_Rate_Percent__c = 1,
                Tanium_Cost_Per_Credit__c = 0.05
            );
            aiCreditTiers.add(tier3);
            insert aiCreditTiers;

            SBQQ__Quote__c quote = new SBQQ__Quote__c(
                SBQQ__Opportunity2__c = opp.Id,
                SBQQ__Account__c = account.Id,
                SBQQ__Type__c = 'Quote',
                SBQQ__Primary__c = true,
                SBQQ__PaymentTerms__c = 'Net 30',
                Deployment_Method__c = 'Cloud'
            );
            insert quote;

            opp.SBQQ__PrimaryQuote__c = quote.Id;
            update opp;

            account.Latest_Closed_Cloud_or_OnPrem_Opp__c = opp.Id;
            update account;

            List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>();
            for (Product2 product : products) {
                quoteLines.add(
                    new SBQQ__QuoteLine__c(
                        SBQQ__Product__c = product.Id,
                        SBQQ__Quantity__c = 1000,
                        SBQQ__Quote__c = quote.Id,
                        SBQQ__StartDate__c = Date.today(),
                        SBQQ__EndDate__c = Date.today().addMonths(12),
                        SBQQ__SubscriptionPricing__c = null,
                        SBQQ__NetPrice__c = 1000
                    )
                );
            }
            insert quoteLines;

			List<SBQQ__Subscription__c> subscriptions = new List<SBQQ__Subscription__c>();
			for (Integer i = 0; i < quoteLines.size(); i++) {
				subscriptions.add(
					TestFactory.buildSubscription(
						account.Id,
						quoteLines[i].SBQQ__Product__c,
						1000,
						quoteLines[i].Id
					)
				);
				subscriptions[i].Include_In_Annualized_Software_Spend__c = i == 0 ? true : false;
				subscriptions[i].SBQQ__ProrateMultiplier__c = 1.0;
				subscriptions[i].SBQQ__NetPrice__c = 1000;
				subscriptions[i].Customer_Annualized_Software_Spend__c = 10000;
			}
			insert subscriptions;

			List<Product2> paidAICreditProducts = new List<Product2>();
			paidAICreditProducts.add(
				TestFactory.buildProduct('AI Credits Tanium Cloud', 'TANIUM-AI-CREDITS-CLOUD')
			);
			paidAICreditProducts.add(
				TestFactory.buildProduct(
					'AI Credits Tanium Cloud for US Government',
					'TANIUM-AI-CREDITS-CLOUDGOV-US'
				)
			);
			for (Product2 paidAICreditProduct : paidAICreditProducts) {
				paidAICreditProduct.Product_Type__c = 'SaaS';
				paidAICreditProduct.Product_Group__c = 'Software';
				paidAICreditProduct.Include_In_Annualized_Software_Spend__c = false;
				paidAICreditProduct.Deployment_Method__c = 'Cloud';
				paidAICreditProduct.Quantity_of_Credits__c = 10000;
			}
			insert paidAICreditProducts;

			List<SBQQ__QuoteLine__c> paidAICreditQuoteLines = new List<SBQQ__QuoteLine__c>();
			paidAICreditQuoteLines.add(
				new SBQQ__QuoteLine__c(
					SBQQ__Product__c = paidAICreditProducts[0].Id,
					SBQQ__Quantity__c = 1,
					SBQQ__Quote__c = quote.Id,
					SBQQ__StartDate__c = Date.today(),
					SBQQ__EndDate__c = Date.today().addMonths(12),
					SBQQ__SubscriptionPricing__c = null,
					SBQQ__NetPrice__c = 1000
				)
			);
			paidAICreditQuoteLines.add(
				new SBQQ__QuoteLine__c(
					SBQQ__Product__c = paidAICreditProducts[1].Id,
					SBQQ__Quantity__c = 3,
					SBQQ__Quote__c = quote.Id,
					SBQQ__StartDate__c = Date.today().addMonths(-13),
					SBQQ__EndDate__c = Date.today().addDays(-1),
					SBQQ__SubscriptionPricing__c = null,
					SBQQ__NetPrice__c = 1000
				)
			);
			insert paidAICreditQuoteLines;

			List<SBQQ__Subscription__c> paidAICreditSubscriptions = new List<SBQQ__Subscription__c>();
			paidAICreditSubscriptions.add(
				TestFactory.buildSubscription(
					account.Id,
					paidAICreditProducts[0].Id,
					1,
					paidAICreditQuoteLines[0].Id
				)
			);
			paidAICreditSubscriptions.add(
				TestFactory.buildSubscription(
					account.Id,
					paidAICreditProducts[1].Id,
					3,
					paidAICreditQuoteLines[1].Id
				)
			);
			for (SBQQ__Subscription__c paidAICreditSubscription : paidAICreditSubscriptions) {
				paidAICreditSubscription.Include_In_Annualized_Software_Spend__c = false;
			}
			paidAICreditSubscriptions[1].SBQQ__SubscriptionStartDate__c = Date.today().addMonths(-13);
			paidAICreditSubscriptions[1].SBQQ__SubscriptionEndDate__c = Date.today().addDays(-1);
			insert paidAICreditSubscriptions;
		}
	}

    @IsTest
    static void testBatchExecute_WhenNoAccountIds_ReturnJobId() {
        Id jobId = null;
        System.runAs(TestUserFactory.getAdminUser()) {
            Test.startTest();
            AccountSetSwSpendAndAiCreditsBatch batch = new AccountSetSwSpendAndAiCreditsBatch();
            jobId = Database.executeBatch(batch, 2);
            Test.stopTest();
        }

        Assert.isFalse(jobId == null);
    }

	@IsTest
	static void testBatchExecute_WhenAccountIds_ReturnJobId() {
		Map<Id, Account> accountMap = new Map<Id, Account>(
			[SELECT Id, Annualized_Software_Spend__c, Booked_ARR_Exit__c FROM Account]
		);
		Id jobId = null;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSetSwSpendAndAiCreditsBatch batch = new AccountSetSwSpendAndAiCreditsBatch(
				accountMap.keySet()
			);
			jobId = Database.executeBatch(batch, 2);
			Test.stopTest();
		}

        Assert.isFalse(jobId == null);
    }

	@IsTest
	static void testExecute_WhenEligibleSubscriptions_SetAnnualizedSoftwareSpendAndAICredits() {
		Map<Id, Account> accountMap = new Map<Id, Account>(
			[SELECT Id, Annualized_Software_Spend__c, Booked_ARR_Exit__c, Monthly_Paid_AI_Credits__c FROM Account]
		);

        System.runAs(TestUserFactory.getAdminUser()) {
            Test.startTest();
            AccountSetSwSpendAndAiCreditsBatch batch = new AccountSetSwSpendAndAiCreditsBatch(
                accountMap.keySet()
            );
            batch.execute(null, accountMap.values());
            Test.stopTest();
        }

        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE
                Id IN :accountMap.keySet()
                AND Annualized_Software_Spend__c > 0
                AND Monthly_FOC_AI_Credits__c > 0
        ];

		Assert.isFalse(
			accounts.isEmpty(),
			'There should be at least one account with Annualized Software Spend greater than 0 and Monthly FOC AI Credits greater than 0'
		);
	}

	@IsTest
	static void testExecute_WhenActiveAndExpiredAICreditsSubscriptions_SetsMonthlyPaidAICreditsFromActiveOnly() {
		Account account = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
		Map<Id, Account> accountMap = new Map<Id, Account>(
			[
				SELECT Id, Annualized_Software_Spend__c, Monthly_Paid_AI_Credits__c, Booked_ARR_Exit__c
				FROM Account
				WHERE Id = :account.Id
			]
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSetSwSpendAndAiCreditsBatch batch = new AccountSetSwSpendAndAiCreditsBatch(
				accountMap.keySet()
			);
			batch.execute(null, accountMap.values());
			Test.stopTest();
		}

		Account updatedAccount = [
			SELECT Monthly_Paid_AI_Credits__c
			FROM Account
			WHERE Id = :account.Id
		];

		Assert.areEqual(
			10000,
			updatedAccount.Monthly_Paid_AI_Credits__c,
			'Active qty-1 sub counts, expired qty-3 sub excluded => 10000'
		);
	}

	@IsTest
	static void testBatchExecute_WhenScheduledPath_RecalculatesAccountWithNonSpendFlaggedAICreditsSubscription() {
		Account account = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new AccountSetSwSpendAndAiCreditsBatch(), 2);
			Test.stopTest();
		}

		Account updatedAccount = [
			SELECT Monthly_Paid_AI_Credits__c
			FROM Account
			WHERE Id = :account.Id
		];

		Assert.areEqual(
			10000,
			updatedAccount.Monthly_Paid_AI_Credits__c,
			'Scheduled path surfaces the account via the new AI Credits query conditions and computes 10000'
		);
	}
}