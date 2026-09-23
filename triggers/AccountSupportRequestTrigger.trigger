/**
 * @Business: Trigger on Account Support Request
 * @Date: 2019-11-07
 * @Author: Cumulus vision
 * @Request: TAN-827
 * Modified  ModifiedDate   Description
 * TAN-834   2020-01-06     Initial Development
 * SS-7240   2024-01-18		Add before update
 */
trigger AccountSupportRequestTrigger on Account_Support_Request__c(
	before insert,
	before update,
	after insert,
	after update,
	after delete,
	after undelete
) {
	new AccountSupportRequestTriggerHandler().run();
}