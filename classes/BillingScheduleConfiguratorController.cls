/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class for BillingScheduleConfigurator
 * @Date: 2024-12-12
 * @Author: Savita Mirpuri
 * RequestId  ModifiedDate  Description
 * SS-9339    2024-12-16    Enable Quarterly Installment for Quotes with Partners having IsAllowedQuarterlyBilling__c = true
 * SS-10925   2025-05-20    Resolve SOQL Limit Error
 * SS-10464   2025-06-27    Added methods isCashWithOrderPaymentTerms, disablePaymentType and updated method getDefaultPaymentType
 * SS-11278   2025-07-10    Use custom metadata in Payment and Quoter Term Mapping
 * SS-13619   2026-08-14    Migrated to standard Quote/QuoteLineItem
 * SS-13942   2026-09-07    Exclude Ramp deal summary lines from Billing Net Total and Configurator
 * SS-14038   2026-09-22    Exclude Usage SKUs and bill pre-tax line totals
 */
public class BillingScheduleConfiguratorController {
	public static final String CUSTOM_PAYMENT_TYPE = 'Custom';
	public static final String QUARTERLY_PAYMENT_TYPE = 'Quarterly Installment';
	public static final String ANNUAL_PAYMENT_TYPE = 'Annual Installment';
	public static final String UPFRONT_PAYMENT_TYPE = 'Upfront';
	public static final String FOC = 'FOC';
	public static final String SUMMARY_LINE_TYPE = 'SummaryItem';
	public static final String USAGE_BILLING_TYPE = 'Usage';
	public static final List<String> PAYMENT_TYPES_RESTRICTED_FROM_AUTOMATION = new List<String>{
		CUSTOM_PAYMENT_TYPE
	};
	public static final List<String> PAYMENT_TYPES_NOT_RESTRICTED_FROM_AUTOMATION = new List<String>{
		ANNUAL_PAYMENT_TYPE,
		QUARTERLY_PAYMENT_TYPE,
		UPFRONT_PAYMENT_TYPE
	};
	public static final String DEFAULT_PAYMENT_TYPE = UPFRONT_PAYMENT_TYPE;
	public static final Boolean DEFAULT_IS_REVERSE_BILLING = false;
	private static Boolean hasFOCQuoteLine = false;

	@AuraEnabled
	public static SaveResult saveBillingsData(String billingsDataJSON) {
		Date opportunityCloseDate;
		Boolean firstBillingOverride = false;
		List<BillingByQuoteLine__c> billingsByQuoteLinesToInsert = new List<BillingByQuoteLine__c>();
		SaveResult saveResult;
		disableTriggers();
		try {
			for (
				BillingData eachBilling : (List<BillingData>) JSON.deserialize(
					billingsDataJSON,
					List<BillingScheduleConfiguratorController.BillingData>.class
				)
			) {
				opportunityCloseDate = eachBilling.oppCloseDate;
				firstBillingOverride = eachBilling.firstBillingOverride;
				billingsByQuoteLinesToInsert.addAll(eachBilling.billingsByQuoteLines);
			}
			saveResult = createBillingScheduleAndRelatedRecords(
				billingsByQuoteLinesToInsert,
				opportunityCloseDate,
				firstBillingOverride
			);
		} catch (Exception e) {
			return new SaveResult(e);
		}
		return saveResult;
	}

	@AuraEnabled
	public static List<BillingData> getBillingByQuoteLines(String recordId, String objectAPIName) {
		List<BillingData> allBillingsData = new List<BillingData>();
		try {
			allBillingsData = getQuoteLinesData(recordId, objectAPIName);
		} catch (Exception e) {
			String errorMessage = getErrorMessage(e);
			allBillingsData.add(new BillingData(errorMessage));
			return allBillingsData;
		}
		return allBillingsData;
	}

