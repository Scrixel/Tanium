/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: RoscoEmailUtilityTest - Test methods for class RoscoEmailUtility
 * @Date: 6/28/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7719    2024-05-30    Fix for duplicate case creation when replying to email thread
 * SS-9295    2024-10-04    Remove references to case assignment
 * SS-9622    2024-12-03    Remove test methods that reference to ThreadId_caseSensitive__c
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */
@IsTest
private class RoscoEmailUtilityTest {
	private static final String SUPPORTCASE_RECORDTYPEID = RoscoUtility.getRecordTypeIdByAPIName(
		'Case',
		'Support'
	);
	private static Map<String, String> defaultInboundEmailSettings = new Map<String, String>{
		'toAddresses' => 'support@tanium.com,other@tanium.com',
		'plainTextBody' => 'plain old text body',
		'htmlBody' => '<html>HTML <ul><li>body</li></ul></html>',
		'subject' => 'default'
	};

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'UserTriggerHandler',
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'CaseTriggerHandler',
				'EmailMessageTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Id profileId = Utility.getProfileId('Tanium System Administrator');
			Id userRoleId = Utility.getUserRoleId('Corporate');

			List<User> testUsers = new List<User>();
			testUsers.add(
				TestUserFactory.createUser(
					'ApexUser',
					'roscoapextest@tanium.com',
					'xafds',
					profileId,
					userRoleId
				)
			);
			testUsers.add(
				TestUserFactory.createUser(
					'ApexUser2',
					'roscoapextest2@roscolab.com',
					'34343',
					profileId,
					userRoleId
				)
			);
			insert testUsers;

			Account acct = TestFactory.buildAccount('roscoapextestingd');
			acct.slack_channel_id__c = 'TESTCASE';
			insert acct;

			List<Contact> contacts = new List<Contact>();
			contacts.add(
				new Contact(
					Email = 'roscoapextest@tanium.com',
					FirstName = 'Test',
					LastName = 'Apex',
					AccountId = acct.Id
				)
			);
			contacts.add(
				new Contact(
					Email = 'roscoapextest2@tanium.com',
					FirstName = 'Test2',
					LastName = 'Apex',
					AccountId = acct.Id
				)
			);
			insert contacts;

			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Name = '';
			cmSetting.rosco_case_accountid__c = acct.Id;
			cmSetting.rosco_chronicle_contactid__c = contacts[0].Id + ',' + contacts[1].Id;
			cmSetting.rosco_local_refid_re__c =
				'_' +
				getOrgId_ThreadIdOldFormat() +
				'[.]_500[0-9A-Za-z]*';
			cmSetting.rosco_local_refid_newformat__c =
				'!' +
				getOrgId_ThreadIdNewFormat() +
				'[.]!500[0-9A-Za-z]*';
			insert cmSetting;

			Case testCase = TestFactory.buildCase(acct.Id, contacts[0].Id);
			testCase.OwnerId = '00532000005VMZAAA4';
			testCase.RecordTypeId = SUPPORTCASE_RECORDTYPEID;
			insert testCase;

			EmailMessage newEmail = TestFactory.buildEmailMessage(
				'ROSCOTESTCASE',
				testCase.Id,
				testCase.Id
			);
			insert newEmail;

			List<CaseContactRole> caseConRoles = new List<CaseContactRole>();
			caseConRoles.add(new CaseContactRole(ContactId = contacts[0].Id, CasesId = testCase.Id));
			caseConRoles.add(new CaseContactRole(ContactId = contacts[1].Id, CasesId = testCase.Id));
			insert caseConRoles;

			List<rosco_people__c> roscoPeople = new List<rosco_people__c>();
			roscoPeople.add(
				TestFactory.buildRoscoPeople('roscoapextestingd', contacts[0].Id, testUsers[0].Id)
			);
			roscoPeople.add(
				TestFactory.buildRoscoPeople('slack.name', contacts[0].Id, testUsers[0].Id)
			);
			roscoPeople.add(
				TestFactory.buildRoscoPeople('roscoapextestingd', contacts[1].Id, testUsers[1].Id)
			);
			roscoPeople[1].secondary_sme__c = 'SME-Patch';
			insert roscoPeople;

			List<TAM_Team__c> teams = new List<TAM_Team__c>();
			teams.add(TestFactory.buildTAMTeam('SME-Patch', 'CCC66LTRT'));
			teams[0].SME_Component_Name__c = 'Workbench-Patch';

			teams.add(TestFactory.buildTAMTeam('SME-Chronicle', 'CCC66LTRT'));
			teams[1].SME_Component_Name__c = 'Workbench-Chronicle';
			insert teams;

			rosco_escalation_rbac__c rbac = new rosco_escalation_rbac__c(
				Name = '4',
				authorized__c = testUsers[0].Id
			);

