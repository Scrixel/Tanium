global class RoscoEmailPublisher implements QuickAction.QuickActionDefaultsHandler {
	// Empty constructor
	global RoscoEmailPublisher() {
	}

	// The main interface method
	global void onInitDefaults(QuickAction.QuickActionDefaults[] defaults) {
		QuickAction.SendEmailQuickActionDefaults sendEmailDefaults = (QuickAction.SendEmailQuickActionDefaults) defaults.get(
			0
		);
		EmailMessage emailMessage = (EmailMessage) sendEmailDefaults.getTargetSObject();

		// Custom settings may override record type id
		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

		String recordTypeId = '0120e000000Dxi7AAC';
		if (cmfields.contains('rosco_case_recordtypeid__c')) {
			recordTypeId = String.valueOf(cm.get('rosco_case_recordtypeid__c'));
		}

		String recordTypeId2 = '0127V000000JPxmQAG';
		if (cmfields.contains('rosco_case_techpartner_recordtypeid__c')) {
			recordTypeId2 = String.valueOf(cm.get('rosco_case_techpartner_recordtypeid__c'));
		}

		String enabled = 'false';
		if (cmfields.contains('rosco_email_publisher__c')) {
			enabled = String.valueOf(cm.get('rosco_email_publisher__c'));
		}

		if (enabled == 'true') {
			// Case Subject
			List<Case> caselist = [
				SELECT Subject, RecordTypeId
				FROM Case
				WHERE Id = :sendEmailDefaults.getContextId()
			];

			if (caselist[0].RecordTypeId == recordTypeId || caselist[0].RecordTypeId == recordTypeId2) {
				emailMessage.Subject = caselist[0].Subject;

				List<CaseContactRole> ccrlist = [
					SELECT Contact.Email
					FROM CaseContactRole
					WHERE CasesId = :sendEmailDefaults.getContextId()
				];

				String ccrs = '';
				for (CaseContactRole c : ccrList) {
					if (c.Contact.Email != null) {
						String cEmail = String.valueOf(c.Contact.Email);

						if (cEmail.contains('@')) {
							if (
								!cEmail.contains('soa@tanium.com') && !cEmail.contains('socontacttbd@tanium.com')
							) {
								if (ccrs == '') {
									ccrs = cEmail;
								} else {
									ccrs = ccrs + ';' + cEmail;
								}
							}
						}
					}
				}

				//emailMessage.FromAddress = 'support@tanium.com';
				emailMessage.ToAddress = ccrs;
				System.debug('emailMessage.ToAddress:' + emailMessage.ToAddress);
				System.debug('emailMessage.Subject:' + emailMessage.Subject);
			}
		}
	}
}