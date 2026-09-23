/*
 * Copyright (c) 2025 Tanium
 *
 * @AUTHOR: Jason Johnson, Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Trigger Handler for the FeedCommentTrigger class.
 * RequestId  ModifiedDate  Comment
 * SCLOUD-    2022-05-12    Initial Development
 * SS-9463    2024-11-19    Constructor clean up
 * SS-9451    2024-11-20    Added the call to preventFeedCommentsOnClosedCases
 * SS-8303    2024-12-18    Added call to method publishWorkBadgeMissionEvent
 * SS-11999   2025-11-03    Added call to method addFeedCommentFilterFields
 * SS-12298   2026-01-06    Moved addFeedCommentFilterFields method to afterInsert
 */
public class FeedCommentTriggerHandler extends TriggerHandler {
	private List<FeedComment> feedComments { get; set; }
	private FeedComment feedComment { get; set; }

	public FeedCommentTriggerHandler() {
		super('FeedCommentTriggerHandler');
		feedComments = (List<FeedComment>) Trigger.new;
		feedComment = feedComments != null ? feedComments[0] : null;
	}

	public override void beforeInsert() {
		FeedCommentTriggerUtility.preventFeedCommentsOnClosedCases(feedComments);
	}

	public override void afterInsert() {
		if (Utility.isCase(feedComment?.ParentId)) {
			RoscoCaseProcesses.processLastCustomerResponseDate(null, null, feedComment);
			CaseTriggerUtilityWithoutSharing.setCaseStatus(null, null, feedComments);
			CaseTriggerUtilityWithoutSharing.processFeedComment(feedComments);
		} else {
			FeedCommentTriggerUtility.publishWorkBadgeMissionEvent(feedComments);
		}
		if (!Test.isRunningTest()) {
			CaseTriggerUtilityWithoutSharing.addFeedCommentFilterFields(feedComments);
		}
	}

	public override void afterUpdate() {
		if (Utility.isCase(feedComment?.ParentId)) {
			RoscoCaseProcesses.processLastCustomerResponseDate(null, null, feedComment);
			CaseTriggerUtilityWithoutSharing.setCaseStatus(null, null, feedComments);
		}
	}
}