			Site_User_Blacklisted_Domains__c blacklist = new Site_User_Blacklisted_Domains__c(
				Name = 'blacklisted.com'
			);
			insert new List<SObject>{ rbac, blacklist };
		}
	}

	static Messaging.InboundEmail getTestInboundEmail(Map<String, String> settings) {
		Messaging.InboundEmail email = new Messaging.InboundEmail();
		email.subject = settings.get('subject');
		email.fromAddress = settings.get('fromAddress');
		email.fromName = settings.get('fromName');
		email.toAddresses = settings.get('toAddresses').split(',');

		Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
		hd.name = 'X-TestName';
		hd.value = settings.get('TestName');
		email.headers = new List<Messaging.InboundEmail.Header>{ hd };

		email.plainTextBody = settings.get('plainTextBody');
		email.plainTextBodyIsTruncated = false;
		email.htmlBody = settings.get('htmlBody');
		email.htmlBodyIsTruncated = false;

		return email;
	}

	static EmailMessage GetEmailMessageFromInbound(
		Messaging.InboundEmail inbound,
		String parentCaseId
	) {
		return new EmailMessage(
			FromAddress = inbound.fromAddress,
			FromName = inbound.fromName,
			ToAddress = inbound.toAddresses[0],
			Subject = inbound.subject,
			TextBody = inbound.plainTextBody,
			HtmlBody = inbound.htmlBody,
			ParentId = parentCaseId
		);
	}

	static void AttachFileToEmailMessage(String ParentId) {
		Attachment attach = new Attachment();
		attach.Name = 'Test Attachment';
		Blob bodyBlob = Blob.valueOf('Test Attachment Body');
		attach.Body = bodyBlob;
		attach.ParentId = ParentId;
		insert attach;
	}

	static Messaging.InboundEnvelope getTestInboundEnvelope(Map<String, String> settings) {
		Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
		envelope.fromAddress = settings.get('fromAddress');
		envelope.toAddress = settings.get('toAddresses');

		return envelope;
	}

	static Account GetTestAccount(Map<String, String> settings) {
		//return new Account(Name = settings.get('Name'));
		return TestFactory.buildAccount(settings.get('Name'));
	}

	static Contact GetTestContact(Map<String, String> settings) {
		return new Contact(
			AccountId = settings.get('AccountId'),
			FirstName = settings.get('FirstName'),
			LastName = settings.get('LastName'),
			Email = settings.get('Email'),
			MailingCountry = 'Japan',
			OtherCountry = 'Japan'
		);
	}

	static Case GetTestCase(Map<String, String> settings) {
		String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');

		return new Case(
			ContactId = settings.get('ContactId'),
			AccountId = settings.get('AccountId'),
			Subject = settings.get('Subject'),
			recordTypeId = recordTypeId
		);
	}

	static CaseContactRole GetTestCaseContactRole(Map<String, String> settings) {
		return new CaseContactRole(
			CasesId = settings.get('CasesId'),
			ContactId = settings.get('ContactId')
		);
	}

	static Map<String, String> getDefaultInboundEmailSettings() {
		Map<String, String> settings = new Map<String, String>();
		settings.put('toAddresses', 'support@tanium.com,other@tanium.com');
		settings.put('plainTextBody', 'plain old text body');
		settings.put('htmlBody', '<html>HTML <ul><li>body</li></ul></html>');
		settings.put('subject', 'default');

		return settings;
	}

	static Map<String, String> getRoscoSettings(List<String> settings) {
		Map<String, String> tmp = new Map<String, String>(), ret = new Map<String, String>();
		RoscoEmailUtility.initRoscoDefaults(tmp);
		RoscoEmailUtility.initRoscoSettings(tmp);

		for (String retKey : settings) {
			ret.put(retKey, tmp.get(retKey));
		}

		return ret;
	}

	static Map<String, String> GetRoscoCaseSettings() {
		List<String> settings = new List<String>{ 'catch_all_case', 'check_auth', 'authenticated' };
		return getRoscoSettings(settings);
	}

	@IsTest
	static void testEmailUtility_init_baseline() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> testMap = new Map<String, String>(),
				roscoEmail = new Map<String, String>();

			Test.startTest();
			Messaging.InboundEmail testInbound = getTestInboundEmail(defaultInboundEmailSettings);
			for (Integer i = 0; i < EmailMessage.HtmlBody.getDescribe().getLength() - 6; i += 6)
				testInbound.htmlBody += ' test ';
			RoscoEmailUtility.init(testMap, testInbound);
			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_init_baseline_exception() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> testMap = new Map<String, String>(),
				roscoEmail = new Map<String, String>();

			Test.startTest();
			Messaging.InboundEmail testInbound = getTestInboundEmail(defaultInboundEmailSettings);
			for (Integer i = 0; i < EmailMessage.HtmlBody.getDescribe().getLength() - 6; i += 6)
				testInbound.htmlBody += ' test ';
			RoscoEmailUtility.init(testMap, null);
			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_initRoscoEmail_baseline() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> roscoMap = new Map<String, String>();

			settings.put('plainTextBody', 'Sender: testing.com ; Subject: testingonly');
			settings.put('subject', 'PROOFPOINT_TEST_MAIL');
			settings.put('fromAddress', 'knowncontact@account.com');
			settings.put('TestName', 'testEmailUtility_initRoscoEmail_baseline');
			Messaging.InboundEmail testInbound = getTestInboundEmail(settings);

			Test.startTest();
			RoscoEmailUtility.init(roscoMap, testInbound);
			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_isEmailTAM() {
		Map<String, String> rosco = new Map<String, String>();
		RoscoEmailUtility.isEmailTAM(rosco, 'jason.johnson@tanium.com');
	}

	@IsTest
	static void testEmailUtility_processHFPOCEmail() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id, AccountId, ContactId FROM Case LIMIT 1];
			Map<String, String> roscoMap = new Map<String, String>();
			Map<String, String> settings = defaultInboundEmailSettings;

			String emailBody =
				'Ticket Type: Support \n' +
				'Summary: Testing Summary \n' +
				'Company BDM: Testing Company BDM \n' +
				'Contact Name: Known Contact \n' +
				'Contact Email: roscoapextest@tanium.com \n' +
				'Contact Company: Testing Company \n' +
				'Contact Phone: +123456 \n' +
				'Preferred Mode of Contact: Email \n' +
				'Support Request Topic: Testing \n' +
				'Support Request Question: Test Q ### Testing ### Test ' +
				'---------------------------------';

			settings.put('plainTextBody', emailBody);
			settings.put('htmlBody', '<html>' + emailBody + '</html>');
			settings.put('fromAddress', 'roscoapextest2@tanium.com');
			settings.put('subject', 'HFPOC');

			Messaging.InboundEmail inboundEmail = getTestInboundEmail(settings);
			Messaging.InboundEnvelope inboundEnv = getTestInboundEnvelope(settings);

			Test.startTest();
			RoscoEmailUtility.init(roscoMap, inboundEmail);
			RoscoEmailUtility.rput(roscoMap, 'case_hfpoc_accountid', testCase.AccountId);
			RoscoEmailUtility.rput(roscoMap, 'case_hfpoc_contactid', testCase.ContactId);
			RoscoEmailUtility.processHFPOCEmail(roscoMap, inboundEmail, inboundEnv);

			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_rput_baseline() {
		// Stage data
		Map<String, String> testMap = new Map<String, String>();
		String tkey = 'tkey', tval = 'tval';
		RoscoEmailUtility.rput(testMap, tkey, tval);
		String testResult = testMap.get(tkey);

		System.assertNotEquals(null, testMap.get(tkey));
		System.assertEquals(tval, testMap.get(tkey));

		testMap.put('casepost', 'foo');
		RoscoEmailUtility.rput(testMap, 'casepost', 'foo');
		testMap.put('casepost', 'foo');
		RoscoEmailUtility.rput(testMap, 'casepost', 'bar');

		RoscoEmailUtility.rput(testMap, 'fromaddress', 'test@foo.com');
		RoscoEmailUtility.rput(testMap, 'fromaddress', 'test2@foo.com');

		RoscoEmailUtility.rput(testMap, 'case_contacts_api', 'test2@foo.com');

		RoscoEmailUtility.rput(testMap, 'ccaddresses', 'test2@foo.com;test3@foo.com');

		RoscoEmailUtility.rput(testMap, 'ccaddresses', 'testx@foo.com;testy@foo.com');

		RoscoEmailUtility.rput(testMap, 'emailpostfix', '.test');
	}

	@IsTest
	static void testEmailUtility_rput_nullValue() {
		Map<String, String> testMap = new Map<String, String>();
		String tkey = 'tkey', tval = null;
		RoscoEmailUtility.rput(testMap, tkey, tval);
		String testResult = testMap.get(tkey);

		System.assertNotEquals(null, testMap.get(tkey));
		System.assertEquals('', testMap.get(tkey));
	}

	@IsTest
	static void testEmailUtility_rput_emailAddresses() {
		// Test normalization and deduplication
		Map<String, String> testMap = new Map<String, String>();
		String tkey = 'toaddresses',
			tkey2 = 'people',
			cont1 = 'contact1@account.com',
			cont2 = 'contact2@account.com',
			cont3 = 'contact3@account.com',
			cont4 = 'contact4@account.com';
		String tval = cont2 + ',' + cont3 + ';' + cont2 + '; ' + cont4;

		testMap.put('fromaddress', cont1);
		RoscoEmailUtility.rput(testMap, tkey, tval);
		String testResult = testMap.get(tkey);

		System.assertNotEquals(null, testResult);
		System.assertEquals(cont2 + ';' + cont3 + ';' + cont4, testResult);
		System.assertEquals(cont1 + ';' + cont2 + ';' + cont3 + ';' + cont4, testMap.get(tkey2));
	}

	@IsTest
	static void testEmailUtility_rget_existingKey() {
		Map<String, String> testMap = new Map<String, String>();
		String tkey = 'tkey', tval = 'tval';
		testMap.put(tkey, tval);
		String testResult = RoscoEmailUtility.rget(testMap, tkey);

		System.assertNotEquals(null, testResult);
		System.assertEquals(tval, testResult);
	}

	@IsTest
	static void testEmailUtility_rget_invalidKey() {
		Map<String, String> testMap = new Map<String, String>();
		String tkey = 'tkey', tval = 'tval', invalidKey = tkey + '1';
		testMap.put(tkey, tval);
		String testResult = RoscoEmailUtility.rget(testMap, invalidKey);

		System.assertNotEquals(null, testResult);
		System.assertEquals('', testResult);
	}

	@IsTest
	static void testEmailUtility_getCaseId_ThreadIdFromSubject() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];
			testCase.Status = 'Closed';
			update testCase;

			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> testMap = new Map<String, String>();

			String oldThreadId =
				'ref:!' +
				getOrgId_ThreadIdNewFormat() +
				'.!' +
				String.valueOf(testCase.Id).left(6) +
				String.valueOf(testCase.Id).left(15).right(10).left(5).replace('0', '') +
				String.valueOf(testCase.Id).left(15).right(5) +
				':ref';

			String testName = 'testEmailUtility_getThreadIdFromEmail';
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');

			settings.put('TestName', testName + randomness);
			String threadId = EmailMessages.getFormattedThreadingToken(testCase.Id);
			settings.put('subject', testName + randomness + threadId);
			settings.put('fromAddress', 'knowncontact@account.com');
			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			Test.startTest();
			RoscoEmailUtility.init(testMap, testEmail);
			RoscoEmailUtility.getCaseId(testMap, testEmail);

			String caseId = RoscoEmailUtility.rget(testMap, 'caseid');
			Test.stopTest();

			Assert.isTrue(
				String.isBlank(caseId),
				'caseId is blank when existing case status is closed or closed as duplicate'
			);
		}
	}

	@IsTest
	static void testEmailUtility_getCaseId_CaseNumberFromSubject() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id, CaseNumber FROM Case LIMIT 1];
			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> testMap = new Map<String, String>();

			String testName = 'testEmailUtility_getCaseId_Subject';

			settings.put('TestName', testName);
			settings.put('fromAddress', 'knowncontact@account.com');
			settings.put('subject', testCase.CaseNumber + ':' + testName);

			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			Test.startTest();
			RoscoEmailUtility.init(testMap, testEmail);
			RoscoEmailUtility.getCaseId(testMap, testEmail);

			String caseId = RoscoEmailUtility.rget(testMap, 'caseid');
			Test.stopTest();

			Assert.areEqual(testCase.Id, caseId);
		}
	}

	@IsTest
	static void testEmailUtility_getCaseId_newCase() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> testMap = new Map<String, String>();

			String testName = 'testEmailUtility_getCaseId_newCase';
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');

			settings.put('subject', testName + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'knowncontact@account.com');

			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			Test.startTest();
			RoscoEmailUtility.init(testMap, testEmail);
			RoscoEmailUtility.getCaseId(testMap, testEmail);

			String caseId = RoscoEmailUtility.rget(testMap, 'caseid');
			Test.stopTest();

			Assert.isTrue(
				String.isBlank(caseId),
				'caseId is blank if no ThreadId, CaseNumber or Previous Email'
			);
		}
	}

	@IsTest
	static void testEmailUtility_getCaseId_CaseNumberFromSubjectUsingAccount() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id, CaseNumber FROM Case LIMIT 1];
			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> roscoMap = new Map<String, String>();

			String testName = 'testEmailUtility_getCaseId_CaseNumberFromSubjectUsingAccount';
			roscoMap.put('people', 'roscoapextest2@tanium.com');
			roscoMap.put('dup_check_multiple_case_limit', '5');

			settings.put('TestName', testName);
			settings.put('fromAddress', 'roscoapextest2@tanium.com');
			settings.put('subject', testCase.CaseNumber + ':' + testName);

			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			Test.startTest();
			RoscoEmailUtility.init(roscoMap, testEmail);
			roscoMap.put('subject_original', '');
			RoscoEmailUtility.getCaseId(roscoMap, testEmail);

			String caseId = RoscoEmailUtility.rget(roscoMap, 'caseid');
			Test.stopTest();

			Assert.areEqual(testCase.Id, caseId);
		}
	}

	@IsTest
	static void testEmailUtility_getCaseId_CaseIdFromPreviousEmails() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String testName = 'testEmailUtility_getCaseId_CaseNumberFromSubjectUsingAccount';
			Case testCase = [SELECT Id, CaseNumber, Subject, AccountId FROM Case LIMIT 1];
			testCase.Subject = testName;
			EmailMessage email = [
				SELECT Id, TextBody, HtmlBody, Subject
				FROM EmailMessage
				WHERE ParentId = :testCase.Id
			];
			email.Subject = testName;
			email.TextBody = testName;
			email.HtmlBody = testName;
			update new List<SObject>{ testCase, email };

			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> roscoMap = new Map<String, String>();

			roscoMap.put('people', 'roscoapextest2@tanium.com');
			roscoMap.put('dup_check_multiple_case_limit', '5');
			roscoMap.put('dup_check_multiple_email_limit', '5');
			roscoMap.put('dupchar', '20');

			settings.put('TestName', testName);
			settings.put('fromAddress', 'roscoapextest2@tanium.com');
			settings.put('subject', testName);
			settings.put('htmlBody', testName);

			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			Test.startTest();
			RoscoEmailUtility.init(roscoMap, testEmail);
			roscoMap.put('subject_original', '');
			RoscoEmailUtility.getCaseId(roscoMap, testEmail);

			String caseId = RoscoEmailUtility.rget(roscoMap, 'caseid');
			Test.stopTest();

			Assert.areEqual(testCase.Id, caseId);
		}
	}

	@IsTest
	static void testEmailUtility_checkMailApi_textBody() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];
			User testUser = [SELECT Id, Email FROM User WHERE Alias = 'xafds' LIMIT 1];

			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> testMap = new Map<String, String>();

			String testName = 'testEmailUtility_checkMailApi';
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			String threadId = EmailMessages.getFormattedThreadingToken(testCase.Id);

			settings.put('subject', testName + randomness + threadId);
			settings.put('TestName', testName + randomness);
			settings.put('fromAddress', 'soa@tanium.com');

			String testEmailTextBody =
				'#tancontact:knowncontact@account.com\n' +
				'#tancontact:unknowncontact@account.com\n' +
				'#tanowner:' +
				testUser.Email +
				'\n' +
				'#tanccr:testccr@account.com\n' +
				'#tanseverity:3\n' +
				'#tanseverity:5\n' +
				'#tancomponent:\n' +
				'#tancomponent:content\n' +
				'#tancomponent:author\n' +
				'#tancomponent:doc\n' +
				'#tancomponent:how\n' +
				'#tancomponent:license\n' +
				'#tancomponent:other\n' +
				'#tancomponent:pytan\n' +
				'#tancomponent:rbac\n' +
				'#tancomponent:appli\n' +
				'#tancomponent:client\n' +
				'#tancomponent:client tool\n' +
				'#tancomponent:console\n' +
				'#tancomponent:database\n' +
				'#tancomponent:excel\n' +
				'#tancomponent:interact\n' +
				'#tancomponent:module\n' +
				'#tancomponent:server\n' +
				'#tancomponent:solution\n' +
				'#tancomponent:zone\n' +
				'#tancomponent:tpan\n' +
				'#tancomponent:training\n' +
				'#tancomponent:connect\n' +
				'#tancomponent:index\n' +
				'#tancomponent:ir\n' +
				'#tancomponent:nqs\n' +
				'#tancomponent:patch\n' +
				'#tancomponent:asset\n' +
				'#tancomponent:comply\n' +
				'#tancomponent:deploy\n' +
				'#tancomponent:discover\n' +
				'#tancomponent:im\n' +
				'#tancomponent:map\n' +
				'#tancomponent:protect\n' +
				'#tancomponent:trends\n' +
				'#tancomponent:threat\n' +
				'#tanstatus:\n' +
				'#tanstatus:pend\n' +
				'#tanstatus:progress\n' +
				'#tanstatus:hold\n' +
				'#tanstatus:solv\n' +
				'#tantype:\n' +
				'#tantype:inc\n' +
				'#tantype:que\n' +
				'#tantype:feature\n' +
				'#tantype:task\n' +
				'#tantype:proj\n' +
				'#tanversion:7.2.3.4.5\n\n' +
				'Starting body now.';
			settings.put('htmlbody', '<html>' + testEmailTextBody + '</html>');
			settings.put('plainTextBody', testEmailTextBody);
			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			Test.startTest();
			testMap.put('fromaddress', 'soa@tanium.com');
			RoscoEmailUtility.init(testMap, testEmail);
			RoscoEmailUtility.checkMailApi(testMap);

			String mailAPI_OwnerId = RoscoEmailUtility.rget(testMap, 'mailapi_case_ownerid');
			Test.stopTest();

			Assert.areEqual(testUser.Id, mailAPI_OwnerId);
		}
	}

	@IsTest
	static void testEmailUtility_checkMailApi_htmlBody() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];
			User testUser = [SELECT Id, Email FROM User WHERE Alias = 'xafds' LIMIT 1];

			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> testMap = new Map<String, String>();

			String testName = 'testEmailUtility_checkMailApi';
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			String threadId = EmailMessages.getFormattedThreadingToken(testCase.Id);

			settings.put('subject', testName + randomness + threadId);
			settings.put('TestName', testName + randomness);
			settings.put('fromAddress', 'soa@tanium.com');

			String testEmailTextBody =
				'#tancontact:knowncontact@account.com\n' +
				'#tancontact:unknowncontact@account.com\n' +
				'#tanowner:' +
				testUser.Email +
				'\n' +
				'#tanccr:testccr@account.com\n' +
				'#tanseverity:3\n' +
				'#tanseverity:5\n' +
				'#tancomponent:\n' +
				'#tancomponent:content\n' +
				'#tancomponent:author\n' +
				'#tancomponent:doc\n' +
				'#tancomponent:how\n' +
				'#tancomponent:license\n' +
				'#tancomponent:other\n' +
				'#tancomponent:pytan\n' +
				'#tancomponent:rbac\n' +
				'#tancomponent:appli\n' +
				'#tancomponent:client\n' +
				'#tancomponent:client tool\n' +
				'#tancomponent:console\n' +
				'#tancomponent:database\n' +
				'#tancomponent:excel\n' +
				'#tancomponent:interact\n' +
				'#tancomponent:module\n' +
				'#tancomponent:server\n' +
				'#tancomponent:solution\n' +
				'#tancomponent:zone\n' +
				'#tancomponent:tpan\n' +
				'#tancomponent:training\n' +
				'#tancomponent:connect\n' +
				'#tancomponent:index\n' +
				'#tancomponent:ir\n' +
				'#tancomponent:nqs\n' +
				'#tancomponent:patch\n' +
				'#tancomponent:asset\n' +
				'#tancomponent:comply\n' +
				'#tancomponent:deploy\n' +
				'#tancomponent:discover\n' +
				'#tancomponent:im\n' +
				'#tancomponent:map\n' +
				'#tancomponent:protect\n' +
				'#tancomponent:trends\n' +
				'#tancomponent:threat\n' +
				'#tanstatus:\n' +
				'#tanstatus:pend\n' +
				'#tanstatus:progress\n' +
				'#tanstatus:hold\n' +
				'#tanstatus:solv\n' +
				'#tantype:\n' +
				'#tantype:inc\n' +
				'#tantype:que\n' +
				'#tantype:feature\n' +
				'#tantype:task\n' +
				'#tantype:proj\n' +
				'#tanversion:7.2.3.4.5\n\n' +
				'Starting body now.';
			settings.put('htmlBody', '<html>' + testEmailTextBody + '</html>');
			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			Test.startTest();
			testMap.put('fromaddress', 'soa@tanium.com');
			RoscoEmailUtility.init(testMap, testEmail);
			RoscoEmailUtility.checkMailApi(testMap);

			String mailAPI_OwnerId = RoscoEmailUtility.rget(testMap, 'mailapi_case_ownerid');
			Test.stopTest();

			Assert.areEqual(testUser.Id, mailAPI_OwnerId);
		}
	}

	@IsTest
	static void testEmailUtility_emailResponseCaseContactRolesSync() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id FROM Case LIMIT 1];
			Map<String, String> settings = defaultInboundEmailSettings;
			Map<String, String> testMap = new Map<String, String>();

			String testName = 'testEmailUtility_emailResponseCaseContactRolesSync';
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');

			settings.put('subject', testName + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'knowncontact@account.com');

			Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

			EmailMessage testEmailMsg = GetEmailMessageFromInbound(testEmail, testCase.Id);
			insert testEmailMsg;

			Attachment attach = TestFactory.buildAttachment(testEmailMsg.Id);
			insert attach;

			Test.startTest();
			RoscoEmailUtility.init(testMap, testEmail);
			testMap.put('messageid', testEmailMsg.Id);
			testMap.put('caseid', testCase.Id);

			RoscoEmailUtility.emailResponseCaseContactRolesSync(testMap, testEmail);
			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_emailTanOwnerOption() {
		Map<String, String> rosco = new Map<String, String>();
		rosco.put('caseid', '500123');
		rosco.put('subject_original', 'roscotestcase');
		rosco.put('notifyTanOwnerOption', 'jason.johnson@tanium.com');
		rosco.put('owea_noreply', 'jason.johnson@tanium.com');

		String soql =
			'SELECT Email, Id ' +
			'FROM User ' +
			'WHERE IsActive = True ' +
			'AND (UserRole.Name LIKE \'%TAM%\' ' +
			'OR UserRole.Name LIKE \'%TSE%\' ' +
			'OR UserRole.Name LIKE \'%Executive%\') ' +
			'LIMIT 1';

		List<User> users = new List<User>();
		if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
			users = Database.query(soql);
			rosco.put('notifyTanOwnerOption', users[0].Email);
		}

		RoscoEmailUtility.emailTanOwnerOption(rosco);
	}

	@IsTest
	static void testEmailUtility_convertHTMLGetAttachmentBase64() {
		// Account
		Map<String, String> accSettings = new Map<String, String>();
		accSettings.put('Name', 'ROSCOTESTCASE');
		Account testAccount = GetTestAccount(accSettings);
		insert testAccount;

		// Contacts
		Map<String, String> contactSettings = new Map<String, String>();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@account.com');
		Contact testContact = GetTestContact(contactSettings);
		insert testContact;

		// Case
		Map<String, String> caseSettings = new Map<String, String>();
		caseSettings.put('ContactId', testContact.Id);
		caseSettings.put('AccountId', testAccount.Id);
		caseSettings.put('Subject', 'ROSCOTESTCASE');
		Case testCase = GetTestCase(caseSettings);
		insert testCase;

		Attachment attach = new Attachment();
		attach.Name = 'ROSCOTESTCASE';

		attach.Body = Blob.valueOf(
			'/9j/4AAQSkZJRgABAQEAAQABAAD/2wCEAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQICAQECAQEBAgICAgICAgICAQICAgICAgICAgIBAQEBAQEBAQEBAQIBAQECAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAv/CABEIAasC9gMBEQACEQEDEQH/xAA7AAEAAgIBBQEAAAAAAAAAAAAACgsICQcBAgMFBgQBAQAABgMBAAAAAAAAAAAAAAABBQYHCAkCAwQK/9oADAMBAAIQAxAAAACfwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD0vqleovLPW5i/c2wWedicvtnGNmenfDlgd47AaV5XhByBzqLfHN8/edu6vwAAAAAAAAABo7NNgP0kx0+xAAAAAAAAAAAAANSZoUAJapkEAAAAAAAAAAAADSvmVqz1T5Ta8w4t+eB+4bJzHvJaGlTOlT53rlwys9V2ZiFTbnPI5gAAAAAAAAAV5hA6B7YvcDnIAAAAAAAAAAAAAhQFbMAXYRs2AAAAAAAAAAAAOnFGr2P6K8VLp49gbPcZc+MicGcu4vNP6rAEYTf6s3r8g86iAAAAAAAAAArzCB0D2xe4HOQAAAAAAAAAAAABCgK2YAuwjZsAAAAAAAAAAAAINOOX+sfUbljrfRDZzjRnrkHgrl1GDkGrABGE3irN6fJHOpgAAAAAAAAAK8wgdA9sXuBzkAAAAAAAAAAAAAQoCtmALsI2bAAAAAAAAAAAAA/B2+TVjlBr4xeudYLs5QzPs3lF63F24sYOQasAEYTeKs3p8kc6mAAAAAAAAAArzCB0D2xe4HOQAAAAAAAAAAAABCgK2YAuwjZsAAAAAAAAAAeKPXjZcexnyE2poAIP29PqyXtxfj6KXTrV5L8Vowcg1YAIwm8VZvT5I51NxD1Ubj3025zA9N5vouUyAAAHQx5NXZ8gZgmxw94dQV5hA6B7YvcDnIAHCJqiPGbWTnY9KelAPsDyAA7TBM17HIxtQOYQAQoCtmALsI2bAHyJ4QD3J7sAAAAAHh5dUfXPnTRgffTENEAAg5Upe4UkrXNvKwdoC0UYOQasAEYTeKs3p4Q+SxcYGQ6r/AEXDwZBei4cuCotwnL/bWQAAwsK38i/nzZ0O4yKJYZPmMwyvMIHQPbF7gc5A4FK70iAHwQPuiYyZXEAgAvSjKQHaRkCv6NQB2g+9JVBYZGcAIUBWzAF2EbNgRhyqaPXAyoLiY2QAAAAAAxdubYCNFsh0TdOQAAAbZsUdjHK2FuS0YOn9WIDlCbvVW9KKdT+pXDnx2YA35zrYLvNm2eYAGOxTVGuUAAAsByfiV5hA6B7YvcDnI4CKgM1AAAA5qOFQC9UMpDtK+UgVHgAABlaW2huXIUBWzAF2EbNjUGU9pwqDkIt1TfCAAAAAAY43EshGO2U6F+nOAAAA29YkbKMocO8t4klN6f0Ij6vnNZvtVb1ob9NaWsd/PbkOUJBk52Kbs5rnL1ABAnK98GbZO1PvTUGRdzEwu5jPwrzCB0D2xe4HORWCkQEAH0R6g/IAAXqhlIRIyrnPGAfQHqj8gBm+XU5ESK2YAuwjnYpuzAsH7i0mJYgAAAAAAO1DSNmnql1g5MYDeDn1gAdYxyRtxfGRVr03ZfeyCsI2Ek1j6mZdiL7jl65Es52Q7fplmVDHpjSbjx0W4GaXrvdKyqHbZ95zn4AFUwRbgS4y0MP0g4+I5BJ4BXmEDoHti9wMeCkgPnzqZfFlsSJDgEhYkEg9SAXqhkGUiBguDKksryR2cAkE0hQGxMsLCVMQrytmALnsrTTRsDqWERPVAAAAAAAB0g49qGi/nffJAAP0cO7lWlrh+fr7usXQ4m66Q+gjMfuuc+HCXVQvrnm/c9HNXbXHmcwABWmkLkHU25knQkbG7096AV5hA6B7YvcCKIVmgPIXDxvWABW7EJAAvVDWIU850O8t4yQkAdhGWJGZ9yCFAVswBvXNFABMSLN4/QAAAAAAAdENWnTl7Gt8u1jjyFT9EZrfv0I8mRpGK/49weBXVkfuB9GD8kP1asP2OGKOJ13Ne+vTI30kjmAAH6/X0ZiZk2W2AbAsd+7lAADUAU6JxoAAZ7E9AmVnnK8wgdA9sXuBAxII4NhBd3nUAEEcrvwC9UIwxWSAzVLxg/WAAACFAVswAAN0xcSH1wAAAAAAAOBuNxa62V/T78VxnwRjYpTT5gI43l2kx5vJs1AmOe/RnuVttgpoG0BbDfXy71AAAd3KG5Xc1hNmDmJZkAAaTyu9NCB6gAAsFCfIV5hA6B7YvcCCCQNwZ2F4UdwAII5XfgF6oRlisUBl4XlZ7EAAAEKArZgD7I+NByMW7xvUAAAAAAABq66cu4Ict+ibqgOiNjbNflxhRS7fjrw68nAJBnq1oyOsUNV+mHS5m8AAABse2QYz7Otn+K6IAAdDEA0Smh0ifGIgMgy9JK/ggdA9sXuBF1KwMHUttCSGAdCtKIXoBeqGvEpujodS14JPx1B+Ih4kpgyDBCgK2YAsmSuKPmwZVFxMbKAAAAAAADjWFVV4Uq+nHgbjcUZ7d2ONgBMvmxgKS36Q9enTkyBIK9WtOWFS+mbQNoA2GfKUpOQAAP0ejq3fbxMEcksk7ZIgBhERZyZsffgEcUqQQewL3YgfEDoHti9wOMSkBPhQc+liKSPDHghjEMs/KAXqhkkUoRrWBzUWHBJUMdCCeRRDKknyk0AhlFbMAXYRGnK5Y6A2ZlxOZPAAAAAAA6IYkcL0R8fLsx+sjJZFPq1gc38rfwDJb9JGvTpyZAkFerWnL192kvhqzNaYKYG3+9BIZgAB+329OYWY1mMocorVIgAK+UgQmU5IlNmB6QigmtwGzoutCvWIHQPbF7gc5FcUQfAAdx2gAAvVDKMjMlT8evAO47QAbMS5xIexWzAF2EbMSr4IiYBvpLcs5EAAAAAAAAB0IBct+kfXp05MgSCvVrTla0Vpt4EsHcIciXFprna/NAd0QAAAA7ClpNUAAAB7gtbCToV5hA6B7YvcDnI43KlMj9gAAyhMXgC9UMpAQkyuLPTgAA2DFt8bNCFAVswBdhGzY40Kf00qAEsYtJT9oAAAAAAAB0IBct+kfXp05MgSCvVrTkW4g6t9OGmvNQd/LjsR2LY2bQto+KndEAAAAMdyGARUzVQfIg9sbnywkJD4IC5CAB7Qu6TmoHwpA8IWZigDKQmxHL5ArALs4yZANGJALI/h8YdTLMlzE9kyFBDdK7oAuRzZADB0qAzHYHUnck60AAAAAAAA6EAuW/SPr06cmQJBPq1pSLcQNXGnHTZmoB+z2dEjT6PNaXuJx4wAAAAAOITEc+HMtDJg7gDxnjAP0AAHzJggeIzvPqzxnjAPOdQADhUwrOQDN4+gAB4zxgHmO4A8J2gHU84AAAAAAAAIQ8v3/wCnfz5wgSifbqJ34WB1t6MNFOfPbCI+jqSVyKPou1s/t93SAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMJOu/kIeX/QFiv13g2T9uKs3yY/P5yrCjtVmqbLXAfAXIX2838e2LbPiFmpmxY7qAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADofid3GPGruWeVGd6A6Qh6Cnpl+2Yef2cx8yIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/8QAMhAAAAYABAQGAQQCAwEAAAAAAQIDBAUGAAcQIBESFTUTFDAyNEA2FhchIyIxJGCgM//aAAgBAQABCAP/AM/SihEiGUUeWY3ESMgn5IDccR9jTXMCTvSWnmsX/Xhe1Sqo/wCDW3PkjB5lhItpJHxm/wBa3XpjTzsyO/3thMfvbCYDOyFEQDDdYHCCDgv27dbmlQatXTv97YTH72wmP3thcRMgnLRjGTS+1ZXpjKFZE1rz0zlsZFSSdgxZLucKqnXUOqrpDSB458kr9fO/5EFqT3kxGdtj/uZ29mh9lL/Eq59ua49Sc8dat8pwGLYIhFbWg8WrYR+rnf8AIgtSe8mIztsf9zO3s0Pspf4lXPt2RibmK+T1q3y3GLb2vaz+I1+tnf8AIgtSe8mIztsf9zO3s0Pspf4lXPtmKU5RKZ5WSHMJ2f6bkMfpuRxCRTpguqovbe17WfxGv1s7/kQWpPeTEZ22P+5nb2aH2Uv8Srn11ZiORHlN16Lx16Lx16Lx16Lx16LwE7GGHhhNVJYvOli29r2s/iNdHL9mz+SWxw5jcuElUliAoj6L6Wi4wOaQXzJpaA8piZn0ow8MNbnVXggCCaqaxAUS1zv+RBak95MRnbY/a9ko+OJ4j9fMmltx5TIZk0tceUGUpHSRPEj8GUTT9/mW+PMt8eZb4/3/ACG19Z69GiJXx8zqUQeGG+YtMcjwIzkGMgTxGOzO3s0Pspf4lXNguEAHgPmW+PMt8eZb4Komp7PUEeAcRl5dR4oZFLe0eLslAUQYvCPm5FyW3te1n8RriwzXTUgRQUUUWOZRXEfJOY1YFUGLxJ+1Scpbp2fjK6yM9k7JmvOyxjoxaqyq5zKr6sJeUilPEjq/nHJtTERn4Wei59qDuLxnf8iC1J7yYjO2x+slJsYhoo9kLRm9JPTKNa84dOXipl3ejdy4aKlXa1TNx+0Okzsecrtu9jKy7acRxxHHEcQfZYfZbMzoivio0Zzl7s0+Jgdat3TlmoVZrXc3JuOEiMzBWKKsTUHUXpnb2aH2Uv8AEq5rmLeSVtmLBgdRRQxjn4jjiOIaJfz0ghGsKvWmVXjE2DX1JlUUY5wYvo1ZUfEdIYtva9rP4jXE+uK8q7EdaWsYSvW47ZaTaw0e6knlnsr6zySr53vyVh1OEnNnxnf8iC1J7yYjO2x+knJs4di4kX9vuD+1vzLLbjyDtRijHKawfZYfXMXMlQTrwVfEREeI7oeakYJ6m+jaZcWdtYeKTGdvZofZS/xKuaXK2NapFmcnkZB1KPF373Rq1cPnCLRrRKY3qkfxP6ssiLiPcEL6NWQHi5cYsTcXMU4AuqCJ3CySCaZATIQgS3cnuymNjFRduh251TJiJxsGnpX4CQskiSOjmOSkURIOor5KwJg/ok8l5ZADHjJWvzMIp4cmQhlDkTJV4csDAxsWGM7/AJEFqT3kxGdtj9M2LWaTk+htdhUlT+wQEv8ABtsH2WH0zTt5oVgEQx2FSVP7BAS/wbWuzryuSraTZxr9GUYNJFvnb2aH2Uv8SrmJ2bY1+OXkn9ksL6yyi0k90KUxzFIXLeiFgG5ZaS9eYg1CHM5Z8BD/AHuYRbl8cORq2TaIEQSEAEOAzlcXbKHcsv8AX+00lFTARKvV8zIfOPMS3cnusXBu5I5eDZuk0QTbo7c31DGtxijplFPxsRLvWsgAgIcQ0ctWzxIyDoMrYNCwMJpjpnf8iC1J7yYjO2x+LRLFg4GSkxVVOsoosrpBwcjYX6UdG1zKuAhyJqyCcexRLyJP63BSZBTe23KEUU1X1ZOQ6RzJqawfZYfCqpEElFlbJNK2CafyiukNDSE8/Sjo2t5UwUSmmrJpRzBAoERkK1AyhBTfXTKhSNSVk67iAqs3ZFvDjKvlTDw3huZQpSkKBSZ29mh9lXdt2FJg3ju83Fe1yQmJrlfQfD8KyTP0VGjVUeKnTmOOnMcdOY46cxx05jgGDIB4gAAAcA1UYMlh5lUWzdv/APDQ0awOYTn6VG4LGR5R5i8OH8BuzpjzpTMfI7IW82aCAqbOLzsN/iSXisx6nK8pSpqprEBRLXO/5EFqT3kxGdtj8Z0vhRgo9iXXL+rJVqDQA+zOaCZMnkfMNtYPssPjMqRGOp8qYmuXNWSrsGkqpsVysrzidcS67Zs3ZokbtdM7ezQ+ywXJeSg4SutNcs6GMwsSclQAAAAD6FgtLSE/pBxdZ5c/Ev6tsGP1bYMRCyjiLjl1nLlBmio5cyl/dqHMnFhb7ABubEJewXUI2lgEDAAhh/KJs/6ynmHxh446q/x1V/jqr/HVX+Oqv8BLPwHDKbBQQTc7rtWSWmEWZA8ZuWDlZo72xFnnYJQFI2pZtspM6TGfAQEOIYzv+RBak95MRnbY/GeCg+br6WtTaEfWWDaqbc8fiV7ZB9lh8Z0qiWvR6Wtcalez0Q2MAAUAKHoZ29mh99DrbazTqTN2ggi1RSbt/oSb0I9g6eC4cKul1XC2sF2WJxfZU6rskYnrRJU7xiqyWeL+WbKq4MYTmExvQhnIrthIfdbKLEWpPnXnctbNCicxTkOmYSKbcp7qqqYtZk8Z3/IgtSe8mIztsfjPBIfMV5fWsPSR1hhnqm3PH4le2QfZYfGdCInrjFYNIB2DGbinZiGA5SnL6GdvZofYs3WbiQF9GjtwwcovGlGuba1x4c/0LkBhr7zl2QxBTiIxM1r7/I7Mu+5PsTfHyQ8PRr3Hmcj6MhAQsqUSyEhlDU3fMLaTyUkkgMeJl4KWgV/LSukS8Uj5Ji9SQV8ZBFYM7/kQWpPeTEZ22PxnLHi5rrV6XXLe2pWGGSaONmcNiZST5jEM9YPssPjMSNNKVCXSJrljbUp2ITjXGpjFIUTGVzhim864YKRsrHS7crqN0zt7ND7H1KTtNCri7ZZJRBVRFbSFmHsDIISTCrWZlaYxN+19d42I8artVJKPXi3irNxpXYZWYkEksAAAAAFq7/I7Mu+5vcOEQcIqJCsidBQySm8AER4BFtBaNuBttjl04KFfyalVzeaOuRpY2zps8SKu01zUIwGovTO9CgJjFKEYUSRrAps7/kQWpPeTEZ22PxPxZJqGkIw7luq0cLtV9IyTexDxJ/H1zN+LdppoTyNqrbgnOlIX2pxxBMra823ckmoygRETCJjawfZYfBylUKYh7dBKV2efRxtI+ReRTtF8wrecEc5TIhYELXWnJOdKRv1TjCGMrcs0H0+RSPjMRM3KQbgHMZV832Tvw2liQXRcpJrt87ezQ+yl/iVcxmlRfNpqWOJ1qtne1aUTfNYeXZTkehJMPXloRhMpeG8c5duwMPlGeXanMAv2EczjEAbs8Wrv8jsy77m90dsUHgf2nr63H+voDrHQHWOgOsdAdY6A6wEA44/5M4pBoPPvznn+J2VeRxGzcvDqeLGR+cdoagBXiOeH8f8AIdZ3qco+SsVrmrQuCsppToc83Yo1kUAAoAUM7/kQWpPeTEZ22P0zcqRmzoLIy9OD7LD6Zl0/9RxnnGZimIYxD+hVK07tMsiwbsWTeOaN2LTO3s0Pspf4lXMf7/gczaL0R0aai9aJdHFUkAKo0dN3zZF21+nau/yOzLvub3Dlym1T8RXrbHHW2OEZJmuPKX1LqjMlsMi4m96aZ1TlTSy2pY1pgL1/jO/5EFqT3kxGdtj9HbRu/bLM3d5oryquzLI7l4h62jGcsvrB9lh9cxMtuo+LNwCiZ0jmTV3V2tSdmelZx9Wq7CrRxWbTGdvZofZS/wASrmjxo3ftlmbu71FxVJMyWzLa+GgXJYmTKYpylOX6Vq7/ACOzLvub3E58LZESRucrVb05KJjZhuZrJzuS6JxOtX5OhWqKEfMKoLoDwW0IQ6g8qcJl9Z5wxRSqGXUTWOV0ppnOzdunEJ5bo8tjo8tgkPK85MRoCEcwAdHLZu8QUbOrRk8ImUd1mRg5eJUMlIaR8JLSqhUo+p5QCU6b2z5xx6qjGuoMOjy2Ojy2Ojy2IUBLDxJTa2mgQdoAyys7lhZocTnRWbuG5uRfSPgpiUOCbCu5NulhI4sUZFR8M1IyjNM5mrl1ERBW3R5bHR5bHR5bFPIdKq19NTSwwDGyRi8Y+larNxL9ywV6PLY6PLY6PLYyys8q38OvTX0rV3+R2Zd9ze4nPhbCiJRAwJm5yEN6y0exc/IUqNZVHioWk1Mo8QbQsSz+Lt4BjgGOAblUUVy8iy9RrLkRMshUay3EDIpIIoF5ENOAY4BjgG9zHR7z+HR6XVVB4mQqtcbDxQTSSRLypbeAY4BjgG7gGOAY4BjgH07uyO2mlFtmXbIwefkDSiIrM1QDVJMyyhEilDlKBQ/6pOwqE2zFupJQsjFKim7xC1eRl1CmwyZoR7VJo3xIxBymMs1EBD+BTSUVNypxkZ5X+5b/AKsJSmDgYI9gU3OXYZJI/vKQpPb/AOjz/8QAVxAAAgEBAgcICwwHBQcFAAAAAQIDBAARBRIgITFBURATIkJSYXGRFDJAU1RVgaGxsrQjJDBiY3KSk7PB0dIVM0OClKKjNHODxNNEYHSgwsPhBmSE8PH/2gAIAQEACT8D/wCX6YIii9mOgC0Yxe+y6Tzqmry2lB+KUW6yCFzmEi/qyee/tN0b/UkXiFTdi7DI3FHns0cA5Mafe99kjqY9ebe5PIRm81mv5aHM6HYw7noqqq7MWVkNMYRi70VBxt8ccq2B8KfSpP8AVtgfCn0qT/VtgfCmc3dtSf6tgVE8McwB0gSIHAN2vP3ZS1FUtVO0CrTmMFSqGS874wzZrYHwp9Kk/wBW2B8KfSpP9W2B8KfSpP8AVsjxR19LDVJHJdjosyBwrYubGz91ngIA8nxmOgHmAyDe9PcAdZjbtfQbaY04I2ucy+ezFnkYszHWTun3J2CTrqMZOnpGnufvVX60W7yl9NvAaT7BO7PGUnszZHiag9nTuvlea7I8H/7i/jbXPHf58nSaeEn6te5u9VfrRbvKX028BpPsE7s8ZSezNkeJqD2dO6xetwSa7i8lujI8H/7iW7/H9+T4NB9mvc3eqv1ot3lL6beA0n2Cd2eMpPZmyPE1B7OndYDKwuIOcEHURaTe7/2Ul5UfNbZbefp23r6y2JivFiDFa/Pjqfut3+P78nwaD7Ne5u9VfrRbvKX028BpPsE7s8ZSezNkeJqD2dO56lL/AIl7+dRaf+nJ+W0/9OT8tp/6cn5bT/05Py2n/pyfltU3dKSAerZ1kXajAjzbnf4/vyfBoPs13KiOLmY8I9CDObVYHO0coHXiWkSRDoZGDDrHwWEKOjGn3xURxMehWa82w1E5+Rgqpf5lhu89sL4vzqSsu80FsO4OLNoWScQHqnxbSJLG3avGwdD0Mpz5Heqv1ot3lL6beA0n2CZNbS0abaieOK/5uO3C8lsNRSH5GGplH0lhu89sNRRn5aCpiH0mhutXUtYu2mnjlu+cEbg+XcdEv0YzBb+u08P1qfjaeH61PxtPD9an45eGMHwONMZqEaUf4cZLea2F8fnSlqyOveLYcp0Py8dRB/NLEB57VlNVpyqaeOYDpxGzZPjKT2ZsjxNQezpkTRAjMQZEvB67Tw/Wp+Np4frU/G08P1qfjaRHu04rBrur4XQM5sxSlU3XDNvt3Gfm5vgHI5S8VxsYW15mXkuNK27/AB/fk+DQfZra7suYcE6d6Tl3bdlnaR2N7O5LMT0ncc4t/ukRPAkGwi3auM41qw7ZTz35dQIkF+9x6Zp31Rwx8ZrOcD0JvA3k+/JF2vUfs+hLum0sk0jm9pJXaR2O1mY58jCFXRNff73nkjB+cgNz+UWgXCEGYGqgVYatRymQcCX+W1UlRHxl0SxHkyxnOh3O9VfrRbvKX028BpPsE3ahKaniF7O5uv8AiqOM3NYHB1LnXsxgGrJRtTGF1OP5ucWqJqmZ87SzyPLI3SzndnmppkzpLBI8Ui9Dobxb39SG5ezgAKuEcqW79ev83TaZZqeeWueKWM3q6mKl2WJ67E9dieu3ivB/skWRdhPCS3gxRt73gb5aUa+YZ7YRlhpjoo6MmmpwNjCM3zfvk5FRNTTL2ssErxOOhkNh+l6TMDK1yVyDaJBmm/ez/GtUrMLhvkR4M8LcmWM51O74yk9mbI8TUHs6bsgOGatCEuz9hRNm7IYd85A257O7u7FndmJZmY3szE6TfYnrsT12RpJ5258WNB28sh4sYFhjym56upI4dTPdwmPxOSNQ+F0lcT6Wb0fBdqUWUdIOKfWHVbv8f35Pg0H2S24j70vMqZsjtVMUq8xfGVvVXKbFgpYmkbax4qLtYm4Wc73eRS09/udPDfwUUbdp1/AY4jN1DTi8hHYXSTPdxruAP3tzvVX60W7yl9NvAaT7BNyUQ01Mhd21nkog40ha4Ac9iYaGJiKOiDcCJNTPy5jrPVmy5Wekpp5KiCNs+9STKqy4mxTiLm5sjxXg/wBki3ZsVFvirsIxnhO2h4KZhoXa2vVmsbyc5J0k5c7QzIc4B4Eq60lTjra6Gvpwq11JfnRjolj5ULaj5NzxlJ7M2R4moPZ03MWStnxo6Clv4Ust3bsO9LrPk12lM1RUOXkc8+obFGrdiaaoqHWOKNBezM2iwWXCtUqtW1HJ1imiOqJfOc/w3bYuMP3c/wAFouWFefjN/wBNhe0d0oHzNPmyM7yuqL0sbraERVHQout4RJ6cjRK0cSc+94xY9bjqymuE2NW1IGtUOJAp5sbGP7m7HjSMMeSRs0UEIIDSytqXOOm+2E6uea7hdjLHDGDzY4YsOq2EcIwttfeZh1Yq2whTVwF90coNNKfSvntg+opdjshMTfNlGY2Us8jKiKNLMxuUDnvtdj09OpnI41TJ7pUN9azeQbneqv1ot3lL6beA0n2CbknvHBre7YpzTVmu/aEGYeXJikb5qMfQLAg84uyvFeD/AGSLckxcIYRQ746nhU9J2rNzM2geXJjkf5qM3oFgQdhF2Q3Cia6aK/gVFOx91gk5iOogHVbG3mrhSZAwxWGMM6sNoN48lvGUnszZHiag9nSz4sUS8FOPNLxIoxrYmz9scWngB9zpqcHgQxj0nWTfugszEKqjOWY5gANZvtGDhepj4CMP7DC3FHyxHbbNHcCF4m4TxL20Z1lRxk9Fs2WhWLjzMLlA5uUbDgoPKTrY89s4OYi0ZlpmvYoud4Dr4PGj/wDp3EaRzoVFLE+QWHvi73KLTvIOkn5T0bnhEnp3UaKmv4c7i4XbEv7drDFjjXFH4nnytEeD6RU6CZWPnO7JHTfpSGGOmqpLljE0MjHeHc9oHx8x0XpdrFiCDoIzjdgiqIXFzRyoHU+RrFqeGln7IlwcRjwPIoJhMRP6oCTFN2ccHVu96q/Wi3eUvpt4DSfYJbtqembeued/c4V+sZbMXkldpHY6WdzjMes7sJlmk7Zjmihj40sz8VBaMYWrsxZ5x72RvkqfRdzm82o6VFGpYIwPVtgqimDazAgYdDKLwbM8oS93wXK2NJi6T2LKe3PxWznUdVlZHRirowxWVhmIIOg5HivB/skVmCRwxvLIx0KkalmY82KDYm6ombeEP7OmXgwR+SO7y37sBnqJc+xIox200z8SIbfvsgwtXZixlHvWNtkUOsc7Z+i1FSxqNCpBGB6tsF0cwOveUVxzq6C8GxkqaWO958HvwqiFBpenb9sg5J4XTuUbvGDdJVSe50sPO8za+YXnmtdhavFze6LdRwt8nCe3z626hZQqrmCqLgBsAGi3jKT2ZsiVYaenwFRSSyOblVVpkJsXjwZTErRU5zXjv8g743m0ZEHuh4eC6SVe0GqslU8fkDV22nR3DTwudrRqT13WpKf6pfwtSU/1S/hakp/ql/C1JT/VL+FqSn+qX8LUkF/90v4WFw2DRkUlO7bWiQnrutBFF/dxqvoG7R07MxvZjEpJO0m61DS/Up+FqKmBGveU/C2YZY9yqqLeC3ytO7HPz4sv8uRhGR6dbrqaq98QgDUofOg6CLYJB2zUUnn3qT8bYRFJK37KtXeDfsxjmtIksbaHjYOh6GU58jvVX60W7yl9NvAaT7BLH+3V+M42x0seP9o8WRGP0lXIlRXyXcNWYYyU1/JQG751+Su9TYTNRHVoouR5KcRMKj+8Ikubbi35HivB/skVjiyVapQJ/wDKbFl/ob7kRj9JYSRKirkI4aqwxoqYHUig/SOSHanmYSjBq+50+/aZGZlzlC3FF1oIqeCIYscUKLHGo5lXd8ZSezNkF4cH4OwdRRVeo1dZFCobG+QRhmGs59mRERgyB76aFx/bZUOm7XAD1nNYXAZgBoAGodwjsmtYXrApuWMamnbijm0m1StOupIY0uHlYEm2EJPox/lthCT6Mf5bNjyzUNLLI3Kd4UZj1m0ixQxLjO7aAPvNolp4ReBNMoeZ+fF7VB12r2PMY4ivViWRIi5xVq4s0d50b8h7XpHVY3g5wRoI3Bvs3J4qfPP3WlxOZVF1pz1L+Fpz1L+Fpz1L+Fpz1L+Fpz1L+Fpr+lV/CwCMcwkHaH5w4uXirWRe70Mh4s6DtSeSwzeW0LwVEDmOWJxcysMrCNRABpix8eB+Z4XzEWRMHVjkJHWJ/YZmOYCTGPvZutecWN4OcEaCNzvVX60W7yl9NvAaT7BLdqtPXyeV5KZT5kG6L45cJUuONN6JIJGB5rkyvCMIfZ0uR4rwf7JFbRJhNWP+HBLd6+7nWWvpgw2qJAxHULaAAB0D4HxlJ7M2XUxwU0S9kTRY2LPVqhHuEHOeMdS2jWGCFFjiiQYqIii5VUDVd3D+wiZgNr6EH0iLMXlmcu7HacjxbRezx2b3GnUSSgceZtF/QvpyGxpKErvZOk08l+KPIykdVtKjg/OOixvZjeTzn4E3vAQt+1T2voPVlr2LhBVuir4QMfmWYftU89qU4RpRonogZDi/Hh7ZT12Ro3GlXUqw6QdGVKZLlvwZNIb2uXTSMTpF3adF253qr9aLd5S+m3gNJ9glu1MOEIvKr0r/APX5t03RwYRpWkOyMyhZG+gxyvCMIfZ0uR4rwf7JFbRDhNA3MJYJc/Wvn3cywV1O7HYu+AMeom2hlDDoIvHwPjKT2ZsiNojJDFUR4wux4Z0EkUi7UKndlaCpp5FkilQ3MrrosUiwrTKq1tPoxtXZEQ70fMc3cOrey3zccX5OlKCkU9IgS3ffuGR4D6J4vxty1v8AgtF0XXe/wOC6Kq55YIy46HuvU2Fbg1zo7GqMeMf4dSr5vKLYVpqwDRDVRtSSnmDqXUnpxbUUtLJxSwvjkG2ORczjoO62K9NVQyg/NcX+a+2iWKOQfvqG++3eqv1ot3lL6beA0n2CWF5wfXoX5oqlTCfJvm9ZEg/SuDY0gqFJ4U8SDFiqV23qAG+ML9eSwmOCjUPVTqb0E84iXsddpUR8Lna7UcjxXg/2SKy40tPCK6MDTfSNvr3c+8iTIkH6VwZGsTqx4VRTLwYqhOVmuD8/SMghVUXsxzAAaSTstSvJgqNxEmEqdsd98XNI7QceDG0Ypv5jarhq4G48Tg3czrpRuY7vjKT2ZshVTDFFgOiNLJo7Ij7HRmpJDsPF2NzE2Ro5YnKSRuLmR1NxUjbfuyYk8DX3cSVONFINaEWOLILkq6Ynh0093CQ/F2HWO4O0njaM814zHrspDRtwTqkTiuu1SN1T2NEyyVUmoRg34l/KbRbMBcB0C3fvuGR4D/mIbcdbvLqPXYXMp/8Aw9HwGcnQLfrJDjvzbB1ZV3veBt6B40zcGJfpkWUUc5OKtdGCaZ8+bfUGeLpzi08NTC4vWWGRZEP7ynICb6rw9hE3Y/ZBkGaP/Dx793SzADpJtpWipQekQpbvVX60W7yl9NvAaT7BLf7XTSRrzSXXxt0hwLLiTU8rwyKdToxU+jdnanqYTerrr2qw4yHZZDg+quANTGpkpZDyjdni89sO4LK/GrYIz9GVwRbDNLMR+zpG7Kdujerx57RvQUzgq9W/9rkX4l36keexJJN5Jzkk6zkeK8H+yRWGMjqVZToKsLiD5LKRCsplpGPHpJSWhI23DgnnTdnenqYGxkkQ3dKnlKdYtGaKpAANVEpemkPKZRni89sO4LK/HrIYm+jKwNsL007D9lRt2U7cw3rN57K+D8GNwZDje+qldjsP1acw3KyWlkGkI3ucnNJHocWjFFOblFdECaZjovlTTF5xaWOeGVceOWJg8bqdasukW8ZSezNkeJqD2dLQ++YlxsI08Y/XRLpqVUaXUdtzZ8gl4WuSspSeBUwX51OxxxTqNpRJBOt/xo340Ug4sgOnuCPhL+qnTgzRfNbZzHNaugdNW/q8bAc+IGvtXJia0pVJY/4kgGL1WhEUY062c8p24zbnfvuGR4D/AJiHcHCHayL2w/EWmjI+PjKfMDaSDrf8lpIOt/yWkg63/JaSDrf8lpIOt/yWlhA5sc/9NvdZeW3F+aurLfMvv2tA2m9aeM/zN1bmEKqib5GVgjfPj7Vx0i0eD8JKONLC0E306dwv8lv/AE/n+Rrs389PbAKq+pqmsLKP3Iohf12qMZI795pYRvdNBfyI787c5JPPurenZCTTnUsEJ3xyeq2gAAdAt3qr9aLd5S+m3gNJ9gm5F73qiEwgFH6qo0LMfisPOPhPFeD/AGSLcS/CuDlZ4rhwqiDTJT85zXrziwKspKspzEEaQR8CGWC8PW1N1601MDw2+edCjWTaPeqaliSGFNiILs+1tu0m3jKT2ZsjxNQezpbODaI/oqrkvnhUZqCoc3kC7RTMe15J4Oi7ILSYJqmUVlPpxNQqIhqkHnFpVmp50WSKRDerK2cdyd++4ZHgP+Yhtfi33ZhfYyfQ/wDNjJ9D/wA2mAbY/B9PwtLLTVFVUSSRh88RgvxYRBLokjEQUZtmf4BGkkkYIiIpZ3ZjcFVRpN9kH6Xr0UyLp7Eg7Zae/vnL58253qr9aLd5S+m3gNJ9gm5Es1PURtHLG+cMrWV6jA07+9qq68w3/wCz1N3avsPG6cuMxUtfPNDSY2Zpux1RpJVHer5AAdZvyPFeD/ZIt2ICtzvWUK8EVW2SDZPzcbpsjRyIxV0dSrow0qynQcuElQR2RUsDvFMnKkfbsGk2GPK1zVVUw90qJdp2LsGrc8ZSezNkeJqD2dNyNZqeojaOWNheCrWDPg6pLSUNRqKX54XPfV/85EhOB6p7kkbP2BMx7cfIE9sNWmxDKwDKym9WU5wQRpF3cffvuGR4D/mIbd8X78hrw2aJjpB5BOz4SjgrIDxZkDFTyo20xvzi42r960kUddeyfNjqFF/RjD962CZ5Ix+2ph2RH1x2hliPykbJ6w3UZ22IpY9QtQPS07aaqsBgiA2gNnfyC12EMK3f2uVeBBtFLGe0+d23Ru009RixVeNvMTyYt7RXX4ozWwbXfw035bYNrv4ab8tsG13bL/s0235thcRRUoIOkEQJeDuwx1FPMpSSGVQ8bqdRU2lFxvY4NqGuxdd1POdXM3XbB9VTMvfImxekPdcRu4Pqqpm0b3ExXpL3XAWdSFudcGQteGOm6qlHF+KvXajd44Ja1RFSwkrEm9UwQYsY4C5s3RbBtd/DTfltg2u/hpvy2wbXfw035bAqy4MoFZTmIIpYgQRqORH2FhG7g19MoDtsFQmidenPz2p/0pSi+6ai4TYu14TwltDLCw1Sxsh/mG7g6rqSeRC+L5WIuutU9jQ5j2FSsGqH+LJNoiHReei1JFSU8fEiW7GOt5H0yybS153YJp2XCEhYQxtIQOx2znFGYWwbXfw035bYNrv4ab8tsG138NN+WysjpgihV0YYrKwp0vDA6DurwZBfDMADJTTge5zxc4OnaCRagqZWgcqJYYZJIpk4ksbBe1K2wbXfw035bYNrv4ab8tsG138NN+W1LXbz2uDquWCb3L/20rlf1fJ2aO4+/fcMjwH/ADENu+L9+RpBBHSLcZVbrF/w1HSzf3sEb+lbYDwcx/4dR6LYBwf9TfbBtFBzpTxg9eLlAWAsBlRRyryZEVx1MLYEwe5OvsdR6tsCYPUjXvCn1rRRwryYkVB1KN0CwFgMuipai/vsEbnrK2wFg+/+5A9FsC4PQ/8ADofWFo0jXkxqqDqUZQFgLAZQFgLAWHcY9zq1WVG57sVx03jIFyuEpYjyrjvkt39O2leGP3dPmyNLsF67cUAdX+6vAlThU8115jk59qHWLU7hb+DOoLQSDasg9Gncieno7+HUyqVBXZED+sbzWXFihXFG07WO1idxcZDnaMdsh14o1rYEHnsjOx1KL7XGYjMNUY/N/uuAwOkEXjqNqKkV+UKeEN14mTGjfORT6RZVX5oA9H/Me//EACwQAQABAwMDAwUAAgMBAAAAAAERACExQVFhIHGBEJGhMECx8PHB0VBg4aD/2gAIAQEAAT8y/wDn6QAJmAZVqyzKRLwls/QVPJ5/D4CkECLM6wG67lO1CNy44fTbRBAP+Hi62i9KXRoWDmY0cTzGGfvT5UUhsQeX/wA4ft2PZohCZRjEbes2aeZA7pisHEl9PSQDPb7yyO+ldOWQt0TZu1VZeNv1MBfDH3cJGAXdbz5D0Tne4yM37oh4KVd0TcF957U1xjJUS+oAZMzCldyHai9zX7n/APutv/Oc6hfW2MTwR8dCb6zKOSF+XvTgMF5F/SjqVDdUX3+5/wD7rb/znOoXnRSAZFn5Fu5z0r4/2t995/8A91t/5znULoPAeAIUZIoAN5vFmDlOCPennc/+yuD2v9VoOT72vaHWP9rffef/APdbf+X51C6gKoBdWwHNJVjZB86PmubQ5tTm1ObU5tQpBLX3xhRlf/EV1n0x/tbr8z5fSS1t5AeKjxywe4ew71lQOx8n0rJSgFG53hGkQXoB4lqe5mT3JFZd4AfBQpUSPu7APPX/AP3W3q52fwpGRmAPuUxCdPn20NqLHySMPNWsfLAbiQfAekR4wpmJ36Hbt2IBBEkS4jcR1OqfCsjhkSDS3+EzY3kJ8UYYdBjhojDf8wMX0+8fVqF0yYQIFkRtZ6Hbt3OeYOYmdvqgiQCjgC6tPLFNU1ChmeMNW/0FqIl13mtPxVqvuWZfuGsf7W6rNnqRJAxLWZ44tLsuDshFunpbhCQ3+7jDkpw/hrcNLrHZwC0kgXb2MrVr9StNCJmcDfU3AiDamX36DhrlD7XcIVpza4IsNjYXek0wI2ZJ+aJ0/wD91t6OaDrg5NMp9BdqYAdC3jRBhB1C08jJWmbuvq+s5KHE+5U/CDxwQkC1YNU1ldaxGCP4aV/eV/eV/edKEEY5M7nWO/2Ux7WXrJHLT3doqVzfv6vWmUn4dKjeDwjZCmxlTU+0hHNDXDo/SqF3dfMIhXlZOUghU+DLYxS6VW6tf3lf3lR32TPy5zV7ZaIwC4kuWQNvkF+qskGDtOX5fSmhsJoT7yUsf7W6vFO1IR0MToU5eHx7/wCPqEjfAAjL0c70FLDq+GPGovoETy+ouwRSdJ9P/wDdbfXmxg7Z8e7kTsvTYYPXvZS77xAdbvQWhM64ruEy6lOLtaJXhicFeDuhNRROQoSi6q5Z6zS6mLzZFNHxVytBt7IuodhFXPoVC76gQDyAJx7WQpPF8zdWPSWGgerluvNoAGm7gCW1D4RxHE1EM7UtPrHNIj7rx5gfpSWQ0N02+0e+ueMcRY+a+OgAINcCXYmfFfAckT8HT4CqcciVuRPPqSXKdpQ6rzvUM53jCjJI1QCppb3Aw+UHwpORS0Ad/wDeoaQKHHAKyUdQBjlyk+9R9mjkMVqmHmj92G374hHB0/8A91t9eftZ2aHDOdx6Q0g5kGN5oe4KZez9BTrv/l5FGfPFKlW7dbq5Xd6L7SQPclJez0KWhyAIgans6JvS/wAu2O8OJp7OqoXBi1Ek4Zb/ABxdtSKrziUcQDOZy9QBnCqQdkRBR31JzBG9jOaO77BHCokuuD8F+zCiAo0SH56wyTXDVr/ZPNQbIk/7cTSAACi4jZE2imIePlJRC+wkxjco2BHZIpOMw4WwFEDjWCAuzUW6XDcAEruvwixrUYkh333EyvfqTu3G3yJeqLhcghtxJpENM0AjBKBB1EyertkAuSGxtVxLgOwiZNuIR1P/AO62+nNTAgT/ALoQVc4EshTyp6qQCZwThLby4BaIhzc8pNYcYTTFFQtAeG1qF6aHYMncoaFPExQnJBMd4KOJcmly8CXOlTamEEsZsR4q9UkFmotoJ7pa+t/dTXBMWKkrcCUDBi68Zq3E7izGFFU+AcbWoTmY8aA5Q0E3lMcnM3y2BhxERRslkcjtQ4+RozkSGG+6UklbSEb7ybvElBjOBB2LAOmpNY54aHnY1aXQ/jcw+bXw6DG2BcDcDRmLLrj7J/RZyLupkyZMmQ4EXHDQEILAQDYDHRNQstPfLQ0SeZN7t71bx5lbKLn0AB8ChKVAAACACANgOsjuyhYhq3FHd0QowcpUWWhOKDoSRE7rD2FVkKiRI0X99ZopUSbO7B1v/wC62+nOHo3Jnkck7x6gqBdbAZVoEROCwxoPRrJt0g7C+gwjC/AZT0qZOJwYYEjuB59QVgutgMrUa5Sd2IuI1RdI9UmzcbI4asw07HdDJtw3obzQo7QYD/OvXUu2BzHffARPHQGyZwGcrD3dLlQJhgAAQAYI+xBLH6od1tB4i9NJ2s4tD3wfXr1R4scCu4arNKRYtYfkbAXVgpkQBhYi14V3OlHrCzPHG1QkyCM1AUxXiNRmgDGEJQSImSPRbCdUSYQ14X7UmAGh49xeowYMGDBhnwQNE74WdNky5xWb9U5o6SpGmnOiJjRsYbOTZ1OpgQSqJbIW21IFBCNWAd1VZ2SgRgCEouImSOn/APutvpzboze1HqsLSXApWqYeH6YpSUJ+Gefd7epFi7YQry0ZsCWwQHt9hUkTjl44/wDITJeIMrNMOxEB9jFyytjIOKDJwZlXn224Onk10RawZ5xiOV0Mfnrm8Jc+JNOET7D5/immMOuqSv0Z8AKyNW82Otc5YWtNvn3s0dKZqKxyYQwNij4ph7dhiupOIq2FnEq/Zsx0/wD91t9OZ7m6dA55ReojD7sDmOwnxWb/AEhSkoFgrAEXhPU2VPSqL5LqaiT2fq1C2yj8ENdE/I+s0uTRJRuaI2RRs1CwsW4BJN101pafY3c3Rtn5CdI7QebDpxSWRnHwRHQmK8Mk0kQ97vegtMP2X+kOCXH/AIJ+jLieKkT58Eayqwppz4idyr6hP/LCanapyNMUBaee/PVXgAsILxqL4gkb0P8A+62+nNq6SCZWrpJ0DGLdZ08y9kUsD0lsOXbIdfrBq+kUqGAtKEY1gTeY6BZhm6+2RxRlt0SDwMg6UMQrNqMpCw5CxJoB7oin2QagJr11IKxtIGsdpXrbBXOzBgVYA9VtkSLI8zY++aC0YFSCDq86x9h+Hc1DyQfFPJZZZqz/ANCM+oMsALa8Ch3XSiaggMAQBxHVEZgrSW2XwKbxFJuaG6PoAiUAF1XAFABiJ7ojx/JepVgt0Gh7rYcVm+IcNSJw8FD9IK92UT0aDb3byN72BoX9b5INwA+WrQxHwT89H/8AdbfTmUpCh4q5KdqdgBSEI30n1S6IjYdnJZVmjzSxihDNnsKKMhOJ8+ZCsCotarcbqKab5pJshcIbLyp6DllBKjlnpUidA5Kg7UU+9C8h6zYtUnIepVGS5wdFZLJmsOzi6slPAKIOBOCRNy1uKMCbAlbsp9zUkNeCTnXzavoh6BYgNd7kq4QiDoAJ5E8FA2JhuzydrqqB7pCrjBYlk7hs6GyA8mKnKcvAtBqfkRgi9iHksn2AeaTJFObbO8FbVdJ9nb4y9qhdBtm7HyzV89sOVfdufoRGQ+EogHn+BonDcPI6g2bNmzbzyJvsj80EuDAgfqXu9eKZGeAvaLu19DWrvaRZ4TFBFIFLjvruqsO5fgFCiSTgksqV+ke9CNVynL6xl36k2WxMKhtIj5ozYMtggPY6P/7rb682DNhcBDGBAv5vrKYEIVwOd/FGtGBeFXQhhEfoncR2IErhKdEtJQPwa7QlqXVqHqqF0AgARG4jZE1KSaGmTQUXqdCPQZYe2fkMbxtbUIKagaQT9PuYjJNmHOS4tPrLKMULBLXYbF8/UcUFnKEqHMyy4B+gFylyQVl0AF2jKFhCeOSMMNEMS9H/APdbfXmdhzodCcOo5EkpEGEE24UWpjGDkda0xcpVqL7CCFjrU2E0hcG58Q5tNG5Pknk4Iibket6WABreNFk+EKtp2wQLvo30h9CoXHyBIZDnDs6JVuhRLdNAlBNSNXQC3KjDg/8AbSOogD+QRLPKhEzP3kRlgor450SMrT2+p/ja7RXaKG9MsbZS1tYcnmkyktkoa34pQRMIkO1j1lo2GXw0wqjcggeJGt3xhnTNt5KUbGPV9OnQFCN5WfWLF/lClUXHUgBA4Z9bI+BeCLDRhrbridvtvm+lh4ijcaDuE+rMDCHJ1HcJpXCRZECxO7Jh0UVqWPxsWBgt0IsWKfUAVeEwIz0YQLhPNL8IdKjRSp0fF2YzZOWlS2hJnaA9V9mAxM6wjyo/V5Mlmwd5/lKGx1gLXK81Sb+sCdOk6BrnRFixXFszGl1A6epEZLk9IdZZrmzTlhn1uzTCdzDc6IsWqYW0n7LS3X2I+4iM/b46Cmw5bJI+9fwXP/L6xSSufyTVNgLz/pauoOR+TUXMGB35qxY6EHIPiv4BX8Ar+AdShTzdPkVkI1J/ArDx6X33VFjbFj+F6IOQe9fwCv4BX8A6xHVD8yVT50ypeeVHi/CfnlQj/FieAdKDknvX8Ar+AV/AOmByD4r+AV/AK/gFcD2Ps0Ctuibls+boDQUg3RuBh3GgLkgt8vydBmyY8rvYJ9qHBBewA/H/AFV0JyWwtHGPIXKPSkaWgSPKBqVDiH2pBQR1hF3g2s1aMcSOprdwV5qJs01Sfmx/4LJ2pdEMgRO40Ox4T+GCtsEO6Mk67v8Aq7LHpm75KvICb8bxlUR0X2nECg3YX2H/ANHv/8QAKxABAAEDAwMEAwACAwEAAAAAAREAITEgQVEQYXEwgaHwQJHBYLGg0fHh/9oACAEBAAE/If8Aj9F/veflD64qNEJgDaAdtSs3xVZ1xUmHBoeEaS959eB1XByrtABAAgyI4R3Ohk1w/RmZNg2AsSd25rLDExltPFZtwJgSW7sbXeGaYsEWscoFDwFC4/jzFrAOX1TIF09alQTEUsQkF4XpiBrJXlMKQUmx/MTrR/qO42ElnRUqdFGmeFHYMSpFn8tDhnih2bYGG1zY0NCu4wG3cvxRASrxPfUkPZUtR8WVh22OAjbrOrCQJHTlkd5u0gFwAjyNx/xU/Zv18hOaV/UvbZohZRVsR/MFJn4GuGx+zSupDM+XJT/ip+zfr5M8KWNmJiI3YJ0Pk/8AG6aiP2b9fJjActOIOmRo52rpjkTYhKBUINgQfaXpKMsJ5BqC2U/xaaiP2b9fIKZpAAlVOCCnR8waTIj3UuWLFiwdUsCUF3cfdasKWJi5KeBh7ejNREYGGvtBTJGhk1AG8sLvQKFQk9g8UT2z29LfNEM4grms3mYVPZli/wDFS+MYflYj5VB3q2VxvnadGv2Y0RkZri9U/Zv+ZDmukPYLtTJIh7uIsPHhNQdxDa9wb7c4qLrlzZD3RjoYyUiNUEMZAkxzoAgQJwHPg6AWQSE50zBLbzULkP65F62VKZyAPKiITtZHeoFS3gOyX4d6DROmByRhbabt6tfIg/4iN3hhEbmgCBA7Vt+1i3d/VDYyKB1BwANHWhzwhEwO0sOGuY6gId4JjfORWHjv5jDxVE5B1zcSgTycAseQmSBCi7UcyArC9tgsW6F5qRBXh80JJccjkSJE9kwY7l8OuEdR6SgThtZYRTWMlu9EoeRShOls8z+LubUvWaIOVJvsYlWlRkqQZpzwh0W5H4m+1Wfm9sKHPMRBwvon7N93tBARc+ZBVHFbjtNQvJpAclAYidbBZXzLBMG3Xu1Aif3KRcWaQlyuZCGc7ZJJRDybuFrN4VdCINfZP7X2T+19k/uiQoXbBdWjCABgEI4cjEQ7yJmYqGRAJclAWpRKVypfnqVfRizI3zHPmi6bYScBRsN+VXYpVepWhSLGKUPSr5ECZvmxwIPCJValUyLIXT7KCstfZP7X2T+0ZqauOHEtPZhYKERHoKC8yqbAch9RiBHZB4/D7+kJg8HU451p2oGi22QBG2F8s6DYGS2Ipxce7nVsD1MWyuITftoM8vxazkZWYquPQZtOVG45LzDuegfs34usToMoFoTCmJBM3IpoDIBwCzCAa0XN4zHgSrZyVnTgUCgASqwAXVXBFGcRmODl1voMlSgj4jGXpdKrdnWynNAWUpewhaZg3q1bgjCAKUMWA/Qq+RkZU3DK4b0XBiK4+pXZUcKGwDqdvKocotdKXRALQINVmCBOwonbQ9VQkTyUZg8LSQo2RRO5n0Qp1LGMnbn7VFpGMJTsXJoqxETCcsBtJcCa+hc6uzX1nPQgdLRDyzguS1W8wQ2GTdB6irCRSKAsAYJq1AphLJLNBsCaJ5bLatkVSdq5cMCIStasetgEwIFG2famxAYN98FjdpDLGkF+O41bx9vQP2b6BmH3vdwhLA7OlwSkj4ZSoKhI3/U7PoYHKizCRAplrmAYpFVQoSi6jlnQFDImQIMstauWjAvsjoHbR4MSeypbQFR6peVwaJ20mchHVXyZT8u9vWSOJog0jypgf3mCwTdsB0Nnj9mDUQC6sFOQswnpZYQXsWfXIIiSJCNxHInFTZGTagaVZYlwN1GTyRUSbJg6s0P5ngiEMeJ8zArMCoymUmRV/wCqBeEMOkmUmlHfPc+VidGxAVPIFZQhMiJaiWbYRsIlb0ViaW2SZFLAwUmV6fXc+l3FJVQiHbWEpYuklUJcY8wu7d0buonpvAiGU/p9W1h3ERiX1UaoHoYXEksSER1WXJ/cC0GWS9OwOUm3PijaBunWfs35VYPgKCeHPNM9G2UIuUnv1EGCIXXgNSuSHIU1Nr0K5u5S3TKHh3+5lhqyqTDpR2VkAjURILAcDgbqCHgkjkirh4tCEiX04EMEPwgwqdqYhCaPU9jYIb1KzBuA9vPFvA6uIp42wEaLeWxkQssyAkEDDAUp17VhoBLmwEb1bIBstSQgEvmvAiqQEAwocM0t9li4sZLzk/VrW6wmbpGsinYFWMmX+AwE2DTXEW5Zmk5gQF0Au1FALwK32IQucsh6/wC9qNESiA7auUyDYD+E3zwqa5WQtSBAgQIHjbClXJNRieCCsBQNDtyKtDlSS80uGylMmQRHv1v7yDxyA7u9ObK0mZHJNC4iHGEFgCNcjsnHEWkMcaLMY9QCLOiAZQOCGR42xfROx0BNEXI5bJapE6F6hAyhMLn0T9m3bQ0EKFGz5AdQSUgCoQAGWahIVLGUE4kEnw0fsGdN2sDB17dGBwOBV6TMs7dYIFAAqGAAyzWQBnhByB0mJmjRAEACBINkRyRV0H4ZYl5xAOIxQLkzKgRi12JV0t9deRUEoSwd0Bs48PWU2EtIA+CUBIUPln5QZQYACwH4NvmpVraKjGQJiuy4pnVOwPus9S5cLIJlqSBZYC9RGBJYQAFUBkwFaB1EVkh8RcZjkMifkkXUypR+Pas83EAgEAS8QmhkJvEVnkUnPRYCEpiBNwcy4LqIV2VbEHEse7q+/fv37Yzn9bkazfnBRsIMjsXwoQAREkTCOE7alDhFxAeF5ftB2pK2QsZo3YkLIIxqJzEZxky9DNuyNLHksiJEbkKXKTEfAIy9CIhM6z9m2+liKbLsw8rv1vKgFpNvZlkn0ymBjxFTAwuQS3/jr+oe5QUIPeiAHjgI3gH4Fd2xu93HyEbaFaoWaXUMRBA/+/glPuBEeaTe00xvNj3CXAIBgALGlgyT3IzimLA4RxoPZGiQLib8bGogYmi4f3100X9GckIXuvoukZBLU7ka3dITRuxYKEYu3SWv6QjCrRcB3pXsirbMvCbJqDjGloc5FZlQhhNR+zfjMnuxQeINzPjrwuhD9ZOHaogAyJIlxHCO56RTBDPHHgMT3bqlZw0ALxcAx8UBR5QhyJkQ9WvL1sUzNtJvDcwDotDDp20Z4ZY5qFRLAPAhPC5RO0JP4F1TPGOlBjSVUK8Qo4bpKlyQROwYdg0GOws25MG4IfOlvgrOZ9rp6Vlm+vIoeYegb25o4WYnlgwAYGbNXMT4LJJpZV4FA1BNWC7MoFLlaKZCEnHAjZ7jqjB3QEJ2MT5qDezWLedo1T9m3OUMO7yQX20GpD3HT7yVVkDoxUyLitIJkbbADE0YIBXCLYCUOF0N2i0DUcIpyVGlLFM6sE/mibYIKrYCnpzcRBngMXQicKUINpUF3DQkrAddfBEvQ8KZweJRB6S5JN5YD1WImmCApxjcTCwp49EGialE4YkvP4B8y9RLKA7f71kNOhSZ5aBEwyoCdbwHQS0GFwOYwaCvFdAgzYADxXyeh+fothn4T/JBUi8jC28+BR7+gYs6VZAGVa84wgGT2r6g8Uyi/gP7lCogGCUolaEkjYuXNEjUmlJ5MEyYSdFlF3x14q4hkFjqK0I2UT/RQzdmQf8A0dR+zfUUJab7ikJs0fPMSCkG4R3Eeoc5OT5dAQGjA01POEoZSLe4VDAEgWU+2Jo812pHkCYWV+KNsAUSvBXdBmwzSKXZnFKXSq3V04BqbyXyMLJxRJgCBZzuKOvZnckcbHbTXQKJ9jzkKdyScDBUMgWFXLHMMyYimroGmFEBURaXzW8bEXlDg+VkMP0mCFonM34zJNkqdAmH4GrW4w4F6yxTxybpDdZEyaq7TexUnbkJQCd8VNurqTiILiBMN4FTNMTJBi9yO0jH10J2KC8oRkLNrzBERw+IoIc5LuCmSJAcmYkle9uri6j/ALOOFbABbp8nofn+gRa1d32sz85xDemN3YJOwi++qzZs2bLQb6T2JdHnFXAnMEi7ngTXw9mlvBXshYjpBIhEiBvP8G1WlIJvk3iJlXN+Rt6YRL3oLxv70LWgpW1mbU5sqcdB5swOkAZEMLdW/QKim+EIcsaJAWeCjdgNZ+zfnQGXOCvHiLsQnQMYt6OCHwe0iQBNhwoLOU40LXHsmiOI0e8aVGjYl9lmrtsYNS/YoGAWG9F7pbuqvkPwB4PkFkFE71vHS7GHBTZUINEGFjFqLW3Udy70EYstOkZhhMoRv+J8nofn6MsheT9haz1KKYlouVj2UXVJ97+nISEsMGJdidqSI8GOCQhyjcZ6CLUmRHY8AowFQjIWpOHNagFkfoB+zfIdRVXcOGwrIghT1j1w2gpSoPRNdsNar2DZwbesrqwKxO5JOK3xxm4tqk12mAnMoARL64fcJc9tMAZSMiB8g42iATLEsjlV118jnbBDbQszIXAlCzaGwCI3mlK2he7hLWQyMAM4dqjgzaQ1iqAQBLfh/J6H5+jB97dcwyNMGaXRtwcKeHuPUIMbDgiEMkOzijgtXqe56BEkmu1BZhwWLRO0k0sOxZLCi6nqK+LCI1f1UptJAb8gborYUg9EXMopOyCrrFGYrgyACCcx1q1RskCLiCer9oqXsRGERuJ1HEksdXwXtuMIiTT2DSyMhxNZwFiyUJFxhyu54SCCX6pO7pa2EHyqAE0Iz4bnyROdrJTw7kv/ADsIBCDDoq1ao2rAjasigbiQ6DKXE4YsgWJQrEWofRlHSwjgw4YK9O7icLnLuqKfvuDWFdWEXojGTjjJGxJDGwSsiuVjSRKIPuqgB1Wi9VwXpHEtp0VatUZrxoHsGooES/V/bbKAO4yUGAlLXL4oEI6ZMqmIaKtUKSfMuZXlOlRN4n4Xyeg+fowaNXsWeQzdwFeF39axICTJ1cqtNLnYpTFywKe2NwXGxlkK2M74rJj+6AAAAQAQAYAMGjZA5D/uvuX8r7l/K+5fzURH0XplJnxUyKt10VIpc4ry4f6ygG/ah4+AjMLVbx02AMQH/dfcv5X3L+V96/msXPKbSc30vemE5F1hF4Nqg7bKlt97RCJgKwQBjHbThCHAf919y/lfcv5X3L+UEWIDgtob5TlC/JX3L+V9y/lfcv5Uf1vj8M2KHDGv0RcB30NTAQCnTZZjYbU34qSWWA7y/So+OrEIWkxAL5J7U+6krW3+Kj5meWDGSBJEkIA1Lr4ULn+Q5dbodgzwJf1V+AkohLisEM07SatlBut2Fa60QEJGRHCOzzan4uUliVmnZh4HBCKw6xkBI0ghIUr2lRHcYKtDRIBGwbMZFjBu/wCLmdaA74Ig81/qPh2aXvQAAABABABYA2NCEr5Z/bV/4THJH/I9/8QAVBEAAQIDAwQKDAYPCQAAAAAAAQIDAAQFBhExBxIhQRATFyAyUVVgYXEWIjNSYoGRkpOh0dIwVnKjsdMIFBU2QlNUY3SCoMHCw+IjJTVDc6Ky4fH/2gAIAQIBAT8B/Z+mGHpp9uXl2y886QEpSLyTFIyaN5iHqzMkuHTtTWCehS9Z483R0mF2Ds2pvMEmUHvgtV/rJ+iK/k8mJJtc1SXjOMo0qbV3QDoI0L8gPXB0aDoI2HHkt6MTBmHD0QmZUOF20JWlYvB5rZOKK2iWcrLyL3niUNeCgcIjpUdHVvMoNFbp1SbnZdGYxUQokDAOC7O868Hrvhas1JME3knG/ZbXmLB1a+a1jCk2bp2ZqSb+u/eZTh/ddPVdpEx/LVf9AiY7nvU4Dmrk4rje1OUV9ea4CVs+EDwkjpGIHF1bzKd/hMh+kfy3Ime5+Pep4Kermq24tlxDrSy262QQoG4gjWDFIykvMtoZrEuZnN0ba3cFH5SNCSekXdUDKNZ+7Ttw/U/7jdGs/wDnvRxbS1VLr0hKy8iV7Yy7nnOTdozFD6TEz3Px71PBT1c0ACogJF5OAGuJSyNopxIW1TFhB1rKUepRB9UdgtpvyD5xv3o7BbTcn/ON+9HYLabk/wCcb96OwW03J/zjfvR2CWn/ACD5xv3ocsPaZCSo03Ou1BbZPkztMTMpNSbpZm5dUu6NSwQfXsTPc/HvU8FPVsKWlPCVdG3Nd9AIOBv5lhJWUpSM5SjcBxxZGyMtSJducm2g7U3RfedIa8FHT3ysdQ0fAVWjyFZllS06yFg8FX4SDxpOrqwOuK5SH6JUXpF7ts3ShXfIOCvb0xM9z8e9TwU9UPO5g0cIwSTicdhDikG8YQhQWkKHMqx8qictDT23BehCs/zRePX8FlQlUGXpk7d/aJWpo9IIzh5M0+WJnue8EJ4I6oeVe4reSp4Q5lWUnUyFep77hzWyrMJ+Xo+m6Bp08fwOU+eRm02nA3rBU8ocWjMR/HDwvbO8SCVADXGAh3hq3ksNBVx8ysOiLIW3l32GqbV3gxNNXJQ6rguDVnHBK+vQeuAoLAKFBQMaY0xpjTGnYrtp6bQ2VF50OzV3aNJN6ienvU8ZPiip1GYq869PTSr3Hj4gNQHQBhF0OskXlOGwBfgL4ZZze2VjsOcNWyhorOGiAAABxczJeq1OVTmS0+8yjiS4oDyXx2QVvlaY9Kr2x2QVvlaY9Kr2x2QVvlaY9Kr2x2QVvlaY9Kr2x2QVvlaY9Kr2wqvVpaSlVVfKT+dX7YUpS1FS1FSjiTpJ3hQk4pgJAwF2zmI72MxHeiMxPejmapYHXGeeqM9XHGerjgYCMILnFGerjhLmpWzb7KrTLHqVTpRsVOtkX7Xfc2zfgXlY3nENp7a7SSkEXz2WK3c26XEVQSSDghptAA8oUo+NRjdWt78YHPNb92N1a3vxgc81v3Y3Vre/GBzzW/djdWt78YHPNb92N1a3vxgc81v3YZyt29ZcSv7uFy7UtttST4syLE5bpepvs0y07KJCZdISiZRoZUo4BxJv2snvgSnjCYBCgCDeDzKJuF8E37xPBT1Q4dN28bOi6LZV7sas3VKsO6y7dzfS4rtUeQm/qETU1MTsw/NzThemJlRWtSjeSVG8k/A5F7UP1+zTklOOF2doa0tFRxUysEsqPSM1SP1eZS+Cd6nAQrE7xrExlsQ8uw8wW+Ch9kq+Tp/f8F9jyhz7ZtQ5cdqDcqOjOznyPHdfzKOmCLtlKbzsL4R3jWJi0NGZtBRajR3+1RPNlIPeqxSrxKAMVujT1Aqc3SqiyWZmUUUm/WNSknWlQ0g6x8A00484hllBcdcISlIF5JOgAAazGS2yLlk7NIamk5tSqKtuf8EkXIbv8BP+4q5llIOMbWdRgN8ZgADDYXwjvGsTsWtsJQbZS4RU2C3NtAhqYbuS8jovuIUjwFAjiuOmJ/7H2sIdP3Nrcu+zq25LjavHmJcHrjcBtXynI+e99TG4DavlOR8976mNwG1fKcj5731MbgNq+U5Hz3vqY3AbV8pyPnvfUxL/AGP9pFOATFXk2mtZRty1eJJbSPXFjclNn7JOJnVX1aqpwedAzW/9JvSE/KJUrpHNFfCO8axMWktLTLKU8VOqlaZbPSjtE5xzlX3aNHFG7fYf8bM+h/qjdvsN+NmfQ/1RRspljK48mXlKwhqYXoCHgWiSdQKu1J6M6+Lweay+Ed41iYy5/eWP0lr+LZvwjJBlJmkzcvZWuTBfl5jtZV5ar1IXqZKjik/gcR7XWOay+Ed41iYy5/eWP0lr6FbyXfdlX2Zlhe1vS6krQeJSTeD5RFPmftyQkpv8qZbc89AV+/mq4O23jfHGVKju1qxVVZl0Z78qA+kaztelQH6t8YbNIpsxWKpI0uVTnPzzqWxd4R0k9CReo9AiWZRLS7Es33OXQlA6kgJH0c1VJzhBSRsJQTAFwuhQBBBF4Og9UZSMkM/KzcxWrLSxnJB8lbksjS6yom87Wn/Mb15qb1pwuIwcYeZWpt5pTTiNBSoEEHpBinUmpVaYTKUyRdnpheCW0FX/AIOk3ARkuyX9i11arWa5W3U3IQLlJl0nEX63DrI0DAHHmxcOLezVIpU8c6dpsvOK43WW3P8AkkxLScpJo2uUlW5VHE2hKB5EgftHv//EAFgRAAECAwMGAw8ODAUFAAAAAAECAwQFBgARIQcSEzFBUSBhcQgQFhciMjZCUmCBkaGx0RQVNVVWYnJzdHWSk8LSIyQwN1NUhJSis8TTgoOgweGytMPi8f/aAAgBAwEBPwH/AE/UbGQsvhX42NfTDQsMkqWtZuSlI2m1TZeXtK5DUtAJDCcPVMReVL40NAjNG4rJJ2oFmssddtv6UzJDw7hbTeZyYAHxG1G5boGbPtS6o4ZMrinSEofQToFKOxQVepq/Yc5Sd5FgQoBSTeDq51YZQZVSn4tm+r5ooXpYSbs0bC6rHMG4dcd12No/KzVsW4Sw83AN7Etov8q84nyWlGWKfwjiUzVhuZw/bXDROeBQ6nwFHhtT1SSupoIRstdzgMFoVgttXcqT5jqOzvWy61U89HMUtDOFELDBLj93buKxQk7whON3dG/YOBkVqp6eSGIlUa4XYyRlKQo61MLB0d+8pKVJ5Am1TThMhkcwmhxVDoOYN6zggeM2jIuIj4p+MinC7ERKitajiSTz6KqJ6m57CRQcIhHVJbfTsU2o3E8qL84cl22wN4BGo96uVQOCu59pNekF3wc0XeDgcz+oiop2gHqTBA3cj7d3ivPjtleWpNJEDUt9oHy8GUKUuVSxajnKXDsknjLaT3q5c6Rf07FVwbRcYUlLUVcOsIwbcPvSOpJ2G7fwOZ/7JJ18h/8AO1bLB2J/tDX2uDJfYaU/JmP5Se9V9hmKZdh4hpL7D6SlaFAFKknApUDrBGu1T5B4aJeci6YjhABZJ9TPZymxf+jcxUkbkqCru6schtaAkD1Mr/O9It0ja13Q31w9FslWTyoKPnExjZsGtBFQ2iTo15xztK2vEbrkm2WDsT/aGvtcGS+w0p+TMfyk96ClpQkrWoJSnWTgBdvNpjlMoiWOFmIn7S3U6w0FvXf4m0qT5bdOCgPbk/UPfct04KA9uD9Q99y3TgoD24P1D33LdOCgPbg/UPfct04KA9uD9Q99yzOVugXnEt+vmjztq2Xkjx6PC0BMoCaMJipdGNx0Ort2lhY5OpvuPEcedlg7E/2hr7XBkvsNKfkzH8pPOmlQyWSi+aTJqDJ1JUrqzyIF6j4rNZS6Ldc0YnKUk7VNupT4yi4eG60LGQscymIg4hEUwvUpCgpPjHeWtaW0LcWrNQgEknUAMSfBbKVlKj6mjoiWS2IVCyCHUUhKCUmJI1rdI1pv6xvVdibzq4dOVPOKWj24+VRRaIIz27zo3U9y4nUeXWNYtSNTQlWSSFm8J1Gk6lxG1t1PXIPnG8XG2WDsT/aGvtcGS+w0p+TMfyk2yjVuaYg0QcvIM3jQc0nEMo1aQjuu4BwvxO4xMVExr7kTFvqiYh03qWs5yieMnnU7U80pmNRFS986MkaRkk6N1O5SdV+5WsWkE6hKglULNIM/g4gYjahY65B40n095WU+YuyyiZ0+yc1x1AaB+MNx/hv/ACXM+zF0RtQSkqvYW03EAblJXo1H/EFp+iLZYOxMfKGvtcGS+w0p+TMfyk2ygx65hVs3WskpYc0Sb9iUDNu4GRKOdUzPZao3ssll5PEV56F+PMR5e8rKNKnJzRs6g2U574b0iBvLZzrh4AbHAkEXEfkeZ+lLoXPZ4tOa0pKIVs7znaRy7kub8dspMtcmdJTFDKc92GzXgPi+u8l54EBBvTGNhYCHGc/FrS2kcajd4hrPFaHZTDw7EOnrWEJQORIAHmtV/ZPPflLnn4GRSWOtQU4mzibkRi22m+MNZ5WeTOWBypPeUccDiDbKZknjoOLiJ7TUMYyXxBK3YdAvcYVrUUJGK2jruT1SNxTiFIW2opWgpUNhwI4dIUBPqvim0wsMqGlwI0kStJDaRtzb+vXuSnw3C1PyKBpuUwkolyMyHhU69q1dstW9SjibKSlaSlYzkqwIO61d5NY+WRL0zkcOqMlTxKlNo6pxgnEjN1qb3FN5TqUMLyQpJuUm42hoaJjHUMQrCol5zAJQkqUTyC+2TjJ45JFpnc6QBMiPwTWvQg61KOrSEYe9HHzqv7J578pc8/Ox3X2pShJzU8Q2UsqhZYD1cQtJCbtobv69XJgO2NpXLYWTwENLoJvRw0KnNSPOTxk4nj7zI2nJBMXNLHyaGi3e6Wy2pXhN15t0FUj7m4P93b9Fugqkfc3Bfu7fot0FUj7m4L93b9Fugqkfc3Bfu7fot0FUj7m4L93b9Fm6OpRpaXG6dg0rRqPqdvD+GyG0NIS22gNoRgABcAOIDAcCKp+Rxq9LFyiHiHO6Uygnx3WgpVLZcLoCAZg7/wBG2lHmHPepinoh1x9+SwzrzpvUpTKCSd5N2Jt0JUx7Qwn1KPRZul6cZWlxqRwqFp1HQt+iwSlICUpCUp1Aah3mZNckE6r9RjnHPWmn2lZqolSb1Oka0Q6MM8jtlkhCdXVK6m0ryC5OZewlt6VLmju1x95ZJ8CChA8CbdJbJp7mW/pu/ft0lsmnuYb+m79+1awMLLKwqmXQLQYg4CYRbLSBfcltt9aUJxxwSALSqVTCeTGFlUqhVRkfGKCW206yfMABiVG4AYkgWpDmbpNCsMxNYRiplHKAKodhZbYQdebni5xwjaRmJ3A67OZEcmbjRa6HEov2pdeChx52kvvtX/M6rl8I/NaLiXIxDAKlwT3VO5o16By4Z5HcLGcdiicLLQttam3ElC0Egg4EEawRsPOp+koqcgRLyvUsD3XbL+AN3vjhuvsxRkgZQEqhdOretSr/ACXDyW6Eqf8Aa5PjV6bdCVP+1yfGr026Eqf9rk+NXpt0JU/7XJ8avTboSp/2uT41emy6Pp9aSPUATxhSgfPaeUK5CtripU4YhtGKmldeB70jrrt2vltiMDgR3lUlIXKmqOUSNvD1weShRGxGtZ8CQbSuWwcnl0HK4BoQ8HAtpbbSnABKR5zrJ2nHgZROz2tPnSP/AO6ctzOFHw8HJImrYlrOjpmpTTJIxQwg3HN3aRWs7QBwOaKo6HkdQwVQQDIZhahC9KkC5IiWrs88WkSpKvhBVpLL/XOZwsH2riuq+CMT6LNNNstoZaQENtgAAbANX5GtpUiXzNL7KcxiPBVduWOvHlB8PeVkMcZbykyPTXdWHUpv7otm7/fg11EIjK1q6KaN7cRMo5SeQxLlxtkcSE5OKYuF17F/8R4HNPJHQpTyrsRMLr+Iwz148Nw8VqGKBPW87WULu5cPyWUcp0UqT22c6fBcj/jvKkc2iJFN5dOIQ/h5c6h0ceacU8ihePDalall1WyOCnksdDjMSkZw7ZtwDq217lJOzw6iOflPrmEoamYuMLo9dYtKmoRq/qlOqF2fd3Dd+cTvuG2y1qcWtxZzluEkk7zibZHfzcUv8R9o8DmnexOn/nH+mftLo1yXR0NGt9cwoG7eNo8ItAxsPMIVqLhl57To/wDoO4g4EfkFqShKlrUEoTrJ1C1VzhM3malsm+GhhmN8ePVK/wAR8gHeXRdfVJQkaYuRxdzTt2mh3OqYeA7tF4uI2LQUrGxV14tK+aeky2U+vVOxMPEXY+plNuoJ4tIpojkN/Laec07DaFaKcp1xT6hg5GLSlKePRtFRVdu0ibVJVE8q2YuTSfRyo2KXgNiEJ2IbQMEJG4cpvPOyO/m4pf4j7R4HNO9idP8Azj/TP86Tz6YSRwqhXM5lfXNqxQr0HjFxtD5RIMp/GoFxC/eZqh/EUm3TClH6o/8ARb/uW6YUo/VH/ot/3LdMKUfqj/0W/wC5bphSj9Uf+i3/AHLdMKUfqj/0W/7ll5Q5YEnRwTylceYB/wBR81p1VsxnCVMC6EhD2idavhq28guHejkd/NxS/wAR9o8DmnexOn/nH+mftLJXFTaI9SwgBduJ6o3C4W6BZ93DX1n/AK26BZ93DX1n/Fo2mJ3AJLj0GVtjWpHV3ct2Pk718jv5uKX+I+0eBzTvYnT/AM4/0z9qC9mz8Uv/AG4FZUy0WXJtAN5jjeLyE6lDuwN47bfr71sjv5uKX+I+0eBzTvYnT/zj/TP2oL2b/wApf+3AcQh1tbTgzm3AUkcRFxtEN6GIfZ/RLUn6JI71eZ/nzM1oOGgErvipItTK07QknOQeQpOvffwOaenzC1U5TTS855guRbwv63OGiZv3EjSHkuO21KRiYKeQi3Dc27egn4Wry8CMim4KFfi3TciHSVeLZynULOLLjjjiuucJUfCb+9XJ3X0xyfzxMyhU+qYJ+5EVD33B1u/Ye1cTrQrfgcCRala9pasoRuJks0bcdI6uHWoIiGjtC2ic7Duk5yDsUbXpuvvwtXuV2l6KhnmxGImk8uIbhWVBZCthfUm8NJG0E552DbaoJ7MKlm8bOpo9poyOXnK3DclO5KRcAN1sRiMCLUzWMO6y3AzVzQxCMEunrVjZnHtVcZwPEbJcQsBSFBaTtBvFomLhYRtTsTEIYbTtUoDz2qqqvXb8Rgb0wKDidRcI4u53d67bjjKw4y4ppxOpSSQRyEY2cqSonmtA7P411jVmKinym74JXd5LG8m8m8ngNRcWwLmIpxke9WpPmNnHnnjnPPKePvlFXn/1Hv8A/8QAKxABAQACAQMDAgYDAQEAAAAAAREAITEQIEEwUWFx8EBggZGhscHR8eGg/9oACAEBAAE/EP8A5nr/AL/LiBroYEXRogVTAqDsCcfiB1kpeCgxb0JQyjbZpue93iXuQZCVQBUseQD8CQ8TGIIic3Pf/GEBfOnpC3iisqmV97ucwTKABNMIzHCIzUUQR3HCAUuHMmbRnlg+KJQ/hwabdFBY4iBYKHW/f0cZ9j4qE36Y7yi1JpFUylCP4wAIim5TaAKqSXrfv/0mQg+rNrpPYi/inpbMCFFsD5mhWOl/75xkX4KoWq5q2qquDJuREhxdIvybHeUGyMro0E0EADrwgsbL+onKPByWwEfYcAnNH8qbMiFSDT9/Hxz4/XBQCkvN37f4nYUgq7c8JsAfDydeEuhdH2nz9L2tMZKrs3yJ+v5U2ZEKkH/eSqNEZyhUODoCPy+55ltmRCpBuvMe4IUEARHjGF7AYFI1gRLggBHnsBn3Ag+oPTa9MwUyA/z15Q8/lbmW2ZEKkG2IY8RNgaKrAwoSxd0DAeTG57f+/fv2UyhrAA7y2wAqmOjkLWF4Y+SHyMnMef19DmWRcI2oWLsBVRLcB2N+ZkHrLUjlMPrivwFBhpUgsQ4NL6FPv9v7yvOC6MZgyew98sw1CxoTz5NvdlU1kp34qWqSMKjAAbU1C+E065zYGkSKFtoIlJcvj1NmRCuTivEsNpz7XwTO7B7QalNqW0DAfk2uoGqPKalhvLAQ1qiZ14PgOhiFVwhTYBUjsKFCgGXSg01QiEQIztQiABVQAFVV4IYyU+CFbJ9r8MMD7RWwNHmjP0ZDqDwHkvPLQ84Qg5ciSWqstp5eqpBoOJVpD4AAQRBJ2FChR4pzL2z4XM0s16pb/TMpqKiugMQ3clwJlrdgCIzv383u+/r9f4/bJNIpGK7uIRZqPIiWziTgOaj4vp7ubn0XIeAsyqPMBliT4Ik4EC8thBYAABk+/b9sQTiDV3SbRkyDBYHcoxGOWHwHR3vSWWKNIgUEha5TZEo6CIlVqZpckMcK8v5aTnL0EbGPuan7YOz19Yh0sQoiGsKlLIlZzaoClqNsln4QroJJ6I2ZEL3cPCTXxhLEbA6haeKKHEAwaRs1IQ4B5USMAa68PvgRW6gQAaBFEtOWRZsEdlVrk3lU+baGohzKdiNGjSsqqyqqrertb79QVAChAAqq8EHA5SZQKJWlbZrITDotQAifgonLBtVUMvKq5y/f+Ppl+/8AH0wTeWexD8KEsgTJ37EzvNkuiK8CPBoMTD6S+VkD6SkHRddXsyoQaQBMlBOx+hHZALI9UaMz2FERsrgwNUJP3AKnq7IsZr1bM0EtENHhXhffyrX3dfv49F5tSbUY4FsNxeDI2u4ni8/8dq+T2Pqc32xfAxqcDuaycpyw18/Xqt5hiY88CYOF+4pFZXTALZjLaIseOJz5L3aupMQdxnC3LpR0z0UFCTv2ZELj7BNLVlT05Fldxa9Yy8LVQp9xfZbmmtTRmuH9yu9Fx4dwAAVXgMQ8EZ0HG2uSFsjyGF6U0iAUSqveAFWkcwabpDQAG3f6USIHwrAke9SDlX9Ca+cUerMtsL2fi2Ck2eGurOIyX3qapwWEVVMFqg7qKgD63UG2SaEGqYbsxCSgAiJAjwj6JMr8SniCQZqp4QnKR3UiLwN4WeU4TSeR3R9m/wBdPpiPc3uD3FA+UQMJuE2tD2vbFxvb5eyZnI5M105o48Vo4+/f57Uos8MUgSVRIPVFJP4+aD5HXKnXaDpozq+4oZoZEOQSs1YW8mHA0nAiMkgILN7xRRZoBg6lEM+DgTnomTlM0UAc4XIW9OlKs6eBgDu2ZELiEL5KB14AFGdmditGgCKAh91nziYgVISpUo2Pjx6Ff2R3q35zljPVO/MYqlXSq1VVexSApnsqjxSvBcVFnAt7pz9uyg7y2SyMlAS5SeNlDoTBktkUdqkGJ1gqoC6KM5lSylyyv50ShSa9bOE8uCpNUo4KhhFEaMxSJ+0jiPrEScAAEQ5QtMXiXtUUTqOpS0wcTh6SIQgiInJ3AqG32OfPH7YCE8cSJEtrqEJvxRJiOgibbt7sNAwVBgU8QQgRIjHIMinYTJFaBg4hCqqqiAShEaaxB8mnSiSFmjlQuKdugL1hCKlayQOOX+fObt7tzfi6AkCvgCrvwG3GKR4ZU8iUCgDCPPinCvy3R1cq3uZuuNVq0ivQL83raYBhZRiRDwAwboBiqoEhRHXVPZP7zbCGgXThCC6SlXWykQeg7MiGSqWbEkTfw2HG4DHSz1VXzproZD2VxDbMkWsirj1tIpJKDTmVYa7iecCS2Q03jDuop8JIWiARHHK0KEuguQEDPKZ7i1CZ/ZKAHtrn1BGi3cxPhMh2NTLHxpygwrrHsOkEWqp64ugdPj1BPGUaWAxfNsZmIE0F8GI/cOqWHqdUhpceR9rd19GgowMFC7ERC1EIiEeeMfgnrUAXCWI8lOdJuWESUFiCrkMRSL+A4AIPB2qXs4tnsy+0CWgYfcO8CEhFghVD1BYAqQAKq6gBtqYT4K9F2SGOIDCH4CH39/GKkdYMSkshtXuNmzZs2CiaWHihvWcSzZ+BQfAAZD2+/wDvSH+OXjEWcGUtOzypXBkwAA5A5OFHV9/SXKp2BRV56NKYeY+7XjhSpLChIGAAIBrvrPCCbnbGcirw9aiIxNiajbqcbwUEhN8WdOgnWhjmZf5fB5PFT39q5fyiZQCIn06MCkI1kgloptN+jsyJUatk0ObHEOhps6mz7wg286AAVWGEuQsh8zI0hDr1/PSDuyIykGtCWrt/XS0SZWf2UO2K3WP3z/k56AP+AiHldAAVWGFkgujJrW8EUHYD+EAmjyIkRIjHH8HEuNMpQOF4HrUWAmaAbrGKu5Se2X2AAUTJHAdk4h2wp+RvJdVQhnTWhMDiAAAPwDo4X6ZQEimMbqufqEGUuTlSypYgdEFmfSef1U/oZzTwc/P5449TD407ZAA6gY3IQ8wDziaJ4xTFCly0KDeU9imuEhkw1QJAR5GGDW9wUawVyaMvPHKKGhCDAiXlxz05FvPUJ5AKwNywraWCc6N73X79+/flmkp+teGvxH2TF8iKxj7MgIViaqZJy1AqB2hI+e5AWD9QIJKtBqCQ0zY70eqNR1kPc8tkVQDYOVgSBA1e9pCHdhCVcAeCH4UUsEIERj37MiXbFZ+ioAQZS7ENr0Kq1OV6UEslXgqBADiE/wC+dT0mddGh5Zgo2xhxbdnUx8IQviIL8OklGzAYGYAnBwBT49VTbz1BumF3JAoQvERQmjEjiE1gNyqpfwNEiVgv3Q5O+LH6MRMtG3FgiAOz7/8AZcMa+/cmSjETSsf31SM04eDQttVNKoAgiFQJHgG/cRj5xV7aSKo7/E8e3jCTzTete0/mYt++TJyoHLtCu17wWPQpREFEIegAxfw3zyjxyffDF7NIJRugCJEk12/+47JpmsHYJZi7x2ZEJ9I0C2dNi+AhKvTcehVxH+vOXCpDMAAQNIJE1ONekjruQ+EUHAhmKmg89SnoaRIQF4UAS4gH3jcMiOJpvqqZGZDGB6lSpU6gc7BpWgkwDUcMlDCSSzapai/wPlKE6LLKXc8Gqph98fd/31b988+Ps+ubNTW9q9LCXU98Ykk2rdBxqB4OwooyLaCdEp4IcuJiwcVHcjobnyek8ce07ZjzePYvv6AAoEERBEdIib1jwVl6kVcsVBQQcFQyswMBhCmGhxGh4VG61kSIgdl6TthR9jUwHQddVnfz2Ew2G8ntzRkk4g2vAp9O7ZkSyFKZKSfgrkSgN6CiIxERNImyJw4T2d926KNEHRXVQKoAKqgAFVXjI26Tl3/COrJYeyvdYthbcB5pZh+/b9OgoiMRERRE2InGDuvwElBm4/8AKHHURZIRDIrkEFZlpkmKCnQ+zqFBR2BQIxu2yiHcpd5uI2CsT1SKMaKxWHJgAYnimnqpqbkqdG2EgxUC43BHVrMa7kA9eSn6FXEb+iL4wpyjzELDYTGc2X7/AJ/rII54mRhUYsQOQAV1CCUACPADu9VGnoWFMETl97gnnHImCLLG3x+kHkT0Cd4THW1cAAquAfDFFa/yRAsq4e42MX4gzKRGwMF9yO8eji5lCiZUkUN9dHaHEQQ6rlyZpWJy2tMUOjYagI55upT64/1MLXLvkE/Tu2ZEIT2I6zbwFNhTZkKNDJRBUxBGaTq6vpgUrMCiohBiBr8QiqT7xUCxl9GPhQBBzpeZjZbIYSGkexeNaoskWcK+ZAkQ7DgCPCGZPAoKq9tfSbk4onLO0oPOAeN3QARvwS6J1gPw1DFMsuKtON9o5d/H2sSsBkOkQ8Oh+HLFmK32wtqcSRkUYO9WuBRDUXJHCOLIqGEhS4EQhW7xREUOiCbUEdlSFE1bLQHBTFIgdin7p/55qVNzeVh0uf2MhSIiMRIiciPkepjSQWFlNvQpXFzyEtrXqh5qK9cJvjx49/jN411hCTD5nOElY2NAdbC5IxfHhE/nQSI7XuhoWY79rq4BbxqyVFg3N+5/Z3eqjiHd2rqFsvqF1cCioVePJC32B8Hdx48ePG6k0w+9A17jmfOWrcCkInbd4i6FM+/udyrTtwmDgwzizEDhnFFoK5VoFRzbwDqUAosg6sQHAMA1SUCW6ug6+7GycNsjViFgkHaOalRadRNRBcQdDdHv2n/NxIw1M/ZrqeXxT4O/ZkQqQ73sRRu+gIdqSqaopRROPpjz313jGP5FfCnqBapA8Elkeb1DgwpDx2CnCrTKaT48drDFUnR2RCOCJI8WU1fcmlbqu9ykG4cLqkfUIBEQkcMNPhpUQNBDYbqc3qxJHEwxricPk8phngNXAmBPwbx+p/Z3eqgBBMOWwakbrn/G4YayuGTMggQxgBJYDggIiMRGibCfp6agra5ELR5ML4uJ/PUDBlUhHRPvLZiDwQWzxoUwNpjUZEBDt6EbzsyIS85ZCGK9g08YIwKx9Q3We5oBHDbsrhDD3vUAVd1IpbnAIONRaMlDcChrI1dgB7y0hzEA6xqr6DAayNmlEzn0lL6FFIM2PHlbs00xhCDiUUwQwHYKMUNOxmTIZA7aRHRHDTmGUeYk6FBQ/gnj9T+z0fVSUQIEREW6dT24PORnaqOmJAKqyFAD7b5d8em3NUKSyAU6OAUyJpBgoR33WIQVMvvQmkaqgfhj2xvUtE0JPc6ydPt2Yc1kNY5fuFOBR93AgG7j4BEtHch2ZAs+h3BtO4q0GUNLHq/frmMBCJK6gDhubL8ZAH0EBBOrYM/jyuxKgIIB7+6zzYYwoHYPTTjSN6gLSeXSYRcATAAoKLTqDiBOiDUu2AoIq85h8NWJ9RCVLA6v378XTi0DYTKFQEnVxoRhMZAEwI8fdSMIpINqEoIQLmBY2xkE+QvQFQCqgByroDDDAk5UGfQUBWhxq52FuG7mRNDgeRi4op8QxeCgdBwKKp90AkJQb2P379plqonCZKAATqD7EwyAFiF6Y4J6A8VT7WASmuj9/Pj/AK+T/EqgotxI+xR/gp8fU/jf9Gc33+789j/pfs839nGfoXYMxc1Jzm1OfTNRQM8ghP09XDfzz849f9xNLOa7t3cV+06EiBeXxN4uRiDrjq4clPc4ctQMD+RBtwHHjh0HHh0AQAADgOxMd4mpvMhn/nZQoUAmjQaA8do56euQr4nOLVjXpugMHWFDlVLRhrteV7YY2M7SERwsul+XpH5w6LeZDOyhQwBAAAAANAHAHtJ3GSIxIxyahUL84uyrC1WNGNAGs0GIIUAQBgNzneEISRiEgGh7HthhWwRWSkO5f37KFCiBAAAAAA0AcHY9oSaWOC0/72UKFAQIKNEBEaI8G/gyXrIjiRKi8jhBn3/v+erwSDAGh7bzyLmz2SphJtoz6cUKJGqJujJ+/UVC8zImPcPwi4GUIn5q/SPyq9tX5pnQEEggaABeD7F2ri6Zcv8ApIssFv6YfunIya90fIDDKdkyh8TtpBdXCoHAUBEHgpG85RR1DUqUIBXUInLoM6vsACeRKYUVLpq4ADyoBVCuPDEG2SFFNMrtSflVL5/1+2amyLHj8FYOEz8EPLTl3sd75wq7jw4BEAAA0dZ+3tD6/vc/Qp//AAW5j1lng/hUDx48ZN39P/o8/8QAKhEBAAEDAQcEAwADAAAAAAAAAREAITFBIFFgYXGBoRCRscEw0fCg4fH/2gAIAQIBAT8Q/wAZ2anhyffZRmwHmcBLIDTTEiaJLyB3QINCvSpuIIe75BbcoofEoAGmUgAEpyxoC0ZEI2R3emIS6funFEO4/dRYAeffH93rvjbzrwrMUKx6JOBKxkC8I1Z9O1v7NB4GVC8IaAi4Foit94W607DLL/XT0LU8hdQ4UbZxU1iyhzZnnOwa4KAdQY3RU7VarxKfewedKyt4fBwpeeRUE09GMiVrTmKYKTETr6/z76sXRsGSvAfHCqRgNLBAQiJZKZKAsuLT1oXfuvTghNy/pfNc33P3TAIZ8xs28sNuTWLo2DJXgPjg9por4uFOAC6raKgbIkhHDZ9N2Xp9wrlqvLVeWq3FjFNGmdhrkJ9BLWRJsVbwBJzJOdROtYujYMleA+PSzgqGYD5oWQHJngtqoACVLABqqgUSjjEK4BEIu8MoSmDS0bSWj90Z9GECPbPRaeQDVlM7GDEupYaBJtWLo2DJXgPioI5TWnlkbqlogtmTT4tWEB4KOA0x1m9iD2o5Y/j6/CMwIxmHnfJTroTLcmwJSlEu58UipmLe3qMYpETFn54KucRWACV0gUp0pWGEkzvLfhYDnQuMjqq6E605TJf2qO565llFRZNAPavKfn1ActqcdYUHQ4KlQjISEsjQYESQcgKwIAYHqWJxCkRkTeJkrt812+a7fNdvmu3zUxnTLp70unWIsWgamQWsFtV+50XhWNpZDu0hEbyRT4pd3lnGsUgKa87f3tSqJHJmrXNwbjnzpBzUc2r81bf4/wB1Bpf+60eiGtfq31RtxwWgrC67SRiBA7G0iRIkSIg2wjAm6jBHlCjeqqvNqCI9UpBehWCegPWZVEubV/yKBZAehwbYc0XVGFf1n0jVllQ+KUEtinWDHOo+ipICF109R4MRixa+6AhU0TRFj+9p0xCxztZcuXLlvx+YsblXTyvrJSMhNUgIkiwhbAhTPHES4iSI6iXHXgqa3KRK6+uj2+68B8UyDpU6aVPpPJkqEUsFhIdjUlTVCrxXMngMzKrf6/ATpZmzSBRJlilZQlN2K3XgvPLZU72mx4X3TAaMzkc6Ei/7/FBcmXegdjtaMHBIAjrTKPVis2b0WsYNmeF91gpHZhsu0NQTWgGHAtPpg8GkQ6G2lnwS8AFUYAKsLmspK/daWEjRg4KJspmbBSzmKFgbU8L7rvTbxDBd6ibsrVkUknq2TNAJvQX3bUvXr169Q2kDqM7pPXWkVKspEvCoyWRgVKMbuFJ4X3Tx3J08LrLpZtuv6dyVaT3MOcFGYhI2BoAIyN+pvN5w1PC+6/t7vUQYMRusntHvmrl9NBF6qMhrMYkAJ14Z3hfdM63zmwxwdcnm5gJ0q1McK0dCTh2DmHKnCCWLJwCrNxrEUikSEyf2p6uJIomITqqMSaUKEdB+LcruFQQ1pCEqJxek9wa0BDBQ4hoJIrIm5LUC1jVAXOkwBKiG1ZMiJ5kAImog0ngYW7wSwReuuQtIAJGgWwbFgYjLpTHC0TmgsD22ItFATvUXu3zX/HL/ADeKCOf+R5//xAApEQEAAQMCBQQDAAMAAAAAAAABEQAhMUFRECBhcfBggZGxMKHBoNHh/9oACAEDAQE/EP8AH6FuxwhKj8AXVAFQpToUhCMRxrERFNqBTSKkodAQ6oLvNII8EtgohWRCxY0dg4oZEbiJkTXgCJQ8g2ihNETuGyoyLBwJkF0aKQdip5PugRSWa0MKnYM0g+yIhpZTDqCndNT6VGmNpIthiWCrXAsHCPnv9U2MvVmAm8mWWY3ZodyWGPfwiXoNIGTFRqsumANCCwcZPzzggkxJKiSWCokUiJDaHCe0elUApInutuzHI0gUaFI+4P3Uu8dSC+LduR6k+Rep3y5lTPuq+lM0W9ACcIS0JlhnjQLgk+f3yR4PC3IcfH36WumWIk6iSIIERKh8yRNSgbbAlgABHXGEIJvZb9TgtN9TC6UARlN4rB4W5Dj4+/SN0BDqgBcqQAF1YIKT0SS0GERqales8rt27dsQBsCRW12juYDVKwc6kWJkrqIBqHDB4W5Dj4++N0mA5AR3CLqMaH26CA9qGsoUX8pW3upO43NT0WUJ5kBKFsAFXQKcPZAGFAqGRjA1K5zc82rPKWmNfPP+FTkvJAN5sKTEJ2UaH6RVsiHWQsmrqVg8Lchx8ffC6uQoBcUiRTICwghQgfSNJlZC3wYCxaAjzzztRZdggG9xYmInuMSOqt7GAi4CjokCyeincmRZAfnh96vqyvn9/CkBB7hxjcVjPQpe59XIcVFDJ7bTF9Q6CA2wvVZzyOjBM4ZDoEtqJz6Kty7pKMw3SEXmgyoEZsyQMm9vwqYUgsV2ckVjWGRrD/IXRTDqPsFTm2GNvPNuDi2ahUnBNlJC8C7AXSvNHErTkBrFOgcyRAF3UvsfRQAhgI4RyNNbo0+wUqrAUtUGDKiCgyIwibRJzAyETP77edqu0guXYoMWA3RVyrGFJRMuu1yTdAsRRDRIEiiERyIompRHWJkjC2N0xLQFThhzZEdohi45valtwLkMQCnuD1pUByzCwBKVYLMkyYqUQ40evrV9/wBf9okgSdCgCqYhGyIuWIqQhhG8VqGLq1cq3Uvozf1jxO78xebzx48eKoekJVuSr9aKHQOOwAANAAqOEUnRbqquVU16qtJjuU0zopKdF4tjw0PlE01W7wLsAuQmHcl0bwAAAGACwGgW9FtXtPKzq0YLLSQNIOhJaohWYG8EGOtOlDXIGfpv9aQqSiF4pQUVW12aOBhMrzKwMXRkRNOwkAa5lhippBQolMxiphgM3UdZpJ5UEBLCAy2jpyNW56sRC4JCNy/bg3GdBkuMIpEMKXWCEHUhlpRlhDOwOxzIUKFChiDH+KJn3tRIKQJBdTABqCJM6ERDAR0fRSfupobH6qnWKNXJUAAwZQVXRUqvCZzRr2/pU2/epAKKcyhldCwRD710G3DNI4PkjMQIl01ThpmsZe3xshDq0SBDgBgANCLe/wCB1PPii/ApIGgAWhhhiZp6K/gYVC5eCFPn80ON4xJn4+u/ejgOobLobiQnRoLKQoIlZXu68jUicMkQk2uN4bUZYt7S+h/FdQnG1gb7S+70VD8KZgiqdy9KR4ftEZGy3CsiCUPBZeHSQhznosiWaJ5RZKvIuqqq7vKj+soNFVvsG7idGGjWjIjcYIXUBttH4BaCqAAJVWwBdnS9XmOWgEgfB9D0U1KJ8EzyCQEpjDISNMicMIYitSSarNHhyGASJTwhsGLtWaoDE9MGmLDK3JGjlR/WcCcFBxxqkjtvoMlqDw4vN7rDBTfHu8wkSJEiWTS4PfJ95rXAd17iCehvj6VR/WUYKpcMTeG99uOGJmbVIAai0aywjOK6emkf1lHiN+BJpFzrPnv2o7ttEa0ERmgQJQIvpaSwTF3TkXe0hfy/3WXwvyDEplhcGui1f6b34mPSoeZLrgeF8JZIGSnNuH3QIDFlYgOgbeWAVPtimCMS0iw96kcXngsURh1liYKDqRuKU7U9zGX7fSqnBqO/pgS5WISBYNqdgKWauWiyaiUhBqoHzNSPoEMIpVYICNMnxBrw4NoI1gRQoJIkSzJe3vRiym24DWHFiwzJJMREAg4hJL1dbGmLaEhXYBZwVnAhckllyBkN1u4D0u/9p7iyA9Rq1cPYWkx3LHWkhiJVuq5lbr14xtanSFoR8FUfV1a+Wv8Ake//2Q=='
		);
		attach.ParentId = testCase.Id;
		insert attach;
		Map<String, String> rosco = new Map<String, String>();
		RoscoEmailUtility.convertHTMLGetAttachmentBase64(rosco, attach.Id);

		String imgTag = 'src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAXCAYAAADtNKTnAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH5gcPEgs7q9fZiAAAAiFJREFUOI3NlL9vUlEUxz+P9yhQEHlCBSJVMS2JISYkJTYYo0MHFycWBxZX5y7+Ca6dunToymiMg4nR2KWpktjEsFUxBUKwWBD6uD7g+Rx4yM82Jk2MZ7zn3M8959zvOZJpmibnNNt5Af8K0kPUNYQwzoxSpk4MjdL+EdmCoKCPnEsSEb+HdDJEzD9+TRprbK3C1tsG+52z3pWILQV5sqpin4KUSzx716I08lch1U0qMsfFnx0+lDXy7aEvEg3z9I5vBGI0ePG8wisxKNJBZu0aqYA8kkGP0t5XNg66CCuj1O1lMstyv7HdT8dDABL3kgOAQbepITr99kVWr5D2DeJMdvMVmoACOrnyaAdNdj4WifsX6L4vsnVkguJi/dF1oriIqjI0rN/SBLtVUKDFl9ZE73TB5stDKzGZRMxH1HKJ3q+xEos1UMDgVBkoTh4/uErS1y+teVAmWxyfktrJSV8n02LpW2jRbwEE+TdFNivTrwU8HhTwcOPCMbnJkoAf1Rrbr78DBoXqrHRlFi+BDdwkgrNzmfd7Sa9cJr3iJjQrwOEkHrZmx5tUSc3g2JU5vKobr2r7o86hSSRuBokwGEA5QOauh8hEWFvXadY1mtUe7QmfK6CSiTv6uNHZEZ8P2djTxqQ/y/zhAOv3F/BagpamNlunSW6nSvZbDzEBs887eHgryNqSe7yw09djD1HX6Q4ATiculzwz8gzI39v/s2N/Aw3eyzNGOIrcAAAAAElFTkSuQmCC"';
		RoscoEmailUtility.convertHTMLGetImgTagWithBase64(rosco, imgTag);

		RoscoEmailUtility.convertHTMLGetImgTagWithBase64(rosco, '|');
		RoscoEmailUtility.convertHTML(rosco, '|');
	}

	@IsTest
	static void testEmailUtility_createEmailMessage_success() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id, CaseNumber, Subject, AccountId FROM Case LIMIT 1];
			Map<String, String> roscoMap = new Map<String, String>();

			String testName = 'testEmailUtility_createEmailMessage_success';
			Map<String, String> settings = getDefaultInboundEmailSettings();
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			settings.put('subject', testName + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'knowncontact@tanium.com');
			settings.put('ccAddresses', 'knowncontact@account.com');

			Messaging.InboundEmail.Header header = new Messaging.InboundEmail.Header();
			header.name = 'Content-ID';
			header.value = 'xxx-test';

			Messaging.InboundEmail.BinaryAttachment testBin = new Messaging.InboundEmail.BinaryAttachment();
			testBin.fileName = 'TestAttachment';
			testBin.body = Blob.valueOf('Test Attachment Body');
			testBin.headers = new List<Messaging.InboundEmail.Header>{ header };

			Messaging.inboundemail.TextAttachment testTxt = new Messaging.InboundEmail.TextAttachment();
			testTxt.fileName = testBin.fileName;
			testTxt.body = 'Test Attachment Body';

			Messaging.InboundEmail inboundEmail = getTestInboundEmail(settings);
			inboundEmail.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{
				testBin
			};
			inboundEmail.textAttachments = new List<Messaging.inboundemail.TextAttachment>{ testTxt };

			RoscoEmailUtility.auditIncoming(inboundEmail);
			Messaging.InboundEnvelope inboundEnv = getTestInboundEnvelope(settings);

			Test.startTest();
			RoscoEmailUtility.init(roscoMap, inboundEmail);
			roscoMap.put('caseid', testCase.Id);
			RoscoEmailUtility.createEmailMessage(roscoMap, inboundEmail, inboundEnv);

			String result = RoscoEmailUtility.rget(roscoMap, 'inbound_email_result_success');

			Assert.areEqual('true', result);

			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_createEmailMessage_exception() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Case testCase = [SELECT Id, CaseNumber, Subject, AccountId FROM Case LIMIT 1];
			Map<String, String> roscoMap = new Map<String, String>();

			String testName = 'testEmailUtility_createEmailMessage_exception';
			Map<String, String> settings = getDefaultInboundEmailSettings();
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			settings.put('subject', testName + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'knowncontact@tanium.com');
			settings.put('ccAddresses', 'knowncontact@account.com');

			Messaging.InboundEmail inboundEmail = getTestInboundEmail(settings);
			inboundEmail.textAttachments = new List<Messaging.InboundEmail.TextAttachment>();
			inboundEmail.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>();

			Test.startTest();
			RoscoEmailUtility.init(roscoMap, inboundEmail);
			roscoMap.put('caseid', testCase.Id);
			RoscoEmailUtility.createEmailMessage(roscoMap, null, null);

			String result = RoscoEmailUtility.rget(roscoMap, 'roscolog');

			Assert.isTrue(result.contains('createEmailMessage Exception'));

			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_updateRoscoWithCaseValues() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailUtility_updateRoscoWithCaseValues';
		Map<String, String> settings = getDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'knowncontact@account.com');

		// Account
		Map<String, String> accSettings = new Map<String, String>();
		accSettings.put('Name', settings.get('subject'));
		Account testAccount = GetTestAccount(accSettings);
		insert testAccount;

		// Contacts
		Map<String, String> contactSettings = new Map<String, String>();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@account.com');
		Contact testContact = GetTestContact(contactSettings);
		insert testContact;

		// Case
		Map<String, String> caseSettings = new Map<String, String>();
		caseSettings.put('ContactId', testContact.Id);
		caseSettings.put('AccountId', testAccount.Id);
		caseSettings.put('Subject', settings.get('subject'));
		Case testCase = GetTestCase(caseSettings);
		insert testCase;

		Map<String, String> tr = new Map<String, String>();
		tr.put('caseid', testCase.Id);

		RoscoEmailUtility.updateRoscoWithCaseValues(tr);

		tr.put('caseid', 'CRASH!!!ME');
		RoscoEmailUtility.updateRoscoWithCaseValues(tr);
	}

	@IsTest
	static void testEmailUtility_emailResponseInitialTanowner() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailUtility_emailResponseCaseContactRolesSync';
		Map<String, String> settings = getDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'knowncontact@account.com');

		// Account
		Map<String, String> accSettings = new Map<String, String>();
		accSettings.put('Name', settings.get('subject'));
		Account testAccount = GetTestAccount(accSettings);
		//insert testAccount;
		testAccount = [SELECT Id FROM Account LIMIT 1];

		// Contacts
		Map<String, String> contactSettings = new Map<String, String>();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@account.com');
		Contact testContact = GetTestContact(contactSettings);
		contactSettings.put('Email', 'someoneelse@tanium.com');
		Contact taniumContact = GetTestContact(contactSettings);
		//insert testContact;
		testContact = [SELECT Id FROM Contact WHERE Email = 'roscoapextest2@tanium.com' LIMIT 1];
		//insert taniumContact;
		taniumContact = [SELECT Id FROM Contact WHERE Email = 'roscoapextest@tanium.com' LIMIT 1];

		// Case
		Map<String, String> caseSettings = new Map<String, String>();
		caseSettings.put('ContactId', testContact.Id);
		caseSettings.put('AccountId', testAccount.Id);
		caseSettings.put('Subject', settings.get('subject'));
		Case testCase = GetTestCase(caseSettings);
		//insert testCase;
		testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE' LIMIT 1];

		// Email
		List<Case> tCase = [SELECT Id FROM Case WHERE Id = :testCase.Id];
		String threadId = EmailMessages.getFormattedThreadingToken(tCase[0].Id);
		settings.put('subject', settings.get('subject') + threadId);
		Messaging.InboundEmail testEmail = getTestInboundEmail(settings);
		EmailMessage testEmailMsg = GetEmailMessageFromInbound(testEmail, testCase.Id);
		insert testEmailMsg;
		//AttachFileToEmailMessage(testEmailMsg.Id);

		// CaseContactRole
		Map<String, String> ccrSettings = new Map<String, String>();
		ccrSettings.put('CasesId', testCase.Id);
		ccrSettings.put('ContactId', testContact.Id);
		CaseContactRole testCCR = GetTestCaseContactRole(ccrSettings);
		//insert testCCR;
		ccrSettings.put('ContactId', taniumContact.Id);
		CaseContactRole taniumCCR = GetTestCaseContactRole(ccrSettings);
		//insert taniumCCR;

		Map<String, String> testMap = new Map<String, String>();
		RoscoEmailUtility.init(testMap, testEmail);
		testMap.put('caseid', testCase.Id);
		testMap.put('messageid', testEmailMsg.Id);
		RoscoEmailUtility.emailResponseInitialTanowner(testMap, testEmail);
	}

	@IsTest
	static void testEmailUtility_emailResponseUnauthenticated() {
		Map<String, String> tr = getRoscoSettings(
			new List<String>{ 'txt_unauth_email_match', 'txt_unauth_email' }
		);
		tr.put('fromaddress', 'support@tanium.com');
		tr.put('textbody', 'test');
		tr.put('subject', 'test');
		tr.put('check_auth', 'true');
		tr.put('authenticated', 'false');
		tr.put('caseid', '');
		tr.put('owea_noreply', 'jason.johnson@tanium.com');

		RoscoEmailUtility.emailResponseUnauthenticated(tr);
	}

	@IsTest
	static void testEmailUtility_createCase() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailUtility_emailResponseCaseContactRolesSync';
		Map<String, String> settings = getDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'knowncontact@account.com');

		// Account
		Map<String, String> accSettings = new Map<String, String>();
		accSettings.put('Name', settings.get('subject'));
		Account testAccount = GetTestAccount(accSettings);
		insert testAccount;

		// Contacts
		Map<String, String> contactSettings = new Map<String, String>();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@account.com');
		Contact testContact = GetTestContact(contactSettings);
		contactSettings.put('Email', 'someoneelse@tanium.com');
		Contact taniumContact = GetTestContact(contactSettings);
		insert testContact;
		insert taniumContact;

		// Email
		Messaging.InboundEmail testEmail = getTestInboundEmail(settings);

		Map<String, String> testMap = new Map<String, String>();
		RoscoEmailUtility.init(testMap, testEmail);
		RoscoEmailUtility.createCase(testMap);
		testMap.put('case_recordtypeid', 'gibberish');
		RoscoEmailUtility.createCase(testMap);
	}

	@IsTest
	static void testEmailUtility_checkSpam() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> roscoMap = new Map<String, String>();
			roscoMap = getRoscoSettings(new List<String>{ 'spam_fromaddress_re', 'spam_textbody_re' });
			roscoMap.put('spam_fromaddress_re', 'mailer-daemon@mx0b-0022fa01.pphosted.com');
			roscoMap.put('spam_textbody_re', '[\\s\\S]*');

			Test.startTest();
			roscoMap.put('fromaddress', roscoMap.get('spam_fromaddress_re'));
			roscoMap.put('textbody', 'TANSPAMTAN');
			roscoMap.put('subject', 'SPAM Email');
			RoscoEmailUtility.checkSpam(roscoMap);

			roscoMap.put('fromaddress_original', 'support@tanium.com');
			roscoMap.put('subject', 'SPAM Email');
			RoscoEmailUtility.checkSpam(roscoMap);

			roscoMap.put('fromaddress_original', 'foo@tanium.com');
			roscoMap.put('subject', 'Automatic reply:foo');
			RoscoEmailUtility.checkSpam(roscoMap);

			roscoMap.put('fromaddress_original', 'foo@tanium.com');
			roscoMap.remove('subject');
			RoscoEmailUtility.checkSpam(roscoMap);
			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_checkContacts() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> roscoMap = new Map<String, String>();
			List<Contact> contacts = [SELECT Id, Email FROM Contact LIMIT 2];
			contacts[0].Email = 'knowncontact@account.com';
			contacts[0].Support_Option__c = 'Support Japanese';
			contacts[1].Email = 'someoneelse@tanium.com';
			contacts[1].Support_Option__c = 'Support English';
			update contacts;

			roscoMap = getRoscoSettings(new List<String>{ 'contact_exclusion', 'exclude_account' });
			roscoMap.put(
				'people',
				'someoneelse@tanium.com;knowncontact@account.com;other@account.com'
			);
			roscoMap.put('check_contact_max_create', '10');

			Test.startTest();
			roscoMap.put('create_contacts', 'false');
			RoscoEmailUtility.checkContacts(roscoMap);
			String result = RoscoEmailUtility.rget(roscoMap, 'roscolog');
			Assert.isTrue(
				result.contains('checkContacts: skipped creating new contact'),
				'When create_contacts = false, skip contact creation'
			);

			roscoMap.put('create_contacts', 'true');
			RoscoEmailUtility.checkContacts(roscoMap);
			result = RoscoEmailUtility.rget(roscoMap, 'roscolog');
			Assert.isTrue(
				result.contains('checkContacts: new contact for'),
				'When create_contacts = true, create contacts'
			);

			roscoMap.put('check_contact_max_create', '1');
			roscoMap.put('people', 'foooTESTX7@tanium.com;foooTESTX8@foo.com');
			RoscoEmailUtility.checkContacts(roscoMap);
			result = RoscoEmailUtility.rget(roscoMap, 'roscolog');
			Assert.isTrue(
				result.contains('not created as contact due to check_contact_max_create reached'),
				'When check_contact_max_create is reached, skip contact creation'
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_checkAuthentication() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> rosco = new Map<String, String>();
			rosco.put('valid_contact_found', 'false');

			Test.startTest();
			rosco.put('fromaddress', 'someoneelse@blacklisted.com');
			rosco.put('authenticated', 'true');
			RoscoEmailUtility.checkAuthentication(rosco);
			String result = RoscoEmailUtility.rget(rosco, 'authenticated');

			Assert.areEqual(
				'false',
				result,
				'When domain is blacklisted, authenticated should be false.'
			);

			rosco.put('fromaddress', 'someoneelse@whitelisted.com');
			rosco.put('authenticated', 'true');
			RoscoEmailUtility.checkAuthentication(rosco);
			result = RoscoEmailUtility.rget(rosco, 'authenticated');

			Assert.areEqual(
				'true',
				result,
				'When domain is NOT blacklisted, authenticated should be true.'
			);

			//cover catch block
			rosco.put('fromaddress', 'someoneelse');
			RoscoEmailUtility.checkAuthentication(rosco);
			result = RoscoEmailUtility.rget(rosco, 'roscolog');

			Assert.isTrue(
				result.contains('checkAuthentication'),
				'When case block is triggered, add in roscolog'
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void testEmailUtility_emailDebugLog() {
		Map<String, String> tr = GetRoscoCaseSettings();
		RoscoEmailUtility.emailDebugLog(
			tr,
			getTestInboundEmail(getDefaultInboundEmailSettings()),
			getTestInboundEnvelope(getDefaultInboundEmailSettings())
		);
	}

	@IsTest
	static void testEmailUtility_slackDebugLog() {
		// Stage data

		String testName = 'testEmailUtility_createEmailMessage';
		Map<String, String> settings = getDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'knowncontact@tanium.com');
		settings.put('ccAddresses', 'knowncontact@account.com');

		// Account
		Map<String, String> accSettings = new Map<String, String>();
		accSettings.put('Name', settings.get('subject'));
		Account testAccount = GetTestAccount(accSettings);
		//insert testAccount;
		testAccount = [SELECT Id FROM Account LIMIT 1];

		// Contact
		Map<String, String> contactSettings = new Map<String, String>();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@account.com');
		Contact testContact = GetTestContact(contactSettings);
		//insert testContact;
		testContact = [SELECT Id FROM Contact WHERE Email = 'roscoapextest2@tanium.com' LIMIT 1];

		// Case
		Map<String, String> caseSettings = new Map<String, String>();
		caseSettings.put('ContactId', testContact.Id);
		caseSettings.put('AccountId', testAccount.Id);
		caseSettings.put('Subject', 'ROSCOTESTCASE');
		Case testCase = GetTestCase(caseSettings);
		//insert testCase;
		testCase = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE' LIMIT 1];

		Messaging.InboundEmail inboundEmail = getTestInboundEmail(settings);
		Messaging.InboundEmail.BinaryAttachment testBin = new Messaging.InboundEmail.BinaryAttachment();
		Messaging.inboundemail.TextAttachment testTxt = new Messaging.InboundEmail.TextAttachment();
		testBin.fileName = 'TestAttachment';
		testTxt.fileName = testBin.fileName;
		testBin.body = Blob.valueOf('Test Attachment Body');
		testTxt.body = 'Test Attachment Body';
		inboundEmail.subject = 'ROSCOTESTCASE';
		inboundEmail.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{ testBin };
		inboundEmail.textAttachments = new List<Messaging.inboundemail.TextAttachment>{ testTxt };
		Messaging.InboundEnvelope inboundEnv = getTestInboundEnvelope(settings);

		Map<String, String> tr = new Map<String, String>();
		RoscoEmailUtility.init(tr, inboundEmail);
		tr.put('caseid', testCase.Id);
		tr.put('slackmap', 'true');
		RoscoEmailUtility.slackDebugLog(tr, inboundEmail, inboundEnv);
		RoscoEmailUtility.emailDebugLog(tr, inboundEmail, inboundEnv);
	}
	@IsTest
	static void testEmailUtility_stripThreadIdFromEmail() {
		Map<String, String> rosco = new Map<String, String>();
		rosco.put('subject', 'test  [ ref:_00D60IYkG._5000e1aqFey:ref ]');
		rosco.put('textbody', 'Hello\\n[ ref:_00D60IYkG._5000e1aqFey:ref ]\\nWorld');
		rosco.put(
			'htmlbody',
			'<html><div>Hello</div><div>test  [ ref:_00D60IYkG._5000e1aqFey:ref ]</div><div>World</div></html>'
		);
		RoscoEmailUtility.stripThreadIdFromEmail(rosco);

		//System.debug(rosco.get('roscolog'));
		//System.assertEquals('test', rosco.get('subject'));
		//System.assertEquals('Hello\n\nWorld', rosco.get('textbody'));
		//System.assertEquals('<html><div>Hello</div><div>test  </div><div>World</div></html>', rosco.get('htmlbody'));

		// hopefully cause exception
		RoscoEmailUtility.stripThreadIdFromEmail(new Map<String, String>());
	}

	@IsTest
	static void test_getAccountFromEmailDomain() {
		Map<String, String> rosco = new Map<String, String>();

		Account acc = TestFactory.buildAccount('roscoapextesting9');
		acc.slack_channel_id__c = 'TESTCASE';
		insert acc;

		rosco_domain__c dom = new rosco_domain__c(
			name = 'foo.com',
			user_automation__c = 'Account Only',
			Auto_register_developer_tanium_com__c = true,
			Account__c = acc.Id
		);
		insert dom;

		rosco_domain__c dom2 = new rosco_domain__c(
			name = 'yahoo.com',
			user_automation__c = 'Account Only',
			Auto_register_developer_tanium_com__c = true,
			Account__c = acc.Id
		);
		insert dom2;

		RoscoEmailUtility.getAccountFromEmailDomain('foo.com');
		RoscoEmailUtility.getAccountFromEmailDomain('yahoo.com');
		RoscoEmailUtility.getAccountFromEmailDomain('barearewrwr.com');
	}

	@IsTest
	static void test_getAccountFromEmail() {
		Map<String, String> rosco = new Map<String, String>();
		RoscoEmailUtility.getAccountFromEmail('test@foo.com');
		RoscoEmailUtility.getAccountFromEmail('user21rosco@yahoo.com');
	}
	@IsTest
	static void test_getAccountId() {
		// Stage data

		String testName = 'testEmailUtility_createEmailMessage';
		Map<String, String> settings = getDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'knowncontact@tanium.com');
		settings.put('ccAddresses', 'knowncontact@account.com');

		// Account
		Map<String, String> accSettings = new Map<String, String>();
		accSettings.put('Name', settings.get('subject'));
		Account testAccount = GetTestAccount(accSettings);
		insert testAccount;

		// Contact
		Map<String, String> contactSettings = new Map<String, String>();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@account.com');
		Contact testContact = GetTestContact(contactSettings);
		insert testContact;

		Map<String, String> rosco = new Map<String, String>();
		rosco.put('people', 'knowncontact@account.com');
		RoscoEmailUtility.getAccountId(rosco);
	}

	@IsTest
	static void test_getAccountIdFromContact() {
		// Stage data

		String testName = 'testEmailUtility_createEmailMessage';
		Map<String, String> settings = getDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'knowncontact@tanium.com');
		settings.put('ccAddresses', 'knowncontact@account.com');

		// Account
		Map<String, String> accSettings = new Map<String, String>();
		accSettings.put('Name', settings.get('subject'));
		Account testAccount = GetTestAccount(accSettings);
		insert testAccount;

		// Contact
		Map<String, String> contactSettings = new Map<String, String>();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@account.com');
		Contact testContact = GetTestContact(contactSettings);
		insert testContact;

		Map<String, String> rosco = new Map<String, String>();
		//RoscoEmailUtility.getAccountIdFromContact(testContact.Id);

		rosco.put('people', 'knowncontact@account.com');
	}

	@IsTest
	static void test_updateCaseStatus() {
		Map<String, String> rosco = new Map<String, String>();
		rosco.put('fromaddress_original', 'test@account.com');

		Case c = [SELECT Id FROM Case WHERE Subject = 'ROSCOTESTCASE'];
		rosco.put('caseid', String.valueOf(c.Id));

		RoscoEmailUtility.updateCaseStatus(rosco);
	}

	@IsTest
	static void test_processDevEmail() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> roscoMap = new Map<String, String>();
			Map<String, String> settings = defaultInboundEmailSettings;

			String emailBody =
				'Ticket Type: Support \n' +
				'Summary: Testing Summary \n' +
				'Company Name: Testing Company \n' +
				'Company BDM: Testing Company BDM \n' +
				'Contact Name: Known Contact \n' +
				'Contact Email: roscoapextest@tanium.com \n' +
				'Original Description: Test Orig Desc \n' +
				'Regards, Tester';
			settings.put('htmlBody', '<html>' + emailBody + '</html>');
			settings.put('fromAddress', 'roscoapextest2@tanium.com');

			Messaging.InboundEmail inboundEmail = getTestInboundEmail(settings);
			Messaging.InboundEnvelope inboundEnv = getTestInboundEnvelope(settings);

			Test.startTest();
			RoscoEmailUtility.init(roscoMap, inboundEmail);
			RoscoEmailUtility.processDevEmail(roscoMap, inboundEmail, inboundEnv);

			Test.stopTest();
		}
	}

	static String getOrgId_ThreadIdOldFormat() {
		return UserInfo.getOrganizationId().left(5) +
			UserInfo.getOrganizationId().left(15).right(10).replace('0', '');
	}

	static String getOrgId_ThreadIdNewFormat() {
		return UserInfo.getOrganizationId().left(6) +
			UserInfo.getOrganizationId().left(15).right(10).replace('0', '');
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