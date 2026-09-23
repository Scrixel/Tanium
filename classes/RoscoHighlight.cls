/**
 * Copyright (c) 2026 Tanium
 *
 * @Business:
 * @Date: UNKNOWN
 * @Authors: Tanium Dev Team
 * @Request:
 * RequestId  ModifiedDate  Description
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-9819    2025-01-09    Remove reference to RefId in the UI
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-8074    2025-07-18    Remove references in handler for a deprecated field
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the class
 * SS-13086   2026-05-19    Replace Level_2_Area__c/Level_3_Sub_Area__c with Region__c/Sub_Region__c for US Federal Civilian/DoD detection
 */
public with sharing class RoscoHighlight {
	public static final String COMMUNITY_LOGIN_UNKNOWN_PROFILENAME = 'Tanium Community Login Unknown';
	public static final String COMMUNITY_LOGIN_AUTH_PROFILENAME = 'Tanium Community Login Authenticated';
	public static final String COMMUNITY_LOGIN_AUTH_CASE_PROFILENAME = 'Tanium Community Login Authenticated Case';
	public static final String COMMUNITY_LOGIN_SUPER_USER_PROFILENAME = 'Tanium Community Login Super User';
	public static final String TANIUM_SLACK_URL = 'https://tanium.slack.com/messages/';

	@TestVisible
	private static final String FEDERAL_TEXT = 'This US Federal Account requires US only case handling procedures to be used.  Non-US citizens cannot be the case owner.';
	@TestVisible
	private static final String PROSPECT_TEXT = 'Prospect Account:  This case is associated with a Customer POC';
	@TestVisible
	private static final String TANIUM_INC_ACCOUNT_ID = '0013200001D3n0nAAB';

	@AuraEnabled
	public static String getAccountInfoBlurb(Case aCase) {
		String ret = '';

		try {
			if (aCase.Account.Support_Model__c != null) {
				ret = String.valueOf(aCase.Account.Support_Model__c);
			}

			String soql =
				'SELECT Name ' +
				' FROM OpportunityLineItem ' +
				' WHERE Opportunity.Account.Id = \'' +
				aCase.AccountId +
				'\' ' +
				' AND Opportunity.StageName != \'Failed\' ' +
				' ORDER BY CreatedDate DESC';

			List<OpportunityLineItem> aItem = Database.query(soql);

			Boolean bMidMarket = false;
			Boolean bSupportLevel = false;
			List<String> lSupportLevels = new List<String>();

			for (OpportunityLineItem a : aItem) {
				String name = String.valueOf(a.Name);

				if (name.containsIgnoreCase('MidMarket')) {
					bMidMarket = true;
				}

				if (!bSupportLevel) {
					if (name.containsIgnoreCase('Support')) {
						bSupportLevel = true;

						if (name.containsIgnoreCase('L1')) {
							lSupportLevels.add('1');
						}

						if (name.containsIgnoreCase('L2')) {
							lSupportLevels.add('2');
						}

						if (name.containsIgnoreCase('L3')) {
							lSupportLevels.add('3');
						}

						if (name.containsIgnoreCase('L4')) {
							lSupportLevels.add('4');
						}
					}
				}
			}

			Boolean bTaas = false;
			String soql2 =
				'SELECT Id ' +
				'FROM Server_Deployment__c ' +
				'WHERE Account__c = \'' +
				aCase.AccountId +
				'\' ' +
				'AND Server_Device_Type__c  = \'Tanium as a Service\' ' +
				'AND Status__c = \'Active\'';

			List<Server_Deployment__c> aDeployment = Database.query(soql2);
			if (!aDeployment.isEmpty()) {
				bTaaS = true;
			}

			String supportLevels = '';
			if (!lSupportLevels.isEmpty()) {
				supportLevels = ' (L' + String.join(lSupportLevels, '-') + ')';
			}

			if (bMidMarket) {
				if (bTaas) {
					ret += ' | MidMarket | Tanium Cloud' + supportLevels;
				} else {
					ret += ' | MidMarket' + supportLevels;
				}
			} else {
				if (bTaas) {
					ret += ' | Tanium Cloud' + supportLevels;
				} else {
					ret += ' ' + supportLevels;
				}
			}

			if (!ret.contains('24x7')) {
				String soql4 =
					'SELECT Id,SBQQ__ProductName__c ' +
					'FROM SBQQ__QuoteLine__c ' +
					'WHERE SBQQ__Quote__r.SBQQ__Account__c = \'' +
					aCase.AccountId +
					'\' ' +
					'AND (SBQQ__ProductName__c LIKE \'%24x7%\' ' +
					'OR SBQQ__ProductName__c LIKE \'%24x7\' )' +
					'AND SBQQ__EndDate__c > TODAY ' +
					'LIMIT 1';

				List<SBQQ__QuoteLine__c> subscriptions2 = Database.query(soql4);
				if (!Subscriptions2.isEmpty()) {
					if (ret == '') {
						ret = '24x7';
					} else {
						ret += ' | 24x7';
					}
				}
			}
		} catch (DmlException e) {
			System.debug('getAccountInfoBlurb:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, String> getAccountInfoBlurbPartner(Case aCase) {
		Map<String, String> partnerAccountInfo = new Map<String, String>();

		try {
			List<Support_Partner__c> aPartnerSupported = [
				SELECT Id, Support_Partner__r.Name, Support_Partner__c
				FROM Support_Partner__c
				WHERE
					Account_Supported__c = :aCase.AccountId
					AND Partner_Role__c = 'Support'
					AND Support_Partner__c != :TANIUM_INC_ACCOUNT_ID
			];

			if (!aPartnerSupported.isEmpty()) {
				if (aPartnerSupported[0].Support_Partner__c != aCase.AccountId) {
					partnerAccountInfo.put('case_partner_id', aPartnerSupported[0].Support_Partner__c);
					partnerAccountInfo.put(
						'case_partner_name',
						aPartnerSupported[0].Support_Partner__r.Name
					);
				}
			}
		} catch (DmlException e) {
			System.debug(
				'getAccountInfoBlurbPartner:' + e.getMessage() + '\n' + e.getStackTraceString()
			);
		}

		return partnerAccountInfo;
	}

	@AuraEnabled
	public static Map<String, String> getHighlightInfo(String caseId) {
		Map<String, String> ret = new Map<String, String>();

		try {
			Case aCase = getCaseDetails(Id.valueOf(caseId));
			String threadId = EmailMessages.getFormattedThreadingToken(aCase.Id);

			ret.put('case_subject', aCase.CaseNumber + ':' + aCase.Subject);
			ret.put('case_type', aCase.Type);
			ret.put('case_contact', aCase.Contact.Name);
			ret.put('case_contact_id', aCase.ContactId);
			ret.put('case_contact_phone', aCase.Contact.Phone);
			ret.put('case_account_name', aCase.Account.Name);
			ret.put('case_owner', aCase.Owner.Name);
			ret.put('case_account_support_model', aCase.Account.Support_Model__c);
			ret.put('case_account_id', aCase.AccountId);
			ret.put('case_component', aCase.Component__c);
			ret.put('case_record_type', aCase.RecordType.Name);
			ret.put('case_esc_team', aCase.Escalation_Team__c);
			ret.put('case_severity', String.valueOf(aCase.Severity_Community__c).left(1));
			ret.put('case_account_premium_support', String.valueOf(aCase.Account.Premium_Support__c));
			ret.put('case_account_segment', aCase.Segment__c);

			ret.put('case_contact_profile', getContactProfile(aCase.ContactId));
			ret.put('flashSecurityText', getSecurityFlash(aCase));
			ret.put('flashClosedCaseText', getClosedCaseFlash(aCase));

			ret.put('case_status', aCase.Status);
			if (aCase.Status == 'On Hold' && String.isNotBlank(aCase.Status_Details__c)) {
				ret.put('case_status', aCase.Status + ' - ' + aCase.Status_Details__c);
			}

			ret.put('case_sme', '');
			if (!aCase.CaseContactRoles.isEmpty()) {
				String caseSME = '';
				for (CaseContactRole sme : aCase.CaseContactRoles) {
					caseSME = sme.Contact.Name;
				}
				ret.put('case_sme', caseSME);
			}

			ret.put('case_opportunity', '');
			if (aCase.Opportunity__c != null) {
				ret.put('case_opportunity_id', aCase.Opportunity__c);
				ret.put('case_opportunity', aCase.Opportunity__r.Name);
			}

			String slackid = getSlackId(aCase);

			Map<String, String> roscoAccDetails = getRoscoAccountDetails(aCase, slackid);
			ret.put('account_slack_url', roscoAccDetails.get('account_slack_url'));
			ret.put('account_slack_label', roscoAccDetails.get('account_slack_label'));
			ret.put('flashText', roscoAccDetails.get('flashText'));

			ret.put('isFedCase', 'false');
			ret.put('fedText', '');
			if (
				aCase.Account?.Region__c == 'US Federal' &&
				aCase.Account?.Sub_Region__c != null &&
				(aCase.Account.Sub_Region__c.containsIgnoreCase('Civilian') ||
				aCase.Account.Sub_Region__c.containsIgnoreCase('DOD'))
			) {
				ret.put('isFedCase', 'true');
				ret.put('fedText', FEDERAL_TEXT);
			}

			ret.put('isProspectCase', 'false');
			ret.put('prospectText', '');
			if (aCase.AccountId != '0010e00001RcgMsAAJ' && aCase.Account?.Type == 'Prospect') {
				ret.put('isProspectCase', 'true');
				ret.put('prospectText', PROSPECT_TEXT);
			}

			String accountInfoBlurb = getAccountInfoBlurb(aCase);
			ret.put('case_account_info', accountInfoBlurb);
			if (accountInfoBlurb.contains('Tanium Cloud')) {
				ret.put('isTaas', 'true');
			} else {
				ret.put('isTaas', 'false');
			}

			Map<String, String> accountInfoBlurbPartner = getAccountInfoBlurbPartner(aCase);
			if (accountInfoBlurbPartner.containsKey('case_partner_name')) {
				ret.put('case_partner_name', accountInfoBlurbPartner.get('case_partner_name'));
				ret.put('case_partner_id', accountInfoBlurbPartner.get('case_partner_id'));
			}

			Map<String, String> caseTime = getCaseTime(caseId);
			ret.put('case_time', caseTime.get('case_time'));
			ret.put('user_time', caseTime.get('user_time'));
			ret.put('case_time_type', caseTime.get('time_type'));
		} catch (DmlException e) {
			System.debug('getHighlightInfo:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	private static Case getCaseDetails(Id caseId) {
		return [
			SELECT
				CaseNumber,
				Subject,
				ContactId,
				Contact.Name,
				Contact.Phone,
				Contact.AccountId,
				Contact.Account.Name,
				ClosedDate,
				AccountId,
				Account.Name,
				Account.Support_Model__c,
				Account.Premium_Support__c,
				Account.Region__c,
				Account.Sub_Region__c,
				Account.Type,
				Account.Slack_Channel_Id__c,
				Owner.Name,
				Severity_Community__c,
				Component__c,
				Status,
				Status_Details__c,
				RecordType.Name,
				Opportunity__c,
				Opportunity__r.Name,
				Escalation_Team__c,
				Type,
				Segment__c,
				(SELECT Contact.Name FROM CaseContactRoles WHERE Role = 'Engaged SME')
			FROM Case
			WHERE Id = :caseId
			LIMIT 1
		];
	}

	private static String getSlackId(Case caseDetails) {
		return caseDetails.Account?.Slack_Channel_Id__c != null
			? caseDetails.Account.Slack_Channel_Id__c
			: '';
	}

	private static Map<String, String> getRoscoAccountDetails(Case caseDetails, String slackId) {
		Map<String, String> details = new Map<String, String>();
		details.put('account_slack_url', '(Unknown)');
		details.put('account_slack_label', '(Unknown)');
		details.put('flashText', '');

		List<Rosco_Account__c> roscoAccounts = [
			SELECT Name, case_flash__c, Case_Flash_Persist__c
			FROM Rosco_Account__c
			WHERE account__c = :caseDetails.AccountId
		];

		if (!roscoAccounts.isEmpty()) {
			details.put('account_slack_url', TANIUM_SLACK_URL + slackId);
			details.put('account_slack_label', '#' + roscoAccounts[0].Name);

			String flashText = '';
			if (caseDetails.Status == 'New') {
				flashText = (roscoAccounts[0].case_flash__c != null
					? roscoAccounts[0].case_flash__c
					: '');
			} else {
				flashText = (roscoAccounts[0].Case_Flash_Persist__c != null
					? roscoAccounts[0].Case_Flash_Persist__c
					: '');
			}
			details.put('flashText', flashText);
		}

		return details;
	}

	@AuraEnabled
	public static Map<String, String> getCaseTime(String caseId) {
		Map<String, String> timeDetails = new Map<String, String>();

		try {
			String userId = UserInfo.getUserId();
			String timeType = '';
			Integer caseTime = 0;
			Integer userTime = 0;

			for (Rosco_Time__c rTime : [
				SELECT Minutes__c, User__c, LaborSubCategory__c
				FROM Rosco_Time__c
				WHERE Case__c = :caseId
				ORDER BY CreatedDate DESC
			]) {
				caseTime += Integer.valueOf(rTime.Minutes__c);
				if (rTime.User__c == userId) {
					userTime = userTime + Integer.valueOf(rTime.Minutes__c);

					if (rTime.LaborSubCategory__c != null && timeType == '') {
						timeType = rTime.LaborSubCategory__c;
					}
				}
			}

			timeDetails.put('case_time', String.valueOf(caseTime));
			timeDetails.put('user_time', String.valueOf(userTime));
			timeDetails.put('time_type', (timeType == '' ? 'Support' : timeType));
		} catch (DmlException e) {
			System.debug('getCaseTime:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return timeDetails;
	}

	@AuraEnabled
	public static List<Map<String, String>> getCaseTime2(String caseId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String userId = UserInfo.getUserId();

			Integer caseTime = 0;
			Integer userTime = 0;
			Datetime removeCutoff = (System.now()).addDays(-7);

			for (Rosco_Time__c rTime : [
				SELECT
					Minutes__c,
					User__c,
					User__r.Email,
					CreatedDate,
					LaborDate__c,
					LaborSubCategory__c
				FROM Rosco_Time__c
				WHERE Case__c = :caseId
				ORDER BY CreatedDate DESC
			]) {
				Map<String, String> tmpmap = new Map<String, String>();

				String userEmail = rTime.User__r.Email;
				tmpmap.put('User', String.valueOf(userEmail).trim());
				tmpMap.put('Minutes', String.valueOf(rTime.Minutes__c).trim());
				tmpMap.put(
					'CreatedDate',
					rTime.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
				);
				tmpMap.put('Date', rTime.LaborDate__c.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));

				tmpMap.put('LaborSubCategory', rTime.LaborSubCategory__c);
				if (rTime.LaborDate__c > removeCutoff) {
					tmpMap.put('removable', 'true');
				} else {
					tmpMap.put('removable', 'false');
				}

				ret.add(tmpMap);
			}
		} catch (DmlException e) {
			System.debug('getCaseTime2:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String getClosedCaseFlash(Case aCase) {
		if (
			(aCase.RecordType.Name == 'Support' && aCase.ClosedDate != null) || Test.isRunningTest()
		) {
			Integer daysClosed = aCase.ClosedDate?.Date().daysBetween(System.now().Date());

			if (daysClosed < 90) {
				return 'Case was closed ' +
					daysClosed +
					' day(s) ago.  ' +
					'Case information will be redacted in ' +
					String.valueOf(90 - daysClosed) +
					' day(s) in compliance with Tanium\'s ' +
					'Record Retention and Destruction policy.';
			} else if (daysClosed < 365) {
				return 'Case was closed ' +
					daysClosed +
					' day(s) ago.  ' +
					'Case information may be redacted in compliance with Tanium\'s ' +
					'Record Retention and Destruction policy. Raw data such as images ' +
					'and log files are removed after 90 days.';
			} else if (daysClosed > 365) {
				return 'Case was closed ' +
					daysClosed +
					' day(s) ago.  ' +
					'Case information may be redacted in compliance with Tanium\'s ' +
					'Record Retention and Destruction policy. All information with the exception ' +
					'of the case closure summary remains after a case is closed for one year.';
			}
		}

		return '';
	}

	public static String getContactProfile(String contactId) {
		String ret = 'Error';

		try {
			List<User> users = [
				SELECT Id, Profile.Name, Email, TimeZoneSidKey
				FROM User
				WHERE IsActive = TRUE AND ContactId = :contactId
			];

			if (users.isEmpty()) {
				return 'Not registered';
			} else if (users[0].Email.containsIgnoreCase('@tanium.com')) {
				return 'Tanium';
			} else {
				User user = users[0];

				Integer userLoginCnt = [
					SELECT COUNT()
					FROM UserLogin
					WHERE isFrozen = TRUE AND UserId = :user.Id
				];

				if (userLoginCnt == 1) {
					return 'Frozen';
				} else {
					TimeZone tz = TimeZone.getTimeZone(user.TimeZoneSidKey);
					String offSet = String.valueOf((tz.getOffSet(DateTime.now()) / 3600000));

					if (!offSet.contains('-')) {
						offSet = '+' + offSet;
					}

					if (user.Profile.Name == COMMUNITY_LOGIN_UNKNOWN_PROFILENAME) {
						return 'Basic Access';
					} else if (user.Profile.Name == COMMUNITY_LOGIN_AUTH_PROFILENAME) {
						return 'KB Access';
					} else if (user.Profile.Name == COMMUNITY_LOGIN_AUTH_CASE_PROFILENAME) {
						return 'Case Access';
					} else if (user.Profile.Name == COMMUNITY_LOGIN_SUPER_USER_PROFILENAME) {
						return 'Power Access';
					}
				}
			}
		} catch (Exception e) {
			System.debug('getContactProfile: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String getSecurityFlash(Case aCase) {
		if (aCase.RecordType.Name == 'Internal') {
			return '';
		} else if (aCase?.Contact?.Account?.Name == 'Customer Community External Members Account') {
			return ' The case contact is in an account called "Customer Community External Members Account" ' +
				'which is a uncategorized/placeholder account.  Please click on the Case Contact\'s name (below left) ' +
				'which opens the Contact Record.  From there you can move the Contact to the proper Account.';
		} else if (aCase?.Account?.Name == 'Customer Community External Members Account') {
			return ' The case account is defined with Customer Community External Members Account ' +
				'which is a uncategorized/placeholder account.  Please click on the Triage tab ' +
				'and specify a proper account.';
		} else if (aCase?.Account?.Name != aCase?.Contact?.Account?.Name) {
			return ' The case contact\'s account \"' +
				aCase.Contact.Account.Name +
				'\" ' +
				' is different than Case account (' +
				aCase.Account.Name +
				') ' +
				' .  This may be normal in a partner scenario, but please understand the security implications. ' +
				' Super/Power users of the ' +
				aCase.Contact.Account.Name +
				' will have visiblity to this case. ' +
				' Please set different Case Contact if appropriate';
		}

		return '';
	}

	@AuraEnabled
	public static List<Map<String, String>> getSMETeams() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		Map<String, String> temp = new Map<String, String>();
		temp.put('value', 'Support');
		temp.put('label', 'Support');
		ret.add(temp);

		try {
			String soql =
				'SELECT Name ' +
				'FROM TAM_Team__c ' +
				'WHERE RecordType.Name = \'Escalation SME\' ' +
				'ORDER BY Name';

			List<TAM_Team__c> aSME = Database.query(soql);

			for (TAM_Team__c s : aSME) {
				Map<String, String> smeTeam = new Map<String, String>();
				smeTeam.put('value', s.Name);
				smeTeam.put('label', s.Name);
				ret.add(smeTeam);
			}
		} catch (Exception e) {
			System.debug('getSMETeams: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		Map<String, String> temp2 = new Map<String, String>();
		temp2.put('value', 'SME-Customer Success');
		temp2.put('label', 'SME-Customer Success');
		ret.add(temp2);
		Map<String, String> temp3 = new Map<String, String>();
		temp3.put('value', 'SME-Sales');
		temp3.put('label', 'SME-Sales');
		ret.add(temp3);
		Map<String, String> temp4 = new Map<String, String>();
		temp4.put('value', 'SME-Integrations');
		temp4.put('label', 'SME-Integrations');
		ret.add(temp4);

		return ret;
	}

	@AuraEnabled
	public static String getUserRoleName() {
		String ret = '';

		try {
			for (UserRole role : [SELECT Name FROM UserRole WHERE Id = :UserInfo.getUserRoleId()]) {
				ret = role.Name;
			}
		} catch (Exception e) {
			System.debug('getUserRoleName: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, String> removeTime(String caseId, String createdDate) {
		Map<String, String> ret = new Map<String, String>();

		try {
			if (String.valueOf(createdDate).length() > 1) {
				String soql =
					'SELECT Id ' +
					'FROM Rosco_Time__c ' +
					'WHERE Case__c = \'' +
					caseId +
					'\' ' +
					'AND CreatedDate = ' +
					createdDate +
					' ' +
					'LIMIT 1';

				List<Rosco_Time__c> lEntry = Database.query(soql);

				if (lEntry.size() != 0) {
					delete lEntry;
				}
			}

			ret = getCaseTime(caseId);
		} catch (DmlException e) {
			System.debug('removeTime:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static String saveCase(String caseId, String newstatus) {
		String ret;

		try {
			Case c = [SELECT AccountId, Dump_Team_Help__c FROM Case WHERE Id = :caseid LIMIT 1];

			String status = '';
			String statusdetails = '';

			if (newstatus == 'In Progress - Troubleshooting') {
				status = newstatus;
				statusdetails = '';
			} else if (newstatus == 'Pending - Clarifying') {
				status = newstatus;
				statusdetails = '';
			} else if (newstatus == 'On Hold - --None--') {
				status = 'On Hold';
				statusdetails = '';
			} else if (newstatus == 'On Hold - Pending Development') {
				status = 'On Hold';
				statusdetails = 'Pending Development';
			} else if (newstatus == 'On Hold - Pending Release') {
				status = 'On Hold';
				statusdetails = 'Pending Release';
			} else if (newstatus == 'On Hold - Pending Installation') {
				status = 'On Hold';
				statusdetails = 'Pending Installation';
			} else if (newstatus == 'On Hold - Pending Validation') {
				status = 'On Hold';
				statusdetails = 'Pending Validation';
			} else if (newstatus == 'On Hold - External Party') {
				status = 'On Hold';
				statusdetails = 'External Party';
			} else if (newstatus == 'On Hold - Pending Review') {
				status = 'On Hold';
				statusdetails = 'Pending Review';
			}

			c.Status = status;
			c.Status_Details__c = statusdetails;
			update c;
		} catch (DmlException e) {
			System.debug('saveCase:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static Map<String, String> saveTime(
		String caseId,
		String minutes,
		String laborCategory,
		String laborSubCategory,
		String laborDate
	) {
		Map<String, String> ret = new Map<String, String>();

		if (laborSubCategory.containsIgnoreCase('SME-')) {
			laborCategory = 'SME Time';
		}

		Datetime laborDateDT = date.valueOf(laborDate);

		try {
			String check = saveTimeCheck(caseId, minutes, laborDateDT);

			if (check == 'ok') {
				Case aCase = RoscoUtility.getCaseDetails(caseId);
				String escLevel = 'Level 1';
				if (aCase.Escalation_Tier__c != null) {
					escLevel = aCase.Escalation_Tier__c;
				}

				String userId = UserInfo.getUserId();

				Rosco_Time__c newTime = new Rosco_Time__c(
					Case__c = caseId,
					User__c = userId,
					Minutes__c = Integer.valueOf(minutes),
					LaborCategory__c = laborCategory,
					LaborSubCategory__c = laborSubCategory,
					LaborDate__c = laborDateDT,
					Escalation_Level__c = escLevel,
					Account__c = aCase.AccountId,
					Role__c = getUserRoleName()
				);
				insert newTime;

				ret = getCaseTime(caseId);
				ret.put('alert', '');
				ret.put('info', 'Successfully added ' + String.valueOf(minutes) + ' minutes.');
			} else {
				ret = getCaseTime(caseId);
				ret.put('alert', String.valueOf(check));
			}
		} catch (DmlException e) {
			System.debug('saveTime:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	public static String saveTimeCheck(String caseId, String minutes, Datetime laborDateDT) {
		String ret = 'Error Checking Time';

		try {
			String userId = UserInfo.getUserId();

			String soql =
				'SELECT LaborDate__c, Minutes__c, User__c' +
				' FROM Rosco_Time__c' +
				' WHERE Case__c = \'' +
				caseId +
				'\'' +
				' AND LaborDate__c != null';

			List<Rosco_Time__c> aTime = Database.query(soql);

			Integer userTime = 0;

			for (Rosco_Time__c a : aTime) {
				if (a.User__c == userId) {
					if (laborDateDT.isSameDay(a.LaborDate__c)) {
						userTime = userTime + Integer.valueOf(a.Minutes__c);
					}
				}
			}

			Integer proposedLabor = userTime + Integer.valueOf(minutes);
			Integer allowedLabor = 1440 - userTime;
			if (proposedLabor > 1440) {
				String dateStr =
					laborDateDT.yearGmt() +
					'-' +
					laborDateDT.monthGMT() +
					'-' +
					laborDateDT.dayGMT();

				ret =
					'Time could not be logged.  You attempted to add ' +
					String.valueOf(minutes) +
					' minutes and ' +
					String.valueOf(userTime) +
					' minutes have already been entered on ' +
					dateStr +
					'.  ' +
					'A maximum of 1440 minutes (24 hr) can be logged in one day (based on UTC).';
			} else {
				ret = 'ok';
			}
		} catch (DmlException e) {
			System.debug('saveTimeCheck:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}
}