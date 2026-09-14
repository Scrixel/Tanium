/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for DNB_AccountEnrichmentBatch class
 * @Date: 2026-06-10
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13236   2026-06-18    Initial development.
 * SS-13362   2026-06-26    Added tests for Secondary and NAICS fields.
 * SS-13855   2026-08-17    Updated tests for disabled Sector enrichment.
 */
@IsTest
private class DNB_AccountEnrichmentBatchTest {
	private static final List<String> BYPASSED_HANDLERS = new List<String>{
		'AccountTriggerHandler',
		'ContactTriggerHandler',
		'OpportunityTriggerHandler',
		'QuoteCPQTriggerHandler'
	};

	@TestSetup
	static void makeData() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		Account account;
		
		System.runAs(TestUserFactory.getAdminUser()) {
			bypassAutomation();
			profile = DNB_TestFactory.buildSubsidiaryProfile(
				'D&B Test Profile',
				new Map<String, Object>{ DNB_TestFactory.DUNS_NUMBER => '999999999' }
			);
			DNB_TestFactory.setSyncFlag(profile, false);
			insert profile;

			account = buildTestAccount('D&B Test Account');
			account.DNBConnect__D_B_Connect_Company_Profile__c = profile.Id;
			insert account;
		}
	}

	@IsTest
	static void testExecuteBatch_FullSuccess_MultipleAccountsEnrichedFlagCleared() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Account unflaggedAccount;
		Integer index;
		Account enrichedAccount;
		Map<Id, Account> accountMap;
		List<Account> accounts = new List<Account>();

		unflaggedAccount = getTestAccount();
		System.runAs(TestUserFactory.getAdminUser()) {
			bypassAutomation();
			companyProfile = createSubsidiaryProfile(fullEntityValues(), true);
			for (index = 0; index < 3; index++) {
				accounts.add(buildTestAccount('Acct ' + index));
			}
			DNB_TestFactory.linkAccounts(accounts, companyProfile.Id);
			insert accounts;
			clearAutomationBypass();

			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		accountMap = getAccounts(new Map<Id, Account>(accounts).keySet());
		for (Account account : accounts) {
			enrichedAccount = accountMap.get(account.Id);
			Assert.areEqual('Austin', enrichedAccount.HQ_City__c, 'HQ City should be enriched');
			Assert.areEqual('78701', enrichedAccount.HQ_Zip__c, 'HQ Zip should be enriched');
			Assert.areEqual(2500000, enrichedAccount.AnnualRevenue.intValue(), 'Annual Revenue should be enriched');
			Assert.areEqual(500, enrichedAccount.D_B_Employee_Count__c.intValue(), 'Employee count should be enriched');
			Assert.areEqual('https://www.example.com', enrichedAccount.Website, 'Website should be enriched');
			Assert.isNotNull(enrichedAccount.D_B_Last_Synced_Date__c, 'Last Synced should be stamped');
		}
		Assert.isFalse(isFlagSet(companyProfile.Id), 'Sync flag must be cleared after processing');
		Assert.areEqual(
			'San Francisco',
			getAccount(unflaggedAccount.Id).HQ_City__c,
			'Account under an unflagged Profile must be untouched (start() scoping)'
		);
	}

	@IsTest
	static void testExecuteBatch_EmptyResult_DoesNotOverwritePopulatedFields() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		account.AnnualRevenue = 12345;
		updateTestAccount(account);
		updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.WEBSITE => 'https://www.example.com' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('https://www.example.com', enrichedAccount.Website, 'Website should be enriched');
		Assert.areEqual(
			'San Francisco',
			enrichedAccount.HQ_City__c,
			'Empty resolved city must NOT overwrite the populated Account city (AC4)'
		);
		Assert.areEqual(
			12345,
			enrichedAccount.AnnualRevenue.intValue(),
			'Empty resolved revenue must NOT overwrite the populated Account revenue (AC4)'
		);
		Assert.isNotNull(enrichedAccount.D_B_Last_Synced_Date__c, 'Last Synced is stamped for every processed Account');
	}

	@IsTest
	static void testExecute_PartialFailure_FailedProfileKeepsFlagSucceededCleared() {
		DNBConnect__D_B_Connect_Company_Profile__c failingProfile;
		Account failingAccount;
		DNBConnect__D_B_Connect_Company_Profile__c okProfile;
		Account okAccount;

		bypassAutomation();
		failingProfile = createSubsidiaryProfile(
			new Map<String, Object>{ DNB_TestFactory.ENTITY_CITY => 'X'.repeat(60) },
			true
		);
		failingAccount = createLinkedAccount('Will Fail', failingProfile.Id);
		okProfile = createSubsidiaryProfile(
			new Map<String, Object>{ DNB_TestFactory.ENTITY_CITY => 'Austin' },
			true
		);
		okAccount = createLinkedAccount('Will Succeed', okProfile.Id);
		clearAutomationBypass();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		Assert.isTrue(
			isFlagSet(failingProfile.Id),
			'A failed Account keeps its Profile Sync flag TRUE so the nightly batch retries it'
		);
		Assert.isFalse(
			isFlagSet(okProfile.Id),
			'A successfully updated Account has its Profile Sync flag cleared'
		);
		Assert.isNull(
			getAccount(failingAccount.Id).D_B_Last_Synced_Date__c,
			'A failed Account is not stamped - flag TRUE + empty Last Synced is the failed-sync report'
		);
		Assert.areEqual('Austin', getAccount(okAccount.Id).HQ_City__c, 'Successful Account is enriched');
		Assert.isNotNull(getAccount(okAccount.Id).D_B_Last_Synced_Date__c, 'Successful Account is stamped');
	}

	@IsTest
	static void testExecute_ClearedFlag_AccountStaysOutOfScopeOnRerun() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		Account account;

		account = getTestAccount();
		profile = updateTestProfileForSync(fullEntityValues());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		Assert.isNotNull(
			getAccount(account.Id).D_B_Last_Synced_Date__c,
			'The run enriches the Account and stamps Last Synced'
		);
		Assert.isFalse(isFlagSet(profile.Id), 'The run clears the Sync flag');
		Assert.areEqual(
			0,
			scopeForBatch().size(),
			'A cleared Sync flag puts the Account out of scope, so a rerun would not reprocess it'
		);
	}

	@IsTest
	static void testStart_FlaggedProfile_ScopesToItsAccounts() {
		DNBConnect__D_B_Connect_Company_Profile__c flaggedProfile;
		Account accountUnderFlagged;
		Account unflaggedAccount;

		unflaggedAccount = getTestAccount();

		bypassAutomation();
		flaggedProfile = createSubsidiaryProfile(fullEntityValues(), true);
		accountUnderFlagged = createLinkedAccount('Under Flagged', flaggedProfile.Id);
		clearAutomationBypass();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		Assert.areEqual(
			'Austin',
			getAccount(accountUnderFlagged.Id).HQ_City__c,
			'Account under a flagged Profile is in scope and enriched'
		);
		Assert.areEqual(
			'San Francisco',
			getAccount(unflaggedAccount.Id).HQ_City__c,
			'Account under an unflagged Profile is out of scope and untouched'
		);
	}

	@IsTest
	static void testExecuteBatch_AccountFilter_ProcessesOnlyProvidedAccounts() {
		DNBConnect__D_B_Connect_Company_Profile__c profileIn;
		DNBConnect__D_B_Connect_Company_Profile__c profileOut;
		Account accountIn;
		Account accountOut;

		bypassAutomation();
		profileIn = createSubsidiaryProfile(fullEntityValues(), true);
		accountIn = createLinkedAccount('Filtered In', profileIn.Id);
		profileOut = createSubsidiaryProfile(fullEntityValues(), true);
		accountOut = createLinkedAccount('Filtered Out', profileOut.Id);
		clearAutomationBypass();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(new Set<Id>{ accountIn.Id }), 200);
			Test.stopTest();
		}

		Assert.areEqual(
			'Austin',
			getAccount(accountIn.Id).HQ_City__c,
			'Account passed in the filter is processed'
		);
		Assert.isFalse(
			isFlagSet(profileIn.Id),
			'Filtered-in Account clears its Profile Sync flag'
		);
		Assert.areEqual(
			'San Francisco',
			getAccount(accountOut.Id).HQ_City__c,
			'A flagged Account not in the filter is left untouched'
		);
		Assert.isTrue(
			isFlagSet(profileOut.Id),
			'A flagged Account not in the filter keeps its Sync flag for the next full run'
		);
	}

	@IsTest
	static void testExecuteBatch_Bulk_50ProfilesAllEnrichedAndCleared() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Account account;
		Integer index;
		List<Account> accounts = new List<Account>();
		List<DNBConnect__D_B_Connect_Company_Profile__c> profiles = new List<DNBConnect__D_B_Connect_Company_Profile__c>();

		System.runAs(TestUserFactory.getAdminUser()) {
			bypassAutomation();
			for (index = 0; index < 50; index++) {
				companyProfile = DNB_TestFactory.buildSubsidiaryProfile('Bulk ' + index, fullEntityValues());
				DNB_TestFactory.setSyncFlag(companyProfile, true);
				profiles.add(companyProfile);
			}
			insert profiles;

			for (index = 0; index < 50; index++) {
				account = buildTestAccount('Bulk Acct ' + index);
				account.DNBConnect__D_B_Connect_Company_Profile__c = profiles[index].Id;
				accounts.add(account);
			}
			insert accounts;
			clearAutomationBypass();

			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 50);
			Test.stopTest();
		}

		Assert.areEqual(
			50,
			[SELECT COUNT() FROM Account WHERE HQ_City__c = 'Austin'],
			'All 50 Accounts should be enriched'
		);
		Assert.areEqual(
			0,
			[
				SELECT COUNT()
				FROM DNBConnect__D_B_Connect_Company_Profile__c
				WHERE Sync_to_Account__c = TRUE
			],
			'All 50 Profile flags should be cleared'
		);
	}

	@IsTest
	static void testExecuteBatch_SameValuesAndUnmappableCountry_FlagStaysTrue() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		profile = updateTestProfileForSync(
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_CITY => 'San Francisco',
				DNB_TestFactory.ENTITY_COUNTRY => 'Atlantis'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.isNull(
			enrichedAccount.D_B_Last_Synced_Date__c,
			'HQ City already matched and the country is unmappable => nothing actually changed => not stamped'
		);
		Assert.isTrue(
			isFlagSet(profile.Id),
			'Re-writing identical values must NOT clear the flag; the unmappable country stays in the failed-sync report'
		);
	}

	@IsTest
	static void testExecuteBatch_UnmappableCountry_SkippedAndFlagStaysTrue() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		profile = updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'Atlantis' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.isNull(
			enrichedAccount.D_B_Last_Synced_Date__c,
			'An unmappable D&B country is not stamped'
		);
		Assert.isTrue(
			isFlagSet(profile.Id),
			'An unmappable D&B country keeps the Sync flag TRUE for the failed-sync report'
		);
		Assert.areEqual(
			'United States',
			enrichedAccount.BillingCountry,
			'An unmappable D&B country leaves Billing Country untouched'
		);
		Assert.areEqual(
			'United States',
			enrichedAccount.ShippingCountry,
			'An unmappable D&B country leaves Shipping Country untouched'
		);
	}

	@IsTest
	static void testExecuteBatch_LegitimatelyBlankSource_FlagCleared() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		profile = updateTestProfileForSync(new Map<String, Object>());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.isFalse(
			isFlagSet(profile.Id),
			'A legitimately blank D&B source is processed successfully => Sync flag cleared'
		);
		Assert.areEqual(
			'San Francisco',
			enrichedAccount.HQ_City__c,
			'A blank D&B source must not wipe the existing HQ City'
		);
		Assert.isNull(
			enrichedAccount.D_B_Last_Synced_Date__c,
			'Nothing was written, so Last Synced is not stamped'
		);
	}

	@IsTest
	static void testExecuteBatch_UnmappableState_SkippedAndFlagStaysTrue() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		profile = updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.HQ_REGION => 'ZZ' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual(
			'California',
			enrichedAccount.HQ_State__c,
			'An unmappable region code is not written and the existing HQ State is left untouched'
		);
		Assert.isTrue(
			isFlagSet(profile.Id),
			'A US/CA account with an unmappable D&B region code keeps the Sync flag TRUE'
		);
		Assert.isNull(
			enrichedAccount.D_B_Last_Synced_Date__c,
			'An unmappable region code writes nothing, so Last Synced is not stamped'
		);
	}

	@IsTest
	static void testExecuteBatch_HqCountryAndStatePopulated() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		account.HQ_Country__c = null;
		account.HQ_State__c = null;
		updateTestAccount(account);
		updateTestProfileForSync(
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'United States',
				DNB_TestFactory.HQ_REGION => 'CA'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('United States', enrichedAccount.HQ_Country__c, 'HQ Country populated from the D&B country name');
		Assert.areEqual(
			'California',
			enrichedAccount.HQ_State__c,
			'HQ State populated from the same-tier region code (CA => California)'
		);
	}

	@IsTest
	static void testExecuteBatch_NonUsCaCountry_StateCleared() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		updateTestProfileForSync(
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'Peru',
				DNB_TestFactory.HQ_REGION => 'LIM'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('Peru', enrichedAccount.HQ_Country__c, 'Non-US/CA country is still written to HQ Country');
		Assert.isNull(
			enrichedAccount.HQ_State__c,
			'Moving HQ Country to a non-US/CA value clears the existing US state to avoid an invalid dependent-picklist combo (SS-13236 bug 3)'
		);
		Assert.areEqual(
			'Peru',
			enrichedAccount.BillingCountry,
			'Moving into a non-state country must update Billing Country to match HQ Country'
		);
		Assert.areEqual(
			'Peru',
			enrichedAccount.ShippingCountry,
			'Moving into a non-state country must update Shipping Country too (not just Billing)'
		);
	}

	@IsTest
	static void testExecuteBatch_AccountUsCountryDnbCountryBlank_StatePopulated() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		account.HQ_State__c = null;
		updateTestAccount(account);
		updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.HQ_REGION => 'CA' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual(
			'United States',
			enrichedAccount.HQ_Country__c,
			'Existing US country is retained when D&B returns no country'
		);
		Assert.areEqual(
			'California',
			enrichedAccount.HQ_State__c,
			'HQ State resolves from the region code because the account country is US, even though D&B had no country'
		);
	}

	@IsTest
	static void testExecuteBatch_NonUsCaCountryCollidingStateCode_StateNotSet() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		account.HQ_State__c = null;
		updateTestAccount(account);
		updateTestProfileForSync(
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'Italy',
				DNB_TestFactory.HQ_REGION => 'CA'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('Italy', enrichedAccount.HQ_Country__c, 'Non-US/CA country is written to HQ Country');
		Assert.isNull(
			enrichedAccount.HQ_State__c,
			'Region code CA collides with California but HQ State stays blank because the account country is Italy'
		);
	}

	@IsTest
	static void testExecuteBatch_StaleNonUsCountry_DnbUsCountryAndRegion_StateWritten() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		account.HQ_Country__c = 'Italy';
		account.HQ_State__c = null;
		updateTestAccount(account);
		updateTestProfileForSync(
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'United States',
				DNB_TestFactory.HQ_REGION => 'CA'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual(
			'United States',
			enrichedAccount.HQ_Country__c,
			'D&B US country overwrites the stale non-US country'
		);
		Assert.areEqual(
			'California',
			enrichedAccount.HQ_State__c,
			'HQ State is written against the NEW US country in the same update (region CA => California), not the stale non-US country'
		);
	}

	@IsTest
	static void testExecuteBatch_CountryRelocationNoNewAddress_ClearsCityStateZip() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'France' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('France', enrichedAccount.HQ_Country__c, 'HQ Country relocates to the new D&B country');
		Assert.isNull(enrichedAccount.HQ_City__c, 'Relocation with no new D&B City clears the stale City');
		Assert.isNull(enrichedAccount.HQ_Zip__c, 'Relocation with no new D&B Zip clears the stale Zip');
		Assert.isNull(enrichedAccount.HQ_State__c, 'Relocation to a non-US/CA country clears the stale State');
	}

	@IsTest
	static void testExecuteBatch_CountryRelocationKeepsNewValueClearsMissing() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		updateTestProfileForSync(
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'France',
				DNB_TestFactory.ENTITY_CITY => 'Paris'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('France', enrichedAccount.HQ_Country__c, 'HQ Country relocates to France');
		Assert.areEqual('Paris', enrichedAccount.HQ_City__c, 'A new D&B City is written, not cleared');
		Assert.isNull(enrichedAccount.HQ_Zip__c, 'Zip has no new D&B value on relocation => cleared');
	}

	@IsTest
	static void testExecuteBatch_FirstCountryPopulation_KeepsExistingAddress() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		account.HQ_Country__c = null;
		updateTestAccount(account);
		updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'United States' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('United States', enrichedAccount.HQ_Country__c, 'HQ Country is populated for the first time');
		Assert.areEqual(
			'San Francisco',
			enrichedAccount.HQ_City__c,
			'Populating a previously-blank HQ Country is not a relocation, so existing City is kept'
		);
	}

	@IsTest
	static void testExecuteBatch_UsToCanadaNoNewState_ClearsStaleState() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'Canada' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('Canada', enrichedAccount.HQ_Country__c, 'HQ Country relocates US => Canada');
		Assert.isNull(
			enrichedAccount.HQ_State__c,
			'US state (California) is stale/invalid under Canada and D&B sent no new region => cleared'
		);
	}

	@IsTest
	static void testExecute_WhenScheduled_RegistersCronJob() {
		String jobId;
		List<CronTrigger> cronTriggers;

		Assert.isNotNull(new DNB_AccountEnrichmentBatch(), 'Default constructor builds a batch');
		Assert.isNotNull(new DNB_AccountEnrichmentBatch(0), 'Non-positive size falls back to the default');

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			jobId = System.schedule(
				'DnB Account Enrichment Test',
				'0 0 2 * * ?',
				new DNB_AccountEnrichmentBatch(50)
			);
			Test.stopTest();
		}

		cronTriggers = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
		Assert.areEqual(
			'0 0 2 * * ?',
			cronTriggers[0].CronExpression,
			'Scheduler must register the daily cron job'
		);
	}

	@IsTest
	static void testExecuteBatch_SecondaryPrioritiesPresent_IndustriesAndCodesPopulated() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		updateTestProfileForSync(
			new Map<String, Object>{
				DNB_TestFactory.NAICS_PRIORITY_2 => 'Other Computer Related Services',
				DNB_TestFactory.NAICS_PRIORITY_3 => 'Administrative Management Consulting Services',
				DNB_TestFactory.NAICS_PRIORITY_4 => 'Internet Publishing and Broadcasting',
				DNB_TestFactory.NAICS_CODE_PRIORITY_2 => '541519',
				DNB_TestFactory.NAICS_CODE_PRIORITY_3 => '541611',
				DNB_TestFactory.NAICS_CODE_PRIORITY_4 => '519130'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual(
			'Other Computer Related Services; Administrative Management Consulting Services; Internet Publishing and Broadcasting',
			enrichedAccount.Secondary_Industries__c,
			'Secondary Industries is populated from the Priority 2-6 NAICS descriptions'
		);
		Assert.areEqual(
			'541519; 541611; 519130',
			enrichedAccount.Secondary_Industry_Codes__c,
			'Secondary Industry Codes is populated from the Priority 2-6 NAICS codes'
		);
		Assert.isNotNull(
			enrichedAccount.D_B_Last_Synced_Date__c,
			'Last Synced is stamped for every processed Account'
		);
	}

	@IsTest
	static void testExecuteBatch_NoSecondaryPriorities_FieldsNotWritten() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.ENTITY_CITY => 'Austin' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual('Austin', enrichedAccount.HQ_City__c, 'The Account is still enriched from other D&B data');
		Assert.isNull(
			enrichedAccount.Secondary_Industries__c,
			'No Priority 2-6 values => Secondary Industries is left unwritten even when the Account is updated'
		);
		Assert.isNull(
			enrichedAccount.Secondary_Industry_Codes__c,
			'No Priority 2-6 values => Secondary Industry Codes is left unwritten even when the Account is updated'
		);
	}

	@IsTest
	static void testExecuteBatch_Priority1CodePresent_NaicsHierarchyPopulated() {
		Account account;
		Account enrichedAccount;

		account = getTestAccount();
		updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.NAICS_CODE_PRIORITY_1 => '111110' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.areEqual(
			'Agriculture, Forestry, Fishing and Hunting',
			enrichedAccount.NAICS_Sector__c,
			'NAICS Sector is the Priority 1 code truncated to 2 digits (11) mapped via NAICS_Lookup__mdt'
		);
		Assert.areEqual(
			'Crop Production',
			enrichedAccount.NAICS_Subsector__c,
			'NAICS Subsector is the Priority 1 code truncated to 3 digits (111) mapped via NAICS_Lookup__mdt'
		);
		Assert.areEqual(
			'Oilseed and Grain Farming',
			enrichedAccount.NAICS_Industry_Group__c,
			'NAICS Industry Group is the Priority 1 code truncated to 4 digits (1111) mapped via NAICS_Lookup__mdt'
		);
	}

	@IsTest
	static void testExecuteBatch_UnmappableNaics_SkippedAndFlagStaysTrue() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		Account account;
		Account enrichedAccount;

		DNB_AccountEnrichmentUtility.naicsLookupOverrides = new List<NAICS_Lookup__mdt>();
		account = getTestAccount();
		profile = updateTestProfileForSync(new Map<String, Object>{ DNB_TestFactory.NAICS_CODE_PRIORITY_1 => '999999' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Database.executeBatch(new DNB_AccountEnrichmentBatch(), 200);
			Test.stopTest();
		}

		enrichedAccount = getAccount(account.Id);
		Assert.isNull(
			enrichedAccount.NAICS_Sector__c,
			'A present NAICS code with no metadata match writes no rollup'
		);
		Assert.isTrue(
			isFlagSet(profile.Id),
			'A present NAICS code with no metadata match keeps the Sync flag TRUE for the failed-sync report'
		);
		Assert.isNull(
			enrichedAccount.D_B_Last_Synced_Date__c,
			'An unmappable NAICS code writes nothing, so Last Synced is not stamped'
		);
	}

	private static void bypassAutomation() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(BYPASSED_HANDLERS);
	}

	private static void clearAutomationBypass() {
		SBQQ.TriggerControl.enable();
		for (String handlerName : BYPASSED_HANDLERS) {
			TriggerHandler.clearBypass(handlerName);
		}
	}

	private static DNBConnect__D_B_Connect_Company_Profile__c updateTestProfileForSync(Map<String, Object> values) {
		List<DNBConnect__D_B_Connect_Company_Profile__c> profiles = [
			SELECT Id
			FROM DNBConnect__D_B_Connect_Company_Profile__c
			WHERE Name = 'D&B Test Profile'
		];
		DNBConnect__D_B_Connect_Company_Profile__c profile = profiles[0];
		for (String field : values.keySet()) {
			profile.put(field, values.get(field));
		}
		profile.Sync_to_Account__c = true;
		update profile;
		return profile;
	}

	private static Account getTestAccount() {
		List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'D&B Test Account'];
		return accounts[0];
	}

	private static void updateTestAccount(Account account) {
		bypassAutomation();
		update account;
		clearAutomationBypass();
	}

	private static Map<String, Object> fullEntityValues() {
		return new Map<String, Object>{
			DNB_TestFactory.ENTITY_CITY => 'Austin',
			DNB_TestFactory.ENTITY_ZIP => '78701',
			DNB_TestFactory.ENTITY_REV_VAL_1 => 2500000.0,
			DNB_TestFactory.ENTITY_REV_CUR_1 => 'USD',
			DNB_TestFactory.ENTITY_EMP => 500.0,
			DNB_TestFactory.WEBSITE => 'https://www.example.com',
			DNB_TestFactory.DESCRIPTION => 'Example company description'
		};
	}

	private static DNBConnect__D_B_Connect_Company_Profile__c createSubsidiaryProfile(
		Map<String, Object> values,
		Boolean flag
	) {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		companyProfile = DNB_TestFactory.buildSubsidiaryProfile('DnB Profile', values);
		DNB_TestFactory.setSyncFlag(companyProfile, flag);
		insert companyProfile;
		return companyProfile;
	}

	private static Account createLinkedAccount(String name, Id profileId) {
		Account account;

		System.runAs(TestUserFactory.getAdminUser()) {
			account = buildTestAccount(name);
			account.DNBConnect__D_B_Connect_Company_Profile__c = profileId;
			insert account;
		}
		return account;
	}

	private static Account buildTestAccount(String name) {
		Account account;
		account = TestFactory.buildAccount(name);
		account.BillingCountry = 'United States';
		account.BillingState = 'California';
		account.ShippingCountry = 'United States';
		account.ShippingState = 'California';
		return account;
	}

	private static List<Account> scopeForBatch() {
		return [
			SELECT
				Id,
				HQ_City__c,
				HQ_Zip__c,
				AnnualRevenue,
				D_B_Employee_Count__c,
				Website,
				Description,
				Sector__c,
				HQ_Country__c,
				HQ_State__c,
				Secondary_Industries__c,
				Secondary_Industry_Codes__c,
				NAICS_Sector__c,
				NAICS_Subsector__c,
				NAICS_Industry_Group__c,
				DNBConnect__D_B_Connect_Company_Profile__c
			FROM Account
			WHERE DNBConnect__D_B_Connect_Company_Profile__r.Sync_to_Account__c = TRUE
		];
	}

	private static Account getAccount(Id accountId) {
		return getAccounts(new Set<Id>{ accountId }).get(accountId);
	}

	private static Map<Id, Account> getAccounts(Set<Id> accountIds) {
		return new Map<Id, Account>(
			[
				SELECT Id, HQ_City__c, HQ_Zip__c, AnnualRevenue, D_B_Employee_Count__c, Website, Description, Sector__c, HQ_Country__c, HQ_State__c, BillingCountry, ShippingCountry, Secondary_Industries__c, Secondary_Industry_Codes__c, NAICS_Sector__c, NAICS_Subsector__c, NAICS_Industry_Group__c, D_B_Last_Synced_Date__c
				FROM Account
				WHERE Id IN :accountIds
			]
		);
	}

	private static Boolean isFlagSet(Id profileId) {
		List<DNBConnect__D_B_Connect_Company_Profile__c> profiles = [
			SELECT Sync_to_Account__c
			FROM DNBConnect__D_B_Connect_Company_Profile__c
			WHERE Id = :profileId
		];
		return profiles.isEmpty() ? null : profiles[0].Sync_to_Account__c;
	}
}