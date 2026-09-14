@IsTest
private class FlowUtilityTest {
	@TestSetup
	static void createTestData() {
	}

	@IsTest
	private static void testFlowUtility() {
		List<FlowUtility.TriggerNames> triggerNamesList = new List<FlowUtility.TriggerNames>();
		FlowUtility.TriggerNames triggerNamesRecord = new FlowUtility.TriggerNames();
		triggerNamesRecord.sBQQTriggerControl = true;
		triggerNamesRecord.accountTriggerHandler = true;
		triggerNamesRecord.contactTriggerHandler = true;
		triggerNamesRecord.opportunityTriggerHandler = true;
		triggerNamesRecord.quoteCPQTriggerHandler = true;
		triggerNamesList.add(triggerNamesRecord);

		Test.startTest();
		FlowUtility.bypassTriggers(triggerNamesList);
		Test.stopTest();

		Assert.isTrue(AccountTriggerHandler.isBypassed('AccountTriggerHandler'));
	}
}