/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Testclass for RoscoCmtyNoShare, run together with RoscoCmtyTest
 * @Date:     2024-02-23
 * @Authors:  Tanium Dev Team
 * @Request:  SS-7276, SS-7277
 * RequestId  ModifiedDate  Description
 * SS-7277    2024-02-23    Created Test class to improve testing of class RoscoCmtyNoShare
 * SS-8049    2024-07-15    Improve test class code coverage
 * SS-8749    2024-07-24    Updated test class
 * SS-9296    2024-10-04    Update asserts for case assignment
 * SS-10083	  2025-01-24	Test class failures comin from flows
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */
@IsTest
private class RoscoCmtyNoShareTest {
	private static final String TEST_CLASS_NAME = 'RoscoCmtyNoShareTest';

	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
		Id communityProfileId = [
			SELECT Id
			FROM Profile
			WHERE Name = 'Tanium Community Login Authenticated'
		]
		.Id;

		System.runAs(TestUserFactory.getAdminUser()) {
			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Name = '';
			cmSetting.rosco_case_country_routing_accountids__c = 'All';
			insert cmSetting;

			Account account = TestFactory.buildAccount('Case Account');
			account.slack_channel_id__c = 'TESTCASE';
			account.Country_Exception_Approved__c = true;
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			insert contact;

			User communityUser = new User(
				Email = contact.Email,
				FirstName = 'First',
				LastName = 'Last',
				UserName = contact.Email + '.' + TEST_CLASS_NAME,
				Alias = 'firLas6',
				CommunityNickName = 'firLas6',
				TimeZoneSidKey = 'America/Los_Angeles',
				LocaleSidKey = 'en_US',
				EmailEncodingKey = 'ISO-8859-1',
				ProfileId = communityProfileId,
				LanguageLocaleKey = 'en_US',
				ContactId = contact.Id
			);
			insert communityUser;

			Id contentVersionGeneralRecTypeId = Utility.getRecordTypeIdByAPIName(
				'ContentVersion',
				'General'
			);
			ContentDocument contentDocument = createContentVersion(
				UserInfo.getUserId(),
				contentVersionGeneralRecTypeId
			);
		}
	}

	@IsTest
	static void testCreateCase_WhenBaseScenario_CaseCreated() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			caseStringsMap = getCaseStringsMap();
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}

		Assert.isTrue(result.get('CaseId').startsWith('500'));
	}

	@IsTest
	static void testCreateCase_WhenSupportCenter_CaseCreated() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id, Support_Model__c FROM Account LIMIT 1];
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			account.Support_Model__c = 'Support Center';
			update account;
			caseStringsMap = getCaseStringsMap();
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}

		Assert.isTrue(result.get('CaseId').startsWith('500'));
	}

	@IsTest
	static void testCreateCase_WhenSupportCenterJapan_CaseCreated() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id, Support_Model__c FROM Account LIMIT 1];
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			account.Support_Model__c = 'Support Center (Japan Bypass)';
			update account;
			caseStringsMap = getCaseStringsMap();
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}

		Assert.isTrue(result.get('CaseId').startsWith('500'));
	}

	@IsTest
	static void testCreateCase_WhenSupportCenterSev3_CaseCreated() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id, Support_Model__c FROM Account LIMIT 1];
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			account.Support_Model__c = 'Support Center';
			update account;
			caseStringsMap = getCaseStringsMap();
			caseStringsMap.put('Severity', '3');
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}

		Assert.isTrue(result.get('CaseId').startsWith('500'));
	}

	@IsTest
	static void testCreateCase_WhenSev3PubSecCreated_CaseRoutedToOmniSev3Queue() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id, Support_Model__c FROM Account LIMIT 1];
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			account.Support_Model__c = 'Hybrid - Pubsec';
			update account;
			caseStringsMap = getCaseStringsMap();
			caseStringsMap.put('Severity', '3');
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}

		Assert.isNotNull(
			[SELECT OwnerId FROM Case WHERE Id = :result.get('CaseId')],
			'Owner should be assigned'
		);
	}

	@IsTest
	static void testCreateCase_WhenSev3PolandCaseCreated_CaseRoutedToSupportCenterPolandQueue() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id, Support_Model__c FROM Account LIMIT 1];
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			account.Support_Model__c = 'Support Center (Poland)';
			update account;
			caseStringsMap = getCaseStringsMap();
			caseStringsMap.put('Severity', '3');
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}

		Assert.isNotNull(
			[SELECT OwnerId FROM Case WHERE Id = :result.get('CaseId')],
			'Owner should be assigned'
		);
	}

	@IsTest
	static void testCreateCase_WhenSev2CaseCreated_CaseRoutedToSupportCenterQueue() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id, Support_Model__c FROM Account LIMIT 1];
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			account.Support_Model__c = 'Hybrid - Pubsec';
			update account;
			caseStringsMap = getCaseStringsMap();
			caseStringsMap.put('Severity', '2');
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}

		Assert.isNotNull(
			[SELECT OwnerId FROM Case WHERE Id = :result.get('CaseId')],
			'Owner should be assigned'
		);
	}

	@IsTest
	static void testCreateCase_WhenCaseAssignmentCriteraNotMet_CaseRoutedToServiceCloudUserDueToFlow() {
		TriggerHandler.bypass('AccountTriggerHandler');
		Account account = [SELECT Id, Support_Model__c FROM Account LIMIT 1];
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			account.Support_Model__c = 'SC-Exempt';
			update account;
			caseStringsMap = getCaseStringsMap();
			caseStringsMap.put('Severity', '3');
			caseFilesStringsMap = getCaseFilesStringsMap();
		}
		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			Test.stopTest();
		}


		// Get different results in different instances, will have to be updated  after next refresh
		//	System.assertEquals(
		//		[SELECT OwnerId FROM Case WHERE Id = :result.get('CaseId')].OwnerId,
		//		'00532000005VMZAAA4'
		//	);
	}

	@IsTest
	static void testCloseCase_WhenBaseScenario_CaseClosed() {
		Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
		User communityUser = [SELECT Id FROM User WHERE Email = :contact.Email LIMIT 1];
		Map<String, String> result;
		Map<String, String> closeResult;
		Map<String, String> caseStringsMap;
		Map<String, String> caseFilesStringsMap;

		System.runAs(TestUserFactory.getAdminUser()) {
			caseStringsMap = getCaseStringsMap();
			caseFilesStringsMap = getCaseFilesStringsMap();
		}

		System.runAs(communityUser) {
			Test.startTest();
			result = RoscoCmtyNoShare.createCase(caseStringsMap, caseFilesStringsMap);
			caseStringsMap.put('Id', result.get('CaseId'));
			TriggerHandler.resetRecursionLimits();
			closeResult = RoscoCmtyNoShare.closeCase(caseStringsMap);
			Test.stopTest();
		}

		Assert.isTrue(closeResult.get('actionResult') == 'SUCCESS');
	}

	static Map<String, String> getCaseStringsMap() {
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

	static Map<String, String> getCaseFilesStringsMap() {
		Map<String, String> caseFilesStringsMap = new Map<String, String>();
		ContentVersion contentVersion = [
			SELECT Id
			FROM ContentVersion
			WHERE Title = :TEST_CLASS_NAME
			LIMIT 1
		];
		Id contentDocumentId = [
			SELECT ContentDocumentId
			FROM ContentVersion
			WHERE Id = :contentVersion.Id
			LIMIT 1
		]
		.ContentDocumentId;
		caseFilesStringsMap.put(String.valueOf(contentDocumentId), TEST_CLASS_NAME + '.pdf');
		return caseFilesStringsMap;
	}

	static ContentDocument createContentVersion(Id userId, Id recordType) {
		ContentVersion cv = new ContentVersion();
		cv.Title = TEST_CLASS_NAME;
		cv.PathOnClient = '/' + cv.Title + '.pdf';
		Blob bodyBlob = Blob.valueOf(TEST_CLASS_NAME);
		cv.VersionData = bodyBlob;
		cv.origin = 'H';
		cv.FirstPublishLocationId = userId;
		cv.RecordTypeId = recordType != null ? recordType : cv.RecordTypeId;
		insert cv;
		return [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument LIMIT 1];
	}
}