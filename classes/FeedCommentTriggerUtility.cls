/*
 * @DATE: 2024-10-16
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Trigger Utility for the FeedCommentTrigger class
 * RequestId  ModifiedDate  Comment
 * SS-9451    2024-11-20    Created the FeedCommentTriggerUtility class
 * SS-8303    2024-12-05    Added method publishWorkBadgeMissionEvent
 */
public with sharing class FeedCommentTriggerUtility {
	public static final Set<String> CLOSED_STATUSES = new Set<String>{
		'Closed',
		'Closed as Duplicate'
	};

	public static void preventFeedCommentsOnClosedCases(List<FeedComment> feedComments) {
		Map<Id, FeedComment> caseIdsFeedCommentMap = new Map<Id, FeedComment>();

		for (FeedComment feedComment : feedComments) {
			if (Utility.isCase(feedComment.ParentId)) {
				caseIdsFeedCommentMap.put(feedComment.ParentId, feedComment);
			}
		}

		for (Case caseRec : [
			SELECT Id, Status
			FROM Case
			WHERE Id IN :caseIdsFeedCommentMap.keySet() AND Status IN :CLOSED_STATUSES
		]) {
			caseIdsFeedCommentMap.get(caseRec.Id)
				.addError('You cannot comment to a closed case. Please open a new case.');
		}
	}

	public static void publishWorkBadgeMissionEvent(List<FeedComment> feedComments) {
		List<Integration_Callout__c> callouts = new List<Integration_Callout__c>();

		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;

		for (FeedComment feedComment : feedComments) {
			workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
			workBadgeMissionEvent.InsertedById__c = feedComment.InsertedById;
			workBadgeMissionEvent.FeedItemId__c = feedComment.FeedItemId;
			workBadgeMissionEvent.FeedCommentId__c = feedComment.Id;
			workBadgeMissionEvent.Type__c = feedComment.CommentType;
			workBadgeMissionEvents.add(workBadgeMissionEvent);
		}

		Database.SaveResult[] publishResults = EventBus.publish(workBadgeMissionEvents);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'FeedCommentTriggerUtility.publishWorkBadgeMissionEvent() ERRORS',
				publishResults
			)
			.addTag('apex')
			.addTag('platform-event');
		for (Database.SaveResult publishResult : publishResults) {
			if (publishResult.isSuccess()) {
				callouts.add(
					new Integration_Callout__c(Name = 'WorkBadgeMissionEvent__e - ' + publishResult.getId())
				);
			}
		}
		Database.SaveResult[] insertResults = Database.insert(callouts);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'FeedCommentTriggerUtility.publishWorkBadgeMissionEvent() ERRORS',
				insertResults
			)
			.addTag('apex');
		Logger.saveLog();
	}
}