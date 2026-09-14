/*
 * Copyright (c) 2025 Tanium
 *
 * @DATE: 2018-08-28
 * @AUTHOR: Cumulus Vision
 * @REQUEST: TAN-629
 * @BUSINESS: Test class for the CaseTrigger.tgr and CaseTriggerHandler class.
 * RequestId     ModifiedDate    Comment
 * TAN-629       2018-08-28      Initial Development
 * SS-11173      2025-07-10      Changed field from Severity__c to Severity_Community__c
 * SS-12185      2025-12-09      Cleanup legacy code
 */
@IsTest
private class CaseTriggerHandlerTest {
	@IsTest
	static void testPopulateSeverityForCommunityCases_Always_PopulateSeverity() {
		Test.startTest();
		Test.setMock(HttpCalloutMock.class, new CaseSendToSlackMock());

		Case caseRec = new Case(Origin = 'Community', Severity_Community__c = '3');
		insert caseRec;

		Test.stopTest();

		caseRec = [SELECT Id, Severity_Community__c FROM Case WHERE Id = :caseRec.Id];
		Assert.areEqual(Integer.valueOf(caseRec.Severity_Community__c), 3);
	}
}