/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Utility class supporting entire code base
 * @Date: 2020-01-18
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-9838    2024-12-24    MSFT Metered Billing will be editable even when invoice is attached
 * SS-13619   2026-08-10    Migrated to standard Quote and Nue counterpart fields
 */

public class BillingScheduleUtility {
	public static final String UPDATE_DELETE_NOT_ALLOWED = System.Label.Billing_Schedule_Delete_with_Attached_Invoice_Error;
	public static final String FIELD_UPDATE_ALLOWED_WHEN_INVOICE_ATTACHED = System.Label.Billing_Schedule_fields_allowed_for_edit_when_invoice_attached;
	public static final String CUSTOM_UPDATE_DELETE_PERMISSION = 'BillingScheduleDeleteAllowedWithInvoicesAttached';
	public static final String UPFRONT_PAYMENT_TYPE = BillingScheduleConfiguratorController.UPFRONT_PAYMENT_TYPE;
	public static final String ANNUAL_PAYMENT_TYPE = BillingScheduleConfiguratorController.ANNUAL_PAYMENT_TYPE;

	public static void updateEstimatedInvoiceDate(
		Map<Id, Opportunity> newOppMap,
		Map<Id, Opportunity> oldOppMap
	) {
		Opportunity oldOpp;
		List<Opportunity> oppsBillingToUpdate = new List<Opportunity>();
		List<Billing_Schedule__c> billingsToUpdate = new List<Billing_Schedule__c>();
		for (Opportunity eachOpp : newOppMap.values()) {
			oldOpp = oldOppMap.get(eachOpp.Id);
			if (oldOpp.StageName != eachOpp.StageName && eachOpp.StageName == Utility.CLOSED_WON) {
				oppsBillingToUpdate.add(eachOpp);
			}
		}
		for (Billing_Schedule__c eachBilling : [
			SELECT
				Id,
				Billing_Date__c,
				Opportunity__r.CloseDate,
				PaymentType__c,
				ELV_Quote__r.ELV_PaymentTypeNew__c
			FROM Billing_Schedule__c
			WHERE Opportunity__c IN :oppsBillingToUpdate AND Billing_Order__c = 1
			FOR UPDATE
		]) {
			eachBilling.Billing_Date__c = eachBilling.Opportunity__r.CloseDate;
			billingsToUpdate.add(eachBilling);
		}
		if (!billingsToUpdate.isEmpty()) {
			Utility.fireUpdateOnObject(billingsToUpdate, null, false);
		}
	}

	public static void processRollupsOnOppForUpsert(
		Map<Id, Billing_Schedule__c> billingNewMap,
		Map<Id, Billing_Schedule__c> billingOldMap
	) {
		Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();
		Set<Id> oppIdsToUpdate = new Set<Id>();
		List<Billing_Schedule__c> billingsOrder1Selected = new List<Billing_Schedule__c>();
		Billing_Schedule__c oldBilling;
		for (Billing_Schedule__c eachBilling : billingNewMap.values()) {
			if (billingOldMap != null) {
				oldBilling = billingOldMap.get(eachBilling.Id);
			}
			if (
				Trigger.IsInsert ||
				oldBilling.Opportunity__c != eachBilling.Opportunity__c ||
				oldBilling.Billing_Amount__c != eachBilling.Billing_Amount__c ||
				oldBilling.Billing_Date__c != eachBilling.Billing_Date__c ||
				oldBilling.Billing_Amount_Net_Rollup__c != eachBilling.Billing_Amount_Net_Rollup__c ||
				(oldBilling.Invoice_Status__c != eachBilling.Invoice_Status__c &&
				eachBilling.Invoice_Status__c != null &&
				eachBilling.Invoice_Status__c == 'Paid')
			) {
				Id oppId = oldBilling != null &&
					oldBilling.Opportunity__c != null
					? oldBilling.Opportunity__c
					: eachBilling.Opportunity__c;
				oppIdsToUpdate.add(oppId);
			}

			if (
				(Trigger.IsInsert ||
				(
				oldBilling.Opportunity__c != eachBilling.Opportunity__c ||
				oldBilling.Billing_Amount_Net_Rollup__c != eachBilling.Billing_Amount_Net_Rollup__c ||
				oldBilling.Billing_Amount__c != eachBilling.Billing_Amount__c ||
				oldBilling.Billing_Order__c != eachBilling.Billing_Order__c)) &&
				eachBilling.Billing_Order__c == 1
			) {
				billingsOrder1Selected.add(eachBilling);
				Id oppId = oldBilling != null &&
					oldBilling.Opportunity__c != null
					? oldBilling.Opportunity__c
					: eachBilling.Opportunity__c;
				oppIdsToUpdate.add(oppId);
			}
		}
		if (!oppIdsToUpdate.isEmpty()) {
			oppsToUpdate = new Map<Id, Opportunity>(
				[
					SELECT
						Id,
						BillingScheduleTotalAmountNew__c,
						BillingScheduleTotalNetAmountPaidNew__c,
						BillingScheduleTotalCount__c,
						InitialBillingDateNew__c,
						InitialGrossBillingAmountNew__c,
						InitialNetBillingAmountNew__c
					FROM Opportunity
					WHERE ID IN :oppIdsToUpdate
					FOR UPDATE
				]
			);
			BillingScheduleUtility.calculateBillingScheduleTotalAmount(oppsToUpdate);
			BillingScheduleUtility.calculateInitialBillingRelatedFldsOnOppForUpsert(
				oppsToUpdate,
				billingsOrder1Selected
			);
			Utility.fireUpdateOnObject(oppsToUpdate.values(), null, true);
		}
	}

