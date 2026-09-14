public class BillingScheduleTriggerHandler extends TriggerHandler {
	private static Set<Id> invoicesToUpdateAfterDelete;
	private static List<Id> billingsByQuoteLinesToDeleteAfterParentDelete;

	public BillingScheduleTriggerHandler() {
		super('BillingScheduleTriggerHandler');
	}

	public override void afterInsert() {
		InvoiceLinkToBillingSchedule.processEstimatedDateChanges(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			null
		);
		BillingScheduleUtility.processRollupsOnQuoteForUpsert(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			null
		);
		BillingScheduleUtility.processRollupsOnOppForUpsert(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			null
		);
	}

	public override void beforeUpdate() {
		BillingScheduleUtility.checkEditPermissionIfInvoiceAttached(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);

		InvoiceLinkToBillingSchedule.processInvoiceLinkChange(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);

		InvoiceLinkToBillingSchedule.processInvoiceDateAmountChange(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);

		InvoiceLinkToBillingSchedule.processEstimatedDateChanges(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
	}

	public override void afterUpdate() {
		InvoiceLinkToBillingSchedule.processBillingSchedulesForInvoiceMatch(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
		BillingScheduleUtility.processRollupsOnQuoteForUpsert(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
		BillingScheduleUtility.processRollupsOnOppForUpsert(
			(Map<Id, Billing_Schedule__c>) Trigger.newMap,
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
	}

	public override void beforeDelete() {
		BillingScheduleUtility.checkDeletePermissionIfInvoiceAttached(
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);

		invoicesToUpdateAfterDelete = new Set<Id>();
		BillingScheduleTriggerHandler.invoicesToUpdateAfterDelete = InvoiceLinkToBillingSchedule.processInvoicesBeforeBillingScheduleDelete(
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
		BillingScheduleTriggerHandler.billingsByQuoteLinesToDeleteAfterParentDelete = BillingScheduleUtility.processBillingsByQuoteLinesBeforeBillingScheduleDelete(
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
	}

	public override void afterDelete() {
		BillingScheduleUtility.processRollupsOnQuoteForDelete(
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
		BillingScheduleUtility.processRollupsOnOppForDelete(
			(Map<Id, Billing_Schedule__c>) Trigger.oldMap
		);
		BillingScheduleUtility.processBillingsByQuoteLinesAfterBillingScheduleDelete(
			BillingScheduleTriggerHandler.billingsByQuoteLinesToDeleteAfterParentDelete
		);
		if (Utility.isFutureMethodAllowed()) {
			InvoiceLinkToBillingSchedule.processInvoicesAfterBillingScheduleDelete(
				BillingScheduleTriggerHandler.invoicesToUpdateAfterDelete
			);
		}
	}
}