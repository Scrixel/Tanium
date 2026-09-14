/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class for DNB_AccountEnrichmentBatch class
 * @Date: 2026-06-10
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13236   2026-06-18    Initial development.
 * SS-13362   2026-06-25    Populate Secondary Industries/Codes and NAICS Sector/Subsector/Industry Group/Industry from D&B via NAICS_Lookup__mdt.
 */
public with sharing class DNB_AccountEnrichmentUtility {
	private static final Integer DESCRIPTION_MAX_LENGTH = 32000;
	private static final String MULTI_VALUE_DELIMITER = '; ';

	private static final String COUNTRY_UNITED_STATES = 'United States';
	private static final String COUNTRY_CANADA = 'Canada';
	private static final Set<String> STATE_SUPPORTED_COUNTRIES = new Set<String>{
		COUNTRY_UNITED_STATES,
		COUNTRY_CANADA
	};
	private static final String BIZ_TYPE_NATIONAL_GOV = 'National Government Entity';
	private static final String BIZ_TYPE_REGIONAL_LOCAL_GOV = 'Regional/Local Government Entity';
	private static final String NAICS_NATIONAL_SECURITY = 'national security';

	private static final String SECTOR_FEDERAL_DOD = 'Federal - DoD';
	private static final String SECTOR_FEDERAL_CIVILIAN = 'Federal - Civilian';
	private static final String SECTOR_SLED = 'SLED';
	private static final String SECTOR_PUBLIC_INTERNATIONAL = 'Public Sector - International';
	private static final String SECTOR_COMMERCIAL = 'Commercial';

	private static final String SYSTEM_DNB = 'D&B';

	private static final Integer NAICS_LEVEL_SECTOR = 2;
	private static final Integer NAICS_LEVEL_SUBSECTOR = 3;
	private static final Integer NAICS_LEVEL_INDUSTRY_GROUP = 4;
	private static final Integer NAICS_LEVEL_INDUSTRY = 5;

	@TestVisible
	private static List<NAICS_Lookup__mdt> naicsLookupOverrides;
	private static Map<String, String> naicsCodeAndLevelToDescription;

	public static String buildHqCity(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		List<String> cityByTier = new List<String>{
			companyProfile.GU_primAddr_AddrLocal_name__c,
			companyProfile.DU_primAddr_AddrLocal_name__c,
			companyProfile.primAddr_AddrLocal_name__c
		};
		return normalizeBlankValue(cityByTier[tierStartIndex(companyProfile)]);
	}

	public static String buildHqZip(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		List<String> zipByTier = new List<String>{
			companyProfile.GU_primAddr_postalCode__c,
			companyProfile.DU_primAddr_postalCode__c,
			companyProfile.primAddr_postalCode__c
		};
		return normalizeBlankValue(zipByTier[tierStartIndex(companyProfile)]);
	}

	public static Decimal buildAnnualRevenue(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		Integer tierIndex;
		Decimal result;
		Decimal entityUsd = usdForTier(
			companyProfile.Fins_yearlyRevenue_value_1__c,
			companyProfile.Fins_yearlyRevenue_curr_1__c,
			companyProfile.Fins_yearlyRevenue_value_2__c,
			companyProfile.Fins_yearlyRevenue_curr_2__c
		);
		List<Decimal> usdByTier = new List<Decimal>{
			usdForTier(
				companyProfile.GU_Fins_yearlyRevenue_value_1__c,
				companyProfile.GU_Fins_yearlyRevenue_curr_1__c,
				companyProfile.GU_Fins_yearlyRevenue_value_2__c,
				companyProfile.GU_Fins_yearlyRevenue_curr_2__c
			),
			usdForTier(
				companyProfile.DU_Fins_yearlyRevenue_value_1__c,
				companyProfile.DU_Fins_yearlyRevenue_curr_1__c,
				companyProfile.DU_Fins_yearlyRevenue_value_2__c,
				companyProfile.DU_Fins_yearlyRevenue_curr_2__c
			),
			entityUsd
		};
		tierIndex = tierStartIndex(companyProfile);
		result = usdByTier[tierIndex];
		if (result == null && tierIndex != 2) {
			result = entityUsd;
		}
		return normalizeZeroValue(result);
	}

	public static Decimal buildEmployeeCount(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		List<Decimal> employeesByTier = new List<Decimal>{
			companyProfile.GU_numOfEmpl_value__c,
			companyProfile.DU_numOfEmpl_value__c,
			companyProfile.numberofemployees_val_Cons__c
		};
		return normalizeZeroValue(employeesByTier[tierStartIndex(companyProfile)]);
	}

	public static String buildWebsite(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		String result;
		if (String.isNotBlank(companyProfile.organization_website_address_url__c)) {
			result = companyProfile.organization_website_address_url__c;
		}
		return result;
	}

	public static String buildDescription(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		String result;
		String value;
		value = companyProfile.Sum_text__c;
		if (String.isNotBlank(value)) {
			result = value.length() > DESCRIPTION_MAX_LENGTH ? value.substring(0, DESCRIPTION_MAX_LENGTH) : value;
		}
		return result;
	}

	public static String buildSector(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		String result;
		String bizEntityType;
		String hqCountry;
		Boolean isUnitedStates;
		Boolean isNationalGovernment;
		Boolean isRegionalLocalGovernment;
		Boolean hasNationalSecurityNaics;

		bizEntityType = companyProfile.bizEntityType_Descr__c;
		if (String.isBlank(bizEntityType)) {
			result = '';
		} else {
			hqCountry = hqCountryForTier(companyProfile);
			isUnitedStates = hqCountry == COUNTRY_UNITED_STATES;
			isNationalGovernment = bizEntityType == BIZ_TYPE_NATIONAL_GOV;
			isRegionalLocalGovernment = bizEntityType == BIZ_TYPE_REGIONAL_LOCAL_GOV;
			hasNationalSecurityNaics = containsNationalSecurity(
				companyProfile.IndustCodes_Descr_NAICS_priority1__c
			);

			if (isNationalGovernment && isUnitedStates && hasNationalSecurityNaics) {
				result = SECTOR_FEDERAL_DOD;
			} else if (isNationalGovernment && isUnitedStates) {
				result = SECTOR_FEDERAL_CIVILIAN;
			} else if (isRegionalLocalGovernment && isUnitedStates) {
				result = SECTOR_SLED;
			} else if ((isNationalGovernment || isRegionalLocalGovernment) && !isUnitedStates) {
				result = SECTOR_PUBLIC_INTERNATIONAL;
			} else {
				result = SECTOR_COMMERCIAL;
			}
		}
		return result;
	}

	public static String buildHqCountry(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return StateCountryMappingUtility.translateCountry(SYSTEM_DNB, hqCountryForTier(companyProfile));
	}

	public static String buildHqState(Account account, DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		String result;
		if (isStateSupportedCountry(account.HQ_Country__c)) {
			result = StateCountryMappingUtility.translateState(
				SYSTEM_DNB,
				regionAbbrForTier(companyProfile),
				account.HQ_Country__c
			);
		}
		return result;
	}

	public static Boolean isStateSupportedCountry(String country) {
		return STATE_SUPPORTED_COUNTRIES.contains(country);
	}

	public static String buildSecondaryIndustries(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		List<String> descriptionsByPriority = new List<String>{
			companyProfile.IndustCodes_Descr_NAICS_priority2__c,
			companyProfile.IndustCodes_Descr_NAICS_priority3__c,
			companyProfile.IndustCodes_Descr_NAICS_priority4__c,
			companyProfile.IndustCodes_Descr_NAICS_priority5__c,
			companyProfile.IndustCodes_Descr_NAICS_priority6__c
		};
		return buildNonBlankPriorityValues(descriptionsByPriority);
	}

	public static String buildSecondaryIndustryCodes(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		List<String> codesByPriority = new List<String>{
			companyProfile.IndustCodes_NAICS_priority2__c,
			companyProfile.IndustCodes_NAICS_priority3__c,
			companyProfile.IndustCodes_NAICS_priority4__c,
			companyProfile.IndustCodes_NAICS_priority5__c,
			companyProfile.IndustCodes_NAICS_priority6__c
		};
		return buildNonBlankPriorityValues(codesByPriority);
	}

	public static String buildNaicsSector(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return buildNaicsDescription(companyProfile, NAICS_LEVEL_SECTOR);
	}

	public static String buildNaicsSubsector(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return buildNaicsDescription(companyProfile, NAICS_LEVEL_SUBSECTOR);
	}

	public static String buildNaicsIndustryGroup(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return buildNaicsDescription(companyProfile, NAICS_LEVEL_INDUSTRY_GROUP);
	}

	public static String buildNaicsIndustry(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return buildNaicsDescription(companyProfile, NAICS_LEVEL_INDUSTRY);
	}
	
	public static Boolean hasHqCountrySource(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return String.isNotBlank(hqCountryForTier(companyProfile));
	}

	public static Boolean hasHqRegionSource(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return String.isNotBlank(regionAbbrForTier(companyProfile));
	}

	public static Boolean hasNaicsSource(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		return String.isNotBlank(companyProfile.IndustCodes_NAICS_priority1__c);
	}

	@TestVisible
	private static Integer tierStartIndex(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		Integer index;
		if (String.isNotBlank(companyProfile.family_treeRole_GU_code__c)) {
			index = 0;
		} else if (String.isNotBlank(companyProfile.family_treeRole_DU_code__c)) {
			index = 1;
		} else {
			index = 2;
		}
		return index;
	}

	private static String normalizeBlankValue(String value) {
		return String.isBlank(value) ? null : value;
	}

	private static Decimal normalizeZeroValue(Decimal value) {
		return (value == null || value == 0) ? null : value;
	}

	private static Decimal usdForTier(Decimal value1, String currency1, Decimal value2, String currency2) {
		Decimal result;
		if ('USD'.equalsIgnoreCase(currency1)) {
			result = value1;
		} else if ('USD'.equalsIgnoreCase(currency2)) {
			result = value2;
		}
		return result;
	}

	private static String hqCountryForTier(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		List<String> countryByTier = new List<String>{
			companyProfile.GU_primAddr_Cntry_name__c,
			companyProfile.DU_primAddr_Cntry_name__c,
			companyProfile.primAddr_Cntry_name__c
		};
		return countryByTier[tierStartIndex(companyProfile)];
	}

	private static String regionAbbrForTier(DNBConnect__D_B_Connect_Company_Profile__c companyProfile) {
		List<String> regionAbbrByTier = new List<String>{
			companyProfile.GU_primAddr_Region_abbrName__c,
			companyProfile.DU_primAddr_Region_abbrName__c,
			companyProfile.primAddr_Region_abbrName__c
		};
		return regionAbbrByTier[tierStartIndex(companyProfile)];
	}

	private static Boolean containsNationalSecurity(String naicsDescription) {
		return String.isNotBlank(naicsDescription) &&
			naicsDescription.containsIgnoreCase(NAICS_NATIONAL_SECURITY);
	}

	private static String buildNonBlankPriorityValues(List<String> priorityValues) {
		List<String> populatedValues = new List<String>();
		String result;
		for (String priorityValue : priorityValues) {
			if (String.isNotBlank(priorityValue)) {
				populatedValues.add(priorityValue);
			}
		}
		result = populatedValues.isEmpty()
			? null
			: String.join(populatedValues, MULTI_VALUE_DELIMITER);
		return result;
	}

	private static String buildNaicsDescription(
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile,
		Integer level
	) {
		String result;
		String truncatedCode;
		String primaryCode = companyProfile.IndustCodes_NAICS_priority1__c;
		if (String.isNotBlank(primaryCode) && primaryCode.length() >= level) {
			truncatedCode = primaryCode.substring(0, level);
			result = naicsDescriptions().get(naicsKey(truncatedCode, level));
		}
		return result;
	}

	private static Map<String, String> naicsDescriptions() {
		if (naicsCodeAndLevelToDescription == null) {
			naicsCodeAndLevelToDescription = new Map<String, String>();
			for (NAICS_Lookup__mdt lookup : naicsLookupRecords()) {
				naicsCodeAndLevelToDescription.put(
					naicsKey(lookup.NAICS_Code__c, lookup.NAICS_Level__c.intValue()),
					lookup.NAICS_Description__c
				);
			}
		}
		return naicsCodeAndLevelToDescription;
	}

	private static List<NAICS_Lookup__mdt> naicsLookupRecords() {
		return naicsLookupOverrides ?? NAICS_Lookup__mdt.getAll().values();
	}

	private static String naicsKey(String code, Integer level) {
		return code + '|' + level;
	}
}