/**
 * Copyright (c) 2025 Tanium
 *
 * @DATE: 2026-03-04
 * @AUTHORS: Tanium Dev Team
 * @BUSINESS: Utility class for Account object
 * RequestId  ModifiedDate  Description
 * SS-12691   2026-03-04    Initial development
 */
public without sharing class AccountUtility {
	public static Map<String, Schema.SobjectField> fieldInfoMap = new Map<String, Schema.SobjectField>();

	public static Boolean evaluate(
		String operator,
		Account_Segment_Mapping__mdt accountSegmentMap,
		Account acc
	) {
		Schema.SobjectField fieldInfo = fieldInfoMap.get(accountSegmentMap.Field__c);
		if (fieldInfo == null) {
			fieldInfo = getFieldInfo(accountSegmentMap.Field__c);
		}

		String fieldType = fieldInfo.getDescribe().getType().name().ToLowerCase();
		Object fieldValue = acc.get(accountSegmentMap.Field__c);
		String metadataValue = accountSegmentMap.Value__c;

		if (
			fieldType == 'currency' ||
			fieldType == 'double' ||
			fieldType == 'percent' ||
			fieldType == 'decimal'
		) {
			return evaluateDecimal(operator, fieldValue, metadataValue);
		} else if (fieldType == 'boolean') {
			return evaluateBoolean(operator, fieldValue, metadataValue);
		} else if (fieldType == 'date') {
			return evaluateDate(operator, fieldValue, metadataValue);
		} else if (
			fieldType == 'string' ||
			fieldType == 'multipicklist' ||
			fieldType == 'url' ||
			fieldType == 'picklist'
		) {
			return evaluateString(operator, fieldValue, metadataValue);
		}
		return false;
	}

	@TestVisible
	private static Schema.SobjectField getFieldInfo(String fieldName) {
		SObjectType objectType = Schema.getGlobalDescribe().get('Account');
		AccountUtility.fieldInfoMap = objectType.getDescribe().fields.getMap();
		return AccountUtility.fieldInfoMap.get(fieldName);
	}

	@TestVisible
	private static Boolean evaluateBoolean(
		String operator,
		Object fieldValue,
		String metadataValue
	) {
		Boolean result = false;
		if (fieldValue == null) {
			fieldValue = '';
		}
		if (metadataValue == null) {
			metadataValue = '0';
		}
		if (
			operator == 'equals' &&
			(fieldValue == 0 && String.isBlank(metadataValue) ||
			(fieldValue == '' &&
			Decimal.valueOf(metadataValue) == 0) ||
			(fieldValue == '' &&
			metadataValue == ''))
		) {
			result = true;
		} else if (operator == 'equals') {
			result = (Boolean) fieldValue == Boolean.valueOf(metadataValue);
		} else if (operator == 'not equal to') {
			result =
				(Boolean) fieldValue !=
				Boolean.valueOf(
					metadataValue == '0' ? 'false' : metadataValue == '1' ? 'true' : metadataValue
				);
		}
		return result;
	}

	@TestVisible
	private static Boolean evaluateDecimal(
		String operator,
		Object fieldValue,
		String metadataValue
	) {
		Boolean result = false;
		if (
			operator == 'equals' &&
			fieldValue != null &&
			metadataValue != null &&
			fieldValue != '' &&
			metadataValue != ''
		) {
			result = (Decimal) fieldValue == Decimal.valueOf(metadataValue);
		} else if (operator == 'not equal to') {
			result = (Decimal) fieldValue != Decimal.valueOf(metadataValue);
		} else if (operator == 'less than') {
			result = (Decimal) fieldValue < Decimal.valueOf(metadataValue);
		} else if (operator == 'greater than') {
			result = (Decimal) fieldValue > Decimal.valueOf(metadataValue);
		} else if (operator == 'less or equal') {
			result = (Decimal) fieldValue <= Decimal.valueOf(metadataValue);
		} else if (operator == 'greater or equal') {
			result = (Decimal) fieldValue >= Decimal.valueOf(metadataValue);
		}
		return result;
	}

	@TestVisible
	private static Boolean evaluateDate(String operator, Object fieldValue, String metadataValue) {
		Boolean result = false;
		if (metadataValue.equalsIgnoreCase('today')) {
			metadataValue = String.valueOf(System.today());
		} else if (metadataValue.equalsIgnoreCase('yesterday')) {
			metadataValue = String.valueOf(System.today().addDays(-1));
		} else if (metadataValue.equalsIgnoreCase('tomorrow')) {
			metadataValue = String.valueOf(System.today().addDays(1));
		}

		if (operator == 'equals') {
			result = (Date) fieldValue == Date.valueOf(metadataValue);
		} else if (operator == 'not equal to') {
			result = (Date) fieldValue != Date.valueOf(metadataValue);
		} else if (operator == 'less than') {
			result = (Date) fieldValue < Date.valueOf(metadataValue);
		} else if (operator == 'greater than') {
			result = (Date) fieldValue > Date.valueOf(metadataValue);
		} else if (operator == 'less or equal') {
			result = (Date) fieldValue <= Date.valueOf(metadataValue);
		} else if (operator == 'greater or equal') {
			result = (Date) fieldValue >= Date.valueOf(metadataValue);
		}
		return result;
	}

	@TestVisible
	private static Boolean evaluateString(String operator, Object fieldValue, String metadataValue) {
		Boolean result = false;
		if (fieldValue == null) {
			fieldValue = '';
		}
		if (metadataValue == null) {
			metadataValue = '';
		}
		if (operator == 'equals') {
			result = (String) fieldValue == String.valueOf(metadataValue);
		} else if (operator == 'not equal to') {
			result = (String) fieldValue != String.valueOf(metadataValue);
		} else if (operator == 'less than') {
			result = (String) fieldValue < String.valueOf(metadataValue);
		} else if (operator == 'greater than') {
			result = (String) fieldValue > String.valueOf(metadataValue);
		} else if (operator == 'less or equal') {
			result = (String) fieldValue <= String.valueOf(metadataValue);
		} else if (operator == 'greater or equal') {
			result = (String) fieldValue >= String.valueOf(metadataValue);
		}
		return result;
	}
}