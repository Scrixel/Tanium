/**
 * @Business: Standard Account Trigger
 * @Date: 2015-04-01
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * TAN-664   2018-09-17     modifed Trigger Management check.
 */
trigger AccountTrigger on Account(after insert, after update, before insert, before update) {
	new AccountTriggerHandler().run();
}