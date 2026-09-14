public class BillingByQuoteLineTriggerHandler extends TriggerHandler {
	private static Set<Id> billingScheduleIdsToUpdate = new Set<Id>();
	public BillingByQuoteLineTriggerHandler() {
		super('BillingByQuoteLineTriggerHandler');
	}

	public override void afterInsert() {
		BillingScheduleUtility.processRollUpsOnBillingSchedules(
			(Map<Id, BillingByQuoteLine__c>) Trigger.newMap
		);
	}

	public override void afterUpdate() {
		BillingScheduleUtility.processRollUpsOnBillingSchedules(
			(Map<Id, BillingByQuoteLine__c>) Trigger.newMap,
			(Map<Id, BillingByQuoteLine__c>) Trigger.oldMap
		);
	}

	public override void beforeDelete() {
		billingScheduleIdsToUpdate = BillingScheduleUtility.processRollUpsOnBillingSchedules(
			(Map<Id, BillingByQuoteLine__c>) Trigger.oldMap
		);
	}

	public override void afterDelete() {
		BillingScheduleUtility.calculateRollUpsOnBillingSchedules(billingScheduleIdsToUpdate);
	}
}