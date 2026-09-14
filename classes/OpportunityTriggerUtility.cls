/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Part of Trigger Framework for the Opportunity object
 * @Date: 2014-08
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7754    2024-03-21    Updated method buildPOCRequest (default values for HFPOC POC requests)
 * SS-7749    05-14-2024    Remove Route to RVP or AVP
 * SS-7595    05-17-2024    Primary Quote Partner and Downstream partner validations
 * SS-8013    2024-08-01    Add Nebula logger on existing DMLs
 * SS-8740    2024-08-14    Exclude Opps with MSP Business Motion in Contract Owner and Parent Contract Update
 * SS-8994    2024-10-03    Updated/Added methods assignContractOwners, getLevel2AssignmentManagementsMap plus class cleanup
 * SS-9056    2024-10-10    Add null checker
 * SS-9872    2024-12-17    Use Geo, Region and Sub Region instead of Level 2, 3, and 4
 * SS-10261   2025-04-15    Add method to update End User Acct territory on MSP Opportunities
 * SS-11171   2025-06-20    Moved method getMultiSelectSet to this class (made it local)
 * SS-10464   2025-06-26    Updated method assignContractOwners
 * SS-12459   2026-01-22    Removed Lead Source fields then added back after field type change
 * SS-12400   2026-01-22    Removed Primary_Contact__c field from class
 * SS-10186   2026-02-27    Removed reference to Level fields in User object
 * SS-12843   2026-03-18    Updated method updatePrimarySalesTerritoryId to handle territory assignment logic
 * SS-12971   2026-04-07    Sync Original_Territory2_ID__c until Opportunity is closed
 * SS-13500   2026-07-14    Remove deprecated fields for project kondo group 2 contact
 * SS-13712   2026-07-30    Removed HFPOC logic
 * SS-13636   2026-09-11    Updated processOppPartners for new stage numbering
 */
public class OpportunityTriggerUtility {
	private static String US_AND_CANADA = 'US and Canada';
	private static String US_UK_MM_AND_COMMERCIAL = 'US-UK MM and Commercial';
	private static Set<String> ASSIGN_CONTRACT_OWNER_LEVEL2_VALUES = new Set<String>{
		US_AND_CANADA,
		US_UK_MM_AND_COMMERCIAL
	};
	private static List<Integer> STAGE_NUMBERS_TO_EXCLUDE;
	private static String ASSIGN_CONTRACT_OWNER_RECTYPE_NAME = 'Oppty_Contract_Partner_Owner_Management';

	public static void filterRecordsForMarketingAndPartnerSync(
		List<Opportunity> opps,
		Map<Id, Opportunity> oldMap
	) {
		Set<Id> closedWonOppIds = new Set<Id>();

		for (Opportunity opp : opps) {
			if (oldMap == null) {
				continue;
			}
			if (
				opp.StageName != oldMap.get(opp.Id).StageName &&
				opp.StageName == 'CLOSED WON' &&
				opp.SBQQ__PrimaryQuote__c != null
			) {
				closedWonOppIds.add(opp.Id);
			}
		}
		if (Utility.isFutureMethodAllowed()) {
			if (!closedWonOppIds.isEmpty()) {
				syncSupportPartners(closedWonOppIds);
			}
		}
	}

	public static void handleBusinessMotionChange(
		List<Opportunity> opps,
		Map<Id, Opportunity> oldMap
	) {
		List<Opportunity> eligibleOpps = new List<Opportunity>();

		for (Opportunity opp : opps) {
			if (opp.Business_Motion__c != oldMap.get(opp.Id).Business_Motion__c) {
				eligibleOpps.add(opp);
			}
		}
		if (!eligibleOpps.isEmpty()) {
			handleBusinessMotionChange(eligibleOpps);
		}
	}

