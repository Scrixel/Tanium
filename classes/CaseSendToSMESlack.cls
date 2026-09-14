public with sharing class CaseSendToSMESlack {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@InvocableMethod(label='Send Case to SME Slack')
	public static void sendToSMESlack(List<Case> cases) {
		System.debug('sendToSMESlack:entering');

		try {
			Case aCase = cases[0];

			// Custom settings may override some options!
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

			// Exception channel defaults to #tool_soa but account should override
			String accountChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String ac = String.valueOf(cm.get('rosco_slack_exceptions__c'));

				if (nullOrEmpty(ac) == false) {
					accountChannel = ac;
				}
			}

			/* Get SME Channel
            System.debug('sendToSMESlack:checking for sme mapping');
            String smeChannel;
            List<TAM_Team__c> teams = [select Id, Name, Slack_Ticket_Channel_ID__c, SME_Component_Name__c, SME_Component_Picklist_Value__c from TAM_Team__c where SME_Component_Picklist_Value__c=:aCase.Component__c];
            if (teams.size() == 0){
                return;
            } else {

                if( nullOrEmpty( teams[0].Slack_Ticket_Channel_ID__c) == False ){
                    smeChannel = teams[0].Slack_Ticket_Channel_ID__c;

                } else {
                    return;
                }
            }
            */
			String smeChannel;
			String soqlT = 'SELECT Slack_Ticket_Channel_ID__c, SME_Component_Picklist_Value__c FROM TAM_Team__c WHERE SME_Component_Picklist_Value__c != null ';
			System.debug('soqlT:' + soqlT);
			System.debug('aCase.Component__c:' + aCase.Component__c);
			List<TAM_Team__c> aTeams = Database.query(soqlT);

			if (aTeams.size() > 0) {
				for (TAM_Team__c aTeam : aTeams) {
					if (aTeam.SME_Component_Picklist_Value__c.contains(aCase.Component__c)) {
						smeChannel = aTeam.Slack_Ticket_Channel_ID__c;
					}
				}
			}
			if (smeChannel == null) {
				System.debug('smeChannel is null, exiting');
				return;
			} else {
				System.debug('smeChannel:' + smeChannel);
			}

			// Webhook
			System.debug('sendToSMESlack:checking for webhook url');
			String webhookURL = 'https://hooks.slack.com/services/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';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}

			// Determine contact
			System.debug('sendToSMESlack:determining contact');
			String contact_from;
			if (String.isBlank(aCase.ContactEmail)) {
				contact_from = aCase.SuppliedEmail;
			} else {
				contact_from = aCase.ContactEmail;
			}

			// Determine origin
			System.debug('sendToSMESlack:determining origin');
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

			// Determine Severity
			System.debug('sendToSMESlack:checking severity');
			String sev = String.valueOf(aCase.Severity_Community__c).left(1);

			// Create text for slack post
			System.debug('sendToSMESlack:creating text for slack post');
			String fallbackPretext =
				'New Sev *' +
				sev +
				'* Case *' +
				aCase.CaseNumber +
				'* for *' +
				contact_from +
				'*';

			// add origin info to text if possible
			if (origin.length() != 0) {
				fallbackPretext += ' (' + origin + ')';
			}

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
					SELECT id, name, Slack_Channel_Id__c, Support_Model__c, Premium_Support__c
					FROM account
					WHERE id = :aCase.AccountId
				];

				// slack attachment support model
				if (aCase.Component__c == 'Screenmeet') {
					String supportModel = 'Not Defined';
					if (!nullOrEmpty(anAccount.Support_Model__c)) {
						supportModel = String.valueOf(anAccount.Support_Model__c);
					}
					Map<String, Object> fieldsInternalMapSupportModel = new Map<String, Object>();
					fieldsInternalMapSupportModel.put('title', 'Support Model:');
					fieldsInternalMapSupportModel.put('value', supportModel);
					fieldsInternalMapSupportModel.put('short', false);
					fieldsInternalList.add(fieldsInternalMapSupportModel);
				}

				if (!String.isBlank(anAccount.Slack_Channel_Id__c)) {
					String soql =
						'SELECT Name FROM rosco_account__c ' +
						'WHERE account__c= \'' +
						anAccount.Id +
						'\'';

					System.debug('SOQL: ' + soql);
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

			// Setup Json for Slack post
			JSONGenerator gen = JSON.createGenerator(true);
			gen.writeStartObject();
			gen.writeStringField('channel', smeChannel);
			gen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			gen.writeFieldName('attachments');
			gen.writeObject(attInternalList);
			gen.writeEndObject();
			String body = gen.getAsString();

			// Post to slack
			System.debug(body);
			if (!Test.isRunningTest()) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', body));
			}
		} catch (Exception e) {
			System.debug('sendToSMESlack: ' + e.getMessage() + '\n' + e.getStackTraceString());
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