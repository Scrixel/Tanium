/**
 * @Business: Deal Registration Trigger Handling
 * @Date: 2024-09-13
 * @Author: Tanium Dev Team
 * Modified  ModifiedDate   Description
 * SS-8999   2024-09-12     Initial development - Opp Reg to Deal Reg Migration
 */
trigger DealRegistrationTrigger on Deal_Registration__c(
	before insert,
	before update,
	after insert,
	after update,
	before delete
) {
	new DealRegistrationTriggerHandler().run();
}