/*
 * @DATE: 2024-12-05
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Trigger Utility class on the WorkBadgeMission__c object
 * RequestId  ModifiedDate  Comment
 * SS-8303    2024-12-05    Created the class
 * SS-12082   2025-11-19    Updated to use Constants.CUSTOMER_COMMUNITY_MANAGER_ID
 */
public without sharing class WorkBadgeMissionTriggerUtility {
	public static final Id CUSTOMER_COMMUNITY_ID = Utility.getNetworkId('Tanium Customer Community');
	private static final String QUESTION_ACTION = 'Ask a question';
	private static final String ANSWER_ACTION = 'Answer a question';
	private static final String POST_ACTION = 'Add a Post';
	private static final String COMMENT_ACTION = 'Add a Comment';
	private static final String IDEA_ACTION = 'Create an Idea';
	public static final String BEST_ANSWER_ACTION = 'Best Answer';
	public static final String UPLOAD_PROFILE_IMAGE_BADGE = 'Profile Image';
	private static final String QUESTION_POST_TYPE = 'QuestionPost';
	private static final Set<String> NON_QUESTION_POST_TYPE = new Set<String>{
		'TextPost',
		'LinkPost',
		'ContentPost',
		'PollPost',
		'AdvancedTextPost'
	};
	private static final Set<String> COMMENT_TYPES = new Set<String>{
		'TextComment',
		'ContentComment'
	};
	private static final String IDEA_POST = 'IdeaPost';
	private static final String IDEA_COMMENT = 'IdeaComment';
	private static final Date programLaunchDate = Date.newInstance(2024, 11, 20);

	public static void validateActiveBadge(WorkBadgeMission__c[] workBadgeMissions) {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = WorkBadgeDefinitionExtTriggerUtility.getWorkBadgeNameDefinitionMap();

		for (WorkBadgeMission__c workBadgeMission : workBadgeMissions) {
			if (!workBadgeNameDefinitionMap.containsKey(workBadgeMission.Badge_Name__c)) {
				workBadgeMission.addError(
					'Unable to find an existing badge with name ' + workBadgeMission.Badge_Name__c
				);
			} else {
				if (!workBadgeNameDefinitionMap.get(workBadgeMission.Badge_Name__c).IsActive) {
					workBadgeMission.addError(
						'Existing badge with name ' + workBadgeMission.Badge_Name__c + ' is not Active'
					);
				}
			}
		}
	}

	public static void setSourceId(WorkBadgeMission__c[] workBadgeMissions) {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = WorkBadgeDefinitionExtTriggerUtility.getWorkBadgeNameDefinitionMap();

		for (WorkBadgeMission__c workBadgeMission : workBadgeMissions) {
			if (workBadgeNameDefinitionMap.containsKey(workBadgeMission.Badge_Name__c)) {
				workBadgeMission.SourceId__c = workBadgeNameDefinitionMap.get(
						workBadgeMission.Badge_Name__c
					)
					.Id;
			}
		}
	}

	public static void setMessage(WorkBadgeMission__c[] workBadgeMissions) {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = WorkBadgeDefinitionExtTriggerUtility.getWorkBadgeNameDefinitionMap();

		for (WorkBadgeMission__c workBadgeMission : workBadgeMissions) {
			if (workBadgeNameDefinitionMap.containsKey(workBadgeMission.Badge_Name__c)) {
				workBadgeMission.Message__c = workBadgeNameDefinitionMap.get(
						workBadgeMission.Badge_Name__c
					)
					.Description;
			}
		}
	}

	public static void setIsActive(WorkBadgeMission__c[] workBadgeMissions) {
		Map<String, WorkBadgeDefinition> workBadgeNameDefinitionMap = WorkBadgeDefinitionExtTriggerUtility.getWorkBadgeNameDefinitionMap();

		for (WorkBadgeMission__c workBadgeMission : workBadgeMissions) {
			if (workBadgeNameDefinitionMap.containsKey(workBadgeMission.Badge_Name__c)) {
				workBadgeMission.IsActive__c = workBadgeNameDefinitionMap.get(
						workBadgeMission.Badge_Name__c
					)
					.IsActive;
			}
		}
	}

	public static void validateNoDuplicateMessages(
		WorkBadgeMission__c[] workBadgeMissions,
		Map<Id, WorkBadgeMission__c> oldsMap
	) {
		Map<String, Id> messageMissionIdMap = new Map<String, Id>();

		for (WorkBadgeMission__c existingWorkBadgeMission : [
			SELECT Id, Message__c
			FROM WorkBadgeMission__c
			WHERE IsActive__c = TRUE
		]) {
			messageMissionIdMap.put(existingWorkBadgeMission.Message__c, existingWorkBadgeMission.Id);
		}

		for (WorkBadgeMission__c workBadgeMission : workBadgeMissions) {
			if (workBadgeMission.IsActive__c) {
				if (messageMissionIdMap.containsKey(workBadgeMission.Message__c)) {
					if (workBadgeMission.Id != messageMissionIdMap.get(workBadgeMission.Message__c)) {
						workBadgeMission.addError('This message already exists');
					}
				} else {
					messageMissionIdMap.put(workBadgeMission.Message__c, workBadgeMission.Id);
				}
			}
		}
	}

	public static void validateNoDuplicateMissions(
		WorkBadgeMission__c[] workBadgeMissions,
		Map<Id, WorkBadgeMission__c> oldsMap
	) {
		Map<String, Id> actionThresholdMissionIdMap = new Map<String, Id>();
		String actionThresholdString;

		for (WorkBadgeMission__c existingWorkBadgeMission : [
			SELECT Id, Action__c, Threshold__c
			FROM WorkBadgeMission__c
			WHERE IsActive__c = TRUE
		]) {
			actionThresholdMissionIdMap.put(
				existingWorkBadgeMission.Action__c +
				Integer.valueOf(existingWorkBadgeMission.Threshold__c),
				existingWorkBadgeMission.Id
			);
		}

		for (WorkBadgeMission__c workBadgeMission : workBadgeMissions) {
			if (workBadgeMission.IsActive__c) {
				actionThresholdString =
					workBadgeMission.Action__c + Integer.valueOf(workBadgeMission.Threshold__c);
				if (actionThresholdMissionIdMap.containsKey(actionThresholdString)) {
					if (workBadgeMission.Id != actionThresholdMissionIdMap.get(actionThresholdString)) {
						workBadgeMission.addError('This mission (action/threshold) already exists');
					}
				}
				actionThresholdMissionIdMap.put(actionThresholdString, workBadgeMission.Id);
			}
		}
	}

	public static void processEvent(WorkBadgeMissionEvent__e[] workBadgeMissionEvents) {
		List<WorkBadgeMissionEvent__e> questionWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		List<WorkBadgeMissionEvent__e> answerWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		List<WorkBadgeMissionEvent__e> postWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		List<WorkBadgeMissionEvent__e> commentWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		List<WorkBadgeMissionEvent__e> answerOrCommentWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		List<WorkBadgeMissionEvent__e> ideasWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();

		Utility.sleep(3);

		for (WorkBadgeMissionEvent__e workBadgeMissionEvent : workBadgeMissionEvents) {
			if (
				workBadgeMissionEvent.FeedItemId__c != null &&
				workBadgeMissionEvent.Type__c == QUESTION_POST_TYPE
			) {
				questionWorkBadgeMissionEvents.add(workBadgeMissionEvent);
			} else if (
				workBadgeMissionEvent.FeedItemId__c != null &&
				NON_QUESTION_POST_TYPE.contains(workBadgeMissionEvent.Type__c)
			) {
				postWorkBadgeMissionEvents.add(workBadgeMissionEvent);
			} else if (
				workBadgeMissionEvent.FeedItemId__c != null &&
				workBadgeMissionEvent.FeedCommentId__c != null &&
				COMMENT_TYPES.contains(workBadgeMissionEvent.Type__c)
			) {
				answerOrCommentWorkBadgeMissionEvents.add(workBadgeMissionEvent);
			} else if (
				workBadgeMissionEvent.IdeaId__c != null &&
				workBadgeMissionEvent.Type__c == IDEA_POST
			) {
				ideasWorkBadgeMissionEvents.add(workBadgeMissionEvent);
			} else if (
				workBadgeMissionEvent.IdeaCommentId__c != null &&
				workBadgeMissionEvent.Type__c == IDEA_COMMENT
			) {
				commentWorkBadgeMissionEvents.add(workBadgeMissionEvent);
			} else {
				continue;
			}
		}

		if (!answerOrCommentWorkBadgeMissionEvents.isEmpty()) {
			answerWorkBadgeMissionEvents = getCommentOrAnswerWorkBadgeMissionEvents(
				answerOrCommentWorkBadgeMissionEvents,
				'Answer'
			);
			commentWorkBadgeMissionEvents = getCommentOrAnswerWorkBadgeMissionEvents(
				answerOrCommentWorkBadgeMissionEvents,
				'Comment'
			);
		}

		if (!questionWorkBadgeMissionEvents.isEmpty()) {
			processEvent(questionWorkBadgeMissionEvents, QUESTION_ACTION);
		}
		if (!answerWorkBadgeMissionEvents.isEmpty()) {
			processEvent(answerWorkBadgeMissionEvents, ANSWER_ACTION);
		}
		if (!postWorkBadgeMissionEvents.isEmpty()) {
			processEvent(postWorkBadgeMissionEvents, POST_ACTION);
		}
		if (!commentWorkBadgeMissionEvents.isEmpty()) {
			processEvent(commentWorkBadgeMissionEvents, COMMENT_ACTION);
		}
		if (!ideasWorkBadgeMissionEvents.isEmpty()) {
			processEvent(ideasWorkBadgeMissionEvents, IDEA_ACTION);
		}
	}

	@TestVisible
	private static void processEvent(
		WorkBadgeMissionEvent__e[] workBadgeMissionEvents,
		String action
	) {
		Set<Id> userIds = new Set<Id>();

		for (WorkBadgeMissionEvent__e workBadgeMissionEvent : workBadgeMissionEvents) {
			userIds.add(workBadgeMissionEvent.InsertedById__c);
		}
		processEvent(userIds, action);
	}

	public static void processEvent(Set<Id> userIds, String action) {
		Map<Id, Integer> userIdCountActionsMap;
		Map<Integer, Id> thresholdBadgeIdMap;
		Map<Id, Set<Id>> userIdBadgeIdsMap;
		Set<String> newBadgeIdUserIdStrings = new Set<String>();
		Set<Id> eligibleWorkBadgeIds;
		Set<Id> assignedWorkBadgeIds;
		Integer actionCount = 0;

		switch on action {
			when 'Ask a question' {
				userIdCountActionsMap = getUserIdCountQuestionsMap(userIds);
			}
			when 'Answer a question' {
				userIdCountActionsMap = getUserIdCountAnswersMap(userIds);
			}
			when 'Best Answer' {
				userIdCountActionsMap = getUserIdCountBestAnswersMap(userIds);
			}
			when 'Add a Post' {
				userIdCountActionsMap = getUserIdCountPostsMap(userIds);
			}
			when 'Add a Comment' {
				userIdCountActionsMap = getUserIdCountCommentsMap(userIds);
			}
			when 'Create an Idea' {
				userIdCountActionsMap = getUserIdCountIdeasMap(userIds);
			}
			when else {
				userIdCountActionsMap = null;
			}
		}

		thresholdBadgeIdMap = getThresholdBadgeIdMap(action);
		userIdBadgeIdsMap = getUserIdBadgeIdsMap(userIds);

		for (Id userId : userIds) {
			actionCount = userIdCountActionsMap.get(userId);
			eligibleWorkBadgeIds = getEligibleBadges(actionCount, thresholdBadgeIdMap);
			assignedWorkBadgeIds = userIdBadgeIdsMap.get(userId);
			System.debug('CK22 action ' + action);
			System.debug('CK22 actionCount ' + actionCount);
			System.debug('CK22 eligibleWorkBadgeIds ' + eligibleWorkBadgeIds);
			System.debug('CK22 userIdBadgeIdsMap ' + userIdBadgeIdsMap);

			for (Id eligibleWorkBadgeId : eligibleWorkBadgeIds) {
				if (assignedWorkBadgeIds != null) {
					if (assignedWorkBadgeIds.contains(eligibleWorkBadgeId)) {
						continue;
					}
				}
				newBadgeIdUserIdStrings.add(
					String.valueOf(eligibleWorkBadgeId) + '***' + String.valueOf(userId)
				);
			}
		}
		if (!newBadgeIdUserIdStrings.isEmpty()) {
			assignBadge(newBadgeIdUserIdStrings);
		}
	}

	@TestVisible // get total number of existing questions per user
	private static Map<Id, Integer> getUserIdCountQuestionsMap(Set<Id> insertedByIds) {
		FeedItem[] feedItems = getFeedItems(new Set<String>{ QUESTION_POST_TYPE }, insertedByIds);

		return getUserIdCountUniquePostsMap(feedItems); // questions is a type of posts;
	}

	@TestVisible // get total number of existing posts (minus questions) per user
	private static Map<Id, Integer> getUserIdCountPostsMap(Set<Id> insertedByIds) {
		Map<Id, Integer> userIdCountUniquePostsMap = new Map<Id, Integer>();
		Id insertedById = null;
		Integer countPosts = 0;

		FeedItem[] feedItems = getFeedItems(NON_QUESTION_POST_TYPE, insertedByIds);
		userIdCountUniquePostsMap = getUserIdCountUniquePostsMap(feedItems);

		for (Idea idea : getIdeas(insertedByIds)) {
			if (insertedById == idea.CreatedById || insertedById != null) {
				countPosts++;
				insertedById = idea.CreatedById;
			}
			if (insertedById != idea.CreatedById) {
				if (userIdCountUniquePostsMap.containsKey(insertedById)) {
					userIdCountUniquePostsMap.put(
						insertedById,
						userIdCountUniquePostsMap.get(insertedById) + countPosts
					);
				} else {
					userIdCountUniquePostsMap.put(insertedById, countPosts);
				}
				countPosts = 1;
				insertedById = idea.CreatedById;
			}
		}
		if (insertedById != null) {
			if (userIdCountUniquePostsMap.containsKey(insertedById)) {
				userIdCountUniquePostsMap.put(
					insertedById,
					userIdCountUniquePostsMap.get(insertedById) + countPosts
				);
			} else {
				userIdCountUniquePostsMap.put(insertedById, countPosts);
			}
		}
		return userIdCountUniquePostsMap;
	}

	@TestVisible // get total number of existing answers per user
	private static Map<Id, Integer> getUserIdCountAnswersMap(Set<Id> insertedByIds) {
		FeedItem[] feedItems = getFeedItems(new Set<String>{ QUESTION_POST_TYPE }, null);
		Map<Id, FeedComment> feedCommentMap = getFeedCommentMap(
			new Map<Id, FeedItem>(feedItems).keySet(),
			insertedByIds
		);

		return getUserIdCountUniqueCommentsMap(feedCommentMap, insertedByIds); // Answer is a comment against a question
	}

	@TestVisible // get total number of best answers per user
	private static Map<Id, Integer> getUserIdCountBestAnswersMap(Set<Id> insertedByIds) {
		FeedItem[] feedItems = getFeedItems(new Set<String>{ QUESTION_POST_TYPE }, null, true);
		FeedComment[] feedComments = getBestAnswerFeedComments(
			new Map<Id, FeedItem>(feedItems).keySet(),
			insertedByIds
		);

		return getUserIdCountBestAnswersMap(feedComments, insertedByIds); // Answer is a comment against a question
	}

	@TestVisible // get total number of existing comments per user
	private static Map<Id, Integer> getUserIdCountCommentsMap(Set<Id> insertedByIds) {
		Map<Id, Integer> userIdCountCommentsMap = new Map<Id, Integer>();
		Id insertedById = null;
		Integer countIdeaComments = 0;

		FeedItem[] feedItems = getFeedItems(NON_QUESTION_POST_TYPE, null);
		Map<Id, FeedComment> feedCommentMap = getFeedCommentMap(
			new Map<Id, FeedItem>(feedItems).keySet(),
			insertedByIds
		);

		userIdCountCommentsMap = getUserIdCountUniqueCommentsMap(feedCommentMap, insertedByIds);

		IdeaComment[] ideaComments = getIdeaComments(insertedByIds);
		for (IdeaComment ideaComment : ideaComments) {
			if (insertedById == ideaComment.CreatedById || insertedById == null) {
				countIdeaComments++;
				insertedById = ideaComment.CreatedById;
			}
			if (insertedById != ideaComment.CreatedById) {
				if (userIdCountCommentsMap.containsKey(insertedById)) {
					userIdCountCommentsMap.put(
						insertedById,
						userIdCountCommentsMap.get(insertedById) + countIdeaComments
					);
				} else {
					userIdCountCommentsMap.put(insertedById, countIdeaComments);
				}
				countIdeaComments = 1;
				insertedById = ideaComment.CreatedById;
			}
		}
		if (insertedById != null) {
			if (userIdCountCommentsMap.containsKey(insertedById)) {
				userIdCountCommentsMap.put(
					insertedById,
					userIdCountCommentsMap.get(insertedById) + countIdeaComments
				);
			} else {
				userIdCountCommentsMap.put(insertedById, countIdeaComments);
			}
		}
		return userIdCountCommentsMap;
	}

	@TestVisible // get total number of existing ideas per user
	private static Map<Id, Integer> getUserIdCountIdeasMap(Set<Id> insertedByIds) {
		Map<Id, Integer> userIdCountIdeasMap = new Map<Id, Integer>();
		Id insertedById = null;
		Integer countIdeas = 0;

		for (Idea idea : getIdeas(insertedByIds)) {
			if (insertedById == idea.CreatedById || insertedById == null) {
				countIdeas++;
				insertedById = idea.CreatedById;
			}
			if (insertedById != idea.CreatedById) {
				userIdCountIdeasMap.put(insertedById, countIdeas);
				countIdeas = 1;
				insertedById = idea.CreatedById;
			}
		}
		if (insertedById != null) {
			userIdCountIdeasMap.put(insertedById, countIdeas);
		}

		return userIdCountIdeasMap;
	}

	// Check what WorkBadge missions exist for this Action type
	public static Map<Integer, Id> getThresholdBadgeIdMap(String action) {
		Map<Integer, Id> thresholdBadgeIdMap = new Map<Integer, Id>();
		Set<Id> activeWorkBadgeIds = new Set<Id>();

		for (WorkBadgeMission__c workBadgeMission : [
			SELECT Id, SourceId__c
			FROM WorkBadgeMission__c
			WHERE Action__c = :action AND IsActive__c = TRUE
		]) {
			activeWorkBadgeIds.add(Id.valueOf(workBadgeMission.SourceId__c));
		}

		for (WorkBadgeDefinition workBadge : [
			SELECT Id, IsActive
			FROM WorkBadgeDefinition
			WHERE Id IN :activeWorkBadgeIds
		]) {
			if (!workBadge.IsActive) {
				activeWorkBadgeIds.remove(workBadge.Id);
			}
		}

		for (WorkBadgeMission__c workBadgeMission : [
			SELECT Id, SourceId__c, Threshold__c
			FROM WorkBadgeMission__c
			WHERE SourceId__c IN :activeWorkBadgeIds
			ORDER BY Threshold__c
		]) {
			thresholdBadgeIdMap.put(
				Integer.valueOf(workBadgeMission.Threshold__c),
				workBadgeMission.SourceId__c
			);
		}
		return thresholdBadgeIdMap;
	}

	// Check what WorkBadges users already have assigned
	public static Map<Id, Set<Id>> getUserIdBadgeIdsMap(Set<Id> recipientIds) {
		Map<Id, Set<Id>> userIdBadgeIdsMap = new Map<Id, Set<Id>>();
		Set<Id> badgeIds;
		Id recipientId = null;
		for (WorkBadge workBadge : [
			SELECT RecipientId, DefinitionId
			FROM WorkBadge
			WHERE NetworkId = :CUSTOMER_COMMUNITY_ID AND RecipientId IN :recipientIds
			ORDER BY RecipientId
		]) {
			if (recipientId != workBadge.RecipientId) {
				if (recipientId != null) {
					userIdBadgeIdsMap.put(recipientId, badgeIds);
				}
				badgeIds = new Set<Id>();
				badgeIds.add(workBadge.DefinitionId);
				recipientId = workBadge.RecipientId;
			}
			if (recipientId == workBadge.RecipientId) {
				badgeIds.add(workBadge.DefinitionId);
				recipientId = workBadge.RecipientId;
			}
		}
		userIdBadgeIdsMap.put(recipientId, badgeIds);
		return userIdBadgeIdsMap;
	}

	@TestVisible
	private static Set<Id> getEligibleBadges(Integer count, Map<Integer, Id> thresholdBadgeIdMap) {
		Set<Id> workBadgeIds = new Set<Id>();
		Id workBadgeId;
		for (Integer i = 1; i <= count; i++) {
			workBadgeIds.add(thresholdBadgeIdMap.get(i));
		}
		workBadgeIds.remove(null);
		return workBadgeIds;
	}

	@TestVisible
	private static Map<String, Id> getWorkThanksMessageworkThanksId() {
		Map<String, Id> workThanksMessageworkThanksId = new Map<String, Id>();

		for (WorkThanks workThanks : [
			SELECT Id, Message
			FROM WorkThanks
			WHERE
				NetworkId = :CUSTOMER_COMMUNITY_ID
				AND GiverId = :Constants.CUSTOMER_COMMUNITY_MANAGER_ID
		]) {
			workThanksMessageworkThanksId.put(workThanks.Message.normalizeSpace(), workThanks.Id);
		}
		return workThanksMessageworkThanksId;
	}

	@TestVisible
	private static Map<Id, WorkBadgeMission__c> getworkBadgeMissionMap() {
		Map<Id, WorkBadgeMission__c> workBadgeMissionMap = new Map<Id, WorkBadgeMission__c>();
		for (WorkBadgeMission__c workBadgeMission : [
			SELECT Id, SourceId__c, Message__c
			FROM WorkBadgeMission__c
			WHERE IsActive__c = TRUE
		]) {
			workBadgeMissionMap.put(workBadgeMission.SourceId__c, workBadgeMission);
		}
		return workBadgeMissionMap;
	}

	// assign (new) badge to user
	public static void assignBadge(Set<String> newBadgeIdUserIdStrings) {
		Map<Id, WorkBadgeMission__c> workBadgeMissionMap = getworkBadgeMissionMap();
		Map<String, Id> workThanksMessageWorkThanksId = getWorkThanksMessageworkThanksId();
		List<WorkThanks> listOfThanks = new List<WorkThanks>();
		List<WorkBadge> badges = new List<WorkBadge>();
		List<FeedItem> chatterPosts = new List<FeedItem>();
		Set<Id> workThanksIds = new Set<Id>();
		Id workBadgeId;
		Id userId;
		Id workThanksId;
		String missionMessage;

		if (workBadgeMissionMap.isEmpty()) {
			return;
		}

		for (String newBadgeIdUserIdString : newBadgeIdUserIdStrings) {
			workBadgeId = Id.valueOf(newBadgeIdUserIdString.substringBefore('***'));
			try {
				missionMessage = workBadgeMissionMap.get(workBadgeId).Message__c;
			} catch (Exception e) {
				missionMessage = '';
			}
			if (workThanksMessageWorkThanksId?.containsKey(missionMessage)) {
				continue;
			}
			listOfThanks.add(
				new WorkThanks(
					NetworkId = CUSTOMER_COMMUNITY_ID,
					GiverId = Constants.CUSTOMER_COMMUNITY_MANAGER_ID,
					Message = missionMessage
				)
			);
		}

		Database.SaveResult[] insertThanksResults = Database.insert(listOfThanks, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'WorkBadgeMissionTriggerUtility.assignBadge() ERRORS',
				insertThanksResults
			)
			.addTag('apex');
		Logger.saveLog();
		for (Database.SaveResult insertThanksResult : insertThanksResults) {
			workThanksIds.add(insertThanksResult.getId());
		}

		for (WorkThanks workThanks : [
			SELECT Id, Message
			FROM WorkThanks
			WHERE Id IN :workThanksIds
		]) {
			workThanksMessageWorkThanksId.put(workThanks.Message.normalizeSpace(), workThanks.Id);
		}

		for (String newBadgeIdUserIdString : newBadgeIdUserIdStrings) {
			workBadgeId = Id.valueOf(newBadgeIdUserIdString.substringBefore('***'));
			userId = Id.valueOf(newBadgeIdUserIdString.substringAfter('***'));
			workThanksId = Id.valueOf(
				workThanksMessageWorkThanksId.get(
					workBadgeMissionMap.get(workBadgeId).Message__c.normalizeSpace()
				)
			);
			badges.add(
				new WorkBadge(
					DefinitionId = workBadgeId,
					NetworkId = CUSTOMER_COMMUNITY_ID,
					RecipientId = userId,
					SourceId = workThanksId
				)
			);
			chatterPosts.add(
				new FeedItem(
					NetworkScope = CUSTOMER_COMMUNITY_ID,
					ParentId = userId,
					RelatedRecordId = workThanksId,
					Body = workBadgeMissionMap.get(workBadgeId).Message__c,
					Type = 'RypplePost',
					Visibility = 'AllUsers'
				)
			);
		}
		Database.SaveResult[] insertBadgeResults = Database.insert(badges, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'WorkBadgeMissionTriggerUtility.assignBadge() ERRORS',
				insertBadgeResults
			)
			.addTag('apex');
		Logger.saveLog();
		Database.SaveResult[] insertChatterPostsResults = Database.insert(chatterPosts, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'WorkBadgeMissionTriggerUtility.assignBadge() ERRORS',
				insertChatterPostsResults
			)
			.addTag('apex');
		Logger.saveLog();
	}
	@TestVisible
	private static WorkBadgeMissionEvent__e[] getCommentOrAnswerWorkBadgeMissionEvents(
		WorkBadgeMissionEvent__e[] workBadgeMissionEvents,
		String type
	) {
		List<WorkBadgeMissionEvent__e> answerWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		List<WorkBadgeMissionEvent__e> commentWorkBadgeMissionEvents = new List<WorkBadgeMissionEvent__e>();
		Set<Id> feedItemIds = new Set<Id>();
		Map<Id, FeedItem> feedItemMap;

		for (WorkBadgeMissionEvent__e workBadgeMissionEvent : workBadgeMissionEvents) {
			feedItemIds.add(Id.valueOf(workBadgeMissionEvent.FeedItemId__c));
		}

		feedItemMap = new Map<Id, FeedItem>([SELECT Id, Type FROM FeedItem WHERE Id IN :feedItemIds]);

		for (WorkBadgeMissionEvent__e workBadgeMissionEvent : workBadgeMissionEvents) {
			if (
				feedItemMap.get(Id.valueOf(workBadgeMissionEvent.FeedItemId__c)).Type ==
				QUESTION_POST_TYPE
			) {
				answerWorkBadgeMissionEvents.add(workBadgeMissionEvent);
			} else if (
				NON_QUESTION_POST_TYPE.contains(
					feedItemMap.get(Id.valueOf(workBadgeMissionEvent.FeedItemId__c)).Type
				)
			) {
				commentWorkBadgeMissionEvents.add(workBadgeMissionEvent);
			} else {
				continue;
			}
		}
		return type == 'Answer' ? answerWorkBadgeMissionEvents : commentWorkBadgeMissionEvents;
	}

	private static FeedItem[] getFeedItems(Set<String> postTypes, Set<Id> insertedByIds) {
		return getFeedItems(postTypes, insertedByIds, false);
	}

	private static FeedItem[] getFeedItems(
		Set<String> postTypes,
		Set<Id> insertedByIds,
		Boolean bestCommentsOnly
	) {
		String query = 'SELECT Id, InsertedById, Body FROM FeedItem WHERE';
		query += ' Type IN :postTypes';
		query += ' AND NetworkScope = \'' + CUSTOMER_COMMUNITY_ID + '\'';
		query += ' AND CreatedDate > :programLaunchDate';
		if (insertedByIds != null) {
			query += ' AND InsertedById IN :insertedByIds';
		}
		if (bestCommentsOnly) {
			query += ' AND BestCommentId != NULL';
		}
		query += ' ORDER BY InsertedById';

		FeedItem[] feedItems = Database.query(query);
		if (feedItems.isEmpty() || Test.isRunningTest()) {
			feedItems = Database.query(query);
		}
		return feedItems;
	}

	private static Map<Id, FeedComment> getFeedCommentMap(
		Set<Id> feedItemIds,
		Set<Id> insertedByIds
	) {
		String query = 'SELECT Id, InsertedById, FeedItemId FROM FeedComment WHERE';
		query += ' CommentType IN :COMMENT_TYPES';
		query += ' AND InsertedById IN :insertedByIds';
		query += ' AND FeedItemId IN :feedItemIds';
		query += ' AND CreatedDate > :programLaunchDate';
		query += ' ORDER BY InsertedById';

		FeedComment[] feedComments = Database.query(query);
		if (feedComments.isEmpty() || Test.isRunningTest()) {
			feedComments = Database.query(query);
		}
		return new Map<Id, FeedComment>(feedComments);
	}

	private static FeedComment[] getBestAnswerFeedComments(
		Set<Id> feedItemIds,
		Set<Id> insertedByIds
	) {
		Set<Id> bestCommentIds = new Set<Id>();
		for (FeedItem feedItem : [SELECT BestCommentId FROM FeedItem WHERE Id IN :feedItemIds]) {
			bestCommentIds.add(feedItem.BestCommentId);
		}

		String query = 'SELECT Id, InsertedById, FeedItemId FROM FeedComment WHERE';
		query += ' CommentType IN :COMMENT_TYPES';
		query += ' AND InsertedById IN :insertedByIds';
		query += ' AND Id IN :bestCommentIds';
		query += ' AND CreatedDate > :programLaunchDate';
		query += ' ORDER BY InsertedById';

		FeedComment[] feedComments = Database.query(query);
		if (feedComments.isEmpty() || Test.isRunningTest()) {
			feedComments = Database.query(query);
		}
		return feedComments;
	}

	private static Idea[] getIdeas(Set<Id> insertedByIds) {
		String query = 'SELECT Id, CreatedById FROM Idea WHERE';
		query += ' CreatedById IN :insertedByIds';
		query += ' AND idea.CommunityId = \'' + Constants.COMMUNITY_PLAYBOOK_IDEAS_ID + '\'';
		query += ' AND CreatedDate > :programLaunchDate';

		Idea[] ideas = Database.query(query);
		if (ideas.isEmpty() || Test.isRunningTest()) {
			ideas = Database.query(query);
		}
		return ideas;
	}

	private static IdeaComment[] getIdeaComments(Set<Id> insertedByIds) {
		String query = 'SELECT Id, CreatedById FROM IdeaComment WHERE';
		query += ' CreatedById IN :insertedByIds';
		query += ' AND CommunityId = \'' + Constants.COMMUNITY_PLAYBOOK_IDEAS_ID + '\'';
		query += ' AND CreatedDate > :programLaunchDate';

		IdeaComment[] ideaComments = Database.query(query);
		if (ideaComments.isEmpty() || Test.isRunningTest()) {
			ideaComments = Database.query(query);
		}
		return ideaComments;
	}

	private static Map<Id, Integer> getUserIdCountUniquePostsMap(FeedItem[] feedItems) {
		Map<Id, Integer> userIdCountUniquePostsMap = new Map<Id, Integer>();
		Id insertedById = null;
		Integer countPosts = 0;

		for (FeedItem feedItem : feedItems) {
			if (feedItem.Body != null && feedItem.Body.startsWith('Level')) {
				continue;
			}
			if (insertedById == feedItem.InsertedById || insertedById == null) {
				countPosts++;
				insertedById = feedItem.InsertedById;
			}
			if (insertedById != feedItem.InsertedById) {
				userIdCountUniquePostsMap.put(insertedById, countPosts);
				countPosts = 1;
				insertedById = feedItem.InsertedById;
			}
		}
		if (insertedById != null) {
			userIdCountUniquePostsMap.put(insertedById, countPosts);
		}
		return userIdCountUniquePostsMap;
	}

	private static Map<Id, Integer> getUserIdCountUniqueCommentsMap(
		Map<Id, FeedComment> feedCommentMap,
		Set<Id> insertedByIds
	) {
		Map<Id, Integer> userIdCountUniqueCommentsMap = new Map<Id, Integer>();
		Set<Id> feedItemIds = new Set<Id>();
		Set<Id> feedCommentIdsToRemove = new Set<Id>();
		Id insertedById = null;
		Integer countComments = 0;

		for (Id feedCommentId : feedCommentMap.keySet()) {
			if (
				feedCommentMap.get(feedCommentId).InsertedById == insertedById ||
				insertedById == null
			) {
				if (feedItemIds.contains(feedCommentMap.get(feedCommentId).FeedItemId)) {
					feedCommentIdsToRemove.add(feedCommentId);
				}
			}
			if (feedCommentMap.get(feedCommentId).InsertedById != insertedById) {
				feedItemIds.clear();
			}
			insertedById = feedCommentMap.get(feedCommentId).InsertedById;
			feedItemIds.add(feedCommentMap.get(feedCommentId).FeedItemId);
		}

		for (Id feedCommentIdToRemove : feedCommentIdsToRemove) {
			feedCommentMap.remove(feedCommentIdToRemove);
		}

		for (FeedComment feedComment : feedCommentMap.values()) {
			if (insertedById == feedComment.InsertedById || insertedById != null) {
				countComments++;
				insertedById = feedComment.InsertedById;
			}
			if (insertedById != feedComment.InsertedById) {
				userIdCountUniqueCommentsMap.put(insertedById, countComments);
				countComments = 1;
				insertedById = feedComment.InsertedById;
			}
		}
		userIdCountUniqueCommentsMap.put(insertedById, countComments);
		return userIdCountUniqueCommentsMap;
	}

	private static Map<Id, Integer> getUserIdCountBestAnswersMap(
		FeedComment[] feedComments,
		Set<Id> insertedByIds
	) {
		Map<Id, Integer> userIdCountBestAnswersMap = new Map<Id, Integer>();
		Id insertedById = null;
		Integer countBestAnswers = 0;

		for (Id userId : insertedByIds) {
			userIdCountBestAnswersMap.put(userId, 0);
		}

		for (FeedComment feedComment : feedComments) {
			if (insertedById == feedComment.InsertedById || insertedById == null) {
				countBestAnswers++;
				insertedById = feedComment.InsertedById;
			}
			if (insertedById != feedComment.InsertedById) {
				userIdCountBestAnswersMap.put(insertedById, countBestAnswers);
				countBestAnswers = 1;
				insertedById = feedComment.InsertedById;
			}
		}
		if (insertedById != null) {
			userIdCountBestAnswersMap.put(insertedById, countBestAnswers);
		}
		return userIdCountBestAnswersMap;
	}
}