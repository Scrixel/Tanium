/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test data factory for D&B Connect managed package
 * @Date: 2026-06-10
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13236   2026-06-18    Initial development.
 * SS-13362   2026-06-25    Added NAICS Priority 1-6 description / code field constants.
 */
@IsTest
public class DNB_TestFactory {
	public static final String GU_CODE = '12775';
	public static final String DU_CODE = '12774';

	public static final String GU_CODE_FIELD = 'family_treeRole_GU_code__c';
	public static final String DU_CODE_FIELD = 'family_treeRole_DU_code__c';

	public static final String GU_CITY = 'GU_primAddr_AddrLocal_name__c';
	public static final String DU_CITY = 'DU_primAddr_AddrLocal_name__c';
	public static final String ENTITY_CITY = 'primAddr_AddrLocal_name__c';

	public static final String GU_ZIP = 'GU_primAddr_postalCode__c';
	public static final String DU_ZIP = 'DU_primAddr_postalCode__c';
	public static final String ENTITY_ZIP = 'primAddr_postalCode__c';

	public static final String GU_REV_VAL_1 = 'GU_Fins_yearlyRevenue_value_1__c';
	public static final String GU_REV_CUR_1 = 'GU_Fins_yearlyRevenue_curr_1__c';
	public static final String GU_REV_VAL_2 = 'GU_Fins_yearlyRevenue_value_2__c';
	public static final String GU_REV_CUR_2 = 'GU_Fins_yearlyRevenue_curr_2__c';
	public static final String DU_REV_VAL_1 = 'DU_Fins_yearlyRevenue_value_1__c';
	public static final String DU_REV_CUR_1 = 'DU_Fins_yearlyRevenue_curr_1__c';
	public static final String DU_REV_VAL_2 = 'DU_Fins_yearlyRevenue_value_2__c';
	public static final String DU_REV_CUR_2 = 'DU_Fins_yearlyRevenue_curr_2__c';
	public static final String ENTITY_REV_VAL_1 = 'Fins_yearlyRevenue_value_1__c';
	public static final String ENTITY_REV_CUR_1 = 'Fins_yearlyRevenue_curr_1__c';
	public static final String ENTITY_REV_VAL_2 = 'Fins_yearlyRevenue_value_2__c';
	public static final String ENTITY_REV_CUR_2 = 'Fins_yearlyRevenue_curr_2__c';

	public static final String GU_EMP = 'GU_numOfEmpl_value__c';
	public static final String DU_EMP = 'DU_numOfEmpl_value__c';
	public static final String ENTITY_EMP = 'numberofemployees_val_Cons__c';

	public static final String WEBSITE = 'organization_website_address_url__c';
	public static final String DESCRIPTION = 'Sum_text__c';
	public static final String DUNS_NUMBER = 'DNBConnect__DUNSNumber__c';

	public static final String BIZ_ENTITY_TYPE = 'bizEntityType_Descr__c';
	public static final String GU_COUNTRY = 'GU_primAddr_Cntry_name__c';
	public static final String DU_COUNTRY = 'DU_primAddr_Cntry_name__c';
	public static final String ENTITY_COUNTRY = 'primAddr_Cntry_name__c';
	public static final String NAICS_PRIORITY_1 = 'IndustCodes_Descr_NAICS_priority1__c';
	public static final String NAICS_PRIORITY_2 = 'IndustCodes_Descr_NAICS_priority2__c';
	public static final String NAICS_PRIORITY_3 = 'IndustCodes_Descr_NAICS_priority3__c';
	public static final String NAICS_PRIORITY_4 = 'IndustCodes_Descr_NAICS_priority4__c';
	public static final String NAICS_PRIORITY_5 = 'IndustCodes_Descr_NAICS_priority5__c';
	public static final String NAICS_PRIORITY_6 = 'IndustCodes_Descr_NAICS_priority6__c';
	public static final String NAICS_CODE_PRIORITY_1 = 'IndustCodes_NAICS_priority1__c';
	public static final String NAICS_CODE_PRIORITY_2 = 'IndustCodes_NAICS_priority2__c';
	public static final String NAICS_CODE_PRIORITY_3 = 'IndustCodes_NAICS_priority3__c';
	public static final String NAICS_CODE_PRIORITY_4 = 'IndustCodes_NAICS_priority4__c';
	public static final String NAICS_CODE_PRIORITY_5 = 'IndustCodes_NAICS_priority5__c';
	public static final String NAICS_CODE_PRIORITY_6 = 'IndustCodes_NAICS_priority6__c';

	public static final String GU_REGION = 'GU_primAddr_Region_abbrName__c';
	public static final String DU_REGION = 'DU_primAddr_Region_abbrName__c';
	public static final String HQ_REGION = 'primAddr_Region_abbrName__c';

	private static Integer dunsCounter = 0;

	public static DNBConnect__D_B_Connect_Company_Profile__c buildProfile(
		String name,
		Map<String, Object> fieldValues
	) {
		DNBConnect__D_B_Connect_Company_Profile__c companyProfile;
		companyProfile = new DNBConnect__D_B_Connect_Company_Profile__c();
		dunsCounter++;
		companyProfile.put(DUNS_NUMBER, String.valueOf(900000000 + dunsCounter));
		if (String.isNotBlank(name)) {
			companyProfile.put('Name', name);
		}
		if (fieldValues != null) {
			for (String field : fieldValues.keySet()) {
				companyProfile.put(field, fieldValues.get(field));
			}
		}
		return companyProfile;
	}

	public static DNBConnect__D_B_Connect_Company_Profile__c buildGlobalUltimateProfile(
		String name,
		Map<String, Object> values
	) {
		Map<String, Object> merged = values == null ? new Map<String, Object>() : values.clone();
		merged.put(GU_CODE_FIELD, GU_CODE);
		merged.put(DU_CODE_FIELD, DU_CODE);
		return buildProfile(name, merged);
	}

	public static DNBConnect__D_B_Connect_Company_Profile__c buildDomesticUltimateProfile(
		String name,
		Map<String, Object> values
	) {
		Map<String, Object> merged = values == null ? new Map<String, Object>() : values.clone();
		merged.put(DU_CODE_FIELD, DU_CODE);
		return buildProfile(name, merged);
	}

	public static DNBConnect__D_B_Connect_Company_Profile__c buildSubsidiaryProfile(
		String name,
		Map<String, Object> values
	) {
		return buildProfile(name, values);
	}

	public static void linkAccounts(List<Account> accounts, Id profileId) {
		for (Account account : accounts) {
			account.DNBConnect__D_B_Connect_Company_Profile__c = profileId;
		}
	}

	public static void setSyncFlag(DNBConnect__D_B_Connect_Company_Profile__c companyProfile, Boolean value) {
		companyProfile.Sync_to_Account__c = value;
	}
}