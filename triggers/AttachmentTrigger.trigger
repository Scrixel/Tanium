/**
 * @Business: Attachment Trigger Handling
 * @Date: 2016-03-23
 * @Author: Cumulus Vision
 * @Request: TAN-107
 * Modified  ModifiedDate   Description
 */
trigger AttachmentTrigger on Attachment(
	before insert,
	before update,
	before delete,
	after insert,
	after update,
	after delete,
	after undelete
) {
	new AttachmentTriggerHandler().run();
}