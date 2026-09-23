/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Invocable action that runs on-demand D&B-to-Account sync
 * @Date: 2026-07-07
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13353   2026-07-07    Initial development
 */
public with sharing class DNB_AccountSyncOnDemandInvoc {
	@InvocableMethod(
		label='On-Demand D&B Account Sync'
		description='Runs the D&B-to-Account sync for the Account immediately, instead of waiting for the nightly schedule job.'
	)
	public static void syncOnDemand(List<Id> accountIds) {
		Database.executeBatch(new DNB_AccountEnrichmentBatch(new Set<Id>(accountIds)));
	}
}