	public static void handleBusinessMotionChange(List<Opportunity> opps) {
		Set<Id> ownerIds = new Set<Id>();
		Set<Id> accountIds = new Set<Id>();
		User oppOwner;
		Account account;
		for (Opportunity opp : opps) {
			ownerIds.add(opp.OwnerId);
			accountIds.add(opp.AccountId);
		}

		Map<Id, User> userMap = getUserDetails(ownerIds);
		Map<Id, Account> accountMap = getAccountDetails(accountIds);
		Map<String, Assignment_Management__c[]> geoAssignmentManagementsMap = getGeoAssignmentManagementsMap(
			ASSIGN_CONTRACT_OWNER_RECTYPE_NAME
		);

		for (Opportunity opp : opps) {
			if (opp.Business_Motion__c == 'MSP') {
				opp.Contract_Owner__c = null;
				opp.Contract_Partner_Owner__c = null;
			} else {
				oppOwner = userMap.get(opp.OwnerId);
				account = accountMap.get(opp.AccountId);
				assignContractOwners(
					opp,
					oppOwner,
					geoAssignmentManagementsMap.get(account.Geo__c),
					account
				);
			}
		}
	}

	public static void handleOwnerChange(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
		List<Opportunity> eligibleOpps = new List<Opportunity>();

		for (Opportunity opp : opps) {
			if (opp.OwnerId != oldMap.get(opp.Id).OwnerId) {
				eligibleOpps.add(opp);
			}
		}
		if (!eligibleOpps.isEmpty()) {
			handleOwnerChange(eligibleOpps);
		}
	}

	public static void handleOwnerChange(List<Opportunity> opps) {
		Set<Id> oppOwnerIds = new Set<Id>();
		Set<Id> accountIds = new Set<Id>();
		User oppOwner;
		Account account;

		for (Opportunity opp : opps) {
			oppOwnerIds.add(opp.OwnerId);
			accountIds.add(opp.AccountId);
		}

		Map<Id, User> userMap = getUserDetails(oppOwnerIds);
		Map<Id, Account> accountMap = getAccountDetails(accountIds);
		Map<String, Assignment_Management__c[]> geoAssignmentManagementsMap = getGeoAssignmentManagementsMap(
			ASSIGN_CONTRACT_OWNER_RECTYPE_NAME
		);

		for (Opportunity opp : opps) {
			oppOwner = userMap.get(opp.OwnerId);
			opp.Opportunity_Manager__c = oppOwner?.ManagerId;
			account = accountMap.get(opp.AccountId);
			assignContractOwners(
				opp,
				oppOwner,
				geoAssignmentManagementsMap.get(account.Geo__c),
				account
			);
		}
	}

	@TestVisible
	private static void assignContractOwners(
		Opportunity opp,
		User oppOwner,
		Assignment_Management__c[] assignMgmtRecords,
		Account account
	) {
		String routingType;
		Id routingToUserId;
		String rvpName;
		Boolean geoMatch;
		Boolean regionMatch;
		Boolean subRegionMatch;
		Assignment_Management__c matchingAssignMgmtRecord = null;

		if (assignMgmtRecords == null) {
			return;
		}
		opp.Contract_Owner__c = null;
		opp.Contract_Partner_Owner__c = null;

		if (opp.Business_Motion__c == 'MSP') {
			return;
		}

		for (Assignment_Management__c assignMgmtRecord : assignMgmtRecords) {
			geoMatch = ((assignMgmtRecord.Geo__c == null) ||
			(assignMgmtRecord.Geo__c != null &&
			assignMgmtRecord.Geo__c == account.Geo__c));

			regionMatch = ((assignMgmtRecord.Region__c == null) ||
			(assignMgmtRecord.Region__c != null &&
			assignMgmtRecord.Region__c == account.Region__c));

			subRegionMatch = ((assignMgmtRecord.Sub_Region__c == null) ||
			(assignMgmtRecord.Sub_Region__c != null &&
			assignMgmtRecord.Sub_Region__c == account.Sub_Region__c));

			routingType = assignMgmtRecord.Route_Based_on_RVP_or_AVP__c;
			routingToUserId = assignMgmtRecord.Persona_Selection__c;
			rvpName = assignMgmtRecord.Persona_Selection__r?.Full_Name__c;

			if ((!geoMatch) || (!regionMatch) || (!subRegionMatch)) {
				continue;
			}
			if (ASSIGN_CONTRACT_OWNER_LEVEL2_VALUES.contains(account.Geo__c)) {
				if (routingType == null || routingToUserId == null) {
					if (
						account.Region__c == assignMgmtRecord.Region__c &&
						account.Geo__c == 'US and Canada'
					) {
						matchingAssignMgmtRecord = assignMgmtRecord;
					} else {
						continue;
					}
				}
				if (routingType == 'RVP' && rvpName == oppOwner.RVP__c) {
					matchingAssignMgmtRecord = assignMgmtRecord;
				}
				if (routingType == 'AVP' && (routingToUserId == oppOwner.Area_VP__c)) {
					matchingAssignMgmtRecord = assignMgmtRecord;
				}
				if (routingType == 'Opportunity Owner' && routingToUserId == oppOwner.Id) {
					matchingAssignMgmtRecord = assignMgmtRecord;
				}
				if (routingType == 'Opportunity Manager' && routingToUserId == oppOwner.ManagerId) {
					matchingAssignMgmtRecord = assignMgmtRecord;
				}
			} else {
				matchingAssignMgmtRecord = assignMgmtRecord;
			}
			opp.Contract_Owner__c = matchingAssignMgmtRecord?.Contract_Owner_Name__c;
			opp.Contract_Partner_Owner__c = matchingAssignMgmtRecord?.Partner_Owner_Name__c;
		}
	}

