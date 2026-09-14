@isTest
private class CaseSendToPagerTest {
	static void CreateRecords() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	static testMethod void testCasePager() {
		CreateRecords();
		Account accountObj = new Account(name = 'testAccount');
		insert accountObj;
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
			subject = 'IGNORE:testing:matt:20180301.01',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			suppliedEmail = 'matt@mindvault.com'
		);
		insert caseObj;
		List<Case> lis = new List<Case>();
		lis.add(caseObj);
		CaseSendToPager.sendToPager(lis);

		Boolean test;
		test = CaseSendToPager.nullOrEmpty('foo');
	}
}