/**
 * @Business: Handler class for Budget Approver Trigger
 * @Date: 2018-02-16
 * @Author: Cumulus Vision
 * @Request: TAN-480
 * Modified  ModifiedDate   Description
 * TAN-480   2018-02-16     Initial Development
 * TAN-664   2018-09-13     added Receiver to the process.
 */
public class BudgetApproverTriggerHandler extends TriggerHandler {
	private List<Budget_Approver__c> newBudgetApproverList;
	private Map<Id, Budget_Approver__c> oldBudgetApproverMap;

	public BudgetApproverTriggerHandler() {
		super('BudgetApproverTriggerHandler');
		this.newBudgetApproverList = (List<Budget_Approver__c>) Trigger.new;
		this.oldBudgetApproverMap = (Map<Id, Budget_Approver__c>) Trigger.oldMap;
	}

	public override void afterUpdate() {
		Set<String> uniqueIdentifiers = new Set<String>();
		Map<String, Id> ownerMap = new Map<String, Id>();
		Map<String, Id> eStaffMap = new Map<String, Id>();
		Map<String, Id> financeMap = new Map<String, Id>();
		Map<String, Id> receiverMap = new Map<String, Id>();

		for (Budget_Approver__c budgetApprover : newBudgetApproverList) {
			Budget_Approver__c oldBudgetApprover = oldBudgetApproverMap.get(budgetApprover.Id);

			if (
				(budgetApprover.Budget_Owner__c != null &&
				budgetApprover.Budget_Owner__c != oldBudgetApprover.Budget_Owner__c) ||
				(budgetApprover.Budget_E_Staff__c != null &&
				budgetApprover.Budget_E_Staff__c != oldBudgetApprover.Budget_E_Staff__c) ||
				(budgetApprover.Budget_Finance_Approver__c != null &&
				budgetApprover.Budget_Finance_Approver__c != oldBudgetApprover.Budget_Finance_Approver__c)
			) {
				uniqueIdentifiers.add(budgetApprover.Unique_Identifier__c);
				ownerMap.put(budgetApprover.Unique_Identifier__c + '.o', budgetApprover.Budget_Owner__c);
				eStaffMap.put(budgetApprover.Unique_Identifier__c + '.e', budgetApprover.Budget_E_Staff__c);
				financeMap.put(
					budgetApprover.Unique_Identifier__c + '.f',
					budgetApprover.Budget_Finance_Approver__c
				);
				receiverMap.put(budgetApprover.Unique_Identifier__c + '.a', budgetApprover.Receiver__c);
			}
		}

		if (!uniqueIdentifiers.isEmpty()) {
			updateOpenBudgets(uniqueIdentifiers, ownerMap, eStaffMap, financeMap);
		}
	}

	private static void updateOpenBudgets(
		Set<String> uniqueIdentifiers,
		Map<String, Id> ownerMap,
		Map<String, Id> eStaffMap,
		Map<String, Id> financeMap
	) {
		List<Budget__c> openBudgets = [
			SELECT
				Id,
				Unique_Identifier__c,
				Budget_Owner__c,
				Procurement_E_Staff_Approver__c,
				Status__c,
				Finance_Approver__c,
				Receiver__c
			FROM Budget__c
			WHERE Unique_Identifier__c IN :uniqueIdentifiers AND Status__c IN ('New', 'In Progess')
		];

		String owner;
		String eStaff;
		String finance;
		String receiver;

		List<Budget__c> updatedBudgets = new List<Budget__c>();

		for (Budget__c budget : openBudgets) {
			owner = budget.Unique_Identifier__c + '.o';
			eStaff = budget.Unique_Identifier__c + '.e';
			finance = budget.Unique_Identifier__c + '.f';
			receiver = budget.Unique_Identifier__c + '.r';

			if (budget.Budget_Owner__c != ownerMap.get(owner)) {
				budget.Budget_Owner__c = ownerMap.get(owner);
			}

			if (budget.Procurement_E_Staff_Approver__c != eStaffMap.get(eStaff)) {
				budget.Procurement_E_Staff_Approver__c = eStaffMap.get(eStaff);
			}

			if (budget.Finance_Approver__c != financeMap.get(finance)) {
				budget.Finance_Approver__c = financeMap.get(finance);
			}

			if (budget.Receiver__c != financeMap.get(receiver)) {
				budget.Receiver__c = financeMap.get(receiver);
			}

			updatedBudgets.add(budget);
		}

		update updatedBudgets;
	}
}