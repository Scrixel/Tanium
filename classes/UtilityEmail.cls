/**
 * @Business: Utility class for Apex EmailService
 * @Date: 2018-03-23
 * @Author: Cumulus Vision
 * @Request: TAN-495
 * Modified  ModifiedDate   Description
 * TAN-496   2018-03-23     Initial dev.
 * TAN-568   2018-05-07     switching case lookup to a case sensitive field.
 * TAN-838   2020-02-27     added methods for Apttus Agreement inbound e-mail processing.
 * SS-9622    2024-12-03    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading Message Id
 */
public class UtilityEmail {
	public class tickets {
		public string AccountName;
		public string AccountId;
		public string Category;
		public string Sub_Category;
		public string Root_Cause;
		public string subject;
		public string sendToEmail;
		public string SuppliedFromEmail;
		public string SuppliedFromName;
		public string SuppliedToEmailAddrs;
		public string SuppliedCcEmailAddrs;
		public string Priority;
		public string Impact;
		public string status;
		public string RecordTypeId;
		public string Body;
		public string contactid;
		public string contactName;
		public string contactEmail;
		public string origin;
		public string DueDate;
		public string external_id;
		public string ParentId;
		public string myCaseId;
		public string MyCaseNumber;
		public string emailHeaders;
		public string EMFromId;
		public set<string> emailTo_set;
		public set<string> emailCC_set;
	}

	public class ApttusAgreement {
		public string AgreementId;
		public string emailHeaders;
		public string subject;
		public string Body;
		public string FromAddress;
		public string FromName;
		public string contactId;
		public set<string> emailTo_set;
		public set<string> emailCC_set;
		public string ToEmailAddrs;
		public string CcEmailAddrs;
		public list<id> toIds;
		public list<id> ccIds;
		public map<string, string> ToContact_Map;
		public map<string, string> CcContact_Map;
	}
	public static void ApttusAgreementDefaults(
		ApttusAgreement myAgreement,
		Messaging.inboundEmail myEmail
	) {
		if (myEmail.headers != null) {
			myAgreement.emailHeaders = string.valueOf(myEmail.headers);
		}

		if (myEmail.subject.Length() > 150) {
			myAgreement.subject = myEmail.subject.substring(0, 150);
		} else {
			myAgreement.subject = myEmail.subject;
		}

		if (myEmail.plainTextBody != null) {
			if (myEmail.plainTextBody.Length() > 32000) {
				myAgreement.Body = myEmail.plainTextBody.substring(0, 31999); //email object max size 32000 chars
			} else {
				myAgreement.Body = myEmail.plainTextBody;
			}
		} else if (myEmail.htmlBody != null) {
			if (myEmail.htmlBody.Length() > 32000) {
				myAgreement.Body = myEmail.htmlBody.substring(0, 31999); //email object max size 32000 chars
			} else {
				myAgreement.Body = myEmail.htmlBody;
			}
		} else {
			myAgreement.Body = '';
		}

		String emailRegex = '([a-zA-Z0-9_\\-\\.]+)@((\\[a-z]{1,3}\\.[a-z]{1,3}\\.[a-z]{1,3}\\.)|(([a-zA-Z0-9\\-]+\\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})';
		Pattern emailPattern = Pattern.compile(emailRegex);

		try {
			system.debug(myEmail.fromAddress);
			matcher myMatcher = emailPattern.matcher(myEmail.fromaddress);
			myMatcher.find();
			system.debug(myMatcher.group(3));
			myAgreement.FromAddress = myEmail.fromaddress;
		} catch (Exception e) {
			System.debug(
				'\n Exception Message: ' +
				e.getMessage() +
				'\n Stack Trace: ' +
				e.getStackTraceString()
			);
			myAgreement.FromAddress = 'invalidemail@tanium.com';
		}

		myAgreement.FromName = myEmail.fromName;
		myAgreement.emailTo_set = new Set<string>();
		myAgreement.toIds = new List<id>();
		if (myEmail.ToAddresses != null) {
			for (string x : myEmail.ToAddresses) {
				myAgreement.emailTo_set.add(x);
			}
		}
		myAgreement.ToContact_Map = new Map<string, string>();
		myAgreement.ToContact_Map = getContactIds(myAgreement.emailTo_set);
		myAgreement.toIds = convertMapToIdList(myAgreement.ToContact_Map);
		string emailToAdd = null;
		if (myEmail.ToAddresses != null) {
			for (string x : myEmail.ToAddresses) {
				if (!myAgreement.toContact_Map.keySet().contains(x)) {
					if (emailToAdd == null) {
						emailToAdd = x;
					} else {
						emailToAdd += ' ; ' + x;
					}
				}
			}
		}
		myAgreement.ToEmailAddrs = emailToAdd;

		myAgreement.emailCC_set = new Set<string>();
		string emailCCAdd = null;
		if (myEmail.ccAddresses != null) {
			for (string x : myEmail.ccAddresses) {
				myAgreement.emailCC_set.add(x);
			}
			myAgreement.CcContact_Map = new Map<string, string>();
			myAgreement.CcContact_Map = getContactIds(myAgreement.emailCc_set);
			myAgreement.ccIds = convertMapToIdList(myAgreement.CcContact_Map);
			for (string x : myEmail.ccAddresses) {
				if (!myAgreement.CcContact_Map.keySet().contains(x)) {
					if (emailCCAdd == null) {
						emailCCAdd = x;
					} else {
						emailCCAdd += ' ; ' + x;
					}
				}
			}
		}
		myAgreement.CcEmailAddrs = emailCCAdd;
	}

