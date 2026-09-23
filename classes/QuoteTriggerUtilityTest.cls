/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for QuoteTriggerUtility
 * @Description: Covers SS-13958's implemented Quote behaviors (partner accreditation, AI credits, billing-quote-terms sync, billing-total zeroing, billing schedule re-linking, newly-quoted-modules diffing, cascade delete); see QuoteTriggerHandler for what's excluded.
 * @Date: 2026-09-09
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13958   2026-09-15    Added AI credits calc, billing quote terms sync
 */
@IsTest
private class QuoteTriggerUtilityTest {
	private static final String TEST_ACCOUNT_NAME = 'Test Account';
	private static final String DEPLOYMENT_PARTNER_NAME = 'Test Deployment Partner';
	private static final String SUPPORT_PARTNER_NAME = 'Test Support Partner';
	private static final String TEST_OPPORTUNITY_NAME = 'Test Opportunity';
	private static final String NEW_MODULE_NAME = 'New Module';
	private static final String ENTITLED_MODULE_NAME = 'Entitled Module';
	private static final String QUOTE_FOR_NEW_MODULE_NAME = 'Quote For New Module';
	private static final String QUOTE_FOR_ENTITLED_MODULE_NAME = 'Quote For Entitled Module';
	private static final String QUOTE_FOR_RELINK_NAME = 'Quote For Relink';
	private static final String QUOTE_WITH_BILLING_NAME = 'Quote With Billing';
	private static final String QUOTE_WITHOUT_BILLING_NAME = 'Quote Without Billing';
	private static final String QUOTE_FOR_AI_CREDITS_NAME = 'Quote For AI Credits';
	private static final String QUOTE_FOR_NO_SPEND_CHANGE_NAME = 'Quote For No Spend Change';
	private static final Integer NO_SPEND_CHANGE_SENTINEL_CREDITS = 99999;
	private static final String QUOTE_FOR_BILLING_TERMS_NAME = 'Quote For Billing Terms';
	private static final String QUOTE_FOR_NO_TERMS_CHANGE_NAME = 'Quote For No Terms Change';
	private static final String BILLING_TERMS_PAYMENT_TYPE = 'Upfront';
	private static final String NUE_ADMIN_PERMISSION_SET = 'Nue_System_Administrations';

