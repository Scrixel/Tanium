/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Badge Extension Trigger
 * Modified   ModifiedDate  Comment
 * SS-8303    2024-09-06    Assign points to badges
 */
trigger WorkBadgeDefinitionExtensionTrigger on WorkBadgeDefinitionExtension__c(
	after insert,
	after update,
	before insert,
	before update
) {
	new WorkBadgeDefinitionExtTriggerHandler().run();
}