	public static map<string, string> getContactIds(set<string> emailTo_set) {
		map<string, string> contact_map = new Map<string, string>();
		List<Contact> toContacts = [SELECT id, Email FROM Contact WHERE Email IN :emailTo_set];
		for (Contact x : toContacts) {
			for (string x1 : emailTo_set) {
				if (x.Email == x1) {
					contact_map.put(x.Email, x.id);
				}
			}
		}
		return contact_map;
	}

	public static list<id> convertMapToIdList(map<string, string> theMap) {
		List<id> theIdList = new List<id>();
		for (string x : theMap.values()) {
			theIdList.add(x);
		}
		return theIdList;
	}

	public static void TicketDefaults(tickets myTicket, Messaging.inboundEmail myEmail) {
		//lookup account by contact e-mail
		String recId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
		if (recId != null) {
			myTicket.recordTypeId = recId;
		}
		myTicket.origin = 'Email';

		//lookup contact by e-mail
		List<Contact> myCon = [
			SELECT Id, Name, FirstName, Email
			FROM Contact
			WHERE Email = :myEmail.fromAddress
			LIMIT 1
		];
		if (myCon.size() > 0) {
			myTicket.EMFromId = myCon[0].id;
			myTicket.contactid = myCon[0].id;
			myTicket.contactName = myCon[0].Name;
			myTicket.contactEmail = myCon[0].Email;
		} else {
			myTicket.contactid = null;
			myTicket.contactName = null;
		}
		if (myEmail.headers != null) {
			myTicket.emailHeaders = string.valueOf(myEmail.headers);
		}
		if (myEmail.plainTextBody != null) {
			if (myEmail.plainTextBody.Length() > 32000) {
				myTicket.Body = myEmail.plainTextBody.substring(0, 31999); //email object max size 32000 chars
			} else {
				myTicket.Body = myEmail.plainTextBody;
			}
		} else if (myEmail.htmlBody != null) {
			if (myEmail.htmlBody.Length() > 32000) {
				myTicket.Body = myEmail.htmlBody.substring(0, 31999); //email object max size 32000 chars
			} else {
				myTicket.Body = myEmail.htmlBody;
			}
		} else {
			myTicket.Body = '';
		}

		if (myEmail.subject.Length() > 150) {
			myTicket.subject = myEmail.subject.substring(0, 150);
		} else {
			myTicket.subject = myEmail.subject;
		}
		String emailRegex = '([a-zA-Z0-9_\\-\\.]+)@((\\[a-z]{1,3}\\.[a-z]{1,3}\\.[a-z]{1,3}\\.)|(([a-zA-Z0-9\\-]+\\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})';
		Pattern emailPattern = Pattern.compile(emailRegex);

		try {
			system.debug(myEmail.fromAddress);
			matcher myMatcher = emailPattern.matcher(myEmail.fromaddress);
			myMatcher.find();
			system.debug(myMatcher.group(3));
			myTicket.SuppliedFromEmail = myEmail.fromaddress;
		} catch (Exception e) {
			System.debug(
				'\n Exception Message: ' +
				e.getMessage() +
				'\n Stack Trace: ' +
				e.getStackTraceString()
			);
			myTicket.SuppliedFromEmail = 'invalidemail@tanium.com';
		}
		myTicket.SuppliedFromName = myEmail.fromName;
		myTicket.sendToEmail = myTicket.SuppliedFromEmail;

		string emailToAdd = null;
		myTicket.emailTo_set = new Set<string>();
		if (myEmail.ToAddresses != null) {
			for (string x : myEmail.ToAddresses) {
				myTicket.emailTo_set.add(x);
				if (emailToAdd == null) {
					emailToAdd = x;
				} else {
					emailToAdd += ' ; ' + x;
				}
			}
		}
		myTicket.SuppliedToEmailAddrs = emailToAdd;

		string emailCCAdd = null;
		myTicket.emailCC_set = new Set<string>();
		if (myEmail.ccAddresses != null) {
			for (string x : myEmail.ccAddresses) {
				myTicket.emailCC_set.add(x);
				if (emailCCAdd == null) {
					emailCCAdd = x;
				} else {
					emailCCAdd += ' ; ' + x;
				}
			}
		}
		myTicket.SuppliedCcEmailAddrs = emailCCAdd;
	}

