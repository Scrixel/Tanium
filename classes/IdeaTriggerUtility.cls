/*
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2026-02-11
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Trigger Utility for the Idea object.
 * RequestId  ModifiedDate  Comment
 * SS-12618    2026-02-11    Created the class and extracted business logic from IdeaTriggerHandler
 */
public with sharing class IdeaTriggerUtility {
	public static void publishWorkBadgeMissionEvent(List<Idea> ideas) {
		List<Idea> ideasWithCommunity = getIdeasWithCommunity(ideas);
		List<Integration_Callout__c> callouts = new List<Integration_Callout__c>();
		List<Idea> ideasToPublish = new List<Idea>();

		for (Idea idea : ideasWithCommunity) {
			if (idea.CommunityId == Constants.COMMUNITY_PLAYBOOK_IDEAS_ID) {
				ideasToPublish.add(idea);
			}
		}

		if (ideasToPublish.isEmpty()) {
			return;
		}

		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;

		for (Idea ideaToPublish : ideasToPublish) {
			workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
			workBadgeMissionEvent.InsertedById__c = ideaToPublish.CreatedById;
			workBadgeMissionEvent.IdeaId__c = ideaToPublish.Id;
			workBadgeMissionEvent.Type__c = 'IdeaPost';
			workBadgeMissionEvents.add(workBadgeMissionEvent);
		}

		Database.SaveResult[] publishResults = EventBus.publish(workBadgeMissionEvents);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'IdeaTriggerUtility.publishWorkBadgeMissionEvent() ERRORS',
				publishResults
			)
			.addTag('apex')
			.addTag('platform-event');
		for (Database.SaveResult publishResult : publishResults) {
			if (publishResult.isSuccess()) {
				callouts.add(
					new Integration_Callout__c(
						Name = 'WorkBadgeMissionEvent__e - ' + publishResult.getId()
					)
				);
			}
		}
		Database.SaveResult[] insertResults = Database.insert(callouts);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'IdeaTriggerUtility.publishWorkBadgeMissionEvent() ERRORS',
				insertResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	private static List<Idea> getIdeasWithCommunity(List<Idea> ideas) {
		Set<Id> ideaIds = new Set<Id>();
		for (Idea idea : ideas) {
			ideaIds.add(idea.Id);
		}
		return [
			SELECT Id, CreatedById, CommunityId
			FROM Idea
			WHERE Id IN :ideaIds
		];
	}
}