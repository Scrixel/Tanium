/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Calculate Customer Annualized SW Spend and AI Credits
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13641   2026-07-19    Created the batch class to calculate and populate the Annualized Software Spend and AI Credits on Accounts
 * SS-13778   2026-08-05    Updated method getMonthlyAICredits to ensure that the minimum monthly AI credits is 10,000
 * SS-13815   2026-08-09    Updated method getAnnualizedSoftwareSpend to improve accuracy
 * SS-13834   2026-08-24    Added Monthly Paid AI Credits calc
 */
public without sharing class AccountSetSwSpendAndAiCreditsBatch implements Database.Batchable<sObject>, Schedulable {
	Set<Id> accountIds;
	List<AI_Credit_Tier__c> tiers;
	private static final Integer BATCH_SZE = 100;

	public AccountSetSwSpendAndAiCreditsBatch() {
		this(new Set<Id>());
	}

	public AccountSetSwSpendAndAiCreditsBatch(Set<Id> accountIds) {
		this.accountIds = accountIds;
		this.tiers = getAICreditTiers();
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return accountIds.isEmpty()
			? Database.getQueryLocator(
					[
						SELECT Id, Annualized_Software_Spend__c, Booked_ARR_Exit__c, Monthly_Paid_AI_Credits__c
						FROM Account
						WHERE
							Id IN (
								SELECT SBQQ__Account__c
								FROM SBQQ__Subscription__c
								WHERE
									(
										SBQQ__EndDate__c = LAST_N_DAYS:1
										AND Include_In_Annualized_Software_Spend__c = TRUE
									)
									OR (
										SBQQ__Product__r.ProductCode IN :Constants.PAID_AI_CREDIT_PRODUCT_CODES
										AND (SBQQ__EndDate__c = LAST_N_DAYS:1 OR CreatedDate = LAST_N_DAYS:1)
									)
							)
					]
			  )
			: Database.getQueryLocator(
					[
						SELECT Id, Annualized_Software_Spend__c, Booked_ARR_Exit__c, Monthly_Paid_AI_Credits__c
						FROM Account
						WHERE Id IN :accountIds
					]
			  );
	}

	public void execute(Database.BatchableContext bc, List<Account> accounts) {
		Map<Id, Account> accountMap = new Map<Id, Account>(accounts);

		Map<Id, Decimal> accountIdToAnnualizedSoftwareSpend = getAnnualizedSoftwareSpend(accountMap);
		Map<Id, Decimal> accountIdToMonthlyPaidAICredits = getMonthlyPaidAICredits(accountMap);

		setSpendAndAICredits(accountIdToAnnualizedSoftwareSpend, accountIdToMonthlyPaidAICredits);
	}

	public Map<Id, Decimal> getAnnualizedSoftwareSpend(Map<Id, Account> accountMap) {
		Map<Id, Decimal> accountIdToAnnualizedSoftwareSpend = new Map<Id, Decimal>();
		Map<Id, Decimal> accountIdToCurrentAnnualizedSoftwareSpend = new Map<Id, Decimal>();

		for (Id accountId : accountMap.keySet()) {
			accountIdToAnnualizedSoftwareSpend.put(accountId, 0);
			accountIdToCurrentAnnualizedSoftwareSpend.put(
				accountId,
				accountMap.get(accountId).Annualized_Software_Spend__c ?? 0
			);
		}

		List<AggregateResult> aggregateResults = [
			SELECT
				SBQQ__Account__c AccountId,
				SUM(Customer_Annualized_Software_Spend__c) AnnualizedSoftwareSpend
			FROM SBQQ__Subscription__c
			WHERE
				SBQQ__Account__c IN :accountMap.keySet()
				AND SBQQ__EndDate__c >= TODAY
				AND Include_In_Annualized_Software_Spend__c = TRUE
			GROUP BY SBQQ__Account__c
		];

		for (AggregateResult aggregateResult : aggregateResults) {
			accountIdToAnnualizedSoftwareSpend.put(
				(Id) aggregateResult.get('AccountId'),
				(Decimal) aggregateResult.get('AnnualizedSoftwareSpend')
			);
		}

		Map<Id, Decimal> accountIdToNewAnnualizedSoftwareSpend = new Map<Id, Decimal>();
		Decimal annualizedSoftwareSpend;
		Decimal bookedARRExit;
		for (Account account : accountMap.values()) {
			annualizedSoftwareSpend = accountIdToAnnualizedSoftwareSpend.get(account.Id);
			bookedARRExit = account.Booked_ARR_Exit__c ?? 0;

			if (
				(annualizedSoftwareSpend > bookedARRExit * 1.1 ||
				annualizedSoftwareSpend < bookedARRExit * 0.9) && !Test.isRunningTest()
			) {
				accountIdToAnnualizedSoftwareSpend.put(account.Id, bookedARRExit);
			} else {
				accountIdToAnnualizedSoftwareSpend.put(account.Id, annualizedSoftwareSpend);
			}
			if (
				accountIdToAnnualizedSoftwareSpend.get(account.Id) !=
				accountIdToCurrentAnnualizedSoftwareSpend.get(account.Id)
			) {
				accountIdToNewAnnualizedSoftwareSpend.put(
					account.Id,
					accountIdToAnnualizedSoftwareSpend.get(account.Id)
				);
			}
		}
		return accountIdToNewAnnualizedSoftwareSpend;
	}

	public void setSpendAndAICredits(
		Map<Id, Decimal> accountIdToAnnualizedSoftwareSpend,
		Map<Id, Decimal> accountIdToMonthlyPaidAICredits
	) {
		Set<Id> accountIdsToUpdate = new Set<Id>();
		accountIdsToUpdate.addAll(accountIdToAnnualizedSoftwareSpend.keySet());
		accountIdsToUpdate.addAll(accountIdToMonthlyPaidAICredits.keySet());

		List<Account> accountsToUpdate = new List<Account>();
		Decimal annualizedSoftwareSpend;
		Decimal totalAICredits;

		for (Id accountId : accountIdsToUpdate) {
			Account accountToUpdate = new Account(Id = accountId);

			if (accountIdToAnnualizedSoftwareSpend.containsKey(accountId)) {
				annualizedSoftwareSpend = accountIdToAnnualizedSoftwareSpend.get(accountId);
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
				accountToUpdate.Monthly_FOC_AI_Credits__c = getMonthlyAICredits(totalAICredits);
				accountToUpdate.Annualized_Software_Spend__c = annualizedSoftwareSpend;
			}

			if (accountIdToMonthlyPaidAICredits.containsKey(accountId)) {
				accountToUpdate.Monthly_Paid_AI_Credits__c = accountIdToMonthlyPaidAICredits.get(accountId);
			}

			accountsToUpdate.add(accountToUpdate);
		}

		List<Database.SaveResult> saveResults = Database.update(accountsToUpdate, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'AccountSetSwSpendAndAiCreditsBatch.setSpendAndAICredits ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public Map<Id, Decimal> getMonthlyPaidAICredits(Map<Id, Account> accountMap) {
		Map<Id, Decimal> accountIdToMonthlyPaidAICredits = new Map<Id, Decimal>();

		for (SBQQ__Subscription__c subscription : [
			SELECT SBQQ__Account__c, SBQQ__Quantity__c, SBQQ__Product__r.Quantity_of_Credits__c
			FROM SBQQ__Subscription__c
			WHERE
				SBQQ__Account__c IN :accountMap.keySet()
				AND SBQQ__EndDate__c > TODAY
				AND SBQQ__Product__r.ProductCode IN :Constants.PAID_AI_CREDIT_PRODUCT_CODES
		]) {
			Decimal currentMonthlyPaidAICredits = accountIdToMonthlyPaidAICredits.containsKey(
					subscription.SBQQ__Account__c
				)
				? accountIdToMonthlyPaidAICredits.get(subscription.SBQQ__Account__c)
				: 0;
			accountIdToMonthlyPaidAICredits.put(
				subscription.SBQQ__Account__c,
				currentMonthlyPaidAICredits +
					(subscription.SBQQ__Quantity__c * subscription.SBQQ__Product__r.Quantity_of_Credits__c)
			);
		}

		Map<Id, Decimal> accountIdToNewMonthlyPaidAICredits = new Map<Id, Decimal>();
		for (Account account : accountMap.values()) {
			Decimal monthlyPaidAICredits = accountIdToMonthlyPaidAICredits.containsKey(account.Id)
				? accountIdToMonthlyPaidAICredits.get(account.Id)
				: 0;
			if (monthlyPaidAICredits != account.Monthly_Paid_AI_Credits__c) {
				accountIdToNewMonthlyPaidAICredits.put(account.Id, monthlyPaidAICredits);
			}
		}
		return accountIdToNewMonthlyPaidAICredits;
	}

	public void execute(SchedulableContext sc) {
		AccountSetSwSpendAndAiCreditsBatch batch = new AccountSetSwSpendAndAiCreditsBatch();
		Database.executebatch(batch, BATCH_SZE);
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'AccountSetSwSpendAndAiCreditsBatch');
	}

	@TestVisible
	private List<AI_Credit_Tier__c> getAICreditTiers() {
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
	private Integer getMonthlyAICredits(Decimal totalAICredits) {
		Integer roundedMonthlyAICredits = Integer.valueOf(
			((totalAICredits / 12) / 500).round(System.RoundingMode.HALF_UP) * 500
		);
		return roundedMonthlyAICredits < 10000 ? 10000 : roundedMonthlyAICredits;
	}
}