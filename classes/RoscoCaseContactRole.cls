/**
 * @Business: RoscoCaseContactRole
 * @Date: 6/28/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-10848   2025-06-05    Use new TAM fields from Account and cleanup
 * SS-11443   2025-09-20    Customer Success Owners should only receive email if Sev 1 or Sev 2
 */
public with sharing class RoscoCaseContactRole {
	private static final List<String> JAPAN_BYPASS_SUPPORT_MODELS = new List<String>{
		'Support Center (Japan Bypass)',
		'Partner Supported (SC Japan Bypass)'
	};
	private static Map<String, String> caseManagementDefault = new Map<String, String>();

	@AuraEnabled
	public static List<Map<String, String>> getCCR(String caseId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			List<Case> caselist = [SELECT Account.Name FROM Case WHERE Id = :caseId];
			String caseAccount = caselist[0].Account.Name;

			List<CaseContactRole> ccr = [
				SELECT
					Contact.Id,
					Contact.Name,
					Contact.phone,
					Contact.Email,
					Contact.Account.Name,
					Role
				FROM CaseContactRole
				WHERE CasesId = :caseId
			];

			List<String> ccrs = new List<String>();
			List<String> contactids = new List<String>();
			for (CaseContactRole cid : ccr) {
				contactids.add(cid.Contact.Id);
				ccrs.add(cid.Contact.Email);
			}
			Map<String, String> indirect = getIndirectAccounts(contactids);
			List<String> nodelete = getNoDelete(ccrs, caseId);

			for (CaseContactRole c : ccr) {
				if (c.Contact.Email != null) {
					if (String.valueOf(c.Contact.Email).contains('@') == true) {
						Map<String, String> tmpmap = new Map<String, String>();
						tmpmap.put('Id', String.valueOf(c.Contact.Id).trim());

						String n = c.Contact.Name;
						if (n == null) {
							n = '';
						}
						tmpmap.put('Name', String.valueOf(n).trim());

						if (c.Contact.Phone == null) {
							c.Contact.Phone = '';
						}
						tmpmap.put('Phone', String.valueOf(c.Contact.Phone).trim());

						if (c.Contact.Email == null) {
							c.Contact.Email = '';
						}
						tmpmap.put('Email', String.valueOf(c.Contact.Email).trim());

						if (c.Role == null) {
							c.Role = '';
						}
						tmpmap.put('Role', String.valueOf(c.Role).trim());

						if (c.Contact.Account.Name == null) {
							c.Contact.Account.Name = '';
						}
						tmpmap.put('AccountDirect', String.valueOf(c.Contact.Account.Name).trim());

						tmpmap.put('AccountInDirect', indirect.get(c.Contact.Id));

						// Contact match case account directly or indirectly?
						if (c.Contact.Email.contains('@tanium.com')) {
							tmpmap.put('VerifiedRelationship', 'true');
						} else {
							String directAndIndirect =
								c.Contact.Account.Name +
								' / ' +
								indirect.get(c.Contact.Id);
							if (directAndIndirect.contains(caseAccount) == true) {
								tmpmap.put('VerifiedRelationship', 'true');
							} else {
								tmpmap.put('VerifiedRelationship', 'false');
							}
						}

						if (nodelete.contains(c.Contact.Email)) {
							tmpmap.put('mandatory', 'true');
						} else {
							tmpmap.put('mandatory ', 'false');
						}

						tmpmap.put('Note', 'foo for now');

						ret.add(tmpmap);
					}
				}
			}
		} catch (DmlException e) {
			logNebulaException('getCcr', e);
		}

		ret = RoscoUtility.sortListMapName(ret);
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getCCRNewCase(
		List<String> cids,
		String accountId,
		List<String> nodelete
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		try {
			String caseAccount = 'foo';
			if (String.isNotBlank(accountId)) {
				Account[] accounts = [SELECT Name FROM Account WHERE Id = :accountId];
				if (!accounts.isEmpty()) {
					caseAccount = String.valueOf(accounts[0].Name);
				}
			}

			Map<String, String> indirect = getIndirectAccounts(cids);

			String whereClause = '';
			for (String cid : cids) {
				if (whereClause == '') {
					whereClause = '\'' + cid + '\'';
				} else {
					whereClause = whereClause + ',\'' + cid + '\'';
				}
			}

			String soql =
				'SELECT Id, Name, Phone, Email, Account.Name FROM  ' +
				'Contact WHERE Id IN (' +
				whereClause +
				')';
			List<Contact> contactids = Database.query(soql);
			for (Contact c : contactids) {
				if (c.Email != null) {
					if (String.valueOf(c.Email).contains('@') == true) {
						Map<String, String> tmpmap = new Map<String, String>();
						tmpmap.put('Id', String.valueOf(c.Id).trim());

						String n = c.Name;
						if (n == null) {
							n = '';
						}
						tmpmap.put('Name', String.valueOf(n).trim());

						if (c.Phone == null) {
							c.Phone = '';
						}
						tmpmap.put('Phone', String.valueOf(c.Phone).trim());

						if (c.Email == null) {
							c.Email = '';
						}
						tmpmap.put('Email', String.valueOf(c.Email).trim());

						if (c.Account.Name == null) {
							c.Account.Name = '';
						}
						tmpmap.put('AccountDirect', String.valueOf(c.Account.Name).trim());

						tmpmap.put('AccountInDirect', indirect.get(c.Id));

						// Contact match case account directly or indirectly?
						if (c.Email.contains('@tanium.com')) {
							tmpmap.put('VerifiedRelationship', 'true');
						} else {
							String directAndIndirect = c.Account.Name + ' / ' + indirect;
							if (directAndIndirect.contains(caseAccount) == true) {
								tmpmap.put('VerifiedRelationship', 'true');
							} else {
								tmpmap.put('VerifiedRelationship', 'false');
							}
						}

						if (nodelete.contains(c.Email)) {
							tmpmap.put('mandatory', 'true');
						} else {
							tmpmap.put('mandatory ', 'false');
						}
						ret.add(tmpmap);
					}
				}
			}
		} catch (DmlException e) {
			logNebulaException('getCCRNewCase', e);
		}

		ret = RoscoUtility.sortListMapName(ret);
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getCCRLookup(
		String searchKeyWord,
		String ccrstring,
		String caseId
	) {
		Case aCase = RoscoUtility.getCaseDetails(caseId);
		String accountid = aCase.AccountId;

		List<String> acrRelationship = new List<String>();
		List<AccountContactRelation> acrs = [
			SELECT ContactId
			FROM AccountContactRelation
			WHERE AccountId = :accountid
		];
		if (!acrs.isEmpty()) {
			for (AccountContactRelation acr : acrs) {
				acrRelationship.add(String.valueOf(acr.ContactId));
			}
		}

		searchKeyWord = searchKeyWord.trim();
		String searchKey = '%' + searchKeyWord + '%';

		List<Map<String, String>> returnList = new List<Map<String, String>>();

		String alreadycc = RoscoUtility.getCleanWhereClause(ccrstring);

		String soql;
		if (searchKeyWord == '' && accountid != '') {
			soql =
				'SELECT Id,Name,Email,AccountId,Title,Account.Name FROM Contact ' +
				'WHERE email NOT IN (' +
				alreadycc +
				') ' +
				'AND Id IN (SELECT ContactId FROM AccountContactRelation WHERE AccountId = \'' +
				accountid +
				'\') ' +
				'AND Id IN (SELECT ContactId FROM CaseContactRole) ' +
				'ORDER BY Name DESC LIMIT 10';
		} else {
			soql =
				'SELECT Id,Name,Email,Title,Account.Name ' +
				'FROM Contact ' +
				'WHERE (Name LIKE \'' +
				searchKey +
				'\' ' +
				'OR Email LIKE \'' +
				searchKey +
				'\') ' +
				'AND email NOT IN (' +
				alreadycc +
				') ' +
				'ORDER BY Name DESC LIMIT 10';
		}
		List<Contact> contacts = Database.query(soql);
		if (!contacts.isEmpty()) {
			for (Contact c : contacts) {
				Map<String, String> people = new Map<String, String>();
				String cid = String.valueOf(c.get('Id'));
				String name = String.valueOf(c.get('Name'));
				String email = String.valueOf(c.get('Email'));
				String account = String.valueOf(c.Account.Name);

				people.put('Id', cid);
				people.put('Name', name);
				people.put('Email', email);
				people.put('Account', account);

				people.put('iscontact', 'true');

				if (email.contains('@tanium.com')) {
					people.put('istanium', 'true');
				}

				if (acrRelationship.contains(cid)) {
					people.put('isrelated', 'true');
				}

				if (email.contains('@')) {
					returnList.add(people);
				}
			}
		}

		// is the searchKeyWord a valid email and already in returnList?
		if (!String.valueOf(returnList).contains(searchKeyWord)) {
			if (searchKeyWord.contains('@')) {
				Map<String, String> people = new Map<String, String>();
				people.put('Id', '-1');
				people.put('Name', 'tbd');
				people.put('Email', searchKeyWord);
				people.put('Account', 'tbd');
				returnList.add(people);
			}
		}
		returnList = RoscoUtility.sortListMapName(returnList);
		return returnList;
	}

	@AuraEnabled
	public static List<Map<String, String>> getCCRLookupNewCase(
		String searchKeyWord,
		String ccrstring,
		String accountId
	) {
		List<String> acrRelationship = new List<String>();
		List<AccountContactRelation> acrs = [
			SELECT ContactId
			FROM AccountContactRelation
			WHERE AccountId = :accountId
		];
		if (!acrs.isEmpty()) {
			for (AccountContactRelation acr : acrs) {
				acrRelationship.add(String.valueOf(acr.ContactId));
			}
		}

		searchKeyWord = searchKeyWord.trim();
		String searchKey = '%' + searchKeyWord + '%';

		List<Map<String, String>> returnList = new List<Map<String, String>>();
		String alreadycc = RoscoUtility.getCleanWhereClause(ccrstring);

		String soql;
		if (searchKeyWord == '' && accountId != '') {
			soql =
				'SELECT Id,Name,Email,AccountId,Title,Account.Name FROM Contact ' +
				'WHERE email NOT IN (' +
				alreadycc +
				') ' +
				'AND Id IN (SELECT ContactId FROM AccountContactRelation WHERE AccountId = \'' +
				accountId +
				'\') ' +
				'AND Id IN (SELECT ContactId FROM CaseContactRole) ' +
				'ORDER BY Name DESC LIMIT 10';
		} else {
			soql =
				'SELECT Id,Name,Email,Title,Account.Name ' +
				'FROM Contact ' +
				'WHERE (Name LIKE \'' +
				searchKey +
				'\' ' +
				'OR Email LIKE \'' +
				searchKey +
				'\') ' +
				'AND email NOT IN (' +
				alreadycc +
				') ' +
				'ORDER BY Name DESC LIMIT 10';
		}

		List<Contact> contacts = Database.query(soql);
		if (!contacts.isEmpty()) {
			for (Contact c : contacts) {
				Map<String, String> people = new Map<String, String>();
				String cid = String.valueOf(c.get('Id'));
				String name = String.valueOf(c.get('Name'));
				String email = String.valueOf(c.get('Email'));
				String account = String.valueOf(c.Account.Name);

				people.put('Id', cid);
				people.put('Name', name);
				people.put('Email', email);
				people.put('Account', account);

				people.put('iscontact', 'true');

				if (email.contains('@tanium.com')) {
					people.put('istanium', 'true');
				}

				if (acrRelationship.contains(cid)) {
					people.put('isrelated', 'true');
				}

				if (email.contains('@')) {
					returnList.add(people);
				}
			}
		}

		// is the searchKeyWord a valid email and already in returnList?
		if (!String.valueOf(returnList).contains(searchKeyWord)) {
			if (searchKeyWord.contains('@')) {
				Map<String, String> people = new Map<String, String>();
				people.put('Id', '-1');
				people.put('Name', 'tbd');
				people.put('Email', searchKeyWord);
				people.put('Account', 'tbd');
				returnList.add(people);
			}
		}
		returnList = RoscoUtility.sortListMapName(returnList);
		return returnList;
	}

	public static String getCCRString(String caseId) {
		String ret = '';

		try {
			List<String> contactIds = new List<String>();
			List<CaseContactRole> ccrlist = [
				SELECT ContactId
				FROM CaseContactRole
				WHERE CasesId = :caseId
			];
			for (CaseContactRole c : ccrList) {
				contactIds.add(c.ContactId);
			}

			List<Contact> clist = [SELECT Email FROM Contact WHERE Id IN :contactIds];
			for (Contact c : clist) {
				if (c.Email != null) {
					if (String.valueOf(c.Email).contains('@') == true) {
						if (ret == '') {
							ret = String.valueOf(c.Email).trim();
						} else {
							ret = ret + ';' + String.valueOf(c.Email).trim();
						}
					}
				}
			}
		} catch (DmlException e) {
			logNebulaException('getCCRString', e);
		}
		return ret;
	}

	public static Map<String, String> getIndirectAccounts(List<String> contactids) {
		Map<String, String> ret = new Map<String, String>();

		try {
			if (!contactids.IsEmpty()) {
				String whereClause = '';
				for (String contactid : contactids) {
					if (whereClause == '') {
						whereClause = '\'' + contactid + '\'';
					} else {
						whereClause = whereClause + ',\'' + contactid + '\'';
					}
				}

				String soql =
					'SELECT ContactId, AccountContactRelation.Account.Name ' +
					'FROM AccountContactRelation ' +
					'WHERE ContactId IN (' +
					whereClause +
					') ' +
					'And IsDirect = FALSE';
				List<AccountContactRelation> theRelationship = Database.query(soql);
				if (!theRelationship.IsEmpty()) {
					for (AccountContactRelation r : theRelationship) {
						if (ret.get(r.ContactId) == null) {
							ret.put(r.ContactId, r.Account.Name);
						} else {
							ret.put(r.ContactId, ret.get(r.ContactId) + ' / ' + r.Account.Name);
						}
					}
				}
			}
		} catch (DmlException e) {
			logNebulaException('getIndirectAccounts', e);
		}
		return ret;
	}

	public static List<String> getNoDelete(List<String> ccrs, String caseId) {
		Set<String> caseContactRoleEmails = new Set<String>();
		Set<String> cmfields;
		Case_Management__c cm;
		String superUsers;

		try {
			Case theCase = getCaseDetails(caseId);
			Map<String, String> roleUserEmailMap = getRoleEmailMap(theCase);

			caseContactRoleEmails.add(roleUserEmailMap.get('creator'));
			caseContactRoleEmails.add(roleUserEmailMap.get('owner'));
			caseContactRoleEmails.add(roleUserEmailMap.get('caseContact'));
			if (theCase.Severity_Community__c == '1' || theCase.Severity_Community__c == '2') {
				caseContactRoleEmails.add(roleUserEmailMap.get('customerSuccessOwner'));
			}
			superUsers = roleUserEmailMap.get('superUsers');
			if (String.isNotBlank(superUsers)) {
				caseContactRoleEmails.addAll(superUsers.split(','));
			}

			if (
				String.isNotBlank(theCase.Account.Support_Model__c) &&
				JAPAN_BYPASS_SUPPORT_MODELS.contains(theCase.Account?.Support_Model__c)
			) {
				String japanCc = getCaseManagementDefaults('rosco_case_sc_japan_email__c');
				if (String.isNotBlank(japanCc)) {
					caseContactRoleEmails.add(japanCc);
				}
			}
			caseContactRoleEmails.remove('');
			caseContactRoleEmails.remove(null);
		} catch (Exception e) {
			logNebulaException('getNoDelete', e);
		}
		return new List<String>(caseContactRoleEmails);
	}

	@InvocableMethod(label='Init Case Contact Roles')
	public static void initCaseContactRoles(List<Case> cases) {
		try {
			Case aCase = cases[0];
			setCcrViaString('', aCase.Id);
		} catch (DmlException e) {
			logNebulaException('initCaseContactRoles', e);
		}
	}

	public static List<String> processExistingCcr(String caseid, List<String> ccrs, Boolean delCCR) {
		List<String> ret = new List<String>();
		List<CaseContactRole> delList = new List<CaseContactRole>();

		try {
			for (CaseContactRole c : [
				SELECT Id, ContactId, Contact.Email
				FROM CaseContactRole
				WHERE CasesId = :caseid
			]) {
				if (String.isNotBlank(c.Contact.Email)) {
					String email = c.Contact.Email.toLowerCase();
					if (!ccrs.contains(email)) {
						delList.add(c);
					} else {
						ret.add(String.valueOf(c.ContactId));
					}
				}
			}
			if (delCCR) {
				delete delList;
			}
		} catch (DmlException e) {
			logNebulaException('processExistingCcr', e);
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> setCcrViaString(String ccrstring, String caseId) {
		List<CaseContactRole> newCaseContactRoles = new List<CaseContactRole>();
		List<String> currentCaseContactRoles = new List<String>();
		List<String> caseContactRoles = new List<String>();
		List<String> mandatoryCCRs = new List<String>();
		Map<String, Id> emailContactId_Map = new Map<String, Id>();
		Map<Id, Id> contactOverride = new Map<Id, Id>();
		String contactid_exclusion;
		String fallback_accountid;

		if (String.isBlank(ccrstring) || String.isBlank(caseId)) {
			return null;
		}

		try {
			ccrstring = ccrstring.toLowerCase();
			caseContactRoles.addAll(ccrstring.split(';'));

			contactid_exclusion = getCaseManagementDefaults('rosco_contactid_exclusion__c');
			fallback_accountid = getCaseManagementDefaults('rosco_case_accountid__c');

			// Delete existing roles (if not email handler)
			Boolean delCCR = !UserInfo.getUserEmail().contains('soa@tanium');
			currentCaseContactRoles = processExistingCcr(caseId, caseContactRoles, delCCR);

			mandatoryCCRs = getNoDelete(ccrstring.split(';'), caseId);
			caseContactRoles.addAll(mandatoryCCRs);
			caseContactRoles = removeDuplicateEmails(caseContactRoles);

			emailContactId_Map = getEmailContactIdMap(caseContactRoles, fallback_accountid, caseId);
			contactOverride = getContactOverrides(emailContactId_Map.values());

			for (String caseContactRole : caseContactRoles) {
				Id contactId = emailContactId_Map.get(caseContactRole);
				if (contactOverride.containsKey(contactId)) {
					contactId = contactOverride.get(contactId);
				}
				if (
					!contactid_exclusion.containsIgnoreCase(contactId) &&
					!currentCaseContactRoles.contains(contactId)
				) {
					newCaseContactRoles.add(
						new CaseContactRole(CasesId = caseId, ContactId = contactId)
					);
				}
			}
			if (!newCaseContactRoles.isEmpty()) {
				Database.SaveResult[] saveResults = Database.insert(newCaseContactRoles, false);
				Logger.logDatabaseErrors(
						LoggingLevel.ERROR,
						'RoscoCaseContactRole.setCcrViaString ERRORS',
						saveResults
					)
					.setRecordId(caseId)
					.addTag('apex');
				Logger.saveLog();

				updateEmailDrafts(caseContactRoles, caseId);
			}
		} catch (Exception e) {
			logNebulaException('setCcrViaString', e);
		}
		return getCCR(caseId);
	}

	@AuraEnabled
	public static List<Map<String, String>> setCcrViaStringNewCase(
		String ccrstring,
		String accountId,
		List<String> nodelete
	) {
		List<String> caseContactRoles = new List<String>();
		Map<String, Id> emailContactId_Map = new Map<String, Id>();
		String contactid_exclusion;
		String fallback_accountid;

		try {
			contactid_exclusion = getCaseManagementDefaults('rosco_contactid_exclusion__c');
			fallback_accountid = getCaseManagementDefaults('rosco_case_accountid__c');

			for (String caseContactRole : ccrstring.split(';')) {
				if (caseContactRole.left(3) == '005') {
					caseContactRole = RoscoUtility.getEmailFromUserId(caseContactRole);
				}
				caseContactRoles.add(caseContactRole);
			}

			if (String.isNotBlank(accountId)) {
				String csOwner = getCSOwner(accountId);
				if (String.isNotBlank(csOwner)) {
					caseContactRoles.add(csOwner);
					nodelete.add(csOwner);
				}

				String superUsers = getContactSuperUsers(accountid);
				if (String.isNotBlank(superUsers)) {
					caseContactRoles.addAll(superUsers.split(','));
					nodelete.addAll(superUsers.split(','));
				}
			}

			caseContactRoles = removeDuplicateEmails(caseContactRoles);
			emailContactId_Map = getEmailContactIdMap(caseContactRoles, fallback_accountid, null);

			return getCCRNewCase(emailContactId_Map.values(), accountId, nodelete);
		} catch (Exception e) {
			logNebulaException('setCcrViaString', e);
			return null;
		}
	}

	public static void updateEmailDrafts(List<String> caseContactRoles, String caseId) {
		List<EmailMessage> emailMessages = new List<EmailMessage>();
		String ccrstring = String.join(caseContactRoles, ';');
		for (EmailMessage eMessage : [
			SELECT Id, ToAddress
			FROM EmailMessage
			WHERE Status = '5' AND ParentID = :caseId
		]) {
			eMessage.ToAddress = ccrstring;
			emailMessages.add(eMessage);
		}
		if (!emailMessages.isEmpty()) {
			Database.SaveResult[] saveResults = Database.update(emailMessages, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'RoscoCaseContactRole.updateEmailDrafts ERRORS',
					saveResults
				)
				.setRecordId(caseId)
				.addTag('apex');
			Logger.saveLog();
		}
	}

	private static Case getCaseDetails(Id caseId) {
		return [
			SELECT
				Id,
				CreatedById,
				CreatedBy.Email,
				CreatedBy.IsActive,
				OwnerId,
				Owner.Email,
				Owner.IsActive,
				ContactId,
				Contact.Email,
				AccountId,
				Account.Name,
				Account.CSM__r.Email,
				Account.Support_Model__c,
				Severity_Community__c
			FROM Case
			WHERE Id = :caseId
		];
	}

	private static Map<String, String> getRoleEmailMap(Case caseRecord) {
		Map<String, String> roleUserEmailMap = new Map<String, String>();
		String superUsers = '';

		if (
			String.isNotBlank(caseRecord.CreatedBy?.Email) &&
			!caseRecord.CreatedBy.Email.contains('soa@tanium.com') &&
			!caseRecord.CreatedBy.Email.contains('@cumulusvision.com') &&
			caseRecord.CreatedBy.IsActive
		) {
			roleUserEmailMap.put('creator', caseRecord.CreatedBy.Email.toLowerCase());
		}

		if (
			String.isNotBlank(caseRecord.Owner?.Email) &&
			!caseRecord.Owner.Email.contains('soa@tanium.com') &&
			caseRecord.Owner.IsActive
		) {
			roleUserEmailMap.put('owner', caseRecord.Owner.Email.toLowerCase());
		}

		if (
			String.isNotBlank(caseRecord.Contact?.Email) &&
			!caseRecord.Contact.Email.contains('soa@tanium.com') &&
			!caseRecord.Contact.Email.contains('socontacttbd@tanium.com')
		) {
			roleUserEmailMap.put('caseContact', caseRecord.Contact.Email.toLowerCase());
		}

		if (String.isNotBlank(caseRecord.Account.CSM__r?.Email)) {
			roleUserEmailMap.put(
				'customerSuccessOwner',
				caseRecord.Account.CSM__r.Email.toLowerCase()
			);
		}

		superUsers = getContactSuperUsers(caseRecord.AccountId);
		if (String.isNotBlank(superUsers)) {
			roleUserEmailMap.put('superUsers', superUsers);
		}
		return roleUserEmailMap;
	}

	private static String getContactSuperUsers(Id accountId) {
		String superUserEmails = '';
		for (Contact con : [
			SELECT Id, Email
			FROM Contact
			WHERE
				AccountId = :accountId
				AND Email != NULL
				AND Email LIKE '%@tanium.com%'
				AND Support_Option__c = 'Include on all Case Cc'
		]) {
			superUserEmails += con.Email.toLowerCase() + ',';
		}
		return superUserEmails;
	}

	public static String getCSOwner(Id accountId) {
		return [SELECT Id, CSM__r.Email FROM Account WHERE Id = :accountId].CSM__r?.Email;
	}

	private static Map<String, Id> getEmailContactIdMap(
		List<String> caseContactRoles,
		Id defaultAccountId,
		Id caseId
	) {
		List<Contact> newContacts = new List<Contact>();
		Map<String, Id> emailContactId_Map = new Map<String, Id>();

		for (Contact contact : [
			SELECT Id, Email, AccountId
			FROM Contact
			WHERE Email IN :caseContactRoles
		]) {
			emailContactId_Map.put(contact.Email.toLowerCase(), contact.Id);
		}

		newContacts = createNewContacts(
			caseContactRoles,
			emailContactId_Map.keySet(),
			defaultAccountId,
			caseId
		);

		for (Contact contact : newContacts) {
			emailContactId_Map.put(contact.Email, contact.Id);
		}
		return emailContactId_Map;
	}

	private static List<Contact> createNewContacts(
		List<String> caseContactRoles,
		Set<String> existingContactEmails,
		Id defaultAccountId,
		Id caseId
	) {
		List<Contact> newContacts = new List<Contact>();
		Map<String, String> domainAccountId_Map = new Map<String, String>();
		String accountIdFromDomain = '';
		String accountId = '';
		String emailDomain = '';

		for (String caseContactRole : caseContactRoles) {
			caseContactRole = caseContactRole.trim();
			if (!existingContactEmails.contains(caseContactRole) && caseContactRole.contains('@')) {
				emailDomain = caseContactRole.split('@')[1];
				if (!domainAccountId_Map.containsKey(emailDomain)) {
					accountIdFromDomain = RoscoEmailUtility.getAccountFromEmail(caseContactRole);
					domainAccountId_Map.put(emailDomain, accountIdFromDomain);
				}
				accountIdFromDomain = domainAccountId_Map.get(emailDomain);
				accountId = String.isNotBlank(accountIdFromDomain)
					? accountIdFromDomain
					: defaultAccountId;

				newContacts.add(
					new Contact(
						Email = caseContactRole,
						LastName = caseContactRole.left(50),
						AccountId = accountId
					)
				);
			}
		}
		Database.SaveResult[] saveResults = Database.insert(newContacts, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'RoscoCaseContactRole.createNewContacts ERRORS',
				saveResults
			)
			.setRecordId(caseId)
			.addTag('apex');
		Logger.saveLog();
		return newContacts;
	}

	private static Map<Id, Id> getContactOverrides(List<Id> contactIds) {
		Map<Id, Id> contactOverrides = new Map<Id, Id>();
		for (rosco_people__c rp : [
			SELECT contact__c, cc_contact_override__c
			FROM rosco_people__c
			WHERE contact__c IN :contactIds AND cc_contact_override__c != NULL
		]) {
			contactOverrides.put(rp.contact__c, rp.cc_contact_override__c);
		}
		return contactOverrides;
	}

	@TestVisible
	private static void logNebulaException(String method, Exception e) {
		Logger.error('RoscoCaseContactRole.' + method + ' Errors', e).addTag('apex').addTag('rosco');
		Logger.saveLog();
	}

	public static List<String> removeDuplicateEmails(List<String> caseContactRoles) {
		Set<String> uniqueEmais = new Set<String>(caseContactRoles);
		uniqueEmais.remove('');
		uniqueEmais.remove(null);
		return new List<String>(uniqueEmais);
	}

	public static String getCaseManagementDefaults(String fieldName) {
		String contactid_exclusion = '0030e00002JnUQcAAN';
		String fallback_accountid = '0010e00001JOFGPAA5';
		String fieldValue;

		if (RoscoCaseContactRole.caseManagementDefault.containsKey(fieldName)) {
			return RoscoCaseContactRole.caseManagementDefault.get(fieldName);
		}

		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
		if (cmfields.contains('rosco_case_sc_japan_email__c')) {
			RoscoCaseContactRole.caseManagementDefault.put(
				'rosco_case_sc_japan_email__c',
				String.valueOf(cm.get('rosco_case_sc_japan_email__c'))
			);
		}

		if (cmfields.contains('rosco_contactid_exclusion__c')) {
			contactid_exclusion = String.valueOf(cm.get('rosco_contactid_exclusion__c')) ??
				contactid_exclusion;
			RoscoCaseContactRole.caseManagementDefault.put(
				'rosco_contactid_exclusion__c',
				contactid_exclusion
			);
		}

		if (cmfields.contains('rosco_case_accountid__c')) {
			fallback_accountid = String.valueOf(cm.get('rosco_case_accountid__c')) ??
				fallback_accountid;
			RoscoCaseContactRole.caseManagementDefault.put(
				'rosco_case_accountid__c',
				fallback_accountid
			);
		}
		return RoscoCaseContactRole.caseManagementDefault.get(fieldName);
	}
}