/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @AUTHOR: Jason Johnson. Tanium Dev Team
 * @BUSINESS: Controller class
 * RequestId  ModifiedDate  Description
 * SS-7175    2023-12-01    Updated Time Logging functionality, layout changes
 * SS-9825    2024-12-07    Updated method getPreSalesAccountTime
 * SS-10251   2025-02-27    Remove Constellant Dev references and replace it with Tanium Developer Users
 * SS-10265   2025-03-07    Update Constellant Dev PSA Conditions
 * SS-10624   2025-05-15    Updated methods initRoscoActionContactSupport, saveRoscoActionContactSupport, getAccount, future methods, and getUniqueAlias
 * SS-11447   2025-11-04    Updated methods saveRoscoActionContactSupport, setContactSupportOption, saveRoscoActionAccountSupport, saveEmailDomain
 * SS-12313   2026-01-06    Updated methods initRoscoActionContactSupport, saveRoscoActionContactSupport, added future method saveContactFlashMessage
 * SS-13294   2026-05-27    Updated method enableUser, added permission set assignments
 * SS-13497   2026-07-13    Remove deprecated fields for project kondo group 2
 */
public without sharing class RoscoAction {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@AuraEnabled
	public static String delKnowledgeArticleTopics(String entityId, String topicName) {
		String ret = '';
		try {
			String netId = [SELECT Name FROM Network WHERE Name = 'Tanium Customer Community'].Id;
			TopicAssignment ta = [
				SELECT Id
				FROM TopicAssignment
				WHERE entityId = :entityId AND NetworkId = :netId
				LIMIT 1
			];
			delete ta;
		} catch (Exception e) {
			Logger.error('RoscoAction.delKnowledgeArticleTopics Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getAvailableUserTimeZones() {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			List<PicklistEntry> entries = Schema.SObjectType.User.fields.TimeZoneSidKey.picklistValues;
			for (Schema.PicklistEntry tz : entries) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('label', tz.getLabel());
				obj.put('value', tz.getValue());
				ret.add(obj);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getAvailableUserTimeZones Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getModuleOptions() {
		return RoscoTag.getModuleOptions();
	}

	@AuraEnabled
	public static void enableUser(String contactId, String profileName, String devUser) {
		try {
			Map<String, String> profiles = getProfiles();
			String profileId = profiles.get(profileName);

			Contact c = [SELECT FirstName, LastName, Email FROM Contact WHERE Id = :contactId];

			String email = String.valueOf(c.Email);
			String first = String.valueOf(c.FirstName);
			String last = String.valueOf(c.LastName);
			String userId;
			String uniqueAlias = getUniqueAlias();
			String soql = 'SELECT Id ' + 'FROM User ' + 'WHERE ContactId = \'' + contactId + '\' ';

			List<User> users = Database.query(soql);
			if (!users.isEmpty()) {
				User userObj = users[0];
				userObj.isActive = true;
				userObj.EmailEncodingKey = 'UTF-8';
				userObj.ProfileId = profileId;
				userObj.FederationIdentifier = email;
				update userObj;
				userId = userObj.Id;
			} else {
				User userObj = new User(
					Email = email,
					ContactId = contactId,
					FirstName = first,
					LastName = last,
					Username = email,
					Alias = uniqueAlias,
					CommunityNickname = uniqueAlias,
					TimeZoneSidKey = 'America/Los_Angeles',
					LocaleSidKey = 'en_US',
					EmailEncodingKey = 'UTF-8',
					ProfileId = profileId,
					LanguageLocaleKey = 'en_US',
					FederationIdentifier = email
				);
				insert userObj;
				userId = userObj.Id;
			}
			if (devUser == 'true') {
				List<PermissionSetAssignment> psAssignments = new List<PermissionSetAssignment>();
				Id constellantDevPermSetId = [
					SELECT Id
					FROM PermissionSet
					WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
				]
				.Id;

				Id partnerCaseAccessPermSetId = [
					SELECT Id
					FROM PermissionSet
					WHERE Name = :Constants.PARTNER_CASE_ACCESS
				]
				.Id;

				Id zoominUserPermSetId = [
					SELECT Id
					FROM PermissionSet
					WHERE Name = :Constants.ZOOMIN_COMMUNITY_CLOUD_PERM_SET
				]
				.Id;

				psAssignments.add(
					new PermissionSetAssignment(
						PermissionSetId = constellantDevPermSetId,
						AssigneeId = userId
					)
				);

				psAssignments.add(
					new PermissionSetAssignment(
						PermissionSetId = partnerCaseAccessPermSetId,
						AssigneeId = userId
					)
				);

				psAssignments.add(
					new PermissionSetAssignment(
						PermissionSetId = zoominUserPermSetId,
						AssigneeId = userId
					)
				);
				List<Database.SaveResult> saveResult = Database.insert(psAssignments, false);
				Logger.logDatabaseErrors(
						LoggingLevel.ERROR,
						'RoscoAction.enableUser Errors',
						saveResult
					)
					.addTag('apex');
				Logger.saveLog();
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.enableUser Errors', e).setRecordId(contactId);
			Logger.saveLog();
			throw new AuraHandledException('Error creating new user ' + e.getMessage());
		}
	}

	public static String getUniqueAlias() {
		String uniqueAlias;
		String dateTimeString = Datetime.now().format('yyMMddHHmmss');
		Integer year, month, day, hours, minutes, seconds;

		year = Integer.valueOf(dateTimeString.substring(0, 2));
		uniqueAlias = String.fromCharArray(new List<Integer>{ (year + 40) });
		month = Integer.valueOf(dateTimeString.substring(2, 4));
		uniqueAlias += String.fromCharArray(new List<Integer>{ (month + 64) });
		day = Integer.valueOf(dateTimeString.substring(4, 6));
		uniqueAlias += (day < 10)
			? String.fromCharArray(new List<Integer>{ (day + 48) })
			: String.fromCharArray(new List<Integer>{ (day + 55) });
		hours = Integer.valueOf(dateTimeString.substring(6, 8));
		uniqueAlias += String.fromCharArray(new List<Integer>{ (hours + 64) });
		minutes = Integer.valueOf(dateTimeString.substring(8, 10));
		uniqueAlias += String.valueOf(minutes);
		seconds = Integer.valueOf(dateTimeString.substring(10, 12));
		uniqueAlias += String.valueOf(seconds);
		return uniqueAlias;
	}

	public static Account getAccount(String contactId) {
		Id accountId = null;
		try {
			accountId = [SELECT AccountId FROM Contact WHERE Id = :contactId].AccountId;
		} catch (Exception e) {
			Logger.error('RoscoAction.getAccount Errors', e);
			Logger.saveLog();
			return null;
		}
		return [
			SELECT Id, Type, Tech_Partner_Program_Tier__c, RecordType.Name
			FROM Account
			WHERE Id = :accountId
		];
	}

	public static String getAccountId2(String opportunityId) {
		String ret = '';
		try {
			ret = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId].AccountId;
		} catch (Exception e) {
			Logger.error('RoscoAction.getAccountId2 Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getAccountOpportunities(String recordId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Map<String, String> noOpp = new Map<String, String>();
		noOpp.put('label', 'No Opportunity');
		noOpp.put('value', '');
		ret.add(noOpp);
		String accountId = recordId;
		if (recordId.left(3) == '006') {
			accountId = [SELECT AccountId FROM Opportunity WHERE Id = :recordId].AccountId;
		} else if (recordId.left(3) == '500') {
			accountId = [SELECT AccountId FROM Case WHERE Id = :recordId].AccountId;
		}
		String soql =
			'SELECT Id, Name, StageName,CloseDate ' +
			'FROM Opportunity ' +
			'WHERE AccountId = \'' +
			accountId +
			'\' ';

		List<Opportunity> opps = Database.query(soql);
		if (!opps.isEmpty()) {
			for (Opportunity o : opps) {
				Map<String, String> opp = new Map<String, String>();
				if (
					o.StageName.containsIgnoreCase('closed') ||
					o.StageName == 'POC' ||
					o.StageName.containsIgnoreCase('fail')
				) {
					opp.put('label', o.Name + ' | ' + o.Stagename + ' | ' + o.CloseDate);
				} else {
					opp.put('label', '*' + o.Name + ' | ' + o.Stagename + ' | ' + o.CloseDate);
				}
				opp.put('value', o.Id);
				ret.add(opp);
			}
		}
		return ret;
	}

	public static String getEmailDomainId(String domain) {
		String ret = '';
		try {
			String soql =
				'SELECT Id' +
				' FROM Rosco_domain__c' +
				' WHERE name = \'' +
				domain +
				'\'' +
				' LIMIT 1';

			List<Rosco_domain__c> domains = Database.query(soql);
			if (!domains.isEmpty()) {
				ret = domains[0].Id;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getEmailDomainId Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getEmailDomains(String accountId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			String soql =
				'SELECT Id, Name, user_automation__c, Auto_register_developer_tanium_com__c' +
				' FROM Rosco_domain__c' +
				' WHERE Account__c = \'' +
				accountId +
				'\'' +
				' ORDER BY Name DESC';

			List<Rosco_domain__c> domains = Database.query(soql);
			for (Rosco_domain__c domain : domains) {
				Map<String, String> tmpmap = new Map<String, String>();
				if (domain.user_automation__c == null) {
					tmpMap.put('automation', 'No Automation');
				} else {
					tmpMap.put('automation', String.valueOf(domain.user_automation__c).trim());
				}
				tmpmap.put('domain', String.valueOf(domain.name).trim());
				tmpMap.put(
					'developer',
					String.valueOf(domain.Auto_register_developer_tanium_com__c).trim()
				);
				tmpMap.put('Id', String.valueOf(domain.Id));
				ret.add(tmpMap);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getEmailDomains Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getAccountInfo(String accountId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT Id,Name,Support_Model__c,Slack_Channel_Id__c,MSSP_Partner__c  ' +
				'FROM Account ' +
				'WHERE Id = \'' +
				accountId +
				'\' ' +
				'LIMIT 1';

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				ret.put('Name', accounts[0].Name);
				String sModel = '';
				ret.put('SupportModel', sModel);
				if (accounts[0].Support_Model__c != null) {
					sModel = String.valueOf(accounts[0].Support_Model__c);
				}
				ret.put('SupportModel', sModel);
				String sSlackId = '';
				if (accounts[0].Slack_Channel_Id__c != null) {
					sSlackId = String.valueOf(accounts[0].Slack_Channel_Id__c);
				}
				ret.put('SlackId', sSlackId);
				String hasMSSPPartner = 'false';
				if (accounts[0].MSSP_Partner__c != null) {
					hasMSSPPartner = 'true';
				}
				ret.put('hasMSSPPartner', hasMSSPPartner);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getAccountInfo Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getAccountTime(String accountId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			Boolean requestingUserisMgr = isUserMgr();
			String soql =
				'SELECT Minutes__c, User__c, User__r.Email, CreatedDate, LaborDate__c, LaborCategory__c, LaborSubCategory__c, LaborChildCategory__c' +
				' FROM Rosco_Time__c' +
				' WHERE Account__c = \'' +
				accountId +
				'\'' +
				' AND Case__c = null' +
				' AND Opportunity__c = null' +
				' AND (LaborDate__c = LAST_N_DAYS:90 OR LaborDate__c > LAST_N_DAYS:90) ' +
				' ORDER BY LaborDate__c DESC ' +
				' LIMIT 50';

			List<Rosco_Time__c> aTime = Database.query(soql);
			String userId = UserInfo.getUserId();
			Integer caseTime = 0;
			Integer userTime = 0;
			Datetime removeCutoff = (System.now()).addDays(-7);
			for (Rosco_Time__c a : aTime) {
				Map<String, String> tmpmap = new Map<String, String>();
				tmpmap.put('User', String.valueOf(a.User__r.Email).trim());
				tmpMap.put('Minutes', a.Minutes__c != 0 ? String.valueOf(a.Minutes__c).trim() : '');
				tmpMap.put('CreatedDate', a.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
				tmpMap.put('Date', a.LaborDate__c.formatGMT('yyyy-MM-dd'));
				tmpMap.put('LaborCategory', a.LaborCategory__c);
				tmpMap.put('LaborSubCategory', a.LaborSubCategory__c);
				tmpMap.put('LaborChildCategory', a.LaborChildCategory__c);
				tmpMap.put('removable', 'false');
				if (String.valueOf(a.User__c) == userId) {
					if (a.LaborDate__c > removeCutoff) {
						tmpMap.put('removable', 'true');
					}
				} else if (requestingUserisMgr) {
					tmpMap.put('removable', 'true');
				}
				ret.add(tmpMap);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getAccountTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static List<String> getDevUsers() {
		List<String> ret = new List<String>();

		for (PermissionSetAssignment psa : [
			SELECT AssigneeId
			FROM PermissionSetAssignment
			WHERE
				PermissionSetId IN (
					SELECT Id
					FROM PermissionSet
					WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
				)
		]) {
			ret.add(String.valueOf(psa.AssigneeId));
		}
		return ret;
	}

	public static String getFlash(String accountId) {
		String ret = '';
		try {
			String soql =
				'SELECT case_flash__c ' +
				'FROM Rosco_Account__c ' +
				'WHERE account__c = \'' +
				accountId +
				'\'';

			List<Rosco_Account__c> raccounts = Database.query(soql);
			if (!raccounts.isEmpty()) {
				ret = String.valueOf(raccounts[0].case_flash__c);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getFlash Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static List<String> getFrozenUsers() {
		List<String> ret = new List<String>();
		try {
			String soql = 'SELECT UserId FROM UserLogin WHERE isFrozen=true';
			List<UserLogin> users = Database.query(soql);
			if (!users.isEmpty()) {
				for (UserLogin u : users) {
					ret.add(String.valueOf(u.UserId));
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getFrozenUsers Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getUserTime(String type) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			Boolean requestingUserisMgr = isUserMgr();
			String soql =
				'SELECT Minutes__c, ' +
				'User__c, ' +
				'User__r.Email, ' +
				'CreatedDate, ' +
				'LaborDate__c, ' +
				'LaborCategory__c,' +
				'LaborSubCategory__c, ' +
				'LaborChildCategory__c, ' +
				'Account__c, ' +
				'Account__r.Name, ' +
				'Case__c, ' +
				'Case__r.Subject, ' +
				'Case__r.CaseNumber, ' +
				'Opportunity__c, ' +
				'Opportunity__r.Name ' +
				' FROM Rosco_Time__c' +
				' WHERE User__c = \'' +
				UserInfo.getUserId() +
				'\'' +
				' AND (LaborDate__c = LAST_N_DAYS:90 OR LaborDate__c > LAST_N_DAYS:90) ';

			if (type == 'opportunity') {
				soql += 'AND Opportunity__c != null ';
			} else if (type == 'case') {
				soql += 'AND Case__c != null ';
			} else if (type == 'account') {
				soql += 'AND Account__c != null ';
			}
			soql += ' ORDER BY LaborDate__c DESC ' + ' LIMIT 100';

			List<Rosco_Time__c> aTime = Database.query(soql);
			String userId = UserInfo.getUserId();
			Integer caseTime = 0;
			Integer userTime = 0;
			Datetime removeCutoff = (System.now()).addDays(-7);
			for (Rosco_Time__c a : aTime) {
				Map<String, String> tmpmap = new Map<String, String>();
				if (!nullOrEmpty(a.Opportunity__c)) {
					tmpmap.put('Subject', a.Opportunity__r.Name);
					tmpmap.put('Type', 'Opportunity');
					tmpmap.put('objectId', a.Opportunity__c);
				} else if (!nullOrEmpty(a.Case__c)) {
					tmpmap.put('Subject', a.Case__r.CaseNumber + ' - ' + a.Case__r.Subject);
					tmpmap.put('Type', 'Case');
					tmpmap.put('objectId', a.Case__c);
				} else {
					tmpmap.put('Subject', a.Account__r.Name);
					tmpmap.put('Type', 'Account');
					tmpmap.put('objectId', a.Account__c);
				}
				tmpmap.put('User', String.valueOf(a.User__r.Email).trim());
				tmpMap.put('Minutes', String.valueOf(a.Minutes__c).trim());
				tmpMap.put('CreatedDate', a.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
				tmpMap.put('Date', a.LaborDate__c.formatGMT('yyyy-MM-dd'));
				tmpMap.put('LaborCategory', a.LaborCategory__c);
				tmpMap.put('LaborSubCategory', a.LaborSubCategory__c);
				tmpMap.put('LaborChildCategory', a.LaborChildCategory__c);
				tmpMap.put('removable', 'false');
				if (String.valueOf(a.User__c) == userId) {
					if (a.LaborDate__c > removeCutoff) {
						tmpMap.put('removable', 'true');
					}
				} else if (requestingUserisMgr) {
					tmpMap.put('removable', 'true');
				}
				ret.add(tmpMap);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getUserTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getUserTimeLookup(String searchKey, String type) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			String accountId;
			String opportunityId;
			if (searchKey == '') {
				Case_Management__c cm = Case_Management__c.getInstance();
				Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
				if (cmfields.contains('rosco_time_internal_account__c')) {
					if (!nullOrEmpty(cm.get('rosco_time_internal_account__c'))) {
						accountId = String.valueOf(cm.get('rosco_time_internal_account__c'));
					}
				}
				if (cmfields.contains('rosco_time_internal_opportunity__c')) {
					if (!nullOrEmpty(cm.get('rosco_time_internal_opportunity__c'))) {
						opportunityId = String.valueOf(cm.get('rosco_time_internal_opportunity__c'));
					}
				}
			}
			String soql = 'SELECT Id, ' + 'Name ' + 'FROM Account ';
			if (nullOrEmpty(accountId)) {
				soql +=
					'WHERE Name LIKE \'' +
					searchKey +
					'%\' ' +
					'OR Name LIKE \'%' +
					searchKey +
					'%\' ' +
					'ORDER BY Name DESC ' +
					'LIMIT 20 ';
			} else {
				soql += 'WHERE Id = \'' + accountId + '\'';
			}

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				for (Account a : accounts) {
					Map<String, String> account = new Map<String, String>();
					account.put('id', a.Id);
					account.put('label', a.Name + ' (Account)');
					ret.add(account);
				}
			}
			if (searchKey != '') {
				String soql2 =
					'SELECT Id, ' +
					'Subject ' +
					'FROM Case ' +
					'WHERE Subject LIKE \'' +
					searchKey +
					'%\' ' +
					'OR Subject LIKE \'%' +
					searchKey +
					'%\' ' +
					'OR CaseNumber LIKE \'' +
					searchKey +
					'%\' ' +
					'OR CaseNumber LIKE \'%' +
					searchKey +
					'%\' ' +
					'ORDER BY CaseNumber DESC ' +
					'LIMIT 20 ';

				List<Case> cases = Database.query(soql2);
				if (!cases.isEmpty()) {
					for (Case c : cases) {
						Map<String, String> cas = new Map<String, String>();
						cas.put('id', c.Id);
						cas.put('label', c.Subject + ' (Case)');
						ret.add(cas);
					}
				}
			}
			String soql3 = 'SELECT Id, ' + 'Name ' + 'FROM Opportunity ';
			if (nullOrEmpty(opportunityId)) {
				soql3 +=
					'WHERE (Name LIKE \'' +
					searchKey +
					'%\' ' +
					'OR Name LIKE \'%' +
					searchKey +
					'%\') ' +
					'AND StageName != \'Failed\' AND StageName != \'CLOSED WON\' ' +
					'ORDER BY Name DESC ' +
					'LIMIT 20 ';
			} else {
				soql3 += 'WHERE Id = \'' + opportunityId + '\'';
			}

			List<Opportunity> opps = Database.query(soql3);
			if (!opps.isEmpty()) {
				for (Opportunity o : opps) {
					if (o.Name == 'Marketing Event Opportunity') {
						continue;
					}
					Map<String, String> opp = new Map<String, String>();
					opp.put('id', o.Id);
					opp.put('label', o.Name + ' (Opportunity)');
					ret.add(opp);
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getUserTimeLookup Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getTagLookup(String searchKey, String existing) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			String soql =
				'SELECT Id, Issue_Key__c,Issue_Summary__c  ' +
				'FROM Jira_Issue__c ' +
				'WHERE (Issue_Key__c LIKE \'%' +
				searchKey +
				'%\' ' +
				' OR Issue_Key__c LIKE \'' +
				searchKey +
				'%\') ';
			if (existing != '') {
				soql += 'AND Issue_Key__c NOT IN (' + existing + ') ';
			}
			soql += 'ORDER BY Issue_Key__c ASC ' + 'LIMIT 10';

			List<Jira_Issue__c> jiras = Database.query(soql);
			if (!jiras.isEmpty()) {
				for (Jira_Issue__c j : jiras) {
					Map<String, String> jira = new Map<String, String>();
					jira.put('jiraIssueSFId', j.Id);
					jira.put('jiraIssueKey', j.Issue_Key__c);
					jira.put('jiraSummary', j.Issue_Summary__c);
					ret.add(jira);
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getTagLookup Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String getKnowledgeArticleTopics(String entityId) {
		String ret = '';
		Map<String, String> retMap = new Map<String, String>();
		try {
			String soql =
				'SELECT TopicId, Topic.Name ' +
				'FROM TopicAssignment ' +
				'WHERE EntityId = \'' +
				entityId +
				'\' ' +
				'ORDER BY Topic.Name ASC ';

			List<TopicAssignment> assignments = Database.query(soql);
			if (!assignments.isEmpty()) {
				for (TopicAssignment a : assignments) {
					retMap.put(a.Topic.Name, 'Assigned');
				}
			}
			String netId = [SELECT Name FROM Network WHERE Name = 'Tanium Customer Community'].Id;
			String soql2 = 'SELECT Name ' + 'FROM Topic ' + 'WHERE NetworkId = \'' + netId + '\' ';
			List<Topic> topics = Database.query(soql2);
			if (!topics.isEmpty()) {
				for (Topic t : topics) {
					if (!retMap.containsKey(t.Name)) {
						retMap.put(t.Name, 'Available');
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getKnowledgeArticleTopics Errors', e);
			Logger.saveLog();
		}
		ret = JSON.serialize(retMap);
		return ret;
	}

	public static Map<String, String> getLoginHistory(String userId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT LoginTime,Status ' +
				'FROM LoginHistory ' +
				'WHERE UserId=\'' +
				userId +
				'\'';
			List<LoginHistory> logins = Database.query(soql);
			if (logins.isEmpty()) {
				ret.put('lastLoginDate', 'never');
				ret.put('lastLoginStatus', 'n/a');
			} else {
				for (LoginHistory l : logins) {
					ret.put('lastLoginDate', String.valueOf(l.LoginTime));
					ret.put('lastLoginStatus', String.valueOf(l.Status));
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getLoginHistory Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getRecordTags(String recordId, String includeClosed) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			String soql =
				'SELECT ' +
				'Account__c, ' +
				'Case__c, ' +
				'Comment__c, ' +
				'CreatedBy.Name, ' +
				'CreatedDate, ' +
				'Id, ' +
				'Impact__c, ' +
				'Jira_Issue__c, ' +
				'LastModifiedBy.Name, ' +
				'LastModifiedDate, ' +
				'Module__c, ' +
				'Name, ' +
				'Opportunity__c, ' +
				'tag__c, ' +
				'Account__r.Name, ' +
				'Account__r.Type, ' +
				'Account__r.RecordType.Name, ' +
				'Opportunity__r.Name, ' +
				'Opportunity__r.Type, ' +
				'Opportunity__r.RecordType.Name, ' +
				'Opportunity__r.StageName, ' +
				'Opportunity__r.CloseDate, ' +
				'Case__r.CaseNumber, ' +
				'Case__r.RecordType.Name, ' +
				'Case__r.Status, ' +
				'Case__r.Subject, ' +
				'Jira_Issue__r.Assignee__c, ' +
				'Jira_Issue__r.Component_Name__c, ' +
				'Jira_Issue__r.Creator__c, ' +
				'Jira_Issue__r.CreatedDate, ' +
				'Jira_Issue__r.Customers__c, ' +
				'Jira_Issue__r.Days_To_Resolution__c, ' +
				'Jira_Issue__r.Issue_Created__c, ' +
				'Jira_Issue__r.Issue_Id__c, ' +
				'Jira_Issue__r.Issue_Key__c, ' +
				'Jira_Issue__r.Issue_Project__c, ' +
				'Jira_Issue__r.Issue_REST_URL__c, ' +
				'Jira_Issue__r.Issue_Status__c, ' +
				'Jira_Issue__r.Issue_Summary__c, ' +
				'Jira_Issue__r.Issue_Type__c, ' +
				'Jira_Issue__r.Issue_Updated__c, ' +
				'Jira_Issue__r.Issue_URL__c, ' +
				'Jira_Issue__r.Name, ' +
				'Jira_Issue__r.Num_Votes__c, ' +
				'Jira_Issue__r.Num_Watchers__c, ' +
				'Jira_Issue__r.Priority__c, ' +
				'Jira_Issue__r.Reporter__c, ' +
				'Jira_Issue__r.Resolution_Date__c, ' +
				'Jira_Issue__r.Resolution_Name__c, ' +
				'Jira_Issue__r.Severity__c ' +
				'FROM Rosco_Tag_Map__c ' +
				'WHERE tag__r.type__c = \'JIRA\' ';
			if (recordId.left(3) == '001') {
				soql += 'AND Account__c = \'' + recordId + '\' ';
			} else if (recordId.left(3) == '006') {
				soql += 'AND Opportunity__c = \'' + recordId + '\' ';
			} else if (recordId.left(3) == '500') {
				soql += 'AND Case__c = \'' + recordId + '\' ';
			}
			List<Rosco_Tag_Map__c> tags = Database.query(soql);
			if (!tags.isEmpty()) {
				for (Rosco_Tag_Map__c t : tags) {
					Map<String, String> tag = new Map<String, String>{
						'tagMapId' => '',
						'caseId' => '',
						'accountId' => '',
						'comment' => '',
						'tagMapCreatedBy' => '',
						'tagMapCreatedDate' => '',
						'impact' => '',
						'jiraIssueSFId' => '',
						'tagMapModifiedBy' => '',
						'tagMapModifiedDate' => '',
						'module' => '',
						'tagMapName' => '',
						'opportunityId' => '',
						'tagId' => '',
						'accountName' => '',
						'accountType' => '',
						'accountRecordType' => '',
						'opportunityName' => '',
						'opportunityType' => '',
						'opportunityRecordType' => '',
						'opportunityStage' => '',
						'opportunityCloseDate' => '',
						'caseNumber' => '',
						'caseRecordType' => '',
						'caseStatus' => '',
						'caseSubject' => '',
						'jiraAssignee' => '',
						'jiraComponent' => '',
						'jiraCreator' => '',
						'jiraCustomers' => '',
						'jiraDaysToResolution' => '',
						'jiraCreatedDate' => '',
						'jiraIssueId' => '',
						'jiraIssueKey' => '',
						'jiraProject' => '',
						'jiraIssueRestUrl' => '',
						'jiraStatus' => '',
						'jiraSummary' => '',
						'jiraType' => '',
						'jiraLastModifiedDate' => '',
						'jiraIssueURL' => '',
						'jiraName' => '',
						'jiraNumVotes' => '',
						'jiraNumWatchers' => '',
						'jiraPriority' => '',
						'jiraReporter' => '',
						'jiraResolutionDate' => '',
						'jiraName' => '',
						'jiraSeverity' => '',
						'isClosed' => '',
						'tagMapType' => '',
						'tagMapTip' => ''
					};
					if (t.Id != null) {
						tag.put('tagMapId', String.valueOf(t.Id));
					}
					if (t.Case__c != null) {
						tag.put('caseId', String.valueOf(t.Case__c));
					}
					if (t.Account__c != null) {
						tag.put('accountId', String.valueOf(t.Account__c));
					}
					if (t.Comment__c != null) {
						tag.put('comment', String.valueOf(t.Comment__c));
					}
					if (t.CreatedBy.Name != null) {
						tag.put('tagMapCreatedBy', String.valueOf(t.CreatedBy.Name));
					}
					if (t.CreatedDate != null) {
						tag.put('tagMapCreatedDate', String.valueOf(t.CreatedDate));
					}
					if (t.Impact__c != null) {
						tag.put('impact', String.valueOf(t.Impact__c));
					}
					if (t.Jira_Issue__c != null) {
						tag.put('jiraIssueSFId', String.valueOf(t.Jira_Issue__c));
					}
					if (t.LastModifiedBy.Name != null) {
						tag.put('tagMapModifiedBy', String.valueOf(t.LastModifiedBy.Name));
					}
					if (t.LastModifiedDate != null) {
						tag.put('tagMapModifiedDate', String.valueOf(t.LastModifiedDate));
					}
					if (t.Module__c != null) {
						tag.put('module', String.valueOf(t.Module__c));
					}
					if (t.Name != null) {
						tag.put('tagMapName', String.valueOf(t.Name));
					}
					if (t.Opportunity__c != null) {
						tag.put('opportunityId', String.valueOf(t.Opportunity__c));
					}
					if (t.tag__c != null) {
						tag.put('tagId', String.valueOf(t.tag__c));
					}

					if (t.Account__r.Name != null) {
						tag.put('accountName', String.valueOf(t.Account__r.Name));
					}
					if (t.Account__r.Type != null) {
						tag.put('accountType', String.valueOf(t.Account__r.Type));
					}
					if (t.Account__r.RecordType.Name != null) {
						tag.put('accountRecordType', String.valueOf(t.Account__r.RecordType.Name));
					}
					if (t.Opportunity__r.Name != null) {
						tag.put('opportunityName', String.valueOf(t.Opportunity__r.Name));
					}
					if (t.Opportunity__r.Type != null) {
						tag.put('opportunityType', String.valueOf(t.Opportunity__r.Type));
					}
					if (t.Opportunity__r.RecordType.Name != null) {
						tag.put(
							'opportunityRecordType',
							String.valueOf(t.Opportunity__r.RecordType.Name)
						);
					}
					if (t.Opportunity__r.StageName != null) {
						tag.put('opportunityStage', String.valueOf(t.Opportunity__r.StageName));
					}
					if (t.Opportunity__r.CloseDate != null) {
						tag.put('opportunityCloseDate', String.valueOf(t.Opportunity__r.CloseDate));
					}

					if (t.Case__r.CaseNumber != null) {
						tag.put('caseNumber', String.valueOf(t.Case__r.CaseNumber));
					}
					if (t.Case__r.RecordType.Name != null) {
						tag.put('caseRecordType', String.valueOf(t.Case__r.RecordType.Name));
					}
					if (t.Case__r.Status != null) {
						tag.put('caseStatus', String.valueOf(t.Case__r.Status));
					}
					if (t.Case__r.Subject != null) {
						tag.put('caseSubject', String.valueOf(t.Case__r.Subject));
					}
					if (t.Jira_Issue__r.Assignee__c != null) {
						tag.put('jiraAssignee', String.valueOf(t.Jira_Issue__r.Assignee__c));
					}
					if (t.Jira_Issue__r.Component_Name__c != null) {
						tag.put('jiraComponent', String.valueOf(t.Jira_Issue__r.Component_Name__c));
					}
					if (t.Jira_Issue__r.Creator__c != null) {
						tag.put('jiraCreator', String.valueOf(t.Jira_Issue__r.Creator__c));
					}
					if (t.Jira_Issue__r.Customers__c != null) {
						tag.put('jiraCustomers', String.valueOf(t.Jira_Issue__r.Customers__c));
					}
					if (t.Jira_Issue__r.Days_To_Resolution__c != null) {
						tag.put(
							'jiraDaysToResolution',
							String.valueOf(t.Jira_Issue__r.Days_To_Resolution__c)
						);
					}
					if (t.Jira_Issue__r.Issue_Created__c != null) {
						tag.put('jiraCreatedDate', String.valueOf(t.Jira_Issue__r.Issue_Created__c));
					}
					if (t.Jira_Issue__r.Issue_Id__c != null) {
						tag.put('jiraIssueId', String.valueOf(t.Jira_Issue__r.Issue_Id__c));
					}
					if (t.Jira_Issue__r.Issue_Key__c != null) {
						tag.put('jiraIssueKey', String.valueOf(t.Jira_Issue__r.Issue_Key__c));
					}
					if (t.Jira_Issue__r.Issue_Project__c != null) {
						tag.put('jiraProject', String.valueOf(t.Jira_Issue__r.Issue_Project__c));
					}
					if (t.Jira_Issue__r.Issue_REST_URL__c != null) {
						tag.put('jiraIssueRestUrl', String.valueOf(t.Jira_Issue__r.Issue_REST_URL__c));
					}
					if (t.Jira_Issue__r.Issue_Status__c != null) {
						tag.put('jiraStatus', String.valueOf(t.Jira_Issue__r.Issue_Status__c));
					}
					if (t.Jira_Issue__r.Issue_Summary__c != null) {
						tag.put('jiraSummary', String.valueOf(t.Jira_Issue__r.Issue_Summary__c));
					}
					if (t.Jira_Issue__r.Issue_Type__c != null) {
						tag.put('jiraType', String.valueOf(t.Jira_Issue__r.Issue_Type__c));
					}
					if (t.Jira_Issue__r.Issue_Updated__c != null) {
						tag.put('jiraLastModifiedDate', String.valueOf(t.Jira_Issue__r.Issue_Updated__c));
					}
					if (t.Jira_Issue__r.Issue_URL__c != null) {
						tag.put('jiraIssueURL', String.valueOf(t.Jira_Issue__r.Issue_URL__c));
					}
					if (t.Jira_Issue__r.Name != null) {
						tag.put('jiraName', String.valueOf(t.Jira_Issue__r.Name));
					}
					if (t.Jira_Issue__r.Num_Votes__c != null) {
						tag.put('jiraNumVotes', String.valueOf(t.Jira_Issue__r.Num_Votes__c));
					}
					if (t.Jira_Issue__r.Num_Watchers__c != null) {
						tag.put('jiraNumWatchers', String.valueOf(t.Jira_Issue__r.Num_Watchers__c));
					}
					if (t.Jira_Issue__r.Priority__c != null) {
						tag.put('jiraPriority', String.valueOf(t.Jira_Issue__r.Priority__c));
					}
					if (t.Jira_Issue__r.Reporter__c != null) {
						tag.put('jiraReporter', String.valueOf(t.Jira_Issue__r.Reporter__c));
					}
					if (t.Jira_Issue__r.Resolution_Date__c != null) {
						tag.put('jiraResolutionDate', String.valueOf(t.Jira_Issue__r.Resolution_Date__c));
					}
					if (t.Jira_Issue__r.Resolution_Name__c != null) {
						tag.put('jiraName', String.valueOf(t.Jira_Issue__r.Resolution_Name__c));
					}
					if (t.Jira_Issue__r.Severity__c != null) {
						tag.put('jiraSeverity', String.valueOf(t.Jira_Issue__r.Severity__c));
					}
					if (!nullOrEmpty(t.Opportunity__c)) {
						if (
							tag.get('opportunityStage').containsIgnoreCase('Closed') ||
							tag.get('opportunityStage').containsIgnoreCase('Failed')
						) {
							tag.put('isClosed', 'true');
						}
					} else if (!nullOrEmpty(t.Case__c)) {
						if (tag.get('caseStatus').containsIgnoreCase('Closed')) {
							tag.put('isClosed', 'true');
						}
					}
					if (
						tag.get('jiraStatus').containsIgnoreCase('Done') ||
						tag.get('jiraStatus').containsIgnoreCase('TBD')
					) {
						tag.put('isJiraClosed', 'true');
					}
					if (tag.get('opportunityId') != '') {
						tag.put('tagMapType', 'Opportunity');
						String tip =
							tag.get('opportunityRecordType') +
							':' +
							tag.get('opportunityName') +
							' (' +
							tag.get('opportunityStage') +
							')';

						if (tag.get('caseId') != '') {
							tag.put('tagMapType', 'Opportunity (Case)');
							tip +=
								' \n\n ' +
								tag.get('caseRecordType') +
								':' +
								tag.get('caseNumber') +
								':' +
								tag.get('caseSubject') +
								' (' +
								tag.get('caseStatus') +
								')';
						}
						tag.put('tagMapTip', tip);
					} else if (tag.get('caseId') != '') {
						tag.put('tagMapType', 'Case');
						String tip =
							tag.get('caseRecordType') +
							':' +
							tag.get('caseNumber') +
							':' +
							tag.get('caseSubject') +
							' (' +
							tag.get('caseStatus') +
							')';

						if (tag.get('opportunityId') != '') {
							tip +=
								' \n\n ' +
								tag.get('opportunityRecordType') +
								':' +
								tag.get('opportunityName') +
								' (' +
								tag.get('opportunityStage') +
								')';
						}
						tag.put('tagMapTip', tip);
					} else {
						tag.put('tagMapType', 'Account');
						tag.put('tagMapTip', tag.get('accountName'));
						String tip = tag.get('accountRecordType') + ':' + tag.get('accountName');
						tag.put('tagMapTip', tip);
					}
					if (includeClosed != 'true') {
						if (tag.get('isClosed') != 'true') {
							ret.add(tag);
						}
					} else {
						ret.add(tag);
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getRecordTags Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, String> getRoscoActionTagInit(String recordId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			if (recordId.left(3) == '001') {
				String soql = 'SELECT Name ' + 'FROM Account ' + 'WHERE Id = \'' + recordId + '\' ';
				List<Account> accounts = Database.query(soql);
				if (!accounts.isEmpty()) {
					ret.put('recordName', 'Account: ' + accounts[0].Name);
				}
				String soql2 =
					'SELECT Id ' +
					'FROM Report ' +
					'WHERE DeveloperName = \'roscoActionTag_account\'';
				List<Report> reports = Database.query(soql2);
				if (!reports.isEmpty()) {
					ret.put('reportId', reports[0].Id);
				}
			}
			if (recordId.left(3) == '006') {
				String soql = 'SELECT Name ' + 'FROM Opportunity ' + 'WHERE Id = \'' + recordId + '\' ';
				List<Opportunity> opportunities = Database.query(soql);
				if (!opportunities.isEmpty()) {
					ret.put('recordName', 'Opportunity:' + opportunities[0].Name);
				}
				String soql2 =
					'SELECT Id ' +
					'FROM Report ' +
					'WHERE DeveloperName = \'roscoActionTag_opportunity\'';
				List<Report> reports = Database.query(soql2);
				if (!reports.isEmpty()) {
					ret.put('reportId', reports[0].Id);
				}
			}
			if (recordId.left(3) == '500') {
				String soql =
					'SELECT CaseNumber,Subject ' +
					'FROM Case ' +
					'WHERE Id = \'' +
					recordId +
					'\' ';
				List<Case> cases = Database.query(soql);
				if (!cases.isEmpty()) {
					ret.put('recordName', 'Case:' + cases[0].CaseNumber + ':' + cases[0].Subject);
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getRoscoActionTagInit Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getOpportunityTime(String opportunityId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			Boolean requestingUserisMgr = isUserMgr();
			String soql =
				'SELECT User__c, CreatedDate, LaborDate__c, LaborCategory__c, LaborSubCategory__c,LaborChildCategory__c, User__r.Email,Opportunity__r.Name,Minutes__c  ' +
				' FROM Rosco_Time__c' +
				' WHERE Opportunity__c = \'' +
				opportunityId +
				'\'' +
				' AND (LaborDate__c = LAST_N_DAYS:365 OR LaborDate__c > LAST_N_DAYS:365) ' +
				' ORDER BY LaborDate__c DESC';

			List<Rosco_Time__c> aTime = Database.query(soql);
			String userId = UserInfo.getUserId();
			Integer caseTime = 0;
			Integer userTime = 0;
			Datetime removeCutoff = (System.now()).addDays(-7);
			for (Rosco_Time__c a : aTime) {
				Map<String, String> tmpmap = new Map<String, String>();
				tmpmap.put('User', String.valueOf(a.User__r.Email).trim());
				tmpmap.put('Opportunity', String.valueOf(a.Opportunity__r.Name).trim());
				tmpmap.put('Minutes', String.valueOf(a.Minutes__c));
				tmpMap.put('Activity', String.valueOf(a.LaborCategory__c).trim());
				tmpMap.put('ActivityDetail', '');
				if (!nullOrEmpty(a.LaborChildCategory__c)) {
					tmpMap.put('ActivityDetail', String.valueOf(a.LaborChildCategory__c).trim());
				}
				tmpMap.put('CreatedDate', a.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
				tmpMap.put('Date', a.LaborDate__c.formatGMT('yyyy-MM-dd'));
				tmpMap.put('removable', 'false');
				if (String.valueOf(a.User__c) == userId) {
					if (a.LaborDate__c > removeCutoff) {
						tmpMap.put('removable', 'true');
					}
				} else if (requestingUserisMgr) {
					tmpMap.put('removable', 'true');
				}
				ret.add(tmpMap);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getOpportunityTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, String> getOpportunityInfo(String opportunityId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT Name,Id,Type,CloseDate,RecordType.Name,Stagename ' +
				' FROM Opportunity ' +
				' WHERE Id = \'' +
				opportunityId +
				'\'';

			List<Opportunity> aOpp = Database.query(soql);
			if (aOpp.size() != 0) {
				ret.put('opportunityRecordType', String.valueOf(aOpp[0].RecordType.Name).trim());
				ret.put('opportunityName', String.valueOf(aOpp[0].Name).trim());
				ret.put('opportunityId', String.valueOf(aOpp[0].Id));
				ret.put('opportunityType', String.valueOf(aOpp[0].Type).trim());
				ret.put('opportunityStage', String.valueOf(aOpp[0].StageName));
				ret.put('opportunityCloseDate', String.valueOf(aOpp[0].CloseDate));
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getOpportunityInfo Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String getPickListSupportOptions() {
		List<String> plValues = new List<String>();
		Schema.SObjectType objType = Schema.getGlobalDescribe().get('Contact');
		Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
		Schema.DescribeFieldResult objFieldInfo = objDescribe.fields.getMap()
			.get('Support_Option__c')
			.getDescribe();
		List<Schema.PicklistEntry> picklistvalues = objFieldInfo.getPicklistValues();
		for (Schema.PicklistEntry plv : picklistvalues) {
			plValues.add(plv.getValue());
		}
		plValues.sort();
		return String.join(plValues, ';');
	}

	@AuraEnabled
	public static List<Map<String, String>> getPreSalesAccountTime(String accountIdOrOpportunityId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Id accountId;
		try {
			Boolean requestingUserisMgr = isUserMgr();
			if (accountIdOrOpportunityId.left(3) == '006') {
				accountId = [SELECT AccountId FROM Opportunity WHERE Id = :accountIdOrOpportunityId]
				.AccountId;
			}
			if (accountIdOrOpportunityId.left(3) == '001') {
				accountId = accountIdOrOpportunityId;
			}
			String soql =
				'SELECT User__c, CreatedDate, LaborDate__c, LaborCategory__c, LaborSubCategory__c, LaborChildCategory__c, User__r.Email, Opportunity__r.Name,Minutes__c ' +
				' FROM Rosco_Time__c' +
				' WHERE Account__c = \'' +
				accountId +
				'\'' +
				' AND (LaborDate__c = LAST_N_DAYS:365 OR LaborDate__c > LAST_N_DAYS:365) ' +
				' ORDER BY LaborDate__c DESC';

			List<Rosco_Time__c> aTime = Database.query(soql);
			String userId = UserInfo.getUserId();
			Integer caseTime = 0;
			Integer userTime = 0;
			Datetime removeCutoff = (System.now()).addDays(-7);
			for (Rosco_Time__c a : aTime) {
				Map<String, String> tmpmap = new Map<String, String>();
				tmpmap.put('User', String.valueOf(a.User__r.Email).trim());
				if (nullOrEmpty(a.Opportunity__r.Name)) {
					tmpmap.put('Opportunity', 'n/a');
				} else {
					tmpmap.put('Opportunity', String.valueOf(a.Opportunity__r.Name).trim());
				}
				tmpmap.put('Minutes', a.Minutes__c != 0 ? String.valueOf(a.Minutes__c) : '');
				tmpMap.put('Activity', String.valueOf(a.LaborCategory__c).trim());
				tmpMap.put('LaborCategory', a.LaborCategory__c);
				tmpMap.put('LaborSubCategory', a.LaborSubCategory__c);
				tmpMap.put('CreatedDate', a.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
				tmpMap.put('Date', a.LaborDate__c.formatGMT('yyyy-MM-dd'));
				tmpMap.put('removable', 'false');
				if (String.valueOf(a.User__c) == userId) {
					if (a.LaborDate__c > removeCutoff) {
						tmpMap.put('removable', 'true');
					}
				} else if (requestingUserisMgr) {
					tmpMap.put('removable', 'true');
				}
				ret.add(tmpMap);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getOpportunityTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getProfiles() {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql = 'SELECT Id,Name FROM Profile';
			List<Profile> profiles = Database.query(soql);
			if (!profiles.isEmpty()) {
				for (Profile p : profiles) {
					ret.put(String.valueOf(p.Id), String.valueOf(p.Name));
					ret.put(String.valueOf(p.Name), String.valueOf(p.Id));
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getProfiles Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, String> getRoscoAccountInfo(String accountId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT Id,Bypass_Triage_Tickets__c,Support_Info__c,Name,Secondary_Slack_Channel_Id__c,Tertiary_Slack_Channel_Id__c, case_flash__c,Case_Flash_Persist__c,account_flash__c  ' +
				'FROM Rosco_Account__c ' +
				'WHERE account__c  = \'' +
				accountId +
				'\' ' +
				'LIMIT 1';

			List<Rosco_Account__c> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				ret.put('Id', accounts[0].Id);
				ret.put('Name', accounts[0].Name);
				String sByPassSlackId = '';
				if (accounts[0].Bypass_Triage_Tickets__c != null) {
					sByPassSlackId = String.valueOf(accounts[0].Bypass_Triage_Tickets__c);
				}
				ret.put('byPassSlackId', sByPassSlackId);
				String sSecondarySlackId = '';
				if (accounts[0].Secondary_Slack_Channel_Id__c != null) {
					sSecondarySlackId = String.valueOf(accounts[0].Secondary_Slack_Channel_Id__c);
				}
				ret.put('secondarySlackId', sSecondarySlackId);
				String sTertiarySlackId = '';
				if (accounts[0].Tertiary_Slack_Channel_Id__c != null) {
					sTertiarySlackId = String.valueOf(accounts[0].Tertiary_Slack_Channel_Id__c);
				}
				ret.put('tertiarySlackId', sTertiarySlackId);
				String sFlash = '';
				if (accounts[0].case_flash__c != null) {
					sFlash = String.valueOf(accounts[0].case_flash__c);
				}
				ret.put('flash', sFlash);
				String sFlashPersist = '';
				if (accounts[0].Case_Flash_Persist__c != null) {
					sFlashPersist = String.valueOf(accounts[0].Case_Flash_Persist__c);
				}
				ret.put('flashPersist', sFlashPersist);
				String sFlashAccount = '';
				if (accounts[0].account_flash__c != null) {
					sFlashAccount = String.valueOf(accounts[0].account_flash__c);
				}
				ret.put('flashAccount', sFlashAccount);
				String sMoreInfo = '';
				if (accounts[0].Support_Info__c != null) {
					sMoreInfo = String.valueOf(accounts[0].Support_Info__c);
				}
				ret.put('moreinfo', sMoreInfo);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getRoscoAccountInfo Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String getRoscoAccountCasePopup(String recordId) {
		String ret = '';
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			if (cmfields.contains('rosco_accountcasepopup__c')) {
				String cfg = String.valueOf(cm.get('rosco_accountcasepopup__c'));
				if (cfg.containsIgnoreCase(getUserRoleName())) {
					if (recordId.left(3) == '500') {
						Case c = [SELECT AccountId FROM Case WHERE Id = :recordId];
						recordId = String.valueOf(c.AccountId);
					}
					String soql =
						'SELECT account_flash__c,account__r.Support_Model__c   ' +
						'FROM Rosco_Account__c ' +
						'WHERE account__c  = \'' +
						recordId +
						'\' ' +
						'LIMIT 1';

					List<Rosco_Account__c> accounts = Database.query(soql);
					if (!accounts.isEmpty()) {
						String flash = '';
						if (accounts[0].account_flash__c != null) {
							ret = String.valueOf(accounts[0].account_flash__c);
						}
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getRoscoAccountPopup Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getSMETeams() {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Map<String, String> temp1 = new Map<String, String>();
		temp1.put('value', 'General');
		temp1.put('label', 'General');
		ret.add(temp1);
		try {
			String soql =
				'SELECT Name ' +
				'FROM TAM_Team__c ' +
				'WHERE RecordType.Name = \'Escalation SME\' ' +
				'ORDER BY Name';

			List<TAM_Team__c> aSME = Database.query(soql);
			for (TAM_Team__c s : aSME) {
				Map<String, String> smeTeam = new Map<String, String>();
				smeTeam.put('value', s.Name);
				smeTeam.put('label', s.Name);
				ret.add(smeTeam);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getSMETeams Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String getTimeType(String accountId) {
		String ret = 'General';
		try {
			String soql =
				'SELECT LaborSubCategory__c ' +
				' FROM Rosco_Time__c' +
				' WHERE Account__c = \'' +
				accountId +
				'\'' +
				' AND User__c = \'' +
				UserInfo.getUserId() +
				'\'' +
				' AND LaborSubCategory__c != null' +
				' ORDER BY CreatedDate DESC' +
				' LIMIT 1';

			List<Rosco_Time__c> aTime = Database.query(soql);
			if (aTime.size() != 0) {
				ret = String.valueOf(aTime[0].LaborSubCategory__c);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getTimeType Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String getUserRoleName() {
		String ret = '';
		try {
			String soql =
				'SELECT Name ' +
				'FROM UserRole ' +
				'WHERE Id = \'' +
				UserInfo.getUserRoleId() +
				'\'';

			List<UserRole> oRs = Database.query(soql);
			for (UserRole o : oRs) {
				ret = o.Name;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.getUserRoleName Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> initRoscoActionAccountSupport(String accountId) {
		Map<String, Object> ret = new Map<String, Object>();
		try {
			ret.put('unsupported', 'false');
			if (isUnsupportedAccount(accountId)) {
				ret.put('accountId', accountId);
				ret.put('unsupported', 'true');
				return ret;
			}
			ret.put('accountId', accountId);
			ret.put('flash', getFlash(accountId));
			Map<String, String> profiles = getProfiles();
			List<String> frozen = getFrozenUsers();
			List<String> dev = getDevUsers();
			String soql =
				'SELECT Email, Id, ProfileId ' +
				'FROM User ' +
				'WHERE IsActive = true ' +
				'AND ContactId IN (SELECT Id FROM Contact WHERE AccountId = \'' +
				accountId +
				'\')';
			List<User> users = Database.query(soql);
			List<Map<String, String>> customers = new List<Map<String, String>>();
			if (users.size() != 0) {
				for (User u : users) {
					ret.put('hasUsers', 'true');
					Map<String, String> customer = new Map<String, String>();
					customer.put('id', u.Id);
					customer.put('email', u.Email);
					customer.put('scenario', 'accountAction');
					if (frozen.contains(u.Id)) {
						customer.put('profile', 'freeze');
					} else {
						String profileName = profiles.get(u.ProfileId);
						customer.put('profile', profileName);
					}
					if (dev.contains(u.Id)) {
						customer.put('devUser', 'true');
					} else {
						customer.put('devUser', 'false');
					}
					customers.add(customer);
				}
				ret.put('customers', customers);
			}
			ret.put('emailDomains', getEmailDomains(accountId));
			ret.put('accountInfo', getAccountInfo(accountId));
			ret.put('roscoAccountInfo', getRoscoAccountInfo(accountId));
			ret.put('isDevUserMgr', String.valueOf(isDevUserMgr()));
			Boolean isUserMgr = isUserMgr();
			if (isUserMgr) {
				ret.put('isUserMgr', true);
			} else {
				ret.put('isUserMgr', false);
			}
			Boolean isSupportTAM = isSupportTAM();
			if (isSupportTAM) {
				ret.put('isSupportTAM', true);
			} else {
				ret.put('isSupportTAM', false);
			}
			List<Map<String, String>> supportModelOptions = new List<Map<String, String>>();
			Schema.DescribeFieldResult fieldResult = Account.Support_Model__c.getDescribe();
			List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
			for (Schema.PicklistEntry f : ple) {
				Map<String, String> p = new Map<String, String>();
				p.put('label', f.getLabel());
				p.put('value', f.getLabel());
				supportModelOptions.add(p);
				ret.put('supportModelOptions', supportModelOptions);
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.initRoscoActionAccountSupport Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> initRoscoActionAccountTime(String accountId) {
		Map<String, Object> ret = new Map<String, Object>();
		try {
			UserRole uRole = [SELECT Name FROM UserRole WHERE Id = :UserInfo.getUserRoleId() LIMIT 1];
			if (String.valueOf(uRole.Name).containsIgnoreCase('TSE')) {
				ret.put('TSE', 'true');
			} else {
				ret.put('TSE', 'false');
			}
			String timeType = getTimeType(accountId);
			ret.put('time_type', timeType);
			ret.put('account_info', getAccountInfo(accountId));
		} catch (Exception e) {
			Logger.error('RoscoAction.initRoscoActionAccountTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> initRoscoActionCaseTime(String caseId) {
		Map<String, Object> ret = new Map<String, Object>();
		ret.put('foo', 'bar');
		return ret;
	}

	@AuraEnabled
	public static Map<String, String> initRoscoActionContactSupport(String contactId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			ret.put('contactId', contactId);
			Account account = getAccount(contactId);
			Contact contact = [SELECT Id, Case_Flash_Message__c FROM Contact WHERE Id = :contactId];
			ret.put('flashMessage', String.valueOf(contact.Case_Flash_Message__c));
			ret.put('unsupported', 'false');
			if (isUnsupportedAccount(account.Id)) {
				ret.put('unsupported', 'true');
			}
			ret.put('accountId', account.Id);
			ret.put('accountType', account.Type);
			ret.put('techPartnerProgramTier', account.Tech_Partner_Program_Tier__c);
			ret.put('accountRecTypeName', account.RecordType.Name);
			Map<String, String> profiles = getProfiles();
			List<String> frozen = getFrozenUsers();
			String soql =
				'SELECT Email, Id, ProfileId,LastPasswordChangeDate,TimeZoneSidKey ' +
				'FROM User ' +
				'WHERE IsActive = true ' +
				'AND ContactId = \'' +
				contactId +
				'\'';

			List<User> users = Database.query(soql);
			if (users.size() != 0) {
				for (User u : users) {
					ret.put('isUser', 'true');
					ret.put('id', u.Id);
					ret.put('email', u.Email);
					ret.put('timeZone', u.TimeZoneSidKey);
					if (u.LastPasswordChangeDate == null) {
						ret.put('lastPasswordChangeDate', 'n/a');
					} else {
						ret.put('lastPasswordChangeDate', String.valueOf(u.LastPasswordChangeDate));
					}
					if (frozen.contains(u.Id)) {
						ret.put('profile', 'freeze');
					} else {
						String profileName = profiles.get(u.ProfileId);
						ret.put('profile', profileName);
					}
					ret.putAll(getLoginHistory(String.valueOf(u.Id)));
					ret.put('devUser', String.valueOf(isDevUser(u.Id)));
					ret.put('scenario', 'contactAction');
					Contact c = [SELECT Email, Support_Option__c FROM Contact WHERE Id = :contactId];
					ret.put('contactSupportOptions', String.valueOf(c.Support_Option__c));
					ret.put('availableSupportOptions', String.valueOf(getPickListSupportOptions()));
				}
			} else {
				ret.put('isUser', 'false');
				ret.put('lastLoginDate', 'n/a');
				ret.put('lastLoginStatus', 'n/a');
				ret.put('lastPasswordChangeDate', 'n/a');
				ret.put('profile', 'Not Registered');
				ret.put('id', '-1');
				Contact c = [SELECT Email, Support_Option__c FROM Contact WHERE Id = :contactId];
				ret.put('email', String.valueOf(c.Email));
				ret.put('contactSupportOptions', String.valueOf(c.Support_Option__c));
				ret.put('availableSupportOptions', String.valueOf(getPickListSupportOptions()));
				ret.put('devUser', 'false');
				ret.put('scenario', 'contactAction');
			}
			ret.put('isDevUserMgr', String.valueOf(isDevUserMgr()));
		} catch (Exception e) {
			Logger.error('RoscoAction.initRoscoActionContactSupport Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> initRoscoActionNextSteps(String accountOrOppurtunityId) {
		Map<String, Object> ret = new Map<String, Object>();
		ret.put('tamNextSteps', '');
		try {
			if (accountOrOppurtunityId.left(3) != '001') {
				String soql =
					'SELECT TAM_Next_Steps__c ' +
					'FROM Opportunity ' +
					'WHERE Id = \'' +
					accountOrOppurtunityId +
					'\' ' +
					'LIMIT 1';
				List<Opportunity> steps = Database.query(soql);
				if (!steps.isEmpty()) {
					if (steps[0].TAM_Next_Steps__c != null) {
						String stepStr = String.valueOf(steps[0].TAM_Next_Steps__c);
						if (stepStr.containsIgnoreCase('- -')) {
							stepStr = stepStr.substring(stepStr.indexOf('- -') + 3);
						}
						ret.put('tamNextSteps', stepStr);
					}
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.initRoscoActionNextSteps Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> initRoscoActionOpportunityCEActivity2(
		String accountOrOppurtunityId
	) {
		Map<String, Object> ret = new Map<String, Object>();
		ret.put('profileCE', 'false');
		try {
			Id profileId = userinfo.getProfileId();
			String profileName = [SELECT Id, Name FROM Profile WHERE Id = :profileId].Name;
			if (!nullOrEmpty(profileName)) {
				if (profileName == 'Customer Engagement') {
					ret.put('profileCE', 'true');
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.initRoscoActionOpportunityCEActivity2 Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> initRoscoActionOpportunityPreSalesActivity(
		String accountOrOpportunityId
	) {
		Map<String, Object> ret = new Map<String, Object>();
		try {
			ret.put('accountOrOpportunityId', accountOrOpportunityId);
			String accountId = accountOrOpportunityId;
			if (accountOrOpportunityId.left(3) != '001') {
				Opportunity o = [SELECT AccountId FROM Opportunity WHERE Id = :accountOrOpportunityId];
				accountId = o.AccountId;
			}
			String soql =
				'SELECT Id, Name, Type, CloseDate ' +
				'FROM Opportunity ' +
				'WHERE AccountId = \'' +
				accountId +
				'\' ' +
				'AND StageName != \'Failed\' AND StageName != \'CLOSED WON\' ' +
				'AND StageName != \'POC\' ' +
				'ORDER BY Name';

			List<Map<String, String>> opportunities = new List<Map<String, String>>();
			List<Opportunity> opps = Database.query(soql);
			if (!opps.isEmpty()) {
				for (Opportunity opp : opps) {
					Map<String, String> o = new Map<String, String>();
					o.put(
						'label',
						opp.Name +
						' - ' +
						String.valueOf(opp.Type) +
						' - Close Date: ' +
						String.valueOf(opp.CloseDate)
					);
					o.put('value', opp.Id);
					opportunities.add(o);
				}
			}
			ret.put('opportunities', opportunities);
			ret.put('requireOpp', shouldRequireOpp(accountId));
		} catch (Exception e) {
			Logger.error('RoscoAction.initRoscoActionOpportunityPreSalesActivity Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	private static Boolean isDevUser(String userId) {
		Boolean ret = false;
		if (userId == '-1') {
			return false;
		}

		for (PermissionSetAssignment psa : [
			SELECT AssigneeId
			FROM PermissionSetAssignment
			WHERE
				AssigneeId = :userId
				AND PermissionSetId IN (
					SELECT Id
					FROM PermissionSet
					WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
				)
		]) {
			ret = true;
		}
		return ret;
	}

	private static Boolean isDevUserWelcomeEmailRecent(String toAddress) {
		Boolean ret = false;
		String soql =
			'SELECT Id ' +
			'FROM EmailMessage  ' +
			'WHERE ToAddress = \'' +
			toAddress +
			'\' ' +
			'AND Subject = \'Enrollment Confirmation – Tanium Technical Partner Program, “Registered” Level\' ' +
			'AND CreatedDate = LAST_N_DAYS:1 ' +
			'LIMIT 1';

		List<EmailMessage> emails = Database.query(soql);
		if (!emails.isEmpty()) {
			ret = true;
		}
		return ret;
	}

	private static Boolean isDevUserMgr() {
		Boolean ret = false;
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Id ' +
			'FROM Group ' +
			'WHERE Name = \'Support: developer.tanium.com admin\' ' +
			'LIMIT 1';

		List<Group> groups = Database.query(soql);
		if (!groups.isEmpty()) {
			String soql2 =
				'SELECT Id ' +
				'FROM GroupMember ' +
				'WHERE UserOrGroupId = \'' +
				userId +
				'\' ' +
				'AND GroupId  = \'' +
				groups[0].Id +
				'\' ' +
				'LIMIT 1';
			List<GroupMember> members = Database.query(soql2);
			if (!members.isEmpty()) {
				ret = true;
			}
		}
		return ret;
	}

	@AuraEnabled
	public static String isProposedDomainOk(String proposedDomain) {
		String ret = 'Undefined error';
		try {
			String soql =
				'SELECT Account__c, Name, user_automation__c, Auto_register_developer_tanium_com__c' +
				' FROM Rosco_domain__c' +
				' WHERE Name = \'' +
				proposedDomain +
				'\'' +
				' AND Account__c != null';
			List<Rosco_domain__c> domains = Database.query(soql);
			if (domains.isEmpty()) {
				ret = 'Available to configure';
			} else {
				for (Rosco_domain__c domain : domains) {
					Account pAccount = [SELECT Name FROM Account WHERE ID = :domains[0].Account__c];
					ret =
						pAccount.Name +
						' (' +
						domains[0].Account__c +
						') has already configured this domain.  Question? Slack #servicecloud';
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.isProposedDomainOk Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Boolean isSupportTAM() {
		Boolean ret = false;
		try {
			String soql =
				'SELECT Name ' +
				'FROM UserRole ' +
				'WHERE Id = \'' +
				UserInfo.getUserRoleId() +
				'\' ' +
				'AND Name = \'STAM\'';

			List<UserRole> rs = Database.query(soql);
			if (rs.size() != 0) {
				ret = true;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.isSupportTAM Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Boolean isUserMgr() {
		Boolean ret = false;
		try {
			String soql = 'SELECT Id ' + 'FROM PermissionSet ' + 'WHERE Name = \'Support_Management\'';

			List<PermissionSet> sets = Database.query(soql);
			if (sets.size() != 0) {
				String userId = UserInfo.getUserId();

				String soql2 =
					'SELECT Id ' +
					'FROM PermissionSetAssignment ' +
					'WHERE PermissionSetId = \'' +
					sets[0].Id +
					'\' ' +
					'AND AssigneeId = \'' +
					userId +
					'\'';
				List<PermissionSetAssignment> assignments = Database.query(soql2);
				if (assignments.size() != 0) {
					ret = true;
				}
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.isUserMgr Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Boolean isUnsupportedAccount(String accountId) {
		Boolean ret = false;
		try {
			String name = [SELECT Name FROM Account WHERE Id = :accountId].Name;
			if (name == 'Customer Community External Members Account') {
				ret = true;
			} else if (name == 'Tanium Support Transitory') {
				ret = true;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.isUnsupportedAccount Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> removeTime(String accountId, String createdDate) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			if (String.valueOf(createdDate).length() > 1) {
				String soql =
					'SELECT Id ' +
					'FROM Rosco_Time__c ' +
					'WHERE Account__c = \'' +
					accountId +
					'\' ' +
					'AND CreatedDate = ' +
					createdDate +
					' ' +
					'LIMIT 1';

				List<Rosco_Time__c> lEntry = Database.query(soql);
				if (lEntry.size() != 0) {
					delete lEntry;
				}
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.removeTime Errors', e);
			Logger.saveLog();
		}
		ret = getAccountTime(accountId);
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> removeTimeOpp(String opportunityId, String createdDate) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			if (String.valueOf(createdDate).length() > 1) {
				String soql;
				if (opportunityId.left(3) == '001') {
					soql =
						'SELECT Id ' +
						'FROM Rosco_Time__c ' +
						'WHERE Account__c = \'' +
						opportunityId +
						'\' ' +
						'AND CreatedDate = ' +
						createdDate +
						' ' +
						'LIMIT 1';
				} else {
					soql =
						'SELECT Id ' +
						'FROM Rosco_Time__c ' +
						'WHERE Opportunity__c = \'' +
						opportunityId +
						'\' ' +
						'AND CreatedDate = ' +
						createdDate +
						' ' +
						'LIMIT 1';
				}
				List<Rosco_Time__c> lEntry = Database.query(soql);
				if (lEntry.size() != 0) {
					delete lEntry;
				}
			}
			ret = getPreSalesAccountTime(opportunityId);
		} catch (DmlException e) {
			Logger.error('RoscoAction.removeTimeOpp Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String resetUserPassword(String userId) {
		String ret = 'unknown error';
		try {
			if (!Test.isRunningTest()) {
				ResetPasswordResult result = System.resetPassword(Id.valueOf(userId), true);
				ret = String.valueOf(result.getPassword());
			}
			String soaText = '*' + UserInfo.getUserName() + '* reset password\n';
			soaText += 'userId: `' + userId + '`\n';
			soaText += 'tempPass: `' + String.valueOf(ret) + '`\n';
			slackSOA(soaText);
		} catch (Exception e) {
			Logger.error('RoscoAction.resetUserPassword Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static void saveCustomers(List<Map<String, String>> customers) {
		try {
			Map<String, String> profiles = getProfiles();
			Set<Id> contactIds = new Set<Id>();
			Map<Id, Id> accountAndContactId = new Map<Id, Id>();
			Map<Id, Account> contactIdAccountMap = new Map<Id, Account>();
			Set<String> taniumAuthenticatedProfiles = new Set<String>{
				'Tanium Community Login Authenticated',
				'Tanium Community Login Authenticated Case',
				'Tanium Community Login Super User'
			};
			Set<String> basicAndFreezeAccess = new Set<String>{
				'freeze',
				'Tanium Community Login Unknown'
			};

			for (Map<String, String> customer : customers) {
				contactIds.add(customer.get('contactId'));
			}

			for (Contact contact : [SELECT AccountId FROM Contact WHERE Id IN :contactIds]) {
				accountAndContactId.put(contact.AccountId, contact.Id);
			}

			for (Account account : [
				SELECT Id, RecordType.DeveloperName, Type, Tech_Partner_Program_Tier__c
				FROM Account
				WHERE Id IN :accountAndContactId.keySet()
			]) {
				contactIdAccountMap.put(accountAndContactId.get(account.Id), account);
			}

			for (Map<String, String> customer : customers) {
				String userId = customer.get('id');
				String profile = customer.get('profile');
				String email = customer.get('email');
				String devUser = customer.get('devUser');
				String scenario = customer.get('scenario');
				String contactId = customer.get('contactId');
				String timeZone = customer.get('timeZone');
				String devUserMgr = String.valueOf(customer.get('isDevUserMgr'));
				if (!profile.containsIgnoreCase('Tanium Community')) {
					if (!profile.containsIgnoreCase('freeze')) {
						return;
					}
				}
				if (email.containsIgnoreCase('@tanium.com')) {
					return;
				}
				if (profile == 'freeze') {
					setIsFrozen(userId, true);
					removePermissionSet(userId, Constants.CONSTELLANT_DEV_PERM_SET);
				} else {
					setIsFrozen(userId, false);
					setProfileId(userId, profiles.get(profile));
					setTimeZone(userId, timeZone);
					setPermissionSet(userId, 'Zoomin_for_Community_Cloud_user_permission_set');

					if (contactIdAccountMap.containsKey(contactId)) {
						Account accountRecord = contactIdAccountMap.get(contactId);
						if (
							(accountRecord.Type == 'Customer' &&
							taniumAuthenticatedProfiles.contains(profile)) ||
							(accountRecord.RecordType.DeveloperName == 'Partner' &&
							accountRecord.Tech_Partner_Program_Tier__c != null &&
							devUser == 'true')
						) {
							setPermissionSet(userId, Constants.CONSTELLANT_DEV_PERM_SET);
						}

						if (
							(basicAndFreezeAccess.contains(profile) && accountRecord.Type == 'Customer') ||
							devUser == 'false'
						) {
							removePermissionSet(userId, Constants.CONSTELLANT_DEV_PERM_SET);
						}
					}
				}
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveCustomers Errors', e);
			Logger.saveLog();
		}
	}

	@Future
	public static void saveEmailDomain(String accountId, Map<String, String> emailDomain) {
		try {
			List<Map<String, String>> existing = getEmailDomains(accountId);
			String incomingDomain = emailDomain.get('domain');
			incomingDomain = incomingDomain.toLowerCase();
			Rosco_domain__c rdUpdate = new Rosco_domain__c();
			if (emailDomain.get('automation') == 'Remove Link') {
				rdUpdate.Name = emailDomain.get('domain');
				rdUpdate.Account__c = null;
				rdUpdate.user_automation__c = 'No Automation';
				rdUpdate.Auto_register_developer_tanium_com__c = false;
			} else {
				rdUpdate.Name = emailDomain.get('domain');
				rdUpdate.Account__c = accountId;
				rdUpdate.user_automation__c = emailDomain.get('automation');
				rdUpdate.Auto_register_developer_tanium_com__c = Boolean.valueOf(
					emailDomain.get('developer')
				);
			}
			Boolean found = false;
			for (Map<String, String> e : existing) {
				String existingDomain = e.get('domain');
				existingDomain = existingDomain.toLowerCase();
				if (incomingDomain == existingDomain) {
					found = true;
					if (
						(emailDomain.get('automation') != e.get('automation')) ||
						(emailDomain.get('developer') != e.get('developer'))
					) {
						rdUpdate.Id = e.get('Id');
						update rdUpdate;
					}
				}
			}

			if (!found) {
				String existingId = getEmailDomainId(incomingDomain);
				if (existingId == '') {
					insert rdUpdate;
				} else {
					rdUpdate.Id = existingId;
					update rdUpdate;
				}
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveEmailDomain Errors', e);
			Logger.saveLog();
		}
	}

	@AuraEnabled
	public static String saveKnowledgeArticleTopics(String entityId, String topicName) {
		String ret = '';
		try {
			String netId = [SELECT Name FROM Network WHERE Name = 'Tanium Customer Community'].Id;
			String topicId = [SELECT Id FROM Topic WHERE Name = :topicName AND NetworkId = :netId].Id;
			TopicAssignment ta = new TopicAssignment();
			ta.TopicId = topicId;
			ta.EntityId = entityId;
			insert ta;
			ret = ta.Id;
		} catch (Exception e) {
			Logger.error('RoscoAction.saveKnowledgeArticleTopics Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@Future
	public static void saveRoscoAccountInfo(String accountId, Map<String, String> roscoAccountInfo) {
		try {
			String soql =
				'SELECT account__c,Name,Support_Info__c,Bypass_Triage_Tickets__c,Secondary_Slack_Channel_Id__c,Tertiary_Slack_Channel_Id__c,case_flash__c,Case_Flash_Persist__c,account_flash__c ' +
				'FROM Rosco_Account__c ' +
				'WHERE account__c = \'' +
				accountId +
				'\'';

			List<Rosco_Account__c> raccounts = Database.query(soql);
			if (raccounts.isEmpty()) {
				Rosco_Account__c a = new Rosco_Account__c();
				a.account__c = accountId;
				if (roscoAccountInfo.get('Name') != null) {
					a.Name = roscoAccountInfo.get('Name');
				}
				if (roscoAccountInfo.get('byPassSlackId') != null) {
					a.Bypass_Triage_Tickets__c = roscoAccountInfo.get('byPassSlackId');
				}
				if (roscoAccountInfo.get('secondarySlackId') != null) {
					a.Secondary_Slack_Channel_Id__c = roscoAccountInfo.get('secondarySlackId');
				}
				if (roscoAccountInfo.get('tertiarySlackId') != null) {
					a.Tertiary_Slack_Channel_Id__c = roscoAccountInfo.get('tertiarySlackId');
				}
				if (roscoAccountInfo.get('flash') != null) {
					a.case_flash__c = roscoAccountInfo.get('flash');
				}
				if (roscoAccountInfo.get('flashPersist') != null) {
					a.Case_Flash_Persist__c = roscoAccountInfo.get('flashPersist');
				}
				if (roscoAccountInfo.get('flashAccount') != null) {
					a.account_flash__c = roscoAccountInfo.get('flashAccount');
				}
				if (roscoAccountInfo.get('moreinfo') != null) {
					a.Support_Info__c = roscoAccountInfo.get('moreinfo');
				}
				insert a;
			} else {
				Boolean updateAccount = false;
				if (roscoAccountInfo.get('Name') != null) {
					if (raccounts[0].Name != roscoAccountInfo.get('Name')) {
						raccounts[0].Name = roscoAccountInfo.get('Name');
						updateAccount = true;
					}
				}
				if (roscoAccountInfo.get('byPassSlackId') != null) {
					if (raccounts[0].Bypass_Triage_Tickets__c != roscoAccountInfo.get('byPassSlackId')) {
						raccounts[0].Bypass_Triage_Tickets__c = roscoAccountInfo.get('byPassSlackId');
						updateAccount = true;
					}
				}
				if (roscoAccountInfo.get('secondarySlackId') != null) {
					if (
						raccounts[0].Secondary_Slack_Channel_Id__c !=
						roscoAccountInfo.get('secondarySlackId')
					) {
						raccounts[0].Secondary_Slack_Channel_Id__c = roscoAccountInfo.get(
							'secondarySlackId'
						);
						updateAccount = true;
					}
				}
				if (roscoAccountInfo.get('tertiarySlackId') != null) {
					if (
						raccounts[0].Tertiary_Slack_Channel_Id__c !=
						roscoAccountInfo.get('tertiarySlackId')
					) {
						raccounts[0].Tertiary_Slack_Channel_Id__c = roscoAccountInfo.get(
							'tertiarySlackId'
						);
						updateAccount = true;
					}
				}
				if (roscoAccountInfo.get('flash') != null) {
					if (raccounts[0].case_flash__c != roscoAccountInfo.get('flash')) {
						raccounts[0].case_flash__c = roscoAccountInfo.get('flash');
						updateAccount = true;
					}
				}
				if (roscoAccountInfo.get('flashPersist') != null) {
					if (raccounts[0].Case_Flash_Persist__c != roscoAccountInfo.get('flashPersist')) {
						raccounts[0].Case_Flash_Persist__c = roscoAccountInfo.get('flashPersist');
						updateAccount = true;
					}
				}
				if (roscoAccountInfo.get('flashAccount') != null) {
					if (raccounts[0].account_flash__c != roscoAccountInfo.get('flashAccount')) {
						raccounts[0].account_flash__c = roscoAccountInfo.get('flashAccount');
						updateAccount = true;
					}
				}
				if (roscoAccountInfo.get('moreinfo') != null) {
					if (raccounts[0].Support_Info__c != roscoAccountInfo.get('moreinfo')) {
						raccounts[0].Support_Info__c = roscoAccountInfo.get('moreinfo');
						updateAccount = true;
					}
				}
				if (updateAccount) {
					update raccounts[0];
				}
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoAccountInfo Errors', e);
			Logger.saveLog();
		}
	}

	@AuraEnabled
	public static List<Map<String, String>> saveRoscoActionAccountTime(
		String accountId,
		String minutes,
		String laborCategory,
		String laborSubCategory,
		String laborDate
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Datetime laborDateDT = date.valueOf(laborDate);
		if (
			laborSubCategory.containsIgnoreCase('Support-') ||
			laborSubCategory.containsIgnoreCase('SME-')
		) {
			laborCategory = 'SME Time';
		}
		try {
			String check = saveTimeCheck(accountId, minutes, laborDateDT);
			if (check == 'ok') {
				String userId = UserInfo.getUserId();
				Rosco_Time__c newTime = new Rosco_Time__c(
					Account__c = accountId,
					User__c = userId,
					Minutes__c = Integer.valueOf(minutes),
					LaborCategory__c = laborCategory,
					LaborSubCategory__c = laborSubCategory,
					LaborDate__c = laborDateDT,
					Role__c = getUserRoleName()
				);
				insert newTime;
				ret = getAccountTime(accountId);
			} else {
				ret = getAccountTime(accountId);
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoActionAccountTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> saveRoscoActionAccountTimeNov2023(
		String accountId,
		String minutes,
		String laborCategory,
		String laborSubCategory,
		String laborChildCategory,
		String laborDate
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Datetime laborDateDT = date.valueOf(laborDate);
		if (
			laborSubCategory.containsIgnoreCase('Support-') ||
			laborSubCategory.containsIgnoreCase('SME-')
		) {
			laborCategory = 'SME Time';
		}
		try {
			String check = saveTimeCheck(accountId, minutes, laborDateDT);
			if (check == 'ok') {
				String orgAccountId = accountId;
				String userId = UserInfo.getUserId();
				Rosco_Time__c newTime = new Rosco_Time__c(
					Account__c = accountId,
					User__c = userId,
					Minutes__c = Integer.valueOf(minutes),
					LaborCategory__c = laborCategory,
					LaborSubCategory__c = laborSubCategory,
					LaborChildCategory__c = laborChildCategory,
					LaborDate__c = laborDateDT,
					Role__c = getUserRoleName()
				);
				insert newTime;
				ret = getAccountTime(orgAccountId);
			} else {
				ret = getAccountTime(accountId);
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoActionAccountTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String saveRoscoActionAccountSupport(
		String accountId,
		Map<String, String> accountInfo,
		Map<String, String> roscoAccountInfo,
		List<Map<String, String>> customers,
		List<Map<String, String>> emailDomains
	) {
		String ret = 'Undefined error';
		try {
			saveAccountInfo(accountId, accountInfo);
			saveRoscoAccountInfo(accountId, roscoAccountInfo);
			saveCustomers(customers);
			for (Map<String, String> emailDomain : emailDomains) {
				saveEmailDomain(accountId, emailDomain);
			}

			String soaText =
				'*' +
				UserInfo.getUserName() +
				'* submitted Support update (Account) with the following\n';
			soaText += 'accountId: `' + accountId + '`\n';
			soaText +=
				'accountInfo: ```' +
				String.valueOf(JSON.serializePretty(accountInfo, true)) +
				'```\n';
			soaText +=
				'roscoAccountInfo: ```' +
				String.valueOf(JSON.serializePretty(roscoAccountInfo, true)) +
				'```\n';
			soaText +=
				'customers: ```' +
				String.valueOf(JSON.serializePretty(customers, true)) +
				'```\n';
			soaText +=
				'roscoAccountInfo: ```' +
				String.valueOf(JSON.serializePretty(emailDomains, true)) +
				'```\n';
			slackSOA(soaText);
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoAccountSupport Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, String> saveRoscoActionCaseTime(
		String caseId,
		String minutes,
		String laborCategory,
		String laborSubCategory,
		String laborDate
	) {
		Map<String, String> ret = new Map<String, String>();
		try {
			ret = RoscoHighlight.saveTime(caseId, minutes, laborCategory, laborSubCategory, laborDate);
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoActionCaseTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String saveRoscoActionContactSupport(Map<String, String> customer) {
		String ret = '';
		try {
			String isUser = customer.get('isUser');
			String profile = customer.get('profile');
			String contactId = customer.get('contactId');
			String accountType = customer.get('accountType');
			String techPartnerProgramTier = customer.get('techPartnerProgramTier');
			String accountRecTypeName = customer.get('accountRecTypeName');
			String email = customer.get('email');
			String devUser = String.valueOf(customer.get('devUser'));
			String userId = customer.get('id');
			String timeZone = customer.get('timeZone');
			String flashMessage = customer.get('flashMessage');
			Contact contact = [SELECT Id, Case_Flash_Message__c FROM Contact WHERE Id = :contactId];
			if (flashMessage != contact.Case_Flash_Message__c) {
				saveContactFlashMessage(contact.Id, flashMessage);
			}

			if (isUser == 'true') {
				if (accountType != 'Former Customer') {
					if (accountRecTypeName != 'Partner') {
						if (devUser == 'true') {
							if (!isDevUser(userId)) {
								setDevUser(userId, true);
							}
						} else {
							setDevUser(userId, false);
						}
					}
				}
			}
			if (isUser == 'false') {
				if (profile.containsIgnoreCase('Tanium Community')) {
					if (!email.containsIgnoreCase('@tanium.com')) {
						enableUser(contactId, profile, devUser);
					}
				}
			} else {
				List<Map<String, String>> customers = new List<Map<String, String>>();
				customers.add(customer);
				saveCustomers(customers);
			}
			String options = String.valueOf(customer.get('contactSupportOptions'));
			setContactSupportOption(contactId, options);
			String soaText =
				'*' +
				UserInfo.getUserName() +
				'* submitted Support update (Contact) with the following\n';
			soaText +=
				'customer: ```' +
				String.valueOf(JSON.serializePretty(customer, true)) +
				'```\n';
			slackSOA(soaText);
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoActionContactSupport Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> saveRoscoActionOpportunityTime(
		String opportunityId,
		String laborCategory,
		String laborSubCategory,
		String laborDate
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Datetime laborDateDT = date.valueOf(laborDate);
		try {
			Decimal minutes = 0;
			if (laborSubCategory == 'Discovery') {
				minutes = 60;
			} else if (laborSubCategory == 'Demo') {
				minutes = 180;
			} else if (laborSubCategory == 'RFP') {
				minutes = 300;
			} else if (laborSubCategory == 'Partner Meeting') {
				minutes = 60;
			} else if (laborSubCategory == 'Planning') {
				minutes = 240;
			} else if (laborSubCategory == 'POC') {
				minutes = 300;
			}
			String userId = UserInfo.getUserId();
			Rosco_Time__c newTime = new Rosco_Time__c();
			if (opportunityId.left(3) == '001') {
				newTime.Account__c = opportunityId;
			} else {
				String accountId = getAccountId2(opportunityId);
				newTime.Account__c = accountId;
				newTime.Opportunity__c = opportunityId;
			}
			newTime.User__c = userId;
			newTime.Minutes__c = minutes;
			newTime.LaborCategory__c = laborCategory;
			newTime.LaborSubCategory__c = laborSubCategory;
			newTime.LaborDate__c = laborDateDT;
			newTime.Role__c = getUserRoleName();
			insert newTime;
			if (opportunityId.left(3) == '001') {
				ret = getPreSalesAccountTime(opportunityId);
			} else {
				ret = getOpportunityTime(opportunityId);
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoActionOpportunityTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> saveRoscoActionOpportunityTime2(
		String recordId,
		String opportunityId,
		String laborCategory,
		String laborSubCategory,
		String laborChildCategory,
		String laborDate,
		String minutes
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Datetime laborDateDT = date.valueOf(laborDate);
		try {
			if (laborSubCategory == 'Marketing') {
				Case_Management__c cm = Case_Management__c.getInstance();
				Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
				if (cmfields.contains('rosco_time_internal_opportunity__c')) {
					if (!nullOrEmpty(cm.get('rosco_time_internal_opportunity__c'))) {
						opportunityId = String.valueOf(cm.get('rosco_time_internal_opportunity__c'));
					}
				}
			}
			String userId = UserInfo.getUserId();
			Rosco_Time__c newTime = new Rosco_Time__c();
			if (opportunityId.left(3) == '001') {
				newTime.Account__c = opportunityId;
			} else {
				if (opportunityId == '') {
					newTime.Account__c = recordId;
				} else {
					String accountId = getAccountId2(opportunityId);
					newTime.Account__c = accountId;
					newTime.Opportunity__c = opportunityId;
				}
			}
			newTime.User__c = userId;
			newTime.Minutes__c = Integer.valueOf(minutes);
			newTime.LaborCategory__c = laborCategory;
			newTime.LaborSubCategory__c = laborSubCategory;
			newTime.LaborChildCategory__c = laborChildCategory;
			newTime.LaborDate__c = laborDateDT;
			newTime.Role__c = getUserRoleName();
			insert newTime;
			if (recordId.left(3) == '001') {
				ret = getPreSalesAccountTime(recordId);
			} else {
				ret = getOpportunityTime(opportunityId);
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoActionOpportunityTime Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@Future
	public static void saveContactFlashMessage(Id contactId, String flashMessage) {
		Contact contact = new Contact(Id = contactId, Case_Flash_Message__c = flashMessage);
		try {
			update contact;
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveRoscoActionContactSupport Errors', e);
			Logger.saveLog();
		}
	}

	@Future
	public static void saveAccountInfo(String accountId, Map<String, String> accountInfo) {
		try {
			String soql =
				'SELECT Support_Model__c, Slack_Channel_Id__c ' +
				'FROM Account ' +
				'WHERE Id = \'' +
				accountId +
				'\' ' +
				'LIMIT 1';

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				Boolean updateAccount = false;
				if (accountInfo.get('SupportModel') != null) {
					if (accounts[0].Support_Model__c != accountInfo.get('SupportModel')) {
						accounts[0].Support_Model__c = accountInfo.get('SupportModel');
						updateAccount = true;
					}
				}
				if (accountInfo.get('SlackId') != null) {
					if (accounts[0].Slack_Channel_Id__c != accountInfo.get('SlackId')) {
						accounts[0].Slack_Channel_Id__c = accountInfo.get('SlackId');
						updateAccount = true;
					}
				}
				if (updateAccount) {
					update accounts[0];
				}
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveAccountInfo Errors', e);
			Logger.saveLog();
		}
	}

	@AuraEnabled
	public static String tagSave(String jsonParam) {
		String ret = '';
		try {
			Map<String, Object> objParam = (Map<String, Object>) JSON.deserializeUntyped(jsonParam);
			String soql = 'SELECT Id, Module__c,Impact__c, Comment__c  ' + 'FROM Rosco_Tag_Map__c ';
			String recordId = String.valueOf(objParam.get('recordId'));
			if (recordId.left(3) == '001') {
				soql += 'WHERE Account__c = \'' + recordId + '\' ';
			} else if (recordId.left(3) == '006') {
				soql += 'WHERE Opportunity__c = \'' + recordId + '\' ';
			} else if (recordId.left(3) == '500') {
				soql += 'WHERE Case__c = \'' + recordId + '\' ';
			}
			soql +=
				'AND Jira_Issue__c = \'' +
				String.valueOf(objParam.get('jiraIssueSFId')) +
				'\' ' +
				'LIMIT 1';

			List<Rosco_Tag_Map__c> rtms = Database.query(soql);
			if (!rtms.isEmpty()) {
				rtms[0].Module__c = String.valueOf(objParam.get('module'));
				rtms[0].Impact__c = String.valueOf(objParam.get('impact'));
				rtms[0].Comment__c = String.valueOf(objParam.get('comment'));
				if (objParam.get('opportunityId') == '') {
					rtms[0].Opportunity__c = null;
				} else {
					rtms[0].Opportunity__c = String.valueOf(objParam.get('opportunityId'));
				}
				upsert rtms;
			} else {
				soql =
					'SELECT Id ' +
					'FROM Rosco_Tag__c ' +
					'WHERE Jira_Issue__c  = \'' +
					String.valueOf(objParam.get('jiraIssueSFId')) +
					'\' ' +
					'LIMIT 1';
				String tagId;
				List<Rosco_Tag__c> tags = Database.query(soql);
				if (tags.isEmpty()) {
					Rosco_Tag__c tag = new Rosco_Tag__c();
					tag.description__c = String.valueOf(objParam.get('jiraSummary'));
					tag.Jira_Issue__c = String.valueOf(objParam.get('jiraIssueSFId'));
					tag.Name = String.valueOf(objParam.get('jiraIssueKey'));
					tag.type__c = 'JIRA';
					insert tag;
					tagId = tag.Id;
				} else {
					tagId = tags[0].Id;
				}
				String accountId;
				if (recordId.left(3) == '001') {
					accountId = recordId;
				} else if (recordId.left(3) == '006') {
					accountId = [
						SELECT AccountId
						FROM Opportunity
						WHERE Id = :String.valueOf(objParam.get('recordId'))
					]
					.AccountId;
				} else if (recordId.left(3) == '500') {
					accountId = [
						SELECT AccountId
						FROM Case
						WHERE Id = :String.valueOf(objParam.get('recordId'))
					]
					.AccountId;
				}
				Rosco_Tag_Map__c rtm = new Rosco_Tag_Map__c();
				rtm.Account__c = accountId;
				rtm.Comment__c = String.valueOf(objParam.get('comment'));
				rtm.Impact__c = String.valueOf(objParam.get('impact'));
				rtm.Jira_Issue__c = String.valueOf(objParam.get('jiraIssueSFId'));
				rtm.Module__c = String.valueOf(objParam.get('module'));
				if (objParam.get('opportunityId') == '') {
					rtm.Opportunity__c = null;
				} else {
					rtm.Opportunity__c = String.valueOf(objParam.get('opportunityId'));
				}
				rtm.Case__c = String.valueOf(objParam.get('caseId'));
				rtm.tag__c = tagId;
				insert rtm;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.tagSave Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String tagSaveOppUpdate(String jsonParam) {
		String ret = '';
		try {
			Map<String, Object> objParam = (Map<String, Object>) JSON.deserializeUntyped(jsonParam);
			String soql =
				'SELECT Id ' +
				'FROM Rosco_Tag_Map__c ' +
				'WHERE Id IN (' +
				String.valueOf(objParam.get('mapIds')) +
				')';

			List<Rosco_Tag_Map__c> rtms = Database.query(soql);
			if (!rtms.isEmpty()) {
				for (Rosco_Tag_Map__c r : rtms) {
					r.Opportunity__c = String.valueOf(objParam.get('opportunityId'));
				}
				update rtms;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.tagSaveOppUpdate Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@AuraEnabled
	public static String saveTAMNextSteps(String accountOrOppurtunityId, String stepsText) {
		String ret = 'Undefined error';
		try {
			if (accountOrOppurtunityId.left(3) == '001') {
				Account_Next_Step__c ans = new Account_Next_Step__c();
				ans.Account__c = accountOrOppurtunityId;
				ans.TAM_Next_Steps__c = stepsText.abbreviate(5999);
				ans.TAM_Owner_User__c = UserInfo.getUserId();
				ans.Type__c = 'TAM';
				insert ans;
				ret = 'Updated Account';
			} else {
				String soql =
					'SELECT TAM_Next_Steps__c ' +
					'FROM Opportunity ' +
					'WHERE Id = \'' +
					accountOrOppurtunityId +
					'\' ' +
					'LIMIT 1';
				List<Opportunity> steps = Database.query(soql);
				if (!steps.isEmpty()) {
					steps[0].TAM_Next_Steps__c = stepsText.abbreviate(5999);
					steps[0].Last_TAM_Next_Step_Date__c = system.today();
					update steps[0];
				}
				RecordType tamRecordType = [
					SELECT Id
					FROM RecordType
					WHERE SobjectType = 'TAM_Next_Steps__c' AND DeveloperName = 'TAM_Next_Step'
					LIMIT 1
				];
				TAM_Next_Steps__c tns = new TAM_Next_Steps__c();
				tns.Opportunity__c = accountOrOppurtunityId;
				tns.RecordTypeId = tamRecordType.Id;
				tns.TAM_Next_Steps__c = stepsText.abbreviate(5999);
				insert tns;
				ret = 'Updated Opportunity';
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.saveTAMNextSteps Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static String saveTimeCheck(String accountId, String minutes, Datetime laborDateDT) {
		String ret = 'Error Checking Time';
		try {
			String userId = UserInfo.getUserId();
			String soql =
				'SELECT LaborDate__c, Minutes__c, User__c' +
				' FROM Rosco_Time__c' +
				' WHERE Account__c = \'' +
				accountId +
				'\'' +
				' AND LaborDate__c != null';

			List<Rosco_Time__c> aTime = Database.query(soql);
			Integer userTime = 0;
			for (Rosco_Time__c a : aTime) {
				if (a.User__c == userId) {
					if (laborDateDT.isSameDay(a.LaborDate__c)) {
						userTime = userTime + Integer.valueOf(a.Minutes__c);
					}
				}
			}
			Integer proposedLabor = userTime + Integer.valueOf(minutes);
			Integer allowedLabor = 1440 - userTime;
			if (proposedLabor > 1440) {
				String dateStr =
					laborDateDT.yearGmt() +
					'-' +
					laborDateDT.monthGMT() +
					'-' +
					laborDateDT.dayGMT();
				ret =
					'Time could not be logged.  You attempted to add ' +
					String.valueOf(minutes) +
					' minutes and ' +
					String.valueOf(userTime) +
					' minutes have already been entered on ' +
					dateStr +
					'.  ' +
					'A maximum of 1440 minutes (24 hr) can be logged in one day (based on UTC).';
			} else {
				ret = 'ok';
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.saveTimeCheck Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	@Future
	public static void setContactSupportOption(String contactId, String options) {
		TriggerHandler.bypass(new List<String>{ 'ContactTriggerHandler' });
		try {
			Contact contact = [
				SELECT Id, AccountId, Support_Option__c
				FROM Contact
				WHERE Id = :contactId
			];
			if (contact.Support_Option__c != options) {
				contact.Support_Option__c = options;
				update contact;
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.setContactSupportOption Errors', e);
			Logger.saveLog();
		}
	}

	@AuraEnabled
	public static void setDevUser(String userIdStr, Boolean enable) {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });
		Id userId;
		try {
			userId = Id.valueOf(userIdStr);
		} catch (Exception e) {
			Logger.error('RoscoAction.setDevUser Errors', e).setRecordId(userIdStr);
			Logger.saveLog();
			throw new AuraHandledException('Error getting userId ' + e.getMessage());
		}
		try {
			if (enable) {
				if (!isDevUser(userId)) {
					User u = [SELECT Id, Email FROM User WHERE Id = :userId];
					u.FederationIdentifier = u.Email;
					update u;
					List<PermissionSetAssignment> psAssignments = new List<PermissionSetAssignment>();
					Id constellantDevPermSetId = [
						SELECT Id
						FROM PermissionSet
						WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
					]
					.Id;

					Id partnerCaseAccessPermSetId = [
						SELECT Id
						FROM PermissionSet
						WHERE Name = :Constants.PARTNER_CASE_ACCESS
					]
					.Id;

					Id zoominUserPermSetId = [
						SELECT Id
						FROM PermissionSet
						WHERE Name = :Constants.ZOOMIN_COMMUNITY_CLOUD_PERM_SET
					]
					.Id;

					psAssignments.add(
						new PermissionSetAssignment(
							PermissionSetId = constellantDevPermSetId,
							AssigneeId = u.Id
						)
					);

					psAssignments.add(
						new PermissionSetAssignment(
							PermissionSetId = partnerCaseAccessPermSetId,
							AssigneeId = u.Id
						)
					);

					psAssignments.add(
						new PermissionSetAssignment(
							PermissionSetId = zoominUserPermSetId,
							AssigneeId = u.Id
						)
					);

					List<Database.SaveResult> saveResult = Database.insert(psAssignments, false);
					Logger.logDatabaseErrors(
							LoggingLevel.ERROR,
							'RoscoAction.setDevUser Errors',
							saveResult
						)
						.addTag('apex');
					Logger.saveLog();
				}
			} else {
				if (isDevUser(userId)) {
					PermissionSet ps = [
						SELECT Id
						FROM PermissionSet
						WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
					];
					String soql2 =
						'SELECT Id ' +
						'FROM PermissionSetAssignment ' +
						'WHERE AssigneeId = \'' +
						userId +
						'\' ' +
						'AND PermissionSetId = \'' +
						ps.Id +
						'\' ' +
						'LIMIT 1';
					List<PermissionSetAssignment> assignments = Database.query(soql2);
					if (!assignments.isEmpty()) {
						delete assignments[0];
					}
				}
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.setDevUser Errors', e).setRecordId(userId);
			Logger.saveLog();
			throw new AuraHandledException('Error assigning permission set ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void setIsFrozen(String userId, Boolean isFrozen) {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });
		try {
			UserLogin userLogin = [SELECT Id, IsFrozen FROM UserLogin WHERE UserId = :userId LIMIT 1];
			if (userLogin.IsFrozen != isFrozen) {
				userLogin.IsFrozen = isFrozen;
				update userLogin;
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.setIsFrozen Errors', e).setRecordId(userId);
			Logger.saveLog();
			throw new AuraHandledException('Error updating UserLogin ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void setPermissionSet(String userId, String permSetName) {
		if (permSetName == null || permSetName == '' || userId == null || userid == '') {
			return;
		}
		try {
			List<PermissionSetAssignment> assignments = [
				SELECT Id
				FROM PermissionSetAssignment
				WHERE PermissionSet.Name = :permSetName AND AssigneeId = :userId
			];
			if (assignments.size() == 0) {
				Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = :permSetName].Id;
				PermissionSetAssignment psa = new PermissionSetAssignment(
					PermissionSetId = permSetId,
					AssigneeId = userId
				);
				insert psa;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.setPermissionSet Errors', e).setRecordId(userId);
			Logger.saveLog();
			throw new AuraHandledException('Error assigning permission-set ' + e.getMessage());
		}
	}

	public static void removePermissionSet(String userId, String permSetName) {
		if (String.isBlank(permSetName) || String.isBlank(userId)) {
			return;
		}

		List<PermissionSetAssignment> assignments = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE PermissionSet.Name = :permSetName AND AssigneeId = :userId
		];

		List<Database.DeleteResult> deleteResults = Database.delete(assignments, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'RoscoAction.removePermissionSet Errors',
				deleteResults
			)
			.addTag('apex');
		Logger.saveLog();
	}

	@AuraEnabled
	public static void setProfileId(String userId, String profileId) {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });
		try {
			User user = [SELECT Id, ProfileId FROM User WHERE Id = :userId LIMIT 1];
			if (user.ProfileId != profileId) {
				user.ProfileId = profileId;
				update user;
			}
		} catch (DmlException e) {
			Logger.error('RoscoAction.setProfileId Errors', e).setRecordId(userId);
			Logger.saveLog();
			throw new AuraHandledException('Error setting profileId ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void setTimeZone(String userId, String timeZone) {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });
		if (userId == null || timeZone == null) {
			return;
		}
		try {
			User user = [SELECT Id, TimeZoneSidKey FROM User WHERE Id = :userId LIMIT 1];
			if (user.TimeZoneSidKey != timeZone) {
				user.TimeZoneSidKey = timeZone;
				update user;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.setTimeZone Errors', e).setRecordId(userId);
			Logger.saveLog();
			throw new AuraHandledException('Error updating user ' + e.getMessage());
		}
	}

	public static Boolean shouldRequireOpp(String accountId) {
		Boolean ret = true;
		try {
			String soql =
				'SELECT Id ' +
				'FROM Account ' +
				'WHERE Id = \'' +
				accountId +
				'\' ' +
				'AND Type IN (' +
				'\'Reseller (channel partner, VAR, LAR, etc)\'' +
				',\'MSP partner\'' +
				',\'Distributor\'' +
				',\'Alliance partner\'' +
				',\'System Integrator\') ' +
				'LIMIT 1';

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				ret = false;
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.shouldRequireOpp Errors', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static void slackSOA(String soaText) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String soaChannel = 'CJ4PWL412'; // #tool_soa
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String soa = String.valueOf(cm.get('rosco_slack_exceptions__c'));

				if (nullOrEmpty(soa) == false) {
					soaChannel = soa;
				}
			}
			String webhookURL = '';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}
			JSONGenerator soaGen = JSON.createGenerator(true);
			soaGen.writeStartObject();
			soaGen.writeStringField('channel', soaChannel);
			soaGen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			soaGen.writeStringField('text', soaText);
			soaGen.writeEndObject();
			String soaBody = soaGen.getAsString();
			if (!Test.isRunningTest()) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', soaBody));
			}
		} catch (Exception e) {
			Logger.error('RoscoAction.slackSOA Errors', e);
			Logger.saveLog();
		}
	}

	@AuraEnabled
	public static void tagDelete(String tagId) {
		try {
			Rosco_Tag_Map__c tag = [SELECT Id FROM Rosco_Tag_Map__c WHERE Id = :tagId LIMIT 1];
			delete tag;
		} catch (Exception e) {
			Logger.error('RoscoAction.tagDelete Errors', e);
			Logger.saveLog();
		}
	}

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