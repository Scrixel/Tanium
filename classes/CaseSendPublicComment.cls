/**
 * @Business:
 * @Date:
 * @Authors: Tanium Dev Team
 * @Request:
 * RequestId  ModifiedDate  Description
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 */
public without sharing class CaseSendPublicComment {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@InvocableMethod(label='Send Case Public Comment')
	public static void sendPublicComment(List<Case> cases) {
		System.debug('sendPublicComment:entering');

		Case aCase = cases[0];

		// Custom settings may override some options
		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

		// Use base url, but override better link
		String caseLink = System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + aCase.ID;

		if (
			cmfields.contains('rosco_case_url_prefix__c') && cmfields.contains('rosco_sfdc_dom_l__c')
		) {
			String urlprefix = String.valueOf(cm.get('rosco_case_url_prefix__c'));
			String urlfriend = String.valueOf(cm.get('rosco_sfdc_dom_l__c'));

			if (nullOrEmpty(urlprefix) == false && nullOrEmpty(urlfriend) == false) {
				caseLink = 'https://' + urlfriend + '/lightning/r/Case/' + aCase.ID + '/view';
			}
		}

		// Exception channel defaults to #tool_soa but account should override
		String accountChannel = 'CJ4PWL412';
		if (cmfields.contains('rosco_slack_exceptions__c')) {
			String ac = String.valueOf(cm.get('rosco_slack_exceptions__c'));

			if (nullOrEmpty(ac) == false) {
				accountChannel = ac;
			}
		}
		// Get Account info
		if (nullOrEmpty(aCase.AccountId) == false) {
			Account anAccount = [
				SELECT id, name, Slack_Channel_Id__c, Premium_Support__c
				FROM account
				WHERE id = :aCase.AccountId
			];

			if (!String.isBlank(anAccount.Slack_Channel_Id__c)) {
				accountChannel = anAccount.Slack_Channel_Id__c;
			}
		}

		// Webhook
		String webhookURL = '';
		if (cmfields.contains('rosco_slack_incoming_hook__c')) {
			String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

			if (nullOrEmpty(hook) == false) {
				webhookURL = hook;
			}
		}

		// Get Case Contact Roles
		List<String> cc_public = new List<String>();
		List<String> cc_tanium = new List<String>();
		List<CaseContactRole> ccr = [
			SELECT Contact.Email
			FROM CaseContactRole
			WHERE CasesId = :aCase.ID
		];
		if (nullOrEmpty(ccr) == false) {
			for (CaseContactRole c : ccr) {
				if (c.Contact.Email != null) {
					String address = c.Contact.Email.toLowerCase();
					if (address.contains('@')) {
						if (address.contains('@tanium.com')) {
							cc_tanium.add(String.valueOf(address));
						} else {
							cc_public.add(String.valueOf(address));
						}
					}
				}
			}
		}

		// clean case #
		String casenum = aCase.CaseNumber;
		//String casenum = aCase.CaseNumber.replaceAll('^[0][0][0]', '');

		//handle <code>
		String sfhtml = aCase.LatestPublicCommentHTML__c;
		System.debug(sfhtml);
		sfhtml = sfhtml.replaceAll(
			'<code>',
			'<table bgcolor="#F0F8FF" width="80%" border=1><th align="left">'
		);
		sfhtml = sfhtml.replaceAll('</code>', '</th></table>');
		sfhtml = sfhtml.replaceAll('\n', '<br>');
		System.debug(sfhtml);

		Case c = [SELECT LastModifiedBy.Email FROM Case WHERE Id = :aCase.Id LIMIT 1];
		String threadId = EmailMessages.getFormattedThreadingToken(c.Id);

		// html body
		String htmlbody = '<html><body>';
		htmlbody = aCase.Subject + ' has been updated (public) by ' + c.LastModifiedBy.Email;
		htmlbody += '<br><br>' + sfhtml;
		htmlbody += '<br>You can update this case via Service Console portal by clicking ';
		htmlbody += '<a href="URLPLACEHOLDER"> here</a>';
		htmlbody += '.  <br><br>Regards,<br>Tanium Support';
		htmlbody += '<br><br>' + threadId + '</body></html>';

		// txt body
		String textbody = aCase.Subject + ' has been updated (public).';
		textbody += '\n\n=======\n' + aCase.LatestPublicComment__c + '\n=======';
		textbody += '\nYou can update this case via the support portal by clicking ';
		textbody += 'URLPLACEHOLDER.  \n\nRegards,\nTanium Support';

		// Get org wide sender id
		String owea = '0D20e0000004DjCCAU';
		if (cmfields.contains('rosco_owea__c')) {
			System.debug('we are here');
			if (!nullOrEmpty(cm.get('rosco_owea__c'))) {
				owea = String.valueOf(cm.get('rosco_owea__c'));
				System.debug('we are here2');
			}
		}
		System.debug('owea:' + owea);

		// Determine whether non tanium people should be syncd
		String sync_non_tanium_ccr = 'false';
		if (cmfields.contains('rosco_sync_non_tanium_ccr__c')) {
			if (!nullOrEmpty(cm.get('rosco_sync_non_tanium_ccr__c'))) {
				sync_non_tanium_ccr = String.valueOf(cm.get('rosco_sync_non_tanium_ccr__c'));
			}
		}
		System.debug('rosco_sync_non_tanium_ccr:' + sync_non_tanium_ccr);

		/* Send Public Email
        if ( nullOrEmpty( cc_public ) == False && sync_non_tanium_ccr == 'true' ){

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setOrgWideEmailAddressId( owea );
            mail.setToAddresses(cc_public);
            mail.setSubject('Tanium Support: #' + casenum + ' has been updated.' );
            
            String html_public = htmlbody.replace( 'URLPLACEHOLDER', 'http://support.tanium.com/s/case/' + aCase.Id );
            mail.setHtmlBody( html_public );
            String text_public = textbody.replace( 'URLPLACEHOLDER', 'http://support.tanium.com/s/case/' + aCase.Id );
            mail.setPlainTextBody( text_public );

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }*/

		// Send Tanium Email
		System.debug('cc_tanium:' + cc_tanium);
		if (nullOrEmpty(cc_tanium) == false) {
			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setOrgWideEmailAddressId(owea);
			mail.setToAddresses(cc_tanium);
			mail.setSubject('Tanium Support: #' + casenum + ' has been updated (public).');

			String html_public = htmlbody.replace('URLPLACEHOLDER', caseLink);
			mail.setHtmlBody(html_public);
			String text_public = textbody.replace('URLPLACEHOLDER', caseLink);
			mail.setPlainTextBody(text_public);

			if (!Test.isRunningTest()) {
				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
			System.debug('Sent mail');
		}
	}
}