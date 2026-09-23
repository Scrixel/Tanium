/*
 * @BUSINESS: Test methods for class UserLicensesUnAssignAsync
 * @DATE: 2025-02-11
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7422    2025-02-11    Created
 */
@IsTest
private class UserLicensesUnAssignAsyncTest {
	@TestSetup
	static void makeData() {
		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			adminUser.Licensed_Conga_User__c = true;
			adminUser.Licensed_KimbleOne_User__c = true;
			update adminUser;
		}
	}

	@IsTest
	static void testBatchExecute_WhenRecordMeetsCriteria_UpdateUserMethod() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();

			Id jobId = Database.executeBatch(new UserLicensesUnAssignAsync());
			Test.stopTest();

			User adminUser = [
				SELECT Id, Licensed_Conga_User__c, Licensed_KimbleOne_User__c
				FROM User
				WHERE Id = :UserInfo.getUserId()
			];

			Assert.areEqual(
				false,
				adminUser.Licensed_Conga_User__c,
				'User is expected not to be a Licensed Conga User'
			);
			Assert.areEqual(
				false,
				adminUser.Licensed_KimbleOne_User__c,
				'User is expected not to be a Licensed Kimble One User'
			);
		}
	}

	@IsTest
	static void testScheduleBatch_WhenBatchIsScheduled_UpdateRecords() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String chron = '0 0 23 * * ?';
			String jobid = System.schedule(
				'testScheduledApex-UserLicensesUnAssignAsync',
				chron,
				new UserLicensesUnAssignAsync()
			);
			Test.stopTest();

			CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
			Assert.areEqual(chron, ct.CronExpression);
		}
	}
}