	public static void processRollupsOnOppForDelete(Map<Id, Billing_Schedule__c> billingOldMap) {
		Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();
		List<Billing_Schedule__c> billingsOrder1Selected = new List<Billing_Schedule__c>();
		Set<Id> oppIdsToUpdate = new Set<Id>();
		for (Billing_Schedule__c eachBilling : billingOldMap.values()) {
			if (eachBilling.Opportunity__c != null) {
				oppIdsToUpdate.add(eachBilling.Opportunity__c);
				if (eachBilling.Billing_Order__c == 1) {
					billingsOrder1Selected.add(eachBilling);
				}
			}
		}
		if (!oppIdsToUpdate.isEmpty()) {
			oppsToUpdate = new Map<Id, Opportunity>(
				[
					SELECT
						Id,
						BillingScheduleTotalAmountNew__c,
						BillingScheduleTotalNetAmountPaidNew__c,
						BillingScheduleTotalCount__c,
						InitialBillingDateNew__c,
						InitialGrossBillingAmountNew__c,
						InitialNetBillingAmountNew__c
					FROM Opportunity
					WHERE ID IN :oppIdsToUpdate
					FOR UPDATE
				]
			);
			BillingScheduleUtility.calculateBillingScheduleTotalAmount(oppsToUpdate);
			BillingScheduleUtility.calculateInitialBillingRelatedFldsOnOppForDelete(
				oppsToUpdate,
				billingsOrder1Selected
			);
			Utility.fireUpdateOnObject(oppsToUpdate.values(), null, true);
		}
	}

	public static void calculateBillingScheduleTotalAmount(Map<Id, Opportunity> oppsToUpdate) {
		List<AggregateResult> aggregatedResults = new List<AggregateResult>(
			[
				SELECT
					Opportunity__c,
					SUM(Billing_Amount__c) totalBillingAmt,
					COUNT(ID) totalCount,
					MIN(Billing_Date__c) minBillingDate
				FROM Billing_Schedule__c
				GROUP BY Opportunity__c
				HAVING Opportunity__c IN :oppsToUpdate.values()
			]
		);
		if (aggregatedResults.isEmpty()) {
			for (Opportunity eachOpp : oppsToUpdate.values()) {
				eachOpp.BillingScheduleTotalAmountNew__c = 0;
				eachOpp.BillingScheduleTotalCount__c = 0;
				eachOpp.InitialBillingDateNew__c = null;
			}
		} else {
			for (AggregateResult eachAggregatedResult : aggregatedResults) {
				Opportunity eachOpp = oppsToUpdate.get((Id) eachAggregatedResult.get('Opportunity__c'));
				if (eachAggregatedResult.get('totalBillingAmt') != null) {
					eachOpp.BillingScheduleTotalAmountNew__c = (Decimal) eachAggregatedResult.get(
						'totalBillingAmt'
					);
				} else {
					eachOpp.BillingScheduleTotalAmountNew__c = 0;
				}
				if (eachAggregatedResult.get('totalCount') != null) {
					eachOpp.BillingScheduleTotalCount__c = (Integer) eachAggregatedResult.get('totalCount');
				} else {
					eachOpp.BillingScheduleTotalCount__c = 0;
				}
				if (eachAggregatedResult.get('minBillingDate') != null) {
					eachOpp.InitialBillingDateNew__c = (Date) eachAggregatedResult.get('minBillingDate');
				} else {
					eachOpp.InitialBillingDateNew__c = null;
				}
			}
		}
		aggregatedResults = new List<AggregateResult>(
			[
				SELECT Opportunity__c, SUM(Billing_Amount_Net_Rollup__c) totalNetAmountPaid
				FROM Billing_Schedule__c
				GROUP BY Opportunity__c, Invoice_Status__c
				HAVING Opportunity__c IN :oppsToUpdate.values() AND Invoice_Status__c = 'Paid'
			]
		);
		if (aggregatedResults.isEmpty()) {
			for (Opportunity eachOpp : oppsToUpdate.values()) {
				eachOpp.BillingScheduleTotalNetAmountPaidNew__c = 0;
			}
		} else {
			for (AggregateResult eachAggregatedResult : aggregatedResults) {
				Opportunity eachOpp = oppsToUpdate.get((Id) eachAggregatedResult.get('Opportunity__c'));
				eachOpp.BillingScheduleTotalNetAmountPaidNew__c = eachAggregatedResult.get(
						'totalNetAmountPaid'
					) == null
					? 0
					: (Decimal) eachAggregatedResult.get('totalNetAmountPaid');
			}
		}
	}

