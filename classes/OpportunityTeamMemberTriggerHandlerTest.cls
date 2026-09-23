@IsTest
private class OpportunityTeamMemberTriggerHandlerTest {
	private static final String NEW_MEMBER_USERNAME = 'newMember';

	@TestSetup
	static void testSetup() {
		TriggerHandler.bypass(
			new List<String>{
				'OpportunityTriggerHandler',
				'OpportunityTeamMemberTriggerHandler',
				'UserTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();

		System.runAs(TestUserFactory.createAutomationAdminUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addDays(30),
				Utility.PROSPECTING,
				null
			);
			opp.Opportunity_Team_Locked__c = true;
			insert opp;

			List<User> users = new List<User>();
			users.add(TestUserFactory.createBasicUser('testUser1', Utility.getSuperUserProfileId()));
			users.add(TestUserFactory.createBasicUser('testUser2', Utility.getSuperUserProfileId()));
			users.add(
				TestUserFactory.createBasicUser(NEW_MEMBER_USERNAME, Utility.getSuperUserProfileId())
			);
			insert users;

			List<OpportunityTeamMember> oppTeamMembers = new List<OpportunityTeamMember>();
			oppTeamMembers.add(new OpportunityTeamMember(OpportunityId = opp.Id, UserId = users[0].Id));
			oppTeamMembers.add(new OpportunityTeamMember(OpportunityId = opp.Id, UserId = users[1].Id));
			insert oppTeamMembers;
		}
	}

	@IsTest
	static void beforeInsert_WhenOpportunityTeamLocked_ShowsError() {
		String expectedError = '';
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		User newMember = [SELECT Id FROM User WHERE LastName = :NEW_MEMBER_USERNAME];

		OpportunityTeamMember newTeamMember = new OpportunityTeamMember(
			OpportunityId = opportunity.Id,
			UserId = newMember.Id
		);

		Test.startTest();
		System.runAs(TestUserFactory.createSalesOpsUser()) {
			try {
				insert newTeamMember;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
		}
		Test.stopTest();

		System.assertEquals(
			true,
			expectedError.contains(System.Label.Opportunity_Team_Locked),
			'Opportunity Team Lock checkbox set to true should result in error when inserting new team member'
		);
	}

	@IsTest
	static void beforeDelete_WhenOpportunityTeamLocked_ShowsError() {
		String expectedError = '';

		OpportunityTeamMember oldTeamMember = [
			SELECT Id
			FROM OpportunityTeamMember
			ORDER BY Id DESC
			LIMIT 1
		];

		Test.startTest();
		System.runAs(TestUserFactory.createSalesOpsUser()) {
			try {
				delete oldTeamMember;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
		}
		Test.stopTest();

		System.assertEquals(
			true,
			expectedError.contains(System.Label.Opportunity_Team_Locked),
			'Opportunity Team Lock checkbox set to true should result in error when deleting old team member'
		);
	}

	@IsTest
	static void beforeUpdate_WhenOpportunityTeamLocked_ShowsError() {
		String expectedError = '';

		OpportunityTeamMember oldTeamMember = [
			SELECT Id, TeamMemberRole
			FROM OpportunityTeamMember
			ORDER BY Id DESC
			LIMIT 1
		];

		Test.startTest();
		System.runAs(TestUserFactory.createSalesOpsUser()) {
			try {
				oldTeamMember.TeamMemberRole = 'BDR';
				update oldTeamMember;
			} catch (Exception error) {
				expectedError = error.getMessage();
			}
		}
		Test.stopTest();

		System.assertEquals(
			true,
			expectedError.contains(System.Label.Opportunity_Team_Locked),
			'Opportunity Team Lock checkbox set to true should result in error when updating old team member'
		);
	}
}