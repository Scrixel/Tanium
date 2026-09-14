/**
 * Copyright (c) 2025 Tanium
 *
 * @Business: CaseSendToTriageSlack without sharing class - supports community app
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7277    2024-02-23    Jason's last changes linked to ticket SCLOUD-723 plus layout changes by Tanium Dev Team
 * SS-8182    2024-05-13    Updated 2 hard coded references to UAT slack channel to instead use SlackUtility constant
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-12185   2025-12-09    Change slack message routing for bypass model and remove legacy code
 */
public without sharing class CaseSendToTriageSlack {
	@InvocableMethod(label='Send Case to Triage Slack')
	public static void sendToTriageSlack(List<Case> cases) {
		sendToTriageSlack2(cases);
	}

	public static void sendToTriageSlack2(List<Case> cases) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			List<String> channels;

			for (Case caseRec : cases) {
				channels = new List<String>();
				String caseLink = CaseSendToSlackUtility.buildBaseUrl(caseRec.Id, cm, cmfields);

				Account acc;
				if (!CaseSendToSlackUtility.nullOrEmpty(caseRec.AccountId)) {
					acc = [
						SELECT Id, Name, Slack_Channel_Id__c, Premium_Support__c, Support_Model__c
						FROM Account
						WHERE Id = :caseRec.AccountId
					];
				}

				String routingIds = 'None';
				if (cmfields.contains('rosco_case_country_routing_accountids__c')) {
					routingIds = String.valueOf(cm.get('rosco_case_country_routing_accountids__c'));
				}
				String country = '';

				Contact c = [
					SELECT MailingCountry, OtherCountry, Support_Option__c
					FROM Contact
					WHERE Id = :caseRec.ContactId
				];
				if (!CaseSendToSlackUtility.nullOrEmpty(c.Support_Option__c)) {
					if (c.Support_Option__c.contains('Support Japanese')) {
						country = 'Japan';
					} else if (c.Support_Option__c.contains('Support English')) {
						country = 'EnglishGlobal';
					}
				}
				if (country == '') {
					if (!CaseSendToSlackUtility.nullOrEmpty(c.MailingCountry)) {
						country = c.MailingCountry;
					}
					if (!CaseSendToSlackUtility.nullOrEmpty(c.OtherCountry)) {
						if (country == '') {
							country = c.OtherCountry;
						} else {
							country += ' | ' + c.OtherCountry;
						}
					}
				}

				Boolean countryRouting = false;
				if (routingIds == 'All') {
					countryRouting = true;
				} else if (routingIds.contains(acc.Id)) {
					countryRouting = true;
				}
				String triageChannel = 'CH87S4VUJ';
				String supportModel = String.valueOf(acc.Support_Model__c);
				if (CaseSendToSlackUtility.nullOrEmpty(supportModel)) {
					supportModel = '';
				}

				if (supportModel == 'Support Center (Poland)') {
					triageChannel = SlackUtility.CHANNEL_SUPPORT_CENTER_TICKETS_POLAND;
					if (cmfields.contains('rosco_slack_triage_channel_poland__c')) {
						String tc = String.valueOf(cm.get('rosco_slack_triage_channel_poland__c'));
						if (!CaseSendToSlackUtility.nullOrEmpty(tc)) {
							triageChannel = tc;
						}
					}
				} else if (
					supportModel == 'Support Center' ||
					supportModel == 'Global Support Bypass' ||
					supportModel == 'Partner Supported (SC)' ||
					supportModel == 'Hybrid' ||
					supportModel == 'Support Center - Pubsec' ||
					supportModel == 'Hybrid - Pubsec' ||
					caseRec.Origin == 'Igloo'
				) {
					triageChannel = 'C01DAP85W3A';
					if (cmfields.contains('rosco_slack_triage_channel_supportcenter__c')) {
						String tc = String.valueOf(cm.get('rosco_slack_triage_channel_supportcenter__c'));
						if (!CaseSendToSlackUtility.nullOrEmpty(tc)) {
							triageChannel = tc;
						}
					}
					if (countryRouting) {
						if (country != '') {
							if (country.containsIgnoreCase('Japan')) {
								String tc = String.valueOf(
									cm.get('rosco_slack_triage_channel_sc_japan__c')
								);
								if (!CaseSendToSlackUtility.nullOrEmpty(tc)) {
									triageChannel = tc;
								}
							}
						}
					}
				} else if (
					supportModel == 'Support Center (Japan Bypass)' ||
					supportModel == 'Hybrid (Japan Bypass)' ||
					supportModel == 'Partner Supported (SC Japan Bypass)'
				) {
					triageChannel = 'C041FV8TT7U';
					if (cmfields.contains('rosco_slack_triage_channel_sc_japan__c')) {
						String tc = String.valueOf(cm.get('rosco_slack_triage_channel_sc_japan__c'));
						if (!CaseSendToSlackUtility.nullOrEmpty(tc)) {
							triageChannel = tc;
						}
					}
					if (countryRouting) {
						if (country != '') {
							if (!country.containsIgnoreCase('Japan')) {
								String tc = String.valueOf(
									cm.get('rosco_slack_triage_channel_supportcenter__c')
								);
								if (!CaseSendToSlackUtility.nullOrEmpty(tc)) {
									triageChannel = tc;
								}
							}
						}
					}
				} else {
					if (cmfields.contains('rosco_slack_triage_channel__c')) {
						String tc = String.valueOf(cm.get('rosco_slack_triage_channel__c'));
						if (!CaseSendToSlackUtility.nullOrEmpty(tc)) {
							triageChannel = tc;
						}
					}
				}
				channels.add(triageChannel);

				String flash;
				String slackName;
				String accountSlackId;
				if (!CaseSendToSlackUtility.nullOrEmpty(acc.Id)) {
					accountSlackId = String.valueOf(acc.Slack_Channel_Id__c);

					List<Rosco_Account__c> roscoAccounts = [
						SELECT
							Id,
							Name,
							Triage_Flash__c,
							Bypass_Triage_Tickets__c,
							Secondary_Slack_Channel_Id__c,
							Tertiary_Slack_Channel_Id__c
						FROM Rosco_Account__c
						WHERE Account__c = :acc.Id
					];

					if (!roscoAccounts.isEmpty()) {
						slackName = String.valueOf(roscoAccounts[0].Name);
						flash = String.valueOf(roscoAccounts[0].triage_flash__c);
						if (
							!CaseSendToSlackUtility.nullOrEmpty(roscoAccounts[0].Bypass_Triage_Tickets__c)
						) {
							channels.clear();
							channels.add(roscoAccounts[0].Bypass_Triage_Tickets__c);
						}
						if (
							!CaseSendToSlackUtility.nullOrEmpty(
								roscoAccounts[0].Secondary_Slack_Channel_Id__c
							)
						) {
							channels.add(roscoAccounts[0].Secondary_Slack_Channel_Id__c);
						}
						if (
							!CaseSendToSlackUtility.nullOrEmpty(
								roscoAccounts[0].Tertiary_Slack_Channel_Id__c
							)
						) {
							channels.add(roscoAccounts[0].Tertiary_Slack_Channel_Id__c);
						}
					}
				}

				String webhookURL = CaseSendToSlackUtility.buildWebhookURL(cm, cmfields);

				String contactEmail;
				if (String.isBlank(caseRec.ContactEmail)) {
					contactEmail = caseRec.SuppliedEmail;
				} else {
					contactEmail = caseRec.ContactEmail;
				}

				String origin = '';
				if (caseRec.Origin == 'Community') {
					origin = 'via community';
				} else {
					if (cmfields.contains('rosco_email_handler_userid__c')) {
						String ehuid = String.valueOf(cm.get('rosco_email_handler_userid__c'));
						if (caseRec.CreatedById == ehuid) {
							origin = 'via email';
						} else {
							origin = 'via console';
						}
					}
				}

				String sev = String.valueOf(caseRec.Severity_Community__c).left(1);
				String fallbackPretext =
					'New Sev *' +
					sev +
					'* Case *' +
					caseRec.CaseNumber +
					'* for *' +
					contactEmail +
					'*';
				if (origin.length() != 0) {
					fallbackPretext += ' (' + origin + ')';
				}
				if (sev == '1' || sev == '2') {
					fallbackPretext = ':rosco_alert: ' + fallbackPretext;
				}
				Map<String, Object> fieldsInternalMap = new Map<String, Object>();
				fieldsInternalMap.put('title', '*' + caseRec.subject + '*');
				fieldsInternalMap.put('text', '*' + caseRec.subject + '*');
				fieldsInternalMap.put('value', caseLink);
				fieldsInternalMap.put('short', false);

				Map<String, Object> fieldsInternalMap2 = new Map<String, Object>();
				String threadId = EmailMessages.getFormattedThreadingToken(caseRec.Id);
				fieldsInternalMap2.put('title', 'Thread Id');
				fieldsInternalMap2.put('value', '`' + threadId + '`');
				fieldsInternalMap2.put('short', false);

				List<Map<String, Object>> fieldsInternalList = new List<Map<String, Object>>();
				fieldsInternalList.add(fieldsInternalMap);
				fieldsInternalList.add(fieldsInternalMap2);

				if (!CaseSendToSlackUtility.nullOrEmpty(accountSlackId)) {
					String sLink =
						'<https://tanium.slack.com/messages/' +
						accountSlackId +
						'| Channel Id: ' +
						accountSlackId +
						'>';
					if (
						!CaseSendToSlackUtility.nullOrEmpty(slackName) &&
						!slackName.containsIgnoreCase('a8q')
					) {
						sLink =
							'<https://tanium.slack.com/messages/' +
							accountSlackId +
							'|#' +
							slackName +
							'>';
					}

					Map<String, Object> fieldsInternalMap3 = new Map<String, Object>();
					fieldsInternalMap3.put('title', 'Customer Channel:');
					fieldsInternalMap3.put('value', sLink);
					fieldsInternalMap3.put('short', false);
					fieldsInternalList.add(fieldsInternalMap3);
				}

				if (!CaseSendToSlackUtility.nullOrEmpty(flash)) {
					Map<String, Object> fieldsInternalMap4 = new Map<String, Object>();
					fieldsInternalMap4.put('title', 'Flash:');
					fieldsInternalMap4.put('value', flash);
					fieldsInternalMap4.put('short', false);
					fieldsInternalList.add(fieldsInternalMap4);
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

				if (caseRec.Origin == 'TechPartner') {
					channels.clear();
					String tpChannel = 'C029H3UGRMW';
					if (cmfields.contains('rosco_slack_techpartner_channel__c')) {
						String tp = String.valueOf(cm.get('rosco_slack_techpartner_channel__c'));
						if (!CaseSendToSlackUtility.nullOrEmpty(tp)) {
							tpChannel = tp;
						}
					}
					channels.add(tpChannel);
				}

				for (String channel : channels) {
					JSONGenerator gen = JSON.createGenerator(true);
					gen.writeStartObject();
					gen.writeStringField('channel', channel);
					gen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
					gen.writeFieldName('attachments');
					gen.writeObject(attInternalList);
					gen.writeEndObject();
					String body = gen.getAsString();
					if (!Test.isRunningTest()) {
						System.enqueueJob(new SlackCallout(webhookURL, 'POST', body));
					}
				}
			}
		} catch (Exception e) {
			Logger.Error('CaseSendToTriageSlack.sendToTriageSlack2 ERRORS', e);
			Logger.saveLog();
		}
	}
}