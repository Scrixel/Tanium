public class InvoiceLinkToBillingSchedule {
	public static void processInvoiceAmtAndDateChanges(
		Map<Id, Invoice__c> newInvoiceMap,
		Map<Id, Invoice__c> oldInvoiceMap
	) {
		Invoice__c oldInvoice, invoiceCheck;
		Map<Id, Billing_Schedule__c> invoicesWithBillings = new Map<Id, Billing_Schedule__c>();
		List<Invoice__c> invoicesToCheck = new List<Invoice__c>();
		Set<Invoice__c> invoicesToUpdate = new Set<Invoice__c>();
		for (Invoice__c newInvoice : newInvoiceMap.values()) {
			oldInvoice = oldInvoiceMap.get(newInvoice.Id);
			if (
				oldInvoice.Invoice_Date__c != newInvoice.Invoice_Date__c ||
				oldInvoice.Amount__c != newInvoice.Amount__c
			) {
				invoicesToCheck.add(newInvoice);
			}
		}
		if (!invoicesToCheck.isEmpty()) {
			for (Billing_Schedule__c eachBilling : [
				SELECT Id, Name, Billing_Amount__c, EstimatedPaymentDate__c, Invoice__c, Invoice_Date__c
				FROM Billing_Schedule__c
				WHERE Invoice__c IN :invoicesToCheck
			]) {
				invoiceCheck = newInvoiceMap.get(eachBilling.Invoice__c);
				InvoiceLinkToBillingSchedule.runInvoiceBillingMatchingCriteria(invoiceCheck, eachBilling);
				if (
					(invoiceCheck.ReconciliationSemiMatchReason__c !=
					newInvoiceMap.get(eachBilling.Invoice__c).ReconciliationSemiMatchReason__c) ||
					(invoiceCheck.ReconciliationStatus__c !=
					newInvoiceMap.get(eachBilling.Invoice__c).ReconciliationStatus__c)
				) {
					invoicesToUpdate.add(invoiceCheck);
				}
			}
		}
	}

	public static void processInvoiceDateAmountChange(
		Map<Id, Billing_Schedule__c> newBillingsMap,
		Map<Id, Billing_Schedule__c> oldBillingsMap
	) {
		Billing_Schedule__c oldBilling;
		Map<Id, Billing_Schedule__c> invoicesWithBillings = new Map<Id, Billing_Schedule__c>();
		for (Billing_Schedule__c newBilling : newBillingsMap.values()) {
			oldBilling = oldBillingsMap.get(newBilling.Id);
			if (
				oldBilling.Invoice__c != null &&
				(newBilling.ReconciliationStatus__c == 'Semi Match' ||
				newBilling.ReconciliationStatus__c == 'No Match' ||
				newBilling.ReconciliationStatus__c == 'Exact Match') &&
				(oldBilling.Invoice_Date__c != newBilling.Invoice_Date__c ||
				oldBilling.Billing_Amount__c != newBilling.Billing_Amount__c)
			) {
				invoicesWithBillings.put(newBilling.Invoice__c, newBilling);
			}
		}
		if (!invoicesWithBillings.isEmpty()) {
			InvoiceLinkToBillingSchedule.updateReconciliationOnInvoices(invoicesWithBillings);
		}
	}

	private static void updateReconciliationOnInvoices(
		Map<Id, Billing_Schedule__c> invoicesWithBillings
	) {
		Billing_Schedule__c eachBilling;
		List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();

		for (Invoice__c eachInvoice : [
			SELECT
				Id,
				Name,
				Amount__c,
				Invoice_Date__c,
				InvoicePaymentTerm__c,
				InvoiceStatus__c,
				ReconciliationStatus__c,
				ReconciliationSemiMatchReason__c,
				Opportunity__c
			FROM Invoice__c
			WHERE Id IN :invoicesWithBillings.keySet()
		]) {
			eachBilling = invoicesWithBillings.get(eachInvoice.Id);
			InvoiceLinkToBillingSchedule.runInvoiceBillingMatchingCriteria(eachInvoice, eachBilling);
			// update invoices only if recon changed
			if (
				eachInvoice.ReconciliationStatus__c != eachBilling.ReconciliationStatus__c ||
				eachInvoice.ReconciliationSemiMatchReason__c != eachBilling.ReconciliationSemiMatchReason__c
			) {
				invoicesToUpdate.add(eachInvoice);
			}
		}
		if (!invoicesToUpdate.isEmpty()) {
			Utility.fireUpdateOnObject(invoicesToUpdate, Database.setSavepoint(), false);
		}
	}

	public static void processBillingScheduleFldUpdates(
		Map<Id, Invoice__c> newInvoiceMap,
		Map<Id, Invoice__c> oldInvoiceMap
	) {
		List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
		Invoice__c oldInvoice;
		for (Invoice__c newInvoice : newInvoiceMap.values()) {
			oldInvoice = oldInvoiceMap.get(newInvoice.Id);
			if (
				newInvoice.InvoiceStatus__c != oldInvoice.InvoiceStatus__c ||
				newInvoice.Name != oldInvoice.Name ||
				newInvoice.InvoicePaymentTerm__c != oldInvoice.InvoicePaymentTerm__c ||
				newInvoice.Invoice_Date__c != oldInvoice.Invoice_Date__c
			) {
				invoicesToUpdate.add(newInvoice);
			}
		}
		if (!invoicesToUpdate.isEmpty()) {
			InvoiceLinkToBillingSchedule.updateBillingScheduleFields(invoicesToUpdate);
		}
	}

	private static void updateBillingScheduleFields(List<Invoice__c> invoicesToUpdate) {
		List<Billing_Schedule__c> billingsToUpdate = new List<Billing_Schedule__c>();
		for (Billing_Schedule__c eachBilling : [
			SELECT
				Id,
				Name,
				Billing_Amount__c,
				Billing_Date__c,
				EstimatedPaymentDate__c,
				Invoice__c,
				Invoice_Date__c,
				Invoice_Number__c,
				Invoice_Status__c,
				Invoice__r.Name,
				Invoice__r.Invoice_Date__c,
				Invoice__r.InvoicePaymentTerm__c,
				Invoice__r.InvoiceStatus__c,
				Opportunity__c
			FROM Billing_Schedule__c
			WHERE Invoice__c IN :invoicesToUpdate AND IsPrimaryQuote__c = TRUE
		]) {
			InvoiceLinkToBillingSchedule.getFldsIntoBillingFromInvoice(
				eachBilling,
				eachBilling.Invoice__r
			);
			billingsToUpdate.add(eachBilling);
		}
		if (!billingsToUpdate.isEmpty()) {
			Utility.fireUpdateOnObject(billingsToUpdate, Database.setSavepoint(), false);
		}
	}

	public static void processInvoiceLinkChange(
		Map<Id, Billing_Schedule__c> newBillingScheduleMap,
		Map<Id, Billing_Schedule__c> oldBillingScheduleMap
	) {
		Map<Id, Billing_Schedule__c> invoicesWithBillings = new Map<Id, Billing_Schedule__c>();
		List<Id> invoicesWithNoBillings = new List<Id>();
		List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
		Billing_Schedule__c newBilling, oldBilling;
		for (Billing_Schedule__c newBillng : newBillingScheduleMap.values()) {
			oldBilling = oldBillingScheduleMap.get(newBillng.Id);
			if (oldBilling?.Invoice__c != null && newBillng.Invoice__c == null) {
				newBillng.Invoice_Number__c = null;
				newBillng.Invoice_Status__c = null;
				// invoice date same as estimated invoice date
				newBillng.Invoice_Date__c = newBillng.Billing_Date__c != null
					? newBillng.Billing_Date__c
					: newBillng.Invoice_Date__c;
				// estimated payment date = estimated invoice date + 30
				newBillng.EstimatedPaymentDate__c = newBillng.Invoice_Date__c != null
					? newBillng.Invoice_Date__c + 30
					: null;
				invoicesWithNoBillings.add(oldBilling.Invoice__c);
			} else if (oldBilling?.Invoice__c != newBillng.Invoice__c) {
				invoicesWithBillings.put(newBillng.Invoice__c, newBillng);
				invoicesWithNoBillings.add(oldBilling.Invoice__c);
			}
		}
		for (Invoice__c eachInvoice : [
			SELECT
				Id,
				Name,
				Invoice_Date__c,
				InvoicePaymentTerm__c,
				InvoiceStatus__c,
				ReconciliationSemiMatchReason__c,
				ReconciliationStatus__c
			FROM Invoice__c
			WHERE ID IN :invoicesWithBillings.keySet()
		]) {
			newBilling = invoicesWithBillings.get(eachInvoice.Id);
			InvoiceLinkToBillingSchedule.getFldsIntoBillingFromInvoice(newBilling, eachInvoice);
		}
		for (Invoice__c eachInvoice : [
			SELECT Id, Name, ReconciliationSemiMatchReason__c, ReconciliationStatus__c
			FROM Invoice__c
			WHERE ID IN :invoicesWithNoBillings
		]) {
			eachInvoice.ReconciliationStatus__c = 'No Match';
			eachInvoice.ReconciliationSemiMatchReason__c = 'None';
			invoicesToUpdate.add(eachInvoice);
		}
		if (!invoicesToUpdate.isEmpty()) {
			Utility.fireUpdateOnObject(invoicesToUpdate, Database.setSavepoint(), false);
		}
	}

	public static void processInvoicesForBillingScheduleMatch(Map<Id, Invoice__c> newInvoices) {
		Set<Id> invoiceIdsToUpdate = new Set<Id>();
		Invoice__c oldInvoice;
		//will not run in future or batch context
		if (
			!System.isFuture() &&
			!System.isBatch() &&
			Limits.getFutureCalls() < Limits.getLimitFutureCalls()
		) {
			for (Invoice__c each : newInvoices.values()) {
				if (each.ReconciliationStatus__c == null || each.ReconciliationStatus__c == 'No Match') {
					invoiceIdsToUpdate.add(each.Id);
				}
			}
			InvoiceLinkToBillingSchedule.updateLinksAndStatusInFuture(invoiceIdsToUpdate);
		}
	}

	@future
	private static void updateLinksAndStatusInFuture(Set<Id> newInvoiceIds) {
		List<Invoice__c> invoicesSelected = new List<Invoice__c>();
		Map<Id, List<Invoice__c>> oppsWithInvoices = new Map<Id, List<Invoice__c>>();
		List<Invoice__c> invoicesToFilter = new List<Invoice__c>();
		invoicesToFilter = [
			SELECT
				Id,
				Name,
				Amount__c,
				Invoice_Date__c,
				InvoicePaymentTerm__c,
				InvoiceStatus__c,
				Opportunity__c,
				ReconciliationSemiMatchReason__c,
				ReconciliationStatus__c
			FROM Invoice__c
			WHERE ID IN :newInvoiceIds AND ReconciliationStatus__c IN (NULL, 'No Match')
		];
		for (Invoice__c eachInvoice : invoicesToFilter) {
			invoicesSelected = oppsWithInvoices.get(eachInvoice.Opportunity__c);
			if (invoicesSelected == null) {
				oppsWithInvoices.put(eachInvoice.Opportunity__c, new List<Invoice__c>{ eachInvoice });
			} else {
				invoicesSelected.add(eachInvoice);
			}
		}
		if (!oppsWithInvoices.isEmpty()) {
			InvoiceLinkToBillingSchedule.findAndUpdateBillingScheduleMatchForInvoice(oppsWithInvoices);
		}
	}

	private static void findAndUpdateBillingScheduleMatchForInvoice(
		Map<Id, List<Invoice__c>> oppsWithInvoices
	) {
		Map<Id, Invoice__c> invoicesToUpdate = new Map<Id, Invoice__c>();
		Map<Id, Billing_Schedule__c> billingsToUpdate = new Map<Id, Billing_Schedule__c>();
		List<Invoice__c> invoicesSelected = new List<Invoice__c>();
		for (Billing_Schedule__c eachBilling : [
			SELECT
				Id,
				Name,
				Billing_Amount__c,
				EstimatedPaymentDate__c,
				Invoice__c,
				Invoice_Date__c,
				Invoice_Number__c,
				Invoice_Status__c,
				Opportunity__c
			FROM Billing_Schedule__c
			WHERE
				Opportunity__c IN :oppsWithInvoices.keySet()
				AND Invoice__c = NULL
				AND IsPrimaryQuote__c = TRUE
		]) {
			invoicesSelected = oppsWithInvoices.get(eachBilling.Opportunity__c);
			for (Invoice__c eachInvoice : invoicesSelected) {
				InvoiceLinkToBillingSchedule.runInvoiceBillingMatchingCriteria(eachInvoice, eachBilling);
				// found a match
				if (eachBilling.Invoice__c == eachInvoice.Id) {
					billingsToUpdate.put(eachBilling.Id, eachBilling);
					invoicesToUpdate.put(eachInvoice.Id, eachInvoice);
				}
			}
		}
		// update those that didn't have a match
		for (List<Invoice__c> eachInvoiceLst : oppsWithInvoices.values()) {
			for (Invoice__c eachInvoice : eachInvoiceLst) {
				if (
					!invoicesToUpdate.containsKey(eachInvoice.Id) &&
					eachInvoice.ReconciliationStatus__c == null
				) {
					eachInvoice.ReconciliationStatus__c = 'No Match';
					eachInvoice.ReconciliationSemiMatchReason__c = 'None';
					invoicesToUpdate.put(eachInvoice.Id, eachInvoice);
				}
			}
		}
		if (!billingsToUpdate.isEmpty() || !invoicesToUpdate.isEmpty()) {
			// update the invoices and billing schedules
			InvoiceLinkToBillingSchedule.fireUpdate(billingsToUpdate.values(), invoicesToUpdate.values());
		}
	}

	private static void runInvoiceBillingMatchingCriteria(
		Invoice__c eachInvoice,
		Billing_Schedule__c eachBilling
	) {
		if (
			eachInvoice.Amount__c != null &&
			eachBilling.Billing_Amount__c != null &&
			eachInvoice.Invoice_Date__c != null &&
			eachBilling.Invoice_Date__c != null &&
			eachInvoice.Amount__c - eachBilling.Billing_Amount__c >= -1 &&
			eachInvoice.Amount__c - eachBilling.Billing_Amount__c <= 1 &&
			eachInvoice.Invoice_Date__c.monthsBetween(eachBilling.Invoice_Date__c) == 0
		) {
			eachBilling.Invoice__c = eachInvoice.Id;
			InvoiceLinkToBillingSchedule.getFldsIntoBillingFromInvoice(eachBilling, eachInvoice);
			InvoiceLinkToBillingSchedule.updateInvoiceReconciliationFlds(eachInvoice, eachBilling);
		}
	}

	private static void updateInvoiceReconciliationFlds(
		Invoice__c eachInvoice,
		Billing_Schedule__c eachBilling
	) {
		if (
			eachBilling.Invoice__c != null &&
			eachInvoice.Amount__c == eachBilling.Billing_Amount__c &&
			eachInvoice.Invoice_Date__c == eachBilling.Invoice_Date__c
		) {
			eachInvoice.ReconciliationStatus__c = 'Exact Match';
			eachInvoice.ReconciliationSemiMatchReason__c = 'None';
		} else if (eachBilling.Invoice__c != null) {
			eachInvoice.ReconciliationStatus__c = 'Semi Match';
			eachInvoice.ReconciliationSemiMatchReason__c = 'Amount mismatch';
		}
	}

	private static void getFldsIntoBillingFromInvoice(
		Billing_Schedule__c billing,
		Invoice__c invoice
	) {
		String invoiceStatus;
		billing.Invoice_Number__c = invoice.Name;
		billing.Invoice_Date__c = invoice.Invoice_Date__c;
		if (invoice.InvoiceStatus__c != null) {
			invoiceStatus = invoice.InvoiceStatus__c.toLowercase();
			switch on invoiceStatus {
				when 'open' {
					billing.Invoice_Status__c = 'Invoiced';
				}
				when 'paid in full' {
					billing.Invoice_Status__c = 'Paid';
				}
				when else {
					billing.Invoice_Status__c = invoice.InvoiceStatus__c;
				}
			}
		}
		InvoiceLinkToBillingSchedule.calculatePaymentTerm(billing, invoice);
	}

	private static void calculatePaymentTerm(Billing_Schedule__c billing, Invoice__c invoice) {
		List<String> invoicePaymentTermInnerStr = new List<String>();
		String paymentTermStrForDelimiter;
		Integer paymentTerm;
		Boolean isEstimatedPaymentDateCalculated = false;
		if (invoice.InvoicePaymentTerm__c != null) {
			paymentTermStrForDelimiter = invoice.InvoicePaymentTerm__c.substringAfter('Net ');
			if (!String.isEmpty(paymentTermStrForDelimiter)) {
				// comma delimiter
				invoicePaymentTermInnerStr = paymentTermStrForDelimiter.split(',');
				for (String each : invoicePaymentTermInnerStr) {
					paymentTermStrForDelimiter = each;
					if (each.isNumeric() && invoice.Invoice_Date__c != null) {
						billing.EstimatedPaymentDate__c = invoice.Invoice_Date__c + Integer.valueOf(each);
						isEstimatedPaymentDateCalculated = true;
						break;
					}
				}
				if (!isEstimatedPaymentDateCalculated) {
					invoicePaymentTermInnerStr = paymentTermStrForDelimiter.split(' ');
					for (String each : invoicePaymentTermInnerStr) {
						if (each.isNumeric() && invoice.Invoice_Date__c != null) {
							billing.EstimatedPaymentDate__c = invoice.Invoice_Date__c + Integer.valueOf(each);
							isEstimatedPaymentDateCalculated = true;
							break;
						}
					}
				}
			}
			// default if we cannot parse invoice payment term
			if (!isEstimatedPaymentDateCalculated && invoice.Invoice_Date__c != null) {
				billing.EstimatedPaymentDate__c = invoice.Invoice_Date__c + 30;
			}
		}
	}

	private static void fireUpdate(
		List<Billing_Schedule__c> billingsToUpdate,
		List<Invoice__c> invoicesToUpdate
	) {
		System.Savepoint databaseSavepoint = Database.setSavepoint();
		List<Database.SaveResult> billings, invoices;
		// billings can never be updated without invoices being updated at the same time
		if (!billingsToUpdate.isEmpty() && !invoicesToUpdate.isEmpty()) {
			Utility.fireUpdateOnObject(billingsToUpdate, databaseSavepoint, true);
		}
		// invoices can be updated with 'No Match' without any billings to update
		if (!invoicesToUpdate.isEmpty()) {
			Utility.fireUpdateOnObject(invoicesToUpdate, databaseSavepoint, true);
		}
	}

	public static void processBillingsInvoiceDate(
		Map<Id, Invoice__c> newInvoiceMap,
		Map<Id, Invoice__c> oldInvoiceMap
	) {
		Set<Invoice__c> invoicesUpdated = new Set<Invoice__c>();
		List<Billing_Schedule__c> billingsToUpdate = new List<Billing_Schedule__c>();
		Invoice__c oldInvoice;
		// Invoice's "Invoice Date" was updated; the attached billing schedule's Invoice date needs to update
		for (Invoice__c newInvoice : newInvoiceMap.values()) {
			oldInvoice = oldInvoiceMap.get(newInvoice.Id);
			if (
				oldInvoice.Invoice_Date__c != newInvoice.Invoice_Date__c &&
				// have an attached billing schedule
				(newInvoice.ReconciliationStatus__c == 'Exact Match' ||
				newInvoice.ReconciliationStatus__c == 'Semi Match')
			) {
				invoicesUpdated.add(newInvoice);
			}
		}
		if (!invoicesUpdated.isEmpty()) {
			for (Billing_Schedule__c eachBilling : [
				SELECT
					Id,
					Name,
					Billing_Amount__c,
					Billing_Date__c,
					EstimatedPaymentDate__c,
					Invoice__c,
					Invoice_Date__c
				FROM Billing_Schedule__c
				WHERE Invoice__c IN :invoicesUpdated
			]) {
				eachBilling.Invoice_Date__c = newInvoiceMap.get(eachBilling.Invoice__c).Invoice_Date__c;
				InvoiceLinkToBillingSchedule.calculatePaymentTerm(
					eachBilling,
					newInvoiceMap.get(eachBilling.Invoice__c)
				);
				billingsToUpdate.add(eachBilling);
			}
		}
		if (!billingsToUpdate.isEmpty()) {
			Utility.fireUpdateOnObject(billingsToUpdate, Database.setSavepoint(), false);
		}
	}

	public static void processBillingSchedulesForInvoiceMatch(
		Map<Id, Billing_Schedule__c> newBillingScheduleMap,
		Map<Id, Billing_Schedule__c> oldBillingScheduleMap
	) {
		Set<Id> invoicesSelected = new Set<Id>();
		Set<Id> billingOpptys = new Set<Id>();
		Billing_Schedule__c oldBilling;
		for (Billing_Schedule__c newBilling : newBillingScheduleMap.values()) {
			oldBilling = oldBillingScheduleMap.get(newBilling.Id);
			if (newBilling.Invoice__c == null && oldBilling.Invoice__c == null) {
				if (
					newBilling.Invoice_Date__c != oldBilling.Invoice_Date__c ||
					newBilling.Billing_Amount__c != oldBilling.Billing_Amount__c
				) {
					billingOpptys.add(newBilling.Opportunity__c);
				}
			}
		}
		for (Invoice__c eachInvoice : [
			SELECT Id
			FROM Invoice__c
			WHERE Opportunity__c IN :billingOpptys AND ReconciliationStatus__c IN (NULL, 'No Match')
		]) {
			invoicesSelected.add(eachInvoice.Id);
		}
		if (
			!invoicesSelected.isEmpty() &&
			!System.isFuture() &&
			!System.isBatch() &&
			Limits.getFutureCalls() < Limits.getLimitFutureCalls()
		) {
			InvoiceLinkToBillingSchedule.updateLinksAndStatusInFuture(invoicesSelected);
		}
	}

	public static void processEstimatedDateChanges(
		Map<Id, Billing_Schedule__c> newBillingScheduleMap,
		Map<Id, Billing_Schedule__c> oldBillingScheduleMap
	) {
		Billing_Schedule__c oldBilling;
		List<Billing_Schedule__c> billingsToUpdate = new List<Billing_Schedule__c>();
		Boolean isUpdateEligible = false;
		if (Trigger.isUpdate) {
			for (Billing_Schedule__c newBilling : newBillingScheduleMap.values()) {
				// Estimated Invoice Date API Name is Billing_Date__c. Label and API discrepancy
				oldBilling = oldBillingScheduleMap.get(newBilling.Id);
				// default values for Invoice Date & Estimated Payment Date when no invoice attached
				if (
					newBilling.Billing_Date__c != oldBilling.Billing_Date__c &&
					newBilling.Billing_Date__c != null &&
					newBilling.Invoice__c == null
				) {
					newBilling.Invoice_Date__c = newBilling.Billing_Date__c;
					newBilling.EstimatedPaymentDate__c = newBilling.Invoice_Date__c + 30;
				}
			}
		} else if (Trigger.IsInsert) {
			for (Billing_Schedule__c newBilling : [
				SELECT
					Id,
					Name,
					Billing_Date__c,
					EstimatedPaymentDate__c,
					Invoice_Date__c,
					Opportunity__r.CloseDate
				FROM Billing_Schedule__c
				WHERE Id IN :newBillingScheduleMap.values() AND Invoice__c = NULL
			]) {
				isUpdateEligible = false;
				if (newBilling.Billing_Date__c == null) {
					newBilling.Billing_Date__c = newBilling.Opportunity__r.CloseDate;
					isUpdateEligible = true;
				}
				if (
					newBilling.Billing_Date__c != null &&
					newBilling.Billing_Date__c != newBilling.Invoice_Date__c
				) {
					newBilling.Invoice_Date__c = newBilling.Billing_Date__c;
					isUpdateEligible = true;
				}
				if (newBilling.EstimatedPaymentDate__c == null && newBilling.Billing_Date__c != null) {
					newBilling.EstimatedPaymentDate__c = newBilling.Billing_Date__c + 30;
					isUpdateEligible = true;
				}
				if (isUpdateEligible) {
					billingsToUpdate.add(newBilling);
				}
			}
			if (!billingsToUpdate.isEmpty()) {
				Utility.fireUpdateOnObject(billingsToUpdate, Database.setSavepoint(), false);
			}
		}
	}

	public static Set<Id> processInvoicesBeforeBillingScheduleDelete(
		Map<Id, Billing_Schedule__c> billingsBeforeDelete
	) {
		Set<Id> invoicesToUpdateAfterDelete = new Set<Id>();
		for (Billing_Schedule__c eachBilling : billingsBeforeDelete.values()) {
			if (eachBilling.Invoice__c != null) {
				invoicesToUpdateAfterDelete.add(eachBilling.Invoice__c);
			}
		}
		return invoicesToUpdateAfterDelete;
	}

	/* Can run into CPU timeout exceptions if done without future */
	@future
	public static void processInvoicesAfterBillingScheduleDelete(
		Set<Id> invoicesToUpdateAfterDelete
	) {
		List<Invoice__c> invoicesUpdatedAfterDelete = new List<Invoice__c>();
		if (!invoicesToUpdateAfterDelete.isEmpty()) {
			for (Invoice__c eachInvoice : [
				SELECT
					Id,
					ReconciliationStatus__c,
					ReconciliationSemiMatchReason__c,
					(SELECT Id FROM BillingSchedules__r)
				FROM Invoice__c
				WHERE ID IN :invoicesToUpdateAfterDelete
			]) {
				if (eachInvoice.BillingSchedules__r.isEmpty()) {
					eachInvoice.ReconciliationStatus__c = null;
					eachInvoice.ReconciliationSemiMatchReason__c = null;
					invoicesUpdatedAfterDelete.add(eachInvoice);
				}
			}
			if (!invoicesUpdatedAfterDelete.isEmpty()) {
				Utility.fireUpdateOnObject(invoicesUpdatedAfterDelete, Database.setSavepoint(), false);
			}
		}
	}
}