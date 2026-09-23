/**
 * @Business: Handler class for Budget Trigger
 * @Date: 2018-02-16
 * @Author: Cumulus Vision
 * @Request: TAN-480
 * Modified  ModifiedDate   Description
 * TAN-480   2018-02-16     Initial Development
 * TAN-664   2018-09-14     Added logic to handle Receiver__c
 */
public class BudgetTriggerHandler extends TriggerHandler {
	private List<Budget__c> newBudgetList;
	private Map<Id, Budget__c> oldBudgetMap;

	public BudgetTriggerHandler() {
		super('BudgetTriggerHandler');
		this.newBudgetList = (List<Budget__c>) Trigger.new;
		this.oldBudgetMap = (Map<Id, Budget__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		Set<String> uniqueIdentifiers = new Set<String>();

		for (Budget__c budget : newBudgetList) {
			if (budget.Business_Department__c != null && budget.Business_Region__c != null) {
				uniqueIdentifiers.add(budget.Business_Department__c + '.' + budget.Business_Region__c);
			}
		}

		if (!uniqueIdentifiers.isEmpty()) {
			findApprovers(newBudgetList, uniqueIdentifiers);
		}
	}

	public override void beforeUpdate() {
		Set<String> uniqueIdentifiers = new Set<String>();

		for (Budget__c budget : newBudgetList) {
			Budget__c oldBudget = oldBudgetMap.get(budget.Id);

			if (budget.Status__c == 'New' || budget.Status__c == 'In Progress') {
				if (
					(budget.Business_Department__c != null &&
					budget.Business_Department__c != oldBudget.Business_Department__c) ||
					(budget.Business_Region__c != null &&
					budget.Business_Region__c != oldBudget.Business_Region__c)
				) {
					uniqueIdentifiers.add(budget.Business_Department__c + '.' + budget.Business_Region__c);
				}
			}
		}

		if (!uniqueIdentifiers.isEmpty()) {
			findApprovers(newBudgetList, uniqueIdentifiers);
		}
	}

	private static void findApprovers(List<Budget__c> newBudgetList, Set<String> uniqueIdentifiers) {
		List<Budget_Approver__c> approvers = [
			SELECT
				Id,
				Budget_Owner__c,
				Budget_E_Staff__c,
				Unique_Identifier__c,
				Budget_Finance_Approver__c,
				Receiver__c
			FROM Budget_Approver__c
			WHERE Unique_Identifier__c IN :uniqueIdentifiers
		];

		Map<String, Id> ownerMap = new Map<String, Id>();
		Map<String, Id> eStaffMap = new Map<String, Id>();
		Map<String, Id> financeMap = new Map<String, Id>();
		Map<String, Id> receiverMap = new Map<String, Id>();

		for (Budget_Approver__c ba : approvers) {
			ownerMap.put(ba.Unique_Identifier__c, ba.Budget_Owner__c);
			eStaffMap.put(ba.Unique_Identifier__c, ba.Budget_E_Staff__c);
			financeMap.put(ba.Unique_Identifier__c, ba.Budget_Finance_Approver__c);
			receiverMap.put(ba.Unique_Identifier__c, ba.Receiver__c);
		}

		for (Budget__c budget : newBudgetList) {
			budget.Budget_Owner__c = ownerMap.get(budget.Unique_Identifier__c);
			budget.Procurement_E_Staff_Approver__c = eStaffMap.get(budget.Unique_Identifier__c);
			budget.Finance_Approver__c = financeMap.get(budget.Unique_Identifier__c);
			budget.Receiver__c = receiverMap.get(budget.Unique_Identifier__c);
		}
	}
}