	public static Boolean TicketCreate(tickets myTicket, Messaging.inboundEmail myEmail) {
		Case newcase = new Case(
			Subject = myTicket.subject,
			Status = myTicket.status,
			Description = myTicket.Body,
			SuppliedName = myTicket.SuppliedFromName,
			SuppliedEmail = myTicket.SuppliedFromEmail,
			AccountID = myTicket.AccountId,
			ContactID = myTicket.contactid,
			Priority = myTicket.Priority,
			Origin = myTicket.origin,
			recordTypeId = myTicket.recordTypeId
		);
		insert newcase;

		Case myNewCase = [SELECT id, CaseNumber FROM case WHERE id = :newcase.id];
		myTicket.MyCaseNumber = myNewCase.CaseNumber;
		myTicket.myCaseId = myNewCase.id;

		TicketEmailReceived_new(myTicket, myEmail);

		return true;
	}

	public static void GenericCreateTicket(
		tickets myTicket,
		List<String> allLines,
		Messaging.inboundEmail myEmail
	) {
		try {
			UtilityEmail.TicketCreate(myTicket, myEmail);
		} catch (Exception e) {
			System.debug(
				'\n Exception Message: ' +
				e.getMessage() +
				'\n Stack Trace: ' +
				e.getStackTraceString()
			);
		}
	}
	public static string getUserIdbyEmail(string email) {
		string id;
		List<User> u = [SELECT id FROM User WHERE Email = :email LIMIT 1];
		if (!u.isEmpty())
			id = u[0].id;
		return id;
	}

