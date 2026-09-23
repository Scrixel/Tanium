/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Trigger on Subscription Object
 * @Date: 2025-11-13
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Added best practices for trigger framework
 */
trigger SubscriptionTrigger on SBQQ__Subscription__c(after insert, after update, after delete) {
	new SubscriptionTriggerHandler().run();
}