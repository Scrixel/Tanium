/**
 * @Business: Trigger on SBQQ__QuoteLine__c object.
 * @Date: 2018-03-23
 * @Author: Cumulus Vision
 * @Request: TAN-494
 * Modified  ModifiedDate   Description
 * TAN-494   2018-03-23     Initial Dev
 * TAN-714   2018-11-14     Added Trigger Management
 */
trigger QuoteLineTrigger on SBQQ__QuoteLine__c(
	before insert,
	before update,
	before delete,
	after insert,
	after update,
	after delete,
	after undelete
) {
	new QuoteLineTriggerHandler().run();
}