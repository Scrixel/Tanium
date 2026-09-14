/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: TriggerHandler on Order object
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13646   2026-08-07    Added afterUpdate to publish ELV_Order_Event__e when an Order is activated
 */
public with sharing class OrderTriggerHandler extends TriggerHandler {
	public OrderTriggerHandler() {
		super('OrderTriggerHandler');
	}

	public override void afterInsert() {
		OrderTriggerUtility.publishOrders((List<Order>) Trigger.new);
		OrderTriggerUtility.publishNueOrderEvents((List<Order>) Trigger.new, null);
	}

	public override void afterUpdate() {
		OrderTriggerUtility.publishNueOrderEvents((List<Order>) Trigger.new, (Map<Id, Order>) Trigger.oldMap);
	}
}