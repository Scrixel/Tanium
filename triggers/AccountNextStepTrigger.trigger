/**
 * @Business: Account_Next_Step__c Trigger Handling
 * @Date: 3/2/2016
 * @Author: Cumulus Vision
 * @Request: %requestId%
 * Modified  ModifiedDate   Description
 */
trigger AccountNextStepTrigger on Account_Next_Step__c(after insert, after update) {
	new AccountNextStepTriggerHandler().run();
}