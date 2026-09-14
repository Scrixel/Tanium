/**
 * Copyright (c) 2026 Tanium, Inc. All rights reserved.
 *
 * @Business: RoscoSchedule Schedulable class - supports community app
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7277    2024-02-23    Jason's last changes linked to ticket SCLOUD-723 plus layout changes by Tanium Dev Team
 * SS-7884    2024-04-26    Grant Permission Set to Partners with Tier. Use Nebulla Logger.
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-10251   2025-02-27    Remove Constellant Dev references and replace it with Tanium Developer Users
 * SS-10536   2025-03-24    Updated methods manageCmtyUsersFedId, manageCmtyUsersDemote, manageCmtyUsersPromoteAccount
 * SS-9790    2025-07-18    Remove unused method from class
 * SS-13113   2026-04-27    Update community user query to include users with a contact tied to an active parent account
 * SS-13086   2026-05-19    Replace Level_3_Sub_Area__c with Geo__c for Japan bypass routing
 */
global class RoscoSchedule implements Schedulable {
	public String action = '';
	public String caseId = '';
	public String jobName = '';

	global void execute(SchedulableContext ctx) {
		if (action == 'evaluateCaseEscalation') {
			RoscoCaseProcesses.evaluateCaseEscalation(caseId, jobName);
		} else if (action == 'all') {
			deEscalateCases();
			setToPartnerSCIfKimbleDone();
			setToSCIfMMOppWon2();
			nagCaseContact();
			closedSolvedCases();
			manageCmtyUsers();
		} else if (action == 'deEscalateCases') {
			deEscalateCases();
		} else if (action == 'setSupportModel') {
			setToPartnerSCIfKimbleDone();
			setToSCIfMMOppWon2();
		} else if (action == 'nagCaseContact') {
			nagCaseContact();
		} else if (action == 'closedSolvedCases') {
			closedSolvedCases();
		} else if (action == 'manageCmtyUsers') {
			manageCmtyUsers();
		}
	}

	public static void closedSolvedCases() {
		try {
			List<Case> cases = [
				SELECT Id, Solved_Date__c, CaseNumber, Subject
				FROM Case
				WHERE Status = 'Solved' AND Solved_Date__c < LAST_N_DAYS:8
				LIMIT 1000
			];
			for (Case c : cases) {
				c.Status = 'Closed';
			}
			update cases;
			String emailBody = '<html>';
			if (cases.size() == 0) {
				emailBody += '0 cases were closed';
			} else {
				emailBody += '<b><u>The following cases were closed</u></b><br>';
				for (Case c : cases) {
					emailBody += c.CaseNumber + ':' + c.Subject + '<br>';
				}
			}
			sendEmail('closedSolvedCases execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('closedSolvedCases', e);
			Logger.saveLog();
		}
	}

	public static void deEscalateCases() {
		String body = '<html>';
		try {
			String soql =
				'SELECT Id, ' +
				'CaseNumber,' +
				'Subject,' +
				'Escalation_Pod__c,' +
				'Escalation_Team__c,' +
				'Escalation_Tier__c ' +
				'FROM Case ' +
				'WHERE Status NOT IN (\'Closed\', \'Closed As Duplicate2\', \'Closed as Duplicate\',\'Solved\') ' +
				'AND Escalation_Tier__c IN (\'Level 2\', \'Level 3\') ' +
				'AND (Last_Customer_Response_Date__c = null OR Last_Customer_Response_Date__c <= LAST_N_DAYS:30) ' +
				'AND (Last_Response_Date__c = null OR Last_Response_Date__c <= LAST_N_DAYS:30) ' +
				'AND Id NOT IN (SELECT ParentId FROM CaseFeed WHERE CreatedDate = LAST_N_DAYS:30) ' +
				'AND Id NOT IN (SELECT ParentId FROM FeedComment WHERE CreatedDate = LAST_N_DAYS:30) ' +
				'LIMIT 20';

			if (Test.isRunningTest()) {
				soql = 'SELECT Id,CaseNumber,Subject,Escalation_Tier__c,Escalation_Team__c FROM Case LIMIT 1';
			}
			List<Case> cases = Database.query(soql);
			List<Case> updatedCases = new List<Case>();
			List<FeedItem> items = new List<FeedItem>();
			for (Case c : cases) {
				String deescinput =
					'Auto Deescalated from ' +
					c.Escalation_Tier__c +
					' (' +
					c.Escalation_Team__c +
					') ' +
					'as there have been no updates in last 30 days';
				c.Escalation_Tier__c = 'Level 1';
				c.Escalation_Reason__c = deescinput;
				c.Escalation_Artifact__c = null;
				c.Escalation_Type__c = null;
				c.DeEscalation_Date__c = System.Datetime.now();
				c.IsEscalated = false;
				updatedCases.add(c);
				FeedItem fi = new FeedItem(
					ParentId = c.Id,
					Body = deescinput,
					Visibility = 'InternalUsers',
					IsRichText = false,
					NetworkScope = 'AllNetworks'
				);
				items.add(fi);
			}
			if (!Test.isRunningTest()) {
				update updatedCases;
				insert items;
			}
			String emailBody = '<html><b><u>deEscalateCases() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (updatedCases.size() == 0) {
				emailBody += '0 cases found requiring de-escalation';
			} else {
				emailBody += '<b><u>The following cases were de-escalated</u></b><br>';
				for (Case c : updatedCases) {
					emailBody += c.CaseNumber + ':' + c.Subject + '<br>';
				}
			}
			sendEmail('deEscalateCases execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('deEscalateCases', e);
			Logger.saveLog();
		}
	}

	public static void manageAPINotificationsGroup() {
	}

	public static void manageCmtyUsers() {
		Map<String, Map<String, String>> roscoDomains = getRoscoDomains();
		manageCmtyUsersDemote();
		manageCmtyUsersPromoteAccount(roscoDomains);
		manageCmtyUsersPromoteProfile(roscoDomains);
		manageCmtyUsersFedId();
		manageCmtyUsersConstellantAdd();
		manageCmtyUsersConstellantRemove();
		UserManagePermissionSetBatch batch;
		if (!Test.isRunningTest()) {
			batch = new UserManagePermissionSetBatch();
		} else {
			String customQuery =
				'SELECT Id,' +
				' Contact.Account.Tech_Partner_Program_Tier__c,' +
				' Contact.Account.RecordType.DeveloperName' +
				' FROM User' +
				' WHERE FirstName LIKE \'Test%\'';
			batch = new UserManagePermissionSetBatch(customQuery);
		}
		Database.executeBatch(batch);
	}

	public static void manageCmtyUsersConstellantAdd() {
		try {
			String soql =
				'SELECT Id,' +
				'Email,' +
				'Profile.Name,' +
				'Contact.Account.Name,' +
				'Contact.Account.Type, ' +
				'LastLoginDate ' +
				'FROM User ' +
				'WHERE IsActive = true ' +
				'AND Contact.Account.Type IN (\'Customer\') ' +
				'AND Profile.Name IN (\'Tanium Community Login Authenticated\',\'Tanium Community Login Authenticated Case\',\'Tanium Community Login Super User\') ' +
				'AND Id NOT IN (SELECT AssigneeId  ' +
				'FROM PermissionSetAssignment ' +
				'WHERE PermissionSet.Name = \'' +
				Constants.CONSTELLANT_DEV_PERM_SET +
				'\' ) ';
			String soqlTest = 'SELECT Id, Email, Profile.Name, Contact.Account.Name, Contact.Account.Type, LastLoginDate FROM User WHERE (Email = \'roscoapextest@roscolab.com\' OR Email = \'roscoapextest@roscolab2.com\')';

			List<User> users = (!Test.isRunningTest())
				? Database.query(soql)
				: Database.query(soqlTest);
			List<User> usersUpdated = new List<User>();
			if (!users.isEmpty()) {
				List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
				for (User u : users) {
					PermissionSetAssignment assignment = new PermissionSetAssignment();
					assignment.AssigneeId = u.Id;
					assignment.PermissionSetId = '0PS7V0000000asUWAQ';
					assignments.add(assignment);
					usersUpdated.add(u);
					if (assignments.size() > 200) {
						break;
					}
				}
				try {
					insert assignments;
				} catch (Exception e) {
				}
			}
			String emailBody = '<html><b><u>manageCmtyUsersConstellantAdd() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (usersUpdated.size() == 0) {
				emailBody += '0 users found requiring addition to Constellant Dev permission set';
			} else {
				emailBody += '<b><u>The following users were added to Constellant Dev permission set</u></b><br>';
				for (User u : usersUpdated) {
					emailBody +=
						u.Email +
						' | ' +
						u.Contact.Account.Name +
						' | ' +
						u.Id +
						' | ' +
						u.Profile.Name +
						' | ' +
						u.LastLoginDate +
						'<br>';
				}
			}
			sendEmail('manageCmtyUsersConstellantAdd execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('manageCmtyUsersConstellantAdd', e);
			Logger.saveLog();
		}
	}

	public static void manageCmtyUsersFedId() {
		try {
			List<String> existingFedIds = getExistingFederationIds();
			String soql =
				'SELECT Id,' +
				'Email,' +
				'Profile.Name,' +
				'Contact.Account.Name,' +
				'Contact.Account.Type, ' +
				'LastLoginDate ' +
				'FROM User ' +
				'WHERE IsActive = true ' +
				'AND FederationIdentifier = null ' +
				'AND Profile.Name IN (\'Tanium Community Login Authenticated\',\'Tanium Community Login Authenticated Case\',\'Tanium Community Login Super User\') ' +
				'LIMIT 50000';

			List<User> users = Database.query(soql);
			List<User> usersToUpdate = new List<User>();
			if (!users.isEmpty()) {
				for (User u : users) {
					if (!existingFedIds.contains(u.Email)) {
						u.FederationIdentifier = u.Email;
						usersToUpdate.add(u);
						existingFedIds.add(String.valueOf(u.Id));
					}
					if (usersToUpdate.size() > 200) {
						break;
					}
				}
			}
			Database.SaveResult[] saveResults = Database.update(usersToUpdate, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'RoscoSchedule.manageCmtyUsersFedId Errors',
					saveResults
				)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
			String emailBody = '<html><b><u>manageCmtyUsersFedId() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (usersToUpdate.size() == 0) {
				emailBody += '0 users found requiring definition of Federation Id';
			} else {
				emailBody += '<b><u>The following users had their Federation Id set </u></b><br>';
				for (User u : usersToUpdate) {
					emailBody +=
						u.Email +
						' | ' +
						u.Contact.Account.Name +
						' | ' +
						u.Id +
						' | ' +
						u.Profile.Name +
						' | ' +
						u.LastLoginDate +
						'<br>';
				}
			}
			sendEmail('manageCmtyUsersFedId execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('manageCmtyUsersFedId', e);
			Logger.saveLog();
		}
	}

	public static void manageCmtyUsersConstellantRemove() {
		try {
			String soql =
				'SELECT Id, ' +
				'Assignee.Email, ' +
				'Assignee.Profile.Name,' +
				'Assignee.Contact.Account.Name,' +
				'Assignee.Contact.Account.Type,' +
				'Assignee.LastLoginDate ' +
				'FROM PermissionSetAssignment ' +
				'WHERE PermissionSet.Name = \'' +
				Constants.CONSTELLANT_DEV_PERM_SET +
				'\' ' +
				'AND Assignee.Profile.Name = \'Tanium Community Login Unknown\' ' +
				'AND Assignee.Contact.Account.Type != \'Former Customer\' ';

			List<PermissionSetAssignment> assignments = Database.query(soql);
			String emailBody = '<html><b><u>manageCmtyUsersConstellantRemove() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (assignments.size() == 0) {
				emailBody += '0 users found requiring removal from Constellant Dev permission set';
			} else {
				emailBody +=
					'<b><u>The following users were removed from ' +
					Constants.CONSTELLANT_DEV_PERM_SET +
					' Permission set</u></b><br>';
				for (PermissionSetAssignment a : assignments) {
					emailBody += a.Assignee.Email + ' | ' + '<br>';
					emailBody +=
						a.Assignee.Email +
						' | ' +
						a.Assignee.Contact.Account.Name +
						' | ' +
						a.Assignee.Id +
						' | ' +
						a.Assignee.Profile.Name +
						' | ' +
						a.Assignee.LastLoginDate +
						'<br>';
				}
			}

			sendEmail(
				'manageCmtyUsersConstellantRemove execution status (running read only)',
				emailBody
			);
		} catch (DmlException e) {
			Logger.error('manageCmtyUsersConstellantRemove', e);
			Logger.saveLog();
		}
	}

	public static void manageCmtyUsersDemote() {
		try {
			String soql =
				'SELECT Id, ' +
				'Email,' +
				'Profile.Name,' +
				'Contact.Account.Name,' +
				'Contact.Account.Type, ' +
				'LastLoginDate ' +
				'FROM User ' +
				'WHERE Profile.Name IN (\'Tanium Community Login Authenticated\',\'Tanium Community Login Authenticated Case\',\'Tanium Community Login Super User\') ' +
				'AND Contact.Account.Type = \'Former Customer\' ' +
				'AND Contact.Account.Parent.Type != \'Customer\' ' +
				'ORDER BY LastLoginDate DESC NULLS LAST';

			List<User> users = Database.query(soql);
			if (!users.isEmpty()) {
				for (User u : users) {
					u.ProfileId = '00e0e000000ovybAAA'; //Tanium Community Login Unknown
				}
			}
			Database.SaveResult[] saveResults = Database.update(users, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'RoscoSchedule.manageCmtyUsersDemote Errors',
					saveResults
				)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();

			String emailBody = '<html><b><u>manageCmtyUsersDemote() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (users.size() == 0) {
				emailBody += '0 users found requiring demotion';
			} else {
				emailBody += '<b><u>The following users were demoted to Tanium Community Login Unknown profile</u></b><br>';
				for (User u : users) {
					emailBody +=
						u.Email +
						' | ' +
						u.Contact.Account.Name +
						' | ' +
						u.Id +
						' | ' +
						u.Profile.Name +
						' | ' +
						u.LastLoginDate +
						'<br>';
				}
			}
			sendEmail('manageCmtyUsersDemote execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('manageCmtyUsersDemote', e);
			Logger.saveLog();
		}
	}

	public static void manageCmtyUsersPromoteAccount(Map<String, Map<String, String>> roscoDomains) {
		try {
			String soql =
				'SELECT Id,' +
				'Email,' +
				'Profile.Name,' +
				'ContactId, ' +
				'Contact.Account.Name,' +
				'Contact.Account.Type, ' +
				'LastLoginDate ' +
				'FROM User ' +
				'WHERE IsActive = true ' +
				'AND Email LIKE \'%@%\' ' +
				'AND Profile.Name IN (\'Tanium Community Login Unknown\') ' +
				'AND Contact.Account.Id IN (\'0010e00001RcgMsAAJ\',\'0010e00001JOFGPAA5\') ' +
				'AND Contact.Account.Type != \'Former Customer\' ' +
				'AND ContactId != null ' +
				'LIMIT 100';
			String soqlTest = 'SELECT Id, Email, Profile.Name, ContactId, Contact.Account.Name, Contact.Account.Type, LastLoginDate FROM User WHERE (Email = \'roscoapextest@roscolab.com\' OR Email = \'roscoapextest@roscolab2.com\')';

			List<User> users = (!Test.isRunningTest())
				? Database.query(soql)
				: Database.query(soqlTest);
			List<Contact> contactsToUpdate = new List<Contact>();
			Map<String, String> accountMap = new Map<String, String>();
			if (!users.isEmpty()) {
				for (User u : users) {
					List<String> emailSplit = u.Email.split('@');
					if (roscoDomains.containsKey(emailSplit[1])) {
						Map<String, String> rd = roscoDomains.get(emailSplit[1]);
						String automation = rd.get('automation');
						String accountId = rd.get('accountId');
						if (accountId.contains('001')) {
							if (
								automation == 'Account Only' ||
								automation == 'Support KB' ||
								automation == 'Support Case'
							) {
								Contact c = new Contact();
								c.Id = u.ContactId;
								c.AccountId = accountId;
								contactsToUpdate.add(c);
								accountMap.put(u.Id, rd.get('accountName'));
							}
						}
					}
				}
			}
			Database.SaveResult[] saveResults = Database.update(contactsToUpdate, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'RoscoSchedule.manageCmtyUsersPromoteAccount Errors',
					saveResults
				)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
			String emailBody = '<html><b><u>manageCmtyUsersPromoteAccount() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (accountMap.size() == 0) {
				emailBody += '0 contacts found requiring demotion';
			} else {
				emailBody += '<b><u>The following users had their account updated</u></b><br>';
				for (User u : users) {
					if (accountMap.containsKey(u.Id)) {
						emailBody +=
							u.Email +
							' | ' +
							accountMap.get(u.Id) +
							' | ' +
							u.Id +
							' | ' +
							u.Profile.Name +
							' | ' +
							u.LastLoginDate +
							'<br>';
					}
				}
			}
			sendEmail('manageCmtyUsersPromoteAccount execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('manageCmtyUsersPromoteAccount', e);
			Logger.saveLog();
		}
	}

	public static void manageCmtyUsersPromoteProfile(Map<String, Map<String, String>> roscoDomains) {
		try {
			String soql =
				'SELECT Id,' +
				'Email,' +
				'Profile.Name,' +
				'ContactId, ' +
				'Contact.Account.Name,' +
				'Contact.Account.Type, ' +
				'LastLoginDate ' +
				'FROM User ' +
				'WHERE IsActive = true ' +
				'AND Email LIKE \'%@%\' ' +
				'AND Profile.Name =\'Tanium Community Login Unknown\' ' +
				'AND Contact.Account.Type != \'Former Customer\' ' +
				'AND Contact.Account.Id NOT IN (\'0010e00001RcgMsAAJ\',\'0010e00001JOFGPAA5\') ' +
				'LIMIT 50000';
			String soqlTest = 'SELECT Id, Email, Profile.Name, ContactId, Contact.Account.Name, Contact.Account.Type, LastLoginDate FROM User WHERE (Email = \'roscoapextest@roscolab.com\' OR Email = \'roscoapextest@roscolab2.com\')';

			List<User> users = (!Test.isRunningTest())
				? Database.query(soql)
				: Database.query(soqlTest);
			List<User> usersToUpdate = new List<User>();
			Map<String, String> profileMap = new Map<String, String>();
			if (!users.isEmpty()) {
				for (User u : users) {
					if (usersToUpdate.size() > 200) {
						break;
					}
					List<String> emailSplit = u.Email.split('@');
					if (roscoDomains.containsKey(emailSplit[1])) {
						Map<String, String> rd = roscoDomains.get(emailSplit[1]);
						String automation = rd.get('automation');
						String accountId = rd.get('accountId');
						if (accountId.contains('001')) {
							if (automation == 'Support KB') {
								u.ProfileId = '00e0e000000ovyZAAQ';
								usersToUpdate.add(u);
								profileMap.put(u.Id, 'Tanium Community Login Authenticated');
							} else if (automation == 'Support Case') {
								u.ProfileId = '00e0e0000016DI4AAM';
								usersToUpdate.add(u);
								profileMap.put(u.Id, 'Tanium Community Login Authenticated Case');
							}
						}
					}
				}
			}
			Database.SaveResult[] saveResults = Database.update(usersToUpdate, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'RoscoSchedule.manageCmtyUsersPromoteProfile Errors',
					saveResults
				)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
			String emailBody = '<html><b><u>manageCmtyUsersPromoteProfile() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (usersToUpdate.size() == 0 && !Test.isRunningTest()) {
				emailBody += '0 users found requiring profile update';
			} else {
				emailBody += '<b><u>The following users had their profile updated</u></b><br>';
				for (User u : usersToUpdate) {
					emailBody +=
						u.Email +
						' | ' +
						u.Contact.Account.Name +
						' | ' +
						u.Id +
						' | ' +
						profileMap.get(u.Id) +
						' | ' +
						u.LastLoginDate +
						'<br>';
				}
			}
			sendEmail('manageCmtyUsersPromoteProfile execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('manageCmtyUsersPromoteProfile', e);
			Logger.saveLog();
		}
	}

	public static void setToPartnerSCIfKimbleDone() {
		try {
			String soql =
				'SELECT Id,Name ' +
				'FROM Account ' +
				'WHERE Id IN (SELECT Account_Supported__c ' +
				'FROM Support_Partner__c ' +
				'WHERE Partner_Role__c  = \'Support\' ' +
				'AND Support_Partner__c != \'0013200001D3n0nAAB\') ' +
				'AND Id IN (SELECT KimbleOne__Account__c ' +
				'FROM KimbleOne__DeliveryGroup__c ' +
				'WHERE KimbleOne__DeliveryStage__r.Name = \'Closed\') ' +
				'AND Support_Model__c = null ' +
				'LIMIT 20';

			String soqlTest = 'SELECT Id, Name, Support_Model__c FROM Account';
			List<Account> accounts = (!Test.isRunningTest())
				? Database.query(soql)
				: Database.query(soqlTest);
			if (!accounts.isEmpty()) {
				for (Account a : accounts) {
					a.Support_Model__c = 'Partner Supported (SC)';
				}
			}
			if (!Test.isRunningTest()) {
				update accounts;
			}
			String emailBody = '<html><b><u>setToPartnerSCIfKimbleDone() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (accounts.size() == 0) {
				emailBody += '0 accounts found requiring update';
			} else {
				emailBody += '<b><u>The following accounts were updated to Partner Supported (SC)</u></b><br>';
				for (Account a : accounts) {
					emailBody += a.Name + '(' + a.Id + ')' + '<br>';
				}
			}
			sendEmail('setToPartnerSCIfKimbleDone execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('setToPartnerSCIfKimbleDone', e);
			Logger.saveLog();
		}
	}

	public static void setToSCIfMMOppWon2() {
		try {
			String stage = 'CLOSED WON';
			if (Test.isRunningTest()) {
				stage = 'TEST';
			}
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String accountTypes = '\'Customer\'';
			if (cmfields.contains('rosco_set_support_model_a_accounttypes__c')) {
				String settingValue = String.valueOf(
					cm.get('rosco_set_support_model_a_accounttypes__c')
				);
				if (settingValue != null && settingValue != '') {
					accountTypes = settingValue;
				}
			}
			String accountSegments = '\'Enterprise\'';
			if (cmfields.contains('rosco_set_support_model_a_accountseg__c')) {
				String settingValue = String.valueOf(cm.get('rosco_set_support_model_a_accountseg__c'));
				if (settingValue != null && settingValue != '') {
					accountSegments = settingValue;
				}
			}
			String opportunityStages = '\'CLOSED WON\'';
			if (cmfields.contains('rosco_set_support_model_a_oppstages__c')) {
				String settingValue = String.valueOf(cm.get('rosco_set_support_model_a_oppstages__c'));
				if (settingValue != null && settingValue != '') {
					opportunityStages = settingValue;
				}
			}
			String soql =
				'SELECT Id,Type,Name,Segment__c,Geo__c,Seats_Purchased1__c ' +
				'FROM Account ' +
				'WHERE Support_Model__c = null ';
			if (accountTypes != '') {
				soql += 'AND Type IN (' + accountTypes + ') ';
			}
			if (opportunityStages != '') {
				soql +=
					'AND Id IN (' +
					'SELECT AccountId ' +
					'FROM Opportunity ' +
					'WHERE StageName IN (' +
					opportunityStages +
					')) ';
			}
			soql += 'LIMIT 10';
			String soqlTest = 'SELECT Id,Type,Name,Segment__c,Geo__c,Seats_Purchased1__c FROM Account';

			List<Account> accounts = (!Test.isRunningTest())
				? Database.query(soql)
				: Database.query(soqlTest);
			List<String> tamAccounts = getTanTamSumAccounts(accounts);
			if (!accounts.isEmpty()) {
				for (Account a : accounts) {
					if (a.Geo__c == 'Japan') {
						if (a.Seats_Purchased1__c < 25000) {
							if (tamAccounts.contains(a.Id)) {
								a.Support_Model__c = 'Hybrid (Japan Bypass)';
							} else {
								a.Support_Model__c = 'Support Center (Japan Bypass)';
							}
						} else {
							a.Support_Model__c = 'Hybrid (Japan Bypass)';
						}
					} else {
						if (a.Seats_Purchased1__c < 5000) {
							a.Support_Model__c = 'Support Center (Poland)';
						} else if (a.Seats_Purchased1__c < 25000) {
							if (tamAccounts.contains(a.Id)) {
								a.Support_Model__c = 'Hybrid';
							} else {
								a.Support_Model__c = 'Support Center';
							}
						} else {
							a.Support_Model__c = 'Hybrid';
						}
					}
				}
				if (!Test.isRunningTest()) {
					update accounts;
				}
			}
			String emailBody = '<html><b><u>setToSCIfMMOppWon2() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (accounts.size() == 0) {
				emailBody += '0 accounts found requiring update';
			} else {
				emailBody += '<b><u>The following accounts Support Model were updated</u></b><br>';
				for (Account a : accounts) {
					emailBody +=
						a.Name +
						'(' +
						a.Id +
						'): ' +
						String.valueOf(a.Support_Model__c) +
						'<br>';
				}
			}
			sendEmail('setToSCIfMMOppWon2 execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('setToSCIfMMOppWon2', e);
			Logger.saveLog();
		}
	}

	@future
	public static void sendEmail(String subject, String body) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D23R0000000093SAA';
			if (cmfields.contains('rosco_owea__c')) {
				if (cm.get('rosco_owea__c') != null) {
					if (cm.get('rosco_owea__c') != '') {
						owea = String.valueOf(cm.get('rosco_owea__c'));
					}
				}
			}
			List<String> to = new List<String>();
			to.add('soa@tanium.com');
			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setOrgWideEmailAddressId(owea);
			mail.setToAddresses(to);
			mail.setSubject(subject);
			mail.setHtmlBody(body);
			mail.setPlainTextBody(body.stripHtmlTags());
			if (!Test.isRunningTest()) {
				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
		} catch (DmlException e) {
			Logger.error('sendEmail', e);
			Logger.saveLog();
		}
	}

	public static void setToSCIfMMOppWon() {
		try {
			String stage = 'CLOSED WON';
			if (Test.isRunningTest()) {
				stage = 'TEST';
			}
			String soql =
				'SELECT Id,Type,Geo__c ' +
				'FROM Account ' +
				'WHERE Type = \'Customer\' ' +
				'AND Segment__c = \'Enterprise\' ' +
				'AND Support_Model__c = null ' +
				'AND Id IN (' +
				'SELECT AccountId ' +
				'FROM Opportunity ' +
				'WHERE StageName = \'' +
				stage +
				'\') ' +
				'LIMIT 10';

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				for (Account a : accounts) {
					if (a.Geo__c == 'Japan') {
						a.Support_Model__c = 'Support Center (Japan Bypass)';
					} else {
						a.Support_Model__c = 'Support Center';
					}
				}
				if (!Test.isRunningTest()) {
					update accounts;
				}
			}
		} catch (DmlException e) {
			Logger.error('setToSCIfMMOppWon', e);
			Logger.saveLog();
		}
	}

	public static List<String> getExistingFederationIds() {
		List<String> ret = new List<String>();
		try {
			String soql =
				'SELECT FederationIdentifier ' +
				'FROM User ' +
				'WHERE IsActive = true ' +
				'AND FederationIdentifier != null ' +
				'AND Profile.Name IN (\'Tanium Community Login Authenticated\',\'Tanium Community Login Authenticated Case\',\'Tanium Community Login Super User\') ';

			List<User> users = Database.query(soql);
			if (!users.isEmpty()) {
				for (User u : users) {
					ret.add(String.valueOf(u.FederationIdentifier));
				}
			}
		} catch (DmlException e) {
			Logger.error('getExistingFederationIds', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getRoscoDomains() {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		try {
			String soql =
				'SELECT Name, ' +
				'Account__c, ' +
				'Account__r.Name, ' +
				'user_automation__c ' +
				'FROM Rosco_domain__c ' +
				'WHERE Account__c != null ' +
				'AND user_automation__c IN (\'Account Only\',\'Support KB\',\'Support Case\')';

			List<Rosco_domain__c> domains = Database.query(soql);
			if (!domains.isEmpty()) {
				for (Rosco_domain__c domain : domains) {
					Map<String, String> d = new Map<String, String>();
					d.put('automation', domain.user_automation__c);
					d.put('accountId', domain.Account__c);
					d.put('accountName', domain.Account__r.Name);
					ret.put(domain.Name, d);
				}
			}
		} catch (DmlException e) {
			Logger.error('getRoscoDomains', e);
			Logger.saveLog();
		}
		return ret;
	}

	public static List<String> getTanTamSumAccounts(List<Account> accounts) {
		List<String> ret = new List<String>();
		try {
			Set<Id> accountIds = new Set<Id>();
			for (Account a : accounts) {
				accountIds.add(a.Id);
			}
			String soql =
				'SELECT SBQQ__Quote__r.SBQQ__Account__c ' +
				'FROM SBQQ__QuoteLine__c ' +
				'WHERE Product_Code__c = \'TAN-TAM-SUM\' ' +
				'AND SBQQ__Quote__r.Opportunity_Stage__c = \'CLOSED WON\' ' +
				'AND SBQQ__Quote__r.SBQQ__Account__c IN:accountIds';

			List<SBQQ__QuoteLine__c> lines = Database.query(soql);
			if (!lines.isEmpty()) {
				for (SBQQ__QuoteLine__c l : lines) {
					ret.add(String.valueOf(l.SBQQ__Quote__r.SBQQ__Account__c));
				}
			}
		} catch (DmlException e) {
			Logger.error('getTanTamSumAccounts', e);
			Logger.saveLog();
		}
		return ret;
	}
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	public static void nagCaseContact() {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D23R0000000093SAA';
			if (cmfields.contains('rosco_owea__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea__c'))) {
					owea = String.valueOf(cm.get('rosco_owea__c'));
				}
			}

			String cmtyUrl = 'https://support.tanium.com/s/';
			if (cmfields.contains('customer_community_url__c')) {
				if (!nullOrEmpty(String.valueOf(cm.get('customer_community_url__c')))) {
					cmtyUrl = String.valueOf(cm.get('customer_community_url__c'));
				}
			}
			Boolean testMode = true;
			if (cmfields.contains('rosco_nag_mail_test_mode__c')) {
				if (!nullOrEmpty(cm.get('rosco_nag_mail_test_mode__c'))) {
					if (cm.get('rosco_nag_mail_test_mode__c') == 'false') {
						testMode = false;
					}
				}
			}
			String rosco_nag_mail_limit_accountids = '';
			if (cmfields.contains('rosco_nag_mail_limit_accountids__c')) {
				if (!nullOrEmpty(cm.get('rosco_nag_mail_limit_accountids__c'))) {
					rosco_nag_mail_limit_accountids = String.valueOf(
						cm.get('rosco_nag_mail_limit_accountids__c')
					);
				}
			}
			String rosco_nag_mail_limit_case_count = '1';
			if (cmfields.contains('rosco_nag_mail_limit_case_count__c')) {
				if (!nullOrEmpty(cm.get('rosco_nag_mail_limit_case_count__c'))) {
					rosco_nag_mail_limit_case_count = String.valueOf(
						cm.get('rosco_nag_mail_limit_case_count__c')
					);
				}
			}
			String soql =
				'SELECT Contact.Name, Contact.Email, ContactId, Id, CaseNumber, Subject, AccountId ' +
				'FROM Case ' +
				'WHERE Support_Model__c IN (\'Support Center\',\'Hybrid\') ' +
				'AND Status = \'Pending - Clarifying\' ' +
				'AND (Last_Customer_Response_Date__c < LAST_N_DAYS:7 ' +
				'  OR Last_Customer_Response_Date__c = null) ' +
				'AND Last_Response_Date__c < LAST_N_DAYS:7 ' +
				'AND CreatedDate < LAST_N_DAYS:7 ' +
				'AND LastModifiedDate > 2022-01-01T00:00:00.000Z ' +
				'AND RecordType.Name = \'Support\' ' +
				'AND (Last_Automation_Response_Date__c < LAST_N_DAYS:7 ' +
				'    OR Last_Automation_Response_Date__c = null) ' +
				'AND (NOT Tags__c LIKE \'%NoOpenCloseEmail%\') ' +
				'AND (NOT Tags__c LIKE \'%SnoozeNag%\') ';
			if (!testMode) {
				soql +=
					'AND Id NOT IN (SELECT ParentId ' +
					'FROM EmailMessage ' +
					'WHERE Subject LIKE \'%(attention requested)\' ' +
					'AND MessageDate = LAST_N_DAYS:7) ';
			}
			if (rosco_nag_mail_limit_accountids != '') {
				soql += 'AND AccountId IN (' + rosco_nag_mail_limit_accountids + ') ';
			}
			soql += 'LIMIT ' + rosco_nag_mail_limit_case_count;
			if (Test.isRunningTest()) {
				soql =
					'SELECT Contact.Name, Contact.Email, ContactId, Id, CaseNumber, Subject ' +
					'FROM Case ' +
					'LIMIT 1';
			}
			List<Case> cases = Database.query(soql);
			if (!cases.isEmpty()) {
				List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
				for (Case c : cases) {
					String contactName = c.Contact.Name;
					String contactEmail = c.Contact.Email;
					if (testMode || Test.isRunningTest()) {
						contactEmail = 'jason.johnson@tanium.com';
					}
					List<String> to = new List<String>();
					to.add(contactEmail);
					String subject = c.CaseNumber + ':' + c.Subject + ' (attention requested)';
					String url = cmtyUrl + 'case/' + c.Id;
					String threadId = EmailMessages.getFormattedThreadingToken(c.Id);
					String textBody =
						'Hello ' +
						contactName +
						',\n\n' +
						'We wanted to make you aware that there is currently a ' +
						'Tanium case awaiting your attention. Please log into the ' +
						'Tanium customer portal here ' +
						url +
						' ' +
						'to view and respond to your case.\n\n ' +
						'Tanium Support Center\n\n ' +
						threadId;
					String htmlBody =
						'<div style="text-align:center;background-color:black;color:white;font-size:large;font-weight:bold;">' +
						'<p>Tanium Support Notification</p></div>' +
						'<p>Hello ' +
						contactName +
						',</p>' +
						'<p>We wanted to make you aware that there is currently a ' +
						'Tanium case awaiting your attention. Please log into the ' +
						'Tanium customer portal here <a href=\"' +
						url +
						'">' +
						url +
						'</a> ' +
						'to view and respond to your case.</p><p> </p>' +
						'<p>Tanium Support Center </p>' +
						'<p> </p><p>' +
						threadId +
						' </p>';

					Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
					mail.setOrgWideEmailAddressId(owea);
					mail.setToAddresses(to);
					mail.setSubject(subject);
					mail.setHtmlBody(htmlBody);
					mail.setPlainTextBody(textBody);
					mail.setUseSignature(false);
					if (!testMode) {
						mail.setWhatId(c.Id);
					}
					if (testMode) {
						mails.add(mail);
						c.Last_Automation_Response_Date__c = System.Datetime.now();
					} else if (contactEmail.containsIgnoreCase('@')) {
						if (!contactEmail.containsIgnoreCase('@tanium.com')) {
							mails.add(mail);
							c.Last_Automation_Response_Date__c = System.Datetime.now();
						}
					}
				}
				if (!Test.isRunningTest() && mails.size() > 0) {
					Messaging.sendEmail(mails);
				}
				if (!Test.isRunningTest()) {
					update cases;
				}
			}
			String emailBody = '<html><b><u>nagCaseContact() executed SOQL:</u></b><br><br>';
			emailBody += soql + '<br><br>';
			if (cases.size() == 0) {
				emailBody += '0 cases found requiring notification';
			} else {
				emailBody += '<b><u>The following cases were notified</u></b><br>';
				for (Case c : cases) {
					emailBody += c.CaseNumber + ':' + c.Subject + '<br>';
				}
			}
			sendEmail('nagCaseContact execution status', emailBody);
		} catch (DmlException e) {
			Logger.error('nagCaseContact', e);
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