/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
/**
 * @description This is helper class which holds the reusable methods.
 */
public with sharing class x7sEventsBaseController {
	public static final String Picklist_Label = 'label';
	public static final String Picklist_Value = 'value';
	public static final String UNKNOWN_NAME = 'Unknown';

	/**
	 * @description Used to get site path
	 * @return site path
	 */
	@AuraEnabled
	public static String getSitePrefix() {
		try {
			return System.Site.getPathPrefix();
		} catch (Exception e) {
			System.debug('Error in getSitePrefix() - ' + e.getMessage());
			throw new AuraHandledException('Error getting site prefix');
		}
	}

	/**
	 * @description Used to get Base Model
	 * @return Base Model
	 */
	@AuraEnabled
	public static BaseModel getModel() {
		try {
			return new BaseModel();
		} catch (Exception e) {
			System.debug('Error in getModel() - ' + e.getMessage());
			throw new AuraHandledException('Error getting base madel');
		}
	}

	/**
	 * @description Base Model Class
	 */
	public with sharing class BaseModel {
		/**
		 * @description Namespace Prefix
		 */
		@AuraEnabled
		public String namespacePrefix { get; set; }

		/**
		 * @description Constructor
		 */
		public BaseModel() {
			this.namespacePrefix = '';
		}
	}

	/**
	 * @description Used to get Site Base URL
	 * @return Site Base URL
	 */
	public static String getCommunityUrl() {
		String baseUrl = System.Url.getSalesforceBaseUrl().toExternalForm();

		try {
			String url = Network.getLoginUrl(Network.getNetworkId());
			return url.substring(0, url.lastIndexOf('/s/'));
		} catch (Exception e) {
			System.debug('No community found');
			return baseUrl;
		}
	}

	private static String nameSpace {
		get {
			if (nameSpace == null) {
				String ns = getModel().namespacePrefix;
				nameSpace = String.isBlank(ns) ? '' : ns + '__';
			}
			return nameSpace;
		}
		private set;
	}

	/**
	 * @description Used to get picklist lable list for given field from the given object
	 * @param objName Object Name
	 * @param fieldName Picklist field
	 * @return List of picklist value labels
	 */
	public static List<String> buildPicklistValues(String objName, String fieldName) {
		List<String> options = new List<String>();

		Schema.SObjectType objType = Schema.getGlobalDescribe().get(nameSpace + objName);
		Schema.DescribeSObjectResult objDescribe = objType.getDescribe();

		Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
		List<Schema.PicklistEntry> values = fieldMap.get(nameSpace + fieldName)
			.getDescribe()
			.getPicklistValues();

		for (Schema.PicklistEntry a : values) {
			options.add(a.getLabel());
		}
		return options;
	}

	/**
	 * @description Used to get JSON String of picklsit values & labels for given field from the given object
	 * @param objName Object Name
	 * @param fieldName Picklist field
	 * @return JSON String of picklist value labels
	 */
	public static String buildPicklistValuesJSON(String objName, String fieldName) {
		List<Map<String, Object>> options = new List<Map<String, Object>>();

		Schema.SObjectType objType = Schema.getGlobalDescribe().get(nameSpace + objName);
		Schema.DescribeSObjectResult objDescribe = objType.getDescribe();

		Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
		List<Schema.PicklistEntry> values = fieldMap.get(nameSpace + fieldName)
			.getDescribe()
			.getPicklistValues();

		for (Schema.PicklistEntry a : values) {
			Map<String, Object> option = new Map<String, Object>();

			option.put(Picklist_Label, a.getLabel());
			option.put(Picklist_Value, a.getValue());

			options.add(option);
		}

		return JSON.serialize(options);
	}

	public static void debugPrintLongString(String title, String stringToPrint) {
		System.debug('Begin : ' + title);

		for (Integer i = 0; i < stringToPrint.length(); i = i + 300) {
			Integer iEffectiveEnd = (i + 300 > (stringToPrint.length() - 1)
				? stringToPrint.length() - 1
				: i + 300);
			System.debug(stringToPrint.substring(i, iEffectiveEnd));
		}

		System.debug('End : ' + title);
	}
}