/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CaseTimeTrackerController.
 * @Date: 2024-10-18
 * @Author: Savita Mirpuri, Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-8175      2024-10-18       Initial Development
 * SS-11136     2025-06-28       Test getCaseTime method
 * SS-11173     2025-07-10       Changed field from Severity__c to Severity_Community__c
 * SS-11345     2025-08-13       Test getCaseTimeStringDetails method
 * SS-13441     2026-06-29       Updated test class for new checkbox fields
 */
@IsTest
private class CaseTimeTrackerControllerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'UserTriggerHandler',
				'CaseTriggerHandler'
			}
		);

		User adminUser = TestUserFactory.getAdminUser();
		System.runAs(adminUser) {
			Account acc = TestFactory.buildAccount('Account Test 1');
			acc.OwnerId = adminUser.Id;
			insert acc;

			Contact customerContact = new Contact(
				Email = 'customerContact@tanium.com',
				FirstName = 'Test',
				LastName = 'Customer Contact',
				AccountId = acc.Id
			);
			insert customerContact;

			Case caseRecord = TestFactory.buildCase(acc.Id, customerContact.Id);
			caseRecord.Escalation_Level_Watermark__c = 'Level 3';
			caseRecord.OwnerId = adminUser.Id;
			caseRecord.RecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			caseRecord.Status_Details__c = 'Pending Development';
			caseRecord.ClosedDate = System.today().addDays(30);
			insert caseRecord;

			Rosco_Time__c timeLog1 = CaseTimeTrackerController.buildRoscoTime(
				caseRecord,
				'Support-Appliance',
				'60',
				false,
				false
			);
			timeLog1.LaborDate__c = Date.today().addDays(-6);
			timeLog1.User__c = adminUser.Id;

			Rosco_Time__c timeLog2 = CaseTimeTrackerController.buildRoscoTime(
				caseRecord,
				'Support-Appliance',
				'30',
				true,
				false
			);
			timeLog2.LaborDate__c = Date.today().addDays(-4);
			timeLog2.User__c = adminUser.Id;

			Rosco_Time__c timeLog3 = CaseTimeTrackerController.buildRoscoTime(
				caseRecord,
				'Support-Appliance',
				'15',
				false,
				true
			);
			timeLog3.LaborDate__c = Date.today().addDays(-2);
			timeLog3.User__c = adminUser.Id;
			insert new List<Rosco_Time__c>{ timeLog1, timeLog2, timeLog3 };
		}
	}

	@IsTest
	static void testGetCaseTime_AlwaysReturnTotalCaseAndUserTime() {
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];

		Map<String, Integer> timeDetails;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			timeDetails = CaseTimeTrackerController.getCaseTime(caseRecord.Id);
			Test.stopTest();
		}

		Integer caseTime = timeDetails.get('caseTotalTime');
		Integer userTime = timeDetails.get('userTotalTime');
		Assert.areEqual(105, caseTime, 'Total Case Time should be 105');
		Assert.areEqual(105, userTime, 'User Time should be 105');
	}

	@IsTest
	static void testCaseSaveTime_whenNoException_returnsTotalCaseAndUserTime() {
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];

		EnhancedReturnType enhancedReturn = new EnhancedReturnType();
		System.runAs(TestUserFactory.getAdminUser()) {
			delete [SELECT Id FROM Rosco_Time__c];

			Test.startTest();
			String result = CaseTimeTrackerController.saveCaseTime(
				caseRecord.Id,
				'Support',
				'60',
				false,
				false
			);
			enhancedReturn = (EnhancedReturnType) JSON.deserialize(result, EnhancedReturnType.class);
			Test.stopTest();
		}

		Assert.isTrue(enhancedReturn.retResult, 'no exception');
		Assert.isTrue(
			enhancedReturn.retData.contains('60***60'),
			'Case Total Time and User Time should be the same.'
		);
	}

	@IsTest
	static void testCaseSaveTime_whenException_returnsSaveResultAccurately() {
		EnhancedReturnType enhancedReturn = new EnhancedReturnType();

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			String result = CaseTimeTrackerController.saveCaseTime(null, null, null, false, false);
			enhancedReturn = (EnhancedReturnType) JSON.deserialize(result, EnhancedReturnType.class);
			Test.stopTest();
		}

		Assert.isFalse(enhancedReturn.retResult);
		Assert.areEqual(enhancedReturn.retData, 'Please choose the time you want to log.');
	}

	@IsTest
	static void testCaseSaveTime_whenHasExistingRoscoTimeRecordsForCase_returnsUpdatedCaseAndUserTime() {
		EnhancedReturnType enhancedReturn = new EnhancedReturnType();
		Case caseRecord = [SELECT Id, AccountId FROM Case LIMIT 1];

		String result;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			result = CaseTimeTrackerController.saveCaseTime(
				caseRecord.Id,
				'Support-Appliance',
				'5',
				true,
				false
			);
			enhancedReturn = (EnhancedReturnType) JSON.deserialize(result, EnhancedReturnType.class);
			Test.stopTest();
		}

		Assert.isTrue(enhancedReturn.retResult);
		Assert.areEqual(
			String.valueOf(110),
			enhancedReturn.retData.split('\\*\\*\\*')[0],
			'Total Case Time should be 110.'
		);
		Assert.areEqual(
			String.valueOf(110),
			enhancedReturn.retData.split('\\*\\*\\*')[1],
			'User Time should be 110.'
		);
	}

	@IsTest
	static void testGetCaseTimeString_WhenTimeSubCategoryExists_ReturnMostRecentTimeSubCategory() {
		Case caseRecord = [SELECT Id FROM Case LIMIT 1];

		Map<String, String> timeDetails;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			timeDetails = CaseTimeTrackerController.getCaseTimeStringDetails(caseRecord.Id);
			Test.stopTest();
		}

		String laborSubCategory = timeDetails.get('laborSubCategory');
		Assert.areEqual(
			'Support-Appliance',
			laborSubCategory,
			'Labor Sub Category should be Support-Appliance'
		);
	}
}