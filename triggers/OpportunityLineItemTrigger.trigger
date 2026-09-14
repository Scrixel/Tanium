/**
 * @Business: Standard Opportunity Line Intem Trigger
 * @Date: 2017-12-08
 * @Author: Cumulus Vision
 * @Request: TAN-463
 * Modified  ModifiedDate   Description
 * TAN-463   2017-12-08     Initial Development
 */
trigger OpportunityLineItemTrigger on OpportunityLineItem(
	after insert,
	before update,
	before delete,
	after delete
) {
	new OpportunityLineItemTriggerHandler().run();
}