/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Handler class for User Territory Association Trigger
 * @Date: 2025-09-30
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-11284     2025-09-30       Initial development
 * SS-12811     2026-07-10       Added populateAccountOwner
 * SS-13545     2026-07-27       Added populateSalesPlanTerritoryFields
 */
public class UserTerritoryAssocTriggerHandler extends TriggerHandler {
	public List<UserTerritory2Association> userTerrAssociations { get; set; }
	public Map<Id, UserTerritory2Association> oldMap { get; set; }

	public UserTerritoryAssocTriggerHandler() {
		super('UserTerritoryAssocTriggerHandler');
		userTerrAssociations = (List<UserTerritory2Association>) Trigger.new;
		oldMap = (Map<Id, UserTerritory2Association>) Trigger.oldMap;
	}

	public override void afterInsert() {
		UserTerritoryAssocTriggerUtility.populateAccountOwner(userTerrAssociations, null);
		UserTerritoryAssocTriggerUtility.populateAccountSDR(userTerrAssociations, null);
		//UserTerritoryAssocTriggerUtility.populateSalesPlanTerritoryFields(userTerrAssociations, null);
	}

	public override void afterUpdate() {
		UserTerritoryAssocTriggerUtility.populateAccountOwner(userTerrAssociations, oldMap);
		UserTerritoryAssocTriggerUtility.populateAccountSDR(userTerrAssociations, oldMap);
		/*
		UserTerritoryAssocTriggerUtility.populateSalesPlanTerritoryFields(
			userTerrAssociations,
			oldMap
		);*/
	}

	public override void afterDelete() {
		UserTerritoryAssocTriggerUtility.removeAccountSDR(oldMap.values());
	}
}