	public static String getSOQL(String recordId, String objectAPIName) {
		String whereClause = '';
		switch on objectAPIName {
			when 'Opportunity' {
				whereClause =
					'WHERE Quote.OpportunityId = :recordId' +
					' AND Quote.Ruby__IsPrimaryQuote__c = TRUE ';
			}
			when else {
				whereClause = 'WHERE QuoteId = :recordId ';
			}
		}
		return 'SELECT ' +
			'Id, ' +
			'LineNumber, ' +
			'Ruby__LineType__c, ' +
			'ELV_Bundled_Product__c, ' +
			'ELV_End_Date__c, ' +
			'ELV_Bundle__c, ' +
			'Ruby__SubscriptionStartDate__c, ' +
			'Ruby__SubscriptionEndDate__c, ' +
			'ELV_BillingQuoteLineNetTotal__c, ' +
			'ELV_OptionType__c, ' +
			'ELV_PackageTotal__c, ' +
			'Ruby__ProductName__c, ' +
			'Product2.Prorate_Billing__c, ' +
			'Product2.Billing_Type__c, ' +
			'QuoteId, ' +
			'Quote.Name, ' +
			'Quote.ELV_Partner__r.IsQuarterlyBillingAllowed__c, ' +
			'Quote.Opportunity.Account.IsQuarterlyBillingAllowed__c, ' +
			'Quote.ELV_First_Billing_Override__c, ' +
			'Quote.Ruby__SellerTotalAmount__c, ' +
			'Quote.OpportunityId, ' +
			'Quote.Opportunity.Name, ' +
			'Quote.Opportunity.CloseDate, ' +
			'Quote.Opportunity.StageName, ' +
			'Quote.Opportunity.Business_Motion__c, ' +
			'Quote.ELV_PaymentTypeNew__c, ' +
			'Quote.ELV_isReverseBilling__c, ' +
			'Quote.Ruby__IsPrimaryQuote__c, ' +
			'Quote.Ruby__SubscriptionStartDate__c, ' +
			'ELV_Term_Computed__c, ' +
			'ELV_SubscriptionPricing__c, ' +
			'ELV_Product_Promotion_Name__c, ' +
			'( ' +
			'SELECT ' +
			'Id, ' +
			'Name, ' +
			'BillAmount__c, ' +
			'BillDate__c, ' +
			'BillingScheduleOrder__c, ' +
			'IsReverseBilling__c, ' +
			'Opportunity__c, ' +
			'PaymentType__c, ' +
			'ELV_Quote__c ' +
			'FROM ELV_BillingByQuoteLines__r ' +
			'ORDER BY BillingScheduleOrder__c, BillDate__c' +
			') ' +
			'FROM QuoteLineItem ' +
			whereClause +
			'ORDER BY SortOrder ASC, Product2.Prorate_Billing__c DESC';
	}

	private static List<BillingData> getQuoteLinesData(String recordId, String objectAPIName) {
		BillingData data = new BillingData();
		List<BillingData> allBillingsData = new List<BillingData>();
		String soql = getSOQL(recordId, objectAPIName);
		List<QuoteLineItem> quoteLines = Database.query(soql);
		allBillingsData = getErrorsInQuote(quoteLines);
		if (!allBillingsData.isEmpty()) {
			return allBillingsData;
		}
		String existingPaymentType = getDefaultPaymentType(quoteLines);
		Boolean existingIsReverseBilling = getDefaultReverseBilling(quoteLines[0]);
		Integer index = 0;
		for (QuoteLineItem eachQuoteLine : quoteLines) {
			if (!BillingScheduleConfiguratorController.hasFOCQuoteLine) {
				BillingScheduleConfiguratorController.hasFOCQuoteLine = getFOCQuoteLine(eachQuoteLine);
			}
			if (!eachQuoteLine.ELV_BillingByQuoteLines__r.isEmpty() && index == 0) {
				existingPaymentType = eachQuoteLine.ELV_BillingByQuoteLines__r[0].PaymentType__c;
				existingIsReverseBilling = eachQuoteLine.ELV_BillingByQuoteLines__r[0]
					.IsReverseBilling__c;
				index++;
			}
		}
		for (QuoteLineItem eachQuoteLine : quoteLines) {
			List<BillingByQuoteLine__c> billingsByQuoteLines = eachQuoteLine.ELV_BillingByQuoteLines__r;
			if (
				PAYMENT_TYPES_NOT_RESTRICTED_FROM_AUTOMATION.contains(existingPaymentType) ||
				(existingPaymentType.contains(CUSTOM_PAYMENT_TYPE) && billingsByQuoteLines.isEmpty())
			) {
				billingsByQuoteLines = new List<BillingByQuoteLine__c>{
					getNewBillingByQuoteLine(
						eachQuoteLine,
						existingPaymentType,
						existingIsReverseBilling
					)
				};
			}
			data = getBillingData(eachQuoteLine, billingsByQuoteLines, recordId);
			if (data.oppName != null) {
				allBillingsData.add(data);
			}
		}
		return allBillingsData;
	}

