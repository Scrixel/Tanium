/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Trigger Handler on the WorkBadgeMission__c object.
 * RequestId  ModifiedDate  Comment
 * SS-8303    2024-12-05    Created the class
 */
public with sharing class WorkBadgeMissionTriggerHandler extends TriggerHandler {
	public WorkBadgeMission__c[] workBadgeMissions { get; set; }
	public Map<Id, WorkBadgeMission__c> oldMap { get; set; }

	public WorkBadgeMissionTriggerHandler() {
		super('WorkBadgeMissionTriggerHandler');
		this.workBadgeMissions = (WorkBadgeMission__c[]) Trigger.new;
		this.oldMap = (Map<Id, WorkBadgeMission__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		WorkBadgeMissionTriggerUtility.validateActiveBadge(workBadgeMissions);
		WorkBadgeMissionTriggerUtility.setSourceId(workBadgeMissions);
		WorkBadgeMissionTriggerUtility.setMessage(workBadgeMissions);
		WorkBadgeMissionTriggerUtility.setIsActive(workBadgeMissions);
		WorkBadgeMissionTriggerUtility.validateNoDuplicateMessages(workBadgeMissions, null);
		WorkBadgeMissionTriggerUtility.validateNoDuplicateMissions(workBadgeMissions, null);
	}

	public override void beforeUpdate() {
		WorkBadgeMissionTriggerUtility.validateActiveBadge(workBadgeMissions);
		WorkBadgeMissionTriggerUtility.setSourceId(workBadgeMissions);
		WorkBadgeMissionTriggerUtility.validateNoDuplicateMessages(workBadgeMissions, oldMap);
		WorkBadgeMissionTriggerUtility.validateNoDuplicateMissions(workBadgeMissions, oldMap);
	}
}