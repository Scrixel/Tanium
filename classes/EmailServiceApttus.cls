/**
 * @Business: Email Service for Apttus Agreements
 * @Date: 2020-01-28
 * @Author: Cumulus Vision
 * @Request: TAN-840
 * Modified  ModifiedDate   Description
 * TAN-838   2020-01-28     Initial Development.ApexPages
 * TAN-840   2020-01-30     Captured the "X-SFDC-EntityId" header and inserted a task
 */
global class EmailServiceApttus implements Messaging.InboundEmailHandler {
	global Messaging.InboundEmailResult handleInboundEmail(
		Messaging.inboundEmail email,
		Messaging.InboundEnvelope env
	) {
		// Create an InboundEmailResult object for returning the result of the
		// Apex Email Service
		Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

		System.debug('email === ' + email);

		UtilityEmail.ApttusAgreement myAgreement = new UtilityEmail.ApttusAgreement();
		UtilityEmail.ApttusAgreementDefaults(myAgreement, email);

		//parse header for X-SFDC-EntityId
		String agreementId = extractAgreementId(myAgreement.body, myAgreement.subject);
		System.debug('\n agreementId:' + agreementId);
		myAgreement.AgreementId = agreementId;
		UtilityEmail.AddAgreementTask(false, myAgreement);

		result.success = true;
		return result;
	}

	private static String extractAgreementId(string plainTextBody, string subject) {
		String agreementId = '';
		String searchFor = '';
		try {
			//Parse e-mail body to retrieve caseid
			List<string> allLines = plainTextBody.split('\n');
			for (String line : allLines) {
				searchFor = 'ref:_';
				if (line.contains(searchFor)) {
					line = line.replace(searchFor, ' ');
					line = line.replace('_:ref', ' ');
					//add extra  > > parsing for iPhones
					if (line.contains('>')) {
						line = line.replace('>', ' ');
					}
					agreementId = line.trim();
				}
			}
		} catch (Exception e) {
		}
		return agreementId;
	}
}