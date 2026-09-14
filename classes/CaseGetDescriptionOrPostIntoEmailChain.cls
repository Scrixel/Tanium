/**
 * @Business: Contains invocable method copyDescriptionToEmail to be called by a flow
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7698    2024-04-18    Updated method copyDescriptionToEmail
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading Token
 */
public with sharing class CaseGetDescriptionOrPostIntoEmailChain {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** sendEmailOnOwnerChange send email to case owner when assigned
	 * @param  List of cases (really only uses top one)
	 */
	@InvocableMethod(label='Copy Description as Email')
	public static void copyDescriptionToEmail(List<Case> cases) {
		try {
			Case aCase = cases[0];

			String caseDescription = String.valueOf(aCase.Description);
			if (
				caseDescription.containsIgnoreCase('Case description provided via Tanium support portal')
			) {
				return;
			}

			String caseId = aCase.Id;
			String threadId = EmailMessages.getFormattedThreadingToken(caseId);
			String description = aCase.Description;
			String caseSubject = '(Description->Email Slipstream) ' + threadid;

			List<String> to = new List<String>();
			if (!Utility.isSandbox()) {
				to.add('support@tanium.com');
			}

			String userEmail = RoscoUtility.getEmailFromUserId(String.valueOf(aCase.CreatedById));
			String htmlBody =
				'Initial description entered via portal by ' +
				userEmail +
				':<br><br>' +
				description;
			String textBody =
				'Initial description entered via portal by ' +
				userEmail +
				':\n\n' +
				description;

			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D260000000XZFgCAO';
			if (cmfields.contains('rosco_owea_noreply__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea_noreply__c'))) {
					owea = String.valueOf(cm.get('rosco_owea_noreply__c'));
				}
			}

			if (nullOrEmpty(description) == false) {
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(owea);
				mail.setToAddresses(to);
				mail.setSubject(caseSubject);
				mail.setHtmlBody(htmlBody);
				mail.setPlainTextBody(textBody);
				if (!caseSubject.contains('ROSCOTESTCASE')) {
					Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
				}
			}
		} catch (Exception e) {
			System.debug('copyDescriptionToEmail: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}
}