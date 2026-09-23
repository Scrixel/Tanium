/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Handler for the Ruby (Nue) Subscription (Ruby__Subscription__c) trigger.
 *            Populates Supported Asset from the support quote line's direct Supported
 *            Hardware Line Asset or fallback Supported Hardware Line lookup.
 */
public with sharing class Ruby_SubscriptionTriggerHandler extends TriggerHandler {
	private List<Ruby__Subscription__c> subs;
	private Map<Id, Ruby__Subscription__c> oldMap;

	public Ruby_SubscriptionTriggerHandler() {
		super('Ruby_SubscriptionTriggerHandler');
		this.subs = (List<Ruby__Subscription__c>) Trigger.new;
		this.oldMap = (Map<Id, Ruby__Subscription__c>) Trigger.oldMap;
	}

	public override void afterInsert() {
		Ruby_SubscriptionTriggerUtility.populateSupportedAsset(subs);
	}

	public override void afterUpdate() {
		Ruby_SubscriptionTriggerUtility.populateSupportedAsset(subs, oldMap);
	}
}