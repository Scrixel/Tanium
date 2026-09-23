/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Provide Rosco Case Processes automation and functionality
 * @Date: 2015-01-18
 * @Author: Jason, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-8049    2024-07-15    Case ownership bug for Poland, Japan, Pubsec-Hybrid and sev 3
 * SS-7436    2024-08-27    Resolve tech debts and moved methods to CaseTriggerUtilityWithoutSharing
 * SS-9018    2024-08-27    Resolve tech debts and remove unnecessary lines
 * SS-9019    2024-09-18    Move methods to CaseTriggerUtilityWithoutSharing
 * SS-9220    2024-09-25    Null pointer exception in convertHTMLToPlainText  for html = html.replaceAll line
 * SS-9459    2024-10-15    Remove processOmniChannel method
 * SS-9480    2024-11-07    Remove getOmniRoundRobinUserJapan method
 * SS-9309    2025-01-07    Add LinkPost in FeedItem type, clean up.
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c and Resolved issues
 * SS-11653   2025-09-15    Updated method processOutboundSupportCaseEmail
 * SS-12056   2025-11-18    Updated method processOutboundSupportCaseEmail
 * SS-12298   2026-01-13    Added logic to check parent object type and formatting fixes
 * SS-13177   2026-05-21    Set Subject on outbound emails for POC_Case RT before early return in processOutboundSupportCaseEmail
 * SS-13459   2026-06-29    Set verified FromAddress and populate ToAddress from contact roles on outbound POC_Cases
 */
