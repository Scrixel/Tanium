/**
 * @Business: Contact Trigger
 * @Date: 2015-01-12
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * TAN-930   2020-09-03     Added before update context.
 */
trigger ContactTrigger on Contact(before update, before delete, after insert, after update) {
	new ContactTriggerHandler().run();
}