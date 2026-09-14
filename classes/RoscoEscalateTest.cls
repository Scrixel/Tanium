/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoEscalate
 * @Date:
 * @Author: Cumulus Vision
 * @Request:
 * Modified  ModifiedDate  Description
 * TAN-832	 2019-11-18    Test methods updated.
 * SS-7283	 2024-02-15    Test methods updated.
 * SS-7276	 2024-02-15    Test methods updated.
 * SS-8343	 2024-06-08    Additional test data.
 * SS-7527	 2024-08-22    Added test data for escalation sub teams - new field on TAM Team table
 * SS-10203	 2025-02-11    Add assertion
 * SS-10848	 2025-07-02    Test setCCR
 * SS-11173  2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-10294  2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */
@IsTest
private class RoscoEscalateTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'UserTriggerHandler',
				'CaseTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Id supCaseRecordType = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			Id teamSMETypeId = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_SME');
			Id teamPodTypeId = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_Pod');
			Id teamSpecialityTypeId = Utility.getRecordTypeIdByAPIName(
				'TAM_Team__c',
				'Escalation_Speciality_Group'
			);
			Id memberSMETypeId = Utility.getRecordTypeIdByAPIName(
				'TAM_Team_Member__c',
				'Escalation_SME'
			);
			Id memberPODTypeId = Utility.getRecordTypeIdByAPIName(
				'TAM_Team_Member__c',
				'Escalation_Pod'
			);

			List<User> testUsers = new List<User>();
			testUsers.add(
				TestUserFactory.createUser(
					'ApexUser',
					'roscoapextest@roscolab.com',
					'xafds',
					Utility.getAdminUserProfileId(),
					Utility.getUserRoleId('Principal Escalation Engineer')
				)
			);
			testUsers.add(
				TestUserFactory.createUser(
					'ApexUser2',
					'roscoapextest2@roscolab.com',
					'34343',
					Utility.getAdminUserProfileId(),
					Utility.getUserRoleId('Principal Escalation Engineer')
				)
			);
			testUsers.add(
				TestUserFactory.createUser(
					'TAM',
					'roscoapextest@tanium.com',
					'tanTam',
					Utility.getAdminUserProfileId(),
					Utility.getCorporateRoleId()
				)
			);
			testUsers[2].ManagerId = UserInfo.getUserId();
			insert testUsers;

			Account acc = TestFactory.buildAccount('roscoapextestingd');
			acc.slack_channel_id__c = 'TESTCASE';

			insert acc;

			Rosco_Account__c roscoAcc = new Rosco_Account__c(Name = 'test', Account__c = acc.Id);
			insert roscoAcc;

			List<Contact> contacts = new List<Contact>();
			contacts.add(
				new Contact(
					Email = 'roscoapextest@tanium.com',
					FirstName = 'Test',
					LastName = 'Apex',
					AccountId = null
				)
			);
			contacts.add(
				new Contact(
					Email = 'roscoapextest2@tanium.com',
					FirstName = 'Test2',
					LastName = 'Apex',
					AccountId = null
				)
			);
			insert contacts;

			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Name = '';
			cmSetting.rosco_chronicle_contactid__c = contacts[0].Id + ',' + contacts[1].Id;
			cmSetting.rosco_chronicle_refid_re__c = '_00D60IYkG[.]_500[0-9A-Za-z]*';
			cmSetting.rosco_case_escalation_level_1__c = 'true';
			cmSetting.rosco_case_url_prefix__c = 'test.prefix';
			cmSetting.rosco_sfdc_dom_l__c = 'test-dom';
			insert cmSetting;

			Case testCase = new Case(
				ContactId = contacts[0].Id,
				Accountid = acc.Id,
				OwnerId = testUsers[0].Id,
				Subject = 'ROSCOTESTCASE',
				Severity_Community__c = '3',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				SuppliedEmail = '99@outlook.com',
				LatestPublicCommentHTML__c = '<html>hello</html>',
				Component__c = 'Other',
				RecordTypeId = supCaseRecordType,
				SME_OwnerId__c = testUsers[0].Id,
				SME_Shadow__c = testUsers[1].Id,
				Status = 'On Hold'
			);
			insert testCase;

			EmailMessage newEmail = new EmailMessage(
				FromAddress = 'rosco@roscolab.com',
				FromName = 'Rosco',
				HtmlBody = 'ROSCOTESTCASE',
				ParentId = testCase.Id,
				RelatedToId = testCase.Id,
				Subject = 'ROSOTESTCASE',
				TextBody = 'ROSCOTESTCASE',
				ToAddress = 'rosco@roscolab.com'
			);
			insert newEmail;

			List<rosco_people__c> roscoPeople = new List<rosco_people__c>();
			roscoPeople.add(
				new rosco_people__c(
					Name = 'roscoapextestingd',
					contact__c = contacts[0].Id,
					user__c = testUsers[0].Id,
					pod__c = 'Support Center',
					primary_sme__c = 'SME-Patch',
					secondary_sme__c = 'SME-Map;SME-Patch'
				)
			);
			roscoPeople.add(
				new rosco_people__c(
					Name = 'roscoapextestingd',
					contact__c = contacts[1].Id,
					user__c = testUsers[1].Id,
					pod__c = 'Support Center',
					primary_sme__c = 'SME-Patch',
					secondary_sme__c = 'SME-Patch'
				)
			);
			roscoPeople.add(
				new rosco_people__c(
					Name = 'slack.name',
					contact__c = contacts[0].Id,
					user__c = testUsers[0].Id,
					pod__c = 'Support Center',
					primary_sme__c = 'SME-Patch',
					secondary_sme__c = 'SME-Map'
				)
			);
			insert roscoPeople;

			rosco_escalation_rbac__c rbac = new rosco_escalation_rbac__c(
				Name = '4',
				authorized__c = testUsers[0].Id
			);
			insert rbac;

			List<TAM_Team__c> teams = new List<TAM_Team__c>();
			teams.add(
				new TAM_Team__c(
					Name = 'Support-Patch',
					EscalationSubTeams__c = 'Support-Patch;',
					SME_Component_Name__c = 'Workbench-Patch',
					Slack_Ticket_Channel_ID__c = SlackUtility.CHANNEL_ROSCO_DEBUG,
					Slack_Escalation_Channel_ID__c = SlackUtility.CHANNEL_ROSCO_DEBUG,
					RecordTypeId = teamPodTypeId
				)
			);
			teams.add(
				new TAM_Team__c(
					Name = 'SME-Chronicle',
					SME_Component_Name__c = 'Workbench-Chronicle',
					Slack_Ticket_Channel_ID__c = SlackUtility.CHANNEL_ROSCO_DEBUG,
					Slack_Escalation_Channel_ID__c = SlackUtility.CHANNEL_ROSCO_DEBUG
				)
			);
			teams.add(
				new TAM_Team__c(
					Name = 'Speciality1',
					recordTypeId = teamSpecialityTypeId,
					EscalationSubTeams__c = 'Support-Patch'
				)
			);
			teams.add(
				new TAM_Team__c(
					Name = 'Support Center',
					recordTypeId = teamPodTypeId,
					Leader__c = UserInfo.getUserId()
				)
			);
			teams.add(
				new TAM_Team__c(
					Name = 'Support-Patch',
					recordTypeId = teamSMETypeId,
					Specialty_Group__c = teams[2].Id,
					L2_Slack_Channel_Ids__c = 'foo,bar',
					L2_Slack_Groups__c = 'foo,bar',
					L2_Sev_1_SLO__c = 1.0,
					L2_Sev_2_SLO__c = 1.0,
					L2_Sev_3_SLO__c = 1.0,
					L2_SMS_Text_Numbers__c = 'foo,bar',
					L3_Email_Aliases__c = 'foo,bar',
					L3_Slack_Channel_Ids__c = 'foo,bar',
					L3_Slack_Groups__c = 'foo,bar',
					L3_Sev_1_SLO__c = 1.0,
					L3_Sev_2_SLO__c = 1.0,
					L3_Sev_3_SLO__c = 1.0,
					L3_SMS_Text_Numbers__c = 'foo,bar',
					L4_Email_Aliases__c = 'foo,bar',
					L4_Slack_Channel_Ids__c = 'foo,bar',
					L4_Slack_Groups__c = 'foo,bar',
					L4_Sev_1_SLO__c = 1.0,
					L4_Sev_2_SLO__c = 1.0,
					L4_Sev_3_SLO__c = 1.0,
					L4_SMS_Text_Numbers__c = 'foo,bar',
					L5_Email_Aliases__c = 'foo,bar',
					L5_Slack_Channel_Ids__c = 'foo,bar',
					L5_Slack_Groups__c = 'foo,bar',
					L5_Sev_1_SLO__c = 1.0,
					L5_Sev_2_SLO__c = 1.0,
					L5_Sev_3_SLO__c = 1.0,
					L5_SMS_Text_Numbers__c = 'foo,bar'
				)
			);
			teams.add(
				new TAM_Team__c(
					Name = 'SME-Other',
					SME_Component_Name__c = 'Other',
					Slack_Ticket_Channel_ID__c = SlackUtility.CHANNEL_ROSCO_DEBUG,
					Slack_Escalation_Channel_ID__c = SlackUtility.CHANNEL_ROSCO_DEBUG,
					RecordTypeId = teamSMETypeId
				)
			);
			insert teams;

			List<TAM_Team_Member__c> teamMembers = new List<TAM_Team_Member__c>();

			teamMembers.add(
				new TAM_Team_Member__c(
					RecordTypeId = memberSMETypeId,
					Responsibility__c = 'Support Enabled',
					Slack_Member_ID__c = 'U123',
					Slack_Name__c = 'foo.bar',
					TAM_Team__c = teams[0].Id,
					TAM__c = testUsers[2].Id
				)
			);
			teamMembers.add(
				new TAM_Team_Member__c(
					RecordTypeId = memberSMETypeId,
					Responsibility__c = 'Support Enabled',
					Slack_Member_ID__c = 'U123',
					Slack_Name__c = 'foo.bar',
					TAM_Team__c = teams[1].Id,
					TAM__c = testUsers[2].Id
				)
			);
			teamMembers.add(
				new TAM_Team_Member__c(
					RecordTypeId = memberSMETypeId,
					Responsibility__c = 'Support Enabled',
					Slack_Member_ID__c = 'U124',
					Slack_Name__c = 'foo.bars',
					TAM_Team__c = teams[0].Id,
					TAM__c = testUsers[0].Id
				)
			);
			teamMembers.add(
				new TAM_Team_Member__c(
					RecordTypeId = memberPODTypeId,
					Responsibility__c = 'Support Enabled',
					Slack_Member_ID__c = 'U125',
					Slack_Name__c = 'pod.bar',
					TAM_Team__c = teams[0].Id,
					TAM__c = testUsers[0].Id
				)
			);
			teamMembers.add(
				new TAM_Team_Member__c(
					RecordTypeId = memberSMETypeId,
					Responsibility__c = 'Escalation Engineer',
					Slack_Member_ID__c = 'U126',
					Slack_Name__c = 'esc.engineer',
					TAM_Team__c = teams[4].Id,
					TAM__c = testUsers[0].Id
				)
			);
			teamMembers.add(
				new TAM_Team_Member__c(
					RecordTypeId = memberSMETypeId,
					Responsibility__c = 'Principal Escalation Engineer',
					Slack_Member_ID__c = 'U127',
					Slack_Name__c = 'principal.engineer',
					TAM_Team__c = teams[4].Id,
					TAM__c = testUsers[0].Id
				)
			);
			insert teamMembers;
		}
	}
	@IsTest
	static void nullOrEmpty_AlwaysReturnBoolean() {
		Test.startTest();
		Boolean isEmpty = RoscoEscalate.nullOrEmpty('foo');
		Assert.isFalse(isEmpty);

		isEmpty = RoscoEscalate.nullOrEmpty('');
		Assert.isTrue(isEmpty);
		Test.stopTest();
	}

	@IsTest
	static void addChronicleSupportToCc_WhenMultipleRoscoChronicleContact_CreateMultipleCaseContactRole() {
		Case testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Test.startTest();
		RoscoEscalate.addChronicleSupportToCc(testCase.Id);
		Test.stopTest();

		Assert.areEqual(
			2,
			[SELECT COUNT() FROM CaseContactRole WHERE CasesId = :testCase.Id],
			'Two case contact role should be created.'
		);
	}

	@IsTest
	static void addChronicleSupportToCc_WhenOnlyOneRoscoChronicleContact_CreateOneCaseContactRole() {
		Case testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];
		Case_Management__c cmSetting = [
			SELECT Id, rosco_chronicle_contactid__c
			FROM Case_Management__c
			LIMIT 1
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			String[] contactIds = cmSetting.rosco_chronicle_contactid__c.split(',');
			cmSetting.rosco_chronicle_contactid__c = contactIds[0];
			update cmSetting;

			Test.startTest();
			RoscoEscalate.addChronicleSupportToCc(testCase.Id);
			Test.stopTest();
		}

		Assert.areEqual(
			1,
			[SELECT COUNT() FROM CaseContactRole WHERE CasesId = :testCase.Id],
			'One case contact role should be created.'
		);
	}

	@IsTest
	static void getInitInfo_AlwaysReturnCaseDetails() {
		TriggerHandler.bypass('CaseTriggerHandler');
		Case testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			testCase.critsit__c = true;
			testCase.Tags__c = 'TestTag';
			testCase.Escalation_Status__c = 'L2 Escalation Engineer';
			testCase.Escalation_Tier__c = 'Level 2';
			testCase.Escalation_L2_Date__c = System.today();
			testCase.Escalation_Team__c = 'SME-Chronicle';
			testCase.Escalation_Artifact__c = 'TestArtifact';
			testCase.Escalation_L2_SME_Engaged_Date__c = null;
			update testCase;

			Test.startTest();
			Map<String, String> caseInfo = RoscoEscalate.getInitInfo(testCase.Id);
			Test.stopTest();

			Assert.isNotNull(caseInfo, 'Return should NOT be null');
		}
	}

	@IsTest
	static void getInfoFromReason_AlwaysReturnEscalationReasonValue() {
		String reason = 'Escalation Reason:\n===\nROSCOTESTCASEReason\nEscalation Artifacts:\n===\nROSCOTESTCASE';

		Test.startTest();
		String roscoReason = RoscoEscalate.getInfoFromReason(reason);
		Test.stopTest();

		Assert.areEqual('ROSCOTESTCASEReason\n', roscoReason);
	}

	@IsTest
	static void getArtifactFromReason_AlwaysReturnEscalationArtifactValue() {
		String reason = 'Escalation Reason:\n===\nROSCOTESTCASE\nEscalation Artifacts:\n===\nROSCOTESTCASEArtifact';

		Test.startTest();
		String artifact = RoscoEscalate.getArtifactFromReason(reason);
		Test.stopTest();

		Assert.areEqual('ROSCOTESTCASEArtifact\n', artifact);
	}

	@IsTest
	static void test_unit_getThreadIdFromEmail() {
		Case caseObj = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Test.startTest();
		RoscoEscalate.getThreadIdFromEmail(caseObj.Id, 'chronicle');
		RoscoEscalate.getThreadIdFromEmail(caseObj.Id, '_00D60IYkG[.]_500[0-9A-Za-z]*');
		Test.stopTest();
	}

	@IsTest
	static void removeChronicleSupportFromCc_AlwaysDeleteRelatedCaseContactRecords() {
		Case testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoEscalate.addChronicleSupportToCc(testCase.Id);
			RoscoEscalate.removeChronicleSupportFromCc(testCase.Id);
			Test.stopTest();
		}

		Assert.areEqual(
			0,
			[SELECT COUNT() FROM CaseContactRole WHERE CasesId = :testCase.Id],
			'Case contact role should be deleted.'
		);
	}

	@IsTest
	static void getPods_ReturnTAMTeamWithPodRecordType() {
		Test.startTest();
		String pods = RoscoEscalate.getPods('Support');
		Test.stopTest();

		Assert.areEqual(true, pods.contains('Support'));
	}

	@IsTest
	static void setPodSMEAsCCR_WhenAccountHasNoPod_CreatesNoCaseContactRole() {
		Account accountObj = [SELECT Id FROM Account WHERE Name = 'roscoapextestingd'];
		Case testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoEscalate.setPodSMEAsCCR(accountObj.Id, testCase.Id, 'SME-Patch');
			Test.stopTest();
		}

		List<CaseContactRole> contactRoles = [
			SELECT Id
			FROM CaseContactRole
			WHERE CasesId = :testCase.Id AND Role = ''
		];
		Assert.areEqual(
			0,
			contactRoles.size(),
			'No CCR created when account has no TAM-assigned pod.'
		);
	}

	@IsTest
	static void test_unit_getSMEInfo() {
		Account accountObj = [SELECT Id FROM Account WHERE Name = 'roscoapextestingd'];

		Test.startTest();
		RoscoEscalate.getSMEInfo(accountObj.Id, 'SME-Patch', 'Level 2', 'Support');
		RoscoEscalate.getSMEInfo(accountObj.Id, 'SME-Other', 'Level 2', 'Support');
		RoscoEscalate.getSMEInfo(accountObj.Id, 'SME-Other', 'Level 3', 'Support');
		RoscoEscalate.getSMEInfo(accountObj.Id, 'SME-Other', 'Level 2', 'Support');
		Test.stopTest();
	}

	@IsTest
	static void test_unit_getEscalationEngineer() {
		Case caseObj = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];
		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			List<User> testUsers = new List<User>();
			for (Integer i = 1; i <= 6; i++) {
				testUsers.add(
					TestUserFactory.createUser(
						'Manager' + i,
						'roscoapextest' + i + '@taniumtest.com',
						'xafds' + i,
						Utility.getAdminUserProfileId(),
						Utility.getCorporateRoleId()
					)
				);
			}
			insert testUsers;

			testUsers[0].ManagerId = adminUser.Id;
			testUsers[1].ManagerId = testUsers[0].Id;
			testUsers[2].ManagerId = testUsers[1].Id;
			testUsers[3].ManagerId = testUsers[2].Id;
			testUsers[4].ManagerId = testUsers[3].Id;
			testUsers[5].ManagerId = testUsers[4].Id;
			update testUsers;

			TAM_Team_Member__c teamMember = [
				SELECT Id, TAM__c
				FROM TAM_Team_Member__c
				WHERE RecordType.DeveloperName = 'Escalation_SME'
				LIMIT 1
			];
			teamMember.TAM__c = testUsers[0].Id;
			teamMember.TAM_Team__c = [
				SELECT Id
				FROM TAM_Team__c
				WHERE Name = 'Support-Patch' AND recordType.DeveloperName = 'Escalation_SME'
				LIMIT 1
			]
			.Id;
			update teamMember;

			Test.startTest();
			List<TAM_Team_Member__c> members = new List<TAM_Team_Member__c>(
				[
					SELECT
						TAM__c,
						Responsibility__c,
						Slack_Name__c,
						TAM_Team__r.Name,
						TAM_Team__r.Specialty_Group__r.Name,
						TAM__r.Name,
						TAM__r.Email,
						TAM__r.ManagerId,
						TAM__r.Manager.Manager.Id,
						TAM__r.Manager.Manager.Manager.Id,
						TAM__r.Manager.Manager.Manager.Manager.Id,
						TAM__r.Manager.Manager.Manager.Manager.Manager.Id,
						TAM__r.UserRole.Name
					FROM TAM_Team_Member__c
					WHERE
						RecordType.DeveloperName = 'Escalation_SME'
						AND Responsibility__c IN ('Escalation Engineer')
				]
			);
			System.assertEquals(true, !members.isEmpty());
			List<Map<String, String>> podSMEMap = RoscoEscalate.getPodSMEMap(
				true,
				'Support',
				'Level 2'
			);
			List<Map<String, String>> escalationEngineers = RoscoEscalate.getEscalationEngineer(
				'',
				'Support-Patch',
				'',
				caseObj.Id,
				'Level 2',
				'Support'
			);
			RoscoEscalate.getEscalationEngineer(
				'',
				'Support-Patch',
				'',
				caseObj.Id,
				'Level 2',
				'Support'
			);
			escalationEngineers = RoscoEscalate.getEscalationEngineer(
				'',
				'Support-Patch',
				'',
				caseObj.Id,
				'Level 2',
				'Support'
			);
			escalationEngineers = RoscoEscalate.getEscalationEngineer(
				'',
				'',
				'',
				caseObj.Id,
				'Level 2',
				'Support'
			);
			escalationEngineers = RoscoEscalate.getEscalationEngineer(
				'',
				'Support-Patch',
				'',
				caseObj.Id,
				'Level 2',
				'Support'
			);
			escalationEngineers = RoscoEscalate.getEscalationEngineer(
				'j',
				'Support-Patch',
				'',
				caseObj.Id,
				'Level 3',
				'Support'
			);
			escalationEngineers = RoscoEscalate.getEscalationEngineer(
				'',
				'Support-Patch',
				'',
				caseObj.Id,
				'Level 3',
				'Support'
			);
			RoscoEscalate.getShadowLookup('', 'SME-Patch', '', caseObj.Id, 'Level 2', 'Support');
			List<Map<String, String>> shadowTeam = RoscoEscalate.getShadowLookup(
				'',
				'SME-Patch',
				'',
				caseObj.Id,
				'Level 2',
				'Support'
			);
			shadowTeam = RoscoEscalate.getShadowLookup('', '', '', caseObj.Id, 'Level 2', 'Support');
			shadowTeam = RoscoEscalate.getShadowLookup(
				'j',
				'Support-Patch',
				'',
				caseObj.Id,
				'Level 3',
				'Support'
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_unit_getUsersAuthorizedLevels() {
		User roscoUser = [SELECT Id FROM User WHERE LastName = 'ApexUser'];

		System.runAs(roscoUser) {
			Test.startTest();
			String authorizedLevels = RoscoEscalate.getUsersAuthorizedLevels();
			Test.stopTest();

			Assert.areEqual('Level 1,Level 1,Level 2,Level 3,Level 4,Level 5', authorizedLevels);
		}
	}

	@IsTest
	static void test_unit_getSMEOwnerLookup() {
		Test.startTest();
		List<Map<String, String>> smeOwner = RoscoEscalate.getSMEOwnerLookup('rosco');
		Test.stopTest();

		Assert.isTrue(smeOwner.size() > 0);
	}

	@IsTest
	static void test_unit_getSMEList() {
		Case testCase = [SELECT Id, ContactId FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			RoscoEscalate.setCcr(String.valueOf(testCase.ContactId), testCase.Id, 'Engaged SME');

			Test.startTest();
			RoscoEscalate.getSMEList(testCase.Id, 'Support');
			Test.stopTest();
		}
	}

	@IsTest
	static void test_unit_getShadowList2() {
		Case testCase = [SELECT Id, ContactId FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Test.startTest();
		RoscoEscalate.getShadowList2(testCase.Id, 'Support');
		Test.stopTest();
	}

	@IsTest
	static void test_unit_getSMEString() {
		Case testCase = [SELECT Id, ContactId FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			RoscoEscalate.setCcr(String.valueOf(testCase.ContactId), testCase.Id, 'Engaged SME');

			Test.startTest();
			RoscoEscalate.getSMEString(testCase.Id);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_unit_removeSMEFromAllCases() {
		Case testCase = [SELECT Id, SME_OwnerId__c FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			testCase.Escalation_Status__c = 'L2 Escalation Engineer';
			testCase.Escalation_Tier__c = 'Level 2';
			testCase.SME_OwnerId__c = UserInfo.getUserId();
			update testCase;

			Test.startTest();
			RoscoEscalate.removeSMEFromAllCases(UserInfo.getUserId());
			Test.stopTest();
		}
	}

	@IsTest
	static void test_unit_saveCaseDeescalate() {
		Case testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			testCase.Tags__c = 'HydraReportingL4';
			testCase.Escalation_Tier__c = 'Level 3';
			testCase.SME_OwnerId__c = UserInfo.getUserId();
			update testCase;

			Map<String, String> sme1 = new Map<String, String>();
			sme1.put('contactid', '003S000001HarLPIAZ');
			sme1.put('slackname', 'adam.caskey.rosco');
			sme1.put('Email', 'fooo12@bar.com');
			sme1.put('pod', 'Federal');

			sme1.put('contactemail', 'adam.caskey@tanium.com.rosco');
			sme1.put('sme', 'SME-Patch');

			List<Map<String, String>> smes = new List<Map<String, String>>();
			smes.add(sme1);

			Test.startTest();
			RoscoEscalate.saveCase(
				testCase.Id,
				'Level 2',
				'Support Center',
				'SME-Chronicle',
				'deescalate',
				'escinput1',
				'escartifact1',
				'false',
				smes
			);

			RoscoEscalate.saveCase(
				testCase.Id,
				'Level 2',
				'Support Center',
				'SME-Chronicle',
				'deescalate',
				'escinput1',
				'escartifact1',
				'false',
				smes,
				smes,
				'L3 Principal Escalation Engineer',
				'No'
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_unit_sendChronicleEmailDeEscalated() {
		Case caseObj = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Test.startTest();
		RoscoEscalate.sendChronicleEmail(
			caseObj.Id,
			'123456',
			'ROSCOTESTCASE',
			'refid1',
			'reason1',
			'artifacts1'
		);
		RoscoEscalate.sendChronicleEmailDeEscalated(caseObj.Id);
		Test.stopTest();
	}

	@IsTest
	static void test_unit_sendToEscalationSlack() {
		Case testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		System.runAs(TestUserFactory.getAdminUser()) {
			testCase.Escalation_Team__c = 'SME-Patch';
			testCase.Escalation_Tier__c = 'Level 2';
			update testCase;

			TAM_Team__c tamTeam = [
				SELECT Id
				FROM TAM_Team__c
				WHERE
					RecordType.DeveloperName = 'Escalation_Pod'
					AND Name = 'Support-Patch'
					AND SME_Component_Name__c = 'Workbench-Patch'
			];
			delete tamTeam;

			Test.startTest();
			RoscoEscalate.sendToEscalationSlack(
				testCase.Id,
				'Level 2',
				'Support Center',
				'Support-Patch',
				'escinput',
				'escartifact'
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_unit_sendToEscalationSlackNewSME() {
		Case caseObj = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Test.startTest();
		RoscoEscalate.sendToEscalationSlackNewSME(
			caseObj.Id,
			'Level 2',
			'SME-Patch',
			'jason.johnson'
		);
		Test.stopTest();
	}

	@IsTest
	static void test_unit_setSmeOwner() {
		Case caseObj = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];
		Contact contactObj = [SELECT Id FROM Contact WHERE Email = 'roscoapextest@tanium.com'];

		System.runAs(TestUserFactory.getAdminUser()) {
			CaseContactRole ccr = new CaseContactRole(
				CasesId = caseObj.Id,
				ContactId = contactObj.Id,
				Role = 'Engaged SME'
			);
			insert ccr;

			Test.startTest();
			RoscoEscalate.setSmeOwner(caseObj.Id);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_unit_setSmeViaString() {
		Case caseObj = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Test.startTest();
		RoscoEscalate.setSmeViaString('roscoapextest@tanium.com', caseObj.Id, 'Support');
		RoscoEscalate.setSmeViaString('roscoapextest2@tanium.com', caseObj.Id, 'Support');
		Test.stopTest();

		CaseContactRole[] caseContactRoles = [
			SELECT Id
			FROM CaseContactRole
			WHERE CasesId = :caseObj.Id AND Role = 'Engaged SME'
		];
		Assert.areEqual(1, caseContactRoles.size());
	}

	@IsTest
	static void test_unit_qCallOut() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Test.startTest();
		RoscoEscalate.qCallOut testCallout = new RoscoEscalate.qCallOut('testURL', 'GET', 'TestBODY');
		Id jobId1 = System.enqueueJob(testCallout);
		Test.stopTest();
	}

	public class mockCallout implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest request) {
			HttpResponse res = new HttpResponse();
			res.setBody('{"text":"value"}');
			res.setStatusCode(200);
			return res;
		}
	}
}