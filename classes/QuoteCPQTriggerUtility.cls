/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: SBQQ Quote Utility class
 * @Author: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-6906    2024-02-09    Null pointer exception in setPaymentTermOnBillingQuoteTerms
 * SS-7469    2024-02-19    Only primary quote will throw validation errors in Quote midmarket validations
 * SS-6987    2024-02-20    Added method recalculateRenewalQuote
 * SS-7665    2024-04-23    isMSP to use quote.Business_Motion_Oppty='MSP'
 * SS-7620    2024-04-18    Deactivating MSP Pricebook
 * SS-7618    2024-05-16    Missing partner error
 * SS-7766    2024-06-07    Added Nebula Logger func.
 * SS-8462    2024-06-13    Updated methods isPartnerRequired, isMidMarket
 * SS-8788    2024-09-13    Added setL1L2Provider method to carry L1L2Provider field to amendment and renewal quote
 * SS-10086   2025-01-27    Remove setL1L2Provider()
 * SS-11278   2025-07-10    Move Payment Term Change to afterUpdate
 * SS-12364   2026-01-22    Renamed method recalculateRenewalQuote to processRenewalQuote, added methods processAmendmentQuote, identifyNewModules plus supporting methods
 * SS-12404   2026-02-20    Updated methods determineLegalEntitiesBeforeInsert, determineLegalEntitiesBeforeUpdate
 * SS-12833   2026-03-16    Revert Identify New Modules related code
 * SS-12818   2026-03-18    Add processIdentifyNewModules() and related code
 * SS-12676   2026-03-25    Deleted depreciated fields (Non_Absorb_Transaction__c)
 * SS-13549   2026-07-16    Updated method determineLegalEntitiesBeforeUpdate
 * SS-13648   2026-08-04    Added methods setAICredits, getAICreditTiers, getMonthlyAICredits
 */