	public static Map<String, Assignment_Management__c[]> getGeoAssignmentManagementsMap(
		String recTypeName
	) {
		Id recTypeId = Utility.getRecordTypeIdByAPIName('Assignment_Management__c', recTypeName);
		Map<String, Assignment_Management__c[]> geoAssignmentManagementsMap = new Map<String, Assignment_Management__c[]>();
		String tmpGeo = null;
		Assignment_Management__c[] assignmentManagementRecords = new List<Assignment_Management__c>();

		Assignment_Management__c[] assignMgmtRecords = [
			SELECT
				Id,
				Route_Based_on_RVP_or_AVP__c,
				Persona_Selection__c,
				Persona_Selection__r.Full_Name__c,
				Geo__c,
				Region__c,
				Sub_Region__c,
				Contract_Owner_Name__c,
				Partner_Owner_Name__c
			FROM Assignment_Management__c
			WHERE RecordTypeId = :recTypeId
			ORDER BY Geo__c
		];

		for (Assignment_Management__c assignMgmtRecord : assignMgmtRecords) {
			if (assignMgmtRecord.Geo__c == tmpGeo) {
				assignmentManagementRecords.add(assignMgmtRecord);
				tmpGeo = assignMgmtRecord.Geo__c;
			}
			if ((assignMgmtRecord.Geo__c != tmpGeo) || tmpGeo == null) {
				if (tmpGeo != null) {
					geoAssignmentManagementsMap.put(tmpGeo, assignmentManagementRecords);
				}
				assignmentManagementRecords = new List<Assignment_Management__c>();
				assignmentManagementRecords.add(assignMgmtRecord);
				tmpGeo = assignMgmtRecord.Geo__c;
			}
		}
		if (tmpGeo != null) {
			geoAssignmentManagementsMap.put(tmpGeo, assignmentManagementRecords);
		}
		return geoAssignmentManagementsMap;
	}

	@future
	public static void syncSupportPartners(Set<Id> closedWonSet) {
		Map<Id, Opportunity> mapOpp = new Map<Id, Opportunity>(
			[
				SELECT
					Id,
					AccountId,
					(
						SELECT Id, Partner_Role__c, Account_Supported__c, Support_Partner__c
						FROM Opportunity_Support_Partners__r
					),
					(
						SELECT
							Id,
							Deployment_Partner__c,
							L1_L2_Support_Partner__c,
							Deployment_Partner__r.Partner_Accreditations__c,
							Deployment_Partner__r.Business_Motion__c,
							SBQQ__Partner__r.Partner_Accreditations__c,
							SBQQ__Partner__r.Business_Motion__c
						FROM SBQQ__Quotes2__r
						WHERE SBQQ__Primary__c = TRUE
					)
				FROM Opportunity
				WHERE Id IN :closedWonSet
			]
		);
		SupportPartnerWrapper wrapper = new SupportPartnerWrapper(mapOpp);
	}

