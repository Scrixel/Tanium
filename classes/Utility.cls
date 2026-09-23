/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class supporting entire code base
 * @Date: 2020-01-18
 * @Author: Tanium Dev Team
 * RequestId ModifiedDate  Description
 * SS-7099   2024-02-23    Added method isQueue
 * SS-7985   2024-05-14    Added method getDependentPicklistValues
 * SS-7595	 2024-05-17    Added 'Waiting For Signature' stage
 * SS-8749   2024-07-24    Added method getQueueId
 * SS-9451   2024-11-20    Added method isCase
 * SS-8303   2024-12-05    Added method getNetworkId
 * SS-9838   2024-12-25    Added method getChangedFields
 * SS-9838   2025-01-17    Added method sleep
 * SS-9852   2025-01-25    Added method getAppName
 * SS-9432   2025-03-01    Added method isClosedOpp
 * SS-11659  2025-09-12    Added method getInstanceSettingValue
 * SS-11875  2025-10-31    Added methods buildEmailUsingTemplate, getNoReplyFromEmailId, getEmailTemplateId
 * SS-13234  2026-06-04    Added method getUserIdToUserManagerId
 * SS-13423  2026-06-23    Added method isUser
 * SS-13636  2026-09-11    Added new stage constants, fixed Waiting for Signature casing
 */
