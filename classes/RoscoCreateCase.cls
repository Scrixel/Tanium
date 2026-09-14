/**
 * @Business: RoscoCreateCase
 * @Date: 8/4/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7985    2024-05-14    Add Sub-Component Field
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c and resolve issues
 */
public with sharing class RoscoCreateCase {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@AuraEnabled
	public static String createCase(Map<String, Object> caseinfo, List<String> ccnodelete) {
		String ret = '';
		Case newcase;

		try {
			// Custom settings may override record type id
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			String recordTypeId = '0120e000000Dxi7AAC';
			if (cmfields.contains('rosco_case_recordtypeid__c')) {
				String tempId = String.valueOf(cm.get('rosco_case_recordtypeid__c'));
				if (tempId != null && tempId != '') {
					recordTypeId = tempId;
				}
			}

			if (String.valueOf(caseinfo.get('isFedCase')) == 'true') {
				recordTypeId = '0120e000000JPVsAAO';

				if (cmfields.contains('rosco_case_fedrecordtypeid__c')) {
					String tempFedId = String.valueOf(cm.get('rosco_case_fedrecordtypeid__c'));
					if (tempFedId != null && tempFedId != '') {
						recordTypeId = tempFedId;
					}
				}
			}

			if (String.valueOf(caseinfo.get('isCaseTypeInternal')) == 'true') {
				recordTypeId = '0120e000000JPqMAAW';

				if (cmfields.contains('rosco_case_internalrecordtypeid__c')) {
					String tempFedId = String.valueOf(cm.get('rosco_case_internalrecordtypeid__c'));
					if (tempFedId != null && tempFedId != '') {
						recordTypeId = tempFedId;
					}
				}
			}

			String contactId = String.valueOf(caseinfo.get('contactId'));
			if (contactId == '1') {
				contactId = '0030e00002Ln3ZHAAZ';
				if (cmfields.contains('rosco_case_defaultcontact__c')) {
					String tempContactId = String.valueOf(cm.get('rosco_case_defaultcontact__c'));
					if (tempContactId != null && tempContactId != '') {
						contactId = tempContactId;
					}
				}
			}

			String accountId = String.valueOf(caseinfo.get('accountId'));
			if (accountId == '1') {
				accountId = '0010e00001QJnXqAAL';
				if (cmfields.contains('rosco_case_defaultaccount__c')) {
					String tempAccountId = String.valueOf(cm.get('rosco_case_defaultaccount__c'));
					if (tempAccountId != null && tempAccountId != '') {
						accountId = tempAccountId;
					}
				}
			}

			String owea = '0D20e0000004DjCCAU';
			if (cmfields.contains('rosco_owea_support__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea_support__c'))) {
					owea = String.valueOf(cm.get('rosco_owea_support__c'));
				}
			}
			System.debug('owea:' + owea);

			String richtext = String.valueOf(caseinfo.get('richtext'));
			String plaintext = richtext.stripHtmlTags();
			String plaintextabbreviated = plaintext.left(1000);

			String description = String.valueOf(caseinfo.get('description'));
			String descriptionTxt = description;
			descriptionTxt = descriptionTxt.replaceAll('<', ' ');
			descriptionTxt = descriptionTxt.replaceAll('>', ' ');
			descriptionTxt = descriptionTxt.left(1000);

			String tags = String.valueOf(caseinfo.get('tags'));
			System.debug('tags:' + String.valueOf(tags));

			// Internal
			if (String.valueOf(caseinfo.get('isCaseTypeInternal')) == 'true') {
				tags = tags + ' NoOpenCloseEmail';
			}

			String mystatusdetails = '';
			if (String.valueOf(caseinfo.get('status_details')) != '--None--') {
				mystatusdetails = String.valueOf(caseinfo.get('status_details'));
			}

			String oppId = null;
			if (!nullOrEmpty(caseinfo.get('opportunity'))) {
				oppId = String.valueOf(caseinfo.get('opportunity'));
			}

			String escTeam = null;
			String escTier = null;
			String escReason = null;
			String escPod = null;
			if (!nullOrEmpty(caseinfo.get('escteam'))) {
				escteam = String.valueOf(caseinfo.get('escteam'));
				escTier = 'Level 2';
				escReason = descriptionTxt;
				escReason = escReason.stripHtmlTags();
				escPod = String.valueOf(caseinfo.get('pod'));
			}

			Integer severity = 3;
			if (!nullOrEmpty(caseinfo.get('severity'))) {
				String sev = String.valueOf(caseinfo.get('severity'));
				if (sev.containsIgnoreCase('1')) {
					severity = 1;
				} else if (sev.containsIgnoreCase('2')) {
					severity = 2;
				}
			}

			Datetime taniumResponse;
			if (tags.contains('NoOpenCloseEmail') == false) {
				if (!nullOrEmpty(richtext)) {
					taniumResponse = System.Datetime.now();
				}
			}

			String ownerId = UserInfo.getUserId();
			if (!nullOrEmpty(caseinfo.get('ownerId'))) {
				ownerId = String.valueOf(caseinfo.get('ownerId'));
			}

			String subComponent = '';
			if (String.valueOf(caseinfo.get('sub_component')) != '--None--') {
				subComponent = String.valueOf(caseinfo.get('sub_component'));
			}

			newcase = new Case(
				AccountId = accountId,
				Component_Version__c = String.valueOf(caseinfo.get('componentversion')),
				Component__c = String.valueOf(caseinfo.get('case_component')),
				Sub_Component__c = subComponent,
				ContactId = contactId,
				JIRA_ID__c = String.valueOf(caseinfo.get('jira')),
				OwnerId = ownerId,
				RecordTypeId = recordTypeId,
				Severity_Community__c = String.valueOf(severity),
				Status = String.valueOf(caseinfo.get('status')),
				Status_Details__c = mystatusdetails,
				Opportunity__c = oppId,
				Subject = String.valueOf(caseinfo.get('subject')),
				tags__c = tags,
				Type = String.valueOf(caseinfo.get('case_type')),
				Description = descriptionTxt,
				Origin = 'Console',
				First_Response_Date__c = taniumResponse,
				Last_Response_Date__c = taniumResponse
			);
			insert newcase;
			String caseId = String.valueOf(newcase.Id);

			// Internal
			if (String.valueOf(caseinfo.get('isCaseTypeInternal')) == 'true') {
				String casePost =
					'<p><b>Description:</b> ' +
					descriptionTxt.replaceAll('\n', '<p>&nbsp;</p>') +
					'</p><p></p><p>&nbsp;</p>';
				casePost +=
					'<p><b>Type:</b> ' +
					String.valueOf(caseinfo.get('case_type')) +
					'</p><p></p><p>&nbsp;</p>';

				if (!nullOrEmpty(caseinfo.get('preferredTAMEmail'))) {
					casePost +=
						'<p><b>Preferred TAM:</b> ' +
						String.valueOf(caseinfo.get('preferredTAMEmail')) +
						'</p><p></p><p>&nbsp;</p>';
				} else {
					//casePost += '<p><b>Preferred TAM:</b> N/A</p><p></p><p>&nbsp;</p>';
				}

				if (!nullOrEmpty(caseinfo.get('escteam'))) {
					casePost +=
						'<p><b>SME Team:</b> ' +
						String.valueOf(caseinfo.get('escteam')) +
						'</p><p></p><p>&nbsp;</p>';
				} else {
					//casePost += '<p><b>SME Team:</b> N/A</p><p></p><p>&nbsp;</p>';
				}

				if (!nullOrEmpty(caseinfo.get('pod'))) {
					casePost +=
						'<p><b>Pod:</b> ' +
						String.valueOf(caseinfo.get('pod')) +
						'</p><p></p><p>&nbsp;</p>';
				} else {
					//casePost += '<p><b>Pod:</b> N/A</p><p></p><p>&nbsp;</p>';
				}

				if (!nullOrEmpty(caseinfo.get('optionalTime'))) {
					casePost +=
						'<p><b>Meeting Time:</b> ' +
						String.valueOf(caseinfo.get('optionalTime')) +
						'</p><p></p><p>&nbsp;</p>';
				} else {
					//casePost += '<p><b>Meeting Time:</b> N/A</p><p></p><p>&nbsp;</p>';
				}

				FeedItem fi = new FeedItem(
					Body = casePost,
					IsRichText = true,
					NetworkScope = 'AllNetworks',
					Type = 'TextPost',
					Visibility = 'InternalUsers',
					ParentId = newcase.Id
				);
				insert fi;

				if (escTier == null) {
					System.debug('Not an SME Engagement');
				} else {
					List<Map<String, String>> smes = new List<Map<String, String>>();
					RoscoEscalate.saveCase(
						caseId,
						'Level 2',
						String.valueOf(caseinfo.get('pod')),
						String.valueOf(caseinfo.get('escteam')),
						'',
						descriptionTxt,
						'(Presales SME Engagement)',
						'false',
						smes,
						new List<Map<String, String>>(),
						null,
						''
					);
				}
			}

			// Set Tags
			if (String.valueOf(caseinfo.get('isCaseTypeInternal')) == 'true') {
				RoscoTag.saveNewIndividualTag(
					caseId,
					'Legacy (String)',
					'NoOpenCloseEmail',
					'',
					'',
					'',
					'',
					'',
					''
				);
			}

			List<Case> theCase = [SELECT Subject, CaseNumber FROM Case WHERE Id = :caseId];

			if (
				tags.contains('NoOpenCloseEmail') == true ||
				String.valueOf(caseinfo.get('isCaseTypeInternal')) == 'true'
			) {
				System.debug('Will not send email...');
			} else {
				String ccrstring = String.valueOf(caseinfo.get('ccrstring'));
				RoscoCaseContactRole.setCcrViaString(ccrstring, caseId);

				// Send Email
				String caseSubject = '';
				String caseNumber = '';
				String caseThread = '';

				if (!thecase.IsEmpty()) {
					caseSubject = thecase[0].Subject;
					caseNumber = thecase[0].CaseNumber;
					caseThread = EmailMessages.getFormattedThreadingToken(thecase[0].Id);
				}
				//caseNumber = caseNumber.replaceAll('^[0][0][0]', '');

				caseSubject = RoscoUtility.getTrimmedSubject(caseSubject);
				if (!caseSubject.contains(String.valueOf(caseNumber))) {
					caseSubject = caseNumber + ':' + caseSubject;
				}

				richtext = richtext + '<br><html>' + caseThread + '</html>';

				List<String> cc = ccrstring.split(';');

				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(owea);
				mail.setReplyTo('support@tanium.com');
				String[] toAddresses = cc;
				mail.setToAddresses(toAddresses);
				mail.setSubject(caseSubject);
				mail.setHtmlBody(richtext);
				mail.setPlainTextBody(plaintext);
				if (!caseSubject.contains('ROSCOTESTCASE')) {
					Messaging.SendEmailResult[] results = Messaging.sendEmail(
						new List<Messaging.SingleEmailMessage>{ mail }
					);
					System.debug('results:' + results);
				}

				// Attach Email Message
				EmailMessage message = new EmailMessage(
					textBody = plaintext,
					htmlBody = richtext,
					subject = caseSubject,
					fromName = 'Tanium Support',
					fromAddress = 'support@tanium.com',
					ToAddress = ccrstring,
					IsExternallyVisible = true,
					relatedToId = caseId,
					incoming = false
				);
				insert message;
			}

			ret = String.valueOf(newcase.Id);
		} catch (Exception e) {
			System.debug('createCase exception:' + e.getMessage() + '\n' + e.getStackTraceString());
			if (!nullOrEmpty(newcase.Id)) {
				ret =
					'Case ' +
					String.valueOf(newcase.Id) +
					' created, however case processing failed:\n\n';
			} else {
				ret = 'Case was not created:\n\n';
			}
			ret +=
				String.valueOf('Message:\n' + e.getMessage()) +
				'\n\nStack:\n' +
				String.valueOf(e.getStackTraceString());
		}

		return ret;
	}

	/** getFedPlaceholderAccountId
	 * @return Map of init Info
	 */
	public static String getFedPlaceholderAccountId() {
		String ret = '0010e00001QJnXqAAL';

		try {
			String userId = String.valueOf(UserInfo.getUserId());

			String soql = 'SELECT Id FROM Account ' + 'WHERE Name = \'Federal Case Placeholder\'';

			System.debug('SOQL: ' + soql);
			List<Account> acct = Database.query(soql);

			if (acct.size() != 0) {
				ret = String.valueOf(acct[0].Id);
			}
		} catch (DmlException e) {
			System.debug('getFedPlaceholderAccountId:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getInitInfo
	 * @return Map of init Info
	 */
	@AuraEnabled
	public static Map<String, String> getInitInfo() {
		Map<String, String> ret = new Map<String, String>();

		try {
			if (isFedTAM() == true) {
				ret.put('isFedTam', 'true');

				ret.put('fedAccount', getFedPlaceholderAccountId());
				ret.put('currentUserContactId', getFedPlaceholderAccountId());
			} else {
				ret.put('isFedTam', 'false');
			}

			if (isTSETAM() == true) {
				ret.put('isTSETam', 'true');
			} else {
				ret.put('isTSETam', 'false');
			}
		} catch (DmlException e) {
			System.debug('getInitInfo:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** isFedTAM
	 * @return Map of init Info
	 */
	public static Boolean isFedTAM() {
		Boolean ret = false;

		try {
			String userId = String.valueOf(UserInfo.getUserId());

			String soql =
				'SELECT Id FROM GroupMember ' +
				'WHERE GroupId IN (SELECT Id FROM Group WHERE Name = \'Fed Cases\') ' +
				'AND UserOrGroupId = \'' +
				userId +
				'\'';

			System.debug('SOQL: ' + soql);
			List<GroupMember> grp = Database.query(soql);

			if (grp.size() != 0) {
				ret = true;
			}
		} catch (DmlException e) {
			System.debug('isFedTAM:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** isTSETAM
	 * @return Map of init Info
	 */
	public static Boolean isTSETAM() {
		Boolean ret = false;

		try {
			String userId = String.valueOf(UserInfo.getUserId());

			String soql =
				'SELECT Id FROM GroupMember ' +
				'WHERE GroupId IN (SELECT Id FROM Group WHERE Name = \'TSE Cases\') ' +
				'AND UserOrGroupId = \'' +
				userId +
				'\'';

			System.debug('SOQL: ' + soql);
			List<GroupMember> grp = Database.query(soql);

			if (grp.size() != 0) {
				ret = true;
			}
		} catch (DmlException e) {
			System.debug('isTSETAM:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}
}