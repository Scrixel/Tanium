/**
 * Copyright (c) 2026 Tanium
 * 
 * @Business: Test class for DNB_AccountEnrichmentUtility class
 * @Date: 2026-06-10
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13236   2026-06-18    Initial development.
 * SS-13362   2026-06-25    Tests for Secondary Industries/Codes and NAICS Sector/Subsector/Industry Group population.
 */
@IsTest
private class DNB_AccountEnrichmentUtilityTest {
	@IsTest
	static void testResolve_SubsidiaryWithAncestorData_UsesEntityValuesOnly() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String city;
		Decimal employees;
		Decimal revenue;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Federal Contractor Subsidiary',
			new Map<String, Object>{
				DNB_TestFactory.GU_CITY => 'Washington',
				DNB_TestFactory.GU_EMP => 2770000.0,
				DNB_TestFactory.GU_REV_VAL_1 => 0.0,
				DNB_TestFactory.GU_REV_CUR_1 => 'USD',
				DNB_TestFactory.ENTITY_CITY => 'Austin',
				DNB_TestFactory.ENTITY_EMP => 500.0,
				DNB_TestFactory.ENTITY_REV_VAL_1 => 1000000.0,
				DNB_TestFactory.ENTITY_REV_CUR_1 => 'USD'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			city = DNB_AccountEnrichmentUtility.buildHqCity(companyProfile);
			employees = DNB_AccountEnrichmentUtility.buildEmployeeCount(companyProfile);
			revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('Austin', city, 'Subsidiary must use entity city, not GU');
		Assert.areEqual(500, employees.intValue(), 'Subsidiary must use entity headcount, not the 2.77M GU figure');
		Assert.areEqual(1000000, revenue.intValue(), 'Subsidiary must use entity revenue, not the GU $0');
	}

