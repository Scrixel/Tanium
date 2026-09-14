/**
 * @Business: Lead Trigger Handling
 * @Date: 2015-04
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * #5145     2015-04-07     Initial development
 * TAN-1046  2020-12-17     added before update
 * TAN-1068  2021-01-08     added before delete
 */
trigger LeadTrigger on Lead(
	after insert,
	after update,
	before update,
	before insert,
	before delete
) {
	new LeadTriggerHandler().run();
}