/**
 * Copyright (c) 2025 Tanium
 *
 * @DATE: 2015-01-18
 * @AUTHORS: Cumulus Vision, Tanium Dev Team
 * @BUSINESS: Account TriggerUtility class, part of Trigger framework
 * RequestId  ModifiedDate  Description
 * SS-7081    2023-12-18    Populate three additional fields on account platform event
 * SS-7583    2024-03-21    Nebula Logger
 * SS-7764    2024-05-22    Added Nebula logger functionality plus class cleanup
 * SS-8481    2024-06-22    Added Invoice_Inquiry_Email__c in publishAccounts method
 * SS-7935    2024-06-26    Change publishAccount trigger to Purchasing Model and Partner Status
 * SS-10897   2025-06-05    Added methods assignTerritoryInformation, insertTerritoryAssociation and supporting method/wrapper class
 * SS-10016   2025-07-22    Added method to auto set the support model on account before insert
 * SS-12200   2025-12-04    Replaced method getUserIdTerritoryIdMap with getUserIdToTerritory, modified method assignTerritoryInformation
 * SS-12027   2026-01-07    Added method populateAccountSDR to populate the SDR field on account
 * SS-12514   2026-02-27    Updated class to follow our trigger framework
 * SS-12691   2026-02-27    Updated method getSegment
 * SS-13234   2026-06-04    Updated setSDR method
 * SS-12811   2026-06-17    Added setOwnerFromSalesTerritory method
 */
