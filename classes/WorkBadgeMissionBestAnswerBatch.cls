/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Assign Badges to users with best answers
 * RequestId  ModifiedDate  Comment
 * SS-8303    2025-02-25    Created the class
 */
global class WorkBadgeMissionBestAnswerBatch implements Database.Batchable<sObject>, Schedulable {
	private static Id CUSTOMER_COMMUNITY_ID = Utility.getNetworkId('Tanium Customer Community');
	private String query = Test.isRunningTest()
		? 'SELECT Id FROM User WHERE IsActive = TRUE LIMIT 1'
		: 'SELECT Id FROM User WHERE IsActive = TRUE';
	private final static Integer BATCH_SIZE = Test.isRunningTest() ? 1 : 200;

	public WorkBadgeMissionBestAnswerBatch() {
		this(null);
	}

	public WorkBadgeMissionBestAnswerBatch(String customQuery) {
		this.query = (customQuery != null) ? customQuery : this.query;
	}

	global Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext bc, User[] users) {
		Set<Id> userIds = new Set<Id>();
		Map<Id, User> userMap = new Map<Id, User>(users);

		ChatterActivity[] chatterActivities = [
			SELECT ParentId
			FROM ChatterActivity
			WHERE
				CommentCount > 0
				AND NetworkId = :CUSTOMER_COMMUNITY_ID
				AND ParentId IN :userMap.keySet()
		];

		for (ChatterActivity chatterActivity : chatterActivities) {
			userIds.add(chatterActivity.ParentId);
		}

		if (!userIds.isEmpty()) {
			processBestAnswers(userIds);
		}
	}

	@TestVisible
	private void processBestAnswers(Set<Id> userIds) {
		WorkBadgeMissionTriggerUtility.processEvent(
			userIds,
			WorkBadgeMissionTriggerUtility.BEST_ANSWER_ACTION
		);
	}

	global void finish(Database.BatchableContext bc) {
	}

	global void execute(SchedulableContext ctx) {
		WorkBadgeMissionBestAnswerBatch batch = new WorkBadgeMissionBestAnswerBatch();
		Database.executeBatch(batch, BATCH_SIZE);
	}
}