	@TestSetup
	static void makeData() {
		User adminUser = TestUserFactory.getAdminUser();
		TestingUtility.assignPermissionSet(adminUser.Id, NUE_ADMIN_PERMISSION_SET);

		System.runAs(adminUser) {
			Account testAccount = TestFactory.buildAccount(TEST_ACCOUNT_NAME);
			Account deploymentPartner = TestFactory.buildAccount(DEPLOYMENT_PARTNER_NAME);
			Account supportPartner = TestFactory.buildAccount(SUPPORT_PARTNER_NAME);
			insert new List<Account>{ testAccount, deploymentPartner, supportPartner };

			Opportunity testOpportunity = TestFactory.buildOpportunity(
				TEST_OPPORTUNITY_NAME,
				Date.today().addDays(30),
				'Prospecting',
				testAccount.Id
			);
			insert testOpportunity;

			Module__c newModule = new Module__c(
				Name = NEW_MODULE_NAME,
				Module_Description__c = NEW_MODULE_NAME
			);
			Module__c entitledModule = new Module__c(
				Name = ENTITLED_MODULE_NAME,
				Module_Description__c = ENTITLED_MODULE_NAME
			);
			insert new List<Module__c>{ newModule, entitledModule };

			Product2 newModuleProduct = TestFactory.buildProduct('New Module Product', 'NEW-MOD');
			Product2 entitledModuleProduct = TestFactory.buildProduct(
				'Entitled Module Product',
				'ENTITLED-MOD'
			);
			insert new List<Product2>{ newModuleProduct, entitledModuleProduct };

			insert new List<Product_Module__c>{
				TestFactory.buildProductModule(newModuleProduct.Id, newModule.Id),
				TestFactory.buildProductModule(entitledModuleProduct.Id, entitledModule.Id)
			};

			PricebookEntry newModulePbe = TestFactory.buildPricebookEntry(
				newModuleProduct.Id,
				100,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			PricebookEntry entitledModulePbe = TestFactory.buildPricebookEntry(
				entitledModuleProduct.Id,
				100,
				TestFactory.STANDARD_PRICEBOOK_ID
			);
			insert new List<PricebookEntry>{ newModulePbe, entitledModulePbe };

			insert TestFactory.buildAccountEntitlement(
				testAccount.Id,
				'Subscription',
				entitledModule.Id,
				1
			);

			Quote quoteForNewModule = TestFactory.buildQuote(
				QUOTE_FOR_NEW_MODULE_NAME,
				testOpportunity.Id,
				null,
				null
			);
			Quote quoteForEntitledModule = TestFactory.buildQuote(
				QUOTE_FOR_ENTITLED_MODULE_NAME,
				testOpportunity.Id,
				null,
				null
			);
			Quote quoteForRelink = TestFactory.buildQuote(QUOTE_FOR_RELINK_NAME, testOpportunity.Id, null, null);
			quoteForRelink.Ruby__IsPrimaryQuote__c = false;
			Quote quoteWithBilling = TestFactory.buildQuote(
				QUOTE_WITH_BILLING_NAME,
				testOpportunity.Id,
				null,
				null
			);
			Quote quoteWithoutBilling = TestFactory.buildQuote(
				QUOTE_WITHOUT_BILLING_NAME,
				testOpportunity.Id,
				null,
				null
			);
			Quote quoteForAICredits = TestFactory.buildQuote(
				QUOTE_FOR_AI_CREDITS_NAME,
				testOpportunity.Id,
				null,
				null
			);
			quoteForAICredits.Calculated_Annualized_Software_Spend__c = 0;
			Quote quoteForNoSpendChange = TestFactory.buildQuote(
				QUOTE_FOR_NO_SPEND_CHANGE_NAME,
				testOpportunity.Id,
				null,
				null
			);
			quoteForNoSpendChange.Calculated_Annualized_Software_Spend__c = 1500000;
			quoteForNoSpendChange.Calculated_AI_Credits__c = NO_SPEND_CHANGE_SENTINEL_CREDITS;
			Quote quoteForBillingTerms = TestFactory.buildQuote(
				QUOTE_FOR_BILLING_TERMS_NAME,
				testOpportunity.Id,
				null,
				null
			);
			quoteForBillingTerms.Ruby__PaymentTerm__c = 'Net 30';
			Quote quoteForNoTermsChange = TestFactory.buildQuote(
				QUOTE_FOR_NO_TERMS_CHANGE_NAME,
				testOpportunity.Id,
				null,
				null
			);
			quoteForNoTermsChange.Ruby__PaymentTerm__c = 'Net 30';
			insert new List<Quote>{
				quoteForNewModule,
				quoteForEntitledModule,
				quoteForRelink,
				quoteWithBilling,
				quoteWithoutBilling,
				quoteForAICredits,
				quoteForNoSpendChange,
				quoteForBillingTerms,
				quoteForNoTermsChange
			};

			insert new List<AI_Credit_Tier__c>{
				new AI_Credit_Tier__c(
					Name = 'Tier 1',
					Tier__c = 1,
					Lower_Band__c = 0,
					Upper_Band__c = 1000000,
					Marginal_Rate_Percent__c = 12,
					Tanium_Cost_Per_Credit__c = 1
				),
				new AI_Credit_Tier__c(
					Name = 'Tier 2',
					Tier__c = 2,
					Lower_Band__c = 1000000,
					Upper_Band__c = 5000000,
					Marginal_Rate_Percent__c = 6,
					Tanium_Cost_Per_Credit__c = 1
				)
			};

			insert new List<QuoteLineItem>{
				TestFactory.buildQuoteLineItem(quoteForNewModule.Id, 1, 100, newModulePbe.Id),
				TestFactory.buildQuoteLineItem(quoteForEntitledModule.Id, 1, 100, entitledModulePbe.Id)
			};

			Billing_Schedule__c billingForRelink = TestFactory.buildBillingSchedule(testOpportunity.Id);
			billingForRelink.ELV_Quote__c = quoteForRelink.Id;
			billingForRelink.Opportunity__c = null;
			Billing_Schedule__c billingForDelete = TestFactory.buildBillingSchedule(testOpportunity.Id);
			billingForDelete.ELV_Quote__c = quoteWithBilling.Id;
			Billing_Schedule__c billingForTerms = TestFactory.buildBillingSchedule(testOpportunity.Id);
			billingForTerms.ELV_Quote__c = quoteForBillingTerms.Id;
			billingForTerms.Billing_Order__c = 0;
			billingForTerms.PaymentType__c = BILLING_TERMS_PAYMENT_TYPE;
			billingForTerms.isReverseBilling__c = true;
			Billing_Schedule__c billingForNoTermsChange = TestFactory.buildBillingSchedule(
				testOpportunity.Id
			);
			billingForNoTermsChange.ELV_Quote__c = quoteForNoTermsChange.Id;
			billingForNoTermsChange.Billing_Order__c = 0;
			billingForNoTermsChange.PaymentType__c = BILLING_TERMS_PAYMENT_TYPE;
			billingForNoTermsChange.isReverseBilling__c = true;
			insert new List<Billing_Schedule__c>{
				billingForRelink,
				billingForDelete,
				billingForTerms,
				billingForNoTermsChange
			};
		}
	}

	@IsTest
	static void testSetPartnerAccreditationValues_WhenBothPartnersPopulatedOnInsert_SetsAccreditationLabel() {
		Opportunity testOpportunity = [
			SELECT Id
			FROM Opportunity
			WHERE Name = :TEST_OPPORTUNITY_NAME
			LIMIT 1
		];
		Account deploymentPartner = [
			SELECT Id
			FROM Account
			WHERE Name = :DEPLOYMENT_PARTNER_NAME
			LIMIT 1
		];
		Account supportPartner = [SELECT Id FROM Account WHERE Name = :SUPPORT_PARTNER_NAME LIMIT 1];
		Quote newQuote = TestFactory.buildQuote('Accreditation Quote', testOpportunity.Id, null, null);
		newQuote.ELV_Deployment_Partner__c = deploymentPartner.Id;
		newQuote.ELV_L1_L2_Support_Partner__c = supportPartner.Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			insert newQuote;
			Test.stopTest();
		}

		Quote insertedQuote = [
			SELECT Id, ELV_Partner_Accreditation__c
			FROM Quote
			WHERE Id = :newQuote.Id
		];
		Assert.areEqual(
			'Support Deployment',
			insertedQuote.ELV_Partner_Accreditation__c,
			'Both partners populated should set a combined accreditation label'
		);
	}