public with sharing class AccountTriggerUtility {
	public static final Set<String> VALID_PURCHASING_MODELS_TO_PUBLISH = new Set<String>{
		'Direct',
		'Indirect'
	};

	private static final String CUSTOMER_TYPE = 'Customer';
	private static final String FORMER_CUSTOMER_TYPE = 'Former Customer';
	private static final String PROSPECT_TYPE = 'Prospect';

	public static void syncInternalSupportRequests(List<Account> accounts, Map<Id, Account> oldMap) {
		List<Account> eligibleAccounts = new List<Account>();

		for (Account account : accounts) {
			if (
				account.OwnerId != oldMap.get(account.Id).OwnerId ||
				account.Area_VP__c != oldMap.get(account.Id).Area_VP__c
			) {
				eligibleAccounts.add(account);
			}
		}
		if (!eligibleAccounts.isEmpty()) {
			syncInternalSupportRequests(eligibleAccounts, false);
		}
	}

	public static void syncInternalSupportRequests(List<Account> accounts, Boolean async) {
		AccountInternalSupportRequestAsync isra = new AccountInternalSupportRequestAsync(
			accounts,
			async
		);
		List<Account_Support_Request__c> internalSupportRequests;

		if (async) {
			isra.syncSupportRequests(isra.getSupportRequestsToSync());
			return;
		}
		internalSupportRequests = isra.getSupportRequestsToSync();

		List<Database.SaveResult> saveResults = Database.update(internalSupportRequests, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountTriggerUtility.syncInternalSupportRequests ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void publishAccounts(List<Account> accounts, Map<Id, Account> oldMap) {
		List<Account> eAccounts = new List<Account>(); // eligible accounts
		Set<Id> eAccountIds = new Set<Id>(); // eligible accountIds
		Map<Id, Account> accountsMap = new Map<Id, Account>(accounts);
		Id partnerAccountRecTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');

		for (Account account : accounts) {
			if (account.RecordTypeId == partnerAccountRecTypeId) {
				eAccountIds.add(account.Id);
			}
		}
		AggregateResult[] accountsResults = [
			SELECT AccountId, Count(Id)
			FROM Opportunity
			WHERE AccountId IN :accountsMap.keySet() AND Probability >= 60
			GROUP BY AccountId
		];

		for (AggregateResult accountsResult : accountsResults) {
			eAccountIds.add((Id) accountsResult.get('AccountId'));
		}
		for (Account account : accounts) {
			if (!eAccountIds.contains(account.Id)) {
				continue;
			}
			if (isAccountToPublish(account, oldMap?.get(account.Id), partnerAccountRecTypeId)) {
				eAccounts.add(account);
			}
		}
		if (!eAccounts.isEmpty()) {
			publishAccounts(eAccounts);
		}
	}

	public static void publishAccounts(List<Account> accounts) {
		List<Account_Event__e> accountEvents = new List<Account_Event__e>();
		Account_Event__e accountEvent;

		List<Account> eAccounts = new List<Account>(); // eligible accounts
		Set<Id> userIds = new Set<Id>();
		List<Integration_Callout__c> callouts = new List<Integration_Callout__c>();
		Integration_Callout__c callout;
		Id partnerAccountRecTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');

		for (Account account : accounts) {
			userIds.add(account.OwnerId);
			eAccounts.add(account);
		}

		Map<Id, User> usersMap = new Map<Id, User>(
			[SELECT Id, NS_ID__c FROM User WHERE Id IN :userIds]
		);

		for (Account eAccount : eAccounts) {
			accountEvent = new Account_Event__e();
			accountEvent.Account_Credit_Limit__c = eAccount.Credit_Limit__c;
			accountEvent.Account_ID__c = eAccount.Id;
			accountEvent.Account_Industry__c = eAccount.Industry;
			accountEvent.Account_MCN__c = eAccount.MCN__c;
			accountEvent.Account_Name__c = eAccount.Name;
			accountEvent.Account_NS_Subsidiary_ID__c = eAccount.NS_Subsidiary_ID__c;
			accountEvent.Account_Owner__c = usersMap.get(eAccount.OwnerId).NS_ID__c;
			accountEvent.Account_Payment_Terms__c = eAccount.Payment_Terms__c;
			accountEvent.Account_Record_Type__c = eAccount.RecordTypeId;
			accountEvent.Account_Sector__c = eAccount.Sector__c;
			accountEvent.Account_Segment__c = eAccount.Segment__c;
			accountEvent.Tax_Reg_Number__c = eAccount.Tax_Reg_Number__c;
			accountEvent.Primary_Bill_to_email__c = eAccount.Primary_Bill_to_email__c;
			accountEvent.Partner_Development_Director__c = (eAccount.RecordTypeId ==
				partnerAccountRecTypeId)
				? usersMap.get(eAccount.OwnerId).NS_ID__c
				: null;
			accountEvent.Invoice_Inquiry_Email__c = eAccount.Invoice_Inquiry_Email__c;
			accountEvents.add(accountEvent);
		}
		List<Database.SaveResult> results = EventBus.publish(accountEvents);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountTriggerUtility.publishAccounts() ERRORS',
				results
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void publishAccounts(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
		Set<Id> accountIds = new Set<Id>();

		for (Opportunity opp : opps) {
			if (opp.Probability >= 60 && opp.Probability != oldMap.get(opp.Id).Probability) {
				accountIds.add(opp.AccountId);
			}
		}
		Account[] accounts = (accountIds.isEmpty())
			? null
			: [
					SELECT
						Credit_Limit__c,
						Id,
						Industry,
						MCN__c,
						Name,
						NS_Subsidiary_ID__c,
						OwnerId,
						Partner_Agreement__c,
						Payment_Terms__c,
						RecordTypeId,
						Sector__c,
						Segment__c,
						Tax_Reg_Number__c,
						Primary_Bill_to_email__c,
						Invoice_Inquiry_Email__c
					FROM Account
					WHERE Id IN :accountIds
			  ];

		if (accounts != null) {
			publishAccounts(accounts);
		}
	}

	@TestVisible
	private static Boolean isAccountToPublish(
		Account newAccount,
		Account oldAccount,
		Id partnerAccountRecTypeId
	) {
		Boolean publishAccount = false;
		Boolean mappedFieldChanged = false;

		if (
			oldAccount != null &&
			(newAccount.Credit_Limit__c != oldAccount.Credit_Limit__c ||
			newAccount.Industry != oldAccount.Industry ||
			newAccount.MCN__c != oldAccount.MCN__c ||
			newAccount.Name != oldAccount.Name ||
			newAccount.NS_Subsidiary_ID__c != oldAccount.NS_Subsidiary_ID__c ||
			newAccount.OwnerId != oldAccount.OwnerId ||
			newAccount.Payment_Terms__c != oldAccount.Payment_Terms__c ||
			newAccount.RecordTypeId != oldAccount.RecordTypeId ||
			newAccount.Sector__c != oldAccount.Sector__c ||
			newAccount.Segment__c != oldAccount.Segment__c ||
			newAccount.Tax_Reg_Number__c != oldAccount.Tax_Reg_Number__c ||
			newAccount.Primary_Bill_to_email__c != oldAccount.Primary_Bill_to_email__c ||
			newAccount.Invoice_Inquiry_Email__c != oldAccount.Invoice_Inquiry_Email__c)
		) {
			mappedFieldChanged = true;
		}

		if (newAccount.RecordTypeId == partnerAccountRecTypeId) {
			if (
				oldAccount == null &&
				newAccount.Partner_Maturity__c == 'Active' &&
				VALID_PURCHASING_MODELS_TO_PUBLISH.contains(newAccount.Sales_Model__c)
			) {
				publishAccount = true;
			} else if (
				oldAccount != null &&
				(newAccount.Sales_Model__c != oldAccount.Sales_Model__c ||
				newAccount.Partner_Maturity__c != oldAccount.Partner_Maturity__c ||
				mappedFieldChanged) &&
				newAccount.Partner_Maturity__c == 'Active' &&
				VALID_PURCHASING_MODELS_TO_PUBLISH.contains(newAccount.Sales_Model__c)
			) {
				publishAccount = true;
			}
		} else if (newAccount.RecordTypeId != partnerAccountRecTypeId && mappedFieldChanged) {
			publishAccount = true;
		}
		return publishAccount;
	}

	public static void assignTerritoryInformation(List<Account> accounts) {
		Map<Id, Territory2> userIdToTerritory = getUserIdToTerritory(accounts);

		for (Account account : accounts) {
			account.Primary_Sales_Territory_Id__c = userIdToTerritory.get(account.OwnerId)?.Id;
			account.Primary_Sales_Territory_Name__c = userIdToTerritory?.get(account.OwnerId)?.Name;
			account.Geo__c = userIdToTerritory?.get(account.OwnerId)?.Geo__c;
			account.Region__c = userIdToTerritory?.get(account.OwnerId)?.Region__c;
			account.Sub_Region__c = userIdToTerritory?.get(account.OwnerId)?.Sub_Region__c;
			account.Primary_PFS_Territory_Id__c = userIdToTerritory.get(account.OwnerId)
				?.Associated_Primary_PFS_Territory_Id__c;
			account.Primary_PFS_Territory_Name__c = userIdToTerritory.get(account.OwnerId)
				?.Associated_Primary_PFS_Territory_Name__c;
		}
	}

	private static Map<Id, Territory2> getUserIdToTerritory(List<Account> accounts) {
		Set<Id> userIds = new Set<Id>();
		Map<Id, Territory2> userIdToTerritory = new Map<Id, Territory2>();
		Territory2 territory;
		Id priorUserId = null;

		for (Account account : accounts) {
			userIds.add(account.OwnerId);
		}

		UserTerritory2Association[] userTerritoryAssociations = [
			SELECT
				Id,
				UserId,
				Territory2Id,
				Territory2.Name,
				Territory2.DeveloperName,
				Territory2.Geo__c,
				Territory2.Region__c,
				Territory2.Sub_Region__c,
				Territory2.Associated_Primary_PFS_Territory_Id__c,
				Territory2.Associated_Primary_PFS_Territory_Name__c
			FROM UserTerritory2Association
			WHERE
				IsActive = TRUE
				AND RoleInTerritory2 = 'Sales'
				AND UserId IN :userIds
				AND Territory2.Territory2Model.State = 'Active'
				AND Territory2.Territory2Type.MasterLabel = 'Sales'
			ORDER BY UserId
		];

		for (UserTerritory2Association userTerritoryAssociation : userTerritoryAssociations) {
			if (priorUserId != userTerritoryAssociation.UserId) {
				if (priorUserId != null) {
					userIdToTerritory.put(priorUserId, territory);
				}
				territory = new Territory2(
					Id = userTerritoryAssociation.Territory2Id,
					Name = userTerritoryAssociation.Territory2.Name,
					DeveloperName = userTerritoryAssociation.Territory2.DeveloperName,
					Geo__c = userTerritoryAssociation.Territory2.Geo__c,
					Region__c = userTerritoryAssociation.Territory2.Region__c,
					Sub_Region__c = userTerritoryAssociation.Territory2.Sub_Region__c,
					Associated_Primary_PFS_Territory_Id__c = userTerritoryAssociation.Territory2.Associated_Primary_PFS_Territory_Id__c,
					Associated_Primary_PFS_Territory_Name__c = userTerritoryAssociation.Territory2.Associated_Primary_PFS_Territory_Name__c
				);
				priorUserId = userTerritoryAssociation.UserId;
			}
		}
		if (priorUserId != null) {
			userIdToTerritory.put(priorUserId, territory);
		}

		return userIdToTerritory;
	}

	public static void insertTerritoryAssociation(List<Account> accounts) {
		List<ObjectTerritory2Association> accountTerritoryAssociations = new List<ObjectTerritory2Association>();

		for (Account account : accounts) {
			if (account.Primary_Sales_Territory_Id__c != null) {
				accountTerritoryAssociations.add(
					new ObjectTerritory2Association(
						AssociationCause = 'Territory2Manual',
						ObjectId = account.Id,
						Territory2Id = account.Primary_Sales_Territory_Id__c
					)
				);
			}
		}

		try {
			Database.SaveResult[] insertResults = Database.insert(accountTerritoryAssociations, true);
		} catch (Exception e) {
			Logger.error(
					'AccountTriggerUtility.insertTerritoryAssociation ERRORS',
					accountTerritoryAssociations,
					e
				)
				.setRecordId(accounts[0].Id)
				.addTag('apex');
			Logger.saveLog();
		}
	}

	public static void setSDR(List<Account> accounts, Map<Id, Account> oldMap) {
		List<Account> accountsToUpdateSDR = new List<Account>();
		Map<Id, Id> accountIdToSalesTerritoryId = new Map<Id, Id>();
		Map<Id, Id> territoryIdToSDRUserId = new Map<Id, Id>();

		for (Account account : accounts) {
			if (
				account.Type == CUSTOMER_TYPE &&
				(oldMap == null ||
				(oldMap?.get(account.Id).Type == FORMER_CUSTOMER_TYPE ||
				oldMap?.get(account.Id).Type == PROSPECT_TYPE))
			) {
				account.BDR__c = Constants.TANIUM_DSA_USER_ID;
				account.SDR_Manager__c = Constants.TANIUM_DSA_USER_ID;
				continue;
			}
			if (isAccountEligibleForSDR(account, oldMap?.get(account.Id))) {
				accountsToUpdateSDR.add(account);
				accountIdToSalesTerritoryId.put(account.Id, account.Primary_Sales_Territory_Id__c);
			}
		}

		for (UserTerritory2Association userTerritoryAssociation : [
			SELECT Id, UserId, Territory2Id, IsActive
			FROM UserTerritory2Association
			WHERE
				Territory2Id IN :accountIdToSalesTerritoryId.values()
				AND IsActive = TRUE
				AND RoleInTerritory2 = 'SDR'
			ORDER BY LastModifiedDate ASC
		]) {
			territoryIdToSDRUserId.put(
				userTerritoryAssociation.Territory2Id,
				userTerritoryAssociation.UserId
			);
		}

		Map<Id, Id> userIdToUserManagerId = Utility.getUserIdToUserManagerId(
			territoryIdToSDRUserId.values()
		);

		Id sdrUserId;
		for (Account account : accountsToUpdateSDR) {
			if (!territoryIdToSDRUserId.containsKey(account.Primary_Sales_Territory_Id__c)) {
				account.BDR__c = Constants.TANIUM_DSA_USER_ID;
				account.SDR_Manager__c = Constants.TANIUM_DSA_USER_ID;
			} else {
				sdrUserId = territoryIdToSDRUserId.get(account.Primary_Sales_Territory_Id__c);
				account.BDR__c = sdrUserId;
				account.SDR_Manager__c = userIdToUserManagerId.get(sdrUserId);
			}
		}
	}

	public static void setOwnerFromSalesTerritory(List<Account> accounts, Map<Id, Account> oldMap) {
		Map<Id, Account> territoryIdToAccount = new Map<Id, Account>();
		for (Account account : accounts) {
			if (
				account.Primary_Sales_Territory_Id__c != null &&
				(oldMap == null ||
				(account.Primary_Sales_Territory_Id__c !=
				oldMap.get(account.Id)?.Primary_Sales_Territory_Id__c))
			) {
				territoryIdToAccount.put(account.Primary_Sales_Territory_Id__c, account);
			}
		}

		Map<Id, Id> territoryIdToUserId = new Map<Id, Id>();
		for (UserTerritory2Association userTerritoryAssociation : [
			SELECT Id, UserId, Territory2Id
			FROM UserTerritory2Association
			WHERE
				Territory2Id IN :territoryIdToAccount.keySet()
				AND IsActive = TRUE
				AND RoleInTerritory2 = 'Sales'
		]) {
			territoryIdToUserId.put(
				userTerritoryAssociation.Territory2Id,
				userTerritoryAssociation.UserId
			);
		}

		for (Account account : territoryIdToAccount.values()) {
			if (
				territoryIdToUserId.get(account.Primary_Sales_Territory_Id__c) != null &&
				account.OwnerId != territoryIdToUserId.get(account.Primary_Sales_Territory_Id__c)
			) {
				account.OwnerId = territoryIdToUserId.get(account.Primary_Sales_Territory_Id__c);
			}
		}
	}

	private static Boolean isAccountEligibleForSDR(Account account, Account oldAccount) {
		List<String> validAccountTypes = new List<String>{ PROSPECT_TYPE, FORMER_CUSTOMER_TYPE };
		return validAccountTypes.contains(account.Type) &&
			account.Primary_Sales_Territory_Id__c != null &&
			((oldAccount == null) ||
			(oldAccount != null &&
			account.Primary_Sales_Territory_Id__c != oldAccount.Primary_Sales_Territory_Id__c));
	}
}