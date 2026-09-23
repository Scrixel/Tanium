public with sharing class CaseSendEmailOnOwnershipChange {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** sendEmailOnOwnerChange send email to case owner when assigned
	 * @param  List of cases (really only uses top one)
	 */
	@InvocableMethod(label='Send Email On Ownership Change')
	public static void sendEmailOnOwnerChange(List<Case> cases) {
		System.debug('sendEmailOnOwnerChange:entering');

		try {
			Case aCase = cases[0];

			// Bail if not assigned to user account
			String ownerEmail = '';
			List<User> ulist = [SELECT Email FROM User WHERE Id = :aCase.OwnerId];
			if (!ulist.isEmpty()) {
				ownerEmail = ulist[0].Email;
			}
			if ((String.valueOf(aCase.OwnerId).left(3) != '005') || (ownerEmail == 'soa@tanium.com')) {
				return;
			}

			if ((String.valueOf(aCase.OwnerId).left(3) == '005')) {
				if(!ownerEmail.containsIgnoreCase('@tanium.com')){
					QueueSobject supportScQ = [
						SELECT QueueId
						FROM QueueSobject
						WHERE Queue.Name = 'Support Center'
					];
					Case c = [SELECT Id FROM Case WHERE Id =:aCase.Id];
					c.OwnerId = supportScQ.QueueId;
					update c;
					return;
				}
			}

			/* TODO
            // Determine if we want to send to all Tanium CC folks
            Boolean allTamOnCc = false;

            String soql = 'SELECT email_cc_on_owner_change__c ' +
                        'FROM rosco_account__c WHERE account__c = \'' + aCase.AccountID + '\'';

            List<rosco_account__c> ra = Database.query(soql); 
            if ( !ra.isEmpty() ) {
                for ( rosco_account__c r : ra ){
                    if( r.email_cc_on_owner_change__c == true){
                        allTamOnCc = true;
                    }
                }
            }
            */

			// List of folks to send email too
			List<String> cc_tanium = new List<String>();

			/* TODO
            // Loop through tams if needed
            if( allTamOnCc ){
                List<CaseContactRole> ccr = [select Contact.Email from CaseContactRole where CasesId=:aCase.Id];
                if( nullOrEmpty( ccr ) == False ){
                    for (CaseContactRole c : ccr){
                        
                        if ( c.Contact.Email != null ){
                            String address = c.Contact.Email.toLowerCase();
                            if ( address.contains('@') ){
                                if ( address.contains('@tanium.com') ){
                                    cc_tanium.add( String.valueOf( address ));
                                }
                            }
                        }
                    }
                }
            } else {*/
			cc_tanium.add(ownerEmail);
			//}

			// clean case #
			String casenum = aCase.CaseNumber;
			//String casenum = aCase.CaseNumber.replaceAll('^[0][0][0]', '');

			// html body
			String htmlbody = '<html><body>';
			htmlbody += RoscoUtility.getCaseInfoHtmlTable(String.valueOf(aCase.Id));
			htmlbody += '</body></html>';

			// Get org wide sender id
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D260000000XZFgCAO';
			if (cmfields.contains('rosco_owea_noreply__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea_noreply__c'))) {
					owea = String.valueOf(cm.get('rosco_owea_noreply__c'));
				}
			}
			System.debug('owea:' + owea);

			// Send Email
			if (nullOrEmpty(cc_tanium) == false) {
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(owea);
				mail.setToAddresses(cc_tanium);
				mail.setSubject(aCase.CaseNumber + ':' + aCase.Subject + ' assigned to ' + ownerEmail);

				mail.setHtmlBody(htmlbody);

				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
		} catch (Exception e) {
			System.debug('sendEmailOnOwnerChange: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}
}