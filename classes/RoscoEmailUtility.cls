/**
 * @Business: RoscoEmailUtility without sharing class - supports community app
 * @Date: 6/28/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7277    2024-02-23    Jason's last changes linked to ticket SCLOUD-723 plus layout changes by Tanium Dev Team
 * SS-7719    2024-05-30    Fix for duplicate case creation when replying to email thread
 * SS-8064    2024-05-31    Contact email to lowercase
 * SS-7236    2024-07-22    Updated method getCaseId, getOwnerId
 * SS-8749    2024-07-24    Updated method getOwnerId
 * SS-8718    2024-08-07    Updated method getCaseId
 * SS-8803    2024-08-24    Updated method getOwnerId
 * SS-9295    2024-10-03    Remove case assignment. Owner will be assigned via flow
 * SS-9622    2024-12-03    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-10083	  2025-01-24    Replace Case.ThreadId__c w/ Case.ThreadId_caseSensitive__c
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c and resolve issue
 * SS-13500   2026-07-27    Remove deprecated fields for project kondo group 2 contact
 */
public class RoscoEmailUtility {
	private static final Id TECH_PARTNER_RECTYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Case',
		'Technical_Partnerships'
	);

	public static void auditIncoming(Messaging.InboundEmail email) {
		try {
			String fromAddress = 'Undetermined';
			if (email.fromAddress != null) {
				fromAddress = email.fromAddress;
			}

			String subject = 'Undetermined';
			if (email.subject != null) {
				subject = email.subject;
			}
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Audit',
				'RoscoEmailUtility:auditIncoming()',
				1,
				'Informational',
				'Email recieved from: ' + fromAddress,
				'Email subject: ' + subject,
				'',
				''
			);
		} catch (Exception e) {
			System.debug('auditIncoming: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** checkAuthentication
	 * Determine if message can mapped to account
	 * not really authentication (easily spoofed)
	 * @param  rosco is a map object passed aroundx
	 * @param  email is email passed in via support@tanium.com
	 * @return void - rosco is passed by reference
	 */
	public static void checkAuthentication(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'checkAuthentication: checking people');
		try {
			if (rget(rosco, 'valid_contact_found') != 'true') {
				String fromaddress = rget(rosco, 'fromaddress');
				List<String> lFromAddress = fromaddress.split('@');
				if (
					!(lFromAddress[1].containsIgnoreCase('tanium.com') ||
					lFromAddress[1].containsIgnoreCase('taniumfed.com'))
				) {
					String soql =
						'SELECT Id ' +
						'FROM Site_User_Blacklisted_Domains__c  ' +
						'WHERE Name = \'' +
						lFromAddress[1] +
						'\' ' +
						'LIMIT 1';
					List<Site_User_Blacklisted_Domains__c> domains = new List<Site_User_Blacklisted_Domains__c>();
					if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
						domains = Database.query(soql);
					}
					if (!domains.isEmpty()) {
						rput(rosco, 'authenticated', 'false');
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'checkAuthentication: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** checkContacts
	 * For emails addresses that are not contacts, create
	 * @param  rosco Map passed by reference
	 */
	public static void checkContacts(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'checkContacts: reviewing contacts....');
		try {
			String people = rget(rosco, 'people');
			List<String> peoplelist = rget(rosco, 'people').split(';');
			String peopleClause = RoscoUtility.getCleanWhereClause(people);
			String soql =
				'SELECT Id,email,AccountId, MailingCountry,OtherCountry,Support_Option__c FROM Contact ' +
				'WHERE email IN (' +
				peopleClause +
				')';
			List<Contact> cs = new List<Contact>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				cs = Database.query(soql);
			}
			Map<String, String> mContact = new Map<String, String>();
			Map<String, String> mContactCountry = new Map<String, String>();
			List<String> lContactBlackListed = new List<String>();
			Map<String, String> mAccount = new Map<String, String>();
			if (!cs.isEmpty()) {
				for (Contact c : cs) {
					if (String.valueOf(c.Email).contains('@')) {
						c.Email = c.Email.toLowerCase();
						mContact.put(String.valueOf(c.Email), String.valueOf(c.Id));
						mAccount.put(String.valueOf(c.Email), String.valueOf(c.AccountId));
						String country = '';
						if (!nullOrEmpty(c.Support_Option__c)) {
							if (c.Support_Option__c.contains('Contact Level Blocklist')) {
								lContactBlackListed.add(String.valueOf(c.Email));
							}
							if (c.Support_Option__c.contains('Support Japanese')) {
								country = 'Japan';
							} else if (c.Support_Option__c.contains('Support English')) {
								country = 'EnglishGlobal';
							}
						}
						if (country == '') {
							if (!nullOrEmpty(c.MailingCountry)) {
								country = c.MailingCountry;
							}
							if (!nullOrEmpty(c.OtherCountry)) {
								if (country == '') {
									country = c.OtherCountry;
								} else {
									country += ' | ' + c.OtherCountry;
								}
							}
						}
						mContactCountry.put(String.valueOf(c.Email), country);
						rput(
							rosco,
							'roscolog',
							'checkContacts: existing contact ' +
							String.valueOf(c.Email) +
							' (' +
							String.valueOf(c.Id) +
							'/' +
							String.valueOf(c.AccountId) +
							')'
						);
					}
				}
			}

			if (rget(rosco, 'create_contacts') == 'true') {
				Integer checkContactsMaxCreate = Integer.valueOf(
					rget(rosco, 'check_contact_max_create')
				);
				Integer contactsCreated = 0;
				for (String p : peoplelist) {
					if (!mContact.containsKey(p) && (p.contains('@') == true)) {
						if (contactsCreated < checkContactsMaxCreate) {
							String accountid = rget(rosco, 'contact_placeholder');
							List<String> psplit = p.split('@');
							String pdomain = (psplit[1]);
							String paccount = rget(rosco, pdomain);
							if (paccount == '') {
								paccount = getAccountFromEmailDomain(pdomain);

								if (paccount != '') {
									accountid = paccount;
									rput(rosco, pdomain, accountid);
								}
							}
							Contact c2 = new Contact(
								Email = p,
								LastName = p.left(50),
								AccountId = accountid,
								HasOptedOutOfEmail = true,
								Sales_Acceptance__c = 'New'
							);
							insert c2;
							mContact.put(String.valueOf(c2.Email), String.valueOf(c2.Id));
							mAccount.put(String.valueOf(c2.Email), String.valueOf(c2.AccountId));
							rput(
								rosco,
								'roscolog',
								'checkContacts: new contact for ' +
								p +
								' (' +
								String.valueOf(c2.Id) +
								')'
							);
							contactsCreated += 1;
						} else {
							rput(
								rosco,
								'roscolog',
								'checkContacts: ' +
								p +
								' not created as contact due to check_contact_max_create reached'
							);
						}
					}
				}
			} else {
				for (String p : peoplelist) {
					if (!mContact.containsKey(p) && (p.contains('@') == true)) {
						rput(rosco, 'roscolog', 'checkContacts: skipped creating new contact for ' + p);
					}
				}
			}
			if (rget(rosco, 'caseid') == '') {
				String primary_case_contact = '';
				for (String p : peoplelist) {
					if (mContact.containsKey(p) && (p.contains('@') == true)) {
						if (primary_case_contact.length() == 0) {
							if (!rget(rosco, 'exclude_account').contains(mAccount.get(p))) {
								rput(
									rosco,
									'roscolog',
									'checkContacts: Selected ' +
									p +
									' as case contact'
								);
								primary_case_contact = p;
								rput(rosco, 'case_contactid', mContact.get(p));
								rput(rosco, 'case_accountid', mAccount.get(p));
								rput(rosco, 'valid_contact_found', 'true');
								rput(rosco, 'case_country', mContactCountry.get(p));
								if (lContactBlackListed.contains(p)) {
									rput(rosco, 'authenticated', 'false');
								}
							}
						}
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'checkContacts: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** checkMailApi
	 * Determine if message can mapped to account
	 * @param  rosco is a map object passed around
	 * @param  email is email passed in via support@tanium.com
	 * @return none - rosco is passed by reference
	 */
	public static void checkMailApi(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'checkMailApi: checking if mail api being used...');
		try {
			if (rget(rosco, 'caseid') == '') {
				if (rget(rosco, 'fromaddress').containsIgnoreCase('@tanium.com')) {
					String tanOwnerEmail = getMailApiTanOwner(
						rosco,
						'(#[Tt][Aa][Nn][Oo][Ww][Nn][Ee][Rr](.*?)[Cc][Oo][Mm])'
					);
					if (!nullOrEmpty(tanOwnerEmail)) {
						String soql =
							'SELECT Id FROM User ' +
							'WHERE Email= \'' +
							tanOwnerEmail +
							'\' ' +
							'AND UserType= \'Standard\' ' +
							'LIMIT 1';
						List<User> users = new List<User>();
						if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
							users = Database.query(soql);
						}
						String tanOwnerId = '';
						if (users.size() != 0) {
							rput(rosco, 'mailapi_case_ownerid', users[0].Id);
							rput(rosco, 'mailapi_case_status', 'In Progress - Troubleshooting');
							rput(rosco, 'case_origin', 'Email-Tanowner');
						} else {
							rput(rosco, 'notifyTanOwnerOption', rget(rosco, 'fromaddress'));
						}
					} else {
						rput(rosco, 'notifyTanOwnerOption', rget(rosco, 'fromaddress'));
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'checkMailApi: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** checkSpam
	 * Use regex on fromAddress and Email text to look for known SPAM
	 * @param  rosco is a map object passed around
	 * @param  email is email passed in via support@tanium.com
	 * @return none - rosco is passed by reference
	 */
	public static void checkSpam(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'checkSpam: checking if email is SPAM...');
		try {
			if (rget(rosco, 'fromaddress_original') == 'support@tanium.com') {
				rput(rosco, 'spam', 'true');
				rput(rosco, 'subject', 'superflous spam: ' + rget(rosco, 'subject'));
				rput(
					rosco,
					'roscolog',
					'checkSpam: marked email as SPAM - from and to: support@tanium'
				);
			} else if (rosco.get('subject').left(16) == 'Automatic reply:') {
				rput(rosco, 'spam', 'true');
				rput(rosco, 'subject', 'automatic reply spam: ' + rget(rosco, 'subject_original'));
				rput(
					rosco,
					'roscolog',
					'checkSpam: marked email as SPAM - Automatic Reply: in first 16 characters'
				);
			} else {
				String fromre = rget(rosco, 'spam_fromaddress_re');
				String fromaddress = rget(rosco, 'fromaddress');
				if (Pattern.matches(fromre, fromaddress)) {
					String textre = rget(rosco, 'spam_textbody_re');
					String text = rget(rosco, 'textbody');
					if (Pattern.matches(textre, text)) {
						rput(rosco, 'spam', 'true');
						rput(rosco, 'subject', 'potental spam: ' + rget(rosco, 'subject'));
						rput(rosco, 'roscolog', 'checkSpam: marked email as SPAM');
					} else {
						rput(rosco, 'roscolog', 'checkSpam: not SPAM (text body does not match)');
					}
				} else {
					rput(rosco, 'roscolog', 'checkSpam: not SPAM (from address does not match)');
				}
			}
		} catch (Exception e) {
			rput(rosco, 'roscolog', 'checkSpam: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	public static String convertHTML(Map<String, String> rosco, String htmlBody) {
		String ret = '';
		try {
			String expression = '<img.*?>';
			Pattern imgThreadIdPattern = Pattern.compile(expression);
			RoscoRowIterator hiter = new RoscoRowIterator(htmlbody, '\n');
			String hrow;
			do {
				if (hiter.hasNext())
					hrow = hiter.next();
				Matcher matcher = imgThreadIdPattern.matcher(hrow);
				if (matcher.find()) {
					String getImgTagWithBase64 = convertHTMLGetImgTagWithBase64(rosco, matcher.group(0));
					ret += hrow.replace(matcher.group(0), getImgTagWithBase64) + '\n';
				} else {
					ret += hrow + '\n';
				}
			} while (hiter.hasNext());
		} catch (Exception e) {
			rput(rosco, 'roscolog', 'convertHTML: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	public static String convertHTMLGetAttachmentBase64(
		Map<String, String> rosco,
		String attachmentId
	) {
		String ret = '';
		try {
			String soql =
				'SELECT Body ' +
				'FROM Attachment ' +
				'WHERE Id = \'' +
				attachmentId +
				'\' ' +
				'LIMIT 1';
			List<Attachment> aAtt = new List<Attachment>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				aAtt = Database.query(soql);
			}
			if (aAtt.size() > 0) {
				ret = EncodingUtil.base64Encode(aAtt[0].Body);
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'convertHTMLGetAttachmentBase64: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		return ret;
	}

	public static String convertHTMLGetImgTagWithBase64(Map<String, String> rosco, String imgTag) {
		String ret = imgTag;
		try {
			String expression = 'src=".*?"';
			Pattern srcPattern = Pattern.compile(expression);
			Matcher matcher = srcPattern.matcher(imgTag);
			if (matcher.find()) {
				String srcAttribute = matcher.group(0);
				String attachmentId = srcAttribute.right(16);
				attachmentId = attachmentId.replace('"', '');
				String base64Attachment = convertHTMLGetAttachmentBase64(rosco, attachmentId);
				if (base64Attachment != '') {
					ret = imgTag.replace(
						srcAttribute,
						'src="data:image/png;base64,' +
						base64Attachment +
						'"'
					);
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'convertHTMLGetImgTagWithBase64: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		return ret;
	}

	/** createCase
	 * Create a Service Cloud case
	 * @param  rosco is a map object passed around
	 * @return void - rosco is passed by reference
	 */
	public static void createCase(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'createCase: creating...');
		try {
			Decimal sev = decimal.valueOf(rget(rosco, 'case_severity'));
			Case newcase = new Case(
				AccountId = rget(rosco, 'case_accountid'),
				ContactId = rget(rosco, 'case_contactid'),
				Component__c = rget(rosco, 'case_component'),
				Component_Version__c = rget(rosco, 'case_version'),
				RecordTypeId = rget(rosco, 'case_recordtypeid'),
				Severity_Community__c = String.valueOf(integer.valueOf(rget(rosco, 'case_severity'))),
				Status = rget(rosco, 'case_status'),
				Subject = rget(rosco, 'subject'),
				Type = rget(rosco, 'case_type'),
				Description = String.valueOf(rget(rosco, 'textbody')).left(1000),
				Origin = rget(rosco, 'case_origin')
			);

			if (Test.isRunningTest()) {
				newcase.OwnerId = Utility.getQueueId('Service Cloud Tanium');
			}

			insert newcase;
			Savepoint savepnt = Database.setSavepoint();
			rput(rosco, 'caseid', newcase.Id);
			rput(rosco, 'new_case', 'true');
			rput(rosco, 'roscolog', 'createCase:' + String.valueOf(newcase.id) + ' created');
		} catch (Exception e) {
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', '--- createCase Exception');
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', 'message:' + e.getMessage());
			rput(rosco, 'roscolog', 'StackTraceString:' + e.getStackTraceString());
			rput(rosco, 'roscolog', 'AccountId:' + rget(rosco, 'case_accountid'));
			rput(rosco, 'roscolog', 'ContactId:' + rget(rosco, 'case_contactid'));
			rput(rosco, 'roscolog', 'Component__c:' + rget(rosco, 'case_component'));
			rput(rosco, 'roscolog', 'Component_Version__c:' + rget(rosco, 'case_version'));
			rput(rosco, 'roscolog', 'OwnerId:' + rget(rosco, 'case_ownerid'));
			rput(rosco, 'roscolog', 'RecordTypeId:' + rget(rosco, 'case_recordtypeid'));
			rput(
				rosco,
				'roscolog',
				'Severity_Community__c:' + String.valueOf(integer.valueOf(rget(rosco, 'case_severity')))
			);
			rput(rosco, 'roscolog', 'Status:' + rget(rosco, 'case_status'));
			rput(rosco, 'roscolog', 'Subject:' + rget(rosco, 'subject'));
			rput(rosco, 'roscolog', 'Type:' + rget(rosco, 'case_type'));
			rput(rosco, 'roscolog', 'Origin:' + rget(rosco, 'case_origin'));
			rput(rosco, 'roscolog', 'Description:' + rget(rosco, 'textbody').left(1000));
			rput(rosco, 'roscolog', '--------------------------------------------------');
		}
	}

	/** createEmailMessage
	 * createEmailMessage description
	 * @param  email    email description
	 * @param  envelope envelope description
	 * @param  rosco    rosco description
	 * @return          return description
	 */
	public static void createEmailMessage(
		Map<String, String> rosco,
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		rput(rosco, 'roscolog', 'createEmailMessage: creating...');
		try {
			Boolean visible = false;
			if (rget(rosco, 'IsExternallyVisible') == 'true') {
				visible = true;
			}
			String caseid = rget(rosco, 'caseid');
			if (caseid == '') {
				caseid = rget(rosco, 'catch_all_case');
				rput(
					rosco,
					'roscolog',
					'createEmailMessage: catch all case (' +
					caseid +
					') will be used'
				);
			}
			List<Id> att = new List<Id>();
			EmailMessage message = new EmailMessage(
				textBody = rget(rosco, 'textbody'),
				htmlBody = rget(rosco, 'htmlbody'),
				subject = rget(rosco, 'subject'),
				fromName = rget(rosco, 'fromname'),
				fromAddress = rget(rosco, 'fromaddress'),
				ToAddress = rget(rosco, 'toaddresses'),
				CcAddress = rget(rosco, 'ccaddresses'),
				Headers = String.valueOf(email.headers),
				MessageIdentifier = rget(rosco, 'references'),
				IsExternallyVisible = visible,
				relatedToId = caseid,
				incoming = true
			);
			insert message;
			rput(rosco, 'messageid', message.Id);
			rput(rosco, 'roscolog', 'createEmailMessage: ' + message.id + ' created');
			Map<String, Attachment> attachmentsMap = createEmailMessageAttachments(email, message.id);
			if (attachmentsMap.size() > 0) {
				insert attachmentsMap.values();
			}
			String attachmentDownloadURL = rget(rosco, 'atturl');
			for (String contentId : attachmentsMap.keySet()) {
				String cid = contentId.replace('<', '').replace('>', '');
				String url =
					attachmentDownloadURL + String.valueOf(attachmentsMap.get(contentId).id).left(15);
				rput(
					rosco,
					'roscolog',
					'createEmailMessage: replacing image references in html body: cid=' +
					cid +
					', url=' +
					url
				);
				message.textBody = message.textBody.replaceAll('cid:' + cid, url);
				message.htmlBody = message.htmlBody.replaceAll('cid:' + cid, url);
			}
			update message;
			rput(rosco, 'inbound_email_result_success', 'true');
		} catch (Exception e) {
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', '--- createEmailMessage Exception');
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', 'message:' + e.getMessage());
			rput(rosco, 'roscolog', 'StackTraceString:' + e.getStackTraceString());
			rput(rosco, 'roscolog', 'subject:' + rget(rosco, 'subject'));
			rput(rosco, 'roscolog', 'fromName:' + rget(rosco, 'fromname'));
			rput(rosco, 'roscolog', 'fromAddress:' + rget(rosco, 'fromaddress'));
			rput(rosco, 'roscolog', 'ToAddress:' + rget(rosco, 'toaddresses'));
			rput(rosco, 'roscolog', 'CcAddress:' + rget(rosco, 'ccaddresses'));
		}
		rput(rosco, 'inbound_email_result_success', 'true');
	}

	/** createEmailMessageAttachments
	 *  description
	 * @param  email    email description
	 * @param  parentId parentId description
	 * @return          return description
	 */
	private static Map<String, Attachment> createEmailMessageAttachments(
		Messaging.InboundEmail email,
		ID parentId
	) {
		Map<String, Attachment> attachmentsMap = new Map<String, Attachment>();
		try {
			Integer noHeaderCount = 0;
			if (email.binaryAttachments != null) {
				for (
					Messaging.InboundEmail.BinaryAttachment binaryAttachment : email.binaryAttachments
				) {
					String contentId = getHeaderValue(binaryAttachment.headers, 'Content-ID');
					if (String.isBlank(contentId)) {
						contentId = 'no-content-id-header-' + noHeaderCount++;
					}
					attachmentsMap.put(
						contentId,
						new Attachment(
							name = binaryAttachment.fileName,
							body = binaryAttachment.body,
							contentType = binaryAttachment.mimeTypeSubType,
							parentId = parentId
						)
					);
				}
			}
			if (email.textAttachments != null) {
				for (Messaging.InboundEmail.TextAttachment textAttachment : email.textAttachments) {
					String contentId = getHeaderValue(textAttachment.headers, 'Content-ID');
					if (String.isBlank(contentId)) {
						contentId = 'no-content-id-header-' + noHeaderCount++;
					}
					attachmentsMap.put(
						contentId,
						new Attachment(
							name = textAttachment.fileName,
							body = Blob.valueOf(textAttachment.body),
							contentType = textAttachment.mimeTypeSubType,
							parentId = parentId
						)
					);
				}
			}
		} catch (Exception e) {
			System.debug(
				'createEmailMessageAttachments: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		return attachmentsMap;
	}

	/** getAccountFromEmailDomain
	 * Using email address finds account id
	 * @param  String email address - foo@bar.com
	 * @return String AccountId
	 */
	public static String getAccountFromEmailDomain(String edomain) {
		String ret = '';
		try {
			edomain = edomain.toLowerCase();
			List<rosco_domain__c> domains = new List<rosco_domain__c>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				domains = [
					SELECT Account__c
					FROM rosco_domain__c
					WHERE
						user_automation__c IN ('Account Only', 'Support KB', '\tSupport Case')
						AND name = :edomain
				];
			}
			if (!domains.isEmpty()) {
				ret = domains[0].Account__c;
			} else {
				Case_Management__c cm = Case_Management__c.getInstance();
				Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
				String hardcoded = '0010e00001RcgMsAAJ';
				String settingsacct = '';
				if (cmfields.contains('rosco_case_accountid__c')) {
					settingsacct = String.valueOf(cm.get('rosco_case_accountid__c'));
				}
				if (nullOrEmpty(settingsacct) == false) {
					ret = settingsacct;
				} else {
					ret = hardcoded;
				}
			}
		} catch (Exception e) {
			System.debug(
				'getAccountFromEmailDomain: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		return ret;
	}

	/** getAccountFromEmail
	 * Using email address finds account id
	 * @param  String email address - foo@bar.com
	 * @return String AccountId
	 */
	public static String getAccountFromEmail(String emailaddress) {
		String ret = '';
		try {
			List<String> lemailaddress = emailaddress.split('@');
			if (lemailaddress.size() == 2) {
				String edomain = (lemailaddress[1]);
				edomain = edomain.toLowerCase();
				List<rosco_domain__c> domains = [
					SELECT Account__c
					FROM rosco_domain__c
					WHERE
						user_automation__c IN ('Account Only', 'Support KB', '\tSupport Case')
						AND name = :edomain
				];
				if (!domains.isEmpty()) {
					ret = domains[0].Account__c;
				} else {
					Case_Management__c cm = Case_Management__c.getInstance();
					Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap()
						.keySet();

					String hardcoded = '0010e00001RcgMsAAJ';
					String settingsacct = '';
					if (cmfields.contains('rosco_case_accountid__c')) {
						settingsacct = String.valueOf(cm.get('rosco_case_accountid__c'));
					}
					if (nullOrEmpty(settingsacct) == false) {
						ret = settingsacct;
					} else {
						ret = hardcoded;
					}
				}
			}
		} catch (Exception e) {
			System.debug('getAccountFromEmail: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getAccountId
	 *  Based on "People" which is just From/To/CC - figure out what account
	 *  this email is from based on which accounts those contacts are a member of
	 *  @param  rosco map
	 *  @return the account id as a string
	 */
	public static String getAccountId(Map<String, String> rosco) {
		String ret = '';
		rput(rosco, 'roscolog', 'getAccountId: looking for account...');
		try {
			String people = rget(rosco, 'people');
			String peopleClause = RoscoUtility.getCleanWhereClause(people);
			String soql =
				'SELECT AccountId,Email FROM Contact ' +
				'WHERE AccountId NOT IN (' +
				rget(rosco, 'exclude_account') +
				')' +
				'AND email IN (' +
				peopleClause +
				')';
			List<Contact> contacts = new List<Contact>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				contacts = Database.query(soql);
			}
			String fromAddress = rget(rosco, 'fromaddress');
			if (!contacts.isEmpty()) {
				for (Contact c : contacts) {
					String aid = c.AccountId;
					if (Pattern.matches('^001[a-zA-Z0-9]{15}$', aid)) {
						if (c.Email.toLowerCase() == fromAddress.toLowerCase()) {
							ret = aid;
						} else if (ret == '') {
							ret = aid;
						}
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'getAccountId: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		return ret;
	}

	/** getMailApiTanOwner
	 * getMailApiTanOwner description
	 */
	private static String getMailApiTanOwner(Map<String, String> rosco, String expression) {
		rput(
			rosco,
			'roscolog',
			'getMailApiTanOwner: looking for tanowner in email with expression' +
			String.valueOf(expression)
		);
		String ret = '';
		if (nullOrEmpty(expression)) {
			return ret;
		}
		try {
			Pattern tanOwnerPattern = Pattern.compile(expression);
			if (ret == '') {
				String textbody = rget(rosco, 'textbody_original');
				RoscoRowIterator titer = new RoscoRowIterator(textbody, '\n');
				String trow;
				do {
					if (titer.hasNext())
						trow = titer.next();
					Matcher matcher2 = tanOwnerPattern.matcher(trow.left(1000));
					if (matcher2.find()) {
						ret = matcher2.group(0);
					}
				} while (titer.hasNext());
				if (ret == '') {
					rput(rosco, 'roscolog', 'getMailApiTanOwner: tanowner not found in textbody');
				} else {
					rput(rosco, 'roscolog', 'getMailApiTanOwner: tanowner found in textbody');
				}
			}
			if (ret == '') {
				String htmlbody = rget(rosco, 'htmlbody_original_stripped');
				RoscoRowIterator hiter = new RoscoRowIterator(htmlbody, '\n');
				String hrow;
				do {
					if (hiter.hasNext())
						hrow = hiter.next();
					Matcher matcher3 = tanOwnerPattern.matcher(hrow.left(1000));
					if (matcher3.find()) {
						ret = matcher3.group(0);
					}
				} while (hiter.hasNext());
				if (ret == '') {
					rput(rosco, 'roscolog', 'getMailApiTanOwner: tanowner not found in htmlbody');
				} else {
					rput(rosco, 'roscolog', 'getMailApiTanOwner: tanowner found in htmlbody');
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'getMailApiTanOwner: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		ret = ret.toLowerCase();
		ret = ret.replace('#tanowner:', '');
		ret = ret.trim();
		return ret;
	}

	/** getCaseId
	 * getCaseId description
	 * @param  email email description
	 * @param  rosco rosco description
	 * @return       return description
	 */
	public static void getCaseId(Map<String, String> rosco, Messaging.InboundEmail email) {
		Boolean techPartnerCase = false;
		Boolean closedCase = false;
		Id caseId;
		String casenumber;
		Set<String> closedStatuses = new Set<String>{ 'Closed', 'Closed as Duplicate' };

		try {
			if (rget(rosco, 'header_based_matching') == 'true') {
				try {
					caseId = EmailMessages.getRecordIdFromEmail(
						email.subject,
						email.plainTextBody,
						email.htmlBody
					);
				} catch (Exception e) {
					rput(
						rosco,
						'roscolog',
						'getRecordIdFromEmail: ' +
						e.getMessage() +
						'\n' +
						e.getStackTraceString()
					);
				}
				if (caseId == null) {
					try {
						caseId = Cases.getCaseIdFromEmailHeaders(email.headers);
					} catch (Exception e) {
						rput(
							rosco,
							'roscolog',
							'getCaseIdFromEmailHeaders: ' +
							e.getMessage() +
							'\n' +
							e.getStackTraceString()
						);
					}
				} else {
					Case[] casethreads = [
						SELECT Id, CaseNumber, Status, AccountId, OwnerId, RecordTypeId
						FROM Case
						WHERE Id = :caseId
					];
					for (Case casethread : casethreads) {
						if (closedStatuses.contains(casethread.Status)) {
							closedCase = true;
						}
						if (casethread.RecordTypeId == TECH_PARTNER_RECTYPE_ID) {
							techPartnerCase = true;
						}
					}
					if (closedCase) {
						casenumber = casethreads[0].CaseNumber;
						casenumber = casenumber.replaceAll('^[0][0][0]', '');
						rput(rosco, 'prior_closed_case_number', casenumber);
						stripThreadIdFromEmail(rosco);
						String blurb =
							'Note: A reference id associated with closed case (' +
							casenumber +
							') ';
						blurb += 'has been detected and removed';
						rput(rosco, 'casepost', blurb);
						if (techPartnerCase) {
							rput(rosco, 'case_recordtypeid', TECH_PARTNER_RECTYPE_ID);
						}
					} else {
						String threadId = EmailMessages.getFormattedThreadingToken(casethreads[0].Id);
						rput(rosco, 'threadid', threadId);
						rput(rosco, 'caseid', casethreads[0].Id);
						rput(rosco, 'casenumber', casethreads[0].CaseNumber);
						rput(rosco, 'case_ownerid', casethreads[0].OwnerId);
						rput(rosco, 'case_accountid', casethreads[0].AccountId);
						rput(rosco, 'caseid_found_via_header', 'true');
					}
				}
			}

			if (rget(rosco, 'caseid') == '') {
				// Try to find the Case ID using threading tokens in email attributes.
				Id caseRecId = EmailMessages.getRecordIdFromEmail(
					email.subject,
					email.plainTextBody,
					email.htmlBody
				);

				// If we haven't found the Case ID, try finding it using headers.
				if (caseRecId == null) {
					caseRecId = Cases.getCaseIdFromEmailHeaders(email.headers);
				}

				if (caseRecId != null) {
					Case caseRec = [
						SELECT Id, CaseNumber, Status, AccountId, OwnerId, RecordTypeId
						FROM Case
						WHERE Id = :caseRecId
					];

					if (closedStatuses.contains(caseRec.Status)) {
						closedCase = true;
					}
					if (caseRec.RecordTypeId == TECH_PARTNER_RECTYPE_ID) {
						techPartnerCase = true;
					}

					if (closedCase) {
						casenumber = caseRec.CaseNumber;
						casenumber = casenumber.replaceAll('^[0][0][0]', '');
						rput(rosco, 'prior_closed_case_number', casenumber);
						stripThreadIdFromEmail(rosco);
						String blurb =
							'Note: A reference id associated with closed case (' +
							casenumber +
							') ';
						blurb += 'has been detected and removed';
						rput(rosco, 'casepost', blurb);
						if (techPartnerCase) {
							rput(rosco, 'case_recordtypeid', TECH_PARTNER_RECTYPE_ID);
						}
					} else {
						String threadId = EmailMessages.getFormattedThreadingToken(caseRec.Id);
						rput(rosco, 'threadid', threadId);
						rput(rosco, 'caseid', caseRec.Id);
						rput(rosco, 'casenumber', caseRec.CaseNumber);
						rput(rosco, 'case_ownerid', caseRec.OwnerId);
						rput(rosco, 'case_accountid', caseRec.AccountId);
						rput(rosco, 'caseid_found_via_thread', 'true');
					}
				}
			}

			if (rget(rosco, 'caseid') == '') {
				String caseNumberRegEx = '[0-9]{8}';
				Pattern caseNumberPattern = Pattern.compile(caseNumberRegEx);
				Matcher matcher = caseNumberPattern.matcher(rget(rosco, 'subject_original'));

				if (matcher.find()) {
					caseNumber = matcher.group(0);
					Case[] casesInSubject = [
						SELECT Id, CaseNumber, Status, AccountId, OwnerId, RecordTypeId
						FROM Case
						WHERE CaseNumber = :caseNumber
					];

					for (Case caseInSubject : casesInSubject) {
						if (closedStatuses.contains(caseInSubject.Status)) {
							closedCase = true;
						}
						if (caseInSubject.RecordTypeId == TECH_PARTNER_RECTYPE_ID) {
							techPartnerCase = true;
						}
					}
					if (!casesInSubject.isEmpty()) {
						if (closedCase) {
							casenumber = casesInSubject[0].CaseNumber;
							casenumber = casenumber.replaceAll('^[0][0][0]', '');
							rput(rosco, 'prior_closed_case_number', casenumber);
							stripThreadIdFromEmail(rosco);
							String blurb =
								'Note: A reference id associated with closed case (' +
								casenumber +
								') ';
							blurb += 'has been detected and removed';
							rput(rosco, 'casepost', blurb);
							if (techPartnerCase) {
								rput(rosco, 'case_recordtypeid', TECH_PARTNER_RECTYPE_ID);
							}
						} else {
							String threadId = EmailMessages.getFormattedThreadingToken(
								casesInSubject[0].Id
							);
							rput(rosco, 'threadid', threadId);
							rput(rosco, 'caseid', casesInSubject[0].Id);
							rput(rosco, 'casenumber', casesInSubject[0].CaseNumber);
							rput(rosco, 'case_ownerid', casesInSubject[0].OwnerId);
						}
					}
				}
			}

			String aid = '';
			List<String> accountids = new List<String>();
			if (rget(rosco, 'caseid') == '') {
				aid = getAccountId(rosco);
				if (Pattern.matches('^001[a-zA-Z0-9]{15}$', aid)) {
					rput(rosco, 'case_accountid', aid);
					accountids.add(aid);
				}
			}

			if (rget(rosco, 'caseid') == '' && aid != '') {
				for (String accountid : accountids) {
					String caseLimit = rget(rosco, 'dup_check_multiple_case_limit');
					if (Pattern.matches('.*[0-9]{5}.*', rget(rosco, 'subject'))) {
						String soql =
							'SELECT Id, ' +
							'CaseNumber, ' +
							'OwnerId ' +
							'FROM Case ' +
							'WHERE Status != \'Closed\' ' +
							'AND Status != \'Closed as Duplicate\' ' +
							'AND AccountId = \'' +
							accountid +
							'\' ' +
							'LIMIT ' +
							caseLimit;
						List<Case> caseRecords = new List<Case>();
						if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
							caseRecords = Database.query(soql);
						}
						if (caseRecords.size() > 0) {
							for (Case cas : caseRecords) {
								String threadId = EmailMessages.getFormattedThreadingToken(cas.Id);
								String casenum = cas.CaseNumber.replaceFirst('^0+', '');
								if (rget(rosco, 'subject').contains(casenum)) {
									rput(rosco, 'threadid', threadId);
									rput(rosco, 'caseid', cas.Id);
									rput(rosco, 'casenumber', cas.CaseNumber);
									rput(rosco, 'case_ownerid', cas.OwnerId);
									rput(rosco, 'roscolog', 'getCaseId: ' + cas.Id + ' found via subject');
								}
							}
						}
					}
				}
			}
			if (rget(rosco, 'caseid') == '' && aid != '') {
				rput(
					rosco,
					'roscolog',
					'getCaseId: Searching for matching subject and body in previous case email...'
				);
				for (String accountid : accountids) {
					String caseLimit = rget(rosco, 'dup_check_multiple_case_limit');
					String dupcharget = rget(rosco, 'dupchar');
					Integer dupchar = Integer.valueOf(dupcharget);
					String emailLimit = rget(rosco, 'dup_check_multiple_email_limit');
					String soql2 =
						'SELECT Id, Subject, ParentId, TextBody, HtmlBody ' +
						'FROM EmailMessage ' +
						'WHERE ParentId IN (' +
						'SELECT Id ' +
						'FROM Case ' +
						'WHERE Status != \'Closed\' ' +
						'AND Status != \'Closed as Duplicate\' ' +
						'AND AccountId = \'' +
						accountid +
						'\') ' +
						'AND Subject LIKE \'%' +
						rosco.get('subject') +
						'%\' ' +
						'ORDER BY CreatedDate DESC ' +
						'LIMIT ' +
						emailLimit;
					List<EmailMessage> existingemails = new List<EmailMessage>();
					if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
						existingemails = Database.query(soql2);
					}
					if (existingemails.size() > 0) {
						String incomingSubject = rget(rosco, 'subject');
						incomingSubject = RoscoUtility.getTrimmedSubject(incomingSubject);
						String incomingSubject2 = incomingSubject.replaceAll('^\\[.*\\]', '');
						incomingSubject2 = incomingSubject2.replaceAll('^\\{.*\\}', '');
						incomingSubject2 = incomingSubject2.trim();
						incomingSubject2 = incomingSubject2.replaceAll('^:', '');
						incomingSubject2 = incomingSubject2.trim();
						for (EmailMessage existingemail : existingemails) {
							if (existingemail.Subject != null) {
								String existingSubject = RoscoUtility.getTrimmedSubject(
									existingemail.Subject
								);
								String existingSubject2 = existingSubject.replaceAll('^\\[.*\\]', '');
								existingSubject2 = existingSubject2.replaceAll('^\\{.*\\}', '');
								existingSubject2 = existingSubject2.trim();
								existingSubject2 = existingSubject2.replaceAll('^:', '');
								existingSubject2 = existingSubject2.trim();
								if (
									(existingSubject == incomingSubject) ||
									(existingSubject2 == incomingSubject2)
								) {
									String extext = existingemail.TextBody;
									if (extext == null) {
										extext = '';
									}
									String exhtml = existingemail.HtmlBody;
									if (exhtml == null) {
										exhtml = '';
									}
									exhtml = exhtml.stripHtmlTags();
									if (extext.length() > dupchar) {
										if (rget(rosco, 'textbody').contains(extext.left(dupchar))) {
											rput(rosco, 'caseid', String.valueOf(existingemail.ParentId));
											rput(
												rosco,
												'roscolog',
												'getCaseId: found ' +
												String.valueOf(existingemail.ParentId) +
												' via text body'
											);
										} else {
											String intext = rget(rosco, 'textbody');
											intext = intext.replace('>', '');
											intext = intext.replace('\n', '');
											extext = intext.replace('>', '');
											extext = extext.replace('\n', '');
											if (intext.contains(extext.left(dupchar))) {
												rput(rosco, 'caseid', String.valueOf(existingemail.ParentId));
												rput(
													rosco,
													'roscolog',
													'getCaseId: found ' +
													String.valueOf(existingemail.ParentId) +
													' via text body (trimmed)'
												);
											}
										}
									}
									if (exhtml.length() > dupchar) {
										String inhtml = rget(rosco, 'htmlbody');
										inhtml = inhtml.stripHtmlTags();
										if (inhtml.contains(exhtml.left(dupchar))) {
											rput(rosco, 'caseid', String.valueOf(existingemail.ParentId));
											rput(
												rosco,
												'roscolog',
												'getCaseId: found ' +
												String.valueOf(existingemail.ParentId) +
												' via html body'
											);
										}
									}
								}
							}
						}
					}
				}
			}
		} catch (Exception e) {
			rput(rosco, 'roscolog', 'getCaseId: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** getHeaderValue
	 * getHeaderValue description
	 * @param  headers headers description
	 * @param  name    name description
	 * @return         return description
	 */
	private static String getHeaderValue(List<Messaging.InboundEmail.Header> headers, String name) {
		String value = null;
		try {
			if (headers != null) {
				for (Messaging.InboundEmail.Header header : headers) {
					if (header.name == name) {
						value = header.value;
						break;
					}
				}
			}
		} catch (Exception e) {
			System.debug('getHeaderValue: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return value;
	}

	/** getThreadIdFromEmail
	 * getThreadIdFromEmail description
	 * @param  email email description
	 * @return       return description
	 */
	@TestVisible
	private static String getThreadIdFromEmail(Map<String, String> rosco, String expression) {
		rput(
			rosco,
			'roscolog',
			'getThreadIdFromEmail: looking for thread id in email with expression' +
			String.valueOf(expression)
		);
		String ret = '';
		if (nullOrEmpty(expression)) {
			return ret;
		}
		try {
			Pattern caseThreadIdPattern = Pattern.compile(expression);
			Matcher matcher = caseThreadIdPattern.matcher(rget(rosco, 'subject_original'));
			if (matcher.find()) {
				ret = matcher.group(0);
				rput(rosco, 'roscolog', 'getThreadIdFromEmail: thread id found in subject');
			} else {
				rput(rosco, 'roscolog', 'getThreadIdFromEmail: thread id not found in subject');
			}
			if (ret == '') {
				String textbody = rget(rosco, 'textbody_original');
				RoscoRowIterator titer = new RoscoRowIterator(textbody, '\n');
				String trow;
				do {
					if (titer.hasNext())
						trow = titer.next();
					Matcher matcher2 = caseThreadIdPattern.matcher(trow.left(1000));
					if (matcher2.find()) {
						ret = matcher2.group(0);
					}
				} while (titer.hasNext());
				if (ret == '') {
					rput(rosco, 'roscolog', 'getThreadIdFromEmail: thread id not found in textbody');
				} else {
					rput(rosco, 'roscolog', 'getThreadIdFromEmail: thread id found in textbody');
				}
			}
			if (ret == '') {
				String htmlbody = rget(rosco, 'htmlbody_original_stripped');
				RoscoRowIterator hiter = new RoscoRowIterator(htmlbody, '\n');
				String hrow;
				do {
					if (hiter.hasNext())
						hrow = hiter.next();
					Matcher matcher3 = caseThreadIdPattern.matcher(hrow.left(1000));
					if (matcher3.find()) {
						ret = matcher3.group(0);
					}
				} while (hiter.hasNext());
				if (ret == '') {
					rput(rosco, 'roscolog', 'getThreadIdFromEmail: thread id not found in htmlbody');
				} else {
					rput(rosco, 'roscolog', 'getThreadIdFromEmail: thread id found in htmlbody');
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'getThreadIdFromEmail: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		return ret;
	}

	/** init
	 * initialize rosco map object used throughout processing
	 * @param email  -Messaging.InboundEmail to support@tanium.com
	 * @return rosco map
	 */
	public static void init(Map<String, String> rosco, Messaging.InboundEmail email) {
		rput(rosco, 'roscolog', 'init: ' + 'rosco email handler version v6-20-2019');
		initRoscoDefaults(rosco);
		initRoscoSettings(rosco);
		initRoscoEmail(rosco, email);
		rput(rosco, 'inbound_email_result_success', 'false');
	}

	/** initRoscoDefaults
	 * initialize all the defaults
	 * @return initialized rosco map object
	 */
	public static void initRoscoDefaults(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'initRoscoDefaults: initializing default rosco map values');
		rput(rosco, 'emailpostfix', '');
		rput(
			rosco,
			'atturl',
			'https://tanium--full--c.cs25.content.force.com/servlet/servlet.FileDownload?file='
		);
		rput(rosco, 'authenticated', 'true'); // Set to false by checkAuthentication
		rput(rosco, 'caseid', ''); // Detected later
		rput(rosco, 'case_accountid', '0010e00001JOFGPAA5'); // Gainsight(defult), determined later
		rput(rosco, 'case_hfpoc_accountid', '0010e00001JOFGPAA5'); // Gainsight(defult), determined later
		rput(rosco, 'case_component', ''); // Case Component null unless override via mailapi
		rput(rosco, 'case_contactid', '0030e00002JnUQcAAN'); // "Contact TBD" Contact, set by checkMailApi or createCase/updateCase
		rput(rosco, 'case_country', '');
		rput(rosco, 'case_country_routing_accountids', 'None');
		rput(rosco, 'case_hfpoc_contactid', '0030e00002JnUQcAAN'); // "Contact TBD" Contact, set by checkMailApi or createCase/updateCase
		rput(rosco, 'case_contacts', ''); // CreateCaseContacts - set via From/To/Cc + mailapi + contact roles
		rput(rosco, 'case_note', ''); //  can be set by checkMailApi (notes to triager)
		rput(rosco, 'case_number', ''); //  determined later
		rput(rosco, 'case_origin', 'Email'); //  determined later
		rput(rosco, 'case_ownerid', '00532000005VMZAAA4'); // Tanium User, set by checkMailApi
		rput(rosco, 'sc_japan_queue', ''); // Japan Queue
		rput(rosco, 'valid_contact_found', 'false'); // used for auth
		rput(rosco, 'header_based_matching', 'true'); // header based matching
		rput(rosco, 'case_recordtypeid', '0120e000000Dxi7AAC');
		try {
			String recId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
			rput(rosco, 'case_recordtypeid', recId);
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'initiRoscoDefaults: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
		rput(rosco, 'case_severity', '3'); // Default, set by checkMailApi
		rput(rosco, 'case_status', 'New'); // Default, set by checkMailApi
		rput(rosco, 'case_type', ''); // Default, set by checkMailApi
		rput(rosco, 'case_version', ''); // Default, set by checkMailApi
		rput(rosco, 'case_url_prefix', '');
		rput(rosco, 'catch_all_case', '5000e00001XW0ULAA1'); // Catch all, set by getCaseId or createCase
		rput(rosco, 'check_auth', 'false'); // Toggle whether to auth email
		rput(rosco, 'check_contact_max_create', '10'); // Maximum contacts that can be created
		rput(rosco, 'check_mail_api', 'false'); // Toggle whether to check mail api
		rput(rosco, 'check_mail_api_pass', '1T1F'); // Used to enable mail api for non tanium emails
		rput(rosco, 'check_spam', 'false'); // Toggle whether to check for spam
		rput(rosco, 'chronicle', 'false'); // From Chronicle Support
		rput(rosco, 'chronicleAuto', 'false'); // Chronicle Automated messages
		rput(rosco, 'chronicle_support_address', 'chronicle-support@test.security'); // Chronicle Automated messages
		rput(rosco, 'chronicle_refid_re', '(_00D0bC9dy._500[a-zA-Z0-9]{8})');
		rput(rosco, 'contact_placeholder', '0010e00001RcgMsAAJ'); // Unclassfied, when account can't be determined
		rput(
			rosco,
			'contact_exclusion',
			'.+?(?=@)[@].*(apex).*(salesforce.com)|support@tanium.com|soa@tanium.com|marketing-operations@tanium.com|support@roscolab.com|chronicle-support@chronicle.security'
		);
		rput(rosco, 'contactid_exclusion', '0030e00002Ln3ZHAAZ');
		rput(rosco, 'create_contacts', 'false'); // Create salesforce contacts based on email
		rput(rosco, 'create_contact_case_roles', 'false'); // Create case contact roles based on on email
		rput(rosco, 'create_contact_domain_lookup', 'false'); // Lookup domain to determine which account
		rput(rosco, 'dupchar', '24'); // number of characters to search for dup prevent
		rput(rosco, 'dup_check_multiple_account_limit', '1'); //
		rput(rosco, 'dup_check_multiple_case_limit', '20'); //
		rput(rosco, 'dup_check_multiple_email_limit', '50'); //
		rput(rosco, 'email_field_exclude', 'support@tanium'); // will not copy to To/Cc/Bcc
		rput(
			rosco,
			'exclude_account',
			'\'0013200001D3n0nAAB\',\'00132000019soMfAAI\',\'0010e00001JOFGPAA5\',\'0010e00001KHJWSAA5\''
		);
		rput(rosco, 'developer.tanium.com', 'false');
		rput(rosco, 'hfpoc', 'false'); // hands free poc
		rput(rosco, 'htmlbody', '');
		rput(rosco, 'htmlbody_original', '');
		rput(rosco, 'htmlbody_original_stripped', '');
		rput(rosco, 'IsExternallyVisible', 'false'); // Controls whether emails available in portal
		rput(rosco, 'local_refid_re', '(_00D60IYkG._500[a-zA-Z0-9]{8})');
		rput(rosco, 'local_refid_newformat', '!00D600IYkG.!500[0-9A-Za-z]*');
		rput(rosco, 'messageid', ''); // Set later in createEmailMessage
		rput(rosco, 'msg_after_hour', 'true'); // Send after hour message toggle
		rput(rosco, 'msg_after_hour_re', ''); // Regex on when to fire after hour msg
		rput(rosco, 'msg_debug', 'true'); // Send debug message toggle
		rput(rosco, 'msg_missing_case_contacts', 'true'); // Send debug message toggle
		rput(rosco, 'msg_new_case', 'true'); // Send new case message toggle
		rput(rosco, 'msg_unauthenticated', 'true'); // Send unauthenticated message toggle
		rput(rosco, 'msg_slipstream', 'true'); // Send slipstream message toggle
		rput(rosco, 'retrycase', '5'); // retry Case put if failed
		rput(rosco, 'retryemail', '5'); // retry EmailMessage put if failed
		rput(rosco, 'rosco_verbose', 'true'); // Verbose Logging
		rput(rosco, 'new_case', 'false'); // Set to true if email results in new case
		rput(rosco, 'owea_noreply', '0D260000000XZFg');
		rput(rosco, 'owea_support', '0D20e0000004DjC');
		rput(
			rosco,
			'slack_incoming_hook',
			'https://hooks.slack.com/services/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'
		);
		rput(rosco, 'slackmap', 'false'); // slack roscomap in tool_soa
		rput(rosco, 'slack_caseupdate', 'C0L7DC8Q6'); // updates to cases
		rput(rosco, 'sfdc_dom_c', 'tanium.my.salesforce.com'); // domain name for SF Classic
		rput(rosco, 'sfdc_dom_l', 'tanium.lightning.force.com'); // domain name for SF Lightning
		rput(rosco, 'inbound_email_result_success', 'false'); // Success/Failure sent back to InboundEmailResult
		rput(rosco, 'sync_non_tanium_ccr', 'false'); // Sync emails to customers not included on CCR
		rput(rosco, 'sfenv', ''); // Set via custom settings
		rput(rosco, 'slack_exceptions', 'CJ4PWL412');
		rput(rosco, 'spam', 'false'); // Set to true by checkSpam
		rput(rosco, 'spam_fromaddress_re', ''); // Regex for checkSpam
		rput(rosco, 'spam_textbody_re', '.*TANSPAMTAN.*'); // Regex for checkSpam
		rput(rosco, 'textbody', '');
		rput(rosco, 'textbody_original', '');
		rput(rosco, 'notify_tanowneroption', 'false'); // Notify of #tanowner:foo.bar@tanium.com
		String txt_afterhr_prem = ('Thank you for contacting Tanium Technical Support!  You have reached us after normal ' +
		'business hours.  As all email cases are categorized as Severity 3 we will follow-up next business day!  ' +
		'If you need immediate assitance please logon to https://community.tanium.com/s/case/[INSERTCASEID] ' +
		'and increase the severity of the support case. \n\n' +
		'Best Regards,\nTanium Support');
		rput(rosco, 'txt_afterhr_prem', txt_afterhr_prem);
		String txt_afterhr_std = ('Thank you for contacting Tanium Technical Support!  You have reached us after normal ' +
		'business hours.  As all email cases are categorized as Severity 3 we will follow-up next business day!  ' +
		'If you need immediate assitance please logon to https://community.tanium.com/s/case/[INSERTCASEID] ' +
		'and increase the severity of the support case. \n\n' +
		'Best Regards,\nTanium Support');
		rput(rosco, 'txt_afterhr_std', txt_afterhr_std);
		String txt_new_case = ('Hello and thank you for contacting Tanium Technical Support!\n\n' +
		'We have received your message and will begin reviewing. We have ' +
		'updated the subject with the case #[REPLACECASENUMBER] and ' +
		'have slipstreamed the reference number ([REPLACETHREADID]) our ' +
		'case management system utilizes to match emails to the case.' +
		'We also encourage you to follow this case within our Support ' +
		'portal at https://support.tanium.com!\n\n' +
		'Best Regards,\n\nTanium Support');
		rput(rosco, 'txt_new_case', txt_new_case);
		String txt_slipstream = ('FYI: The Tanium Support incident management system utilizes a reference number to match emails to ' +
		'case numbers.  For example, [REPLACETHREADID] - we have slipstreamed it within this message ' +
		'please continue discussion using this updated message.');
		rput(rosco, 'txt_slipstream', txt_slipstream);
		String txt_unauth_email_match = ('Hello and thank you for contacting Tanium Technical Support!\n\n' +
		'Unfortunately we are unable to locate you as a defined technical support contact.  Please consider ' +
		'the following:\n\n' +
		'* If you are experiencing a technical issue please work through your internal escalation path.  Alternatively, you can post a ' +
		'question on our public discussion forum at https://community.tanium.com\n\n' +
		'* Help with training? - please email training@tanium.com\n\n' +
		'* Help with Technical Integrations? - please email integrations@tanium.com\n\n' +
		'* Help with Sales or need info about Tanium? - please email info@tanium.com\n\n' +
		'* Are you a Sales Channel partner? - please email var.channel@tanium.com\n\n' +
		'Best Regards,\nTanium Support');
		rput(rosco, 'txt_unauth_email_match', txt_unauth_email_match);
		String txt_unauth_email = ('Hello and thank you for contacting Tanium Technical Support!\n\n' +
		'Unfortunately we are unable to locate you as a defined technical support contact.  If you ' +
		'are experiencing a technical issue please work through your internal escalation path.  Alternatively, you can post a ' +
		'question on our public forum at https://community.tanium.com.\n\n Best Regards,\nTanium Support');
		rput(rosco, 'txt_unauth_email', txt_unauth_email);
	}

	/** initRoscoEmail
	 * initRoscoEmail description
	 * @param  rosco rosco description
	 * @param  email email description
	 */
	public static void initRoscoEmail(Map<String, String> rosco, Messaging.InboundEmail email) {
		rput(rosco, 'roscolog', 'initRoscoEmail: reading in email...');
		try {
			Integer maxLengthPlainTextBody = EmailMessage.TextBody.getDescribe().getLength();
			Integer maxLengthHtmlBody = EmailMessage.HtmlBody.getDescribe().getLength();
			Integer maxLengthSubject = EmailMessage.Subject.getDescribe().getLength();
			try {
				if (email.plainTextBody == null) {
					rput(rosco, 'roscolog', 'initRoscoEmail: email does not contain text body');
				} else {
					Integer textlength = email.plainTextBody.length();
					rput(
						rosco,
						'roscolog',
						'initRoscoEmail: TEXT Size ' +
						textlength +
						' (' +
						maxLengthPlainTextBody +
						')'
					);
					rput(rosco, 'textbody_original', email.plainTextBody);
					String plainTextBody = email.plainTextBody.abbreviate(
						maxLengthPlainTextBody - 10000
					);
					rput(rosco, 'textbody', plainTextBody);
					Integer textlength2 = plainTextBody.length();
					if (textlength != textlength2) {
						rput(
							rosco,
							'roscolog',
							'initRoscoEmail: TEXT Size abbreviated and is now ' +
							String.valueOf(textlength2)
						);
					}
				}
			} catch (Exception e) {
				rput(rosco, 'roscolog', 'initRoscoEmail: TEXT Size NOT available ');
				rput(
					rosco,
					'roscolog',
					'initRoscoEmail: ' +
					e.getMessage() +
					'\n' +
					e.getStackTraceString()
				);
			}
			try {
				if (email.htmlBody == null) {
					rput(rosco, 'roscolog', 'initRoscoEmail: email does not contain HTML body');
				} else {
					Integer htmllength = email.htmlBody.length();
					rput(
						rosco,
						'roscolog',
						'initRoscoEmail: HTML Size ' +
						email.htmlBody.length() +
						' (' +
						maxLengthHtmlBody +
						')'
					);
					rput(rosco, 'htmlbody_original', email.htmlBody);
					rput(rosco, 'htmlbody_original_stripped', email.htmlBody.stripHtmlTags());
					String htmlBody = email.htmlBody.abbreviate(maxLengthHtmlBody - 10000);
					rput(rosco, 'htmlbody', htmlBody);
					Integer htmllength2 = htmlBody.length();
					if (htmllength != htmllength2) {
						rput(
							rosco,
							'roscolog',
							'initRoscoEmail: HTML Size abbreviated and is now ' +
							String.valueOf(htmllength2)
						);
					}
				}
			} catch (Exception e) {
				rput(rosco, 'roscolog', 'initRoscoEmail: HTML Size NOT available ');
				rput(
					rosco,
					'roscolog',
					'initRoscoEmail: ' +
					e.getMessage() +
					'\n' +
					e.getStackTraceString()
				);
			}
			String subject = (String.isBlank(email.subject)
				? ''
				: email.subject.abbreviate(maxLengthSubject));
			String trimmedSubject = RoscoUtility.getTrimmedSubject(email.subject);
			String headers = '';
			for (Messaging.InboundEmail.Header header : email.headers) {
				headers += header.name + '=' + header.value + '\n';
			}
			rput(rosco, 'headers', headers);
			String cc = '';
			if (email.ccAddresses != null) {
				for (String ccad : email.ccAddresses) {
					if (cc == '') {
						cc = ccad;
					} else {
						cc = ccad + ';' + cc;
					}
				}
			}
			rput(rosco, 'ccaddresses_original', String.valueOf(email.ccAddresses));
			rput(rosco, 'ccaddresses', String.valueOf(cc));
			if (email.headers != null) {
				for (Messaging.InboundEmail.Header hc : email.headers) {
					if (hc.name == 'ccAddresses') {
						rput(rosco, 'ccaddresses', hc.value);
					}
				}
			}
			rput(rosco, 'fromaddress_original', email.fromAddress);
			rput(rosco, 'fromaddress', email.fromAddress);
			rput(rosco, 'fromname_original', email.fromName);
			rput(rosco, 'fromname', email.fromName);
			rput(rosco, 'inreplyto', email.inReplyTo);
			rput(rosco, 'references', email.messageId);
			rput(
				rosco,
				'roscolog',
				'initRoscoEmail: Message-Id is ' + String.valueOf(email.messageId)
			);
			rput(rosco, 'replyto', email.replyTo);
			rput(rosco, 'subject_original', subject);
			rput(rosco, 'subject_email', subject);
			rput(rosco, 'subject', RoscoUtility.getTrimmedSubject(email.subject));
			String to = '';
			if (email.toAddresses != null) {
				for (String toad : email.toAddresses) {
					if (to == '') {
						to = toad;
					} else {
						to = toad + ';' + to;
					}
				}
			}
			rput(rosco, 'toaddresses_original', to);
			rput(rosco, 'toaddresses', to);
			if (email.headers != null) {
				for (Messaging.InboundEmail.Header ht : email.headers) {
					if (ht.name == 'toAddresses') {
						rput(rosco, 'toaddresses', ht.value);
					}
				}
			}
			if ((String.valueOf(email.fromAddress)).containsIgnoreCase('@tanium.com')) {
				rput(rosco, 'case_origin', 'Email-Tan');
			}
			if (
				(String.valueOf(email.fromAddress).toLowerCase() ==
				'do-not-reply@developer.tanium.com') ||
				(subject.containsIgnoreCase('CONSTELLANT_TEST_MAIL'))
			) {
				rput(rosco, 'developer.tanium.com', 'true');
				rput(rosco, 'case_type', 'DEV');
			}
			if (
				subject.contains('HFPOC Contact Request Alert') &&
				String.valueOf(email.fromAddress).toLowerCase() == 'marketing-operations@tanium.com'
			) {
				rput(rosco, 'hfpoc', 'true');
				rput(rosco, 'case_type', 'HFPOC');
			}
			String chronicleAdd = rget(rosco, 'chronicle_support_address');
			if (String.valueOf(email.fromAddress).toLowerCase() == chronicleAdd) {
				rput(rosco, 'chronicle', 'true');
				String ctextbody = rget(rosco, 'textbody');
				if (ctextbody.left(255).containsIgnoreCase('This is an automated message')) {
					rput(rosco, 'chronicleAuto', 'true');
				} else {
					String chtmlbody = rget(rosco, 'htmlbody');
					if (chtmlbody.left(255).containsIgnoreCase('This is an automated message')) {
						rput(rosco, 'chronicleAuto', 'true');
					}
				}
			}
			if (String.valueOf(email.fromAddress).toLowerCase() == 'sender@tanium.com') {
				if (subject.containsIgnoreCase('(Description->Email Slipstream)')) {
					rosco.put('IsExternallyVisible', 'true');
				}
			}
			if (
				(String.valueOf(email.fromAddress).toLowerCase() == 'proofpoint-pps@ppops.net') ||
				(subject.containsIgnoreCase('PROOFPOINT_TEST_MAIL'))
			) {
				String body = String.valueOf(email.plainTextBody);
				body = body.replace(
					'This means the message had either: 1. A size greater than 50 MB 2. An uncompressed size great than 100 MB 3. A file depth greater than 20 Please verify with the sender, and use another mechanism to send the attachment if the attempt was valid',
					''
				);
				if (body.length() > 0) {
					String psender = '';
					Pattern senderPattern = Pattern.compile('(Sender:\\s[a-zA-Z0-9.+-~@]+)');
					Matcher matcher1 = senderPattern.matcher(body);
					if (matcher1.find()) {
						psender = matcher1.group(0);
						psender = psender.replaceAll('Sender:', '');
						psender = psender.trim();
						rput(rosco, 'fromaddress', psender);
					}
					String psubject = '';
					Pattern subjectPattern = Pattern.compile('(Subject:.*)');
					Matcher matcher2 = subjectPattern.matcher(body);
					if (matcher2.find()) {
						psubject = matcher2.group(0);
						psubject = psubject.replaceAll('Subject:', '');
						psubject = psubject.trim();
						rput(rosco, 'subject', RoscoUtility.getTrimmedSubject(psubject));
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'initRoscoEmail: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** initRoscoSettings
	 * read in values Setup > Custom Settings > Case Management
	 * @param  rosco is a map object passed around
	 * @return void - rosco is passed by reference
	 */
	public static void initRoscoSettings(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'initRoscoSettings: custom settings override...');
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			Map<String, String> regexchk = new Map<String, String>();
			regexchk.put('case_accountid', '^001[a-zA-Z0-9]{15}$');
			regexchk.put('case_contactid', '^003[a-zA-Z0-9]{15}$');
			regexchk.put('case_ownerid', '^00[35][a-zA-Z0-9]{15}$');
			regexchk.put('case_recordtypeid', '^012[a-zA-Z0-9]{15}$');
			regexchk.put('case_severity', '^[123][.][0]$');
			regexchk.put(
				'case_status',
				'^New$|^In Progress - Troubleshooting$|^Pending - Clarifying$|^On Hold$'
			);
			regexchk.put('catch_all_case', '^500[a-zA-Z0-9]{15}$');
			regexchk.put('check_auth', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('check_mail_api', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('check_spam', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('contact_placeholder', '^001[a-zA-Z0-9]{15}$');
			regexchk.put('create_contacts', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('create_contact_case_roles', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('msg_after_hour', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('msg_debug', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('msg_missing_case_contacts', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('msg_new_case', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('msg_slipstream', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('msg_unauthenticated', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			regexchk.put('rosco_verbose', '^[Tt][Rr][Uu][Ee]$|^[Ff][Aa][Ll][Ss][Ee]$');
			for (String cmfield : cmfields) {
				String cmkey = cmfield.replace('rosco_', '');
				cmkey = cmkey.replace('__c', '');
				String cmval = String.valueOf(cm.get(cmfield));
				if ((rosco.containsKey(cmkey)) && (cmval != null)) {
					if (regexchk.containsKey(cmkey)) {
						String chk = regexchk.get(cmkey);
						if (Pattern.matches(chk, cmval)) {
							rput(rosco, cmkey, cmval);
							rput(rosco, 'roscolog', 'initRoscoSettings: set ' + cmkey + ':' + cmval);
						} else {
							rput(
								rosco,
								'roscolog',
								'initRoscoSettings: RegEx Fail ' +
								cmkey +
								'[' +
								cmval +
								'] does not match: ' +
								chk
							);
						}
					} else {
						rput(rosco, cmkey, cmval);
						rput(rosco, 'roscolog', 'initRoscoSettings: set ' + cmkey + ':' + cmval);
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'initRoscoSettings: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** isEmailTAM
	 * test if email is a TAM
	 * @param  email string
	 * @return       Boolean
	 */
	public static Boolean isEmailTAM(Map<String, String> rosco, String email) {
		Boolean ret = false;
		try {
			String soql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE Email = \'' +
				email +
				'\' ' +
				'AND IsActive = True ' +
				'AND (UserRole.Name LIKE \'%TAM%\' ' +
				'OR UserRole.Name LIKE \'%TSE%\' ' +
				'OR UserRole.Name LIKE \'%Executive%\') ';
			List<User> users = new List<User>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				users = Database.query(soql);
			}
			if (!users.isEmpty()) {
				ret = true;
			}
		} catch (Exception e) {
			rput(rosco, 'roscolog', 'isEmailTAM: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** nullOrEmpty
	 * test if object is empty or null
	 * @param  object
	 * @return       Boolean
	 */
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** emailDebugLog
	 * @param  rosco    rosco description
	 * @param  email    email description
	 * @param  envelope envelope description
	 * @return          return description
	 */
	public static void emailDebugLog(
		Map<String, String> rosco,
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		rput(rosco, 'roscolog', 'emailDebugLog:Sending email (this email)');
		try {
			String env = rget(rosco, 'sfenv');
			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setReplyTo('soa@tanium.com');
			mail.setSenderDisplayName(env);
			String[] toAddresses = new List<String>{ 'soa@tanium.com' };
			mail.setToAddresses(toAddresses);
			mail.setSubject(env + ' Email Handler Report:' + rget(rosco, 'subject_original'));
			String roscolog = rget(rosco, 'roscolog');
			roscolog = roscolog.replace('\n', '<br>');
			List<String> roscokeys = new List<String>();
			roscokeys.addAll(rosco.keySet());
			roscokeys.sort();
			String roscomap = '';
			for (String key : roscokeys) {
				if (
					key != 'roscolog' &&
					!key.contains('body') &&
					!key.contains('subject') &&
					key != 'headers' &&
					!key.contains('txt_')
				) {
					if (key != null) {
						roscomap += key + ': ' + rget(rosco, key) + '\n';
					}
				}
			}
			String html = '<html><body>';
			html += '<table border="1">';
			html += '<tr><th align="left" bgcolor="#EC332F"><b>rosco log</b></th></tr>';
			html += '<tr><td align="left" bgcolor="#E7E8E8">' + roscolog + '</td></tr>';
			html += '<tr><th align="left" bgcolor="#EC332F"><b>rosco map</b></th></tr>';
			html += '<tr><td align="left" bgcolor="#E7E8E8">' + roscomap + '</td></tr>';
			html += '<tr><th align="left" bgcolor="#EC332F"><b>email headers</b></th></tr>';
			html +=
				'<tr><td align="left" bgcolor="#E7E8E8">' +
				rget(rosco, 'headers').replace('\n', '<br>') +
				'</td></tr>';
			html += '<tr><th align="left" bgcolor="#EC332F"><b>subject</b></th></tr>';
			html += '<tr><td align="left" bgcolor="#E7E8E8">' + rget(rosco, 'subject');
			html += '<tr><th align="left" bgcolor="#EC332F"><b>subject original</b></th></tr>';
			html += '<tr><td align="left" bgcolor="#E7E8E8">' + rget(rosco, 'subject_original');
			html += '<tr><th align="left" bgcolor="#EC332F"><b>email html (html4 escaped)</b></th></tr>';
			html += '<tr><td align="left" bgcolor="#E7E8E8">' + rget(rosco, 'htmlbody').escapeHtml4();
			html += '<tr><th align="left" bgcolor="#EC332F"><b>email html</b></th></tr>';
			html += '<tr><td align="left" bgcolor="#E7E8E8">' + rget(rosco, 'htmlbody').escapeHtml4();
			html += '<tr><th align="left" bgcolor="#EC332F"><b>email text</b></th></tr>';
			html += '<tr><td align="left" bgcolor="#E7E8E8">' + rosco.get('textbody') + '</td></tr>';
			html += '</table>';
			html += '</body></html>';
			mail.setHtmlBody(html);
			String subject = rget(rosco, 'subject');
			if (!Test.isRunningTest() && !subject.containsIgnoreCase('roscotestcase')) {
				if (Limits.getEmailInvocations() < 9) {
					Messaging.SendEmailResult[] results = Messaging.sendEmail(
						new List<Messaging.SingleEmailMessage>{ mail }
					);
				}
			}
		} catch (Exception e) {
			System.debug('emailDebugLog: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** emailResponse
	 * emailResponse description
	 * @param  email       email description
	 * @param  relatedToId relatedToId description
	 * @return             return description
	 */

	public static void emailResponse(
		Map<String, String> rosco,
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		try {
			rput(rosco, 'roscolog', 'emailResponse()');
			if (
				(rget(rosco, 'check_auth') == 'true') &&
				(rget(rosco, 'authenticated') != 'true') &&
				(rget(rosco, 'caseid') == '')
			) {
				emailResponseUnauthenticated(rosco);
			} else {
				if (rget(rosco, 'new_case') == 'true') {
					if (rget(rosco, 'case_origin') == 'Email-Tanowner') {
						emailResponseInitialTanowner(rosco, email);
					} else if (rget(rosco, 'chronicle') == 'true') {
						emailResponseChronicleNewCase(rosco);
					}
				}
				if (rget(rosco, 'case_origin') != 'Email-Tanowner') {
					emailResponseCaseContactRolesSync(rosco, email);
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'emailResponse: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** emailResponseAfterHour
	 *  description
	 * @param  rosco rosco description
	 */
	public static void emailResponseAfterHour(Map<String, String> rosco) {
	}

	/** emailResponseCaseContactRolesNew
	 *
	 * @param  email       email description
	 * @param  relatedToId relatedToId description
	 * @return             return description
	 */
	public static void emailResponseCaseContactRolesNew(
		Map<String, String> rosco,
		Messaging.InboundEmail email
	) {
	}

	/** emailResponseCaseContactRolesSync
	 *
	 * @param  email       email description
	 * @param  relatedToId relatedToId description
	 * @return             return description
	 */
	public static void emailResponseCaseContactRolesSync(
		Map<String, String> rosco,
		Messaging.InboundEmail email
	) {
		try {
			rput(rosco, 'roscolog', 'emailResponseCaseContactRoles()');
			String htmlbody = '<html><body>';
			htmlbody += 'FYI: New Case or Missed CC email notification. ';
			htmlbody += '<br><br>';
			if (!Test.isRunningTest()) {
				htmlbody += RoscoUtility.getCaseInfoHtmlTable(rget(rosco, 'caseid'));
			}
			htmlbody += '<br><br>';
			htmlbody += '<b>Missed Email</b><br><hr>';
			htmlbody += '-----Original Message-----<br>';
			htmlbody += 'From: ' + rget(rosco, 'fromaddress_original') + '<br>';
			htmlbody += 'To: ' + rget(rosco, 'toaddresses_original') + '<br>';
			htmlbody += 'Cc: ' + rget(rosco, 'ccaddresses_original') + '<br>';
			htmlbody += 'Subject: ' + rget(rosco, 'subject_original');
			htmlbody += '<br><br>';
			String messageid = rget(rosco, 'messageid');
			String htmlbodyMsg = [SELECT Htmlbody FROM EmailMessage WHERE id = :messageid].Htmlbody;
			htmlbody = htmlbody + htmlbodyMsg + '</body></html>';
			List<Messaging.Emailfileattachment> fileAttachments = new List<Messaging.Emailfileattachment>();
			for (Attachment a : [
				SELECT Id, Name, Body, BodyLength
				FROM Attachment
				WHERE ParentId = :messageid
			]) {
				String link = rget(rosco, 'atturl') + +String.valueOf(a.Id).left(15);
				htmlbody = htmlbody.replace(link, 'cid:' + a.Name);
				Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
				efa.setFileName(a.Name);
				efa.setBody(a.Body);
				efa.setinline(true);
				efa.setcontenttype('image/png');
				fileAttachments.add(efa);
			}
			String original = '';
			original += rget(rosco, 'fromaddress_original');
			original += rget(rosco, 'toaddresses_original');
			original += rget(rosco, 'ccaddresses_original');
			String textbody = rget(rosco, 'textbody');
			String soql =
				'select Contact.Email from CaseContactRole ' +
				'where CasesId=\'' +
				rget(rosco, 'caseid') +
				'\'';
			List<CaseContactRole> ccr = new List<CaseContactRole>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				ccr = Database.query(soql);
			}
			if (!ccr.isEmpty()) {
				for (CaseContactRole c : ccr) {
					if (c.Contact.Email != null) {
						if (String.valueOf(c.Contact.Email).contains('@')) {
							if (!original.containsIgnoreCase(c.Contact.Email)) {
								if (c.Contact.Email.contains('@tanium.com')) {
									String casesubject =
										rget(rosco, 'casenumber') +
										':' +
										rget(rosco, 'subject') +
										' (email notification)';
									rput(
										rosco,
										'roscolog',
										'emailResponseCaseContactRoles: Email Sync ' + c.Contact.Email
									);
									Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
									mail.setReplyTo('sender@tanium.com');
									mail.setSenderDisplayName('Tanium - No Reply');
									String[] toAddresses = new List<String>{ c.Contact.Email };
									mail.setToAddresses(toAddresses);
									mail.setSubject(casesubject);
									mail.setHtmlBody(htmlbody);
									mail.setFileAttachments(fileAttachments);
									if (!Test.isRunningTest() && Limits.getEmailInvocations() < 9) {
										Messaging.SendEmailResult[] results = Messaging.sendEmail(
											new List<Messaging.SingleEmailMessage>{ mail }
										);
									}
								} else {
									rput(
										rosco,
										'roscolog',
										'emailResponseCaseContactRoles: Skipped Email Sync ' + c.Contact.Email
									);
								}
							}
						}
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'emailResponseCaseContactRolesSync: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** emailResponseInitialTanowner
	 *
	 * @param  email       email description
	 * @param  relatedToId relatedToId description
	 * @return             return description
	 */
	public static void emailResponseInitialTanowner(
		Map<String, String> rosco,
		Messaging.InboundEmail email
	) {
		try {
			rput(rosco, 'roscolog', 'emailResponseInitialTanowner()');
			Case aCase = RoscoUtility.getCaseDetails(rget(rosco, 'caseid'));
			Site site = [SELECT Id FROM Site WHERE Name = 'Tanium_Customer_Community' LIMIT 1];
			String communityUrl = [SELECT SecureURL FROM SiteDetail WHERE DurableId = :site.Id]
			.SecureUrl;
			String caseLink = communityUrl.replace('/Customers', '/s/case/' + rget(rosco, 'caseid'));
			String htmlbody = '<html><body>';
			htmlbody +=
				'Your request (#' +
				aCase.CaseNumber +
				') has been received, and is being reviewed by our support staff. Reply to this email to provide an update on your case. ';
			htmlbody += '<br><br>';
			htmlbody += 'If you are a member of the Tanium Community, you can also view and comment on your case by clicking the link below:';
			htmlbody += '<br>' + caseLink + '<br><br>';
			htmlbody += 'Regards,<br>Tanium Support<br>support@tanium.com<br><br>';
			htmlbody += '-----Original Message-----<br>';
			htmlbody += 'From: ' + rget(rosco, 'fromaddress_original') + '<br>';
			htmlbody += 'To: ' + rget(rosco, 'toaddresses_original') + '<br>';
			htmlbody += 'Cc: ' + rget(rosco, 'ccaddresses_original') + '<br>';
			htmlbody += 'Subject: ' + rget(rosco, 'subject_original');
			htmlbody += '<br><br>';
			String messageid = rget(rosco, 'messageid');
			String htmlbodyMsg = [SELECT Htmlbody FROM EmailMessage WHERE id = :messageid].Htmlbody;
			String htmlConverted = convertHTML(rosco, htmlbodyMsg);
			String threadId = EmailMessages.getFormattedThreadingToken(aCase.Id);
			htmlbody = htmlbody + htmlConverted + '<br>' + threadId + '</body></html>';
			List<Messaging.Emailfileattachment> fileAttachments = new List<Messaging.Emailfileattachment>();
			for (Attachment a : [
				SELECT Id, Name, Body, BodyLength
				FROM Attachment
				WHERE ParentId = :messageid
			]) {
				Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
				efa.setFileName(a.Name);
				efa.setBody(a.Body);
				efa.setinline(true);
				efa.setcontenttype('image/png');
				fileAttachments.add(efa);
			}
			String original = '';
			original += rget(rosco, 'fromaddress_original');
			original += rget(rosco, 'toaddresses_original');
			original += rget(rosco, 'ccaddresses_original');
			List<String> cc = new List<String>();
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
							cc.add(String.valueOf(address));
						}
					}
				}
			}
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D20e0000004DjCCAU';
			if (cmfields.contains('rosco_owea_support__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea_support__c'))) {
					owea = String.valueOf(cm.get('rosco_owea_support__c'));
				}
			}
			if (nullOrEmpty(cc) == false) {
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(owea);
				mail.setToAddresses(cc);
				mail.setSubject(aCase.CaseNumber + ':' + aCase.Subject);
				mail.setHtmlBody(htmlbody);
				mail.setPlainTextBody(htmlbody.stripHtmlTags());
				mail.setFileAttachments(fileAttachments);
				if (Limits.getEmailInvocations() < 9) {
					Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'emailResponseInitial: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** emailResponseChronicleNewCase
	 */
	public static void emailResponseChronicleNewCase(Map<String, String> rosco) {
	}

	/** emailResponseUnauthenticated
	 *
	 * @param  email       email description
	 * @param  relatedToId relatedToId description
	 * @return             return description
	 */
	public static void emailResponseUnauthenticated(Map<String, String> rosco) {
		try {
			rput(rosco, 'roscolog', 'emailResponseUnauthenticated()');
			String caseId = rget(rosco, 'caseid');
			String subject = rget(rosco, 'subject_original');
			String email = rget(rosco, 'fromaddress');
			if (
				(rget(rosco, 'check_auth') == 'true') &&
				(rget(rosco, 'authenticated') != 'true') &&
				(rget(rosco, 'caseid') == '')
			) {
				String html =
					'<div style="text-align:center;background-color:black;color:white;font-size:large;font-weight:bold;">' +
					'<p>Unrecognized Tanium Technical Support Contact</p></div>';
				html +=
					'The Tanium Technical Support team recently received email with the subject "' +
					subject +
					'" from your email address. ';
				html +=
					'Unfortunately, we do not recognize your email (' +
					email +
					') as registered support contact. <br><br>';
				html += 'Please logon to our Support Portal at https://community.tanium.com or resend your message from an alternate (corporate) email.  ';
				html += '<br><br>Regards,<br>Tanium Technical Support';
				html += '<html><body><br>';
				String txt =
					'The Tanium Technical Support team recently received email with the subject "' +
					subject +
					'" from your email address. ';
				txt +=
					'Unfortunately, we do not recognize your email (' +
					email +
					') as registered support contact.\n\n ';
				txt += 'Please logon to our Support Portal at https://community.tanium.com or resend your message from an alternate (corporate) email.  ';
				txt += '\n\nRegards,\nTanium Technical Support';
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(rget(rosco, 'owea_noreply'));
				List<String> to = new List<String>();
				to.add(email);
				mail.setToAddresses(to);
				List<String> bcc = new List<String>();
				bcc.add('soa@tanium.com');
				mail.setBccAddresses(bcc);
				mail.setSubject('Tanium Technical Support: Unrecognized Email Address');
				mail.setHtmlBody(html);
				mail.setPlainTextBody(txt);
				if (!Test.isRunningTest()) {
					if (Limits.getEmailInvocations() < 9) {
						Messaging.SendEmailResult[] results = Messaging.sendEmail(
							new List<Messaging.SingleEmailMessage>{ mail }
						);
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'emailResponseUnauthenticated: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** emailTanOwnerOption
	 */
	public static void emailTanOwnerOption(Map<String, String> rosco) {
		try {
			rput(rosco, 'roscolog', 'emailTanOwnerOption()');
			String caseId = rget(rosco, 'caseid');
			String subject = rget(rosco, 'subject_original');
			String email = rget(rosco, 'notifyTanOwnerOption');
			if (isEmailTAM(rosco, email)) {
				String html =
					'A recent email with the subject "' +
					subject +
					'" sent to support@tanium.com ';
				html += 'resulted in a case being sent to triage.  A friendly reminder ';
				html += 'that you can bypass triage by including #tanowner:' + email + ' ';
				html += 'in the body of your email.  Doing so will automatically assign you the case.';
				html += '<html><body><br>';
				String txt =
					'A recent email with the subject "' +
					subject +
					'" sent to support@tanium.com ';
				txt += 'resulted in a case being sent to triage.  A friendly reminder ';
				txt += 'that you can bypass triage by including #tanowner:' + email + ' ';
				txt += 'in the body of your email.  Doing so will automatically assign you the case.';
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(rget(rosco, 'owea_noreply'));
				List<String> to = new List<String>();
				to.add(email);
				mail.setToAddresses(to);
				mail.setSubject('FYI #tanowner:foo.bar option for support cases');
				mail.setHtmlBody(html);
				mail.setPlainTextBody(txt);
				if (!subject.containsIgnoreCase('roscotestcase')) {
					if (Limits.getEmailInvocations() < 9) {
						Messaging.SendEmailResult[] results = Messaging.sendEmail(
							new List<Messaging.SingleEmailMessage>{ mail }
						);
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'emailTanOwnerOption: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** processChronicleAutoEmail
	 * Google Chronicle's automated messages
	 * @param  rosco is a map object passed around
	 * @return void - rosco is passed by reference
	 */
	public static void processChronicleAutoEmail(
		Map<String, String> rosco,
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
	}

	/** processDevEmail
	 * Handle developer.tanium.com
	 * @param  rosco is a map object passed around
	 * @return void - rosco is passed by reference
	 */
	public static void processDevEmail(
		Map<String, String> rosco,
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		rput(rosco, 'roscolog', 'processDevEmail: processing...');
		try {
			Boolean isExpectedBody = true;
			String body = rget(rosco, 'htmlbody');
			rput(rosco, 'roscolog', 'processDevEmail: htmlbody=' + body);
			String ticketType = '';
			String ticketSummary = '';
			String ticketCompany = '';
			String ticketBDM = '';
			String contactName = '';
			String contactEmail = '';
			String ticketDescription = '';
			List<String> lBody = body.split('\n');
			for (String s : lBody) {
				s = s.stripHtmlTags();
				if (s.containsIgnoreCase('Ticket Type:')) {
					ticketType = s.replace('Ticket Type:', '').trim();
				}
				if (s.containsIgnoreCase('Summary:')) {
					ticketSummary = s.replace('Summary:', '').trim();
				}
				if (s.containsIgnoreCase('Company Name:')) {
					ticketCompany = s.replace('Company Name:', '').trim();
				}
				if (s.containsIgnoreCase('Company BDM:')) {
					ticketBDM = s.replace('Company BDM:', '').trim();
				}
				if (s.containsIgnoreCase('Contact Name:')) {
					contactName = s.replace('Contact Name:', '').trim();
				}
				if (s.containsIgnoreCase('Contact Email:')) {
					contactEmail = s.replace('Contact Email:', '').trim();
				}
			}
			String strippedBody = body.stripHtmlTags();
			Integer descriptionStart = strippedBody.indexOf('Original Description:');
			Integer descriptionStop = strippedBody.indexOf('Regards,');
			ticketDescription = strippedBody.substring(descriptionStart, descriptionStop);
			ticketDescription = ticketDescription.replace('Original Description:', '');
			ticketDescription = ticketDescription.replace('Regards,', '');
			ticketDescription = ticketDescription.trim();
			if (nullOrEmpty(ticketDescription) || nullOrEmpty(contactEmail)) {
				isExpectedBody = false;
			}
			String contactId = rget(rosco, 'case_contactid');
			String accountId = rget(rosco, 'case_accountid');
			if (contactEmail.contains('@')) {
				String soql =
					'SELECT Id, AccountId FROM Contact ' +
					'WHERE email = \'' +
					contactEmail +
					'\' LIMIT 1';
				List<Contact> cs = new List<Contact>();
				if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
					cs = Database.query(soql);
				}
				if (!cs.isEmpty()) {
					contactId = cs[0].Id;
					accountId = cs[0].AccountId;
					rput(
						rosco,
						'roscolog',
						'processDevEmail: found contact ' +
						contactId +
						'\'' +
						accountId +
						'...'
					);
				} else {
					if (contactEmail.contains('@') == true) {
						List<String> esplit = contactEmail.split('@');
						String edomain = (esplit[1]);
						accountId = getAccountFromEmailDomain(edomain);
						Contact c = new Contact(
							Email = contactEmail,
							LastName = contactName.left(50),
							AccountId = accountId,
							HasOptedOutOfEmail = true
						);
						insert c;
						contactId = c.Id;
						rput(
							rosco,
							'roscolog',
							'processDevEmail: created contact ' +
							c.Id +
							'/' +
							accountId +
							'...'
						);
					}
				}
			}
			QueueSobject supportQ = [
				SELECT QueueId
				FROM QueueSobject
				WHERE Queue.Name = 'Technical Partnerships'
			];
			String ownerId = String.valueOf(supportQ.QueueId);
			RecordType techPartnerRecordType = [
				SELECT Id
				FROM RecordType
				WHERE SobjectType = 'Case' AND DeveloperName = 'Technical_Partnerships'
				LIMIT 1
			];
			Case newcase = new Case(
				AccountId = accountId,
				ContactId = contactId,
				Component__c = 'Other',
				OwnerId = ownerId,
				RecordTypeId = techPartnerRecordType.Id,
				Severity_Community__c = '3',
				Subject = ticketSummary,
				Type = 'Incident',
				Description = ticketDescription,
				Origin = 'TechPartner'
			);
			insert newCase;
			if (newCase.Id != null) {
				Integer retryemail = Integer.valueOf(rget(rosco, 'retryemail'));
				for (Integer i = 0; i < retryemail; i++) {
					if (rget(rosco, 'messageid') == '') {
						String hbody = rget(rosco, 'htmlbody');
						String tBody = hbody.stripHtmlTags();
						if (isExpectedBody) {
							tBody = ticketDescription;
							hBody = ticketDescription;
						} else {
							rput(rosco, 'roscolog', 'processDevEmail: isExpectedBody not true');
							RoscoLog.addEntry(
								UserInfo.getUserId(),
								'Exception',
								'RoscoEmailUtility:processDevEmail()',
								1,
								'Error',
								'Processed unexpected email body',
								rget(rosco, 'htmlbody'),
								'',
								''
							);
						}
						rput(rosco, 'roscolog', 'processDevEmail: hbody: ' + hBody);
						EmailMessage message = new EmailMessage(
							textBody = 'Case Opened via developer.tanium.com\n\n' + tBody,
							htmlBody = 'Case Opened via developer.tanium.com<br/><br/>' + hBody,
							subject = ticketSummary,
							fromName = contactName,
							fromAddress = contactEmail,
							ToAddress = '',
							CcAddress = '',
							IsExternallyVisible = false,
							relatedToId = newCase.Id,
							incoming = true
						);
						insert message;
						rput(rosco, 'messageid', message.Id);
						if (rget(rosco, 'messageid') != '') {
							i = 99;
						}
					} else {
						i = 99; //break
					}
				}
			}
			RoscoCaseContactRole.setCcrViaString(contactEmail, newCase.Id);
		} catch (Exception e) {
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', '--- processDevEmail Exception');
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', 'message:' + e.getMessage());
			rput(rosco, 'roscolog', 'StackTraceString:' + e.getStackTraceString());
			rput(rosco, 'roscolog', 'AccountId:' + rget(rosco, 'case_hfpoc_accountid'));
			rput(rosco, 'roscolog', 'ContactId:' + rget(rosco, 'case_hfpoc_contactid'));
			rput(rosco, 'roscolog', 'OwnerId:' + rget(rosco, 'case_ownerid'));
			rput(rosco, 'roscolog', 'RecordTypeId:' + rget(rosco, 'case_recordtypeid'));
			rput(rosco, 'roscolog', 'Subject:' + e.getStackTraceString());
			rput(rosco, 'roscolog', 'Description:' + e.getStackTraceString());
			rput(rosco, 'roscolog', '--------------------------------------------------');
		}
	}

	/** processHFPOCEmail
	 * Handle Hands Free Proof of Concept emails
	 * @param  rosco is a map object passed around
	 * @return void - rosco is passed by reference
	 */
	public static void processHFPOCEmail(
		Map<String, String> rosco,
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		rput(rosco, 'roscolog', 'processHFPOCEmail: processing...');
		try {
			String subject = rget(rosco, 'subject');
			subject = subject.replace('HFPOC Contact Request Alert', 'Tanium PoC Support');
			rput(rosco, 'subject', subject);
			String body = rget(rosco, 'textbody');
			body = String.valueOf(body);
			body = body.replace('\n', '');
			body = body.replace('\r', '');
			final String NAME_EXPRESSION = '(Contact Name.*Contact Email)';
			Pattern namePattern = Pattern.compile(NAME_EXPRESSION);
			String contactName;
			Matcher matcher = namePattern.matcher(body);
			if (matcher.find()) {
				contactName = matcher.group(1);
				contactName = contactName.replace('Contact Name', '');
				contactName = contactName.replace('Contact Email', '');
				contactName = contactName.replace(':', '');
				contactName = contactName.replaceAll('\u00A0', '');
				contactName = contactName.trim();
			}
			final String EMAIL_EXPRESSION = '(Contact Email.*Contact Company)';
			Pattern emailPattern = Pattern.compile(EMAIL_EXPRESSION);
			String cemail;
			Matcher emailMatcher = emailPattern.matcher(body);
			if (emailMatcher.find()) {
				cemail = emailMatcher.group(1);
				cemail = cemail.replace('Contact Email', '');
				cemail = cemail.replace('Contact Company', '');
				cemail = cemail.replace(':', '');
				cemail = cemail.replaceAll('\u00A0', '');
				cemail = cemail.trim();
			}
			final String PHONE_EXPRESSION = '(Contact Phone.*Preferred Mode of Contact)';
			Pattern phonePattern = Pattern.compile(PHONE_EXPRESSION);
			String phone;
			Matcher phoneMatcher = phonePattern.matcher(body);
			if (phoneMatcher.find()) {
				phone = phoneMatcher.group(1);
				phone = phone.replace('Contact Phone', '');
				phone = phone.replace('Preferred Mode of Contact', '');
				phone = phone.replace(':', '');
				phone = phone.replaceAll('\u00A0', '');
				phone = phone.trim();
			}
			final String MODE_EXPRESSION = '(Preferred Mode of Contact.*Support Request Topic)';
			Pattern modePattern = Pattern.compile(MODE_EXPRESSION);
			String mode;
			Matcher modeMatcher = modePattern.matcher(body);
			if (modeMatcher.find()) {
				mode = modeMatcher.group(1);
				mode = mode.replace('Preferred Mode of Contact', '');
				mode = mode.replace('Support Request Topic', '');
				mode = mode.replace(':', '');
				mode = mode.replaceAll('\u00A0', '');
				mode = mode.trim();
			}
			final String TOPIC_EXPRESSION = '(Support Request Topic.*Support Request Question)';
			Pattern topicPattern = Pattern.compile(TOPIC_EXPRESSION);
			String topic;
			Matcher topicMatcher = topicPattern.matcher(body);
			if (topicMatcher.find()) {
				topic = topicMatcher.group(1);
				topic = topic.replace('Support Request Topic', '');
				topic = topic.replace('Support Request Question', '');
				topic = topic.replace(':', '');
				topic = topic.replaceAll('\u00A0', '');
				topic = topic.trim();
			}
			final String QUESTION_EXPRESSION = '(Support Request Question.*---------------------------------)';
			Pattern questionPattern = Pattern.compile(QUESTION_EXPRESSION);
			String questionraw;
			Matcher questionMatcher = questionPattern.matcher(body);
			if (questionMatcher.find()) {
				questionraw = questionMatcher.group(1);
				questionraw = questionraw.replace('Support Request Question:', '');
				questionraw = questionraw.replace('---------------------------------', '');
				questionraw = questionraw.replaceAll('\u00A0', '');
			}
			String latestQuestion = '';
			String previousQuestionsText = '';
			String previousQuestionsHtml = '';
			List<String> questions = questionraw.split('###');
			for (String q : questions) {
				String question = q.trim();
				if (question.contains(' - ')) {
					String questiondate = question.mid(0, 20);
					String questiontext = question.mid(38, 10000);
					if (latestQuestion == '') {
						latestQuestion = questiontext;
					} else {
						previousQuestionsText += questiondate + ' - ' + questiontext + '\n';
						previousQuestionsHtml += '<li>' + questiondate + ' - ' + questiontext + '</li>';
					}
				}
			}
			String textbody = 'Tanium PoC Support request:\n\n';
			textbody += 'Topic: ' + topic + '\n';
			if (phone != null || phone != '') {
				textbody += 'Phone: ' + phone + '\n';
			}
			textbody += 'Email: ' + cemail + '\n';
			textbody += 'Preferred contact method:' + mode + '\n';
			textbody += 'Question:' + latestQuestion + '\n\n';
			String htmlbody = '<b><u>Tanium PoC Support request:</u></b><br>';
			htmlbody += '<ul>';
			htmlbody += '<li><b>Topic:</b> ' + topic + '</li>';
			if (phone != null || phone != '') {
				htmlbody += '<li><b>Phone:</b> ' + phone + '</li>';
			}
			htmlbody += '<li><b>Email:</b> ' + cemail + '</li>';
			htmlbody += '<li><b>Preferred contact method: </b>' + mode + '</li>';
			htmlbody += '<li><b>Question:</b> ' + latestQuestion + '</li>';
			htmlbody += '</ul>';
			String caseId = null;
			if (String.valueOf(cemail).containsAny('@')) {
				String soql =
					'SELECT Id FROM Case WHERE ' +
					'Origin = \'HFPOC\' AND Tags__c LIKE \'%' +
					cemail +
					'%\'';
				List<Case> lCases = new List<Case>();
				if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
					lCases = Database.query(soql);
				}
				if (lCases.size() != 0) {
					for (Case c : lCases) {
						caseId = c.Id;
					}
				}
				if (caseId == null) {
					Case newcase = new Case(
						AccountId = rget(rosco, 'case_hfpoc_accountid'),
						ContactId = rget(rosco, 'case_hfpoc_contactid'),
						Component__c = 'Other',
						OwnerId = rget(rosco, 'case_ownerid'),
						RecordTypeId = rget(rosco, 'case_recordtypeid'),
						Severity_Community__c = '3',
						Status = 'In Progress - Troubleshooting',
						Subject = subject,
						Type = 'Task',
						Description = body,
						Origin = 'HFPOC',
						Tags__c = cemail
					);
					insert newcase;
					caseId = newcase.Id;
					rput(rosco, 'new_case', 'true');
					rput(rosco, 'roscolog', 'createCase:' + String.valueOf(newcase.id) + ' created');
					rput(rosco, 'caseid', caseId);
				}
			} else {
				rput(
					rosco,
					'roscolog',
					'processHFPOCEmail:Fatal Error unable to determine email:' + String.valueOf(cemail)
				);
			}
			if (caseId != null) {
				Integer retryemail = Integer.valueOf(rget(rosco, 'retryemail'));
				for (Integer i = 0; i < retryemail; i++) {
					if (rget(rosco, 'messageid') == '') {
						EmailMessage message = new EmailMessage(
							textBody = textbody,
							htmlBody = htmlbody,
							subject = subject,
							fromName = contactName,
							fromAddress = cemail,
							ToAddress = '',
							CcAddress = '',
							IsExternallyVisible = false,
							relatedToId = caseid,
							incoming = true
						);
						insert message;
						rput(rosco, 'messageid', message.Id);
						if (rget(rosco, 'messageid') != '') {
							i = 99;
						}
					} else {
						i = 99; //break
					}
				}
			}
			RoscoCaseContactRole.setCcrViaString(cemail, caseId);
			updateCaseStatus(rosco);
			slackCaseUpdate(rosco);
		} catch (Exception e) {
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', '--- processHFPOCEmail Exception');
			rput(rosco, 'roscolog', '--------------------------------------------------');
			rput(rosco, 'roscolog', 'message:' + e.getMessage());
			rput(rosco, 'roscolog', 'StackTraceString:' + e.getStackTraceString());
			rput(rosco, 'roscolog', 'AccountId:' + rget(rosco, 'case_hfpoc_accountid'));
			rput(rosco, 'roscolog', 'ContactId:' + rget(rosco, 'case_hfpoc_contactid'));
			rput(rosco, 'roscolog', 'OwnerId:' + rget(rosco, 'case_ownerid'));
			rput(rosco, 'roscolog', 'RecordTypeId:' + rget(rosco, 'case_recordtypeid'));
			rput(rosco, 'roscolog', 'Subject:' + e.getStackTraceString());
			rput(rosco, 'roscolog', 'Description:' + e.getStackTraceString());
			rput(rosco, 'roscolog', '--------------------------------------------------');
		}
	}

	/** rget
	 * retrieves value from rosco map
	 * @param  rosco is a map object passed around
	 * @param  key key within rosco map to retrieve
	 * @return map value (string)
	 */
	public static String rget(Map<String, String> rosco, String key) {
		String ret = '';
		try {
			if (rosco == null) {
				rput(rosco, 'roscolog', 'rget: rosco is null');
			} else {
				if (rosco.containsKey(key)) {
					ret = rosco.get(key);
				}
			}
		} catch (Exception e) {
			rput(rosco, 'roscolog', 'rget: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** rput
	 * inserts value into rosco map
	 * @param  rosco is a map object passed around
	 * @param  key within rosco map to upsert
	 * @param  value within rosco map to upsert
	 * @return void - rosco is passed by reference
	 */
	public static void rput(Map<String, String> rosco, String key, String value) {
		try {
			if (rosco == null) {
				rput(rosco, 'roscolog', 'rput: rosco is null');
			} else {
				if (value == null) {
					value = '';
				}
				String existing = '';
				if (rosco.containsKey(key)) {
					existing = rget(rosco, key);
				}
				if (key == 'roscolog') {
					if (existing == '') {
						rosco.put('roscolog', value.trim());
					} else {
						value = value.replace('\n', '');
						rosco.put('roscolog', existing + '\n' + value.trim());
					}
				} else if (key.contains('casepost')) {
					if (existing == '') {
						rosco.put('casepost', value.trim());
					} else {
						value = value.replace('\n', '');
						rosco.put('casepost', existing + '\n' + value.trim());
					}
				} else if (key.contains('mailapi_')) {
					rosco.put(key, value.trim());
					rosco.put(key.replace('mailapi_', ''), value.trim());
				} else if (
					(key != 'fromaddress') &&
					(key != 'toaddresses') &&
					(key != 'ccaddresses') &&
					(key != 'case_contacts')
				) {
					rosco.put(key, value.trim());
				} else {
					value = value.replace('(', '');
					value = value.replace(')', '');
					value = value.replace(',', ';');
					if (value.contains('@')) {
						if (value.contains(';')) {
							List<String> addresses = value.split(';');
							for (String a : addresses) {
								if (
									a.contains('@') && !Pattern.matches(rget(rosco, 'contact_exclusion'), a)
								) {
									a = a.trim();
									a = a.toLowerCase();

									existing = rget(rosco, key);
									if (!existing.containsIgnoreCase(a)) {
										if (existing == '' || key == 'fromaddress') {
											rosco.put(key, a);
										} else {
											rosco.put(key, existing + ';' + a);
										}
									}
								}
							}
						} else {
							existing = rget(rosco, key);
							if (
								!existing.containsIgnoreCase(value) &&
								!Pattern.matches(rget(rosco, 'contact_exclusion'), value)
							) {
								value = value.trim();
								value = value.toLowerCase();
								if (value.contains('@')) {
									if (existing == '' || key == 'fromaddress') {
										rosco.put(key, value);
									} else {
										rosco.put(key, existing + ';' + value);
									}
								}
							}
						}
					}
					String people = rget(rosco, 'fromaddress');
					if (rget(rosco, 'case_contacts_api').length() > 0) {
						people += ';' + rget(rosco, 'case_contacts');
					}
					if (rget(rosco, 'toaddresses').length() > 0) {
						people += ';' + rget(rosco, 'toaddresses');
					}
					if (rget(rosco, 'ccaddresses').length() > 0) {
						people += ';' + rget(rosco, 'ccaddresses');
					}
					people = people.toLowerCase();
					people = people.trim();
					List<String> peeplist = new List<String>();
					if (people.contains(';')) {
						List<String> peeptemp = people.split(';');
						for (String peeptempelement : peeptemp) {
							if (!peeplist.contains(peeptempelement)) {
								if (
									peeptempelement.contains('@') &&
									!Pattern.matches(rget(rosco, 'contact_exclusion'), peeptempelement)
								) {
									peeptempelement = peeptempelement.trim();
									peeplist.add(peeptempelement);
								}
							}
						}
					} else {
						if (
							people.contains('@') &&
							!Pattern.matches(rget(rosco, 'contact_exclusion'), people)
						) {
							peeplist.add(people);
						}
					}
					people = '';
					String emailpostfix = rget(rosco, 'emailpostfix');
					emailpostfix = emailpostfix.trim();
					emailpostfix = emailpostfix.toLowerCase();
					Integer emailpostfixlen = emailpostfix.length();
					for (String peep : peeplist) {
						if (emailpostfix != '') {
							String peepright = peep.right(emailpostfixlen);
							if (peepright != emailpostfix) {
								peep += emailpostfix;
							}
						}
						if (people == '') {
							people = peep;
						} else {
							people = people + ';' + peep;
						}
						if (!peep.contains('@tanium.com')) {
							rosco.put('IsExternallyVisible', 'true');
						}
					}
					rosco.put('people', people.trim());
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'rput: (' +
				key +
				':' +
				value +
				') ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** slackCaseUpdate
	 * @param  rosco    rosco description
	 * @return          return description
	 */
	public static void slackCaseUpdate(Map<String, String> rosco) {
	}

	/** slackDebugLog
	 * @param  rosco    rosco description
	 * @param  email    email description
	 * @param  envelope envelope description
	 * @return          return description
	 */
	public static void slackDebugLog(
		Map<String, String> rosco,
		Messaging.InboundEmail email,
		Messaging.InboundEnvelope envelope
	) {
		rput(rosco, 'roscolog', 'slackDebugLog:Slacking (this message)');
		try {
			String title =
				rget(rosco, 'sfenv') +
				' Email Handler Report:' +
				rget(rosco, 'subject_original');
			String slackChannel = rget(rosco, 'slack_exceptions');
			String webhookURL = rget(rosco, 'slack_incoming_hook');
			List<String> roscokeys = new List<String>();
			roscokeys.addAll(rosco.keySet());
			roscokeys.sort();
			String roscomap = '';
			for (String key : roscokeys) {
				if (
					key != 'roscolog' &&
					!key.contains('body') &&
					!key.contains('subject') &&
					key != 'headers' &&
					!key.contains('txt_')
				) {
					roscomap += key + ': ' + rget(rosco, key) + '\n';
				}
			}
			String urlprefix = rget(rosco, 'case_url_prefix');
			String urlfriend = rget(rosco, 'sfdc_dom_l');
			String caseid = rget(rosco, 'caseid');
			if (caseid == '') {
				caseid = rget(rosco, 'catch_all_case');
			}
			String caselink =
				'<' +
				urlprefix +
				caseid +
				'%2Fview|https://' +
				urlfriend +
				'/lightning/r/Case/' +
				caseid +
				'>';
			String text = '===============================================================';
			text += '\n=== ' + rget(rosco, 'sfenv') + ' Email Handler Report';
			text += '\n=== ' + caselink;
			text += '\n=== ' + 'https://groups.google.com/a/tanium.com/forum/#!forum/supportemail';
			text += '\n=== ' + 'https://groups.google.com/a/tanium.com/forum/#!forum/soa';
			text += '\n=== From:' + rget(rosco, 'fromaddress_original');
			text += '\n=== To:' + rget(rosco, 'toaddresses');
			text += '\n=== Cc:' + rget(rosco, 'ccaddresses');
			text += '\n=== Subject:' + rget(rosco, 'subject_original');
			text += '\n=== ' + String.valueOf(datetime.now());
			text += '\n===============================================================\n';
			text += rget(rosco, 'roscolog');
			text += '\n===============================================================\n';
			if (rget(rosco, 'slackmap') == 'true') {
				text += '\n=== rosco map\n';
				text += roscomap;
				text += '\n===============================================================\n';
			}
			JSONGenerator gen = JSON.createGenerator(true);
			gen.writeStartObject();
			gen.writeStringField('title', '');
			gen.writeStringField('channel', slackChannel);
			gen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			gen.writeStringField('text', text);
			gen.writeEndObject();
			String body = gen.getAsString();
			String subject = rget(rosco, 'subject');
			if (!subject.contains('ROSCOTESTCASE')) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', body));
			}
		} catch (Exception e) {
			System.debug('slackDebugLog: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** stripThreadIdFromEmail
	 *
	 * @param  email email description
	 * @return       return description
	 */
	public static void stripThreadIdFromEmail(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'stripThreadIdFromEmail: stripping thread id from email');
		try {
			final String CASE_THREAD_ID_EXPRESSION = '([Rr][Ee][Ff][:][_][a-zA-Z0-9]+[.][_][a-zA-Z0-9]+[:][Rr][Ee][Ff])';
			Pattern caseThreadIdPattern = Pattern.compile(CASE_THREAD_ID_EXPRESSION);
			String text = rget(rosco, 'textbody');
			List<String> tlines = text.split('\n');
			for (Integer i = 0; i < tlines.size(); i++) {
				Matcher matcher2 = caseThreadIdPattern.matcher(tlines[i]);
				if (matcher2.find()) {
					String threadid2 = matcher2.group(1);
					tlines[i] = tlines[i].replaceAll(threadid2, '');
					tlines[i] = tlines[i].replaceAll('(\\[\\])|(\\[ \\])|(\\[  \\])', '');
				}
			}
			rput(rosco, 'textbody', String.join(tlines, '\n'));
			String htmlbody = rget(rosco, 'htmlbody');
			List<String> hlines = htmlbody.split('<[Dd][Ii][Vv]');
			for (Integer i = 0; i < hlines.size(); i++) {
				Matcher matcher3 = caseThreadIdPattern.matcher(hlines[i]);
				if (matcher3.find()) {
					String threadid3 = matcher3.group(1);
					hlines[i] = hlines[i].replaceAll(threadid3, '');
					hlines[i] = hlines[i].replaceAll('(\\[\\])|(\\[ \\])|(\\[  \\])', '');
				}
			}
			rput(rosco, 'htmlbody', String.join(hlines, '<div'));
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'stripThreadIdFromEmail: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** updateCaseMailApi
	 * description
	 * @param  rosco rosco description
	 */
	public static void updateCaseMailApi(Map<String, String> rosco) {
	}

	/** updateCaseStatus
	 * description
	 * @param  rosco rosco description
	 */
	public static void updateCaseStatus(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'updateCaseStatus: updating case...');
		try {
			String fromaddress = rget(rosco, 'fromaddress_original');
			Boolean fromtanium = fromaddress.containsIgnoreCase('@tanium.com');
			if (!fromtanium) {
				String caseid = rget(rosco, 'caseid');
				Case c = [SELECT Status FROM Case WHERE Id = :caseid LIMIT 1];
				if (c != null) {
					if (c.Status != null) {
						if (c.Status != 'New') {
							Boolean isInProgress = c.Status.containsIgnoreCase(
								'In Progress - Troubleshoting'
							);
							if (!isInProgress) {
								c.Status = 'In Progress - Troubleshooting';
								update c;
							}
						}
					}
				}
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'updateCaseStatus: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** updateRoscoWithCaseValues
	 *  description
	 * @param  rosco rosco description
	 */
	public static void updateRoscoWithCaseValues(Map<String, String> rosco) {
		rput(rosco, 'roscolog', 'updateRoscoWithCaseValues: reviewing current values...');
		try {
			String soql =
				'SELECT ContactId, Subject, AccountId,Severity_Community__c, Component_Version__c, ' +
				'Component__c,OwnerId,Status,Type FROM Case ' +
				'WHERE Id = \'' +
				rget(rosco, 'caseid') +
				'\'';
			List<Case> c = new List<Case>();
			if (Limits.getQueries() < Limits.getLimitQueries() - 1) {
				c = Database.query(soql);
			}
			if (!c.isEmpty()) {
				rput(rosco, 'case_contactid', String.valueOf(c[0].ContactId));
				rput(rosco, 'case_accountid', String.valueOf(c[0].AccountId));
				rput(rosco, 'case_severity', String.valueOf(c[0].Severity_Community__c));
				rput(rosco, 'case_component', String.valueOf(c[0].Component__c));
				rput(rosco, 'case_version', String.valueOf(c[0].Component_Version__c));
				rput(rosco, 'case_owner', String.valueOf(c[0].OwnerId));
				rput(rosco, 'case_status', String.valueOf(c[0].Status));
				rput(rosco, 'case_type', String.valueOf(c[0].Type));
				rput(rosco, 'subject', String.valueOf(c[0].Subject));
			}
		} catch (Exception e) {
			rput(
				rosco,
				'roscolog',
				'updateRoscoWithCaseValues: ' +
				e.getMessage() +
				'\n' +
				e.getStackTraceString()
			);
		}
	}

	/** qCallOut
	 */
	public class qCallOut implements System.Queueable, Database.AllowsCallouts {
		private final String url;
		private final String method;
		private final String body;

		public qCallOut(String url, String method, String body) {
			this.url = url;
			this.method = method;
			this.body = body;
		}

		public void execute(System.QueueableContext ctx) {
			HttpRequest req = new HttpRequest();
			req.setEndpoint(url);
			req.setMethod(method);
			req.setBody(body);
			Http http = new Http();
			HttpResponse res = http.send(req);
		}
	}
}