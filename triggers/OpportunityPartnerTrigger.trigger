/**
 * @Business: Standard trigger
 * @Date: 2015-07-09
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * TAN-83    2016-02-10     added before update to support new validation process
 * TAN-439   2017-09-11     added trigger mgmg for this trigger.
 */
trigger OpportunityPartnerTrigger on Opportunity_Partners__c(
	before insert,
	before update,
	after update,
	after insert
) {
	new OpportunityPartnerTriggerHandler().run();
}