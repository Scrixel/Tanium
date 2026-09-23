/**
 * @Business: TAM Team Member Trigger
 * @Date: 2023-04-06
 * @Author: Jason Johnson
 * @Request: 
 * Modified  ModifiedDate   Description
 */
trigger TAMTeamMemberTrigger on TAM_Team_Member__c(
    after delete
) {
	new TAMTeamMemberTriggerHandler().run();
}