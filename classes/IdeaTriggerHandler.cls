/*
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Trigger Handler on the Idea object.
 * RequestId  ModifiedDate  Comment
 * SS-8303    2025-01-14    Created the class
 * SS-12618   2026-02-11    Delegated trigger logic to IdeaTriggerUtility
 */
public with sharing class IdeaTriggerHandler extends TriggerHandler {
	public List<Idea> ideas { get; set; }
	public Map<Id, Idea> oldMap { get; set; }

	public IdeaTriggerHandler() {
		super('IdeaTriggerHandler');
		ideas = (List<Idea>) Trigger.new;
		oldMap = (Map<Id, Idea>) Trigger.oldMap;
	}

	public override void afterInsert() {
		IdeaTriggerUtility.publishWorkBadgeMissionEvent(ideas);
	}
}