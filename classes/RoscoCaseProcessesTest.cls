/*
 * @DATE:
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Test methods for class RoscoCaseProcesses
 * RequestId  ModifiedDate  Comment
 * SS-7436    2024-08-27    Resolve tech debts
 * SS-9019    2024-09-19    Remove test methods from removed methods
 * SS-9018    2024-09-19    Resolve tech debts
 * SS-9351    2024-10-05    Create test data using System Admin user
 * SS-9459    2024-10-15    Remove processOmniChannel method references
 * SS-9480    2024-11-07    Remove getOmniRoundRobinUserJapan method references
 * SS-9309    2025-01-07    Clean up test methods for LastCustomerResponseDate and LastResponseDate.
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c and resolve issues
 * SS-12607   2026-02-12    Remove TAM profile references and best practice updates
 */
@IsTest
private class RoscoCaseProcessesTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'UserTriggerHandler',
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'CaseTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User'];

			String fedId;
			String fedsoql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE Username = \'RoscoCaseProcesses@taniumfed.com\'';
			List<User> FedUsers = Database.query(fedsoql);

			if (FedUsers.isEmpty()) {
				User uFed = new User(
					Alias = 'rcpfed',
					Email = 'RoscoCaseProcesses@taniumfed.com',
					EmailEncodingKey = 'UTF-8',
					LastName = 'Testing',
					LanguageLocaleKey = 'en_US',
					LocaleSidKey = 'en_US',
					ProfileId = stdProfile.Id,
					TimeZoneSidKey = 'America/Los_Angeles',
					UserName = 'RoscoCaseProcesses@taniumfed.com'
				);
				insert uFed;
				fedId = uFed.Id;
			} else {
				fedId = String.valueOf(FedUsers[0].Id);
			}

			String tanId;
			String tansoql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE Username = \'RoscoCaseProcesses@tanium.com\'';
			List<User> TanUsers = Database.query(tansoql);

			if (TanUsers.isEmpty()) {
				User uTan = new User(
					Alias = 'rcpfed',
					Email = 'RoscoCaseProcesses@tanium.com',
					EmailEncodingKey = 'UTF-8',
					LastName = 'Testing',
					LanguageLocaleKey = 'en_US',
					LocaleSidKey = 'en_US',
					ProfileId = stdProfile.Id,
					TimeZoneSidKey = 'America/Los_Angeles',
					UserName = 'RoscoCaseProcesses@tanium.com'
				);
				insert uTan;
				tanId = uTan.Id;
			} else {
				tanId = String.valueOf(TanUsers[0].Id);
			}

			String soaId;
			String soasoql = 'SELECT Id ' + 'FROM User ' + 'WHERE Username LIKE \'soa@tanium%\'';
			List<User> soaUsers = Database.query(soasoql);

			if (soaUsers.isEmpty()) {
				User uSoa = new User(
					Alias = 'rcpsoa',
					Email = 'soa@tanium.com',
					EmailEncodingKey = 'UTF-8',
					LastName = 'Testing',
					LanguageLocaleKey = 'en_US',
					LocaleSidKey = 'en_US',
					ProfileId = stdProfile.Id,
					TimeZoneSidKey = 'America/Los_Angeles',
					UserName = 'soa@tanium.com'
				);
				insert uSoa;
				soaId = uSoa.Id;
			} else {
				soaId = String.valueOf(soaUsers[0].Id);
			}

			String cusaccountsoql = 'SELECT Id ' + 'FROM Account ' + 'WHERE Name = \'ROSCOTESTCASE\'';
			List<Account> CusAccounts = Database.query(cusaccountsoql);

			Account accountObj;
			if (CusAccounts.isEmpty()) {
				accountObj = TestFactory.buildAccount('ROSCOTESTCASE');
				insert accountObj;
			} else {
				accountObj = CusAccounts[0];
			}

			String cuscontactsoql =
				'SELECT Id ' +
				'FROM Contact ' +
				'WHERE Email = \'RoscoCaseProcesses@foo.com\'';
			List<Contact> CusContacts = Database.query(cuscontactsoql);

			Contact contactObj;
			if (CusContacts.isEmpty()) {
				contactObj = new Contact();
				contactObj.Email = 'RoscoCaseProcesses@foo.com';
				contactObj.FirstName = 'RoscoCaseProcesse';
				contactObj.LastName = 'Foo';
				contactObj.AccountId = accountObj.id;
				insert contactObj;
			} else {
				contactObj = CusContacts[0];
			}

			String cusId;
			String cususersoql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE Username = \'RoscoCaseProcesses@foo.com\'';
			List<User> CusUsers = Database.query(cususersoql);

			user uCus;
			if (CusUsers.isEmpty()) {
				Profile cmtyProfile = [
					SELECT Id
					FROM Profile
					WHERE Name = 'Tanium Community Login Authenticated Case'
				];

				uCus = new User(
					Alias = 'rcpfed',
					Email = 'RoscoCaseProcesses@foo.com',
					EmailEncodingKey = 'UTF-8',
					LastName = 'Testing',
					LanguageLocaleKey = 'en_US',
					LocaleSidKey = 'en_US',
					ProfileId = cmtyProfile.Id,
					TimeZoneSidKey = 'America/Los_Angeles',
					UserName = 'RoscoCaseProcesses@foo.com',
					ContactId = contactObj.Id
				);
				insert uCus;
				cusId = uCus.Id;
			} else {
				cusId = String.valueOf(CusUsers[0].Id);
				uCus = CusUsers[0];
			}

			upsert new Case_Management__c(
				rosco_case_ownerid__c = soaId,
				rosco_count_agent_post_as_response__c = 'true'
			);

			Case c = new Case();
			c.RecordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');
			c.Subject = 'ROSCOTESTCASE-RoscoCaseProcesses';
			c.ContactId = contactObj.Id;
			insert c;

			FeedItem tanFi = new FeedItem(
				ParentId = c.Id,
				Body = 'ROSCOTESTCASE-Tanium',
				Visibility = 'AllUsers',
				NetworkScope = 'AllNetworks'
			);
			insert tanFi;

			Task t = new Task();
			t.Subject = 'ROSCOTESTCASE-RoscoCaseProcesses';
			insert t;

			Integer randomNumber = Integer.valueof((Math.random() * 10));
			User u = new User(
				Alias = 'standt',
				Email = 'standarduser@testorg.com',
				EmailEncodingKey = 'UTF-8',
				LastName = 'Testing',
				LanguageLocaleKey = 'en_US',
				LocaleSidKey = 'en_US',
				ProfileId = stdProfile.Id,
				TimeZoneSidKey = 'America/Los_Angeles',
				UserName = 'standarduser1234@testorg.com' + randomNumber
			);
			insert u;

			List<TAM_Team__c> teams = new List<TAM_Team__c>();

			String escTeamRecordTypeId = Utility.getRecordTypeIdByAPIName(
				'TAM_Team__c',
				'Escalation_SME'
			);

			TAM_Team__c tEscTeam1 = new TAM_Team__c(
				Description__c = 'Description123',
				L2_Email_Aliases__c = 'l2email',
				L2_Slack_Channel_Ids__c = 'l2channel',
				L2_Slack_Groups__c = 'l2group',
				L2_Sev_1_SLO__c = 210,
				L2_Sev_2_SLO__c = 220,
				L2_Sev_3_SLO__c = 230,
				L2_SMS_Text_Numbers__c = 'l2number',
				L3_Email_Aliases__c = 'l3email',
				L3_Slack_Channel_Ids__c = 'l3channel',
				L3_Slack_Groups__c = 'l3group',
				L3_Sev_1_SLO__c = 310,
				L3_Sev_2_SLO__c = 320,
				L3_Sev_3_SLO__c = 330,
				L3_SMS_Text_Numbers__c = 'l3number',
				L4_Email_Aliases__c = 'l4email',
				L4_Slack_Channel_Ids__c = 'l4channel',
				L4_Slack_Groups__c = 'l4group',
				L4_Sev_1_SLO__c = 410,
				L4_Sev_2_SLO__c = 420,
				L4_Sev_3_SLO__c = 430,
				L4_SMS_Text_Numbers__c = 'l4number',
				L5_Email_Aliases__c = 'l5email',
				L5_Slack_Channel_Ids__c = 'l5channel',
				L5_Slack_Groups__c = 'l5group',
				L5_Sev_1_SLO__c = 510,
				L5_Sev_2_SLO__c = 520,
				L5_Sev_3_SLO__c = 530,
				L5_SMS_Text_Numbers__c = 'l5number',
				Name = 'SME-foo',
				RecordTypeId = escTeamRecordTypeId,
				Support_Model__c = null
			);
			teams.add(tEscTeam1);

			TAM_Team__c tEscTeam2 = new TAM_Team__c(
				Description__c = 'DescriptiontEscTeam2',
				L2_Email_Aliases__c = 'tEscTeam2email',
				L2_Slack_Channel_Ids__c = 'tEscTeam2channel',
				L2_Slack_Groups__c = 'tEscTeam2group',
				L2_Sev_1_SLO__c = 2100,
				L2_Sev_2_SLO__c = 2200,
				L2_Sev_3_SLO__c = 2300,
				L2_SMS_Text_Numbers__c = 'l2number',
				L3_Email_Aliases__c = 'l3email',
				L3_Slack_Channel_Ids__c = 'l3channel',
				L3_Slack_Groups__c = 'l3group',
				L3_Sev_1_SLO__c = 3100,
				L3_Sev_2_SLO__c = 3200,
				L3_Sev_3_SLO__c = 3300,
				L3_SMS_Text_Numbers__c = 'l3number',
				L4_Email_Aliases__c = 'l4email',
				L4_Slack_Channel_Ids__c = 'l4channel',
				L4_Slack_Groups__c = 'l4group',
				L4_Sev_1_SLO__c = 4100,
				L4_Sev_2_SLO__c = 4200,
				L4_Sev_3_SLO__c = 4300,
				L4_SMS_Text_Numbers__c = 'l4number',
				L5_Email_Aliases__c = 'l5email',
				L5_Slack_Channel_Ids__c = 'l5channel',
				L5_Slack_Groups__c = 'l5group',
				L5_Sev_1_SLO__c = 5100,
				L5_Sev_2_SLO__c = 5200,
				L5_Sev_3_SLO__c = 5300,
				L5_SMS_Text_Numbers__c = 'l5number',
				Name = 'SME-foo',
				RecordTypeId = escTeamRecordTypeId,
				Support_Model__c = 'Model Foo'
			);
			teams.add(tEscTeam2);

			String responseTeamRecordTypeId = Utility.getRecordTypeIdByAPIName(
				'TAM_Team__c',
				'Response_L1'
			);

			TAM_Team__c tResponse1 = new TAM_Team__c(
				Description__c = 'DescriptionResponse1',
				L1_Email_Aliases__c = 'Response1email',
				L1_Slack_Channel_Ids__c = 'Response1Channel',
				L1_Slack_Groups__c = 'Response1group',
				L1_Sev_1_SLO__c = 101,
				L1_Sev_2_SLO__c = 202,
				L1_Sev_3_SLO__c = 303,
				L1_SMS_Text_Numbers__c = 'Response1number',
				Name = 'L1-Response',
				RecordTypeId = responseTeamRecordTypeId,
				Support_Model__c = null
			);
			teams.add(tResponse1);

			TAM_Team__c tResponse2 = new TAM_Team__c(
				Description__c = 'DescriptiontResponse2',
				L1_Email_Aliases__c = 'tResponse2email',
				L1_Slack_Channel_Ids__c = 'tResponse2Channel',
				L1_Slack_Groups__c = 'tResponse2group',
				L1_Sev_1_SLO__c = 104,
				L1_Sev_2_SLO__c = 205,
				L1_Sev_3_SLO__c = 306,
				L1_SMS_Text_Numbers__c = 'tResponse2number',
				Name = 'L1-tResponse2',
				RecordTypeId = responseTeamRecordTypeId,
				Support_Model__c = 'Model Foo'
			);
			teams.add(tResponse2);

			insert teams;
		}
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseManagementSettings() {
		Map<String, String> cm = RoscoCaseProcesses.getCaseManagementSettings();
		Assert.isFalse(cm.containsKey('foo'));
		Assert.isTrue(cm.containsKey('rosco_case_ownerid__c'));
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseSloStatus() {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		Map<String, String> results = RoscoCaseProcesses.getCaseSloStatus(
			c.Id,
			null,
			null,
			null,
			null,
			null,
			'Support'
		);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseSloStatus_L1() {
		Map<String, String> results = new Map<String, String>();

		Datetime escDate = System.Datetime.now();
		results = RoscoCaseProcesses.getCaseSloStatus(null, '', '', 'Level 1', 1, escDate, 'Support');
		results = RoscoCaseProcesses.getCaseSloStatus(null, '', '', 'Level 1', 2, escDate, 'Support');
		results = RoscoCaseProcesses.getCaseSloStatus(null, '', '', 'Level 1', 3, escDate, 'Support');

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'',
			'Level 1',
			1,
			escDate,
			'Support'
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'',
			'Level 1',
			2,
			escDate,
			'Support'
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'',
			'Level 1',
			3,
			escDate,
			'Support'
		);

		results = RoscoCaseProcesses.getCaseSloStatus(null, '', '', 'Level 1', 1, escDate, 'Support');
		results = RoscoCaseProcesses.getCaseSloStatus(null, '', '', 'Level 1', 2, escDate, 'Support');
		results = RoscoCaseProcesses.getCaseSloStatus(null, '', '', 'Level 1', 3, escDate, 'Support');

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'',
			'Level 1',
			1,
			escDate,
			'Support'
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'',
			'Level 1',
			2,
			escDate,
			'Support'
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'',
			'Level 1',
			3,
			escDate,
			'Support'
		);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseSloStatus_L2() {
		Map<String, String> results = new Map<String, String>();

		Datetime escDate = System.Datetime.now();
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 2',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(210).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 2',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(220).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 2',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(230).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 2',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(2100 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 2',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(2200 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 2',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(2300 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 2',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(210 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 2',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(220 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 2',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(230 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 2',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(2100 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 2',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(2200 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 2',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(2300 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseSloStatus_L3() {
		Map<String, String> results = new Map<String, String>();

		Datetime escDate = System.Datetime.now();
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 3',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(310).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 3',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(320).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 3',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(330).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 3',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(3100 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 3',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(3200 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 3',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(3300 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 3',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(310 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 3',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(320 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 3',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(330 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 3',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(3100 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 3',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(3200 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 3',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(3300 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseSloStatus_L4() {
		Map<String, String> results = new Map<String, String>();

		Datetime escDate = System.Datetime.now();
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 4',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(410).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 4',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(420).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 4',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(430).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusFail'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 4',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(4100 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 4',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(4200 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 4',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(4300 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 4',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(410 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 4',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(420 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'',
			'SME-Foo',
			'Level 4',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(430 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);

		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 4',
			1,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(4100 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 4',
			2,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(4200 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
		results = RoscoCaseProcesses.getCaseSloStatus(
			null,
			'Model Foo',
			'SME-Foo',
			'Level 4',
			3,
			escDate,
			'Support'
		);
		Assert.isTrue(
			util_TimeDiffRight(
				escDate.addMinutes(4300 / 2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
				results.get('escalationSLOStatusWarn'),
				1,
				120000
			)
		);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseState() {
		Case c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		Map<String, String> results = RoscoCaseProcesses.getCaseState(c.Id);

		List<Map<String, String>> smes = new List<Map<String, String>>();
		List<Map<String, String>> shadows = new List<Map<String, String>>();
		String resultsStr = RoscoEscalate.saveCase(
			c.Id,
			'Level 2',
			'Pod Foo',
			'SME-Foo',
			'',
			'escinput',
			'escartifact',
			'false',
			smes,
			shadows,
			'In progress - Escalation next step owner is L1 case owner',
			'Yes'
		);
		results = RoscoCaseProcesses.getCaseState(c.Id);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCaseState_L3() {
		Case c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		Map<String, String> results = RoscoCaseProcesses.getCaseState(c.Id);

		c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		c.Escalation_Tier__c = 'Level 3';
		update c;
		results = RoscoCaseProcesses.getCaseState(c.Id);
	}

	static void RoscoCaseProcessesTest_getCaseState_L5() {
		Case c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		Map<String, String> results = RoscoCaseProcesses.getCaseState(c.Id);

		c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		c.Escalation_Tier__c = 'Level 4';
		update c;
		results = RoscoCaseProcesses.getCaseState(c.Id);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getCMSetting() {
		RoscoCaseProcesses.getCMSetting('rosco_case_ownerid__c');
		RoscoCaseProcesses.getCMSetting(null);
		RoscoCaseProcesses.getCMSetting('TEST_FORCE_EXECPTION');
	}

	@IsTest
	static void RoscoCaseProcessesTest_getEscalationTeamSettings() {
		Map<String, String> results = new Map<String, String>();

		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 2',
			1,
			'Support'
		);
		Assert.areEqual('l2email', results.get('escalationEmail'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 2',
			1,
			'Support'
		);
		Assert.areEqual('l2channel', results.get('escalationSlackChannels'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 2',
			1,
			'Support'
		);
		Assert.areEqual('l2group', results.get('escalationSlackGroups'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 2',
			1,
			'Support'
		);
		Assert.areEqual('210', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 2',
			2,
			'Support'
		);
		Assert.areEqual('220', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 2',
			3,
			'Support'
		);
		Assert.areEqual('230', results.get('escalationSLO'));

		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 3',
			1,
			'Support'
		);
		Assert.areEqual('l3email', results.get('escalationEmail'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 3',
			1,
			'Support'
		);
		Assert.areEqual('l3channel', results.get('escalationSlackChannels'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 3',
			1,
			'Support'
		);
		Assert.areEqual('l3group', results.get('escalationSlackGroups'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 3',
			1,
			'Support'
		);
		Assert.areEqual('310', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 3',
			2,
			'Support'
		);
		Assert.areEqual('320', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 3',
			3,
			'Support'
		);
		Assert.areEqual('330', results.get('escalationSLO'));

		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 4',
			1,
			'Support'
		);
		Assert.areEqual('l4email', results.get('escalationEmail'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 4',
			1,
			'Support'
		);
		Assert.areEqual('l4channel', results.get('escalationSlackChannels'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 4',
			1,
			'Support'
		);
		Assert.areEqual('l4group', results.get('escalationSlackGroups'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 4',
			1,
			'Support'
		);
		Assert.areEqual('410', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 4',
			2,
			'Support'
		);
		Assert.areEqual('420', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 4',
			3,
			'Support'
		);
		Assert.areEqual('430', results.get('escalationSLO'));

		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 5',
			1,
			'Support'
		);
		Assert.areEqual('l5email', results.get('escalationEmail'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 5',
			1,
			'Support'
		);
		Assert.areEqual('l5channel', results.get('escalationSlackChannels'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 5',
			1,
			'Support'
		);
		Assert.areEqual('l5group', results.get('escalationSlackGroups'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 5',
			1,
			'Support'
		);
		Assert.areEqual('510', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 5',
			2,
			'Support'
		);
		Assert.areEqual('520', results.get('escalationSLO'));
		results = RoscoCaseProcesses.getEscalationTeamSettings(
			null,
			'SME-foo',
			'Level 5',
			3,
			'Support'
		);
		Assert.areEqual('530', results.get('escalationSLO'));

		results = RoscoCaseProcesses.getEscalationTeamSettings(
			'Model Foo',
			'SME-foo',
			'Level 2',
			1,
			'Support'
		);
		Assert.areEqual('2100', results.get('escalationSLO'));

		RoscoCaseProcesses.getEscalationTeamSettings(
			'TEST_FORCE_EXECPTION',
			'TEST_FORCE_EXECPTION',
			'TEST_FORCE_EXECPTION',
			null,
			'Support'
		);
	}

	@IsTest
	static void RoscoCaseProcessesTest_getResponseTeamSettings() {
		Map<String, String> results = new Map<String, String>();

		results = RoscoCaseProcesses.getResponseTeamSettings('Model Not Defined', 1);
		Assert.isNull(results.get('supportModel'));

		results = RoscoCaseProcesses.getResponseTeamSettings('Model Not Defined', 2);
		results = RoscoCaseProcesses.getResponseTeamSettings('Model Not Defined', 3);

		results = RoscoCaseProcesses.getResponseTeamSettings('Model Foo', 1);
		results = RoscoCaseProcesses.getResponseTeamSettings('Model Foo', 2);
		results = RoscoCaseProcesses.getResponseTeamSettings('Model Foo', 3);

		RoscoCaseProcesses.getResponseTeamSettings('TEST_FORCE_EXECPTION', null);
	}

	@IsTest
	static void RoscoCaseProcessesTest_isAgent() {
		User u1 = [SELECT Id FROM User WHERE NOT Email LIKE '%tanium.com' LIMIT 1];
		RoscoCaseProcesses.isAgent(u1.Id);

		User u2 = [SELECT Id FROM User WHERE Email LIKE '%@tanium.com' LIMIT 1];
		RoscoCaseProcesses.isAgent(u2.Id);
		Assert.isFalse(RoscoCaseProcesses.isAgent(null));
	}

	@IsTest
	static void RoscoCaseProcessesTest_isCMSettingTrue() {
		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

		for (String s : cmfields) {
			if (s == 'rosco_case_ownerid__c') {
				String sId = String.valueOf(cm.get(s));
				Assert.isTrue(RoscoCaseProcesses.isCMSettingTrue('rosco_case_ownerid__c', sId));
			}
		}

		RoscoCaseProcesses.isCMSettingTrue('TEST_FORCE_EXECPTION', 'TEST_FORCE_EXECPTION');
	}

	@IsTest
	static void RoscoCaseProcessesTest_isJob() {
		RoscoCaseProcesses.isJob('foo');
		RoscoCaseProcesses.isJob(null);
		RoscoCaseProcesses.isJob('TEST_FORCE_EXECPTION');
	}

	@IsTest
	static void RoscoCaseProcessesTest_evaluateCaseEscalation() {
		String jobName = '';
		Case c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		c.Response_L1_SLO__c = 'foo';
		update c;
		jobName = c.Id + ': Escalation Alert Job : Fail schedule : SME-Foo : Level 1 : Sev 3';
		RoscoCaseProcesses.evaluateCaseEscalation(c.Id, jobName);

		c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		c.Escalation_Tier__c = 'Level 2';
		c.Escalation_L2_SLO__c = 'foo';
		update c;
		jobName = c.Id + ': Escalation Alert Job : Fail schedule : SME-Foo : Level 2 : Sev 3';
		RoscoCaseProcesses.evaluateCaseEscalation(c.Id, jobName);

		c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		c.Escalation_Tier__c = 'Level 3';
		c.Escalation_L3_SLO__c = 'foo';
		update c;
		jobName = c.Id + ': Escalation Alert Job : Fail schedule : SME-Foo : Level 3 : Sev 3';
		RoscoCaseProcesses.evaluateCaseEscalation(c.Id, jobName);

		c = [SELECT Id, Subject FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		c.Escalation_Tier__c = 'Level 4';
		c.Escalation_L4_SLO__c = 'foo';
		update c;
		jobName = c.Id + ': Escalation Alert Job : Fail schedule : SME-Foo : Level 4 : Sev 3';
		RoscoCaseProcesses.evaluateCaseEscalation(c.Id, jobName);
	}

	@IsTest
	static void RoscoCaseProcessesTest_manageEscalationAlertJobs() {
		Case c = [
			SELECT
				Escalation_Tier__c,
				Escalation_Team__c,
				Support_Model__c,
				Severity_Community__c,
				CreatedDate,
				Escalation_L2_Date__c,
				Escalation_L3_Date__c,
				Escalation_L4_Date__c,
				Escalation_L5_Date__c,
				RecordTypeId,
				RecordType.Name
			FROM Case
			WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'
			LIMIT 1
		];

		Map<String, String> status = RoscoCaseProcesses.getCaseSloStatus(
			null,
			c.Support_Model__c,
			c.Escalation_Team__c,
			c.Escalation_Tier__c,
			Decimal.valueOf(c.Severity_Community__c),
			c.CreatedDate,
			'Support'
		);
		Boolean result;
		RoscoCaseProcesses.manageEscalationAlertJobs(null, c);
		result = util_JobExists(
			c.Id + ' : Escalation Alert Job : Fail schedule : Response : Level 1 : Sev 3',
			status.get('escalationSLOStatusFail')
		);

		result = util_JobExists(
			c.Id + ' : Escalation Alert Job : Warn schedule : Response : Level 1 : Sev 3',
			status.get('escalationSLOStatusWarn')
		);
	}

	@IsTest
	static void RoscoCaseProcessesTest_manageEscalationAlertJobsDelete() {
		RoscoCaseProcesses.manageEscalationAlertJobsDelete(null);
		RoscoCaseProcesses.manageEscalationAlertJobsDelete('TEST_FORCE_EXECPTION');
	}

	@IsTest
	static void RoscoCaseProcessesTest_nullOrEmpty() {
		Assert.isTrue(RoscoCaseProcesses.nullOrEmpty(null));
		Assert.isTrue(RoscoCaseProcesses.nullOrEmpty(''));
		Assert.isFalse(RoscoCaseProcesses.nullOrEmpty('foo'));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processCaseStatusComment() {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		User u = [SELECT Id FROM User WHERE Email = 'RoscoCaseProcesses@foo.com'];
		Account a = [SELECT Id FROM Account WHERE Name = 'ROSCOTESTCASE'];

		FeedItem tanFi = new FeedItem(
			ParentId = c.Id,
			Body = 'ROSCOTESTCASE-Tanium',
			Visibility = 'AllUsers',
			IsRichText = true,
			NetworkScope = 'AllNetworks'
		);
		insert tanFi;
		FeedComment tanFc = new FeedComment(
			FeedItemId = tanFi.Id,
			CommentBody = 'ROSCOTESTCASE-Tanium',
			CommentType = 'TextComment',
			Status = 'Published'
		);
		insert tanFc;
		FeedComment tanFc2 = [
			SELECT ParentId, CommentType, Status, CreatedById
			FROM FeedComment
			WHERE Id = :tanFc.Id
		];

		FeedItem tanFiA = new FeedItem(
			ParentId = a.Id,
			Body = 'ROSCOTESTCASE-Account',
			Visibility = 'AllUsers',
			IsRichText = true,
			NetworkScope = 'AllNetworks'
		);
		insert tanFiA;

		FeedComment tanFcA = new FeedComment(
			FeedItemId = tanFiA.Id,
			CommentBody = 'ROSCOTESTCASE-Account',
			CommentType = 'TextComment'
		);
		insert tanFcA;

		String custFcId;
		System.runAs(u) {
			FeedItem custFi = new FeedItem(
				ParentId = c.Id,
				Body = 'ROSCOTESTCASE-Customer',
				Visibility = 'AllUsers',
				IsRichText = true,
				NetworkScope = 'AllNetworks'
			);
			insert custFi;
			FeedComment custFc = new FeedComment(
				FeedItemId = custFi.Id,
				CommentBody = 'ROSCOTESTCASE-Tanium',
				CommentType = 'TextComment',
				Status = 'Published'
			);
			insert custFc;
			custFcId = custFc.Id;
		}
		FeedComment custFc2 = [
			SELECT ParentId, CommentType, Status, CreatedById
			FROM FeedComment
			WHERE Id = :custFcId
		];

		String result;

		result = 'Status already set to In Progress - Troubleshooting, no changes made';
		result = 'Setting Status to In Progress - Troubleshooting based on Comment';
		util_set_status(c.Id, null);
		RoscoCaseProcesses.processCaseStatus(null, null, custFc2);

		result = 'Setting Status to In Progress - Troubleshooting based on Comment';
		util_set_status(c.Id, 'Pending - Clarifying');
		Assert.areEqual(result, RoscoCaseProcesses.processCaseStatus(null, null, custFc2));

		result = 'FeedComment is from agent';
		Assert.areEqual(result, RoscoCaseProcesses.processCaseStatus(null, null, tanFc2));

		result = 'FeedComment is not case feed item, TextComment, or published';
		result = 'FeedComment is missing expected property';
		Assert.areEqual(result, RoscoCaseProcesses.processCaseStatus(null, null, tanFcA));

		result = 'FeedComment is missing expected property';
		FeedComment bad = new FeedComment();
		bad.CommentType = 'Foo';
		Assert.areEqual(result, RoscoCaseProcesses.processCaseStatus(null, null, bad));

		result = 'EmailMessage, FeedItem, and FeedComment null';
		Assert.areEqual(result, RoscoCaseProcesses.processCaseStatus(null, null, null));

		result = 'Exception';
		delete c;
		Assert.areEqual(result, RoscoCaseProcesses.processCaseStatus(null, null, custFc2));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processCaseStatusEmail() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
			Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

			c.Status = 'Pending - Clarifying';
			update c;

			Test.startTest();

			String result = 'Setting Status to In Progress - Troubleshooting based on email';
			EmailMessage email = new EmailMessage();
			email.ParentId = c.Id;
			email.FromAddress = 'foo@bar.com';
			email.Status = '3';

			Assert.areEqual(result, RoscoCaseProcesses.processCaseStatus(email, null, null));

			Test.stopTest();
		}
	}

	@IsTest
	static void RoscoCaseProcessesTest_processCaseStatusItem() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case c = [SELECT Id, Status FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
			Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
			User tanUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@tanium.com'];
			User fedUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@taniumfed.com'];
			User cusUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@foo.com'];

			c.Status = 'Pending - Clarifying';
			update c;

			Test.startTest();
			FeedItem item = new FeedItem();
			item.ParentId = c.Id;
			item.Visibility = 'AllUsers';
			item.NetworkScope = 'AllNetworks';
			item.Type = 'TextPost';
			item.Status = 'Published';
			item.CreatedById = cusUser.Id;

			Assert.areEqual(
				'Setting Status to In Progress - Troubleshooting based on Item',
				RoscoCaseProcesses.processCaseStatus(null, item, null)
			);

			Test.stopTest();
		}
	}

	@IsTest
	static void RoscoCaseProcessesTest_processEscalationDateL2() {
		Case oldCase = new Case();
		Case newCase = new Case();

		String result;

		result = 'Case escalated to Level 2';
		newCase.Escalation_Tier__c = 'Level 2';
		newCase.Escalation_L2_Date__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL2(oldCase, newCase));

		result = 'Case Escalation_L2_Date__c has previously been set';
		newCase.Escalation_Tier__c = 'Level 2';
		newCase.Escalation_L2_Date__c = System.Datetime.now();
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL2(oldCase, newCase));

		result = 'Case Escalation_Tier__c is not Level 2';
		newCase.Escalation_Tier__c = 'Level 3';
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL2(oldCase, newCase));

		result = 'Case Escalation_Tier__c is empty';
		newCase.Escalation_Tier__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL2(oldCase, newCase));

		result = 'Case Escalation_Tier__c is empty';
		newCase.Escalation_Tier__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL2(oldCase, newCase));

		result = 'Exception';
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL2(null, null));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processEscalationDateL3() {
		Case oldCase = new Case();
		Case newCase = new Case();

		String result;

		result = 'Case escalated to Level 3';
		newCase.Escalation_Tier__c = 'Level 3';
		newCase.Escalation_L3_Date__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL3(oldCase, newCase));

		result = 'Case Escalation_L3_Date__c has previously been set';
		newCase.Escalation_Tier__c = 'Level 3';
		newCase.Escalation_L3_Date__c = System.Datetime.now();
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL3(oldCase, newCase));

		result = 'Case Escalation_Tier__c is not Level 3';
		newCase.Escalation_Tier__c = 'Level 4';
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL3(oldCase, newCase));

		result = 'Case Escalation_Tier__c is empty';
		newCase.Escalation_Tier__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL3(oldCase, newCase));

		result = 'Case Escalation_Tier__c is empty';
		newCase.Escalation_Tier__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL3(oldCase, newCase));

		result = 'Exception';
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL3(null, null));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processEscalationDateL4() {
		Case oldCase = new Case();
		Case newCase = new Case();

		String result;

		result = 'Case escalated to Level 4';
		newCase.Escalation_Tier__c = 'Level 4';
		newCase.Escalation_L4_Date__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL4(oldCase, newCase));

		result = 'Case Escalation_L4_Date__c has previously been set';
		newCase.Escalation_Tier__c = 'Level 4';
		newCase.Escalation_L4_Date__c = System.Datetime.now();
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL4(oldCase, newCase));

		result = 'Case Escalation_Tier__c is not Level 4';
		newCase.Escalation_Tier__c = 'Level 3';
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL4(oldCase, newCase));

		result = 'Case Escalation_Tier__c is empty';
		newCase.Escalation_Tier__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL4(oldCase, newCase));

		result = 'Case Escalation_Tier__c is empty';
		newCase.Escalation_Tier__c = null;
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL4(oldCase, newCase));

		result = 'Exception';
		Assert.areEqual(result, RoscoCaseProcesses.processEscalationDateL4(null, null));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processFirstResponseDateEmail() {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		EmailMessage email = new EmailMessage();

		String result;

		result = 'Setting First Response Date based on email';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));

		result = 'Setting First Response Date based on email (match CreatedDate)';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';

		result = 'EmailMessage is not case email, from tanium address, or status is draft';
		email.ParentId = t.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));

		result = 'EmailMessage is not case email, from tanium address, or status is draft';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@bar.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));

		result = 'EmailMessage is not case email, from tanium address, or status is draft';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '5';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));

		result = 'EmailMessage is missing expected property';
		email.ParentId = null;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));

		result = 'EmailMessage is missing expected property';
		email.ParentId = c.Id;
		email.FromAddress = null;
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));

		result = 'EmailMessage is missing expected property';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = null;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));

		result = 'Both EmailMessage and FeedItem null';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, null));

		result = 'Exception';
		util_post_count_as_initial_response('true');
		email.ParentId = '5007V00001zfFLJQA2';
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(email, null));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processFirstResponseDateItem() {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		User tanUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@tanium.com'];
		User fedUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@taniumfed.com'];
		User cusUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@foo.com'];

		FeedItem item = new FeedItem();

		String result;

		result = 'Setting First Response Date based on FeedItem';
		util_set_first_response_to_null(c.Id, true);
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'Setting First Response Date based on FeedItem';
		util_set_first_response_to_null(c.Id, true);
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = fedUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'Setting First Response Date based on FeedItem (match CreatedDate)';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;

		result = 'Setting First Response Date based on FeedItem (match CreatedDate)';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;

		result = 'FeedItem does not count toward initial response in this environment';
		util_post_count_as_initial_response('false');
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is not from agent';
		util_set_first_response_to_null(c.Id, true);
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = cusUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = t.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'foo';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'foo';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'foo';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'foo';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = null;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = null;
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = null;
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = null;
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = null;
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));

		result = 'Both EmailMessage and FeedItem null';
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, null));

		result = 'Exception';
		util_post_count_as_initial_response('true');
		item.ParentId = '5007V00001zfFLJQA2';
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processFirstResponseDate(null, item));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processLastCustomerResponseDateComment() {
		User portalUser = [SELECT Id FROM User WHERE Email = 'RoscoCaseProcesses@foo.com'];
		FeedItem tanFi = [SELECT Id, ParentId FROM FeedItem LIMIT 1];

		System.runAs(portalUser) {
			String result;
			Case c = [SELECT Id, Last_Customer_Response_Date__c FROM Case LIMIT 1];
			Datetime lastCustomerResponseDate = c.Last_Customer_Response_Date__c;

			FeedComment commentByCust = new FeedComment(
				FeedItemId = tanFi.Id,
				CommentBody = 'ROSCOTESTCASE-Tanium',
				CommentType = 'TextComment',
				Status = 'Published'
			);
			insert commentByCust;

			System.runAs(TestUserFactory.getAdminUser()) {
				commentByCust = [
					SELECT ParentId, CommentType, Status, CreatedById
					FROM FeedComment
					WHERE Id = :commentByCust.Id
				];
			}

			Test.startTest();
			RoscoCaseProcesses.processLastCustomerResponseDate(null, null, commentByCust);
			Assert.areNotEqual(
				lastCustomerResponseDate,
				[SELECT Last_Customer_Response_Date__c FROM Case WHERE Id = :c.Id]
				.Last_Customer_Response_Date__c
			);

			Test.stopTest();
		}
	}

	@IsTest
	static void RoscoCaseProcessesTest_processLastCustomerResponseDateEmail() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String expectedResult;
			Case c = [SELECT Id, Last_Customer_Response_Date__c FROM Case LIMIT 1];
			Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
			Datetime lastCustomerResponseDate = c.Last_Customer_Response_Date__c;
			EmailMessage email = new EmailMessage(
				ParentId = c.Id,
				FromAddress = 'foo@bar.com',
				Status = '3'
			);

			Test.startTest();

			expectedResult = 'EmailMessage is not case email, from tanium address, or status is draft';
			email.ParentId = t.Id;
			RoscoCaseProcesses.processLastCustomerResponseDate(email, null, null);
			Assert.areEqual(
				lastCustomerResponseDate,
				[SELECT Id, Last_Customer_Response_Date__c FROM Case WHERE Id = :c.Id]
				.Last_Customer_Response_Date__c
			);

			expectedResult = 'EmailMessage is not case email, from tanium address, or status is draft';
			email.ParentId = c.Id;
			email.FromAddress = 'foo@tanium.com';
			RoscoCaseProcesses.processLastCustomerResponseDate(email, null, null);
			Assert.areEqual(
				lastCustomerResponseDate,
				[SELECT Id, Last_Customer_Response_Date__c FROM Case WHERE Id = :c.Id]
				.Last_Customer_Response_Date__c
			);

			expectedResult = 'EmailMessage is missing expected property';
			email.ParentId = null;
			RoscoCaseProcesses.processLastCustomerResponseDate(email, null, null);
			Assert.areEqual(
				lastCustomerResponseDate,
				[SELECT Id, Last_Customer_Response_Date__c FROM Case WHERE Id = :c.Id]
				.Last_Customer_Response_Date__c
			);

			expectedResult = 'Setting Last Customer Response Date based on email';
			email.ParentId = c.Id;
			email.FromAddress = 'foo@bar.com';
			email.Status = '3';
			String actualResult = RoscoCaseProcesses.processLastCustomerResponseDate(
				email,
				null,
				null
			);
			c = [
				SELECT Id, Last_Customer_Response_Date__c, CreatedDate
				FROM Case
				WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'
			];
			Assert.areEqual(expectedResult, actualResult);
			Test.stopTest();
		}
	}

	@IsTest
	static void RoscoCaseProcessesTest_processLastCustomerResponseDateItem() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String expectedResult;
			String actualResult;

			Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
			User tanUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@tanium.com'];
			User cusUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@foo.com'];

			Case c = [SELECT Id, Last_Customer_Response_Date__c FROM Case LIMIT 1];
			Datetime lastCustomerResponseDate = c.Last_Customer_Response_Date__c;
			FeedItem item = new FeedItem(
				ParentId = c.Id,
				Visibility = 'AllUsers',
				NetworkScope = 'AllNetworks',
				Type = 'TextPost',
				Status = 'Published'
			);

			Test.startTest();

			expectedResult = 'FeedItem is from agent';
			item.CreatedById = tanUser.Id;
			RoscoCaseProcesses.processLastCustomerResponseDate(null, item, null);
			Assert.areEqual(
				lastCustomerResponseDate,
				[SELECT Last_Customer_Response_Date__c FROM Case WHERE Id = :c.Id]
				.Last_Customer_Response_Date__c
			);

			expectedResult = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
			item.ParentId = t.Id;
			RoscoCaseProcesses.processLastCustomerResponseDate(null, item, null);
			Assert.areEqual(
				lastCustomerResponseDate,
				[SELECT Last_Customer_Response_Date__c FROM Case WHERE Id = :c.Id]
				.Last_Customer_Response_Date__c
			);

			expectedResult = 'Setting Last Customer Response Date based on FeedItem';
			item.ParentId = c.Id;
			item.CreatedById = cusUser.Id;
			actualResult = RoscoCaseProcesses.processLastCustomerResponseDate(null, item, null);
			Assert.areEqual(expectedResult, actualResult);
			Assert.areNotEqual(
				lastCustomerResponseDate,
				[SELECT Last_Customer_Response_Date__c FROM Case WHERE Id = :c.Id]
				.Last_Customer_Response_Date__c
			);

			expectedResult = 'Exception';
			item.ParentId = '5007V00001zfFLJQA2';
			actualResult = RoscoCaseProcesses.processLastCustomerResponseDate(null, item, null);
			Assert.areEqual(expectedResult, actualResult);

			Test.stopTest();
		}
	}

	@IsTest
	static void RoscoCaseProcessesTest_processLastResponseDateEmail() {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		EmailMessage email = new EmailMessage();

		String result;

		result = 'Setting Last Response Date based on email';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));

		c.Last_Response_Date__c = System.now();
		update c;
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual('', RoscoCaseProcesses.processLastResponseDate(email, null));

		result = 'EmailMessage is not case email, from tanium address, or status is draft';
		email.ParentId = t.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));

		result = 'EmailMessage is not case email, from tanium address, or status is draft';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@bar.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));

		result = 'EmailMessage is not case email, from tanium address, or status is draft';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '5';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));

		result = 'EmailMessage is missing expected property';
		email.ParentId = null;
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));

		result = 'EmailMessage is missing expected property';
		email.ParentId = c.Id;
		email.FromAddress = null;
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));

		result = 'EmailMessage is missing expected property';
		email.ParentId = c.Id;
		email.FromAddress = 'foo@tanium.com';
		email.Status = null;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));

		result = 'Both EmailMessage and FeedItem null';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, null));

		result = 'Exception';
		util_post_count_as_initial_response('true');
		email.ParentId = '5007V00001zfFLJQA2';
		email.FromAddress = 'foo@tanium.com';
		email.Status = '3';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(email, null));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processLastResponseDateItem() {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		Task t = [SELECT Id FROM Task WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];
		User tanUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@tanium.com'];
		User fedUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@taniumfed.com'];
		User cusUser = [SELECT Id FROM User WHERE UserName = 'RoscoCaseProcesses@foo.com'];

		FeedItem item = new FeedItem();

		String result;

		result = 'Setting Last Response Date based on FeedItem';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'Setting Last Response Date based on FeedItem';
		util_set_first_response_to_null(c.Id, true);
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = fedUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is not from agent';
		util_set_first_response_to_null(c.Id, true);
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = cusUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = t.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'foo';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'foo';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'foo';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'foo';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = null;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = null;
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = null;
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = null;
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'FeedItem is missing expected property';
		item.ParentId = c.Id;
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = null;
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));

		result = 'Both EmailMessage and FeedItem null';
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, null));

		result = 'Exception';
		util_post_count_as_initial_response('true');
		item.ParentId = '5007V00001zfFLJQA2';
		item.Visibility = 'AllUsers';
		item.NetworkScope = 'AllNetworks';
		item.Type = 'TextPost';
		item.Status = 'Published';
		item.CreatedById = tanUser.Id;
		Assert.areEqual(result, RoscoCaseProcesses.processLastResponseDate(null, item));
	}

	@IsTest
	static void RoscoCaseProcessesTest_processOutboundSupportCaseEmail() {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		EmailMessage emailObj = new EmailMessage(
			ParentId = c.Id,
			RelatedToId = c.Id,
			Incoming = false
		);
		RoscoCaseProcesses.processOutboundSupportCaseEmail(emailObj);
	}

	static Case getTestCase() {
		Case c = [
			SELECT
				Id,
				CreatedDate,
				Escalation_Tier__c,
				Escalation_Team__c,
				Escalation_L2_Date__c,
				Escalation_L3_Date__c,
				Escalation_L4_Date__c,
				Escalation_L5_Date__c,
				Escalation_L2_SLO__c,
				Escalation_L3_SLO__c,
				Escalation_L4_SLO__c,
				Escalation_L5_SLO__c,
				Escalation_L2_SME_Engaged_Date__c,
				Escalation_L3_SME_Engaged_Date__c,
				Escalation_L4_SME_Engaged_Date__c,
				Escalation_L5_SME_Engaged_Date__c,
				First_Response_Date__c,
				Response_L1_SLO__c,
				SME_OwnerId__c,
				Severity_Community__c,
				Support_Model__c
			FROM Case
			WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'
		];

		return c;
	}

	static Boolean util_TimeDiffRight(String date1, String date2, Long low, Long high) {
		Boolean ret = false;

		Datetime dt1 = Datetime.valueOf(date1.replace('T', ' '));
		Long dt1Long = dt1.getTime();

		Datetime dt2 = Datetime.valueOf(date2.replace('T', ' '));
		Long dt2Long = dt2.getTime();

		Long dtDiff = dt2Long - dt1Long;

		if (dtDiff > low && dtDiff < high) {
			ret = true;
		}

		return ret;
	}

	static Boolean util_JobExists(String name, String fireTime) {
		Boolean ret = false;

		String soql =
			'SELECT Id ' +
			'FROM CronTrigger  ' +
			'WHERE CronJobDetail.Name = \'' +
			name +
			'\' ' +
			'AND NextFireTime = ' +
			fireTime;

		List<CronTrigger> jobs = Database.query(soql);

		if (!jobs.isEmpty()) {
			ret = true;
		}

		if (!ret) {
			soql = 'SELECT Id, CronJobDetail.Name,NextFireTime ' + 'FROM CronTrigger';
			jobs = Database.query(soql);

			if (!jobs.isEmpty()) {
				for (CronTrigger c : jobs) {
					System.debug(c.CronJobDetail.Name + ':' + c.NextFireTime);
				}
			}
		}

		return ret;
	}

	static void util_post_count_as_initial_response(String value) {
		Case_Management__c cm = [SELECT Id FROM Case_Management__c];
		cm.rosco_count_agent_post_as_response__c = value;
		update cm;
	}

	static void util_set_first_response_to_null(String caseId, Boolean setNull) {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		if (setNull) {
			c.First_Response_Date__c = null;
		} else {
			c.First_Response_Date__c = System.Datetime.now();
		}
		update c;
	}

	static void util_set_last_customer_response_to_null(String caseId, Boolean setNull) {
		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'];

		if (setNull) {
			c.Last_Customer_Response_Date__c = null;
		} else {
			c.Last_Customer_Response_Date__c = System.Datetime.now();
		}
		update c;
	}

	static void util_set_status(String caseId, String status) {
		Case c = [SELECT Id, Status FROM Case WHERE Id = :caseId];
		if (status == null) {
			c.Status = null;
		} else {
			c.Status = status;
		}
		update c;
	}

	public class mockCallout implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest request) {
			HttpResponse res = new HttpResponse();
			res.setBody('{"text":"value"}');
			res.setStatusCode(200);
			return res;
		}
	}

	@IsTest
	static void test_unit_qCallOut() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Test.startTest();
		RoscoCaseProcesses.qCallOut testCallout = new RoscoCaseProcesses.qCallOut(
			'testURL',
			'GET',
			'TestBODY'
		);
		Id jobId1 = System.enqueueJob(testCallout);
		Test.stopTest();

		Assert.isNotNull(jobId1);
	}

	@IsTest
	static void testScheduleJob() {
		Case c = [
			SELECT Id, Escalation_Tier__c, Severity_Community__c
			FROM Case
			WHERE Subject = 'ROSCOTESTCASE-RoscoCaseProcesses'
		];

		Test.startTest();
		RoscoCaseProcesses.scheduleJob(
			c.Id,
			'evaluateCaseEscalation',
			'Escalation Alert Job : Fail schedule : ' +
			'Response' +
			' : ' +
			c.Escalation_Tier__c +
			' : Sev ' +
			c.Severity_Community__c,
			String.valueOf(DateTime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.000\'Z\''))
		);
		Test.stopTest();

		List<AsyncApexJob> scheduledJob = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = 'RoscoSchedule'
		];

		Assert.areEqual(1, scheduledJob.size());
	}
}