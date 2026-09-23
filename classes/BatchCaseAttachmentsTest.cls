@IsTest
private class BatchCaseAttachmentsTest {
	private static User batchUser;

	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;
			Case myCase1 = TestFactory.buildCase(acct.Id);
			myCase1.Severity_Community__c = '1';
			Case myCase2 = TestFactory.buildCase(acct.Id);
			myCase2.Severity_Community__c = '2';
			insert new List<Case>{ myCase1, myCase2 };
			Attachment myAttachment1 = TestFactory.buildAttachment(myCase1.Id);
			Attachment myAttachment2 = TestFactory.buildAttachment(myCase2.Id);
			insert new List<Attachment>{ myAttachment1, myAttachment2 };
		}
	}

	@isTest
	static void testBatch_whenMeetsCriteria_deletesAttachments() {
		Test.startTest();
		System.runAs(TestUserFactory.getAdminUser()) {
			String query =
				'SELECT Id, (SELECT Id FROM Attachments) ' +
				'FROM Case ' +
				'WHERE Severity_Community__c = \'1\' OR Severity_Community__c = \'2\'';
			BatchCaseAttachments batch = new BatchCaseAttachments(query);
			Database.executeBatch(batch);
			String chron = '0 0 23 * * ?';
			String jobid = System.schedule('testScheduledApex-BatchCaseAttachmentsTest', chron, batch);
			CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
			System.assertEquals(chron, ct.CronExpression);
		}
		Test.stopTest();
		for (Case myCase1 : [
			SELECT Id, (SELECT Id FROM Attachments)
			FROM Case
			WHERE Severity_Community__c = '1'
		]) {
			System.assertEquals(true, myCase1.attachments.isEmpty());
		}
		for (Case myCase2 : [
			SELECT Id, (SELECT Id FROM Attachments)
			FROM Case
			WHERE Severity_Community__c = '2'
		]) {
			System.assertEquals(true, myCase2.attachments.isEmpty());
		}
	}

	@isTest
	static void testBatch_whenDoesNotMeetCriteria_doesNotDeleteAttachments() {
		Test.startTest();
		System.runAs(TestUserFactory.getAdminUser()) {
			String query =
				'SELECT Id, (SELECT Id FROM Attachments) ' +
				'FROM Case ' +
				'WHERE Severity_Community__c=\'3\'';
			BatchCaseAttachments batch = new BatchCaseAttachments(query);
			Database.executeBatch(batch);
			String chron = '0 0 23 * * ?';
			String jobid = System.schedule('testScheduledApex-BatchCaseAttachmentsTest', chron, batch);
			CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
			System.assertEquals(chron, ct.CronExpression);
		}
		Test.stopTest();
		for (Case eachCase : [
			SELECT Id, (SELECT Id FROM Attachments)
			FROM Case
			WHERE Severity_Community__c = '1' OR Severity_Community__c = '2'
		]) {
			System.assertEquals(false, eachCase.attachments.isEmpty());
		}
	}

	@isTest
	static void testBatch_whenFails_createsNebulaEventLogRecords() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String query =
				'SELECT Id, (SELECT Id FROM Attachments) ' +
				'FROM Case ' +
				'WHERE Id=' +
				'\'500ABCPQRABCPQRXYZ\'';
			try {
				BatchCaseAttachments batch = new BatchCaseAttachments(query);
				Database.executeBatch(batch);
			} catch (Exception e) {
				for (LogEntry__c eachLog : [SELECT Id, Message__c FROM LogEntry__c]) {
					System.assertEquals(true, eachLog.Message__c.contains('NumberOfErrors: 1'));
				}
			}
		}
	}
}