	@TestVisible
	private static List<BillingData> getErrorsInQuote(List<QuoteLineItem> quoteLines) {
		List<BillingData> allBillingsData = new List<BillingData>();
		BillingData data = new BillingData();
		data.errorMessage = '';
		if (quoteLines.isEmpty()) {
			data.errorMessage = System.Label.Billing_Schedule_Configurator_no_quotes_lines_error;
		} else if (
			quoteLines[0].Quote.OpportunityId != null &&
			!profileHasAccessToConfiguratorTool(quoteLines[0].Quote.Opportunity.StageName)
		) {
			data.errorMessage = System.Label.Billing_Schedule_Configurator_Closed_Opportunity_Error;
		} else if (quoteLines[0].Quote.Ruby__SellerTotalAmount__c == 0) {
			if (billingScheduleExists(quoteLines)) {
				deleteBillingsAndUpdateQuote(quoteLines[0].QuoteId);
			}
			data.errorMessage = System.Label.Billing_Schedule_Configurator_Zero_Dollar_Quote_Error;
		} else if (String.isBlank(getDefaultPaymentType(quoteLines))) {
			data.errorMessage = System.Label.Billing_Schedule_Configurator_Retry_Error_Message;
		} else if (hasBlankStartDate(quoteLines)) {
			data.errorMessage = System.Label.Billing_Schedule_Configurator_Blank_Dates_Error;
		} else if (hasBlankTermComputed(quoteLines)) {
			data.errorMessage = System.Label.Billing_Schedule_Configurator_Blank_Term_Computed;
		}
		if (!String.isBlank(data.errorMessage)) {
			allBillingsData.add(data);
		}
		return allBillingsData;
	}

	private static BillingData getBillingData(
		QuoteLineItem quoteLine,
		List<BillingByQuoteLine__c> billingsByQuoteLines,
		Id recordId
	) {
		return new BillingData(billingsByQuoteLines, quoteLine, recordId);
	}

	private static BillingByQuoteLine__c getNewBillingByQuoteLine(
		QuoteLineItem eachQuoteLine,
		String existingPaymentType,
		Boolean existingIsReverseBilling
	) {
		BillingByQuoteLine__c newBillingByQuoteLine = new BillingByQuoteLine__c(
			BillAmount__c = 0,
			BillDate__c = null,
			BillingScheduleOrder__c = '1',
			Id = null,
			IsReverseBilling__c = existingIsReverseBilling,
			PaymentType__c = existingPaymentType,
			ELV_QuoteLine__c = eachQuoteLine.Id,
			ELV_Quote__c = eachQuoteLine.QuoteId
		);
		if (eachQuoteLine.Quote.Ruby__IsPrimaryQuote__c == true) {
			newBillingByQuoteLine.Opportunity__c = eachQuoteLine.Quote.OpportunityId;
		}
		return newBillingByQuoteLine;
	}

	@TestVisible
	public static SaveResult createBillingScheduleAndRelatedRecords(
		List<BillingByQuoteLine__c> billingsByQuoteLines,
		Date opportunityCloseDate,
		Boolean firstBillingOverride
	) {
		Savepoint databaseSavePoint = Database.setSavepoint();
		SaveResult saveResult = new SaveResult();
		try {
			deleteExistingBillingSchedules(billingsByQuoteLines[0].ELV_Quote__c, databaseSavepoint);

			createBillingsByQuoteLines(opportunityCloseDate, billingsByQuoteLines, databaseSavepoint);

			createBillingSchedules(
				billingsByQuoteLines[0].ELV_Quote__c,
				opportunityCloseDate,
				databaseSavepoint
			);

			linkParentAndChildren(billingsByQuoteLines[0].ELV_Quote__c, databaseSavepoint);

			saveResult = updateBillingInformationOnQuote(
				billingsByQuoteLines[0].ELV_Quote__c,
				firstBillingOverride
			);
		} catch (Exception e) {
			Database.rollback(databaseSavepoint);
			return new SaveResult(e);
		}
		return saveResult;
	}

	public static void deleteBillingsAndUpdateQuote(Id quoteId) {
		Savepoint databaseSavePoint = Database.setSavepoint();

		try {
			deleteExistingBillingSchedules(quoteId, databaseSavePoint);
			Quote quote = [
				SELECT Id, ELV_BillingQuoteTerms__c, ELV_isReverseBilling__c, ELV_PaymentTypeNew__c
				FROM Quote
				WHERE Id = :quoteId
			];
			quote.ELV_BillingQuoteTerms__c = '';
			quote.ELV_isReverseBilling__c = false;
			quote.ELV_PaymentTypeNew__c = UPFRONT_PAYMENT_TYPE;

			saveQuote(quote);
		} catch (Exception e) {
			Database.rollback(databaseSavepoint);
		}
	}

