@isTest
private class CaseSendToEscalationSlackTest {
	static void CreateRecords() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	static testMethod void testEscalationSlackCall() {
		Case_Management__c cmSetting = new Case_Management__c();
		cmSetting.Name = '';
		cmSetting.rosco_case_url_prefix__c = 'foo';
		cmSetting.rosco_sfdc_dom_l__c = 'foo';
		insert cmSetting;

		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		/*Account accountObj = new Account(name='testAccount',
		 slack_channel_id__c='C72LD4NN5');*/
		Account accountObj = TestFactory.buildAccount('testAccount');
		accountObj.slack_channel_id__c = 'CH87S4VUJ';

		insert accountObj;
		rosco_account__c ra = new rosco_account__c(
			Name = 'customer-foo',
			account__c = accountObj.Id,
			case_flash__c = 'caseflash1'
		);
		insert ra;
		Contact contactObj = new Contact(
			Email = 'matt+testapex@mindvault.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.id
		);
		insert contactObj;
		Case caseObj = new Case(
			ContactId = contactObj.id,
			accountid = accountObj.id,
			subject = 'IGNORE:testing:matt:20180313.1009',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			suppliedEmail = 'matt+testapex@mindvault.com'
		);
		insert caseObj;
		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		CaseSendToEscalationSlack.sendToEscalationSlack(lis);
	}

	static testMethod void testEscalationSlackCallWithNoContact() {
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		/*Account accountObj = new Account(name='testAccount',
		 slack_channel_id__c='C72LD4NN5');*/
		Account accountObj = TestFactory.buildAccount('testAccount');
		accountObj.slack_channel_id__c = 'CH87S4VUJ';
		insert accountObj;
		Case caseObj = new Case(
			accountid = accountObj.id,
			subject = 'IGNORE:testing:matt:20180313.1009',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			suppliedEmail = 'matt+testapex@mindvault.com'
		);
		insert caseObj;
		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		CaseSendToEscalationSlack.sendToEscalationSlack(lis);
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