public class InvoiceTriggerHandler extends TriggerHandler {
	public InvoiceTriggerHandler() {
		super('InvoiceTriggerHandler');
	}

	public override void afterInsert() {
		InvoiceLinkToBillingSchedule.processInvoicesForBillingScheduleMatch(
			(Map<Id, Invoice__c>) Trigger.newMap
		);
	}

	public override void beforeUpdate() {
		InvoiceLinkToBillingSchedule.processInvoiceAmtAndDateChanges(
			(Map<Id, Invoice__c>) Trigger.newMap,
			(Map<Id, Invoice__c>) Trigger.oldMap
		);
	}

	public override void afterUpdate() {
		InvoiceLinkToBillingSchedule.processInvoicesForBillingScheduleMatch(
			(Map<Id, Invoice__c>) Trigger.newMap
		);
		InvoiceLinkToBillingSchedule.processBillingScheduleFldUpdates(
			(Map<Id, Invoice__c>) Trigger.newMap,
			(Map<Id, Invoice__c>) Trigger.oldMap
		);
		InvoiceLinkToBillingSchedule.processBillingsInvoiceDate(
			(Map<Id, Invoice__c>) Trigger.newMap,
			(Map<Id, Invoice__c>) Trigger.oldMap
		);
	}
}