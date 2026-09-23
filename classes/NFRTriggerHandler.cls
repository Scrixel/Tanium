/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: Trigger Handler on NFR Object
 * @Date: 2025-11-13
 * @Author: Tanium Dev Team
 * RequestId    ModifiedDate    Description
 * SS-12077     2025-11-13      Initial development
 */
public class NFRTriggerHandler extends TriggerHandler {
	private List<NFR__c> nfrs;
	private Map<Id, NFR__c> oldMap;

	public NFRTriggerHandler() {
		super('NFRTriggerHandler');
		nfrs = (List<NFR__c>) Trigger.new;
		oldMap = (Map<Id, NFR__c>) Trigger.oldMap;
	}

	public override void afterUpdate() {
		NFRTriggerUtility.handleApprovedNFRs(nfrs, oldMap);
	}
}