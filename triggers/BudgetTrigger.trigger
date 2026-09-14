/**
 * @Business: Standard Trigger on Budget Object
 * @Date: 2018-02-16
 * @Author: Cumulus Vision
 * @Request: TAN-480
 * Modified  ModifiedDate   Description
 * TAN-480   2018-02-16     Initial Development
 */
trigger BudgetTrigger on Budget__c(after insert, after update, before insert, before update) {
	new BudgetTriggerHandler().run();
}