@isTest
private class CaseSendToFedSlackTest {
	static void CreateRecords() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	static testMethod void testFedSlackCall() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		//Account accountObj = new Account(name = 'testAccount', slack_channel_id__c = 'CH87S4VUJ');

		Account accountObj = TestFactory.buildAccount('testAccount');
		accountObj.slack_channel_id__c = 'CH87S4VUJ';
		insert accountObj;
		Contact contactObj = new Contact(
			Email = '99@outlook.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.id
		);
		insert contactObj;
		Case caseObj = new Case(
			ContactId = contactObj.id,
			accountid = accountObj.id,
			subject = 'ROSCOTESTCASE',
			Severity_Community__c = '2',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			suppliedEmail = '00@outlook.comm'
		);
		insert caseObj;
		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		CaseSendToFedSlack.sendToFedSlack(lis);
		Boolean foo = CaseSendToFedSlack.nullOrEmpty('foo');
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