	public static void calculateInitialBillingRelatedFldsOnOppForUpsert(
		Map<Id, Opportunity> oppsToUpdate,
		List<Billing_Schedule__c> billingsOrder1Selected
	) {
		List<Billing_Schedule__c> billings = new List<Billing_Schedule__c>(
			[
				SELECT
					Billing_Amount__c,
					Billing_Amount_Net_Rollup__c,
					Billing_Order__c,
					Opportunity__c,
					ELV_Quote__r.OpportunityId
				FROM Billing_Schedule__c
				WHERE Opportunity__c IN :oppsToUpdate.values() AND Billing_Order__c = 1
				FOR UPDATE
			]
		);
		if (billings.isEmpty()) {
			for (Opportunity eachOpp : oppsToUpdate.values()) {
				eachOpp.InitialGrossBillingAmountNew__c = 0;
				eachOpp.InitialNetBillingAmountNew__c = 0;
			}
		} else {
			Opportunity eachOpp;
			for (Billing_Schedule__c eachBilling : billings) {
				if (eachBilling.ELV_Quote__r.OpportunityId != null) {
					eachOpp = oppsToUpdate.get(eachBilling.ELV_Quote__r.OpportunityId);
					eachOpp.InitialGrossBillingAmountNew__c = 0;
					eachOpp.InitialNetBillingAmountNew__c = 0;
				}
			}
			for (Billing_Schedule__c eachBilling : billings) {
				if (eachBilling.Opportunity__c != null) {
					eachOpp = oppsToUpdate.get(eachBilling.Opportunity__c);
					if (eachBilling.Billing_Amount__c != null) {
						eachOpp.InitialGrossBillingAmountNew__c += eachBilling.Billing_Amount__c;
					}
					if (eachBilling.Billing_Amount_Net_Rollup__c != null) {
						eachOpp.InitialNetBillingAmountNew__c += eachBilling.Billing_Amount_Net_Rollup__c;
					}
				}
			}
		}
	}

	private static void calculateInitialBillingRelatedFldsOnOppForDelete(
		Map<Id, Opportunity> oppsToUpdate,
		List<Billing_Schedule__c> billingsOrder1Selected
	) {
		Opportunity eachOpp;
		for (Billing_Schedule__c eachBilling : billingsOrder1Selected) {
			if (eachBilling.Opportunity__c != null) {
				eachOpp = oppsToUpdate.get(eachBilling.Opportunity__c);
				eachOpp.InitialGrossBillingAmountNew__c = 0;
				eachOpp.InitialNetBillingAmountNew__c = 0;
			}
		}
	}

	public static void processRollUpsOnBillingSchedules(
		Map<Id, BillingByQuoteLine__c> newMap,
		Map<Id, BillingByQuoteLine__c> oldMap
	) {
		Map<Id, BillingByQuoteLine__c> billingByQuoteLinesForUpdate = new Map<Id, BillingByQuoteLine__c>();
		Set<Id> billingScheduleIdsToUpdate = new Set<Id>();
		BillingByQuoteLine__c oldRecord;
		for (BillingByQuoteLine__c eachBillingByQuoteLine : newMap.values()) {
			oldRecord = oldMap.get(eachBillingByQuoteLine.Id);
			if (
				eachBillingByQuoteLine.BillAmount__c != oldRecord.BillAmount__c ||
				eachBillingByQuoteLine.PaymentType__c != oldRecord.PaymentType__c
			) {
				if (
					eachBillingByQuoteLine.BillingSchedule__c != null &&
					eachBillingByQuoteLine.ELV_QuoteLine__c != null
				) {
					billingScheduleIdsToUpdate.add(eachBillingByQuoteLine.BillingSchedule__c);
				}
			}
		}
		if (!billingScheduleIdsToUpdate.isEmpty()) {
			BillingScheduleUtility.calculateRollUpsOnBillingSchedules(billingScheduleIdsToUpdate);
		}
	}

