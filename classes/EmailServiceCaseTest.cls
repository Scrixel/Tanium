/**
 * @Business: Test class for the EmailServiceCase
 * @Date: 2018-04-09
 * @Author: Cumulus Vision
 * @Request: TAN-496
 * Modified  ModifiedDate   Description
 * TAN-496   2018-04-12     Initial dev.
 * SS-9056   2024-10-10     Update asserts
 * SS-10083	 2025-01-24			Replace Case.ThreadId__c w/ Case.ThreadId_caseSensitive__c
 * SS-9622   2025-02-04     Update test class to use tokens
 */
@IsTest
public class EmailServiceCaseTest {
	@IsTest
	static void testHandleInboundEmailForZendeskTicketNumber() {
		Case testCase = new Case(Zendesk_Ticket_Number__c = '4551');
		insert testCase;

		Test.startTest();

		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();
		Messaging.InboundEnvelope inboundEnvelope = new Messaging.InboundEnvelope();

		inboundEmail.subject = 'Email for the Email-to-Case thread::testthreadId::';
		inboundEmail.fromAddress = 'test.user@company.com';
		inboundEmail.plainTextBody = '##- Please type your reply above this line -##\r\n(#4551 <https://cumulusvision.zendesk.com/agent/tickets/4551>) by\t\nSome other content';

		new EmailServiceCase().handleInboundEmail(inboundEmail, inboundEnvelope);
		Test.stopTest();

		List<Case> casesCreatedFromEmail = [SELECT Id FROM Case WHERE Origin = 'Email'];
		Assert.isTrue(!casesCreatedFromEmail.isEmpty());
	}

	@IsTest
	static void testHandleInboundEmailForThreadId() {
		Case testCase = new Case();
		insert testCase;

		testCase = [SELECT Id FROM Case WHERE Id = :testCase.Id];
		Test.startTest();

		Messaging.InboundEmail inboundEmail = new Messaging.InboundEmail();
		Messaging.InboundEnvelope inboundEnvelope = new Messaging.InboundEnvelope();

		inboundEmail.subject = 'Email for the Email-to-Case thread::testthreadId::';
		inboundEmail.fromAddress = 'test.user@company.com';
		inboundEmail.plainTextBody = '##- Please type your reply above this line -##\r\nSome other content';

		new EmailServiceCase().handleInboundEmail(inboundEmail, inboundEnvelope);
		Test.stopTest();

		List<Case> casesCreatedFromEmail = [SELECT Id FROM Case WHERE Origin = 'Email'];
		Assert.isTrue(!casesCreatedFromEmail.isEmpty());
	}
}