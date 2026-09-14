/**
 *  Copyright (c) 2026 Tanium
 *
 * @Business: Test class for LeadConvertController
 * @Authors:  Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-12490   2026-02-12    Created the test class
 * SS-12490   2026-02-18    Prepared tests for LeadConvertController
 */
@IsTest
private class LeadConvertControllerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'LeadTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account Lead Convert');
			insert account;
			Lead lead = TestFactory.buildLead(
				'FirstName',
				'LastName',
				'firstname.lastname@somecorp.io',
				'Some Company'
			);
			insert lead;
		}
	}

	private static Id getLeadId() {
		return [SELECT Id FROM Lead LIMIT 1].Id;
	}

	private static Id getAccountId() {
		return [SELECT Id FROM Account LIMIT 1].Id;
	}

	private static Id getOwnerId() {
		return TestUserFactory.getAdminUser().Id;
	}

	private static String getConvertedLeadStatus() {
		List<LeadStatus> statuses = [
			SELECT MasterLabel
			FROM LeadStatus
			WHERE IsConverted = TRUE
			ORDER BY SortOrder
			LIMIT 1
		];
		return statuses.isEmpty() ? null : statuses[0].MasterLabel;
	}

	private static Map<String, Object> getValidConvertParams() {
		return new Map<String, Object>{
			'leadId' => getLeadId(),
			'accountId' => getAccountId(),
			'ownerId' => getOwnerId(),
			'sendEmailToOwner' => false,
			'doNotCreateOpportunity' => true,
			'opportunityName' => '',
			'convertedStatus' => getConvertedLeadStatus(),
			'contactId' => null,
			'taskSubject' => 'Follow up',
			'taskType' => 'Call',
			'taskActivityDateStr' => String.valueOf(Date.today()),
			'taskMeetingDateStr' => null,
			'taskStatus' => 'Not Started',
			'taskDescription' => null,
			'taskPriority' => 'Normal',
			'taskTeam' => null,
			'isReminderSet' => false,
			'reminderDateStr' => null,
			'reminderTimeStr' => null
		};
	}

	@IsTest
	static void testGetLead_WhenValidLeadId_ReturnsLead() {
		Id leadId = getLeadId();
		Lead lead;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			lead = LeadConvertController.getLead(leadId);
			Test.stopTest();
		}
		Assert.areEqual(lead.Email, 'firstname.lastname@somecorp.io');
		Assert.areEqual(lead.Id, leadId);
	}

	@IsTest
	static void testGetConvertedLeadStatusOptions_ReturnsOptions() {
		List<String> options;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			options = LeadConvertController.getConvertedLeadStatusOptions();
			Test.stopTest();
		}
		Assert.isNotNull(options);
		Assert.isTrue(options.size() >= 1, 'Org should have at least one converted lead status');
		Assert.isNotNull(options[0]);
	}

	@IsTest
	static void testParseReminderDateTime_WhenValidDateAndTime_ReturnsDateTime() {
		DateTime result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = LeadConvertController.parseReminderDateTime('2025-01-15', '14:30');
			Test.stopTest();
		}
		Assert.isNotNull(result);
		Assert.areEqual(2025, result.year());
		Assert.areEqual(1, result.month());
		Assert.areEqual(15, result.day());
		Assert.areEqual(14, result.hour());
		Assert.areEqual(30, result.minute());
	}

	@IsTest
	static void testParseReminderDateTime_WhenTimeWithSeconds_ParsesCorrectly() {
		DateTime result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = LeadConvertController.parseReminderDateTime('2026-06-01', '00:00:00');
			Test.stopTest();
		}
		Assert.isNotNull(result);
		Assert.areEqual(0, result.hour());
		Assert.areEqual(0, result.minute());
	}

	@IsTest
	static void testParseReminderDateTime_WhenBlankDate_ReturnsNull() {
		DateTime result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = LeadConvertController.parseReminderDateTime('', '08:00');
			Test.stopTest();
		}
		Assert.isNull(result);
	}

	@IsTest
	static void testParseReminderDateTime_WhenBlankTime_ReturnsNull() {
		DateTime result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = LeadConvertController.parseReminderDateTime('2025-01-15', null);
			Test.stopTest();
		}
		Assert.isNull(result);
	}

	@IsTest
	static void testParseReminderDateTime_WhenInvalidDate_ReturnsNull() {
		DateTime result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = LeadConvertController.parseReminderDateTime('not-a-date', '08:00');
			Test.stopTest();
		}
		Assert.isNull(result);
	}

	@IsTest
	static void testConvertLead_WhenLeadIdNull_ReturnsError() {
		Map<String, Object> params = getValidConvertParams();
		params.put('leadId', null);
		EnhancedReturnType result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = invokeConvertLead(params);
			Test.stopTest();
		}
		Assert.isFalse(result.retResult);
		Assert.isTrue(
			result.retData.contains('required fields'),
			'Error should list required fields'
		);
		Assert.isTrue(
			result.retData.contains(Lead.SObjectType.getDescribe().getLabel()),
			'Error should mention Lead'
		);
	}

	@IsTest
	static void testConvertLead_WhenAccountIdNull_ReturnsError() {
		Map<String, Object> params = getValidConvertParams();
		params.put('accountId', null);
		EnhancedReturnType result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = invokeConvertLead(params);
			Test.stopTest();
		}
		Assert.isFalse(result.retResult);
		Assert.isTrue(result.retData.contains('Account'));
	}

	@IsTest
	static void testConvertLead_WhenRequiredFieldsMissing_ReturnsError() {
		Map<String, Object> params = getValidConvertParams();
		params.put('convertedStatus', '');
		params.put('taskSubject', '');
		EnhancedReturnType result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = invokeConvertLead(params);
			Test.stopTest();
		}
		Assert.isFalse(result.retResult);
		Assert.isTrue(result.retData.contains('required fields'));
		Assert.isTrue(
			result.retData.contains('Converted Status') || result.retData.contains('Subject')
		);
	}

	@IsTest
	static void testConvertLead_WhenLeadAlreadyConverted_ReturnsError() {
		String convertedStatus = getConvertedLeadStatus();
		if (convertedStatus == null) {
			return;
		}
		Id leadId = getLeadId();
		Id accountId = getAccountId();
		Id ownerId = getOwnerId();
		System.runAs(TestUserFactory.getAdminUser()) {
			Database.LeadConvert lc = new Database.LeadConvert();
			lc.setLeadId(leadId);
			lc.setAccountId(accountId);
			lc.setConvertedStatus(convertedStatus);
			lc.setDoNotCreateOpportunity(true);
			lc.setOwnerId(ownerId);
			Database.convertLead(lc);
		}
		EnhancedReturnType result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = invokeConvertLead(getValidConvertParams());
			Test.stopTest();
		}
		Assert.isFalse(result.retResult);
		Assert.isTrue(result.retData.contains('already been converted'));
	}

	@IsTest
	static void testConvertLead_WhenValidRequest_ConvertsLeadAndReturnsSuccess() {
		String convertedStatus = getConvertedLeadStatus();
		if (convertedStatus == null) {
			return;
		}
		Id accountId = getAccountId();
		Id ownerId = getOwnerId();
		Lead lead2;
		System.runAs(TestUserFactory.getAdminUser()) {
			lead2 = TestFactory.buildLead('Second', 'Lead', 'second.lead@test.com', 'Company 2');
			insert lead2;
		}
		Map<String, Object> params = getValidConvertParams();
		params.put('leadId', lead2.Id);
		params.put('accountId', accountId);
		params.put('ownerId', ownerId);
		params.put('convertedStatus', convertedStatus);
		EnhancedReturnType result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = invokeConvertLead(params);
			Test.stopTest();
		}
		Assert.isTrue(result.retResult, 'Expected success: ' + result.retData);
		Assert.isNotNull(result.retData);
		Assert.areEqual(accountId, result.retData, 'retData should be the account Id');
		Lead lead = [SELECT IsConverted FROM Lead WHERE Id = :lead2.Id];
		Assert.isTrue(lead.IsConverted);
		List<Task> tasks = [
			SELECT Id, Subject
			FROM Task
			WHERE Subject = 'Follow up' AND WhoId != NULL
		];
		Assert.isTrue(tasks.size() >= 1, 'Follow-up task should be created');
	}

	@IsTest
	static void testConvertLead_WhenReminderSetWithValidDateAndTime_SetsTaskReminderDateTime() {
		String convertedStatus = getConvertedLeadStatus();
		if (convertedStatus == null) {
			return;
		}
		Id accountId = getAccountId();
		Id ownerId = getOwnerId();
		Lead lead2;
		System.runAs(TestUserFactory.getAdminUser()) {
			lead2 = TestFactory.buildLead(
				'Reminder',
				'Lead',
				'reminder.lead@test.com',
				'Company Reminder'
			);
			insert lead2;
		}
		Date reminderDate = Date.today().addDays(1);
		String reminderDateStr = String.valueOf(reminderDate);
		String reminderTimeStr = '09:30';
		DateTime expectedReminder = DateTime.newInstance(reminderDate, Time.newInstance(9, 30, 0, 0));
		Map<String, Object> params = getValidConvertParams();
		params.put('leadId', lead2.Id);
		params.put('accountId', accountId);
		params.put('ownerId', ownerId);
		params.put('convertedStatus', convertedStatus);
		params.put('taskSubject', 'Reminder task');
		params.put('isReminderSet', true);
		params.put('reminderDateStr', reminderDateStr);
		params.put('reminderTimeStr', reminderTimeStr);
		EnhancedReturnType result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = invokeConvertLead(params);
			Test.stopTest();
		}
		Assert.isTrue(result.retResult, 'Expected success: ' + result.retData);
		List<Task> tasks = [
			SELECT Id, Subject, ReminderDateTime
			FROM Task
			WHERE Subject = 'Reminder task' AND WhoId != NULL
		];
		Assert.isTrue(tasks.size() >= 1, 'Task with reminder should be created');
		Assert.areEqual(
			expectedReminder,
			tasks[0].ReminderDateTime,
			'Task ReminderDateTime should match reminder date and time'
		);
	}

	private static EnhancedReturnType invokeConvertLead(Map<String, Object> params) {
		Map<String, Object> leadMap = new Map<String, Object>{
			'leadId' => params.get('leadId'),
			'accountId' => params.get('accountId'),
			'ownerId' => params.get('ownerId'),
			'sendEmailToOwner' => params.get('sendEmailToOwner'),
			'doNotCreateOpportunity' => params.get('doNotCreateOpportunity'),
			'opportunityName' => params.get('opportunityName'),
			'convertedStatus' => params.get('convertedStatus'),
			'contactId' => params.get('contactId')
		};
		Map<String, Object> taskMap = new Map<String, Object>{
			'taskSubject' => params.get('taskSubject'),
			'taskType' => params.get('taskType'),
			'taskActivityDateStr' => params.get('taskActivityDateStr'),
			'taskMeetingDateStr' => params.get('taskMeetingDateStr'),
			'taskStatus' => params.get('taskStatus'),
			'taskDescription' => params.get('taskDescription'),
			'taskPriority' => params.get('taskPriority'),
			'taskTeam' => params.get('taskTeam'),
			'isReminderSet' => params.get('isReminderSet'),
			'reminderDateStr' => params.get('reminderDateStr'),
			'reminderTimeStr' => params.get('reminderTimeStr')
		};
		String leadJsonStr = JSON.serialize(leadMap);
		String taskJsonStr = JSON.serialize(taskMap);
		return LeadConvertController.convertLead(leadJsonStr, taskJsonStr);
	}
}