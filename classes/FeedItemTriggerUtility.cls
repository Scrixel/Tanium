/*
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2024-10-16
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Trigger Utility for the FeedItemTrigger class
 * RequestId  ModifiedDate  Comment
 * SS-9451    2024-10-16    Created the FeedItemTriggerUtility class
 * SS-8303    2024-12-05    Added method publishWorkBadgeMissionEvent
 * SS-12298   2026-01-13    Added logic to check parent object type
 * SS-12885   2026-03-26    Added logic to update feed item visibility for milestone events
 */
public with sharing class FeedItemTriggerUtility {
	public static void preventFeedItemsOnClosedCases(List<FeedItem> feedItems) {
		Map<Id, FeedItem> caseIdToFeedItem = new Map<Id, FeedItem>();
		for (FeedItem feedItem : feedItems) {
			if (feedItem?.ParentId?.getSObjectType() == Case.SObjectType) {
				caseIdToFeedItem.put(feedItem.ParentId, feedItem);
			}
		}

		for (Case caseRec : [
			SELECT Id
			FROM Case
			WHERE Id IN :caseIdToFeedItem.keySet() AND Status IN :Constants.CASE_CLOSE_STATUSES
		]) {
			caseIdToFeedItem.get(caseRec.Id)
				.addError('You cannot post to a closed case. Please open a new case.');
		}
	}

	public static void publishWorkBadgeMissionEvent(List<FeedItem> feedItems) {
		List<Integration_Callout__c> callouts = new List<Integration_Callout__c>();
		List<FeedItem> feedItemsToPublish = new List<FeedItem>();
		Set<String> eligibleTypes = new Set<String>{
			'QuestionPost',
			'TextPost',
			'LinkPost',
			'ContentPost',
			'PollPost',
			'AdvancedTextPost'
		};

		for (FeedItem feedItem : feedItems) {
			if (
				feedItem?.ParentId?.getSObjectType() != Case.SObjectType &&
				eligibleTypes.contains(feedItem.Type)
			) {
				feedItemsToPublish.add(feedItem);
			}
		}

		if (feedItemsToPublish.isEmpty()) {
			return;
		}

		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;

		for (FeedItem feedItemToPublish : feedItemsToPublish) {
			workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
			workBadgeMissionEvent.InsertedById__c = feedItemToPublish.InsertedById;
			workBadgeMissionEvent.FeedItemId__c = feedItemToPublish.Id;
			workBadgeMissionEvent.Type__c = feedItemToPublish.Type;
			workBadgeMissionEvents.add(workBadgeMissionEvent);
		}

		List<Database.SaveResult> publishResults = EventBus.publish(workBadgeMissionEvents);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'FeedItemTriggerUtility.publishWorkBadgeMissionEvent() ERRORS',
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
		List<Database.SaveResult> insertResults = Database.insert(callouts);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'FeedItemTriggerUtility.publishWorkBadgeMissionEvent() ERRORS',
				insertResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	public static void processMilestoneEventFeedItems(List<FeedItem> feedItems) {
		for (FeedItem feedItem : feedItems) {
			if (feedItem.Type == 'MilestoneEvent') {
				feedItem.Visibility = 'InternalUsers';
			}
		}
	}
}