/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Controller class for CaseTimeTracker LWC.
 * @Date: 2024-10-18
 * @Author: Savita Mirpuri, Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-8175      2024-10-18       Initial Development
 * SS-11136     2025-06-28       Create getCaseTime method
 * SS-11364     2025-08-05       Update Roco Time log
 * SS-11345     2025-08-13       Added logic to get laborSubCategory for the current user
 * SS-13441     2026-06-29       Updated controller with new checkboxes functionality
 */
public without sharing class CaseTimeTrackerController {
	static final String CLASS_NAME = 'CaseTimeTrackerController';

	@AuraEnabled
	public static Map<String, Integer> getCaseTime(String caseId) {
		Map<String, Integer> timeDetails = new Map<String, Integer>();
		String userId = UserInfo.getUserId();
		Integer caseTime = 0;
		Integer userTime = 0;
		Integer minutes = 0;

		for (AggregateResult aggregateResult : [
			SELECT Case__c, User__c, SUM(Minutes__c) userTime
			FROM Rosco_Time__c
			GROUP BY Case__c, User__c
			HAVING Case__c = :caseId
		]) {
			minutes = Integer.valueOf(String.valueOf(aggregateResult.get('userTime')));
			caseTime += minutes;
			if (userId == String.valueOf(aggregateResult.get('User__c'))) {
				userTime = minutes;
			}
		}
		timeDetails.put('userTotalTime', userTime);
		timeDetails.put('caseTotalTime', caseTime);
		return timeDetails;
	}

	@AuraEnabled
	public static Map<String, String> getCaseTimeStringDetails(String caseId) {
		Map<String, String> caseKeyToValue = new Map<String, String>();

		List<Rosco_Time__c> roscoTimes = [
			SELECT Id, LaborSubCategory__c
			FROM Rosco_Time__c
			WHERE Case__c = :caseId AND User__c = :UserInfo.getUserId()
			ORDER BY CreatedDate DESC
			LIMIT 1
		];
		String laborSubCategory = roscoTimes.isEmpty()
			? 'Support'
			: roscoTimes[0].LaborSubCategory__c;

		caseKeyToValue.put('laborSubCategory', laborSubCategory);
		return caseKeyToValue;
	}

	@AuraEnabled
	public static String saveCaseTime(
		String recordId,
		String laborSubCategory,
		String selectedTime,
		Boolean isAIUsed,
		Boolean isAIToolingDeveloped
	) {
		EnhancedReturnType enhancedReturn = new EnhancedReturnType(false, '');
		Map<String, Integer> timeDetails = new Map<String, Integer>();
		Rosco_Time__c roscoTime = new Rosco_Time__c();

		if (String.isBlank(selectedTime)) {
			enhancedReturn.retData = 'Please choose the time you want to log.';
			return JSON.serialize(enhancedReturn);
		}

		Case caseRecord = [
			SELECT Id, AccountId, Escalation_Level_Watermark__c
			FROM Case
			WHERE Id = :recordId
		];
		roscoTime = buildRoscoTime(
			caseRecord,
			laborSubCategory,
			selectedTime,
			isAIUsed,
			isAIToolingDeveloped
		);
		Database.SaveResult saveResult = Database.insert(roscoTime, true);
		if (saveResult.isSuccess()) {
			timeDetails = getCaseTime(recordId);
			enhancedReturn.retResult = true;
			enhancedReturn.retData =
				timeDetails.get('caseTotalTime') +
				'***' +
				timeDetails.get('userTotalTime');
		} else {
			enhancedReturn.retData = saveResult.getErrors()[0].getMessage();
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'CaseTimeTrackerController.saveCaseTime ERRORS',
					new List<Database.SaveResult>{ saveResult }
				)
				.addTag('apex');
		}
		return JSON.serialize(enhancedReturn);
	}

	@TestVisible
	private static Rosco_Time__c buildRoscoTime(
		Case caseRecord,
		String laborSubCategory,
		String selectedTime,
		Boolean isAIUsed,
		Boolean isAIToolingDeveloped
	) {
		String laborCategory = laborSubCategory.equals('Support') ? 'Case Account Time' : 'SME Time';
		return new Rosco_Time__c(
			Account__c = caseRecord.AccountId,
			Case__c = caseRecord.Id,
			Escalation_Level__c = caseRecord.Escalation_Level_Watermark__c,
			LaborCategory__c = laborCategory,
			LaborSubCategory__c = laborSubCategory,
			LaborDate__c = System.now(),
			Minutes__c = Integer.valueOf(selectedTime),
			User__c = UserInfo.getUserId(),
			Support_AI_Agent_Tool_Used_on_Case__c = isAIUsed,
			Support_AI_Agent_Tool_Development__c = isAIToolingDeveloped
		);
	}
}