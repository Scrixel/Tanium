/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Trigger on Order Object
 * @Date: UNKNOWN
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13646   2026-08-11    Added after update to publish ELV_Order_Event__e on Order activation
 */
trigger OrderTrigger on Order(after insert, after update) {
	new OrderTriggerHandler().run();
}