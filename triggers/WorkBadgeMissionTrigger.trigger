/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS:  Trigger on the WorkBadgeMission__c object.
 * RequestId  ModifiedDate  Comment
 * SS-8303    2024-12-05    Created the trigger
 */
trigger WorkBadgeMissionTrigger on WorkBadgeMission__c(
	after insert,
	after update,
	before insert,
	before update
) {
	new WorkBadgeMissionTriggerHandler().run();
}