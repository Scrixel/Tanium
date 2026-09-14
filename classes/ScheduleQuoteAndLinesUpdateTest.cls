@IsTest
private class ScheduleQuoteAndLinesUpdateTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'QuoteLineTriggerHandler',
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);
		SBQQ.TriggerControl.disable();

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = new Account(
				Name = 'Test Account',
				Total_Addressable_Seats__c = 1000,
				Type = 'Analyst'
			);
			insert acc;

			Opportunity opp = new Opportunity(
				Name = 'Test Opp',
				CloseDate = System.today(),
				StageName = Utility.CLOSED_WON,
				AccountId = acc.Id,
				Pricebook2Id = Test.getStandardPricebookId()
			);
			insert opp;
		}
	}

	@IsTest
	static void execute_CreateSchedule() {
		Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
		Set<Id> setOppIds = new Set<Id>{ opp.Id };

		Test.startTest();
		String schedule = OpportunityRenewalUtility.generateSchedule(Datetime.now());
		String jobId = System.schedule(
			'testUpdateQuoteAndLines',
			schedule,
			new ScheduleQuoteAndLinesUpdate(setOppIds)
		);

		CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :jobId];
		System.assertEquals(true, schedule.equalsIgnoreCase(ct.CronExpression));
		Test.stopTest();
	}
}