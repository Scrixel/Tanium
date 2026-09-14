/*
 * Copyright (c) 2025 Tanium
 *
 * @DATE: 2020-05-12
 * @AUTHOR: Jason Johnson, Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Trigger Handler for the FeedItemTrigger class.
 * RequestId  ModifiedDate  Comment
 * SCLOUD-    2022-05-12    Initial Development
 * SS-9220    2024-10-01    default value for feeditem.Body in before insert to stop null pointer exceptions on case
 * SS-9392    2024-10-09    Move back isCaseRelated and isCustomerCommunityRelated assignment to constructor
 * SS-9451    2024-10-16    Added call to method preventFeedItemsOnClosedCases
 * SS-8303    2024-12-05    Added call to method publishWorkBadgeMissionEvent
 * SS-11999   2025-11-03    Added call to method addFeedItemFilterFields
 * SS-12298   2026-01-13    Moved addFeedItemFilterFields method to afterInsert and best practice updates
 * SS-12885   2026-03-26    Added call to method processMilestoneEventFeedItems
 */
public class FeedItemTriggerHandler extends TriggerHandler {
	private List<FeedItem> feedItems { get; set; }

	public FeedItemTriggerHandler() {
		super('FeedItemTriggerHandler');
		feedItems = (List<FeedItem>) Trigger.new;
	}

	public override void beforeInsert() {
		FeedItemTriggerUtility.preventFeedItemsOnClosedCases(feedItems);
		FeedItemTriggerUtility.processMilestoneEventFeedItems(feedItems);
	}

	public override void afterInsert() {
		RoscoCaseProcesses.processFirstResponseDate(null, feedItems[0]);
		RoscoCaseProcesses.processLastResponseDate(null, feedItems[0]);
		RoscoCaseProcesses.processLastCustomerResponseDate(null, feedItems[0], null);
		CaseTriggerUtilityWithoutSharing.setCaseStatus(null, feedItems, null);
		CaseTriggerUtilityWithoutSharing.processFeedItem(feedItems);
		FeedItemTriggerUtility.publishWorkBadgeMissionEvent(feedItems);
		CaseTriggerUtilityWithoutSharing.processNewCmtyQuestion(feedItems[0]);

		if (!Test.isRunningTest()) {
			CaseTriggerUtilityWithoutSharing.addFeedItemFilterFields(feedItems);
		}
	}

	public override void afterUpdate() {
		RoscoCaseProcesses.processFirstResponseDate(null, feedItems[0]);
		RoscoCaseProcesses.processLastResponseDate(null, feedItems[0]);
		RoscoCaseProcesses.processLastCustomerResponseDate(null, feedItems[0], null);
		CaseTriggerUtilityWithoutSharing.setCaseStatus(null, feedItems, null);
	}
}