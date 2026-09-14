/*
 * Copyright (c) 2026 Tanium
 *
 * @DATE: 2020-05-12
 * @AUTHOR: Shared Services (jason.johnson), Tanium Dev Team
 * @REQUEST:
 * @BUSINESS: Controller for roscoHomePageAccounts.
 * RequestId  ModifiedDate  Description
 * SS-7175    2024-02-20    Modified method getAcct, layout cleanup
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-10294   2026-02-12    Remove TAM_Assigned_GS__c and TAM_Secondary_GS__c reference	from the class
 * SS-13276   2026-05-19    Remove TAM_Owner_GS__c reference from the class
 * SS-13497   2026-07-07    Remove deprecated fields for project kondo group 2
 */
public with sharing class RoscoHomePage {
	/** addToObj
	 *
	 */
	private static Map<String, String> addToObj(Map<String, String> obj, String key, String val) {
		if (nullOrEmpty(val)) {
			obj.put(key, 'None');
		} else {
			obj.put(key, val);
		}
		return obj;
	}

	/** initRoscoHomePageAccounts
	 * @return Map of accounts to select from
	 */
	@AuraEnabled
	public static Map<String, String> initRoscoHomePageAccounts() {
		Map<String, String> ret = new Map<String, String>();

		try {
			UserRole uRole = [SELECT Name FROM UserRole WHERE Id = :UserInfo.getUserRoleId() LIMIT 1];
			if (String.valueOf(uRole.Name).containsIgnoreCase('TSE')) {
				ret.put('TSE', 'true');
			} else {
				ret.put('TSE', 'false');
			}

			if (getUserProfileName() == 'Customer Engagement') {
				ret.put('CE', 'true');
			} else {
				ret.put('CE', 'false');
			}
		} catch (DmlException e) {
		}
		return ret;
	}

	@AuraEnabled
	public static List<Object> getAcct() {
		List<Object> ret = new List<Object>();

		String userId = UserInfo.getUserId();

		Boolean isTSE = false;
		if (Test.isRunningTest()) {
			isTSE = true;
		}
		if (String.valueOf(getUserRole()).containsIgnoreCase('TSE')) {
			isTSE = true;
		}

		String soql =
			'SELECT Name,Id,RecordType.Name ' +
			'FROM Account ' +
			'WHERE Name = \'Tanium TAM Organization\' ' +
			'OR ( TAM_Sales_SME__c = \'' +
			userId +
			'\') ' +
			'OR ( P_TSE_Secondary__c = \'' +
			userId +
			'\') ' +
			'OR ( P_TSE_Account_Owner__c = \'' +
			userId +
			'\') ';

		List<Account> accounts = Database.query(soql);

		if (accounts.size() != 0) {
			for (Account a : accounts) {
				Map<String, Object> obj = new Map<String, Object>();
				obj.put('Name', a.Name);
				obj.put('Id', a.Id);

				if (isTSE) {
					if (String.valueOf(a.RecordType.Name) == 'Partner') {
						ret.add(obj);
					}
				} else {
					ret.add(obj);
				}
			}
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getAssociatedObjects(String jsonParam) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Map<String, Object> objParam = (Map<String, Object>) JSON.deserializeUntyped(jsonParam);
		String daysBack = String.valueOf(objParam.get('startIteration'));
		Map<String, Map<String, String>> entries = getAssociatedObjectsLabor(daysBack);
		Map<String, Map<String, String>> owners = getAssociatedObjectsCaseOwner();
		Map<String, Map<String, String>> ccs = getAssociatedObjectsCaseCc('');
		Map<String, Map<String, String>> posts = getAssociatedObjectsCasePost(daysBack);
		Map<String, Map<String, String>> comments = getAssociatedObjectsCaseComment(daysBack);
		Map<String, Map<String, String>> emails = getAssociatedObjectsCaseEmail(daysBack);
		Map<String, Map<String, String>> opportunityOwners = getAssociatedObjectsOpportunityOwner();
		Map<String, Map<String, String>> accountOwners = getAssociatedObjectsAccountOwner();
		Set<String> cid = new Set<String>();
		cid.addAll(entries.keySet());
		cid.addAll(owners.keySet());
		cid.addAll(ccs.keySet());
		cid.addAll(posts.keySet());
		cid.addAll(comments.keySet());
		cid.addAll(emails.keySet());
		cid.addAll(opportunityOwners.keySet());
		cid.addAll(accountOwners.keySet());
		Map<String, Decimal> entriesTotalTally = getAssociatedObjectsLaborTotalTally(cid);
		Map<String, String> selectFields = getCaseSelectFields(null);
		String soql =
			'SELECT ' +
			String.join(new List<String>(selectFields.keySet()), ',') +
			' FROM Case ' +
			'WHERE Id IN :cid ';

		List<Case> cases = Database.query(soql);
		for (Case c : cases) {
			Map<String, String> m = new Map<String, String>();
			m.put('Item Type', 'Case');
			for (String key : selectFields.keySet()) {
				List<String> keyList = key.split('[.]');
				String val = 'None';
				try {
					if (keyList.size() == 1) {
						val = String.valueOf(c.get(keyList[0]));
					} else if (keyList.size() == 2) {
						val = String.valueOf(c.getSObject(keyList[0]).get(keyList[1]));
					} else if (keyList.size() == 3) {
						val = String.valueOf(
							c.getSObject(keyList[0]).getSObject(keyList[1]).get(keyList[2])
						);
					}
				} catch (Exception e) {
				} finally {
					if (nullOrEmpty(val)) {
						m.put(selectFields.get(key), 'None');
					} else {
						m.put(selectFields.get(key), val);
					}
				}
			}

			if (entries.containsKey(c.Id)) {
				m.putAll(entries.get(c.Id));
				m.put('I\'ve Logged Labor Recently', 'true');
			} else {
				m.put('I\'ve Logged Labor Recently', 'false');
			}
			if (entriesTotalTally.containsKey(c.Id)) {
				m.put('Labor Tally (all time)', String.valueOf(entriesTotalTally.get(c.Id)));
			}

			if (emails.containsKey(c.Id)) {
				m.put('I\'ve emailed within case case recently', 'true');
			} else {
				m.put('I\'ve emailed within case recently', 'false');
			}

			if (owners.containsKey(c.Id)) {
				m.put('I\'m the owner', 'true');
			} else {
				m.put('I\'m the owner', 'false');
			}

			if (ccs.containsKey(c.Id)) {
				m.put('I\'m on the Case Cc', 'true');
				Map<String, String> cc = ccs.get(c.Id);
				if (cc.get('isEngagedSME') == 'true') {
					m.put('I\'m an engaged SME', 'true');
				} else {
					m.put('I\'m an engaged SME', 'false');
				}
			} else {
				m.put('I\'m on the Case Cc', 'false');
				m.put('I\'m an engaged SME', 'false');
			}

			if (posts.containsKey(c.Id)) {
				m.put('I\'ve posted to case recently', 'true');
			} else {
				m.put('I\'ve posted to case recently', 'false');
			}

			if (comments.containsKey(c.Id)) {
				m.put('I\'ve commented on case recently', 'true');
			} else {
				m.put('I\'ve commented on case recently', 'false');
			}

			ret.add(m);
		}

		for (String s : cid) {
			Map<String, String> m = new Map<String, String>();
			if (s.left(3) == '001') {
				if (entries.containsKey(s)) {
					m.putAll(entries.get(s));
					m.put('I\'ve Logged Labor Recently', 'true');
				} else {
					m.put('I\'ve Logged Labor Recently', 'false');
				}
				if (accountOwners.containsKey(s)) {
					m.putAll(accountOwners.get(s));
				}
				if (entriesTotalTally.containsKey(s)) {
					m.put('Labor Tally (all time)', String.valueOf(entriesTotalTally.get(s)));
				}
				ret.add(m);
			}
			if (s.left(3) == '006') {
				if (entries.containsKey(s)) {
					m.putAll(entries.get(s));
				}
				if (opportunityOwners.containsKey(s)) {
					m.putAll(opportunityOwners.get(s));
				}
				if (entriesTotalTally.containsKey(s)) {
					m.put('Labor Tally (all time)', String.valueOf(entriesTotalTally.get(s)));
				}
				ret.add(m);
			}
		}

		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsAccountOwner() {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();

		String userId = UserInfo.getUserId();

		String soql =
			'SELECT Name,Id,RecordType.Name ' +
			'FROM Account ' +
			'WHERE Name = \'Tanium Internal Customer Org\' ' +
			'OR ( TAM_Sales_SME__c = \'' +
			userId +
			'\') ' +
			'OR ( P_TSE_Secondary__c = \'' +
			userId +
			'\') ' +
			'OR ( P_TSE_Account_Owner__c = \'' +
			userId +
			'\') ';

		List<Account> accounts = Database.query(soql);
		if (accounts.size() != 0) {
			for (Account o : accounts) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('Account Name', o.Name);
				obj.put('Account Id', o.Id);
				obj.put('Id', o.Id);
				obj.put('Name/Subject', o.Name);
				obj.put('isOwner', 'true');
				obj.put('Item Type', 'Account');
				ret.put(String.valueOf(o.Id), obj);
			}
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsCaseCc(String email) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();

		if (nullOrEmpty(email)) {
			email = UserInfo.getUserEmail();
		}

		String soql =
			'SELECT CasesId, ' +
			'Role ' +
			'FROM CaseContactRole ' +
			'WHERE Contact.Email LIKE \'' +
			email +
			'%\' ' +
			'AND Cases.IsClosed = false';

		List<CaseContactRole> ccrs = Database.query(soql);
		if (ccrs.size() != 0) {
			for (CaseContactRole c : ccrs) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('isCaseCc', 'true');

				if (c.Role == 'Engaged SME') {
					obj.put('isEngagedSME', 'true');
				} else {
					obj.put('isEngagedSME', 'false');
				}

				ret.put(String.valueOf(c.CasesId), obj);
			}
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsCaseComment(String daysBack) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		String casesCommented = RoscoHomePageNoShare.getRecentCommentIds(daysBack);
		String soql = 'SELECT Id ' + 'FROM Case  ' + 'WHERE Id IN (' + casesCommented + ')' + '';

		List<Case> cases = Database.query(soql);
		if (cases.size() != 0) {
			for (Case c : cases) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('isCaseComment', 'true');
				ret.put(String.valueOf(c.Id), obj);
			}
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsCaseEmail(String daysBack) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		String userId = UserInfo.getUserId();
		String userEmail = UserInfo.getUserEmail();
		String soql =
			'SELECT Id ' +
			'FROM Case  ' +
			'WHERE Id IN (SELECT ParentId ' +
			'FROM EmailMessage ' +
			'WHERE CreatedDate = LAST_N_DAYS:' +
			daysBack +
			' ' +
			'AND (FromAddress = \'' +
			userEmail +
			'\'  ' +
			' OR CreatedById = \'' +
			userId +
			'\'))';

		List<Case> cases = Database.query(soql);
		if (cases.size() != 0) {
			for (Case c : cases) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('isEmail', 'true');
				ret.put(String.valueOf(c.Id), obj);
			}
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsCaseOwner() {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Id ' +
			'FROM Case  ' +
			'WHERE isClosed = False ' +
			'AND OwnerId = \'' +
			userId +
			'\'';

		List<Case> cases = Database.query(soql);
		if (cases.size() != 0) {
			for (Case c : cases) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('Id', c.Id);
				obj.put('isOwner', 'true');
				ret.put(String.valueOf(c.Id), obj);
			}
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsCasePost(String daysBack) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Id ' +
			'FROM Case  ' +
			'WHERE Id IN (SELECT ParentId ' +
			'FROM CaseFeed ' +
			'WHERE CreatedDate = LAST_N_DAYS:' +
			daysBack +
			' ' +
			'AND CreatedById = \'' +
			userId +
			'\') ' +
			'';

		List<Case> cases = Database.query(soql);
		if (cases.size() != 0) {
			for (Case c : cases) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('isCasePost', 'true');
				ret.put(String.valueOf(c.Id), obj);
			}
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsLabor(String daysBack) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Case__r.CaseNumber, ' +
			'Case__r.Subject, ' +
			'Case__r.OwnerId, ' +
			'Case__r.Status, ' +
			'Case__r.Opportunity__c, ' +
			'Case__c, ' +
			'Account__r.Name, ' +
			'Account__c, ' +
			'Opportunity__r.Name, ' +
			'Opportunity__r.StageName, ' +
			'Opportunity__r.Type, ' +
			'Opportunity__r.CloseDate, ' +
			'Opportunity__c, ' +
			'LaborDate__c, ' +
			'LaborSubCategory__c, ' +
			'Minutes__c ' +
			'FROM Rosco_Time__c  ' +
			'WHERE User__c = \'' +
			userId +
			'\' ' +
			'AND LaborDate__c = LAST_N_DAYS:' +
			daysBack +
			' ' +
			'ORDER BY LaborDate__c DESC';

		List<Rosco_Time__c> times = Database.query(soql);
		if (times.size() != 0) {
			Map<String, Decimal> laborTally = new Map<String, Decimal>();
			for (Rosco_Time__c t : times) {
				String tallyId = 'undefined';

				if (!nullOrEmpty(t.Case__c)) {
					tallyId = t.Case__c;
				} else if (!nullOrEmpty(t.Opportunity__r.Name)) {
					tallyId = t.Opportunity__c;
				} else if (!nullOrEmpty(t.Account__r.Name)) {
					tallyId = t.Account__c;
				}

				if (laborTally.containsKey(tallyId)) {
					Decimal min = laborTally.get(tallyId) + t.Minutes__c;
					laborTally.put(tallyId, min);
				} else {
					laborTally.put(tallyId, t.Minutes__c);
				}
			}

			for (Rosco_Time__c t : times) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('isRecent', 'true');

				if (!nullOrEmpty(t.Case__c)) {
					obj.put('Item Type', 'Case');
					obj.put('Id', t.Case__c);
					obj.put('Labor Tally', String.valueOf(laborTally.get(t.Case__c)));
					obj.put('Labor Date', String.valueOf(t.LaborDate__c));
					obj.put('Labor Date GMT', String.valueOf(t.LaborDate__c.dateGMT()));
					obj.put('Name/Subject', t.Case__r.Subject);
					if (nullOrEmpty(t.Case__r.Opportunity__c)) {
						obj.put('Opportunity ID', 'None');
					} else {
						obj.put('Opportunity ID', t.Case__r.Opportunity__c);
					}
				} else if (!nullOrEmpty(t.Opportunity__r.Name)) {
					obj.put('Item Type', 'Opportunity');
					obj.put('Id', t.Opportunity__c);
					obj.put('Account Name', t.Account__r.Name);
					obj.put('Account ID', t.Account__c);

					String subject =
						t.Opportunity__r.Name +
						' - ' +
						String.valueOf(t.Opportunity__r.Type) +
						' - ' +
						'Stage: ' +
						String.valueOf(t.Opportunity__r.StageName) +
						' - ' +
						'Close Date: ' +
						String.valueOf(t.Opportunity__r.CloseDate);
					obj.put('Name/Subject', subject);

					obj.put('Labor Tally', String.valueOf(laborTally.get(t.Opportunity__c)));
					obj.put('Labor Date', String.valueOf(t.LaborDate__c));
					obj.put('Labor Date GMT', String.valueOf(t.LaborDate__c.dateGMT()));
					obj.put('Opportunity ID', t.Opportunity__c);
				} else if (!nullOrEmpty(t.Account__r.Name)) {
					obj.put('Item Type', 'Account');
					obj.put('Id', t.Account__c);
					obj.put('Account Name', t.Account__r.Name);
					obj.put('Opportunity ID', 'None');

					obj.put('Labor Tally', String.valueOf(laborTally.get(t.Account__c)));
					obj.put('Labor Date', String.valueOf(t.LaborDate__c));
					obj.put('Labor Date GMT', String.valueOf(t.LaborDate__c.dateGMT()));
					obj.put('Name/Subject', t.Account__r.Name);
				}

				Integer laborDateAge = t.LaborDate__c.Date().daysBetween(System.now().Date());
				obj.put('LaborDateAge', String.valueOf(laborDateAge));

				if (!ret.containsKey((String.valueOf(obj.get('Id'))))) {
					ret.put(String.valueOf(obj.get('Id')), obj);
				}
			}
		}
		return ret;
	}

	public static Map<String, Decimal> getAssociatedObjectsLaborTotalTally(Set<String> cid) {
		Map<String, Decimal> ret = new Map<String, Decimal>();
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Case__c, ' +
			'Account__c, ' +
			'Opportunity__c, ' +
			'Minutes__c ' +
			'FROM Rosco_Time__c  ' +
			'WHERE User__c = \'' +
			userId +
			'\' ' +
			'AND (Case__c IN :cid ' +
			' OR Account__c IN :cid ' +
			' OR Opportunity__C IN :cid) ';

		List<Rosco_Time__c> times = Database.query(soql);
		if (times.size() != 0) {
			for (Rosco_Time__c t : times) {
				String tallyId = 'undefined';
				if (!nullOrEmpty(t.Case__c)) {
					tallyId = t.Case__c;
				} else if (!nullOrEmpty(t.Opportunity__c)) {
					tallyId = t.Opportunity__c;
				} else if (!nullOrEmpty(t.Account__c)) {
					tallyId = t.Account__c;
				}
				if (ret.containsKey(tallyId)) {
					Decimal min = ret.get(tallyId) + t.Minutes__c;
					ret.put(tallyId, min);
				} else {
					ret.put(tallyId, t.Minutes__c);
				}
			}
		}
		return ret;
	}

	public static Map<String, Map<String, String>> getAssociatedObjectsOpportunityOwner() {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Account.Name, AccountId, Type, Name,Id,StageName,CSM_Account_Owner__c,CloseDate ' +
			'FROM Opportunity ' +
			'WHERE TAM_Sales_SME_Owner__c = \'' +
			userId +
			'\' ' +
			'OR CSM_Account_Owner__c = \'' +
			userId +
			'\' ' +
			'ORDER BY CloseDate ASC';

		List<Opportunity> opportunities = Database.query(soql);
		if (opportunities.size() != 0) {
			for (Opportunity o : opportunities) {
				Map<String, String> obj = new Map<String, String>();
				obj.put('Account Name', o.Account.Name);
				obj.put('Account Id', o.accountid);
				String subject =
					o.Name +
					' - ' +
					String.valueOf(o.Type) +
					' - ' +
					'Stage: ' +
					String.valueOf(o.StageName) +
					' - ' +
					'Close Date: ' +
					String.valueOf(o.CloseDate);
				obj.put('Name/Subject', subject);
				obj.put('Opportunity Id', o.Id);
				obj.put('Id', o.Id);
				obj.put('isOwner', 'true');
				obj.put('Item Type', 'Opportunity');
				ret.put(String.valueOf(o.Id), obj);
			}
		}
		return ret;
	}

	/** getCaseSelectFields
	 *
	 */
	public static Map<String, String> getCaseSelectFields(List<String> lParam) {
		Map<String, String> ret = new Map<String, String>();
		List<String> excluded = new List<String>{
			'isdeleted',
			'masterrecordid',
			'assetid',
			'sourceid',
			'businesshoursid',
			'parentid',
			'suppliedname',
			'suppliedemail',
			'suppliedphone',
			'suppliedcompany',
			'reason',
			'language',
			'currencyisocode',
			'isclosedoncreate',
			'systemmodstamp',
			'contactphone',
			'contactmobile',
			'contactfax',
			'comments',
			'lastvieweddate',
			'lastreferenceddate',
			'case_creator__c',
			'category__c',
			'case_delivery_date__c',
			'updates__c',
			'lntcms__engineeringreqnumber__c',
			'lntcms__product__c',
			'enhancement_request_filed__c',
			'kb_created__c',
			'kb_worthy__c',
			'e_number__c',
			'preferred_contact_method__c',
			'reference_number__c',
			'severity__c',
			'reason_for_high_priority__c',
			'expected_release_date__c',
			'email_ccs__c',
			'operatingsystem__c',
			'zendesk_group__c',
			'zendesk_ticket_number__c',
			'case_comment__c',
			'current_date_time__c',
			'dump_team_help__c',
			'escalation_reason_delete__c',
			'escalation_type__c',
			'no_public_comments_allowed__c',
			'severity_community__c',
			'severity_flag__c',
			'visible_in_community__c',
			'deal_registration__c',
			'end_points__c',
			'licenses__c',
			'partner__c',
			'priority',
			'reseller__c',
			'completed_documents_new_partner_only__c',
			'critsit__c',
			'isstopped',
			'stopstartdate',
			'milestonestatus',
			'servicecontractid',
			'productid',
			'slastartdate',
			'slaexitdate',
			'latestpubliccommenthtml__c',
			'latestprivatecommenthtml__c',
			'latestprivatecomment__c',
			'cumulus_ticket_link__c',
			'workload_per_week__c',
			'total_effort__c',
			'create_kanbanize_card__c',
			'incident_cause__c',
			'resolution_code__c',
			'sme_ownerid__c',
			'team__c',
			'peer_reviewer__c',
			'',
			'test_steps__c',
			'kimbleone__activityassignment__c',
			'kimbleone__deliverygroup__c',
			'kimbleone__proposal__c',
			'kimbleone__resourcedactivity__c',
			'escalation_l2date__c',
			'external_id__c',
			'createdhour__c',
			'uniqueentry__current_endpoint__c',
			'uniqueentry__ringlead_app_field__c',
			'uniqueentry__ringlead_last_processed_date__c'
		};
		excluded.add('opportunity__c');
		Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
		Schema.SObjectType caseSchema = schemaMap.get('Case');
		Map<String, Schema.SObjectField> caseMap = caseSchema.getDescribe().fields.getMap();
		Map<String, String> fieldMap = new Map<String, String>();
		for (String fieldName : caseMap.keySet()) {
			String fieldLabel = caseMap.get(fieldName).getDescribe().getLabel();
			if (fieldName == 'Subject') {
				fieldLabel = 'Name/Subject';
			}
			if (fieldName == 'Id') {
				fieldLabel = 'Id';
			}

			if (!excluded.contains(fieldName)) {
				ret.put(fieldName, fieldLabel);
			}
		}

		Schema.SObjectType accountSchema = schemaMap.get('Account');
		Map<String, Schema.SObjectField> accountMap = accountSchema.getDescribe().fields.getMap();
		ret.put('account.name', accountMap.get('name').getDescribe().getLabel());

		Schema.SObjectType userSchema = schemaMap.get('User');
		Map<String, Schema.SObjectField> userMap = userSchema.getDescribe().fields.getMap();

		ret.put('sme_ownerid__r.name', 'SME Owner Name');
		ret.put('contact.name', 'Contact Name');
		ret.put('contact.account.name', 'Contact Account Name');

		if (!nullOrEmpty(lParam)) {
			for (String key : ret.keySet()) {
				if (!lParam.contains(ret.get(key))) {
					ret.remove(key);
				}
			}
		}
		return ret;
	}

	/** getCaseObjects
	 * @return
	 */
	@AuraEnabled(cacheable=true)
	public static List<Map<String, String>> getCaseObjects(String jsonParam) {
		Map<String, Object> objParam = (Map<String, Object>) JSON.deserializeUntyped(jsonParam);
		String cursor = String.valueOf(objParam.get('cursor'));
		String columnIterator = String.valueOf(objParam.get('columnIterator'));
		String startIteration = String.valueOf(objParam.get('startIteration'));
		String batchSize = String.valueOf(objParam.get('batchSize'));
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Map<String, String> selectFields = getCaseSelectFields(null);
		String soql =
			'SELECT ' +
			String.join(new List<String>(selectFields.keySet()), ',') +
			' FROM Case ';

		if (!nullOrEmpty(columnIterator)) {
			if (columnIterator.contains('Date')) {
				if (nullOrEmpty(cursor)) {
					soql += ' WHERE ' + columnIterator + '=LAST_N_DAYS:' + startIteration + ' ';
				} else {
					cursor = cursor.replace(' ', 'T');
					cursor = cursor.replace('/"', '');
					cursor = cursor + '.000Z';
					soql += ' WHERE ' + columnIterator + ' > ' + cursor + ' ';
				}
			} else {
				if (nullOrEmpty(cursor)) {
					soql += ' WHERE ' + columnIterator + ' > \'' + startIteration + '\' ';
				} else {
					soql += ' WHERE ' + columnIterator + ' > \'' + cursor + '\' ';
				}
			}
		}
		soql += 'ORDER By CaseNumber LIMIT ' + batchSize;

		List<Case> cases = Database.query(soql);
		for (Case c : cases) {
			Map<String, String> obj = new Map<String, String>();

			for (String key : selectFields.keySet()) {
				List<String> keyList = key.split('[.]');

				String val = 'None';

				try {
					if (keyList.size() == 1) {
						val = String.valueOf(c.get(keyList[0]));
					} else if (keyList.size() == 2) {
						val = String.valueOf(c.getSObject(keyList[0]).get(keyList[1]));
					} else if (keyList.size() == 3) {
						val = String.valueOf(
							c.getSObject(keyList[0]).getSObject(keyList[1]).get(keyList[2])
						);
					}
				} catch (Exception e) {
				} finally {
					obj = addToObj(obj, selectFields.get(key), val);
				}
			}
			ret.add(obj);
		}
		return ret;
	}

	@AuraEnabled
	public static List<Object> getCc() {
		List<Object> ret = new List<Object>();
		String email = UserInfo.getUserEmail();
		List<String> cases = new List<String>();
		String soql =
			'SELECT Cases.CaseNumber, ' +
			'Cases.Subject, ' +
			'Cases.Account.Name, ' +
			'CasesId, ' +
			'Role ' +
			'FROM CaseContactRole ' +
			'WHERE Contact.Email = \'' +
			email +
			'\' ' +
			'AND Cases.IsClosed = false';

		List<CaseContactRole> ccrs = Database.query(soql);
		if (ccrs.size() != 0) {
			for (CaseContactRole c : ccrs) {
				Map<String, Object> obj = new Map<String, Object>();
				obj.put('Id', c.CasesId);
				obj.put('Name', c.Cases.CaseNumber + ' - ' + c.Cases.Subject);
				obj.put('Role', '');
				if (!nullOrEmpty(c.Role)) {
					obj.put('Role', c.Role);
				}
				obj.put(
					'Name',
					c.Cases.Account.Name +
					' - ' +
					c.Cases.CaseNumber +
					' - ' +
					c.Cases.Subject
				);
				ret.add(obj);
			}
		}
		return ret;
	}

	@AuraEnabled
	public static String getJSON(
		String contentWorkspaceName,
		String contentFolderName,
		String contentTitle,
		Boolean prependUserIdToTitle
	) {
		String ret = '{}';
		try {
			if (prependUserIdToTitle) {
				contentTitle = UserInfo.getUserId() + '-' + contentTitle;
			}
			ContentWorkspace contentWorkspace = [
				SELECT Id, RootContentFolderId
				FROM ContentWorkspace
				WHERE Name = :contentWorkspaceName
			];
			Id contentFolderId = [SELECT Id FROM ContentFolder WHERE Name = :contentFolderName].Id;
			Id scUserId = [SELECT Id FROM User WHERE Name = 'Service Cloud Tanium' LIMIT 1].Id;
			List<ContentVersion> files = [
				SELECT VersionData
				FROM ContentVersion
				WHERE Title = :contentTitle AND OwnerId = :scUserId AND isLatest = TRUE
				LIMIT 1
			];
			if (files.size() == 1) {
				ret = files[0].VersionData.toString();
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
		return ret;
	}

	/** getGroupObjects
     * @param accountId - retrieve Pod SME mappings
       @param accountId - retrieve Pod SME mappings
     * @return Map
     */
	@AuraEnabled
	public static List<Map<String, String>> getGroupObjects(Boolean aggregate) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			Map<String, String> podMap = getPodMap();
			Map<String, String> podMapOverride = getPodOverrideMap();
			String soql =
				'SELECT TAM__c, ' +
				'Responsibility__c, ' +
				'Slack_Name__c, ' +
				'TAM_Team__r.Name, ' +
				'TAM_Team__r.Specialty_Group__r.Name, ' +
				'TAM__r.Email, ' +
				'TAM__r.ManagerId, ' +
				'TAM__r.Manager.Manager.Id, ' +
				'TAM__r.Manager.Manager.Manager.Id, ' +
				'TAM__r.Manager.Manager.Manager.Manager.Id, ' +
				'TAM__r.Manager.Manager.Manager.Manager.Manager.Id ' +
				'FROM TAM_Team_Member__c ' +
				'WHERE RecordType.Name = \'Escalation SME\' ' +
				'ORDER BY Slack_Name__c ASC NULLS LAST';

			List<TAM_Team_Member__c> members = Database.query(soql);

			List<String> retList = new List<String>();
			for (TAM_Team_Member__c m : members) {
				Map<String, String> sme = new Map<String, String>();
				sme.put('SlackName', m.Slack_Name__c);
				sme.put('Responsiblity', m.Responsibility__c);
				if (nullOrEmpty(m.TAM_Team__r.Specialty_Group__r.Name)) {
					sme.put('Speciality Group', m.TAM_Team__r.Name);
				} else {
					sme.put('Speciality Group', m.TAM_Team__r.Specialty_Group__r.Name);
				}
				sme.put('SMETeam', m.TAM_Team__r.Name);
				sme.put('Team & Responsibility', m.TAM_Team__r.Name + ' (' + m.Responsibility__c + ')');
				sme.put('contactemail', m.TAM__r.Email);
				sme.put('Pod', 'n/a');
				if (m.TAM__r.ManagerId != null) {
					if (podMap.containsKey(m.TAM__r.ManagerId)) {
						sme.put('Pod', podMap.get(m.TAM__r.ManagerId));
						ret.add(sme);
						continue;
					}
				}
				if (m.TAM__r.Manager.ManagerId != null) {
					if (podMap.containsKey(m.TAM__r.Manager.ManagerId)) {
						sme.put('Pod', podMap.get(m.TAM__r.Manager.ManagerId));
						ret.add(sme);
						continue;
					}
				}
				if (m.TAM__r.Manager.Manager.ManagerId != null) {
					if (podMap.containsKey(m.TAM__r.Manager.Manager.ManagerId)) {
						sme.put('Pod', podMap.get(m.TAM__r.Manager.Manager.ManagerId));
						ret.add(sme);
						continue;
					}
				}
				if (m.TAM__r.Manager.Manager.Manager.ManagerId != null) {
					if (podMap.containsKey(m.TAM__r.Manager.Manager.Manager.ManagerId)) {
						sme.put('Pod', podMap.get(m.TAM__r.Manager.Manager.Manager.ManagerId));
						ret.add(sme);
						continue;
					}
				}
				if (m.TAM__r.Manager.Manager.Manager.Manager.ManagerId != null) {
					if (podMap.containsKey(m.TAM__r.Manager.Manager.Manager.Manager.ManagerId)) {
						sme.put('Pod', podMap.get(m.TAM__r.Manager.Manager.Manager.Manager.ManagerId));
						ret.add(sme);
						continue;
					}
				}
			}

			if (aggregate) {
				Map<String, Map<String, String>> agg = new Map<String, Map<String, String>>();
				for (Map<String, String> r : ret) {
					if (agg.containsKey(r.get('SlackName'))) {
						Map<String, String> existing = agg.get(r.get('SlackName'));
						String smeTeam = existing.get('SMETeam');
						smeTeam += ' | ' + r.get('SMETeam');
						existing.put('SMETeam', smeTeam);
						String smeResponsiblity = existing.get('Responsiblity');
						smeResponsiblity += ' | ' + r.get('Responsiblity');
						existing.put('Responsiblity', smeResponsiblity);
						String specialityGroup = existing.get('Speciality Group');
						specialityGroup += ' | ' + r.get('Speciality Group');
						existing.put('Speciality Group', specialityGroup);
						String teamAndResponsiblity = existing.get('Team & Responsibility');
						teamAndResponsiblity += ' | ' + r.get('Team & Responsibility');
						existing.put('Team & Responsibility', teamAndResponsiblity);
					} else {
						agg.put(r.get('SlackName'), r);
					}
				}

				for (Map<String, String> a : agg.values()) {
					String sGroup = a.get('Speciality Group');
					if (sGroup.contains('|')) {
						List<String> lGroupSplit = sGroup.split('(\\|)');
						Boolean bSameGroup = true;
						List<String> scratch = new List<String>();
						for (String s : lGroupSplit) {
							s = s.trim();
							if (scratch.size() > 0) {
								if (!scratch.contains(s)) {
									bSameGroup = false;
								}
							}
							scratch.add(s);
						}
						if (bSameGroup) {
							a.put('Speciality Group', scratch[0]);
						}
					}
				}
				ret = agg.values();
			}
		} catch (DmlException e) {
		}
		return ret;
	}

	@AuraEnabled
	public static List<Object> getOpp() {
		List<Object> ret = new List<Object>();
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Account.Name, Name,Id,Type,StageName,CSM_Account_Owner__c,CloseDate ' +
			'FROM Opportunity ' +
			'WHERE Name = \'Marketing Event Opportunity\'' +
			'OR ( TAM_Sales_SME_Owner__c = \'' +
			userId +
			'\' ' +
			'OR CSM_Account_Owner__c = \'' +
			userId +
			'\')' +
			'ORDER BY CloseDate ASC';

		List<Opportunity> opportunities = Database.query(soql);
		Boolean bCSM = false;
		if (opportunities.size() != 0) {
			for (Opportunity o : opportunities) {
				if (o.CSM_Account_Owner__c != null) {
					if (o.CSM_Account_Owner__c == userId) {
						bCSM = true;
					}
				}
			}
		}
		if (opportunities.size() != 0) {
			for (Opportunity o : opportunities) {
				Map<String, Object> obj = new Map<String, Object>();
				obj.put('Name', o.Account.Name + ' : ' + o.Name);
				obj.put('CloseDate', o.CloseDate);
				obj.put('Id', o.Id);
				obj.put('Stage', o.StageName);
				obj.put('CE', 'false');
				if (o.CSM_Account_Owner__c != null) {
					if (o.CSM_Account_Owner__c == userId) {
						obj.put('CE', 'true');
					}
				}
				ret.add(obj);
			}
		}
		return ret;
	}

	/** getPodMap
	 */
	public static Map<String, String> getPodMap() {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT Leader__c, ' +
				'Name ' +
				'FROM TAM_Team__c ' +
				'WHERE RecordType.Name  = \'Escalation Pod\'';

			List<TAM_Team__c> pods = Database.query(soql);

			if (pods.size() != 0) {
				for (TAM_Team__c p : pods) {
					ret.put(p.Leader__c, p.Name);
					ret.put(p.Name, p.Leader__c);
				}
			}
		} catch (DmlException e) {
		}
		return ret;
	}

	/** getPodOverrideMap
	 */
	public static Map<String, String> getPodOverrideMap() {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT TAM__c, ' +
				'TAM_Team__r.Name ' +
				'FROM TAM_Team_Member__c ' +
				'WHERE RecordType.Name = \'Escalation_Pod\'';

			List<TAM_Team_Member__c> aTeams = Database.query(soql);

			if (aTeams.size() != 0) {
				for (TAM_Team_Member__c t : aTeams) {
					ret.put(t.TAM__c, t.TAM_Team__r.Name);
					ret.put(t.TAM_Team__r.Name, t.TAM__c);
				}
			}
		} catch (DmlException e) {
		}
		return ret;
	}

	private static Map<String, String> getUserAttributes() {
		Map<String, String> ret = new Map<String, String>();
		String soql =
			'SELECT Id, ' +
			'Email, ' +
			'Department, ' +
			'Title, ' +
			'UserRole.Name, ' +
			'Profile.Name, ' +
			'Manager.Email ' +
			'FROM User ' +
			'WHERE Id = \'' +
			UserInfo.getUserId() +
			'\' ' +
			'AND isActive = true';

		List<User> users = Database.query(soql);
		if (users.size() > 0) {
			ret.put('Id', users[0].Id);
			ret.put('Email', users[0].Email);
			ret.put('Department', users[0].Department);
			ret.put('Title', users[0].Title);
			ret.put('Role', users[0].UserRole.Name);
			ret.put('Profile', users[0].Profile.Name);
			ret.put('Manager', users[0].Manager.Email);
		}
		return ret;
	}

	private static Map<String, String> getUserGroups() {
		Map<String, String> ret = new Map<String, String>();
		String soql =
			'SELECT Group.Name, ' +
			'Group.Type ' +
			'FROM GroupMember  ' +
			'WHERE UserOrGroupId = \'' +
			UserInfo.getUserId() +
			'\'';

		List<GroupMember> members = Database.query(soql);
		if (members.size() > 0) {
			for (GroupMember m : members) {
				ret.put(m.Group.Name, m.Group.Type);
			}
		}
		return ret;
	}

	private static Map<String, String> getUserPermissionSets() {
		Map<String, String> ret = new Map<String, String>();
		String soql =
			'SELECT PermissionSet.Name, ' +
			'PermissionSet.Type ' +
			'FROM PermissionSetAssignment ' +
			'WHERE AssigneeId = \'' +
			UserInfo.getUserId() +
			'\' ' +
			'AND isActive = true';

		List<PermissionSetAssignment> sets = Database.query(soql);
		if (sets.size() > 0) {
			for (PermissionSetAssignment s : sets) {
				ret.put(s.PermissionSet.Name, s.PermissionSet.Type);
			}
		}
		return ret;
	}

	@AuraEnabled
	public static List<Object> getRecent() {
		List<Object> ret = new List<Object>();
		String userId = UserInfo.getUserId();
		String soql =
			'SELECT Case__r.CaseNumber, ' +
			'Case__r.Subject, ' +
			'Case__c, ' +
			'Account__r.Name, ' +
			'Account__c, ' +
			'Opportunity__r.Name, ' +
			'Opportunity__r.StageName, ' +
			'Opportunity__r.Type, ' +
			'Opportunity__r.CloseDate, ' +
			'Opportunity__c, ' +
			'LaborDate__c, ' +
			'LaborSubCategory__c ' +
			'FROM Rosco_Time__c  ' +
			'WHERE User__c = \'' +
			userId +
			'\' ' +
			'AND LaborDate__c = LAST_N_DAYS:45 ' +
			'ORDER BY LaborDate__c DESC';

		List<Rosco_Time__c> times = Database.query(soql);
		List<String> existing = new List<String>();
		if (times.size() != 0) {
			for (Rosco_Time__c t : times) {
				Map<String, Object> obj = new Map<String, Object>();
				if (!nullOrEmpty(t.Case__r.CaseNumber)) {
					obj.put('type', 'case');
					obj.put('Id', t.Case__c);
					obj.put(
						'Name',
						t.Account__r.Name +
						' - ' +
						t.Case__r.CaseNumber +
						' - ' +
						t.Case__r.Subject
					);
					obj.put('LaborDate', String.valueOf(t.LaborDate__c));
				} else if (!nullOrEmpty(t.Opportunity__r.Name)) {
					obj.put('type', 'opportunity');
					obj.put('Id', t.Opportunity__c);
					String name =
						t.Opportunity__r.Name +
						' - ' +
						String.valueOf(t.Opportunity__r.Type) +
						' - ' +
						'Close Date: ' +
						String.valueOf(t.Opportunity__r.CloseDate);
					obj.put('Name', name);
					obj.put('StageName', t.Opportunity__r.StageName);
					if (
						t.Opportunity__r.StageName == 'Failed' ||
						t.Opportunity__r.StageName == 'CLOSED WON' ||
						t.Opportunity__r.StageName == 'POC'
					) {
						obj.put('allowLogTime', 'false');
					} else {
						obj.put('allowLogTime', 'true');
					}
					obj.put('LaborDate', String.valueOf(t.LaborDate__c));
				} else if (!nullOrEmpty(t.Account__r.Name)) {
					obj.put('type', 'account');
					obj.put('Id', t.Account__c);
					obj.put('Name', t.Account__r.Name);
					obj.put('LaborDate', String.valueOf(t.LaborDate__c));
				}
				if (!existing.contains(String.valueOf(obj.get('Id')))) {
					ret.add(obj);
					existing.add(String.valueOf(obj.get('Id')));
				}
			}
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getRoscoTable(String jsonParam) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Map<String, Object> objParam = (Map<String, Object>) JSON.deserializeUntyped(jsonParam);
		String provider = String.valueOf(objParam.get('provider'));

		if (provider == 'Items Associated with you') {
			ret = getAssociatedObjects(jsonParam);
		} else if (provider == 'Groups') {
			ret = getGroupObjects(true);
		} else if (provider == 'Cases') {
			ret = getCaseObjects(jsonParam);
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, Map<String, String>> getRoscoTableInit(String jsonParam) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		ret.put('userAttributes', getUserAttributes());
		if (!nullOrEmpty(jsonParam)) {
			Map<String, Object> objParam = (Map<String, Object>) JSON.deserializeUntyped(jsonParam);
			if (objParam.containsKey('collectGroups')) {
				if (objParam.get('collectGroups') == 'true') {
					ret.put('userGroups', getUserGroups());
				}
			}
			if (objParam.containsKey('collectPermissionSets')) {
				if (objParam.get('collectPermissionSets') == 'true') {
					ret.put('userPermissionSets', getUserPermissionSets());
				}
			}
		}
		return ret;
	}

	private static String getUserProfileName() {
		String ret = '';
		try {
			String userProfileId = UserInfo.getProfileId();
			if (Test.isRunningTest()) {
				userProfileId = '00e60000000ywmUAAQ';
			}

			if (userProfileId != null) {
				String soql =
					'SELECT Name ' +
					'FROM Profile ' +
					'WHERE Id = \'' +
					userProfileId +
					'\'' +
					'LIMIT 1';

				List<Profile> profiles = Database.query(soql);
				if (profiles.size() != 0) {
					ret = String.valueOf(profiles[0].Name);
				}
			}
		} catch (DmlException e) {
		}
		return ret;
	}

	private static String getUserRole() {
		String ret = '';
		try {
			String userRoleId = UserInfo.getUserRoleId();
			if (Test.isRunningTest()) {
				userRoleId = '00E7V000001dJS7UAM';
			}

			if (userRoleId != null) {
				String soql =
					'SELECT Name ' +
					'FROM UserRole ' +
					'WHERE Id = \'' +
					userRoleId +
					'\'' +
					'LIMIT 1';

				List<UserRole> roles = Database.query(soql);
				if (roles.size() != 0) {
					ret = String.valueOf(roles[0].Name);
				}
			}
		} catch (DmlException e) {
		}
		return ret;
	}

	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@AuraEnabled
	public static void persistJSON(
		String contentWorkspaceName,
		String contentFolderName,
		String contentTitle,
		String contentReasonForChange,
		String jsonString,
		Integer maxContentVersions,
		Boolean prependUserIdToTitle
	) {
		try {
			if (prependUserIdToTitle) {
				contentTitle = UserInfo.getUserId() + '-' + contentTitle;
			}
			ContentWorkspace contentWorkspace = [
				SELECT Id, RootContentFolderId
				FROM ContentWorkspace
				WHERE Name = :contentWorkspaceName
			];
			Id contentFolderId = [SELECT Id FROM ContentFolder WHERE Name = :contentFolderName].Id;
			Id scUserId = [SELECT Id FROM User WHERE Name = 'Service Cloud Tanium' LIMIT 1].Id;
			String base64Content = EncodingUtil.Base64Encode(Blob.valueOf(jsonString));
			Blob blobContent = EncodingUtil.base64Decode(base64Content);
			List<ContentVersion> files = [
				SELECT Id, ContentDocumentId, PathOnClient
				FROM ContentVersion
				WHERE Title = :contentTitle AND OwnerId = :scUserId
				ORDER BY CreatedDate DESC
			];
			Boolean createFile = true;
			if (files.size() > 0) {
				if (files.size() < maxContentVersions) {
					ContentVersion objCV = new ContentVersion(
						ContentDocumentId = files[0].ContentDocumentId,
						PathOnClient = files[0].PathOnClient,
						ReasonForChange = contentReasonForChange,
						VersionData = blobContent
					);
					insert objCV;
					createFile = false;
				} else {
					List<ContentDocument> documents = [
						SELECT Id
						FROM ContentDocument
						WHERE Id = :files[0].ContentDocumentId
						LIMIT 1
					];
					delete documents;
				}
			}
			if (createFile) {
				ContentVersion objCV = new ContentVersion(
					Title = contentTitle,
					PathOnClient = contentTitle + '\\.txt',
					VersionData = blobContent
				);
				insert objCV;
				Id contentDocumentId = [
					SELECT ContentDocumentId
					FROM ContentVersion
					WHERE Id = :objCV.Id
				]
				.ContentDocumentId;
				ContentDocumentLink cdl = new ContentDocumentLink(
					ContentDocumentId = contentDocumentId,
					LinkedEntityId = contentWorkspace.Id
				);
				insert cdl;
				List<ContentFolderMember> members = [
					SELECT Id, ChildRecordId, ParentContentFolderId
					FROM ContentFolderMember
					WHERE ChildRecordId = :contentDocumentId
					LIMIT 1
				];
				if (members.size() > 0) {
					members[0].ParentContentFolderId = contentFolderId;
					update members[0];
				}

				ContentVersion objCVX = [SELECT Id FROM ContentVersion WHERE Id = :objCV.Id];
				objCVX.OwnerId = scUserId;
				update objCVX;
			}
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}
}