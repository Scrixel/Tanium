/**
 * @Business: Update Reputation Points to 0 when User opt-out to Leaderboard
 * @Date: 2024-09-10
 * @Author: Tanium Dev Team
 * @Request: SS-8302
 * Modified    ModifiedDate   Description
 * SS-8302   2024-09-10     Created
 */
global class NetworkMemberResetReputationPointsAsync implements Database.Batchable<sObject>, Schedulable, Database.Stateful {
	global Database.QueryLocator start(Database.BatchableContext batchContext) {
		return Database.getQueryLocator(
			[
				SELECT Id, ReputationPoints, MemberId, Member.Name
				FROM NetworkMember
				WHERE Member.Opt_Out_Leaderboard__c = TRUE
			]
		);
	}

	global void execute(
		Database.BatchableContext batchContext,
		List<NetworkMember> networkMemberList
	) {
		for (NetworkMember networkMember : networkMemberList) {
			networkMember.ReputationPoints = 0;
		}

		update networkMemberList;
	}

	global void finish(Database.BatchableContext BC) {
	}

	// Scheduler execute method
	global void execute(SchedulableContext ctx) {
		NetworkMemberResetReputationPointsAsync async = new NetworkMemberResetReputationPointsAsync();
		Database.executeBatch(async);
	}
}