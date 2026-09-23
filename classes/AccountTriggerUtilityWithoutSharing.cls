/**
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2025-12-02
 * @AUTHORS: Tanium Dev Team
 * @BUSINESS: Account TriggerUtility class without sharing, part of Trigger framework
 * RequestId  ModifiedDate  Description
 * SS-12027   2025-12-02    Initial development
 * SS-12400   2026-01-22    Removed Tam_Owner_GS__c field from class
 * SS-11508   2026-02-26    Remove TAM_Assigned_GS__c reference	from the class
 * SS-12514   2026-02-27    Updated class to follow our trigger framework
 * SS-13234   2026-06-04    Added setContactLeadSDROwner method to update SDR fields on Contact and Lead
 * SS-12811   2026-06-17    Added setOpportunityOwnerFromAccount method
 */
public without sharing class AccountTriggerUtilityWithoutSharing {
	private static final Integer SDR_CONTACT_BATCH_SIZE = 100;
	private static final Integer SDR_LEAD_BATCH_SIZE = 100;

	public static void setSegment(List<Account> accounts) {
		for (Account account : accounts) {
			account.Segment__c = getSegment(account);
		}
	}

	public static String getSegment(Account account) {
		List<Account_Segment_Mapping__mdt> segmentMappings = Account_Segment_Mapping__mdt.getAll()
			.values();
		segmentMappings.sort(new AccountTriggerUtilityWithoutSharing.SortByOrder());
		String accountSegment = null;

		if (account.Sales_Segment_Override__c != null) {
			accountSegment = account.Sales_Segment_Override__c;
		} else {
			for (Account_Segment_Mapping__mdt segmentMap : segmentMappings) {
				if (AccountUtility.evaluate(segmentMap.Operator__c, segmentMap, account)) {
					accountSegment = segmentMap.Segment__c;
					break;
				}
			}
		}
		return accountSegment;
	}

	public static void setSupportModel(List<Account> accounts) {
		Map<String, String> accountSegmentMappingMap = new Map<String, String>();

		for (Account_Segment_Mapping__mdt accountSegmentMapping : [
			SELECT Id, Segment__c, Support_Model__c
			FROM Account_Segment_Mapping__mdt
			WHERE Support_Model__c != NULL
		]) {
			accountSegmentMappingMap.put(
				accountSegmentMapping.Segment__c,
				accountSegmentMapping.Support_Model__c
			);
		}

		for (Account account : accounts) {
			account.Support_Model__c = accountSegmentMappingMap.get(account.Segment__c);
		}
	}

	public static void partnerInfluencePickListProcess(List<Account> accounts) {
		Set<String> accountNames = new Set<String>();
		Id partnerRecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
		for (Account account : accounts) {
			if (isValidForPartnerInfluencePickListValue(account, partnerRecordTypeId)) {
				accountNames.add(account.name);
			}
		}
		if (accountNames.size() > 0) {
			initiatePartnerInfluencePickListProcess(
				accountNames,
				UserInfo.getSessionId(),
				new Set<String>()
			);
		}
	}

	public static void partnerInfluencePickListProcess(
		List<Account> accounts,
		Map<Id, Account> oldMap
	) {
		Set<String> accountNamesToCreatePicklistValue = new Set<String>();
		Set<String> accountNamesToDeletePicklistValue = new Set<String>();
		Id partnerRecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
		String sessionId = UserInfo.getSessionId();
		Account oldAccount;

		for (Account account : accounts) {
			oldAccount = oldMap.get(account.Id);
			if (
				account.recordTypeId != oldAccount.recordTypeId ||
				account.Active__c != oldAccount.Active__c ||
				account.Name != oldAccount.Name
			) {
				if (isValidForPartnerInfluencePickListValue(oldAccount, partnerRecordTypeId)) {
					accountNamesToDeletePicklistValue.add(oldAccount.Name);
				}

				if (isValidForPartnerInfluencePickListValue(account, partnerRecordTypeId)) {
					accountNamesToCreatePicklistValue.add(account.Name);
				}
			}
		}
		if (
			accountNamesToDeletePicklistValue.size() > 0 ||
			accountNamesToCreatePicklistValue.size() > 0
		) {
			initiatePartnerInfluencePickListProcess(
				accountNamesToCreatePicklistValue,
				UserInfo.getSessionId(),
				accountNamesToDeletePicklistValue
			);
		}
	}

	public static void setOpportunityCsmAccountOwner(
		List<Account> accounts,
		Map<Id, Account> oldMap
	) {
		Map<Id, Id> accountIdToCsmOwnerId = new Map<Id, Id>();
		for (Account account : accounts) {
			if (account.CSM__c != oldMap.get(account.Id).CSM__c) {
				accountIdToCsmOwnerId.put(account.Id, account.CSM__c);
			}

			if (!accountIdToCsmOwnerId.isEmpty() && !System.isBatch() && !System.isFuture()) {
				handleCSMUpdate(accountIdToCsmOwnerId);
			}
		}
	}

	public static void setOpportunityTSEOwner(List<Account> accounts, Map<Id, Account> oldMap) {
		Set<Id> accountIds = new Set<Id>();
		List<Opportunity> opps;
		List<Opportunity> oppsToUpdate = new List<Opportunity>();

		for (Account account : accounts) {
			if (account.TAM_Sales_SME__c != oldMap.get(account.Id).TAM_Sales_SME__c) {
				accountIds.add(account.Id);
			}
		}

		if (!accountIds.isEmpty()) {
			for (Opportunity opp : [
				SELECT TAM_Sales_SME_Owner__c, Account.TAM_Sales_SME__c
				FROM Opportunity
				WHERE
					ForecastCategoryName != 'Closed'
					AND StageName != :Utility.FAILED
					AND AccountId IN :accountIds
			]) {
				opp.TAM_Sales_SME_Owner__c = opp.Account.TAM_Sales_SME__c;
				oppsToUpdate.add(opp);
			}

			List<Database.SaveResult> saveResults = Database.update(oppsToUpdate, false);
			Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountTriggerUtilityWithoutSharing.setOpportunityTSEOwner ERRORS',
				saveResults
			);
			Logger.saveLog();
		}
	}

	@Future(callout=true)
	private static void handleCSMUpdate(Map<Id, Id> csmUpdateMap) {
		List<Opportunity> opps = [
			SELECT Id, AccountId
			FROM Opportunity
			WHERE AccountId IN :csmUpdateMap.keySet() AND IsClosed = FALSE
		];
		for (Opportunity opp : opps) {
			opp.CSM_Account_Owner__c = csmUpdateMap.get(opp.AccountId);
		}
		Database.SaveResult[] updateResults = Database.update(opps, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountTriggerUtilityWithoutSharing.handleCSMUpdate ERRORS',
				updateResults
			)
			.addTag('apex');
		Logger.saveLog();
		String CSV_file = 'reference(Id), Status, Message \n';
		Boolean sendEmail = false;
		for (Integer i = 0; i < updateResults.size(); i++) {
			Database.SaveResult sr = updateResults[i];
			if (!sr.success) {
				CSV_file += '"' + opps[i].Id + '"' + ',Failure,' + sr.errors[0].message + '\n';
				sendEmail = true;
			}
			if (Test.isRunningTest()) {
				CSV_file += '"' + opps[i].Id + '"' + ',Testing,This is a test file\n';
				sendEmail = true;
			}
		}
		if (sendEmail) {
			String currentDateTime = System.now().format();
			String future_method_NAME = 'CSM Future Update';
			Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
			message.subject = future_method_NAME + ' - Notification - ' + currentDateTime;
			message.plainTextBody = 'Customer Engagement Owner Future Operation.Please check details about failed records in this future operation';
			message.toAddresses = new List<String>{ 'dev+tan@cumulusvision.com' };
			if (String.isNotBlank(CSV_file)) {
				Messaging.EmailFileAttachment csvFileAttach = new Messaging.EmailFileAttachment();
				csvFileAttach.setFileName(future_method_NAME + '-' + currentDateTime + '-Result.csv');
				csvFileAttach.setContentType('application/vnd.ms-excel');
				csvFileAttach.setBody(Blob.valueOf(CSV_file));
				message.FileAttachments = new List<Messaging.EmailFileAttachment>{ csvFileAttach };
			}
			if (!Test.isRunningTest()) {
				List<Messaging.SingleEmailMessage> emailMessageList = new List<Messaging.SingleEmailMessage>{
					message
				};
				List<Messaging.SendEmailResult> emailResultList = Messaging.sendEmail(emailMessageList);
				if (!emailResultList[0].isSuccess()) {
					List<String> accountIds = (List<String>) JSON.deserialize(
						JSON.serialize(csmUpdateMap.keySet()),
						List<String>.class
					);
				}
			}
		}
	}

	private static Boolean isValidForPartnerInfluencePickListValue(
		Account account,
		Id partnerRecordTypeId
	) {
		if (account.RecordTypeId == partnerRecordTypeId && account.Active__c == 'Active')
			return true;
		return false;
	}

	@Future(callout=true)
	private static void initiatePartnerInfluencePickListProcess(
		Set<String> newPickListValuesToAdd,
		String sessionId,
		Set<String> pickListValuesToDelete
	) {
		final String fullFieldNameOfPicklistField = 'Campaign.Partner_Influence__c';

		if (pickListValuesToDelete.size() > 0)
			deletePicklistValue(pickListValuesToDelete, sessionId, fullFieldNameOfPicklistField);

		if (newPickListValuesToAdd.size() > 0)
			addPicklistFieldValue(newPickListValuesToAdd, sessionId, fullFieldNameOfPicklistField);
	}

	private static void deletePicklistValue(
		Set<String> newPickListValuesToDelete,
		String sessionId,
		String fullFieldNameOfPicklistField
	) {
		MetadataService.MetadataPort service = createService(sessionId);
		MetadataService.CustomField customField = getCustomFieldValue(
			service,
			fullFieldNameOfPicklistField
		);
		Set<String> existingPartnerInfluencePicklistValues = getPicklistValues(
			customField.picklist.picklistValues
		);
		Set<String> fullNameOfPicklistValue = new Set<String>();

		for (String aname : newPickListValuesToDelete) {
			if (existingPartnerInfluencePicklistValues.contains(aname))
				fullNameOfPicklistValue.add(fullFieldNameOfPicklistField + '.' + aname);
		}
		if (fullNameOfPicklistValue.size() > 0) {
			MetadataService.SaveResult saveResult;
			if (!Test.isRunningTest()) {
				saveResult = convertToSaveResult(
					service.deleteMetadata('PicklistValue', new List<String>(fullNameOfPicklistValue))[0]
				);
			} else {
				saveResult = mockdataOfMetaDataApiResult();
			}
			handleSaveResults(saveResult);
		}
	}

	private static void addPicklistFieldValue(
		Set<String> newPickListValuesToAdd,
		String sessionId,
		String fullFieldNameOfPicklistField
	) {
		MetadataService.MetadataPort service = createService(sessionId);
		MetadataService.CustomField customField = getCustomFieldValue(
			service,
			fullFieldNameOfPicklistField
		);
		Set<String> existingPartnerInfluencePicklistValues = getPicklistValues(
			customField.picklist.picklistValues
		);
		MetadataService.PicklistValue picklistValue;

		for (String value : newPickListValuesToAdd) {
			if (!existingPartnerInfluencePicklistValues.contains(value)) {
				picklistValue = new metadataservice.PicklistValue();
				picklistValue.fullName = value;
				picklistValue.default_x = false;
				customField.picklist.picklistValues.add(picklistValue);
			}
		}
		if (!Test.isRunningTest()) {
			handleSaveResults(
				service.updateMetadata(new List<MetadataService.Metadata>{ customField })[0]
			);
		} else {
			handleSaveResults(mockdataOfMetaDataApiResult());
		}
	}

	private static MetadataService.MetadataPort createService(string sessionId) {
		MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		service.SessionHeader = new MetadataService.SessionHeader_element();
		service.SessionHeader.sessionId = sessionId;
		return service;
	}

	private static MetadataService.CustomField getCustomFieldValue(
		MetadataService.MetadataPort service,
		String fullFieldNameOfPicklistField
	) {
		MetadataService.CustomField customField = new MetadataService.CustomField();
		customField.picklist = new MetadataService.picklist();
		customField.picklist.picklistValues = new List<MetadataService.PicklistValue>();
		if (!Test.isRunningTest()) {
			customField = (MetadataService.CustomField) service.readMetadata(
					'CustomField',
					new List<String>{ fullFieldNameOfPicklistField }
				)
				.getRecords()[0];
		} else
			customField = mockDataOfCustomField(customField);
		return customField;
	}

	private static Set<String> getPicklistValues(
		List<MetadataService.PicklistValue> picklistValues
	) {
		Set<String> nameOfPicklistValues = new Set<String>();

		for (MetadataService.PicklistValue value : picklistValues) {
			nameOfPicklistValues.add(value.fullName);
		}
		return nameOfPicklistValues;
	}

	@TestVisible
	private static MetadataService.SaveResult convertToSaveResult(
		MetadataService.DeleteResult deleteResult
	) {
		MetadataService.SaveResult saveResult = new MetadataService.SaveResult();
		saveResult.errors = deleteResult.errors;
		saveResult.fullName = deleteResult.fullName;
		saveResult.success = deleteResult.success;
		return saveResult;
	}

	@TestVisible
	private static void handleSaveResults(MetadataService.SaveResult saveResult) {
		if (saveResult == null || saveResult.success) {
			return;
		}
		if (saveResult.errors != null) {
			List<String> messages = new List<String>();
			messages.add(
				(saveResult.errors.size() == 1 ? 'Error ' : 'Errors ') +
				'occured processing component ' +
				saveResult.fullName +
				'.'
			);
			for (MetadataService.Error error : saveResult.errors)
				messages.add(
					error.message +
					' (' +
					error.statusCode +
					').' +
					(error.fields != null &&
						error.fields.size() > 0
						? ' Fields ' + String.join(error.fields, ',') + '.'
						: '')
				);
			if (messages.size() > 0) {
				throw new MetadataServiceException(String.join(messages, ' '));
			}
		}
		if (!saveResult.success) {
			throw new MetadataServiceException('Request failed with no specified error.');
		}
	}

	private static MetadataService.SaveResult mockdataOfMetaDataApiResult() {
		String strOfSaveResult = '{"success_type_info":["success","http://soap.sforce.com/2006/04/metadata",null,"1","1","false"],"success":true,"fullName_type_info":["fullName","http://soap.sforce.com/2006/04/metadata",null,"1","1","false"],"fullName":"Campaign.Partner_Influence__c","field_order_type_info":["errors","fullName","success"],"errors_type_info":["errors","http://soap.sforce.com/2006/04/metadata",null,"0","-1","false"],"errors":null,"apex_schema_type_info":["http://soap.sforce.com/2006/04/metadata","true","false"]}';

		return (MetadataService.SaveResult) System.JSON.deserialize(
			strOfSaveResult,
			MetadataService.SaveResult.class
		);
	}

	private static MetadataService.CustomField mockDataOfCustomField(
		MetadataService.CustomField customField
	) {
		metadataservice.PicklistValue picklistValue = new metadataservice.PicklistValue();
		picklistValue.fullName = 'Partner Account 1';
		picklistValue.default_x = false;
		customField.picklist.picklistValues.add(picklistValue);
		return customField;
	}

	public static void setContactOwnerFromAccount(List<Account> accounts, Map<Id, Account> oldMap) {
		Map<Id, Account> accountMap = new Map<Id, Account>();

		for (Account account : accounts) {
			if (account.Named_Account__c) {
				continue;
			}
			if (account.ownerId != oldMap.get(account.Id).ownerId) {
				accountMap.put(account.Id, account);
			}
		}
		if (!accountMap.isEmpty()) {
			setContactOwnerFromAccount(accountMap);
		}
	}

	@TestVisible
	private static void setContactOwnerFromAccount(Map<Id, Account> accountMap) {
		List<Contact> contacts = [
			SELECT AccountId, OwnerId
			FROM Contact
			WHERE AccountId IN :accountMap.keySet()
		];
		for (Contact contact : contacts) {
			contact.OwnerId = accountMap.get(contact.AccountId).OwnerId;
		}

		List<Database.SaveResult> saveResults = Database.update(contacts, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountTriggerHandler.updateContactOwnerFromAccount ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void setDealRegistrationAccountSegment(
		List<Account> accounts,
		Map<Id, Account> oldMap
	) {
		Map<Id, String> accountIdToAccountSegment = new Map<Id, String>();

		for (Account account : accounts) {
			if (account.Named_Account__c) {
				continue;
			}
			if (account.Segment__c != oldMap.get(account.Id).Segment__c) {
				accountIdToAccountSegment.put(account.Id, account.Segment__c);
			}
		}

		if (!accountIdToAccountSegment.isEmpty()) {
			setDealRegistrationAccountSegment(accountIdToAccountSegment);
		}
	}

	@TestVisible
	private static void setDealRegistrationAccountSegment(
		Map<Id, String> accountIdToAccountSegment
	) {
		List<Deal_Registration__c> dealRegistrations = new List<Deal_Registration__c>();
		for (Deal_Registration__c dealRegistration : [
			SELECT Id, Account__c, End_Customer_Account_Segment__c
			FROM Deal_Registration__c
			WHERE Account__c IN :accountIdToAccountSegment.keySet()
		]) {
			dealRegistration.End_Customer_Account_Segment__c = accountIdToAccountSegment.get(
				dealRegistration.Account__c
			);
			dealRegistrations.add(dealRegistration);
		}
		TriggerHandler.bypass('DealRegistrationTriggerHandler');

		List<Database.SaveResult> saveResults = Database.update(dealRegistrations, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountTriggerHandler.updateDealRegistrationAccountSegment() ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
		TriggerHandler.clearBypass('DealRegistrationTriggerHandler');
	}

	public static void setOpportunityOwnerFromAccount(
		List<Account> accounts,
		Map<Id, Account> oldMap
	) {
		Set<Id> accountIds = new Set<Id>();
		for (Account account : accounts) {
			if (account.OwnerId != oldMap.get(account.Id).OwnerId) {
				accountIds.add(account.Id);
			}
		}

		if (!accountIds.isEmpty() && !Test.isRunningTest()) {
			Database.executeBatch(new OpportunityOwnerETMBatch(accountIds));
		}
	}

	public static void setContactLeadSDROwner(List<Account> accounts, Map<Id, Account> oldMap) {
		Set<Id> accountIds = new Set<Id>();
		for (Account account : accounts) {
			if (
				(account.BDR__c != null &&
				(oldMap == null ||
				account.BDR__c != oldMap.get(account.Id).BDR__c)) ||
				(account.SDR_Manager__c != null &&
				(oldMap == null ||
				account.SDR_Manager__c != oldMap.get(account.Id).SDR_Manager__c))
			) {
				accountIds.add(account.Id);
			}
		}

		if (!accountIds.isEmpty()) {
			Database.executeBatch(new ContactSDRBatch(accountIds), SDR_CONTACT_BATCH_SIZE);
			Database.executeBatch(new LeadSDRBatch(accountIds), SDR_LEAD_BATCH_SIZE);
		}
	}

	public class SortByOrder implements Comparator<Account_Segment_Mapping__mdt> {
		public Integer compare(Account_Segment_Mapping__mdt a, Account_Segment_Mapping__mdt b) {
			Integer result = 0;
			if (a.Order__c < b.Order__c) {
				result = -1;
			} else if (a.Order__c > b.Order__c) {
				result = 1;
			}
			return result;
		}
	}

	public class MetadataServiceException extends Exception {
	}
}