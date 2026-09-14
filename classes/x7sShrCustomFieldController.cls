/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Custom field CMT controller
 * @Date: UNKNOWN
 * @Author: 7Summits, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11494   2025-08-12    Fix user search vulnerability for inactive users
 * SS-12574   2026-02-23    Add security enforcment query in getObjectResults method
 * SS-13018   2026-05-29    Block guest user access to objectNameFieldSearch; clean up getObjectResults SOQL
 */
public without sharing class x7sShrCustomFieldController {
	private static final Integer SEARCH_LIMIT = 500;

	/**
	 * @description Search 1 or more objects object(s) on a search term and a list of excluded IDs
	 * - if 1st object search return 0, try the 2nd objects
	 *
	 * @param object1 First object
	 * @param object2 Second object (optional)
	 * @param searchTerm Search string
	 * @param selectedIds Exclude Ds
	 *
	 * @return list of objects found (Id, Name)
	 */
	@AuraEnabled(Cacheable=true)
	public static List<SObject> objectNameFieldSearch(
		String object1,
		String object2,
		String searchTerm,
		List<String> selectedIds
	) {
		if (Auth.CommunitiesUtil.isGuestUser()) {
			throw new AuraHandledException('Access denied.');
		}
		List<SObject> resultSet = new List<SObject>();

		if (String.isNotBlank(searchTerm)) {
			if (String.isNotBlank(object1)) {
				resultSet = getObjectResults(object1, searchTerm, selectedIds);
			}

			if (resultSet.size() == 0 && String.isNotBlank(object2)) {
				resultSet = getObjectResults(object2, searchTerm, selectedIds);
			}
		}

		return resultSet;
	}

	private static List<SObject> getObjectResults(
		String objectName,
		String searchTerm,
		List<String> selectedIds
	) {
		String query;
		query =
			'SELECT Id, Name FROM ' +
			String.escapeSingleQuotes(objectName) +
			' WHERE Name LIKE \'%' +
			String.escapeSingleQuotes(searchTerm) +
			'%\' AND Id NOT IN :selectedIds' +
			(objectName == 'User' ? ' AND isActive = true' : '') +
			' WITH USER_MODE' +
			' LIMIT ' + SEARCH_LIMIT;
		return Database.query(query);
	}

	/**
	 * @description Get the list of custom fields for the specified field set
	 *
	 * @param fieldSetName Custom field CMT set name
	 *
	 * @return Custom field list
	 */
	@AuraEnabled
	public static x7sShrCustomFieldList getCustomFields(String fieldSetName) {
		x7sShrCustomFieldList fieldList = new x7sShrCustomFieldList();

		if (String.isNotBlank(fieldSetName)) {
			X7S_Shr_Custom_Field_Set__mdt fieldSet = X7S_Shr_Custom_Field_Set__mdt.getInstance(
				fieldSetName
			);

			if (fieldSet != null) {
				fieldList.objectName = fieldSet.Object_API_Name__c;
				fieldList.active = fieldSet.Active__c;
				fieldList.allFieldsRequired = fieldSet.All_fields_required__c;

				String fieldSetId = fieldSet.Id;
				Map<String, X7S_Shr_Custom_Field_Set_Assignment__mdt> fieldSetItems = X7S_Shr_Custom_Field_Set_Assignment__mdt.getAll();

				for (String key : fieldSetItems.keySet()) {
					if (fieldSetItems.get(key).X7S_Shr_Custom_Field_Set__c == fieldSetId) {
						X7S_Shr_Custom_Field_Set_Assignment__mdt fieldSetItem = fieldSetItems.get(key);
						String fieldId = fieldSetItem.X7S_Shr_Custom_Field__c;

						X7S_Shr_Custom_Field__mdt customField = X7S_Shr_Custom_Field__mdt.getInstance(
							fieldId
						);

						if (getValidField(fieldList.objectName, customField.API_Name__c)) {
							x7sShrCustomFieldModel field = new x7sShrCustomFieldModel();

							field.apiName = customField.API_Name__c;
							field.fieldType = customField.Type__c;
							field.sequence = Integer.valueOf(fieldSetItem.Sequence__c);
							field.required =
								field.fieldType != 'checkbox' &&
								(fieldSet.All_fields_required__c ||
								fieldSetItem.Required__c ||
								getFieldRequired(fieldList.objectName, field.apiName));
							field.placeholder = fieldSetItem.Placeholder__c;
							field.tooltip = customField.Tooltip__c;
							field.label = getFieldLabel(
								fieldList.objectName,
								field.apiName,
								customField.Label__c
							);

							if (String.isNotBlank(fieldSetItem.Label_Type__c)) {
								field.labelType = fieldSetItem.Label_Type__c;
								if (field.labelType == 'Label') {
									if (String.isNotBlank(fieldSetItem.Label_Override__c)) {
										field.label = fieldSetItem.Label_Override__c;
									}
								}

								if (field.labelType == 'Icon') {
									if (String.isNotBlank(fieldSetItem.Label_Icon__c)) {
										field.icon = fieldSetItem.Label_Icon__c;
									}
								}
							}

							if (field.fieldType.toLowerCase().contains('picklist')) {
								field.picklistValues = getFieldPickListValues(
									fieldList.objectName,
									field.apiName
								);
							}

							if (field.fieldType.toLowerCase().contains('lookup')) {
								field.lookupName = getLookupReference(fieldList.objectName, field.apiName);
							}

							fieldList.fields.add(field);
							fieldList.fields.sort();
						} else {
							System.debug(
								'Custom field error - Invalid field API name: ' + customField.API_Name__c
							);
						}
					}
				}
			}
		}

		return fieldList;
	}

	@TestVisible
	private static String getLookupReference(String objectName, String fieldApiName) {
		String referencedObjectName = '';

		if (String.isNotBlank(fieldApiName)) {
			Schema.DescribeFieldResult result = Schema.getGlobalDescribe()
				.get(objectName)
				.getDescribe()
				.fields.getMap()
				.get(fieldApiName)
				.getDescribe();

			for (Schema.SObjectType reference : result.getReferenceTo()) {
				referencedObjectName = (String) reference.getDescribe().getName();
			}
		}

		return referencedObjectName;
	}

	private static Boolean getValidField(String objectName, String fieldApiName) {
		List<Schema.DescribeSObjectResult> results = Schema.describeSObjects(
			new List<String>{ objectName }
		);
		Map<String, Schema.SObjectField> fieldMap = results[0].fields.getMap();

		Boolean validField = false;
		if (String.isNotBlank(fieldApiName)) {
			try {
				validField = fieldMap.get(fieldApiName).getDescribe().isAccessible();
			} catch (Exception ex) {
				System.debug(
					'Custom field - Invalid Field for ' +
					fieldApiName +
					' : ' +
					ex.getMessage()
				);
			}
		}
		return validField;
	}

	private static List<String> getFieldPickListValues(String objectName, String fieldApiName) {
		List<String> picklistValues = new List<String>();

		Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
		Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
		List<Schema.PicklistEntry> values = fieldMap.get(fieldApiName)
			.getDescribe()
			.getPicklistValues();

		for (Schema.PicklistEntry entry : values) {
			if (entry.active) {
				picklistValues.add(entry.getLabel());
			}
		}

		return picklistValues;
	}

	private static String getFieldLabel(String objectName, String fieldAPIName, String fieldLabel) {
		String objectFieldLabel = '';

		try {
			if (String.isBlank(fieldLabel)) {
				List<Schema.DescribeSObjectResult> results = Schema.describeSObjects(
					new List<String>{ objectName }
				);
				Map<String, Schema.SObjectField> fieldMap = results[0].fields.getMap();
				objectFieldLabel = fieldMap.get(fieldAPIName).getDescribe().getLabel();
			} else {
				objectFieldLabel = String.escapeSingleQuotes(fieldLabel);
			}
		} catch (Exception ex) {
			System.debug('Invalid Field label for' + fieldAPIName + ' : ' + ex.getMessage());
		}

		return objectFieldLabel;
	}

	private static Boolean getFieldRequired(String objectName, String fieldAPIName) {
		Boolean isRequired = false;

		try {
			Map<String, Schema.SObjectType> typeMap = Schema.getGlobalDescribe();
			Schema.DescribeSObjectResult result = typeMap.get(objectName).getDescribe();
			Map<String, Schema.SObjectField> fieldMap = result.fields.getMap();

			if (fieldMap.containsKey(fieldAPIName)) {
				Schema.DescribeFieldResult fieldDetails = fieldMap.get(fieldAPIName).getDescribe();
				isRequired = !fieldDetails.isNillable();
			}
		} catch (Exception ex) {
			System.debug(
				'Custom field - Invalid field is required ' +
				fieldAPIName +
				' : ' +
				ex.getMessage()
			);
		}

		return isRequired;
	}
}