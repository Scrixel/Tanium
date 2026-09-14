/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test Class for RoscoCmtyDevReg
 * @Date: UNKNOWN
 * @Authors: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13085   2026-04-23    Fixed issue with tests failing because of validation on Account insert
 * SS-13591   2026-07-14    Add security measure for recaptcha validation to prevent bot vulnerabilities
 * SS-13630   2026-07-16    Added coverage for reCAPTCHA changes
 */
@IsTest
public with sharing class RoscoCmtyDevRegTest {
	private static String firstName = 'FirstName1';
	private static String lastName = 'LastName1';
	private static String nickName = 'NickName1';
	private static String email = 'EmailA@foo.com';
	private static String phone = '5551231234';
	private static String companyName = 'CompanyName1';
	private static String companyURL = 'CompanyURL1';
	private static String companyDescription = 'CompanyDescription1';
	private static String companyAddress = 'CompanyAddress1';
	private static String companyAddress2 = 'CompanyAddress2';
	private static String companyAddressCity = 'companyAddressCity';
	private static String companyAddressState = 'companyAddressState';
	private static String companyAddressCountry = 'companyAddressCountry';
	private static String companyAddressZip = 'companyAddressZip';
	private static String companyReason = 'companyReason';
	private static String recaptchaResponse = '123';
	public static List<Trigger_Management__c> tm { get; set; }

	@TestSetup
	static void makeData() {
		Site_User_Blacklisted_Domains__c setting = new Site_User_Blacklisted_Domains__c();
		setting.Name = '0-mail.com';
		insert setting;

		reCaptchaGoogle__c recaptchaConfig = reCaptchaGoogle__c.getOrgDefaults();
		recaptchaConfig.endPoint__c = 'testendpointurl';
		recaptchaConfig.secretKey__c = 'testsecretkey';
		recaptchaConfig.libraryUrl__c = 'testlibraryurl';
		recaptchaConfig.siteKey__c = 'testsitekey';
		upsert recaptchaConfig;
	}

	@IsTest
	static void test_Unit_createContact() {
		Account account = TestFactory.buildAccount('Tanium Support Transitory');
		insert account;

		RoscoCmtyDevReg.createContact(firstName, lastName, email, phone, account.Id);
		RoscoCmtyDevReg.createContact(firstName, lastName, '\'', phone, account.Id); //exception
	}

	@IsTest
	static void test_Unit_createDevRegCase() {
		User user = [
			SELECT Id
			FROM User
			WHERE isActive = TRUE AND Profile.Name = 'System Administrator'
			LIMIT 1
		];

		System.runAs(user) {
			Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
			Test.startTest();

			Group testGroup = new Group(Name = 'Technical Partnerships', Type = 'Queue');
			insert testGroup;
			QueuesObject testQueue = new QueueSObject(QueueID = testGroup.id, SObjectType = 'Case');
			insert testQueue;

			RoscoCmtyDevReg.createDevRegCase(
				'Registration-New Partner',
				firstName,
				lastName,
				nickName,
				email,
				phone,
				companyName,
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason
			);
			RoscoCmtyDevReg.createDevRegCase(
				'Registration-New Partner',
				firstName,
				lastName,
				nickName,
				'\'',
				phone,
				companyName,
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason
			);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_Unit_createUser() {
		Account account = TestFactory.buildAccount('Tanium Support Transitory');
		insert account;

		String contactId = RoscoCmtyDevReg.createContact(
			firstName,
			lastName,
			email,
			phone,
			account.Id
		);
		String accountId = RoscoCmtyDevReg.getAccountIdFromContact(email);
		RoscoCmtyDevReg.createUser(firstName, lastName, nickName, email, contactId, accountId);
		RoscoCmtyDevReg.createUser(firstName, lastName, nickName, '\'', contactId, accountId); // exception
	}

	@IsTest
	static void test_Unit_createUserPostProcessing() {
		Account account = TestFactory.buildAccount('Tanium Support Transitory');
		insert account;

		String contactId = RoscoCmtyDevReg.createContact(
			firstName,
			lastName,
			email,
			phone,
			account.Id
		);
		String accountId = RoscoCmtyDevReg.getAccountIdFromContact(email);
		String userId = RoscoCmtyDevReg.createUser(
			firstName,
			lastName,
			nickName,
			email,
			contactId,
			accountId
		);
		RoscoCmtyDevReg.createUserPostProcessing(userId, email);
		RoscoCmtyDevReg.createUserPostProcessing(userId, '\''); //exception
	}

	@IsTest
	static void test_Unit_getAccountId() {
		Account account = TestFactory.buildAccount('Tanium Support Transitory');
		insert account;

		String contactId = RoscoCmtyDevReg.createContact(
			firstName,
			lastName,
			email,
			phone,
			account.Id
		);
		String accountId = RoscoCmtyDevReg.getAccountIdFromContact(email);
		RoscoCmtyDevReg.getAccountIdFromContact('\'');
	}

	@IsTest
	static void test_Unit_getCountryCodes() {
		RoscoCmtyDevReg.getCountryCodes();
	}

	@IsTest
	static void test_Unit_getDevRegInit() {
		RoscoCmtyDevReg.getDevRegInit();
	}

	@IsTest
	static void test_Unit_getSupportEmail() {
		RoscoCmtyDevReg.getSupportEmail();
	}

	@IsTest
	static void test_Unit_isExistingNickName() {
		RoscoCmtyDevReg.isExistingNickName(nickName);
		RoscoCmtyDevReg.isExistingNickName('\''); //exception
	}

	@IsTest
	static void test_Unit_isEmailDomainBlacklisted() {
		RoscoCmtyDevReg.isEmailDomainBlacklisted(email);
		RoscoCmtyDevReg.isEmailDomainBlacklisted('\''); //exception
	}

	@IsTest
	static void test_Unit_isExistingUser() {
		RoscoCmtyDevReg.isExistingUser(email);
		RoscoCmtyDevReg.isExistingUser('\'');
	}

	@IsTest
	static void test_Unit_modifyUser() {
		Account account = TestFactory.buildAccount('Tanium Support Transitory');
		insert account;

		String contactId = RoscoCmtyDevReg.createContact(
			firstName,
			lastName,
			email,
			phone,
			account.Id
		);
		String accountId = RoscoCmtyDevReg.getAccountIdFromContact(email);
		RoscoCmtyDevReg.createUser(firstName, lastName, nickName, email, contactId, accountId);
		RoscoCmtyDevReg.modifyUser(firstName, lastName, 'fooooo', email, contactId, accountId);
		RoscoCmtyDevReg.modifyUser(firstName, lastName, 'fooooo', '\'', contactId, accountId); //exception
	}

	@IsTest
	static void test_Unit_nullOrEmpty() {
		RoscoCmtyDevReg.nullOrEmpty('');
	}

	@IsTest
	static void test_Unit_processDevRegistration() {
		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		RoscoCmtyDevReg.processDevRegistration(
			firstName,
			lastName,
			nickName,
			email,
			phone,
			companyName,
			companyURL,
			companyDescription,
			companyAddress,
			companyAddress2,
			companyAddressCity,
			companyAddressState,
			companyAddressZip,
			companyAddressCountry,
			companyReason,
			recaptchaResponse
		);
		RoscoCmtyDevReg.processDevRegistration(
			firstName,
			lastName,
			nickName,
			'\'',
			phone,
			companyName,
			companyURL,
			companyDescription,
			companyAddress,
			companyAddress2,
			companyAddressCity,
			companyAddressState,
			companyAddressZip,
			companyAddressCountry,
			companyReason,
			recaptchaResponse
		);
		Test.stopTest();
	}

	@IsTest
	static void test_Unit_slackInfo() {
		RoscoCmtyDevReg.slackInfo('test_Unit_slackInfo');
	}

	@IsTest
	static void test_Unit_verifyCaptcha() {
		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		RoscoCmtyDevReg.verifyCaptcha(recaptchaResponse);
		Test.stopTest();
	}

	@IsTest
	static void testProcessDevRegistration_UnknownCompanyPreCheck_DoesNotVerifyCaptcha() {
		String email4 = '4' + email;
		User customerCommunityuser = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];

		Test.startTest();
		System.runAs(customerCommunityuser) {
			Integer calloutsBeforePreCheck = Limits.getCallouts();
			String preCheckResponse = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email4,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			Assert.areEqual(
				'Unknown email domain',
				preCheckResponse,
				'Pre-check with no company info returns before verifying the recaptcha token'
			);
			Assert.areEqual(
				calloutsBeforePreCheck,
				Limits.getCallouts(),
				'Pre-check should not call out to verify the recaptcha token'
			);
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_2_ExistingUserNotLoggedIn() {
		Account account = TestFactory.buildAccount('roscoapextestingA');
		account.slack_channel_id__c = 'TESTCASE';
		insert account;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = account.Id
		);
		insert contactObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;
		User newU = new User(
			Email = email,
			FirstName = firstName,
			LastName = lastName,
			UserName = email,
			Alias = nickName.substring(0, 7),
			CommunityNickName = nickName,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert newU;

		User u = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];
		System.runAs(u) {
			Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
			Test.startTest();
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			Test.stopTest();
			System.assertEquals('Can not be modified unless logged in', response);
		}
	}

	@IsTest
	static void testProcessDevRegistration_ExistingUserWithoutLogin_StillRequiresCaptcha() {
		User user = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];
		String response;
		System.runAs(user) {
			Test.startTest();
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email,
				phone,
				companyName,
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				''
			);
			Test.stopTest();
		}
		Assert.areEqual(
			'Captcha failed',
			response,
			'Existing-user rejection must still require a valid recaptcha token, not be reachable for free'
		);
	}

	@IsTest
	static void test_Scenario_3_UserLoggedInNotMatchEmail() {
		Account account = TestFactory.buildAccount('roscoapextestingA');
		account.slack_channel_id__c = 'TESTCASE';
		insert account;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = account.Id
		);
		insert contactObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;
		String emailExisting = 'override@foo.com';
		String nickNameExisting = 'overridefoo';
		User newU = new User(
			Email = emailExisting,
			FirstName = firstName,
			LastName = lastName,
			UserName = email,
			Alias = nickNameExisting.substring(0, 7),
			CommunityNickName = nickNameExisting,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert newU;

		User u = [SELECT Id FROM User WHERE Id = :newU.Id];
		System.runAs(u) {
			Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
			Test.startTest();
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			Test.stopTest();
			System.assertEquals('Can not modify other users', response);
		}
	}

	@IsTest
	static void test_Scenario_4_Blacklisted() {
		String emailHotmail = 'foo@0-mail.com';

		User u = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(u) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				emailHotmail,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals('Please use corporate domain', response);
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_4_Blacklisted_Part2() {
		String emailHotmail = 'foo@0-mail.com';

		Account account = TestFactory.buildAccount('roscoapextestingA');
		account.slack_channel_id__c = 'TESTCASE';
		insert account;

		Contact contactObj = new Contact(
			Email = emailHotmail,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = account.Id
		);
		insert contactObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;
		User newU = new User(
			Email = emailHotmail,
			FirstName = firstName,
			LastName = lastName,
			UserName = email,
			Alias = nickName.substring(0, 7),
			CommunityNickName = nickName,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert newU;

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(newU) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				emailHotmail,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals('Please use corporate domain', response);
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_5_UnknownEmailDomain() {
		String email2 = '2' + email;

		User u = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(u) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email2,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals('Unknown email domain', response);
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_5_UnknownEmailDomain_Part2() {
		String email3 = '3' + email;
		Account account = TestFactory.buildAccount('UnknownEmailDomain');
		account.slack_channel_id__c = 'TESTCASE';
		insert account;

		Contact contactObj = new Contact(
			Email = email3,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = account.Id
		);
		insert contactObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;
		User newU = new User(
			Email = email3,
			FirstName = firstName,
			LastName = lastName,
			UserName = email3,
			Alias = nickName.substring(0, 7),
			CommunityNickName = nickName,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert newU;

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(newU) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email3,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals('Unknown email domain', response);
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_6_UnknownEmailDomainInfoProvided() {
		String email2 = '1' + email;
		User u = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(u) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email2,
				phone,
				companyName,
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals(true, response.contains('createDevRegCase returned'));
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_6_UnknownEmailDomainInfoProvided_Part2() {
		String email3 = '3' + email;
		Account account = TestFactory.buildAccount('UnknownEmailDomain2');
		account.slack_channel_id__c = 'TESTCASE';
		insert account;

		Contact contactObj = new Contact(
			Email = email3,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = account.Id
		);
		insert contactObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;
		User newU = new User(
			Email = email3,
			FirstName = firstName,
			LastName = lastName,
			UserName = email3,
			Alias = nickName.substring(0, 7),
			CommunityNickName = nickName,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert newU;

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(newU) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email3,
				phone,
				companyName,
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals(true, response.contains('createDevRegCase returned'));
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_7_KnownEmailDomainAccountMatchExistingUser() {
		Account account = TestFactory.buildAccount('roscoapextestingA');
		account.slack_channel_id__c = 'TESTCASE';
		insert account;

		List<String> aEmail = email.split('@');
		String domain = aEmail[1];

		Rosco_domain__c rd = new Rosco_domain__c();
		rd.Name = domain;
		rd.Account__c = account.Id;
		rd.Auto_register_developer_tanium_com__c = true;
		rd.user_automation__c = 'Account Only';
		insert rd;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = account.Id
		);
		insert contactObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;
		User newU = new User(
			Email = email,
			FirstName = firstName,
			LastName = lastName,
			UserName = email,
			Alias = nickName.substring(0, 7),
			CommunityNickName = nickName,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert newU;

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(newU) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals(true, response.contains('modifyUser returned:'));
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_8_KnownEmailDomainAccountMatchNoUser() {
		Account account = TestFactory.buildAccount('roscoapextestingA');
		account.slack_channel_id__c = 'TESTCASE';
		insert account;

		List<String> aEmail = email.split('@');
		String domain = aEmail[1];

		Rosco_domain__c rd = new Rosco_domain__c();
		rd.Name = domain;
		rd.Account__c = account.Id;
		rd.Auto_register_developer_tanium_com__c = true;
		rd.user_automation__c = 'Account Only';
		insert rd;

		User u = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];
		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(u) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email,
				phone,
				'',
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals(true, response.contains('createUser returned'));
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_9_KnownEmailDomainAccountMisMatch() {
		Account accountA = TestFactory.buildAccount('RoscoTestAccount');
		insert accountA;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountA.Id
		);
		insert contactObj;

		Account accountB = TestFactory.buildAccount('RoscoTestAccountB');
		insert accountB;

		List<String> aEmail = email.split('@');
		String domain = aEmail[1];

		Rosco_domain__c rd = new Rosco_domain__c();
		rd.Name = domain;
		rd.Account__c = accountB.Id;
		rd.Auto_register_developer_tanium_com__c = true;
		rd.user_automation__c = 'Account Only';
		insert rd;

		User u = [
			SELECT Id
			FROM User
			WHERE Name = 'Tanium Customer Community Site Guest User'
			LIMIT 1
		];

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(u) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email,
				phone,
				companyName,
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals(true, response.contains('createDevRegCase returned'));
		}
		Test.stopTest();
	}

	@IsTest
	static void test_Scenario_9_KnownEmailDomainAccountMisMatch_Part2() {
		Account accountA = TestFactory.buildAccount('RoscoTestAccount');
		insert accountA;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountA.Id
		);
		insert contactObj;

		Account accountB = TestFactory.buildAccount('RoscoTestAccountB');
		insert accountB;

		List<String> aEmail = email.split('@');
		String domain = aEmail[1];

		Rosco_domain__c rd = new Rosco_domain__c();
		rd.Name = domain;
		rd.Account__c = accountB.Id;
		rd.Auto_register_developer_tanium_com__c = true;
		rd.user_automation__c = 'Account Only';
		insert rd;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown'].Id;
		User newU = new User(
			Email = email,
			FirstName = firstName,
			LastName = lastName,
			UserName = email,
			Alias = nickName.substring(0, 7),
			CommunityNickName = nickName,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert newU;

		Test.setMock(HttpCalloutMock.class, new RecaptchaSiteVerifyMock(true));
		Test.startTest();
		System.runAs(newU) {
			String response = '';
			response = RoscoCmtyDevReg.processDevRegistration(
				firstName,
				lastName,
				nickName,
				email,
				phone,
				companyName,
				companyURL,
				companyDescription,
				companyAddress,
				companyAddress2,
				companyAddressCity,
				companyAddressState,
				companyAddressZip,
				companyAddressCountry,
				companyReason,
				recaptchaResponse
			);
			System.assertEquals(true, response.contains('createDevRegCase returned'));
		}
		Test.stopTest();
	}

	private class RecaptchaSiteVerifyMock implements HttpCalloutMock {
		private Boolean success;
		public RecaptchaSiteVerifyMock(Boolean success) {
			this.success = success;
		}
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(200);
			res.setBody('{"success": ' + success + '}');
			return res;
		}
	}
}