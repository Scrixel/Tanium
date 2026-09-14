/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: RoscoTriage
 * @Date: 8/4/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7985    2024-05-14    Add Sub-Component Field
 * SS-9852    2025-01-24    Added app name return on init
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c and resolve issues
 * SS-10294   2026-02-13    Remove TAM_Assigned_GS__c reference	from the class
 */
public with sharing class RoscoTriage {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** getCaseInfo
	 * @param caseId - case to retrieve Case info
	 * @return Map of Case info
	 */
	@AuraEnabled
	public static Map<String, String> getCaseInfo(String caseId) {
		Map<String, String> ret = new Map<String, String>();

		try {
			if (caseId == 'newcase') {
				ret.put('subject', '');

				ret.put('contact', '');
				ret.put('account', '');
				ret.put('owner', '');
				ret.put('severity', '3');
				ret.put('status', 'New');

				ret.put('type', '');
				ret.put('component', '');
				ret.put('sub_component', '');
				ret.put('componentversion', '');
				ret.put('jira', '');
				ret.put('status_details', '');

				ret.put('tags', '');
			} else {
				Case aCase = RoscoUtility.getCaseDetails(caseId);

				ret.put('contact', String.valueOf(aCase.ContactId));
				ret.put('contactname', String.valueOf(aCase.Contact.Name));
				ret.put('contactemail', String.valueOf(aCase.Contact.Email));
				ret.put('contactaccount', String.valueOf(aCase.Contact.Account.Name));
				ret.put('ownerid', String.valueOf(aCase.OwnerId));
				ret.put('ownername', String.valueOf(aCase.Owner.Name));
				ret.put('owneremail', String.valueOf(aCase.Owner.Email));
				ret.put('subject', String.valueOf(aCase.Subject));
				ret.put('severity', String.valueOf(aCase.Severity_Community__c).left(1));
				ret.put('status', String.valueOf(aCase.Status));
				ret.put('accountid', String.valueOf(aCase.AccountId));
				ret.put('origin', String.valueOf(aCase.Origin));
				ret.put('accountname', String.valueOf(aCase.Account.Name));
				ret.put('accounttype', String.valueOf(aCase.Account.Type));
				ret.put('recordtype', String.valueOf(aCase.RecordType.Name));

				ret.put('component', String.valueOf(aCase.Component__c));
				ret.put('sub_component', String.valueOf(aCase.Sub_Component__c));
				ret.put('componentversion', String.valueOf(aCase.Component_Version__c));
				ret.put('jira', String.valueOf(aCase.JIRA_ID__c));
				ret.put('tags', String.valueOf(aCase.tags__c));

				String status_details = '--None--';
				if (aCase.Status_Details__c != null) {
					status_details = String.valueOf(aCase.Status_Details__c);
				}
				ret.put('status_details', status_details);

				String case_type = '--None--';
				if (aCase.Type != null) {
					case_type = String.valueOf(aCase.Type);
				}
				ret.put('case_type', case_type);

				// Triage Message
				String initialEmailSent = initialEmailSent(caseId);
				ret.put('initialEmailSent', initialEmailSent);
			}

			if (!Test.isRunningTest()) {
				ret.put('app_name', Utility.getAppName());
			}
		} catch (DmlException e) {
			System.debug('getCaseInfo:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		System.debug(ret);
		return ret;
	}

	/** getCaseInfoTSE
	 * @param caseId - case to retrieve Case info
	 * @return Map of Case info
	 */
	@AuraEnabled
	public static Map<String, String> getCaseInfoTSE(String caseId) {
		Map<String, String> ret = new Map<String, String>();

		try {
			if (caseId == 'newcase') {
				ret.put('subject', '');

				ret.put('contact', getSalesCaseContactId());
				ret.put('account', '');
				ret.put('owner', '');
				ret.put('severity', '3');
				ret.put('status', 'Pending - Clarifying');
				ret.put('smeteams', RoscoEscalate.getSMETeams('Support'));
				ret.put('smeteam', '');
				ret.put('pods', RoscoEscalate.getPods('Support'));
				ret.put('pod', '');

				ret.put('type', '');
				ret.put('component', 'Other');
				ret.put('componentversion', '');
				ret.put('jira', '');
				ret.put('status_details', '');

				ret.put('tags', 'NoOpenCloseEmail');
			} else {
				Case aCase = RoscoUtility.getCaseDetails(caseId);

				ret.put('contact', String.valueOf(aCase.ContactId));
				ret.put('contactname', String.valueOf(aCase.Contact.Name));
				ret.put('contactemail', String.valueOf(aCase.Contact.Email));
				ret.put('contactaccount', String.valueOf(aCase.Contact.Account.Name));
				ret.put('ownerid', String.valueOf(aCase.OwnerId));
				ret.put('ownername', String.valueOf(aCase.Owner.Name));
				ret.put('owneremail', String.valueOf(aCase.Owner.Email));
				ret.put('subject', String.valueOf(aCase.Subject));
				ret.put('severity', String.valueOf(aCase.Severity_Community__c).left(1));
				ret.put('status', String.valueOf(aCase.Status));
				ret.put('accountid', String.valueOf(aCase.AccountId));
				ret.put('accountname', String.valueOf(aCase.Account.Name));
				ret.put('accounttype', String.valueOf(aCase.Account.Type));
				ret.put('description', String.valueOf(aCase.Description));
				ret.put('component', String.valueOf(aCase.Component__c));
				ret.put('componentversion', String.valueOf(aCase.Component_Version__c));
				ret.put('jira', String.valueOf(aCase.JIRA_ID__c));
				ret.put('tags', String.valueOf(aCase.tags__c));
				ret.put('smeteam', String.valueOf(aCase.Escalation_Team__c));
				ret.put('smeteams', RoscoEscalate.getSMETeams(aCase.RecordType.Name));

				ret.put('pods', getPods());
				if (aCase.Escalation_Pod__c == null) {
					ret.put('pod', '');
				} else {
					ret.put('pod', String.valueOf(aCase.Escalation_Pod__c));
				}

				String status_detail = '--None--';
				if (aCase.Status_Details__c != null) {
					status_detail = String.valueOf(aCase.Status_Details__c);
				}
				ret.put('status_detail', status_detail);

				String case_type = '--None--';
				if (aCase.Type != null) {
					case_type = String.valueOf(aCase.Type);
				}
				ret.put('case_type', case_type);

				// Opp
				ret.put('opportunityid', '');
				ret.put('opportunityname', '');
				Id oppId = [SELECT Opportunity__c FROM Case WHERE Id = :caseId].Opportunity__c;
				if (oppId != null) {
					ret.put('opportunityid', String.valueOf(oppId));

					String name = [SELECT Name FROM Opportunity WHERE Id = :oppId].Name;
					if (name != null) {
						ret.put('opportunityname', String.valueOf(name));
					}
				}

				// Triage Message
				//String initialEmailSent = initialEmailSent(caseId);
				//ret.put('initialEmailSent',initialEmailSent);
			}
		} catch (DmlException e) {
			System.debug('getCaseInfoTSE:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		System.debug(ret);
		return ret;
	}

	/** getCaseAccountLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getCaseAccountLookup(
		String searchKeyWord,
		String caseId,
		String contactAccountId
	) {
		String accountId = '';
		if (caseId != null && caseId != '') {
			Case aCase = RoscoUtility.getCaseDetails(caseId);
			accountId = aCase.AccountId;
		}

		if (contactAccountId == null) {
			contactAccountId = '';
		}

		System.debug('searchKeyWord:' + searchKeyWord);
		System.debug('caseId:' + caseId);
		System.debug('contactAccountId:' + contactAccountId);

		// Search Keyword
		searchKeyWord = searchKeyWord.trim();

		String searchKey = '%' + searchKeyWord + '%';
		searchKey = String.escapeSingleQuotes(searchKey);

		List<Map<String, String>> returnList = new List<Map<String, String>>();
		List<Map<String, String>> returnListStartsWith = new List<Map<String, String>>();
		List<Map<String, String>> returnListContains = new List<Map<String, String>>();

		String soql;
		if (searchKeyWord == '' && contactAccountId != '') {
			soql =
				'SELECT Name,Type,Slack_Channel_Id__c FROM Account ' +
				'WHERE Id = \'' +
				contactAccountId +
				'\'';
		} else {
			soql =
				'SELECT Name, Type, Slack_Channel_Id__c ' +
				'FROM Account ' +
				'WHERE (Name LIKE \'' +
				searchKey +
				'\') ' +
				'ORDER BY Name ASC LIMIT 1000';
		}

		System.debug('soql:' + soql);
		List<Account> accounts = Database.query(soql);
		System.debug('accounts:' + accounts);
		if (!accounts.isEmpty()) {
			Integer count = 0;
			for (Account a : accounts) {
				System.debug('a:' + a);

				Map<String, String> customer = new Map<String, String>();
				String aid = String.valueOf(a.get('Id'));
				String name = String.valueOf(a.get('Name'));
				String atype = String.valueOf(a.get('Type'));

				String hasslack = 'false';
				if (a.get('Slack_Channel_Id__c') != null) {
					if (a.get('Slack_Channel_Id__c') != '') {
						hasslack = 'true';
					}
				}

				System.debug('aid:' + aid);
				System.debug('name:' + name);
				System.debug('atype:' + atype);
				System.debug('hasslack:' + hasslack);

				customer.put('Id', aid);
				customer.put('hasslack', hasslack);
				customer.put('Description', name + ' (' + atype + ')');

				if (name.containsIgnoreCase('Customer Community External Members Account')) {
					System.debug('Filtering out community external members account...');
				} else if (name.startsWithIgnoreCase(searchKeyWord)) {
					returnListStartsWith.add(customer);
				} else {
					if (count < 10) {
						returnListContains.add(customer);
						count += 1;
					}
				}
			}
		}

		// Lets sort list by name
		//returnList = RoscoUtility.sortListMapName( returnList );
		returnList.addAll(returnListStartsWith);
		returnList.addAll(returnListContains);

		return returnList;
	}

	/** getCaseAccountLookupSales - used by lightning component to readahead
	 * @param search - read ahead value
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getCaseAccountLookupSales(
		String searchKeyWord,
		String caseId,
		String oppId
	) {
		System.debug('searchKeyWord:' + searchKeyWord);
		System.debug('caseId:' + caseId);
		System.debug('oppId:' + oppId);

		// Search Keyword
		searchKeyWord = searchKeyWord.trim();

		String searchKey = '%' + searchKeyWord + '%';

		List<Map<String, String>> returnList = new List<Map<String, String>>();
		List<Map<String, String>> returnListStartsWith = new List<Map<String, String>>();
		List<Map<String, String>> returnListContains = new List<Map<String, String>>();

		String soql;
		if (oppId != '') {
			soql =
				'SELECT Id, Name, Type ' +
				'FROM Account ' +
				'WHERE Id IN (SELECT AccountId ' +
				'FROM Opportunity ' +
				'WHERE Id = \'' +
				oppId +
				'\')';
		} else if (searchKeyWord == '') {
			String currentuser = UserInfo.getUserId();
			soql =
				'SELECT Id, Name, Type ' +
				'FROM Account ' +
				'WHERE Id IN (SELECT AccountId ' +
				'FROM Opportunity ' +
				'WHERE StageName != \'Failed\' AND StageName != \'CLOSED WON\' ' +
				'AND (TAM_Sales_SME_Owner__c = \'' +
				currentuser +
				'\') ' +
				'ORDER BY Account.Name DESC LIMIT 20';
		} else {
			soql =
				'SELECT Id, Name, Type ' +
				'FROM Account ' +
				'WHERE Name LIKE \'' +
				searchKey +
				'\' ' +
				//'AND Id IN (SELECT AccountId ' +
				//    'FROM Opportunity ' +
				//    'WHERE StageName != \'Failed\' AND StageName != \'CLOSED WON\') ' +
				'ORDER BY Account.Name DESC LIMIT 1000';
		}

		System.debug('soql:' + soql);
		List<Account> accounts = Database.query(soql);
		System.debug('accounts:' + accounts);
		if (!accounts.isEmpty()) {
			for (Account a : accounts) {
				System.debug('a:' + a);

				Map<String, String> customer = new Map<String, String>();
				String aid = String.valueOf(a.get('Id'));
				String name = String.valueOf(a.get('Name'));
				String atype = String.valueOf(a.get('Type'));

				System.debug('aid:' + aid);
				System.debug('name:' + name);
				System.debug('atype:' + atype);

				customer.put('Id', aid);
				if (atype == '' || atype == null) {
					customer.put('Description', name);
				} else {
					customer.put('Description', name + ' (' + atype + ')');
				}

				if (name.containsIgnoreCase('Customer Community External Members Account')) {
					System.debug('Filtering out community external members account...');
				} else if (name.startsWithIgnoreCase(searchKeyWord)) {
					returnListStartsWith.add(customer);
				} else {
					returnListContains.add(customer);
				}
			}
		}

		// Lets sort list by name
		//returnList = RoscoUtility.sortListMapName( returnList );
		returnList.addAll(returnListStartsWith);
		returnList.addAll(returnListContains);

		return returnList;
	}

	/** getPicklistValuesCaseComponent
	 * return  Case Status picklist values
	 */
	@AuraEnabled
	public static Map<String, Object> getPicklistValuesCaseComponent() {
		Map<String, Object> ret = new Map<String, Object>();
		List<Map<String, String>> components = new List<Map<String, String>>();

		Schema.DescribeFieldResult fieldResult = Case.Component__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for (Schema.PicklistEntry f : ple) {
			if (f.getLabel() != 'Other: Product not listed') {
				Map<String, String> p = new Map<String, String>();
				p.put('label', f.getLabel());
				p.put('value', f.getLabel());
				components.add(p);
			}
		}
		Map<String, String> o = new Map<String, String>();
		o.put('label', 'Other: Product not listed');
		o.put('value', 'Other: Product not listed');
		components.add(o);
		ret.put('components', components);

		Map<String, List<String>> subComponents = Utility.getDependentPicklistValues(
			'Case',
			'Component__c',
			'Sub_Component__c'
		);
		ret.put('sub_components_map', subComponents);

		return ret;
	}

	/** getPods
	 * @return comma separated list of Pods
	 */
	public static String getPods() {
		String ret = '';

		try {
			/*               
            // Get Escalation Level Information
            String soql = 'SELECT Name' +
                    ' FROM TAM_Team__c' +
                    ' WHERE Type__c = \'Pod\' ' +
                    ' AND Slack_Escalation_Channel_ID__c != null ' +
                    ' ORDER BY Name ASC NULLS LAST';

            List<TAM_Team__c> aTeams = Database.query(soql);

            if ( aTeams.size() != 0 ) {

                for( TAM_Team__c aTeam : aTeams ){
                    if( ret == '' ){
                        ret = aTeam.Name;
                    } else {
                        ret = ret + ',' + aTeam.Name;
                    }
                }
            }
            */
			ret = 'Asia North,Asia South,DACH,East,EMEA North,EMEA South,Federal,West';
		} catch (DmlException e) {
			System.debug('getPods:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getCaseContactLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getCaseContactLookup(
		String searchKeyWord,
		String caseId,
		String accountId
	) {
		// Get accountid from caseId
		System.debug('searchKeyWord:' + searchKeyWord);
		System.debug('caseId:' + caseId);
		System.debug('accountId:' + accountId);

		if (caseId != null && caseId != '') {
			if (accountId == null || accountId == '') {
				Case aCase = RoscoUtility.getCaseDetails(caseId);
				accountId = aCase.AccountId;
			}
		}

		List<String> acrRelationship = new List<String>();
		if (accountId != null && accountId != '') {
			// Get a list of related contacts for account

			String rsoql =
				'SELECT ContactId FROM AccountContactRelation WHERE AccountId = \'' +
				accountId +
				'\'';
			List<AccountContactRelation> acrs = Database.query(rsoql);
			if (!acrs.isEmpty()) {
				for (AccountContactRelation acr : acrs) {
					acrRelationship.add(String.valueOf(acr.ContactId));
				}
			}
		}

		// Search Keyword
		searchKeyWord = searchKeyWord.trim();

		String searchKey = '%' + searchKeyWord + '%';
		String taniumemail = '%tanium.com';

		List<Map<String, String>> returnList = new List<Map<String, String>>();

		String soql;
		if (searchKeyWord == '' && accountId != '') {
			soql =
				'SELECT Id,Name,Email,AccountId,Title,Account.Name FROM Contact ' +
				'WHERE Id IN (SELECT ContactId FROM AccountContactRelation WHERE AccountId = \'' +
				accountId +
				'\') ' +
				'AND Id IN (SELECT ContactId FROM CaseContactRole) ' +
				'AND (NOT Email LIKE \'' +
				taniumemail +
				'\') ' +
				'ORDER BY Name DESC LIMIT 10';
		} else {
			soql =
				'SELECT Id,Name,Email,AccountId,Title,Account.Name ' +
				'FROM Contact ' +
				'WHERE (Name LIKE \'' +
				searchKey +
				'\' ' +
				'OR Email LIKE \'' +
				searchKey +
				'\') ' +
				'ORDER BY Name DESC LIMIT 10';
		}

		System.debug('soql:' + soql);
		List<Contact> contacts = Database.query(soql);
		System.debug('contacts:' + contacts);
		if (!contacts.isEmpty()) {
			for (Contact c : contacts) {
				System.debug('c:' + c);

				Map<String, String> people = new Map<String, String>();
				String cid = String.valueOf(c.get('Id'));
				String aid = String.valueOf(c.get('AccountId'));
				String name = String.valueOf(c.get('Name'));
				String email = String.valueOf(c.get('Email'));
				String account = String.valueOf(c.Account.Name);

				System.debug('id:' + cid);
				System.debug('name:' + name);
				System.debug('email:' + email);
				System.debug('account:' + account);
				System.debug('accountId:' + aid);

				if (email != null) {
					if (email.contains('@')) {
						//if ( email.contains( '@tanium.com' )){
						//    System.debug('Filtering out tanium contact...');
						//} else {
						people.put('Id', cid);
						people.put('AccountId', aid);
						people.put('Email', email);
						people.put('Description', name + ' (' + email + ') at ' + account);
						returnList.add(people);
						//}
					}
				}
			}
		}

		// Lets sort list by name
		//returnList = RoscoUtility.sortListMapName( returnList );
		return returnList;
	}

	/** getCaseOwnerLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getCaseOwnerLookup(
		String searchKeyWord,
		String caseId,
		String accountId
	) {
		List<Map<String, String>> returnList = new List<Map<String, String>>();

		if (searchKeyWord == null) {
			searchKeyWord = '';
		}

		// Get accountid from caseId
		System.debug('searchKeyWord:' + searchKeyWord);
		System.debug('caseId:' + caseId);
		System.debug('accountId:' + accountId);

		if (caseId != null && caseId != '') {
			if (accountId == null || accountId == '') {
				Case aCase = RoscoUtility.getCaseDetails(caseId);
				accountId = aCase.AccountId;
			}
		}

		// Add Support Center Queue to top of listte
		List<Account> scAcct = [
			SELECT Id
			FROM Account
			WHERE Id = :accountId AND Support_Model__c IN ('Hybrid', 'Support Center')
		];
		if (!scAcct.isEmpty() || searchKeyWord != 'newcaseinit') {
			QueueSobject supportQ = [
				SELECT QueueId, Queue.Name
				FROM QueueSobject
				WHERE Queue.Name = 'Support Center'
			];
			System.debug(supportQ);

			Map<String, String> people = new Map<String, String>();
			people.put('Id', String.valueOf(supportQ.QueueId));
			people.put('Description', 'Support Center Queue');
			people.put('Email', getSupportCenterEmail());
			if (searchKeyWord == '') {
				returnList.add(people);
			} else if (supportQ.Queue.Name.containsIgnoreCase(searchKeyWord)) {
				returnList.add(people);
			}

			if (isUserMgr() || isSupportTAM()) {
				// Get org wide sender id
				Case_Management__c cm = Case_Management__c.getInstance();
				Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
				String channels = '';
				if (cmfields.contains('rosco_sc_queues__c')) {
					if (!nullOrEmpty(cm.get('rosco_sc_queues__c'))) {
						channels = String.valueOf(cm.get('rosco_sc_queues__c'));
					}
				}
				System.debug('channels:' + channels);

				if (channels != '') {
					String soql =
						'SELECT QueueId, Queue.Name ' +
						'FROM QueueSobject ' +
						'WHERE QueueId IN (' +
						channels +
						')';

					System.debug('soql:' + soql);

					List<QueueSobject> queues = Database.query(soql);
					for (QueueSobject q : queues) {
						Map<String, String> omniPeople = new Map<String, String>();
						omniPeople.put('Id', String.valueOf(q.QueueId));
						omniPeople.put('Description', String.valueOf(q.Queue.Name));
						omniPeople.put('Email', getSupportCenterEmail());

						if (searchKeyWord == '') {
							returnList.add(omniPeople);
						} else if (q.Queue.Name.containsIgnoreCase(searchKeyWord)) {
							returnList.add(omniPeople);
						}
					}
				}
			}
		}

		// Search Keyword
		searchKeyWord = searchKeyWord.trim();

		String searchKey = '%' + searchKeyWord + '%';
		String taniumemail = '%tanium.com';

		String soql;
		if (searchKeyWord == 'newcaseinit') {
			User uLoggedIn = [SELECT Id, Email, Name FROM User WHERE Id = :UserInfo.getUserId()];
			Map<String, String> loggedInpeople = new Map<String, String>();
			loggedInpeople.put('Id', String.valueOf(uLoggedIn.Id));
			loggedInpeople.put('Description', uLoggedIn.Name);
			loggedInpeople.put('Email', uLoggedIn.Email);
			returnList.add(loggedInpeople);
		} else if (searchKeyWord == '' && accountId != '') {
			String stam = null;

			String inClause;
			if (stam != null) {
				inClause = '\'' + stam + '\'';
				soql =
					'SELECT Name, Email ' +
					'FROM User ' +
					'WHERE ID IN (' +
					inClause +
					')' +
					'ORDER BY Name DESC LIMIT 10';
			}
		}

		if (soql == null) {
			soql =
				'SELECT Name, Email ' +
				'FROM User ' +
				'WHERE (Name LIKE \'' +
				searchKey +
				'\' ' +
				'OR Email LIKE \'' +
				searchKey +
				'\') ' +
				'AND Email LIKE \'' +
				taniumemail +
				'\' ' +
				'AND (NOT Profile.Name LIKE \'%Community%\') ' +
				'AND IsActive = true ' +
				'ORDER BY Name DESC LIMIT 10';
		}

		System.debug('soql:' + soql);
		List<User> users = Database.query(soql);
		System.debug('users:' + users);
		if (!users.isEmpty()) {
			for (User u : users) {
				System.debug('u:' + u);

				Map<String, String> people = new Map<String, String>();
				String uid = String.valueOf(u.get('Id'));
				String name = String.valueOf(u.get('Name'));
				String email = String.valueOf(u.get('Email'));

				System.debug('id:' + uid);
				System.debug('name:' + name);
				System.debug('email:' + email);

				if (email != null) {
					if (email.contains('@')) {
						people.put('Id', uid);
						people.put('Description', name + ' (' + email + ')');
						people.put('Email', email);
					}
					returnList.add(people);
				}
			}
		}

		// Lets sort list by name
		//returnList = RoscoUtility.sortListMapName( returnList );
		return returnList;
	}

	/** getCasePreferredTAMLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getCasePreferredTAMLookup(
		String searchKeyWord,
		String caseId,
		String accountId,
		String oppId
	) {
		List<Map<String, String>> returnList = new List<Map<String, String>>();

		if (searchKeyWord == null) {
			searchKeyWord = '';
		}

		// Get accountid from caseId
		System.debug('searchKeyWord:' + searchKeyWord);
		System.debug('caseId:' + caseId);
		System.debug('accountId:' + accountId);

		if (caseId != null && caseId != '') {
			if (accountId == null || accountId == '') {
				Case aCase = RoscoUtility.getCaseDetails(caseId);
				accountId = aCase.AccountId;
			}
		}

		// Add Support Center Queue to top of listte
		List<Account> scAcct = [
			SELECT Id
			FROM Account
			WHERE Id = :accountId AND Support_Model__c = 'Support Center'
		];
		if (!scAcct.isEmpty()) {
			QueueSobject supportQ = [
				SELECT QueueId
				FROM QueueSobject
				WHERE Queue.Name = 'Support Center'
			];
			System.debug(supportQ);

			Map<String, String> people = new Map<String, String>();
			people.put('Id', String.valueOf(supportQ.QueueId));
			people.put('Description', 'Support Center Queue');
			people.put('Email', getSupportCenterEmail());
			returnList.add(people);
		}

		// Search Keyword
		searchKeyWord = searchKeyWord.trim();

		String searchKey = '%' + searchKeyWord + '%';
		String taniumemail = '%tanium.com';

		String soql;
		if (searchKeyWord == 'newcaseinit') {
			String currentuser = UserInfo.getUserId();
			soql = 'SELECT Name, Email ' + 'FROM User ' + 'WHERE ID = \'' + currentuser + '\'';
		} else if (searchKeyWord == '' && accountId != '') {
			String stam = null;

			String inClause;
			if (stam != null) {
				inClause = '\'' + stam + '\'';
				soql =
					'SELECT Name, Email ' +
					'FROM User ' +
					'WHERE ID IN (' +
					inClause +
					')' +
					'ORDER BY Name DESC LIMIT 10';
			}
		}

		if (soql == null) {
			soql =
				'SELECT Name, Email ' +
				'FROM User ' +
				'WHERE (Name LIKE \'' +
				searchKey +
				'\' ' +
				'OR Email LIKE \'' +
				searchKey +
				'\') ' +
				'AND Email LIKE \'' +
				taniumemail +
				'\' ' +
				'ORDER BY Name DESC LIMIT 10';
		}

		System.debug('soql:' + soql);
		List<User> users = Database.query(soql);
		System.debug('users:' + users);
		if (!users.isEmpty()) {
			for (User u : users) {
				System.debug('u:' + u);

				Map<String, String> people = new Map<String, String>();
				String uid = String.valueOf(u.get('Id'));
				String name = String.valueOf(u.get('Name'));
				String email = String.valueOf(u.get('Email'));

				System.debug('id:' + uid);
				System.debug('name:' + name);
				System.debug('email:' + email);

				if (email != null) {
					if (email.contains('@')) {
						people.put('Id', uid);
						people.put('Description', name + ' (' + email + ')');
						people.put('Email', email);
					}
					returnList.add(people);
				}
			}
		}

		// Lets sort list by name
		//returnList = RoscoUtility.sortListMapName( returnList );
		return returnList;
	}

	/** getCaseOppLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getCaseOppLookup(
		String searchKeyWord,
		String caseId,
		String accountId
	) {
		// Get accountid from caseId
		System.debug('searchKeyWord:' + searchKeyWord);
		System.debug('caseId:' + caseId);
		System.debug('accountId:' + accountId);

		if (caseId != null && caseId != '') {
			if (accountId == null || accountId == '') {
				Case aCase = RoscoUtility.getCaseDetails(caseId);
				accountId = aCase.AccountId;
			}
		}

		// Search Keyword
		searchKeyWord = searchKeyWord.trim();

		String searchKey = '%' + searchKeyWord + '%';

		List<Map<String, String>> returnList = new List<Map<String, String>>();

		String soql;
		if (searchKeyWord == '' && accountId != '') {
			soql =
				'SELECT Id,Name,Account.Name, Account.Type FROM Opportunity ' +
				'WHERE AccountId = \'' +
				accountId +
				'\' ' +
				'AND StageName NOT IN (\'Failed\',\'CLOSED WON\',\'POC\') ' +
				'ORDER BY Name DESC LIMIT 20';
		} else {
			if (accountId == '') {
				soql =
					'SELECT Id,Name,Account.Name, Account.Type FROM Opportunity ' +
					'WHERE (Name LIKE \'' +
					searchKey +
					'\') ' +
					'AND StageName NOT IN (\'Failed\',\'CLOSED WON\',\'POC\') ' +
					'ORDER BY Name DESC LIMIT 20';
			} else {
				soql =
					'SELECT Id,Name,Account.Name, Account.Type FROM Opportunity ' +
					'WHERE AccountId = \'' +
					accountId +
					'\' ' +
					'AND (Name LIKE \'' +
					searchKey +
					'\') ' +
					'AND StageName NOT IN (\'Failed\',\'CLOSED WON\',\'POC\') ' +
					'ORDER BY Name DESC LIMIT 20';
			}
		}

		System.debug('soql:' + soql);
		List<Opportunity> opps = Database.query(soql);
		System.debug('opps:' + opps);
		if (!opps.isEmpty()) {
			for (Opportunity o : opps) {
				System.debug('o:' + o);

				Map<String, String> opp = new Map<String, String>();
				String oid = String.valueOf(o.get('Id'));
				String aid = String.valueOf(o.get('AccountId'));
				String name = String.valueOf(o.get('Name'));

				String accountName = String.valueOf(o.Account.Name);
				String accountType = String.valueOf(o.Account.Type);

				System.debug('id:' + oid);
				System.debug('name:' + name);
				System.debug('account:' + accountName);
				System.debug('accountId:' + aid);

				opp.put('Id', oid);
				opp.put('AccountId', aid);
				opp.put('Description', name + ' at ' + accountName);
				if (accountType == '' || accountType == null) {
					opp.put('accountDescription', accountName);
				} else {
					opp.put('accountDescription', accountName + ' (' + accountType + ')');
				}
				returnList.add(opp);
			}
		}

		// Lets sort list by name
		//returnList = RoscoUtility.sortListMapName( returnList );
		return returnList;
	}

	/** getSalesCaseContactId
	 * @return
	 */
	public static String getSalesCaseContactId() {
		String ret = '0030e00002Ln3ZHAAZ';

		try {
			String soql = 'SELECT Id FROM Contact ' + 'WHERE Email = \'soa@tanium.com\'';

			System.debug('SOQL: ' + soql);
			List<Contact> contacts = Database.query(soql);

			if (contacts.size() != 0) {
				ret = String.valueOf(contacts[0].Id);
			}
		} catch (DmlException e) {
			System.debug('getSalesCaseContactId:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** getSuportCenterEmail
	 * @return
	 */
	public static String getSupportCenterEmail() {
		String ret = 'support-center@tanium.com';

		try {
			// Get org wide sender id
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D260000000XZFgCAO';
			if (cmfields.contains('rosco_sc_email__c')) {
				if (!nullOrEmpty(cm.get('rosco_sc_email__c'))) {
					ret = String.valueOf(cm.get('rosco_sc_email__c'));
				}
			}
			System.debug('owea:' + owea);
		} catch (DmlException e) {
			System.debug('getSupportCenterEmail:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** initialEmailSent - used to determine if initial email sent
	 * @param @caseid - case id used to lookup account
	 *
	 * @return String of curent initial triage status
	 */
	@AuraEnabled
	public static String initialEmailSent(String caseId) {
		String ret = 'false';

		try {
			Case aCase = RoscoUtility.getCaseDetails(caseId);

			if (aCase.Origin == 'Console') {
				ret = 'true';
			} else {
				String created = aCase.CreatedDate.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

				// Check Email
				Boolean customerEmail = false;
				String soql =
					'SELECT FromAddress,ToAddress FROM EmailMessage ' +
					'WHERE ParentId = \'' +
					caseId +
					'\' ' +
					'AND IsPrivateDraft = false ' +
					'AND CreatedDate > ' +
					created;

				List<EmailMessage> emails = Database.query(soql);
				if (!emails.isEmpty()) {
					String both = '';
					for (EmailMessage e : emails) {
						if (e.FromAddress == 'support@tanium.com') {
							if (e.ToAddress != null) {
								// To address should always have multiple people if Service console used
								if (e.ToAddress.contains(';')) {
									List<String> To = e.ToAddress.split(';');
									for (String t : To) {
										if (t.contains('@tanium.com')) {
											//pass
										} else {
											ret = 'true';
										}
									}
								}
							}
						}
					}
				}
			}
		} catch (Exception e) {
			System.debug('initialEmailSent: ' + e.getMessage() + '\n' + e.getStackTraceString());
			return ret;
		}
		return ret;
	}

	/** isSupportTAM
	 */
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

			System.debug('SOQL: ' + soql);
			List<UserRole> rs = Database.query(soql);

			if (rs.size() != 0) {
				ret = true;
			}
		} catch (Exception e) {
			System.debug('isSupportTAM: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** isUserMgr
	 */
	public static Boolean isUserMgr() {
		Boolean ret = false;

		try {
			String soql = 'SELECT Id ' + 'FROM PermissionSet ' + 'WHERE Name = \'Support_Management\'';

			System.debug('SOQL: ' + soql);
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

				System.debug('SOQL2: ' + soql2);
				List<PermissionSetAssignment> assignments = Database.query(soql2);

				if (assignments.size() != 0) {
					ret = true;
				}
			}
		} catch (Exception e) {
			System.debug('isUserMgr: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** saveCase
	 * @param caseId - case to retrieve Case info
	 * @return Map of Case info
	 */
	@AuraEnabled
	public static String saveCase(Map<String, Object> caseinfo) {
		String ret;

		System.debug('caseinfo:' + caseinfo);

		try {
			String caseId = String.valueOf(caseinfo.get('caseId'));
			System.debug('Updating ' + caseId);

			Case c = [
				SELECT
					ContactId,
					AccountId,
					Severity_Community__c,
					Component_Version__c,
					Component__c,
					Sub_Component__c,
					OwnerId,
					Status,
					Type
				FROM Case
				WHERE Id = :caseid
				LIMIT 1
			];

			c.AccountId = String.valueOf(caseinfo.get('accountId'));
			c.Component_Version__c = String.valueOf(caseinfo.get('componentversion'));
			c.Component__c = String.valueOf(caseinfo.get('case_component'));
			c.Sub_Component__c = String.valueOf(caseinfo.get('case_sub_component'));
			c.ContactId = String.valueOf(caseinfo.get('contactId'));
			c.JIRA_ID__c = String.valueOf(caseinfo.get('jira'));
			c.OwnerId = String.valueOf(caseinfo.get('ownerId'));
			c.Severity_Community__c = String.valueOf(caseinfo.get('severity'));
			c.Status = String.valueOf(caseinfo.get('status'));
			if (String.valueOf(caseinfo.get('status_details')) == '--None--') {
				c.Status_Details__c = '';
			} else {
				c.Status_Details__c = String.valueOf(caseinfo.get('status_details'));
			}

			c.Subject = String.valueOf(caseinfo.get('subject'));
			c.tags__c = String.valueOf(caseinfo.get('tags'));
			c.Type = String.valueOf(caseinfo.get('case_type'));
			System.debug(c);

			update c;

			string ccrstring = RoscoCaseContactRole.getCCRString(caseId);
			RoscoCaseContactRole.setCcrViaString(ccrstring, caseId);
		} catch (DmlException e) {
			System.debug('saveCase:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	/** saveCaseTSE
	 * @param caseId - case to retrieve Case info
	 * @return Map of Case info
	 */
	@AuraEnabled
	public static String saveCaseTSE2(Map<String, Object> caseinfo) {
		String ret;

		System.debug('caseinfo:' + caseinfo);

		try {
			for (String k : caseinfo.keyset()) {
				System.debug(k + ':' + caseinfo.get(k));
			}

			String caseId = String.valueOf(caseinfo.get('caseId'));
			System.debug('Updating ' + caseId);

			Case c = [
				SELECT
					ContactId,
					AccountId,
					Severity_Community__c,
					Component_Version__c,
					Component__c,
					OwnerId,
					Status,
					Type
				FROM Case
				WHERE Id = :caseid
				LIMIT 1
			];

			String escteam = null;
			String escTier = null;
			String escReason = null;
			if (caseinfo.get('escteam') != null) {
				escteam = String.valueOf(caseinfo.get('escteam'));
				escTier = 'Level 2';
				escReason = String.valueOf(caseinfo.get('description'));
				escReason = escReason.stripHtmlTags();
			}

			c.AccountId = String.valueOf(caseinfo.get('accountId'));
			c.OwnerId = String.valueOf(caseinfo.get('ownerId'));
			if (!nullOrEmpty(String.valueOf(caseinfo.get('opportunity')))) {
				c.Opportunity__c = String.valueOf(caseinfo.get('opportunity'));
			}
			c.Escalation_Team__c = escteam;
			c.Description = String.valueOf(caseinfo.get('description'));
			c.Subject = String.valueOf(caseinfo.get('subject'));
			c.Type = String.valueOf(caseinfo.get('case_type'));
			c.Escalation_Team__c = escteam;
			c.Escalation_Tier__c = escTier;
			c.Escalation_Reason__c = escReason;
			c.Escalation_Pod__c = String.valueOf(caseinfo.get('pod'));

			c.Status = String.valueOf(caseinfo.get('status'));
			if (String.valueOf(caseinfo.get('status_details')) == '--None--') {
				c.Status_Details__c = '';
			} else {
				c.Status_Details__c = String.valueOf(caseinfo.get('status_details'));
			}

			String sev = String.valueOf(caseinfo.get('severity'));
			if (!nullOrEmpty(sev)) {
				c.Severity_Community__c = sev;
			}

			System.debug(c);

			update c;

			String description = '';
			if (caseinfo.get('description') != null) {
				description = String.valueOf(caseinfo.get('description'));
				description = '<p>' + description.replaceAll('\n', '<p>&nbsp;</p>') + '</p>';
			}

			String casePost =
				'<p><b>Description1:</b></p> <p>&nbsp;</p> Foo' +
				description +
				'<p></p><p>&nbsp;</p>';
			casePost +=
				'<p><b>Type:</b> ' +
				String.valueOf(caseinfo.get('case_type')) +
				'</p><p></p><p>&nbsp;</p>';

			if (!nullOrEmpty(String.valueOf(caseinfo.get('preferredTAMEmail')))) {
				casePost +=
					'<p><b>Preferred TAM:</b> ' +
					String.valueOf(caseinfo.get('preferredTAMEmail')) +
					'</p><p></p><p>&nbsp;</p>';
			} else {
				//casePost += '<p><b>Preferred TAM:</b> N/A</p><p></p><p>&nbsp;</p>';
			}

			if (!nullOrEmpty(String.valueOf(caseinfo.get('escteam')))) {
				casePost +=
					'<p><b>SME Team:</b> ' +
					String.valueOf(caseinfo.get('escteam')) +
					'</p><p></p><p>&nbsp;</p>';
			} else {
				//casePost += '<p><b>SME Team:</b> N/A</p><p></p><p>&nbsp;</p>';
			}

			if (!nullOrEmpty(String.valueOf(caseinfo.get('pod')))) {
				casePost +=
					'<p><b>Pod:</b> ' +
					String.valueOf(caseinfo.get('pod')) +
					'</p><p></p><p>&nbsp;</p>';
			} else {
				//casePost += '<p><b>Pod:</b> N/A</p><p></p><p>&nbsp;</p>';
			}

			if (!nullOrEmpty(String.valueOf(caseinfo.get('optionalTime')))) {
				casePost +=
					'<p><b>Meeting Time:</b> ' +
					String.valueOf(caseinfo.get('optionalTime')) +
					'</p><p></p><p>&nbsp;</p>';
			} else {
				//casePost += '<p><b>Meeting Time:</b> N/A</p><p></p><p>&nbsp;</p>';
			}

			if (String.valueOf(caseinfo.get('boolTriage')) != 'true') {
				FeedItem fi = new FeedItem(
					Body = casePost,
					IsRichText = true,
					NetworkScope = 'AllNetworks',
					Type = 'TextPost',
					Visibility = 'InternalUsers',
					ParentId = caseId
				);
				insert fi;
			}
		} catch (DmlException e) {
			System.debug('saveCaseTSE2:' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}
}