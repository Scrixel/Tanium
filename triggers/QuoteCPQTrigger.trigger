/**
 * @Business: Trigger for CPQ Quote
 * @Date: 2018-12-20
 * @Author: Cumulus Vision
 * @Request: TAN-738
 * Modified  ModifiedDate   Description
 * TAN-738   2018-12-20     Initial development
 * TAN-1317  2021-10-22     added before insert context, migrated to new framework
 **/
trigger QuoteCPQTrigger on SBQQ__Quote__c(
	before insert,
	before update,
	before delete,
	after insert,
	after update,
	after delete,
	after undelete
) {
	new QuoteCPQTriggerHandler().run();
}