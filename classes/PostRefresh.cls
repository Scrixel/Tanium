/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Post refresh class to run automations as part of the post refresh process
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12775   2026-03-24    Add new automations as part of post refresh process
 */
global class PostRefresh implements SandboxPostCopy {
	@TestVisible
	private Boolean isRunSuccessful = false;
	private static String sandboxName;
	private static String instanceUrl;
	@TestVisible
	private static String nonProdSlackChannelId = System.Label.PostRefresh_NonProdSlackChannelId;

	global void runApexClass(SandboxContext context) {
		sandboxName = context.sandboxName();
		instanceUrl = URL.getOrgDomainURL().toExternalForm();

		try {
			updateComplySystemPropertiesCustomSettings();
			updateApprovalsSystemPropertiesCustomSettings();
			updateCaseManagementCustomSettings();
			updateTAMTeamRecords();
			runDataResetBatchClasses();
			isRunSuccessful = true;
		} catch (Exception e) {
			isRunSuccessful = false;
			Logger.error('PostRefresh Error: ' + e.getMessage()).addTag('apex').addTag('postrefresh');
			Logger.saveLog();
		}
	}

	private void updateComplySystemPropertiesCustomSettings() {
		Apttus__ComplySystemProperties__c complySystemProperties = Apttus__ComplySystemProperties__c.getInstance(
			'System Properties'
		);
		complySystemProperties.Apttus__InstanceUrl__c = instanceUrl;

		Database.SaveResult result = Database.update(complySystemProperties);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'Comply System Properties Custom Settings Update Errors',
				new List<Database.SaveResult>{ result }
			)
			.addTag('apex')
			.addTag('postrefresh');
		Logger.saveLog();
	}

	private void updateApprovalsSystemPropertiesCustomSettings() {
		Apttus_Approval__ApprovalsSystemProperties__c approvalsSystemProperties = Apttus_Approval__ApprovalsSystemProperties__c.getInstance(
			'System Properties'
		);
		approvalsSystemProperties.Apttus_Approval__InstanceUrl__c = instanceUrl;

		Database.SaveResult result = Database.update(approvalsSystemProperties);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'Approvals System Properties Custom Settings Update Errors',
				new List<Database.SaveResult>{ result }
			)
			.addTag('apex')
			.addTag('postrefresh');
		Logger.saveLog();
	}

	private void updateCaseManagementCustomSettings() {
		Case_Management__c caseManagementOrgDefault = Case_Management__c.getOrgDefaults();
		caseManagementOrgDefault.rosco_case_url_prefix__c =
			'https://' +
			sandboxName +
			'.sandbox.lightning.force.com/lightning/r/Case/';
		caseManagementOrgDefault.rosco_sfdc_dom_c__c = sandboxName + '.my.salesforce.com';
		caseManagementOrgDefault.rosco_sfdc_dom_l__c = sandboxName + '.lightning.force.com';
		caseManagementOrgDefault.rosco_slack_dump_channel__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_escalation_channel__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_exceptions__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_triage_channel__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_can__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_chat__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_fedtriage__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_caseupdate__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_community__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_hfpoc__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_techpartner_channel__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_triage_channel_supportcenter__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_triage_channel_sc_japan__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_support_center_csat_slackId__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_implement_survey_slackId__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_onboard_survey_slackId__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_SC_CSAT_slackId__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_ftam_slackId__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_cmty_esc_channel__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_ES_CSAT_slackid__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_community_0F90e000000HAUrCAO__c = nonProdSlackChannelId;
		caseManagementOrgDefault.rosco_slack_triage_channel_poland__c = nonProdSlackChannelId;

		Database.SaveResult result = Database.update(caseManagementOrgDefault);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'Case Management Custom Settings Update Errors',
				new List<Database.SaveResult>{ result }
			)
			.addTag('apex')
			.addTag('postrefresh');
		Logger.saveLog();
	}

	private void updateTAMTeamRecords() {
		List<TAM_Team__c> tamTeamsToUpdate = new List<TAM_Team__c>();

		for (TAM_Team__c team : [
			SELECT
				Id,
				L2_Slack_Channel_Ids__c,
				L3_Slack_Channel_Ids__c,
				L4_Slack_Channel_Ids__c,
				L5_Slack_Channel_Ids__c
			FROM TAM_Team__c
			WHERE
				L2_Slack_Channel_Ids__c != NULL
				OR L3_Slack_Channel_Ids__c != NULL
				OR L4_Slack_Channel_Ids__c != NULL
				OR L5_Slack_Channel_Ids__c != NULL
		]) {
			if (team.L2_Slack_Channel_Ids__c != null) {
				team.L2_Slack_Channel_Ids__c = nonProdSlackChannelId;
			}

			if (team.L3_Slack_Channel_Ids__c != null) {
				team.L3_Slack_Channel_Ids__c = nonProdSlackChannelId;
			}

			if (team.L4_Slack_Channel_Ids__c != null) {
				team.L4_Slack_Channel_Ids__c = nonProdSlackChannelId;
			}

			if (team.L5_Slack_Channel_Ids__c != null) {
				team.L5_Slack_Channel_Ids__c = nonProdSlackChannelId;
			}

			tamTeamsToUpdate.add(team);
		}

		List<Database.SaveResult> results = Database.update(tamTeamsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'TAM Team Records Update Errors', results)
			.addTag('apex')
			.addTag('postrefresh');
		Logger.saveLog();
	}

	private void runDataResetBatchClasses() {
		Database.executeBatch(new PostRefreshAccountResetBatch());
		Database.executeBatch(new BatchPostRefreshContactReset());
	}
}