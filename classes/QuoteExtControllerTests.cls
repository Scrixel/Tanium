@isTest
private class QuoteExtControllerTests {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' });
		Account acct = TestFactory.buildAccount('Test Account');
		insert acct;

		Opportunity opp = TestFactory.buildOpportunity(
			'Test Opportunity',
			Date.today(),
			Utility.PROSPECTING,
			acct.Id
		);
		insert opp;

		insert TestFactory.buildSBQQ_Quote(opp.Id, acct.Id, 'Draft', null, null, null, null);
	}

	@isTest
	static void submitQuote_WhenQuoteSubmitted_QuoteStatusIsApproved() {
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

		Test.startTest();
		QuoteExtController con = new QuoteExtController(new ApexPages.StandardController(quote));
		con.onSubmit();
		Test.stopTest();

		quote = [SELECT ApprovalStatus__c FROM SBQQ__Quote__c WHERE Id = :quote.Id LIMIT 1];

		System.assertEquals('Approved', quote.ApprovalStatus__c);
	}

	testMethod static void recallQuote_WhenQuoteRecalled_QuoteStatusIsRecalled() {
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

		Test.startTest();
		QuoteExtController con = new QuoteExtController(new ApexPages.StandardController(quote));
		con.onRecall();
		Test.stopTest();

		quote = [SELECT ApprovalStatus__c FROM SBQQ__Quote__c WHERE Id = :quote.Id LIMIT 1];

		System.assertEquals('Recalled', quote.ApprovalStatus__c);
	}
}