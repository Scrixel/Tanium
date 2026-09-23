/**
 * @Business: ContentDocumentLink Utility test class
 * @Date: 2025-10-28
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-6810    2024-01-15	Created the test class
 * SS-11875   2025-10-28    Updated the test class
 */
@IsTest
private class ContentDocumentLinkTriggerUtilityTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			List<Opportunity> opps = new List<Opportunity>();
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity 1',
					Date.today() + 1,
					Utility.PROSPECTING,
					account.Id
				)
			);
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opportunity 2',
					Date.today() + 30,
					Utility.PROSPECTING,
					account.Id
				)
			);
			insert opps;

			// some workflow rule or something is updating closedate to way into the future upon insert
			opps[0].CloseDate = Date.today() + 1;
			opps[1].CloseDate = Date.today() + 30;
			update opps;

			Case cs = TestFactory.buildCase(account.Id);
			insert cs;

			Id contentVersionGeneralRecTypeId = Utility.getRecordTypeIdByAPIName(
				'ContentVersion',
				'General'
			);

			ContentDocument contentDocument = createContentDocument(
				UserInfo.getUserId(),
				contentVersionGeneralRecTypeId
			);

			List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = opps[0].Id,
					ShareType = 'V',
					ContentDocumentId = contentDocument.Id
				)
			);
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = opps[1].Id,
					ShareType = 'V',
					ContentDocumentId = contentDocument.Id
				)
			);
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = account.Id,
					ShareType = 'V',
					ContentDocumentId = contentDocument.Id
				)
			);
			contentDocumentLinks.add(
				new ContentDocumentLink(
					LinkedEntityId = cs.Id,
					ShareType = 'V',
					ContentDocumentId = contentDocument.Id
				)
			);
			insert contentDocumentLinks;
		}
	}

	@IsTest
	static void testSetKlarityDateOnOpportunity_WhenCloseDateWithinTwoBizDays_UpdateKlarityDate() {
		Opportunity[] opps = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 1'];

		ContentDocumentLink[] contentDocumentLinks = [
			SELECT Id, ContentDocumentId, LinkedEntityId
			FROM ContentDocumentLink
			WHERE LinkedEntityId = :opps[0].Id
		];

		Test.startTest();
		ContentDocumentLinkTriggerUtility.setKlarityDateOnOpportunity(contentDocumentLinks);
		Test.stopTest();

		Opportunity[] updatedOpps = [
			SELECT Id, Last_Update_Date_for_Klarity__c
			FROM Opportunity
			WHERE Name = 'Test Opportunity 1'
		];
		Assert.isTrue(updatedOpps[0].Last_Update_Date_for_Klarity__c.date() == System.today());
	}

	@IsTest
	static void testSetKlarityDateOnOpportunity_WhenCloseDateOutsideTwoBizDays_DoNotUpdateKlarityDate() {
		Opportunity[] opps = [SELECT Id FROM Opportunity WHERE Name = 'Test Opportunity 2'];

		ContentDocumentLink[] contentDocumentLinks = [
			SELECT Id, ContentDocumentId, LinkedEntityId
			FROM ContentDocumentLink
			WHERE LinkedEntityId = :opps[0].Id
		];

		Test.startTest();
		ContentDocumentLinkTriggerUtility.setKlarityDateOnOpportunity(contentDocumentLinks);
		Test.stopTest();

		Opportunity[] oppsAfterUpdate = [
			SELECT Id, Last_Update_Date_for_Klarity__c
			FROM Opportunity
			WHERE Name = 'Test Opportunity 2'
		];

		Assert.isTrue(oppsAfterUpdate[0].Last_Update_Date_for_Klarity__c == null);
	}

	@IsTest
	static void testSetKlarityDateOnOpportunity_WhenFilesLinkedToAccounts_DoNotUpdateKlarityDate() {
		Account[] accounts = [SELECT Id FROM Account];

		ContentDocumentLink[] contentDocumentLinks = [
			SELECT Id, ContentDocumentId, LinkedEntityId
			FROM ContentDocumentLink
			WHERE LinkedEntityId = :accounts[0].Id
		];

		Test.startTest();
		ContentDocumentLinkTriggerUtility.setKlarityDateOnOpportunity(contentDocumentLinks);
		Test.stopTest();

		Opportunity[] opps = [
			SELECT Id, Last_Update_Date_for_Klarity__c
			FROM Opportunity
		];

		Assert.isTrue(opps[0].Last_Update_Date_for_Klarity__c == null);
		Assert.isTrue(opps[1].Last_Update_Date_for_Klarity__c == null);
	}

	@IsTest
	static void testNotifyCaseOwnerOnFileUpload_WhenFileUploadedToCase_SendEmail() {
		Case cs = [SELECT Id FROM Case LIMIT 1];

		ContentDocumentLink[] contentDocumentLinks = [
			SELECT Id, ContentDocumentId, LinkedEntityId
			FROM ContentDocumentLink
			WHERE LinkedEntityId = :cs.Id
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ContentDocumentLinkTriggerUtility.notifyCaseOwnerOnFileUpload(contentDocumentLinks);
			Assert.areEqual(1, Limits.getEmailInvocations());
			Test.stopTest();
		}
	}

	private static ContentDocument createContentDocument(Id userId, Id recordType) {
		ContentVersion cv = new ContentVersion();
		cv.Title = 'Unit_Test_ContentVersion_Title';
		cv.PathOnClient = '/' + cv.Title + '.csv';
		Blob bodyBlob = Blob.valueOf('Unit_Test_ContentVersion_Body');
		cv.VersionData = bodyBlob;
		cv.origin = 'H';
		cv.FirstPublishLocationId = userId;
		cv.RecordTypeId = recordType != null ? recordType : cv.RecordTypeId;
		insert cv;
		return [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument LIMIT 1];
	}
}