	public static Set<Id> processRollUpsOnBillingSchedules(
		Map<Id, BillingByQuoteLine__c> billingByQuoteLinesForUpdate
	) {
		Set<Id> billingScheduleIdsToUpdate = new Set<Id>();
		for (BillingByQuoteLine__c eachBillingByQuoteLine : billingByQuoteLinesForUpdate.values()) {
			if (
				eachBillingByQuoteLine.BillingSchedule__c != null &&
				eachBillingByQuoteLine.ELV_QuoteLine__c != null
			) {
				billingScheduleIdsToUpdate.add(eachBillingByQuoteLine.BillingSchedule__c);
			}
		}
		if (Trigger.isDelete) {
			return billingScheduleIdsToUpdate;
		} else if (!billingScheduleIdsToUpdate.isEmpty()) {
			BillingScheduleUtility.calculateRollupsOnBillingSchedules(billingScheduleIdsToUpdate);
		}
		return billingScheduleIdsToUpdate;
	}

	public static void calculateRollupsOnBillingSchedules(Set<Id> billingScheduleIdsToUpdate) {
		Map<Id, Billing_Schedule__c> billingSchedulesToUpdate = new Map<Id, Billing_Schedule__c>(
			[
				SELECT Id, Billing_Amount__c, Billing_Amount_Net_Rollup__c, Invoice_Date__c, PaymentType__c
				FROM Billing_Schedule__c
				WHERE ID IN :billingScheduleIdsToUpdate
			]
		);
		List<AggregateResult> aggregatedResults = new List<AggregateResult>(
			[
				SELECT
					BillingSchedule__c,
					SUM(BillAmount__c) totalBillingAmt,
					MIN(PaymentType__c) paymentType
				FROM BillingByQuoteLine__c
				GROUP BY BillingSchedule__c
				HAVING BillingSchedule__c IN :billingSchedulesToUpdate.values()
			]
		);
		for (AggregateResult eachAggregatedResult : aggregatedResults) {
			Billing_Schedule__c eachBillingSchedule = billingSchedulesToUpdate.get(
				(Id) eachAggregatedResult.get('BillingSchedule__c')
			);
			eachBillingSchedule.Billing_Amount__c = eachAggregatedResult.get('totalBillingAmt') == null
				? 0
				: (Decimal) eachAggregatedResult.get('totalBillingAmt');
			eachBillingSchedule.PaymentType__c = (String) eachAggregatedResult.get('paymentType') == null
				? null
				: (String) eachAggregatedResult.get('paymentType');
		}
		if (aggregatedResults.isEmpty()) {
			for (Billing_Schedule__c eachBillingSchedule : billingSchedulesToUpdate.values()) {
				eachBillingSchedule.Billing_Amount__c = 0;
				eachBillingSchedule.PaymentType__c = null;
			}
		}
		Utility.fireUpdateOnObject(billingSchedulesToUpdate.values(), null, true);
	}

	public static List<Id> processBillingsByQuoteLinesBeforeBillingScheduleDelete(
		Map<Id, Billing_Schedule__c> billingSchedulesToDelete
	) {
		Map<Id, BillingByQuoteLine__c> billingsByQuoteLinesToDelete = new Map<Id, BillingByQuoteLine__c>(
			[
				SELECT Id
				FROM BillingByQuoteLine__c
				WHERE BillingSchedule__c IN :billingSchedulesToDelete.values()
				FOR UPDATE
			]
		);
		return new List<Id>(billingsByQuoteLinesToDelete.keySet());
	}

	public static void processBillingsByQuoteLinesAfterBillingScheduleDelete(
		List<Id> billingsByQuoteLinesToDelete
	) {
		List<Database.DeleteResult> deleteResults = Database.delete(billingsByQuoteLinesToDelete, true);
		for (Database.DeleteResult eachResult : deleteResults) {
			if (!eachResult.isSuccess()) {
				throw new DmlException('### DMLException: ' + eachResult.getErrors());
			}
		}
	}

