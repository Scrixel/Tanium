/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility for QuoteTriggerHandler (standard Quote, Nue)
 * @Description: Ports SS-13958's Quote-object behaviors: partner accreditation, AI credits, billing-quote-terms sync, billing-total zeroing, billing schedule re-linking, newly-quoted-modules diffing, and cascade delete; see QuoteTriggerHandler for what's excluded and why.
 * @Date: 2026-09-09
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13958   2026-09-15    Added AI credits calc, billing quote terms sync
 */
public with sharing class QuoteTriggerUtility {
	public static void setPartnerAccreditationValues(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
		Set<String> partnerAccredMap = new Set<String>();
		for (Quote eachQuote : newQuotes) {
			if (
				(eachQuote.ELV_Deployment_Partner__c != null) &&
				(eachQuote.ELV_L1_L2_Support_Partner__c != null)
			) {
				partnerAccredMap.add(eachQuote.ELV_L1_L2_Support_Partner__c);
				partnerAccredMap.add(eachQuote.ELV_Deployment_Partner__c);
			} else {
				if (
					oldMap != null &&
					(eachQuote.ELV_Deployment_Partner__c != null &&
					eachQuote.ELV_Deployment_Partner__c !=
					oldMap.get(eachQuote.Id).ELV_Deployment_Partner__c ||
					(eachQuote.ELV_L1_L2_Support_Partner__c != null &&
					oldMap.get(eachQuote.Id).ELV_L1_L2_Support_Partner__c != null &&
					eachQuote.ELV_L1_L2_Support_Partner__c !=
					oldMap.get(eachQuote.Id).ELV_L1_L2_Support_Partner__c))
				) {
					partnerAccredMap.add(eachQuote.ELV_Deployment_Partner__c);
					partnerAccredMap.add(eachQuote.ELV_L1_L2_Support_Partner__c);
				} else if (
					oldMap != null &&
					((eachQuote.ELV_Deployment_Partner__c !=
					oldMap.get(eachQuote.Id).ELV_Deployment_Partner__c &&
					eachQuote.ELV_Deployment_Partner__c == null) ||
					(eachQuote.ELV_L1_L2_Support_Partner__c !=
					oldMap.get(eachQuote.Id).ELV_L1_L2_Support_Partner__c &&
					eachQuote.ELV_L1_L2_Support_Partner__c == null))
				) {
					if (
						eachQuote.ELV_Deployment_Partner__c == null &&
						eachQuote.ELV_Partner_Accreditation__c != null &&
						eachQuote.ELV_Partner_Accreditation__c.contains('Deployment')
					) {
						String clearString = eachQuote.ELV_Partner_Accreditation__c.replace(
							'Deployment',
							''
						);
						eachQuote.ELV_Partner_Accreditation__c = clearString.trim();
					}
					if (
						eachQuote.ELV_L1_L2_Support_Partner__c == null &&
						eachQuote.ELV_Partner_Accreditation__c != null &&
						eachQuote.ELV_Partner_Accreditation__c.contains('Support')
					) {
						String clearString = eachQuote.ELV_Partner_Accreditation__c.replace(
							'Support',
							''
						);
						eachQuote.ELV_Partner_Accreditation__c = clearString.trim();
					}
				} else if (
					oldMap != null &&
					eachQuote.ELV_Deployment_Exception_Granted__c !=
					oldMap.get(eachQuote.Id).ELV_Deployment_Exception_Granted__c
				) {
					if (
						eachQuote.ELV_Deployment_Exception_Granted__c &&
						eachQuote.ELV_Partner_Accreditation__c != null &&
						eachQuote.ELV_Partner_Accreditation__c.contains('Deployment')
					) {
						String clearString = eachQuote.ELV_Partner_Accreditation__c.replace(
							'Deployment',
							''
						);
						eachQuote.ELV_Partner_Accreditation__c = clearString.trim();
					} else {
						partnerAccredMap.add(eachQuote.ELV_Deployment_Partner__c);
					}
				} else if (
					oldMap != null &&
					eachQuote.ELV_L1_L2_Support_Exception_Granted__c !=
					oldMap.get(eachQuote.Id).ELV_L1_L2_Support_Exception_Granted__c
				) {
					if (
						eachQuote.ELV_L1_L2_Support_Exception_Granted__c &&
						eachQuote.ELV_Partner_Accreditation__c != null &&
						eachQuote.ELV_Partner_Accreditation__c.contains('Support')
					) {
						String clearString = eachQuote.ELV_Partner_Accreditation__c.replace(
							'Support',
							''
						);
						eachQuote.ELV_Partner_Accreditation__c = clearString.trim();
					} else {
						partnerAccredMap.add(eachQuote.ELV_L1_L2_Support_Partner__c);
					}
				}
			}
		}
		if (!partnerAccredMap.isEmpty()) {
			QuoteTriggerUtility.handleDefaultPartnerAccreditation(newQuotes, partnerAccredMap);
		}
	}

	public static void setBillingRelatedFieldsOnQuote(List<Quote> newQuotes) {
		for (Quote eachQuote : newQuotes) {
			eachQuote.ELV_Billing_Schedule_Total_Amount__c = 0;
		}
	}

	public static void setAICredits(List<Quote> quotes, Map<Id, Quote> oldMap) {
		List<Quote> eligibleQuotes = new List<Quote>();
		for (Quote quote : quotes) {
			if (
				quote.Calculated_Annualized_Software_Spend__c !=
				oldMap.get(quote.Id).Calculated_Annualized_Software_Spend__c
			) {
				eligibleQuotes.add(quote);
			}
		}
		if (!eligibleQuotes.isEmpty()) {
			List<AI_Credit_Tier__c> tiers = getAICreditTiers();

			for (Quote eligibleQuote : eligibleQuotes) {
				Decimal annualizedSoftwareSpend =
					eligibleQuote.Calculated_Annualized_Software_Spend__c ?? 0;
				Decimal totalAICredits = 0;
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
	}

	public static void processBillingScheduleOnOpportunity(
		List<Quote> newQuotes,
		Map<Id, Quote> oldQuotes
	) {
		Set<Id> oppIdsForBillingUpdates = new Set<Id>();
		for (Quote eachQuote : newQuotes) {
			if (eachQuote.Ruby__IsPrimaryQuote__c != oldQuotes.get(eachQuote.Id).Ruby__IsPrimaryQuote__c) {
				oppIdsForBillingUpdates.add(eachQuote.OpportunityId);
			}
		}
		if (!oppIdsForBillingUpdates.isEmpty()) {
			updateBillingScheduleFuture(oppIdsForBillingUpdates);
		}
	}

	public static void updateBillingSchedules(Set<Id> oppIdsForBillingUpdates) {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteTriggerHandler'
			}
		);
		try {
			List<Billing_Schedule__c> billingsToUpdate = new List<Billing_Schedule__c>();
			List<Billing_Schedule__c> billingsSelected = [
				SELECT Id, Opportunity__c, ELV_Quote__r.Ruby__IsPrimaryQuote__c, ELV_Quote__r.OpportunityId
				FROM Billing_Schedule__c
				WHERE ELV_Quote__r.OpportunityId IN :oppIdsForBillingUpdates
			];
			for (Billing_Schedule__c eachBilling : billingsSelected) {
				if (eachBilling.ELV_Quote__r.Ruby__IsPrimaryQuote__c == true) {
					eachBilling.Opportunity__c = eachBilling.ELV_Quote__r.OpportunityId;
				} else {
					eachBilling.Opportunity__c = null;
				}
				billingsToUpdate.add(eachBilling);
			}
			List<Database.SaveResult> saveResults = Database.update(billingsToUpdate, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'QuoteTriggerUtility.updateBillingSchedules ERRORS',
					saveResults
				)
				.addTag('apex');
		} catch (Exception e) {
			Logger.error('QuoteTriggerUtility.updateBillingSchedules ERRORS', e);
		}
		Logger.saveLog();
	}

	public static void updateBillingQuoteTerms(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
		for (Quote eachQuote : newQuotes) {
			if (
				oldMap != null &&
				(eachQuote.ELV_Do_Not_Show_Dates__c != oldMap.get(eachQuote.Id).ELV_Do_Not_Show_Dates__c ||
				(eachQuote.Ruby__PaymentTerm__c != null &&
				eachQuote.Ruby__PaymentTerm__c != oldMap.get(eachQuote.Id).Ruby__PaymentTerm__c))
			) {
				BillingScheduleConfiguratorController.updateBillingInformationOnQuote(
					eachQuote.Id,
					eachQuote.ELV_First_Billing_Override__c
				);
			}
		}
	}

	public static void processIdentifyNewModules(List<Quote> quotes, Map<Id, Quote> oldMap) {
		List<Quote> quotesToIdentifyNewModules = new List<Quote>();
		for (Quote quote : quotes) {
			if (quote.ELV_LastCalculatedOn__c != oldMap.get(quote.Id).ELV_LastCalculatedOn__c) {
				quotesToIdentifyNewModules.add(quote);
			}
		}
		if (!quotesToIdentifyNewModules.isEmpty()) {
			identifyNewModules(quotesToIdentifyNewModules);
		}
	}

	public static void identifyNewModules(List<Quote> quotes) {
		List<Quote> quotesToUpdate = new List<Quote>();
		Map<Id, Id> quoteIdToAccountId = new Map<Id, Id>();
		for (Quote quote : quotes) {
			quoteIdToAccountId.put(quote.Id, quote.AccountId);
		}

		Map<Id, Set<String>> accountIdToEntitlementModuleNames = getAccountIdToEntitlementModuleNames(
			new Set<Id>(quoteIdToAccountId.values())
		);

		Set<Id> productIds = new Set<Id>();
		List<QuoteLineItem> quoteLines = [
			SELECT Id, PricebookEntry.Product2Id, QuoteId
			FROM QuoteLineItem
			WHERE QuoteId IN :quoteIdToAccountId.keySet()
		];
		for (QuoteLineItem quoteLine : quoteLines) {
			productIds.add(quoteLine.PricebookEntry.Product2Id);
		}

		Map<Id, Set<String>> productIdToProductModuleNames = ProductUtility.getProductIdToProductModuleNames(
			productIds
		);

		Map<Id, Set<String>> quoteIdToProductModuleNames = new Map<Id, Set<String>>();
		for (QuoteLineItem quoteLine : quoteLines) {
			if (!quoteIdToProductModuleNames.containsKey(quoteLine.QuoteId)) {
				quoteIdToProductModuleNames.put(quoteLine.QuoteId, new Set<String>());
			}
			if (productIdToProductModuleNames.containsKey(quoteLine.PricebookEntry.Product2Id)) {
				quoteIdToProductModuleNames.get(quoteLine.QuoteId)
					?.addAll(productIdToProductModuleNames.get(quoteLine.PricebookEntry.Product2Id));
			}
		}

		for (Quote quote : quotes) {
			if (quoteIdToProductModuleNames.get(quote.Id) != null) {
				Set<String> productModuleDifference = quoteIdToProductModuleNames.get(quote.Id)?.clone();

				if (accountIdToEntitlementModuleNames.get(quoteIdToAccountId.get(quote.Id)) != null) {
					productModuleDifference.removeAll(
						accountIdToEntitlementModuleNames.get(quoteIdToAccountId.get(quote.Id))
					);
				}

				quotesToUpdate.add(
					new Quote(
						Id = quote.Id,
						ELV_Newly_Quoted_Modules__c = String.join(productModuleDifference, ', ')
					)
				);
			}
		}

		List<Database.SaveResult> saveResults = Database.update(quotesToUpdate, false);
		Logger.logDatabaseErrors(
			LoggingLevel.ERROR,
			'QuoteTriggerUtility.identifyNewModules Errors',
			saveResults
		);
		Logger.saveLog();
	}

	public static void handleDeletedQuotes(List<Quote> oldQuotes) {
		Map<Id, Billing_Schedule__c> billingMap = new Map<Id, Billing_Schedule__c>(
			[SELECT Id FROM Billing_Schedule__c WHERE ELV_Quote__c IN :oldQuotes]
		);
		if (!billingMap.isEmpty()) {
			QuoteTriggerUtility.deleteBillingSchedulesFuture(billingMap.keySet());
		}
	}

	public static void deleteBillingSchedulesFuture(Set<Id> billingIdsToDelete) {
		deleteBillingSchedules(billingIdsToDelete);
	}

	public static void deleteBillingSchedules(Set<Id> billingIdsToDelete) {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteTriggerHandler'
			}
		);
		try {
			List<Billing_Schedule__c> billingsToDelete = [
				SELECT Id
				FROM Billing_Schedule__c
				WHERE Id IN :billingIdsToDelete
			];
			List<Database.DeleteResult> deleteResults = Database.delete(billingsToDelete, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'QuoteTriggerUtility.deleteBillingSchedules ERRORS',
					deleteResults
				)
				.addTag('apex');
		} catch (Exception e) {
			Logger.error('QuoteTriggerUtility.deleteBillingSchedules ERRORS', e);
		}
		Logger.saveLog();
	}

	@future
	private static void updateBillingScheduleFuture(Set<Id> oppIdsForBillingUpdates) {
		updateBillingSchedules(oppIdsForBillingUpdates);
	}

	private static void handleDefaultPartnerAccreditation(List<Quote> newQuotes, Set<String> partnerSet) {
		Map<Id, Account> mapAccount = new Map<Id, Account>(
			[SELECT Id, Partner_Accreditations__c, Business_Motion__c FROM Account WHERE Id IN :partnerSet]
		);
		for (Quote eachQuote : newQuotes) {
			String partnerAccreditation = '';
			if (mapAccount.get(eachQuote.ELV_L1_L2_Support_Partner__c) != null) {
				Account supportPartner = mapAccount.get(eachQuote.ELV_L1_L2_Support_Partner__c);
				if (!eachQuote.ELV_L1_L2_Support_Exception_Granted__c) {
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
			if (mapAccount.get(eachQuote.ELV_Deployment_Partner__c) != null) {
				Account deploymentPartner = mapAccount.get(eachQuote.ELV_Deployment_Partner__c);
				if (!eachQuote.ELV_Deployment_Exception_Granted__c) {
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

			eachQuote.ELV_Partner_Accreditation__c = partnerAccreditation.trim();
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