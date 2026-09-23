@isTest
public with sharing class CaseSendPrivateCommentTest {
	// New bits for trigger mgmt
	static void CreateRecords() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	@isTest
	static void TestSendPrivateComment() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());

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
			LatestPrivateCommentHTML__c = '<html>hello</html>',
			status = 'On Hold'
		);
		insert caseObj;

		CaseContactRole ccrObj = new CaseContactRole(CasesId = caseObj.Id, ContactId = contactObj2.Id);
		insert ccrObj;

		Case casecreated = RoscoUtility.getCaseDetails(caseObj.Id);
		List<Case> cases = new List<Case>();
		cases.add(casecreated);

		CaseSendPrivateComment.sendPrivateComment(cases);
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