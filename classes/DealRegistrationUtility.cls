/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class for handling Deal Registration.
 * @Date: 2024-09-13
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-8999    2024-09-12    Initial development - Opp Reg to Deal Reg Migration
 * SS-9432    2025-02-22    Prevent Deal Approval and Duplicates
 * SS-11723   2025-09-23    Populate PFS fields on Deal Registration from related Account
 * SS-11635   2025-09-25    Added methods assignEndCustomerAccount, extractDomainFromUrl
 * SS-12040   2025-11-17    Updated method assignEndCustomerAccount, renamed method to extractDomainFromEmail
 * SS-12400   2026-01-22    Removed Primary_Contact__c field from class
 * SS-13104   2026-02-10    Updated method handleApprovedDealReg
 * SS-13176   2026-05-27    Removed deprecated Level field references
 */
public with sharing class DealRegistrationUtility {
	public static Set<String> profilesAllowedToDeleteDealReg = new Set<String>{
		'Tanium System Administrator',
		'System Administrator'
	};

	private static Integration_User__c integrationUser = Integration_User__c.getInstance();
	private static Automation_Management__c automationManagement = Automation_Management__c.getInstance();
	private static final List<String> OPP_REG_STATUS_BYPASS = new List<String>{
		'Cancelled',
		'Expired',
		'Rejected'
	};
	@TestVisible
	private static final String PARTNER_CREATOR = 'Partner Creator';
	@TestVisible
	private static final String PUBLIC_SECTOR_SEGMENT = 'Public Sector';
	@TestVisible
	private static final String STATUS_EXTENSION_PENDING = 'Extension Pending';
	@TestVisible
	private static final String SUPPLY_CHAIN_PROCUREMENT = 'Supply chain/Procurement';

	public static void populateSPIFFEmail(List<Deal_Registration__c> deals) {
		for (Deal_Registration__c deal : deals) {
			if (deal.Partner_Sales_Account_Manager_Email__c != null) {
				deal.SPIFF_Recipient_Email__c = deal.Partner_Sales_Account_Manager_Email__c;
			} else if (deal.Partner_Contact_Email__c != null) {
				deal.SPIFF_Recipient_Email__c = deal.Partner_Contact_Email__c;
			}
		}
	}

	public static void processUpdateDealRegOwnerAndEmailFields(
		List<Deal_Registration__c> deals,
		Map<Id, Account> accountMap,
		Map<Id, User> ownerMap,
		Map<Id, Deal_Registration__c> oldMap
	) {
		for (Deal_Registration__c deal : deals) {
			if (
				oldMap != null &&
				integrationUser.RingLead__c != null &&
				System.UserInfo.getUserId().left(15) == integrationUser.RingLead__c.left(15)
			) {
				deal.addError('Cannot edit a Deal Registration');
			} else if (
				deal.Account__c == null &&
				(oldMap == null ||
				(oldMap != null &&
				deal.Account__c != oldMap.get(deal.Id).Account__c)) &&
				deal.Partner_Geo_Region__c == 'LatAm'
			) {
				deal.OwnerId = automationManagement?.Default_Opp_Reg_Owner_LATAM__c;
				deal.Opp_Reg_Owner_is_AVP_RVP__c = (oldMap == null && isAVPRVP(deal, ownerMap));
			} else if (
				deal.Account__c != null &&
				(oldMap == null ||
				(oldMap != null &&
				deal.Account__c != oldMap.get(deal.Id).Account__c))
			) {
				deal.OwnerId = accountMap.get(deal.Account__c).OwnerId;
				deal.Opp_Reg_Owner__c = accountMap.get(deal.Account__c).OwnerId;
				deal.or_Tanium_Contact__c = accountMap.get(deal.Account__c).OwnerId;
				deal.Lead_Owner_Manager_Email__c = accountMap.get(deal.Account__c).Owner.Manager.Email;
				deal.Lead_Owner_Manager__c = accountMap.get(deal.Account__c).Owner.ManagerId;
				deal.End_Customer_Account_Segment__c = accountMap.get(deal.Account__c).Segment__c;
			}
			if (
				oldMap != null &&
				deal.or_Rejection_Reason_OppReg__c != oldMap.get(deal.Id).or_Rejection_Reason_OppReg__c
			) {
				deal.Rejection_Reason_WI__c = deal.or_Rejection_Reason_OppReg__c;
			}
		}
	}

	public static boolean isAVPRVP(Deal_Registration__c deal, Map<Id, User> ownerMap) {
		if (
			ownerMap.containsKey(deal.OwnerId) && ownerMap.get(deal.OwnerId).Role_Category__c != null
		) {
			return (ownerMap.get(deal.OwnerId).Role_Category__c == 'AVP' ||
			ownerMap.get(deal.OwnerId).Role_Category__c == 'RVP' ||
			ownerMap.get(deal.OwnerId).Role_Category__c == 'VP');
		} else {
			return false;
		}
	}

	public static void updateCurrentApprover(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		for (Deal_Registration__c deal : deals) {
			if (
				(deal.or_Opp_Reg_Status__c == 'Pending' ||
				deal.or_Opp_Reg_Status__c == 'Extension Pending') &&
				(deal.or_Opp_Reg_Approval_Flow_Status__c == null ||
				deal.or_Opp_Reg_Approval_Flow_Status__c == 'Approvals not started') &&
				(oldMap == null ||
				deal.or_Opp_Reg_Status__c != oldMap.get(deal.Id).or_Opp_Reg_Status__c ||
				deal.Opp_Reg_Approval_Assignment__c !=
				oldMap.get(deal.Id).Opp_Reg_Approval_Assignment__c ||
				deal.or_Opp_Reg_Approval_Flow_Status__c !=
				oldMap.get(deal.Id).or_Opp_Reg_Approval_Flow_Status__c)
			) {
				if (
					deal.Opp_Reg_Approval_Assignment__c == 12 ||
					deal.Opp_Reg_Approval_Assignment__c == 11
				) {
					deal.Current_Approver__c = 'PDD';
				} else {
					deal.Current_Approver__c = 'DSA/TSM';
				}
			} else if (
				deal.or_Opp_Reg_Status__c != 'Pending' &&
				deal.or_Opp_Reg_Status__c != 'Extension Pending'
			) {
				deal.Current_Approver__c = null;
			}
		}
	}

	public static void updateFieldsOnDealRegStatusExtensionPending(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		for (Deal_Registration__c deal : deals) {
			if (
				deal.or_Opp_Reg_Status__c == 'Extension Pending' &&
				(oldMap == null ||
				deal.or_Opp_Reg_Status__c != oldMap.get(deal.Id).or_Opp_Reg_Status__c)
			) {
				deal.Date_Approved_Extension__c = null;
				deal.Opp_Reg_Ext_Request_Date_Time__c = System.now();
			}
		}
	}

	public static void updateDealRegNewBusDaysExtBusDaysFields(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		for (Deal_Registration__c deal : deals) {
			if (
				oldMap == null ||
				deal.OR_Created_Date__c != oldMap.get(deal.Id).OR_Created_Date__c ||
				deal.or_Date_Approved__c != oldMap.get(deal.Id).or_Date_Approved__c
			) {
				if (deal.OR_Created_Date__c != null) {
					Date startDate = deal.OR_Created_Date__c;
					Date endDate = deal.or_Date_Approved__c == null
						? System.today()
						: deal.or_Date_Approved__c;
					deal.Opp_Reg_NEW_Bus_Days_Clone__c = calculateBusinessDays(startDate, endDate);
				} else {
					deal.Opp_Reg_NEW_Bus_Days_Clone__c = null;
				}
			}
			if (
				oldMap == null ||
				deal.Opp_Reg_Ext_Request_Date_Time__c !=
				oldMap.get(deal.Id).Opp_Reg_Ext_Request_Date_Time__c ||
				deal.Date_Approved_Extension__c != oldMap.get(deal.Id).Date_Approved_Extension__c
			) {
				if (deal.Opp_Reg_Ext_Request_Date_Time__c != null) {
					Date startDate = Date.newInstance(
						deal.Opp_Reg_Ext_Request_Date_Time__c.year(),
						deal.Opp_Reg_Ext_Request_Date_Time__c.month(),
						deal.Opp_Reg_Ext_Request_Date_Time__c.day()
					);
					Date endDate = deal.Date_Approved_Extension__c == null
						? System.today()
						: deal.Date_Approved_Extension__c;
					deal.Opp_Reg_EXT_Bus_Days_Clone__c = calculateBusinessDays(startDate, endDate);
				} else {
					deal.Opp_Reg_EXT_Bus_Days_Clone__c = null;
				}
			}
		}
	}

	public static void populateDealRegType(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		Set<Id> oppIds = new Set<Id>();
		for (Deal_Registration__c deal : deals) {
			oppIds.add(deal.Mapped_Opportunity__c);
		}
		Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>(
			[SELECT Id, Probability FROM Opportunity WHERE Id IN :oppIds]
		);

		for (Deal_Registration__c deal : deals) {
			if (
				deal.or_Opportunity_Registration__c == null &&
				((deal.or_Create_Opportunity_upon_Approval__c !=
				oldMap.get(deal.Id).or_Create_Opportunity_upon_Approval__c &&
				deal.or_Create_Opportunity_upon_Approval__c) ||
				(deal.Mapped_Opportunity__c != oldMap.get(deal.Id).Mapped_Opportunity__c &&
				deal.Mapped_Opportunity__c != null))
			) {
				if (
					deal.or_Create_Opportunity_upon_Approval__c && deal.Opp_Reg_Extension_Count__c == 0
				) {
					deal.or_Opportunity_Registration__c = 'Partner Sourced';
				} else if (
					deal.Mapped_Opportunity__c != null && !deal.or_Create_Opportunity_upon_Approval__c
				) {
					if (oppsMap.get(deal.Mapped_Opportunity__c).Probability >= 20) {
						deal.or_Opportunity_Registration__c = 'Teaming';
					} else {
						deal.or_Opportunity_Registration__c = 'Partner Sourced';
					}
				}
			}
		}
	}

	public static void partnerCreatorDealRegsExist(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		List<Deal_Registration__c> partnerSourcedDealRegistrations = getEligibleDealRegistrationsByDealRegType(
			deals,
			'Partner Sourced'
		);
		Map<Id, Id> dealRegistrationIdsOppIdsMap = new Map<Id, Id>();
		Set<Id> oppIdsPartnerCreatorExists = new Set<Id>();
		DateTime lastMinute = System.now().addMinutes(-1);

		if (partnerSourcedDealRegistrations.isEmpty()) {
			return;
		}
		for (Deal_Registration__c partnerSourcedDealRegistration : partnerSourcedDealRegistrations) {
			if (
				partnerSourcedDealRegistration.or_Opp_Reg_Approval_Flow_Status__c ==
				'Approvals in progress' &&
				partnerSourcedDealRegistration.or_Opp_Reg_Approval_Flow_Status__c !=
				oldMap.get(partnerSourcedDealRegistration.Id).or_Opp_Reg_Approval_Flow_Status__c
			) {
				dealRegistrationIdsOppIdsMap.put(
					partnerSourcedDealRegistration.Id,
					partnerSourcedDealRegistration.Mapped_Opportunity__c
				);
			}
		}

		for (Opportunity_Partners__c oppPartner : [
			SELECT Id, Opportunity__c
			FROM Opportunity_Partners__c
			WHERE
				Opportunity__c IN :dealRegistrationIdsOppIdsMap.values()
				AND Partner_Role__c = :PARTNER_CREATOR
				AND Deal_Registration__r.or_Opp_Reg_Status__c != :STATUS_EXTENSION_PENDING
				AND CreatedDate < :lastMinute
			WITH SYSTEM_MODE
		]) {
			oppIdsPartnerCreatorExists.add(oppPartner.Opportunity__c);
		}

		if (!FeatureManagement.checkPermission('DisableValidationRules')) {
			for (
				Deal_Registration__c partnerSourcedDealRegistration : partnerSourcedDealRegistrations
			) {
				if (
					oppIdsPartnerCreatorExists.contains(
						dealRegistrationIdsOppIdsMap.get(partnerSourcedDealRegistration.Id)
					)
				) {
					partnerSourcedDealRegistration.addError(
						'There is already a ' +
							PARTNER_CREATOR +
							' listed on this Opportunity, so this Deal Reg cannot be approved. Please reach out to ChannelOps@tanium.com if you believe this is incorrect.'
					);
				}
			}
		}
	}

	public static void checkDeletePermission(List<Deal_Registration__c> oldDeals) {
		String userProfile = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()].Name;

		for (Deal_Registration__c deal : oldDeals) {
			if (!profilesAllowedToDeleteDealReg.contains(userProfile)) {
				deal.addError(System.Label.Deal_Reg_Deletion_Restricted);
			}
		}
	}

	public static void processDealRegApprovalAssignment(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap,
		Map<Id, User> ownerMap
	) {
		Set<String> dealIdSetForAssignment = new Set<String>();
		Set<String> dealIdSetForApprovals = new Set<String>();
		for (Deal_Registration__c deal : deals) {
			if (
				oldMap == null ||
				deal.Account__c != oldMap.get(deal.Id).Account__c ||
				(deal.OwnerId != oldMap.get(deal.Id).OwnerId &&
				deal.ownerId != integrationUser.Web_Infinity__c &&
				deal.OwnerId != automationManagement.Default_Opp_Reg_Owner_LATAM__c &&
				deal.Partner_Geo_Region__c != 'LatAm')
			) {
				dealIdSetForAssignment.add(deal.Id);
			}
			if (
				oldMap != null &&
				deal.or_Opp_Reg_Status__c != oldMap.get(deal.id).or_Opp_Reg_Status__c &&
				deal.or_Opp_Reg_Status__c == 'Approved'
			) {
				dealIdSetForApprovals.add(deal.Id);
			}
		}
		if (!dealIdSetForAssignment.isEmpty()) {
			updateDealRegApprovalAssignment(dealIdSetForAssignment, ownerMap);
		}
		if (!dealIdSetForApprovals.isEmpty() && !System.isFuture()) {
			handleApprovedDealReg(dealIdSetForApprovals);
		}
	}

	public static void updateDealRegApprovalAssignment(
		Set<String> dealIdSet,
		Map<Id, User> ownerMap
	) {
		List<String> applicableDealRegStatus = new List<String>{
			'New',
			'Pending',
			'Approved',
			'Expired',
			'Extension Pending'
		};
		if (dealIdSet != null && !dealIdSet.isEmpty()) {
			List<Deal_Registration__c> deals = [
				SELECT
					Id,
					Account__r.HQ_Country__c,
					Countries__c,
					Opp_Reg_Approval_Assignment__c,
					or_Opp_Reg_Status__c,
					wi_Associated_Partner__r.Sales_Model__c,
					OwnerId
				FROM Deal_Registration__c
				WHERE Id IN :dealIdSet
			];
			Map<String, AssignmentWrapper> assignmentValueConditionMap = getAssignmentConditionMap();

			for (Deal_Registration__c deal : deals) {
				deal.Countries__c = (deal.Account__r.HQ_Country__c != null
					? deal.Account__r.HQ_Country__c
					: deal.Countries__c);
				deal.Opp_Reg_Owner_is_AVP_RVP__c = (applicableDealRegStatus.contains(
					deal.or_Opp_Reg_Status__c
				) && isAVPRVP(deal, ownerMap));

				Boolean matchFound = false;
				for (String key : assignmentValueConditionMap.keyset()) {
					if (key != 'Default Assignment' && key != 'Default_Assignment') {
						if (checkMatch(deal, assignmentValueConditionMap.get(key))) {
							deal.Distributor__c = assignmentValueConditionMap.get(key).partnerId;
							if (applicableDealRegStatus.contains(deal.or_Opp_Reg_Status__c)) {
								deal.Opp_Reg_Approval_Assignment__c = assignmentValueConditionMap.get(key)
									.assignmentValue;
							}
							matchFound = true;
							break;
						}
					}
				}
				if (!matchFound && assignmentValueConditionMap.containsKey('Default_Assignment')) {
					deal.Opp_Reg_Approval_Assignment__c = assignmentValueConditionMap.get(
							'Default_Assignment'
						)
						.assignmentValue;
				}
				deal.Opp_Reg_Owner__c = deal.OwnerId;
				deal.or_Tanium_Contact__c = deal.OwnerId;
				if (ownerMap.get(deal.OwnerId).Manager.Email != null) {
					deal.Lead_Owner_Manager_Email__c = ownerMap.get(deal.OwnerId).Manager.Email;
				}
				if (ownerMap.get(deal.OwnerId).ManagerId != null) {
					deal.Lead_Owner_Manager__c = ownerMap.get(deal.OwnerId).ManagerId;
				}
			}
			Utility.fireUpdateOnObject(deals, null, false);
		}
	}

	public static Map<String, AssignmentWrapper> getAssignmentConditionMap() {
		Map<String, AssignmentWrapper> mapAssignmentCondition = new Map<String, AssignmentWrapper>();
		for (Opp_Registration_Approval_Assignment__mdt assignmentCond : [
			SELECT
				ID,
				DeveloperName,
				Approval_Assignment__c,
				Countries__c,
				Countries_Exceptions__c,
				Partner_Name__c,
				Partner_Account_ID__c
			FROM Opp_Registration_Approval_Assignment__mdt
			ORDER BY Approval_Assignment__c
		]) {
			AssignmentWrapper assignmentWrap = new AssignmentWrapper(assignmentCond);
			if (assignmentCond.Countries__c != null) {
				assignmentWrap.conditions.add(getAssignmentCondition('Countries__c', assignmentCond));
			}
			if (assignmentCond.Countries_Exceptions__c != null) {
				assignmentWrap.conditions.add(
					getAssignmentCondition('Countries_Exceptions__c', assignmentCond)
				);
			}
			if (!mapAssignmentCondition.containsKey(assignmentCond.DeveloperName)) {
				mapAssignmentCondition.put(assignmentCond.DeveloperName, assignmentWrap);
			}
		}
		return mapAssignmentCondition;
	}

	public static AssignmentCondition getAssignmentCondition(
		String field,
		Opp_Registration_Approval_Assignment__mdt assignmentCond
	) {
		switch on field {
			when 'Countries__c' {
				return new AssignmentCondition('Countries__c', 'equals', assignmentCond.get(field));
			}
			when 'Countries_Exceptions__c' {
				return new AssignmentCondition('Countries__c', 'not equals', assignmentCond.get(field));
			}
		}
		return null;
	}

	public static Boolean checkMatch(
		Deal_Registration__c deal,
		AssignmentWrapper assignmentCondition
	) {
		Boolean matchFound = true;
		if (assignmentCondition != null && !assignmentCondition.conditions.isEmpty()) {
			for (AssignmentCondition condition : assignmentCondition.conditions) {
				if (condition?.operator == 'equals') {
					if (deal.get(condition.fieldName) != condition.value) {
						matchFound = false;
						break;
					}
				} else {
					if (deal.get(condition.fieldName) == condition.value) {
						matchFound = false;
						break;
					}
				}
			}
		}
		return matchFound;
	}

	private static void handleApprovedDealReg(Set<String> dealIds) {
		ActionResult result = new ActionResult();
		Map<String, String> contactEmailMap = new Map<String, String>();
		Map<String, String> mapDealFieldToOpportunityField = new Map<String, String>();
		List<Contact> newContactList = new List<Contact>();
		List<Deal_Registration__c> updateDealList = new List<Deal_Registration__c>();
		List<Opportunity> newOpportunityList = new List<Opportunity>();
		List<Opportunity> updateOpportunityList = new List<Opportunity>();
		Set<Id> dealIdSet = new Set<Id>();
		Set<String> dealEmailSet = new Set<String>();
		Set<Id> hasContactSet = new Set<Id>();
		Map<String, Schema.SObjectField> mapOpportunityField = Schema.SObjectType.Opportunity.fields.getMap();
		Map<String, Schema.SObjectField> mapDealField = Schema.SObjectType.Deal_Registration__c.fields.getMap();

		for (Opp_Reg_Lead_Conversion_Mapping__mdt orlcm : [
			SELECT Source_Field_API_Name__c, Destination_Field_API_Name__c
			FROM Opp_Reg_Lead_Conversion_Mapping__mdt
			WHERE
				Source_Field_API_Name__c != NULL
				AND Destination_Field_API_Name__c != NULL
				AND Destination_Field_API_Name__c != NULL
		]) {
			mapDealFieldToOpportunityField.put(
				orlcm.Source_Field_API_Name__c.toLowerCase(),
				orlcm.Destination_Field_API_Name__c
			);
		}
		Set<String> setDealField = new Set<String>(mapDealFieldToOpportunityField.keySet());

		String query =
			'SELECT Id, Email__c, Account__c, Account__r.Type, or_Create_Opportunity_upon_Approval__c, Mapped_Opportunity__c, ' +
			'Mapped_Opportunity__r.Deal_Reg_ID__c, Mapped_Opportunity__r.StageName, Mapped_Opportunity__r.Probability, ' +
			'wi_Associated_Partner__r.Name, LastName__c, FirstName__c, Street__c, City__c, State__c, PostalCode__c, ' +
			'Opp_Reg_Extension_Count__c, Mapped_Opportunity__r.Deal_Reg_ID__r.or_Opp_Reg_Status__c, ' +
			'End_Customer_Account_Segment__c, Account__r.Total_Addressable_Seats__c, ' +
			String.join(new List<String>(setDealField), ',') +
			' FROM Deal_Registration__c WHERE Id = :dealIds';

		List<Deal_Registration__c> lstDeal = Database.query(query);
		Set<Id> setOppId = new Set<Id>();

		for (Deal_Registration__c deal : lstDeal) {
			setOppId.add(deal.Mapped_Opportunity__c);
			dealEmailSet.add(deal.Email__c);
		}
		dealEmailSet.remove(null);
		List<Contact> contactList = new List<Contact>();
		if (!dealEmailSet.isempty()) {
			contactList = [
				SELECT Id, AccountId, Email
				FROM Contact
				WHERE Email IN :dealEmailSet AND Email != NULL
			];
		}
		for (Contact contact : contactList) {
			contactEmailMap.put(contact.Email, contact.Id);
		}
		for (Deal_Registration__c deal : lstDeal) {
			if (contactEmailMap.get(deal.Email__c) != null) {
				hasContactSet.add(deal.Id);
			} else {
				newContactList.add(
					new Contact(
						AccountId = deal.Account__c,
						LastName = deal.LastName__c,
						FirstName = deal.FirstName__c,
						Email = deal.Email__c,
						MailingStreet = deal.Street__c,
						MailingCity = deal.City__c,
						MailingState = deal.State__c,
						MailingPostalCode = deal.PostalCode__c
					)
				);
			}
		}
		try {
			insert newContactList;
		} catch (Exception e) {
			Logger.error('DealRegistrationUtility.handleApprovedDealReg ERRORS', e);
			Logger.saveLog();
		}

		for (Contact contact : newContactList) {
			for (Deal_Registration__c deal : lstDeal) {
				if (contact.Email == deal.Email__c) {
					contactEmailMap.put(contact.Email, contact.Id);
					hasContactSet.add(deal.Id);
				}
			}
		}
		for (Deal_Registration__c deal : lstDeal) {
			if (dealIds.contains(deal.Id)) {
				if (
					deal.or_Create_Opportunity_upon_Approval__c && deal.Opp_Reg_Extension_Count__c == 0
				) {
					Opportunity newOpportunity = new Opportunity();

					for (String dealField : mapDealFieldToOpportunityField.keySet()) {
						String opportunityField = mapDealFieldToOpportunityField.get(dealField);

						Schema.SObjectField opportunityFieldHandle = mapOpportunityField.get(
							opportunityField
						);
						Schema.SObjectField dealFieldHandle = mapDealField.get(dealField);

						if (opportunityFieldHandle == null || dealFieldHandle == null) {
							String message =
								'Invalid Field mapping stored in custom Setting.' +
								'<br/>Deal_Registration__c.' +
								dealField +
								' [' +
								(isFieldPresent(dealFieldHandle) ? 'Found' : 'Not Found') +
								']' +
								' => ' +
								'Opportunity.' +
								opportunityField +
								' [' +
								(isFieldPresent(opportunityFieldHandle) ? 'Found' : 'Not Found') +
								']';
						} else {
							Schema.SOAPType opportunityFieldType = opportunityFieldHandle.getDescribe()
								.getSOAPType();
							Object fieldValue;
							fieldValue = castFieldValue(deal.get(dealField), opportunityFieldType);
							newOpportunity.put(opportunityField, fieldValue);
						}
					}
					newOpportunity.AccountId = deal.Account__c;
					newOpportunity.StageName = Utility.DISCOVERY;
					newOpportunity.CloseDate = System.today().addDays(270);
					newOpportunity.Deal_Reg_ID__c = deal.Id;
					newOpportunity.Pooled_Instance__c = 'No';
					String accountType = deal.Account__r?.Type;
					setOpportunityType(newOpportunity, accountType);
					newOpportunityList.add(newOpportunity);
					if (hasContactSet.contains(deal.Id)) {
						deal.Related_contact__c = contactEmailMap.get(deal.Email__c);
					}
					updateDealList.add(deal);
				} else if (
					deal.Mapped_Opportunity__c != null && !deal.or_Create_Opportunity_upon_Approval__c
				) {
					Opportunity existingOpportunity = new Opportunity(
						Id = deal.Mapped_Opportunity__c,
						Pooled_Instance__c = 'No'
					);
					Deal_Registration__c updateDeal = new Deal_Registration__c(Id = deal.Id);
					if (
						deal.Mapped_Opportunity__r.Deal_Reg_ID__c == null ||
						OPP_REG_STATUS_BYPASS.contains(
							deal.Mapped_Opportunity__r.Deal_Reg_ID__r.or_Opp_Reg_Status__c
						)
					) {
						existingOpportunity.Deal_Reg_ID__c = deal.Id;
					}
					if (deal.Mapped_Opportunity__r.Probability < 20) {
						existingOpportunity.StageName = Utility.DISCOVERY;
					}
					if (hasContactSet.contains(deal.Id)) {
						updateOpportunityList.add(existingOpportunity);
						updateDeal.Related_contact__c = contactEmailMap.get(deal.Email__c);
						updateDealList.add(updateDeal);
					}
				}
				dealIdSet.add(deal.Id);
			}
		}

		try {
			insert newOpportunityList;
		} catch (Exception e) {
			Logger.error('DealRegistrationUtility.handleApprovedDealReg ERRORS', e);
			Logger.saveLog();
		}

		for (Opportunity opp : newOpportunityList) {
			for (Deal_Registration__c deal : updateDealList) {
				if (
					opp.AccountId == deal.Account__c &&
					opp.StageName == Utility.DISCOVERY &&
					opp.CloseDate == System.today().addDays(270)
				) {
					deal.Mapped_Opportunity__c = opp.Id;
					Map<String, Object> mapData = new Map<String, Object>{ 'opportunityId' => opp.Id };
					result.setSucess(mapData);
				}
			}
		}
		try {
			update updateOpportunityList;
		} catch (Exception e) {
			Logger.error('DealRegistrationUtility.handleApprovedDealReg ERRORS', e);
			Logger.saveLog();
		}

		try {
			update updateDealList;
		} catch (Exception e) {
			Logger.error('DealRegistrationUtility.handleApprovedDealReg ERRORS', e);
			Logger.saveLog();
		}
		insertOpportunityPartner(dealIdSet);
	}

	public static void insertOpportunityPartner(Set<Id> dealRegistrationIds) {
		List<Opportunity_Partners__c> oppPartnersToInsert = new List<Opportunity_Partners__c>();
		Set<String> eligibleDealRegTypes = new Set<String>{ 'Partner Sourced', 'Teaming' };
		List<Deal_Registration__c> deals = [
			SELECT
				Id,
				Mapped_Opportunity__c,
				wi_Associated_Partner__c,
				or_Opportunity_Registration__c,
				Distributor__c,
				or_Create_Opportunity_upon_Approval__c,
				or_Opportunity_Registration_Discount_p__c
			FROM Deal_Registration__c
			WHERE Id IN :dealRegistrationIds
		];
		List<Database.SaveResult> saveResults;

		for (Deal_Registration__c deal : deals) {
			if (!deal.or_Create_Opportunity_upon_Approval__c) {
				continue;
			}
			if (!eligibleDealRegTypes.contains(deal.or_Opportunity_Registration__c)) {
				continue;
			}
			oppPartnersToInsert.add(
				new Opportunity_Partners__c(
					Opportunity__c = deal.Mapped_Opportunity__c,
					Account__c = deal.wi_Associated_Partner__c,
					Partner_Role__c = (deal.or_Opportunity_Registration__c == 'Partner Sourced')
						? PARTNER_CREATOR
						: SUPPLY_CHAIN_PROCUREMENT,
					Deal_Registration__c = deal.Id,
					isRecordManuallyCreated__c = false
				)
			);
			if (deal.Distributor__c != null && deal.Distributor__c != deal.wi_Associated_Partner__c) {
				oppPartnersToInsert.add(
					new Opportunity_Partners__c(
						Opportunity__c = deal.Mapped_Opportunity__c,
						Account__c = deal.Distributor__c,
						Partner_Role__c = SUPPLY_CHAIN_PROCUREMENT,
						Deal_Registration__c = deal.Id,
						isRecordManuallyCreated__c = false
					)
				);
			}
		}
		saveResults = Database.insert(oppPartnersToInsert, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'DealRegistrationUtility.insertOpportunityPartner ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void processDealRegDistributor(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		List<Deal_Registration__c> dealsToUpdate = new List<Deal_Registration__c>();
		Map<String, String> assignmentNamesWithDistributorAccount = new Map<String, String>();
		List<Deal_Registration__c> dealsSelectedForUpdate = new List<Deal_Registration__c>();
		Map<String, OppReg_Distributor_Partner__mdt> mapDisti = OppReg_Distributor_Partner__mdt.getAll();
		for (String each : mapDisti.keySet()) {
			assignmentNamesWithDistributorAccount.put(
				mapDisti.get(each).Label,
				mapDisti.get(each).Distributor_Account_Id__c
			);
		}
		for (Deal_Registration__c deal : deals) {
			if (
				assignmentNamesWithDistributorAccount.containsKey(deal.Select_Your_Distributor__c) &&
				deal.End_Customer_Account_Segment__c == PUBLIC_SECTOR_SEGMENT &&
				deal.Select_Your_Distributor__c != null &&
				(oldMap == null ||
				(oldMap.get(deal.Id).Select_Your_Distributor__c != deal.Select_Your_Distributor__c ||
				oldMap.get(deal.Id).End_Customer_Account_Segment__c !=
				deal.End_Customer_Account_Segment__c))
			) {
				dealsSelectedForUpdate.add(deal);
			}
		}
		if (!dealsSelectedForUpdate.isEmpty()) {
			for (Deal_Registration__c deal : dealsSelectedForUpdate) {
				Deal_Registration__c eachRecord = new Deal_Registration__c(
					Id = deal.Id,
					Distributor__c = (Id) assignmentNamesWithDistributorAccount.get(
						deal.Select_Your_Distributor__c
					)
				);
				dealsToUpdate.add(eachRecord);
			}
		}
		if (!dealsToUpdate.isEmpty()) {
			try {
				update dealsToUpdate;
			} catch (Exception e) {
				Logger.error('DealRegistrationUtility.processDealRegDistributor ERRORS', e);
				Logger.saveLog();
			}
		}
	}

	public static void upsertOpportunityPartner(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		Map<Id, Id> dealRegIdOppIdMap = new Map<Id, Id>();
		List<Deal_Registration__c> partnerSourcedDealRegistrations = getEligibleDealRegistrationsByDealRegType(
			deals,
			'Partner Sourced'
		);
		List<Deal_Registration__c> teamingDealRegistrations = getEligibleDealRegistrationsByDealRegType(
			deals,
			'Teaming'
		);
		List<Deal_Registration__c> partnerInvolvedDealRegistrations = partnerSourcedDealRegistrations;
		partnerInvolvedDealRegistrations.addAll(teamingDealRegistrations);
		List<Deal_Registration__c> recentlyApprovedPartnerInvolvedDealRegistrations = new List<Deal_Registration__c>();

		for (
			Deal_Registration__c partnerInvolvedDealRegistration : partnerInvolvedDealRegistrations
		) {
			if (
				partnerInvolvedDealRegistration.or_Opp_Reg_Status__c == 'Approved' &&
				partnerInvolvedDealRegistration.or_Opp_Reg_Status__c !=
				oldMap.get(partnerInvolvedDealRegistration.Id).or_Opp_Reg_Status__c
			) {
				recentlyApprovedPartnerInvolvedDealRegistrations.add(partnerInvolvedDealRegistration);
			}
		}

		Map<Id, List<Opportunity_Partners__c>> oppIdOppPartnersMap = new Map<Id, List<Opportunity_Partners__c>>();
		List<Opportunity_Partners__c> oppPartners;
		List<Opportunity_Partners__c> oppPartnersToUpdate = new List<Opportunity_Partners__c>();
		List<Opportunity_Partners__c> oppPartnersToInsert = new List<Opportunity_Partners__c>();
		List<Opportunity_Partners__c> existingOppPartners;
		Id prevOppId = null;
		Boolean sameAccountoppPartnerExists;
		Boolean sameDistributorAccountoppPartnerExists;
		List<Database.SaveResult> saveResults;

		if (recentlyApprovedPartnerInvolvedDealRegistrations.isEmpty()) {
			return;
		}
		for (
			Deal_Registration__c partnerInvolvedDealRegistration : recentlyApprovedPartnerInvolvedDealRegistrations
		) {
			dealRegIdOppIdMap.put(
				partnerInvolvedDealRegistration.Id,
				partnerInvolvedDealRegistration.Mapped_Opportunity__c
			);
		}
		for (Opportunity_Partners__c oppPartner : [
			SELECT Id, Name, Opportunity__c, Account__c, Opportunity_Registration__c, Partner_Role__c
			FROM Opportunity_Partners__c
			WHERE Opportunity__c IN :dealRegIdOppIdMap.values()
			WITH SYSTEM_MODE
			ORDER BY Opportunity__c
		]) {
			if (prevOppId == oppPartner.Opportunity__c) {
				prevOppId = oppPartner.Opportunity__c;
				oppPartners.add(oppPartner);
				continue;
			}
			if (prevOppId == null || prevOppId != oppPartner.Opportunity__c) {
				if (prevOppId != null) {
					oppIdOppPartnersMap.put(prevOppId, oppPartners);
				}
				prevOppId = oppPartner.Opportunity__c;
				oppPartners = new List<Opportunity_Partners__c>();
				oppPartners.add(oppPartner);
			}
		}
		oppIdOppPartnersMap.put(prevOppId, oppPartners);
		for (
			Deal_Registration__c partnerInvolvedDealRegistration : recentlyApprovedPartnerInvolvedDealRegistrations
		) {
			sameAccountoppPartnerExists = false;
			sameDistributorAccountoppPartnerExists = false;
			existingOppPartners = oppIdOppPartnersMap.get(
				partnerInvolvedDealRegistration.Mapped_Opportunity__c
			);
			for (
				Opportunity_Partners__c existingOppPartner : (existingOppPartners != null)
					? existingOppPartners
					: new List<Opportunity_Partners__c>()
			) {
				if (
					partnerInvolvedDealRegistration.Distributor__c != null &&
					existingOppPartner.Account__c == partnerInvolvedDealRegistration.Distributor__c
				) {
					sameDistributorAccountoppPartnerExists = true;
				}
				if (
					existingOppPartner.Account__c ==
					partnerInvolvedDealRegistration.wi_Associated_Partner__c
				) {
					if (
						partnerInvolvedDealRegistration.or_Opportunity_Registration__c ==
						'Partner Sourced'
					) {
						oppPartnersToUpdate.add(
							new Opportunity_Partners__c(
								Id = existingOppPartner.Id,
								Partner_Role__c = PARTNER_CREATOR,
								Deal_Registration__c = partnerInvolvedDealRegistration.Id
							)
						);
					}
					sameAccountoppPartnerExists = true;
				}
			}
			if (!sameAccountoppPartnerExists) {
				oppPartnersToInsert.add(
					new Opportunity_Partners__c(
						Opportunity__c = partnerInvolvedDealRegistration.Mapped_Opportunity__c,
						Account__c = partnerInvolvedDealRegistration.wi_Associated_Partner__c,
						Partner_Role__c = (partnerInvolvedDealRegistration.or_Opportunity_Registration__c ==
							'Partner Sourced')
							? PARTNER_CREATOR
							: SUPPLY_CHAIN_PROCUREMENT,
						Deal_Registration__c = partnerInvolvedDealRegistration.Id,
						isRecordManuallyCreated__c = false
					)
				);
			}
			if (
				!sameDistributorAccountoppPartnerExists &&
				partnerInvolvedDealRegistration.Distributor__c != null
			) {
				oppPartnersToInsert.add(
					new Opportunity_Partners__c(
						Opportunity__c = partnerInvolvedDealRegistration.Mapped_Opportunity__c,
						Account__c = partnerInvolvedDealRegistration.Distributor__c,
						Partner_Role__c = SUPPLY_CHAIN_PROCUREMENT,
						Deal_Registration__c = partnerInvolvedDealRegistration.Id,
						isRecordManuallyCreated__c = false
					)
				);
			}
		}
		saveResults = Database.insert(oppPartnersToInsert, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'DealRegistrationUtility.upsertOpportunityPartner ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();

		saveResults = Database.update(oppPartnersToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'DealRegistrationUtility.upsertOpportunityPartner ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void handleMappedOpportunityChange(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		Set<Id> oppIds = new Set<Id>();

		for (Deal_Registration__c deal : deals) {
			oppIds.add(deal.Mapped_Opportunity__c);
		}

		Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
			[SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]
		);

		for (Deal_Registration__c deal : deals) {
			if (
				(oldMap == null ||
				oldMap?.get(deal.Id)?.Mapped_Opportunity__c != deal.Mapped_Opportunity__c) &&
				deal.Mapped_Opportunity__c != null
			) {
				String stageName = oppMap.get(deal.Mapped_Opportunity__c).StageName;
				if (Utility.isClosedOpp(stageName)) {
					deal.addError(Label.Deal_Reg_Map_Closed_Won_Opp_Restricted);
				}
			}
		}
	}

	public static void preApprovalChecks(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap
	) {
		List<Deal_Registration__c> approvedDeals = new List<Deal_Registration__c>();
		Set<Id> oppIds = new Set<Id>();
		String mappedOppStage = '';

		for (Deal_Registration__c deal : deals) {
			if (
				(oldMap == null ||
				oldMap?.get(deal.Id)?.or_Opp_Reg_Status__c != deal.or_Opp_Reg_Status__c) &&
				deal.or_Opp_Reg_Status__c == 'Approved' &&
				deal.Mapped_Opportunity__c != null
			) {
				approvedDeals.add(deal);
				oppIds.add(deal.Mapped_Opportunity__c);
			}
		}

		Map<Id, Deal_Registration__c> oppDealRegMap = getExpiredOrExtendedDeals(
			oppIds,
			approvedDeals
		);
		Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
			[SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]
		);

		for (Deal_Registration__c deal : approvedDeals) {
			mappedOppStage = oppMap?.get(deal.Mapped_Opportunity__c).StageName;

			if (Utility.isClosedOpp(mappedOppStage)) {
				deal.addError(Label.Deal_Reg_Approval_Restricted_Closed_Won_Opp);
			} else if (
				partnerHasExpiredOrExtensionPendingDeal(
					deal.Mapped_Opportunity__c,
					deal.wi_Associated_Partner__c,
					oppDealRegMap
				)
			) {
				String recordLink = URL.getOrgDomainURL().toExternalForm() + '/' + deal.Id;
				deal.addError(
					Label.Deal_Reg_Approval_Restricted_Expired_Extended_Exists.replace(
						'{recordLink}',
						recordLink
					)
				);
			}
		}
	}

	public static void assignEndCustomerAccount(List<Deal_Registration__c> dealRegs) {
		Map<String, Deal_Registration__c> domainToDealReg = new Map<String, Deal_Registration__c>();
		Id accountId;
		Deal_Registration__c dealRegToUpdate;

		for (Deal_Registration__c dealReg : dealRegs) {
			if (
				dealReg.Account__c == null &&
				dealReg.Email__c != null &&
				dealReg.Countries__c != null
			) {
				domainToDealReg.put(extractDomainFromEmail(dealReg.Email__c).toLowerCase(), dealReg);
			}
		}

		for (Account account : [
			SELECT
				Id,
				DNBConnect__D_B_Connect_Company_Profile__r.organization_website_address_domain__c,
				HQ_Country__c
			FROM Account
			WHERE
				DNBConnect__D_B_Connect_Company_Profile__r.organization_website_address_domain__c IN :domainToDealReg.keySet()
		]) {
			dealRegToUpdate = domainToDealReg.get(
				account.DNBConnect__D_B_Connect_Company_Profile__r.organization_website_address_domain__c.toLowerCase()
			);
			if (dealRegToUpdate != null && dealRegToUpdate.Countries__c == account.HQ_Country__c) {
				dealRegToUpdate.Account__c = account.Id;
			}
		}
	}

	public static String extractDomainFromEmail(String emailAddress) {
		String domain;
		try {
			domain = emailAddress.substringAfter('@');
		} catch (Exception e) {
			domain = '';
		}
		return domain;
	}

	public static void processDealRegEndCustomerAccount(
		List<Deal_Registration__c> deals,
		Map<Id, Deal_Registration__c> oldMap,
		Map<Id, Account> accountMap
	) {
		Set<Id> pfsTerritoryIds = new Set<Id>();
		Map<Id, Id> accountIdToPFSTerritoryId = new Map<Id, Id>();
		for (Account acc : accountMap.values()) {
			if (acc.Primary_PFS_Territory_Id__c != null) {
				pfsTerritoryIds.add(acc.Primary_PFS_Territory_Id__c);
				accountIdToPFSTerritoryId.put(acc.Id, acc.Primary_PFS_Territory_Id__c);
			}
		}

		Map<Id, UserTerritory2Association> userTerrAssocMap = new Map<Id, UserTerritory2Association>(
			[
				SELECT Id, UserId, Territory2Id
				FROM UserTerritory2Association
				WHERE Territory2Id IN :pfsTerritoryIds
			]
		);
		Map<Id, String> pfsTerritoryIdToUserTerrAssocId = new Map<Id, String>();
		for (UserTerritory2Association userTerrAssoc : userTerrAssocMap.values()) {
			if (!pfsTerritoryIdToUserTerrAssocId.containsKey(userTerrAssoc.Territory2Id)) {
				pfsTerritoryIdToUserTerrAssocId.put(userTerrAssoc.Territory2Id, userTerrAssoc.Id);
			} else {
				pfsTerritoryIdToUserTerrAssocId.put(userTerrAssoc.Territory2Id, 'duplicate');
			}
		}

		for (Deal_Registration__c deal : deals) {
			if (
				((deal.Account__c != null && oldMap == null) ||
				(deal.Account__c != null &&
				deal.Account__c != oldMap.get(deal.Id)?.Account__c)) &&
				(pfsTerritoryIdToUserTerrAssocId.get(accountIdToPFSTerritoryId.get(deal.Account__c)) !=
				'duplicate')
			) {
				deal.Primary_PFS_Territory_Name__c = accountMap.get(deal.Account__c)
					?.Primary_PFS_Territory_Name__c;
				deal.Primary_PFS_Territory_Owner__c = userTerrAssocMap.get(
						pfsTerritoryIdToUserTerrAssocId.get(
							accountMap.get(deal.Account__c)?.Primary_PFS_Territory_Id__c
						)
					)
					?.UserId;
			}
		}
	}

	@TestVisible
	private static Map<Id, Deal_Registration__c> getExpiredOrExtendedDeals(
		Set<Id> oppIds,
		List<Deal_Registration__c> approvedDeals
	) {
		Map<Id, Deal_Registration__c> oppDealRegMap = new Map<Id, Deal_Registration__c>();
		for (Deal_Registration__c expiredOrExtendedDeal : [
			SELECT Id, wi_Associated_Partner__c, Mapped_Opportunity__c
			FROM Deal_Registration__c
			WHERE
				Mapped_Opportunity__c IN :oppIds
				AND Id NOT IN :approvedDeals
				AND or_Opp_Reg_Status__c IN ('Expired', 'Extension Pending')
		]) {
			oppDealRegMap.put(expiredOrExtendedDeal.Mapped_Opportunity__c, expiredOrExtendedDeal);
		}
		return oppDealRegMap;
	}

	@TestVisible
	private static Boolean partnerHasExpiredOrExtensionPendingDeal(
		Id mappedOppId,
		Id associatedPartner,
		Map<Id, Deal_Registration__c> expiredOrExtendedDeals
	) {
		Deal_Registration__c deal = expiredOrExtendedDeals.get(mappedOppId);
		return associatedPartner != null && associatedPartner == deal?.wi_Associated_Partner__c;
	}

	private static Integer calculateBusinessDays(Date startDate, Date endDate) {
		Integer businessDays = 0;
		Integer daysBetween = startDate.daysBetween(endDate);
		for (Integer i = 0; i <= daysBetween; i++) {
			Date currentDate = startDate + i;
			DateTime currentDateTime = DateTime.newInstance(
				currentDate.year(),
				currentDate.month(),
				currentDate.day()
			);
			String todayDay = currentDateTime.format('EEEE');
			if (todayDay != 'Saturday' && todayDay != 'Sunday') {
				businessDays = businessDays + 1;
			}
		}
		return businessDays;
	}

	@TestVisible
	private static List<Deal_Registration__c> getEligibleDealRegistrationsByDealRegType(
		List<Deal_Registration__c> deals,
		String dealRegType
	) {
		List<Deal_Registration__c> dealRegistrations = getEligibleDealRegistrations(deals);
		List<Deal_Registration__c> partnerInvolvedDealRegistrations = new List<Deal_Registration__c>();

		for (Deal_Registration__c dealRegistration : dealRegistrations) {
			if (dealRegistration.or_Opportunity_Registration__c == dealRegType) {
				partnerInvolvedDealRegistrations.add(dealRegistration);
			}
		}
		return partnerInvolvedDealRegistrations;
	}

	@TestVisible
	private static List<Deal_Registration__c> getEligibleDealRegistrations(
		List<Deal_Registration__c> deals
	) {
		List<Deal_Registration__c> eligibleDealRegistrations = new List<Deal_Registration__c>();
		for (Deal_Registration__c deal : deals) {
			if (deal.Mapped_Opportunity__c != null && deal.wi_Associated_Partner__c != null) {
				eligibleDealRegistrations.add(deal);
			}
		}
		return eligibleDealRegistrations;
	}

	@TestVisible
	private static Boolean isFieldPresent(Schema.SObjectField objecFieldHandle) {
		return objecFieldHandle != null;
	}

	private static Object castFieldValue(Object fieldValue, Schema.SOAPType fieldType) {
		Object castedFieldValue;

		if (fieldType == Schema.SOAPType.Boolean) {
			castedFieldValue = (Boolean) fieldValue;
		} else if (fieldType == Schema.SOAPType.Date) {
			castedFieldValue = Date.valueOf(fieldValue);
		} else if (fieldType == Schema.SOAPType.DateTime) {
			castedFieldValue = DateTime.valueOf(fieldValue);
		} else if (fieldType == Schema.SOAPType.Double) {
			castedFieldValue = Double.valueOf(fieldValue);
		} else if (fieldType == Schema.SOAPType.Id) {
			castedFieldValue = fieldValue;
		} else if (fieldType == Schema.SOAPType.Integer) {
			castedFieldValue = Integer.valueOf(fieldValue);
		} else if (fieldType == Schema.SOAPType.String) {
			castedFieldValue = String.valueOf(fieldValue);
		} else {
			castedFieldValue = fieldValue;
		}
		return fieldValue;
	}

	@TestVisible
	private static void setOpportunityType(Opportunity oppty, String accountType) {
		if (accountType != null && accountType == 'Customer') {
			oppty.Type = 'Expansion';
		} else if (
			accountType != null &&
			(accountType == 'Prospect' ||
			accountType == 'Former Customer' ||
			accountType == 'MSP Partner')
		) {
			oppty.Type = 'New Customer';
		}
	}

	public class AssignmentWrapper {
		public Decimal assignmentValue;
		public List<AssignmentCondition> conditions;
		public String partnerName;
		public String partnerId;

		public AssignmentWrapper(Opp_Registration_Approval_Assignment__mdt assignmentData) {
			this.assignmentValue = assignmentData.Approval_Assignment__c;
			this.conditions = new List<AssignmentCondition>();
			this.partnerName = assignmentData.Partner_Name__c;
			this.partnerId = assignmentData.Partner_Account_ID__c;
		}
	}

	public class AssignmentCondition {
		public String fieldName;
		public String operator;
		public String value;

		public AssignmentCondition(String field, String operator, Object value) {
			this.fieldName = field;
			this.operator = operator;
			this.value = value != null ? (String) value : '';
		}
	}

	public class ActionResult {
		public Boolean isSuccess;
		public String error;
		public Object data;

		public void setSucess(Map<String, Object> mapData) {
			isSuccess = true;
			data = mapData;
		}

		public void setFailure(Exception ex) {
			isSuccess = false;
			error = ex.getMessage();
			data = new Map<String, Object>{ 'exception' => ex.getStackTraceString() };
		}

		public void setFailure(String errorMessage) {
			isSuccess = false;
			error = errorMessage;
		}
	}
}