	@IsTest
	static void testResolve_Subsidiary_NeverReceivesGuOrDuValues() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String city;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Subsidiary No Entity Data',
			new Map<String, Object>{
				DNB_TestFactory.GU_CITY => 'GlobalParentCity',
				DNB_TestFactory.DU_CITY => 'DomesticParentCity'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			city = DNB_AccountEnrichmentUtility.buildHqCity(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(city, 'A subsidiary with empty entity city must resolve to null - never cascade up to GU/DU');
	}

	@IsTest
	static void testResolve_GlobalUltimate_ResolvesViaGuTier() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String city;
		Decimal revenue;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'Global Ultimate',
			new Map<String, Object>{
				DNB_TestFactory.GU_CITY => 'GlobalCity',
				DNB_TestFactory.ENTITY_CITY => 'LocalBranch',
				DNB_TestFactory.GU_REV_VAL_1 => 5000000.0,
				DNB_TestFactory.GU_REV_CUR_1 => 'USD',
				DNB_TestFactory.ENTITY_REV_VAL_1 => 100.0,
				DNB_TestFactory.ENTITY_REV_CUR_1 => 'USD'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			city = DNB_AccountEnrichmentUtility.buildHqCity(companyProfile);
			revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('GlobalCity', city, 'GU record resolves city via the GU tier');
		Assert.areEqual(5000000, revenue.intValue(), 'GU record resolves revenue via the GU tier');
	}

	@IsTest
	static void testResolve_DomesticUltimateForeignParent_UsesDuNotGu() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String city;

		companyProfile = DNB_TestFactory.buildDomesticUltimateProfile(
			'Domestic Ultimate Foreign Parent',
			new Map<String, Object>{
				DNB_TestFactory.GU_CITY => 'ForeignParentCity',
				DNB_TestFactory.DU_CITY => 'DomesticCity',
				DNB_TestFactory.ENTITY_CITY => 'EntityCity'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			city = DNB_AccountEnrichmentUtility.buildHqCity(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('DomesticCity', city, 'DU-only record resolves via DU, never the foreign GU parent');
	}

	@IsTest
	static void testResolve_GuStartButGuEmpty_ReturnsNullNoCascade() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String city;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'GU Empty No Cascade',
			new Map<String, Object>{
				DNB_TestFactory.DU_CITY => 'Denver',
				DNB_TestFactory.ENTITY_CITY => 'Austin'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			city = DNB_AccountEnrichmentUtility.buildHqCity(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(
			city,
			'GU code present but GU city blank => null'
		);
	}

	@IsTest
	static void testResolve_RevenueUsdInSlot2_PicksUsdValue() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Decimal revenue;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'ZAR then USD',
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_REV_VAL_1 => 999.0,
				DNB_TestFactory.ENTITY_REV_CUR_1 => 'ZAR',
				DNB_TestFactory.ENTITY_REV_VAL_2 => 2500000.0,
				DNB_TestFactory.ENTITY_REV_CUR_2 => 'USD'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(2500000, revenue.intValue(), 'Must select the USD figure from slot 2, not the ZAR slot 1');
	}

	@IsTest
	static void testResolve_NoUsdAtAnyTier_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Decimal revenue;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'No USD',
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_REV_VAL_1 => 999.0,
				DNB_TestFactory.ENTITY_REV_CUR_1 => 'ZAR',
				DNB_TestFactory.ENTITY_REV_VAL_2 => 888.0,
				DNB_TestFactory.ENTITY_REV_CUR_2 => 'EUR'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(revenue, 'With no USD slot at any tier, revenue resolves to null (Account left unchanged)');
	}

	@IsTest
	static void testResolve_GuNoUsd_FallsBackToEntityRevenueNotDu() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Decimal revenue;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'GU No USD Falls Back To Entity',
			new Map<String, Object>{
				DNB_TestFactory.GU_REV_VAL_1 => 9000000.0,
				DNB_TestFactory.GU_REV_CUR_1 => 'EUR',
				DNB_TestFactory.DU_REV_VAL_1 => 7000000.0,
				DNB_TestFactory.DU_REV_CUR_1 => 'USD',
				DNB_TestFactory.ENTITY_REV_VAL_1 => 2500000.0,
				DNB_TestFactory.ENTITY_REV_CUR_1 => 'USD'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(
			2500000,
			revenue.intValue(),
			'GU tier has no USD => fall back to the entity tier (2,500,000), never the DU tier (per formula)'
		);
	}

	@IsTest
	static void testResolve_ZeroRevenueAndHeadcount_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Decimal revenue;
		Decimal employees;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Zero Values',
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_REV_VAL_1 => 0.0,
				DNB_TestFactory.ENTITY_REV_CUR_1 => 'USD',
				DNB_TestFactory.ENTITY_EMP => 0.0
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
			employees = DNB_AccountEnrichmentUtility.buildEmployeeCount(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(revenue, 'A USD revenue of 0 is treated as no-data');
		Assert.isNull(employees, 'A headcount of 0 is treated as no-data');
	}

	@IsTest
	static void testResolve_AllTiersEmpty_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String city;
		String zip;
		String website;
		String description;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile('Empty', new Map<String, Object>());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			city = DNB_AccountEnrichmentUtility.buildHqCity(companyProfile);
			zip = DNB_AccountEnrichmentUtility.buildHqZip(companyProfile);
			website = DNB_AccountEnrichmentUtility.buildWebsite(companyProfile);
			description = DNB_AccountEnrichmentUtility.buildDescription(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(city, 'No city at any tier => null');
		Assert.isNull(zip, 'No zip at any tier => null');
		Assert.isNull(website, 'No website => null');
		Assert.isNull(description, 'No description => null');
	}

	@IsTest
	static void testResolve_DescriptionOver32k_Truncated() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String description;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Long Description',
			new Map<String, Object>{ DNB_TestFactory.DESCRIPTION => 'a'.repeat(40000) }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			description = DNB_AccountEnrichmentUtility.buildDescription(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(32000, description.length(), 'Description must be hard-truncated to 32,000 characters');
	}

	@IsTest
	static void testResolve_WebsiteAndZip_EntityValuesResolved() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String website;
		String zip;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Website And Zip',
			new Map<String, Object>{
				DNB_TestFactory.WEBSITE => 'https://www.example.com',
				DNB_TestFactory.ENTITY_ZIP => '78701'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			website = DNB_AccountEnrichmentUtility.buildWebsite(companyProfile);
			zip = DNB_AccountEnrichmentUtility.buildHqZip(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('https://www.example.com', website, 'Website is an entity passthrough');
		Assert.areEqual('78701', zip, 'Zip resolves from the entity tier');
	}

	@IsTest
	static void testTierStartIndex_ByRoleCode_ReturnsTierIndex() {
		DNBConnect__D_B_Connect_Company_Profile__c globalUltimate;
		DNBConnect__D_B_Connect_Company_Profile__c domesticUltimate;
		DNBConnect__D_B_Connect_Company_Profile__c subsidiary;
		Integer globalUltimateIndex;
		Integer domesticUltimateIndex;
		Integer subsidiaryIndex;

		globalUltimate = DNB_TestFactory.buildGlobalUltimateProfile('GU', null);
		domesticUltimate = DNB_TestFactory.buildDomesticUltimateProfile('DU', null);
		subsidiary = DNB_TestFactory.buildSubsidiaryProfile('Sub', null);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			globalUltimateIndex = DNB_AccountEnrichmentUtility.tierStartIndex(globalUltimate);
			domesticUltimateIndex = DNB_AccountEnrichmentUtility.tierStartIndex(domesticUltimate);
			subsidiaryIndex = DNB_AccountEnrichmentUtility.tierStartIndex(subsidiary);
			Test.stopTest();
		}

		Assert.areEqual(0, globalUltimateIndex, 'GU code populated => start at GU (index 0)');
		Assert.areEqual(1, domesticUltimateIndex, 'DU code only => start at DU (index 1)');
		Assert.areEqual(2, subsidiaryIndex, 'Neither code => start at entity (index 2)');
	}

	@IsTest
	static void testResolveSector_NationalGovUsNationalSecurity_ReturnsFederalDoD() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String sector;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Federal DoD',
			new Map<String, Object>{
				DNB_TestFactory.BIZ_ENTITY_TYPE => 'National Government Entity',
				DNB_TestFactory.ENTITY_COUNTRY => 'United States',
				DNB_TestFactory.NAICS_PRIORITY_1 => 'National Security'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildSector(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(
			'Federal - DoD',
			sector,
			'National gov + US + National Security NAICS => Federal - DoD'
		);
	}

	@IsTest
	static void testResolveSector_NationalGovUsNoNationalSecurity_ReturnsFederalCivilian() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String sector;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Federal Civilian',
			new Map<String, Object>{
				DNB_TestFactory.BIZ_ENTITY_TYPE => 'National Government Entity',
				DNB_TestFactory.ENTITY_COUNTRY => 'United States',
				DNB_TestFactory.NAICS_PRIORITY_1 => 'Public Administration'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildSector(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(
			'Federal - Civilian',
			sector,
			'National gov + US without National Security NAICS => Federal - Civilian'
		);
	}

	@IsTest
	static void testResolveSector_RegionalLocalGovUs_ReturnsSled() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String sector;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'SLED',
			new Map<String, Object>{
				DNB_TestFactory.BIZ_ENTITY_TYPE => 'Regional/Local Government Entity',
				DNB_TestFactory.ENTITY_COUNTRY => 'United States'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildSector(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('SLED', sector, 'Regional/Local gov + US => SLED');
	}

	@IsTest
	static void testResolveSector_GovNonUs_ReturnsPublicSectorInternational() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String sector;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'International Public Sector',
			new Map<String, Object>{
				DNB_TestFactory.BIZ_ENTITY_TYPE => 'National Government Entity',
				DNB_TestFactory.ENTITY_COUNTRY => 'Canada'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildSector(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(
			'Public Sector - International',
			sector,
			'Government entity outside the US => Public Sector - International'
		);
	}

	@IsTest
	static void testResolveSector_BlankBizType_ReturnsBlank() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String sector;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'No Biz Type',
			new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'United States' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildSector(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('', sector, 'Blank Business Entity Type => blank Sector');
	}

	@IsTest
	static void testResolveSector_NonGovBizType_ReturnsCommercial() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String sector;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Commercial',
			new Map<String, Object>{
				DNB_TestFactory.BIZ_ENTITY_TYPE => 'Corporation',
				DNB_TestFactory.ENTITY_COUNTRY => 'United States'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildSector(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('Commercial', sector, 'Any non-government, non-blank entity type => Commercial');
	}

	@IsTest
	static void testResolveSector_CountryReadFromRoleCodeTier_NoCascade() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String sector;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'GU Country Drives Classification',
			new Map<String, Object>{
				DNB_TestFactory.BIZ_ENTITY_TYPE => 'National Government Entity',
				DNB_TestFactory.GU_COUNTRY => 'Canada',
				DNB_TestFactory.ENTITY_COUNTRY => 'United States'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildSector(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(
			'Public Sector - International',
			sector,
			'Country is read from the GU role-code tier (Canada) and must NOT cascade to the US entity'
		);
	}

	@IsTest
	static void testBuildHqCountryAndState_UsSubsidiary() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'US Subsidiary',
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'United States',
				DNB_TestFactory.HQ_REGION => 'CA'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('United States', country, 'Entity-tier country name matches the picklist directly');
		Assert.areEqual('California', state, 'Entity-tier region code CA maps to California');
	}

	@IsTest
	static void testBuildHqCountryAndState_GlobalUltimateTier() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'US Global Ultimate',
			new Map<String, Object>{
				DNB_TestFactory.GU_COUNTRY => 'United States',
				DNB_TestFactory.GU_REGION => 'TX'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('United States', country, 'GU record resolves country via the GU tier');
		Assert.areEqual('Texas', state, 'GU record resolves state via the GU tier (TX => Texas)');
	}

	@IsTest
	static void testBuildHqCountryAndState_DomesticUltimateTier() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildDomesticUltimateProfile(
			'US Domestic Ultimate',
			new Map<String, Object>{
				DNB_TestFactory.DU_COUNTRY => 'United States',
				DNB_TestFactory.DU_REGION => 'FL'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('United States', country, 'DU record resolves country via the DU tier');
		Assert.areEqual('Florida', state, 'DU record resolves state via the DU tier (FL => Florida)');
	}

	@IsTest
	static void testBuildHqCountryAndState_Canada() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Canada Subsidiary',
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'Canada',
				DNB_TestFactory.HQ_REGION => 'ON'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('Canada', country, 'Canada matches the picklist directly');
		Assert.areEqual('Ontario', state, 'Canadian province code ON maps to Ontario');
	}

	@IsTest
	static void testBuildHqState_InternationalCountry_LeftNull() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Germany Subsidiary',
			new Map<String, Object>{
				DNB_TestFactory.ENTITY_COUNTRY => 'Germany',
				DNB_TestFactory.HQ_REGION => 'BY'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('Germany', country, 'Germany matches the picklist directly');
		Assert.isNull(state, 'A non-US/CA region code is not a State picklist code => HQ State left blank');
	}

	@IsTest
	static void testBuildHq_SameTierConsistency() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'US GU With Canadian Local',
			new Map<String, Object>{
				DNB_TestFactory.GU_COUNTRY => 'United States',
				DNB_TestFactory.GU_REGION => 'TX',
				DNB_TestFactory.ENTITY_COUNTRY => 'Canada',
				DNB_TestFactory.HQ_REGION => 'ON'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('United States', country, 'Country comes from the GU tier (role code picks the tier)');
		Assert.areEqual(
			'Texas',
			state,
			'State must come from the SAME (GU) tier as country - never the entity tier'
		);
	}

	@IsTest
	static void testBuildHq_NoCascadeToLowerTier() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'Blank GU Tier',
			new Map<String, Object>{
				DNB_TestFactory.DU_COUNTRY => 'United States',
				DNB_TestFactory.DU_REGION => 'FL'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.isNull(country, 'GU code present but GU country blank => null (no cascade to DU)');
		Assert.isNull(state, 'GU code present but GU region blank => null (no cascade to DU)');
	}

	@IsTest
	static void testBuildHqState_BlankRegionAtTier_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;
		String state;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'US No Region',
			new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'United States' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			state = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = country), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('United States', country, 'Country is written from the entity tier');
		Assert.isNull(state, 'A blank region code leaves HQ State unchanged');
	}

	@IsTest
	static void testBuildHqCountry_OverrideMapping() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>{
			new StateCountryMapping__mdt(
				System__c = 'D&B',
				Category__c = StateCountryMappingUtility.CATEGORY_COUNTRY,
				External_Value__c = 'Turkiye',
				Salesforce_Value__c = 'Turkey'
			)
		};
		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Turkiye Subsidiary',
			new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'Turkiye' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('Turkey', country, 'A non-matching country name is translated via the metadata override');
	}

	@IsTest
	static void testBuildHqCountry_NoMatch_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String country;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>();
		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Unknown Country',
			new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'Atlantis' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			country = DNB_AccountEnrichmentUtility.buildHqCountry(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(country, 'A country with no picklist match and no override is not written');
	}

	@IsTest
	static void testBuildHqState_GatesOnAccountCountry() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String usState;
		String italyState;

		companyProfile = DNB_TestFactory.buildSubsidiaryProfile(
			'Region Only',
			new Map<String, Object>{ DNB_TestFactory.HQ_REGION => 'CA' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			usState = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = 'United States'), companyProfile);
			italyState = DNB_AccountEnrichmentUtility.buildHqState(new Account(HQ_Country__c = 'Italy'), companyProfile);
			Test.stopTest();
		}

		Assert.areEqual('California', usState, 'A US account resolves region code CA to California');
		Assert.isNull(
			italyState,
			'A non-US/CA account leaves HQ State blank even though CA exists in the global State picklist'
		);
	}

	@IsTest
	static void testResolve_GuStartButGuZipEmpty_ReturnsNullNoCascade() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		String zip;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'GU Zip Empty No Cascade',
			new Map<String, Object>{
				DNB_TestFactory.DU_ZIP => '99999',
				DNB_TestFactory.ENTITY_ZIP => '88888'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			zip = DNB_AccountEnrichmentUtility.buildHqZip(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(zip, 'GU code present but GU zip blank => null; HQ Zip is strict tier and never cascades to DU/entity');
	}

	@IsTest
	static void testResolve_GuStartButGuEmployeesEmpty_ReturnsNullNoCascade() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Decimal employees;

		companyProfile = DNB_TestFactory.buildGlobalUltimateProfile(
			'GU Employees Empty No Cascade',
			new Map<String, Object>{
				DNB_TestFactory.DU_EMP => 1000.0,
				DNB_TestFactory.ENTITY_EMP => 500.0
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			employees = DNB_AccountEnrichmentUtility.buildEmployeeCount(companyProfile);
			Test.stopTest();
		}

		Assert.isNull(
			employees,
			'GU code present but GU employee count blank => null; Employee Count is strict tier and never cascades to DU/entity'
		);
	}

	@IsTest
	static void testResolve_DuNoUsd_FallsBackToEntityRevenue() {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		Decimal revenue;

		companyProfile = DNB_TestFactory.buildDomesticUltimateProfile(
			'DU No USD Falls Back To Entity',
			new Map<String, Object>{
				DNB_TestFactory.DU_REV_VAL_1 => 8000000.0,
				DNB_TestFactory.DU_REV_CUR_1 => 'EUR',
				DNB_TestFactory.ENTITY_REV_VAL_1 => 1500000.0,
				DNB_TestFactory.ENTITY_REV_CUR_1 => 'USD'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			revenue = DNB_AccountEnrichmentUtility.buildAnnualRevenue(companyProfile);
			Test.stopTest();
		}

		Assert.areEqual(
			1500000,
			revenue.intValue(),
			'DU tier has no USD => fall back to the entity tier revenue (1,500,000) per formula'
		);
	}

	@IsTest
	static void testIsStateSupportedCountry_OnlyUsAndCanada() {
		Boolean usSupported;
		Boolean canadaSupported;
		Boolean italySupported;
		Boolean nullSupported;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			usSupported = DNB_AccountEnrichmentUtility.isStateSupportedCountry('United States');
			canadaSupported = DNB_AccountEnrichmentUtility.isStateSupportedCountry('Canada');
			italySupported = DNB_AccountEnrichmentUtility.isStateSupportedCountry('Italy');
			nullSupported = DNB_AccountEnrichmentUtility.isStateSupportedCountry(null);
			Test.stopTest();
		}

		Assert.isTrue(usSupported, 'United States supports states');
		Assert.isTrue(canadaSupported, 'Canada supports states');
		Assert.isFalse(italySupported, 'Italy does not support the US/CA state picklist');
		Assert.isFalse(nullSupported, 'A null country does not support states');
	}

	@IsTest
	static void testBuildSecondaryIndustries_AllPriorities_JoinedInPriorityOrder() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String secondaryIndustries;

		profile = DNB_TestFactory.buildSubsidiaryProfile(
			'All Priorities',
			new Map<String, Object>{
				DNB_TestFactory.NAICS_PRIORITY_2 => 'Priority Two Industry',
				DNB_TestFactory.NAICS_PRIORITY_3 => 'Priority Three Industry',
				DNB_TestFactory.NAICS_PRIORITY_4 => 'Priority Four Industry',
				DNB_TestFactory.NAICS_PRIORITY_5 => 'Priority Five Industry',
				DNB_TestFactory.NAICS_PRIORITY_6 => 'Priority Six Industry'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			secondaryIndustries = DNB_AccountEnrichmentUtility.buildSecondaryIndustries(profile);
			Test.stopTest();
		}

		Assert.areEqual(
			'Priority Two Industry; Priority Three Industry; Priority Four Industry; Priority Five Industry; Priority Six Industry',
			secondaryIndustries,
			'Priority 2-6 descriptions are joined with a semicolon in priority order'
		);
	}

	@IsTest
	static void testBuildSecondaryIndustries_SomeBlankSlots_BlanksSkipped() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String secondaryIndustries;

		profile = DNB_TestFactory.buildSubsidiaryProfile(
			'Sparse Priorities',
			new Map<String, Object>{
				DNB_TestFactory.NAICS_PRIORITY_2 => 'Priority Two Industry',
				DNB_TestFactory.NAICS_PRIORITY_4 => 'Priority Four Industry',
				DNB_TestFactory.NAICS_PRIORITY_6 => 'Priority Six Industry'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			secondaryIndustries = DNB_AccountEnrichmentUtility.buildSecondaryIndustries(profile);
			Test.stopTest();
		}

		Assert.areEqual(
			'Priority Two Industry; Priority Four Industry; Priority Six Industry',
			secondaryIndustries,
			'Blank priority slots are skipped and remaining values keep their order'
		);
	}

	@IsTest
	static void testBuildSecondaryIndustries_NoPriorityValues_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String secondaryIndustries;

		profile = DNB_TestFactory.buildSubsidiaryProfile(
			'No Secondary Industries',
			new Map<String, Object>{ DNB_TestFactory.NAICS_PRIORITY_1 => 'Primary Only' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			secondaryIndustries = DNB_AccountEnrichmentUtility.buildSecondaryIndustries(profile);
			Test.stopTest();
		}

		Assert.isNull(
			secondaryIndustries,
			'No Priority 2-6 descriptions => null so the Account field is left unwritten'
		);
	}

	@IsTest
	static void testBuildSecondaryIndustryCodes_AllPriorities_JoinedInPriorityOrder() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String secondaryIndustryCodes;

		profile = DNB_TestFactory.buildSubsidiaryProfile(
			'All Codes',
			new Map<String, Object>{
				DNB_TestFactory.NAICS_CODE_PRIORITY_2 => '541519',
				DNB_TestFactory.NAICS_CODE_PRIORITY_3 => '541611',
				DNB_TestFactory.NAICS_CODE_PRIORITY_4 => '519130',
				DNB_TestFactory.NAICS_CODE_PRIORITY_5 => '423120',
				DNB_TestFactory.NAICS_CODE_PRIORITY_6 => '336211'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			secondaryIndustryCodes = DNB_AccountEnrichmentUtility.buildSecondaryIndustryCodes(profile);
			Test.stopTest();
		}

		Assert.areEqual(
			'541519; 541611; 519130; 423120; 336211',
			secondaryIndustryCodes,
			'Raw 6-digit Priority 2-6 codes are joined with a semicolon in priority order'
		);
	}

	@IsTest
	static void testBuildSecondaryIndustryCodes_NoPriorityValues_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String secondaryIndustryCodes;

		profile = DNB_TestFactory.buildSubsidiaryProfile('No Codes', new Map<String, Object>());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			secondaryIndustryCodes = DNB_AccountEnrichmentUtility.buildSecondaryIndustryCodes(profile);
			Test.stopTest();
		}

		Assert.isNull(
			secondaryIndustryCodes,
			'No Priority 2-6 codes => null so the Account field is left unwritten'
		);
	}

	@IsTest
	static void testBuildNaics_SixDigitCode_TruncatesAndMapsEachLevel() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String sector;
		String subsector;
		String industryGroup;

		DNB_AccountEnrichmentUtility.naicsLookupOverrides = new List<NAICS_Lookup__mdt>{
			new NAICS_Lookup__mdt(
				NAICS_Code__c = '11',
				NAICS_Level__c = 2,
				NAICS_Description__c = 'Agriculture, Forestry, Fishing and Hunting'
			),
			new NAICS_Lookup__mdt(NAICS_Code__c = '111', NAICS_Level__c = 3, NAICS_Description__c = 'Crop Production'),
			new NAICS_Lookup__mdt(
				NAICS_Code__c = '1111',
				NAICS_Level__c = 4,
				NAICS_Description__c = 'Oilseed and Grain Farming'
			)
		};
		profile = DNB_TestFactory.buildSubsidiaryProfile(
			'NAICS Hierarchy',
			new Map<String, Object>{ DNB_TestFactory.NAICS_CODE_PRIORITY_1 => '111110' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildNaicsSector(profile);
			subsector = DNB_AccountEnrichmentUtility.buildNaicsSubsector(profile);
			industryGroup = DNB_AccountEnrichmentUtility.buildNaicsIndustryGroup(profile);
			Test.stopTest();
		}

		Assert.areEqual(
			'Agriculture, Forestry, Fishing and Hunting',
			sector,
			'A 6-digit code truncated to 2 digits (11) maps to the Sector description'
		);
		Assert.areEqual(
			'Crop Production',
			subsector,
			'A 6-digit code truncated to 3 digits (111) maps to the Subsector description'
		);
		Assert.areEqual(
			'Oilseed and Grain Farming',
			industryGroup,
			'A 6-digit code truncated to 4 digits (1111) maps to the Industry Group description'
		);
	}

	@IsTest
	static void testBuildNaics_NoPrimaryCode_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String sector;
		String subsector;
		String industryGroup;

		DNB_AccountEnrichmentUtility.naicsLookupOverrides = new List<NAICS_Lookup__mdt>{
			new NAICS_Lookup__mdt(
				NAICS_Code__c = '11',
				NAICS_Level__c = 2,
				NAICS_Description__c = 'Agriculture, Forestry, Fishing and Hunting'
			)
		};
		profile = DNB_TestFactory.buildSubsidiaryProfile('No Primary NAICS Code', new Map<String, Object>());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildNaicsSector(profile);
			subsector = DNB_AccountEnrichmentUtility.buildNaicsSubsector(profile);
			industryGroup = DNB_AccountEnrichmentUtility.buildNaicsIndustryGroup(profile);
			Test.stopTest();
		}

