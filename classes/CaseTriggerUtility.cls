/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Trigger Utility for the CaseTrigger class
 * @Date: 2024-02-16
 * @Author: Tanium Dev Team
 * Modified     ModifiedDate     Description
 * SS-7278      2024-02-16       Created the CaseTriggerUtility class
 * SS-7697      2024-04-16       Added method getPolandSupportComponents
 * SS-7740      2024-04-23       Added method sevIncreaseSlackNotification
 * SS-8182      2024-05-13       Updated hard coded reference to slack channel to instead use SlackUtility constants
 * SS-11173     2025-07-10       Changed field from Severity__c to Severity_Community__c
 * SS-13467     2026-06-25       Added null check to sevIncreaseSlackNotification
 */
public with sharing class CaseTriggerUtility {
	@TestVisible
	private static final String PUBLIC_SECTOR = 'Pubsec';
	@TestVisible
	private static final String PUBLIC_SECTOR_HYBRID = 'Hybrid - Pubsec';
	@TestVisible
	private static final String PUBLIC_SECTOR_SUPPORT_CENTER = 'Support Center - Pubsec';

	public static void setCaseTeamField(List<Case> cases) {
		Set<String> publicSectorSupportModels = new Set<String>{
			PUBLIC_SECTOR_HYBRID,
			PUBLIC_SECTOR_SUPPORT_CENTER
		};

		for (Case caseRecord : cases) {
			if (
				publicSectorSupportModels.contains(caseRecord.Support_Model__c) &&
				caseRecord.Team__c != PUBLIC_SECTOR
			) {
				caseRecord.Team__c = PUBLIC_SECTOR;
			}
		}
	}

	public static Set<String> getPolandSupportComponents() {
		Set<String> polandSupportComponents = new Set<String>();
		Case_Component_Setting__mdt[] caseComponentSettings = Case_Component_Setting__mdt.getAll()
			.values();

		for (Case_Component_Setting__mdt caseComponentSetting : caseComponentSettings) {
			if (caseComponentSetting.IsActive__c && caseComponentSetting.Route_To_Poland__c) {
				polandSupportComponents.add(caseComponentSetting.API_Name__c);
			}
		}
		return polandSupportComponents;
	}

	public static void sevIncreaseSlackNotification(List<Case> cases, Map<Id, Case> oldMap) {
		List<Case> eligibleCases = new List<Case>();
		String slackChannel;

		Integer caseRecSev;
		Integer oldRecCaseRecSev;
		for (Case caseRecord : cases) {
			if (caseRecord.Severity_Community__c != null) {
				caseRecSev = Integer.valueOf(caseRecord.Severity_Community__c);
				oldRecCaseRecSev = Integer.valueOf(oldMap?.get(caseRecord.Id)?.Severity_Community__c);
				if (caseRecSev <= 2 && caseRecSev < oldRecCaseRecSev) {
					eligibleCases.add(caseRecord);
				}
			}
		}

		if (!eligibleCases.isEmpty()) {
			slackChannel = (!Utility.isSandbox())
				? SlackUtility.CHANNEL_SUPPORT_CENTER_TICKETS
				: SlackUtility.CHANNEL_ROSCO_DEBUG;
			CaseSendToEscalationSlack.sendToEscalationSlack(cases, slackChannel);
		}
	}
}