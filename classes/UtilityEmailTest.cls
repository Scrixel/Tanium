/**
 * @Business: Test class for the UtilityEmail
 * @Date: 2024-12-05
 * @Author: Cumulus Vision
 * @Request:
 * Modified  ModifiedDate   Description
 * SS-9622   2024-12-03     Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 */
@IsTest
private class UtilityEmailTest {
	@TestSetup
	static void makeData() {
		Id supportCaseRecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
		String partnerAgreementRecordType = Utility.getRecordTypeIdByAPIName(
			'Apttus__APTS_Agreement__c',
			'Partner_Agreement'
		);

		Apttus__APTS_Agreement__c agreement = new Apttus__APTS_Agreement__c(
			Name = 'Amendment',
			RecordTypeId = partnerAgreementRecordType,
			Apttus__Status_Category__c = 'In Authoring',
			Apttus__Agreement_Number__c = '123457'
		);
		insert agreement;

		Apttus__Agreement_Clause__c agreementClause = new Apttus__Agreement_Clause__c();
		agreementClause.Apttus__Category__c = 'Systems Information';
		agreementClause.Apttus__Action__c = 'Final';
		agreementClause.Apttus__Agreement__c = agreement.Id;
		agreementClause.Apttus__Clause__c = AgreementTriggerHandler.NON_STANDARD_USE;
		insert agreementClause;

		List<Account> accts = new List<Account>();
		accts.add(TestFactory.buildAccount('Test Account'));
		accts.add(TestFactory.buildAccount('Test Account2'));
		insert accts;

		Contact contact = TestFactory.buildContact(accts[0].Id);
		contact.Email = 'test@test.com';
		insert contact;

		Case supportCaseL1 = new Case(RecordTypeId = supportCaseRecordTypeId);
		supportCaseL1.Origin = 'Community';
		supportCaseL1.Severity_Community__c = '3';
		supportCaseL1.ContactId = contact.Id;
		supportCaseL1.AccountId = accts[0].Id;
		supportCaseL1.Subject = 'Case Subject';
		supportCaseL1.Escalation_Tier__c = 'Level 1';
		supportCaseL1.Zendesk_Ticket_Number__c = '1234';
		insert supportCaseL1;

		List<EmailMessage> emailMessages = new List<EmailMessage>();
		emailMessages.add(
			TestFactory.buildEmailMessage('Test Open Case - Email', supportCaseL1.Id, supportCaseL1.Id)
		);
		insert emailMessages;
	}

	@IsTest
	static void testHandleInboundEmail_WhenEmailServiceIsCalled_ReturnSuccess() {
		Apttus__APTS_Agreement__c agreement = [SELECT Id FROM Apttus__APTS_Agreement__c LIMIT 1];

		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();
		Messaging.InboundEnvelope inboundEnvelope = new Messaging.InboundEnvelope();

		inboundEmail.subject = 'Email';
		inboundEmail.fromAddress = 'test.user@company.com';
		inboundEmail.ToAddresses = new List<String>{ 'test@test.com' };
		inboundEmail.ccAddresses = new List<String>{ 'test2@test.com' };
		inboundEmail.plainTextBody = 'ref:_' + agreement.Id;
		inboundEmail.htmlBody = 'ref:_' + agreement.Id;

		Test.startTest();
		Messaging.InboundEmailResult result = new EmailServiceApttus()
			.handleInboundEmail(inboundEmail, inboundEnvelope);
		Test.stopTest();

		Assert.isTrue(result.success, 'Email Service Handler result should be success');
	}

	@IsTest
	static void testGetContactIds_WhenContactExist_ReturnMap() {
		Test.startTest();
		Map<String, String> contactMap = UtilityEmail.getContactIds(new Set<String>{ 'test@test.com' });
		Test.stopTest();

		Assert.isNotNull(contactMap, 'Returned contactMap should not be null');
	}

