/**
 * @Business: Test Class for RoscoClose
 * @Date: 8/4/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7985    2024-05-14    New Test Method for Adding Sub-Component Field
 * SS-8433    2024-06-13    Change getInitInfo return type
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */
@IsTest
private class RoscoCloseTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'SurveyTriggerHandler',
				'UserTriggerHandler',
				'CaseTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.setMock(HttpCalloutMock.class, new mockCallout());

			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';

			Contact contactObj = new Contact(
				Email = 'roscoapextest@roscolab.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = null
			);
			Contact contactObj2 = new Contact(
				Email = 'roscoapextest@tanium.com',
				FirstName = 'Test2',
				LastName = 'Apex',
				AccountId = null
			);

			User userObj = TestUserFactory.createUser(
				'ApexUser',
				'roscoapextest@roscolab.com',
				'jrj413',
				Utility.getAdminUserProfileId(),
				Utility.getCorporateRoleId()
			);
			insert new List<SObject>{ accountObj, contactObj, contactObj2, userObj };

			Case caseObj = new Case(
				ContactId = contactObj.Id,
				AccountId = accountObj.Id,
				Ownerid = userObj.Id,
				Subject = 'ROSCOTESTCASE',
				Severity_Community__c = '3',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				SuppliedEmail = '99@outlook.com',
				LatestPublicCommentHTML__c = '<html>hello</html>',
				Status = 'On Hold',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support')
			);
			insert caseObj;

			Survey__c survey = new Survey__c(
				Case_1_Recommend__c = '10',
				Case_2_Overall_Support__c = 'Very Satisfied',
				Case_2_Satisfaction__c = '100',
				Case_3_Speed_of_Resolution__c = 'Very Satisfied',
				Case_4_Technical_Knowledge__c = 'Very Satisfied',
				Case_5_Issue_Resolved__c = 'Yes',
				Case_6_Comment__c = 'Comment1',
				Name = 'Support Center CSAT',
				SurveyCreateDate__c = System.Datetime.now(),
				Case__c = caseObj.Id
			);

			CaseContactRole ccrObj = new CaseContactRole(
				CasesId = caseObj.Id,
				ContactId = contactObj2.Id
			);
			insert new List<SObject>{ survey, ccrObj };
		}
	}

	@IsTest
	static void getInitInfo_AlwaysReturnCaseDetails() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = [SELECT Id FROM Account LIMIT 1];
			Case testCase = [SELECT Id, Tags__c FROM Case LIMIT 1];
			testCase.Tags__c = 'NoOpenCloseEmail, HydraReportingL1';
			testCase.Status = 'Closed';
			update testCase;

			Test.startTest();
			Map<String, Object> caseDetails = RoscoClose.getInitInfo(testCase.Id);
			Test.stopTest();

			Assert.isNotNull(caseDetails.keySet());
		}
	}

	@IsTest
	static void getPicklistValuesIncidentCause_AlwaysReturnIncidentPicklistValues() {
		Test.startTest();
		List<Map<String, String>> incidentPicklistValues = RoscoClose.getPicklistValuesIncidentCause();
		Test.stopTest();

		Assert.isTrue(incidentPicklistValues.size() > 0);
	}

	@IsTest
	static void getPicklistValuesIncidentCause2_AlwaysReturnIncidentPicklistValues() {
		Test.startTest();
		List<Map<String, String>> incidentPicklistValues = RoscoClose.getPicklistValuesIncidentCause2(
			'Technical Partnerships'
		);
		Assert.isTrue(incidentPicklistValues[0].get('label').contains('Partner Application'));

		incidentPicklistValues = RoscoClose.getPicklistValuesIncidentCause2('Support');
		Assert.isTrue(incidentPicklistValues[0].get('label').contains('Hardware Issue'));

		incidentPicklistValues = RoscoClose.getPicklistValuesIncidentCause2('Internal');
		Assert.isTrue(incidentPicklistValues[0].get('label').contains('TBD'));
		Test.stopTest();
	}

	@IsTest
	static void getPicklistValuesResolutionCodes_AlwaysReturnResolutionPicklistValues() {
		Test.startTest();
		List<Map<String, String>> resolutionPicklistValues = RoscoClose.getPicklistValuesResolutionCodes();
		Test.stopTest();

		Assert.isTrue(resolutionPicklistValues.size() > 0);
	}

	@IsTest
	static void getPicklistValuesResolutionCodes2_AlwaysReturnResolutionPicklistValues() {
		Test.startTest();
		List<Map<String, String>> resolutionPicklistValues = RoscoClose.getPicklistValuesResolutionCodes2(
			'Technical Partnerships'
		);
		Assert.isTrue(
			resolutionPicklistValues[0].get('label').contains('Application Accepted - Existing Partner')
		);

		resolutionPicklistValues = RoscoClose.getPicklistValuesResolutionCodes2('Support');
		Assert.isTrue(resolutionPicklistValues[0].get('label').contains('Solved (Bug Workaround)'));

		resolutionPicklistValues = RoscoClose.getPicklistValuesResolutionCodes2('Internal');
		Assert.isTrue(resolutionPicklistValues[0].get('label').contains('TBD'));
		Test.stopTest();
	}

	@IsTest
	static void saveCase_NonStandardEmail_WhenFieldsAreAllValid_updateCase() {
		Case testCase = [SELECT Id, Tags__c, AccountId, Status FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			testCase.Tags__c = 'HydraReportingL1';
			testCase.Status = 'Closed';
			testCase.Escalation_Level_Watermark__c = 'Level 2';

			Datetime laborDateDT = DateTime.Now();
			String laborDate = laborDateDT.formatGMT('yyyy-MM-dd\'T\'00:00:000.000\'Z\'');
			Rosco_Time__c roscoTime = new Rosco_Time__c(
				Case__c = testCase.Id,
				User__c = UserInfo.getUserId(),
				Minutes__c = 99,
				LaborCategory__c = 'laborCategory',
				LaborSubCategory__c = 'laborSubCategory',
				LaborDate__c = Date.valueOf(laborDate),
				Escalation_Level__c = 'Level 2',
				Account__c = testCase.AccountId,
				Role__c = UserInfo.getUserRoleId()
			);
			upsert new List<SObject>{ testCase, roscoTime };

			Test.startTest();
			String result = RoscoClose.saveCase(
				testCase.Id,
				'problem1',
				'solution1',
				'true',
				'true',
				'cause1',
				'resolution1',
				'false',
				'true',
				'Yes',
				'Tanium Deploy',
				'Deployments'
			);
			Test.stopTest();

			Assert.isTrue(String.isBlank(result), 'Successful save returns blank');
		}
	}

	@IsTest
	static void saveCase_StandardEmail_WhenFieldsAreAllValid_updateCase() {
		Case testCase = [SELECT Id, Tags__c, AccountId, Status FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			testCase.Tags__c = 'NoOpenCloseEmail, HydraReportingL1';
			testCase.Status = 'Closed';
			testCase.Escalation_Level_Watermark__c = 'Level 3';

			Datetime laborDateDT = DateTime.Now();
			String laborDate = laborDateDT.formatGMT('yyyy-MM-dd\'T\'00:00:000.000\'Z\'');
			Rosco_Time__c roscoTime = new Rosco_Time__c(
				Case__c = testCase.Id,
				User__c = UserInfo.getUserId(),
				Minutes__c = 99,
				LaborCategory__c = 'laborCategory',
				LaborSubCategory__c = 'laborSubCategory',
				LaborDate__c = Date.valueOf(laborDate),
				Escalation_Level__c = 'Level 3',
				Account__c = testCase.AccountId,
				Role__c = UserInfo.getUserRoleId()
			);
			upsert new List<SObject>{ testCase, roscoTime };

			Test.startTest();
			String result = RoscoClose.saveCase(
				testCase.Id,
				'problem1',
				'solution1',
				'true',
				'false',
				'cause1',
				'resolution1',
				'true',
				'false',
				'Yes',
				'Tanium Deploy',
				'Deployments'
			);
			Test.stopTest();

			Assert.isTrue(String.isBlank(result), 'Successful save returns blank');
		}
	}

	@IsTest
	static void saveCase_WhenNoRoscoTime_ReturnNoCaseTime() {
		Case testCase = [SELECT Id, Tags__c, AccountId, Status FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			testCase.Tags__c = 'HydraReportingL1';
			testCase.Status = 'Closed';
			testCase.Escalation_Level_Watermark__c = 'Level 3';

			update testCase;

			Test.startTest();
			String result = RoscoClose.saveCase(
				testCase.Id,
				'problem1',
				'solution1',
				'true',
				'false',
				'cause1',
				'resolution1',
				'false',
				'false',
				'Yes',
				'Tanium Deploy',
				'Deployments'
			);
			Test.stopTest();

			Assert.isTrue(
				result == 'NoCaseTime',
				'NoCaseTime should be returned when no rosco time record found.'
			);
		}
	}

	@IsTest
	static void saveCaseDup_WhenCaseIsSavedAsDuplicate_RelatedRecordsAreClonedAndReturnsBlank() {
		Case testCase = [SELECT Id, Tags__c, AccountId, Status FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Case dupCase = testCase.clone(false, false, false, false);

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

			FeedItem newPost = new FeedItem(
				ParentId = testCase.Id,
				Body = 'ROSCOTESTCASE',
				Visibility = 'InternalUsers',
				IsRichText = true
			);

			insert new List<SObject>{ dupCase, newEmail, newPost };

			Attachment attach = new Attachment();
			attach.Name = 'ROSCOTESTCASE';
			Blob bodyBlob = Blob.valueOf('ROSCOTESTCASE');
			attach.Body = bodyBlob;
			attach.ParentId = newEmail.Id;
			insert attach;

			Test.startTest();
			String result = RoscoClose.saveCaseDup(testCase.Id, dupCase.Id, 'true');

			Test.stopTest();

			Assert.isTrue(String.isBlank(result), 'Successful save returns blank');
		}
	}

	@IsTest
	static void saveCaseDup_WhenExceptionOccured_ReturnsMergingCaseError() {
		Case testCase = [SELECT Id, ContactId, AccountId, Status FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.rosco_case_ownerid__c = '0123456';

			Case dupCase = testCase.clone(false, false, false, false);
			insert new List<SObject>{ dupCase, cmSetting };

			Test.startTest();
			String result = RoscoClose.saveCaseDup(testCase.Id, dupCase.Id, 'true');

			Test.stopTest();

			Assert.isTrue(
				result.contains('Error merging case'),
				'Return should have "Error merging case"'
			);
		}
	}

	@IsTest
	static void getDuplicateCaseLookup_WhenKeyWordNotBlank_SearchSubjectOrCaseNumber() {
		Case testCase = [SELECT Id, Subject, AccountId, Status FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('testAccount');
			insert acc;

			Case dupCase = testCase.clone(false, false, false, false);
			dupCase.AccountId = acc.Id;
			insert dupCase;

			Test.startTest();
			List<Map<String, String>> duplicateCase = RoscoClose.getDuplicateCaseLookup(
				testCase.Subject,
				testCase.Id
			);

			Test.stopTest();

			Assert.areEqual(
				String.valueOf(dupCase.Id),
				duplicateCase[0].get('Id'),
				'dupCase record id should be included in the return'
			);

			Assert.isTrue(
				duplicateCase[0].get('Description').contains(testCase.Subject),
				'dupCase should have the test case subject'
			);

			Assert.isTrue(
				duplicateCase[0].get('Description').contains('Warning: Different Account'),
				'Description should have a warning that dupCase has different account'
			);
		}
	}

	@IsTest
	static void getDuplicateCaseLookup_WhenKeyWordBlank_SearchAccountId() {
		Case testCase = [SELECT Id, Subject, AccountId, Status FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Case dupCase = testCase.clone(false, false, false, false);
			insert dupCase;

			Test.startTest();
			RoscoClose.nullOrEmpty('');
			List<Map<String, String>> duplicateCase = RoscoClose.getDuplicateCaseLookup(
				null,
				testCase.Id
			);

			Test.stopTest();

			Assert.areEqual(
				String.valueOf(dupCase.Id),
				duplicateCase[0].get('Id'),
				'dupCase record id should be included in the return'
			);

			Assert.isFalse(
				duplicateCase[0].get('Description').contains('Warning: Different Account'),
				'Description should NOT have a warning that dupCase has different account'
			);
		}
	}

	@IsTest
	static void test_getComponentAndSubComponentPicklist() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			Map<String, Object> picklistValues = RoscoClose.getComponentAndSubComponentPicklist();

			Test.stopTest();

			List<Map<String, String>> components = (List<Map<String, String>>) picklistValues.get(
				'components'
			);
			Map<String, List<String>> sub_components = (Map<String, List<String>>) picklistValues.get(
				'sub_components'
			);

			Assert.isFalse(components.isEmpty());
			Assert.isTrue(sub_components.get(components[0].get('value')) != null);
		}
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