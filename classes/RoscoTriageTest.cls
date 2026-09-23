/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for RoscoTriage
 * @Date:
 * @Author: Cumulus Vision
 * @Request:
 * RequestId  ModifiedDate  Description
 * TAN-832	  2019-18-11    Test methods updated..
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the test class
 */
@isTest
public with sharing class RoscoTriageTest {
	static void CreateRecords() {
		TriggerHandler.bypass(new List<String>{ 'ContactTriggerHandler', 'AccountTriggerHandler' });
	}

	@isTest(SeeAllData=false)
	static void TestIt() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'].Id;

		User userObj = TestFactory.buildUser(
			'ApexUser',
			'roscoapextest@roscolab.com',
			'roscoapextest@roscolab.com',
			profileId
		);
		userObj.Email = 'roscoapextest@roscolab.com';
		userObj.FirstName = 'Test';
		userObj.LastName = 'ApexUser';
		userObj.Username = 'roscoapextest@roscolab.com';
		userObj.Alias = 'afdsa';
		userObj.CommunityNickname = 'asfdasf';
		userObj.TimeZoneSidKey = 'America/Los_Angeles';
		userObj.LocaleSidKey = 'en_US';
		userObj.EmailEncodingKey = 'ISO-8859-1';
		userObj.ProfileId = profileId;
		userObj.LanguageLocaleKey = 'en_US';
		insert userObj;

		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
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

			RoscoTriage.getCaseContactLookup('foo', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseContactLookup('', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseContactLookup('rosco', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseOwnerLookup('foo', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseOwnerLookup('', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseOwnerLookup('newcaseinit', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseAccountLookup('foo', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseAccountLookup('', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseAccountLookupSales('foo', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseAccountLookupSales('', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseInfo(caseObj.Id);
			RoscoTriage.getCaseInfo('newcase');
			RoscoTriage.getCaseInfoTSE(caseObj.Id);
			RoscoTriage.getCaseInfoTSE('newcase');
			RoscoTriage.getPicklistValuesCaseComponent();
			RoscoTriage.getPods();
			RoscoTriage.getCasePreferredTAMLookup(
				'',
				String.valueOf(caseObj.Id),
				String.valueOf(accountObj.Id),
				''
			);
			RoscoTriage.getCasePreferredTAMLookup(
				'foo',
				String.valueOf(caseObj.Id),
				String.valueOf(accountObj.Id),
				''
			);
			RoscoTriage.getCaseOppLookup('', caseObj.Id, accountObj.Id);
			RoscoTriage.getCaseOppLookup('foo', caseObj.Id, accountObj.Id);
			RoscoTriage.getSalesCaseContactId();

			Map<String, Object> caseinfo = new Map<String, Object>();
			caseinfo.put('caseId', caseObj.Id);
			caseinfo.put('accountId', accountObj.Id);
			caseinfo.put('componentversion', '123');
			caseinfo.put('case_component', 'Other');
			caseinfo.put('contactId', contactObj.Id);
			caseinfo.put('jira', '1');
			caseinfo.put('ownerId', userObj.Id);
			caseinfo.put('severity', '3');
			caseinfo.put('status', 'On Hold');
			caseinfo.put('status_details', '');
			caseinfo.put('subject', 'Subject123');
			caseinfo.put('tags', 'tag1');
			caseinfo.put('case_type', 'Incident');
			caseinfo.put('richtext', 'blah');

			caseinfo.put('ccrstring', 'rosco1@tanium.com;rosco2@tanium.com');
			RoscoTriage.saveCase(caseinfo);
			RoscoTriage.saveCaseTSE2(caseinfo);
		}
	}

	@isTest(SeeAllData=true)
	static void test_Unit_createCase() {
		List<Map<String, String>> result = RoscoTriage.getCaseOppLookup('', '', '');
		System.debug('result:' + result);
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