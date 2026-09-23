public with sharing class OpportunityTeamMemberLockUtility {
	public static Boolean isOpportunityTeamLocked(
		List<OpportunityTeamMember> opportunityTeamMembers
	) {
		Boolean opportunityTeamLocked = false;
		Set<Id> relatedOpportunityIds = new Set<Id>();

		for (OpportunityTeamMember opportunityTeamMember : opportunityTeamMembers) {
			relatedOpportunityIds.add(opportunityTeamMember.OpportunityId);
		}

		Map<Id, Opportunity> relatedOpportunityMap = new Map<Id, Opportunity>(
			[
				SELECT Id
				FROM Opportunity
				WHERE Id IN :relatedOpportunityIds AND Opportunity_Team_Locked__c = TRUE
			]
		);

		for (OpportunityTeamMember opportunityTeamMember : opportunityTeamMembers) {
			if (relatedOpportunityMap.keySet().contains(opportunityTeamMember.OpportunityId)) {
				opportunityTeamLocked = true;
				opportunityTeamMember.addError(System.Label.Opportunity_Team_Locked);
			}
		}
		return opportunityTeamLocked;
	}
}