	private static void deleteExistingBillingSchedules(Id quoteId, Savepoint databaseSavepoint) {
		if (quoteId == null) {
			throw new IllegalArgumentException('Quote Id is required to delete billing schedules.');
		}
		List<Billing_Schedule__c> billingSchedulesToDelete = new List<Billing_Schedule__c>(
			[SELECT Id FROM Billing_Schedule__c WHERE ELV_Quote__c = :quoteId]
		);
		List<Database.DeleteResult> deleteResults = Utility.fireDeleteOnObject(
			billingSchedulesToDelete,
			databaseSavepoint,
			true
		);
	}

	private static void createBillingsByQuoteLines(
		Date opportunityCloseDate,
		List<BillingByQuoteLine__c> billingsByQuoteLines,
		Savepoint databaseSavepoint
	) {
		List<BillingByQuoteLine__c> billingsByQuoteLinesToInsert = new List<BillingByQuoteLine__c>();
		List<BillingByQuoteLine__c> billingsByQuoteLinesToUpdate = new List<BillingByQuoteLine__c>();
		Quote quoteAttached = [
			SELECT Ruby__IsPrimaryQuote__c, OpportunityId
			FROM Quote
			WHERE Id = :billingsByQuoteLines[0].ELV_Quote__c
		];
		for (BillingByQuoteLine__c each : billingsByQuoteLines) {
			BillingByQuoteLine__c billingByQuoteLine = new BillingByQuoteLine__c(
				BillAmount__c = each.BillAmount__c,
				BillDate__c = each.BillDate__c,
				BillingSchedule__c = null,
				BillingScheduleOrder__c = Integer.valueOf(each.BillingScheduleOrder__c).format(),
				Id = null,
				IsReverseBilling__c = each.IsReverseBilling__c,
				PaymentType__c = each.PaymentType__c,
				ELV_Quote__c = each.ELV_Quote__c,
				ELV_QuoteLine__c = each.ELV_QuoteLine__c
			);
			if (quoteAttached.Ruby__IsPrimaryQuote__c == true) {
				billingByQuoteLine.Opportunity__c = quoteAttached.OpportunityId;
			}
			billingsByQuoteLinesToInsert.add(billingByQuoteLine);
		}
		Utility.fireInsertOnObject(billingsByQuoteLinesToInsert, databaseSavepoint, true);
	}

	private static void createBillingSchedules(
		Id quoteId,
		Date opportunityCloseDate,
		Savepoint databaseSavepoint
	) {
		List<Billing_Schedule__c> billingSchedulesToInsert = new List<Billing_Schedule__c>();
		Integer billingOrder = 0;
		Date billDate = null;
		Date estimatedInvoiceDateOrder1;
		for (AggregateResult eachAggregatedResult : [
			SELECT
				SUM(BillAmount__c) totalBillAmount,
				BillDate__c,
				isReverseBilling__c,
				Opportunity__c,
				PaymentType__c,
				ELV_Quote__c
			FROM BillingByQuoteLine__c
			GROUP BY BillDate__c, isReverseBilling__c, Opportunity__c, PaymentType__c, ELV_Quote__c
			HAVING ELV_Quote__c = :quoteId
			ORDER BY BillDate__c
		]) {
			String paymentType = (String) eachAggregatedResult.get('PaymentType__c');
			billDate = (Date) eachAggregatedResult.get('BillDate__c');
			if (billingOrder == 0) {
				estimatedInvoiceDateOrder1 = billDate;
			}
			Billing_Schedule__c newBillingSchedule = new Billing_Schedule__c(
				Billing_Amount__c = (Decimal) eachAggregatedResult.get('totalBillAmount'),
				Billing_Date__c = billDate,
				Billing_Order__c = ++billingOrder,
				EstimatedInvoiceDateOrder1__c = estimatedInvoiceDateOrder1,
				isReverseBilling__c = (Boolean) eachAggregatedResult.get('isReverseBilling__c'),
				Opportunity__c = (Id) eachAggregatedResult.get('Opportunity__c'),
				PaymentType__c = (String) eachAggregatedResult.get('PaymentType__c'),
				ELV_Quote__c = (Id) eachAggregatedResult.get('ELV_Quote__c')
			);
			billingSchedulesToInsert.add(newBillingSchedule);
		}
		Utility.fireInsertOnObject(billingSchedulesToInsert, databaseSavepoint, true);
	}

