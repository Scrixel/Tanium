@isTest
private class CaseSendToSMESlackTest {
	static void CreateRecords() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	static testMethod void testSMESlackCallWithoutContact() {
		System.debug('entering testSMESlackCallWithoutContact');
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		// Sending w/o an account or a contact...
		TAM_Team__c teamObj = new TAM_Team__c(
			Name = 'Test',
			Slack_Ticket_Channel_ID__c = 'G6HDQMPM0',
			SME_Component_Name__c = 'Other',
			SME_Component_Picklist_Value__c = 'Other'
		);
		insert teamObj;
		Case caseObj = new Case(
			subject = 'IGNORE:testing:matt:20180608.1009:testSMESlackCallWithoutContact',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			Component__c = 'Other',
			suppliedEmail = 'matt+testapex@mindvault.com'
		);
		insert caseObj;
		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		System.debug(caseObj.subject);
		CaseSendToAccountSlack.sendToAccountSlack(lis);
	}

	static testMethod void testSMESlackCall() {
		System.debug('entering testSMESlackCall');
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		//Account accountObj = new Account(name = 'testAccount', slack_channel_id__c = 'C72LD4NN5');
		Account accountObj = TestFactory.buildAccount('testAccount');
		accountObj.slack_channel_id__c = 'CH87S4VUJ';
		insert accountObj;
		Contact contactObj = new Contact(
			Email = 'matt+testapex@mindvault.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.id
		);
		insert contactObj;
		TAM_Team__c teamObj = new TAM_Team__c(
			Name = 'Test',
			Slack_Ticket_Channel_ID__c = 'G6HDQMPM0',
			SME_Component_Name__c = 'Other',
			SME_Component_Picklist_Value__c = 'Other'
		);
		insert teamObj;
		Case caseObj = new Case(
			ContactId = contactObj.id,
			accountid = accountObj.id,
			subject = 'IGNORE:testing:matt:20180608.1009:testSMESlackCall',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			Component__c = 'Other',
			suppliedEmail = 'matt+testapex@mindvault.com'
		);
		insert caseObj;
		rosco_account__c ra = new rosco_account__c(
			Name = 'customer-foo',
			account__c = accountObj.Id,
			triage_flash__c = 'triageflash1',
			account_flash__c = 'accountflash1'
		);
		insert ra;

		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		System.debug(caseObj.subject);
		CaseSendToSMESlack.sendToSMESlack(lis);
	}

	static testMethod void testSMESlackCallWithNoSMEGroup() {
		System.debug('entering testSMESlackCallWithNoSMEGroup');
		CreateRecords();
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		//Account accountObj = new Account(name = 'testAccount', slack_channel_id__c = 'C72LD4NN5');
		Account accountObj = TestFactory.buildAccount('testAccount');
		accountObj.slack_channel_id__c = 'CH87S4VUJ';
		insert accountObj;
		Contact contactObj = new Contact(
			Email = 'matt+testapex@mindvault.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.id
		);
		insert contactObj;
		System.debug('testSMESlackCallWithNoSMEGroup: pre case creation');
		Case caseObj = new Case(
			ContactId = contactObj.id,
			accountid = accountObj.id,
			subject = 'IGNORE:testing:matt:20180608.1009:testSMESlackCallWithNoSMEGroup',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			Component__c = 'Other',
			suppliedEmail = 'matt+testapex@mindvault.com'
		);
		insert caseObj;
		System.debug('testSMESlackCallWithNoSMEGroup: post case creation');
		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		System.debug(caseObj.subject);
		CaseSendToSMESlack.sendToSMESlack(lis);
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