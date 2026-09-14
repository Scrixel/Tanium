/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description This is Idea Utility class having reusable methods
 */
public without sharing class x7sIdeasUtility {

	@TestVisible
	private static String getNameSpacePrefix() {
		String namespacePrefix = [SELECT NamespacePrefix FROM ApexClass WHERE Name = 'x7sIdeasUtility' LIMIT 1].NamespacePrefix;

		return String.isNotBlank(namespacePrefix) ? namespacePrefix + '__' : '';
	}

	/**
	 * @description Method to get site prefix
	 * @return Site prefix
	 */
	@AuraEnabled (Cacheable=true)
	public static String getSitePrefix() {
		return System.Site.getPathPrefix();
	}

	/**
	 * @description Used to get idea zone Id
	 * @param nameValue Idea zone name
	 * @return Idea zone Id
	 */
	@AuraEnabled
	public static String getZoneId(String nameValue) {
		String zoneId = '';

		try {
			if (!String.isEmpty(nameValue)) {
				List<Community> currCommunity = [SELECT Id FROM Community WHERE Name = :nameValue];

				if (currCommunity != null && currCommunity.size() > 0) {
					zoneId = currCommunity[0].Id;
				}
			}
			return zoneId;
		} catch (Exception ex) { System.debug('getZoneId() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());return null; }
	}

	/**
	 * @description Used to check if current user is authenticated or not	 
	 * @return True if authenticated else false
	 */
	@AuraEnabled
	public static Boolean isAuthenticated() {
		return !Auth.CommunitiesUtil.isGuestUser();
	}

	/**
	 * @description Check if the user nickname should be displayed. This is a community preference but we use a CMT setting for LEX.
	 * @return true if display nickname is enabled
	 */
	@AuraEnabled (Cacheable=true)
	public static Boolean isNicknameDisplayEnabled() {
		Id networkId = System.Network.getNetworkId();
		Boolean isNicknameDisplayEnabled = false;

		try {
			// get initial option from CMT in case we are in LEX
			X7S_Ideas_Setting__mdt ideaSettingDefault = X7S_Ideas_Setting__mdt.getInstance('Default');
			isNicknameDisplayEnabled =  ideaSettingDefault?.LEX_Nickname_Display__c;

			// this will throw in LEX
			Boolean display = [SELECT Id, OptionsNicknameDisplayEnabled FROM Network WHERE Id = :networkId LIMIT 1]?.OptionsNicknameDisplayEnabled;
			if (display != null) { isNicknameDisplayEnabled = display;}
		}
		catch (Exception e) { System.debug('Nickname option not found - possibly in LEX mode');}

		return isNicknameDisplayEnabled != null ? isNicknameDisplayEnabled : false;
	}

	/**
	 * @description Method to check Email Turn on/off
	 * @return true if email is on else false
	 */
	public static Boolean emailTurnedOn() {
		Boolean emailsTurnedOn = false;

		try {
			Messaging.reserveSingleEmailCapacity(0);
			emailsTurnedOn = true;
		}
		catch (System.NoAccessException e) {System.debug('emailsTurnedOn check failed: ' + e.getMessage());}

		return emailsTurnedOn;
	}

	/**
	 * @description Method to check if given user is part of permission set list
	 * @param userId Id of the user to check with
	 * @param permissionSetList permission set list to check in
	 * @return true if user is member of given permission set else false
	 */
	public static Boolean permissionSetMember(String userId, String permissionSetList) {
		Boolean isMember = false;

		if (String.isNotBlank(permissionSetList)) {
			List<String> permissionSets = permissionSetList.split(',\\s*');

			isMember = [
				SELECT COUNT()
				FROM PermissionSetAssignment
				WHERE AssigneeId = :userId AND PermissionSet.Name IN :permissionSets
			] > 0;
		}

		return isMember;
	}

	/**
	 * @description Method to check if given user is part of profile list
	 * @param userId Id of the user to check with
	 * @param profileNameList profile list to check in
	 * @return true if user is member of given profiles else false
	 */
	public static Boolean profileMember(String userId, String profileNameList) {
		Boolean isMember = false;
		String networkId = System.Network.getNetworkId();
		System.debug('profileMember: NetworkId: ' + networkId);

		Network network;

		if (Test.isRunningTest()) {
			try {
				X7S_Ideas_Setting__mdt setting = [SELECT Id, Default_Test_Community_ID__c FROM X7S_Ideas_Setting__mdt WHERE DeveloperName = 'Default' LIMIT 1];
				if (setting != null) {
					networkId = setting.Default_Test_Community_ID__c;
					System.debug('Network ID from CMT Default: ' + networkId);
				}
			}
			catch (QueryException ex) { System.debug('Test - profileMember exception: ' + ex.getMessage());}

			if (networkId == null) {
				network = (Network) [SELECT Id, Name, OptionsGuestChatterEnabled FROM Network WHERE Status IN ('Live', 'UnderConstruction') LIMIT 1];
				networkId = network.Id;
				System.debug('Network Id from Query: ' + networkId);
			}
		}

		if (String.isNotBlank(profileNameList)) {
			List<String> profileNames = profileNameList.split(',\\s*');
			try {
				User currentUser = [SELECT Id, Profile.Name, UserType FROM User WHERE Id = :userId];
				network = (Network) [SELECT Id, Name, OptionsGuestChatterEnabled FROM Network WHERE Id = :networkId];

				if (currentUser != null) {
					List<NetworkMember> member = [SELECT MemberId, NetworkId FROM NetworkMember WHERE NetworkId = :networkId AND MemberId = :userId LIMIT 1];
					if (member.size() > 0) {
						isMember = profileNames.contains(currentUser.Profile.Name);
					}
					else {
						// check to see if network allows guest chatter access
						if (currentUser.UserType == 'Guest' && network.OptionsGuestChatterEnabled == true) { isMember = true;}
					}
				}
			}
			catch (Exception ex) { System.debug('profileMember exception: ' + ex.getMessage()); }
		}

		return isMember;
	}

	/**
	 * @description this method parse a field value as a string and return as a map. ex - field1:value,field2:value2
	 * @param fieldValueString Field value as a string
	 * @return Map of field name value pair
	 */    
	public static Map<String, String> parseFieldValueString(String fieldValueString) {
		Map<String, String> userFieldValues = null;

		if (String.isNotBlank(fieldValueString)) {
			userFieldValues = new Map<String, String>();

			List<String> fieldValuePairs = fieldValueString.trim().split(',');
			for (String fieldValue : fieldValuePairs) {
				String[] entries = fieldValue.trim().split(':');
				if (String.isNotBlank(entries[0])) {
					userFieldValues.put(entries[0], entries[1]);
				}
			}
		}
		return userFieldValues;
	}

	/**
	 * @description Used to set custom field for User record
	 * @param newUser User Record
	 * @return Updated User record
	 */ 
	public static User setCustomUserFields(User newUser) {
		try {
			X7S_Ideas_Setting__mdt setting = [SELECT Id, User_Custom_FieldValues__c FROM X7S_Ideas_Setting__mdt WHERE DeveloperName = 'Default' LIMIT 1];
		
			if (setting != null && String.isNotBlank(setting.User_Custom_FieldValues__c)) {
				Map<String, String> customFields = x7sIdeasUtility.parseFieldValueString(setting.User_Custom_FieldValues__c);

				if (customFields != null && customFields.size() > 0) {
					for (String fieldName : customFields.keySet()) { newUser.put(fieldName, customFields.get(fieldName));}
				}
			}
			return newUser;

		} catch (Exception ex) { System.debug('setCustomUserFields() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber()); return null;}
	}

	/**
	 * @description Used to Check if user has Idea object create access
	 * @return true if has access else false
	 */ 
	public static Boolean isIdeaObjectCreateable() {
		Boolean isCreateEnabled = false;

		if (Idea.SObjectType.getDescribe().isCreateable()) {
			isCreateEnabled = true;
		}
		return isCreateEnabled;
	}

	/**
	 * @description Method to get idea status list
	 * @param zoneName Idea zone name
	 * @return List of statuses
	 */
	public static List<String> getIdeaStatusValues(String zoneName) {
		List<String> options = new List<String>();
		List<String> statusListFromCMT = new List<String>();

		//Check if idea status list is available at zone CMT Setting
		if(!String.isEmpty(zoneName)) {
			Boolean isZoneSetting = false;

			List<X7S_Ideas_Zone_Setting__mdt> zoneSettings = X7S_Ideas_Zone_Setting__mdt.getAll().values();
			for(X7S_Ideas_Zone_Setting__mdt setting : zoneSettings) {
				if(setting.Zone_Name__c == zoneName) {
					isZoneSetting = true;
					String statusList = setting.Statuses__c;
					if(String.isNotBlank(statusList)) {					
						statusListFromCMT = statusList.split(x7sIdeasBaseController.STATUS_SEPARATOR);
						break;
					}
				}
			}

			if(!isZoneSetting) {
				System.debug('getIdeaStatusValues - No Zone found for the given idea zone name');
			}
		} else {
			System.debug('getIdeaStatusValues - Invalid Idea Zone Name');
		}

		Schema.SObjectType objType = Schema.getGlobalDescribe().get('Idea');
		Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
		Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
		List<Schema.PicklistEntry> values = fieldMap.get('Status').getDescribe().getPicklistValues();

		if(statusListFromCMT.size() > 0) {
			for(String status : statusListFromCMT) {
				status = status.trim();
				Boolean isValidStatus = false;
				for (Schema.PicklistEntry a : values) {
					if (a.active) {
						String statusLabel = a.getLabel();
						if(statusLabel == status) {
							options.add(status);
							isValidStatus = true;
						}
					}
				}	
				if(!isValidStatus) {
					System.debug('getIdeaStatusValues - Invalid Idea Status Value : '+status);
				}
			}
		} 

		//If no zone setting found/No valid status list found in the zone setting, then get idea status list from the object
		if(options.size() < 1) {
			for (Schema.PicklistEntry a : values) {
				if (a.active) {
					System.debug(a);
					options.add(a.getLabel());
				}
			}
		}
		return options;
	}

	/**
	 * @description To get list of idea categories
	 * @return list of categories
	 */
	@AuraEnabled
	public static List<String> getIdeaCategoryValues() {
		System.debug('getIdeaCategoryValues');
		List<String> options = new List<String>();

		Schema.SObjectType objType = Schema.getGlobalDescribe().get('Idea');
		Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
		Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
		List<Schema.PicklistEntry> values = fieldMap.get('Categories').getDescribe().getPicklistValues();

		for (Schema.PicklistEntry a : values) {
			System.debug(a);
			if (a.active) {
				options.add(a.getLabel());
			}
		}

		options.sort();

		return options;
	}

	/**
	 * @description To get list of idea categories based on theme
	 * @param themeName Idea Theme Name
	 * @return list of categories
	 */
	public static List<String> getThemeCategories(String themeName) {
		List<String> options = new List<String>();

		try {
			IdeaTheme theme = [SELECT Id, Title, toLabel(Categories) FROM IdeaTheme WHERE Title = :themeName];
			if (theme != null) { options = theme.Categories.split(';'); }
		} catch (Exception ex) { System.debug('getThemeCategories error: ' + ex.getMessage());}

		return options;
	}

	/**
	* @description To check if profile of current user is 'Read Only'
	* @return true if profile is ready only else false
	*/
	
	@AuraEnabled(Cacheable=true)
	public static Boolean IsReadOnly() {
		Boolean IsReadOnlyProfile = false;
		Boolean canCreate = X7S_Ideas_Subscription__c.sObjectType.getDescribe().isCreateable();
		Boolean canDelete = X7S_Ideas_Subscription__c.sObjectType.getDescribe().isDeletable(); 
		if(!canCreate && !canDelete)
		{
			IsReadOnlyProfile = true;
			
		}
		return IsReadOnlyProfile;
	}
}