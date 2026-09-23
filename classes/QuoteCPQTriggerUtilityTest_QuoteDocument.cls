/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: Test class for QuoteCPQTriggerUtility
 * @Author: Cumulus Vision
 * RequestId  ModifiedDate  Description
 * SS-13648   2026-08-04    Updated makeData method
 */
@IsTest
private class QuoteCPQTriggerUtilityTest_QuoteDocument {
	static final String APPROVED_QUOTE_STATUS = QuoteCPQTriggerUtility.APPROVED_QUOTE_STATUS;
	private static User adminUser;
	private static User dealDeskUser;
	@TestSetup
	static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'OpportunityLineItemTriggerHandler',
				'QuoteCPQTriggerHandler',
				'QuoteLineTriggerHandler',
				'BillingScheduleTriggerHandler'
			}
		);
		System.runAs(getAdminUser()) {
			Pricebook2 globalPriceBook = new Pricebook2(
				Name = 'Global Pricebook',
				Description = 'Global Pricebook description.',
				IsActive = true
			);
			String fieldApiName = 'Ruby__PriceAttributes__c';
			Map<String, Schema.SObjectField> pricebookFields = Schema.SObjectType.Pricebook2.fields.getMap();
			if (pricebookFields.containsKey(fieldApiName)) {
				globalPriceBook.put(fieldApiName, 'Currency;UOM');
			}
			insert globalPriceBook;
			Account acct1 = TestFactory.buildAccount('Test Account 1');
			acct1.Total_Addressable_Seats__c = 26000;
			acct1.Seats_Purchased1__c = 26000;
			acct1.Total_Addressable_Seats__c = 5000;
			insert new List<Account>{ acct1 };

			Opportunity oppty = TestFactory.buildOpportunity(
				'Test Opportunity 1',
				Date.today() + 30,
				'Prospecting',
				acct1.Id
			);
			oppty.CloseDate = Date.today() + 60;
			oppty.Type = 'New Customer';
			insert new List<Opportunity>{ oppty };

			SBQQ__Quote__c testQuote1 = new SBQQ__Quote__c(
				SBQQ__Account__c = acct1.Id,
				SBQQ__EndDate__c = Date.today().addDays(30),
				SBQQ__Opportunity2__c = oppty.Id,
				SBQQ__PaymentTerms__c = 'Net 30',
				SBQQ__PriceBook__c = Test.getStandardPricebookId(),
				SBQQ__Primary__c = true,
				SBQQ__StartDate__c = Date.today(),
				SBQQ__Status__c = 'Accepted',
				SBQQ__SubscriptionTerm__c = 30,
				SBQQ__Type__c = 'Quote'
			);
			insert new List<SBQQ__Quote__c>{ testQuote1 };
		}
	}

	@isTest
	static void testQuoteDocumentAutoGeneration_whenApprovalStatusIsChangedToApproved_QuoteDocumentCreatedSuccessfully() {
		SBQQ__Quote__c testQuote1 = [SELECT Id, ApprovalStatus__c FROM SBQQ__Quote__c LIMIT 1];
		System.runAs(getAdminUser()) {
			Test.startTest();
			try {
				System.assertEquals(QuoteCPQTriggerUtility.flagToCreateQuoteDocument, false);
				testQuote1.ApprovalStatus__c = APPROVED_QUOTE_STATUS;
				update testQuote1;
				System.assertEquals(QuoteCPQTriggerUtility.flagToCreateQuoteDocument, true);
			} catch (Exception e) {
				System.assertEquals('', e.getMessage(), 'quote exception');
			}
			Test.stopTest();
		}
	}

	@isTest
	static void testOpportunityAttachmentAutoGeneration_whenOppStageIsChangedToClosedWon_AttachmentCreatedSuccessfullyFromQuoteDocument() {
		Opportunity oppty = [SELECT Id, StageName FROM Opportunity LIMIT 1];
		SBQQ__Quote__c quote = [
			SELECT Id
			FROM SBQQ__Quote__c
			WHERE SBQQ__Opportunity2__c = :oppty.Id
		];
		Attachment quoteAttachment1 = new Attachment(
			Body = Blob.valueOf('test body 1'),
			Name = 'name test 1',
			Description = 'description test 1',
			ParentId = quote.Id
		);

		Attachment quoteAttachment2 = new Attachment(
			Body = Blob.valueOf('test body 2'),
			Name = 'name test 2',
			Description = 'description test 2',
			ParentId = quote.Id
		);
		insert new List<Attachment>{ quoteAttachment1, quoteAttachment2 };
		SBQQ__QuoteDocument__c quoteDocument1 = new SBQQ__QuoteDocument__c(
			SBQQ__AttachmentId__c = quoteAttachment1.Id,
			Name = quoteAttachment1.Name,
			SBQQ__Opportunity__c = oppty.Id,
			SBQQ__Quote__c = quote.Id
		);
		insert quoteDocument1;
		SBQQ__QuoteDocument__c quoteDocument2 = new SBQQ__QuoteDocument__c(
			SBQQ__AttachmentId__c = quoteAttachment2.Id,
			Name = quoteAttachment2.Name,
			SBQQ__Opportunity__c = oppty.Id,
			SBQQ__Quote__c = quote.Id
		);
		insert quoteDocument2;
		System.runAs(getAdminUser()) {
			Test.startTest();
			try {
				System.assertEquals(QuoteCPQTriggerUtility.flagToCreateAttachmentOnOpportunity, false);
				oppty.StageName = Utility.CLOSED_WON;
				update oppty;
				System.assertEquals(QuoteCPQTriggerUtility.flagToCreateAttachmentOnOpportunity, true);
			} catch (Exception e) {
				System.assertEquals('', e.getMessage(), 'opp exception');
			}
			Test.stopTest();
			List<Attachment> oppAttachments = [
				SELECT Id, Name, Description
				FROM Attachment
				WHERE ParentId = :oppty.Id
			];
			List<SBQQ__QuoteDocument__c> quoteDocuments = [
				SELECT SBQQ__AttachmentId__c, Name
				FROM SBQQ__QuoteDocument__c
				WHERE Is_Primary_Quote__c = TRUE AND SBQQ__Opportunity__c = :oppty.Id
				ORDER BY LastModifiedDate DESC
			];
			System.assertEquals(1, oppAttachments.size());
			System.assertEquals(true, oppAttachments[0].Name.contains(quoteDocuments[0].Name));
		}
	}

	static User getAdminUser() {
		if (adminUser == null) {
			List<User> testUsers = [SELECT Id FROM User WHERE LastName LIKE 'TaniumAdminUser%'];
			if (testUsers.isEmpty()) {
				adminUser = TestFactory.getTaniumAdminUser(true);
				// No flows exist for Billing schedule related objects but those on acct and oppty block test class execution
				TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');
				TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
				TestingUtility.assignPermissionSet(adminUser.Id, 'BillingScheduleConfigurator');
			} else {
				adminUser = testUsers[0];
			}
		}
		return adminUser;
	}
}