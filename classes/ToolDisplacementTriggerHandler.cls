/**
 * @Business: Handler class for Tool Displacement Trigger
 * @Date: 2019-10-16
 * @Author: Cumulus Vision
 * @Request: TAN-820
 * Modified  ModifiedDate   Description
 * TAN-820   2019-10-21     Initial Development
 * TAN-833   2019-11-25     Updated code to make a method public.
 */
public class ToolDisplacementTriggerHandler extends TriggerHandler {
	private List<Tool_Displacement__c> newToolDisplacementList;
	private List<Tool_Displacement__c> oldToolDisplacementList;
	private Map<Id, Tool_Displacement__c> oldToolDisplacementMap;

	public ToolDisplacementTriggerHandler() {
		super('AccountTriggerHandler');
		this.newToolDisplacementList = (List<Tool_Displacement__c>) Trigger.new;
		this.oldToolDisplacementList = (List<Tool_Displacement__c>) Trigger.old;
		this.oldToolDisplacementMap = (Map<Id, Tool_Displacement__c>) Trigger.oldMap;
	}

	public override void afterInsert() {
		findAndUpdateStageCount(newToolDisplacementList);
	}

	public override void afterUpdate() {
		List<Tool_Displacement__c> updatedToolDisplacements = getUpdatedToolDisplacements(
			oldToolDisplacementMap,
			newToolDisplacementList
		);
		findAndUpdateStageCount(updatedToolDisplacements);
	}
	public override void afterDelete() {
		findAndUpdateStageCount(oldToolDisplacementList);
	}

	public override void afterUndelete() {
		findAndUpdateStageCount(newToolDisplacementList);
	}

	private static List<Tool_Displacement__c> getUpdatedToolDisplacements(
		Map<Id, Tool_Displacement__c> oldToolDisplacementListMap,
		List<Tool_Displacement__c> newToolDisplacementListList
	) {
		List<Tool_Displacement__c> updatedToolDisplacements = new List<Tool_Displacement__c>();

		for (Tool_Displacement__c newToolDisplacement : newToolDisplacementListList) {
			Tool_Displacement__c oldToolDisplacement = oldToolDisplacementListMap.get(
				newToolDisplacement.Id
			);
			// if stage changed
			if (
				newToolDisplacement.Account__c != null &&
				oldToolDisplacement.Displacement_Stage__c != newToolDisplacement.Displacement_Stage__c
			) {
				updatedToolDisplacements.add(newToolDisplacement);
			}
			// if account lookup changed
			if (oldToolDisplacement.Account__c != newToolDisplacement.Account__c) {
				if (oldToolDisplacement.Account__c != null) {
					updatedToolDisplacements.add(oldToolDisplacement);
				}
				if (newToolDisplacement.Account__c != null) {
					updatedToolDisplacements.add(newToolDisplacement);
				}
			}
		}
		return updatedToolDisplacements;
	}

	public static void findAndUpdateStageCount(List<Tool_Displacement__c> toolDisplacementList) {
		Set<Id> accountIds = new Set<Id>();
		for (Tool_Displacement__c toolDisplacement : toolDisplacementList) {
			if (toolDisplacement.Account__c != null) {
				accountIds.add(toolDisplacement.Account__c);
			}
		}

		if (accountIds != null && !accountIds.isEmpty()) {
			// fetch tool displacement
			List<Tool_Displacement__c> fetchedToolDisplcements = fetchToolDisplacements(accountIds);
			// create account to tool displacement map
			Map<Id, Map<String, Integer>> accIdToTDStages = createAccIdToTDStagesMap(
				fetchedToolDisplcements,
				accountIds
			);
			// create Account instance with Tool_Displacement_Stage__c values
			List<Account> accountsToUpdate = createAccountListWithTDStage(accIdToTDStages);
			//update accounts
			if (accountsToUpdate != null && !accountsToUpdate.isEmpty()) {
				update accountsToUpdate;
			}
		}
	}

	private static List<Account> createAccountListWithTDStage(
		Map<Id, Map<String, Integer>> accIdToTDStages
	) {
		List<Account> accList = new List<Account>();
		if (accIdToTDStages != null && !accIdToTDStages.isEmpty()) {
			for (Id accId : accIdToTDStages.keySet()) {
				String strValue = '';
				Map<String, Integer> TDStages = accIdToTDStages.get(accId);
				if (TDStages != null) {
					for (String stageStr : TDStages.keySet()) {
						if (String.isBlank(strValue)) {
							strValue = TDStages.get(stageStr) + ' ' + stageStr;
						} else {
							strValue = strValue + ', ' + TDStages.get(stageStr) + ' ' + stageStr;
						}
					}

					if (String.isNotBlank(strValue)) {
						strValue = strValue + '.';
						accList.add(new Account(Id = accId, Tool_Displacement_Stage__c = strValue));
					}
				} else {
					accList.add(new Account(Id = accId, Tool_Displacement_Stage__c = ''));
				}
			}
		}
		return accList;
	}

	private static Map<Id, Map<String, Integer>> createAccIdToTDStagesMap(
		List<Tool_Displacement__c> toolDisplcements,
		Set<Id> accountIds
	) {
		Map<Id, Map<String, Integer>> accIdToTDStages = new Map<Id, Map<String, Integer>>();
		for (Tool_Displacement__c toolDisplcementRec : toolDisplcements) {
			if (!accIdToTDStages.containsKey(toolDisplcementRec.Account__c)) {
				accIdToTDStages.put(toolDisplcementRec.Account__c, new Map<String, Integer>());
			}
			if (
				!accIdToTDStages.get(toolDisplcementRec.Account__c)
					.containsKey(toolDisplcementRec.Displacement_Stage__c)
			) {
				accIdToTDStages.get(toolDisplcementRec.Account__c)
					.put(toolDisplcementRec.Displacement_Stage__c, 1);
			} else {
				accIdToTDStages.get(toolDisplcementRec.Account__c)
					.put(
						toolDisplcementRec.Displacement_Stage__c,
						accIdToTDStages.get(toolDisplcementRec.Account__c)
							.get(toolDisplcementRec.Displacement_Stage__c) + 1
					);
			}
		}
		// when after delete no tool displacement is found
		for (Id accId : accountIds) {
			if (!accIdToTDStages.containsKey(accId)) {
				accIdToTDStages.put(accId, null);
			}
		}
		return accIdToTDStages;
	}

	private static List<Tool_Displacement__c> fetchToolDisplacements(Set<Id> accountIds) {
		// fetch tool displacement
		List<Tool_Displacement__c> fetchedToolDisplcements = new List<Tool_Displacement__c>();
		if (accountIds != null && !accountIds.isEmpty()) {
			fetchedToolDisplcements = [
				SELECT Account__c, Displacement_Stage__c
				FROM Tool_Displacement__c
				WHERE Account__c IN :accountIds
			];
		}
		return fetchedToolDisplcements;
	}
}