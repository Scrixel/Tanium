/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Standard User Territory Association Trigger
 * @Date: 2025-09-30
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-11284     2025-09-30       Initial development
 */
trigger UserTerritoryAssociationTrigger on UserTerritory2Association(
	after insert,
	after update,
	after delete
) {
	new UserTerritoryAssocTriggerHandler().run();
}