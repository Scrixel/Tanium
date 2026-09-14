/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
/**
 * @description Helper class for the trigger x7sEventsFeedItemTrigger
 */
public with sharing class x7sEventsFeedItemTriggerHelper {
	static final String EVENTS_SETTING = 'Default';

	public static void handleEventsFeedItemInsert(List<FeedItem> feedItems) {
		X7S_Events_Setting__mdt eventsSetting;

		if (!Test.isRunningTest()) {
			// Check the Notification setting in Event Settings
			eventsSetting = X7S_Events_Setting__mdt.getInstance(EVENTS_SETTING);

			if (!eventsSetting.Notify_Organizer_of_New_Posts_Chatter__c) {
				return;
			}
		}

		Map<Id, FeedItem> eventFeedItems = new Map<Id, FeedItem>();

		// Get all the feed items that are related to events
		for (FeedItem feedItem : feedItems) {
			if (feedItem.ParentId == null) {
				continue;
			}

			if (feedItem.ParentId.getSobjectType() != X7S_Event__c.SObjectType) {
				continue;
			}

			// Feed item is connected to an event, continue checking
			eventFeedItems.put(feedItem.ParentId, feedItem);
		}

		List<String> organizerIds = new List<String>();
		Map<String, X7S_Event__c> events = new Map<String, X7S_Event__c>();

		if (!eventFeedItems.isEmpty()) {
			// Load all the events
			events = new Map<String, X7S_Event__c>(
				[
					SELECT Id, Event_Organizer__c
					FROM X7S_Event__c
					WHERE Id IN :eventFeedItems.keySet()
					WITH SECURITY_ENFORCED
				]
			);
		}

		if (!events.isEmpty()) {
			// Load all organizers

			for (X7S_Event__c event : events.values()) {
				if (event.Event_Organizer__c != null) {
					organizerIds.add(event.Event_Organizer__c);
				}
			}
		}

		if (!organizerIds.isEmpty()) {
			Map<String, User> eventOrganizers = new Map<String, User>(
				[
					SELECT Id, X7S_Event_Feed_Notification_Chatter__c
					FROM User
					WHERE Id IN :organizerIds
					WITH SECURITY_ENFORCED
				]
			);
			Map<String, X7S_Event__c> feedItemEventMap = new Map<String, X7S_Event__c>();

			if (eventOrganizers.isEmpty()) {
				return;
			}

			for (FeedItem feedItem : eventFeedItems.values()) {
				X7S_Event__c currentEvent = events.get(feedItem.ParentId);

				if (currentEvent.Event_Organizer__c == null) {
					continue;
				}

				if (currentEvent.Event_Organizer__c == UserInfo.getUserId()) {
					continue;
				}

				User eventOrganizer = eventOrganizers.get(currentEvent.Event_Organizer__c);

				if (!eventOrganizer.X7S_Event_Feed_Notification_Chatter__c) {
					return;
				}

				// Store Feed Item Id and Event
				feedItemEventMap.put(feedItem.Id, currentEvent);
			}

			UpdateFeedItems(feedItemEventMap, eventsSetting);
		}
	}

	private static void UpdateFeedItems(
		Map<String, X7S_Event__c> feedItemEventMap,
		X7S_Events_Setting__mdt eventsSetting
	) {
		String networkId = Network.getNetworkId();
		ConnectApi.BatchResult[] results = ConnectApi.ChatterFeeds.getFeedElementBatch(
			networkId,
			new List<String>(feedItemEventMap.keySet())
		);

		for (ConnectApi.BatchResult result : results) {
			if (result.isSuccess()) {
				Object theResult = result.getResult();

				if (theResult instanceof ConnectApi.FeedItem) {
					ConnectApi.FeedItem item = (ConnectApi.FeedItem) theResult;

					// Convert body to input segments
					x7sEventsConnectApiHelper connectApiHelper = new x7sEventsConnectApiHelper();
					ConnectApi.FeedItemInput input = connectApiHelper.createFeedItemInputFromBody(item.body);

					// Modify the feed item content
					ModifyFeedBody(input, feedItemEventMap.get(item.id), eventsSetting);

					// Update the feed item, no batch process to update in bulk
					ConnectApi.ChatterFeeds.updateFeedElement(networkId, item.id, input);
				}
			} else {
				System.debug('Error retrieving feed item: ' + result.getErrorMessage());
			}
		}
	}

	private static void ModifyFeedBody(
		ConnectApi.FeedItemInput feedItem,
		X7S_Event__c event,
		X7S_Events_Setting__mdt eventsSetting
	) {
		// Add mention to event organizer to chatter post
		ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();
		textSegmentInput.text = '\n';

		feedItem.body.messageSegments.add(textSegmentInput);

		ConnectApi.MentionSegmentInput mentionSegment = new ConnectApi.MentionSegmentInput();
		mentionSegment.id = event.Event_Organizer__c;

		feedItem.body.messageSegments.add(mentionSegment);

		if (
			(eventsSetting != null && eventsSetting.Show_Notification_Label__c) || (Test.isRunningTest())
		) {
			ConnectApi.TextSegmentInput textSegmentInputNotification = new ConnectApi.TextSegmentInput();
			textSegmentInputNotification.text = System.Label.x7sEventsMentionText;

			feedItem.body.messageSegments.add(textSegmentInputNotification);
		}
	}
}