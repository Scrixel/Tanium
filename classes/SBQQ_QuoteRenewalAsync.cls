/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Renewal Quote Asynchronous processing
 * @Authors:  Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-6987	  2024-01-04    Created the Queueable class
 * SS-12364	  2026-01-23    Added call to method QuoteCPQTriggerUtility.identifyNewModules
 * SS-12833	  2026-03-16    Revert Identify New Modules related code
 * SS-13086	  2026-05-19    Replace Level_3_Sub_Area__c with Account.Region__c for US Federal detection; moved detection to constructor
 */
public with sharing class SBQQ_QuoteRenewalAsync implements Queueable {
	private SBQQ__Quote__c[] renewalQuotes;
	private Boolean firstIteration;
	private Boolean federalQuote;
	private SBQQ_QuoteRenewalAsync async;
	@TestVisible
	private Boolean doChainJob;
	private Id jobId;
	private Set<Id> productIdsToExclude;
	@TestVisible
	private Boolean submitSecondIteration; // variable used by test class

	public SBQQ_QuoteRenewalAsync(SBQQ__Quote__c[] renewalQuotes) {
		this(renewalQuotes, true);
	}

	public SBQQ_QuoteRenewalAsync(SBQQ__Quote__c[] renewalQuotes, Boolean firstIteration) {
		this.renewalQuotes = renewalQuotes;
		this.firstIteration = firstIteration;
		this.federalQuote = false;
		this.doChainJob = true;
		this.jobId = null;
		this.submitSecondIteration = false;
		this.setProductsToExclude();
		this.setFederalQuoteFlag();
	}

	// override interface execute method
	public void execute(QueueableContext context) {
		if (renewalQuotes.isEmpty()) {
			return;
		}
		if (firstIteration) {
			recalculateQuote1stIteration(renewalQuotes[0].Id, federalQuote, productIdsToExclude);
		} else {
			recalculateQuote2ndIteration(renewalQuotes.remove(0).Id);
		}
		if (renewalQuotes.isEmpty()) {
			return;
		}
		async = (firstIteration)
			? new SBQQ_QuoteRenewalAsync(renewalQuotes, false)
			: new SBQQ_QuoteRenewalAsync(renewalQuotes);
		jobId = (!this.doChainJob)
			? null
			: (firstIteration) ? System.enqueueJob(async, 10) : System.enqueueJob(async);
		submitSecondIteration = (!this.doChainJob && firstIteration) ? true : false; // for test class
	}

	@Future
	@TestVisible
	private static void recalculateQuote1stIteration(
		Id quoteId,
		Boolean federalQuote,
		Set<Id> productIdsToExclude
	) {
		SBQQ_ApiDataModels.QuoteModel quoteModel = null;
		SBQQ_ApiDataModels.QuoteModel savedQuoteModel = null;
		SBQQ_QuoteCalculator quoteCalculator = new SBQQ_QuoteCalculator();
		SBQQ_QuoteReader quoteReader = new SBQQ_QuoteReader();
		SBQQ_QuoteSaver quoteSaver = new SBQQ_QuoteSaver();
		Integer i = 0;
		Boolean excludeFromCalc;
		try {
			quoteModel = quoteReader.read(String.valueOf(quoteId));
		} catch (Exception e) {
			quoteModel = null;
		}
		if (quoteModel == null) {
			return;
		}
		SBQQ__QuoteLine__c[] quoteLines = [
			SELECT
				Id,
				Name,
				SBQQ__OptionType__c,
				Uplift_Output__c,
				SBQQ__RenewedSubscription__r.SBQQ__AdditionalDiscountAmount__c,
				SBQQ__RenewedSubscription__r.SBQQ__Discount__c,
				SBQQ__Product__c,
				SBQQ__Discount__c,
				SBQQ__AdditionalDiscountAmount__c
			FROM SBQQ__QuoteLine__c
			WHERE SBQQ__Quote__c = :quoteId
		];
		for (SBQQ__QuoteLine__c quoteLine : quoteLines) {
			excludeFromCalc = false;
			if (
				productIdsToExclude.contains(quoteLine.SBQQ__Product__c) ||
				quoteLine.SBQQ__OptionType__c == 'Component'
			) {
				excludeFromCalc = true;
			}
			if (federalQuote) {
				if (quoteLine.SBQQ__RenewedSubscription__r.SBQQ__AdditionalDiscountAmount__c > 0) {
					quoteModel.lineItems[i].record.SBQQ__AdditionalDiscountAmount__c = (excludeFromCalc)
						? quoteLine.SBQQ__AdditionalDiscountAmount__c
						: quoteLine.SBQQ__RenewedSubscription__r.SBQQ__AdditionalDiscountAmount__c;
				} else {
					quoteModel.lineItems[i].record.SBQQ__Discount__c = (excludeFromCalc)
						? quoteLine.SBQQ__Discount__c
						: quoteLine.SBQQ__RenewedSubscription__r.SBQQ__Discount__c;
				}
			} else {
				quoteModel.lineItems[i].record.SBQQ__Discount__c = (excludeFromCalc)
					? quoteLine.SBQQ__Discount__c
					: quoteLine.Uplift_Output__c;
			}
			i++;
		}
		try {
			savedQuoteModel = quoteSaver.save(quoteModel);
		} catch (Exception e) {
			savedQuoteModel = null;
		}
		if (savedQuoteModel == null) {
			return;
		}
		try {
			quoteCalculator.calculate(savedQuoteModel, 'SBQQ_CalculateCallback');
		} catch (Exception e) {
			Logger.error('SBQQ_QuoteRenewalAsync.recalculateQuote1stIteration Errors', e);
			Logger.saveLog();
		}
	}

	@Future
	@TestVisible
	private static void recalculateQuote2ndIteration(Id quoteId) {
		SBQQ_ApiDataModels.QuoteModel quoteModel = null;
		SBQQ_QuoteCalculator quoteCalculator = new SBQQ_QuoteCalculator();
		SBQQ_QuoteReader quoteReader = new SBQQ_QuoteReader();
		try {
			quoteModel = quoteReader.read(String.valueOf(quoteId));
		} catch (Exception e) {
			quoteModel = null;
		}
		if (quoteModel == null) {
			return;
		}
		try {
			quoteCalculator.calculate(quoteModel, 'SBQQ_CalculateCallback');
		} catch (Exception e) {
			Logger.error('SBQQ_QuoteRenewalAsync.recalculateQuote2ndIteration Errors', e);
			Logger.saveLog();
		}
	}

	@TestVisible
	private void setProductsToExclude() {
		productIdsToExclude = new Map<Id, Product2>(
				[SELECT Id FROM Product2 WHERE Bypass_Recalc_Batch_Job__c = TRUE]
			)
			.keySet();
	}

	@TestVisible
	private void setFederalQuoteFlag() {
		if (!firstIteration || renewalQuotes.isEmpty()) {
			return;
		}
		SBQQ__Quote__c quoteForFedCheck = [
			SELECT SBQQ__Account__r.Region__c
			FROM SBQQ__Quote__c
			WHERE Id = :renewalQuotes[0].Id
			LIMIT 1
		];
		this.federalQuote = (quoteForFedCheck.SBQQ__Account__r.Region__c == 'US Federal');
	}
}