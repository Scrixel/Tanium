/**
 * @Business: Standard Trigger on Tool Displacement
 * @Date: 2019-10-16
 * @Author: Cumulus Vision
 * @Request: TAN-820
 * Modified  ModifiedDate   Description
 * TAN-820   2019-10-21     Initial Development
 */
trigger ToolDisplacementTrigger on Tool_Displacement__c(
	after insert,
	after update,
	after delete,
	after undelete
) {
	new ToolDisplacementTriggerHandler().run();
}