	private static void linkParentAndChildren(Id quoteId, Savepoint databaseSavepoint) {
		Billing_Schedule__c billingOrder1 = new Billing_Schedule__c();
		List<BillingByQuoteLine__c> newlyCreatedChildren = new List<BillingByQuoteLine__c>(
			[
				SELECT Id, BillDate__c, BillingSchedule__c, BillingScheduleOrder__c
				FROM BillingByQuoteLine__c
				WHERE ELV_Quote__c = :quoteId
			]
		);
		for (Billing_Schedule__c eachParent : [
			SELECT Id, Billing_Date__c, Billing_Order__c, Opportunity__r.CloseDate
			FROM Billing_Schedule__c
			WHERE ELV_Quote__c = :quoteId
		]) {
			if (eachParent.Billing_Order__c == 1) {
				billingOrder1 = eachParent;
			}
			for (BillingByQuoteLine__c eachChild : newlyCreatedChildren) {
				if (
					eachChild.BillingSchedule__c == null &&
					eachChild.BillDate__c == eachParent.Billing_Date__c
				) {
					eachChild.BillingSchedule__c = eachParent.Id;
				}
			}
		}
		for (BillingByQuoteLine__c eachChild : newlyCreatedChildren) {
			if (
				eachChild.BillingSchedule__c == null &&
				Integer.valueOf(eachChild.BillingScheduleOrder__c) == 1
			) {
				eachChild.BillingSchedule__c = billingOrder1.Id;
			}
		}
		Utility.fireUpdateOnObject(newlyCreatedChildren, databaseSavepoint, true);
	}

	@TestVisible
	private static String saveQuote(Quote quote) {
		String warningMessage = '';
		Database.SaveResult saveResult = Database.update(quote, false);
		if (!saveResult.isSuccess()) {
			String errorMessage = BillingScheduleConfiguratorController.getErrorMessage(saveResult);
			warningMessage =
				System.Label.Billing_Schedule_Configurator_warning_when_Quote_Terms_not_saved +
				errorMessage;
			Logger.error('BillingScheduleConfiguratorController.saveQuote Errors', saveResult)
				.addTag('apex');
			Logger.saveLog();
		}
		return warningMessage;
	}

	public static SaveResult updateBillingInformationOnQuote(
		Id quoteId,
		Boolean firstBillingOverride
	) {
		String warningMessage = '';
		String billingScheduleFields = '';
		List<Billing_Schedule__c> billingSchedules;

		Quote quote = getQuote(quoteId);
		billingScheduleFields = BillingScheduleConfiguratorUtility.getBillingScheduleFields();
		billingSchedules = getBillingSchedules(quote.Id, billingScheduleFields);

		if (billingSchedules.isEmpty()) {
			warningMessage = 'No billing schedule record found.';
			return new SaveResult(warningMessage);
		}

		quote.ELV_isReverseBilling__c = billingSchedules[0].isReverseBilling__c;
		quote.ELV_PaymentTypeNew__c = billingSchedules[0].PaymentType__c;
		quote.ELV_First_Billing_Override__c = firstBillingOverride;
		quote.ELV_BillingQuoteTerms__c = getBillingQuoteTerms(
			quote,
			billingScheduleFields,
			billingSchedules
		);

		warningMessage = saveQuote(quote);
		return new SaveResult(warningMessage);
	}

	private static Quote getQuote(Id quoteId) {
		return [
			SELECT
				Id,
				ELV_BillingQuoteTerms__c,
				ELV_Do_Not_Show_Dates__c,
				ELV_First_Billing_Override__c,
				ELV_isReverseBilling__c,
				ELV_PaymentTypeNew__c,
				Ruby__PaymentTerm__c
			FROM Quote
			WHERE Id = :quoteId
		];
	}

	public static String getBillingQuoteTerms(
		Quote quote,
		String billingScheduleFields,
		List<Billing_Schedule__c> billingSchedules
	) {
		String billingQuoteTerm = '';
		String firstBillingQuoteTerm = '';
		String succeedingQuoteTerm = '';

		Map<String, String> paymentTermQuoteTermMap = getQuoteTermsForPaymentTerm(
			quote.Ruby__PaymentTerm__c
		);

		firstBillingQuoteTerm = paymentTermQuoteTermMap.get('First Billing');
		succeedingQuoteTerm = (quote.ELV_Do_Not_Show_Dates__c == true
			? paymentTermQuoteTermMap.get('Locked Dates')
			: paymentTermQuoteTermMap.get('Unlocked Dates'));

		for (Billing_Schedule__c billingSchedule : billingSchedules) {
			String quoteTerm = '';

			switch on billingSchedule.Billing_Order__c.format() {
				when '1' {
					quoteTerm = replaceQuoteTermVariables(
						firstBillingQuoteTerm,
						billingSchedule,
						billingScheduleFields
					);
				}
				when else {
					if (billingSchedule.Billing_Order__c > 1) {
						quoteTerm = replaceQuoteTermVariables(
							succeedingQuoteTerm,
							billingSchedule,
							billingScheduleFields
						);
					}
				}
			}
			billingQuoteTerm += quoteTerm;
		}
		return billingQuoteTerm;
	}

