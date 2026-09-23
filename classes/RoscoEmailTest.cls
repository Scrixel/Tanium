@isTest
public class RoscoEmailTest {
	public static String PLCHLDR_TXT1 = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Nunc mattis enim ut tellus elementum sagittis. Turpis cursus in hac habitasse platea dictumst quisque sagittis. Neque ornare aenean euismod elementum nisi quis eleifend. In egestas erat imperdiet sed euismod nisi porta. Ac tincidunt vitae semper quis lectus nulla. In metus vulputate eu scelerisque felis. Facilisis volutpat est velit egestas dui. Pretium vulputate sapien nec sagittis aliquam malesuada bibendum arcu vitae. Id porta nibh venenatis cras sed felis eget velit aliquet.';
	public static String PLCHLDR_TXT2 = 'Quisque egestas diam in arcu cursus euismod. Molestie at elementum eu facilisis sed. Non curabitur gravida arcu ac. A diam maecenas sed enim. Volutpat diam ut venenatis tellus in metus vulputate eu scelerisque. Ultrices dui sapien eget mi proin. Et pharetra pharetra massa massa ultricies mi quis hendrerit. Facilisis mauris sit amet massa vitae tortor condimentum lacinia quis. Augue interdum velit euismod in pellentesque massa. Tellus orci ac auctor augue mauris augue neque. Malesuada fames ac turpis egestas integer eget aliquet nibh praesent. Porta nibh venenatis cras sed felis eget velit. Arcu bibendum at varius vel. Leo integer malesuada nunc vel risus. Gravida quis blandit turpis cursus. Velit dignissim sodales ut eu sem integer vitae justo eget. Lobortis elementum nibh tellus molestie nunc. Amet facilisis magna etiam tempor. Morbi enim nunc faucibus a.';
	public static String PLCHLDR_TXT3 = 'Quis imperdiet massa tincidunt nunc pulvinar sapien et. Nisl rhoncus mattis rhoncus urna neque viverra justo nec. Molestie at elementum eu facilisis. In est ante in nibh mauris cursus mattis molestie. Tempus egestas sed sed risus pretium quam. Nec ullamcorper sit amet risus nullam eget felis eget nunc. Sed libero enim sed faucibus turpis in. Ut sem nulla pharetra diam. Tincidunt ornare massa eget egestas purus. Adipiscing vitae proin sagittis nisl rhoncus mattis rhoncus. Molestie a iaculis at erat pellentesque adipiscing commodo. Proin sagittis nisl rhoncus mattis rhoncus. Cursus in hac habitasse platea dictumst quisque sagittis purus. Augue mauris augue neque gravida in fermentum et sollicitudin. Libero justo laoreet sit amet cursus. Parturient montes nascetur ridiculus mus mauris vitae. Viverra mauris in aliquam sem fringilla ut morbi. Volutpat ac tincidunt vitae semper quis. Nec sagittis aliquam malesuada bibendum arcu vitae elementum curabitur vitae. Scelerisque purus semper eget duis at tellus at urna condimentum.';
	static void CreateRecords() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	@TestSetup
	static void makeData() {
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = new User(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest@roscolab.com',
			Alias = 'xafds',
			CommunityNickname = 'asdfsaafd3',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);

		insert userObj;

		User userObj2 = new User(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser2',
			Username = 'roscoapextest2@roscolab.com',
			Alias = '34343',
			CommunityNickname = '342423',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);

		insert userObj2;
		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			accountObj.Support_Model__c = 'Support Center';
			insert accountObj;

			Contact contactObj = new Contact(
				Email = 'roscoapextest@foo.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = null
			);
			insert contactObj;
			Contact contactObj2 = new Contact(
				Email = 'roscoapextest2@foo.com',
				FirstName = 'Test2',
				LastName = 'Apex',
				AccountId = null
			);
			insert contactObj2;

			String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');

			Case caseObj = new Case(
				ContactId = contactObj.id,
				accountid = accountObj.id,
				ownerid = userObj.id,
				subject = 'ROSCOTESTCASE',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				suppliedEmail = '99@outlook.com',
				LatestPublicCommentHTML__c = '<html>hello</html>',
				Component__c = 'Other',
				RecordTypeId = recordTypeId,
				status = 'On Hold'
			);
			insert caseObj;

			Case caseObjSelect = [SELECT ThreadId_caseSensitive__c FROM CASE LIMIT 1];
			String[] refSplit = String.valueOf(caseObjSelect.ThreadId_caseSensitive__c).split('_');
			String rosco_local_refid_re = '_' + getOrgId_ThreadIdOldFormat() + '[.]_500[0-9A-Za-z]*';

			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Name = '';
			cmSetting.rosco_chronicle_contactid__c =
				String.valueOf(contactObj.Id) +
				',' +
				String.valueOf(contactObj2.Id);
			cmSetting.rosco_create_contacts__c = 'false';
			cmSetting.rosco_check_spam__c = 'true';
			cmSetting.rosco_chronicle_support_address__c = 'chronicle-support@chronicle.security';
			cmSetting.rosco_check_mail_api__c = 'true';
			cmSetting.rosco_notify_tanowneroption__c = 'true';
			cmSetting.rosco_check_auth__c = 'true';
			cmSetting.rosco_local_refid_re__c = rosco_local_refid_re;
			cmSetting.rosco_check_contact_max_create__c = '2';
			insert cmSetting;

			EmailMessage newEmail = new EmailMessage(
				FromAddress = 'rosco@roscolab.com',
				FromName = 'Rosco',
				HtmlBody = 'ROSCOTESTCASE',
				ParentId = caseObj.Id,
				RelatedToId = caseObj.Id,
				Subject = 'ROSOTESTCASE',
				TextBody = 'ROSCOTESTCASE',
				ToAddress = 'rosco@roscolab.com',
				CcAddress = 'rosco2@roscolab.com'
			);
			insert newEmail;

			rosco_people__c peep = new rosco_people__c(
				Name = 'roscotestpeople',
				contact__c = contactObj.Id,
				user__c = userObj.Id,
				pod__c = 'Support Center',
				primary_sme__c = 'SME-Patch',
				secondary_sme__c = 'SME-Map'
			);
			insert peep;

			rosco_people__c peep2 = new rosco_people__c(
				Name = 'roscotestpeople2',
				contact__c = contactObj2.Id,
				user__c = userObj2.Id,
				pod__c = 'Support Center',
				primary_sme__c = 'SME-Patch',
				secondary_sme__c = 'SME-Patch'
			);
			insert peep2;

			rosco_escalation_rbac__c rbac = new rosco_escalation_rbac__c(
				Name = '4',
				authorized__c = userObj.Id
			);
			insert rbac;

			rosco_people__c sme = new rosco_people__c(
				Name = 'slack.name',
				contact__c = contactObj.Id,
				user__c = userObj.Id,
				pod__c = 'Support Center',
				primary_sme__c = 'SME-Patch',
				secondary_sme__c = 'SME-Map'
			);
			insert sme;

			TAM_Team__c team = new TAM_Team__c(
				Name = 'SME-Patch',
				SME_Component_Name__c = 'Workbench-Patch',
				Slack_Ticket_Channel_ID__c = 'CCC66LTRT',
				Slack_Escalation_Channel_ID__c = 'CCC66LTRT'
			);
			insert team;

			TAM_Team__c team2 = new TAM_Team__c(
				Name = 'SME-Chronicle',
				SME_Component_Name__c = 'Workbench-Chronicle',
				Slack_Ticket_Channel_ID__c = 'CCC66LTRT',
				Slack_Escalation_Channel_ID__c = 'CCC66LTRT'
			);
			insert team2;

			Case casecreated = RoscoUtility.getCaseDetails(caseObj.Id);
			List<Case> cases = new List<Case>();
			cases.add(casecreated);

			Map<String, String> sme1 = new Map<String, String>();
			sme1.put('contactid', '003S000001HarLPIAZ');
			sme1.put('slackname', 'adam.caskey.rosco');
			sme1.put('pod', 'Federal');
			sme1.put('contactemail', 'adam.caskey@tanium.com.rosco');
			sme1.put('sme', 'SME-Patch');

			Map<String, String> sme2 = new Map<String, String>();

			List<Map<String, String>> smes = new List<Map<String, String>>();
			smes.add(sme1);
		}
	}

	static Messaging.InboundEmail GetTestInboundEmail(Map<String, String> settings) {
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

	static Messaging.InboundEnvelope GetTestInboundEnvelope(Map<String, String> settings) {
		Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
		envelope.fromAddress = settings.get('fromAddress');
		envelope.toAddress = settings.get('toAddresses');

		return envelope;
	}

	static Account GetTestAccount(Map<String, String> settings) {
		Account accountObj = TestFactory.buildAccount(settings.get('Name'));
		accountObj.OwnerId = UserInfo.getUserId();
		return accountObj;
	}

	static Account GetTestAccount2() {
		Account accountObj = [SELECT Id, Name FROM Account WHERE Name = 'roscoapextestingd'];
		return accountObj;
	}

	static Contact GetTestContact(Map<String, String> settings) {
		return new Contact(
			AccountId = settings.get('AccountId'),
			FirstName = settings.get('FirstName'),
			LastName = settings.get('LastName'),
			Email = settings.get('Email'),
			MailingCountry = 'United States',
			OtherCountry = 'United States'
		);
	}

	static Contact GetTestContact2(String email) {
		Contact contactObj = [SELECT Id, Name, Email FROM Contact WHERE Email = :email];
		return contactObj;
	}

	static Case GetTestCase(Map<String, String> settings) {
		String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');
		return new Case(
			ContactId = settings.get('ContactId'),
			AccountId = settings.get('AccountId'),
			Subject = settings.get('Subject'),
			RecordTypeId = recordTypeId
		);
	}

	static Case GetTestCase2() {
		Case caseObj = [
			SELECT Id, Subject, ThreadId_caseSensitive__c, CaseNumber
			FROM Case
			WHERE Subject = 'ROSCOTESTCASE'
		];
		return CaseObj;
	}

	static Case GetTestCaseClosed(Map<String, String> settings) {
		String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');
		return new Case(
			ContactId = settings.get('ContactId'),
			AccountId = settings.get('AccountId'),
			Subject = settings.get('Subject'),
			Status = 'Closed',
			RecordTypeId = recordTypeId
		);
	}

	public class ProcessedEmail {
		Messaging.InboundEmailResult result;
		EmailMessage msg;
		Case sfcase;
	}

	static ProcessedEmail ProcessTestEmail(
		Messaging.InboundEmail eml,
		Messaging.InboundEnvelope env
	) {
		RoscoEmailHandler handler = new RoscoEmailHandler();
		ProcessedEmail ret = new ProcessedEmail();

		ret.result = handler.handleInboundEmail(eml, env);

		List<EmailMessage> msg = [
			SELECT ParentId
			FROM EmailMessage
			WHERE Subject = :eml.Subject
			LIMIT 1
		];
		ret.msg = msg.size() > 0 ? msg[0] : null;

		if (ret.msg != null) {
			List<Case> c = [
				SELECT AccountId, ContactId
				FROM Case
				WHERE Id = :ret.msg.ParentId
				LIMIT 1
			];
			ret.sfcase = c.size() > 0 ? c[0] : null;
		} else {
			ret.sfcase = null;
		}

		return ret;
	}

	static Map<String, String> GetDefaultInboundEmailSettings() {
		Map<String, String> settings = new Map<String, String>();
		settings.put('toAddresses', 'support@tanium.com,other@tanium.com');
		settings.put('plainTextBody', 'plain old text body\nhello\nworld');
		settings.put('htmlBody', '<html>HTML <ul><li>body</li></ul></html>');

		return settings;
	}

	static Map<String, String> GetHFPOCInboundEmailSettings() {
		Map<String, String> settings = new Map<String, String>();
		settings.put('toAddresses', 'support@tanium.com,other@tanium.com');

		String txt = '[image: logo] HFPOC SUPPORT ALERT! *Submitted 2020-08-13 15:51:52* Hello Team, A new HFPOC support request has just come in (details below). Please follow up ASAP. Thanks, The Tanium Evaluation Team *Contact Details:* SFDC Link: https://tanium.my.salesforce.com/0030e00002NlpBXAAZ Contact Name: Mark TestChow Contact Email: roscoapextest@foo.com Contact Company: Tanium Inc. Contact Phone: 123-123-1234 Preferred Mode of Contact Phone Call Support Request Topic: Sales Inquiries Support Request Question: 2020-08-13 15:51:49 - HFPOC Question: test test again ### 2020-08-13 15:47:13 - HFPOC Question: test5 ### ----------------------------------------------------------------------------------------------------------- [image: Twitter]';

		settings.put('plainTextBody', txt);
		settings.put('htmlBody', '<html>HTML <ul><li>body</li></ul></html>');

		return settings;
	}

	static Map<String, String> GetDevInboundEmailSettings() {
		Map<String, String> settings = new Map<String, String>();
		settings.put('toAddresses', 'support@tanium.com,other@tanium.com');

		String txt = '[image: logo] HFPOC SUPPORT ALERT! *Submitted 2020-08-13 15:51:52* Hello Team, A new HFPOC support request has just come in (details below). Please follow up ASAP. Thanks, The Tanium Evaluation Team *Contact Details:* SFDC Link: https://tanium.my.salesforce.com/0030e00002NlpBXAAZ Contact Name: Mark TestChow Contact Email: mark.chow@tanium.com Contact Company: Tanium Inc. Contact Phone: 123-123-1234 Preferred Mode of Contact Phone Call Support Request Topic: Sales Inquiries Support Request Question: 2020-08-13 15:51:49 - HFPOC Question: test test again ### 2020-08-13 15:47:13 - HFPOC Question: test5 ### ----------------------------------------------------------------------------------------------------------- [image: Twitter]';

		settings.put('plainTextBody', txt);
		settings.put('htmlBody', '<html>HTML <ul><li>body</li></ul></html>');

		return settings;
	}

	static Map<String, String> GetPPOPSInboundEmailSettings() {
		Map<String, String> settings = new Map<String, String>();

		settings.put('toAddresses', 'support@tanium.com,other@tanium.com');
		settings.put('ccAddresses', 'other2@tanium.com');
		settings.put('subject', 'PROOFPOINT_TEST_MAIL');

		String txt = 'blah\nsender:blah@blah.com\nsubject:blah';

		settings.put('plainTextBody', txt);
		settings.put('htmlBody', '<html>HTML <ul><li>body</li></ul></html>');

		return settings;
	}

	static String GetCatchAllCaseId() {
		Map<String, String> ret = new Map<String, String>();
		RoscoEmailUtility.initRoscoDefaults(ret);
		RoscoEmailUtility.initRoscoSettings(ret);
		return ret.get('catch_all_case');
	}

	static String GetAuthenticationEnabled() {
		Map<String, String> ret = new Map<String, String>();
		RoscoEmailUtility.initRoscoDefaults(ret);
		RoscoEmailUtility.initRoscoSettings(ret);
		return ret.get('check_auth');
	}

	static Map<String, String> GetRoscoSettings(List<String> settings) {
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
		return GetRoscoSettings(settings);
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_HFPOC() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_StandardCase-ROSCOTESTCASE';
		Map<String, String> settings = GetHFPOCInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', 'HFPOC Contact Request Alert ' + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'marketing-operations@tanium.com');

		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEmail.BinaryAttachment testBin = new Messaging.InboundEmail.BinaryAttachment();
		Messaging.inboundemail.TextAttachment testTxt = new Messaging.InboundEmail.TextAttachment();
		testBin.fileName = 'TestAttachment';
		testTxt.fileName = testBin.fileName;
		testBin.body = Blob.valueOf('Test Attachment Body');
		testTxt.body = 'Test Attachment Body';
		inboundEmail.subject = 'HFPOC Contact Request Alert ROSCOTESTCASE';
		inboundEmail.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{ testBin };
		inboundEmail.textAttachments = new List<Messaging.inboundemail.TextAttachment>{ testTxt };

		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_PPS() {
		// Stage data
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.setMock(HttpCalloutMock.class, new mockCallout());
			String testName = 'testEmailHandler_StandardCase-ROSCOTESTCASE';
			Map<String, String> settings = GetPPOPSInboundEmailSettings();
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			settings.put('subject', 'PROOFPOINT_TEST_MAIL');
			settings.put('subject_original', 'PROOFPOINT_TEST_MAIL');
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'proofpoint-pps@ppos.net');

			Account testAccount = GetTestAccount2();

			Contact testContact = GetTestContact2('roscoapextest@foo.com');

			Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
			Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

			ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

			Map<String, String> roscoSettings = GetRoscoCaseSettings();
		}
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Support() {
		// Stage data
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.setMock(HttpCalloutMock.class, new mockCallout());
			String testName = 'testEmailHandler_StandardCase-ROSCOTESTCASE';
			Map<String, String> settings = GetPPOPSInboundEmailSettings();
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			settings.put('subject', 'subject:xyz ' + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'support@tanium.com');

			// Account
			Account testAccount = getTestAccount2();
			Contact testContact = GetTestContact2('roscoapextest@foo.com');

			Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
			Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

			ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

			Map<String, String> roscoSettings = GetRoscoCaseSettings();
		}
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_SPAM() {
		// Stage data
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_StandardCase-ROSCOTESTCASE';
		Map<String, String> settings = GetHFPOCInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', 'HFPOC Contact Request Alert ' + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'voice-noreply@google.com	');

		// Account
		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

		Map<String, String> roscoSettings = GetRoscoCaseSettings();
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Gen_KnownCustomerContact() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.setMock(HttpCalloutMock.class, new mockCallout());
			String testName = 'testEmailHandler_StandardCase-ROSCOTESTCASE';
			Map<String, String> settings = GetDefaultInboundEmailSettings();
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			settings.put('subject', testName + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'knowncontact@hotmail.com');

			// Account
			Account testAccount = getTestAccount2();
			Contact testContact = GetTestContact2('roscoapextest@foo.com');

			Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
			Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

			ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

			Map<String, String> roscoSettings = GetRoscoCaseSettings();
		}
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Gen_TaniumContact_ToSupportWithCustomerContactCC() {
		// Stage data
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.setMock(HttpCalloutMock.class, new mockCallout());
			String testName = 'testEmailHandler_Gen_TaniumContact_ToSupportWithCustomerContactCC-ROSCOTESTCASE';
			Map<String, String> settings = GetDefaultInboundEmailSettings();
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			settings.put('subject', testName + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'knowncontact@tanium.com');
			settings.put('ccAddresses', 'knowncontact@hotmail.com');

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
			contactSettings.put('Email', 'knowncontact@hotmail.com');
			Contact testContact = GetTestContact(contactSettings);
			insert testContact;

			Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
			Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

			ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

			Map<String, String> roscoSettings = GetRoscoCaseSettings();
		}
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Gen_UnknownSender() {
		// Stage data
		////CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_CatchAll';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'unknown' + randomness + '@account' + randomness + '.com');

		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

		Map<String, String> roscoSettings = GetRoscoCaseSettings();
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Assoc_RefId_ContactMatchingCaseContact() {
		// Stage data
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.setMock(HttpCalloutMock.class, new mockCallout());
			String testName = 'testEmailHandler_Assoc_RefId_ContactMatchingCaseContact-ROSCOTESTCASE';
			Map<String, String> settings = GetDefaultInboundEmailSettings();
			String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
			settings.put('subject', testName + randomness);
			settings.put('TestName', settings.get('subject'));
			settings.put('fromAddress', 'roscoapextest@foo.com');

			// Account
			Account testAccount = getTestAccount2();
			Contact testContact = GetTestContact2('roscoapextest@foo.com');

			Case testCase = GetTestCase2();
			testCase.Status = 'Closed';
			update testCase;

			settings.put(
				'subject',
				settings.get('subject') + ' ' + testCase.ThreadId_caseSensitive__c
			);
			Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
			Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

			ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

			Map<String, String> roscoSettings = GetRoscoCaseSettings();
		}
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Assoc_RefId_ContactMatchingCaseAccount() {
		// Stage data
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_Assoc_RefId_ContactMatchingCaseAccount-ROSCOTESTCASE';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'othercontact@hotmail.com');

		// Account
		Account testAccount = getTestAccount2();
		Contact testContact1 = GetTestContact2('roscoapextest@foo.com');
		Contact testContact2 = GetTestContact2('roscoapextest2@foo.com');

		// Case
		Case testCase = GetTestCase2();
		settings.put('subject', settings.get('subject') + ' ' + testCase.ThreadId_caseSensitive__c);
		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

		Map<String, String> roscoSettings = GetRoscoCaseSettings();
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Assoc_RefId_UnknownSender() {
		// Stage data
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_Assoc_RefId_UnknownSender';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'unknown' + randomness + '@account' + randomness + '.com');

		// Contact
		Map<String, String> contactSettings = new Map<String, String>();
		Account testAccount = getTestAccount2();
		contactSettings.put('AccountId', testAccount.Id);
		contactSettings.put('FirstName', 'known');
		contactSettings.put('LastName', 'contact');
		contactSettings.put('Email', 'knowncontact@hotmail.com');
		Contact testContact = GetTestContact(contactSettings);
		insert testContact;
		testContact = GetTestContact2('roscoapextest@foo.com');

		// Case

		Case testCase = getTestCase2();

		settings.put('subject', settings.get('subject') + ' ' + testCase.ThreadId_caseSensitive__c);
		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

		Map<String, String> roscoSettings = GetRoscoCaseSettings();
		// Ref ID allows email to join thread without need for contact identification
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Assoc_CaseNum_ContactMatchingCaseContact() {
		// Stage data
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_Assoc_CaseNum_ContactMatchingCaseContact-ROSCOTESTCASE';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'roscoapextest@foo.com');

		// Account
		Account testAccount = getTestAccount2();
		Contact testContact = GetTestContact2('roscoapextest@foo.com');

		// Case
		Case testCase = GetTestCase2();

		settings.put('subject', settings.get('subject') + ' ' + testCase.CaseNumber);
		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

		Map<String, String> roscoSettings = GetRoscoCaseSettings();
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Assoc_CaseNum_ContactMatchingCaseAccount() {
		// Stage data
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_Assoc_CaseNum_ContactMatchingCaseAccount-ROSCOTESTCASE';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'othercontact@hotmail.com');
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Assoc_SubjectBody_ContactMatchingCaseContact() {
		// Stage data
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_Assoc_SubjectBody_ContactMatchingCaseContact-ROSCOTESTCASE';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'roscoapextest@foo.com');
		settings.put('fromName', 'Known Contact');

		// Account
		Account testAccount = getTestAccount2();
		Contact testContact = GetTestContact2('roscoapextest@foo.com');

		Case testCase = GetTestCase2();

		// Email Message to start case
		Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
		hd.name = 'X-TestName';
		hd.value = settings.get('TestName');
		EmailMessage testCaseEmail = new EmailMessage(
			textBody = PLCHLDR_TXT1,
			htmlBody = '<html><ol><li>' + PLCHLDR_TXT1 + '</li></ol></html>',
			subject = settings.get('subject'),
			fromName = settings.get('fromName'),
			fromAddress = settings.get('fromAddress'),
			ToAddress = settings.get('toAddresses'),
			CcAddress = settings.get('ccAddresses'),
			Headers = hd.name + ': ' + hd.value,
			relatedToId = testCase.Id,
			incoming = true
		);
		insert testCaseEmail;

		// This is the setup for an email responding to an existing case email
		//   Arrange response first, with quoted original email after
		settings.put('plainTextBody', PLCHLDR_TXT2 + '\n' + PLCHLDR_TXT1);
		settings.put(
			'htmlBody',
			'<html><ol><li>' + PLCHLDR_TXT2 + '</li><li>' + PLCHLDR_TXT1 + '</li></ol></html>'
		);
		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);

		Map<String, String> roscoSettings = GetRoscoCaseSettings();
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_Assoc_SubjectBody_ContactMatchingCaseAccount() {
		// Stage data
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		String testName = 'testEmailHandler_Assoc_SubjectBody_ContactMatchingCaseAccount-ROSCOTESTCASE';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'othercontact@hotmail.com');
		settings.put('fromName', 'Other Contact');

		// Account
		Contact testContact1 = GetTestContact2('roscoapextest@foo.com');
		Case testCase = GetTestCase2();

		// Email Message to start case
		Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
		hd.name = 'X-TestName';
		hd.value = settings.get('TestName');
		EmailMessage testCaseEmail = new EmailMessage(
			textBody = PLCHLDR_TXT1,
			htmlBody = '<html><ol><li>' + PLCHLDR_TXT1 + '</li></ol></html>',
			subject = settings.get('subject'),
			fromName = testContact1.Name,
			fromAddress = testContact1.Email,
			ToAddress = settings.get('toAddresses'),
			CcAddress = settings.get('ccAddresses'),
			Headers = hd.name + ': ' + hd.value,
			relatedToId = testCase.Id,
			incoming = true
		);
		insert testCaseEmail;

		// This is the setup for an email responding to an existing case email
		//   Arrange response first, with quoted original email after
		settings.put('plainTextBody', PLCHLDR_TXT2 + '\n' + PLCHLDR_TXT1);
		settings.put(
			'htmlBody',
			'<html><ol><li>' + PLCHLDR_TXT2 + '</li><li>' + PLCHLDR_TXT1 + '</li></ol></html>'
		);
		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);
	}

	@isTest(SeeAllData=false)
	static void testEmailUtility_slackDebugLog() {
		// Stage data
		String testName = 'testEmailUtility_createEmailMessage-ROSCOTESTCASE';
		Map<String, String> settings = GetDefaultInboundEmailSettings();
		String randomness = String.valueOf(Math.random()).abbreviate(10).replace('.', '');
		settings.put('subject', testName + randomness);
		settings.put('TestName', settings.get('subject'));
		settings.put('fromAddress', 'knowncontact@tanium.com');
		settings.put('ccAddresses', 'knowncontact@hotmail.com');

		// Account

		Account testAccount = getTestAccount2();
		Contact testContact = GetTestContact2('roscoapextest@foo.com');

		// Case
		Map<String, String> caseSettings = new Map<String, String>();
		caseSettings.put('ContactId', testContact.Id);
		caseSettings.put('AccountId', testAccount.Id);
		caseSettings.put('Subject', 'ROSCOTESTCASE');
		Case testCase = GetTestCase(caseSettings);
		insert testCase;

		Messaging.InboundEmail inboundEmail = GetTestInboundEmail(settings);
		Messaging.InboundEmail.BinaryAttachment testBin = new Messaging.InboundEmail.BinaryAttachment();
		Messaging.inboundemail.TextAttachment testTxt = new Messaging.InboundEmail.TextAttachment();
		testBin.fileName = 'TestAttachment';
		testTxt.fileName = testBin.fileName;
		testBin.body = Blob.valueOf('Test Attachment Body');
		testTxt.body = 'Test Attachment Body';
		inboundEmail.subject = 'ROSCOTESTCASE';
		inboundEmail.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{ testBin };
		inboundEmail.textAttachments = new List<Messaging.inboundemail.TextAttachment>{ testTxt };
		Messaging.InboundEnvelope inboundEnv = GetTestInboundEnvelope(settings);

		Map<String, String> tr = new Map<String, String>();
		RoscoEmailUtility.init(tr, inboundEmail);
		tr.put('caseid', testCase.Id);
		RoscoEmailUtility.slackDebugLog(tr, inboundEmail, inboundEnv);
		RoscoEmailUtility.emailDebugLog(tr, inboundEmail, inboundEnv);
	}
	@isTest(SeeAllData=false)
	static void testEmailHandler_codecov() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();
		Messaging.InboundEnvelope inboundEnv = new Messaging.InboundEnvelope();

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_chronicle() {
		Case c = [SELECT CaseNumber FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();
		inboundEmail.subject = 'ROSCOTESTCASE 123456:' + c.CaseNumber;
		inboundEmail.fromAddress = 'chronicle-support@chronicle.security';
		inboundEmail.fromName = 'Constellant';
		inboundEmail.toAddresses = new List<String>{ 'support@tanium.com' };

		Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
		hd.name = 'X-TestName';
		hd.value = 'foo';
		inboundEmail.headers = new List<Messaging.InboundEmail.Header>{ hd };

		inboundEmail.plainTextBody = 'This is an automated message';
		inboundEmail.plainTextBodyIsTruncated = false;
		inboundEmail.htmlBody = ' This is an automated message ';
		inboundEmail.htmlBodyIsTruncated = false;

		Messaging.InboundEnvelope inboundEnv = new Messaging.InboundEnvelope();
		inboundEnv.fromAddress = 'chronicle-support@chronicle.security';
		inboundEnv.toAddress = 'support@tanium.com';

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);
	}

	static void testEmailHandler_chronicle2() {
		Case c = [SELECT CaseNumber FROM Case WHERE Subject = 'ROSCOTESTCASE'];

		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();
		inboundEmail.subject = 'ROSCOTESTCASE 123456:' + c.CaseNumber;
		inboundEmail.fromAddress = 'chronicle-support@chronicle.security';
		inboundEmail.fromName = 'Constellant';
		inboundEmail.toAddresses = new List<String>{ 'support@tanium.com' };

		Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
		hd.name = 'X-TestName';
		hd.value = 'foo';
		inboundEmail.headers = new List<Messaging.InboundEmail.Header>{ hd };

		inboundEmail.plainTextBody = 'wrong';
		inboundEmail.plainTextBodyIsTruncated = false;
		inboundEmail.htmlBody = ' This is an automated message ';
		inboundEmail.htmlBodyIsTruncated = false;

		Messaging.InboundEnvelope inboundEnv = new Messaging.InboundEnvelope();
		inboundEnv.fromAddress = 'chronicle-support@chronicle.security';
		inboundEnv.toAddress = 'support@tanium.com';

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_dev() {
		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();
		inboundEmail.subject = 'NEW: Ticket 25 ROSCOTESTCASE';
		inboundEmail.fromAddress = 'do-not-reply@developer.tanium.com';
		inboundEmail.fromName = 'Constellant';
		inboundEmail.toAddresses = new List<String>{ 'support@tanium.com' };

		Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
		hd.name = 'X-TestName';
		hd.value = 'foo';
		inboundEmail.headers = new List<Messaging.InboundEmail.Header>{ hd };

		inboundEmail.plainTextBody = '';
		inboundEmail.plainTextBodyIsTruncated = false;
		inboundEmail.htmlBody = '<table><tbody><tr><td width="685px"><br><br><!--End Header -->This is to inform you that <a href="https://developer.tanium.com/dpTroubleTicket/edit/17">Ticket 17</a> has been created with the following information: <br><br> <strong style="color:#CC0000;">TICKET INFORMATION</strong><br> <strong>Ticket Type:</strong> Support Ticket<br> <strong>Summary:</strong> TEST FROM Jason Johnson3<br> <br><strong style="color:#CC0000;">CONTACT INFORMATION</strong><br> <strong>Company Name:</strong> Support:Rosco Outlook (Tanium Smoke Testing)<br> <strong>Company BDM:</strong> <i>None</i><br><br> <strong>Contact Name:</strong> Ninety Nine TEST<br> <strong>Contact Email:</strong> 99@outlook.com<br><br> To respond, you can log into the system to view this ticket and its history by clicking <a href="https://developer.tanium.com/dpTroubleTicket/edit/17">here</a>. <br><br> <strong style="color:#CC0000;">Original Description:</strong><br> <pre>Description3</pre> <br><br><!-- Begin Footer--><br><br>Regards,<br><strong><a href="https://developer.tanium.com">Tanium Developer Portal</a></span></td></tr></tbody></table>';

		inboundEmail.htmlBodyIsTruncated = false;

		Messaging.InboundEnvelope inboundEnv = new Messaging.InboundEnvelope();
		inboundEnv.fromAddress = 'do-not-reply@developer.tanium.com';
		inboundEnv.toAddress = 'support@tanium.com';

		ProcessedEmail processed = ProcessTestEmail(inboundEmail, inboundEnv);
	}

	@isTest(SeeAllData=false)
	static void testEmailHandler_jj() {
		Messaging.InboundEmail email = new Messaging.InboundEmail();
		email.subject = 'ROSCOTESTCASE';
		email.fromAddress = 'test@hotmail.com';
		email.fromName = 'test@hotmail.com';

		List<String> to = new List<String>();
		to.add('test@hotmail.com');
		email.toAddresses = to;

		Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
		hd.name = 'X-TestName';
		hd.value = 'foo';
		email.headers = new List<Messaging.InboundEmail.Header>{ hd };

		email.plainTextBody = 'text 1, 2, 3';
		email.plainTextBodyIsTruncated = false;
		email.htmlBody = 'text 1, 2, 3';
		email.htmlBodyIsTruncated = false;

		Messaging.InboundEmail.BinaryAttachment testBin = new Messaging.InboundEmail.BinaryAttachment();
		Messaging.inboundemail.TextAttachment testTxt = new Messaging.InboundEmail.TextAttachment();
		testBin.fileName = 'TestAttachment';
		testTxt.fileName = testBin.fileName;
		testBin.body = Blob.valueOf('Test Attachment Body');
		testTxt.body = 'Test Attachment Body';
		email.binaryAttachments = new List<Messaging.InboundEmail.BinaryAttachment>{ testBin };
		email.textAttachments = new List<Messaging.inboundemail.TextAttachment>{ testTxt };

		Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
		envelope.fromAddress = 'test@hotmail.com';
		envelope.toAddress = 'test@hotmail.com';

		RoscoEmailHandler handler = new RoscoEmailHandler();
		handler.handleInboundEmail(email, envelope);
	}

	static String getOrgId_ThreadIdOldFormat() {
		return UserInfo.getOrganizationId().left(5) +
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