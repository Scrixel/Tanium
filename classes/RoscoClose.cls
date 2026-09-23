/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: RoscoClose
 * @Date: 8/4/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7985    2024-05-14    Add Sub-Component Field
 * SS-8433    2024-06-13    Get picklist values in getInitInfo method
 * SS-9451    2024-10-23    Add bypass to closed cases validation
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-9852    2025-01-24    Added app name return on init
 * SS-12298   2026-01-13    Fixed formatting of Case Close Summary for ConnectApi stream
 */
public with sharing class RoscoClose {
	@TestVisible
	private static final List<String> CLOSED_STATUSES = new List<String>{
		'Solved',
		'Closed',
		'Closed as Duplicate'
	};

	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	public static Boolean enforceTimeCheck(String caseId) {
		Boolean ret = false;
		try {
			String soql =
				'SELECT CreatedDate FROM Case ' +
				' WHERE Id = \'' +
				caseId +
				'\'' +
				' AND CreatedDate > 2020-04-20T00:00:00Z';

			List<Case> cases = Database.query(soql);
			if (!cases.isEmpty()) {
				ret = true;
			}
		} catch (DmlException e) {
			Logger.error('RoscoClose.enforceTimeCheck ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> getInitInfo(String caseId) {
		Map<String, Object> ret = new Map<String, Object>();
		Map<String, String> caseDetails = new Map<String, String>();
		Map<String, Object> componentAndSubComponentOptions = new Map<String, Object>();
		List<Map<String, String>> incidentCauseOptions = new List<Map<String, String>>();
		List<Map<String, String>> resolutionCodeOptions = new List<Map<String, String>>();

		try {
			Case aCase = RoscoUtility.getCaseDetails(caseId);

			if (CLOSED_STATUSES.contains(aCase.Status)) {
				caseDetails.put('closedorsolved', 'true');
			} else {
				caseDetails.put('closedorsolved', 'false');
			}

			caseDetails.put('customerEmail', 'true');
			caseDetails.put('hydra', 'No');

			if (String.isBlank(aCase.Tags__c)) {
				caseDetails.put('notags', 'true');
			} else {
				caseDetails.put('notags', 'false');

				String tags = aCase.Tags__c;
				if (tags.contains('NoOpenCloseEmail')) {
					caseDetails.put('customerEmail', 'false');
				}
				if (tags.contains('HydraReporting')) {
					caseDetails.put('hydra', 'Yes');
				}
			}

			caseDetails.put('recordType', aCase.RecordType.Name);

			User user = [
				SELECT Id, Profile.Name, UserRole.Name
				FROM User
				WHERE Id = :UserInfo.getUserId()
				LIMIT 1
			];

			if (user.UserRole?.Name != null) {
				caseDetails.put('userRole', user.UserRole.Name);
			} else {
				caseDetails.put('userRole', '');
			}

			if (user.Profile?.Name != null) {
				caseDetails.put('userProfile', user.Profile.Name);
			} else {
				caseDetails.put('userProfile', '');
			}

			if (aCase.Summary__c != null) {
				caseDetails.put('caseSummary', aCase.Summary__c);
			} else {
				caseDetails.put('caseSummary', '');
			}

			if (aCase.Incident_Cause__c != null) {
				caseDetails.put('caseIncidentCause', aCase.Incident_Cause__c);
			} else {
				caseDetails.put('caseIncidentCause', '');
			}

			if (aCase.Resolution_Code__c != null) {
				caseDetails.put('caseResolutionCode', aCase.Resolution_Code__c);
			} else {
				caseDetails.put('caseResolutionCode', '');
			}

			if (aCase.KB_Worthy__c != null) {
				if (aCase.KB_Worthy__c) {
					caseDetails.put('caseKbWorthy', 'true');
				} else {
					caseDetails.put('caseKbWorthy', 'false');
				}
			} else {
				caseDetails.put('caseKbWorthy', 'false');
			}

			caseDetails.put('component', aCase.Component__c);
			caseDetails.put('subcomponent', aCase.Sub_Component__c);
			ret.put('caseDetails', caseDetails);

			componentAndSubComponentOptions = getComponentAndSubComponentPicklist();
			ret.put('componentAndSubComponentOptions', componentAndSubComponentOptions);

			incidentCauseOptions = getPicklistValuesIncidentCause2(aCase.RecordType.Name);
			ret.put('incidentCauseOptions', incidentCauseOptions);

			resolutionCodeOptions = getPicklistValuesResolutionCodes2(aCase.RecordType.Name);
			ret.put('resolutionCodeOptions', resolutionCodeOptions);

			if (!Test.isRunningTest()) {
				ret.put('app_name', Utility.getAppName());
			}

			return ret;
		} catch (DmlException e) {
			Logger.error('RoscoClose.getInitInfo ERRORS', e);
			Logger.saveLog();
		}

		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getPicklistValuesIncidentCause() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		Schema.DescribeFieldResult fieldResult = Case.Incident_Cause__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for (Schema.PicklistEntry f : ple) {
			Map<String, String> p = new Map<String, String>();
			p.put('label', f.getLabel());
			p.put('value', f.getLabel());

			ret.add(p);
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getPicklistValuesIncidentCause2(String recordType) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		List<String> codes = new List<String>();

		if (recordType == 'Technical Partnerships') {
			codes.add('Partner Application');
			codes.add('Customer Application');
			codes.add('Lab Request');
			codes.add('Other');
		} else if (recordType == 'Support') {
			codes.add('Hardware Issue');
			codes.add('Software Issue');
			codes.add('Network/Environmental Issue');
			codes.add('Knowledge / Training Related');
			codes.add('Partner Deployment/Migration');
			codes.add('Performance Related');
			codes.add('Tanium/3rd Party Vulnerability');
		} else {
			codes.add('TBD');
		}

		for (String c : codes) {
			Map<String, String> p = new Map<String, String>();
			p.put('label', c);
			p.put('value', c);

			ret.add(p);
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getPicklistValuesResolutionCodes() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		Schema.DescribeFieldResult fieldResult = Case.Resolution_Code__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for (Schema.PicklistEntry f : ple) {
			Map<String, String> p = new Map<String, String>();
			p.put('label', f.getLabel());
			p.put('value', f.getLabel());

			ret.add(p);
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getPicklistValuesResolutionCodes2(String recordType) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		// Need to redesign this one day, but apparently you can't get picklist values by
		// record type easily in apex without a callout
		// https://developer.salesforce.com/forums/?id=9062I000000QxgtQAC

		List<String> codes = new List<String>();

		if (recordType == 'Technical Partnerships') {
			codes.add('Application Accepted - Existing Partner');
			codes.add('Application Accepted - New Partner');
			codes.add('Application Accepted - Customer');
			codes.add('Application Rejected - Ineligible');
			codes.add('Application Rejected - Unresponsive');
			codes.add('Application Rejected - Customer or Prospect');
			codes.add('Lab Request Granted - OnPrem');
			codes.add('Lab Request Granted - Cloud');
			codes.add('Lab Request Denied');
			codes.add('Other');
		} else if (recordType == 'Support') {
			codes.add('Solved (Bug Workaround)');
			codes.add('Solved (Configuration Change)');
			codes.add('Solved (Education/Training - No changes required)');
			codes.add('Solved (Feature / Bug Logged)');
			codes.add('Solved (Upgrade)');
			codes.add('Solved (Tuning/Performance)');
			codes.add('Closed / Resolved by Customer');
			codes.add('Unable to Replicate');
			codes.add('Non-responsive customer');
			codes.add('Password Reset');
			codes.add('Completed migration to Support Center');
		} else {
			codes.add('TBD');
		}

		for (String c : codes) {
			Map<String, String> p = new Map<String, String>();
			p.put('label', c);
			p.put('value', c);

			ret.add(p);
		}
		return ret;
	}

	@AuraEnabled
	public static String saveCase(
		String caseId,
		String problem,
		String solution,
		String kb,
		String spam,
		String incidentCause,
		String resolutionCode,
		String standardEmail,
		String psEmail,
		String hydra,
		String component,
		String subcomponent
	) {
		String ret;
		try {
			Map<String, String> caseTime = RoscoHighlight.getCaseTime(caseId);
			if (
				spam == 'false' &&
				caseTime.get('case_time') == '0' &&
				enforceTimeCheck(caseId) == true
			) {
				ret = 'NoCaseTime';
				return ret;
			}

			Case caseRec = [
				SELECT AccountId, Tags__c, Escalation_Level_Watermark__c, Status, Summary__c
				FROM Case
				WHERE Id = :caseid
			];

			if (hydra == 'Yes') {
				String hydraTag = 'HydraReportingL1';
				String tags = String.isNotBlank(caseRec.Tags__c) ? caseRec.Tags__c : '';

				if (String.isNotBlank(caseRec.Escalation_Level_Watermark__c)) {
					if (caseRec.Escalation_Level_Watermark__c == 'Level 2') {
						hydraTag = 'HydraReportingL2';
					} else if (caseRec.Escalation_Level_Watermark__c == 'Level 3') {
						hydraTag = 'HydraReportingL3';
					} else if (caseRec.Escalation_Level_Watermark__c == 'Level 4') {
						hydraTag = 'HydraReportingL4';
					}
					if (!tags.containsIgnoreCase(hydraTag)) {
						caseRec.Tags__c = tags + ' ' + hydraTag;
					}
				}
			}

			if (standardEmail == 'false') {
				if (caseRec.Tags__c == null || caseRec.Tags__c == '') {
					caseRec.Tags__c = 'NoOpenCloseEmail';
				} else if (!caseRec.Tags__c.contains('NoOpenCloseEmail')) {
					caseRec.Tags__c = caseRec.Tags__c + ',NoOpenCloseEmail';
				}
			} else if (caseRec.Tags__c != null && caseRec.Tags__c.contains('NoOpenCloseEmail')) {
				caseRec.Tags__c = caseRec.Tags__c.replaceAll('NoOpenCloseEmail', '').normalizeSpace();
			}

			String caseSummary =
				'Symptoms:\n=======================\n' +
				problem +
				'\n\n\n' +
				'Solution:\n=======================\n' +
				solution;
			caseRec.Summary__c = caseSummary;

			if (
				!Constants.CASE_CLOSE_STATUSES.contains(caseRec.Status) && caseRec.Status != 'Solved'
			) {
				caseRec.Status = 'Solved';
				caseRec.LatestPrivateComment__c = caseSummary;
			}

			caseRec.Incident_Cause__c = String.valueOf(incidentCause);
			caseRec.Resolution_Code__c = String.valueOf(resolutionCode);
			caseRec.Component__c = component;
			caseRec.Sub_Component__c = subcomponent;

			if (spam == 'true') {
				caseRec.Summary__c = 'spam';
				caseRec.Incident_Cause__c = 'SPAM';
				caseRec.Resolution_Code__c = 'SPAM';
			} else if (kb == 'true') {
				caseRec.KB_Worthy__c = true;
			} else {
				caseRec.KB_Worthy__c = false;
			}

			Database.SaveResult saveResult = Database.update(caseRec, false);
			if (!saveResult.isSuccess()) {
				Logger.error('RoscoClose.saveCase ERRORS', saveResult);
				Logger.saveLog();
			}

			if (psEmail == 'true') {
				sendPSEmail(caseid, problem, solution);
			}
		} catch (Exception e) {
			Logger.error('RoscoClose.saveCase ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	@future
	public static void writeFeedItem(String caseId, String text) {
		FeedItem feedItem = new FeedItem(
			Body = text,
			IsRichText = true,
			NetworkScope = 'AllNetworks',
			Type = 'TextPost',
			Visibility = 'InternalUsers',
			ParentId = caseId
		);
		insert feedItem;
	}

	@AuraEnabled
	public static String saveCaseDup(String caseId, String orgCaseId, String copy) {
		String ret = '';

		try {
			if (copy == 'true') {
				String soql =
					'SELECT ' +
					'ActivityId ' +
					',BccAddress ' +
					',CcAddress ' +
					',CreatedDate ' +
					',FromAddress ' +
					',FromName ' +
					',HasAttachment ' +
					',HtmlBody ' +
					',Id ' +
					',Incoming ' +
					',IsExternallyVisible ' +
					',MessageDate ' +
					',MessageIdentifier ' +
					',ParentId ' +
					',RelatedToId ' +
					',Status ' +
					',Subject ' +
					',TextBody ' +
					',ThreadIdentifier ' +
					',ToAddress ' +
					',ValidatedFromAddress ' +
					'FROM EmailMessage ' +
					'WHERE IsPrivateDraft = false ' +
					'AND ParentId = \'' +
					caseId +
					'\' ' +
					'ORDER BY CreatedDate ASC';

				List<EmailMessage> messages = Database.query(soql);

				if (messages.size() != 0) {
					String emailIds = '';
					for (EmailMessage m : messages) {
						String eid = '\'' + String.valueOf(m.Id) + '\'';
						emailIds = emailIds == '' ? eid : emailIds + ',' + eid;
					}

					Map<String, String> attMap = new Map<String, String>();
					String soql2 =
						'SELECT Body' +
						',ContentType' +
						',Description' +
						',IsPrivate' +
						',Name' +
						',OwnerId ' +
						'FROM Attachment ' +
						'WHERE ParentId IN (' +
						emailIds +
						')';

					List<Attachment> attachments = Database.query(soql2);

					if (attachments.size() != 0) {
						for (Attachment a : attachments) {
							Attachment newAttachment = new Attachment(
								Body = a.Body,
								ContentType = a.ContentType,
								Description = a.Description,
								IsPrivate = a.IsPrivate,
								Name = a.Name,
								OwnerId = a.OwnerId,
								ParentId = orgCaseId
							);
							String newAttId = RoscoUtilityNoShare.createAttachment(newAttachment);
							attMap.put(String.valueOf(a.Id), String.valueOf(newAttId));
						}
					}

					for (EmailMessage m : messages) {
						String body = m.HtmlBody;
						for (String orgId : attMap.keySet()) {
							body = body.replace(orgId, attMap.get(orgId));
						}

						EmailMessage newEmail = new EmailMessage(
							BccAddress = m.BccAddress,
							CcAddress = m.CcAddress,
							FromAddress = m.FromAddress,
							FromName = m.FromName,
							HtmlBody = body,
							Incoming = m.Incoming,
							IsExternallyVisible = m.IsExternallyVisible,
							MessageDate = m.MessageDate,
							MessageIdentifier = m.MessageIdentifier,
							ParentId = orgCaseId,
							RelatedToId = orgCaseId,
							Status = m.Status,
							Subject = m.Subject,
							TextBody = m.TextBody,
							ThreadIdentifier = m.ThreadIdentifier,
							ToAddress = m.ToAddress,
							CreatedDate = m.CreatedDate
						);
						insert newEmail;
					}
				}

				String soql3 =
					'SELECT Body' +
					',IsRichText' +
					',NetworkScope' +
					',Type' +
					',Visibility ' +
					'FROM CaseFeed ' +
					'WHERE ParentId = \'' +
					caseId +
					'\' ' +
					'AND Type = \'TextPost\'';

				List<CaseFeed> items = Database.query(soql3);
				if (items.size() != 0) {
					for (CaseFeed item : items) {
						FeedItem newFi = new FeedItem(
							Body = item.Body,
							IsRichText = item.IsRichText,
							NetworkScope = item.NetworkScope,
							Type = item.Type,
							Visibility = item.Visibility,
							ParentId = orgCaseId
						);
						insert newFi;
					}
				}
			}

			Case orgCaseNumber = [SELECT CaseNumber, Id FROM Case WHERE Id = :orgCaseId];
			String text2 = 'Merged this case into Case #' + orgCaseNumber.CaseNumber;
			writeFeedItem(caseId, text2);

			Case mergedCase = [
				SELECT Id, CaseNumber, Status, Tags__c, IsClosed
				FROM Case
				WHERE Id = :caseId
			];
			String text = 'Case #' + mergedCase.CaseNumber + ' merged into this case';
			writeFeedItem(orgCaseId, text);

			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String caseOwnerId = '00532000005VMZAAA4';
			if (cmfields.contains('rosco_case_ownerid__c')) {
				if (!nullOrEmpty(cm.get('rosco_case_ownerid__c'))) {
					caseOwnerId = String.valueOf(cm.get('rosco_case_ownerid__c'));
				}
			}

			mergedCase.Tags__c = mergedCase.Tags__c + ',NoOpenCloseEmail';
			mergedCase.Status = 'Closed as Duplicate';
			mergedCase.OwnerId = caseOwnerId;
			update mergedCase;
		} catch (Exception e) {
			System.debug('saveCaseDup:' + e.getMessage() + '\n' + e.getStackTraceString());
			ret = 'Error merging case, consider unchecking Copy emails checkbox and retrying :\n\n';
			ret +=
				String.valueOf('Message:\n' + e.getMessage()) +
				'\n\nStack:\n' +
				String.valueOf(e.getStackTraceString());
		}

		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getDuplicateCaseLookup(
		String searchKeyWord,
		String caseId
	) {
		List<Map<String, String>> returnList = new List<Map<String, String>>();

		if (searchKeyWord == null) {
			searchKeyWord = '';
		}

		String accountId = [SELECT AccountId FROM Case WHERE Id = :caseId].AccountId;

		searchKeyWord = searchKeyWord.trim();

		String soql;
		if (searchKeyWord == '') {
			soql =
				'SELECT CaseNumber, Subject, Account.Name ' +
				'FROM Case ' +
				'WHERE Status != \'Closed\' and Status != \'Closed as Duplicate\' ' +
				'AND AccountId = \'' +
				accountId +
				'\' ' +
				'AND Id != \'' +
				caseId +
				'\' ' +
				'ORDER BY CreatedDate DESC';
		} else {
			soql =
				'SELECT CaseNumber, Subject, AccountId, Account.Name ' +
				'FROM Case ' +
				'WHERE Status != \'Closed as Duplicate\' ' +
				'AND Id != \'' +
				caseId +
				'\' ' +
				'AND (Subject LIKE \'%' +
				searchKeyWord +
				'%\' ' +
				'OR CaseNumber LIKE \'%' +
				searchKeyWord +
				'%\') ' +
				'ORDER BY CreatedDate DESC LIMIT 20';
		}

		List<Case> cases = Database.query(soql);
		if (!cases.isEmpty()) {
			for (Case c : cases) {
				Map<String, String> orgCase = new Map<String, String>();
				String orgCaseId = String.valueOf(c.get('Id'));
				String caseNumber = String.valueOf(c.get('CaseNumber'));
				String caseSubject = String.valueOf(c.get('Subject'));
				String caseAccountName = String.valueOf(c.Account.Name);

				orgCase.put('Id', orgCaseId);
				if (accountId != c.AccountId) {
					orgCase.put(
						'Description',
						'Warning: Different Account - ' +
						caseNumber +
						' - ' +
						caseSubject +
						' (' +
						caseAccountName +
						')'
					);
				} else {
					orgCase.put(
						'Description',
						caseNumber +
						' - ' +
						caseSubject +
						' (' +
						caseAccountName +
						')'
					);
				}

				returnList.add(orgCase);
			}
		}

		return returnList;
	}

	public static void sendPSEmail(String caseid, String problem, String solution) {
		String ccrString = RoscoCaseContactRole.getCCRString(caseid);

		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
		String owea = '0D20e0000004DjCCAU';
		if (cmfields.contains('rosco_owea_support__c')) {
			if (!nullOrEmpty(cm.get('rosco_owea_support__c'))) {
				owea = String.valueOf(cm.get('rosco_owea_support__c'));
			}
		}

		Case c = [SELECT CaseNumber, Subject FROM Case WHERE Id = :caseid LIMIT 1];
		String caseSubject = c.caseNumber + ':' + c.Subject + ' (Solved)';
		String threadId = EmailMessages.getFormattedThreadingToken(c.Id);
		String htmlBody =
			'Thank you for choosing Tanium Support!<br><br>Your case has been marked solved and  ' +
			'below you will find a brief synopsis of the issue. <br><br><b>Symptoms</b><br>' +
			problem +
			'<br><br><b>Solution</b><br>' +
			solution +
			'<br><br> ' +
			'If you have any comments or concerns please respond to this email.  Otherwise we will mark this case Closed in 7 days.' +
			'<br><br>Regards,<br>Tanium Support' +
			'<br><br> ' +
			threadId;

		String textBody =
			'Thank you for choosing Tanium Support!\n\nYour case has been marked solved and  ' +
			'below you will find a brief synopsis of the issue. \n\nSymptoms\n==========\n' +
			problem +
			'\n\nSolution\n==========' +
			solution +
			'\n\n ' +
			'If you have any comments or concerns please respond to this email.  Otherwise we will mark this case Closed in 7 days.' +
			'\n\nRegards,<br>Tanium Support' +
			'\n\n ' +
			threadId;

		List<String> cc = ccrstring.split(';');
		String[] toAddresses = cc;

		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
		mail.setOrgWideEmailAddressId(owea);
		mail.setToAddresses(toAddresses);
		mail.setSubject(caseSubject);
		mail.setHtmlBody(htmlBody);
		mail.setPlainTextBody(textBody);

		if (!caseSubject.contains('ROSCOTESTCASE')) {
			Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
		}
	}

	@AuraEnabled
	public static Map<String, Object> getComponentAndSubComponentPicklist() {
		Map<String, Object> ret = new Map<String, Object>();

		try {
			List<String> lComponents = new List<String>();
			Schema.DescribeFieldResult fieldResult = Case.Component__c.getDescribe();
			List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
			for (Schema.PicklistEntry p : ple) {
				String label = String.valueOf(p.getLabel());
				if (label != 'Other: Product not listed') {
					lComponents.add(String.valueOf(p.getLabel()));
				}
			}
			lComponents.sort();
			lComponents.add('Other: Product not listed');
			List<Map<String, String>> components = new List<Map<String, String>>();
			for (String component : lComponents) {
				Map<String, String> c = new Map<String, String>();
				c.put('label', component);
				c.put('value', component);
				components.add(c);
			}
			ret.put('components', components);

			Map<String, List<String>> subComponents = Utility.getDependentPicklistValues(
				'Case',
				'Component__c',
				'Sub_Component__c'
			);
			ret.put('sub_components', subComponents);

			return ret;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}
}