	private static Map<String, String> getQuoteTermsForPaymentTerm(String quotePaymentTerm) {
		Map<String, String> paymentTermQuoteTermMap = new Map<String, String>();
		Map<String, String> defaultQuoteTermMap = new Map<String, String>();
		Set<String> paymentTerms = new Set<String>{ quotePaymentTerm, 'Default' };

		for (Payment_and_Quote_Term_Mapping__mdt mapping : [
			SELECT Type__c, Quote_Term__c, Payment_Term__c
			FROM Payment_and_Quote_Term_Mapping__mdt
			WHERE Payment_Term__c IN :paymentTerms
		]) {
			if (mapping.Payment_Term__c == quotePaymentTerm) {
				paymentTermQuoteTermMap.put(mapping.Type__c, mapping.Quote_Term__c);
			} else {
				defaultQuoteTermMap.put(mapping.Type__c, mapping.Quote_Term__c);
			}
		}
		if (!paymentTermQuoteTermMap.isEmpty()) {
			return paymentTermQuoteTermMap;
		}

		return defaultQuoteTermMap;
	}

	private static List<Billing_Schedule__c> getBillingSchedules(
		Id quoteId,
		String billingScheduleFields
	) {
		String query =
			'SELECT ' +
			billingScheduleFields +
			' FROM Billing_Schedule__c' +
			' WHERE ELV_Quote__c = \'' +
			quoteId +
			'\'' +
			' ORDER BY Billing_Order__c ASC';
		return Database.query(query);
	}

	private static String replaceQuoteTermVariables(
		String metadataQuoteTerm,
		Billing_Schedule__c billingSchedule,
		String billingScheduleFields
	) {
		String quoteTerm = '';
		for (String field : billingScheduleFields.split(',')) {
			String value = '';
			field = field.trim();
			if (metadataQuoteTerm.contains(field)) {
				if (field == 'Billing_Amount__c') {
					value = BillingScheduleConfiguratorUtility.formatBillingAmount(
						(Decimal) billingSchedule.get(field)
					);
				} else if (field == 'Billing_Date__c') {
					value = BillingScheduleConfiguratorUtility.formatBillingDate(
						(Date) billingSchedule.get(field)
					);
				} else {
					if (billingSchedule.get(field) != null) {
						value = billingSchedule.get(field).toString();
					}
				}
				metadataQuoteTerm = metadataQuoteTerm.replace('{' + field + '}', value);
			}
		}
		quoteTerm = metadataQuoteTerm;
		return quoteTerm;
	}

	@AuraEnabled
	public static Boolean disablePaymentType(Id quoteId) {
		return isCashWithOrderPaymentTerms(quoteId);
	}

	private static Boolean isCashWithOrderPaymentTerms(Id quoteId) {
		return ([SELECT Id, Ruby__PaymentTerm__c FROM Quote WHERE Id = :quoteId]
		.Ruby__PaymentTerm__c == 'Cash with Order (CWO)');
	}

	public static String getDefaultPaymentType(List<QuoteLineItem> quoteLines) {
		if (disablePaymentType(quoteLines[0].QuoteId)) {
			return UPFRONT_PAYMENT_TYPE;
		}
		if (quoteLines[0].Quote.ELV_PaymentTypeNew__c != null) {
			return quoteLines[0].Quote.ELV_PaymentTypeNew__c;
		}
		return DEFAULT_PAYMENT_TYPE;
	}

	public static Boolean getDefaultReverseBilling(QuoteLineItem quoteLine) {
		if (quoteLine.Quote.ELV_PaymentTypeNew__c != null) {
			switch on quoteLine.Quote.ELV_PaymentTypeNew__c {
				when 'Annual Installment', 'Quarterly Installment' {
					return quoteLine.Quote.ELV_isReverseBilling__c;
				}
			}
		}
		return false;
	}

	private static Boolean getFOCQuoteLine(QuoteLineItem quoteLine) {
		return String.isNotBlank(quoteLine.ELV_SubscriptionPricing__c) &&
			quoteLine.ELV_Product_Promotion_Name__c == FOC;
	}

	@TestVisible
	private static Boolean profileHasAccessToConfiguratorTool(String oppStage) {
		List<String> restrictedOppStages = BillingScheduleConfiguratorUtility.getRestrictedOppStages();

		if (restrictedOppStages != null && restrictedOppStages.contains(oppStage.toLowerCase())) {
			String userProfile = BillingScheduleConfiguratorUtility.getProfileName();
			List<String> profilesWithAccess = BillingScheduleConfiguratorUtility.getProfilesWithRestrictedOppStageAccess();
			return profilesWithAccess.contains(userProfile);
		}
		return true;
	}