	public static void checkEditPermissionIfInvoiceAttached(
		Map<Id, Billing_Schedule__c> newBillingsMap,
		Map<Id, Billing_Schedule__c> oldBillingsMap
	) {
		if (FeatureManagement.checkPermission(CUSTOM_UPDATE_DELETE_PERMISSION)) {
			return;
		}
		Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
		Set<String> fieldSet = schemaMap.get('Billing_Schedule__c')
			.getDescribe()
			.fields.getMap()
			.keySet();
		Billing_Schedule__c oldBilling;
		for (Billing_Schedule__c newBilling : newBillingsMap.values()) {
			oldBilling = oldBillingsMap.get(newBilling.Id);
			Set<String> fieldsChanged = Utility.getChangedFields(oldBilling, newBilling, fieldSet);
			List<String> fieldsAllowedForEditingWhenInvoiceAttached = FIELD_UPDATE_ALLOWED_WHEN_INVOICE_ATTACHED.split(
				','
			);
			for (String eachFieldAllowedToEdit : fieldsAllowedForEditingWhenInvoiceAttached) {
				fieldsChanged.remove(eachFieldAllowedToEdit.toLowerCase());
			}
			if (oldBilling.Invoice__c != null && !fieldsChanged.isEmpty()) {
				newBilling.addError(UPDATE_DELETE_NOT_ALLOWED + ' on ' + fieldsChanged);
			}
		}
	}

	public static void checkDeletePermissionIfInvoiceAttached(
		Map<Id, Billing_Schedule__c> oldBillingsMap
	) {
		if (FeatureManagement.checkPermission(CUSTOM_UPDATE_DELETE_PERMISSION)) {
			return;
		}
		for (Billing_Schedule__c billing : oldBillingsMap.values()) {
			if (billing.Invoice__c != null) {
				billing.addError(UPDATE_DELETE_NOT_ALLOWED);
			}
		}
	}

	public static void processRollupsOnQuoteForUpsert(
		Map<Id, Billing_Schedule__c> newBillingMap,
		Map<Id, Billing_Schedule__c> oldBillingMap
	) {
		Billing_Schedule__c oldBilling;
		Set<Id> quoteIdsToUpdate = new Set<Id>();

		for (Billing_Schedule__c eachBilling : newBillingMap.values()) {
			oldBilling = oldBillingMap?.get(eachBilling.Id);

			if (
				Trigger.IsInsert ||
				oldBilling.ELV_Quote__c != eachBilling.ELV_Quote__c ||
				oldBilling.Billing_Amount__c != eachBilling.Billing_Amount__c
			) {
				quoteIdsToUpdate.add(eachBilling.ELV_Quote__c);
			}
		}
		updateBillingTotalAmountOnQuote(quoteIdsToUpdate);
	}

	public static void processRollupsOnQuoteForDelete(Map<Id, Billing_Schedule__c> oldBillingMap) {
		Set<Id> quoteIdsToUpdate = new Set<Id>();

		for (Billing_Schedule__c eachBilling : oldBillingMap.values()) {
			if (eachBilling.ELV_Quote__c != null) {
				quoteIdsToUpdate.add(eachBilling.ELV_Quote__c);
			}
		}
		updateBillingTotalAmountOnQuote(quoteIdsToUpdate);
	}

	private static void updateBillingTotalAmountOnQuote(Set<Id> quoteIdsToUpdate) {
		if (!quoteIdsToUpdate.isEmpty()) {
			Map<Id, Quote> quotesToUpdate = new Map<Id, Quote>(
				[
					SELECT Id, ELV_Billing_Schedule_Total_Amount__c
					FROM Quote
					WHERE Id IN :quoteIdsToUpdate
					FOR UPDATE
				]
			);
			calculateBillingTotalAmountForQuote(quotesToUpdate);
			Utility.fireUpdateOnObject(quotesToUpdate.values(), null, true);
		}
	}

	private static void calculateBillingTotalAmountForQuote(Map<Id, Quote> quotesToUpdate) {
		List<AggregateResult> aggregatedResults = new List<AggregateResult>(
			[
				SELECT ELV_Quote__c, SUM(Billing_Amount__c) totalBillingAmt
				FROM Billing_Schedule__c
				GROUP BY ELV_Quote__c
				HAVING ELV_Quote__c IN :quotesToUpdate.values()
			]
		);

		if (aggregatedResults.isEmpty()) {
			for (Quote quote : quotesToUpdate.values()) {
				quote.ELV_Billing_Schedule_Total_Amount__c = 0;
			}
		} else {
			for (AggregateResult aggregateResult : aggregatedResults) {
				Quote quote = quotesToUpdate.get((Id) aggregateResult.get('ELV_Quote__c'));

				quote.ELV_Billing_Schedule_Total_Amount__c = (aggregateResult.get('totalBillingAmt') != null
					? (Decimal) aggregateResult.get('totalBillingAmt')
					: 0);
			}
		}
	}
}