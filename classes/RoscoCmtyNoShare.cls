/**
 * @Business: RoscoCmtyNoShare without sharing class - supports community app
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7276    2024-02-22    Jason's last changes linked to ticket SCLOUD-787 plus layout changes by Tanium Dev Team
 * SS-7277    2024-02-23    Jason's last changes linked to ticket SCLOUD-723 plus layout changes by Tanium Dev Team
 * SS-7976    2024-04-16    Fixed Japan case routing bug in method getCaseOwnerId
 * SS-7697    2024-04-17    Updated method getCaseOwnerId, added method routeCaseToPoland
 * SS-7698    2024-04-18    Updated method routeCaseToPoland, added method isPolandOnline
 * SS-7985    2024-05-14    Add Sub_Component
 * SS-8049    2024-07-15    Case ownership bug for Poland, Japan, Pubsec-Hybrid and sev 3
 * SS-8749    2024-07-24    Updated method getCaseOwnerId
 * SS-8803    2024-08-24    Updated method getCaseOwnerId
 * SS-9264    2024-09-27    Updated method createCase
 * SS-9296    2024-10-04    Remove case assignment
 * SS-9622    2024-12-03    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-10083   2025-01-24    Replace Case.ThreadId__c w/ Case.ThreadId_caseSensitive__c
 * SS-10739   2025-04-29    Updated method getContactId
 * SS-10826   2025-07-03    Updated method getContactId
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c and resolve issues
 */
