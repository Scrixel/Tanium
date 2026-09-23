/**
 * @Business: Contract Trigger
 * @Date: 2025-07-01
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11112   2025-07-01    Created the trigger
 */
trigger ContractTrigger on Contract(after update) {
	new ContractTriggerHandler().run();
}