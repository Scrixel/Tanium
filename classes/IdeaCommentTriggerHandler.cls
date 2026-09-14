/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Trigger Handler on the IdeaComment object.
 * RequestId  ModifiedDate  Comment
 * SS-8303    2025-01-14    Created the class
 */
public with sharing class IdeaCommentTriggerHandler extends TriggerHandler {
	public IdeaComment[] ideaComments { get; set; }
	public Map<Id, Idea> oldMap { get; set; }

	public IdeaCommentTriggerHandler() {
		super('IdeaCommentTriggerHandler');
		this.ideaComments = (IdeaComment[]) Trigger.new;
		this.oldMap = (Map<Id, Idea>) Trigger.oldMap;
	}

	public override void afterInsert() {
		List<IdeaComment> ideaCommentsToPublish = new List<IdeaComment>();

		for (IdeaComment ideaComment : ideaComments) {
			if (ideaComment.CommunityId == Constants.COMMUNITY_PLAYBOOK_IDEAS_ID) {
				ideaCommentsToPublish.add(ideaComment);
			}
		}
		if (!ideaCommentsToPublish.isEmpty()) {
			publishWorkBadgeMissionEvent(ideaCommentsToPublish);
		}
	}

	@TestVisible
	private static void publishWorkBadgeMissionEvent(IdeaComment[] ideaComments) {
		List<Integration_Callout__c> callouts = new List<Integration_Callout__c>();
		List<WorkBadgeMissionEvent__e> workBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		WorkBadgeMissionEvent__e workBadgeMissionEvent;

		for (IdeaComment ideaComment : ideaComments) {
			workBadgeMissionEvent = new WorkBadgeMissionEvent__e();
			workBadgeMissionEvent.InsertedById__c = ideaComment.CreatedById;
			workBadgeMissionEvent.IdeaId__c = ideaComment.IdeaId;
			workBadgeMissionEvent.IdeaCommentId__c = ideaComment.Id;
			workBadgeMissionEvent.Type__c = 'IdeaComment';
			workBadgeMissionEvents.add(workBadgeMissionEvent);
		}

		Database.SaveResult[] publishResults = EventBus.publish(workBadgeMissionEvents);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'IdeaCommentTriggerHandler.publishWorkBadgeMissionEvent() ERRORS',
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
				'IdeaCommentTriggerHandler.publishWorkBadgeMissionEvent() ERRORS',
				insertResults
			)
			.addTag('apex');
		Logger.saveLog();
	}
}