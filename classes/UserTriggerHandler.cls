/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Standard trigger handler for User object
 * @Date: 2014-12-10
 * @Author: Cumulus Vision, Tanium Dev Team
 * Modified  ModifiedDate   Description
 * SS-2570   2023-04-24	    Added call to method syncInternalSupportRequests
 * SS-10173	 2025-02-05	    Remove L1 thru L6 references
 * SS-10186  2026-02-27     Removed updateAccountQuoteOpportunityInfo and fixed trigger framework
 * SS-12811  2026-07-10     Added method processDeactivatedUsers
 */
public class UserTriggerHandler extends TriggerHandler {
	private List<User> users;
	private Map<Id, User> oldMap;

	public UserTriggerHandler() {
		super('UserTriggerHandler');
		users = (List<User>) Trigger.new;
		oldMap = (Map<Id, User>) Trigger.oldMap;
	}

	public override void afterUpdate() {
		UserTriggerUtility.syncInternalSupportRequests(users, oldMap);
		UserTriggerUtility.processDeactivatedUsers(users, oldMap);
	}
}