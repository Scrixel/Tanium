@isTest
public with sharing class RoscoStateTest {
	static void CreateRecords() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	@isTest(SeeAllData=false)
	static void TestIt() {
		CreateRecords();
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

		System.runAs(TestUserFactory.getAdminUser()) {
			Account accountObj = TestFactory.buildAccount('roscoapextestingd');
			accountObj.slack_channel_id__c = 'TESTCASE';
			insert accountObj;

			rosco_account__c ra = new rosco_account__c(
				Name = 'customer-foo',
				account__c = accountObj.Id,
				triage_flash__c = 'triageflash1',
				account_flash__c = 'accountflash1'
			);
			insert ra;
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
				Component__c = 'Workbench-Patch',
				status = 'On Hold',
				Tags__c = 'foo'
			);
			insert caseObj;
			CaseContactRole ccrObj = new CaseContactRole(
				CasesId = caseObj.Id,
				ContactId = contactObj.Id
			);
			insert ccrObj;

			// Email Message to start case
			Messaging.InboundEmail.Header hd = new Messaging.InboundEmail.Header();
			EmailMessage testCaseEmail = new EmailMessage(
				textBody = 'footext',
				htmlBody = '<html><ol><li>foo</li></ol></html>',
				subject = 'foosubject',
				fromName = 'foo name',
				fromAddress = 'foo@bar.com',
				ToAddress = 'footo@bar.com',
				relatedToId = caseObj.Id,
				incoming = true
			);
			insert testCaseEmail;

			//Case casecreated = RoscoUtility.getCaseDetails(caseObj.Id);

			RoscoState.getInitInfo(caseObj.Id);
			RoscoState.saveCase(
				caseObj.Id, //caseid
				'subjective1', //subjective
				'objective1', //objective
				'assessment1', //assessment
				'plan1', //plan
				'Low', //priority
				'true', //soap email customer
				'', //condition
				'', //action
				'', //need
				'false', //can email customer
				'false' //critsit
			);
			RoscoState.getInitInfo(caseObj.Id);

			RoscoState.saveCase(
				caseObj.Id, //caseid
				'', //subjective
				'', //objective
				'', //assessment
				'', //plan
				'Medium', //priority
				'false', //soap email customer
				'condition1', //condition
				'action1', //action
				'need1', //need
				'false', //can email customer
				'false' //critsit
			);
			RoscoState.getInitInfo(caseObj.Id);

			RoscoState.nullOrEmpty(caseObj.Id);
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