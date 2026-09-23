trigger OpportunityTeamMemberTrigger on OpportunityTeamMember(
	before insert,
	before update,
	before delete
) {
	new OpportunityTeamMemberTriggerHandler().run();
}