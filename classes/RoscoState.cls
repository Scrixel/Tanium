/**
 * @Business:
 * @Date:
 * @Authors: Tanium Dev Team
 * @Request:
 * RequestId  ModifiedDate  Description
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-9852    2025-01-24    Added app name return on init
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */
public with sharing class RoscoState {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** addCasePost
	 * @param  caseid
	 * @param  post
	 * return  void
	 */
	public static void addCasePost(String caseId, String body, Boolean rich) {
		system.debug('body:' + body);

		try {
			FeedItem newPost = new FeedItem(
				ParentId = caseId,
				Body = body,
				Visibility = 'InternalUsers',
				IsRichText = rich
			);
			insert newPost;
		} catch (Exception e) {
			System.debug('addCasePost: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** getSummaryHTML
	 */
	public static Map<String, String> getSummaryHTML(
		Case aCase,
		String subjective,
		String objective,
		String assessment,
		String plan,
		String soapemailcustomer,
		String condition,
		String action,
		String need,
		String canemailcustomer
	) {
		Map<String, String> ret = new Map<String, String>();

		String email = '';
		String post = '';

		email = '<html><body>';
		post = '<html><body>';

		email +=
			'Please find the below summary of Tanium support case  ' +
			String.valueOf(aCase.CaseNumber) +
			':';
		email += '<p>&nbsp;</p>';

		if (nullOrEmpty(subjective) == false) {
			email += '<b><u>Description</u></b>&nbsp;';
			email += subjective + '<p>&nbsp;</p>';
			post += '<b><u>Description</u></b>&nbsp;';
			post += subjective + '<p>&nbsp;</p>';

			if (nullOrEmpty(objective) == false) {
				email += '<b><u>Objective (facts, explicit goals))</u></b>&nbsp;';
				email += objective + '<p>&nbsp;</p>';
				post += '<b><u>Objective (facts, explicit goals))</u></b>&nbsp;';
				post += objective + '<p>&nbsp;</p>';
			}

			if (nullOrEmpty(assessment) == false) {
				email += '<b><u>Assessment (observations)</u></b>&nbsp;';
				email += assessment + '<p>&nbsp;</p>';
				post += '<b><u>Assessment (observations)</u></b>&nbsp;';
				post += assessment + '<p>&nbsp;</p>';
			}

			if (nullOrEmpty(plan) == false) {
				email += '<b><u>Plan (next steps)</u></b>&nbsp;';
				email += plan + '<p>&nbsp;</p>';
				post += '<b><u>Plan (next steps)</u></b>&nbsp;';
				post += plan + '<p>&nbsp;</p>';
			}

			if (nullOrEmpty(soapemailcustomer) == false) {
				if (soapemailcustomer == 'true') {
					post += '<i>Note: Summary emailed to customer (cc)</i>&nbsp;';
				} else {
					post += '<i>Note: Summary <b>not</b> emailed to customer</i>&nbsp;';
				}
			}
		}

		if (nullOrEmpty(condition) == false) {
			email += '<b><u>Conditions</u></b>&nbsp;';
			email += condition + '<p>&nbsp;</p>';
			post += '<b><u>Conditions</u></b>&nbsp;';
			post += condition + '<p>&nbsp;</p>';

			if (nullOrEmpty(action) == false) {
				email += '<b><u>Actions</u></b>&nbsp;';
				email += action + '<p>&nbsp;</p>';
				post += '<b><u>Actions</u></b>&nbsp;';
				post += action + '<p>&nbsp;</p>';
			}

			if (nullOrEmpty(need) == false) {
				email += '<b><u>Needs</u></b>&nbsp;';
				email += need + '<p>&nbsp;</p>';
				post += '<b><u>Needs</u></b>&nbsp;';
				post += need + '<p>&nbsp;</p>';
			}

			if (nullOrEmpty(canemailcustomer) == false) {
				if (canemailcustomer == 'true') {
					post += '<i>Note: Summary emailed to customer (cc)</i>&nbsp;';
				} else {
					post += '<i>Note: Summary <b>not</b> emailed to customer</i>&nbsp;';
				}
			}
		}

		String threadId = EmailMessages.getFormattedThreadingToken(aCase.Id);

		email += '<p>&nbsp;</p>' + '<p>Regards,&nbsp;</p>Tanium Support';
		email += '<p>&nbsp;</p>' + threadId;

		email += '</body></html>';
		post += '</body></html>';

		ret.put('post', post);
		ret.put('email', email);

		return ret;
	}

	/** getSummaryText
	 */
	public static String getSummaryText(
		Case aCase,
		String subjective,
		String objective,
		String assessment,
		String plan,
		String condition,
		String action,
		String need
	) {
		String ret = '';
		ret +=
			'Please find a quick summary of Tanium support case ' +
			String.valueOf(aCase.CaseNumber) +
			' below:';
		ret += '\n\n';

		if (nullOrEmpty(subjective) == false) {
			ret += 'Description';
			ret += '\n============================';
			ret += '\n' + subjective.stripHtmlTags();

			if (nullOrEmpty(objective) == false) {
				ret += 'Objective (facts, explicit goals)';
				ret += '\n============================';
				ret += '\n' + objective.stripHtmlTags();
			}

			if (nullOrEmpty(assessment) == false) {
				ret += 'Assessment (observations)';
				ret += '\n============================';
				ret += '\n' + assessment.stripHtmlTags();
			}

			if (nullOrEmpty(plan) == false) {
				ret += 'Plan (next steps)';
				ret += '\n============================';
				ret += '\n' + plan.stripHtmlTags();
			}
		}

		if (nullOrEmpty(condition) == false) {
			ret += 'Conditions';
			ret += '\n============================';
			ret += '\n' + condition.stripHtmlTags();

			if (nullOrEmpty(action) == false) {
				ret += 'Actions';
				ret += '\n============================';
				ret += '\n' + action.stripHtmlTags();
			}

			if (nullOrEmpty(need) == false) {
				ret += 'Needs';
				ret += '\n============================';
				ret += '\n' + need.stripHtmlTags();
			}
		}

		String threadId = EmailMessages.getFormattedThreadingToken(aCase.Id);
		ret += '\n\nRegards,\nTanium Support';
		ret += '\n\n' + threadId;

		return ret;
	}

	/** getInitInfo
	 * @param caseId - case to retrieve Case info
	 * @return Map of State Info
	 */
	@AuraEnabled
	public static Map<String, String> getInitInfo(String caseId) {
		Map<String, String> ret = new Map<String, String>();

		ret.put('subjective', '');
		ret.put('objective', '');
		ret.put('assessment', '');
		ret.put('plan', '');
		ret.put('priority', '');

		ret.put('condition', '');
		ret.put('action', '');
		ret.put('need', '');

		try {
			// Get State info from rosco_case_state
			// Get Escalation Level Information
			String soql =
				'SELECT Name, CreatedById,CreatedDate,Id,IsDeleted,LastModifiedById,LastModifiedDate ' +
				',conditions__c,actions__c,needs__c ' +
				',subjective__c,objective__c,assessment__c,plan__c ' +
				'FROM rosco_case_state__c ' +
				'WHERE case__c=\'' +
				caseid +
				'\' ' +
				'ORDER BY LastModifiedDate desc';

			System.debug('soql:' + soql);

			List<rosco_case_state__c> aStates = Database.query(soql);

			if (aStates.size() != 0) {
				ret.put('subjective', aStates[0].subjective__c);
				ret.put('objective', aStates[0].objective__c);
				ret.put('assessment', aStates[0].assessment__c);
				ret.put('plan', aStates[0].plan__c);

				ret.put('condition', aStates[0].conditions__c);
				ret.put('action', aStates[0].actions__c);
				ret.put('need', aStates[0].needs__c);
			}

			String soql2 =
				'SELECT Description,Priority,critsit__c,Status ' +
				'FROM Case ' +
				'WHERE Id=\'' +
				caseid +
				'\'';

			System.debug('soql2:' + soql2);

			List<Case> aCase = Database.query(soql2);
			if (aCase.size() != 0) {
				ret.put('subjective', aCase[0].Description);
				ret.put('priority', aCase[0].Priority);
				if (aCase[0].critsit__c == true) {
					ret.put('critsit', 'true');
				} else {
					ret.put('critsit', 'false');
				}

				if (
					aCase[0].Status == 'Solved' ||
					aCase[0].Status == 'Closed' ||
					aCase[0].Status == 'Closed as Duplicate'
				) {
					ret.put('closedorsolved', 'true');
				} else {
					ret.put('closedorsolved', 'false');
				}
			}

			if (!Test.isRunningTest()) {
				ret.put('app_name', Utility.getAppName());
			}
		} catch (DmlException e) {
			System.debug('getInitInfo:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getPreviousEmail
	 */
	public static Map<String, String> getPreviousEmail(Case aCase) {
		Map<String, String> ret = new Map<String, String>();
		ret.put('html', '');
		ret.put('text', '');

		String caseid = aCase.Id;
		if (caseid.left(3) == '500') {
			String soql =
				'SELECT FromAddress,ToAddress,CcAddress,Subject,TextBody,HtmlBody ' +
				'FROM EmailMessage ' +
				'WHERE ParentId = \'' +
				caseid +
				'\' ' +
				'AND IsPrivateDraft = false ' +
				'AND IsExternallyVisible = true ' +
				'ORDER BY LastModifiedDate DESC NULLS LAST LIMIT 1';

			System.debug('soql:' + soql);

			List<EmailMessage> aEmails = Database.query(soql);

			if (aEmails.size() != 0) {
				// Prior Email Fields
				String priorFieldsHtml = '-----Original Message-----<br>';
				String priorFieldsText = '-----Original Message-----\n';

				if (nullOrEmpty(aEmails[0].FromAddress) == false) {
					priorFieldsHtml += 'From: ' + aEmails[0].FromAddress + '<br>';
					priorFieldsText += 'From: ' + aEmails[0].FromAddress + '\n';
				}

				if (nullOrEmpty(aEmails[0].ToAddress) == false) {
					priorFieldsHtml += 'To: ' + aEmails[0].ToAddress + '<br>';
					priorFieldsText += 'To: ' + aEmails[0].ToAddress + '\n';
				}

				if (nullOrEmpty(aEmails[0].CcAddress) == false) {
					priorFieldsHtml += 'Cc: ' + aEmails[0].CcAddress + '<br>';
					priorFieldsText += 'Cc: ' + aEmails[0].CcAddress + '\n';
				}

				if (nullOrEmpty(aEmails[0].Subject) == false) {
					priorFieldsHtml += 'Subject: ' + aEmails[0].Subject + '<br>';
					priorFieldsText += 'Subject: ' + aEmails[0].Subject + '\n';
				}

				priorFieldsHtml += '<br><br>';
				priorFieldsText += '\n\n';

				// HTML and Text Body
				if (aEmails[0].HtmlBody != null) {
					ret.put('html', priorFieldsHTML + aEmails[0].HtmlBody);
				}
				if (aEmails[0].TextBody != null) {
					ret.put('text', priorFieldsText + aEmails[0].TextBody);
				}
			}
		}

		return ret;
	}

	/** saveCase
	 * @param caseId
	 * @param reason
	 * @return String
	 */
	@AuraEnabled
	public static String saveCase(
		String caseid,
		String subjective,
		String objective,
		String assessment,
		String plan,
		String priority,
		String soapemailcustomer,
		String condition,
		String action,
		String need,
		String canemailcustomer,
		String critsit
	) {
		String ret;

		System.debug('saveCase called with the following parameters:');
		System.debug('caseid:' + caseid);
		System.debug('subjective:' + subjective);
		System.debug('objective:' + objective);
		System.debug('assessment:' + assessment);
		System.debug('plan:' + plan);
		System.debug('priority:' + priority);
		System.debug('soapemailcustomer:' + soapemailcustomer);
		System.debug('condition:' + condition);
		System.debug('action:' + action);
		System.debug('need:' + need);
		System.debug('canemailcustomer:' + canemailcustomer);
		System.debug('critsit:' + critsit);

		try {
			// Update Case Description
			if (subjective != '') {
				Case c = [SELECT Description FROM Case WHERE Id = :caseid LIMIT 1];

				// Update the case
				c.Description = subjective.stripHtmlTags();
				if (priority != '') {
					c.Priority = priority;
				}
				update c;
			}

			// Update Critical Situation
			if (condition != '' && critsit != null) {
				Case c = [SELECT critsit__c FROM Case WHERE Id = :caseid LIMIT 1];

				// Update the case
				if (String.valueOf(c.critsit__c).toLowerCase() != critsit.toLowerCase()) {
					if (critsit.toLowerCase() == 'true') {
						c.critsit__c = true;
					} else {
						c.critsit__c = false;
					}
					update c;
				}
			}

			// SOAP or CAN Report
			Datetime soaplastmodifieddate = null;
			Datetime canlastmodifieddate = null;
			if (subjective != '') {
				soaplastmodifieddate = system.now();
			} else {
				canlastmodifieddate = system.now();
			}

			// Update rosco_state
			rosco_case_state__c newrcs = new rosco_case_state__c(
				case__c = +caseid,
				subjective__c = subjective,
				objective__c = objective,
				assessment__c = assessment,
				plan__c = plan,
				SOAPLastModifiedDate__c = soaplastmodifieddate,
				conditions__c = condition,
				actions__c = action,
				needs__c = need,
				CANLastModifiedDate__c = canlastmodifieddate
			);
			insert newrcs;

			// Get Case info
			Case aCase = RoscoUtility.getCaseDetails(caseid);

			// get summary html/text

			// Send Email
			Map<String, String> summary = getSummaryHTML(
				aCase,
				subjective,
				objective,
				assessment,
				plan,
				soapemailcustomer,
				condition,
				action,
				need,
				canemailcustomer
			);

			if (
				(subjective != '' && soapemailcustomer == 'true') ||
				(condition != '' &&
				canemailcustomer == 'true')
			) {
				String html = summary.get('email');
				String text = getSummaryText(
					aCase,
					subjective,
					objective,
					assessment,
					plan,
					condition,
					action,
					need
				);
				Map<String, String> previous = getPreviousEmail(aCase);
				sendEmail(aCase, html, text, previous);
			}

			sendToSlack(
				caseid,
				subjective,
				objective,
				assessment,
				plan,
				priority,
				soapemailcustomer,
				condition,
				action,
				need,
				canemailcustomer,
				critsit
			);

			String html = summary.get('post');
			addCasePost(caseid, html, true);
		} catch (DmlException e) {
			System.debug('saveCase:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		ret = 'foo';
		return ret;
	}

	/** sendEmail
	 */
	public static void sendEmail(Case aCase, String html, String text, Map<String, String> previous) {
		String caseid = aCase.Id;

		// get people on CC
		List<String> cc = new List<String>();
		List<CaseContactRole> ccr = [SELECT Contact.Email FROM CaseContactRole WHERE CasesId = :caseid];
		if (nullOrEmpty(ccr) == false) {
			for (CaseContactRole c : ccr) {
				if (c.Contact.Email != null) {
					String address = c.Contact.Email.toLowerCase();
					if (address.contains('@')) {
						cc.add(address);
					}
				}
			}
		}
		//cc.add('rosco@w-m1mzr2z8clz86j1lxuok39pntqlm9dk5zv9dd3thb5zshils7.s-3en8xmac.cs1.apex.sandbox.salesforce.com');

		// Get org wide sender id
		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
		String owea = '0D20e0000004DjCCAU';
		if (cmfields.contains('rosco_owea_support__c')) {
			if (!nullOrEmpty(cm.get('rosco_owea_noreply__c'))) {
				owea = String.valueOf(cm.get('rosco_owea_noreply__c'));
			}
		}
		System.debug('owea:' + owea);

		// Get Subject
		String subject = aCase.CaseNumber + ':' + aCase.Subject;

		// Send Email
		if (nullOrEmpty(cc) == false) {
			//slipstream
			if (previous.get('html') != '') {
				html += previous.get('html');
			}

			if (previous.get('text') != '') {
				text += '\n\n' + previous.get('text');
			}

			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setOrgWideEmailAddressId(owea);
			mail.setToAddresses(cc);
			mail.setSubject(subject);

			mail.setHtmlBody(html);
			mail.setPlainTextBody(text);

			if (!aCase.Subject.contains('ROSCOTESTCASE')) {
				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
		}
	}
	/** sendToSlack
	 */
	public static void sendToSlack(
		String caseId,
		String subjective,
		String objective,
		String assessment,
		String plan,
		String priority,
		String soapemailcustomer,
		String condition,
		String action,
		String need,
		String canemailcustomer,
		String critsit
	) {
		System.debug('sendToSlack:entering');

		try {
			Case aCase = RoscoUtility.getCaseDetails(caseid);

			// Custom settings may override some options
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			// Use base url, but override better link
			String caseLink = System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + aCase.ID;

			if (
				cmfields.contains('rosco_case_url_prefix__c') && cmfields.contains('rosco_sfdc_dom_l__c')
			) {
				String urlprefix = String.valueOf(cm.get('rosco_case_url_prefix__c'));
				String urlfriend = String.valueOf(cm.get('rosco_sfdc_dom_l__c'));

				if (nullOrEmpty(urlprefix) == false && nullOrEmpty(urlfriend) == false) {
					caseLink =
						'<' +
						urlprefix +
						aCase.ID +
						'%2Fview|https://' +
						urlfriend +
						'/lightning/r/Case/' +
						aCase.ID +
						'/view>';
					caseLink += ' <https://' + urlfriend + '/lightning/r/Case/' + aCase.ID + '/view|(alt)>';
				}
			}

			// Exception channel defaults to #tool_soa but account should override
			String accountChannel = 'CJ4PWL412';
			String smeChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String ac = String.valueOf(cm.get('rosco_slack_exceptions__c'));

				if (nullOrEmpty(ac) == false) {
					accountChannel = ac;
					smeChannel = ac;
				}
			}

			// SME Channel (really where CAN Reports go to)
			if (cmfields.contains('rosco_slack_can__c')) {
				String canchannel = String.valueOf(cm.get('rosco_slack_can__c'));

				if (nullOrEmpty(canchannel) == false) {
					smeChannel = canchannel;
				}
			}

			// Webhook
			System.debug('sendToSlack:checking for webhook url');
			String webhookURL = 'https://hooks.slack.com/services/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';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}

			// Determine contact
			System.debug('sendToSlack:determining contact');
			String contact_from;
			if (String.isBlank(aCase.ContactEmail)) {
				contact_from = aCase.SuppliedEmail;
			} else {
				contact_from = aCase.ContactEmail;
			}

			// Determine Severity
			System.debug('sendToSlack:checking severity');
			String sev = String.valueOf(aCase.Severity_Community__c).left(1);

			// Create text for slack pos
			String caseNumber = aCase.CaseNumber;
			String fallbackPretext =
				'for Sev *' +
				sev +
				'* Case *' +
				caseNumber +
				'* for *' +
				contact_from +
				'*';
			if (subjective != '') {
				fallbackPretext = '*DOAP* review ' + fallbackPretext;
			}
			if (condition != '') {
				fallbackPretext = '*CAN* review ' + fallbackPretext;
			}

			// slack list of attachments
			List<Map<String, Object>> fieldsInternalListSME = new List<Map<String, Object>>();
			List<Map<String, Object>> fieldsInternalListAccount = new List<Map<String, Object>>();

			// slack attachment
			Map<String, Object> fieldsInternalMap = new Map<String, Object>();
			fieldsInternalMap.put('title', '*' + aCase.subject + '*');
			fieldsInternalMap.put('text', '*' + aCase.subject + '*');
			fieldsInternalMap.put('value', caseLink);
			fieldsInternalMap.put('short', false);
			fieldsInternalListSME.add(fieldsInternalMap);
			fieldsInternalListAccount.add(fieldsInternalMap);

			// slack attachment
			// Get Slack Channel Name for Account if available
			if (nullOrEmpty(aCase.AccountId) == false) {
				Account anAccount = [
					SELECT id, name, Slack_Channel_Id__c, Premium_Support__c
					FROM account
					WHERE id = :aCase.AccountId
				];

				if (!String.isBlank(anAccount.Slack_Channel_Id__c)) {
					String soql2 =
						'SELECT Name FROM rosco_account__c ' +
						'WHERE account__c= \'' +
						anAccount.Id +
						'\'';

					System.debug('SOQL2: ' + soql2);
					List<Rosco_Account__c> slacknames = Database.query(soql2);

					if (slacknames.size() != 0) {
						String slackname;
						slackname = String.valueOf(slacknames[0].Name);

						if (nullOrEmpty(slackname) == false) {
							accountChannel = anAccount.Slack_Channel_Id__c;

							String sLink =
								'<https://tanium.slack.com/messages/' +
								anAccount.Slack_Channel_Id__c +
								'|#' +
								slackname +
								'>';

							Map<String, Object> fieldsInternalMap2 = new Map<String, Object>();
							fieldsInternalMap2.put('title', 'Customer Channel:');
							fieldsInternalMap2.put('value', sLink);
							fieldsInternalMap2.put('short', false);
							fieldsInternalListSME.add(fieldsInternalMap2);
						}
					}
				}
			}

			// slack attachment
			// Get Component
			//if( nullOrEmpty( aCase.Component__c ) == False ){

			//Map<String,Object> fieldsInternalMap3 = new Map<String, Object>();
			//fieldsInternalMap3.put('title', 'Component:');
			//fieldsInternalMap3.put('value', aCase.Component__c );
			//fieldsInternalMap3.put('short', false);
			//fieldsInternalListSME.add(fieldsInternalMap3);
			//fieldsInternalListAccount.add(fieldsInternalMap3);

			//}

			// slack attachment
			// CAN
			if (nullOrEmpty(condition) == false) {
				Map<String, Object> fieldsInternalMap5 = new Map<String, Object>();
				fieldsInternalMap5.put('title', 'Conditions:');
				fieldsInternalMap5.put('value', condition.stripHtmlTags());
				fieldsInternalMap5.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap5);
				fieldsInternalListAccount.add(fieldsInternalMap5);

				Map<String, Object> fieldsInternalMap6 = new Map<String, Object>();
				fieldsInternalMap6.put('title', 'Actions:');
				fieldsInternalMap6.put('value', action.stripHtmlTags());
				fieldsInternalMap6.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap6);
				fieldsInternalListAccount.add(fieldsInternalMap6);

				Map<String, Object> fieldsInternalMap7 = new Map<String, Object>();
				fieldsInternalMap7.put('title', 'Needs:');
				fieldsInternalMap7.put('value', need.stripHtmlTags());
				fieldsInternalMap7.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap7);
				fieldsInternalListAccount.add(fieldsInternalMap7);
			}

			// slack attachment
			// DOAP
			if (nullOrEmpty(subjective) == false) {
				Map<String, Object> fieldsInternalMap8 = new Map<String, Object>();
				fieldsInternalMap8.put('title', 'Description:');
				fieldsInternalMap8.put('value', subjective);
				fieldsInternalMap8.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap8);
				fieldsInternalListAccount.add(fieldsInternalMap8);

				Map<String, Object> fieldsInternalMap9 = new Map<String, Object>();
				fieldsInternalMap9.put('title', 'Objective:');
				fieldsInternalMap9.put('value', objective);
				fieldsInternalMap9.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap9);
				fieldsInternalListAccount.add(fieldsInternalMap9);

				Map<String, Object> fieldsInternalMap10 = new Map<String, Object>();
				fieldsInternalMap10.put('title', 'Assessment:');
				fieldsInternalMap10.put('value', assessment);
				fieldsInternalMap10.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap10);
				fieldsInternalListAccount.add(fieldsInternalMap10);

				Map<String, Object> fieldsInternalMap11 = new Map<String, Object>();
				fieldsInternalMap11.put('title', 'Plan:');
				fieldsInternalMap11.put('value', plan);
				fieldsInternalMap11.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap11);
				fieldsInternalListAccount.add(fieldsInternalMap11);
			}

			//}

			// mark down
			List<String> mrkdwnList = new List<String>();
			mrkdwnList.add('text');
			mrkdwnList.add('pretext');

			// Account
			// ====================
			// Internal Map
			Map<String, Object> attInternalMapAccount = new Map<String, Object>();
			attInternalMapAccount.put('mrkdwn_in', mrkdwnList);
			attInternalMapAccount.put('fallback', fallbackPretext);
			attInternalMapAccount.put('pretext', fallbackPretext);
			attInternalMapAccount.put('color', '#D00000');
			attInternalMapAccount.put('fields', fieldsInternalListAccount);
			// Internal List
			List<Map<String, Object>> attInternalListAccount = new List<Map<String, Object>>();
			attInternalListAccount.add(attInternalMapAccount);
			// Setup Json for Slack post to account channel
			JSONGenerator genAccount = JSON.createGenerator(true);
			genAccount.writeStartObject();
			genAccount.writeStringField('channel', accountChannel);
			genAccount.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			genAccount.writeStringField('link_names', 'true');
			genAccount.writeFieldName('attachments');
			genAccount.writeObject(attInternalListAccount);
			genAccount.writeEndObject();
			String bodyAccount = genAccount.getAsString();
			// Post to account slack
			System.debug(bodyAccount);
			if (!aCase.Subject.contains('ROSCOTESTCASE')) {
				// only slack on CAN reports for now
				if (nullOrEmpty(condition) == false) {
					System.enqueueJob(new qCallOut(webhookURL, 'POST', bodyAccount));
				}
			}

			// SME
			// ====================
			// Internal Map
			Map<String, Object> attInternalMapSME = new Map<String, Object>();
			attInternalMapSME.put('mrkdwn_in', mrkdwnList);
			attInternalMapSME.put('fallback', fallbackPretext);
			attInternalMapSME.put('pretext', fallbackPretext);
			attInternalMapSME.put('color', '#D00000');
			attInternalMapSME.put('fields', fieldsInternalListSME);
			// Internal List
			List<Map<String, Object>> attInternalListSME = new List<Map<String, Object>>();
			attInternalListSME.add(attInternalMapSME);
			// Setup Json for Slack post to SME channel
			JSONGenerator genSME = JSON.createGenerator(true);
			genSME.writeStartObject();
			genSME.writeStringField('channel', smeChannel);
			genSME.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			genSME.writeFieldName('attachments');
			genSME.writeObject(attInternalListSME);
			genSME.writeEndObject();
			String bodySME = genSME.getAsString();
			// Post to SME slack
			System.debug(bodySME);
			if (!aCase.Subject.contains('ROSCOTESTCASE')) {
				// only slack on CAN reports for now
				if (nullOrEmpty(condition) == false) {
					System.enqueueJob(new qCallOut(webhookURL, 'POST', bodySME));
				}
			}
		} catch (Exception e) {
			System.debug('sendToSlack: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
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