		Assert.isNull(sector, 'No Priority 1 NAICS code => Sector is left unwritten');
		Assert.isNull(subsector, 'No Priority 1 NAICS code => Subsector is left unwritten');
		Assert.isNull(industryGroup, 'No Priority 1 NAICS code => Industry Group is left unwritten');
	}

	@IsTest
	static void testBuildNaics_NoMetadataMatch_ReturnsNull() {
		DNBConnect__D_B_Connect_Company_Profile__c profile;
		String sector;

		DNB_AccountEnrichmentUtility.naicsLookupOverrides = new List<NAICS_Lookup__mdt>{
			new NAICS_Lookup__mdt(
				NAICS_Code__c = '11',
				NAICS_Level__c = 2,
				NAICS_Description__c = 'Agriculture, Forestry, Fishing and Hunting'
			)
		};
		profile = DNB_TestFactory.buildSubsidiaryProfile(
			'Unmapped NAICS Code',
			new Map<String, Object>{ DNB_TestFactory.NAICS_CODE_PRIORITY_1 => '999999' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sector = DNB_AccountEnrichmentUtility.buildNaicsSector(profile);
			Test.stopTest();
		}

		Assert.isNull(
			sector,
			'A code with no matching NAICS_Lookup__mdt record at the target level is left unwritten'
		);
	}
	
	@IsTest
	static void testHasHqCountrySource_ReflectsTierCountryPresence() {
		DNBConnect__D_B_Connect_Company_Profile__c withCountry;
		DNBConnect__D_B_Connect_Company_Profile__c withoutCountry;
		Boolean present;
		Boolean absent;

		withCountry = DNB_TestFactory.buildSubsidiaryProfile(
			'With Country',
			new Map<String, Object>{ DNB_TestFactory.ENTITY_COUNTRY => 'Atlantis' }
		);
		withoutCountry = DNB_TestFactory.buildSubsidiaryProfile('No Country', new Map<String, Object>());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			present = DNB_AccountEnrichmentUtility.hasHqCountrySource(withCountry);
			absent = DNB_AccountEnrichmentUtility.hasHqCountrySource(withoutCountry);
			Test.stopTest();
		}

		Assert.isTrue(present, 'A country at the role-code tier is a country source, even if it does not map');
		Assert.isFalse(absent, 'No country at the role-code tier means no country source');
	}

	@IsTest
	static void testHasHqRegionSource_ReflectsTierRegionPresence() {
		DNBConnect__D_B_Connect_Company_Profile__c withRegion;
		DNBConnect__D_B_Connect_Company_Profile__c withoutRegion;
		Boolean present;
		Boolean absent;

		withRegion = DNB_TestFactory.buildSubsidiaryProfile(
			'With Region',
			new Map<String, Object>{ DNB_TestFactory.HQ_REGION => 'ZZ' }
		);
		withoutRegion = DNB_TestFactory.buildSubsidiaryProfile('No Region', new Map<String, Object>());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			present = DNB_AccountEnrichmentUtility.hasHqRegionSource(withRegion);
			absent = DNB_AccountEnrichmentUtility.hasHqRegionSource(withoutRegion);
			Test.stopTest();
		}

		Assert.isTrue(present, 'A region code at the role-code tier is a region source, even if it does not map');
		Assert.isFalse(absent, 'No region code at the role-code tier means no region source');
	}

	@IsTest
	static void testHasNaicsSource_ReflectsPriority1CodePresence() {
		DNBConnect__D_B_Connect_Company_Profile__c withCode;
		DNBConnect__D_B_Connect_Company_Profile__c withoutCode;
		Boolean present;
		Boolean absent;

		withCode = DNB_TestFactory.buildSubsidiaryProfile(
			'With NAICS Code',
			new Map<String, Object>{ DNB_TestFactory.NAICS_CODE_PRIORITY_1 => '999999' }
		);
		withoutCode = DNB_TestFactory.buildSubsidiaryProfile('No NAICS Code', new Map<String, Object>());

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			present = DNB_AccountEnrichmentUtility.hasNaicsSource(withCode);
			absent = DNB_AccountEnrichmentUtility.hasNaicsSource(withoutCode);
			Test.stopTest();
		}

		Assert.isTrue(present, 'A Priority 1 NAICS code is a NAICS source, even if it does not map');
		Assert.isFalse(absent, 'No Priority 1 NAICS code means no NAICS source');
	}
}