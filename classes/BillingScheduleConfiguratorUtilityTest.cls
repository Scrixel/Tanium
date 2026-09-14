/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for BillingScheduleConfiguratorUtility
 * @Date: 2024-12-12
 * @Author: Savita Mirpuri
 * RequestId  ModifiedDate  Description
 * SS-9339    2024-12-16    IsQuarterlyBillingAllowed__c allowed is tested
 * SS-11278   2025-07-10    test getBillingScheduleFields
 * SS-13619   2026-08-18    Migrated getOpportunityStage tests to makeData
 */
@IsTest
private class BillingScheduleConfiguratorUtilityTest {
	static List<Schema.PicklistEntry> allPickListEntries;

	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			TestFactory.seedRubySettings();

			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity('Test Opp', System.today(), 'Discovery', acc.Id);
			insert opp;

			Quote quote = TestFactory.buildQuote('Test Quote', opp.Id, null, null);
			insert quote;
		}
	}

	@IsTest
	static void testGetUtilityInfo_whenRunningUserProfileHasAccessToRestrictedPayments_restrictedPaymentOptionsAreShown() {
		List<String> restrictedPaymentTypes = BillingScheduleConfiguratorUtility.getRestrictedPaymentTypes();
		String profilesWithRestrictedPaymentTypesAccess = BillingScheduleConfiguratorUtility.getToolInfo()
			.ProfilesWithRestrictedPaymentTypesAccess__c;
		profilesWithRestrictedPaymentTypesAccess = String.isBlank(
				profilesWithRestrictedPaymentTypesAccess
			)
			? 'Tanium System Administrator'
			: BillingScheduleConfiguratorUtility.getProfilesWithRestrictedPaymentTypesAccess()[0];
		Profile profileWithRestrictedPaymentTypesAccess = [
			SELECT Id
			FROM Profile
			WHERE Name = :profilesWithRestrictedPaymentTypesAccess
		];
		User profileAccessTester = TestUserFactory.createBasicUser(
			'WithRestrictedPaymentTypeAccess',
			profileWithRestrictedPaymentTypesAccess.Id
		);
		Test.startTest();
		System.runAs(profileAccessTester) {
			BillingScheduleConfiguratorUtility.Utility info = BillingScheduleConfiguratorUtility.getUtilityInfo();
			for (String eachRestrictedPayment : restrictedPaymentTypes) {
				System.assertEquals(true, info.paymentTypeOptions.contains(eachRestrictedPayment));
			}
		}
		profileAccessTester = TestUserFactory.createBasicUser(
			'WithoutRestrictedPaymentTypeAccess',
			[SELECT Id FROM Profile WHERE Name = 'Read Only' LIMIT 1].Id
		);
		System.runAs(profileAccessTester) {
			BillingScheduleConfiguratorUtility.Utility info = BillingScheduleConfiguratorUtility.getUtilityInfo();
			for (String eachRestrictedPayment : restrictedPaymentTypes) {
				System.assertEquals(false, info.paymentTypeOptions.contains(eachRestrictedPayment));
			}
		}
		Test.stopTest();
	}

	@IsTest
	static void testGetUtilityInfo_whenRunningUserProfileIsOtherThanAdminOrDealDesk_restrictedPaymentOptionsAreNOTShown() {
		List<String> restrictedPaymentTypes = BillingScheduleConfiguratorUtility.getRestrictedPaymentTypes();
		Test.startTest();
		System.runAs(TestUserFactory.createTaniumStandardUser()) {
			BillingScheduleConfiguratorUtility.Utility info = BillingScheduleConfiguratorUtility.getUtilityInfo();
			for (String eachRestrictedPayment : restrictedPaymentTypes) {
				System.assertEquals(false, info.paymentTypeOptions.contains(eachRestrictedPayment));
			}
		}
		Test.stopTest();
	}

	@IsTest
	static void testGetQuoteTerms_whenLockedOrUnlockedDates_customMetadataIsReturned() {
		Billing_Schedule_Configurator__mdt tool = [
			SELECT Id, QuoteTermsForLockedDates__c, QuoteTermsForUnlockedDates__c
			FROM Billing_Schedule_Configurator__mdt
			WHERE DeveloperName = 'BillingScheduleConfiguratorToolInfo'
			LIMIT 1
		];
		Test.startTest();
		System.assertEquals(
			tool.QuoteTermsForLockedDates__c,
			BillingScheduleConfiguratorUtility.getQuoteTermsForLockedDates()
		);
		System.assertEquals(
			tool.QuoteTermsForUnlockedDates__c,
			BillingScheduleConfiguratorUtility.getQuoteTermsForUnlockedDates()
		);
		Test.stopTest();
	}

	@IsTest
	static void testGetQuoteTerms_whenBillingOrder1_customMetadataIsReturned() {
		Billing_Schedule_Configurator__mdt tool = [
			SELECT Id, QuoteTermsForFirstBilling__c
			FROM Billing_Schedule_Configurator__mdt
			WHERE DeveloperName = 'BillingScheduleConfiguratorToolInfo'
			LIMIT 1
		];
		Test.startTest();
		System.assertEquals(
			tool.QuoteTermsForFirstBilling__c,
			BillingScheduleConfiguratorUtility.getQuoteTermsForFirstBilling()
		);
		Test.stopTest();
	}

	@IsTest
	static void testGetBillingScheduleFields_whenUtilityMethodIsCalled_customMetadataIsReturned() {
		Billing_Schedule_Configurator__mdt tool = [
			SELECT Id, Billing_Schedule_Fields__c
			FROM Billing_Schedule_Configurator__mdt
			WHERE DeveloperName = 'BillingScheduleConfiguratorToolInfo'
			LIMIT 1
		];
		Test.startTest();
		String expected = BillingScheduleConfiguratorUtility.getBillingScheduleFields();
		Test.stopTest();
		Assert.areEqual(expected, tool.Billing_Schedule_Fields__c);
	}

	@IsTest
	static void testGetQuoteTerms_whenUtilityMethodIsCalled_customMetadataIsReturned() {
		Billing_Schedule_Configurator__mdt tool = [
			SELECT Id, QuoteTermsForZeroDollars__c
			FROM Billing_Schedule_Configurator__mdt
			WHERE DeveloperName = 'BillingScheduleConfiguratorToolInfo'
			LIMIT 1
		];
		Test.startTest();
		if (!String.isBlank(BillingScheduleConfiguratorUtility.getQuoteTermsForZeroDollars())) {
			System.assertEquals(
				tool.QuoteTermsForZeroDollars__c,
				BillingScheduleConfiguratorUtility.getQuoteTermsForZeroDollars(),
				'String not empty'
			);
		} else {
			System.assertEquals(
				'',
				BillingScheduleConfiguratorUtility.getQuoteTermsForZeroDollars(),
				'Empty string'
			);
		}
		Test.stopTest();
	}

	@IsTest
	static void getProfilesWithRestrictedOppStageAccess_whenUtilityMethodIsCalled_ProfilesWithRestrictedOppStageAccessReturned() {
		Billing_Schedule_Configurator__mdt tool = [
			SELECT Id, ProfilesWithRestrictedOppStageAccess__c
			FROM Billing_Schedule_Configurator__mdt
			WHERE DeveloperName = 'BillingScheduleConfiguratorToolInfo'
			LIMIT 1
		];
		Test.startTest();
		System.assertEquals(
			tool.ProfilesWithRestrictedOppStageAccess__c.split(';'),
			BillingScheduleConfiguratorUtility.getProfilesWithRestrictedOppStageAccess()
		);
		Test.stopTest();
	}

	@IsTest
	static void getRestrictedOppStages_whenUtilityMethodIsCalled_RestrictedOppStagesReturned() {
		Billing_Schedule_Configurator__mdt tool = [
			SELECT Id, RestrictedOpportunityStagesForToolAccess__c
			FROM Billing_Schedule_Configurator__mdt
			WHERE DeveloperName = 'BillingScheduleConfiguratorToolInfo'
			LIMIT 1
		];
		Test.startTest();
		System.assertEquals(
			tool.RestrictedOpportunityStagesForToolAccess__c.toLowerCase().split(';'),
			BillingScheduleConfiguratorUtility.getRestrictedOppStages()
		);
		Test.stopTest();
	}

	@IsTest
	static void getOpportunityStage_whenOppIdIsPassed_QueryOppObjectReturnOppStage() {
		Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Name = 'Test Opp'];

		Test.startTest();
		String expected = BillingScheduleConfiguratorUtility.getOpportunityStage(opp.Id, 'Opportunity');
		String actual = opp.StageName;
		System.assertEquals(expected, actual);
		Test.stopTest();
	}

	@IsTest
	static void getOpportunityStage_whenQuoteIdIsPassed_QueryQuoteObjectReturnOppStage() {
		Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote'];

		Test.startTest();
		String expected = BillingScheduleConfiguratorUtility.getOpportunityStage(quote.Id, 'Quote');

		Quote quoteWithStage = [SELECT Id, Opportunity.StageName FROM Quote WHERE Id = :quote.Id];
		System.assertEquals(expected, quoteWithStage.Opportunity.StageName);
		Test.stopTest();
	}

	@IsTest
	static void formatBillingAmount_WhenUtilityMethodIsCalled_ReturnFormattedBillingAmount() {
		Decimal unformattedAmount = 123789.00;
		Test.startTest();
		String formattedAmount = BillingScheduleConfiguratorUtility.formatBillingAmount(
			unformattedAmount
		);
		Test.stopTest();

		System.assertEquals(
			'123,789.00',
			formattedAmount,
			'Billing Amount should have a format of XXX,XXX,XXX.XX'
		);
		System.assert(formattedAmount.contains(','), 'Formatted Billing Amount should have comma(,)');
	}

	@IsTest
	static void formatBillingDate_WhenUtilityMethodIsCalled_ReturnFormattedBillingDate() {
		Date unformattedDate = Date.newInstance(2025, 1, 30);

		Test.startTest();
		String formattedDate = BillingScheduleConfiguratorUtility.formatBillingDate(unformattedDate);
		Test.stopTest();

		System.assertEquals(
			'January 2025',
			formattedDate,
			'Billing Quote Terms should have the "MMMM YEAR" format"'
		);
	}

	@IsTest
	static void testGetUtilityInfo_whenHasAllTheInformation_returnsInfoSuccessfully() {
		BillingScheduleConfiguratorUtility.Utility utilityInfo;
		Test.startTest();
		utilityInfo = BillingScheduleConfiguratorUtility.getUtilityInfo();
		Test.stopTest();
		System.assertNotEquals(null, utilityInfo.paymentTypeOptions);
		System.assertNotEquals(null, utilityInfo.profilesWithRestrictedPaymentTypesAccess);
		System.assertNotEquals(null, utilityInfo.closedOpportunityError);
		System.assertNotEquals(null, utilityInfo.restrictedPaymentError);
	}

	@IsTest
	static void testGetPaymentTypeOptions_whenHasAllTheInformation_returnsPaymentOptionsSuccessfully() {
		List<String> paymentTypeOptions;
		Test.startTest();
		paymentTypeOptions = BillingScheduleConfiguratorUtility.getPaymentTypeOptions(null);
		Test.stopTest();
		System.assertEquals(true, paymentTypeOptions.size() > 0);
	}

	@IsTest
	static void testFormatBillingAmount_whenHasDecimal_returnsFormattedBillingAmount() {
		String formattedAmount;
		Test.startTest();
		formattedAmount = BillingScheduleConfiguratorUtility.formatBillingAmount(10000.60);
		System.assertEquals('10,000.60', formattedAmount);
		formattedAmount = BillingScheduleConfiguratorUtility.formatBillingAmount(10000);
		System.assertEquals('10,000.00', formattedAmount);
		formattedAmount = BillingScheduleConfiguratorUtility.formatBillingAmount(10000.0);
		System.assertEquals('10,000.00', formattedAmount);
		Test.stopTest();
	}

	@IsTest
	static void testGetBundleOptionTypesNotShownInTool_whenHasAllTheInformation_returnsBundleOptionTypesSuccessfully() {
		List<String> bundleOptionTypesNotShownInTool;
		Test.startTest();
		bundleOptionTypesNotShownInTool = BillingScheduleConfiguratorUtility.getBundleOptionTypesNotShownInTool();
		Test.stopTest();
		System.assertEquals(true, bundleOptionTypesNotShownInTool.size() > 0);
	}
}