	@Testvisible
	public static void defaultRelatedAccountOwnerToOppOwner(List<Opportunity> opps) {
		Set<Id> accountIds = new Set<Id>();
		Set<Id> ownerIds = new Set<Id>();
		Account account;
		User oppOwner;

		for (Opportunity opp : opps) {
			if (opp.AccountId != null) {
				accountIds.add(opp.AccountId);
			}
			if (opp.OwnerId != null) {
				ownerIds.add(opp.OwnerId);
			}
		}

		Map<Id, Account> accountMap = new Map<Id, Account>(
			[SELECT Id, OwnerId, TAM_Sales_SME__c, BDR__c, CSM__c FROM Account WHERE Id IN :accountIds]
		);
		for (Account acc : accountMap.values()) {
			ownerIds.add(acc.OwnerId);
		}

		Map<Id, User> userMap = getUserDetails(ownerIds);

		for (Opportunity opp : opps) {
			account = accountMap.get(opp.AccountId);
			oppOwner = userMap.get(opp.OwnerId);
			if (
				(userMap.get(opp.OwnerId) == null ||
				(oppOwner.UserRoleId != null && !oppOwner.UserRole.Name.contains('ITSM')))
			) {
				opp.OwnerId = account?.OwnerId;
			}

			opp.TAM_Sales_SME_Owner__c = account?.TAM_Sales_SME__c;
			opp.CSM_Account_Owner__c = account?.CSM__c;

			if (userMap.get(opp.OwnerId) != null && userMap.get(opp.OwnerId).ManagerId != null) {
				opp.Opportunity_Manager__c = userMap.get(opp.OwnerId).ManagerId;
			} else {
				opp.Opportunity_Manager__c = null;
			}
		}
	}

	private static Support_Partner__c buildSupportPartner(
		Id opportunityId,
		String partnerRole,
		Id supportPartnerId,
		Id accountSupportedId,
		Boolean businessMotionSupport,
		String partnerAccreditations
	) {
		return new Support_Partner__c(
			Opportunity__c = opportunityId,
			Partner_Role__c = partnerRole,
			Support_Partner__c = supportPartnerId,
			Account_Supported__c = accountSupportedId,
			Partner_Accreditation__c = partnerAccreditations,
			Partner_Business_Motion_Contains_Support__c = businessMotionSupport
		);
	}

	private static void addSupportPartners(SupportPartnerRecordTracker tracker) {
		if (tracker.primaryQuote.Deployment_Partner__c != null) {
			tracker.newPartners.add(
				buildSupportPartner(
					tracker.opportunityToTrack.Id,
					'Deployment',
					tracker.primaryQuote.Deployment_Partner__c,
					tracker.opportunityToTrack.AccountId,
					tracker.partnerContainsBMSupport,
					tracker.primaryQuote.SBQQ__Partner__r.Partner_Accreditations__c
				)
			);
		}
		if (tracker.primaryQuote.L1_L2_Support_Partner__c != null) {
			tracker.newPartners.add(
				buildSupportPartner(
					tracker.opportunityToTrack.Id,
					'Support',
					tracker.primaryQuote.L1_L2_Support_Partner__c,
					tracker.opportunityToTrack.AccountId,
					tracker.partnerContainsBMSupport,
					tracker.primaryQuote.SBQQ__Partner__r.Partner_Accreditations__c
				)
			);
		}
	}

	private static void checkForExisting_IdentifyNewSupportPartners(
		SupportPartnerRecordTracker tracker
	) {
		List<Support_Partner__c> existingPartners = tracker.opportunityToTrack.Opportunity_Support_Partners__r;
		if (!existingPartners.isEmpty()) {
			tracker.deletePartners.addAll(existingPartners);
			addSupportPartners(tracker);
		} else {
			addSupportPartners(tracker);
		}
	}