	public static Boolean AddAgreementTask(boolean dontNotify, ApttusAgreement myAgreement) {
		String taskbody =
			'From: ' +
			myAgreement.FromName +
			' (' +
			myAgreement.FromAddress +
			')\n' +
			'To: ' +
			myAgreement.ToEmailAddrs +
			'\n' +
			'Cc: ' +
			myAgreement.CcEmailAddrs +
			'\n' +
			'Subject: ' +
			myAgreement.subject +
			'\n' +
			myAgreement.Body;
		string subjectCleanse = '';
		if (myAgreement.subject.contains('ref:_')) {
			subjectCleanse = myAgreement.subject.substring(0, myAgreement.subject.indexOf('ref:_') - 1);
		} else {
			subjectCleanse = myAgreement.subject;
		}

		EmailMessage newEmail = new EmailMessage(
			Incoming = true,
			Status = '1',
			RelatedToId = myAgreement.AgreementId,
			Subject = subjectCleanse,
			FromName = myAgreement.FromName,
			FromAddress = myAgreement.FromAddress,
			ToAddress = myAgreement.ToEmailAddrs,
			ToIds = myAgreement.toIds,
			CcIds = myAgreement.ccIds,
			CcAddress = myAgreement.CcEmailAddrs,
			HtmlBody = myAgreement.Body
		);
		insert newEmail;

		// Add Email Message Relation for id of the sender
		string fromUser = getUserIdbyEmail(myAgreement.FromAddress);
		system.debug(fromUser);
		List<EmailMessageRelation> newEMRLst = new List<EmailMessageRelation>();
		if (fromUser != null) {
			EmailMessageRelation emr = new EmailMessageRelation(
				emailMessageId = newEmail.id,
				relationId = fromUser,
				relationType = 'FromAddress'
			);
			newEMRLst.add(emr);
		}

		if (myAgreement.toIds != null) {
			for (id x : myAgreement.toIds) {
				EmailMessageRelation emr = new EmailMessageRelation(
					emailMessageId = newEmail.id,
					relationId = x,
					relationType = 'ToAddress'
				);
				newEMRLst.add(emr);
			}
		}
		if (myAgreement.CcIds != null) {
			for (id x : myAgreement.ccIds) {
				EmailMessageRelation emr = new EmailMessageRelation(
					emailMessageId = newEmail.id,
					relationId = x,
					relationType = 'CcAddress'
				);
				newEMRLst.add(emr);
			}
		}
		if (!newEMRLst.isEmpty())
			insert newEMRLst;

		return true;
	}
	public static Boolean AddAgreementTaskOutbound(
		boolean dontNotify,
		Messaging.SingleEmailMessage message,
		string agreementId,
		string toAddresses,
		string ccAddresses
	) {
		string subjectCleanse = '';
		if (message.subject.contains('ref:_')) {
			subjectCleanse = message.subject.substring(0, message.subject.indexOf('ref:_') - 1);
		} else {
			subjectCleanse = message.subject;
		}
		string emailToAdd = null;
		string emailCcAdd = null;
		List<string> toAddressesLst = toAddresses.split(';');
		system.debug(toAddressesLst);
		set<string> emailTo_set = new Set<string>();
		list<id> toIds = new List<id>();
		toIds.add(message.targetObjectId);
		if (toAddressesLst != null) {
			for (string x : toAddressesLst) {
				emailTo_set.add(x);
			}
			map<string, string> ToContact_Map = new Map<string, string>();
			ToContact_Map = getContactIds(emailTo_set);
			toIds = convertMapToIdList(ToContact_Map);
			for (string x : toAddressesLst) {
				if (!ToContact_Map.keySet().contains(x)) {
					if (emailToAdd == null) {
						emailToAdd = x;
					} else {
						emailToAdd += ' ; ' + x;
					}
				}
			}
		}

		List<string> CcAddressesLst = CcAddresses.split(';');
		system.debug(CcAddressesLst);
		set<string> emailCc_set = new Set<string>();
		list<id> CcIds = new List<id>();
		if (CcAddressesLst != null) {
			for (string x : CcAddressesLst) {
				emailCc_set.add(x);
			}
			map<string, string> CcContact_Map = new Map<string, string>();
			CcContact_Map = getContactIds(emailCc_set);
			CcIds = convertMapToIdList(CcContact_Map);
			for (string x : CcAddressesLst) {
				if (!CcContact_Map.keySet().contains(x)) {
					if (emailCcAdd == null) {
						emailCcAdd = x;
					} else {
						emailCcAdd += ' ; ' + x;
					}
				}
			}
		}

		EmailMessage newEmail = new EmailMessage(
			Incoming = false,
			Status = '3',
			RelatedToId = agreementId,
			Subject = subjectCleanse,
			FromName = UserInfo.getName(),
			FromAddress = UserInfo.getUserEmail(),
			ToAddress = emailToAdd,
			ToIds = toIds,
			CcAddress = emailCcAdd,
			ccIds = ccIds,
			HtmlBody = message.plainTextBody
		);
		insert newEmail;

		string fromUser = getUserIdbyEmail(UserInfo.getUserEmail());
		system.debug(fromUser);
		List<EmailMessageRelation> newEMRLst = new List<EmailMessageRelation>();
		if (fromUser != null) {
			EmailMessageRelation emr = new EmailMessageRelation(
				emailMessageId = newEmail.id,
				relationId = fromUser,
				relationType = 'FromAddress'
			);
			newEMRLst.add(emr);
		}

		if (toIds != null) {
			for (id x : toIds) {
				EmailMessageRelation emr = new EmailMessageRelation(
					emailMessageId = newEmail.id,
					relationId = x,
					relationType = 'ToAddress'
				);
				newEMRLst.add(emr);
			}
		}
		if (CcIds != null) {
			for (id x : ccIds) {
				EmailMessageRelation emr = new EmailMessageRelation(
					emailMessageId = newEmail.id,
					relationId = x,
					relationType = 'CcAddress'
				);
				newEMRLst.add(emr);
			}
		}
		if (!newEMRLst.isEmpty())
			insert newEMRLst;

		return true;
	}

