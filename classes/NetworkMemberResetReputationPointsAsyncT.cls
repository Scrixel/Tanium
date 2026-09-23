/*
 * @BUSINESS: Test methods for class NetworkMemberResetReputationPointsAsync
 * @DATE: 2024-09-10
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-8302    2024-09-10    Created test class
 */
@IsTest
private class NetworkMemberResetReputationPointsAsyncT {
	@isTest(SeeAllData=true)
	static void testBatchExecute_WhenThereAreOptOutUsers_ResetReputationPoints() {
		NetworkMember networkMember = [
			SELECT Id, ReputationPoints, MemberId, Member.Name
			FROM NetworkMember
			WHERE Member.Opt_Out_Leaderboard__c = FALSE
			LIMIT 1
		];
		User communityUser = new User(Id = networkMember.MemberId, Opt_Out_Leaderboard__c = true);
		update communityUser;

		Test.startTest();
		Database.executeBatch(new NetworkMemberResetReputationPointsAsync());
		Test.stopTest();

		NetworkMember updatedNetworkMember = [
			SELECT Id, ReputationPoints
			FROM NetworkMember
			WHERE Id = :networkMember.Id
		];
		Assert.areEqual(0, updatedNetworkMember.ReputationPoints);
	}

	@isTest
	static void testSchedulerExecute_WhenJobIsScheduled_AlwaysGetBatchJobId() {
		Date scheduleDate = Date.today().addDays(1);
		Integer day = scheduleDate.day();
		Integer month = scheduleDate.month();
		Integer year = scheduleDate.year();
		String cronExp = '0 0 0 ' + day + ' ' + month + ' ? ' + year;

		Test.startTest();
		NetworkMemberResetReputationPointsAsync schObj = new NetworkMemberResetReputationPointsAsync();
		Id jobId = System.schedule('NetworkMemberResetReputationPointsAsync Test', cronExp, schObj);
		Test.stopTest();

		Assert.isTrue(jobId != null);
	}
}