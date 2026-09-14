/**
 * @Business: Test Class for QuoteApprovalEmailTemplateController
 * @Date: 07/16/2025
 * @Authors: Tanium Dev Team
 * @Request: SS-11017
 * RequestId    ModifiedDate    Description
 * SS-11017     2025-07-16      Created the class
 */
@IsTest
private class QuoteApprovalEmailTemplateControllerTest {
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler',
				'UserTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			User approver = TestUserFactory.createAdvancedApprovalsUser();

			Account acc = TestFactory.buildAccount('Test Account');
			insert acc;

			Opportunity opp = TestFactory.buildOpportunity(
				'Test Opportunity',
				Date.today().addDays(10),
				Utility.PROSPECTING,
				acc.Id
			);
			insert opp;

			SBQQ__Quote__c quote = TestFactory.buildSBQQ_Quote(
				opp.Id,
				acc.Id,
				'Draft',
				'Quote',
				Date.today().addDays(10),
				Date.today().addDays(30),
				null
			);
			insert quote;

			List<sbaa__Approver__c> approvers = new List<sbaa__Approver__c>();
			approvers.add(new sbaa__Approver__c(sbaa__User__c = approver.Id, Name = approver.Name));
			approvers.add(
				new sbaa__Approver__c(
					sbaa__User__c = UserInfo.getUserId(),
					Name = TestUserFactory.TANIUM_ADMIN_USER
				)
			);
			insert approvers;

			List<sbaa__Approval__c> approvals = new List<sbaa__Approval__c>();
			approvals.add(
				new sbaa__Approval__c(
					sbaa__ApprovalStep__c = 1.00,
					sbaa__Approver__c = approvers[0].Id,
					Quote__c = quote.Id,
					sbaa__RecordField__c = 'Quote__c'
				)
			);
			approvals.add(
				new sbaa__Approval__c(
					sbaa__ApprovalStep__c = 2.00,
					sbaa__Approver__c = approvers[0].Id,
					Quote__c = quote.Id,
					sbaa__RecordField__c = 'Quote__c'
				)
			);
			approvals.add(
				new sbaa__Approval__c(
					sbaa__ApprovalStep__c = 3.00,
					sbaa__Approver__c = approvers[1].Id,
					Quote__c = quote.Id,
					sbaa__RecordField__c = 'Quote__c'
				)
			);
			insert approvals;

			Document doc = new Document(
				Name = 'Green Flag',
				DeveloperName = 'Green_Flag',
				Body = Blob.valueOf('Green Flag'),
				ContentType = 'image/png',
				FolderId = UserInfo.getUserId(),
				IsPublic = true
			);
			insert doc;
		}
	}

	@IsTest
	static void getFinalApproverName_WhenQuoteApprovalsExists_AlwaysReturnFinalApproverName() {
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
		sbaa__Approval__c approval = [
			SELECT Id
			FROM sbaa__Approval__c
			WHERE sbaa__ApprovalStep__c = 1.00
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteApprovalEmailTemplateController controller = new QuoteApprovalEmailTemplateController();
			controller.quoteId = quote.Id;
			controller.approverId = approval.Id;
			String finalApprover = controller.getFinalApproverName();
			Test.stopTest();

			Assert.areEqual(
				TestUserFactory.TANIUM_ADMIN_USER,
				finalApprover,
				'Tanium Admin User should be the final approver'
			);
		}
	}

	@IsTest
	static void getFinalApproverName_WhenExceptionOccured_LogNebulaAndReturnBlank() {
		sbaa__Approval__c approval = [
			SELECT Id
			FROM sbaa__Approval__c
			WHERE sbaa__ApprovalStep__c = 1.00
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteApprovalEmailTemplateController controller = new QuoteApprovalEmailTemplateController();
			controller.quoteId = 'a59RO00000Piii5YAB';
			controller.approverId = approval.Id;
			String finalApprover = controller.getFinalApproverName();
			Test.stopTest();

			List<LogEntry__c> logs = [SELECT Id FROM LogEntry__c];
			Assert.isTrue(String.isBlank(finalApprover), 'finalApprover should be blank.');
			Assert.isFalse(logs.isEmpty(), 'Log record should be created.');
		}
	}

	@IsTest
	static void getFinalApproverName_WhenQuoteIdIsNull_ReturnBlank() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteApprovalEmailTemplateController controller = new QuoteApprovalEmailTemplateController();
			controller.quoteId = null;
			String finalApprover = controller.getFinalApproverName();
			Test.stopTest();

			Assert.isTrue(String.isBlank(finalApprover), 'finalApprover should be blank.');
		}
	}

	@IsTest
	static void getApprovals_AlwaysReturnApprovalsRelatedToQuoteAndToUser() {
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
		sbaa__Approval__c approval = [
			SELECT Id, sbaa__Approver__c
			FROM sbaa__Approval__c
			WHERE sbaa__ApprovalStep__c = 1.00
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteApprovalEmailTemplateController controller = new QuoteApprovalEmailTemplateController();
			controller.quoteId = quote.Id;
			controller.approverId = approval.sbaa__Approver__c;
			List<sbaa__Approval__c> approvals = controller.getApprovals();
			Test.stopTest();

			Assert.areEqual(2, approvals.size(), 'Two approval records should be returned.');
		}
	}

	@IsTest
	static void getApprovals_WhenApproverIdIsNull_ReturnEmptyList() {
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteApprovalEmailTemplateController controller = new QuoteApprovalEmailTemplateController();
			controller.quoteId = quote.Id;
			controller.approverId = null;
			List<sbaa__Approval__c> approvals = controller.getApprovals();
			Test.stopTest();

			Assert.areEqual(0, approvals.size(), 'Return should be empty list.');
		}
	}

	@IsTest
	static void getFlagUrl_AlwaysReturnDocumentUrl() {
		SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
		Document doc = [SELECT Id, DeveloperName FROM Document LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			QuoteApprovalEmailTemplateController controller = new QuoteApprovalEmailTemplateController();
			controller.quoteId = quote.Id;
			controller.color = 'Green';
			String flagUrl = controller.getFlagUrl();
			Test.stopTest();

			Assert.isTrue(flagUrl.contains(doc.Id), 'Return should contain the document id.');
		}
	}
}