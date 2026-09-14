/*
 * @DATE: 2022-12-02
 * @AUTHOR: Shared Services (jason.johnson)
 * @REQUEST: 
 * @BUSINESS: Trigger for the Survey class.
 * RequestId       ModifiedDate    Comment
 * SCLOUD-         2022-12-02      Initial Development
 */
trigger SurveyTrigger on Survey__c(
	after update,
	before update,
	before insert,
	after insert
) {
	new SurveyTriggerHandler().run();
}