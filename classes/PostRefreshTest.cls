/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Test class for PostRefresh
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-12775   2026-03-24    Add best practice updates
 */
@IsTest
public class PostRefreshTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Apttus__ComplySystemProperties__c complySystemProperties = new Apttus__ComplySystemProperties__c();
			complySystemProperties.Name = 'System Properties';
			insert complySystemProperties;

			Apttus_Approval__ApprovalsSystemProperties__c approvalsSystemProperties = new Apttus_Approval__ApprovalsSystemProperties__c();
			approvalsSystemProperties.Name = 'System Properties';
			insert approvalsSystemProperties;

			Case_Management__c caseManagement = new Case_Management__c();
			insert caseManagement;

			TAM_Team__c tamTeamL2 = TestFactory.buildTAMTeam(
				'Test TAM Team L2',
				'test-slack-channel-id'
			);
			tamTeamL2.L2_Slack_Channel_Ids__c = 'test-slack-channel-id';
			TAM_Team__c tamTeamL3 = TestFactory.buildTAMTeam(
				'Test TAM Team L3',
				'test-slack-channel-id-2'
			);
			tamTeamL3.L3_Slack_Channel_Ids__c = 'test-slack-channel-id-2';
			insert new List<TAM_Team__c>{ tamTeamL2, tamTeamL3 };
		}
	}

	@IsTest
	static void testRunApexClass_WhenSandboxRefreshed_AlwaysRunApex() {
		Test.startTest();
		PostRefresh apexClass = new PostRefresh();
		Test.testSandboxPostCopyScript(
			apexClass,
			UserInfo.getOrganizationId(),
			UserInfo.getOrganizationId(),
			'sandboxName'
		);
		Test.stopTest();

		Assert.isTrue(apexClass.isRunSuccessful, 'PostRefresh should have run successfully');
		Apttus__ComplySystemProperties__c complySystemProperties = Apttus__ComplySystemProperties__c.getInstance(
			'System Properties'
		);
		Assert.areEqual(
			URL.getOrgDomainURL().toExternalForm(),
			complySystemProperties.Apttus__InstanceUrl__c,
			'Comply System Properties should have been updated'
		);

		Apttus_Approval__ApprovalsSystemProperties__c approvalsSystemProperties = Apttus_Approval__ApprovalsSystemProperties__c.getInstance(
			'System Properties'
		);
		Assert.areEqual(
			URL.getOrgDomainURL().toExternalForm(),
			approvalsSystemProperties.Apttus_Approval__InstanceUrl__c,
			'Approvals System Properties should have been updated'
		);

		Case_Management__c caseManagement = Case_Management__c.getOrgDefaults();
		Assert.areEqual(
			PostRefresh.nonProdSlackChannelId,
			caseManagement.rosco_slack_triage_channel_poland__c,
			'Case Management slack channel ids should have been updated'
		);

		TAM_Team__c tamTeamL2 = [
			SELECT Id, L2_Slack_Channel_Ids__c
			FROM TAM_Team__c
			WHERE L2_Slack_Channel_Ids__c != NULL
		];
		Assert.areEqual(
			PostRefresh.nonProdSlackChannelId,
			tamTeamL2.L2_Slack_Channel_Ids__c,
			'TAM Team slack channel ids should have been updated'
		);

		TAM_Team__c tamTeamL3 = [
			SELECT Id, L3_Slack_Channel_Ids__c
			FROM TAM_Team__c
			WHERE L3_Slack_Channel_Ids__c != NULL
		];
		Assert.areEqual(
			PostRefresh.nonProdSlackChannelId,
			tamTeamL3.L3_Slack_Channel_Ids__c,
			'TAM Team slack channel ids should have been updated'
		);
	}
}