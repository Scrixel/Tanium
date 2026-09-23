/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: RoscoUtility
 * @Date: 6/13/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7985    2024-05-14    Add Sub-Component Field
 * SS-10083	  2025-01-24	Replace Case.ThreadId__c w/ Case.ThreadId_caseSensitive__c
 * SS-7124	  2025-02-04	Use !empty in setCleanCaseSubject()
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c reference	from the class
 * SS-13177   2026-05-27    Update getTrimmedSubject regex pattern for bug fix
 * SS-13497   2026-07-07    Remove deprecated fields for project kondo group 2
 */
public with sharing class RoscoUtility {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	public static String convertHTMLGetAttachmentBase64(String attachmentId) {
		String ret = '';

		try {
			String soql =
				'SELECT Body ' +
				'FROM Attachment ' +
				'WHERE Id = \'' +
				attachmentId +
				'\' ' +
				'LIMIT 1';

			List<Attachment> aAtt = new List<Attachment>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				aAtt = Database.query(soql);
			}

			if (aAtt.size() > 0) {
				ret = EncodingUtil.base64Encode(aAtt[0].Body);
			}
		} catch (Exception e) {
		}

		return ret;
	}

	public static String convertHTMLGetImgTagWithBase64(String imgTag) {
		String ret = imgTag;

		try {
			System.debug('imgTag:' + imgTag);

			String expression = 'src=".*?"';
			Pattern srcPattern = Pattern.compile(expression);
			Matcher matcher = srcPattern.matcher(imgTag);

			if (matcher.find()) {
				String srcAttribute = matcher.group(0);
				System.debug('srcAttribute:' + srcAttribute);

				List<String> srcAttributeSplit = srcAttribute.split('[?]');
				System.debug('srcAttributeSplit:' + String.valueOf(srcAttributeSplit));

				String attachmentId = srcAttributeSplit[0].right(15);
				attachmentId = attachmentId.replace('"', '');
				System.debug('attachmentId:' + attachmentId);
				String base64Attachment = convertHTMLGetAttachmentBase64(attachmentId);
				System.debug('base64Attachment:' + base64Attachment);

				System.debug('imgTag:' + imgTag);
				if (base64Attachment != '') {
					ret = imgTag.replace(
						srcAttribute,
						'src="data:image/png;base64,' +
						base64Attachment +
						'"'
					);
				}
				System.debug('returning:' + ret);
			}
		} catch (Exception e) {
			System.debug(
				'convertHTMLGetImgTagWithBase64: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}

		return ret;
	}

	/** getAccountDetails Get all the fields of a given case
	 * @param  account id String (i.e. 001xyz...)
	 * @return Map Object
	 */
	public static Map<String, String> getAccountDetails(String accountId) {
		Map<String, String> ret = new Map<String, String>();

		try {
			String soql =
				'SELECT Id' +
				',Name' +
				',Premium_Support__c' +
				',Type' +
				' FROM Account' +
				' WHERE Id = \'' +
				accountId +
				'\'';

			List<Account> accounts = Database.query(soql);

			if (accounts.size() > 0) {
				Account a = accounts[0];

				ret.put('ptamid', 'not defined');
				ret.put('stamid', 'not defined');
				ret.put('mtamname', 'not defined');

				ret.put('name', 'not defined');
				if (a.Name != null) {
					if (String.valueOf(a.Name) != '') {
						ret.put('name', String.valueOf(a.Name));
					}
				}

				ret.put('premium', 'false');
				if (a.Premium_Support__c != null) {
					if (String.valueOf(a.Premium_Support__c) != '') {
						if (String.valueOf(a.Premium_Support__c).toLowerCase() == 'true') {
							ret.put('premium', 'true');
						}
					}
				}

				ret.put('type', 'not defined');
				if (a.Type != null) {
					if (String.valueOf(a.Type) != '') {
						ret.put('type', String.valueOf(a.Type));
					}
				}
			}

			// Get People info
			List<Map<String, String>> peeps = RoscoUtility.getPeopleDetails();

			ret.put('ptamname', 'not defined');
			ret.put('stamname', 'not defined');
			for (Map<String, String> peep : peeps) {
				if (peep.get('userid') == ret.get('ptamid')) {
					ret.put('ptamname', peep.get('slackname'));
					ret.put('ptampod', peep.get('pod'));
				}
				if (peep.get('userid') == ret.get('stamid')) {
					ret.put('stamname', peep.get('slackname'));
					ret.put('stampod', peep.get('pod'));
				}
			}
		} catch (Exception e) {
			System.debug('getAccountDetails: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCaseDetails Get all the fields of a given case
	 * @param  case id String (i.e. 500xyz...)
	 * @return Case Object
	 */
	public static Case getCaseDetails(String caseId) {
		Case ret;

		try {
			String soql =
				'SELECT Id' +
				',IsDeleted' +
				',CaseNumber' +
				',ContactId' +
				',AccountId' +
				//',SourceId' +
				//',BusinessHoursId' +
				',ParentId' +
				',SuppliedEmail' +
				',Type' +
				',RecordTypeId' +
				',RecordType.Name' +
				',Status' +
				',Reason' +
				',Origin' +
				',Subject' +
				',Priority' +
				',Description' +
				',IsClosed' +
				',ClosedDate' +
				',OwnerId' +
				',CreatedDate' +
				',CreatedById' +
				',LastModifiedDate' +
				',LastModifiedById' +
				',SystemModstamp' +
				',ContactPhone' +
				',ContactMobile' +
				',ContactEmail' +
				',ContactFax' +
				',LastViewedDate' +
				',LastReferencedDate' +
				',Case_Creator__c' +
				',Category__c' +
				',Case_Delivery_Date__c' +
				',Updates__c' +
				',Component_Version__c' +
				',Component__c' +
				',Sub_Component__c' +
				',Enhancement_request_filed__c' +
				',JIRA_ID__c' +
				',KB_Created__c' +
				',KB_Worthy__c' +
				',LatestPublicComment__c' +
				',LatestPublicCommentHTML__c' +
				',LatestPrivateComment__c' +
				',LatestPrivateCommentHTML__c' +
				',Last_Response_Date__c' +
				',Last_Customer_Response_Date__c' +
				',Last_Automation_Response_Date__c' +
				//',Case_Audit_Trail__c' +
				//',Phone_number__c' +
				//',Preferred_Contact_Method__c' +
				',Reference_Number__c' +
				',Severity_Community__c' +
				//',Reason_for_High_Priority__c' +
				//',Expected_Release_Date__c' +
				//',Email_CCs__c' +
				',OperatingSystem__c' +
				//',Sub_Status__c' +
				',Tags__c' +
				//',Zendesk_Group__c' +
				//',Zendesk_Ticket_Number__c' +
				',Case_Comment__c' +
				',Dump_Team_Help__c' +
				',critsit__c' +
				',DeEscalation_Date__c' +
				',Escalation_Date__c' +
				',Escalation_L2_Date__c' +
				',Escalation_L2_SME_Engaged_Date__c' +
				',Escalation_L2_SLO__c' +
				',Escalation_L3_Date__c' +
				',Escalation_L3_SME_Engaged_Date__c' +
				',Escalation_L3_SLO__c' +
				',Escalation_L4_Date__c' +
				',Escalation_L4_SME_Engaged_Date__c' +
				',Escalation_L4_SLO__c' +
				',Escalation_L5_Date__c' +
				',Escalation_L5_SME_Engaged_Date__c' +
				',Escalation_L5_SLO__c' +
				',Escalation_Level_Watermark__c' +
				',Escalation_Reason_Delete__c' +
				',Escalation_Reason__c' +
				',Escalation_Artifact__c' +
				',Escalation_Pod__c' +
				',Escalation_Tier__c' +
				',Escalation_Type__c' +
				',Escalation_Team__c' +
				',Escalation_Status__c' +
				',First_Assigned_Date__c' +
				',First_Response_Date__c' +
				',First_SME_Assigned_Date__c' +
				',First_Solved_Date__c' +
				',No_Public_Comments_Allowed__c' +
				',Severity_Flag__c' +
				',SME_OwnerId__c' +
				',SME_Shadow__c' +
				',Solved_Date__c' +
				',Status_Details__c' +
				',Summary__c' +
				',Support_Model__c' +
				',Visible_in_Community__c' +
				',Community_Case_Link__c' +
				',Case.Account.Name' +
				',Case.Account.Type' +
				',Case.Contact.Name' +
				',Case.Contact.Email' +
				',Case.Contact.Account.Name' +
				',Case.Owner.Name' +
				',Case.Owner.Email' +
				',Incident_Cause__c' +
				',Resolution_Code__c' +
				' FROM Case' +
				' WHERE Id = \'' +
				caseId +
				'\'';

			List<Case> cases = Database.query(soql);

			return cases[0];
		} catch (Exception e) {
			System.debug('getCaseDetails: ' + e.getMessage() + '\n' + e.getStackTraceString());
			return ret;
		}
	}

	/** getPeopleDetails Get all the fields of a given case
	 * @return Map Object
	 */
	public static List<Map<String, String>> getPeopleDetails() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			// Get Email map
			Map<String, String> emails = new Map<String, String>();
			String soql = 'SELECT Id, Email FROM Contact WHERE Id IN (SELECT contact__c FROM rosco_people__c)';

			List<Contact> contactemails = Database.query(soql);
			for (Contact c : contactemails) {
				emails.put(String.valueOf(c.Id), String.valueOf(c.Email));
			}

			// Get People info
			soql =
				'SELECT Id' +
				',Name' +
				',contact__c' +
				',user__c' +
				',pod__c' +
				',primary_sme__c' +
				',secondary_sme__c' +
				' FROM rosco_people__c' +
				' WHERE pod__c != null';

			List<rosco_people__c> people = Database.query(soql);

			for (rosco_people__c p : people) {
				Map<String, String> peep = new Map<String, String>();

				peep.put('slackname', 'not defined');
				if (p.Name != null) {
					if (String.valueOf(p.Name) != '') {
						peep.put('slackname', String.valueOf(p.Name));
					}
				}

				peep.put('contactid', 'not defined');
				peep.put('contactemail', 'not defined');
				if (p.contact__c != null) {
					if (String.valueOf(p.contact__c) != '') {
						peep.put('contactid', String.valueOf(p.contact__c));
					}

					if (emails.containsKey(String.valueOf(p.contact__c))) {
						peep.put('contactemail', emails.get(String.valueOf(p.contact__c)));
					}
				}

				peep.put('userid', 'not defined');
				if (p.user__c != null) {
					if (String.valueOf(p.user__c) != '') {
						peep.put('userid', String.valueOf(p.user__c));
					}
				}

				peep.put('pod', 'not defined');
				if (p.pod__c != null) {
					if (String.valueOf(p.pod__c) != '') {
						peep.put('pod', String.valueOf(p.pod__c));
					}
				}

				peep.put('psme', 'not defined');
				if (p.primary_sme__c != null) {
					if (String.valueOf(p.primary_sme__c) != '') {
						peep.put('psme', String.valueOf(p.primary_sme__c));
					}
				}

				peep.put('ssme', 'not defined');
				if (p.secondary_sme__c != null) {
					if (String.valueOf(p.secondary_sme__c) != '') {
						peep.put('ssme', String.valueOf(p.secondary_sme__c));
					}
				}

				ret.add(peep);
			}
		} catch (Exception e) {
			System.debug('getPeopleDetails: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCaseInfoHtmlTable retrieves HTML table used
	 * by a number of other functions for presenting.
	 * @param  case id String (i.e. 500xyz...)
	 * @return string representing html table
	 */
	public static String getCaseInfoHtmlTable(String caseId) {
		String ret = '';

		try {
			// Get a good link to case, lookup in Custom Settings
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			String caseLink = System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + caseId;
			String friendlylink = '';
			if (
				cmfields.contains('rosco_case_url_prefix__c') &&
				cmfields.contains('rosco_sfdc_dom_l__c')
			) {
				String urlprefix = String.valueOf(cm.get('rosco_case_url_prefix__c'));
				String urlfriend = String.valueOf(cm.get('rosco_sfdc_dom_l__c'));

				caseLink = 'https://' + urlfriend + '/lightning/r/Case/' + caseId + '/view';
			}

			// Get additional info about case
			List<Case> c = [
				SELECT Id, CaseNumber, OwnerId, Subject, Severity_Community__c, Component__c, AccountId
				FROM Case
				WHERE Id = :caseId
			];

			if (!c.IsEmpty()) {
				String casenumber = c[0].CaseNumber;
				//casenumber = casenumber.replaceAll('^[0][0][0]', '');
				String threadId = EmailMessages.getFormattedThreadingToken(c[0].Id);
				String subject = c[0].Subject;
				String accountid = c[0].AccountId;
				String ownerid = c[0].ownerId;
				String severity = String.valueOf(c[0].Severity_Community__c).left(1);
				String component = c[0].Component__c;

				System.debug('casenumber:' + casenumber);
				System.debug('threadid:' + threadid);
				System.debug('subject:' + subject);
				System.debug('accountid:' + accountid);
				System.debug('ownerid:' + ownerId);
				System.debug('severity:' + severity);
				System.debug('component:' + component);

				// Get Owner Email Id
				String ownerEmail = 'support-sme@tanium.com';
				try {
					ownerEmail = [SELECT Email FROM User WHERE Id = :ownerid].Email;
					System.debug('ownerEmail:' + ownerEmail);
				} catch (Exception e) {
					System.debug('Unable to determine owner email');
				}
				System.debug('ownerEmail:' + ownerEmail);

				// Account Slack Channel
				String slackname = 'not configured';
				try {
					slackname = [SELECT Name FROM Rosco_Account__c WHERE account__c = :accountid].Name;
				} catch (Exception e) {
					System.debug('Rosco_Account__c may not be configured');
				}
				System.debug('slackname:' + slackname);

				// Account info
				String slackid, accountname = 'undetermined';
				try {
					Account a = [SELECT name, Slack_Channel_Id__c FROM Account WHERE id = :accountid];
					slackid = a.Slack_Channel_Id__c;
					System.debug('slackid:' + slackid);
					accountname = a.Name;
					System.debug('accountname:' + accountname);
				} catch (Exception e) {
					System.debug('Unable to retrieve account info');
				}

				// CCR String
				String ccr = 'to be enabled soon';

				try {
					ccr = RoscoCaseContactRole.getCCRString(caseId);
				} catch (Exception e) {
					System.debug('An unexpected error has occurred: ' + e.getMessage());
				}

				// Create table
				ret += '<table style="border: 1px solid #dddddd;width: 100%">';
				ret += '<tr>';
				ret += '<td style="border: 1px solid #dddddd";><b>Case</b></td>';
				ret += '<td>' + casenumber + '</td>';
				ret += '</tr>';
				ret += '<tr bgcolor="#dddddd">';
				ret += '<td style="border: 1px solid #dddddd"><b>Subject</b></td>';
				ret += '<td>' + subject + '</td>';
				ret += '</tr>';
				ret += '<tr>';
				ret += '<td style="border: 1px solid #dddddd"><b>Severity</b></td>';
				ret += '<td>' + severity + '</td>';
				ret += '</tr>';
				ret += '<tr bgcolor="#dddddd">';
				ret += '<td style="border: 1px solid #dddddd"><b>Component</b></td>';
				ret += '<td>' + component + '</td>';
				ret += '</tr>';
				ret += '<tr>';
				ret += '<td style="border: 1px solid #dddddd"><b>Owner</b></td>';
				ret += '<td>' + ownerEmail + '</td>';
				ret += '</tr>';
				ret += '<tr bgcolor="#dddddd">';
				ret += '<td style="border: 1px solid #dddddd"><b>Ref Id</b></td>';
				ret += '<td>' + threadid + '</td>';
				ret += '</tr>';
				ret += '<tr>';
				String accountslack = 'undetermined';
				if (slackName != '') {
					accountslack =
						'<a href="https://tanium.slack.com/messages/' +
						slackid +
						'">#' +
						slackname +
						'</a><br>';
				}
				ret += '<td style="border: 1px solid #dddddd";><b>Account</b></td>';
				ret += '<td>' + accountslack + '</td>';
				ret += '</tr>';
				ret += '<tr bgcolor="#dddddd">';
				ret += '<td style="border: 1px solid #dddddd"><b>Link</b></td>';
				ret += '<td>' + '<a href="' + caseLink + '">' + caseLink + '</a><br>' + '</td>';
				ret += '</tr>';
				ret += '<tr>';
				ret += '<td style="border: 1px solid #dddddd";><b>CC List</b></td>';
				ret += '<td>' + ccr + '</td>';
				ret += '</tr>';
				ret += '</table>';
			}
		} catch (Exception e) {
			System.debug('getCaseInfoHtmlTable: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCleanWhereClause used for text such that it can
	 * be used in SOQL IN clause (i.e 'value1','value2','value3')
	 * @param  String with values separated by ; or ,
	 * @return String with values such as 'value1','value2','value3'
	 */
	public static String getCleanWhereClause(String txt) {
		String ret = '';

		try {
			// standardize delims
			txt = txt.replace(';', ',');
			txt = txt.replace('\'', '\\\'');
			System.debug('txt:' + txt);

			// create list
			List<String> l = new List<String>();
			if (txt.contains(',')) {
				l = txt.split(',');
			} else {
				l.add(txt);
			}

			// loop through list and create return string
			for (String s : l) {
				if (ret == '') {
					ret = '\'' + s.trim() + '\'';
				} else {
					ret = ret + ',' + '\'' + s.trim() + '\'';
				}
			}
		} catch (Exception e) {
			System.debug('getCleanWhereClause: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getRecordTypeIdByAPIName
	 *
	 */
	public static Id getRecordTypeIdByAPIName(String objectName, String recordTypeAPIName) {
		SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
		if (objectType == null) {
			System.debug('Object not found');
			return null;
		} else {
			RecordTypeInfo recordtypeInfo = objectType.getDescribe()
				.getRecordTypeInfosByDeveloperName()
				.get(recordTypeAPIName);
			if (recordtypeInfo == null) {
				System.debug('RecordType not found');
				return null;
			} else {
				return recordtypeInfo.getRecordTypeId();
			}
		}
	}

	/** getTrimmedSubject
	 * Attempt to remove superflous text from subject
	 * @param String - existing subject
	 * @return String - cleaned up subject
	 */
	public static String getTrimmedSubject(String value) {
		String newValue = value;

		try {
			Datetime dt = Datetime.Now();
			String dts = String.valueOf(dt.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));

			if (newValue == null) {
				newValue = 'null subject, please specify (' + dts + ')';
			} else if (newValue == '') {
				newValue = 'blank subject, please specify (' + dts + ')';
			}

			newvalue = newValue.replaceAll('\\[[Ee][Xx][Tt][Ee][Rr][Nn][Aa][Ll]\\]', '');
			newvalue = newvalue.replaceAll('\\{[Ee][Xx][Tt][Ee][Rr][Nn][Aa][Ll]\\}', '');
			newvalue = newvalue.replaceAll('\\[[Ee][Xx][Tt]\\]', '');
			newvalue = newvalue.replaceAll('\\{[Ee][Xx][Tt]\\}', '');
			newvalue = newvalue.trim();
			newvalue = newvalue.replaceAll(
				'^(?:\\[?(?:[Ff][Ww][Dd]?|[Rr][Ee])(?:\\s*[:;-]+\\s*\\]?))+',
				''
			);
			newvalue = newvalue.replaceAll('^Sandbox:', '');
			newvalue = newvalue.replaceAll('(Warning - Password Protected File Attached)', '');
			newValue = newvalue.trim();

			// replace refid
			final String CASE_THREAD_ID_EXPRESSION = '([Rr][Ee][Ff][:][_][a-zA-Z0-9]+[.][_][a-zA-Z0-9]+[:][Rr][Ee][Ff])';
			newValue = newValue.replaceAll(CASE_THREAD_ID_EXPRESSION, '');
			newValue = newValue.trim();

			newValue = newValue.replaceAll('(\\[\\])|(\\[ \\])|(\\[  \\])', '');
			newValue = newvalue.trim();

			if (newValue == '') {
				newValue = 'blank subject, please specify (' + dts + ')';
			}
		} catch (Exception e) {
			System.debug('getTrimmedSubject: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return newvalue;
	}

	/** getEmailFromUserId
	 * Given a user Id, returns its email address
	 * @param  String Salesforce User Id (i.e 005zzz)
	 * @return String Email - foo@bar.com
	 */
	public static String getEmailFromUserId(String userId) {
		String ret;

		try {
			List<User> ulist = [SELECT Email FROM User WHERE Id = :userId];
			if (!ulist.isEmpty()) {
				ret = ulist[0].Email;
			}
		} catch (Exception e) {
			System.debug('getEmailFromUserId: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getNameFromUserId
	 * Given a user Id, returns its Name
	 * @param  String Salesforce User Id (i.e 005zzz)
	 * @return String Name - John Doe
	 */
	public static String getNameFromUserId(String userId) {
		String ret;

		try {
			List<User> ulist = [SELECT Name FROM User WHERE Id = :userId];
			if (!ulist.isEmpty()) {
				ret = ulist[0].Name;
			}
		} catch (Exception e) {
			System.debug('getNameFromUserId: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** inCronExpression given a Cron expression determine if current time is inside it
	 * @param  String Salesforce cron expression
	 * @return Boolean true if current time (PT) is inside expression
	 */
	public static Boolean inCronExpression(String cronExpression) {
		Boolean ret;

		try {
			ret = true;

			datetime now = system.now();

			List<String> parts = cronExpression.split(' ');

			// Second
			//String sec = parts[0];
			//System.debug('sec:' + sec);

			// Min
			//String min = parts[1];
			//System.debug('min:' + min);

			// Hour
			// =================================
			String hr = parts[2];
			System.debug('hr:' + hr);
			List<String> hrs = new List<String>();

			// add all hours if * specified
			if (hr.contains('*')) {
				for (Integer i = 0; i <= 23; i++) {
					hrs.add(String.valueOf(i));
				}
			} else if (hr.contains('-')) {
				List<String> hrends = hr.split('-');
				Integer start = Integer.valueOf(hrends[0]);
				Integer stop = Integer.valueOf(hrends[1]);

				for (Integer i = start; i <= stop; i++) {
					System.Debug(i);
					hrs.add(String.valueOf(i));
				}
			} else if (hr.contains(',')) {
				hrs = hr.split(',');
			} else {
				hrs.add(hr);
			}

			// is the current hour in the expression?
			if (hrs.contains(String.valueOf(now.hour()))) {
				System.debug('Hour in expression');
			} else {
				System.debug('Hour not in expression:' + String.valueOf(now.hour()));
				ret = false;
			}

			// Day (month)
			//String day1 = parts[3];
			//System.debug('day1:' + day1);

			// Month
			//String mo = parts[4];
			//System.debug('mo:' + mo);

			// Day (week)
			String day2 = parts[5].toLowerCase();
			System.debug('day2:' + day2);
			List<String> days2 = new List<String>();
			if (day2.contains(',')) {
				days2 = day2.split(',');
			} else {
				days2.add(day2);
			}

			String dayOfWeek = now.format('E').toLowerCase();
			// is the current day of week in the expression?
			if (days2.contains(dayOfWeek)) {
				System.debug('Day of week in expression');
			} else {
				System.debug('Day of week not in expression:' + dayofWeek);
				System.debug('days2:' + String.valueOf(days2));
				ret = false;
			}

			// Year
			//String yr = parts[6];
			//System.debug('yr:' + yr);
		} catch (Exception e) {
			System.debug('inCronExpression: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** setCleanCaseSubject updates Case Object with "clean" subject
	 * @param  List of Cases (only does element 0)
	 */
	@InvocableMethod(label='Set Clean Case Subject')
	public static void setCleanCaseSubject(List<Case> cases) {
		try {
			if (!cases.isEmpty()) {
				Case aCase = cases[0];
				if (aCase?.Id != null) {
					Case c = [SELECT Subject, CaseNumber FROM Case WHERE Id = :aCase.Id];
					if (c != null) {
						String s = getTrimmedSubject(c.Subject);
						String caseNumber = c.CaseNumber;
						Case tmpcase = new Case(Id = c.Id, Subject = s);
						update tmpcase;
					}
				}
			}
		} catch (Exception e) {
			System.debug('setCleanCaseSubject: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}
	/** sortListMapName sorts list by Name
	 * @param  List of Map
	 * return  same list sorted list alpabetically
	 */
	public static List<Map<String, String>> sortListMapName(List<Map<String, String>> thelist) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			List<String> sorted = new List<String>();
			for (Map<String, String> element : thelist) {
				sorted.add(element.get('Name'));
			}
			sorted.sort();

			// In case people have same names
			List<String> already = new List<String>();

			for (String sname : sorted) {
				for (Map<String, String> element : thelist) {
					String contactid = element.get('Id');
					if (!already.contains(contactid)) {
						if (element.get('Name') == sname) {
							ret.add(element);
							already.add(contactid);
						}
					}
				}
			}
		} catch (Exception e) {
			System.debug('sortListMapName: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getPicklistValuesCaseComponent sorts list by Name
	 * @param  List of Map
	 * return  same list sorted list alpabetically
	 */
	public static String getPicklistValuesCaseComponent() {
		String ret = '';

		Schema.DescribeFieldResult fieldResult = Case.Component__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for (Schema.PicklistEntry f : ple) {
			if (ret == '') {
				ret = f.getLabel();
			} else {
				ret = ret + ',' + f.getLabel();
			}
		}
		return ret;
	}

	/** getSlackNamesForGlobalSMEs sorts list by Name
	 * @param  List of Map
	 * return  same list sorted list alpabetically
	 */
	public static String getSlackNamesForGlobalSMEs(String smeteam) {
		String ret = '';

		try {
			String soql =
				'SELECT Name FROM rosco_people__c WHERE primary_sme__c LIKE \'%' +
				smeteam +
				'%\' and pod__c = \'Product SME\'';

			List<rosco_people__c> aPeoples = Database.query(soql);

			if (aPeoples.size() > 0) {
				for (rosco_people__c aPeople : aPeoples) {
					if (ret == '') {
						ret = '@' + aPeople.Name;
					} else {
						ret = ret + ' @' + aPeople.Name;
					}
				}
			}
		} catch (Exception e) {
			System.debug(
				'getSlackNamesForGlobalSMEs: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}

		return ret;
	}

	/** getSlackNamesForSMEs sorts list by Name
	 * @param  List of Map
	 * return  same list sorted list alpabetically
	 */
	public static String getSlackNamesForSMEs(String smeteam) {
		String ret = '';

		try {
			String soql =
				'SELECT Name,pod__c FROM rosco_people__c WHERE primary_sme__c LIKE \'%' +
				smeteam +
				'%\' or secondary_sme__c LIKE \'%' +
				smeteam +
				'%\'';

			List<rosco_people__c> aPeoples = Database.query(soql);

			if (aPeoples.size() > 0) {
				for (rosco_people__c aPeople : aPeoples) {
					if (aPeople.pod__c != 'Product SME') {
						if (ret == '') {
							ret = '@' + aPeople.Name;
						} else {
							ret = ret + ' @' + aPeople.Name;
						}
					}
				}
			}
		} catch (Exception e) {
			System.debug('getSlackNamesForSMEs: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSlackNamesFromCCR sorts list by Name
	 * @param  List of Map
	 * return  same list sorted list alpabetically
	 */
	public static String getSlackNamesFromCCR(String caseId) {
		String ret = '';

		try {
			String soql =
				'SELECT Name FROM rosco_people__c WHERE contact__c IN ' +
				'(SELECT ContactId FROM CaseContactRole WHERE CasesId = \'' +
				caseId +
				'\')';

			List<rosco_people__c> aPeoples = Database.query(soql);

			if (aPeoples.size() > 0) {
				for (rosco_people__c aPeople : aPeoples) {
					if (ret == '') {
						ret = '@' + aPeople.Name;
					} else {
						ret = ret + ' @' + aPeople.Name;
					}
				}
			}
		} catch (Exception e) {
			System.debug('getSlackNamesFromCCR: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** addCasePostX
	 * @param  caseid
	 * @param  post
	 * return  void
	 */
	/** addCasePost
	 * @param  caseid
	 * @param  post
	 * return  void
	 */
	public static void addCasePost(String caseId, String body) {
		try {
			FeedItem newPost = new FeedItem(
				ParentId = caseId,
				Body = body,
				Visibility = 'InternalUsers',
				IsRichText = false
			);
			insert newPost;
		} catch (Exception e) {
			System.debug('addCasePost: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	public static void addCasePostRich(String caseId, String body) {
		try {
			FeedItem newPost = new FeedItem(
				ParentId = caseId,
				Body = body,
				Visibility = 'InternalUsers',
				IsRichText = true
			);
			insert newPost;
		} catch (Exception e) {
			System.debug('addCasePost: ' + e.getMessage() + '\n' + e.getStackTraceString());
			FeedItem newPost2 = new FeedItem(
				ParentId = caseId,
				Body = body.stripHTMLTags(),
				Visibility = 'InternalUsers',
				IsRichText = false
			);
			insert newPost2;
		}
	}
}