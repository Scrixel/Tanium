/*
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2026-02-11
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Test class for IdeaTriggerUtility. makeData covers IdeaTriggerHandler.
 * RequestId  ModifiedDate  Comment
 * SS-12618   2026-02-11    Created the class and moved test methods from IdeaTriggerHandlerTest
 */
@IsTest
private class IdeaTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Idea idea = new Idea(
				Title = 'Title',
				Body = 'SomeIdea',
				Categories = 'Improve Efficiency',
				CommunityId = Constants.COMMUNITY_PLAYBOOK_IDEAS_ID
			);
			insert idea;
			update idea;
		}
	}

	@IsTest
	static void testPublishWorkBadgeMissionEvent_WhenNewIdea_PublishPlatformEvent() {
		Idea[] ideas = [
			SELECT Id, CreatedById
			FROM Idea
		];

		Test.startTest();
		IdeaTriggerUtility.publishWorkBadgeMissionEvent(ideas);
		Test.stopTest();

		Integration_Callout__c[] callouts = [SELECT Id FROM Integration_Callout__c];
		Assert.isFalse(callouts.isEmpty());
	}
}