	public static void processOppPartners(
		Map<Id, Opportunity> oppsMap,
		Map<Id, Opportunity> oldMap
	) {
		List<Opportunity> oppsWithPartnerError = new List<Opportunity>();
		List<Opportunity> oppsWithDownstreamPartnerError = new List<Opportunity>();
		Map<Id, List<Opportunity_Partners__c>> oppsWithOppPartners = new Map<Id, List<Opportunity_Partners__c>>();
		for (Opportunity_Partners__c oppPartner : [
			SELECT Id, Name, Account__c, Opportunity__c
			FROM Opportunity_Partners__c
			WHERE Opportunity__c IN :oppsMap.values()
		]) {
			if (oppsWithOppPartners.keySet().contains(oppPartner.Opportunity__c)) {
				List<Opportunity_Partners__c> oppPartners = oppsWithOppPartners.get(
					oppPartner.Opportunity__c
				);
				if (oppPartners == null || !oppPartners.contains(oppPartner)) {
					oppPartners.add(oppPartner);
				}
			} else {
				oppsWithOppPartners.put(
					oppPartner.Opportunity__c,
					new List<Opportunity_Partners__c>{ oppPartner }
				);
			}
		}
		for (Opportunity opp : oppsMap.values()) {
			Opportunity oldOpp = oldMap.get(opp.Id);
			if (
				oldOpp != null &&
				oldOpp.StageName != opp.StageName &&
				opp.StageNumber__c != null &&
				oldOpp.StageNumber__c <= 130 &&
				opp.StageNumber__c >= 60 &&
				getStageNumbersToExclude() != null &&
				!getStageNumbersToExclude().contains(Integer.valueOf(opp.StageNumber__c))
			) {
				if (!doesOppPartnerExistsForPartnerFieldOnPrimaryQuote(opp, oppsWithOppPartners)) {
					oppsWithPartnerError.add(opp);
				}
				if (
					!doesOppPartnerExistsForDownStreamPartnerFieldOnPrimaryQuote(
						opp,
						oppsWithOppPartners
					)
				) {
					oppsWithDownstreamPartnerError.add(opp);
				}
			}
		}

		if (!FeatureManagement.checkPermission('DisableValidationRules')) {
			if (!oppsWithPartnerError.isEmpty()) {
				for (Opportunity oppWithPartnerError : oppsWithPartnerError) {
					oppWithPartnerError.StageName.addError(
						System.Label.Partner_error_on_Primary_Quote_And_Opp_Partners
					);
				}
			}
			if (!oppsWithDownstreamPartnerError.isEmpty()) {
				for (Opportunity oppWithDownstreamPartnerError : oppsWithDownstreamPartnerError) {
					oppWithDownstreamPartnerError.StageName.addError(
						System.Label.Downstream_Partner_error_on_Primary_Quote_And_Opp_Partners
					);
				}
			}
		}
	}

	@TestVisible
	private static Boolean doesOppPartnerExistsForPartnerFieldOnPrimaryQuote(
		Opportunity opp,
		Map<Id, List<Opportunity_Partners__c>> oppsWithOppPartners
	) {
		List<Opportunity_Partners__c> oppPartners = oppsWithOppPartners.get(opp.Id);
		if (opp.PrimaryQuotePartner__c == null) {
			return true;
		}
		if (oppPartners != null && !oppPartners.isEmpty()) {
			for (Opportunity_Partners__c oppPartner : oppPartners) {
				if (oppPartner.Account__c == opp.PrimaryQuotePartner__c) {
					return true;
				}
			}
		}
		return false;
	}

	@TestVisible
	private static Boolean doesOppPartnerExistsForDownStreamPartnerFieldOnPrimaryQuote(
		Opportunity opp,
		Map<Id, List<Opportunity_Partners__c>> oppsWithOppPartners
	) {
		List<Opportunity_Partners__c> oppPartners = oppsWithOppPartners.get(opp.Id);
		if (opp.PrimaryQuoteDownstreamPartner__c == null) {
			return true;
		}
		if (oppPartners != null && !oppPartners.isEmpty()) {
			for (Opportunity_Partners__c oppPartner : oppPartners) {
				if (oppPartner.Account__c == opp.PrimaryQuoteDownstreamPartner__c) {
					return true;
				}
			}
		}
		return false;
	}