public without sharing class RoscoCmtyNoShare {
	private static final String IT_DEPT = 'IT';
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	public static Map<String, String> closeCase(Map<String, String> caseObj) {
		Map<String, String> ret = new Map<String, String>();
		try {
			Case c = [SELECT Id FROM Case WHERE Id = :caseObj.get('Id') LIMIT 1];
			c.Status = 'Solved';
			c.Summary__c = caseObj.get('note');
			update c;
			ret.put('actionResult', 'SUCCESS');
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.closeCase ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	@TestVisible
	private static String populateCaseDescriptionHtml(Map<String, String> caseObj) {
		String caseDescriptionHtml;
		String caseDescription = caseObj.get('Description');
		String caseSubject = caseObj.get('Subject');
		String caseComponent = caseObj.get('Component');
		String caseSeverityTxt = caseObj.get('Severity');
		String caseSeverityReason = caseObj.get('SeverityReason');
		String caseTimeIncident = caseObj.get('TimeIncident');
		String caseDuration = caseObj.get('Duration');
		String caseFrequency = caseObj.get('Frequency');
		String caseComponentVersion = caseObj.get('ComponentVersion');
		String caseOS = caseObj.get('OS');
		String caseInfoCollected = caseObj.get('InfoCollected');
		String caseActionTaken = caseObj.get('ActionTaken');
		String caseNextSteps = caseObj.get('NextSteps');
		String casePreferredContact = caseObj.get('PreferredContact');

		caseDescriptionHtml = '<p><b>Subject:</b> ' + caseSubject + '</p><p> </p>';
		caseDescriptionHtml += '<p><b>Component:</b> ' + caseComponent + '</p><p> </p>';
		caseDescriptionHtml += '<p><b>Severity:</b> ' + caseSeverityTxt + '</p><p> </p>';
		if (caseSeverityReason.length() > 0) {
			caseDescriptionHtml +=
				'<p><b>Severity Reason:</b></p><p>' +
				caseSeverityReason.stripHtmlTags() +
				'</p><p> </p>';
		}
		if (caseTimeIncident.length() > 0) {
			caseDescriptionHtml += '<p><b>Incident Time:</b> ' + caseTimeIncident + '</p><p> </p>';
		}
		if (caseDuration.length() > 0) {
			caseDescriptionHtml += '<p><b>Duration:</b> ' + caseDuration.escapeHtml4() + '</p><p> </p>';
		}
		if (caseFrequency.length() > 0) {
			caseDescriptionHtml += '<p><b>Frequency:</b> ' + caseFrequency.escapeHtml4() + '</p><p> </p>';
		}
		if (caseComponentVersion.length() > 0) {
			caseDescriptionHtml +=
				'<p><b>Component Version:</b> ' +
				caseComponentVersion +
				'</p><p> </p>';
		}
		if (caseOS.length() > 0) {
			caseDescriptionHtml += '<p><b>Operating System:</b> ' + caseOS + '</p><p> </p>';
		}
		caseDescriptionHtml += '<p><b>Description:</b></p><p>' + caseDescription + '</p><p> </p>';
		if (caseInfoCollected.length() > 0) {
			caseDescriptionHtml += '<p><b>Info Collected:</b> ' + caseInfoCollected + '</p><p> </p>';
		}
		if (caseActionTaken.length() > 0) {
			caseDescriptionHtml += '<p><b>Action Taken:</b> ' + caseActionTaken + '</p><p> </p>';
		}
		if (caseNextSteps.length() > 0) {
			caseDescriptionHtml += '<p><b>Next Steps:</b> ' + caseNextSteps + '</p><p> </p>';
		}
		if (casePreferredContact.length() > 0) {
			caseDescriptionHtml +=
				'<p><b>Preferred Contact:</b></p><p> ' +
				casePreferredContact +
				'</p><p> </p>';
		}
		return caseDescriptionHtml;
	}

	private static EnhancedReturnType routeCaseToPoland(
		String component,
		Decimal severity,
		String supportModel
	) {
		EnhancedReturnType routeCaseToPoland = new EnhancedReturnType(false, '');
		if (supportModel != 'Support Center (Poland)') {
			return routeCaseToPoland;
		}
		Boolean highSeverity = (severity < 3) ? true : false;
		Boolean polandIsOnline = isPolandOnline();
		Set<String> polandSupportComponents = CaseTriggerUtility.getPolandSupportComponents();

		if (polandSupportComponents.contains(component)) {
			if (!highSeverity || (highSeverity && polandIsOnline)) {
				routeCaseToPoland.retResult = true;
			}
			if (highSeverity && !polandIsOnline) {
				routeCaseToPoland.retData = 'Send Slack Alert';
			}
		}
		return routeCaseToPoland;
	}

	private static Boolean isPolandOnline() {
		Id polandQueueGroupId;
		Set<Id> userIds = new Set<Id>();
		DateTime past24hours = System.now().addDays(-1);
		UserServicePresence[] onlineMembers;
		try {
			polandQueueGroupId = [
				SELECT Id
				FROM Group
				WHERE DeveloperName = 'Omni_Poland_Support_Center'
				LIMIT 1
			]
			.Id;
		} catch (Exception e) {
			return false;
		}
		for (GroupMember groupMember : [
			SELECT Id, UserOrGroupId
			FROM GroupMember
			WHERE GroupId = :polandQueueGroupId
		]) {
			userIds.add(groupMember.UserOrGroupId);
		}
		onlineMembers = [
			SELECT Id
			FROM UserServicePresence
			WHERE UserId IN :userIds AND StatusStartDate > :past24hours AND StatusEndDate = NULL
		];
		return !onlineMembers.isEmpty();
	}

	public static Map<String, String> createCase(
		Map<String, String> caseObj,
		Map<String, String> caseFiles
	) {
		Map<String, String> ret = new Map<String, String>();
		String caseAccountId = caseObj.get('AccountId');
		String caseDescription = caseObj.get('Description');
		String caseDescription2 = caseDescription.stripHtmlTags();
		String caseDescriptionTxt = caseDescription2;
		String caseDescriptionHtml = populateCaseDescriptionHtml(caseObj);
		String caseSubject = caseObj.get('Subject');
		String caseComponent = caseObj.get('Component');
		String caseSubComponent = caseObj.get('Sub_Component');
		String caseComponentVersion = caseObj.get('ComponentVersion');
		String caseOS = caseObj.get('OS');
		Decimal caseSeverity = (caseObj.get('Severity') == '1')
			? 1
			: (caseObj.get('Severity') == '2') ? 2 : 3;
		String contactId;
		Id supportCaseRecordTypeId = Utility.getRecordTypeIdByAPIName('Case', 'Support');
		Map<String, Blob> rtaBlobs = getRTABlobs(caseDescriptionHtml);
		Case_Management__c cm = Case_Management__c.getInstance();
		Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

		contactId = getContactId(Userinfo.getUserId());
		if (contactId != null || contactId != '') {
			if (caseAccountId == null || caseAccountId == '') {
				caseAccountId = getAccountId(contactId);
			}
		}

		Case newCaseObj = new Case(
			AccountId = caseAccountId,
			Component_Version__c = caseComponentVersion,
			Component__c = caseComponent,
			Sub_Component__c = caseSubComponent,
			Description = 'Case description provided via Tanium support portal:' + caseDescriptionTxt,
			OperatingSystem__c = caseOS,
			Origin = 'Community',
			RecordTypeId = supportCaseRecordTypeId,
			Severity_Community__c = String.valueOf(caseSeverity),
			Subject = caseSubject,
			Type = 'Incident',
			ContactId = contactId
		);

		if (Test.isRunningTest()) {
			newCaseObj.OwnerId = Utility.getQueueId('Service Cloud Tanium');
		}

		Database.SaveResult saveResult = Database.insert(newCaseObj);
		if (!saveResult.isSuccess()) {
			Logger.error('RoscoCmtyNoShare.create Errors', saveResult).addTag('apex');
			Logger.saveLog();
		}

		if (saveResult.isSuccess()) {
			Case[] cases = [SELECT Owner.Name, Id FROM Case WHERE Id = :saveResult.getId()];

			if (
				routeCaseToPoland(caseComponent, caseSeverity, getContactSupportModel(contactId)).retData ==
				'Send Slack Alert'
			) {
				String slackChannel = (Utility.getInstance(Url.getOrgDomainURL()) == 'Production')
					? SlackUtility.CHANNEL_SUPPORT_CENTER_TICKETS
					: SlackUtility.CHANNEL_ROSCO_DEBUG;

				CaseSendToAccountSlack.sendToAccountSlack(cases, slackChannel);
			}
		}

		ret.put('CaseId', String.valueOf(newCaseObj.Id));
		String caseId = newCaseObj.Id;
		String strFiles = '';
		for (String cid : caseFiles.keySet()) {
			if (caseFiles.get(cid) != null) {
				ContentDocumentLink cdl = new ContentDocumentLink(
					ContentDocumentId = cid,
					LinkedEntityId = newCaseObj.Id,
					ShareType = 'V',
					Visibility = 'AllUsers'
				);
				insert cdl;
				if (strFiles == '') {
					strFiles = caseFiles.get(cid);
				} else {
					strFiles += ', ' + caseFiles.get(cid);
				}
			}
		}
		if (strFiles == '') {
			caseDescriptionTxt += '\n\nAttached Files:\nNone';
			caseDescriptionHtml += '<p><b>Attached Files:</b></p><p>None</p><p> </p>';
		} else {
			caseDescriptionTxt += '\n\nAttached Files: ' + strFiles;
			caseDescriptionHtml += '<p><b>Attached Files:</b></p><p>' + strFiles + '</p><p> </p>';
		}
		ret.put('caseDescription', caseDescriptionHtml);
		Map<String, String> caseInfo = RoscoCmtyNoShare.getCaseInfo(caseId);
		String threadid = caseInfo.get('threadid');
		ret.put('threadid', threadid);
		ret.put('caseNumber', caseInfo.get('caseNumber'));
		String userEmail = UserInfo.getUserEmail();
		ret.put('email', userEmail);
		String instanceName = [SELECT InstanceName FROM Organization LIMIT 1].InstanceName;
		String supportEmail = 'soa@tanium.com';
		String supportEmailSetting = RoscoCmtyNoShare.getRoscoSetting('rosco_email_apex__c');
		if (supportEmailSetting != null) {
			if (supportEmailSetting != '') {
				supportEmail = supportEmailSetting;
			}
		}
		List<String> to = new List<String>();
		if (!Utility.isSandbox()) {
			to.add(supportEmail);
		}
		String emailSubject = '(Description->Email Slipstream) ' + threadid;
		String htmlBody =
			'<p>Case submitted via Tanium support portal by ' +
			userEmail +
			':</p><p> </p>' +
			caseDescriptionHtml;
		String textBody =
			'Case submitted via Tanium support portal by ' +
			userEmail +
			':\n' +
			caseDescriptionTxt;
		String owea = '0D23R0000000093SAA';
		if (cmfields.contains('rosco_owea__c')) {
			if (cm.get('rosco_owea__c') != null) {
				if (cm.get('rosco_owea__c') != '') {
					owea = String.valueOf(cm.get('rosco_owea__c'));
				}
			}
		}
		htmlBody = getFixedMarkupForFeedItem(htmlBody);
		htmlBody = getRTAToBase64HTML(htmlBody, rtaBlobs);
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
		mail.setOrgWideEmailAddressId(owea);
		mail.setToAddresses(to);
		mail.setSubject(emailSubject);
		mail.setHtmlBody(htmlBody);
		mail.setPlainTextBody(textBody);
		mail.setUseSignature(false);
		try {
			Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.createCase Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getAccountId(String contactId) {
		String ret;
		try {
			String soql = 'SELECT AccountId ' + 'FROM Contact ' + 'WHERE Id = \'' + contactId + '\'';
			List<Contact> contacts = Database.query(soql);
			if (!contacts.isEmpty()) {
				for (Contact c : contacts) {
					ret = c.AccountId;
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getAccountId Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getAccountContactRelation(String contactId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT AccountId, ' +
				'Roles, ' +
				'Account.Name ' +
				'FROM AccountContactRelation ' +
				'WHERE ContactId = \'' +
				contactId +
				'\'';
			List<AccountContactRelation> relations = Database.query(soql);
			if (!relations.isEmpty()) {
				for (AccountContactRelation r : relations) {
					if (r.Roles != null) {
						String roles = String.valueOf(r.Roles);
						if (roles.contains('Support Case')) {
							ret.put(String.valueOf(r.Account.Name), String.valueOf(r.AccountId));
						}
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getAccountContactRelation Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getArticleIdFromUrl(String url) {
		String ret = 'Sorry, article was not found!';
		try {
			String kbUrl = 't-b-d';
			if (url.containsIgnoreCase('?kburl=')) {
				List<String> aUrl = url.split('=');
				kbUrl = aUrl[aUrl.size() - 1];
			} else {
				List<String> aUrl = url.split('/');
				kbUrl = aUrl[aUrl.size() - 1];
			}
			String soql =
				'SELECT Id' +
				',Title' +
				',Summary ' +
				',Article_Body__c' +
				',FirstPublishedDate' +
				',LastPublishedDate ' +
				',RecordType.Name ' +
				',UrlName ' +
				'FROM Knowledge__kav ' +
				'WHERE UrlName = \'' +
				kbUrl +
				'\' ' +
				'AND PublishStatus = \'Online\' ' +
				'AND IsVisibleInCsp = true ' +
				'UPDATE VIEWSTAT';

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					ret = kb.Id;
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getArticleFromURL Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, String> getArticleInitVuln(String articleId) {
		Map<String, String> ret = new Map<String, String>();
		ret.put('Id', '');
		ret.put('Title', 'Sorry, article was not found!');
		ret.put('Summary', 'Sorry, article was not found!!');
		ret.put('Body', 'Sorry, article was not found!!!');
		ret.put('iFrameURL', '');
		ret.put('URL', '');
		try {
			String whereClause = '';
			if (articleId.left(2) == 'ka') {
				whereClause = 'AND Id = \'' + articleId + '\'';
			} else {
				whereClause = 'AND ArticleNumber = \'' + articleId + '\'';
			}
			String soql =
				'SELECT ArticleNumber' +
				',Title' +
				',Summary ' +
				',Article_Body__c' +
				',FirstPublishedDate' +
				',LastPublishedDate ' +
				',RecordType.Name ' +
				',UrlName ' +
				'FROM Knowledge__kav ' +
				'WHERE PublishStatus = \'Online\' ' +
				whereClause +
				' ' +
				'AND IsVisibleInCsp = true ' +
				'AND RecordType.Name = \'Tanium Vulnerability\' ' +
				'UPDATE VIEWSTAT';

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					ret.put('Id', kb.Id);
					ret.put('Title', kb.Title);
					ret.put('Summary', kb.Summary);
					ret.put('Body', String.valueOf(kb.Article_Body__c));
					ret.put('iFrameURL', '');
					ret.put('URL', kb.UrlName);
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getArticleInitVuln Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getContactSupportModel(String contactId) {
		String ret = '';
		try {
			String soql =
				'SELECT Support_Model__c ' +
				'FROM Account ' +
				'WHERE Id IN (SELECT AccountId FROM Contact WHERE Id = \'' +
				contactId +
				'\')';

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				for (Account a : accounts) {
					if (a.Support_Model__c != null) {
						ret = String.valueOf(a.Support_Model__c);
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getContactSupportModel Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getContactDetails(String contactId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT ' +
				'AccountId, ' +
				'Account.Name, ' +
				'Account.RecordType.Name ' +
				'FROM Contact ' +
				'WHERE Id = \'' +
				contactId +
				'\'';

			List<Contact> contacts = Database.query(soql);
			if (!contacts.isEmpty()) {
				for (Contact c : contacts) {
					ret.put('AccountId', String.valueOf(c.AccountId));
					ret.put('AccountName', String.valueOf(c.Account.Name));
					ret.put('CaseCreateProfile', 'long');
					ret.put('AccountType', String.valueOf(c.Account.RecordType.Name));
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getContactDetails Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getCaseInfo(String caseId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql = 'SELECT CaseNumber ' + 'FROM Case ' + 'WHERE Id = \'' + caseId + '\'';

			List<Case> caseRecords = Database.query(soql);
			if (!caseRecords.isEmpty()) {
				String threadId = EmailMessages.getFormattedThreadingToken(caseRecords[0].Id);
				ret.put('threadid', threadId);
				ret.put('caseNumber', caseRecords[0].CaseNumber);
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getCaseInfo Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getCommunityUrl() {
		String ret = 'https://support.tanium.com';
		try {
			String name = 'Tanium Customer Community';
			String soql = 'SELECT Id ' + 'FROM Network ' + 'WHERE Name = \'' + name + '\'';

			List<Network> networks = Database.query(soql);
			if (!networks.isEmpty()) {
				for (Network n : networks) {
					String url = Network.getLoginUrl(n.Id);
					List<String> lUrl = url.Split('/');
					ret = 'https://' + lUrl[2];
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getCommunityUrl Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getContactId(String userId) {
		String ret = null;

		String soql =
			'SELECT ContactId, Email, Role_Category__c ' +
			'FROM User ' +
			'WHERE Id = \'' +
			userId +
			'\'';

		List<User> users = Database.query(soql);

		if (users.isEmpty()) {
			return ret;
		}

		if (users[0].ContactId != null) {
			ret = users[0].ContactId;
		} else {
			if (users[0].Role_Category__c == IT_DEPT) {
				ret = getContactIdByEmail(users[0]);
			}
		}
		if (ret == null) {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			ret = '0030e00002VWscDAAT';
			if (cm.get('rosco_case_defaultcontact__c') != null) {
				ret = String.valueOf(cm.get('rosco_case_defaultcontact__c'));
			}
		}
		return ret;
	}

	private static String getContactIdByEmail(User user) {
		Contact contact;
		try {
			contact = [SELECT Id FROM Contact WHERE Email = :user.Email LIMIT 1];
		} catch (Exception e) {
			contact = null;
		}
		return contact == null ? null : '' + contact.Id;
	}

	public static Map<String, String> getCustomerIdAccount(String customerId) {
		Map<String, String> ret = new Map<String, String>();
		ret.put('result', 'Customer License Id not found');
		try {
			String soql =
				'SELECT ServerDeployment__r.Account__c,ServerDeployment__r.Account__r.Name,Expiration_Date__c ' +
				'FROM Tanium_Server_License__c ' +
				'WHERE LicenseID__c  = ' +
				customerId +
				' LIMIT 1';

			List<Tanium_Server_License__c> licenses = Database.query(soql);
			if (!licenses.isEmpty()) {
				if (licenses[0].Expiration_Date__c < Datetime.now()) {
					ret.put('result', 'Customer License Id has expired');
				} else {
					ret.put('result', 'Ok');
					ret.put('accountId', licenses[0].ServerDeployment__r.Account__c);
					ret.put('accountName', licenses[0].ServerDeployment__r.Account__r.Name);
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getCustomerIdAccount Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getFixedMarkupForFeedItem(String html) {
		String ret = html;
		ret = ret.replaceAll('<br>', ' ');
		return ret;
	}

	public static String getKBRecordType(String sKbUrlorNumber) {
		String ret = 'undefined';
		try {
			List<Knowledge__kav> kbs = [
				SELECT RecordType.Name
				FROM Knowledge__kav
				WHERE
					PublishStatus = 'Online'
					AND IsVisibleInCsp = TRUE
					AND (UrlName = :sKbUrlorNumber
					OR ArticleNumber = :sKbUrlorNumber)
				LIMIT 1
			];
			if (kbs.size() > 0) {
				ret = String.valueOf(kbs[0].RecordType.Name);
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getKBType Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getKBArticleId(String sKbUrlorNumber) {
		String ret = 'undefined';
		try {
			List<Knowledge__kav> kbs = [
				SELECT KnowledgeArticleId
				FROM Knowledge__kav
				WHERE
					PublishStatus = 'Online'
					AND IsVisibleInCsp = TRUE
					AND (UrlName = :sKbUrlorNumber
					OR ArticleNumber = :sKbUrlorNumber)
				LIMIT 1
			];
			if (kbs.size() > 0) {
				ret = String.valueOf(kbs[0].KnowledgeArticleId);
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getKBArticleId ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getRoscoSetting(String key) {
		String ret = '';
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			if (cmfields.contains(key)) {
				if (cm.get(key) != null) {
					ret = String.valueOf(cm.get(key));
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getRoscoSetting ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, Blob> getRTABlobs(String html) {
		Map<String, Blob> ret = new Map<String, Blob>();
		try {
			Matcher imgMatcher = Pattern.compile('<img(.+?)>').matcher(html);
			Integer count = 0;
			while (imgMatcher.find()) {
				String imageTag = imgMatcher.group();
				String imageURL = imageTag.substringBetween(' src="', '"');
				String decodedURL = imageURL.unescapeHtml4();
				PageReference page = new PageReference(getCommunityUrl() + decodedURL);
				Blob b = page.getContent();
				ret.put(decodedURL, b);
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getRTABlobs ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getRTAToBase64HTML(String html, Map<String, Blob> rtaBlobMap) {
		String ret = html;
		try {
			Integer count = 0;
			for (String r : rtaBlobMap.keySet()) {
				String b64 = EncodingUtil.base64Encode(rtaBlobMap.get(r));
				String newImgTag = '<img src="data:image/png;base64,' + b64 + '" />';

				ret = ret.replace('<img src="' + r + '">', newImgTag);
				count += 1;
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getRTAToBase64HTML ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getRTAToFileHTML(String html, String caseId, Map<String, Blob> rtaBlobMap) {
		String ret = html;
		try {
			Integer count = 0;
			for (String r : rtaBlobMap.keySet()) {
				ContentVersion contentVersion_1 = new ContentVersion(
					Title = 'inline-caseform-' + String.valueOf(count) + '.png',
					PathOnClient = 'inline-caseform-' + String.valueOf(count) + '.png',
					VersionData = rtaBlobMap.get(r),
					origin = 'H',
					FirstPublishLocationId = caseId
				);
				insert contentVersion_1;
				ContentVersion contentVersion_2 = [
					SELECT Id, Title, ContentDocumentId
					FROM ContentVersion
					WHERE Id = :contentVersion_1.Id
					LIMIT 1
				];
				ret = ret.replace(
					'<img src="' +
					r +
					'">',
					'<img src="sfdc://' +
					String.valueOf(contentVersion_2.contentdocumentid) +
					'"></img>'
				);
				count += 1;
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getRTAToFileHTML ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String getUserProfileName(String userId) {
		String ret = '';
		try {
			Profile p = [SELECT Name FROM Profile WHERE Id = :userinfo.getProfileid()];
			ret = String.valueOf(p.name);
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getUserProfileName ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getVulnInitVuln() {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			String soql =
				'SELECT ArticleNumber' +
				',Title' +
				',Summary ' +
				',Article_Body__c' +
				',FirstPublishedDate' +
				',LastPublishedDate ' +
				',RecordType.Name ' +
				',UrlName ' +
				',CreatedDate ' +
				',LastModifiedDate ' +
				'FROM Knowledge__kav ' +
				'WHERE PublishStatus = \'Online\' ' +
				'AND IsVisibleInCsp = true ' +
				'AND RecordType.Name = \'Tanium Vulnerability\' ' +
				'ORDER BY Title DESC ' +
				'UPDATE VIEWSTAT';

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					Map<String, String> kbTemp = new Map<String, String>();
					kbTemp.put('Id', kb.Id);
					kbTemp.put('ArticleNumber', kb.ArticleNumber);
					kbTemp.put('Title', kb.Title);
					kbTemp.put(
						'Label',
						kb.Title +
						' (' +
						String.valueOf(kb.FirstPublishedDate.formatGMT('yyyy-MM-dd')) +
						')'
					);
					kbTemp.put('Summary', kb.Summary);
					kbTemp.put('Body', String.valueOf(kb.Article_Body__c));
					kbTemp.put(
						'FirstPublishedDate',
						String.valueOf(kb.FirstPublishedDate.formatGMT('yyyy-MM-dd'))
					);
					kbTemp.put(
						'LastPublishedDate',
						String.valueOf(kb.LastPublishedDate.formatGMT('yyyy-MM-dd'))
					);
					kbTemp.put('CreatedDate', String.valueOf(kb.CreatedDate));
					kbTemp.put('LastModifiedDate', String.valueOf(kb.LastModifiedDate));

					ret.add(kbTemp);
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.getVulnInitVuln ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String isSubscribed(String subscriptionType, Id userId) {
		String ret = 'false';
		try {
			String soql =
				'SELECT Subscribed__c ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE User__c = \'' +
				userId +
				'\' ' +
				'AND Type__c = \'' +
				subscriptionType +
				'\' ' +
				'AND Subscribed__c = true';

			List<Rosco_Subscription__c> subscriptions = Database.query(soql);
			if (!subscriptions.isEmpty()) {
				ret = 'true';
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.isSubscribed ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static List<Map<String, String>> searchTaniumVuln(String searchText) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			String soql =
				'SELECT Id, ' +
				'Title, ' +
				'Summary, ' +
				'Article_Body__c, ' +
				'ArticleNumber, ' +
				'RecordTypeId, ' +
				'RecordType.Name, ' +
				'LastPublishedDate, ' +
				'FirstPublishedDate ' +
				'FROM Knowledge__kav ' +
				'WHERE RecordType.Name = \'Tanium Vulnerability\' ' +
				'AND PublishStatus = \'Online\'';

			List<Knowledge__kav> kbs = Database.query(soql);
			if (!kbs.isEmpty()) {
				for (Knowledge__kav kb : kbs) {
					Boolean isMatch = false;
					if (String.valueOf(kb).containsIgnoreCase(searchText) || searchText == '') {
						Map<String, String> kbTmp = new Map<String, String>();
						kbTmp.put('Id', kb.Id);
						kbTmp.put('Title', kb.Title);
						kbTmp.put('Summary', kb.Summary);
						kbTmp.put('ArticleNumber', kb.ArticleNumber);
						kbTmp.put('FirstPublishedDate', kb.FirstPublishedDate.formatGMT('yyyy-MM-dd'));
						kbTmp.put('LastPublishedDate', kb.LastPublishedDate.formatGMT('yyyy-MM-dd'));
						kbTmp.put('Category', 'Tanium Vulnerability');
						kbTmp.put('Type', 'Tanium Vulnerability');
						kbTmp.put('Popularity', '50');
						ret.add(kbTmp);
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.searchTaniumVuln ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String subscriptionToggle(String subscriptionType, Id userId) {
		String ret = 'false';
		try {
			String soql =
				'SELECT Subscribed__c ' +
				'FROM Rosco_Subscription__c ' +
				'WHERE User__c = \'' +
				userId +
				'\' ' +
				'AND Type__c = \'' +
				subscriptionType +
				'\'';

			List<Rosco_Subscription__c> subscriptions = Database.query(soql);
			if (!subscriptions.isEmpty()) {
				for (Rosco_Subscription__c s : subscriptions) {
					if (s.Subscribed__c == true) {
						s.Subscribed__c = false;
					} else {
						s.Subscribed__c = true;
						ret = 'true';
					}
					update s;
				}
			} else {
				Rosco_Subscription__c s = new Rosco_Subscription__c(
					Subscribed__c = true,
					Type__c = subscriptionType,
					User__c = userId
				);
				insert s;
				ret = 'true';
			}
		} catch (Exception e) {
			Logger.error('RoscoCmtyNoShare.subscriptionToggle ERRORS', e);
			Logger.saveLog();
		}
		return ret;
	}
}