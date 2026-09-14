@isTest
private class CaseSendToAccountSlackTest {
	// New bits for trigger mgmt
	static void CreateRecords() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	// End of new bits for trigger mgmt

	static testMethod void testAccountSlackCall() {
		CreateRecords();

		Case_Management__c cmExceptionSetting = new Case_Management__c();
		cmExceptionSetting.Name = '';
		cmExceptionSetting.rosco_case_url_prefix__c = 'foo';
		cmExceptionSetting.rosco_sfdc_dom_l__c = 'bar';
		insert cmExceptionSetting;

		Test.setMock(HttpCalloutMock.class, new mockCallout());
		//Account accountObj = new Account(name = 'testAccount', slack_channel_id__c = 'CH87S4VUJ');
		Account accountObj = TestFactory.buildAccount('testAccount');
		accountObj.slack_channel_id__c = 'CH87S4VUJ';
		insert accountObj;

		rosco_account__c ra = new rosco_account__c(
			Name = 'customer-foo',
			account__c = accountObj.Id,
			triage_flash__c = 'triageflash1',
			account_flash__c = 'accountflash1'
		);
		insert ra;

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
			subject = 'IGNORE:testing:jason',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			suppliedEmail = '00@outlook.comm'
		);
		insert caseObj;
		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		CaseSendToAccountSlack.sendToAccountSlack(lis);
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