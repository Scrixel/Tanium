/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for StateCountryMappingUtility class
 * @Date: 2026-06-16
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13236   2026-06-16    Created the test class.
 */
@IsTest
private class StateCountryMappingUtilityTest {
	private static final String SYSTEM_DNB = 'D&B';

	@IsTest
	static void testTranslateCountry_DirectPicklistMatch() {
		String result;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, 'United States');
			Test.stopTest();
		}

		Assert.areEqual('United States', result, 'A country that matches the picklist is returned as-is');
	}

	@IsTest
	static void testTranslateCountry_OverrideMapping() {
		String result;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>{
			new StateCountryMapping__mdt(
				System__c = SYSTEM_DNB,
				Category__c = StateCountryMappingUtility.CATEGORY_COUNTRY,
				External_Value__c = 'Turkiye',
				Salesforce_Value__c = 'Turkey'
			)
		};

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, 'Turkiye');
			Test.stopTest();
		}

		Assert.areEqual('Turkey', result, 'A non-matching country is translated via the metadata override');
	}

	@IsTest
	static void testTranslateCountry_NoMatchReturnsNull() {
		String result;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, 'Atlantis');
			Test.stopTest();
		}

		Assert.isNull(result, 'A country with no picklist match and no override returns null');
	}

	@IsTest
	static void testTranslateCountry_BlankReturnsNull() {
		String result;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, null);
			Test.stopTest();
		}

		Assert.isNull(result, 'A blank country returns null');
	}

	@IsTest
	static void testTranslateState_UsAndCanadaCodes() {
		String california;
		String ontario;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			california = StateCountryMappingUtility.translateState(SYSTEM_DNB, 'CA', 'United States');
			ontario = StateCountryMappingUtility.translateState(SYSTEM_DNB, 'ON', 'Canada');
			Test.stopTest();
		}

		Assert.areEqual('California', california, 'US state code CA maps to California');
		Assert.areEqual('Ontario', ontario, 'Canadian province code ON maps to Ontario');
	}

	@IsTest
	static void testTranslateState_InternationalCodeReturnsNull() {
		String result;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateState(SYSTEM_DNB, 'TKY', null);
			Test.stopTest();
		}

		Assert.isNull(result, 'An international region code (non US/CA) is left blank');
	}

	@IsTest
	static void testTranslateState_BlankReturnsNull() {
		String result;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateState(SYSTEM_DNB, '   ', 'United States');
			Test.stopTest();
		}

		Assert.isNull(result, 'A blank region code returns null');
	}

	@IsTest
	static void testInvocable_TranslatesValuesInOrder() {
		StateCountryMappingUtility.Request countryRequest;
		StateCountryMappingUtility.Request stateRequest;
		List<StateCountryMappingUtility.Result> results;

		countryRequest = new StateCountryMappingUtility.Request();
		countryRequest.sourceSystem = SYSTEM_DNB;
		countryRequest.category = StateCountryMappingUtility.CATEGORY_COUNTRY;
		countryRequest.externalValue = 'United States';
		stateRequest = new StateCountryMappingUtility.Request();
		stateRequest.sourceSystem = SYSTEM_DNB;
		stateRequest.category = StateCountryMappingUtility.CATEGORY_STATE;
		stateRequest.externalValue = 'CA';
		List<StateCountryMappingUtility.Request> requests = new List<StateCountryMappingUtility.Request>{
			countryRequest,
			stateRequest
		};

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = StateCountryMappingUtility.translateLocationValues(requests);
			Test.stopTest();
		}

		Assert.areEqual(2, results.size(), 'One result per request, order-aligned');
		Assert.areEqual('United States', results[0].salesforceValue, 'Country request resolves');
		Assert.areEqual('California', results[1].salesforceValue, 'State request resolves');
	}

	@IsTest
	static void testAuraEnabled_TranslatesSingleValue() {
		String result;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateLocationValue(
				SYSTEM_DNB,
				StateCountryMappingUtility.CATEGORY_STATE,
				'CA'
			);
			Test.stopTest();
		}

		Assert.areEqual('California', result, 'The Aura-enabled entry point translates a single value');
	}

	@IsTest
	static void testTranslateCountry_KnownDnbMismatches_TranslateViaOverride() {
		Map<String, String> picklistValueByDnbValue;
		List<StateCountryMapping__mdt> overrides;
		String actual;

		picklistValueByDnbValue = new Map<String, String>{
			'Republic Of Korea' => 'Korea, Republic of',
			'Turkiye' => 'Turkey',
			'Vietnam' => 'Viet Nam',
			'Ivory Coast' => 'Cote d\'Ivoire',
			'Bolivia' => 'Bolivia, Plurinational State of',
			'Venezuela' => 'Venezuela, Bolivarian Republic of',
			'Tanzania' => 'Tanzania, United Republic of',
			'Iran' => 'Iran, Islamic Republic of',
			'Syria' => 'Syrian Arab Republic',
			'Brunei' => 'Brunei Darussalam',
			'Moldova' => 'Moldova, Republic of',
			'Laos' => 'Lao People\'s Democratic Republic',
			'Bosnia-Herzegovina' => 'Bosnia and Herzegovina',
			'Democratic Republic Of The Congo' => 'Congo'
		};

		overrides = new List<StateCountryMapping__mdt>();
		for (String dnbValue : picklistValueByDnbValue.keySet()) {
			overrides.add(
				new StateCountryMapping__mdt(
					System__c = SYSTEM_DNB,
					Category__c = StateCountryMappingUtility.CATEGORY_COUNTRY,
					External_Value__c = dnbValue,
					Salesforce_Value__c = picklistValueByDnbValue.get(dnbValue)
				)
			);
		}
		StateCountryMappingUtility.mappingOverride = overrides;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			for (String dnbValue : picklistValueByDnbValue.keySet()) {
				actual = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, dnbValue);
				Assert.areEqual(
					picklistValueByDnbValue.get(dnbValue),
					actual,
					'D&B country "' + dnbValue + '" must translate to its HQ Country picklist value'
				);
			}
			Test.stopTest();
		}
	}

	@IsTest
	static void testTranslateCountry_MismatchIsCaseInsensitive() {
		String lowerCaseInput;
		String upperCaseInput;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>{
			new StateCountryMapping__mdt(
				System__c = SYSTEM_DNB,
				Category__c = StateCountryMappingUtility.CATEGORY_COUNTRY,
				External_Value__c = 'Turkiye',
				Salesforce_Value__c = 'Turkey'
			)
		};

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			lowerCaseInput = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, 'turkiye');
			upperCaseInput = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, 'TURKIYE');
			Test.stopTest();
		}

		Assert.areEqual('Turkey', lowerCaseInput, 'Override match must be case-insensitive (lowercase input)');
		Assert.areEqual('Turkey', upperCaseInput, 'Override match must be case-insensitive (uppercase input)');
	}

	@IsTest
	static void testTranslateCountry_OverrideScopedToSourceSystem() {
		String result;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>{
			new StateCountryMapping__mdt(
				System__c = SYSTEM_DNB,
				Category__c = StateCountryMappingUtility.CATEGORY_COUNTRY,
				External_Value__c = 'Turkiye',
				Salesforce_Value__c = 'Turkey'
			)
		};

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateCountry('ZoomInfo', 'Turkiye');
			Test.stopTest();
		}

		Assert.isNull(result, 'A D&B override must not resolve for a different source system (key includes System)');
	}

	@IsTest
	static void testTranslateCountry_OverrideTakesPrecedenceOverPicklistMatch() {
		String result;

		StateCountryMappingUtility.mappingOverride = new List<StateCountryMapping__mdt>{
			new StateCountryMapping__mdt(
				System__c = SYSTEM_DNB,
				Category__c = StateCountryMappingUtility.CATEGORY_COUNTRY,
				External_Value__c = 'Ivory Coast',
				Salesforce_Value__c = 'Cote d\'Ivoire'
			)
		};

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = StateCountryMappingUtility.translateCountry(SYSTEM_DNB, 'Ivory Coast');
			Test.stopTest();
		}

		Assert.areEqual(
			'Cote d\'Ivoire',
			result,
			'An override must win even when the external value also matches a picklist label directly'
		);
	}
}