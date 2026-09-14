public with sharing class OpportunityTeamMemberTriggerHandler extends TriggerHandler {
	OpportunityTeamMember[] newOpportunityTeamMemberList, oldOpportunityTeamMemberList;

	public OpportunityTeamMemberTriggerHandler() {
		super('OpportunityTeamMemberTriggerHandler');
		this.newOpportunityTeamMemberList = (List<OpportunityTeamMember>) Trigger.new;
		this.oldOpportunityTeamMemberList = (List<OpportunityTeamMember>) Trigger.old;
	}

	public override void beforeInsert() {
		OpportunityTeamMemberLockUtility.isOpportunityTeamLocked(newOpportunityTeamMemberList);
	}

	public override void beforeDelete() {
		OpportunityTeamMemberLockUtility.isOpportunityTeamLocked(oldOpportunityTeamMemberList);
	}

	public override void beforeUpdate() {
		OpportunityTeamMemberLockUtility.isOpportunityTeamLocked(newOpportunityTeamMemberList);
	}
}