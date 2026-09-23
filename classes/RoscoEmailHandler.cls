/** RoscoEmailHandler
 * Handles incoming email to support@tanium.com
 * Spam detection, Email authentication, Case/Contact Creation, etc..
 */
public with sharing class RoscoEmailHandler implements Messaging.InboundEmailHandler {
	/** handleInboundEmail
	 * Main handler for incoming emil.
	 * @param  email    contains From, To, Body Text, Body HTML, etc..
	 * @param  envelope contains From to info, added to Emailmessage but not used for analysis
	 * @return InboundEmailResult back to Salesforce
	 */
	public Messaging.InboundEmailResult handleInboundEmail(
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		Map<String, String> rosco = new Map<String, String>();

		// Result sent back to SF - success set true in createEmailMessage
		Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
		result.success = Boolean.valueOf(RoscoEmailUtility.rget(rosco, 'inbound_email_result_success'));

		try {
			// audit incoming
			RoscoEmailUtility.auditIncoming(email);

			// rosco map used heavily
			RoscoEmailUtility.init(rosco, email);

			// Check for SPAM messages
			if (RoscoEmailUtility.rget(rosco, 'check_spam') == 'true') {
				RoscoEmailUtility.checkSpam(rosco);
			}

			if (RoscoEmailUtility.rget(rosco, 'developer.tanium.com') == 'true') {
				RoscoEmailUtility.processDevEmail(rosco, email, envelope);

				// Hands free PoC handling
			} else if (RoscoEmailUtility.rget(rosco, 'hfpoc') == 'true') {
				RoscoEmailUtility.processHFPOCEmail(rosco, email, envelope);

				// Handle Chronicle Automated messages
			} else if (RoscoEmailUtility.rget(rosco, 'chronicleAuto') == 'true') {
				RoscoEmailUtility.processChronicleAutoEmail(rosco, email, envelope);

				// Process if not Spam
			} else if (RoscoEmailUtility.rget(rosco, 'spam') == 'false') {
				// Check Contacts
				RoscoEmailUtility.checkContacts(rosco);

				// Look for existing case
				if (RoscoEmailUtility.rget(rosco, 'caseid') == '') {
					RoscoEmailUtility.getCaseId(rosco, email);
				}

				// update rosco map with case values
				if (RoscoEmailUtility.rget(rosco, 'caseid') != '') {
					RoscoEmailUtility.updateRoscoWithCaseValues(rosco);
				}

				// Handle Mail API
				if (RoscoEmailUtility.rget(rosco, 'check_mail_api') == 'true') {
					RoscoEmailUtility.checkMailApi(rosco);
				}

				// Check if email can be authenticated
				if (
					(RoscoEmailUtility.rget(rosco, 'check_auth') == 'true') &&
					(RoscoEmailUtility.rget(rosco, 'caseid') == '')
				) {
					RoscoEmailUtility.checkAuthentication( rosco );
				}

				// Create Case or update case
				if (RoscoEmailUtility.rget(rosco, 'caseid') == '') {
					if (RoscoEmailUtility.rget(rosco, 'authenticated') == 'true') {
						//  create EmailMessage sObject
						Integer retrycase = Integer.valueOf(RoscoEmailUtility.rget(rosco, 'retrycase'));
						for (Integer i = 0; i < retrycase; i++) {
							if (RoscoEmailUtility.rget(rosco, 'caseid') == '') {
								RoscoEmailUtility.createCase(rosco);
							} else {
								i = 99; //break
							}
						}
					}
				} else {
					RoscoEmailUtility.updateCaseStatus(rosco);

					if (RoscoEmailUtility.rget(rosco, 'check_mail_api') == 'true') {
						//RoscoEmailUtility.updateCaseMailApi( rosco );
					}
				}

				//  create EmailMessage sObject
				Integer retryemail = Integer.valueOf(RoscoEmailUtility.rget(rosco, 'retryemail'));
				for (Integer i = 0; i < retryemail; i++) {
					if (RoscoEmailUtility.rget(rosco, 'messageid') == '') {
						RoscoEmailUtility.createEmailMessage(rosco, email, envelope);
					} else {
						i = 99; //break
					}
				}

				// Create Case Contact Roles
				if (
					(RoscoEmailUtility.rget(rosco, 'create_contacts') == 'true') &&
					(RoscoEmailUtility.rget(rosco, 'caseid') != '')
				) {
					String ccrstring = RoscoCaseContactRole.getCCRString(
						RoscoEmailUtility.rget(rosco, 'caseid')
					);
					ccrstring = ccrstring + ';' + RoscoEmailUtility.rget(rosco, 'people');
					RoscoCaseContactRole.setCcrViaString(ccrstring, RoscoEmailUtility.rget(rosco, 'caseid'));
				}

				// Email Response
				RoscoEmailUtility.emailResponse(rosco, email, envelope);

				//Triage Update
				if (RoscoEmailUtility.rget(rosco, 'new_case') != 'true') {
					String fromAddress = RoscoEmailUtility.rget(rosco, 'fromaddress_original');
					if (!fromAddress.contains('@tanium.com')) {
						if(Test.isRunningTest()){
							RoscoEmailUtility.slackCaseUpdate(rosco);
						}
					}
				}
			}
		} catch (Exception e) {
			RoscoEmailUtility.rput(
				rosco,
				'roscolog',
				'handleInboundEmail: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);

			result.success = false;
		}

		// Notify Tan Owner option
		if (RoscoEmailUtility.rget(rosco, 'notify_tanowneroption') == 'true') {
			RoscoEmailUtility.emailTanOwnerOption(rosco);
		}

		// Send debug log for analysis
		RoscoEmailUtility.emailDebuglog(rosco, email, envelope);
		RoscoEmailUtility.slackDebuglog(rosco, email, envelope);

		// return result back to SF
		result.success = RoscoEmailUtility.rget(rosco, 'inbound_email_result_success') == 'true'
			? true
			: false;
		return result;
	}
}