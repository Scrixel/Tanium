@IsTest
private class OpportunityTeamMemberLockUtilityTest {
	@TestSetup
	static void testSetup() {
		TriggerHandler.bypass(new List<String>{ 'OpportunityTriggerHandler', 'UserTriggerHandler' });
		SBQQ.TriggerControl.disable();

		System.runAs(getAutomationUser()) {
			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opp',
				System.today().addDays(30),
				Utility.PROSPECTING,
				null
			);
			opp.Opportunity_Team_Locked__c = false;
			insert opp;

			List<User> users = new List<User>();
			users.add(TestUserFactory.createBasicUser('testUser1', Utility.getSuperUserProfileId()));
			users.add(TestUserFactory.createBasicUser('testUser2', Utility.getSuperUserProfileId()));
			insert users;

			List<OpportunityTeamMember> oppTeamMembers = new List<OpportunityTeamMember>();
			oppTeamMembers.add(new OpportunityTeamMember(OpportunityId = opp.Id, UserId = users[0].Id));
			oppTeamMembers.add(new OpportunityTeamMember(OpportunityId = opp.Id, UserId = users[1].Id));
			insert oppTeamMembers;
		}
	}

	@IsTest
	public static void isOpportunityTeamLocked_WhenLockCheckboxTrue_ReturnsTrue() {
		Boolean actual;
		TriggerHandler.bypass('OpportunityTriggerHandler');
		SBQQ.TriggerControl.disable();

		System.runAs(getAutomationUser()) {
			Opportunity opp = [SELECT Id, Opportunity_Team_Locked__c FROM Opportunity LIMIT 1];
			opp.Opportunity_Team_Locked__c = true;
			update opp;
		}

		List<OpportunityTeamMember> opportunityTeamMembers = [
			SELECT Id, OpportunityId
			FROM OpportunityTeamMember
		];

		Test.startTest();
		actual = OpportunityTeamMemberLockUtility.isOpportunityTeamLocked(opportunityTeamMembers);
		Test.stopTest();

		System.assertEquals(
			true,
			actual,
			'Opportunity Team Lock checkbox set to true should prevent changes on opportunity team'
		);
	}

	@IsTest
	public static void isOpportunityTeamLocked_WhenLockCheckboxFalse_ReturnsFalse() {
		Boolean actual;

		List<OpportunityTeamMember> oppoTeamMembers = [
			SELECT Id, OpportunityId
			FROM OpportunityTeamMember
		];

		Test.startTest();
		actual = OpportunityTeamMemberLockUtility.isOpportunityTeamLocked(oppoTeamMembers);
		Test.stopTest();

		System.assertEquals(
			false,
			actual,
			'Opportunity Team Lock checkbox set to false should allow changes on opportunity team'
		);
	}

	static User getAutomationUser() {
		User[] automationUsers = [
			SELECT Id
			FROM User
			WHERE LastName = :TestUserFactory.AUTOMATION_ADMIN_USER
		];
		if (automationUsers.isEmpty()) {
			User automationUser = TestUserFactory.createAutomationAdminUser(true);
			TestingUtility.assignPermissionSet(automationUser.Id, 'DisableValidationRules');
			TestingUtility.assignPermissionSet(automationUser.Id, 'DisableFlows');
			return automationUser;
		}
		return automationUsers[0];
	}
}