	@TestVisible
	private static List<Integer> getStageNumbersToExclude() {
		if (OpportunityTriggerUtility.Stage_Numbers_To_Exclude == null) {
			OpportunityTriggerUtility.Stage_Numbers_To_Exclude = new List<Integer>();
			if (
				System.Label.Stage_Numbers_to_Exclude_for_partner_validation != null &&
				!String.isBlank(System.Label.Stage_Numbers_to_Exclude_for_partner_validation)
			) {
				for (
					String eachElement : System.Label.Stage_Numbers_to_Exclude_for_partner_validation.split(
						','
					)
				) {
					OpportunityTriggerUtility.Stage_Numbers_To_Exclude.add(
						Integer.valueOf(eachElement.trim())
					);
				}
			}
		}
		return OpportunityTriggerUtility.Stage_Numbers_To_Exclude;
	}

	public static Map<Id, User> getUserDetails(Set<Id> userIds) {
		Map<Id, User> userMap = new Map<Id, User>(
			[
				SELECT Id, ManagerId, Area_VP__c, RVP__c, UserRoleId, UserRole.Name
				FROM User
				WHERE Id IN :userIds
			]
		);
		return userMap;
	}

	public static Map<Id, Account> getAccountDetails(Set<Id> accountIds) {
		Map<Id, Account> accountMap = new Map<Id, Account>(
			[SELECT Id, Geo__c, Region__c, Sub_Region__c FROM Account WHERE Id IN :accountIds]
		);
		return accountMap;
	}

	public class SupportPartnerRecordTracker {
		public Opportunity opportunityToTrack;
		public SBQQ__Quote__c primaryQuote;
		public Boolean partnerContainsBMSupport = false;
		public List<Support_Partner__c> newPartners;
		public List<Support_Partner__c> deletePartners;

		public SupportPartnerRecordTracker(Opportunity oppToTrack) {
			this.newPartners = new List<Support_Partner__c>();
			this.deletePartners = new List<Support_Partner__c>();
			this.opportunityToTrack = oppToTrack;
			this.primaryQuote = this.opportunityToTrack.SBQQ__Quotes2__r;

			if (this.primaryQuote != null) {
				Set<String> busMotionSet = new Set<String>();
				if (primaryQuote.Deployment_Partner__r.Business_Motion__c != null) {
					busMotionSet = getMultiSelectSet(primaryQuote.SBQQ__Partner__r.Business_Motion__c);
					for (String bm : busMotionSet) {
						if (bm != null && bm.contains('Support')) {
							this.partnerContainsBMSupport = true;
						}
					}
				}
				checkForExisting_IdentifyNewSupportPartners(this);
			}
		}
	}

	@TestVisible
	private static Set<String> getMultiSelectSet(String multiSelectField) {
		Set<String> resultSet = new Set<String>();
		if (multiSelectField != null) {
			if (multiSelectField.contains(';')) {
				resultSet.addAll(multiSelectField.split(';'));
			} else {
				resultSet.add(multiSelectField);
			}
		}
		return resultSet;
	}

	public static void processPrimaryQuote(
		Map<Id, Opportunity> oppsMap,
		Map<Id, Opportunity> oldMap
	) {
		Opportunity oldOpp;
		for (Opportunity opp : oppsMap.values()) {
			oldOpp = oldMap.get(opp.Id);
			if (oldOpp.SBQQ__PrimaryQuote__c != opp.SBQQ__PrimaryQuote__c) {
				if (opp.SBQQ__PrimaryQuote__c == null) {
					opp.Primary_Quote__c = false;
				} else {
					opp.Primary_Quote__c = true;
				}
			}
		}
	}

	public class SupportPartnerWrapper {
		List<SupportPartnerRecordTracker> recordTrackers = new List<SupportPartnerRecordTracker>();
		List<Support_Partner__c> supportPartnersToDelete = new List<Support_Partner__c>();
		List<Support_Partner__c> supportPartnersToUpsert = new List<Support_Partner__c>();

