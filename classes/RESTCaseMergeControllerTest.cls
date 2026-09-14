@isTest
private class RESTCaseMergeControllerTest {
	// New bits for trigger mgmt
	static void CreateRecords() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler' });
	}

	static testMethod void testCaseMerge() {
		CreateRecords();
		System.runAs(getAdminUser()) {
			Account accountObj = new Account(name = 'testAccount');
			insert accountObj;
			Contact contactObj = new Contact(
				Email = 'matt+testapex@mindvault.com',
				FirstName = 'Test',
				LastName = 'Apex',
				AccountId = accountObj.id
			);
			insert contactObj;
			Case caseObj = new Case(
				ContactId = contactObj.id,
				accountid = accountObj.id,
				subject = 'IGNORE:testing:matt:20180706.01',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				suppliedEmail = 'matt+testapex@mindvault.com'
			);
			insert caseObj;
			Case dupeCaseObj = new Case(
				ContactId = contactObj.id,
				accountid = accountObj.id,
				subject = 'RE:IGNORE:testing:matt:20180706.01',
				Severity_Community__c = '3',
				type = 'Incident',
				Reason = 'New problem',
				Origin = 'Email',
				suppliedEmail = 'matt+testapex@mindvault.com'
			);
			insert dupeCaseObj;
			//How do i get attachments, emailmessages, etc. in here

			Case[] parentCaseList = [SELECT Id, CaseNumber, AccountId FROM case WHERE Id = :caseObj.Id];
			Case parentCase = parentCaseList[0];
			Case[] mergeCaseList = [
				SELECT Id, CaseNumber, AccountId, Status
				FROM case
				WHERE Id = :dupeCaseObj.Id
			];
			Case mergeCase = mergeCaseList[0];

			Attachment att = new Attachment();
			String bodyStr = 'this would be an example of an attachment contents';
			att.Body = Blob.valueOf(bodyStr);
			//Do I Need content type?
			//att.ContentType
			att.Name = 'AttNote_' + System.now().format('yyyy_MM_dd_hh_mm_ss') + '.txt';
			att.parentId = dupeCaseObj.id;
			insert att;
			ContentVersion contentVersion_1 = new ContentVersion(
				Title = 'TestDoc',
				PathOnClient = 'testdoc1.txt',
				VersionData = Blob.valueOf('Test Content'),
				IsMajorVersion = true
			);
			insert contentVersion_1;
			ContentVersion contentVersion_2 = [
				SELECT Id, Title, ContentDocumentId
				FROM ContentVersion
				WHERE Id = :contentVersion_1.Id
				LIMIT 1
			];
			ContentDocumentLink aCDL = new ContentDocumentLink(
				LinkedEntityId = dupeCaseObj.Id,
				ShareType = 'V',
				ContentDocumentId = contentVersion_2.ContentDocumentId
			);
			// Do I need to create a user / owner one? (of type I?)
			insert aCDL;
			CaseComment aCaseComment = new CaseComment();
			aCaseComment.CommentBody = 'Test comment';
			aCaseComment.ParentId = dupeCaseObj.Id;
			insert aCaseComment;

			EmailMessage em = new EmailMessage(
				FromAddress = 'matt+testapex@mindvault.com',
				FromName = 'test matt',
				ToAddress = 'test.servicecloud@tanium.com',
				Status = '1',
				Subject = 'test subject',
				TextBody = 'testing: ignore',
				HtmlBody = 'testing: ignore',
				ParentId = dupeCaseObj.Id
			);
			insert em;

			RESTCaseMergeController.mergeIntoParentCase(parentCase.CaseNumber, mergeCase.CaseNumber);
			Attachment[] attList = [
				SELECT Id, ParentId, Name, Body
				FROM Attachment
				WHERE ParentId = :caseObj.Id
			];
			Attachment anAttachment = attList[0];

			System.assertEquals(anAttachment.ParentId, caseObj.Id);

			ContentDocumentLink[] CDLList = [
				SELECT Id, LinkedEntityId, ContentDocumentId
				FROM ContentDocumentLink
				WHERE LinkedEntityId = :parentCase.Id
			];
			ContentDocumentLink verifyCDL = CDLList[0];
			System.assertEquals(verifyCDL.LinkedEntityId, parentCase.Id);

			EmailMessage[] emailList = [
				SELECT Id, FromName, Subject, TextBody, ParentId, Status
				FROM EmailMessage
				WHERE ParentId = :parentCase.Id
			];
			EmailMessage verifyEmail = emailList[0];
			System.assertEquals(verifyEmail.ParentId, parentCase.Id);
			System.assertEquals(verifyEmail.Status, em.Status);
			// See if the email contains both the original textbody _and_   "Original body"
			//myString.contains('FORCE')
			System.assert(verifyEmail.TextBody.contains('testing: ignore'));
			System.assert(verifyEmail.TextBody.contains('Original body'));
		}
		// Definitely need to do some asserts after all of this to make sure things got moved appropriately.
	}

	static User getAdminUser() {
		List<User> testUsers = [SELECT Id FROM User WHERE LastName LIKE 'TaniumAdminUser%'];
		if (testUsers.isEmpty()) {
			User adminUser = TestFactory.getTaniumAdminUser(true);
			// No flows exist for Billing schedule related objects but those on acct and oppty block test class execution
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableFlows');
			TestingUtility.assignPermissionSet(adminUser.Id, 'DisableValidationRules');
			return adminUser;
		}
		return testUsers[0];
	}
}