/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoInfo
 * @Date:
 * @Author: Cumulus Vision
 * @Request:
 * Modified  ModifiedDate   Description
 * TAN-832	  2019-18-11    Test methods updated.
 * SS-9852    2025-01-24    Added test method
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */
@IsTest
private class RoscoInfoTest {
	@TestSetup
	static void makeData() {
		Id taniumCloudRecTypeId = Utility.getRecordTypeIdByAPIName('Server_Deployment__c', 'TaaS');
		String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName('Case', 'Support');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			account.Type = 'Prospect';
			insert account;

			Contact contact = TestFactory.buildContact(account.Id);
			insert contact;

			List<Server_Deployment__c> serverDeployments = new List<Server_Deployment__c>();
			serverDeployments.add(
				new Server_Deployment__c(
					Account__c = account.Id,
					RecordTypeId = taniumCloudRecTypeId,
					Server_Device_Type__c = 'Tanium as a Service',
					Cloud_Provider__c = 'AWS'
				)
			);

			insert serverDeployments;

			Case caseObj = new Case(
				ContactId = contact.id,
				accountid = account.id,
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
		}
	}

	@IsTest
	static void testGetInitInfo_WhenCaseRecordIsExisting_GetCaseDetails() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = new User(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'ApexUser',
			Username = 'roscoapextest@roscolab.com',
			Alias = 'testals',
			CommunityNickname = 'testcommnickname',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US'
		);

		insert userObj;

		Account accountObj = TestFactory.buildAccount('ROSCOTESTCASE');
		accountObj.slack_channel_id__c = 'TESTCASE';

		insert accountObj;
		Contact contactObj = new Contact(
			Email = 'roscoapextest@roscolab.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = null
		);
		insert contactObj;
		Contact contactObj2 = new Contact(
			Email = 'roscoapextest@tanium.com',
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

		Survey__c s = new Survey__c();
		//s.Account__c = '00160000018u4tdAAA'
		s.Case_1_Recommend__c = '10';
		s.Case_2_Overall_Support__c = 'Very Satisfied';
		s.Case_2_Satisfaction__c = '100';
		s.Case_3_Speed_of_Resolution__c = 'Very Satisfied';
		s.Case_4_Technical_Knowledge__c = 'Very Satisfied';
		s.Case_5_Issue_Resolved__c = 'Yes';
		s.Case_6_Comment__c = 'Comment1';
		s.Name = 'Support Center CSAT';
		s.SurveyCreateDate__c = System.Datetime.now();
		s.Case__c = String.valueOf(caseObj.Id);
		insert s;

		rosco_people__c peep = new rosco_people__c(
			Name = 'roscoapextestingd',
			contact__c = contactObj.Id,
			user__c = userObj.Id,
			pod__c = 'Central',
			psme__c = 'SME-Patch',
			ssme__c = 'SME-Map'
		);
		insert peep;

		rosco_escalation_rbac__c rbac = new rosco_escalation_rbac__c(
			Name = '4',
			authorized__c = userObj.Id
		);
		insert rbac;

		rosco_people__c sme = new rosco_people__c(
			Name = 'slack.name',
			contact__c = contactObj.Id,
			user__c = userObj.Id,
			pod__c = 'Central',
			psme__c = 'SME-Patch',
			ssme__c = 'SME-Map'
		);
		insert sme;

		TAM_Team__c team = new TAM_Team__c(
			Name = 'Patch',
			SME_Component_Name__c = 'Workbench-Patch',
			Slack_Ticket_Channel_ID__c = 'CCC66LTRT'
		);
		insert team;

		Case casecreated = RoscoUtility.getCaseDetails(caseObj.Id);
		List<Case> cases = new List<Case>();
		cases.add(casecreated);

		RoscoInfo.getInitInfo(caseObj.Id);
		RoscoInfo.nullOrEmpty(caseObj.Id);
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
	static void testGetSDR_WhenThereAreServerDeploymentRecords_ReturnResult() {
		List<Map<String, String>> result = new List<Map<String, String>>();
		Case caseRec = [SELECT Id FROM Case LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = RoscoInfo.getSDR(caseRec.Id);
			Test.stopTest();
		}

		Assert.isTrue(result != null);
	}
}