	@AuraEnabled
	public static Boolean profileHasRestrictedPaymentAccess() {
		String userProfile = BillingScheduleConfiguratorUtility.getProfileName();
		List<String> profilesWithAccess = BillingScheduleConfiguratorUtility.getProfilesWithRestrictedPaymentTypesAccess();
		return profilesWithAccess.contains(userProfile);
	}

	public static void disableTriggers() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
	}

	@TestVisible
	private static String getErrorMessage(Exception myException) {
		String errorMessage = '';
		if (myException != null) {
			errorMessage =
				myException.getMessage() +
				' ### StackTraceString: ' +
				myException.getStackTraceString();
		}
		return getUserFacingErrorMessage(errorMessage);
	}

	private static String getErrorMessage(Database.SaveResult sr) {
		String errorMessage = '';
		if (sr != null) {
			errorMessage =
				sr.getErrors()[0].getMessage() +
				' ### Fields: ' +
				sr.getErrors()[0].getFields() +
				' ### StatusCode: ' +
				sr.getErrors()[0].getStatusCode();
		}
		return getUserFacingErrorMessage(errorMessage);
	}

	@TestVisible
	private static String getUserFacingErrorMessage(String errorMessage) {
		if (errorMessage.containsIgnoreCase('LOCK')) {
			errorMessage = System.Label.Billing_Schedule_Configurator_locking_error;
		} else if (
			errorMessage.containsIgnoreCase(
				System.Label.Billing_Schedule_Configurator_Retry_Error_Types
			)
		) {
			errorMessage = System.Label.Billing_Schedule_Configurator_Retry_Error_Message;
		}
		return errorMessage;
	}

	private static Boolean hasBlankStartDate(List<QuoteLineItem> quoteLines) {
		for (QuoteLineItem quoteLine : quoteLines) {
			if (
				quoteLine.Ruby__SubscriptionStartDate__c == null &&
				quoteLine.Quote.Ruby__SubscriptionStartDate__c == null
			) {
				return true;
			}
		}
		return false;
	}

	@TestVisible
	private static Boolean hasBlankTermComputed(List<QuoteLineItem> quoteLines) {
		for (QuoteLineItem quoteLine : quoteLines) {
			if (quoteLine.ELV_Term_Computed__c == null || quoteLine.ELV_Term_Computed__c == 0) {
				return true;
			}
		}
		return false;
	}

	public static Boolean billingScheduleExists(List<QuoteLineItem> quoteLines) {
		for (QuoteLineItem eachQuoteLine : quoteLines) {
			if (!eachQuoteLine.ELV_BillingByQuoteLines__r.isEmpty()) {
				return true;
			}
		}
		return false;
	}

	public class BillingData {
		BillingData() {
		}

		@TestVisible
		BillingData(String errorMessage) {
			this.errorMessage = errorMessage;
		}

		@TestVisible
		BillingData(
			List<BillingByQuoteLine__c> billingsByQuoteLines,
			QuoteLineItem quoteLine,
			Id recordId
		) {
			if (
				quoteLine.Product2?.Billing_Type__c == USAGE_BILLING_TYPE ||
				quoteLine.Ruby__LineType__c == SUMMARY_LINE_TYPE ||
				quoteLine.ELV_Bundled_Product__c ||
				BillingScheduleConfiguratorUtility.getBundleOptionTypesNotShownInTool()
					.contains(quoteLine.ELV_OptionType__c)
			) {
				return;
			} else if (
				quoteLine.ELV_BillingQuoteLineNetTotal__c == 0 &&
				!quoteLine.ELV_Bundle__c &&
				!quoteLine.ELV_Bundled_Product__c
			) {
				return;
			} else if (quoteLine.ELV_PackageTotal__c == 0 && quoteLine.ELV_Bundle__c) {
				return;
			}
			this.billingsByQuoteLines = billingsByQuoteLines;
			this.quoteLineName = quoteLine.LineNumber;
			this.oppName = quoteLine.Quote.Opportunity.Name;
			this.oppCloseDate = quoteLine.Quote.Opportunity.CloseDate;
			this.quoteName = quoteLine.Quote.Name;
			this.quoteNetAmount = quoteLine.Quote.Ruby__SellerTotalAmount__c;
			this.quoteStartDate = quoteLine.Quote.Ruby__SubscriptionStartDate__c;
			this.firstBillingOverride = quoteLine.Quote.ELV_First_Billing_Override__c;
			this.quoteLineProduct = quoteLine.Ruby__ProductName__c;
			this.hasOptionType = quoteLine.ELV_OptionType__c != null ? true : false;
			this.hasFOCQuoteLine = BillingScheduleConfiguratorController.hasFOCQuoteLine;
			this.isBundle = quoteLine.ELV_Bundle__c;
			this.isBundledProduct = quoteLine.ELV_Bundled_Product__c;
			this.hasMisconfiguredBundledProduct =
				this.hasOptionType &&
				!this.isBundle &&
				!this.isBundledProduct &&
				quoteLine.ELV_BillingQuoteLineNetTotal__c > 0;
			this.isProrateBilling = quoteLine.Product2.Prorate_Billing__c;
			this.quoteLineNetTotal = quoteLine.ELV_BillingQuoteLineNetTotal__c;
			this.quoteLinePackageTotal = quoteLine.ELV_PackageTotal__c;
			this.quoteLineEffectiveStartDate = quoteLine.Ruby__SubscriptionStartDate__c;
			this.quoteLineEffectiveEndDate = quoteLine.Ruby__SubscriptionEndDate__c;
			this.quoteLineEndDate = quoteLine.ELV_End_Date__c;
			this.quoteLineTermComputed = quoteLine.ELV_Term_Computed__c;
			String quoteLineNetTotalStr = this.quoteLineNetTotal != null
				? BillingScheduleConfiguratorUtility.formatBillingAmount(this.quoteLineNetTotal)
				: '0.00';
			String quoteLineProductStr = this.quoteLineProduct != null ? this.quoteLineProduct : '';
			this.rowLabel =
				this.quoteLineName +
				' - ' +
				this.quoteLineProduct +
				' - ' +
				' $' +
				quoteLineNetTotalStr;
			this.errorMessage = '';
			this.paymentTypeOptions = BillingScheduleConfiguratorUtility.getPaymentTypeOptions(
				quoteLine
			);
			this.isQuarterlyAllowedForSalesRepsForPartnerAccount = this.paymentTypeOptions.contains(
				QUARTERLY_PAYMENT_TYPE
			);
		}

		@AuraEnabled
		public List<BillingByQuoteLine__c> billingsByQuoteLines { get; set; }

		@AuraEnabled
		public String errorMessage { get; set; }

		@AuraEnabled
		public Boolean hasOptionType { get; set; }

		@AuraEnabled
		public Boolean hasMisconfiguredBundledProduct { get; set; }

		@AuraEnabled
		public Boolean isBundle { get; set; }

		@AuraEnabled
		public Boolean isBundledProduct { get; set; }

		@AuraEnabled
		public Boolean isProrateBilling { get; set; }

		@AuraEnabled
		public String oppName { get; set; }

		@AuraEnabled
		public Date oppCloseDate { get; set; }

		@AuraEnabled
		public Date quoteLineEffectiveStartDate { get; set; }

		@AuraEnabled
		public Date quoteLineEffectiveEndDate { get; set; }

		@AuraEnabled
		public Date quoteLineEndDate { get; set; }

		@AuraEnabled
		public String quoteLineName { get; set; }

		@AuraEnabled
		public Decimal quoteLineNetTotal { get; set; }

		@AuraEnabled
		public Decimal quoteLinePackageTotal { get; set; }

		@AuraEnabled
		public String quoteLineProduct { get; set; }

		@AuraEnabled
		public Decimal quoteLineTermComputed { get; set; }

		@AuraEnabled
		public String quoteName { get; set; }

		@AuraEnabled
		public Decimal quoteNetAmount { get; set; }

		@AuraEnabled
		public Date quoteStartDate { get; set; }

		@AuraEnabled
		public String rowLabel { get; set; }

		@AuraEnabled
		public Boolean firstBillingOverride { get; set; }

		@AuraEnabled
		public Boolean hasFOCQuoteLine { get; set; }

		@AuraEnabled
		public List<String> paymentTypeOptions { get; set; }

		@AuraEnabled
		public Boolean isQuarterlyAllowedForSalesRepsForPartnerAccount { get; set; }
	}

	public class SaveResult {
		@TestVisible
		SaveResult() {
			this.isSuccess = true;
			this.errorMessage = '';
			this.warningMessage = '';
		}

		SaveResult(Exception e) {
			this.isSuccess = false;
			this.errorMessage = getErrorMessage(e);
			this.warningMessage = '';
		}

		SaveResult(String warningMessage) {
			this.isSuccess = true;
			this.errorMessage = '';
			this.warningMessage = warningMessage;
		}

		@AuraEnabled
		public Boolean isSuccess { get; set; }

		@AuraEnabled
		public String errorMessage { get; set; }

		@AuraEnabled
		public String warningMessage { get; set; }
	}

	class BillingScheduleConfiguratorException extends Exception {
	}
}