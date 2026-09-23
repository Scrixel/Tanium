/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: POC Request Trigger
 * @Date: 2018-03-14
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request: TAN-487
 * RequestId    ModifiedDate    Description
 * TAN-487      2018-03-14      Initial development
 * SS-12077     2025-11-13      Best practices for trigger framework
 */
trigger POCRequestTrigger on POC_Request__c(before insert, before update, after update) {
	new POCRequestTriggerHandler().run();
}