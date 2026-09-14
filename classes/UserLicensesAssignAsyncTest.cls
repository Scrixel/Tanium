/*
 * @BUSINESS: Test methods for class UserLicensesAssignAsync
 * @DATE: 2025-02-11
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7422    2025-02-11    Created
 */
@IsTest
private class UserLicensesAssignAsyncTest {
	@TestSetup
	static void makeData() {
		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			TestingUtility.assignPackageLicense(adminUser.Id, 'Apttus');
			TestingUtility.assignPackageLicense(adminUser.Id, 'KimbleOne');
		}
	}

	@IsTest
	static void testBatchExecute_WhenRecordMeetsCriteria_UpdateUserMethod() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Id jobId = Database.executeBatch(new UserLicensesAssignAsync(), 100);
			Test.stopTest();

			User adminUser = [
				SELECT Id, Licensed_Conga_User__c, Licensed_KimbleOne_User__c
				FROM User
				WHERE Id = :UserInfo.getUserId()
			];

			Assert.areEqual(
				true,
				adminUser.Licensed_Conga_User__c,
				'User is expected to be Licensed Conga User'
			);
			Assert.areEqual(
				true,
				adminUser.Licensed_KimbleOne_User__c,
				'User is expected to be Licensed Kimble One User'
			);
		}
	}

	@IsTest
	static void testScheduleBatch_WhenBatchIsScheduled_UpdateRecords() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String chron = '0 0 23 * * ?';
			String jobid = System.schedule(
				'testScheduledApex-UserLicensesAssignAsync',
				chron,
				new UserLicensesAssignAsync()
			);
			Test.stopTest();

			CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
			Assert.areEqual(chron, ct.CronExpression);
		}
	}
}