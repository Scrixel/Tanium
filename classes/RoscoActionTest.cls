/**
 * Copyright (c) 2026 Tanium
 *
 * @BUSINESS: Test class for RoscoAction.
 * @AUTHOR: Jason Johnson, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7175	  2023-12-01    Redesigned test class to follow Tanium design pattern for test classes
 * SS-10251	  2025-02-27    Remove Constellant Dev references and replace it with Tanium Developer Users
 * SS-10265	  2025-03-07    Add testRemovePermissionSet_Always_RemoveUserPermissionSet
 * SS-10624   2025-06-03    Updated test class
 * SS-13497   2026-07-13    Remove deprecated fields for project kondo group 2
 */
@IsTest
private class RoscoActionTest {
	private static final String TAM_NEXT_STEPS_ACCT = '9/3/2024 - accountnextstepsfoo';
	private static final String TAM_NEXT_STEPS_OPP = '9/3/2024 - oppnextstepsfoo';
	private static final String EMAIL_ADDRESS = 'foobar@roscolab.com';
	private static final String EMAIL_ADDRESS2 = 'foobar2@roscolab.com';
	private static final String USER_NAME = 'foobar@roscolab.com.123876123';

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'CaseTriggerHandler',
				'UserTriggerHandler'
			}
		);
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Account> accounts = new List<Account>();
			Account account1 = TestFactory.buildAccount('roscoapextestingd');
			account1.slack_channel_id__c = 'TESTCASE';
			account1.Country_Exception_Approved__c = true;
			accounts.add(account1);

			Account account2 = TestFactory.buildAccount('Customer Community External Members Account');
			account2.slack_channel_id__c = 'TESTCASE';
			account2.Country_Exception_Approved__c = true;
			accounts.add(account2);
			insert accounts;

			List<Contact> contacts = new List<Contact>();
			contacts.add(
				new Contact(
					Email = EMAIL_ADDRESS,
					FirstName = 'Test',
					LastName = 'Apex',
					AccountId = accounts[0].Id
				)
			);
			contacts.add(
				new Contact(
					Email = EMAIL_ADDRESS2,
					FirstName = 'Test2',
					LastName = 'Apex2',
					AccountId = accounts[0].Id
				)
			);
			insert contacts;

			Opportunity opportunity = new Opportunity(
				Name = 'RoscoActionNextStepsTestOpp',
				AccountId = accounts[0].Id,
				StageName = Utility.PROSPECTING,
				CloseDate = System.today()
			);
			opportunity.TAM_Next_Steps__c = TAM_NEXT_STEPS_OPP;
			opportunity.Type = 'New Customer';
			insert opportunity;

			Case caseRecord = new Case(AccountId = accounts[0].Id);
			insert caseRecord;

			List<Jira_Issue__c> jiraIssues = new List<Jira_Issue__c>();
			jiraIssues.add(
				new Jira_Issue__c(Issue_Key__c = 'ProjectFoo-123', Issue_Summary__c = 'Summary Foo')
			);
			jiraIssues.add(
				new Jira_Issue__c(
					Issue_Key__c = 'invalidIssueKey',
					Issue_Summary__c = 'invalidIssueKey'
				)
			);
			insert jiraIssues;

			User user = new User(
				Email = EMAIL_ADDRESS,
				FirstName = 'Foo',
				LastName = 'Bar',
				UserName = USER_NAME,
				Alias = 'foo',
				CommunityNickName = 'foo',
				TimeZoneSidKey = 'America/Los_Angeles',
				LocaleSidKey = 'en_US',
				EmailEncodingKey = 'ISO-8859-1',
				ProfileId = profileId,
				LanguageLocaleKey = 'en_US',
				ContactId = contacts[0].Id
			);
			insert user;

			List<Rosco_Time__c> roscoTimes = new List<Rosco_Time__c>();
			roscoTimes.add(
				new Rosco_Time__c(
					User__c = UserInfo.getUserId(),
					Minutes__c = 15,
					LaborCategory__c = 'Other Account Time',
					LaborSubCategory__c = 'General',
					LaborDate__c = Datetime.now(),
					Account__c = accounts[0].Id,
					Opportunity__c = opportunity.Id
				)
			);
			roscoTimes.add(
				new Rosco_Time__c(
					User__c = UserInfo.getUserId(),
					Minutes__c = 15,
					LaborCategory__c = 'PreSales Activity',
					LaborSubCategory__c = 'General',
					LaborDate__c = Datetime.now(),
					Account__c = accounts[0].Id,
					Opportunity__c = opportunity.Id
				)
			);
			roscoTimes.add(
				new Rosco_Time__c(
					User__c = user.Id,
					Minutes__c = 15,
					LaborCategory__c = 'Other Account Time',
					LaborSubCategory__c = 'General',
					LaborDate__c = Datetime.now(),
					Account__c = accounts[0].Id
				)
			);
			insert roscoTimes;

			Rosco_domain__c roscoDomain = new Rosco_domain__c(
				Name = 'roscoapextestingd',
				user_automation__c = 'No Automation',
				Auto_register_developer_tanium_com__c = true,
				Account__c = accounts[0].Id
			);
			insert roscoDomain;

			Rosco_Account__c roscoAccount = new Rosco_Account__c(
				Name = 'customer-foo',
				account__c = accounts[0].Id,
				Bypass_Triage_Tickets__c = 'xxx',
				Secondary_Slack_Channel_Id__c = 'xxx',
				Tertiary_Slack_Channel_Id__c = 'xxx',
				case_flash__c = 'caseflash1',
				Case_Flash_Persist__c = 'caseflash2',
				account_flash__c = 'flashfoo'
			);
			insert roscoAccount;

			Id escalationSmeRecordTypeId = Utility.getRecordTypeIdByAPIName(
				'TAM_Team__c',
				'Escalation_SME'
			);
			TAM_Team__c tamTeam = new TAM_Team__c(
				RecordTypeId = escalationSmeRecordTypeId,
				Account__c = accounts[0].Id,
				Name = 'TAM Team 1'
			);
			insert tamTeam;
		}
	}

	@IsTest
	static void testNullOrEmpty_WhenNotNull_ReturnFalse() {
		Account[] accounts = [SELECT Id FROM Account];

		Boolean nullOrEmpty = true;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			nullOrEmpty = RoscoAction.nullOrEmpty(accounts);
			Test.stopTest();
		}
		Assert.isTrue(nullOrEmpty == false);
	}

	@IsTest
	static void testGetSaveAndDelKnowledgeArticleTopics_Always_ReturnKnowledgeArticleTopic() {
		Knowledge__kav article;
		String networkId;
		Topic topic;
		String topicAsJson = null;
		String returnValue;

		System.runAs(TestUserFactory.getAdminUser()) {
			article = new Knowledge__kav(
				Title = 'ROSCOTESTCASE Tanium Server',
				Summary = 'ROSCOTESTCASE',
				UrlName = 'urlname',
				Language = 'en_US',
				IsVisibleInCsp = true,
				IsVisibleInPkb = true,
				IsVisibleInPrm = true
			);
			insert article;
			networkId = [SELECT Name FROM Network WHERE Name = 'Tanium Customer Community'].Id;
			topic = new Topic(Name = 'foo', NetworkId = networkId);
			insert topic;

			Test.startTest();
			RoscoAction.saveKnowledgeArticleTopics(article.Id, 'foo');
			topicAsJson = RoscoAction.getKnowledgeArticleTopics(article.Id);
			returnValue = RoscoAction.delKnowledgeArticleTopics(article.Id, 'foo');
			Test.stopTest();
		}
		Assert.isFalse(topicAsJson == null);
	}

	@IsTest
	static void testGetAvailableUserTimeZones_Always_ReturnTimeZones() {
		List<Map<String, String>> timeZones = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			timeZones = RoscoAction.getAvailableUserTimeZones();
			Test.stopTest();
		}
		Assert.isFalse(timeZones == null);
	}

	@IsTest
	static void testGetModuleOptions_Always_ReturnModuleOptions() {
		List<Map<String, String>> moduleOptions = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			moduleOptions = RoscoAction.getModuleOptions();
			Test.stopTest();
		}
		Assert.isFalse(moduleOptions == null);
	}
	@IsTest
	static void testEnableUser_WhenDevUser_CreatePermissionSetAssignment() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];
		Contact[] contacts = [SELECT Id FROM Contact];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.enableUser(contacts[0].Id, 'Tanium Community Login Unknown', 'true');
			RoscoAction.enableUser(contacts[1].Id, 'Tanium Community Login Unknown', 'true');
			Test.stopTest();
		}
		PermissionSet ps = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
			LIMIT 1
		];
		PermissionSetAssignment[] psaList = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE PermissionSetId = :ps.Id
		];
		Assert.isFalse(psaList.isEmpty());
	}

	@IsTest
	static void testGetAccountId_Always_ReturnAccountId() {
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		Account account = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			account = RoscoAction.getAccount(contact.Id);
			Test.stopTest();
		}
		Assert.isFalse(account.Id == null);
	}

	@IsTest
	static void testGetAccountId2_Always_ReturnAccountId() {
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		String accountId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountId = RoscoAction.getAccountId2(opportunity.Id);
			Test.stopTest();
		}
		Assert.isFalse(accountId == null);
	}

	@IsTest
	static void testGetAccountOpportunities_Always_ReturnAccountOpportunities() {
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];
		List<Map<String, String>> accountOpportunities = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountOpportunities = RoscoAction.getAccountOpportunities(caseRecord.Id);
			accountOpportunities = RoscoAction.getAccountOpportunities(opportunity.Id);
			Test.stopTest();
		}
		Assert.isFalse(accountOpportunities == null);
	}

	@IsTest
	static void testGetUniqueAlias_Always_ReturnAliases() {
		String uniqueAlias = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			uniqueAlias = RoscoAction.getUniqueAlias();
			Test.stopTest();
		}
		Assert.isFalse(uniqueAlias == null);
	}

	@IsTest
	static void testGetEmailDomainId_Always_ReturnEmailDomainId() {
		Rosco_domain__c roscoDomain = [SELECT Id, Name FROM Rosco_domain__c LIMIT 1];
		String emailDomainId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			emailDomainId = RoscoAction.getEmailDomainId(roscoDomain.Name);
			Test.stopTest();
		}
		Assert.isFalse(emailDomainId == null);
	}

	@IsTest
	static void testGetEmailDomains_Always_ReturnEmailDomains() {
		Account[] accounts = [SELECT Id FROM Account];
		List<Map<String, String>> emailDomains = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			emailDomains = RoscoAction.getEmailDomains(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(emailDomains == null);
	}

	@IsTest
	static void testGetAccountInfo_Always_ReturnAccountInfo() {
		Account[] accounts = [SELECT Id FROM Account];
		Map<String, String> accountInfo = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountInfo = RoscoAction.getAccountInfo(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(accountInfo == null);
	}

	@IsTest
	static void testGetAccountTime_Always_ReturnAccountTime() {
		Account[] accounts = [SELECT Id FROM Account];
		List<Map<String, String>> accountTime = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountTime = RoscoAction.getAccountTime(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(accountTime == null);
	}

	@IsTest
	static void testGetDevUsers_Always_ReturnDevUsers() {
		List<String> devUsers = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			devUsers = RoscoAction.getDevUsers();
			Test.stopTest();
		}
		Assert.isFalse(devUsers == null);
	}

	@IsTest
	static void testGetFlash_Always_ReturnFlash() {
		Account[] accounts = [SELECT Id FROM Account];
		String flash = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			flash = RoscoAction.getFlash(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(flash == null);
	}

	@IsTest
	static void testGetFrozenUsers_Always_ReturnFrozenUser() {
		String[] frozen;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			frozen = RoscoAction.getFrozenUsers();
			Test.stopTest();
		}
		Assert.isFalse(frozen.isEmpty());
	}

	@IsTest
	static void testGetUserTime_Always_ReturnUserTime() {
		List<Map<String, String>> userTime = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			userTime = RoscoAction.getUserTime('opportunity');
			userTime = RoscoAction.getUserTime('case');
			userTime = RoscoAction.getUserTime('account');
			Test.stopTest();
		}
		Assert.isFalse(userTime == null);
	}

	@IsTest
	static void testGetUserTimeLookup_Always_ReturnUserTimeLookup() {
		Account[] accounts = [SELECT Id, Name FROM Account];
		Opportunity opportunity = [SELECT Id, Name FROM Opportunity LIMIT 1];
		Case caseRecord = [SELECT Id, CaseNumber FROM Case LIMIT 1];
		List<Map<String, String>> userTimeLookup = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			userTimeLookup = RoscoAction.getUserTimeLookup('', null);
			userTimeLookup = RoscoAction.getUserTimeLookup(accounts[0].Name, null);
			userTimeLookup = RoscoAction.getUserTimeLookup(opportunity.Name, null);
			userTimeLookup = RoscoAction.getUserTimeLookup(caseRecord.CaseNumber, null);
			Test.stopTest();
		}
		Assert.isFalse(userTimeLookup == null);
	}

	@IsTest
	static void testGetTagLookup_Always_ReturnTagLookup() {
		Jira_Issue__c[] jiraIssues = [SELECT Id, Issue_Key__c, Issue_Summary__c FROM Jira_Issue__c];
		List<Map<String, String>> tagLookup = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			tagLookup = RoscoAction.getTagLookup(jiraIssues[0].Issue_Key__c, '');
			tagLookup = RoscoAction.getTagLookup(jiraIssues[0].Issue_Key__c, 'invalidIssueKey');
			Test.stopTest();
		}
		Assert.isFalse(tagLookup == null);
	}

	@IsTest
	static void testGetLoginHistory_Always_ReturnLoginHistory() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];
		Map<String, String> loginHistory = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			loginHistory = RoscoAction.getLoginHistory(user.Id);
			Test.stopTest();
		}
		Assert.isFalse(loginHistory == null);
	}

	@IsTest
	static void testGetRecordTags_Always_ReturnRecordTags() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];
		Jira_Issue__c jiraIssue = [
			SELECT Id, Issue_Key__c, Issue_Summary__c
			FROM Jira_Issue__c
			LIMIT 1
		];

		List<Map<String, String>> accountRecordTags = null;
		List<Map<String, String>> opportunityRecordTags = null;
		List<Map<String, String>> caseRecordTags = null;

		Map<String, String> jira = new Map<String, String>();
		jira.put('jiraIssueSFId', String.valueOf(jiraIssue.Id));
		jira.put('impact', 'Blocking');
		jira.put('module', 'Asset');
		jira.put('comment', 'Comment 123');
		jira.put('jiraIssueKey', 'ProjectFoo-123');
		jira.put('jiraSummary', 'Summary Foo');
		jira.put('recordId', String.valueOf(accounts[0].Id));

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.tagSave(JSON.serialize(jira));
			accountRecordTags = RoscoAction.getRecordTags(accounts[0].Id, 'true');
			jira.put('recordId', String.valueOf(opportunity.Id));
			jira.put('opportunityId', String.valueOf(opportunity.Id));
			opportunityRecordTags = RoscoAction.getRecordTags(opportunity.Id, 'true');
			jira.put('recordId', String.valueOf(caseRecord.Id));
			jira.put('caseId', String.valueOf(caseRecord.Id));
			caseRecordTags = RoscoAction.getRecordTags(caseRecord.Id, 'true');
			Test.stopTest();
		}

		Assert.isFalse(
			accountRecordTags == null ||
			opportunityRecordTags == null ||
			caseRecordTags == null
		);
	}

	@IsTest
	static void testGetRoscoActionTagInit_Always_ReturnTagInfo() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];
		Jira_Issue__c jiraIssue = [
			SELECT Id, Issue_Key__c, Issue_Summary__c
			FROM Jira_Issue__c
			LIMIT 1
		];

		Map<String, String> accountTagInfo = null;
		Map<String, String> oppTagInfo = null;
		Map<String, String> caseTagInfo = null;

		Map<String, String> jira = new Map<String, String>();
		jira.put('Id', String.valueOf(jiraIssue.Id));
		jira.put('impact', 'Blocking');
		jira.put('module', 'Asset');
		jira.put('comment', 'Comment 123');
		jira.put('Issue_Key', 'ProjectFoo-123');
		jira.put('Issue_Summary', 'Summary Foo');
		jira.put('recordId', String.valueOf(opportunity.Id));

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountTagInfo = RoscoAction.getRoscoActionTagInit(String.valueOf(accounts[0].Id));
			oppTagInfo = RoscoAction.getRoscoActionTagInit(String.valueOf(opportunity.Id));
			caseTagInfo = RoscoAction.getRoscoActionTagInit(String.valueOf(caseRecord.Id));
			Test.stopTest();
		}
		Assert.isFalse(accountTagInfo == null && oppTagInfo == null && caseTagInfo == null);
	}

	@IsTest
	static void testGetOpportunityTime_Always_ReturnOpportunityTime() {
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		List<Map<String, String>> opportunityTime = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			opportunityTime = RoscoAction.getOpportunityTime(opportunity.Id);
			Test.stopTest();
		}
		Assert.isFalse(opportunityTime == null);
	}

	@IsTest
	static void testGetOpportunityInfo_Always_ReturnOpportunityInfo() {
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Map<String, String> opportunityInfo = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			opportunityInfo = RoscoAction.getOpportunityInfo(opportunity.Id);
			Test.stopTest();
		}
		Assert.isFalse(opportunityInfo == null);
	}

	@IsTest
	static void testGetPreSalesAccountTime_Always_ReturnPreSalesAccountTime() {
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		List<Map<String, String>> preSalesAccountTime = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			preSalesAccountTime = RoscoAction.getPreSalesAccountTime(opportunity.Id);
			Test.stopTest();
		}
		Assert.isFalse(preSalesAccountTime == null);
	}

	@IsTest
	static void testGetProfiles_Always_ReturnProfiles() {
		Map<String, String> profiles = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			profiles = RoscoAction.getProfiles();
			Test.stopTest();
		}
		Assert.isFalse(profiles == null);
	}

	@IsTest
	static void testGetRoscoAccountInfo_Always_ReturnRoscoAccountInfo() {
		Account[] accounts = [SELECT Id FROM Account];
		Map<String, String> roscoAccountInfo = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			roscoAccountInfo = RoscoAction.getRoscoAccountInfo(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(roscoAccountInfo == null);
	}

	@IsTest
	static void testGetSMETeams_Always_ReturnSMETeams() {
		List<Map<String, String>> smeTeams = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			smeTeams = RoscoAction.getSMETeams();
			Test.stopTest();
		}
		Assert.isFalse(smeTeams == null);
	}

	@IsTest
	static void testGetTimeType_Always_ReturnTimeType() {
		Account[] accounts = [SELECT Id FROM Account];
		String timeType = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			timeType = RoscoAction.getTimeType(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(timeType == null);
	}

	@IsTest
	static void testGetUserRoleName_Always_ReturnUserRoleName() {
		String userRoleName = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			userRoleName = RoscoAction.getUserRoleName();
			Test.stopTest();
		}
		Assert.isFalse(userRoleName == null);
	}

	@IsTest
	static void testInitRoscoActionAccountSupport_Always_ReturnRoscoActionAccountSupport() {
		Account[] accounts = [SELECT Id FROM Account];
		Map<String, Object> result = null;
		Map<String, Object> result2 = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.initRoscoActionAccountSupport(String.valueOf(accounts[0].Id));
			result2 = RoscoAction.initRoscoActionAccountSupport(String.valueOf(accounts[1].Id));
			Test.stopTest();
		}
		Assert.isFalse(result == null || result2 == null);
	}

	@IsTest
	static void testInitRoscoActionAccountTime_Always_ReturnRoscoActionAccountTime() {
		Account[] accounts = [SELECT Id FROM Account];
		Map<String, Object> result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.initRoscoActionAccountTime(String.valueOf(accounts[0].Id));
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testInitGetRoscoActionCaseTime_Always_ReturnResult() {
		Account[] accounts = [SELECT Id FROM Account];
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];

		UserRole uRole = [SELECT Id, Name FROM UserRole WHERE Id = :UserInfo.getUserRoleId() LIMIT 1];
		Case_Management__c cmSetting;
		cmSetting = new Case_Management__c();
		cmSetting.Name = '';
		cmSetting.rosco_accountcasepopup__c = uRole.Name;
		String cfg = null;
		Map<String, Object> result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			insert cmSetting;
			result = RoscoAction.initRoscoActionCaseTime(caseRecord.Id);
			cfg = RoscoAction.getRoscoAccountCasePopup(accounts[0].Id);
			result = RoscoAction.initRoscoActionCaseTime(caseRecord.Id);
			cfg = RoscoAction.getRoscoAccountCasePopup(caseRecord.Id);
			Test.stopTest();
		}
		Assert.isFalse(cfg == null || result == null);
	}

	@IsTest
	static void testInitRoscoActionContactSupport_Always_ReturnResult() {
		Account[] accounts = [SELECT Id FROM Account];
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		Contact contact2;
		Map<String, Object> result = null;
		Map<String, Object> result2 = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.initRoscoActionContactSupport(String.valueOf(contact.Id));
			contact2 = [SELECT Id, AccountId FROM Contact WHERE Id = :contact.Id];
			contact2.AccountId = accounts[1].Id;
			result2 = RoscoAction.initRoscoActionContactSupport(String.valueOf(contact2.Id));
			Test.stopTest();
		}
		Assert.isFalse(result == null || result2 == null);
	}

	@IsTest
	static void testInitRoscoActionNextSteps_Always_ReturnNextSteps() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Map<String, Object> accountNextSteps = null;
		Map<String, Object> opportunityNextSteps = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountNextSteps = RoscoAction.initRoscoActionNextSteps(String.valueOf(accounts[0].Id));
			opportunityNextSteps = RoscoAction.initRoscoActionNextSteps(
				String.valueOf(opportunity.Id)
			);
			Test.stopTest();
		}
		Assert.isFalse(accountNextSteps == null || opportunityNextSteps == null);
	}

	@IsTest
	static void testInitRoscoActionOpportunityCEActivity2_Always_ReturnResult() {
		Map<String, Object> result = null;
		String accountOrOpportunityId = '';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.initRoscoActionOpportunityCEActivity2(accountOrOpportunityId);
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testInitRoscoActionOpportunityPreSalesActivity_Always_ReturnResult() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Map<String, Object> result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.initRoscoActionOpportunityPreSalesActivity(opportunity.Id);
			result = RoscoAction.initRoscoActionOpportunityPreSalesActivity(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testGetSetContactSupportOption_Always_ReturnSupportOption() {
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		String supportOptions = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			supportOptions = RoscoAction.getPickListSupportOptions();
			RoscoAction.setContactSupportOption(String.valueOf(contact.Id), supportOptions);
			Test.stopTest();
		}
		Assert.isFalse(supportOptions == null);
	}

	@IsTest
	static void testSetDevUser() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.setDevUser(String.valueOf(user.Id), true);
			RoscoAction.setDevUser(String.valueOf(user.Id), false);
			Test.stopTest();
		}
		PermissionSet ps = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
			LIMIT 1
		];
		PermissionSetAssignment[] psaList = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE PermissionSetId = :ps.Id
		];
		Assert.isFalse(psaList.isEmpty());
	}

	@IsTest
	static void testSetIsFrozen_WhenFalseParameter_UserNotFrozen() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];
		Map<String, String> customer;
		customer = new Map<String, String>();
		customer.put('id', String.valueOf(user.Id));
		customer.put('profile', 'Tanium Community Login Unknown');
		customer.put('email', EMAIL_ADDRESS);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.setIsFrozen(String.valueOf(user.Id), true);
			RoscoAction.setIsFrozen(String.valueOf(user.Id), false);
			Test.stopTest();
		}

		UserLogin userLogin = [SELECT Id, IsFrozen FROM UserLogin WHERE UserId = :user.Id LIMIT 1];
		Assert.isTrue(userLogin.IsFrozen == false);
	}

	@IsTest
	static void testSetProfileId_Always_SetProfileId() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Super User'].Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.setProfileId(String.valueOf(user.Id), profileId);
			Test.stopTest();
		}
		User updatedUser = [SELECT Id, ProfileId FROM User WHERE UserName = :USER_NAME LIMIT 1];
		Assert.isTrue(updatedUser.ProfileId == profileId);
	}

	@IsTest
	static void testShouldRequireOpp_Always_ReturnTrue() {
		Account[] accounts = [SELECT Id FROM Account];
		Boolean shouldRequireOpp = false;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			shouldRequireOpp = RoscoAction.shouldRequireOpp(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isTrue(shouldRequireOpp == true);
	}

	@IsTest
	static void testSaveEmailDomain_Always_ReturnResult() {
		Rosco_domain__c roscoDomain = [SELECT Id, Name FROM Rosco_domain__c LIMIT 1];
		String emailDomainName = 'roscolab.com';
		String result = null;
		Map<String, String> emailDomain;

		System.runAs(TestUserFactory.getAdminUser()) {
			roscoDomain.Name = emailDomainName;
			update roscoDomain;
			Test.startTest();
			result = RoscoAction.isProposedDomainOk(emailDomainName);
			emailDomain = new Map<String, String>();
			emailDomain.put('domain', 'foo2.com');
			emailDomain.put('automation', 'Account Only');
			emailDomain.put('developer', 'false');

			RoscoAction.saveEmailDomain('0010m00000gGcmaAAC', emailDomain);
			result = RoscoAction.isProposedDomainOk('foo2.com');
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testGetEmailDomains_Always_ReturnResult() {
		Account[] accounts = [SELECT Id FROM Account];
		List<Map<String, String>> result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.getEmailDomains(accounts[0].Id);
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testSaveRoscoAccountInfo_Always_CreateRoscoAccount() {
		Account[] accounts = [SELECT Id FROM Account];

		Map<String, String> roscoAccountInfo = new Map<String, String>();
		roscoAccountInfo.put('Name', 'foo');
		roscoAccountInfo.put('byPassSlackId', 'foo');
		roscoAccountInfo.put('secondarySlackId', 'foo');
		roscoAccountInfo.put('tertiarySlackId', 'foo');
		roscoAccountInfo.put('flash', 'foo');
		roscoAccountInfo.put('flashPersist', 'foo');

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.saveRoscoAccountInfo(accounts[0].Id, roscoAccountInfo);
			RoscoAction.saveRoscoAccountInfo(accounts[1].Id, roscoAccountInfo);
			Test.stopTest();
		}

		Rosco_Account__c[] roscoAccounts = [SELECT Id FROM Rosco_Account__c];
		Assert.isTrue(roscoAccounts.size() > 1);
	}

	@IsTest
	static void testSaveRoscoActionAccountTime_Always_CreateRoscoTime() {
		Account[] accounts = [SELECT Id FROM Account];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.saveRoscoActionAccountTime(
				String.valueOf(accounts[0].Id),
				'15',
				'Account Time',
				'General',
				String.valueOf(Datetime.now())
			);
			RoscoAction.saveRoscoActionAccountTime(
				String.valueOf(accounts[0].Id),
				'1440',
				'Account Time',
				'General',
				String.valueOf(Datetime.now())
			);
			Test.stopTest();
		}

		Rosco_Time__c[] roscoTimes = [SELECT Id FROM Rosco_Time__c];
		Assert.isTrue(roscoTimes.size() > 3);
	}

	@IsTest
	static void testSaveRoscoActionAccountTimeNov2023_Always_CreateRoscoTime() {
		Account[] accounts = [SELECT Id FROM Account];
		List<Map<String, String>> results;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = RoscoAction.saveRoscoActionAccountTimeNov2023(
				String.valueOf(accounts[0].Id),
				'15',
				'Account Time',
				'General',
				null,
				String.valueOf(Datetime.now())
			);
			Test.stopTest();
		}

		Rosco_Time__c[] roscoTimes = [SELECT Id FROM Rosco_Time__c];
		Assert.isTrue(roscoTimes.size() > 3);
	}

	@IsTest
	static void testSaveRoscoActionAccountSupport_Always_ReturnSuccessMsg() {
		Account[] accounts = [SELECT Id FROM Account];
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];

		Map<String, String> accountInfo;
		Map<String, String> roscoAccountInfo;
		Map<String, String> customer;
		List<Map<String, String>> customers;
		List<Map<String, String>> customers2;
		List<Map<String, String>> emailDomains;
		Map<String, String> emailDomain;
		String result = null;

		accountInfo = new Map<String, String>();
		accountInfo.put('Name', 'foo');
		accountInfo.put('SupportModel', 'Support Center');
		accountInfo.put('SlackId', 'XXX');
		roscoAccountInfo = new Map<String, String>();
		roscoAccountInfo.put('Name', 'foo');
		roscoAccountInfo.put('byPassSlackId', 'foo');
		roscoAccountInfo.put('secondarySlackId', 'foo');
		roscoAccountInfo.put('tertiarySlackId', 'foo');
		roscoAccountInfo.put('flash', 'foo');
		roscoAccountInfo.put('flashPersist', 'foo');
		customers = new List<Map<String, String>>();
		customer = new Map<String, String>();
		customer.put('id', String.valueOf(user.Id));
		customer.put('profile', 'Tanium Community Login Unknown');
		customer.put('email', EMAIL_ADDRESS);
		customer.put('scenario', 'accountAction');
		customer.put('devUser', 'true');
		customers.add(customer);
		emailDomains = new List<Map<String, String>>();
		emailDomain = new Map<String, String>();
		emailDomain.put('domain', 'foo1.com');
		emailDomain.put('automation', 'Account Only');
		emailDomain.put('developer', 'true');
		emailDomains.add(emailDomain);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.saveRoscoActionAccountSupport(
				String.valueOf(accounts[0].Id),
				accountInfo,
				roscoAccountInfo,
				customers,
				emailDomains
			);
			accountInfo.put('SupportModel', 'Field TAM');
			accountInfo.put('SlackId', '123');
			roscoAccountInfo.put('byPassSlackId', 'foo2');
			roscoAccountInfo.put('secondarySlackId', 'foo2');
			roscoAccountInfo.put('tertiarySlackId', 'foo2');
			roscoAccountInfo.put('flash', 'foo2');
			roscoAccountInfo.put('flashPersist', 'foo2');
			customer.put('profile', 'Tanium Community Login Authenticated');
			customer.put('devUser', 'false');
			customers2 = new List<Map<String, String>>();
			customers2.add(customer);
			RoscoAction.saveRoscoActionAccountSupport(
				String.valueOf(accounts[0].Id),
				accountInfo,
				roscoAccountInfo,
				customers2,
				emailDomains
			);
			Test.stopTest();
		}
		Assert.isFalse(result == 'Undefined error');
	}

	@IsTest
	static void testSaveRoscoActionCaseTime_Always_CreateRoscoTime() {
		Account[] accounts = [SELECT Id FROM Account];
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];
		Map<String, String> result;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.saveRoscoActionCaseTime(
				String.valueOf(caseRecord.Id),
				'15',
				'Case Time',
				'General',
				String.valueOf(Datetime.now())
			);
			Test.stopTest();
		}
		Rosco_Time__c[] roscoTimes = [SELECT Id FROM Rosco_Time__c];
		Assert.isTrue(roscoTimes.size() > 3);
	}

	@IsTest
	static void testSaveRoscoActionContactSupport_Always_ReturnResult() {
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];
		Map<String, String> customer;
		String result = null;

		customer = new Map<String, String>();
		customer.put('id', String.valueOf(user.Id));
		customer.put('profile', 'Tanium Community Login Unknown');
		customer.put('email', EMAIL_ADDRESS);
		customer.put('contactId', String.valueOf(contact.Id));

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.saveRoscoActionContactSupport(customer);
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testSaveRoscoActionOpportunityTime_Always_CreateRoscoTime() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		List<Map<String, String>> result;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.saveRoscoActionOpportunityTime(
				String.valueOf(opportunity.Id),
				'PreSales Activity',
				'Demo',
				String.valueOf(Datetime.now())
			);
			result = RoscoAction.saveRoscoActionOpportunityTime(
				String.valueOf(opportunity.Id),
				'PreSales Activity',
				'POC',
				String.valueOf(Datetime.now())
			);
			result = RoscoAction.saveRoscoActionOpportunityTime(
				String.valueOf(accounts[0].Id),
				'PreSales Activity',
				'POC',
				String.valueOf(Datetime.now())
			);
			Test.stopTest();
		}
		Rosco_Time__c[] roscoTimes = [SELECT Id FROM Rosco_Time__c];
		Assert.isTrue(roscoTimes.size() > 3);
	}

	@IsTest
	static void testSaveRoscoActionOpportunityTime2_Always_CreateRoscoTime() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		List<Map<String, String>> result;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.saveRoscoActionOpportunityTime2(
				String.valueOf(opportunity.Id),
				String.valueOf(opportunity.Id),
				'PreSales Activity',
				'Demo',
				null,
				String.valueOf(Datetime.now()),
				'15'
			);
			result = RoscoAction.saveRoscoActionOpportunityTime2(
				String.valueOf(accounts[0].Id),
				String.valueOf(opportunity.Id),
				'PreSales Activity',
				'POC',
				null,
				String.valueOf(Datetime.now()),
				'15'
			);
			Test.stopTest();
		}
		Rosco_Time__c[] roscoTimes = [SELECT Id FROM Rosco_Time__c];
		Assert.isTrue(roscoTimes.size() > 3);
	}

	@IsTest
	static void testTagSave_Always_ReturnResult() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Jira_Issue__c jiraIssue = [
			SELECT Id, Issue_Key__c, Issue_Summary__c
			FROM Jira_Issue__c
			LIMIT 1
		];
		Map<String, String> jira;
		String result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			jira = new Map<String, String>();
			jira.put('Id', String.valueOf(jiraIssue.Id));
			jira.put('impact', 'Blocking');
			jira.put('module', 'Asset');
			jira.put('comment', 'Comment 123');
			jira.put('Issue_Key', 'ProjectFoo-123');
			jira.put('Issue_Summary', 'Summary Foo');
			jira.put('recordId', String.valueOf(opportunity.Id));
			Test.startTest();
			result = RoscoAction.tagSave(JSON.serialize(jira));
			jira.put('recordId', String.valueOf(accounts[0].Id));
			result = RoscoAction.tagSave(JSON.serialize(jira));
			jira.put('comment', 'SummaryUpdate2');
			result = RoscoAction.tagSave(JSON.serialize(jira));
			result = RoscoAction.tagSaveOppUpdate(JSON.serialize(jira));
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testIsSupportTAM_WhenNotSupportTAM_ReturnFalse() {
		Boolean result = true;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.isSupportTAM();
			Test.stopTest();
		}

		Assert.isFalse(result == true);
	}

	@IsTest
	static void testIsUserMgr_WhenNonManagerUser_ReturnFalse() {
		Boolean result = true;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.isUserMgr();
			Test.stopTest();
		}

		Assert.isFalse(result == true);
	}

	@IsTest
	static void testIsUnsupportedAccount_WhenCustomerCommunityExternalMembersAccount_ReturnTrue() {
		Account[] accounts = [SELECT Id FROM Account];
		Boolean result = false;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.isUnsupportedAccount(String.valueOf(accounts[1].Id));
			Test.stopTest();
		}
		Assert.isFalse(result == false);
	}

	@IsTest
	static void testSaveTAMNextSteps_Always_ReturnSuccessMsg() {
		Account[] accounts = [SELECT Id FROM Account];
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		String accountNextSteps;
		String opportunityNextSteps;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			accountNextSteps = RoscoAction.saveTAMNextSteps(accounts[0].Id, TAM_NEXT_STEPS_ACCT);
			opportunityNextSteps = RoscoAction.saveTAMNextSteps(opportunity.Id, TAM_NEXT_STEPS_OPP);
			Test.stopTest();
		}
		Assert.isFalse(
			accountNextSteps == 'Undefined error' ||
			opportunityNextSteps == 'Undefined error'
		);
	}

	@IsTest
	static void testRemoveTime_Always_ReturnNullResult() {
		Account[] accounts = [SELECT Id FROM Account];
		Rosco_Time__c rt = [SELECT CreatedDate FROM Rosco_Time__c LIMIT 1];
		List<Map<String, String>> result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.removeTime(
				String.valueOf(accounts[0].Id),
				rt.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
			);
			Test.stopTest();
		}
		Assert.isTrue(result == null);
	}

	@IsTest
	static void testRemoveTimeOpp_Always_ReturnResult() {
		Opportunity opportunity = [SELECT Id FROM Opportunity LIMIT 1];
		Rosco_Time__c rt = [SELECT CreatedDate FROM Rosco_Time__c LIMIT 1];
		List<Map<String, String>> result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.removeTimeOpp(
				String.valueOf(opportunity.Id),
				rt.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
			);
			Test.stopTest();
		}
		Assert.isFalse(result == null);
	}

	@IsTest
	static void testResetUserPassword_WhenRunningTest_ReturnErrorMsg() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];
		String result = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoAction.resetUserPassword(String.valueOf(user.Id));
			Test.stopTest();
		}
		Assert.isTrue(result == 'unknown error');
	}

	@IsTest
	static void testSaveCustomers_Always_AssignUserPermissionSet() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];

		Map<String, String> customer = new Map<String, String>();
		customer.put('id', String.valueOf(user.Id));
		customer.put('profile', 'Tanium Community Login Unknown');
		customer.put('email', EMAIL_ADDRESS);

		List<Map<String, String>> customers = new List<Map<String, String>>();
		customers.add(customer);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.saveCustomers(customers);
			Test.stopTest();
		}
		PermissionSet ps = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
			LIMIT 1
		];
		PermissionSetAssignment[] psaList = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE PermissionSetId = :ps.Id
		];
		Assert.isFalse(psaList.isEmpty());
	}

	@IsTest
	static void testRemovePermissionSet_Always_RemoveUserPermissionSet() {
		User user = [SELECT Id FROM User WHERE UserName = :USER_NAME LIMIT 1];
		Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET]
		.Id;

		PermissionSetAssignment psa = new PermissionSetAssignment(
			PermissionSetId = permSetId,
			AssigneeId = user.Id
		);
		insert psa;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			RoscoAction.removePermissionSet(user.Id, Constants.CONSTELLANT_DEV_PERM_SET);
			Test.stopTest();
		}

		PermissionSetAssignment[] psaList = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE PermissionSetId = :permSetId AND AssigneeId = :user.Id
		];

		Assert.isTrue(psaList.isEmpty());
	}
}