	@IsTest
	static void testConvertMapToIdList_WhenIdsExist_ReturnList() {
		Map<String, String> idsMap = new Map<String, String>();
		idsMap.put('id', '500RK00000EJemVYAT');

		Test.startTest();
		List<Id> idList = UtilityEmail.convertMapToIdList(idsMap);
		Test.stopTest();

		Assert.isNotNull(idList, 'Returned contactMap should not be null');
	}

	@IsTest
	static void testTicketDefaults_WhenTicketIsDEfaulted_ValuesAreSet() {
		UtilityEmail.tickets myTicket = new UtilityEmail.tickets();
		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();

		inboundEmail.subject = 'Email';
		inboundEmail.fromAddress = 'test@test.com';
		inboundEmail.ToAddresses = new List<String>{ 'test@test.com' };
		inboundEmail.ccAddresses = new List<String>{ 'test2@test.com' };
		inboundEmail.plainTextBody = 'ref:_TEST';
		inboundEmail.htmlBody = 'ref:_TEST';

		Test.startTest();
		UtilityEmail.TicketDefaults(myTicket, inboundEmail);
		Test.stopTest();

		Assert.areEqual(myTicket.origin, 'Email', 'Origin should be defaulted to Email');
	}

	@IsTest
	static void testTicketCreate_WhenTicketIsCreatyed_ReturnTrue() {
		Account acc = [SELECT Id FROM Account LIMIT 1];
		Contact con = [SELECT Id FROM Contact LIMIT 1];

		UtilityEmail.tickets myTicket = new UtilityEmail.tickets();
		myTicket.subject = 'Test Subject';
		myTicket.status = 'In Progress - Troubleshooting';
		myTicket.Body = 'Test';
		myTicket.SuppliedFromName = 'Test Name';
		myTicket.SuppliedFromEmail = 'test@test.com';
		myTicket.AccountId = acc.Id;
		myTicket.contactid = con.Id;
		myTicket.Priority = 'Medium';
		myTicket.origin = 'Email';
		myTicket.recordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');

		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();

		inboundEmail.subject = 'Email';
		inboundEmail.fromAddress = 'test@test.com';
		inboundEmail.ToAddresses = new List<String>{ 'test@test.com' };
		inboundEmail.ccAddresses = new List<String>{ 'test2@test.com' };
		inboundEmail.plainTextBody = 'ref:_TEST';
		inboundEmail.htmlBody = 'ref:_TEST';

		Test.startTest();
		Boolean ticketCreated = UtilityEmail.TicketCreate(myTicket, inboundEmail);
		Test.stopTest();

		Assert.isTrue(ticketCreated, 'Ticket should be created');
	}

	@IsTest
	static void testAddAgreementTaskOutbound_WhenAgreementIsAdded_ReturnTrue() {
		Apttus__APTS_Agreement__c agreement = [SELECT Id FROM Apttus__APTS_Agreement__c LIMIT 1];
		Contact con = [SELECT Id FROM Contact LIMIT 1];

		String recordTag = 'ref:_' + agreement.Id + '_:ref';
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
		message.subject = 'Email';
		message.targetObjectId = con.Id;
		message.toAddresses = new List<String>{ 'test@test.com' };
		message.ccAddresses = new List<String>{ 'test2@test.com' };
		message.plainTextBody = 'ref:_' + agreement.Id;
		message.htmlBody = 'ref:_' + agreement.Id;

		Test.startTest();
		Boolean isAgreementAdded = UtilityEmail.AddAgreementTaskOutbound(
			false,
			message,
			agreement.Id,
			'test2@test.com',
			'test3@test.com'
		);
		Test.stopTest();

		Assert.isTrue(isAgreementAdded, 'Agreement should be added');
	}

