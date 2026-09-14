/*
 * @DATE: 2020-05-12
 * @AUTHOR: Shared Services (jason.johnson)
 * @REQUEST:
 * @BUSINESS: CaseSendToEscalationSlack - slack messges for escalated cases
 * RequestId  ModifiedDate  Comment
 * SS-7740    2024-04-22    Added new signature to method sendToEscalationSlack
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */
public with sharing class CaseSendToEscalationSlack {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@InvocableMethod(label='Send Case to Escalation Slack')
	public static void sendToEscalationSlack(List<Case> cases) {
		sendToEscalationSlack(cases, null);
	}
	public static void sendToEscalationSlack(List<Case> cases, String channelParam) {
		try {
			Case aCase = cases[0];

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
						'/view|https://' +
						urlfriend +
						'/lightning/r/Case/' +
						aCase.ID +
						'/view>';
					caseLink += ' <https://' + urlfriend + '/lightning/r/Case/' + aCase.ID + '/view|(alt)>';
				}
			}

			// Escalation Channel
			String escChannel = 'C044FEDR0';
			if (cmfields.contains('rosco_slack_escalation_channel__c')) {
				String ac = String.valueOf(cm.get('rosco_slack_escalation_channel__c'));

				if (nullOrEmpty(ac) == false) {
					escChannel = ac;
				}
			}

			// Webhook
			String webhookURL = 'https://hooks.slack.com/services/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';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}

			// Determine contact
			String contact_from;
			if (String.isBlank(aCase.ContactEmail)) {
				contact_from = aCase.SuppliedEmail;
			} else {
				contact_from = aCase.ContactEmail;
			}

			// Determine Severity
			String sev = String.valueOf(aCase.Severity_Community__c).left(1);

			// Create text for slack post
			String fallbackPretext =
				'Escalation requested for Sev *' +
				sev +
				'* Case *' +
				aCase.CaseNumber +
				'* for *' +
				contact_from +
				'*';

			// slack list of attachments
			List<Map<String, Object>> fieldsInternalList = new List<Map<String, Object>>();

			// slack attachment
			Map<String, Object> fieldsInternalMap = new Map<String, Object>();
			fieldsInternalMap.put('title', '*' + aCase.subject + '*');
			fieldsInternalMap.put('text', '*' + aCase.subject + '*');
			fieldsInternalMap.put('value', caseLink);
			fieldsInternalMap.put('short', false);
			fieldsInternalList.add(fieldsInternalMap);

			// slack attachment
			// Get Slack Channel Name for Account if available
			if (nullOrEmpty(aCase.AccountId) == false) {
				Account anAccount = [
					SELECT id, name, Slack_Channel_Id__c, Premium_Support__c
					FROM account
					WHERE id = :aCase.AccountId
				];

				if (!String.isBlank(anAccount.Slack_Channel_Id__c)) {
					String soql =
						'SELECT Name FROM rosco_account__c ' +
						'WHERE account__c= \'' +
						anAccount.Id +
						'\'';

					List<Rosco_Account__c> slacknames = Database.query(soql);

					if (slacknames.size() != 0) {
						String slackname;
						slackname = String.valueOf(slacknames[0].Name);

						if (nullOrEmpty(slackname) == false) {
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
							fieldsInternalList.add(fieldsInternalMap2);
						}
					}
				}
			}

			// slack attachment
			// Get Component
			//if( nullOrEmpty( aCase.Component__c ) == False ){

			Map<String, Object> fieldsInternalMap3 = new Map<String, Object>();
			fieldsInternalMap3.put('title', 'Component:');
			fieldsInternalMap3.put('value', aCase.Component__c);
			fieldsInternalMap3.put('short', false);
			fieldsInternalList.add(fieldsInternalMap3);

			//}

			// slack attachment
			// Get Escalation Type
			//if( nullOrEmpty( aCase.Escalation_Type__c ) == False ){

			Map<String, Object> fieldsInternalMap4 = new Map<String, Object>();
			fieldsInternalMap4.put('title', 'Escalation Type:');
			fieldsInternalMap4.put('value', aCase.Escalation_Type__c);
			fieldsInternalMap4.put('short', false);
			fieldsInternalList.add(fieldsInternalMap4);

			//}

			// slack attachment
			// Get Escalation Reason
			if (nullOrEmpty(aCase.Escalation_Reason__c) == false) {
				Map<String, Object> fieldsInternalMap5 = new Map<String, Object>();
				fieldsInternalMap5.put('title', 'Escalation Reason:');
				fieldsInternalMap5.put('value', aCase.Escalation_Reason__c);
				fieldsInternalMap5.put('short', false);
				fieldsInternalList.add(fieldsInternalMap5);
			}

			// mark down
			List<String> mrkdwnList = new List<String>();
			mrkdwnList.add('text');
			mrkdwnList.add('pretext');

			// Internal Map
			Map<String, Object> attInternalMap = new Map<String, Object>();
			attInternalMap.put('mrkdwn_in', mrkdwnList);
			attInternalMap.put('fallback', fallbackPretext);
			attInternalMap.put('pretext', fallbackPretext);
			attInternalMap.put('color', '#D00000');
			attInternalMap.put('fields', fieldsInternalList);

			// Internal List
			List<Map<String, Object>> attInternalList = new List<Map<String, Object>>();
			attInternalList.add(attInternalMap);

			escChannel = (channelParam == null) ? escChannel : channelParam;

			// Setup Json for Slack post
			JSONGenerator gen = JSON.createGenerator(true);
			gen.writeStartObject();
			gen.writeStringField('channel', escChannel);
			gen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			gen.writeFieldName('attachments');
			gen.writeObject(attInternalList);
			gen.writeEndObject();
			String body = gen.getAsString();

			// Post to slack
			System.enqueueJob(new qCallOut(webhookURL, 'POST', body));
		} catch (Exception e) {
			System.debug('sendToEscalationSlack: ' + e.getMessage() + '\n' + e.getStackTraceString());
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