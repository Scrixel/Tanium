/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Trigger Handler for the CaseTrigger class.
 * @Date: 2020-05-12
 * @Author: Jason Johnson, Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-7278      2024-02-06       Jason Johnson's last changes (SCLOUD-705)
 * SS-7278      2024-02-16       Adjusting variables as a first step to align the class into our triggering framework
 * SS-7740      2024-04-22       Added call to method sevIncreaseSlackNotification
 * SS-7436      2024-08-27       Resolve tech debts
 * SS-9019      2024-09-18       Move methods to CaseTriggerUtilityWithoutSharing
 * SS-9459      2024-10-16       Remove processOmniChannel method
 * SS-13423     2026-06-24       Added call to method handleCaseOwnerChange
 */
public class CaseTriggerHandler extends TriggerHandler {
	private List<Case> cases { get; set; }
	private Map<Id, Case> oldMap { get; set; }

	public CaseTriggerHandler() {
		this.cases = (List<Case>) Trigger.new;
		this.oldMap = (Map<Id, Case>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		CaseTriggerUtilityWithoutSharing.setAssignedDate(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.processEscalationChange(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setEscalationLevelWatermark(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setFirstSMEAssignedDate(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setFirstSolvedDate(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setEscalationSMEOwnerChange(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setEscalationSLO(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setLastCustomerResponseDate(cases);
		CaseTriggerUtility.setCaseTeamField(cases);
	}

	public override void afterInsert() {
		CaseTriggerUtilityWithoutSharing.handleCaseOwnerChange(cases, oldMap);
	}

	public override void beforeUpdate() {
		CaseTriggerUtilityWithoutSharing.setAssignedDate(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setDeescalationDate(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.processEscalationChange(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setEscalationLevelWatermark(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setFirstSMEAssignedDate(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setFirstSolvedDate(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setEscalationSMEOwnerChange(cases, oldMap);
		CaseTriggerUtilityWithoutSharing.setEscalationSLO(cases, oldMap);
		CaseTriggerUtility.setCaseTeamField(cases);
	}

	public override void afterUpdate() {
		CaseTriggerUtilityWithoutSharing.handleCaseOwnerChange(cases, oldMap);
		CaseTriggerUtility.sevIncreaseSlackNotification(cases, oldMap);
	}
}