public without sharing class RoscoCaseProcesses {
	public static String convertHTMLToPlainText(String html) {
		final String LINE_BREAKS_EXP = '</(p|ul|li|blockquote|div|h\\d|header|footer|hr|ol|pre|section|table)>';
		List<String> listTextLine = new List<String>();
		if (!String.isBlank(html)) {
			html = html.replaceAll(LINE_BREAKS_EXP, '\n');
			for (String text : html.split('\n')) {
				text = text.trim();
				String imageTxt = convertImageTagHTMLToText(text);
				if (String.isNotBlank(imageTxt)) {
					text = imageTxt;
				}
				listTextLine.add(text.trim().stripHTMLTags());
			}
		}
		return String.join(listTextLine, '\n');
	}

	private static String convertImageTagHTMLToText(String imageTagHTML) {
		final String IMAGE_TAG_REGEX = '<img .*?alt=["\']?([^"\']*)["\']?.*?/?>';
		Pattern imgPattern = Pattern.compile(IMAGE_TAG_REGEX);
		Matcher imgMatcher = imgPattern.matcher(imageTagHTML.trim());

		if (imgMatcher.find()) {
			String imgTxt = '[Image: ' + imgMatcher.group(1) + ']';
			return imgTxt;
		}
		return null;
	}

	public static Map<String, String> getCaseManagementSettings() {
		Map<String, String> ret = new Map<String, String>();
		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

		for (String s : cmfields) {
			ret.put(s, String.valueOf(cm.get(s)));
		}
		return ret;
	}

	public static Map<String, String> getCaseSloStatus(
		String caseId,
		String model,
		String team,
		String level,
		Decimal severity,
		Datetime escDate,
		String caseRecordType
	) {
		Map<String, String> ret = new Map<String, String>();
		try {
			if (caseId != null) {
				Case c = [
					SELECT
						Support_Model__c,
						Escalation_Team__c,
						Escalation_Tier__c,
						Severity_Community__c,
						Escalation_L2_Date__c,
						Escalation_L3_Date__c,
						Escalation_L4_Date__c,
						Escalation_L5_Date__c,
						CreatedDate,
						RecordType.Name
					FROM Case
					WHERE Id = :caseId
				];

				model = c.Support_Model__c;
				team = c.Escalation_Team__c;
				level = c.Escalation_Tier__c;
				severity = Decimal.valueOf(c.Severity_Community__c);
				caseRecordType = c.RecordType.Name;

				if (c.Escalation_Tier__c == 'Level 5') {
					escDate = c.Escalation_L5_Date__c;
				} else if (c.Escalation_Tier__c == 'Level 4') {
					escDate = c.Escalation_L4_Date__c;
				} else if (c.Escalation_Tier__c == 'Level 3') {
					escDate = c.Escalation_L3_Date__c;
				} else if (c.Escalation_Tier__c == 'Level 2') {
					escDate = c.Escalation_L2_Date__c;
				} else if (c.Escalation_Tier__c == 'Level 1') {
					if (nullOrEmpty(c.CreatedDate)) {
						escDate = System.Datetime.now();
					} else {
						escDate = c.CreatedDate;
					}
				}
			}

			Map<String, String> escSettings = new Map<String, String>();
			if (level == 'Level 1') {
				escSettings = getResponseTeamSettings(model, severity);
			} else {
				escSettings = getEscalationTeamSettings(model, team, level, severity, caseRecordType);
			}

			Integer slo = Integer.valueOf(escSettings.get('escalationSLO'));

			Datetime failDT = escDate.addMinutes(slo);
			Decimal failDiff = failDT.getTime() - System.Datetime.now().getTime();
			Integer failMin = Integer.valueOf(failDiff / 60000);
			ret.put(
				'escalationSLOStatusFail',
				failDT.addMinutes(1).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.000\'Z\'')
			);
			ret.put('escalationSLOStatusFailMin', String.valueOf(failMin));
			if (math.abs(failMin) < 30.0) {
				ret.put('escalationSLOStatusFailGracePeriod', 'true');
			} else {
				ret.put('escalationSLOStatusFailGracePeriod', 'false');
			}

			Datetime warnDT = escDate.addMinutes(slo / 2);
			Decimal warnDiff = warnDT.getTime() - System.Datetime.now().getTime();
			Integer warnMin = Integer.valueOf(warnDiff / 60000);
			ret.put(
				'escalationSLOStatusWarn',
				warnDT.addMinutes(1).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.000\'Z\'')
			);
			ret.put('escalationSLOStatusWarnMin', String.valueOf(warnMin));
			if (math.abs(warnMin) < 30.0) {
				ret.put('escalationSLOStatusWarnGracePeriod', 'true');
			} else {
				ret.put('escalationSLOStatusWarnGracePeriod', 'false');
			}

			if (System.Datetime.now() > escDate.addMinutes(slo)) {
				ret.put('escalationSLOStatus', 'Fail');
			} else if (System.Datetime.now() > escDate.addMinutes(slo / 2)) {
				ret.put('escalationSLOStatus', 'Warning');
			} else {
				ret.put('escalationSLOStatus', 'Waiting');
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.getCaseSloStatus() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getCaseState(String caseId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT Id, ' +
				'Account.Name, ' +
				'Support_Model__c, ' +
				'CaseNumber, ' +
				'Component__c, ' +
				'RecordType.Name, ' +
				'Escalation_Artifact__c, ' +
				'Escalation_L2_Date__c, ' +
				'Escalation_L2_SLO__c, ' +
				'Escalation_L2_SME_Engaged_Date__c, ' +
				'Escalation_L3_Date__c, ' +
				'Escalation_L3_SLO__c, ' +
				'Escalation_L3_SME_Engaged_Date__c, ' +
				'Escalation_L4_Date__c, ' +
				'Escalation_L4_SLO__c, ' +
				'Escalation_L4_SME_Engaged_Date__c, ' +
				'Escalation_L5_Date__c, ' +
				'Escalation_L5_SLO__c, ' +
				'Escalation_L5_SME_Engaged_Date__c, ' +
				'Escalation_Pod__c, ' +
				'Escalation_Reason__c, ' +
				'Escalation_Tier__c, ' +
				'Escalation_Team__c, ' +
				'SME_OwnerId__c, ' +
				'Subject, ' +
				'Severity_Community__c ' +
				'FROM Case ' +
				'WHERE Id = \'' +
				caseId +
				'\' ' +
				'LIMIT 1';

			List<Case> cases = Database.query(soql);
			if (!cases.isEmpty()) {
				ret.put('Id', cases[0].Id);
				ret.put('accountName', cases[0].Account.Name);
				ret.put('recordType', cases[0].RecordType.Name);
				ret.put('caseNumber', cases[0].CaseNumber);
				if (nullOrEmpty(cases[0].Support_Model__c)) {
					ret.put('supportModel', '');
				} else {
					ret.put('supportModel', cases[0].Support_Model__c);
				}
				ret.put('component', cases[0].Component__c);
				ret.put('subject', cases[0].Subject);
				ret.put('severity', String.valueOf(cases[0].Severity_Community__c));
				ret.put('escalationLevel', cases[0].Escalation_Tier__c);
				ret.put('escalationPod', cases[0].Escalation_Pod__c);
				ret.put('escalationTeam', cases[0].Escalation_Team__c);
				ret.put('escalationArtifact', cases[0].Escalation_Artifact__c);
				ret.put('escalationReason', cases[0].Escalation_Reason__c);

				if (cases[0].SME_OwnerId__c == null) {
					ret.put('escalationEngagedSME', 'false');
				} else {
					ret.put('escalationEngagedSME', 'true');
				}

				if (cases[0].Escalation_Tier__c == 'Level 2') {
					ret.put('escalationDate', String.valueOf(cases[0].Escalation_L2_Date__c));
					ret.put('escalationSLO', String.valueOf(cases[0].Escalation_L2_SLO__c));
					ret.put(
						'escalationSMEEngaged',
						String.valueOf(cases[0].Escalation_L2_SME_Engaged_Date__c)
					);
					Map<String, String> status = getCaseSloStatus(
						null,
						cases[0].Support_Model__c,
						cases[0].Escalation_Team__c,
						cases[0].Escalation_Tier__c,
						Decimal.valueOf(cases[0].Severity_Community__c),
						cases[0].Escalation_L2_Date__c,
						cases[0].RecordType.Name
					);
					ret.putAll(status);
				} else if (cases[0].Escalation_Tier__c == 'Level 3') {
					ret.put('escalationDate', String.valueOf(cases[0].Escalation_L3_Date__c));
					ret.put('escalationSLO', cases[0].Escalation_L3_SLO__c);
					ret.put(
						'escalationSMEEngaged',
						String.valueOf(cases[0].Escalation_L3_SME_Engaged_Date__c)
					);
					Map<String, String> status = getCaseSloStatus(
						null,
						cases[0].Support_Model__c,
						cases[0].Escalation_Team__c,
						cases[0].Escalation_Tier__c,
						Decimal.valueOf(cases[0].Severity_Community__c),
						cases[0].Escalation_L3_Date__c,
						cases[0].RecordType.Name
					);
					ret.putAll(status);
				} else if (cases[0].Escalation_Tier__c == 'Level 4') {
					ret.put('escalationDate', String.valueOf(cases[0].Escalation_L4_Date__c));
					ret.put('escalationSLO', cases[0].Escalation_L4_SLO__c);
					ret.put(
						'escalationSMEEngaged',
						String.valueOf(cases[0].Escalation_L4_SME_Engaged_Date__c)
					);
					Map<String, String> status = getCaseSloStatus(
						null,
						cases[0].Support_Model__c,
						cases[0].Escalation_Team__c,
						cases[0].Escalation_Tier__c,
						Decimal.valueOf(cases[0].Severity_Community__c),
						cases[0].Escalation_L4_Date__c,
						cases[0].RecordType.Name
					);
					ret.putAll(status);
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.getCaseState() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getCMSetting(String setting) {
		String ret = '';
		try {
			Map<String, String> cm = getCaseManagementSettings();

			if (cm.containsKey(setting)) {
				String settingValue = cm.get(setting);

				if (!nullOrEmpty(settingValue)) {
					ret = settingValue;
				}
			}

			if (setting == 'TEST_FORCE_EXECPTION') {
				Integer forceException = 0 / 0;
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.getCMSetting() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getEscalationTeamSettings(
		String model,
		String team,
		String level,
		Decimal severity,
		String caseRecordType
	) {
		Map<String, String> ret = new Map<String, String>();
		try {
			if (level == 'Level 1') {
				return ret;
			}
			Id recordTypeId = RoscoEscalate.getTAMTeamRecordTypeId(caseRecordType, null);
			String soql =
				'SELECT ' +
				'L2_Email_Aliases__c,' +
				'L2_Slack_Channel_Ids__c,' +
				'L2_Slack_Groups__c,' +
				'L2_Sev_1_SLO__c,' +
				'L2_Sev_2_SLO__c,' +
				'L2_Sev_3_SLO__c,' +
				'L2_SMS_Text_Numbers__c,' +
				'L3_Email_Aliases__c,' +
				'L3_Slack_Channel_Ids__c,' +
				'L3_Slack_Groups__c,' +
				'L3_Sev_1_SLO__c,' +
				'L3_Sev_2_SLO__c,' +
				'L3_Sev_3_SLO__c,' +
				'L3_SMS_Text_Numbers__c,' +
				'L4_Email_Aliases__c,' +
				'L4_Slack_Channel_Ids__c,' +
				'L4_Slack_Groups__c,' +
				'L4_Sev_1_SLO__c,' +
				'L4_Sev_2_SLO__c,' +
				'L4_Sev_3_SLO__c,' +
				'L4_SMS_Text_Numbers__c,' +
				'L5_Email_Aliases__c,' +
				'L5_Slack_Channel_Ids__c,' +
				'L5_Slack_Groups__c,' +
				'L5_Sev_1_SLO__c,' +
				'L5_Sev_2_SLO__c,' +
				'L5_Sev_3_SLO__c,' +
				'L5_SMS_Text_Numbers__c,' +
				'Specialty_Group__r.Name, ' +
				'Support_Model__c ' +
				'FROM TAM_Team__c ' +
				'WHERE RecordTypeId = \'' +
				recordTypeId +
				'\' ' +
				'AND Name = \'' +
				team +
				'\' ' +
				'AND (Support_Model__c = null ' +
				'OR Support_Model__c = \'' +
				model +
				'\') ' +
				'ORDER BY Support_Model__c DESC NULLS LAST ' +
				'LIMIT 1';

			List<TAM_Team__c> teams = Database.query(soql);
			if (!teams.isEmpty()) {
				ret.put('name', team);
				ret.put('parentGroup', teams[0].Specialty_Group__r.Name);
				ret.put('supportModel', teams[0].Support_Model__c);

				if (level == 'Level 2') {
					ret.put('escalationEmail', teams[0].L2_Email_Aliases__c);
					ret.put('escalationSlackChannels', teams[0].L2_Slack_Channel_Ids__c);
					ret.put('escalationSlackGroups', teams[0].L2_Slack_Groups__c);
					ret.put('escalationSMS', teams[0].L2_Slack_Groups__c);
					if (severity == 1) {
						ret.put('escalationSLO', String.valueOf(teams[0].L2_Sev_1_SLO__c));
					} else if (severity == 2) {
						ret.put('escalationSLO', String.valueOf(teams[0].L2_Sev_2_SLO__c));
					} else {
						ret.put('escalationSLO', String.valueOf(teams[0].L2_Sev_3_SLO__c));
					}
				} else if (level == 'Level 3') {
					ret.put('escalationEmail', teams[0].L3_Email_Aliases__c);
					ret.put('escalationSlackChannels', teams[0].L3_Slack_Channel_Ids__c);
					ret.put('escalationSlackGroups', teams[0].L3_Slack_Groups__c);
					ret.put('escalationSMS', teams[0].L3_Slack_Groups__c);
					if (severity == 1) {
						ret.put('escalationSLO', String.valueOf(teams[0].L3_Sev_1_SLO__c));
					} else if (severity == 2) {
						ret.put('escalationSLO', String.valueOf(teams[0].L3_Sev_2_SLO__c));
					} else {
						ret.put('escalationSLO', String.valueOf(teams[0].L3_Sev_3_SLO__c));
					}
				} else if (level == 'Level 4') {
					ret.put('escalationEmail', teams[0].L4_Email_Aliases__c);
					ret.put('escalationSlackChannels', teams[0].L4_Slack_Channel_Ids__c);
					ret.put('escalationSlackGroups', teams[0].L4_Slack_Groups__c);
					ret.put('escalationSMS', teams[0].L4_Slack_Groups__c);
					if (severity == 1) {
						ret.put('escalationSLO', String.valueOf(teams[0].L4_Sev_1_SLO__c));
					} else if (severity == 2) {
						ret.put('escalationSLO', String.valueOf(teams[0].L4_Sev_2_SLO__c));
					} else {
						ret.put('escalationSLO', String.valueOf(teams[0].L4_Sev_3_SLO__c));
					}
				} else if (level == 'Level 5') {
					ret.put('escalationEmail', teams[0].L5_Email_Aliases__c);
					ret.put('escalationSlackChannels', teams[0].L5_Slack_Channel_Ids__c);
					ret.put('escalationSlackGroups', teams[0].L5_Slack_Groups__c);
					ret.put('escalationSMS', teams[0].L5_Slack_Groups__c);
					if (severity == 1) {
						ret.put('escalationSLO', String.valueOf(teams[0].L5_Sev_1_SLO__c));
					} else if (severity == 2) {
						ret.put('escalationSLO', String.valueOf(teams[0].L5_Sev_2_SLO__c));
					} else {
						ret.put('escalationSLO', String.valueOf(teams[0].L5_Sev_3_SLO__c));
					}
				}

				if (caseRecordType == 'Internal') {
					if (!nullOrEmpty(teams[0].L5_Slack_Channel_Ids__c)) {
						ret.put('escalationSlackChannels', teams[0].L5_Slack_Channel_Ids__c);
					}

					if (!nullOrEmpty(teams[0].L5_Slack_Groups__c)) {
						ret.put('escalationSlackGroups', teams[0].L5_Slack_Groups__c);
					}
				}
			}

			if (model == 'TEST_FORCE_EXECPTION') {
				Integer forceException = 0 / 0;
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.getEscalationTeamSettings() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getResponseTeamSettings(String model, Decimal severity) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT ' +
				'L1_Email_Aliases__c,' +
				'L1_Slack_Channel_Ids__c,' +
				'L1_Slack_Groups__c,' +
				'L1_Sev_1_SLO__c,' +
				'L1_Sev_2_SLO__c,' +
				'L1_Sev_3_SLO__c,' +
				'L1_SMS_Text_Numbers__c,' +
				'Specialty_Group__r.Name,' +
				'Support_Model__c ' +
				'FROM TAM_Team__c ' +
				'WHERE RecordType.Name = \'Response_L1\' ' +
				'AND (Support_Model__c = null ' +
				'OR Support_Model__c = \'' +
				model +
				'\') ' +
				'ORDER BY Support_Model__c DESC NULLS LAST ' +
				'LIMIT 1';

			List<TAM_Team__c> teams = Database.query(soql);
			if (!teams.isEmpty()) {
				ret.put('parentGroup', String.valueOf(teams[0].Specialty_Group__r.Name));
				ret.put('supportModel', String.valueOf(teams[0].Support_Model__c));

				ret.put('escalationEmail', String.valueOf(teams[0].L1_Email_Aliases__c));
				ret.put('escalationSlackChannels', String.valueOf(teams[0].L1_Slack_Channel_Ids__c));
				ret.put('escalationSlackGroups', String.valueOf(teams[0].L1_Slack_Groups__c));
				ret.put('escalationSMS', String.valueOf(teams[0].L1_SMS_Text_Numbers__c));
				if (severity == 1) {
					ret.put('escalationSLO', String.valueOf(teams[0].L1_Sev_1_SLO__c));
				} else if (severity == 2) {
					ret.put('escalationSLO', String.valueOf(teams[0].L1_Sev_2_SLO__c));
				} else {
					ret.put('escalationSLO', String.valueOf(teams[0].L1_Sev_3_SLO__c));
				}
			}
			if (model == 'TEST_FORCE_EXECPTION') {
				Integer forceException = 0 / 0;
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.getResponseTeamSettings() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Boolean isAgent(String userId) {
		Boolean ret = false;
		try {
			if (nullOrEmpty(userId)) {
				ret = false;
			} else if (String.valueOf(userId).left(3) == '00G') {
				ret = true;
			} else {
				String soql =
					'SELECT Email ' +
					'FROM User ' +
					'WHERE Id = \'' +
					userId +
					'\' ' +
					'LIMIT 1';

				List<User> users = Database.query(soql);
				if (!users.isEmpty()) {
					if (!nullOrEmpty(users[0].Email)) {
						if (
							(users[0].Email.containsIgnoreCase('@tanium.com') ||
							users[0].Email.containsIgnoreCase('@taniumfed.com')) &&
							!users[0].Email.containsIgnoreCase('soa@tanium.com')
						) {
							ret = true;
						}
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.isAgent() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Boolean isCMSettingTrue(String setting, String value) {
		Boolean ret = false;
		try {
			Map<String, String> cm = getCaseManagementSettings();

			if (cm.containsKey(setting)) {
				String settingValue = cm.get(setting);

				if (!nullOrEmpty(settingValue)) {
					if (settingValue.containsIgnoreCase(value)) {
						ret = true;
					}
				}
			}
			if (setting == 'TEST_FORCE_EXECPTION') {
				Integer forceException = 0 / 0;
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.isCMSettingTrue() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Boolean isJob(String jobName) {
		Boolean ret = false;
		try {
			String soql =
				'SELECT Id, ' +
				'CronJobDetail.Name ' +
				'FROM CronTrigger  ' +
				'WHERE CronJobDetail.Name = \'' +
				jobName +
				'\'' +
				'LIMIT 1';

			List<CronTrigger> jobs = Database.query(soql);
			if (!jobs.isEmpty()) {
				ret = true;
			}
			if (jobName == 'TEST_FORCE_EXECPTION') {
				Integer forceException = 0 / 0;
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.isJob() ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static void evaluateCaseEscalation(String caseId, String jobName) {
		Map<String, String> state = getCaseState(caseId);
		List<String> lJob = jobName.split(':');
		String jobEscTeam = String.valueOf(lJob[3]).trim();
		String jobEscLevel = String.valueOf(lJob[4]).trim();
		String jobCaseSev = String.valueOf(lJob[5]).replace('Sev', '').trim();

		Case c = [
			SELECT
				Id,
				Escalation_Tier__c,
				Escalation_Team__c,
				Response_L1_SLO__c,
				Escalation_L2_SLO__c,
				Escalation_L3_SLO__c,
				Escalation_L4_SLO__c,
				Escalation_L5_SLO__c,
				Severity_Community__c,
				SME_OwnerId__c,
				Escalation_Pod__c,
				Status,
				RecordType.Name
			FROM Case
			WHERE Id = :caseId
			LIMIT 1
		];

		if (
			Test.isRunningTest() ||
			(c.Escalation_Team__c == jobEscTeam &&
			c.Escalation_Tier__c == jobEscLevel &&
			Integer.valueOf(c.Severity_Community__c) == Integer.valueOf(jobCaseSev))
		) {
			if (c.Escalation_Tier__c == 'Level 1') {
				if (c.Response_L1_SLO__c != state.get('escalationSLOStatus')) {
					c.Response_L1_SLO__c = state.get('escalationSLOStatus');
					update c;
				}
			} else if (c.Escalation_Tier__c == 'Level 2') {
				if (c.Escalation_L2_SLO__c != state.get('escalationSLOStatus')) {
					c.Escalation_L2_SLO__c = state.get('escalationSLOStatus');
					update c;
				}
			} else if (c.Escalation_Tier__c == 'Level 3') {
				if (c.Escalation_L3_SLO__c != state.get('escalationSLOStatus')) {
					c.Escalation_L3_SLO__c = state.get('escalationSLOStatus');
					update c;
				}
			} else if (c.Escalation_Tier__c == 'Level 4') {
				if (c.Escalation_L4_SLO__c != state.get('escalationSLOStatus')) {
					c.Escalation_L4_SLO__c = state.get('escalationSLOStatus');
					update c;
				}
			}
			String status = state.get('escalationSLOStatus');
			if (
				nullOrEmpty(c.SME_OwnerId__c) &&
				c.Escalation_Tier__c != 'Level 1' &&
				c.Status != 'Solved' &&
				c.Status != 'Closed'
			) {
				if (status != 'Cancelled' || status != 'Pass') {
					Map<String, String> settings = new Map<String, String>();
					if (c.Escalation_Tier__c == 'Level 1') {
						settings = getResponseTeamSettings(
							state.get('model'),
							Decimal.valueOf(state.get('severity'))
						);
					} else {
						settings = getEscalationTeamSettings(
							state.get('model'),
							state.get('escalationTeam'),
							state.get('escalationLevel'),
							Decimal.valueOf(state.get('severity')),
							c.RecordType.Name
						);
					}

					sendAlertSlack(state, settings);
				}
			}
			if (
				!nullOrEmpty(c.SME_OwnerId__c) ||
				status == 'Cancelled' ||
				status == 'Pass' ||
				status == 'Fail'
			) {
				manageEscalationAlertJobsDelete(caseId);
			}
		}
	}

	public static void manageEscalationAlertJobs(String caseId, Case c) {
		if (caseId != null) {
			c = [
				SELECT
					Escalation_Tier__c,
					Escalation_Team__c,
					Support_Model__c,
					Severity_Community__c,
					CreatedDate,
					Escalation_L2_Date__c,
					Escalation_L3_Date__c,
					Escalation_L4_Date__c,
					Escalation_L5_Date__c,
					RecordType.Name,
					RecordTypeId
				FROM Case
				WHERE Id = :caseId
				LIMIT 1
			];
		}

		Datetime escDate;
		if (c.Escalation_Tier__c == 'Level 5') {
			escDate = c.Escalation_L5_Date__c;
		} else if (c.Escalation_Tier__c == 'Level 4') {
			escDate = c.Escalation_L4_Date__c;
		} else if (c.Escalation_Tier__c == 'Level 3') {
			escDate = c.Escalation_L3_Date__c;
		} else if (c.Escalation_Tier__c == 'Level 2') {
			escDate = c.Escalation_L2_Date__c;
		} else if (c.Escalation_Tier__c == 'Level 1') {
			if (nullOrEmpty(c.CreatedDate)) {
				escDate = System.Datetime.now();
			} else {
				escDate = c.CreatedDate;
			}
		}

		if (!nullOrEmpty(c.Id)) {
			manageEscalationAlertJobsDelete(c.Id);
		}

		String caseRecordType = c.RecordTypeId;
		if (!nullOrEmpty(c.RecordType.Name)) {
			caseRecordType = c.RecordType.Name;
		}

		Map<String, String> state = getCaseSloStatus(
			null,
			c.Support_Model__c,
			c.Escalation_Team__c,
			c.Escalation_Tier__c,
			Decimal.valueOf(c.Severity_Community__c),
			escDate,
			caseRecordType
		);

		String team = 'Response';
		if (!nullOrEmpty(c.Escalation_Team__c)) {
			team = c.Escalation_Team__c;
		}
		if (!nullOrEmpty(c.Id)) {
			DateTime cutOver = DateTime.newInstance(2023, 2, 18, 0, 0, 0);

			if (escDate > cutOver) {
				scheduleJob(
					c.Id,
					'evaluateCaseEscalation',
					'Escalation Alert Job : Fail schedule : ' +
					team +
					' : ' +
					c.Escalation_Tier__c +
					' : Sev ' +
					c.Severity_Community__c,
					state.get('escalationSLOStatusFail')
				);
				scheduleJob(
					c.Id,
					'evaluateCaseEscalation',
					'Escalation Alert Job : Warn schedule : ' +
					team +
					' : ' +
					c.Escalation_Tier__c +
					' : Sev ' +
					c.Severity_Community__c,
					state.get('escalationSLOStatusWarn')
				);
			}
		}
	}

	public static void manageEscalationAlertJobsDelete(String caseId) {
		try {
			if (nullOrEmpty(caseId)) {
				return;
			}
			String soql =
				'SELECT Id, ' +
				'CronJobDetail.Name ' +
				'FROM CronTrigger  ' +
				'WHERE CronJobDetail.Name LIKE \'' +
				caseId +
				' : Escalation Alert Job%\' ' +
				'LIMIT 10';

			List<CronTrigger> jobs = Database.query(soql);
			if (!jobs.isEmpty()) {
				for (CronTrigger job : jobs) {
					System.abortJob(job.Id);
				}
			}
			if (caseId == 'TEST_FORCE_EXECPTION') {
				Integer forceException = 0 / 0;
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.manageEscalationAlertJobsDelete() ERRORS', e);
			Logger.saveLog();
		}
	}

	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	public static String processCaseStatus(EmailMessage email, FeedItem item, FeedComment comment) {
		String ret = '';
		try {
			if (email != null) {
				if (email.ParentId != null && email.FromAddress != null && email.Status != null) {
					if (
						String.valueOf(email.ParentId).left(3) == '500' &&
						(!email.FromAddress.containsIgnoreCase('@tanium.com') &&
						!email.FromAddress.containsIgnoreCase('@taniumfed.com') &&
						!email.FromAddress.containsIgnoreCase('apex.sandbox.salesforce.com')) &&
						email.Status != '5'
					) {
						Case c = [SELECT Status FROM Case WHERE Id = :email.ParentId];
						if (nullOrEmpty(c.Status)) {
							ret = 'Setting Status from empty to In Progress - Troubleshooting based on email';
							c.Status = 'In Progress - Troubleshooting';
							update c;
						} else if (c.Status == 'Closed') {
							ret = 'Will not change Status of closed cases';
						} else if (c.Status != 'In Progress - Troubleshooting') {
							ret = 'Setting Status to In Progress - Troubleshooting based on email';
							c.Status = 'In Progress - Troubleshooting';
							update c;
						} else {
							ret = 'Status already set to In Progress - Troubleshooting, no changes made';
						}
					} else {
						ret = 'EmailMessage is not case email, from tanium address, or status is draft';
					}
				} else {
					ret = 'EmailMessage is missing expected property';
				}
			} else if (item != null) {
				if (
					item.ParentId != null &&
					item.Visibility != null &&
					item.NetworkScope != null &&
					item.Type != null &&
					item.Status != null
				) {
					if (
						String.valueOf(item.ParentId).left(3) == '500' &&
						item.Visibility == 'AllUsers' &&
						item.NetworkScope == 'AllNetworks' &&
						(item.Type == 'TextPost' ||
						item.Type == 'ContentPost') &&
						item.Status == 'Published'
					) {
						if (!isAgent(item.CreatedById)) {
							Boolean caseClosure = false;
							if (!nullOrEmpty(item.Body)) {
								if (item.Body.containsIgnoreCase(Constants.CASE_CLOSE_SUMMARY)) {
									caseClosure = true;
								}
							}
							if (!caseClosure) {
								Case c = [SELECT Status FROM Case WHERE Id = :item.ParentId];
								if (nullOrEmpty(c.Status)) {
									ret = 'Setting Status from empty to In Progress - Troubleshooting based on FeedItem';
									c.Status = 'In Progress - Troubleshooting';
									update c;
								} else if (c.Status == 'Closed') {
									ret = 'Will not change Status of closed cases';
									FeedComment newComment = new FeedComment(
										FeedItemId = item.Id,
										CommentBody = 'Attention: Closed cases are not monitored, please open new case',
										CommentType = 'TextComment'
									);
									insert newComment;
								} else if (c.Status != 'In Progress - Troubleshooting') {
									ret = 'Setting Status to In Progress - Troubleshooting based on Item';
									c.Status = 'In Progress - Troubleshooting';
									update c;
								} else {
									ret = 'Status already set to In Progress - Troubleshooting, no changes made';
								}
							}
						} else {
							ret = 'FeedItem is from agent';
						}
					} else {
						ret = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
					}
				} else {
					ret = 'FeedItem is missing expected property';
				}
			} else if (comment != null) {
				if (comment.ParentId != null && comment.CommentType != null && comment.Status != null) {
					if (
						String.valueOf(comment.ParentId).left(3) == '500' &&
						comment.CommentType == 'TextComment' &&
						comment.Status == 'Published'
					) {
						if (!isAgent(comment.CreatedById)) {
							Case c = [SELECT Status FROM Case WHERE Id = :comment.ParentId];
							if (nullOrEmpty(c.Status)) {
								ret = 'Setting Status from empty to In Progress - Troubleshooting based on FeedComment';
								c.Status = 'In Progress - Troubleshooting';
								update c;
							} else if (c.Status == 'Closed') {
								ret = 'Will not change Status of closed cases';
								FeedComment newComment = new FeedComment(
									FeedItemId = comment.ParentId,
									CommentBody = 'Attention: Closed cases are not monitored, please open new case',
									CommentType = 'TextComment'
								);
								insert newComment;
							} else if (c.Status != 'In Progress - Troubleshooting') {
								ret = 'Setting Status to In Progress - Troubleshooting based on Comment';
								c.Status = 'In Progress - Troubleshooting';
								update c;
							} else {
								ret = 'Status already set to In Progress - Troubleshooting, no changes made';
							}
						} else {
							ret = 'FeedComment is from agent';
						}
					} else {
						ret = 'FeedComment is not case feed item, TextComment, or published';
					}
				} else {
					ret = 'FeedComment is missing expected property';
				}
			} else {
				ret = 'EmailMessage, FeedItem, and FeedComment null';
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.processCaseStatus() ERRORS', e);
			Logger.saveLog();
			ret = 'Exception';
		}
		return ret;
	}

	public static String processEscalationDateL2(Case oldCase, Case newCase) {
		String ret = '';
		try {
			if (!nullOrEmpty(newCase.Escalation_Tier__c)) {
				if (newCase.Escalation_Tier__c == 'Level 2') {
					if (nullOrEmpty(newCase.Escalation_L2_Date__c)) {
						ret = 'Case escalated to Level 2';
						newCase.Escalation_L2_Date__c = System.Datetime.now();
					} else {
						ret = 'Case Escalation_L2_Date__c has previously been set';
					}
				} else {
					ret = 'Case Escalation_Tier__c is not Level 2';
				}
			} else {
				ret = 'Case Escalation_Tier__c is empty';
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.processEscalationDateL2() ERRORS', e);
			Logger.saveLog();
			ret = 'Exception';
		}
		return ret;
	}

	public static String processEscalationDateL3(Case oldCase, Case newCase) {
		String ret = '';
		try {
			if (!nullOrEmpty(newCase.Escalation_Tier__c)) {
				if (newCase.Escalation_Tier__c == 'Level 3') {
					if (nullOrEmpty(newCase.Escalation_L3_Date__c)) {
						ret = 'Case escalated to Level 3';
						newCase.Escalation_L3_Date__c = System.Datetime.now();
					} else {
						ret = 'Case Escalation_L3_Date__c has previously been set';
					}
				} else {
					ret = 'Case Escalation_Tier__c is not Level 3';
				}
			} else {
				ret = 'Case Escalation_Tier__c is empty';
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.processEscalationDateL3() ERRORS', e);
			Logger.saveLog();
			ret = 'Exception';
		}
		return ret;
	}

	public static String processEscalationDateL4(Case oldCase, Case newCase) {
		String ret = '';
		try {
			if (!nullOrEmpty(newCase.Escalation_Tier__c)) {
				if (newCase.Escalation_Tier__c == 'Level 4') {
					if (nullOrEmpty(newCase.Escalation_L4_Date__c)) {
						ret = 'Case escalated to Level 4';
						newCase.Escalation_L4_Date__c = System.Datetime.now();
					} else {
						ret = 'Case Escalation_L4_Date__c has previously been set';
					}
				} else {
					ret = 'Case Escalation_Tier__c is not Level 4';
				}
			} else {
				ret = 'Case Escalation_Tier__c is empty';
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.processEscalationDateL4() ERRORS', e);
			Logger.saveLog();
			ret = 'Exception';
		}
		return ret;
	}

	public static String processFirstResponseDate(EmailMessage email, FeedItem item) {
		String ret = '';
		try {
			if (email != null) {
				String myId;
				if (email.ParentId != null) {
					myId = email.ParentId;
				} else {
					myId = email.relatedToId;
				}

				if (myId != null && email.FromAddress != null && email.Status != null) {
					if (
						String.valueOf(myId).left(3) == '500' &&
						(email.FromAddress.containsIgnoreCase('@tanium.com') ||
						email.FromAddress.containsIgnoreCase('@taniumfed.com') ||
						email.FromAddress.containsIgnoreCase('apex.sandbox.salesforce.com')) &&
						!email.FromAddress.containsIgnoreCase('sender@tanium') &&
						email.Status != '5'
					) {
						Case c = [SELECT CreatedDate, First_Response_Date__c FROM Case WHERE Id = :myId];
						if (nullOrEmpty(c.First_Response_Date__c)) {
							c.First_Response_Date__c = System.Datetime.now();
							c.Last_Response_Date__c = System.Datetime.now();

							if (!nullOrEmpty(c.CreatedDate)) {
								Decimal diff = c.First_Response_Date__c.getTime() - c.CreatedDate.getTime();
								if (math.abs(diff) < 30000) {
									c.First_Response_Date__c = c.CreatedDate;
									c.Last_Response_Date__c = c.CreatedDate;
								}
							}
							ret = 'Setting First Response Date based on email';
							update c;
						} else {
							if (nullOrEmpty(c.CreatedDate)) {
								ret = 'Case First Response Date already set, CreatedDate empty, no changes made';
							} else {
								Decimal diff = c.First_Response_Date__c.getTime() - c.CreatedDate.getTime();
								if (math.abs(diff) < 30000) {
									c.First_Response_Date__c = c.CreatedDate;
									update c;
									ret = 'Setting First Response Date based on email (match CreatedDate)';
								} else {
									ret = 'Case First Response Date already set, no changes made';
								}
							}
						}
					} else {
						ret = 'EmailMessage is not case email, from tanium address, or status is draft';
					}
				} else {
					ret = 'EmailMessage is missing expected property';
				}
			} else if (item != null) {
				if (
					item.ParentId != null &&
					item.Visibility != null &&
					item.NetworkScope != null &&
					item.Type != null &&
					item.Status != null
				) {
					if (
						item?.ParentId?.getSObjectType() == Case.SObjectType &&
						item.Visibility == 'AllUsers' &&
						item.NetworkScope == 'AllNetworks' &&
						(item.Type == 'TextPost' ||
						item.Type == 'ContentPost') &&
						item.Status == 'Published'
					) {
						if (isAgent(item.CreatedById)) {
							if (isCMSettingTrue('rosco_count_agent_post_as_response__c', 'true')) {
								Case c = [
									SELECT CreatedDate, First_Response_Date__c
									FROM Case
									WHERE Id = :item.ParentId
								];
								if (nullOrEmpty(c.First_Response_Date__c)) {
									ret = 'Setting First Response Date based on FeedItem';
									c.First_Response_Date__c = System.Datetime.now();
									update c;
								} else {
									Decimal diff =
										c.First_Response_Date__c.getTime() - c.CreatedDate.getTime();
									if (math.abs(diff) < 30000) {
										c.First_Response_Date__c = c.CreatedDate;
										ret = 'Setting First Response Date based on FeedItem (match CreatedDate)';
									} else {
										ret = 'Case First Response Date already set, no changes made';
									}
								}
							} else {
								ret = 'FeedItem does not count toward initial response in this environment';
							}
						} else {
							ret = 'FeedItem is not from agent';
						}
					} else {
						ret = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
					}
				} else {
					ret = 'FeedItem is missing expected property';
				}
			} else {
				ret = 'Both EmailMessage and FeedItem null';
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.processFirstResponseDate ERRORS :', e);
			Logger.saveLog();
			ret = 'Exception';
		}
		return ret;
	}

	public static String processLastCustomerResponseDate(
		EmailMessage email,
		FeedItem item,
		FeedComment comment
	) {
		String ret = '';
		String source = '';
		Id caseId = null;
		try {
			if (
				email != null &&
				String.valueOf(email.ParentId)?.left(3) == '500' &&
				(email.FromAddress != null &&
				!email.FromAddress.containsIgnoreCase('@tanium.com') &&
				!email.FromAddress.containsIgnoreCase('@taniumfed.com') &&
				!email.FromAddress.containsIgnoreCase('apex.sandbox.salesforce.com')) &&
				(email.Status != null &&
				email.Status != '5')
			) {
				ret = 'Setting Last Customer Response Date based on email';
				source = 'email';
				caseId = email.ParentId;
			} else if (
				item != null &&
				item?.ParentId?.getSObjectType() == Case.SObjectType &&
				item.Visibility == 'AllUsers' &&
				item.NetworkScope == 'AllNetworks' &&
				item.Status == 'Published' &&
				CaseTriggerUtilityWithoutSharing.VALID_FEEDITEM_TYPES.contains(item.Type)
			) {
				if (!isAgent(item.CreatedById)) {
					ret = 'Setting Last Customer Response Date based on FeedItem';
					source = 'feeditem';
					caseId = item.ParentId;
				}
			} else if (
				comment != null &&
				String.valueOf(comment.ParentId)?.left(3) == '500' &&
				CaseTriggerUtilityWithoutSharing.VALID_FEEDCOMMENT_TYPES.contains(
					comment.CommentType
				) &&
				comment.Status == 'Published'
			) {
				if (!isAgent(comment.CreatedById)) {
					ret = 'Setting Last Customer Response Date based on FeedComment';
					source = 'feedcomment';
					caseId = comment.ParentId;
				}
			}

			if (caseId != null) {
				Case caseRecord = [
					SELECT CreatedDate, Last_Customer_Response_Date__c
					FROM Case
					WHERE Id = :caseId
				];
				caseRecord.Last_Customer_Response_Date__c = System.Datetime.now();

				if (source == 'email') {
					if (!nullOrEmpty(caseRecord.CreatedDate)) {
						Decimal diff =
							caseRecord.Last_Customer_Response_Date__c.getTime() -
							caseRecord.CreatedDate.getTime();
						if (math.abs(diff) < 30000) {
							caseRecord.Last_Customer_Response_Date__c = caseRecord.CreatedDate;
						}
					}
				}

				Database.SaveResult saveResult = Database.update(caseRecord, false);
				Logger.logDatabaseErrors(
						LoggingLevel.ERROR,
						'RoscoCaseProcesses.processLastCustomerResponseDate ERRORS',
						new List<Database.SaveResult>{ saveResult }
					)
					.addTag('apex');
				Logger.saveLog();
			}
		} catch (Exception e) {
			ret = 'Exception';
			Logger.error('RoscoCaseProcesses.processLastCustomerResponseDate ERRORS :', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String processLastResponseDate(EmailMessage email, FeedItem item) {
		String ret = '';
		try {
			if (email != null) {
				if (email.ParentId != null && email.FromAddress != null && email.Status != null) {
					if (
						email?.ParentId?.getSObjectType() == Case.SObjectType &&
						(email.FromAddress.containsIgnoreCase('@tanium.com') ||
						email.FromAddress.containsIgnoreCase('@taniumfed.com') ||
						email.FromAddress.containsIgnoreCase('apex.sandbox.salesforce.com')) &&
						!email.FromAddress.containsIgnoreCase('sender@tanium') &&
						email.Status != '5'
					) {
						Case c = [SELECT Last_Response_Date__c FROM Case WHERE Id = :email.ParentId];

						if (nullOrEmpty(c.Last_Response_Date__c)) {
							ret = 'Setting Last Response Date based on email';
							c.Last_Response_Date__c = System.Datetime.now();
							update c;
						} else {
							Decimal diff =
								System.Datetime.now().getTime() - c.Last_Response_Date__c.getTime();
							if (math.abs(diff) < 30000) {
							} else {
								ret = 'Setting Last Response Date based on email';
								c.Last_Response_Date__c = System.Datetime.now();
								update c;
							}
						}
					} else {
						ret = 'EmailMessage is not case email, from tanium address, or status is draft';
					}
				} else {
					ret = 'EmailMessage is missing expected property';
				}
			} else if (item != null) {
				if (
					item.ParentId != null &&
					item.Visibility != null &&
					item.NetworkScope != null &&
					item.Type != null &&
					item.Status != null
				) {
					if (
						item?.ParentId?.getSObjectType() == Case.SObjectType &&
						item.Visibility == 'AllUsers' &&
						item.NetworkScope == 'AllNetworks' &&
						item.Status == 'Published' &&
						CaseTriggerUtilityWithoutSharing.VALID_FEEDITEM_TYPES.contains(item.Type)
					) {
						if (isAgent(item.CreatedById)) {
							if (isCMSettingTrue('rosco_count_agent_post_as_response__c', 'true')) {
								Case c = [SELECT Last_Response_Date__c FROM Case WHERE Id = :item.ParentId];
								ret = 'Setting Last Response Date based on FeedItem';
								c.Last_Response_Date__c = System.Datetime.now();
								update c;
							} else {
								ret = 'FeedItem does not count toward initial response in this environment';
							}
						} else {
							ret = 'FeedItem is not from agent';
						}
					} else {
						ret = 'FeedItem is not case feed item, visible to all users/networks, TextPost, or published';
					}
				} else {
					ret = 'FeedItem is missing expected property';
				}
			} else {
				ret = 'Both EmailMessage and FeedItem null';
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.processLastResponseDate ERRORS :', e);
			Logger.saveLog();
			ret = 'Exception';
		}
		return ret;
	}

	public static void processOutboundSupportCaseEmail(EmailMessage email) {
		if (!Utility.isCase(email.ParentId)) {
			return;
		}
		String emailSubject = '';
		String toAddress = '';
		String htmlBody;
		String accountIdentifier;
		Set<Id> validRecTypeIds = new Set<Id>();
		validRecTypeIds.add(Utility.getRecordTypeIdByAPIName('Case', 'Support'));
		validRecTypeIds.add(Utility.getRecordTypeIdByAPIName('Case', 'Technical_Partnerships'));

		Case cs = [
			SELECT RecordTypeId, Subject, CaseNumber, Account.Name
			FROM Case
			WHERE Id = :email.ParentId
		];

		if (!validRecTypeIds.contains(cs.RecordTypeId)) {
			if (cs.RecordTypeId == Utility.getRecordTypeIdByAPIName('Case', 'POC_Case')) {
				email.Subject = String.isNotBlank(cs.Subject) ? cs.Subject : 'Case ' + cs.CaseNumber;
				if (!email.Incoming) {
					email.ToAddress = RoscoCaseContactRole.getCCRString(email.ParentId);
					email.FromAddress = getOutboundFromAddress();
				}
			}
			return;
		}

		toAddress += RoscoCaseContactRole.getCCRString(email.ParentId);

		emailSubject += email.Subject;

		if (emailSubject.containsIgnoreCase('(attention requested)')) {
			email.FromAddress = 'sender@tanium.com';
			return;
		}

		if (String.isNotBlank(toAddress) || Test.isRunningTest()) {
			email.ToAddress = toAddress;
		} else {
			email.addError(Label.Email_Message_Missing_ToAddress);
		}

		if (!nullOrEmpty(cs.CaseNumber) && !nullOrEmpty(cs.Subject)) {
			emailSubject = String.valueOf(cs.CaseNumber) + ':' + String.valueOf(cs.Subject);
		}

		String chronicleEmail = getCMSetting('rosco_chronicle_support_address__c');
		if (!nullOrEmpty(chronicleEmail)) {
			if (String.valueOf(email.ToAddress).containsIgnoreCase(chronicleEmail)) {
				String ref = RoscoEscalate.getThreadIdFromEmail(email.ParentId, 'chronicle');
				if (!nullOrEmpty(ref)) {
					if (!emailSubject.containsIgnoreCase(ref)) {
						emailSubject += ' [ ref:' + ref + ':ref ]';
					}
				}
			}
		}
		email.Subject = emailSubject;

		accountIdentifier = cs.Account.Name + ',' + cs.CaseNumber;
		htmlBody = email.HtmlBody;
		if (String.isNotBlank(htmlBody) && !htmlBody.containsIgnoreCase(accountIdentifier)) {
			htmlBody = email.HtmlBody.substringBefore('</body>');
			htmlBody +=
				'<p>&nbsp;</p><i>' +
				cs.Account.Name +
				',' +
				cs.CaseNumber +
				'</i></body></html>';
			email.HtmlBody = htmlBody;
		}
		email.FromAddress = getOutboundFromAddress();
	}

	public static void scheduleJob(String caseId, String action, String jobName, String dt) {
		try {
			DateTime schedDt = (DateTime) JSON.deserialize('"' + dt + '"', DateTime.class);
			String hour = String.valueOf(schedDt.hour());
			String min = String.valueOf(schedDt.minute());
			String ss = String.valueOf(schedDt.second());
			String nextFireTime = ss + ' ' + min + ' ' + hour + ' * * ?';

			RoscoSchedule schedFail = new RoscoSchedule();
			schedFail.action = action;
			schedFail.caseId = caseId;
			schedFail.jobName = caseId + ' : ' + jobName;

			if (!isJob(caseId + ' : ' + jobName)) {
				System.schedule(caseId + ' : ' + jobName, nextFireTime, schedFail);
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.scheduleJob ERRORS :', e);
			Logger.saveLog();
		}
	}

	public static void sendAlertSlack(Map<String, String> state, Map<String, String> settings) {
		try {
			String webhookURL = '';

			List<String> escalationSlackGroups = settings.get('escalationSlackGroups').split(',');
			String smeString = '';
			for (String grp : escalationSlackGroups) {
				smeString = smeString == '' ? '@' + grp : smeString + ' @' + grp;
			}

			String alertText = '';

			if (state.get('escalationSLOStatus').containsIgnoreCase('Warn')) {
				String yellow = ':rosco_yellow_blink:';
				if (state.get('recordType') != 'Support') {
					yellow = ':rosco_yellow_internal:';
				}

				alertText =
					yellow +
					' ' +
					state.get('recordType') +
					' Escalation SLO FYI: ' +
					state.get('escalationSLOStatus') +
					' ' +
					yellow +
					' - ' +
					state.get('escalationTeam') +
					' (' +
					smeString +
					') engagement needed for ' +
					'<' +
					URL.getOrgDomainUrl().toExternalForm() +
					'/' +
					state.get('Id') +
					'|' +
					state.get('caseNumber') +
					':' +
					state.get('subject') +
					'>';
			} else if (state.get('escalationSLOStatus').containsIgnoreCase('Fail')) {
				String red = ':rosco_red_blink:';
				if (state.get('recordType') != 'Support') {
					red = ':rosco_red_internal:';
				}

				alertText =
					red +
					' ' +
					state.get('recordType') +
					' Escalation SLO FYI: ' +
					state.get('escalationSLOStatus') +
					' ' +
					red +
					' - ' +
					state.get('escalationTeam') +
					' (' +
					smeString +
					') engagement needed for ' +
					'<' +
					URL.getOrgDomainUrl().toExternalForm() +
					'/' +
					state.get('Id') +
					'|' +
					state.get('caseNumber') +
					':' +
					state.get('subject') +
					'>';
			}

			List<String> channels = settings.get('escalationSlackChannels').split(',');

			for (String channel : channels) {
				JSONGenerator gen = JSON.createGenerator(true);
				gen.writeStartObject();
				gen.writeStringField('text', alertText);
				gen.writeStringField('username', 'rosco');
				gen.writeStringField('channel', channel);
				gen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
				gen.writeStringField('link_names', 'true');
				gen.writeEndObject();

				if (!Test.isRunningTest()) {
					System.enqueueJob(new qCallOut(webhookURL, 'POST', gen.getAsString()));
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCaseProcesses.sendAlertSlack ERRORS :', e);
			Logger.saveLog();
		}
	}

	private static String getOutboundFromAddress() {
		String fromEmailAddress = getCMSetting('rosco_email_apex__c');
		return nullOrEmpty(fromEmailAddress) ? 'support@tanium.com' : fromEmailAddress;
	}

	public class qCallOut implements System.Queueable, Database.AllowsCallouts {
		private final String url;
		private final String method;
		private final String body;

		public qCallOut(String url, String method, String body) {
			this.url = url;
			this.method = method;
			this.body = body;
		}

		public void execute(System.QueueableContext ctx) {
			HttpRequest req = new HttpRequest();
			req.setEndpoint(url);
			req.setMethod(method);
			req.setBody(body);
			Http http = new Http();
			HttpResponse res = http.send(req);
		}
	}
}