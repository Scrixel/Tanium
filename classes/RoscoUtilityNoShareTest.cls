@isTest
public with sharing class RoscoUtilityNoShareTest {
	@isTest(SeeAllData=true)
	static void test_createAttachment() {
		Account accountObj = TestFactory.buildAccount('RoscoTestAccount');
		insert accountObj;
		Contact contactObj = new Contact(
			Email = 'test@foo111.com',
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.id
		);
		insert contactObj;
		Case caseObj = new Case(
			ContactId = contactObj.id,
			accountid = accountObj.id,
			subject = 'TEST12313',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			Component__c = 'Other'
		);
		insert caseObj;

		Attachment newAttachment = new Attachment();
		newAttachment.Name = 'ROSCOTESTCASE';
		Blob bodyBlob = Blob.valueOf('ROSCOTESTCASE');
		newAttachment.Body = bodyBlob;
		newAttachment.ParentId = caseObj.Id;

		String newAttId = RoscoUtilityNoShare.createAttachment(newAttachment);
	}
}