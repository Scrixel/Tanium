/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for SurveyTriggerHandler
 * @Date: 2026-04-27
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13032   2026-04-27    Modified test class
 **/
@IsTest
private class SurveyTriggerHandlerTest {
	@IsTest
	static void caseSurveyTestOneSurvey() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'CaseTriggerHandler' }
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Account for survey');
			insert account;

			Contact contact = new Contact(
				Email = 'survey@tanium.com',
				FirstName = 'Test',
				LastName = 'Contact',
				AccountId = account.Id
			);

			Case cs = new Case(
				ContactId = contact.Id,
				Accountid = account.Id,
				Subject = 'ROSCOTESTCASE',
				Severity_Community__c = '3',
				Type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				SuppliedEmail = '99@outlook.com',
				Status = 'On Hold',
				Description = 'Case Description',
				RecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support')
			);
			insert cs;

			Survey__c survey = new Survey__c();
			survey.Name = 'Support Center CSAT';
			survey.Case__c = cs.Id;
			survey.SurveyCreateDate__c = Datetime.now();
			survey.Case_1_Recommend__c = '10';
			survey.Case_2_Overall_Support__c = 'Not so satisfied';
			survey.Case_3_Speed_of_Resolution__c = 'Not so satisfied';
			survey.Case_4_Technical_Knowledge__c = 'Not so satisfied';
			survey.Case_5_Issue_Resolved__c = 'No';
			survey.Case_6_Comment__c = 'comment 123';
			insert survey;
		}
	}
}