	public static Boolean TicketEmailReceived_new(tickets myTicket, Messaging.inboundEmail myEmail) {
		List<Contact> emailToContact = [SELECT id FROM Contact WHERE email IN :myTicket.emailTo_set];
		List<Contact> emailCCContact = [SELECT id FROM Contact WHERE email IN :myTicket.emailCC_set];
		string[] toIds = new List<string>{};
		string[] CCIds = new List<string>{};
		for (Contact x : emailToContact) {
			toIds.add(x.id);
		}
		for (Contact x : emailCCContact) {
			CCIds.add(x.id);
		}
		EmailMessage newEM = new EmailMessage();
		newEM.Headers = myTicket.emailHeaders;
		newEM.Status = '0';
		newEM.Incoming = true;
		newEM.parentId = myTicket.myCaseId;
		newEM.FromAddress = myTicket.SuppliedFromEmail;
		newEM.CcAddress = myTicket.SuppliedCcEmailAddrs;
		if (!CCIds.isEmpty()) {
			newEM.CCIds = CCIds;
		}
		newEM.FromName = myTicket.SuppliedFromName;
		newEM.Subject = myTicket.Subject;
		newEM.ToAddress = myTicket.SuppliedToEmailAddrs;
		if (!toIds.isEmpty()) {
			newEM.toIds = toIds;
		}
		newEM.TextBody = myTicket.Body;

		insert newEM;

		if (myEmail.binaryAttachments != null && myEmail.binaryAttachments.size() > 0) {
			AddBinaryAttachment(newEM.id, myEmail);
		}
		// Add any text attachments to the case
		if (myEmail.textAttachments != null && myEmail.textAttachments.size() > 0) {
			AddTextAttachment(newEM.id, myEmail);
		}

		return true;
	}

	public static void TicketAlreadyExists(
		tickets myTicket,
		List<String> allLines,
		Messaging.inboundEmail myEmail,
		string threadId
	) {
		try {
			Id caseRecId = EmailMessages.getRecordIdFromEmail(
				myEmail.subject,
				myEmail.plainTextBody,
				myEmail.htmlBody
			);

			// If we haven't found the Case ID, try finding it using headers.
			if (caseRecId == null && myEmail.headers != null) {
				caseRecId = Cases.getCaseIdFromEmailHeaders(myEmail.headers);
			}
			Case clookup1 = [SELECT id, casenumber, ownerid FROM case WHERE Id = :caseRecId LIMIT 1];
			//add original e-mail detail to ticket
			myTicket.myCaseId = clookup1.id;
			myTicket.MyCaseNumber = clookup1.casenumber;
			TicketEmailReceived_new(myTicket, myEmail);
		} catch (Exception e) {
			System.debug(
				'\n Exception Message: ' +
				e.getMessage() +
				'\n Stack Trace: ' +
				e.getStackTraceString()
			);
		}
	}

	public static void ZendeskTicket(
		tickets myTicket,
		List<String> allLines,
		Messaging.inboundEmail myEmail,
		string ZendeskTicketNumber
	) {
		try {
			Case clookup1 = [
				SELECT id, casenumber, ownerid
				FROM case
				WHERE Zendesk_Ticket_Number__c = :ZendeskTicketNumber
				LIMIT 1
			];
			//add original e-mail detail to ticket
			myTicket.myCaseId = clookup1.id;
			myTicket.MyCaseNumber = clookup1.casenumber;
			TicketEmailReceived_new(myTicket, myEmail);
		} catch (Exception e) {
			System.debug(
				'\n Exception Message: ' +
				e.getMessage() +
				'\n Stack Trace: ' +
				e.getStackTraceString()
			);
		}
	}

	public static void AddTextAttachment(string parent, Messaging.inboundEmail myEmail) {
		integer i;
		for (i = 0; i < myEmail.textAttachments.size(); i++) {
			try {
				if (myEmail.textAttachments[i].filename != null) {
					Attachment newAttachment = new Attachment(
						ParentId = parent,
						Name = myEmail.textAttachments[i].filename,
						Body = Blob.valueOf(myEmail.textAttachments[i].body)
					);
					insert newAttachment;
					System.debug('New Text Attachment: ' + newAttachment);
				}
			} catch (Exception e) {
				System.debug(
					'\n Exception Message: ' +
					e.getMessage() +
					'\n Stack Trace: ' +
					e.getStackTraceString()
				);
			}
		}
	}

	public static void AddBinaryAttachment(string parent, Messaging.inboundEmail myEmail) {
		integer i;
		for (i = 0; i < myEmail.binaryAttachments.size(); i++) {
			try {
				if (myEmail.binaryAttachments[i].filename != null) {
					Attachment newAttachment = new Attachment(
						ParentId = parent,
						Name = myEmail.binaryAttachments[i].filename,
						Body = myEmail.binaryAttachments[i].body
					);
					insert newAttachment;
					System.debug('New Binary Attachment: ' + newAttachment);
				}
			} catch (Exception e) {
				System.debug(
					'\n Exception Message: ' +
					e.getMessage() +
					'\n Stack Trace: ' +
					e.getStackTraceString()
				);
			}
		}
	}
}