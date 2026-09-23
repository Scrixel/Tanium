/*
 * Copyright (c) 2025 Tanium
 *
 * @DATE: 2025-12-09
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Utility class for sending Case notifications to Slack.
 * RequestId  ModifiedDate  Description
 * SS-12185   2025-12-09    Initial development
 */
public class CaseSendToSlackUtility {
	public static String buildBaseUrl(Id caseId, Case_Management__c cm, Set<String> cmfields) {
		return URL.getOrgDomainUrl().toExternalForm() + '/' + caseId;
	}

	public static String buildWebhookURL(Case_Management__c cm, Set<String> cmfields) {
		String webhookURL = System.Label.SlackWebhook;
		if (cmfields.contains('rosco_slack_incoming_hook__c')) {
			String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

			if (nullOrEmpty(hook) == false) {
				webhookURL = hook;
			}
		}
		return webhookURL;
	}

	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}
}