public with sharing class QuoteCPQTriggerUtility {
	public static final Set<String> VALIDATION_BYPASS_QUOTE_TYPES = new Set<String>{
		'Renewal',
		'Amendment'
	};
	public static final Set<String> VALIDATION_BYPASS_UPDATED_FIELDS = new Set<String>{
		'sbqq__primary__c',
		'billingschedulesyncstatus__c',
		'sbqq__lastsavedon__c'
	};
	public static final String MID_MARKET_PRICEBOOK = 'Global Pricebook';
	private static Map<Id, Pricebook2> activePricebookMap = Utility.getActivePricebooksMap();
	private static Integration_User__c integrationUser = Integration_User__c.getInstance();
	@TestVisible
	private static final List<String> LOCKED_QUOTE_STATUSES = new List<String>{ 'Approved' };
	@TestVisible
	private static final String APPROVED_QUOTE_STATUS = 'Approved';
	@TestVisible
	private static Boolean flagToCreateQuoteDocument = false;
	@TestVisible
	private static final String DEFAULT_QUOTE_TEMPLATE = 'TaniumQuote2022';
	@TestVisible
	private static Boolean flagToCreateAttachmentOnOpportunity = false;
	@TestVisible
	private static final String ON_PREM_DEPLOYMENT = 'OnPrem';
	@TestVisible
	private static final String TAAS_DEPLOYMENT = 'TaaS';

	public static void processBillingScheduleOnOpportunity(
		List<SBQQ__Quote__c> newQuotes,
		Map<Id, SBQQ__Quote__c> oldQuotes
	) {
		Set<Id> oppIdsForBillingUpdates = new Set<Id>();
		List<Billing_Schedule__c> billingsToUpdate = new List<Billing_Schedule__c>();
		for (SBQQ__Quote__c eachQuote : newQuotes) {
			if (eachQuote.SBQQ__Primary__c != oldQuotes.get(eachQuote.Id).SBQQ__Primary__c) {
				oppIdsForBillingUpdates.add(eachQuote.SBQQ__Opportunity2__c);
			}
		}
		if (!oppIdsForBillingUpdates.isEmpty()) {
			updateBillingScheduleFuture(oppIdsForBillingUpdates);
		}
	}

	@future
	private static void updateBillingScheduleFuture(Set<Id> oppIdsForBillingUpdates) {
		updateBillingSchedules(oppIdsForBillingUpdates);
	}

	public static void updateBillingSchedules(Set<Id> oppIdsForBillingUpdates) {
		List<Database.SaveResult> saveResults = new List<Database.SaveResult>();
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		try {
			List<Billing_Schedule__c> billingsToUpdate = new List<Billing_Schedule__c>();
			List<Billing_Schedule__c> billingsSelected = [
				SELECT
					Id,
					Name,
					Opportunity__c,
					Quote__r.SBQQ__Primary__c,
					Quote__r.SBQQ__Opportunity2__c
				FROM Billing_Schedule__c
				WHERE Quote__r.SBQQ__Opportunity2__c IN :oppIdsForBillingUpdates
			];
			for (Billing_Schedule__c eachBilling : billingsSelected) {
				if (eachBilling.Quote__r.SBQQ__Primary__c == true) {
					eachBilling.Opportunity__c = eachBilling.Quote__r.SBQQ__Opportunity2__c;
				} else {
					eachBilling.Opportunity__c = null;
				}
				billingsToUpdate.add(eachBilling);
			}
			saveResults = Database.update(billingsToUpdate, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'QuoteCPQTriggerUtility.updateBillingSchedules ERRORS',
					saveResults
				)
				.addTag('apex');
		} catch (Exception e) {
			Logger.error('QuoteCPQTriggerUtility.updateBillingSchedules ERRORS', e);
		}
		Logger.saveLog();
	}

	public static void handleDeletedQuotes(List<SBQQ__Quote__c> oldQuotes) {
		Map<Id, Billing_Schedule__c> billingMap = new Map<Id, Billing_Schedule__c>(
			[SELECT Id FROM Billing_Schedule__c WHERE Quote__c IN :oldQuotes]
		);
		if (billingMap != null && !billingMap.isEmpty()) {
			QuoteCPQTriggerUtility.deleteBillingSchedulesFuture(billingMap.keySet());
		}
	}

	@future
	public static void deleteBillingSchedulesFuture(Set<Id> billingIdsTodelete) {
		deleteBillingSchedules(billingIdsTodelete);
	}

	public static void deleteBillingSchedules(Set<Id> billingIdsTodelete) {
		List<Database.DeleteResult> deleteResults = new List<Database.DeleteResult>();
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		try {
			List<Billing_Schedule__c> billingsToDelete = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE Id IN :billingIdsTodelete
			];
			deleteResults = Database.delete(billingsToDelete, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'QuoteCPQTriggerUtility.deleteBillingSchedules ERRORS',
					deleteResults
				)
				.addTag('apex');
		} catch (Exception e) {
			Logger.error('QuoteCPQTriggerUtility.deleteBillingSchedules ERRORS', deleteResults);
		}
		Logger.saveLog();
	}

	public static void setPartnerAccreditationValues(
		List<SBQQ__Quote__c> newQuotes,
		Map<Id, SBQQ__Quote__c> oldMap
	) {
		Set<String> partnerAccredMap = new Set<String>();
		for (SBQQ__Quote__c eachQuote : newQuotes) {
			if (
				(eachQuote.Deployment_Partner__c != null) &&
				(eachQuote.L1_L2_Support_Partner__c != null)
			) {
				partnerAccredMap.add(eachQuote.L1_L2_Support_Partner__c);
				partnerAccredMap.add(eachQuote.Deployment_Partner__c);
			} else {
				if (
					oldMap != null &&
					(eachQuote.Deployment_Partner__c != null &&
					eachQuote.Deployment_Partner__c != oldMap.get(eachQuote.Id).Deployment_Partner__c ||
					(eachQuote.L1_L2_Support_Partner__c != null &&
					oldMap.get(eachQuote.Id).L1_L2_Support_Partner__c != null &&
					eachQuote.L1_L2_Support_Partner__c !=
					oldMap.get(eachQuote.Id).L1_L2_Support_Partner__c))
				) {
					partnerAccredMap.add(eachQuote.Deployment_Partner__c);
					partnerAccredMap.add(eachQuote.L1_L2_Support_Partner__c);
				} else if (
					oldMap != null &&
					((eachQuote.Deployment_Partner__c !=
					oldMap.get(eachQuote.Id).Deployment_Partner__c &&
					eachQuote.Deployment_Partner__c == null) ||
					(eachQuote.L1_L2_Support_Partner__c !=
					oldMap.get(eachQuote.Id).L1_L2_Support_Partner__c &&
					eachQuote.L1_L2_Support_Partner__c == null))
				) {
					if (
						eachQuote.Deployment_Partner__c == null &&
						eachQuote.Partner_Accreditation__c != null &&
						eachQuote.Partner_Accreditation__c.contains('Deployment')
					) {
						String clearString = eachQuote.Partner_Accreditation__c.replace('Deployment', '');
						eachQuote.Partner_Accreditation__c = clearString.trim();
					}
					if (
						eachQuote.L1_L2_Support_Partner__c == null &&
						eachQuote.Partner_Accreditation__c != null &&
						eachQuote.Partner_Accreditation__c.contains('Support')
					) {
						String clearString = eachQuote.Partner_Accreditation__c.replace('Support', '');
						eachQuote.Partner_Accreditation__c = clearString.trim();
					}
				} else if (
					oldMap != null &&
					eachQuote.Deployment_Exception_Granted__c !=
					oldMap.get(eachQuote.Id).Deployment_Exception_Granted__c
				) {
					if (
						eachQuote.Deployment_Exception_Granted__c &&
						eachQuote.Partner_Accreditation__c != null &&
						eachQuote.Partner_Accreditation__c.contains('Deployment')
					) {
						String clearString = eachQuote.Partner_Accreditation__c.replace('Deployment', '');
						eachQuote.Partner_Accreditation__c = clearString.trim();
					} else {
						partnerAccredMap.add(eachQuote.Deployment_Partner__c);
					}
				} else if (
					oldMap != null &&
					eachQuote.L1_L2_Support_Exception_Granted__c !=
					oldMap.get(eachQuote.Id).L1_L2_Support_Exception_Granted__c
				) {
					if (
						eachQuote.L1_L2_Support_Exception_Granted__c &&
						eachQuote.Partner_Accreditation__c != null &&
						eachQuote.Partner_Accreditation__c.contains('Support')
					) {
						String clearString = eachQuote.Partner_Accreditation__c.replace('Support', '');
						eachQuote.Partner_Accreditation__c = clearString.trim();
					} else {
						partnerAccredMap.add(eachQuote.L1_L2_Support_Partner__c);
					}
				}
			}
		}
		if (!partnerAccredMap.isEmpty()) {
			QuoteCPQTriggerUtility.handleDefaultPartnerAccreditation(newQuotes, partnerAccredMap);
		}
	}

	private static void handleDefaultPartnerAccreditation(
		List<SBQQ__Quote__c> newQuotes,
		Set<String> partnerSet
	) {
		Map<Id, Account> mapAccount = new Map<Id, Account>(
			[
				SELECT Id, Partner_Accreditations__c, Business_Motion__c
				FROM Account
				WHERE Id IN :partnerSet
			]
		);
		for (SBQQ__Quote__c eachQuote : newQuotes) {
			String partnerAccreditation = '';
			if (mapAccount.get(eachQuote.L1_L2_Support_Partner__c) != null) {
				Account supportPartner = mapAccount.get(eachQuote.L1_L2_Support_Partner__c);
				if (!eachQuote.L1_L2_Support_Exception_Granted__c) {
					if (
						supportPartner.Business_Motion__c != null &&
						!supportPartner.Business_Motion__c.contains('Support') &&
						supportPartner.Partner_Accreditations__c == null
					) {
						partnerAccreditation += 'Support';
					} else if (
						supportPartner.Partner_Accreditations__c == null &&
						supportPartner.Business_Motion__c == null
					) {
						partnerAccreditation += 'Support';
					} else if (
						supportPartner.Partner_Accreditations__c != null &&
						!supportPartner.Partner_Accreditations__c.contains('Support')
					) {
						partnerAccreditation += 'Support';
					}
				}
			}
			if (mapAccount.get(eachQuote.Deployment_Partner__c) != null) {
				Account deploymentPartner = mapAccount.get(eachQuote.Deployment_Partner__c);
				if (!eachQuote.Deployment_Exception_Granted__c) {
					if (
						deploymentPartner.Business_Motion__c != null &&
						!deploymentPartner.Business_Motion__c.contains('Support') &&
						deploymentPartner.Partner_Accreditations__c == null
					) {
						partnerAccreditation += ' Deployment';
					} else if (
						deploymentPartner.Partner_Accreditations__c == null &&
						deploymentPartner.Business_Motion__c == null
					) {
						partnerAccreditation += ' Deployment';
					} else if (
						deploymentPartner.Partner_Accreditations__c != null &&
						!deploymentPartner.Partner_Accreditations__c.contains('Deployment')
					) {
						partnerAccreditation += ' Deployment';
					}
				}
			}

			eachQuote.Partner_Accreditation__c = partnerAccreditation.trim();
		}
	}

	public static void setLockInDates(List<SBQQ__Quote__c> newQuotes) {
		Set<Id> oppIds = new Set<Id>();
		for (SBQQ__Quote__c eachQuote : newQuotes) {
			if (eachQuote.SBQQ__Opportunity2__c != null) {
				oppIds.add(eachQuote.SBQQ__Opportunity2__c);
			}
		}

		Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
			[SELECT Id, Type FROM Opportunity WHERE Id IN :oppIds]
		);

		for (SBQQ__Quote__c eachQuote : newQuotes) {
			Opportunity opp = oppMap.get(eachQuote.SBQQ__Opportunity2__c);
			if (opp != null && opp.Type != null && opp.Type.contains('Renewal')) {
				eachQuote.Do_Not_Show_Dates__c = true;
			}
		}
	}

	public static Boolean isPartnerRequired(SBQQ__Quote__c quote) {
		return (quote.ApprovalStatus__c == null &&
			quote.SBQQ__Partner__c == null &&
			!VALIDATION_BYPASS_QUOTE_TYPES.contains(quote.SBQQ__Type__c) &&
			((isMidMarket(quote) && quote.Opportunity_Type__c != 'Concession')) &&
			quote.Bypass_Partner_Requirement__c == false) ||
			(quote.Id == null &&
			isMSP(quote) &&
			quote.SBQQ__Partner__c == null);
	}

	public static Boolean isDeploymentProviderRequired(SBQQ__Quote__c quote) {
		return !quote.isClone() &&
			quote.ApprovalStatus__c == null &&
			!VALIDATION_BYPASS_QUOTE_TYPES.contains(quote.SBQQ__Type__c) &&
			isMidMarket(quote) &&
			(quote.Opportunity_Type__c == 'New Customer') &&
			quote.Bypass_Partner_Requirement__c == false &&
			quote.Deployment_Exception_Granted__c == false;
	}

	public static Boolean isSupportProviderRequired(SBQQ__Quote__c quote) {
		return !quote.isClone() &&
			quote.ApprovalStatus__c == null &&
			quote.L1_L2_Support_Partner__c == null &&
			!VALIDATION_BYPASS_QUOTE_TYPES.contains(quote.SBQQ__Type__c) &&
			isMidMarket(quote) &&
			((quote.Opportunity_Type__c != 'Upsell' &&
			quote.Opportunity_Type__c != 'Concession')) &&
			quote.Bypass_Partner_Requirement__c == false &&
			quote.L1_L2_Support_Exception_Granted__c == false;
	}

	public static void quoteMidMarketValidations(List<SBQQ__Quote__c> newQuotes) {
		HiddenFeatures__mdt hiddenFeatureL1L2SupportProviderVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_L1L2SupportProvVR'
		);
		HiddenFeatures__mdt hiddenFeatureDeploymentProviderVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentVR'
		);
		HiddenFeatures__mdt hiddenFeatureSupportPartnerVR = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_SupportPartnerVR'
		);

		if (UserInfo.getUserId() == integrationUser.Boomi__c) {
			return;
		}
		if (!FeatureManagement.checkPermission('DisableValidationRules')) {
			for (SBQQ__Quote__c eachQuote : newQuotes) {
				if (eachQuote.SBQQ__Primary__c) {
					if (
						hiddenFeatureSupportPartnerVR?.isActive__c == 'False' &&
						isPartnerRequired(eachQuote)
					) {
						eachQuote.SBQQ__Partner__c.addError(System.Label.Partner_Required);
					}
					if (
						hiddenFeatureDeploymentProviderVR?.isActive__c == 'False' &&
						isDeploymentProviderRequired(eachQuote) &&
						eachQuote.Deployment_Partner__c == null
					) {
						eachQuote.Deployment_Partner__c.addError(
							System.Label.Deployment_Provider_Required
						);
					}
					if (
						hiddenFeatureL1L2SupportProviderVR?.isActive__c == 'False' &&
						isSupportProviderRequired(eachQuote)
					) {
						eachQuote.L1_L2_Support_Partner__c.addError(
							System.Label.Support_Provider_Required
						);
					}
				}
			}
		}
	}

	public static Boolean isMidMarket(SBQQ__Quote__c quote) {
		return (quote.Sales_Ops_Derived_EP__c > 0 && quote.Sales_Ops_Derived_EP__c < 10000);
	}

	public static Boolean isMSP(SBQQ__Quote__c quote) {
		return quote.Business_Motion_Oppty__c == 'MSP';
	}

	public static void setBillingRelatedFieldsOnQuote(List<SBQQ__Quote__c> newQuotes) {
		for (SBQQ__Quote__c eachQuote : newQuotes) {
			eachQuote.Billing_Schedule_Total_Amount__c = 0;
		}
	}

	public static void updateBillingQuoteTerms(
		List<SBQQ__Quote__c> newQuotes,
		Map<Id, SBQQ__Quote__c> oldMap
	) {
		for (SBQQ__Quote__c eachQuote : newQuotes) {
			if (
				oldMap != null &&
				(eachQuote.Do_Not_Show_Dates__c != oldMap.get(eachQuote.Id).Do_Not_Show_Dates__c ||
				(eachQuote.SBQQ__PaymentTerms__c != null &&
				eachQuote.SBQQ__PaymentTerms__c != oldMap.get(eachQuote.Id).SBQQ__PaymentTerms__c))
			) {
				BillingScheduleConfiguratorController.updateBillingInformationOnQuote(
					eachQuote.Id,
					eachQuote.First_Billing_Override__c
				);
			}
		}
	}

	public static void determineLegalEntitiesBeforeInsert(List<SBQQ__Quote__c> quotes) {
		Map<Id, Id> quoteIdToClonedQuoteId = new Map<Id, Id>();
		List<SBQQ__Quote__c> quotesToUpdateFromMaster = new List<SBQQ__Quote__c>();
		List<String> federalPartnerNames = System.Label.Federal_Partners.split(',');
		List<String> federalSectors = System.Label.Federal_Sectors.split(',');
		Map<String, Id> entityMap;
		List<SBQQ__Quote__c> quotesToAdjust = new List<SBQQ__Quote__c>();
		List<SBQQ__Quote__c> federalQuotes = new List<SBQQ__Quote__c>();
		Set<String> uniqueCountries = new Set<String>();
		Set<Id> partnerIds = new Set<Id>();
		Set<Id> opportunityIds = new Set<Id>();

		for (SBQQ__Quote__c quote : quotes) {
			if (quote.SBQQ__Partner__c != null) {
				partnerIds.add(quote.SBQQ__Partner__c);
			}
			if (quote.SBQQ__Opportunity2__c != null) {
				opportunityIds.add(quote.SBQQ__Opportunity2__c);
			}
		}

		Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>(
			[SELECT Id, Account.Sector__c FROM Opportunity WHERE Id IN :opportunityIds]
		);

		Map<Id, Account> partnerAccountMap = new Map<Id, Account>(
			[SELECT Id, Name FROM Account WHERE Id IN :partnerIds]
		);

		for (SBQQ__Quote__c quote : quotes) {
			if (quote.Legal_Entity_Override__c != false) {
				continue;
			}

			if (quote.getCloneSourceId() != null) {
				quoteIdToClonedQuoteId.put(quote.Id, quote.getCloneSourceId());
				quotesToUpdateFromMaster.add(quote);
				continue;
			}

			if (
				federalSectors.contains(
					opportunityMap?.get(quote.SBQQ__Opportunity2__c)?.Account?.Sector__c
				) && federalPartnerNames.contains(partnerAccountMap?.get(quote.SBQQ__Partner__c)?.Name)
			) {
				quote.Legal_Entity__c = System.Label.Federal_Legal_Entity_ID;
				continue;
			}

			if (quote.SBQQ__BillingCountry__c != null && quote.Legal_Entity_Override__c == false) {
				uniqueCountries.add(quote.SBQQ__BillingCountry__c);
				quotesToAdjust.add(quote);
			}
		}

		if (!quotesToUpdateFromMaster.isEmpty()) {
			updateLegalEntityFromMaster(quotesToUpdateFromMaster, quoteIdToClonedQuoteId);
		}

		if (!quotesToAdjust.isEmpty()) {
			entityMap = buildEntityMap(uniqueCountries);
			handleLegalEntityPrefill(entityMap, quotesToAdjust);
		}
	}

	public static Map<String, Id> buildEntityMap(Set<String> uniqueCountries) {
		Map<String, Id> entityMap = new Map<String, Id>();

		List<Contracting_Entity__c> contractingEntities = [
			SELECT Id, Country__c, Legal_Entity__c
			FROM Contracting_Entity__c
			WHERE Country__c IN :uniqueCountries
		];

		for (Contracting_Entity__c contractingEntity : contractingEntities) {
			entityMap.put(contractingEntity.Country__c, contractingEntity.Legal_Entity__c);
		}

		return entityMap;
	}

	public static void handleLegalEntityPrefill(
		Map<String, Id> entityMap,
		List<SBQQ__Quote__c> quotesToAdjust
	) {
		for (SBQQ__Quote__c quote : quotesToAdjust) {
			if (entityMap.containsKey(quote.SBQQ__BillingCountry__c)) {
				quote.Legal_Entity__c = entityMap.get(quote.SBQQ__BillingCountry__c);
			}
		}
	}

	public static void updateLegalEntityFromMaster(
		List<SBQQ__Quote__c> quotesToUpdateFromMaster,
		Map<Id, Id> clonedIdMap
	) {
		Map<Id, SBQQ__Quote__c> surceQuoteMap = new Map<Id, SBQQ__Quote__c>(
			[
				SELECT Id, Business_Motion_Oppty__c, Legal_Entity__c
				FROM SBQQ__Quote__c
				WHERE Id IN :clonedIdMap.values()
			]
		);

		for (SBQQ__Quote__c clonedQuote : quotesToUpdateFromMaster) {
			clonedQuote.Legal_Entity__c = surceQuoteMap.get(clonedIdMap.get((clonedQuote.Id)))
				.Legal_Entity__c;
		}
	}

	public static void determineLegalEntitiesBeforeUpdate(
		List<SBQQ__Quote__c> quotes,
		Map<Id, SBQQ__Quote__c> oldMap
	) {
		Map<String, Id> entityMap;
		List<SBQQ__Quote__c> quotesToAdjust = new List<SBQQ__Quote__c>();
		Set<String> uniqueCountries = new Set<String>();
		List<String> federalPartnerNames = System.Label.Federal_Partners.split(';');
		List<String> federalSectors = System.Label.Federal_Sectors.split(',');
		Set<Id> partnerIds = new Set<Id>();
		Set<Id> opportunityIds = new Set<Id>();

		for (SBQQ__Quote__c quote : quotes) {
			if (quote.SBQQ__Partner__c != null) {
				partnerIds.add(quote.SBQQ__Partner__c);
			}
			if (quote.SBQQ__Opportunity2__c != null) {
				opportunityIds.add(quote.SBQQ__Opportunity2__c);
			}
		}

		Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>(
			[SELECT Id, Account.Sector__c FROM Opportunity WHERE Id IN :opportunityIds]
		);

		Map<Id, Account> partnerAccountMap = new Map<Id, Account>(
			[SELECT Id, Name FROM Account WHERE Id IN :partnerIds]
		);

		for (SBQQ__Quote__c quote : quotes) {
			if (quote.Legal_Entity_Override__c != false) {
				continue;
			}

			if (
				federalSectors.contains(
					opportunityMap?.get(quote.SBQQ__Opportunity2__c)?.Account?.Sector__c
				) && federalPartnerNames.contains(partnerAccountMap?.get(quote.SBQQ__Partner__c)?.Name)
			) {
				quote.Legal_Entity__c = System.Label.Federal_Legal_Entity_ID;
				continue;
			}

			if (
				quote.SBQQ__BillingCountry__c != null &&
				oldMap.get(quote.Id).SBQQ__BillingCountry__c != quote.SBQQ__BillingCountry__c
			) {
				uniqueCountries.add(quote.SBQQ__BillingCountry__c);
				quotesToAdjust.add(quote);
			}
		}

		if (!quotesToAdjust.isEmpty()) {
			entityMap = buildEntityMap(uniqueCountries);
			handleLegalEntityPrefill(entityMap, quotesToAdjust);
		}
	}

	public static void determineIfQuoteWasCloned(List<SBQQ__Quote__c> newQuotes) {
		Map<Id, Id> sourceIds = new Map<Id, Id>();
		Map<Id, Id> billingQuotesWithNewlyClonedQuotes = new Map<Id, Id>();
		for (SBQQ__Quote__c quote : newQuotes) {
			if (quote.getCloneSourceId() != null) {
				sourceIds.put(quote.getCloneSourceId(), quote.Id);
				if (
					quote.PaymentTypeNew__c == BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE
				) {
					billingQuotesWithNewlyClonedQuotes.put(quote.getCloneSourceId(), quote.Id);
				}
			}
		}
		if (!sourceIds.isEmpty()) {
			cloneQuoteTerms(sourceIds);
		}
		if (!billingQuotesWithNewlyClonedQuotes.isEmpty()) {
			cloneBillingSchedules(billingQuotesWithNewlyClonedQuotes);
		}
	}

	@future
	public static void cloneQuoteTerms(Map<Id, Id> sourceIds) {
		List<SBQQ__Quote__c> quotesWithTerms = [
			SELECT
				Id,
				Business_Motion_Oppty__c,
				(
					SELECT
						Id,
						SBQQ__Active__c,
						SBQQ__AdvancedCondition__c,
						SBQQ__Body__c,
						SBQQ__ConditionsMet__c,
						Description__c,
						SBQQ__Locked__c,
						SBQQ__ParentTerm__c,
						SBQQ__PrintOrder__c,
						SBQQ__Quote__c,
						SBQQ__StandardTerm__c,
						SBQQ__Status__c,
						SBQQ__TemplateContent__c,
						SBQQ__Type__c
					FROM SBQQ__QuoteTerms__r
				)
			FROM SBQQ__Quote__c
			WHERE Id IN :sourceIds.keySet()
		];

		List<SBQQ__QuoteTerm__c> newQuoteTerms = new List<SBQQ__QuoteTerm__c>();
		List<SBQQ__QuoteTerm__c> clonedQuoteTerms = new List<SBQQ__QuoteTerm__c>();

		for (SBQQ__Quote__c quote : quotesWithTerms) {
			List<SBQQ__QuoteTerm__c> quoteTerms = quote.SBQQ__QuoteTerms__r;
			for (SBQQ__QuoteTerm__c quoteTerm : quoteTerms) {
				newQuoteTerms.add(quoteTerm.clone(false, false, false, false));
			}
		}

		if (!newQuoteTerms.isEmpty()) {
			for (SBQQ__QuoteTerm__c quoteTerm : newQuoteTerms) {
				quoteTerm.SBQQ__Quote__c = sourceIds.get(quoteTerm.SBQQ__Quote__c);
				clonedQuoteTerms.add(quoteTerm);
			}
		}

		if (!clonedQuoteTerms.isEmpty()) {
			insert clonedQuoteTerms;
		}

		Map<Id, Id> quoteTermIds = new Map<Id, Id>();
		for (SBQQ__QuoteTerm__c quoteTerm : clonedQuoteTerms) {
			quoteTermIds.put(quoteTerm.getCloneSourceId(), quoteTerm.Id);
		}

		List<SBQQ__QuoteTerm__c> insertedQuoteTerms = [
			SELECT
				Id,
				(
					SELECT
						Id,
						SBQQ__Index__c,
						SBQQ__Operator__c,
						SBQQ__QuoteTerm__c,
						SBQQ__TestedField__c,
						SBQQ__TestedVariable__c,
						SBQQ__Value__c
					FROM SBQQ__UseConditions__r
				)
			FROM SBQQ__QuoteTerm__c
			WHERE Id IN :quoteTermIds.keySet()
		];

		List<SBQQ__TermCondition__c> newTermConditions = new List<SBQQ__TermCondition__c>();
		List<SBQQ__TermCondition__c> clonedTermConditions = new List<SBQQ__TermCondition__c>();

		for (SBQQ__QuoteTerm__c quoteTerm : insertedQuoteTerms) {
			List<SBQQ__TermCondition__c> termConditions = quoteTerm.SBQQ__UseConditions__r;
			for (SBQQ__TermCondition__c termCondition : termConditions) {
				newTermConditions.add(termCondition.clone(false, false, false, false));
			}
		}

		if (!newTermConditions.isEmpty()) {
			for (SBQQ__TermCondition__c termCondition : newTermConditions) {
				termCondition.SBQQ__QuoteTerm__c = quoteTermIds.get(termCondition.SBQQ__QuoteTerm__c);
				clonedTermConditions.add(termCondition);
			}
		}

		if (!clonedTermConditions.isEmpty()) {
			insert clonedTermConditions;
		}

		List<SBQQ__QuoteTerm__c> insertedQuoteTermsSub = [
			SELECT
				Id,
				(
					SELECT
						Id,
						SBQQ__Active__c,
						SBQQ__AdvancedCondition__c,
						SBQQ__Body__c,
						SBQQ__ConditionsMet__c,
						Description__c,
						SBQQ__Locked__c,
						SBQQ__ParentTerm__c,
						SBQQ__PrintOrder__c,
						SBQQ__Quote__c,
						SBQQ__StandardTerm__c,
						SBQQ__Status__c,
						SBQQ__TemplateContent__c,
						SBQQ__Type__c
					FROM SBQQ__SubTerms__r
				)
			FROM SBQQ__QuoteTerm__c
			WHERE Id IN :quoteTermIds.keySet()
		];

		List<SBQQ__QuoteTerm__c> newSubTerms = new List<SBQQ__QuoteTerm__c>();
		List<SBQQ__QuoteTerm__c> clonedSubTerms = new List<SBQQ__QuoteTerm__c>();

		for (SBQQ__QuoteTerm__c quoteTerm : insertedQuoteTermsSub) {
			List<SBQQ__QuoteTerm__c> subTerms = quoteTerm.SBQQ__SubTerms__r;
			for (SBQQ__QuoteTerm__c subTerm : subTerms) {
				newSubTerms.add(subTerm.clone(false, false, false, false));
			}
		}

		if (!newSubTerms.isEmpty()) {
			for (SBQQ__QuoteTerm__c subTerm : newSubTerms) {
				subTerm.SBQQ__ParentTerm__c = quoteTermIds.get(subTerm.SBQQ__ParentTerm__c);
				clonedSubTerms.add(subTerm);
			}
		}

		if (!clonedSubTerms.isEmpty()) {
			insert clonedSubTerms;
		}
	}

	public static void setIsPrimaryUpdated(
		List<SBQQ__Quote__c> newQuoteList,
		Map<Id, SBQQ__Quote__c> oldQuotesMap
	) {
		Set<String> updatedFields = new Set<String>();
		SBQQ__Quote__c oldQuote = new SBQQ__Quote__c();
		Set<String> fieldNames = SBQQ__Quote__c.sObjectType.getDescribe().fields.getMap().keyset();

		for (SBQQ__Quote__c eachQuote : newQuoteList) {
			if (isLockedQuote(eachQuote)) {
				oldQuote = oldQuotesMap.get(eachQuote.Id);
				for (String field : fieldNames) {
					if (eachQuote.get(field) != oldQuote.get(field)) {
						updatedFields.add(field);
					}
				}
				if (updatedFields.containsAll(VALIDATION_BYPASS_UPDATED_FIELDS)) {
					updatedFields.removeAll(VALIDATION_BYPASS_UPDATED_FIELDS);
				}
				if (updatedFields.isEmpty()) {
					eachQuote.Primary_Updated_and_Approved__c = true;
				}
			}
		}
	}

	private static Boolean isLockedQuote(SBQQ__Quote__c quote) {
		return ((LOCKED_QUOTE_STATUSES.contains(quote.SBQQ__Status__c) ||
		LOCKED_QUOTE_STATUSES.contains(quote.ApprovalStatus__c)) && quote.Unlock_Quote__c == false);
	}

	@future
	public static void cloneBillingSchedules(Map<Id, Id> customBillingQuotesWithNewlyClonedQuotes) {
		List<Billing_Schedule__c> newBillings = new List<Billing_Schedule__c>();
		Map<Id, Id> oldBillingsWithNewBillings = new Map<Id, Id>();
		Savepoint savePoint = Database.setSavepoint();

		for (Billing_Schedule__c eachOldBilling : [
			SELECT
				Id,
				Billing_Amount__c,
				Billing_Amount_Net_Rollup__c,
				Billing_Date__c,
				Billing_Order__c,
				isReverseBilling__c,
				Opportunity__c,
				PaymentType__c,
				Quote__c
			FROM Billing_Schedule__c
			WHERE Quote__c IN :customBillingQuotesWithNewlyClonedQuotes.keySet()
		]) {
			Billing_Schedule__c newBilling = eachOldBilling.clone();
			newBilling.Billing_Amount__c = eachOldBilling.Billing_Amount__c;
			newBilling.Billing_Amount_Net_Rollup__c = eachOldBilling.Billing_Amount_Net_Rollup__c;
			newBilling.Billing_Order__c = eachOldBilling.Billing_Order__c;
			newBilling.Billing_Date__c = eachOldBilling.Billing_Date__c;
			newBilling.isReverseBilling__c = eachOldBilling.isReverseBilling__c;
			newBilling.Opportunity__c = eachOldBilling.Opportunity__c;
			newBilling.PaymentType__c = eachOldBilling.PaymentType__c;
			newBilling.Quote__c = customBillingQuotesWithNewlyClonedQuotes.get(
				eachOldBilling.Quote__c
			);
			newBillings.add(newBilling);
		}
		List<Database.SaveResult> saveResults = Utility.fireInsertOnObject(
			newBillings,
			savePoint,
			true
		);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'QuoteCPQTriggerUtility.cloneBillingSchedules ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();

		for (Billing_Schedule__c eachNewBilling : newBillings) {
			oldBillingsWithNewBillings.put(eachNewBilling.getCloneSourceId(), eachNewBilling.Id);
		}

		cloneBillingByQuoteLines(
			customBillingQuotesWithNewlyClonedQuotes,
			newBillings,
			oldBillingsWithNewBillings,
			savePoint
		);
	}

	public static void cloneBillingByQuoteLines(
		Map<Id, Id> customBillingQuotesWithNewlyClonedQuotes,
		List<Billing_Schedule__c> newBillingSchedules,
		Map<Id, Id> oldBillingsWithNewBillings,
		Savepoint savePoint
	) {
		Map<Id, Id> oldQLWithNewQL = new Map<Id, Id>();
		List<BillingByQuoteLine__c> newBillingsByQL = new List<BillingByQuoteLine__c>();
		for (SBQQ__QuoteLine__c eachQL : [
			SELECT Id, SBQQ__Source__c
			FROM SBQQ__QuoteLine__c
			WHERE SBQQ__Quote__c IN :customBillingQuotesWithNewlyClonedQuotes.values()
		]) {
			oldQLWithNewQL.put(eachQL.SBQQ__Source__c, eachQL.Id);
		}
		for (BillingByQuoteLine__c eachOldBillingByQL : [
			SELECT
				Id,
				BillAmount__c,
				BillDate__c,
				BillingSchedule__c,
				BillingScheduleOrder__c,
				isReverseBilling__c,
				Opportunity__c,
				PaymentType__c,
				Quote__c,
				QuoteLine__c
			FROM BillingByQuoteLine__c
			WHERE BillingSchedule__c IN :oldBillingsWithNewBillings.keyset()
		]) {
			BillingByQuoteLine__c newBillingByQL = eachOldBillingByQL.clone();
			newBillingByQL.BillAmount__c = eachOldBillingByQL.BillAmount__c;
			newBillingByQL.BillDate__c = eachOldBillingByQL.BillDate__c;
			newBillingByQL.BillingSchedule__c = oldBillingsWithNewBillings.get(
				eachOldBillingByQL.BillingSchedule__c
			);
			newBillingByQL.BillingScheduleOrder__c = eachOldBillingByQL.BillingScheduleOrder__c;
			newBillingByQL.isReverseBilling__c = eachOldBillingByQL.isReverseBilling__c;
			newBillingByQL.Opportunity__c = eachOldBillingByQL.Opportunity__c;
			newBillingByQL.PaymentType__c = eachOldBillingByQL.PaymentType__c;
			newBillingByQL.Quote__c = customBillingQuotesWithNewlyClonedQuotes.get(
				eachOldBillingByQL.Quote__c
			);
			newBillingByQL.QuoteLine__c = oldQLWithNewQL.get(eachOldBillingByQL.QuoteLine__c);
			newBillingsByQL.add(newBillingByQL);
		}
		List<Database.SaveResult> saveResults = Utility.fireInsertOnObject(
			newBillingsByQL,
			savePoint,
			true
		);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'QuoteCPQTriggerUtility.cloneBillingByQuoteLines ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void checkDeploymentProvider(
		List<SBQQ__Quote__c> newQuoteList,
		Map<Id, SBQQ__Quote__c> oldQuotesMap
	) {
		List<SBQQ__Quote__c> quotesForValidationCheck = new List<SBQQ__Quote__c>();
		Map<Id, Id> quotesWithDeploymentProvider = new Map<Id, Id>();
		HiddenFeatures__mdt hiddenFeatureDeploymentAccred = Utility.getHiddenFeaturesByDeveloperName(
			'QuoteCPQTriggerUtility_DeploymentAccred'
		);
		if (!FeatureManagement.checkPermission('DisableValidationRules')) {
			for (SBQQ__Quote__c eachQuote : newQuoteList) {
				SBQQ__Quote__c oldQuote = oldQuotesMap?.get(eachQuote.Id);
				if (
					hiddenFeatureDeploymentAccred?.isActive__c == 'False' &&
					!eachQuote.isClone() &&
					(oldQuotesMap == null && eachQuote.SBQQ__Type__c != 'Renewal' &&
					eachQuote.SBQQ__Type__c != 'Amendment' ||
					(oldQuotesMap != null &&
					eachQuote.SBQQ__Type__c != 'Amendment' &&
					(eachQuote.Deployment_Method__c != oldQuote.Deployment_Method__c ||
					(eachQuote.Deployment_Partner__c != oldQuote.Deployment_Partner__c)) &&
					(eachQuote.ApprovalStatus__c == null ||
					(eachQuote.ApprovalStatus__c != null &&
					eachQuote.ApprovalStatus__c != 'Approved'))))
				) {
					quotesForValidationCheck.add(eachQuote);
					quotesWithDeploymentProvider.put(eachQuote.Id, eachQuote.Deployment_Partner__c);
				}
			}
			if (!quotesForValidationCheck.isEmpty()) {
				fireDeploymentProviderValidationError(
					quotesForValidationCheck,
					quotesWithDeploymentProvider,
					oldQuotesMap
				);
			}
		}
	}

	public static void fireDeploymentProviderValidationError(
		List<SBQQ__Quote__c> quotesForValidationCheck,
		Map<Id, Id> quotesWithDeploymentProvider,
		Map<Id, SBQQ__Quote__c> oldQuotesMap
	) {
		Map<Id, Account> deploymentProviders = new Map<Id, Account>(
			[
				SELECT Id, Name, Cloud_Deployment_Accredited__c, On_Prem_Deployment_Accredited__c
				FROM Account
				WHERE Id IN :quotesWithDeploymentProvider.values()
			]
		);
		for (SBQQ__Quote__c eachQuote : quotesForValidationCheck) {
			Account deploymentProvider = deploymentProviders.get(eachQuote.Deployment_Partner__c);
			if (
				((isDeploymentProviderRequired(eachQuote) &&
				eachQuote.Deployment_Method__c != null &&
				deploymentProvider == null) ||
				(oldQuotesMap != null &&
				eachQuote.Deployment_Method__c != null &&
				deploymentProvider != null) ||
				(oldQuotesMap == null &&
				isDeploymentProviderRequired(eachQuote) &&
				eachQuote.Deployment_Method__c != null &&
				deploymentProvider != null)) &&
				((deploymentProvider != null &&
				!deploymentProvider.Cloud_Deployment_Accredited__c &&
				eachQuote.Deployment_Method__c == TAAS_DEPLOYMENT) ||
				(deploymentProvider != null &&
				!deploymentProvider.On_Prem_Deployment_Accredited__c &&
				eachQuote.Deployment_Method__c == ON_PREM_DEPLOYMENT))
			) {
				if (deploymentProvider != null) {
					eachQuote.Deployment_Partner__c.addError(
						System.Label.DeploymentProviderApexValidationError +
							'\n isDeploymentProviderRequired: ' +
							isDeploymentProviderRequired(eachQuote) +
							'\n Deployment Method: ' +
							eachQuote.Deployment_Method__c +
							'\n Deployment Provider: ' +
							deploymentProvider.Name +
							'\n deploymentProvider.Cloud_Deployment_Accredited__c:' +
							deploymentProvider.Cloud_Deployment_Accredited__c +
							'\n deploymentProvider.On_Prem_Deployment_Accredited__c:' +
							deploymentProvider.On_Prem_Deployment_Accredited__c +
							'\n isMidMarket: ' +
							isMidMarket(eachQuote)
					);
				} else {
					eachQuote.Deployment_Partner__c.addError(
						System.Label.DeploymentProviderApexValidationError +
							'\n isDeploymentProviderRequired: ' +
							isDeploymentProviderRequired(eachQuote) +
							'\n Deployment Method: ' +
							eachQuote.Deployment_Method__c +
							'\n Deployment Provider: ' +
							deploymentProvider +
							'\n isMidMarket: ' +
							isMidMarket(eachQuote)
					);
				}
			}
		}
	}

	public static void processQuoteDocuments(
		List<SBQQ__Quote__c> newQuoteList,
		Map<Id, SBQQ__Quote__c> oldQuotesMap
	) {
		SBQQ__Quote__c oldQuote = new SBQQ__Quote__c();
		List<SBQQ__QuoteTemplate__c> quoteTemplates = new List<SBQQ__QuoteTemplate__c>();

		for (SBQQ__Quote__c eachQuote : newQuoteList) {
			oldQuote = oldQuotesMap.get(eachQuote.Id);
			if (
				eachQuote.ApprovalStatus__c != oldQuote.ApprovalStatus__c &&
				eachQuote.ApprovalStatus__c == APPROVED_QUOTE_STATUS &&
				newQuoteList.size() == 1
			) {
				quoteTemplates = [
					SELECT Id
					FROM SBQQ__QuoteTemplate__c
					WHERE Name = :DEFAULT_QUOTE_TEMPLATE
				];
				if (!quoteTemplates.isEmpty() && !Test.isRunningTest()) {
					SBQQ.QuoteDocumentController.saveProposal(
						'en_US',
						newQuoteList[0].Id,
						quoteTemplates[0].Id,
						newQuoteList[0].Name +
							'-' +
							Date.today().year() +
							Date.today().month() +
							Date.today().day() +
							'-' +
							DateTime.now().millisecond() +
							'- AutoGenerated',
						'pdf',
						'Default',
						new List<String>()
					);
				}
				QuoteCPQTriggerUtility.flagToCreateQuoteDocument = true;
			}
		}
	}

	public static void processAutoGenerationQuotePDFOnOpportunityAttachments(
		List<Opportunity> newOpps,
		Map<Id, Opportunity> oldOpps
	) {
		Opportunity oldOpp;
		List<SBQQ__QuoteDocument__c> quoteDocuments = new List<SBQQ__QuoteDocument__c>();
		if (newOpps.size() == 1 && !flagToCreateAttachmentOnOpportunity) {
			for (Opportunity eachOpp : newOpps) {
				quoteDocuments = [
					SELECT SBQQ__AttachmentId__c
					FROM SBQQ__QuoteDocument__c
					WHERE Is_Primary_Quote__c = TRUE AND SBQQ__Opportunity__c = :eachOpp.Id
					ORDER BY LastModifiedDate DESC
				];
				if (!quoteDocuments.isEmpty()) {
					List<Attachment> quoteDocumentAttachments = [
						SELECT Id, Body, Name, Description, ParentId
						FROM Attachment
						WHERE Id = :quoteDocuments[0].SBQQ__AttachmentId__c
					];
					oldOpp = oldOpps.get(eachOpp.Id);
					if (
						!quoteDocumentAttachments.isEmpty() &&
						oldOpp != null &&
						oldOpp.StageName != eachOpp.StageName &&
						eachOpp.StageName == Utility.CLOSED_WON
					) {
						Attachment oppAttachment = new Attachment(
							Body = quoteDocumentAttachments[0].Body,
							Name = quoteDocumentAttachments[0].Name,
							Description = quoteDocumentAttachments[0].Description,
							ParentId = eachOpp.Id
						);
						insert oppAttachment;
						flagToCreateAttachmentOnOpportunity = true;
					}
				}
			}
		}
	}

	public static void processRenewalQuote(Map<Id, SBQQ__Quote__c> quoteMap) {
		List<SBQQ__Quote__c> renewalQuotes = new List<SBQQ__Quote__c>();
		Id salesSystemsUserId;

		try {
			salesSystemsUserId = [SELECT Id FROM User WHERE Alias = 'ssystems' LIMIT 1].Id;
		} catch (Exception e) {
			salesSystemsUserId = null;
		}
		for (SBQQ__Quote__c quote : quoteMap.values()) {
			if (
				(quoteMap.get(quote.Id).SBQQ__Type__c == 'Renewal' &&
				quoteMap.get(quote.Id).CreatedById == salesSystemsUserId)
			) {
				renewalQuotes.add(quote);
			}
		}

		SBQQ_QuoteRenewalAsync async = new SBQQ_QuoteRenewalAsync(renewalQuotes);
		Id jobId = (Test.isRunningTest() || renewalQuotes.isEmpty())
			? null
			: System.enqueueJob(async, 10);
	}

	public static void checkPartner(
		List<SBQQ__Quote__c> newQuoteList,
		Map<Id, SBQQ__Quote__c> oldQuotesMap
	) {
		List<SBQQ__Quote__c> quotesWithoutPartner = new List<SBQQ__Quote__c>();
		if (!FeatureManagement.checkPermission('DisableValidationRules')) {
			for (SBQQ__Quote__c eachQuote : newQuoteList) {
				SBQQ__Quote__c oldQuote = oldQuotesMap?.get(eachQuote.Id);
				if (
					oldQuote != null &&
					eachQuote.SBQQ__Type__c != 'Renewal' &&
					eachQuote.SBQQ__Type__c != 'Amendment' &&
					(eachQuote.SBQQ__Partner__c != oldQuote.SBQQ__Partner__c ||
					eachQuote.SBQQ__Partner__c == null) &&
					QuoteCPQTriggerUtility.isMSP(eachQuote) &&
					(eachQuote.ApprovalStatus__c == null ||
					(eachQuote.ApprovalStatus__c != null &&
					eachQuote.ApprovalStatus__c != 'Approved')) &&
					eachQuote.SBQQ__Partner__c == null
				) {
					quotesWithoutPartner.add(eachQuote);
				}
			}
			if (!quotesWithoutPartner.isEmpty()) {
				for (SBQQ__Quote__c eachQuote : quotesWithoutPartner) {
					eachQuote.SBQQ__Partner__c.addError(System.Label.Partner_Required);
				}
			}
		}
	}

	public static void processIdentifyNewModules(
		List<SBQQ__Quote__c> quotes,
		Map<Id, SBQQ__Quote__c> oldMap
	) {
		List<SBQQ__Quote__c> quotesToIdentifyNewModules = new List<SBQQ__Quote__c>();

		for (SBQQ__Quote__c quote : quotes) {
			if (quote.SBQQ__LastCalculatedOn__c != oldMap.get(quote.Id).SBQQ__LastCalculatedOn__c) {
				quotesToIdentifyNewModules.add(quote);
			}
		}

		if (!quotesToIdentifyNewModules.isEmpty()) {
			identifyNewModules(quotesToIdentifyNewModules);
		}
	}

	public static void identifyNewModules(List<SBQQ__Quote__c> quotes) {
		List<SBQQ__Quote__c> quotesToUpdate = new List<SBQQ__Quote__c>();

		Map<Id, Id> quoteIdToAccountId = new Map<Id, Id>();
		for (SBQQ__Quote__c quote : quotes) {
			quoteIdToAccountId.put(quote.Id, quote.SBQQ__Account__c);
		}

		Map<Id, Set<String>> accountIdToEntitlementModuleNames = getAccountIdToEntitlementModuleNames(
			new Set<Id>(quoteIdToAccountId.values())
		);

		Set<Id> productIds = new Set<Id>();
		List<SBQQ__QuoteLine__c> quoteLines = [
			SELECT Id, SBQQ__Product__c, SBQQ__Quote__c
			FROM SBQQ__QuoteLine__c
			WHERE SBQQ__Quote__c IN :quoteIdToAccountId.keySet()
		];
		for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
			productIds.add(quoteLine.SBQQ__Product__c);
		}

		Map<Id, Set<String>> productIdToProductModuleNames = ProductUtility.getProductIdToProductModuleNames(
			productIds
		);

		Map<Id, Set<String>> quoteIdToProductModuleNames = new Map<Id, Set<String>>();
		for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
			if (!quoteIdToProductModuleNames.containsKey(quoteLine.SBQQ__Quote__c)) {
				quoteIdToProductModuleNames.put(quoteLine.SBQQ__Quote__c, new Set<String>());
			}
			if (productIdToProductModuleNames.containsKey(quoteLine.SBQQ__Product__c)) {
				quoteIdToProductModuleNames.get(quoteLine.SBQQ__Quote__c)
					?.addAll(productIdToProductModuleNames.get(quoteLine.SBQQ__Product__c));
			}
		}

		for (SBQQ__Quote__c quote : quotes) {
			if (quoteIdToProductModuleNames.get(quote.Id) != null) {
				Set<String> productModuleDifference = quoteIdToProductModuleNames.get(quote.Id)
					?.clone();

				if (accountIdToEntitlementModuleNames.get(quoteIdToAccountId.get(quote.Id)) != null) {
					productModuleDifference.removeAll(
						accountIdToEntitlementModuleNames.get(quoteIdToAccountId.get(quote.Id))
					);
				}

				quotesToUpdate.add(
					new SBQQ__Quote__c(
						Id = quote.Id,
						Newly_Quoted_Modules__c = String.join(productModuleDifference, ', ')
					)
				);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(quotesToUpdate, false);
		Logger.logDatabaseErrors(
			LoggingLevel.ERROR,
			'QuoteCPQTriggerUtility.identifyNewModules Errors',
			saveResults
		);
		Logger.saveLog();
	}

	public static void setAICredits(List<SBQQ__Quote__c> quotes, Map<Id, SBQQ__Quote__c> oldMap) {
		List<SBQQ__Quote__c> eligibleQuotes = new List<SBQQ__Quote__c>();

		for (SBQQ__Quote__c quote : quotes) {
			if (
				(quote.Calculated_Annualized_Software_Spend__c !=
				oldMap.get(quote.Id).Calculated_Annualized_Software_Spend__c)
			) {
				eligibleQuotes.add(quote);
			}
		}
		if (eligibleQuotes.isEmpty()) {
			return;
		}

		List<AI_Credit_Tier__c> tiers = getAICreditTiers();
		Decimal annualizedSoftwareSpend;
		Decimal totalAICredits;

		for (SBQQ__Quote__c eligibleQuote : eligibleQuotes) {
			annualizedSoftwareSpend = eligibleQuote.Calculated_Annualized_Software_Spend__c ?? 0;
			totalAICredits = 0;
			for (AI_Credit_Tier__c tier : tiers) {
				if (annualizedSoftwareSpend >= tier.Lower_Band__c) {
					if (annualizedSoftwareSpend >= tier.Upper_Band__c) {
						totalAICredits += tier.Full_Credits__c;
					}
					if (annualizedSoftwareSpend < tier.Upper_Band__c) {
						totalAICredits +=
							((annualizedSoftwareSpend - tier.Lower_Band__c) / tier.Full_Amount__c) *
							tier.Full_Credits__c;
					}
				}
			}
			eligibleQuote.Calculated_AI_Credits__c = getMonthlyAICredits(totalAICredits);
		}
	}

	@TestVisible
	private static List<AI_Credit_Tier__c> getAICreditTiers() {
		return [
			SELECT
				Id,
				Tier__c,
				Lower_Band__c,
				Upper_Band__c,
				Full_Amount__c,
				Marginal_Rate_Percent__c,
				Tanium_Cost_Per_Credit__c,
				Full_Credits__c
			FROM AI_Credit_Tier__c
			ORDER BY Tier__c ASC
		];
	}

	@TestVisible
	private static Integer getMonthlyAICredits(Decimal totalAICredits) {
		Integer roundedMonthlyAICredits = Integer.valueOf(
			((totalAICredits / 12) / 500).round(System.RoundingMode.HALF_UP) * 500
		);
		return roundedMonthlyAICredits < 10000 ? 10000 : roundedMonthlyAICredits;
	}

	@TestVisible
	private static Map<Id, Set<String>> getAccountIdToEntitlementModuleNames(Set<Id> accountIds) {
		Map<Id, Set<String>> accountIdToEntitlementModules = new Map<Id, Set<String>>();

		for (Account_Entitlements__c accountEntitlement : [
			SELECT Id, Module_Name__c, Account__c
			FROM Account_Entitlements__c
			WHERE Account__c IN :accountIds AND Active__c = TRUE
			ORDER BY Account__c
		]) {
			if (!accountIdToEntitlementModules.containsKey(accountEntitlement.Account__c)) {
				accountIdToEntitlementModules.put(accountEntitlement.Account__c, new Set<String>());
			}
			accountIdToEntitlementModules.get(accountEntitlement.Account__c)
				.add(accountEntitlement.Module_Name__c);
		}
		return accountIdToEntitlementModules;
	}
}