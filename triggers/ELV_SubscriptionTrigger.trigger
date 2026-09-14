/**
 * @Business: Trigger for the Ruby (Nue) Subscription (Ruby__Subscription__c). Delegates to
 *            ELV_SubscriptionTrigger via the org TriggerHandler framework.
 */
trigger ELV_SubscriptionTrigger on Ruby__Subscription__c(after insert, after update) {
	System.debug(
		LoggingLevel.INFO,
		'Ruby_SubscriptionTrigger fired. isAfter=' +
			Trigger.isAfter +
			', isInsert=' +
			Trigger.isInsert +
			', isUpdate=' +
			Trigger.isUpdate +
			', size=' +
			Trigger.size
	);
	new ELV_SubscriptionTriggerHandler().run();
}