public inherited sharing class Utility {
	public static final String OBJECT_NOT_FOUND_ERROR = ' SObject was not found';
	public static final String RECORDTYPE_NOT_FOUND_ERROR = ' RecordType Developer name was not found';
	public static final String PROSPECTING = 'Prospecting';
	public static final String PILOT_VALUE_VALIDATED = 'Pilot & Value Validated';
	public static final String DISCOVERY = 'Discovery';
	public static final String POC = 'POC';
	public static final String TECH_WIN_NEGOTIATIONS = 'Tech Win & Negotiations';
	public static final String UNCOMMITTED_RENEWAL = 'Uncommitted Renewal';
	public static final String ACCOUNT_ASSESSMENT = 'Account Assessment';
	public static final String CUSTOMER_ENGAGED = 'Customer Engaged';
	public static final String PROPOSAL_SENT = 'Proposal Sent';
	public static final String COMMIT_STAGE = 'Commit';
	public static final String SIGNED_PAPERWORK_RECEIVED = 'Signed - Paperwork received';
	public static final String SIGNED_AND_INVOICED = 'Signed & Invoiced';
	public static final String SIGNED_AND_PAID = 'Signed & Paid';
	public static final String ORDER_DRAFTED = 'Order Drafted';
	public static final String CLOSED_WON = 'CLOSED WON';
	public static final String FAILED = 'Failed';
	public static final String FAILED_RENEWAL = 'Failed Renewal';
	public static final String WAITING_FOR_SIGNATURE = 'Waiting for Signature';
	public static final List<String> CLOSED_STAGES = new List<String>{
		CLOSED_WON,
		FAILED,
		FAILED_RENEWAL
	};
	public static final Integer PROSPECTING_STAGE_NUMBER = 10;
	public static final Integer COMMIT_STAGE_NUMBER = 130;
	public static final Integer SIGNED_PAPERWORK_RECEIVED_STAGE_NUMBER = 170;

	public static Map<String, Id> profileIdMap = new Map<String, Id>();
	public static Map<String, Id> userRoleIdMap = new Map<String, Id>();
	@TestVisible
	private static Boolean isSandbox;
	@TestVisible
	private static Map<String, List<HiddenFeatures__mdt>> hiddenFeaturesByMetadataType;
	@TestVisible
	private static Map<String, HiddenFeatures__mdt> hiddenFeaturesByDeveloperName;
	@TestVisible
	private static Map<Id, Pricebook2> activePricebookMap;
	private static Map<String, Id> recordTypeIdMap = new Map<String, Id>();
	@TestVisible
	private static User runningUser;
	@TestVisible
	private static List<String> orgDomains = new List<String>();
	private static final Map<Decimal, String> formatNumbers = new Map<Decimal, String>{
		1 => 'first',
		2 => 'second',
		3 => 'third',
		4 => 'fourth',
		5 => 'fifth',
		6 => 'sixth',
		7 => 'seventh',
		8 => 'eigth',
		9 => 'ninth',
		10 => 'tenth',
		11 => 'eleventh',
		12 => 'twelfth'
	};

	public static String addProtocolToURL(String url) {
		if (String.isBlank(url)) {
			return '';
		} else if (url.startsWithIgnoreCase('https://')) {
			return url;
		} else if (url.startsWithIgnoreCase('http')) {
			return url.replaceFirst('http', 'https');
		} else {
			return 'https://' + url;
		}
	}

	public static String safeString(String input) {
		return String.isBlank(input) ? '' : input;
	}

	public static String shortenString(String input, Integer maxLength) {
		input = safeString(input);

		while (input.length() > maxLength) {
			String shortenedInput = input.substringBeforeLast(' ');

			//Trying to shorten by space separator
			if (input.length() != shortenedInput.length()) {
				input = shortenedInput;
			} else {
				input = input.substring(0, maxLength);
			}
		}

		return input;
	}

	public static String addressToString(Address address) {
		if (address != null) {
			return (safeString(address.getStreet()) +
				' ' +
				safeString(address.getCity()) +
				', ' +
				safeString(address.getState()) +
				' ' +
				safeString(address.getPostalCode()) +
				' ' +
				safeString(address.getCountry()))
				.trim();
		}
		return '';
	}

	public static String truncateString(String text, Integer maxLength) {
		if (text != null && text.length() > maxLength) {
			return text.subString(0, maxLength);
		}
		return text;
	}

	public static Id getRecordTypeIdByAPIName(String objectName, String recordTypeAPIName) {
		Id recordTypeId = Utility.recordTypeIdMap.get(objectName + recordTypeAPIName);

		if (recordTypeId == null) {
			SObjectType objectType;

			try {
				objectType = ((SObject) Type.forName('Schema', objectName).newInstance())
					.getSObjectType();
			} catch (Exception error) {
				throw new SObjectException(objectName + OBJECT_NOT_FOUND_ERROR);
			}

			recordTypeId = Utility.getRecordTypeIdByAPIName(objectType, recordTypeAPIName);
		}

		return recordTypeId;
	}

	public static Id getRecordTypeIdByAPIName(SObject objectName, String recordTypeAPIName) {
		Id recordTypeId = Utility.recordTypeIdMap.get(objectName + recordTypeAPIName);

		if (recordTypeId == null) {
			SObjectType objectType = objectName.getSObjectType();
			recordTypeId = Utility.getRecordTypeIdByAPIName(objectType, recordTypeAPIName);
		}

		return recordTypeId;
	}

	public static Id getRecordTypeIdByAPIName(SObjectType objectType, String recordTypeAPIName) {
		Id recordTypeId = Utility.recordTypeIdMap.get(objectType + recordTypeAPIName);

		if (recordTypeId == null) {
			try {
				recordTypeId = objectType.getDescribe()
					.getRecordTypeInfosByDeveloperName()
					.get(recordTypeAPIName)
					.getRecordTypeId();

				Utility.recordTypeIdMap.put(objectType + recordTypeAPIName, recordTypeId);
			} catch (Exception error) {
				throw new SObjectException(recordTypeAPIName + RECORDTYPE_NOT_FOUND_ERROR);
			}
		}

		return recordTypeId;
	}

	public static Boolean isSandbox() {
		if (isSandbox == null) {
			isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
		}
		return isSandbox;
	}

	public static String getInstance(Url orgDomainUrl) {
		String[] baseUrlSegements = orgDomainUrl.getHost().split('\\.');
		String instance = (!isSandbox())
			? 'Production'
			: (baseUrlSegements[0].contains('build'))
					? 'Build'
					: (baseUrlSegements[0].contains('uat')) ? 'UAT' : 'Developer';
		return instance;
	}

	public static Id getProfileId(String profileName) {
		Id profileId = Utility.profileIdMap.get(profileName);

		if (profileId == null) {
			try {
				profileId = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1].Id;
				Utility.profileIdMap.put(profileName, profileId);
			} catch (Exception error) {
				throw new QueryException(profileName + ' profile not found');
			}
		}

		return profileId;
	}

	public static Id getUserRoleId(String userRoleName) {
		Id userRoleId = Utility.userRoleIdMap.get(userRoleName);

		if (userRoleId == null) {
			try {
				userRoleId = [SELECT Id FROM UserRole WHERE Name = :userRoleName LIMIT 1].Id;
				Utility.userRoleIdMap.put(userRoleName, userRoleId);
			} catch (Exception error) {
				throw new QueryException(userRoleName + ' user role not found');
			}
		}

		return userRoleId;
	}

	public static Id getAdminUserProfileId() {
		return Utility.getProfileId('Tanium System Administrator');
	}

	public static Id getSuperUserProfileId() {
		return Utility.getProfileId('Super User');
	}

	public static Id getTaniumDealsDeskProfileId() {
		return Utility.getProfileId('Tanium Deals Desk');
	}

	public static Id getAPIOnlyIntegrationAdminProfileId() {
		return Utility.getProfileId('API Only Integration Admin');
	}

	public static Id getTaniumStandardUserProfileId() {
		return Utility.getProfileId('Tanium Standard User');
	}

	public static Id getCorporateRoleId() {
		return Utility.getUserRoleId('Corporate');
	}

	public static void fireUpdateOnObject(
		List<SObject> recordsToUpdate,
		System.Savepoint databaseSavepoint,
		Boolean allOrNone
	) {
		List<Database.SaveResult> saveResults = Database.update(recordsToUpdate, allOrNone);
		for (Database.SaveResult each : saveResults) {
			if (!each.isSuccess()) {
				if (databaseSavepoint != null) {
					Database.rollback(databaseSavepoint);
				}
				throw new DmlException('### DMLException: ' + each.getErrors());
			}
		}
	}

	public static List<Database.SaveResult> fireInsertOnObject(
		List<SObject> recordsToInsert,
		System.Savepoint databaseSavepoint,
		Boolean allOrNone
	) {
		List<Database.SaveResult> saveResults = Database.insert(recordsToInsert, allOrNone);
		for (Database.SaveResult each : saveResults) {
			if (!each.isSuccess()) {
				if (databaseSavepoint != null) {
					Database.rollback(databaseSavepoint);
				}
				throw new DmlException('### DMLException: ' + each.getErrors());
			}
		}
		return saveResults;
	}

	public static List<Database.DeleteResult> fireDeleteOnObject(
		List<SObject> recordsToDelete,
		System.Savepoint databaseSavepoint,
		Boolean allOrNone
	) {
		List<Database.DeleteResult> deleteResults = Database.delete(recordsToDelete, allOrNone);
		for (Database.DeleteResult each : deleteResults) {
			if (!each.isSuccess()) {
				if (databaseSavepoint != null) {
					Database.rollback(databaseSavepoint);
				}
				throw new DmlException('#### DMLException: ' + each.getErrors());
			}
		}
		return deleteResults;
	}

	public static Map<String, HiddenFeatures__mdt> getAllHiddenFeatures() {
		List<HiddenFeatures__mdt> features = new List<HiddenFeatures__mdt>();
		HiddenFeatures__mdt eachFeature;
		if (Utility.hiddenFeaturesByMetadataType == null) {
			hiddenFeaturesByMetadataType = new Map<String, List<HiddenFeatures__mdt>>();
			hiddenFeaturesByDeveloperName = new Map<String, HiddenFeatures__mdt>();
			for (HiddenFeatures__mdt each : [
				SELECT Id, Description__c, DeveloperName, isActive__c, Label, MetadataType__c, SOQL__c
				FROM HiddenFeatures__mdt
				ORDER BY MetadataType__c
			]) {
				features = hiddenFeaturesByMetadataType.get(each.MetadataType__c);
				if (features == null) {
					Utility.hiddenFeaturesByMetadataType.put(
						each.MetadataType__c,
						new List<HiddenFeatures__mdt>{ each }
					);
				} else {
					features.add(each);
				}
				Utility.hiddenFeaturesByDeveloperName.put(each.DeveloperName, each);
			}
		}
		return Utility.hiddenFeaturesByDeveloperName;
	}

	/* 
        If we have duplicate API names due to different metadata types, this method will help 
    */
	public static List<HiddenFeatures__mdt> getHiddenFeaturesByMetadataType(String metadataType) {
		List<HiddenFeatures__mdt> hiddenFeatures = new List<HiddenFeatures__mdt>();
		Utility.getAllHiddenFeatures();
		if (metadataType != null && Utility.hiddenFeaturesByMetadataType != null) {
			hiddenFeatures = Utility.hiddenFeaturesByMetadataType.get(metadataType);
		}
		return hiddenFeatures;
	}

	public static HiddenFeatures__mdt getHiddenFeaturesByDeveloperName(String developerName) {
		HiddenFeatures__mdt feature;
		Utility.getAllHiddenFeatures();
		if (developerName != null && Utility.hiddenFeaturesByDeveloperName != null) {
			feature = Utility.hiddenFeaturesByDeveloperName.get(developerName);
		}
		return feature;
	}

	public static HiddenFeatures__mdt activateHiddenFeature(String developerName) {
		HiddenFeatures__mdt feature = Utility.getHiddenFeaturesByDeveloperName(developerName);
		if (feature != null) {
			feature.isActive__c = 'True';
		}
		return feature;
	}

	public static HiddenFeatures__mdt deactivateHiddenFeature(String developerName) {
		HiddenFeatures__mdt feature = Utility.getHiddenFeaturesByDeveloperName(developerName);
		if (feature != null) {
			feature.isActive__c = 'False';
		}
		return feature;
	}

	public static HiddenFeaturesWrapper getHiddenFeatureWrapper(String developerName) {
		HiddenFeaturesWrapper wrpr = new HiddenFeaturesWrapper();
		HiddenFeatures__mdt feature = Utility.getHiddenFeaturesByDeveloperName(developerName);
		if (feature != null && feature.isActive__c == 'True' && feature.SOQL__c != null) {
			// code to run for given SOQL; hence not technically hidden
			wrpr.isHidden = false;
			wrpr.soql = feature.SOQL__c;
		} else if (feature != null && feature.isActive__c == 'True' && feature.SOQL__c == null) {
			// if not active, SOQL doesn't matter
			wrpr.isHidden = true;
			wrpr.soql = '';
		} else if (feature != null && feature.isActive__c == 'False') {
			// if not active, SOQL doesn't matter
			wrpr.isHidden = false;
			wrpr.soql = '';
		} else {
			//default
			wrpr.isHidden = false;
			wrpr.soql = '';
		}
		return wrpr;
	}

	public static String getSOQLForHiddenFeature(String developerName) {
		HiddenFeatures__mdt feature = Utility.getHiddenFeaturesByDeveloperName(developerName);
		if (feature != null && feature.isActive__c == 'True' && feature.SOQL__c != null) {
			return feature.SOQL__c;
		}
		return '';
	}

	public class HiddenFeaturesWrapper {
		public Boolean isHidden { get; set; }
		public String soql { get; set; }
	}

	public static Map<Id, Pricebook2> getActivePricebooksMap() {
		if (Utility.activePricebookMap == null) {
			Utility.activePricebookMap = new Map<Id, Pricebook2>(
				[SELECT id, Name FROM Pricebook2 WHERE isActive = TRUE]
			);
			if (Utility.activePricebookMap == null) {
				throw new QueryException('No Active Pricebooks Found');
			}
		}
		return Utility.activePricebookMap;
	}

	public static List<Pricebook2> getActivePricebook(String priceBookName) {
		List<Pricebook2> priceBooks = new List<Pricebook2>(
			[SELECT Id, Name FROM Pricebook2 WHERE isActive = TRUE AND Name = :priceBookName]
		);
		return priceBooks;
	}

	public static Boolean isFutureMethodAllowed() {
		return !System.isFuture() &&
			!System.isBatch() &&
			Limits.getFutureCalls() < Limits.getLimitFutureCalls();
	}

	public static Decimal safeDecimal(String input) {
		Decimal result;
		try {
			result = Decimal.valueOf(input);
		} catch (Exception error) {
			result = 0;
		}
		return result;
	}

	public static User getRunningUser() {
		if (Utility.runningUser == null) {
			Utility.runningUser = [
				SELECT Id, DisableTaniumCustomTriggers__c
				FROM User
				WHERE Id = :UserInfo.getUserId()
			];
		}
		return Utility.runningUser;
	}

	public static Boolean isTaniumCustomTriggerDisabled(String triggerOrHandlerName) {
		Utility.getRunningUser();
		if (Utility.runningUser.DisableTaniumCustomTriggers__c != null) {
			return Utility.runningUser.DisableTaniumCustomTriggers__c.contains('All') ||
				Utility.runningUser.DisableTaniumCustomTriggers__c.contains(triggerOrHandlerName);
		}
		return false;
	}

	public static String getFormattedString(Decimal myNumber) {
		return Utility.formatNumbers.get(myNumber);
	}

	public static Boolean isValidRedirectUrl(String url) {
		if (String.isNotBlank(url)) {
			if (url.startsWithIgnoreCase('https')) {
				Url returnURL = new Url(url);
				String domain = returnURL.getHost();
				List<String> orgDomains = getOrgDomains();
				if (orgDomains.contains(domain)) {
					return true;
				}
			} else if (url.startsWith('/')) {
				if (!url.contains('//') && !url.contains('@')) {
					return true;
				}
			}
		}

		return false;
	}

	@TestVisible
	private static List<String> getOrgDomains() {
		if (Utility.orgDomains.isEmpty()) {
			for (Domain domain : [SELECT Id, Domain FROM Domain]) {
				Utility.orgDomains.add(domain.Domain);
			}
		}
		return Utility.orgDomains;
	}

	public static Boolean isQueue(Id ownerId) {
		return (ownerId == null) ? false : (String.valueOf(ownerId).left(3) == '00G');
	}

	public static Id getQueueId(String queueName) {
		Id queueId = null;
		try {
			queueId = [SELECT QueueId FROM QueueSobject WHERE Queue.Name = :queueName].QueueId;
		} catch (Exception e) {
		}
		return queueId;
	}

	public static Id getServiceChannelId(String objectName) {
		Id serviceChannelId;
		try {
			serviceChannelId = [
				SELECT Id
				FROM ServiceChannel
				WHERE RelatedEntity = :objectName
				WITH SYSTEM_MODE
				LIMIT 1
			]
			.Id;
		} catch (Exception e) {
			Logger.error('Utility.getServiceChannelId Errors', e).addTag('apex');
			Logger.saveLog();
			serviceChannelId = null;
		}
		return serviceChannelId;
	}

	public static Map<String, List<String>> getDependentPicklistValues(
		String objectName,
		String contrfieldApiName,
		String depfieldApiName
	) {
		String controllingField = contrfieldApiName.toLowerCase();
		String dependentField = depfieldApiName.toLowerCase();

		Map<String, List<String>> objResults = new Map<String, List<String>>();

		Schema.SObjectType objType = ((SObject) Type.forName('Schema', objectName).newInstance())
			.getSObjectType();
		if (objType == null) {
			return objResults;
		}

		Map<String, Schema.SObjectField> objFieldMap = objType.getDescribe().fields.getMap();

		if (!objFieldMap.containsKey(controllingField) || !objFieldMap.containsKey(dependentField)) {
			return objResults;
		}

		Schema.SObjectField theField = objFieldMap.get(dependentField);
		Schema.SObjectField ctrlField = objFieldMap.get(controllingField);

		List<Schema.PicklistEntry> contrEntries = ctrlField.getDescribe().getPicklistValues();
		List<PicklistEntryWrapper> depEntries = wrapPicklistEntries(
			theField.getDescribe().getPicklistValues()
		);
		List<String> controllingValues = new List<String>();

		for (Schema.PicklistEntry ple : contrEntries) {
			String label = ple.getLabel();
			objResults.put(label, new List<String>());
			controllingValues.add(label);
		}

		for (PicklistEntryWrapper plew : depEntries) {
			String label = plew.label;
			String validForBits = base64ToBits(plew.validFor);
			for (Integer i = 0; i < validForBits.length(); i++) {
				String bit = validForBits.mid(i, 1);
				if (bit == '1') {
					objResults.get(controllingValues.get(i)).add(label);
				}
			}
		}
		return objResults;
	}

	public static String decimalToBinary(Integer val) {
		String bits = '';
		while (val > 0) {
			Integer remainder = Math.mod(val, 2);
			val = Integer.valueOf(Math.floor(val / 2));
			bits = String.valueOf(remainder) + bits;
		}
		return bits;
	}

	public static String base64ToBits(String validFor) {
		if (String.isEmpty(validFor))
			return '';

		String validForBits = '';

		for (Integer i = 0; i < validFor.length(); i++) {
			String thisChar = validFor.mid(i, 1);
			Integer val = base64Chars.indexOf(thisChar);
			String bits = decimalToBinary(val).leftPad(6, '0');
			validForBits += bits;
		}

		return validForBits;
	}

	private static final String base64Chars =
		'' +
		'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
		'abcdefghijklmnopqrstuvwxyz' +
		'0123456789+/';

	private static List<PicklistEntryWrapper> wrapPicklistEntries(List<Schema.PicklistEntry> PLEs) {
		return (List<PicklistEntryWrapper>) JSON.deserialize(
			JSON.serialize(PLEs),
			List<PicklistEntryWrapper>.class
		);
	}

	public static Boolean isCase(Id recordId) {
		return (recordId == null) ? false : (String.valueOf(recordId).left(3) == '500');
	}

	public static Boolean isUser(Id recordId) {
		return (recordId == null) ? false : (String.valueOf(recordId).left(3) == '005');
	}

	public static Boolean isClosedOpp(String oppStage) {
		return CLOSED_STAGES.contains(oppStage);
	}

	public static Id getNetworkId(String networkName) {
		try {
			return [SELECT Id FROM Network WHERE Name = :networkName].Id;
		} catch (Exception e) {
			return null;
		}
	}

	public static Set<String> getChangedFields(
		SObject oldRecord,
		SObject newRecord,
		Set<String> fieldList
	) {
		Set<String> changedFields = new Set<String>();
		for (String eachField : fieldList) {
			Object oldField = oldRecord.get(eachField);
			Object newField = newRecord.get(eachField);
			if (oldField != newField) {
				changedFields.add(eachField);
			}
		}
		return changedFields;
	}

	public static String getAppName() {
		String appName = '';
		UserAppInfo userAppInfo = [
			SELECT Id, AppDefinitionId
			FROM UserAppInfo
			WHERE UserId = :UserInfo.getUserId()
			LIMIT 1
		];

		AppDefinition appDefinition = [
			SELECT DurableId, Label
			FROM AppDefinition
			WHERE DurableId = :userAppInfo.AppDefinitionId
			LIMIT 1
		];

		return appDefinition.Label;
	}

	public static void sleep(Integer seconds) {
		Long epochToDate = System.currentTimeMillis();
		Long epochStop = epochToDate + (seconds * 1000);

		while (epochToDate <= epochStop) {
			epochToDate = System.currentTimeMillis();
		}
	}

	public static void logBatchErrors(Database.BatchableContext bc, String apexClass) {
		AsyncApexJob job = [
			SELECT
				Id,
				Status,
				NumberOfErrors,
				JobItemsProcessed,
				TotalJobItems,
				CreatedBy.Email,
				ExtendedStatus
			FROM AsyncApexJob
			WHERE Id = :bc.getJobId()
		];

		if ((job.Status == 'Completed' && job.NumberOfErrors > 0) || Test.isRunningTest()) {
			String results =
				'NumberOfErrors: ' +
				job.NumberOfErrors +
				'.' +
				apexClass +
				' processed ' +
				job.TotalJobItems +
				' batches with ' +
				job.NumberOfErrors;
			if (job.ExtendedStatus != null) {
				results = results + ' failures.ExtendedStatus: ' + job.ExtendedStatus;
			}
			Logger.error(apexClass + ' FAILURE STATISTICS:' + results).addTag('apex').addTag('batch');
			Logger.saveLog();
		}
	}

	public static String getInstanceSettingValue(String type) {
		Boolean isSandbox = Utility.isSandbox();
		String instance = Utility.getInstance(Url.getOrgDomainURL());
		String instanceSettingValue = null;

		for (Instance_Setting__mdt instanceSetting : Instance_Setting__mdt.getAll().values()) {
			if (
				instanceSetting.IsActive__c &&
				instanceSetting.Instance__c == instance &&
				instanceSetting.Type__c == type &&
				instanceSetting.IsSandbox__c == isSandbox
			) {
				instanceSettingValue = instanceSetting.Value__c;
			}
		}
		return instanceSettingValue;
	}

	public static Messaging.SingleEmailMessage buildEmailUsingTemplate(
		Id emailTemplateId,
		List<String> toAddresses,
		Id whatId,
		Id targetObjectId,
		Boolean saveActivity,
		Id orgWideEmailAdressId
	) {
		Messaging.SingleEmailMessage email;
		email = new Messaging.SingleEmailMessage();
		email.setTemplateId(emailTemplateId);
		email.setToAddresses(toAddresses);
		email.setTargetObjectId(targetObjectId);
		email.setWhatId(whatId);
		email.setSaveAsActivity(saveActivity);
		email.setUseSignature(false);
		email.setOrgWideEmailAddressId(orgWideEmailAdressId);
		return email;
	}

	public static Id getEmailTemplateId(String emailTemplateName) {
		try {
			return [SELECT Id FROM EmailTemplate WHERE Name = :emailTemplateName].Id;
		} catch (Exception e) {
			return null;
		}
	}

	public static Id getNoReplyFromEmailId() {
		try {
			return [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'Tanium - No Reply' LIMIT 1]
			.Id;
		} catch (Exception e) {
			return null;
		}
	}

	public static Map<Id, Id> getUserIdToUserManagerId(List<Id> userIds) {
		Map<Id, Id> userIdToUserManagerId = new Map<Id, Id>();
		for (User user : [SELECT Id, ManagerId, RVP_Override__c FROM User WHERE Id IN :userIds]) {
			if (user.RVP_Override__c != null) {
				userIdToUserManagerId.put(user.Id, user.RVP_Override__c);
			} else {
				userIdToUserManagerId.put(user.Id, user.ManagerId);
			}
		}
		return userIdToUserManagerId;
	}

	public class PicklistEntryWrapper {
		public String active { get; set; }
		public String defaultValue { get; set; }
		public String label { get; set; }
		public String value { get; set; }
		public String validFor { get; set; }
		public PicklistEntryWrapper() {
		}
	}
}