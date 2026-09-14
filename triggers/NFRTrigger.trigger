/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Trigger on NFR Object
 * @Date: 2025-11-13
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Initial development
 */
trigger NFRTrigger on NFR__c(after update) {
	new NFRTriggerHandler().run();
}