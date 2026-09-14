/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class for translating external state/country values to Salesforce picklist values
 * @Date: 2026-06-18
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13236   2026-06-16    Created the generic external state/country mapping utility.
 */
public with sharing class StateCountryMappingUtility {
	public static final String CATEGORY_COUNTRY = 'Country';
	public static final String CATEGORY_STATE = 'State';

	private static Map<String, String> countryKeyToPicklistLabel;
	private static Map<String, String> stateCodeToPicklistLabel;
	private static Map<String, String> overrideKeyToSalesforceValue;

	@TestVisible
	private static List<StateCountryMapping__mdt> mappingOverride;

	private static Map<String, String> buildCountryLabels() {
		if (countryKeyToPicklistLabel == null) {
			countryKeyToPicklistLabel = new Map<String, String>();
			for (Schema.PicklistEntry entry : Account.HQ_Country__c.getDescribe().getPicklistValues()) {
				countryKeyToPicklistLabel.put(entry.getLabel().toUpperCase(), entry.getLabel());
			}
		}
		return countryKeyToPicklistLabel;
	}

	private static Map<String, String> buildStateLabels() {
		if (stateCodeToPicklistLabel == null) {
			stateCodeToPicklistLabel = new Map<String, String>();
			for (Schema.PicklistEntry entry : Account.BillingStateCode.getDescribe().getPicklistValues()) {
				stateCodeToPicklistLabel.put(entry.getValue().toUpperCase(), entry.getLabel());
			}
		}
		return stateCodeToPicklistLabel;
	}

	private static Map<String, String> buildOverrides() {
		if (overrideKeyToSalesforceValue == null) {
			overrideKeyToSalesforceValue = new Map<String, String>();
			for (StateCountryMapping__mdt mapping : mappingRecords()) {
				overrideKeyToSalesforceValue.put(
					overrideKey(
						mapping.System__c,
						mapping.Category__c,
						mapping.External_Value__c,
						mapping.Country__c
					),
					mapping.Salesforce_Value__c
				);
			}
		}
		return overrideKeyToSalesforceValue;
	}

	public static String translateCountry(String sourceSystem, String externalCountry) {
		return translate(sourceSystem, CATEGORY_COUNTRY, externalCountry);
	}

	public static String translateState(String sourceSystem, String externalStateCode, String country) {
		return translate(sourceSystem, CATEGORY_STATE, externalStateCode, country);
	}

	public static String translate(String sourceSystem, String category, String externalValue) {
		return translate(sourceSystem, category, externalValue, null);
	}

	public static String translate(String sourceSystem, String category, String externalValue, String country) {
		String result;
		if (String.isNotBlank(externalValue)) {
			result = buildOverrides().get(overrideKey(sourceSystem, category, externalValue, country));
			result = result ?? buildOverrides().get(overrideKey(sourceSystem, category, externalValue, null));
			result = result ?? picklistMapFor(category).get(externalValue.toUpperCase());
		}
		return result;
	}

	private static Map<String, String> picklistMapFor(String category) {
		Map<String, String> result;
		if (CATEGORY_COUNTRY.equalsIgnoreCase(category)) {
			result = buildCountryLabels();
		} else if (CATEGORY_STATE.equalsIgnoreCase(category)) {
			result = buildStateLabels();
		} else {
			result = new Map<String, String>();
		}
		return result;
	}

	private static List<StateCountryMapping__mdt> mappingRecords() {
		return mappingOverride ?? StateCountryMapping__mdt.getAll().values();
	}

	private static String overrideKey(String sourceSystem, String category, String externalValue, String country) {
		return (sourceSystem + '|' + category + '|' + externalValue + '|' + (country ?? '')).toUpperCase();
	}

	@InvocableMethod(
		label='Translate External Location Value'
		description='Translates an external system state/country value to the matching Salesforce picklist value.'
	)
	public static List<Result> translateLocationValues(List<Request> requests) {
		List<Result> results = new List<Result>();
		Result result;
		for (Request request : requests) {
			result = new Result();
			result.salesforceValue = translate(request.sourceSystem, request.category, request.externalValue);
			results.add(result);
		}
		return results;
	}

	@AuraEnabled(cacheable=true)
	public static String translateLocationValue(String sourceSystem, String category, String externalValue) {
		return translate(sourceSystem, category, externalValue);
	}

	public class Request {
		@InvocableVariable(label='Source System' required=true)
		public String sourceSystem;
		@InvocableVariable(label='Category (Country or State)' required=true)
		public String category;
		@InvocableVariable(label='External Value' required=true)
		public String externalValue;
	}

	public class Result {
		@InvocableVariable(label='Salesforce Value')
		public String salesforceValue;
	}
}