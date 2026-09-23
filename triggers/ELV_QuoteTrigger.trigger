/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Trigger on the standard Quote (Legacy Quote) object. All logic lives in
 *            ELV_QuoteTriggerHandler. Named with the ELV_ prefix because the Nue managed
 *            package already ships Ruby__QuoteTrigger on this object.
 */
trigger ELV_QuoteTrigger on Quote(
	before insert,
	before update,
	before delete,
	after insert,
	after update,
	after delete
) {
	new ELV_QuoteTriggerHandler().run();
}