/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Batch class for copying D&B Connect Company Profile data to Accounts
 * @Date: 2026-06-10
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13236   2026-06-18    Initial development.
 * SS-13362   2026-06-25    Populate Secondary Industries/Codes and NAICS Sector/Subsector/Industry Group/Industry from D&B via NAICS_Lookup__mdt.
 * SS-13855   2026-08-17    Excluded Sector from batch enrichment.
 */
public without sharing class DNB_AccountEnrichmentBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
	@TestVisible
	private static final Integer DEFAULT_BATCH_SIZE = 200;
	@TestVisible
	private Set<Id> companyProfilesWithSuccessfulAccount = new Set<Id>();
	private Set<Id> accountIds;
	private Integer batchSize;

	public DNB_AccountEnrichmentBatch() {
		this((Set<Id>) null);
	}

	public DNB_AccountEnrichmentBatch(Set<Id> accountIds) {
		this.accountIds = accountIds;
		this.batchSize = DEFAULT_BATCH_SIZE;
	}

	public DNB_AccountEnrichmentBatch(Integer batchSize) {
		this.batchSize = (batchSize == null || batchSize <= 0) ? DEFAULT_BATCH_SIZE : batchSize;
	}

	public void execute(SchedulableContext sc) {
		Database.executeBatch(new DNB_AccountEnrichmentBatch(), batchSize);
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		Boolean runAll = (accountIds == null || accountIds.isEmpty());
		Set<Id> queryAccountIds = runAll ? new Set<Id>() : accountIds;
		return Database.getQueryLocator(
			[
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
					NAICS_Industry__c,
					BillingCountry,
					ShippingCountry,
					DNBConnect__D_B_Connect_Company_Profile__c
				FROM Account
				WHERE
					DNBConnect__D_B_Connect_Company_Profile__r.Sync_to_Account__c = TRUE
					AND (DNBConnect__D_B_Connect_Company_Profile__r.Sync_to_Account__c = :runAll
					OR Id IN :queryAccountIds)
			]
		);
	}

	public void execute(Database.BatchableContext bc, List<Account> accounts) {
		List<Account> accountsToUpdate = new List<Account>();
		Map<Id, Id> accountIdToCompanyProfileId = new Map<Id, Id>();
		Map<Id, DNBConnect__D_B_Connect_Company_Profile__c> companyProfileMap = getCompanyProfileMap(
			accounts
		);
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		EnrichmentResult result;

		for (Account account : accounts) {
			companyProfile = companyProfileMap.get(account.DNBConnect__D_B_Connect_Company_Profile__c);
			result = enrichAccount(account, companyProfile);
			if (result.isChanged) {
				accountIdToCompanyProfileId.put(
					account.Id,
					account.DNBConnect__D_B_Connect_Company_Profile__c
				);
				accountsToUpdate.add(account);
			} else if (!result.hasUnmappableValue) {
				companyProfilesWithSuccessfulAccount.add(
					account.DNBConnect__D_B_Connect_Company_Profile__c
				);
			}
		}

		updateAccounts(accountsToUpdate, accountIdToCompanyProfileId);
		Logger.saveLog();
	}

	private Map<Id, DNBConnect__D_B_Connect_Company_Profile__c> getCompanyProfileMap(
		List<Account> accounts
	) {
		Set<Id> companyProfileIds = new Set<Id>();
		for (Account account : accounts) {
			companyProfileIds.add(account.DNBConnect__D_B_Connect_Company_Profile__c);
		}
		return new Map<Id, DNBConnect__D_B_Connect_Company_Profile__c>(
			[
				SELECT
					Id,
					family_treeRole_GU_code__c,
					family_treeRole_DU_code__c,
					GU_primAddr_AddrLocal_name__c,
					DU_primAddr_AddrLocal_name__c,
					primAddr_AddrLocal_name__c,
					GU_primAddr_postalCode__c,
					DU_primAddr_postalCode__c,
					primAddr_postalCode__c,
					GU_Fins_yearlyRevenue_value_1__c,
					GU_Fins_yearlyRevenue_curr_1__c,
					GU_Fins_yearlyRevenue_value_2__c,
					GU_Fins_yearlyRevenue_curr_2__c,
					DU_Fins_yearlyRevenue_value_1__c,
					DU_Fins_yearlyRevenue_curr_1__c,
					DU_Fins_yearlyRevenue_value_2__c,
					DU_Fins_yearlyRevenue_curr_2__c,
					Fins_yearlyRevenue_value_1__c,
					Fins_yearlyRevenue_curr_1__c,
					Fins_yearlyRevenue_value_2__c,
					Fins_yearlyRevenue_curr_2__c,
					GU_numOfEmpl_value__c,
					DU_numOfEmpl_value__c,
					numberofemployees_val_Cons__c,
					organization_website_address_url__c,
					Sum_text__c,
					bizEntityType_Descr__c,
					GU_primAddr_Cntry_name__c,
					DU_primAddr_Cntry_name__c,
					primAddr_Cntry_name__c,
					IndustCodes_Descr_NAICS_priority1__c,
					IndustCodes_Descr_NAICS_priority2__c,
					IndustCodes_Descr_NAICS_priority3__c,
					IndustCodes_Descr_NAICS_priority4__c,
					IndustCodes_Descr_NAICS_priority5__c,
					IndustCodes_Descr_NAICS_priority6__c,
					IndustCodes_NAICS_priority1__c,
					IndustCodes_NAICS_priority2__c,
					IndustCodes_NAICS_priority3__c,
					IndustCodes_NAICS_priority4__c,
					IndustCodes_NAICS_priority5__c,
					IndustCodes_NAICS_priority6__c,
					GU_primAddr_Region_abbrName__c,
					DU_primAddr_Region_abbrName__c,
					primAddr_Region_abbrName__c
				FROM DNBConnect__D_B_Connect_Company_Profile__c
				WHERE Id IN :companyProfileIds
			]
		);
	}

	private EnrichmentResult enrichAccount(
		Account account,
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile
	) {
		EnrichmentResult result = new EnrichmentResult();
		Decimal revenue;
		Decimal employees;
		String website;
		String description;
		String sector;

		enrichAddressFields(account, companyProfile, result);
		enrichNaicsFields(account, companyProfile, result);

		revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
		if (revenue != null && revenue != 0 && account.AnnualRevenue != revenue) {
			account.AnnualRevenue = revenue;
			result.isChanged = true;
		}

		employees = DNB_AccountEnrichmentUtility.buildEmployeeCount(companyProfile);
		if (employees != null && employees != 0 && account.D_B_Employee_Count__c != employees) {
			account.D_B_Employee_Count__c = employees;
			result.isChanged = true;
		}

		website = DNB_AccountEnrichmentUtility.buildWebsite(companyProfile);
		if (String.isNotBlank(website) && account.Website != website) {
			account.Website = website;
			result.isChanged = true;
		}

		description = DNB_AccountEnrichmentUtility.buildDescription(companyProfile);
		if (String.isNotBlank(description) && account.Description != description) {
			account.Description = description;
			result.isChanged = true;
		}

		if (result.isChanged) {
			account.D_B_Last_Synced_Date__c = System.now();
		}
		return result;
	}

	private void enrichAddressFields(
		Account account,
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile,
		EnrichmentResult result
	) {
		Boolean isCountryRelocated = false;
		Boolean shouldSyncAddressCountry = false;
		String city;
		String zip;
		String state;
		String country;

		country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
		if (String.isBlank(country)) {
			if (DNB_AccountEnrichmentUtility.hasHqCountrySource(companyProfile)) {
				result.hasUnmappableValue = true;
			}
		} else if (account.HQ_Country__c != country) {
			isCountryRelocated = String.isNotBlank(account.HQ_Country__c);
			account.HQ_Country__c = country;
			result.isChanged = true;
			shouldSyncAddressCountry = true;
		}

		city = DNB_AccountEnrichmentUtility.buildHqCity(companyProfile);
		if (String.isNotBlank(city) && account.HQ_City__c != city) {
			account.HQ_City__c = city;
			result.isChanged = true;
		}

		zip = DNB_AccountEnrichmentUtility.buildHqZip(companyProfile);
		if (String.isNotBlank(zip) && account.HQ_Zip__c != zip) {
			account.HQ_Zip__c = zip;
			result.isChanged = true;
		}

		if (DNB_AccountEnrichmentUtility.isStateSupportedCountry(account.HQ_Country__c)) {
			state = DNB_AccountEnrichmentUtility.buildHqState(account, companyProfile);
			if (String.isBlank(state)) {
				if (DNB_AccountEnrichmentUtility.hasHqRegionSource(companyProfile)) {
					result.hasUnmappableValue = true;
				}
			} else if (account.HQ_State__c != state) {
				account.HQ_State__c = state;
				result.isChanged = true;
				shouldSyncAddressCountry = true;
			}
		} else {
			account.HQ_State__c = null;
		}

		if (isCountryRelocated && String.isBlank(city)) {
			account.HQ_City__c = null;
		}
		if (isCountryRelocated && String.isBlank(zip)) {
			account.HQ_Zip__c = null;
		}
		if (isCountryRelocated && String.isBlank(state)) {
			account.HQ_State__c = null;
		}

		if (shouldSyncAddressCountry && String.isNotBlank(account.HQ_Country__c)) {
			account.BillingCountry = account.HQ_Country__c;
			account.ShippingCountry = account.HQ_Country__c;
		}
	}

	private void enrichNaicsFields(
		Account account,
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile,
		EnrichmentResult result
	) {
		Boolean isNaicsRollupMapped;
		String secondaryIndustries;
		String secondaryIndustryCodes;
		String naicsSector;
		String naicsSubsector;
		String naicsIndustryGroup;
		String naicsIndustry;

		secondaryIndustries = DNB_AccountEnrichmentUtility.buildSecondaryIndustries(companyProfile);
		if (
			String.isNotBlank(secondaryIndustries) &&
			account.Secondary_Industries__c != secondaryIndustries
		) {
			account.Secondary_Industries__c = secondaryIndustries;
			result.isChanged = true;
		}

		secondaryIndustryCodes = DNB_AccountEnrichmentUtility.buildSecondaryIndustryCodes(
			companyProfile
		);
		if (
			String.isNotBlank(secondaryIndustryCodes) &&
			account.Secondary_Industry_Codes__c != secondaryIndustryCodes
		) {
			account.Secondary_Industry_Codes__c = secondaryIndustryCodes;
			result.isChanged = true;
		}

		naicsSector = DNB_AccountEnrichmentUtility.buildNaicsSector(companyProfile);
		if (String.isNotBlank(naicsSector) && account.NAICS_Sector__c != naicsSector) {
			account.NAICS_Sector__c = naicsSector;
			result.isChanged = true;
		}

		naicsSubsector = DNB_AccountEnrichmentUtility.buildNaicsSubsector(companyProfile);
		if (String.isNotBlank(naicsSubsector) && account.NAICS_Subsector__c != naicsSubsector) {
			account.NAICS_Subsector__c = naicsSubsector;
			result.isChanged = true;
		}

		naicsIndustryGroup = DNB_AccountEnrichmentUtility.buildNaicsIndustryGroup(companyProfile);
		if (
			String.isNotBlank(naicsIndustryGroup) &&
			account.NAICS_Industry_Group__c != naicsIndustryGroup
		) {
			account.NAICS_Industry_Group__c = naicsIndustryGroup;
			result.isChanged = true;
		}

		naicsIndustry = DNB_AccountEnrichmentUtility.buildNaicsIndustry(companyProfile);
		if (String.isNotBlank(naicsIndustry) && account.NAICS_Industry__c != naicsIndustry) {
			account.NAICS_Industry__c = naicsIndustry;
			result.isChanged = true;
		}

		isNaicsRollupMapped =
			String.isNotBlank(naicsSector) ||
			String.isNotBlank(naicsSubsector) ||
			String.isNotBlank(naicsIndustryGroup) ||
			String.isNotBlank(naicsIndustry);
		if (DNB_AccountEnrichmentUtility.hasNaicsSource(companyProfile) && !isNaicsRollupMapped) {
			result.hasUnmappableValue = true;
		}
	}

	private void updateAccounts(
		List<Account> accountsToUpdate,
		Map<Id, Id> accountIdToCompanyProfileId
	) {
		Integer index;
		Id successfulAccountId;
		List<Database.SaveResult> results = Database.update(accountsToUpdate, false);
		for (index = 0; index < results.size(); index++) {
			if (results[index].isSuccess()) {
				successfulAccountId = accountsToUpdate[index].Id;
				companyProfilesWithSuccessfulAccount.add(
					accountIdToCompanyProfileId.get(successfulAccountId)
				);
			}
		}
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'DNB_AccountEnrichmentBatch.execute ERRORS',
				results
			)
			.addTag('apex')
			.addTag('batch');
	}

	private void clearSyncFlags() {
		List<DNBConnect__D_B_Connect_Company_Profile__c> companyProfilesToReset = new List<DNBConnect__D_B_Connect_Company_Profile__c>();
		for (Id companyProfileId : companyProfilesWithSuccessfulAccount) {
			companyProfilesToReset.add(
				new DNBConnect__D_B_Connect_Company_Profile__c(
					Id = companyProfileId,
					Sync_to_Account__c = false
				)
			);
		}
		Database.update(companyProfilesToReset, false);
	}

	public void finish(Database.BatchableContext bc) {
		clearSyncFlags();
		Utility.logBatchErrors(bc, 'DNB_AccountEnrichmentBatch');
	}

	private class EnrichmentResult {
		private Boolean isChanged = false;
		private Boolean hasUnmappableValue = false;
	}
}