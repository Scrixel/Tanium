/**
 * @Business: RoscoInfo
 * @Date:
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-9852    2025-01-24    Added app name return on init
 */
public with sharing class RoscoInfo {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** getInitInfo
	 * @param caseId - case to retrieve Case escalation info
	 * @return Map of Escalation Info
	 */
	@AuraEnabled
	public static Map<String, String> getInitInfo(String caseId) {
		Map<String, String> ret = new Map<String, String>();

		try {
			ret = getLatestSurvey(caseId);
			ret.put('supportinfo', '');

			String accountId = getAccountId(caseId);

			String soql =
				'SELECT Support_Info__c ' +
				'FROM Rosco_Account__c ' +
				'WHERE account__c = \'' +
				accountId +
				'\'';

			List<Rosco_Account__c> raccounts = Database.query(soql);

			if (!raccounts.isEmpty()) {
				String supportinfo = '';
				if (raccounts[0].Support_Info__c != null) {
					ret.put('supportinfo', String.valueOf(raccounts[0].Support_Info__c));
				}
			}

			// Case details
			Case c = RoscoUtility.getCaseDetails(caseId);
			if (c.CreatedDate == null) {
				ret.put('CreatedDate', 'Error');
			} else {
				ret.put('CreatedDate', String.valueOf(c.CreatedDate));
			}
			if (c.First_Assigned_Date__c == null) {
				ret.put('First_Assigned_Date', 'n/a');
			} else {
				ret.put('First_Assigned_Date', String.valueOf(c.First_Assigned_Date__c));
			}
			if (c.First_Response_Date__c == null) {
				ret.put('First_Response_Date', 'n/a');
			} else {
				ret.put('First_Response_Date', String.valueOf(c.First_Response_Date__c));
			}
			if (c.Last_Response_Date__c == null) {
				ret.put('Last_Response_Date', 'n/a');
			} else {
				ret.put('Last_Response_Date', String.valueOf(c.Last_Response_Date__c));
			}
			if (c.Last_Customer_Response_Date__c == null) {
				ret.put('Last_Customer_Response_Date', 'n/a');
			} else {
				ret.put('Last_Customer_Response_Date', String.valueOf(c.Last_Customer_Response_Date__c));
			}
			if (c.Last_Automation_Response_Date__c == null) {
				ret.put('Last_Automation_Response_Date', 'n/a');
			} else {
				ret.put(
					'Last_Automation_Response_Date',
					String.valueOf(c.Last_Automation_Response_Date__c)
				);
			}
			if (c.Escalation_L2_Date__c == null) {
				ret.put('Escalation_L2_Date', 'n/a');
			} else {
				ret.put('Escalation_L2_Date', String.valueOf(c.Escalation_L2_Date__c));
			}
			if (c.Escalation_L3_Date__c == null) {
				ret.put('Escalation_L3_Date', 'n/a');
			} else {
				ret.put('Escalation_L3_Date', String.valueOf(c.Escalation_L3_Date__c));
			}
			if (c.Escalation_L4_Date__c == null) {
				ret.put('Escalation_L4_Date', 'n/a');
			} else {
				ret.put('Escalation_L4_Date', String.valueOf(c.Escalation_L4_Date__c));
			}
			if (c.Escalation_L5_Date__c == null) {
				ret.put('Escalation_L5_Date', 'n/a');
			} else {
				ret.put('Escalation_L5_Date', String.valueOf(c.Escalation_L5_Date__c));
			}
			if (c.Escalation_Level_Watermark__c == null) {
				ret.put('Escalation_Level_Watermark', 'n/a');
			} else {
				ret.put('Escalation_Level_Watermark', String.valueOf(c.Escalation_Level_Watermark__c));
			}
			if (c.First_SME_Assigned_Date__c == null) {
				ret.put('First_SME_Assigned_Date', 'n/a');
			} else {
				ret.put('First_SME_Assigned_Date', String.valueOf(c.First_SME_Assigned_Date__c));
			}
			if (c.DeEscalation_Date__c == null) {
				ret.put('DeEscalation_Date', 'n/a');
			} else {
				ret.put('DeEscalation_Date', String.valueOf(c.DeEscalation_Date__c));
			}
			if (c.First_Solved_Date__c == null) {
				ret.put('First_Solved_Date', 'n/a');
			} else {
				ret.put('First_Solved_Date', String.valueOf(c.First_Solved_Date__c));
			}
			if (c.ClosedDate == null) {
				ret.put('ClosedDate', 'n/a');
			} else {
				ret.put('ClosedDate', String.valueOf(c.ClosedDate));
			}
			if (c.Escalation_L2_SLO__c == null) {
				ret.put('Escalation_L2_SLO', 'n/a');
			} else {
				ret.put('Escalation_L2_SLO', String.valueOf(c.Escalation_L2_SLO__c));
			}
			if (c.Escalation_L3_SLO__c == null) {
				ret.put('Escalation_L3_SLO', 'n/a');
			} else {
				ret.put('Escalation_L3_SLO', String.valueOf(c.Escalation_L3_SLO__c));
			}
			if (c.Escalation_L4_SLO__c == null) {
				ret.put('Escalation_L4_SLO', 'n/a');
			} else {
				ret.put('Escalation_L4_SLO', String.valueOf(c.Escalation_L4_SLO__c));
			}
			if (c.Escalation_L5_SLO__c == null) {
				ret.put('Escalation_L5_SLO', 'n/a');
			} else {
				ret.put('Escalation_L5_SLO', String.valueOf(c.Escalation_L5_SLO__c));
			}
			if (c.Escalation_L2_SME_Engaged_Date__c == null) {
				ret.put('Escalation_L2_SME_Engaged_Date', 'n/a');
			} else {
				ret.put(
					'Escalation_L2_SME_Engaged_Date',
					String.valueOf(c.Escalation_L2_SME_Engaged_Date__c)
				);
			}
			if (c.Escalation_L3_SME_Engaged_Date__c == null) {
				ret.put('Escalation_L3_SME_Engaged_Date', 'n/a');
			} else {
				ret.put(
					'Escalation_L3_SME_Engaged_Date',
					String.valueOf(c.Escalation_L3_SME_Engaged_Date__c)
				);
			}
			if (c.Escalation_L4_SME_Engaged_Date__c == null) {
				ret.put('Escalation_L4_SME_Engaged_Date', 'n/a');
			} else {
				ret.put(
					'Escalation_L4_SME_Engaged_Date',
					String.valueOf(c.Escalation_L4_SME_Engaged_Date__c)
				);
			}
			if (c.Escalation_L5_SME_Engaged_Date__c == null) {
				ret.put('Escalation_L5_SME_Engaged_Date', 'n/a');
			} else {
				ret.put(
					'Escalation_L5_SME_Engaged_Date',
					String.valueOf(c.Escalation_L5_SME_Engaged_Date__c)
				);
			}

			if (!Test.isRunningTest()) {
				ret.put('app_name', Utility.getAppName());
			}
		} catch (DmlException e) {
			System.debug('getInitInfo:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		ret.put('CreatedDate_Help', 'Date Case Opened');
		ret.put('First_Assigned_Date_Help', '');
		ret.put('First_Response_Date_Help', '');
		ret.put('Last_Response_Date_Help', '');
		ret.put('Last_Customer_Response_Date_Help', '');
		ret.put('Last_Automation_Response_Date_Help', '');
		ret.put('Escalation_L2_Date_Help', '');
		ret.put('Escalation_L3_Date_Help', '');
		ret.put('Escalation_L4_Date_Help', '');
		ret.put('Escalation_L5_Date_Help', '');
		ret.put('Escalation_Level_Watermark_Help', '');
		ret.put('First_SME_Assigned_Date_Help', '');
		ret.put('DeEscalation_Date_Help', '');
		ret.put('First_Solved_Date_Help', '');
		ret.put('ClosedDate_Help', 'Date Case closed');

		List<FieldDefinition> fieldDef = [
			SELECT QualifiedApiName, Description
			FROM FieldDefinition
			WHERE EntityDefinition.QualifiedApiName = 'Case'
		];
		for (FieldDefinition f : fieldDef) {
			if (f.QualifiedApiName == 'CreatedDate') {
				ret.put('CreatedDate_Help', 'Date Case Opened');
			}

			if (f.QualifiedApiName == 'First_Assigned_Date__c') {
				ret.put('First_Assigned_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'First_Response_Date__c') {
				ret.put('First_Response_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Last_Response_Date__c') {
				ret.put('Last_Response_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Last_Customer_Response_Date__c') {
				ret.put('Last_Customer_Response_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Last_Automation_Response_Date__c') {
				ret.put('Last_Automation_Response_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Escalation_L2_Date__c') {
				ret.put('Escalation_L2_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Escalation_L3_Date__c') {
				ret.put('Escalation_L3_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Escalation_L4_Date__c') {
				ret.put('Escalation_L4_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Escalation_L5_Date__c') {
				ret.put('Escalation_L5_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'Escalation_Level_Watermark__c') {
				ret.put('Escalation_Level_Watermark_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'First_SME_Assigned_Date__c') {
				ret.put('First_SME_Assigned_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'DeEscalation_Date__c') {
				ret.put('DeEscalation_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'First_Solved_Date__c') {
				ret.put('First_Solved_Date_Help', String.valueOf(f.Description));
			}

			if (f.QualifiedApiName == 'ClosedDate') {
				ret.put('ClosedDate_Help', 'Date Case closed');
			}
		}

		return ret;
	}

	/** getAccountId
	 */
	public static String getAccountId(String caseId) {
		String ret = '';

		try {
			String soql = 'SELECT AccountId ' + 'FROM Case ' + 'WHERE Id = \'' + caseId + '\'';

			List<Case> rcases = Database.query(soql);

			if (!rcases.isEmpty()) {
				ret = rcases[0].AccountId;
			}
		} catch (DmlException e) {
			System.debug('getAccountId:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getLatestSurvey
	 * @param caseId - case to retrieve
	 * @return Boolean
	 */
	public static Map<String, String> getLatestSurvey(String caseId) {
		Map<String, String> ret = new Map<String, String>();
		ret.put('hasSurvey', 'false');

		try {
			// Get Super Users defeined within Contact Relation
			String soql =
				'SELECT Case_1_Detractor__c, ' +
				'Case_1_NPS__c, ' +
				'Case_1_Promoter__c,' +
				'Case_1_Recommend__c,' +
				'Case_2_Overall_Support__c,' +
				'Case_2_Satisfaction__c,' +
				'Case_3_Speed_of_Resolution__c,' +
				'Case_4_Technical_Knowledge__c,' +
				'Case_5_Issue_Resolved__c,' +
				'Case_6_Comment__c,' +
				'Detractor__c,' +
				'Name,' +
				'Promoter__c,' +
				'SurveyCreateDate__c  ' +
				'FROM Survey__c ' +
				'WHERE Case__c= \'' +
				caseId +
				'\' ' +
				'ORDER BY SurveyCreateDate__c DESC ' +
				'LIMIT 1';

			List<Survey__c> surveys = Database.query(soql);
			if (!surveys.isEmpty()) {
				ret.put('hasSurvey', 'true');

				ret.put('submissionDate', 'n/a');
				if (!nullOrEmpty(surveys[0].SurveyCreateDate__c)) {
					ret.put('submissionDate', String.valueOf(surveys[0].SurveyCreateDate__c));
				}

				ret.put('promoter', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_1_Promoter__c)) {
					ret.put('promoter', String.valueOf(surveys[0].Case_1_Promoter__c));
				}

				ret.put('detractor', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_1_Detractor__c)) {
					ret.put('detractor', String.valueOf(surveys[0].Case_1_Detractor__c));
				}

				ret.put('transactionalNPS', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_1_NPS__c)) {
					ret.put('transactionalNPS', String.valueOf(surveys[0].Case_1_NPS__c));
				}

				ret.put('transactionalNPSFactor', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_1_Recommend__c)) {
					ret.put('transactionalNPSFactor', String.valueOf(surveys[0].Case_1_Recommend__c));
				}

				ret.put('overallSatisfaction', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_2_Satisfaction__c)) {
					ret.put('overallSatisfaction', String.valueOf(surveys[0].Case_2_Satisfaction__c));
				}

				ret.put('overallSatisfactionFactor', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_2_Overall_Support__c)) {
					ret.put(
						'overallSatisfactionFactor',
						String.valueOf(surveys[0].Case_2_Overall_Support__c)
					);
				}

				ret.put('speedOfResolution', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_3_Speed_of_Resolution__c)) {
					ret.put('speedOfResolution', String.valueOf(surveys[0].Case_3_Speed_of_Resolution__c));
				}

				ret.put('technicalKnowledge', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_4_Technical_Knowledge__c)) {
					ret.put('technicalKnowledge', String.valueOf(surveys[0].Case_4_Technical_Knowledge__c));
				}

				ret.put('issueResolved', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_5_Issue_Resolved__c)) {
					ret.put('issueResolved', String.valueOf(surveys[0].Case_5_Issue_Resolved__c));
				}

				ret.put('comment', 'n/a');
				if (!nullOrEmpty(surveys[0].Case_6_Comment__c)) {
					ret.put('comment', String.valueOf(surveys[0].Case_6_Comment__c));
				}

				ret.put('surveyId', String.valueOf(surveys[0].Id));
			}
		} catch (DmlException e) {
			System.debug('getLatestSurvey:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSDR
	 * @param caseId - case to retrieve Case escalation info
	 * @return Map of Escalation Info
	 */
	@AuraEnabled
	public static List<Map<String, String>> getSDR(String caseId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String soql =
				'SELECT Name, ' +
				'Server_Device_Type__c, ' +
				'Type__c, ' +
				'Vanity_URL__c ' +
				'FROM Server_Deployment__c ' +
				'WHERE Status__c = \'Active\' ' +
				'AND Account__c IN (SELECT AccountId FROM Case WHERE Id = \'' +
				caseId +
				'\') ';

			List<Server_Deployment__c> sdrs = Database.query(soql);

			if (!sdrs.isEmpty()) {
				for (Server_Deployment__c sdr : sdrs) {
					Map<String, String> s = new Map<String, String>();
					s.put('Id', sdr.Id);
					s.put('Name', sdr.Name);
					s.put('License', sdr.Server_Device_Type__c);
					s.put('Type', sdr.Type__c);
					s.put('Vanity', sdr.Vanity_URL__c);
					ret.add(s);
				}
			}
		} catch (DmlException e) {
			System.debug('getSDR:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}
}