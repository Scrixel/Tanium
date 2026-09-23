/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Calculates and builds BillingByQuoteLine__c records for a quote's primary quote lines, split across upfront/annual/quarterly and reverse/non-reverse billing schedules.
 * @Date: 2023-06-04
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-13619     2026-08-14      Migrated to standard QuoteLineItem
 * SS-14038     2026-09-22      Exclude Usage/summary lines and bill pre-tax line totals
 */
public with sharing class BillingScheduleService {
	static Map<BillingByQuoteLine__c, QuoteLineItem> billingsWithQuoteLines;
	@TestVisible
	static final String ANNUAL_PAYMENT_TYPE = BillingScheduleConfiguratorController.ANNUAL_PAYMENT_TYPE;
	@TestVisible
	static final String UPFRONT_PAYMENT_TYPE = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE;
	@TestVisible
	static final String CUSTOM_PAYMENT_TYPE = BillingScheduleConfiguratorController.CUSTOM_PAYMENT_TYPE;
	@TestVisible
	static final String QUARTERLY_PAYMENT_TYPE = BillingScheduleConfiguratorController.QUARTERLY_PAYMENT_TYPE;
	public static List<BillingByQuoteLine__c> getPrimaryQuoteLinesData(
		String recordId,
		String objectAPIName
	) {
		List<BillingByQuoteLine__c> billingsByQuoteLinesToInsert = new List<BillingByQuoteLine__c>();
		List<BillingByQuoteLine__c> newBillings = new List<BillingByQuoteLine__c>();
		String soql = BillingScheduleConfiguratorController.getSOQL(recordId, objectAPIName);
		List<QuoteLineItem> primaryQuoteLines = Database.query(soql);
		billingsWithQuoteLines = new Map<BillingByQuoteLine__c, QuoteLineItem>();
		if (!primaryQuoteLines.isEmpty()) {
			if (
				primaryQuoteLines[0].Quote.Ruby__SellerTotalAmount__c == 0 &&
				BillingScheduleConfiguratorController.billingScheduleExists(primaryQuoteLines)
			) {
				BillingScheduleConfiguratorController.deleteBillingsAndUpdateQuote(
					primaryQuoteLines[0].QuoteId
				);
				return new List<BillingByQuoteLine__c>();
			}
			Date firstBillDate = primaryQuoteLines[0].Quote.Opportunity.CloseDate;
			Boolean firstBillingOverride = primaryQuoteLines[0].Quote.ELV_First_Billing_Override__c;
			Boolean existingIsReverseBilling = (firstBillingOverride == true
				? true
				: BillingScheduleConfiguratorController.getDefaultReverseBilling(primaryQuoteLines[0]));
			String existingPaymentType = BillingScheduleConfiguratorController.getDefaultPaymentType(
				primaryQuoteLines
			);

			for (QuoteLineItem eachQuoteLine : primaryQuoteLines) {
				if (!eachQuoteLine.ELV_BillingByQuoteLines__r.isEmpty()) {
					existingPaymentType = eachQuoteLine.ELV_BillingByQuoteLines__r[0].PaymentType__c;
					if (!firstBillingOverride) {
						existingIsReverseBilling = eachQuoteLine.ELV_BillingByQuoteLines__r[0].IsReverseBilling__c;
					}
				}
			}
			if (
				BillingScheduleConfiguratorController.PAYMENT_TYPES_RESTRICTED_FROM_AUTOMATION.contains(
					existingPaymentType
				)
			) {
				return new List<BillingByQuoteLine__c>();
			}
			for (QuoteLineItem eachQuoteLine : primaryQuoteLines) {
				List<BillingByQuoteLine__c> billingsByQuoteLines = eachQuoteLine.ELV_BillingByQuoteLines__r;
				if (
					eachQuoteLine.Product2?.Billing_Type__c ==
					BillingScheduleConfiguratorController.USAGE_BILLING_TYPE ||
					eachQuoteLine.Ruby__LineType__c ==
					BillingScheduleConfiguratorController.SUMMARY_LINE_TYPE ||
					eachQuoteLine.ELV_Bundled_Product__c ||
					(eachQuoteLine.ELV_BillingQuoteLineNetTotal__c == 0 &&
					!eachQuoteLine.ELV_Bundle__c &&
					!eachQuoteLine.ELV_Bundled_Product__c)
				) {
					continue;
				}
				billingsByQuoteLinesToInsert.add(
					getNewBillingByQuoteLine(eachQuoteLine, existingPaymentType, existingIsReverseBilling)
				);
			}
			newBillings = runPaymentProcess(
				billingsByQuoteLinesToInsert,
				existingPaymentType,
				existingIsReverseBilling,
				firstBillingOverride,
				firstBillDate
			);
		}
		return newBillings;
	}

	private static BillingByQuoteLine__c getNewBillingByQuoteLine(
		QuoteLineItem quoteLine,
		String existingPaymentType,
		Boolean existingIsReverseBilling
	) {
		switch on existingPaymentType {
			when 'Installments' {
				existingPaymentType = 'Annual Installment';
			}
			when 'Upfront' {
				existingIsReverseBilling = false;
			}
		}
		BillingByQuoteLine__c newBillingByQuoteLine = new BillingByQuoteLine__c(
			BillAmount__c = 0,
			BillDate__c = null,
			BillingScheduleOrder__c = '1',
			IsReverseBilling__c = existingIsReverseBilling,
			PaymentType__c = existingPaymentType,
			ELV_QuoteLine__c = quoteLine.Id,
			Opportunity__c = quoteLine.Quote.OpportunityId,
			ELV_Quote__c = quoteLine.QuoteId
		);
		billingsWithQuoteLines.put(newBillingByQuoteLine, quoteLine);
		return newBillingByQuoteLine;
	}

	private static List<BillingByQuoteLine__c> runPaymentProcess(
		List<BillingByQuoteLine__c> billingByQuoteLines,
		String paymentType,
		Boolean isReverseBilling,
		Boolean firstBillingOverride,
		Date firstBillDate
	) {
		List<BillingByQuoteLine__c> newBillings = new List<BillingByQuoteLine__c>();
		switch on paymentType {
			when 'Upfront' {
				runUpfrontBillingProcess(billingByQuoteLines, paymentType);
				return billingByQuoteLines;
			}
			when 'Annual Installment' {
				if (isReverseBilling == true) {
					newBillings = runAnnualBillingReverseProcess(billingByQuoteLines, paymentType);
					if (firstBillingOverride) {
						updateFirstBillDates(newBillings, firstBillDate);
					}
				} else {
					newBillings = runAnnualBillingNotReverseProcess(billingByQuoteLines, paymentType);
				}
			}
			when 'Quarterly Installment' {
				if (isReverseBilling == true) {
					newBillings = runQuarterlyBillingReverseProcess(billingByQuoteLines, paymentType);
				} else {
					newBillings = runQuarterlyBillingNotReverseProcess(billingByQuoteLines, paymentType);
				}
			}
		}
		return newBillings;
	}

	private static List<BillingByQuoteLine__c> updateFirstBillDates(
		List<BillingByQuoteLine__c> billingByQuoteLines,
		Date firstBillDate
	) {
		Date earliestDate = firstBillDate;
		for (BillingByQuoteLine__c billingByQL : billingByQuoteLines) {
			if (billingByQL.BillingScheduleOrder__c == '1') {
				if (earliestDate < billingByQL.BillDate__c) {
					billingByQL.BillDate__c = earliestDate;
				} else {
					earliestDate = billingByQL.BillDate__c;
				}
			}
		}
		return billingByQuoteLines;
	}

	private static List<BillingByQuoteLine__c> runAnnualBillingNotReverseProcess(
		List<BillingByQuoteLine__c> billingByQuoteLines,
		String paymentType
	) {
		List<BillingByQuoteLine__c> billingByQuoteLinesToInsert = new List<BillingByQuoteLine__c>();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			QuoteLineItem quoteLine = billingsWithQuoteLines.get(billingByQuoteLine);
			if (quoteLine.Product2.Prorate_Billing__c == false) {
				calculateBillingsForNonProrated(billingByQuoteLine, quoteLine);
				billingByQuoteLinesToInsert.add(billingByQuoteLine);
			} else {
				List<BillingByQuoteLine__c> newBillings = calculateBillingsForProratedAnnualNotReverse(
					billingByQuoteLine,
					quoteLine
				);
				billingByQuoteLinesToInsert.addAll(newBillings);
			}
		}
		return billingByQuoteLinesToInsert;
	}

	private static List<BillingByQuoteLine__c> runAnnualBillingReverseProcess(
		List<BillingByQuoteLine__c> billingByQuoteLines,
		String paymentType
	) {
		List<BillingByQuoteLine__c> billingByQuoteLinesToInsert = new List<BillingByQuoteLine__c>();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			QuoteLineItem quoteLine = billingsWithQuoteLines.get(billingByQuoteLine);
			if (quoteLine.Product2.Prorate_Billing__c == false) {
				calculateBillingsForNonProrated(billingByQuoteLine, quoteLine);
				billingByQuoteLinesToInsert.add(billingByQuoteLine);
			} else {
				List<BillingByQuoteLine__c> newBillings = calculateBillingsForProratedAnnualReverse(
					billingByQuoteLine,
					quoteLine
				);
				billingByQuoteLinesToInsert.addAll(newBillings);
			}
		}
		return billingByQuoteLinesToInsert;
	}

	private static List<BillingByQuoteLine__c> runQuarterlyBillingNotReverseProcess(
		List<BillingByQuoteLine__c> billingByQuoteLines,
		String paymentType
	) {
		List<BillingByQuoteLine__c> billingByQuoteLinesToInsert = new List<BillingByQuoteLine__c>();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			QuoteLineItem quoteLine = billingsWithQuoteLines.get(billingByQuoteLine);
			if (quoteLine.Product2.Prorate_Billing__c == false) {
				calculateBillingsForNonProrated(billingByQuoteLine, quoteLine);
				billingByQuoteLinesToInsert.add(billingByQuoteLine);
			} else {
				List<BillingByQuoteLine__c> newBillings = calculateBillingsForProratedQuarterlyNotReverse(
					billingByQuoteLine,
					quoteLine
				);
				billingByQuoteLinesToInsert.addAll(newBillings);
			}
		}
		return billingByQuoteLinesToInsert;
	}

	private static List<BillingByQuoteLine__c> runQuarterlyBillingReverseProcess(
		List<BillingByQuoteLine__c> billingByQuoteLines,
		String paymentType
	) {
		List<BillingByQuoteLine__c> billingByQuoteLinesToInsert = new List<BillingByQuoteLine__c>();
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			QuoteLineItem quoteLine = billingsWithQuoteLines.get(billingByQuoteLine);
			if (quoteLine.Product2.Prorate_Billing__c == false) {
				calculateBillingsForNonProrated(billingByQuoteLine, quoteLine);
				billingByQuoteLinesToInsert.add(billingByQuoteLine);
			} else {
				List<BillingByQuoteLine__c> newBillings = calculateBillingsForProratedQuarterlyReverse(
					billingByQuoteLine,
					quoteLine
				);
				billingByQuoteLinesToInsert.addAll(newBillings);
			}
		}
		return billingByQuoteLinesToInsert;
	}

	private static void calculateBillingsForNonProrated(
		BillingByQuoteLine__c billingByQuoteLine,
		QuoteLineItem quoteLine
	) {
		billingByQuoteLine.BillAmount__c = getQuoteLineNetTotal(quoteLine);
		billingByQuoteLine.BillDate__c = getQuoteLineStartDate(quoteLine);
	}

	private static List<BillingByQuoteLine__c> calculateBillingsForProratedAnnualReverse(
		BillingByQuoteLine__c billingByQuoteLine,
		QuoteLineItem quoteLine
	) {
		List<BillingByQuoteLine__c> newBillings = new List<BillingByQuoteLine__c>();
		Decimal totalBillingAmountToDate = 0;
		Date quoteLineStartDate = getQuoteLineStartDate(quoteLine);
		Date quoteLineEndDate = getQuoteLineEndDate(quoteLine);
		Decimal monthsBetweenQuoteStartEndDate = getQuoteLineTermComputed(quoteLine);
		Decimal quotelineNetTotal = getQuoteLineNetTotal(quoteLine);
		Integer noOfInstallments = calculateNoOfInstallments(monthsBetweenQuoteStartEndDate);
		Decimal installmentPerMonth = quotelineNetTotal / monthsBetweenQuoteStartEndDate;
		for (Integer i = 0; i < noOfInstallments; i++) {
			BillingByQuoteLine__c newBilling = getNewBillingByQuoteLine(
				quoteLine,
				ANNUAL_PAYMENT_TYPE,
				true
			);
			newBilling.BillingScheduleOrder__c = String.valueOf(i + 1);
			if (i == 0) {
				calculateFirstBillingForReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					newBilling,
					monthsBetweenQuoteStartEndDate,
					12
				);
			} else if (i == noOfInstallments - 1) {
				calculateLastBillingForAnnualReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					totalBillingAmountToDate,
					newBilling,
					newBillings
				);
			} else {
				calculateDefaultBillingForAnnualReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					newBilling,
					newBillings
				);
			}
			totalBillingAmountToDate = totalBillingAmountToDate + newBilling.BillAmount__c;
			if (newBilling.BillAmount__c > 0) {
				newBillings.add(newBilling);
			}
		}
		return newBillings;
	}

	private static List<BillingByQuoteLine__c> calculateBillingsForProratedQuarterlyReverse(
		BillingByQuoteLine__c billingByQuoteLine,
		QuoteLineItem quoteLine
	) {
		List<BillingByQuoteLine__c> newBillings = new List<BillingByQuoteLine__c>();
		Decimal totalBillingAmountToDate = 0;
		Date quoteLineStartDate = getQuoteLineStartDate(quoteLine);
		Date quoteLineEndDate = getQuoteLineEndDate(quoteLine);
		Decimal monthsBetweenQuoteStartEndDate = getQuoteLineTermComputed(quoteLine);
		Decimal quotelineNetTotal = getQuoteLineNetTotal(quoteLine);
		Integer noOfInstallments = Math.ceil(monthsBetweenQuoteStartEndDate / 3).intValue();
		Decimal installmentPerMonth = quotelineNetTotal / monthsBetweenQuoteStartEndDate;
		for (Integer i = 0; i < noOfInstallments; i++) {
			BillingByQuoteLine__c newBilling = getNewBillingByQuoteLine(
				quoteLine,
				QUARTERLY_PAYMENT_TYPE,
				true
			);
			newBilling.BillingScheduleOrder__c = String.valueOf(i + 1);
			if (i == 0) {
				calculateFirstBillingForReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					newBilling,
					monthsBetweenQuoteStartEndDate,
					3
				);
			} else if (i == noOfInstallments - 1) {
				calculateLastBillingForQuarterlyReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					totalBillingAmountToDate,
					newBilling,
					newBillings,
					monthsBetweenQuoteStartEndDate
				);
			} else {
				calculateDefaultBillingForQuarterlyReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					newBilling,
					newBillings,
					monthsBetweenQuoteStartEndDate
				);
			}
			totalBillingAmountToDate = totalBillingAmountToDate + newBilling.BillAmount__c;
			if (newBilling.BillAmount__c > 0) {
				newBillings.add(newBilling);
			}
		}
		return newBillings;
	}

	private static void calculateFirstBillingForReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		BillingByQuoteLine__c newBilling,
		Decimal monthsBetweenQuoteStartEndDate,
		Integer splitType
	) {
		newBilling.BillDate__c = quotelineStartDate;
		switch on noOfInstallments {
			when 1 {
				newBilling.BillAmount__c = quotelineNetTotal;
			}
			when else {
				if (Math.mod(noOfInstallments, splitType) == 0) {
					newBilling.BillAmount__c = (installmentPerMonth * splitType).setScale(2);
				} else {
					Decimal totalAnnualAmount = 0;
					for (Integer i = 0; i < noOfInstallments - 1; i++) {
						totalAnnualAmount += (installmentPerMonth * splitType).setScale(2);
					}
					newBilling.BillAmount__c = quotelineNetTotal.setScale(2) - totalAnnualAmount;
				}
			}
		}
	}

	private static void calculateLastBillingForAnnualReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		Decimal totalBillingAmountToDate,
		BillingByQuoteLine__c newBilling,
		List<BillingByQuoteLine__c> newBillings
	) {
		newBilling.BillAmount__c = (quotelineNetTotal - totalBillingAmountToDate).setScale(2);
		newBilling.BillDate__c = Date.newInstance(
			quoteLineEndDate.year() - 1,
			quoteLineEndDate.month(),
			quoteLineEndDate.day()
		);
		newBilling.BillDate__c = newBilling.BillDate__c.addDays(1);
	}

	private static void calculateLastBillingForQuarterlyReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		Decimal totalBillingAmountToDate,
		BillingByQuoteLine__c newBilling,
		List<BillingByQuoteLine__c> newBillings,
		Decimal monthsBetweenQuoteStartEndDate
	) {
		newBilling.BillAmount__c = (quotelineNetTotal - totalBillingAmountToDate).setScale(2);
		newBilling.BillDate__c = quoteLineStartDate.addMonths((noOfInstallments - 1) * 3);
		if (Math.mod(Math.ceil(monthsBetweenQuoteStartEndDate).intValue(), 3) == 0) {
			newBilling.BillDate__c = quotelineStartDate.addMonths((noOfInstallments - 1) * 3);
		} else if (newBilling.BillingScheduleOrder__c != '2') {
			Integer newBillingsSize = newBillings.size();
			Date priorBillDate = newBillings.size() > 0
				? newBillings[newBillings.size() - 1].BillDate__c
				: null;
			if (priorBillDate != null) {
				newBilling.BillDate__c = priorBillDate.addMonths(3);
			}
		} else if (newBilling.BillingScheduleOrder__c == '2') {
			calculateDefaultBillingForQuarterlyReverse(
				quoteLineStartDate,
				quoteLineEndDate,
				quotelineNetTotal,
				noOfInstallments,
				installmentPerMonth,
				newBilling,
				newBillings,
				monthsBetweenQuoteStartEndDate
			);
		}
	}

	private static void calculateDefaultBillingForAnnualReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		BillingByQuoteLine__c newBilling,
		List<BillingByQuoteLine__c> newBillings
	) {
		newBilling.BillAmount__c = (installmentPerMonth * 12).setScale(2);
		Integer monthsBetween2PaymentsInFirstYear = monthsBetween2PaymentsInFirstYear(
			quoteLineStartDate,
			quoteLineEndDate
		);
		if (newBilling.BillingScheduleOrder__c == '2' && monthsBetween2PaymentsInFirstYear >= 0) {
			newBilling.BillDate__c = Date.newInstance(
				quoteLineStartDate.year(),
				quoteLineEndDate.month(),
				quoteLineEndDate.day()
			);
			if (newBilling.BillDate__c.month() <= quotelineStartDate.month()) {
				newBilling.BillDate__c = newBilling.BillDate__c.addYears(1).addDays(1);
			} else if (newBilling.BillDate__c.month() > quotelineStartDate.month()) {
				newBilling.BillDate__c = newBilling.BillDate__c.addDays(1);
			}
		} else if (newBilling.BillingScheduleOrder__c == '2' && monthsBetween2PaymentsInFirstYear < 0) {
			newBilling.BillDate__c = Date.newInstance(
					quoteLineStartDate.year(),
					quoteLineEndDate.month(),
					quoteLineEndDate.day()
				)
				.addYears(1)
				.addDays(1);
		} else {
			newBilling.BillDate__c = newBillings.get(newBillings.size() - 1).BillDate__c;
			newBilling.BillDate__c = newBilling.BillDate__c.addYears(1);
		}
	}

	private static void calculateDefaultBillingForQuarterlyReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		BillingByQuoteLine__c newBilling,
		List<BillingByQuoteLine__c> newBillings,
		Decimal monthsBetweenQuoteStartEndDate
	) {
		newBilling.BillAmount__c = (installmentPerMonth * 3).setScale(2);
		Date billDate;
		if (Math.mod(Math.ceil(monthsBetweenQuoteStartEndDate).intValue(), 3) == 0) {
			billDate = quotelineStartDate.addMonths(
				(Integer.valueOf(newBilling.BillingScheduleOrder__c) - 1) * 3
			);
		} else {
			if (newBilling.BillingScheduleOrder__c == '2') {
				billDate = Date.newInstance(
					quotelineStartDate.year(),
					quotelineEndDate.month(),
					quotelineEndDate.day()
				);
				Integer diff = quotelineStartDate.monthsBetween(billDate);
				if (diff < 0) {
					billDate = Date.newInstance(
						quotelineStartDate.year() + 1,
						quotelineEndDate.month(),
						quotelineEndDate.day()
					);
					diff = quotelineStartDate.monthsBetween(billDate);
				}
				diff++;

				if (diff > 0 && diff <= 3) {
					billDate = quotelineStartDate.addMonths(diff);
				} else if (diff > 3 && diff <= 6) {
					billDate = quotelineStartDate.addMonths(diff - 3);
				} else if (diff > 6 && diff <= 9) {
					billDate = quotelineStartDate.addMonths(diff - 6);
				} else if (diff > 9) {
					billDate = quotelineStartDate.addMonths(diff - 9);
				}
			} else if (newBillings.size() > 0) {
				Date priorBillDate = newBillings[newBillings.size() - 1].BillDate__c;
				priorBillDate = priorBillDate.addMonths(3);
				billDate = Date.newInstance(
					priorBillDate.year(),
					priorBillDate.month(),
					priorBillDate.day()
				);
			}
		}
		newBilling.BillDate__c = billDate;
	}

	private static Integer monthsBetween2PaymentsInFirstYear(
		Date quoteLineStartDate,
		Date quoteLineEndDate
	) {
		Integer monthsBetween2PaymentsInFirstYear = 0;
		Date billEndDate = Date.newInstance(quotelineStartDate.year(), quotelineEndDate.month(), 1);
		monthsBetween2PaymentsInFirstYear = quotelineStartDate.monthsBetween(billEndDate) + 1;
		return monthsBetween2PaymentsInFirstYear;
	}

	private static List<BillingByQuoteLine__c> calculateBillingsForProratedAnnualNotReverse(
		BillingByQuoteLine__c billingByQuoteLine,
		QuoteLineItem quoteLine
	) {
		List<BillingByQuoteLine__c> newBillings = new List<BillingByQuoteLine__c>();
		Decimal totalBillingAmountToDate = 0;
		Date quoteLineStartDate = getQuoteLineStartDate(quoteLine);
		Date quoteLineEndDate = getQuoteLineEndDate(quoteLine);
		Decimal monthsBetweenQuoteStartEndDate = getQuoteLineTermComputed(quoteLine);
		Decimal quotelineNetTotal = getQuoteLineNetTotal(quoteLine);
		Integer noOfInstallments = calculateNoOfInstallments(monthsBetweenQuoteStartEndDate);
		Decimal installmentPerMonth = quotelineNetTotal / monthsBetweenQuoteStartEndDate;
		for (Integer i = 0; i < noOfInstallments; i++) {
			BillingByQuoteLine__c newBilling = getNewBillingByQuoteLine(
				quoteLine,
				ANNUAL_PAYMENT_TYPE,
				false
			);
			newBilling.BillingScheduleOrder__c = String.valueOf(i + 1);
			if (i == 0) {
				calculateFirstBillingForNonReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					ANNUAL_PAYMENT_TYPE,
					newBilling
				);
			} else if (i == noOfInstallments - 1) {
				calculateLastBillingForNonReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					totalBillingAmountToDate,
					ANNUAL_PAYMENT_TYPE,
					newBilling
				);
			} else {
				calculateDefaultBillingForNonReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					ANNUAL_PAYMENT_TYPE,
					newBilling
				);
			}
			totalBillingAmountToDate = totalBillingAmountToDate + newBilling.BillAmount__c;
			if (newBilling.BillAmount__c > 0) {
				newBillings.add(newBilling);
			}
		}
		return newBillings;
	}

	private static List<BillingByQuoteLine__c> calculateBillingsForProratedQuarterlyNotReverse(
		BillingByQuoteLine__c billingByQuoteLine,
		QuoteLineItem quoteLine
	) {
		List<BillingByQuoteLine__c> newBillings = new List<BillingByQuoteLine__c>();
		Decimal totalBillingAmountToDate = 0;
		Date quoteLineStartDate = getQuoteLineStartDate(quoteLine);
		Date quoteLineEndDate = getQuoteLineEndDate(quoteLine);
		Decimal monthsBetweenQuoteStartEndDate = getQuoteLineTermComputed(quoteLine);
		Decimal quotelineNetTotal = getQuoteLineNetTotal(quoteLine);
		Integer noOfInstallments = Math.ceil(monthsBetweenQuoteStartEndDate / 3).intValue();
		Decimal installmentPerMonth = quotelineNetTotal / monthsBetweenQuoteStartEndDate;
		for (Integer i = 0; i < noOfInstallments; i++) {
			BillingByQuoteLine__c newBilling = getNewBillingByQuoteLine(
				quoteLine,
				QUARTERLY_PAYMENT_TYPE,
				false
			);
			newBilling.BillingScheduleOrder__c = String.valueOf(i + 1);
			if (i == 0) {
				calculateFirstBillingForNonReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					QUARTERLY_PAYMENT_TYPE,
					newBilling
				);
			} else if (i == noOfInstallments - 1) {
				calculateLastBillingForNonReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					totalBillingAmountToDate,
					QUARTERLY_PAYMENT_TYPE,
					newBilling
				);
			} else {
				calculateDefaultBillingForNonReverse(
					quoteLineStartDate,
					quoteLineEndDate,
					quotelineNetTotal,
					noOfInstallments,
					installmentPerMonth,
					QUARTERLY_PAYMENT_TYPE,
					newBilling
				);
			}
			totalBillingAmountToDate = totalBillingAmountToDate + newBilling.BillAmount__c;
			if (newBilling.BillAmount__c > 0) {
				newBillings.add(newBilling);
			}
		}
		return newBillings;
	}

	private static Integer calculateNoOfInstallments(Decimal monthsBetweenQuoteStartEndDate) {
		Decimal noOfInstallments = 1;
		if (monthsBetweenQuoteStartEndDate > 0) {
			noOfInstallments = monthsBetweenQuoteStartEndDate / 12;
			if (noOfInstallments == 0) {
				return 1;
			}
		}
		return Math.ceil(noOfInstallments).intValue();
	}

	private static void calculateFirstBillingForNonReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		String paymentType,
		BillingByQuoteLine__c newBilling
	) {
		newBilling.BillDate__c = quotelineStartDate;
		switch on noOfInstallments {
			when 1 {
				newBilling.BillAmount__c = quotelineNetTotal;
			}
			when else {
				switch on paymentType {
					when 'Annual Installment' {
						newBilling.BillAmount__c = (installmentPerMonth * 12).setScale(2);
					}
					when 'Quarterly Installment' {
						newBilling.BillAmount__c = (installmentPerMonth * 3).setScale(2);
					}
				}
			}
		}
	}

	private static void calculateLastBillingForNonReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		Decimal totalBillingAmountToDate,
		String paymentType,
		BillingByQuoteLine__c newBilling
	) {
		newBilling.BillAmount__c = (quotelineNetTotal - totalBillingAmountToDate).setScale(2);
		switch on paymentType {
			when 'Annual Installment' {
				newBilling.BillDate__c = quoteLineStartDate.addYears(
					Integer.valueOf(newBilling.BillingScheduleOrder__c) - 1
				);
			}
			when 'Quarterly Installment' {
				newBilling.BillDate__c = quoteLineStartDate.addMonths(
					(Integer.valueOf(newBilling.BillingScheduleOrder__c) - 1) * 3
				);
			}
		}
	}

	private static void calculateDefaultBillingForNonReverse(
		Date quoteLineStartDate,
		Date quoteLineEndDate,
		Decimal quotelineNetTotal,
		Integer noOfInstallments,
		Decimal installmentPerMonth,
		String paymentType,
		BillingByQuoteLine__c newBilling
	) {
		switch on paymentType {
			when 'Annual Installment' {
				newBilling.BillAmount__c = (installmentPerMonth * 12).setScale(2);
				newBilling.BillDate__c = quoteLineStartDate.addYears(
					Integer.valueOf(newBilling.BillingScheduleOrder__c) - 1
				);
			}
			when 'Quarterly Installment' {
				newBilling.BillAmount__c = (installmentPerMonth * 3).setScale(2);
				newBilling.BillDate__c = quoteLineStartDate.addMonths(
					(Integer.valueOf(newBilling.BillingScheduleOrder__c) - 1) * 3
				);
			}
		}
	}

	@TestVisible
	private static Decimal getQuoteLineNetTotal(QuoteLineItem quoteLine) {
		return quoteLine.ELV_BillingQuoteLineNetTotal__c;
	}

	@TestVisible
	private static Date getQuoteLineStartDate(QuoteLineItem quoteLine) {
		return quoteLine.Ruby__SubscriptionStartDate__c ?? quoteLine.Quote.Ruby__SubscriptionStartDate__c;
	}

	@TestVisible
	private static Date getQuoteLineEndDate(QuoteLineItem quoteLine) {
		return quoteLine.Ruby__SubscriptionEndDate__c ?? quoteLine.ELV_End_Date__c;
	}

	@TestVisible
	private static Decimal getQuoteLineTermComputed(QuoteLineItem quoteLine) {
		return quoteLine.ELV_Term_Computed__c ?? 0;
	}

	private static void runUpfrontBillingProcess(
		List<BillingByQuoteLine__c> billingByQuoteLines,
		String paymentType
	) {
		for (BillingByQuoteLine__c billingByQuoteLine : billingByQuoteLines) {
			QuoteLineItem quoteLine = billingsWithQuoteLines.get(billingByQuoteLine);
			billingByQuoteLine.BillAmount__c = getQuoteLineNetTotal(quoteLine);
			billingByQuoteLine.BillDate__c = quoteLine.Quote.Opportunity.CloseDate;
			billingByQuoteLine.isReverseBilling__c = false;
		}
	}
}