	@IsTest
	static void testTicketAlreadyExists_WhenTicketDoesntExist_CatchErrors() {
		UtilityEmail.tickets myTicket = new UtilityEmail.tickets();
		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();

		inboundEmail.subject = 'Email';
		inboundEmail.fromAddress = 'test@test.com';
		inboundEmail.ToAddresses = new List<String>{ 'test@test.com' };
		inboundEmail.ccAddresses = new List<String>{ 'test2@test.com' };
		inboundEmail.plainTextBody = 'ref:_TEST';
		inboundEmail.htmlBody = 'ref:_TEST';

		UtilityEmail.TicketAlreadyExists(myTicket, null, inboundEmail, '');
	}

	@IsTest
	static void testZendeskTicket_WhenCaseIsFound_UpdateTicket() {
		Boolean isCaseFound = true;
		UtilityEmail.tickets myTicket = new UtilityEmail.tickets();
		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();

		inboundEmail.subject = 'Email';
		inboundEmail.fromAddress = 'test@test.com';
		inboundEmail.ToAddresses = new List<String>{ 'test@test.com' };
		inboundEmail.ccAddresses = new List<String>{ 'test2@test.com' };
		inboundEmail.plainTextBody = 'ref:_TEST';
		inboundEmail.htmlBody = 'ref:_TEST';

		try {
			UtilityEmail.ZendeskTicket(myTicket, null, inboundEmail, '1234');
		} catch (Exception e) {
			isCaseFound = false;
		}

		Assert.isTrue(isCaseFound, 'Case should be found');
	}

	@IsTest
	static void testAddTextAttachment_WhenEmailHasTextAttachment_InsertAttachment() {
		EmailMessage message = [SELECT Id FROM EmailMessage LIMIT 1];
		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();

		inboundEmail.subject = 'Email';
		inboundEmail.fromAddress = 'test@test.com';
		inboundEmail.ToAddresses = new List<String>{ 'test@test.com' };
		inboundEmail.ccAddresses = new List<String>{ 'test2@test.com' };
		inboundEmail.plainTextBody = 'ref:_TEST';
		inboundEmail.htmlBody = 'ref:_TEST';

		Messaging.InboundEmail.TextAttachment attachment = new Messaging.InboundEmail.TextAttachment();
		attachment.body = 'my attachment text';
		attachment.fileName = 'textfileone.txt';
		attachment.mimeTypeSubType = 'text/plain';
		inboundEmail.textAttachments = new List<Messaging.inboundEmail.TextAttachment>{ attachment };

		Test.startTest();
		UtilityEmail.AddTextAttachment(message.Id, inboundEmail);
		Test.stopTest();

		Attachment[] att = [SELECT Id FROM Attachment WHERE Name = 'textfileone.txt'];
		Assert.areEqual(1, att.size(), '1 Attachment should be created');
	}

	@IsTest
	static void testAddBinaryAttachment_WhenEmailHasBinaryAttachment_InsertAttachment() {
		EmailMessage message = [SELECT Id FROM EmailMessage LIMIT 1];
		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();

		inboundEmail.subject = 'Email';
		inboundEmail.fromAddress = 'test@test.com';
		inboundEmail.ToAddresses = new List<String>{ 'test@test.com' };
		inboundEmail.ccAddresses = new List<String>{ 'test2@test.com' };
		inboundEmail.plainTextBody = 'ref:_TEST';
		inboundEmail.htmlBody = 'ref:_TEST';

		Messaging.InboundEmail.BinaryAttachment attachment = new Messaging.InboundEmail.BinaryAttachment();
		attachment.body = blob.valueOf('my attachment text');
		attachment.fileName = 'textfiletwo.txt';
		attachment.mimeTypeSubType = 'text/plain';
		inboundEmail.binaryAttachments = new List<Messaging.inboundEmail.BinaryAttachment>{
			attachment
		};

		Test.startTest();
		UtilityEmail.AddBinaryAttachment(message.Id, inboundEmail);
		Test.stopTest();

		Attachment[] att = [SELECT Id FROM Attachment WHERE Name = 'textfiletwo.txt'];
		Assert.areEqual(1, att.size(), '1 Attachment should be created');
	}
}