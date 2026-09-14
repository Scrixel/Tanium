/**
 * @Business: TriggerHandler on Contract Object
 * @Date: 2025-07-01
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-11112   2025-07-01    Created the TriggerHandler (Create ContractTriggerUtility when we have more than one method)
 * SS-11649   2025-09-24    Updated method populateProductMigrationData
 */
public with sharing class ContractTriggerHandler extends TriggerHandler {
	private Contract[] contracts;
	private Map<Id, Contract> oldMap;

	public ContractTriggerHandler() {
		super('ContractTriggerHandler');
		this.contracts = (Contract[]) Trigger.new;
		this.oldMap = (Map<Id, Contract>) Trigger.oldMap;
	}

	public override void afterUpdate() {
		populateProductMigrationData(contracts, oldMap);
	}

	public static void populateProductMigrationData(
		List<Contract> contracts,
		Map<Id, Contract> oldMap
	) {
		Set<Id> oppIds = new Set<Id>();
		Id salesSystemsUserId;

		try {
			salesSystemsUserId = [SELECT Id FROM User WHERE Alias = 'ssystems' LIMIT 1].Id;
		} catch (Exception e) {
			salesSystemsUserId = null;
		}

		for (Contract contract : contracts) {
			if (
				contract.SBQQ__RenewalOpportunity__c !=
				oldMap.get(contract.Id).SBQQ__RenewalOpportunity__c &&
				contract.SBQQ__RenewalOpportunity__c != null
			) {
				oppIds.add(contract.SBQQ__RenewalOpportunity__c);
			}
		}

		if (oppIds.isEmpty()) {
			return;
		}
		ProductMigrationAsync async = new ProductMigrationAsync(
			[
				SELECT
					Id,
					Renewed_Contract_Modules__c,
					Potential_AEM_Modules__c,
					Potential_New_Modules__c,
					Potential_New_Module_Count__c,
					Potential_AEM_Migration_ARR__c
				FROM Opportunity
				WHERE Id IN :oppIds
			]
		);
		Id jobId = Test.isRunningTest() ? null : System.enqueueJob(async, 1);
	}
}