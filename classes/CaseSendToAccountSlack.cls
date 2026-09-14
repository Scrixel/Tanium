/*
 * @DATE: 2020-05-12
 * @AUTHOR: Shared Services (jason.johnson)
 * @REQUEST:
 * @BUSINESS: CaseSendToAccountSlack - slack messages for cases
 * RequestId  ModifiedDate  Comment
 * SS-7740    2024-04-23    Added new signature to method sendToAccountSlack
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 */

public with sharing class CaseSendToAccountSlack {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@InvocableMethod(label='Send Case to Account Slack')
	public static void sendToAccountSlack(List<Case> cases) {
		sendToAccountSlack(cases, null);
	}
	public static void sendToAccountSlack(List<Case> cases, String channelParam) {
		try {
			Case aCase = cases[0];

			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String caseLink = System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + aCase.ID;
			if (
				cmfields.contains('rosco_case_url_prefix__c') && cmfields.contains('rosco_sfdc_dom_l__c')
			) {
				String urlprefix = String.valueOf(cm.get('rosco_case_url_prefix__c'));
				String urlfriend = String.valueOf(cm.get('rosco_sfdc_dom_l__c'));
				if (!nullOrEmpty(urlprefix) && !nullOrEmpty(urlfriend)) {
					caseLink =
						'<' +
						urlprefix +
						aCase.ID +
						'/view|https://' +
						urlfriend +
						'/lightning/r/Case/' +
						aCase.ID +
						'/view>';
				}
			}
			String accountChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String ac = String.valueOf(cm.get('rosco_slack_exceptions__c'));

				if (nullOrEmpty(ac) == false) {
					accountChannel = ac;
				}
			}
			if (nullOrEmpty(aCase.AccountId) == false) {
				Account anAccount = [
					SELECT id, name, Slack_Channel_Id__c, Premium_Support__c
					FROM account
					WHERE id = :aCase.AccountId
				];
				if (!String.isBlank(anAccount.Slack_Channel_Id__c)) {
					accountChannel = anAccount.Slack_Channel_Id__c;
					if (accountChannel == 'TESTCASE') {
						return;
					}
				}
			}
			String webhookURL = 'https://hooks.slack.com/services/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';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}
			String contact_from;
			if (String.isBlank(aCase.ContactEmail)) {
				contact_from = aCase.SuppliedEmail;
			} else {
				contact_from = aCase.ContactEmail;
			}
			String origin = '';
			if (aCase.Origin == 'Community') {
				origin = 'via community';
			} else {
				if (cmfields.contains('rosco_email_handler_userid__c')) {
					String ehuid = String.valueOf(cm.get('rosco_email_handler_userid__c'));

					if (aCase.CreatedById == ehuid) {
						origin = 'via email';
					} else {
						origin = 'via console';
					}
				}
			}
			String sev = String.valueOf(aCase.Severity_Community__c).left(1);
			String fallbackPretext =
				'New Sev *' +
				sev +
				'* Case *' +
				aCase.CaseNumber +
				'* for *' +
				contact_from +
				'*';
			if (origin.length() != 0) {
				fallbackPretext += ' (' + origin + ')';
			}
			if (sev == '1' || sev == '2') {
				fallbackPretext = ':rosco_alert: ' + fallbackPretext;
			}
			Map<String, Object> fieldsInternalMap = new Map<String, Object>();
			fieldsInternalMap.put('title', '*' + aCase.subject + '*');
			fieldsInternalMap.put('text', '*' + aCase.subject + '*');
			fieldsInternalMap.put('value', caseLink);
			fieldsInternalMap.put('short', false);

			Map<String, Object> fieldsInternalMap2 = new Map<String, Object>();
			String threadId = EmailMessages.getFormattedThreadingToken(aCase.Id);
			fieldsInternalMap2.put('title', 'Thread Id');
			fieldsInternalMap2.put('value', '`' + threadId + '`');
			fieldsInternalMap2.put('short', false);

			String flash;
			Map<String, Object> fieldsInternalMap3 = new Map<String, Object>();
			if (nullOrEmpty(aCase.AccountId) == false) {
				String soql =
					'SELECT account_flash__c FROM Rosco_Account__c ' +
					'WHERE account__c= \'' +
					aCase.AccountId +
					'\'';

				List<Rosco_Account__c> ras = Database.query(soql);
				if (ras.size() != 0) {
					flash = String.valueOf(ras[0].account_flash__c);
					fieldsInternalMap3.put('title', 'Flash:');
					fieldsInternalMap3.put('value', flash);
					fieldsInternalMap3.put('short', false);
				}
			}

			List<Map<String, Object>> fieldsInternalList = new List<Map<String, Object>>();
			fieldsInternalList.add(fieldsInternalMap);
			fieldsInternalList.add(fieldsInternalMap2);
			if (nullOrEmpty(flash) == false) {
				fieldsInternalList.add(fieldsInternalMap3);
			}

			List<String> mrkdwnList = new List<String>();
			mrkdwnList.add('text');
			mrkdwnList.add('pretext');

			Map<String, Object> attInternalMap = new Map<String, Object>();
			attInternalMap.put('mrkdwn_in', mrkdwnList);
			attInternalMap.put('fallback', fallbackPretext);
			attInternalMap.put('pretext', fallbackPretext);
			attInternalMap.put('color', '#D00000');
			attInternalMap.put('fields', fieldsInternalList);

			List<Map<String, Object>> attInternalList = new List<Map<String, Object>>();
			attInternalList.add(attInternalMap);
			accountChannel = (channelParam == null) ? accountChannel : channelParam;

			JSONGenerator gen = JSON.createGenerator(true);
			gen.writeStartObject();
			gen.writeStringField('channel', accountChannel);
			gen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			gen.writeFieldName('attachments');
			gen.writeObject(attInternalList);
			gen.writeEndObject();
			String body = gen.getAsString();

			if (!Test.isRunningTest()) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', body));
			}
		} catch (Exception e) {
			Logger.error('CaseSendToAccountSlack.sendToAccountSlack ERRORS', e);
			Logger.saveLog();
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