		public SupportPartnerWrapper(Map<Id, Opportunity> opportunityMap) {
			for (Opportunity opp : opportunityMap.values()) {
				recordTrackers.add(new SupportPartnerRecordTracker(opp));
			}

			for (SupportPartnerRecordTracker tracker : recordTrackers) {
				if (!tracker.newPartners.isEmpty()) {
					supportPartnersToUpsert.addAll(tracker.newPartners);
				}
				if (!tracker.deletePartners.isEmpty()) {
					supportPartnersToDelete.addAll(tracker.deletePartners);
				}
			}
			try {
				delete supportPartnersToDelete;
			} catch (Exception ex) {
				Logger.error('OpportunityTriggerUtility.SupportPartnerWrapper ERRORS', ex);
				Logger.saveLog();
			}

			Map<Id, String> opportunityPartnerRoleMap = new Map<Id, String>();
			for (Support_Partner__c existingPartner : [
				SELECT Partner_Role__c, Opportunity__c
				FROM Support_Partner__c
				WHERE Opportunity__c IN :opportunityMap.keySet()
			]) {
				opportunityPartnerRoleMap.put(
					existingPartner.Opportunity__c,
					existingPartner.Partner_Role__c
				);
			}
			for (Integer index = supportPartnersToUpsert.size() - 1; index >= 0; index--) {
				String existingPartnerRole = opportunityPartnerRoleMap.get(
					supportPartnersToUpsert[index].Opportunity__c
				);
				if (existingPartnerRole == supportPartnersToUpsert[index].Partner_Role__c) {
					supportPartnersToUpsert.remove(index);
				}
			}
			try {
				upsert supportPartnersToUpsert;
			} catch (Exception ex) {
				Logger.error('OpportunityTriggerUtility.SupportPartnerWrapper ERRORS', ex);
				Logger.saveLog();
			}
		}
	}

	public static void updatePrimarySalesTerritoryId(
		List<Opportunity> opps,
		Map<Id, Opportunity> oldMap
	) {
		Set<Id> accountIds = new Set<Id>();
		Map<Id, Account> accountIdToAccount = new Map<Id, Account>();

		for (Opportunity opp : opps) {
			if (opp.AccountId != null) {
				accountIds.add(opp.AccountId);
			}
			if (opp.End_User_Account__c != null) {
				accountIds.add(opp.End_User_Account__c);
			}
		}

		accountIdToAccount = getAccountIdToAccount(accountIds);

		for (Opportunity opp : opps) {
			if (opp.End_User_Account__c != null && opp.Type != 'Split') {
				opp.Territory2Id = accountIdToAccount.get(opp.End_User_Account__c)
					?.Primary_Sales_Territory_Id__c;
			} else if (opp.Type != 'Split') {
				opp.Territory2Id = accountIdToAccount.get(opp.AccountId)?.Primary_Sales_Territory_Id__c;
			}
		}
	}

	public static void syncOriginalTerritory2Id(
		List<Opportunity> opps,
		Map<Id, Opportunity> oldMap
	) {
		Boolean territoryChanged;
		Boolean opportunityClosingNow;
		for (Opportunity opp : opps) {
			territoryChanged = oldMap == null || oldMap.get(opp.Id).Territory2Id != opp.Territory2Id;
			opportunityClosingNow =
				oldMap != null &&
				!isOpportunityInClosedStage(oldMap?.get(opp.Id)) &&
				isOpportunityInClosedStage(opp);

			if (
				(!isOpportunityInClosedStage(opp) &&
				(territoryChanged ||
				opp.Original_Territory2_ID__c != String.valueOf(opp?.Territory2Id))) ||
				opportunityClosingNow
			) {
				opp.Original_Territory2_ID__c = String.valueOf(opp?.Territory2Id);
			}
		}
	}

	private static Boolean isOpportunityInClosedStage(Opportunity opp) {
		return opp != null &&
			!String.isBlank(opp.StageName) &&
			(opp.StageName.equals(Utility.CLOSED_WON) || opp.StageName.equals(Utility.FAILED));
	}

	private static Map<Id, Account> getAccountIdToAccount(Set<Id> accountIds) {
		return new Map<Id, Account>(
			[SELECT Id, Primary_Sales_Territory_Id__c FROM Account WHERE Id IN :accountIds]
		);
	}
}