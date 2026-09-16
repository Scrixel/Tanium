/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Handler for the Elevate Product2 trigger. The managed CPQ and Nue product triggers
 *            cannot be extended, so Elevate logic runs from its own trigger.
 */
public with sharing class ELV_ProductTriggerHandler extends TriggerHandler {
	private List<Product2> products;
	private Map<Id, Product2> oldMap;

	public ELV_ProductTriggerHandler() {
		super('ELV_ProductTriggerHandler');
		this.products = (List<Product2>) Trigger.new;
		this.oldMap = (Map<Id, Product2>) Trigger.oldMap;
	}

	public override void afterUpdate() {
		ELV_ProductARRStampService.handleProductChanges(products, oldMap);
		ELV_ProductGroupStampService.handleProductChanges(products, oldMap);
	}
}