/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: TNCI 139 / ELV-CPQ-036. Opportunity trigger for the ELV ARR layer. All logic
 *            lives in ELV_OpportunityTriggerHandler. Named with the ELV_ prefix and kept
 *            separate because this object already carries several unrelated active triggers
 *            with no single-trigger discipline to join.
 */
trigger ELV_OpportunityTrigger on Opportunity(after insert, after update) {
	new ELV_OpportunityTriggerHandler().run();
}