/**
 * @Business: Inbound email service.
 * @Date: 2018-03-23
 * @Author: Cumulus Vision
 * @Request: TAN-495
 * Modified  ModifiedDate   Description
 * TAN-496   2018-04-28     Initial dev.
 * TAN-564   2018-05-06     added zendesk domain check.
 * SS-9622   2024-12-03     Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 */
global class EmailServiceCase implements Messaging.InboundEmailHandler {
	global Messaging.InboundEmailResult handleInboundEmail(
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		String threadId;
		// Create an inboundEmailResult object for returning the result of the Apex Email Service
		Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
		//set ticket defaults
		UtilityEmail.tickets myTicket = new UtilityEmail.tickets();
		UtilityEmail.TicketDefaults(myTicket, email);
		//stage email parse
		String searchFor = '';
		List<String> allLines = new List<String>();
		allLines = myTicket.Body.split('\n');

		// Try to find the Case ID using threading tokens in email attributes.
		Id caseId = EmailMessages.getRecordIdFromEmail(
			email.subject,
			email.plainTextBody,
			email.htmlBody
		);

		// If we haven't found the Case ID, try finding it using headers.
		if (caseId == null && email.headers != null) {
			caseId = Cases.getCaseIdFromEmailHeaders(email.headers);
		}

		if (caseId != null) {
			// Get the formatted threading token.
			// Extract "Case Thread Id" from the Case
			threadId = EmailMessages.getFormattedThreadingToken(caseId);
		}

		map<string, string> emailHeaders_Map = new Map<string, string>();
		integer i = 0;
		if (email.headers != null && email.headers.size() > 0) {
			for (i = 0; i < email.headers.size(); i++) {
				emailHeaders_Map.put(email.headers[i].name, email.headers[i].value);
			}
		}
		system.debug(emailHeaders_Map.get('In-Reply-To'));
		string theReplyTo = emailHeaders_Map.get('In-Reply-To');
		string theDomainReply;
		if (String.isNotBlank(theReplyTo)) {
			string[] lstReplyTo = theReplyTo.split('@');
			theDomainReply = lstReplyTo[1].replace('>', '').trim();
			system.debug(theDomainReply);
		}

		// Extract "Zendesk Ticket Number" from the plainTextBody of the Email
		String zendeskTicketNumber = extractZendeskTicketNumber(email.plainTextBody, email.subject);
		if (theDomainReply == 'zendesk.com' && zendeskTicketNumber != null) {
			//handle zendesk replies
			UtilityEmail.ZendeskTicket(myTicket, allLines, email, zendeskTicketNumber);
		} else if (threadId != null) {
			// Process comments being added to existing tickets
			UtilityEmail.TicketAlreadyExists(myTicket, allLines, email, threadId);
		} else {
			// New ticket creation
			UtilityEmail.GenericCreateTicket(myTicket, allLines, email);
		}
		// Set the result to true. No need to send an email back to the user
		// with an error message
		result.success = true;

		// Return the result for the Apex Email Service
		return result;
	}

	public static String extractZendeskTicketNumber(String emailPlainTextBody, String emailSubject) {
		final String KEY_EMAIL_LINE = 'Please type your reply above this line';
		final String ZENDESK_ID_LINE_EXPRESSION = '(?s)\\(#(\\d+)(.+>)?\\)';
		Pattern zendeskIdLinePattern = Pattern.compile(ZENDESK_ID_LINE_EXPRESSION);

		//try to find ticket number in body
		//should work for resolved and new tickets (request received)
		//matched off of '# Please type your reply above this line #' and the lines below containing a ticket number
		//surrounded by '(#' and ')' the ticket number being between the '#' and ')' any outside text is not considered.
		//should work for ticket created (request received) and the (request resolved)
		//request received example managed to:
		/*
        Your request (#13870) has been received, and is being reviewed by our support staff.
        To add additional comments, reply to this email or follow the link below:
        http://tanium.zendesk.com/agent/tickets/13870
        */
		//request resolved managed to:
		/*
        # Please type your reply above this line #
        Your request (#13451) has been deemed solved. To reopen, reply to this email or follow the link below:
        http://tanium.zendesk.com/agent/tickets/13451
        */
		emailPlainTextBody = String.isBlank(emailPlainTextBody) ? '' : emailPlainTextBody;
		emailPlainTextBody = emailPlainTextBody.substringAfter(KEY_EMAIL_LINE);
		System.debug('\n emailPlainTextBody:' + emailPlainTextBody);

		String zendeskTicketNumber;
		Matcher matcher = zendeskIdLinePattern.matcher(emailPlainTextBody);
		if (matcher.find()) {
			zendeskTicketNumber = matcher.group(1);
		}
		System.debug('\n zendeskTicketNumber (1st Check): ' + zendeskTicketNumber);
		//otherwise try to find ticket number from subject.
		//the pattern in subject is notification is separated by :'s.
		//find the first number in the subject is the approach.
		//regardless of any text ahead of the number, the zendesk ticket number is always the first number
		//Subject examples manged to:
		/*
        Update: 13870: test:ignore:20180417.01
        */
		/*
        Tanium: Request received: 13870: test:ignore:20180417.01
        */
		/*
        Tanium: 13878: Re: [EXTERNAL] testing a ticket
        */
		if (zendeskTicketNumber == null && emailSubject.contains(':')) {
			string[] theSubjectSplit = emailSubject.split(':');
			integer i = 0;
			if (theSubjectSplit != null && theSubjectSplit.size() > 0) {
				for (i = 0; i < theSubjectSplit.size(); i++) {
					system.debug(theSubjectSplit[i]);
					if (theSubjectSplit[i].trim().isNumeric()) {
						//number found
						zendeskTicketNumber = theSubjectSplit[i].trim();
						//break (stop the loop) because we want to find the FIRST number in the subject
						break;
					}
				}
			}
		}
		System.debug('\n zendeskTicketNumber (2nd Check): ' + zendeskTicketNumber);
		return zendeskTicketNumber;
	}
}