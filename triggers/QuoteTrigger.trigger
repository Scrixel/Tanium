/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Trigger for standard Quote (Nue)
 * @Date: 2026-09-09
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13958   2026-09-09    Initial development
 */
trigger QuoteTrigger on Quote(before insert, before update, before delete, after update) {
	new QuoteTriggerHandler().run();
}