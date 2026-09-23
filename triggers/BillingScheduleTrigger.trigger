trigger BillingScheduleTrigger on Billing_Schedule__c(
	before insert,
	before update,
	after insert,
	after update,
	before delete,
	after delete,
	after undelete
) {
	new BillingScheduleTriggerHandler().run();
}