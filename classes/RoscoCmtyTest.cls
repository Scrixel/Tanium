/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoCmty (community app support).
 * @Date: 1/25/2021
 * @Authors: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12751   2026-03-04    Refactored class: removed SeeAllData, added test setup, runAs admin with validations/flows off
 * SS-13075   2026-04-21    Changed FCRM__FCR_Admin_Originating_Contact__c to Primary_Opportunity_Contact__c field
 */

@isTest
public with sharing class RoscoCmtyTest {
	private static final String TEST_CLASS_PREFIX = 'RoscoCmtyTest';

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Case_Management__c caseManagementSetting = new Case_Management__c();
			caseManagementSetting.Name = '';
			caseManagementSetting.rosco_case_country_routing_accountids__c = 'All';
			insert caseManagementSetting;

			Account account = TestFactory.buildAccount(TEST_CLASS_PREFIX + '_Account');
			account.slack_channel_id__c = 'TESTCASE';
			account.Country_Exception_Approved__c = true;
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			contact.Email = TEST_CLASS_PREFIX + '@roscolab.com';
			insert contact;

			Id communityProfileId = [
				SELECT Id
				FROM Profile
				WHERE Name = 'Tanium Community Login Authenticated'
				LIMIT 1
			]
			.Id;

			User communityUser = new User(
				Email = contact.Email,
				FirstName = 'Test',
				LastName = 'Apex',
				UserName = contact.Email + '.' + TEST_CLASS_PREFIX,
				Alias = 'tstapex',
				CommunityNickName = 'tstapex',
				TimeZoneSidKey = 'America/Los_Angeles',
				LocaleSidKey = 'en_US',
				EmailEncodingKey = 'ISO-8859-1',
				ProfileId = communityProfileId,
				LanguageLocaleKey = 'en_US',
				ContactId = contact.Id
			);
			insert communityUser;

			ContentVersion contentVersion = new ContentVersion();
			contentVersion.ContentLocation = 'S';
			contentVersion.Title = TEST_CLASS_PREFIX + '_Doc';
			contentVersion.PathOnClient = TEST_CLASS_PREFIX + '.pdf';
			contentVersion.VersionData = Blob.valueOf('Test Content');
			contentVersion.IsMajorVersion = true;
			insert contentVersion;

			Rosco_CmtyContent__c splashContent = new Rosco_CmtyContent__c();
			splashContent.Name = 'splash1';
			splashContent.body__c = 'Splash body';
			splashContent.Status__c = 'Online';
			splashContent.Title__c = 'Splash';
			splashContent.Content_Type__c = 'Splash';
			insert splashContent;
		}
	}

	private static Map<String, String> getCaseStringsMap() {
		Map<String, String> caseStringsMap = new Map<String, String>();
		caseStringsMap.put('Subject', 'ROSCOTESTCASE');
		caseStringsMap.put('Component', 'Tanium Patch');
		caseStringsMap.put('Severity', '2');
		caseStringsMap.put('SeverityReason', 'Sev Reason');
		caseStringsMap.put('TimeIncident', 'Time Incident 123');
		caseStringsMap.put('Duration', '2021');
		caseStringsMap.put('Frequency', '2021');
		caseStringsMap.put('ComponentVersion', '123');
		caseStringsMap.put('OS', 'Windows');
		caseStringsMap.put('Description', 'Description 123');
		caseStringsMap.put('InfoCollected', 'Info 123');
		caseStringsMap.put('ActionTaken', 'Action 123');
		caseStringsMap.put('NextSteps', 'Steps 123');
		caseStringsMap.put('PreferredContact', 'Preferred 123');
		caseStringsMap.put('pocDescription', 'poc desc 123');
		caseStringsMap.put('summary', 'note123');
		return caseStringsMap;
	}

	private static Map<String, String> getCaseFilesMap(Id contentDocumentId, String fileName) {
		Map<String, String> caseFilesMap = new Map<String, String>();
		if (contentDocumentId != null) {
			caseFilesMap.put(String.valueOf(contentDocumentId), fileName);
		}
		return caseFilesMap;
	}

	private static Id getSetupContentDocumentId() {
		ContentVersion contentVersion = [
			SELECT Id
			FROM ContentVersion
			WHERE Title = :TEST_CLASS_PREFIX + '_Doc'
			LIMIT 1
		];
		return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1]
		.ContentDocumentId;
	}

	@isTest
	static void createCase_WhenCommunityUser_ReturnsCaseIdAndCloseSuccess() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Id contentDocumentId = getSetupContentDocumentId();
		Map<String, String> caseStringsMap = getCaseStringsMap();
		Map<String, String> caseFilesMap = getCaseFilesMap(
			contentDocumentId,
			TEST_CLASS_PREFIX + '.pdf'
		);

		Map<String, String> createResult;
		Map<String, String> closeResult;

		System.runAs(communityUser) {
			Test.startTest();
			createResult = RoscoCmty.createCase(caseStringsMap, caseFilesMap);
			Test.stopTest();
			Assert.isTrue(createResult.containsKey('CaseId'), 'createCase should return CaseId');
			Assert.isTrue(createResult.get('CaseId').startsWith('500'), 'CaseId should be a Case');

			caseStringsMap.put('Id', createResult.get('CaseId'));
			closeResult = RoscoCmty.closeCase(caseStringsMap);
			Assert.areEqual('SUCCESS', closeResult.get('actionResult'), 'closeCase should succeed');
		}
	}

	@isTest
	static void createCase_WhenSupportCenter_ReturnsCaseId() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id FROM Account LIMIT 1];
		account.Support_Model__c = 'Support Center';
		System.runAs(TestUserFactory.getAdminUser()) {
			update account;
		}

		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Id contentDocumentId = getSetupContentDocumentId();

		Map<String, String> result;
		System.runAs(communityUser) {
			result = RoscoCmty.createCase(
				getCaseStringsMap(),
				getCaseFilesMap(contentDocumentId, 'doc.pdf')
			);
		}
		Assert.isTrue(result.get('CaseId').startsWith('500'), 'Case should be created');
	}

	@isTest
	static void createCase_WhenSupportCenterJapanBypass_ReturnsCaseId() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id FROM Account LIMIT 1];
		account.Support_Model__c = 'Support Center (Japan Bypass)';
		System.runAs(TestUserFactory.getAdminUser()) {
			update account;
		}

		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Id contentDocumentId = getSetupContentDocumentId();

		Map<String, String> createResult;
		System.runAs(communityUser) {
			createResult = RoscoCmty.createCase(
				getCaseStringsMap(),
				getCaseFilesMap(contentDocumentId, 'doc.pdf')
			);
		}
		Assert.isTrue(createResult.get('CaseId').startsWith('500'), 'Case should be created');
	}

	@isTest
	static void getArticleInit_WhenRoscoCmtyContentId_ReturnsContent() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Rosco_CmtyContent__c rcc = new Rosco_CmtyContent__c();
			rcc.body__c = 'ROSCOTESTCASE';
			rcc.Name = 'ROSCOTESTCASE';
			rcc.Status__c = 'Online';
			rcc.Title__c = 'ROSCOTESTCASE';
			rcc.Topics__c = 'ROSCOTESTCASE';
			rcc.Content_Type__c = 'Core Doc';
			insert rcc;

			Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
			User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

			Map<String, String> init;
			System.runAs(communityUser) {
				init = RoscoCmty.getArticleInit(rcc.Id);
			}
			Assert.areEqual('ROSCOTESTCASE', init.get('Title'), 'Title should match');
		}
	}

	@isTest
	static void getArticleIdFromUrl_WhenUrlNameNoPublishedKb_ReturnsNotFoundMessage() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String result = RoscoCmty.getArticleIdFromUrl('urlname');
			Assert.areEqual(
				'Sorry, article was not found!',
				result,
				'No published KB so expect message'
			);
		}
	}

	@isTest
	static void getArticleIdFromUrl_WhenKbUrlParam_ReturnsParsedIdOrMessage() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String result = RoscoCmty.getArticleIdFromUrl('https://foo?kburl=someurl');
			Assert.isTrue(result != null, 'Should return string');
		}
	}

	@isTest
	static void getCaseRecordDetail_WhenValidCaseId_ReturnsCaseDetails() {
		Id supportRecordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');
		Account account = [SELECT Id FROM Account LIMIT 1];
		Contact contact = [SELECT Id FROM Contact LIMIT 1];

		Case caseObj;
		System.runAs(TestUserFactory.getAdminUser()) {
			caseObj = new Case(
				ContactId = contact.Id,
				AccountId = account.Id,
				Subject = 'ROSCOTESTCASE',
				Severity_Community__c = '2',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				SuppliedEmail = '00@outlook.com',
				RecordTypeId = supportRecordTypeId
			);
			insert caseObj;
		}

		Map<String, String> detail;
		System.runAs(TestUserFactory.getAdminUser()) {
			RoscoCmtyNoShare.GetCaseInfo(caseObj.Id);
			detail = RoscoCmty.getCaseRecordDetail(caseObj.Id);
		}
		Assert.areEqual('ROSCOTESTCASE', detail.get('subject'), 'Subject should match');
		Assert.isTrue(detail.containsKey('number'), 'Should have CaseNumber');
	}

	@isTest
	static void getCmtyCaseInit_WhenValidCaseId_ReturnsStatus() {
		Id supportRecordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');
		Account account = [SELECT Id FROM Account LIMIT 1];
		Contact contact = [SELECT Id FROM Contact LIMIT 1];

		Case caseObj;
		System.runAs(TestUserFactory.getAdminUser()) {
			caseObj = new Case(
				ContactId = contact.Id,
				AccountId = account.Id,
				Subject = 'ROSCOTESTCASE',
				Severity_Community__c = '2',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				SuppliedEmail = '00@outlook.com',
				RecordTypeId = supportRecordTypeId
			);
			insert caseObj;
		}

		Map<String, String> init;
		System.runAs(TestUserFactory.getAdminUser()) {
			init = RoscoCmty.getCmtyCaseInit(caseObj.Id);
		}
		Assert.isTrue(init.containsKey('Status'), 'Should return Status');
	}

	@isTest
	static void getCmtyPortalInit_Always_ReturnsPortalInitMap() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		Map<String, String> init;
		System.runAs(communityUser) {
			init = RoscoCmty.getCmtyPortalInit('https://foo/s/');
		}
		Assert.isTrue(init.containsKey('canCreateCase'), 'Should have canCreateCase');
		Assert.isTrue(init.containsKey('subscriptionTaniumVuln'), 'Should have subscription');
		Assert.isTrue(init.containsKey('logToConsole'), 'Should have logToConsole');
	}

	@isTest
	static void getContentByTopic_GetSupportDocsByTopic_WhenTopicExists_ReturnLists() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Rosco_CmtyContent__c rcc = new Rosco_CmtyContent__c();
			rcc.body__c = 'ROSCOTESTCASE';
			rcc.Name = 'ROSCOTESTCASE';
			rcc.Status__c = 'Online';
			rcc.Title__c = 'ROSCOTESTCASE';
			rcc.Topics__c = 'ROSCOTESTCASE';
			rcc.Content_Type__c = 'Core Doc';
			insert rcc;
		}

		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		List<Map<String, String>> byTopic;
		List<Map<String, String>> docsSplash;
		List<Map<String, String>> docsCore;
		System.runAs(communityUser) {
			byTopic = RoscoCmty.getContentByTopic('ROSCOTESTCASE', true);
			docsSplash = RoscoCmty.getSupportDocsByTopic('ROSCOTESTCASE', true);
			docsCore = RoscoCmty.getSupportDocsByTopic('ROSCOTESTCASE', false);
		}
		Assert.isNotNull(byTopic, 'getContentByTopic should return list');
		Assert.isNotNull(docsSplash, 'getSupportDocsByTopic splash should return list');
		Assert.isNotNull(docsCore, 'getSupportDocsByTopic core should return list');
	}

	@isTest
	static void getSupportKBByTopic_WhenPublishedKbExists_ReturnsKbListWithCategories() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Knowledge__kav article = new Knowledge__kav(
				Title = TEST_CLASS_PREFIX + ' KB By Topic',
				Summary = 'Summary for getSupportKBByTopic',
				UrlName = 'getSupportKBByTopic-art',
				Language = 'en_US',
				IsVisibleInCsp = true,
				IsVisibleInPkb = true,
				IsVisibleInPrm = true
			);
			insert article;

			Knowledge__DataCategorySelection dcs = new Knowledge__DataCategorySelection();
			dcs.ParentId = article.Id;
			dcs.DataCategoryGroupName = 'Customer_KB';
			dcs.DataCategoryName = 'Tanium_Client';
			insert dcs;

			Knowledge__kav kav = [
				SELECT KnowledgeArticleId
				FROM Knowledge__kav
				WHERE Id = :article.Id
			];
			KbManagement.PublishingService.publishArticle(kav.KnowledgeArticleId, true);
		}

		List<Map<String, String>> result;
		System.runAs(TestUserFactory.getAdminUser()) {
			result = RoscoCmty.getSupportKBByTopic('ROSCOTESTCASE');
		}
		Assert.isNotNull(result, 'getSupportKBByTopic should return list');
		Assert.isTrue(
			result.size() >= 1,
			'getSupportKBByTopic for-loop: at least one KB (kbList.size != 0)'
		);
		Assert.isTrue(result[0].containsKey('Id'), 'Each KB map should have Id');
		Assert.isTrue(result[0].containsKey('Title'), 'Each KB map should have Title');
		Assert.isTrue(
			result[0].containsKey('Category'),
			'Each KB map should have Category (kbCategories path)'
		);
		Assert.isTrue(
			result[0].containsKey('ArticleNumber'),
			'Each KB map should have ArticleNumber'
		);
	}

	@isTest
	static void getSupportCreateCaseInit_Always_ReturnsInitMap() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		Map<String, Object> init;
		System.runAs(communityUser) {
			init = RoscoCmty.getSupportCreateCaseInit();
		}
		Assert.isTrue(init.containsKey('contact'), 'Should have contact');
		Assert.isTrue(init.containsKey('relations'), 'Should have relations');
		Assert.isTrue(init.containsKey('components'), 'Should have components');
		Assert.isTrue(init.containsKey('severities'), 'Should have severities');
		Assert.isTrue(init.containsKey('uiOptions'), 'Should have uiOptions');
	}

	@isTest
	static void getRoscoSetting_Always_ReturnsSettingValue() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String v = RoscoCmtyNoShare.getRoscoSetting('rosco_cmty_show_partner_account__c');
			Assert.isNotNull(v, 'Setting value should be non-null');
		}
	}

	@isTest
	static void getSupportUserExperience_Always_ReturnsStandardOrPartner() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String exp = RoscoCmty.getSupportUserExperience();
			Assert.isTrue(
				exp == 'Standard' || exp == 'Partner',
				'Experience should be Standard or Partner'
			);
		}
	}

	@isTest
	static void getCustomerIdAccount_WhenValidExpiredAndUnknownLicense_ReturnsMaps() {
		Account a;
		Country_For_Export__c country;
		Opportunity o;
		Server_Deployment__c sd;
		Tanium_Server_License__c licenseValid;
		Tanium_Server_License__c licenseExpired;

		System.runAs(TestUserFactory.getAdminUser()) {
			a = TestFactory.buildAccount('Foo');
			a.Country_Restrictions__c = 'Unrestricted';
			insert a;

			Contact contact = new Contact(
				Email = TEST_CLASS_PREFIX + '_cust@tanium1.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = a.Id
			);
			insert contact;

			o = new Opportunity();
			o.Name = 'FooOpp';
			o.StageName = 'Prospecting';
			o.CloseDate = System.today();
			o.Primary_Opportunity_Contact__c = contact.Id;
			o.AccountId = a.Id;
			insert o;

			country = new Country_For_Export__c();
			country.Business_Allowed__c = true;
			country.Deal_Desk_Approval_Required__c = false;
			country.Name = 'United States of America';
			country.Country_Code__c = 'NA';
			insert country;

			sd = new Server_Deployment__c();
			sd.Account__c = a.Id;
			sd.Country__c = country.Id;
			sd.Name = 'FooServerDeployment';
			sd.Opportunity__c = o.Id;
			sd.Seats_Deployed__c = 1;
			sd.Seats_Licensed__c = 1;
			sd.Server_Device_Type__c = 'Tanium as a Service';
			sd.Server_Hostnames__c = 'foo.bar.com';
			sd.Server_OS__c = 'Tanium as a Service';
			sd.Server_Version__c = '7.3.314.4269';
			sd.Stage__c = 'Active';
			sd.TaaS_Admin_email__c = '99@outlook.com';
			sd.TaaS_Region__c = 'US-West-2';
			sd.Tanium_Infrastructure__c = 'Tanium as a Service';
			sd.Type__c = 'Production';
			sd.License_delivery_email_primary__c = '99@outlook.com';
			sd.Vanity_URL__c = 'vanity1';
			insert sd;

			licenseValid = new Tanium_Server_License__c();
			licenseValid.Expiration_Date__c = System.today().addDays(1);
			licenseValid.LicenseID__c = 12341234;
			licenseValid.Name = 'fooCustomer';
			licenseValid.ServerDeployment__c = sd.Id;
			insert licenseValid;

			licenseExpired = new Tanium_Server_License__c();
			licenseExpired.Expiration_Date__c = System.today().addDays(-1);
			licenseExpired.LicenseID__c = 43214321;
			licenseExpired.Name = 'fooCustomerExpired';
			licenseExpired.ServerDeployment__c = sd.Id;
			insert licenseExpired;
		}

		Map<String, String> goodCheck;
		Map<String, String> expiredCheck;
		Map<String, String> noCheck;
		System.runAs(TestUserFactory.getAdminUser()) {
			goodCheck = RoscoCmty.getCustomerIdAccount('12341234');
			expiredCheck = RoscoCmty.getCustomerIdAccount('43214321');
			noCheck = RoscoCmty.getCustomerIdAccount('99999999');
		}
		Assert.isNotNull(goodCheck, 'Valid license should return map');
		Assert.isNotNull(expiredCheck, 'Expired license should return map');
		Assert.isNotNull(noCheck, 'Unknown ID should return map');
	}

	@isTest
	static void getVulnInit_Always_ReturnsList() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		List<Map<String, String>> vuln;
		System.runAs(communityUser) {
			vuln = RoscoCmty.getVulnInit();
		}
		Assert.isNotNull(vuln, 'getVulnInit should return list');
	}

	@isTest
	static void searchSupport_SearchSupportDisc_SearchSupportDocs_WhenSearchText_ReturnLists() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		List<Map<String, String>> support;
		List<Map<String, String>> disc;
		List<Map<String, String>> docs;
		System.runAs(TestUserFactory.getAdminUser()) {
			support = RoscoCmty.searchSupport('ROSCOTESTCASE');
			disc = RoscoCmty.searchSupportDisc('ROSCOTESTCASE');
			docs = RoscoCmty.searchSupportDocs('ROSCOTESTCASE');
		}
		System.runAs(communityUser) {
			RoscoCmty.searchSupportDisc('ROSCOTESTCASE');
			RoscoCmty.searchSupportDocs('ROSCOTESTCASE');
		}
		Assert.isNotNull(support, 'searchSupport should return list');
		Assert.isNotNull(disc, 'searchSupportDisc should return list');
		Assert.isNotNull(docs, 'searchSupportDocs should return list');
	}

	@isTest
	static void getArticleIdFromURL_WhenFullUrl_ReturnsIdOrMessage() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String idOrMsg = RoscoCmty.getArticleIdFromURL('https://foo/s/urlname');
			Assert.isNotNull(idOrMsg, 'Should return string');
		}
	}

	@isTest
	static void isKBInternal_WhenInvalidId_ReturnsFalse() {
		System.runAs(TestUserFactory.getAdminUser()) {
			String result = RoscoCmty.isKBInternal('ka000000000000AAA');
			Assert.areEqual('false', result, 'Invalid KB Id should return false');
		}
	}

	@isTest
	static void isKBInternal_WhenKbWithoutInternalOnly_ReturnsFalse() {
		Knowledge__kav article;
		System.runAs(TestUserFactory.getAdminUser()) {
			article = new Knowledge__kav(
				Title = TEST_CLASS_PREFIX + ' KB Internal False',
				Summary = 'Summary',
				UrlName = 'isKBInternal-false',
				Language = 'en_US',
				IsVisibleInCsp = true,
				IsVisibleInPkb = true,
				IsVisibleInPrm = true
			);
			insert article;

			Knowledge__DataCategorySelection dcs = new Knowledge__DataCategorySelection();
			dcs.ParentId = article.Id;
			dcs.DataCategoryGroupName = 'Customer_KB';
			dcs.DataCategoryName = 'Tanium_Client';
			insert dcs;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			String result = RoscoCmty.isKBInternal(article.Id);
			Assert.areEqual('false', result, 'KB without Internal_Only category should return false');
		}
	}

	@isTest
	static void isKBInternal_WhenKbWithInternalOnlyOrNot_ReturnsTrueOrFalse() {
		Knowledge__kav article;
		Boolean internalOnlyAdded = false;
		System.runAs(TestUserFactory.getAdminUser()) {
			article = new Knowledge__kav(
				Title = TEST_CLASS_PREFIX + ' KB Internal True',
				Summary = 'Summary',
				UrlName = 'isKBInternal-true',
				Language = 'en_US',
				IsVisibleInCsp = true,
				IsVisibleInPkb = true,
				IsVisibleInPrm = true
			);
			insert article;

			Knowledge__DataCategorySelection dcs = new Knowledge__DataCategorySelection();
			dcs.ParentId = article.Id;
			dcs.DataCategoryGroupName = 'Customer_KB';
			dcs.DataCategoryName = 'Internal_Only';
			try {
				insert dcs;
				internalOnlyAdded = true;
			} catch (Exception e) {
				System.debug('Error inserting Knowledge__DataCategorySelection: ' + e.getMessage());
			}
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			String result = RoscoCmty.isKBInternal(article.Id);
			if (internalOnlyAdded) {
				Assert.areEqual('true', result, 'KB with Internal_Only category should return true');
			} else {
				Assert.areEqual(
					'false',
					result,
					'KB without Internal_Only category should return false'
				);
			}
		}
	}

	@isTest
	static void processKnowledgeFeedback_WhenPublishedArticle_CreatesFeedItem() {
		String articleNumber = null;
		Id knowledgeArticleId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Knowledge__kav article = new Knowledge__kav(
				Title = TEST_CLASS_PREFIX + ' Feedback Article',
				Summary = 'Summary',
				UrlName = 'processKnowledgeFeedback-art',
				Language = 'en_US',
				IsVisibleInCsp = true,
				IsVisibleInPkb = true,
				IsVisibleInPrm = true
			);
			insert article;

			Knowledge__DataCategorySelection dcs = new Knowledge__DataCategorySelection();
			dcs.ParentId = article.Id;
			dcs.DataCategoryGroupName = 'Customer_KB';
			dcs.DataCategoryName = 'Tanium_Client';
			insert dcs;

			Knowledge__kav kav = [
				SELECT ArticleNumber, KnowledgeArticleId
				FROM Knowledge__kav
				WHERE Id = :article.Id
			];
			articleNumber = kav.ArticleNumber;
			knowledgeArticleId = kav.KnowledgeArticleId;
			KbManagement.PublishingService.publishArticle(knowledgeArticleId, true);
		}

		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		System.runAs(communityUser) {
			RoscoCmty.processKnowledgeFeedback(articleNumber, 'feedback text');
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			List<FeedItem> feedItems = [
				SELECT Id, Body, ParentId
				FROM FeedItem
				WHERE ParentId = :knowledgeArticleId
			];
			Assert.isTrue(feedItems.size() >= 1, 'processKnowledgeFeedback should create a FeedItem');
			Assert.areEqual('feedback text', feedItems[0].Body, 'FeedItem body should match');
		}
	}

	@isTest
	static void processKnowledgeVote_WhenPublishedArticle_CreatesAndUpdatesVote() {
		String articleNumber = null;
		Id knowledgeArticleId = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Knowledge__kav article = new Knowledge__kav(
				Title = TEST_CLASS_PREFIX + ' Vote Article',
				Summary = 'Summary',
				UrlName = 'processKnowledgeVote-art',
				Language = 'en_US',
				IsVisibleInCsp = true,
				IsVisibleInPkb = true,
				IsVisibleInPrm = true
			);
			insert article;

			Knowledge__DataCategorySelection dcs = new Knowledge__DataCategorySelection();
			dcs.ParentId = article.Id;
			dcs.DataCategoryGroupName = 'Customer_KB';
			dcs.DataCategoryName = 'Tanium_Client';
			insert dcs;

			Knowledge__kav kav = [
				SELECT ArticleNumber, KnowledgeArticleId
				FROM Knowledge__kav
				WHERE Id = :article.Id
			];
			articleNumber = kav.ArticleNumber;
			knowledgeArticleId = kav.KnowledgeArticleId;
			KbManagement.PublishingService.publishArticle(knowledgeArticleId, true);
		}

		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		System.runAs(communityUser) {
			RoscoCmty.processKnowledgeVote(articleNumber, 'Yes');
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Vote> votes = [
				SELECT Id, Type, ParentId
				FROM Vote
				WHERE ParentId = :knowledgeArticleId
			];
			Assert.isTrue(votes.size() >= 1, 'processKnowledgeVote should create a Vote');
			Assert.areEqual('Up', votes[0].Type, 'Vote type for Yes should be Up');
		}

		System.runAs(communityUser) {
			RoscoCmty.processKnowledgeVote(articleNumber, 'No');
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Vote> votesAfter = [
				SELECT Id, Type
				FROM Vote
				WHERE ParentId = :knowledgeArticleId
			];
			Assert.isTrue(votesAfter.size() >= 1, 'Vote should still exist after toggle');
			Assert.areEqual('Down', votesAfter[0].Type, 'Vote type for No should be Down');
		}
	}

	@isTest
	static void processPortalFeedback_WhenFeedbackText_ReturnsResult() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		System.runAs(communityUser) {
			String result = RoscoCmty.processPortalFeedback('rosco');
			Assert.isNotNull(result, 'Should return string');
		}
	}

	@isTest
	static void processSubscriptionToggle_WhenSubscriptionType_ReturnsResult() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		System.runAs(communityUser) {
			String ret = RoscoCmty.processSubscriptionToggle('Tanium Vulnerability');
			Assert.isNotNull(ret, 'Should return string');
		}
	}

	@isTest
	static void getCmtyPortalInit_WhenSubscriptionToggled_ReturnsInitMap() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			RoscoCmtyNoShare.subscriptionToggle('subscriptiontype', communityUser.Id);
			RoscoCmtyNoShare.subscriptionToggle('subscriptiontype', communityUser.Id);
		}
		Map<String, String> init;
		System.runAs(communityUser) {
			init = RoscoCmty.getCmtyPortalInit('https://foo/s/');
		}
		Assert.isTrue(init.containsKey('subscriptionTaniumVuln'), 'Should have subscription');
	}

	@isTest
	static void searchSupportTypeAhead_WhenSearchText_ReturnsList() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		List<Map<String, String>> single;
		List<Map<String, String>> multi;
		System.runAs(communityUser) {
			single = RoscoCmty.searchSupportTypeAhead('tanium');
			multi = RoscoCmty.searchSupportTypeAhead('tanium client');
		}
		Assert.isNotNull(single, 'TypeAhead single word should return list');
		Assert.isNotNull(multi, 'TypeAhead multi word should return list');
	}

	@isTest
	static void exportCases_WhenUserHasCases_ReturnsCaseList() {
		Contact contact = [SELECT Id, Email, AccountId FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Id supportRecordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');

		System.runAs(TestUserFactory.getAdminUser()) {
			Case caseOpen = new Case(
				ContactId = contact.Id,
				AccountId = contact.AccountId,
				Subject = 'Export Test Open',
				Severity_Community__c = '2',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Community',
				SuppliedEmail = contact.Email,
				RecordTypeId = supportRecordTypeId,
				Status = 'New'
			);
			insert caseOpen;

			Case caseClosed = new Case(
				ContactId = contact.Id,
				AccountId = contact.AccountId,
				Subject = 'Export Test Closed',
				Severity_Community__c = '3',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Community',
				SuppliedEmail = contact.Email,
				RecordTypeId = supportRecordTypeId,
				Status = 'Closed',
				CreatedDate = System.today().addDays(-15),
				ClosedDate = System.today().addDays(-10)
			);
			insert caseClosed;
		}

		List<Map<String, String>> exported;
		System.runAs(communityUser) {
			exported = RoscoCmty.exportCases(contact.Id);
		}
		Assert.isNotNull(exported, 'exportCases should return list');
		Assert.isTrue(
			exported.size() >= 2,
			'exportCases for-loop should run: at least 2 cases visible'
		);
		Set<String> subjects = new Set<String>();
		for (Map<String, String> row : exported) {
			subjects.add(row.get('Subject'));
			Assert.isTrue(row.containsKey('CaseNumber'), 'Each row should have CaseNumber');
			Assert.isTrue(row.containsKey('Closed'), 'Each row should have Closed');
		}
		Assert.isTrue(subjects.contains('Export Test Open'), 'Open case should be in exported list');
		Assert.isTrue(
			subjects.contains('Export Test Closed'),
			'Closed case should be in exported list'
		);
	}

	@isTest
	static void getSplashCmtyContent_WhenSplashContentExists_ReturnsSplashMap() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Map<String, String> splash = RoscoCmty.getSplashCmtyContent();
			Assert.isNotNull(splash, 'getSplashCmtyContent should return map');
		}
	}

	@isTest
	static void getArticleInit_WhenUnknownKbId_ReturnsNotFoundMessage() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];

		Map<String, String> articleInit;
		System.runAs(communityUser) {
			articleInit = RoscoCmty.getArticleInit('ka000000000000AAA');
		}
		Assert.areEqual(
			'Sorry, article was not found!',
			articleInit.get('Title'),
			'Unknown KB id should return not found'
		);
	}
}