	@IsTest
	static void testSetPartnerAccreditationValues_WhenNoPartnerPopulatedOnInsert_AccreditationStaysBlank() {
		Opportunity testOpportunity = [
			SELECT Id
			FROM Opportunity
			WHERE Name = :TEST_OPPORTUNITY_NAME
			LIMIT 1
		];
		Quote newQuote = TestFactory.buildQuote('No Partner Quote', testOpportunity.Id, null, null);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			insert newQuote;
			Test.stopTest();
		}

		Quote insertedQuote = [
			SELECT Id, ELV_Partner_Accreditation__c
			FROM Quote
			WHERE Id = :newQuote.Id
		];
		Assert.isTrue(
			String.isBlank(insertedQuote.ELV_Partner_Accreditation__c),
			'No partner populated should leave accreditation blank'
		);
	}

	@IsTest
	static void testSetBillingRelatedFieldsOnQuote_WhenQuoteInserted_ZeroesBillingScheduleTotalAmount() {
		Opportunity testOpportunity = [
			SELECT Id
			FROM Opportunity
			WHERE Name = :TEST_OPPORTUNITY_NAME
			LIMIT 1
		];
		Quote newQuote = TestFactory.buildQuote('Billing Zero Quote', testOpportunity.Id, null, null);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			insert newQuote;
			Test.stopTest();
		}

		Quote insertedQuote = [
			SELECT Id, ELV_Billing_Schedule_Total_Amount__c
			FROM Quote
			WHERE Id = :newQuote.Id
		];
		Assert.areEqual(
			0,
			insertedQuote.ELV_Billing_Schedule_Total_Amount__c,
			'Billing schedule total amount should be zeroed on insert'
		);
	}

	@IsTest
	static void testSetAICredits_WhenAnnualizedSpendChanges_RecalculatesAICreditsPerTier() {
		Quote quoteForAICredits = [
			SELECT Id, Calculated_Annualized_Software_Spend__c
			FROM Quote
			WHERE Name = :QUOTE_FOR_AI_CREDITS_NAME
			LIMIT 1
		];
		quoteForAICredits.Calculated_Annualized_Software_Spend__c = 1500000;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update quoteForAICredits;
			Test.stopTest();
		}

		Quote updatedQuote = [
			SELECT Id, Calculated_AI_Credits__c
			FROM Quote
			WHERE Id = :quoteForAICredits.Id
		];
		Assert.areEqual(
			12500,
			updatedQuote.Calculated_AI_Credits__c,
			'AI credits should recalculate per tier, monthly, rounded to 500'
		);
	}

	@IsTest
	static void testSetAICredits_WhenNoSpendChange_AICreditsUntouched() {
		Quote quoteForNoSpendChange = [
			SELECT Id, Description
			FROM Quote
			WHERE Name = :QUOTE_FOR_NO_SPEND_CHANGE_NAME
			LIMIT 1
		];
		quoteForNoSpendChange.Description = 'Updated unrelated field';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update quoteForNoSpendChange;
			Test.stopTest();
		}

		Quote updatedQuote = [
			SELECT Id, Calculated_AI_Credits__c
			FROM Quote
			WHERE Id = :quoteForNoSpendChange.Id
		];
		Assert.areEqual(
			NO_SPEND_CHANGE_SENTINEL_CREDITS,
			updatedQuote.Calculated_AI_Credits__c,
			'AI credits should stay untouched when annualized spend does not change'
		);
	}

	@IsTest
	static void testProcessBillingScheduleOnOpportunity_WhenPrimaryFlagFlips_RelinksBillingScheduleToOpportunity() {
		Opportunity testOpportunity = [
			SELECT Id
			FROM Opportunity
			WHERE Name = :TEST_OPPORTUNITY_NAME
			LIMIT 1
		];
		Quote quoteForRelink = [
			SELECT Id, Ruby__IsPrimaryQuote__c
			FROM Quote
			WHERE Name = :QUOTE_FOR_RELINK_NAME
			LIMIT 1
		];
		quoteForRelink.Ruby__IsPrimaryQuote__c = true;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update quoteForRelink;
			Test.stopTest();
		}

		List<Billing_Schedule__c> billingSchedules = [
			SELECT Id, Opportunity__c
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quoteForRelink.Id
		];
		Assert.areEqual(
			1,
			billingSchedules.size(),
			'Exactly one billing schedule should be re-linked, not duplicated'
		);
		Assert.areEqual(
			testOpportunity.Id,
			billingSchedules[0].Opportunity__c,
			'Billing schedule should be re-linked to the Opportunity once the quote becomes primary'
		);
	}

	@IsTest
	static void testUpdateBillingQuoteTerms_WhenPaymentTermChanges_SyncsBillingInfoFromSchedule() {
		Quote quoteForBillingTerms = [
			SELECT Id, Ruby__PaymentTerm__c
			FROM Quote
			WHERE Name = :QUOTE_FOR_BILLING_TERMS_NAME
			LIMIT 1
		];
		quoteForBillingTerms.Ruby__PaymentTerm__c = 'Net 60';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update quoteForBillingTerms;
			Test.stopTest();
		}

		Quote updatedQuote = [
			SELECT Id, ELV_PaymentTypeNew__c
			FROM Quote
			WHERE Id = :quoteForBillingTerms.Id
		];
		Assert.areEqual(
			BILLING_TERMS_PAYMENT_TYPE,
			updatedQuote.ELV_PaymentTypeNew__c,
			'Payment term change should sync billing info from the linked billing schedule'
		);
	}

	@IsTest
	static void testUpdateBillingQuoteTerms_WhenNoTrackedFieldChanges_BillingInfoStaysUnsynced() {
		Quote quoteForNoTermsChange = [
			SELECT Id, Description
			FROM Quote
			WHERE Name = :QUOTE_FOR_NO_TERMS_CHANGE_NAME
			LIMIT 1
		];
		quoteForNoTermsChange.Description = 'Updated unrelated field';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update quoteForNoTermsChange;
			Test.stopTest();
		}

		Quote updatedQuote = [
			SELECT Id, ELV_PaymentTypeNew__c
			FROM Quote
			WHERE Id = :quoteForNoTermsChange.Id
		];
		Assert.isNull(
			updatedQuote.ELV_PaymentTypeNew__c,
			'Billing info should stay unsynced when no tracked field changes'
		);
	}

	@IsTest
	static void testProcessIdentifyNewModules_WhenLastCalculatedOnChangesWithNewModule_PopulatesNewlyQuotedModules() {
		Quote quoteForNewModule = [
			SELECT Id, ELV_LastCalculatedOn__c
			FROM Quote
			WHERE Name = :QUOTE_FOR_NEW_MODULE_NAME
			LIMIT 1
		];
		quoteForNewModule.ELV_LastCalculatedOn__c = System.now();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update quoteForNewModule;
			Test.stopTest();
		}

		Quote updatedQuote = [
			SELECT Id, ELV_Newly_Quoted_Modules__c
			FROM Quote
			WHERE Id = :quoteForNewModule.Id
		];
		Assert.areEqual(
			NEW_MODULE_NAME,
			updatedQuote.ELV_Newly_Quoted_Modules__c,
			'Module not present in Account Entitlements should show up as newly quoted'
		);
	}

	@IsTest
	static void testProcessIdentifyNewModules_WhenLastCalculatedOnChangesWithNoNewModule_NewlyQuotedModulesStaysEmpty() {
		Quote quoteForEntitledModule = [
			SELECT Id, ELV_LastCalculatedOn__c
			FROM Quote
			WHERE Name = :QUOTE_FOR_ENTITLED_MODULE_NAME
			LIMIT 1
		];
		quoteForEntitledModule.ELV_LastCalculatedOn__c = System.now();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			update quoteForEntitledModule;
			Test.stopTest();
		}

		Quote updatedQuote = [
			SELECT Id, ELV_Newly_Quoted_Modules__c
			FROM Quote
			WHERE Id = :quoteForEntitledModule.Id
		];
		Assert.isTrue(
			String.isBlank(updatedQuote.ELV_Newly_Quoted_Modules__c),
			'Module already covered by Account Entitlements should not appear as newly quoted'
		);
	}

	@IsTest
	static void testHandleDeletedQuotes_WhenQuoteHasBillingSchedule_DeletesChildBillingSchedule() {
		Quote quoteWithBilling = [SELECT Id FROM Quote WHERE Name = :QUOTE_WITH_BILLING_NAME LIMIT 1];
		List<Billing_Schedule__c> billingsBefore = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quoteWithBilling.Id
		];
		Assert.isTrue(
			!billingsBefore.isEmpty(),
			'Setup should have attached at least one billing schedule'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			delete quoteWithBilling;
			Test.stopTest();
		}

		List<Billing_Schedule__c> billingsAfter = [
			SELECT Id
			FROM Billing_Schedule__c
			WHERE Id IN :billingsBefore
		];
		Assert.isTrue(
			billingsAfter.isEmpty(),
			'Deleting the quote should cascade-delete its billing schedules'
		);
	}

	@IsTest
	static void testHandleDeletedQuotes_WhenQuoteHasNoBillingSchedule_DeletesWithoutError() {
		Quote quoteWithoutBilling = [
			SELECT Id
			FROM Quote
			WHERE Name = :QUOTE_WITHOUT_BILLING_NAME
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			delete quoteWithoutBilling;
			Test.stopTest();
		}

		List<Quote> deletedQuote = [SELECT Id FROM Quote WHERE Id = :quoteWithoutBilling.Id];
		Assert.isTrue(
			deletedQuote.isEmpty(),
			'Quote with no billing schedule children should delete without error'
		);
	}
}