/*
 * @DATE: 2022-05-12
 * @AUTHOR: Shared Services (jason.johnson)
 * @REQUEST: 
 * @BUSINESS: Trigger for the EmailMessage class.
 * RequestId       ModifiedDate    Comment
 * SCLOUD-         2020-05-12      Initial Development
 */
trigger EmailMessageTrigger on EmailMessage(
	after update,
	before update,
	before insert,
	after insert
) {
	new EmailMessageTriggerHandler().run();
}