/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: RoscoEscalate - supports rosco escalation functionality
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-7429    2024-02-22    Slack message change for escalation
 * SS-7276    2024-04-17    Updated method getSMEInfo, removed references to POD field and functionality
 * SS-7527    2024-04-29    Restrict Escalation fields
 * SS-8137    2024-05-14    Updated method sendToEscalationSlack plus class cleanup, plus Nebula logger
 * SS-8343    2024-06-08    Slack mention using member id instead of username
 * SS-7842    2024-07-18    Updated method getSMETeamDescription - change the default team description
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-9951    2025-01-23    Remove clearSME method
 * SS-10203   2025-02-12    Add clearSME method to update Role to null in CaseContactRole
 * SS-10492   2025-04-09    Revert SS-9951 and SS-10203
 * SS-10848   2025-07-02    Move setCCR from RoscoCaseContactRole and remove unused methods
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c
 * SS-12610   2026-02-24    Update the Escalation Update Feed Item functionality
 */
public with sharing class RoscoEscalate {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	public static void addChronicleSupportToCc(String caseId) {
		try {
			String contactIds;

			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			if (cmfields.contains('rosco_chronicle_contactid__c')) {
				if (!nullOrEmpty(cm.get('rosco_chronicle_contactid__c'))) {
					contactIds = String.valueOf(cm.get('rosco_chronicle_contactid__c'));
				}
			}
			if (contactIds != null) {
				if (contactIds != '') {
					if (contactIds.containsAny(',')) {
						List<String> csplit = contactIds.split(',');
						for (String c : csplit) {
							setCcr(c, caseId, null);
						}
					} else {
						setCcr(contactIds, caseId, null);
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('addChronicleSupportToCc', e);
		}
	}

	public static void clearSme(String caseid) {
		try {
			List<CaseContactRole> caseContactRoles = new List<CaseContactRole>();
			for (CaseContactRole existingSME : [
				SELECT Role
				FROM CaseContactRole
				WHERE CasesId = :caseId AND Role = 'Engaged SME'
			]) {
				existingSME.Role = null;
				caseContactRoles.add(existingSME);
			}
			delete caseContactRoles;
		} catch (Exception e) {
			logNebulaException('clearSme', e);
		}
	}

	@AuraEnabled
	public static Map<String, String> getInitInfo(String caseId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			Case aCase = RoscoUtility.getCaseDetails(caseId);
			ret.put('recordType', '');
			if (aCase.RecordType.Name != null) {
				ret.put('recordType', String.valueOf(aCase.RecordType.Name));
			}
			ret.put('caseType', '');
			if (aCase.Type != null) {
				ret.put('caseType', String.valueOf(aCase.Type));
			}
			ret.put('accountid', '');
			String accountId = String.valueOf(aCase.AccountId);
			if (accountId != null) {
				ret.put('accountid', String.valueOf(accountId));
			}
			ret.put('critsit', 'false');
			String critsit = String.valueOf(aCase.critsit__c);
			if (critsit != null) {
				if (critsit.toLowerCase() == 'true') {
					ret.put('critsit', 'true');
				}
			}
			ret.put('tags', '');
			if (!nullOrEmpty(aCase.Tags__c)) {
				ret.put('tags', String.valueOf(aCase.Tags__c));
			}
			ret.put('escstatus', '');
			String escstatus = String.valueOf(aCase.Escalation_Status__c);
			if (escstatus != null) {
				ret.put('escstatus', escstatus);
			}
			ret.put('level', 'Level 1');
			String level = String.valueOf(aCase.Escalation_Tier__c);
			if (level != null && level != '') {
				ret.put('level', level);
				Datetime escDate;
				if (level == 'Level 2' && aCase.Escalation_L2_SME_Engaged_Date__c == null) {
					escDate = aCase.Escalation_L2_Date__c;
				} else if (level == 'Level 3' && aCase.Escalation_L3_SME_Engaged_Date__c == null) {
					escDate = aCase.Escalation_L3_Date__c;
				} else if (level == 'Level 4' && aCase.Escalation_L4_SME_Engaged_Date__c == null) {
					escDate = aCase.Escalation_L4_Date__c;
				} else if (level == 'Level 5' && aCase.Escalation_L5_SME_Engaged_Date__c == null) {
					escDate = aCase.Escalation_L5_Date__c;
				}
				if (escDate != null) {
					Map<String, String> status = RoscoCaseProcesses.getCaseSLOStatus(
						null,
						aCase.Support_Model__c,
						aCase.Escalation_Team__c,
						aCase.Escalation_Tier__c,
						Decimal.valueOf(aCase.Severity_Community__c),
						escDate,
						aCase.RecordType.Name
					);
					ret.putAll(status);
				}
			}
			String levelauth = getUsersAuthorizedLevels2();
			if (levelauth != null) {
				if (levelauth != '') {
					ret.put('levelauth', levelauth);
				}
			} else {
				ret.put('levelauth', 'Level 1');
			}
			String team = '';
			if (aCase.Escalation_Team__c != null) {
				team = aCase.Escalation_Team__c;
			}
			ret.put('team', team);
			ret.put('smeteams', getSMETeams('Support'));
			String pod = '';
			if (aCase.Escalation_Pod__c != null) {
				pod = aCase.Escalation_Pod__c;
			} else {
				Map<String, String> account = RoscoUtility.getAccountDetails(accountId);
				pod = account.get('ptampod');
				if (pod == null) {
					pod = account.get('stampod');
				} else if (pod == '') {
					pod = account.get('stampod');
				}
			}
			ret.put('pod', pod);
			ret.put('pods', getPods('Support'));
			String teamdetermined = ret.get('team');
			ret.put('teaminfo', getSMEInfo(accountId, teamdetermined, level, aCase.RecordType.Name));
			ret.put('escinput', '');
			if (!nullOrEmpty(aCase.Escalation_Reason__c)) {
				ret.put('escinput', String.valueOf(aCase.Escalation_Reason__c));
			}
			ret.put('escartifact', '');
			if (!nullOrEmpty(aCase.Escalation_Artifact__c)) {
				ret.put('escartifact', String.valueOf(aCase.Escalation_Artifact__c));
			}
			if (
				aCase.Status == 'Solved' ||
				aCase.Status == 'Closed' ||
				aCase.Status == 'Closed as Duplicate'
			) {
				ret.put('closedorsolved', 'true');
			} else {
				ret.put('closedorsolved', 'false');
			}
			ret.put('priorSME', getPriorSME(caseId));
			ret.put('priorShadow', getPriorShadow(caseId));
		} catch (Exception e) {
			logNebulaException('getInitInfo', e);
		}
		return ret;
	}

	public static String getInfoFromReason(String reason) {
		String ret = '';
		Boolean insection = false;
		if (reason.contains('\n') == true) {
			List<String> atemp = reason.split('\n');
			for (String s : atemp) {
				if (s.contains('Escalation Reason') == true) {
					insection = true;
				} else if (s.contains('===') == true) {
					//skip
				} else if (s.contains('Escalation Artifacts') == true) {
					return ret;
				} else {
					if (insection == true) {
						ret = ret + s + '\n';
					}
				}
			}
		}
		return ret;
	}

	@AuraEnabled
	public static String getArtifactFromReason(String reason) {
		String ret = '';
		Boolean start = false;
		if (reason.contains('\n') == true) {
			List<String> atemp = reason.split('\n');
			for (String s : atemp) {
				if (s.contains('Escalation Artifacts') == true) {
					start = true;
				} else if (start == true) {
					if (s.contains('Engaged SMEs') == true) {
						return ret;
					}
					if (s.contains('===') == true) {
						//skip
					} else {
						ret = ret + s + '\n';
					}
				}
			}
		}
		return ret;
	}

	public static String getLatestCasePost(String caseId) {
		String ret = '';
		try {
			String soql =
				'SELECT Body,CreatedDate FROM CaseFeed WHERE ParentId = \'' +
				caseId +
				'\' ORDER BY CreatedDate DESC NULLS LAST';

			List<CaseFeed> aFeed = Database.query(soql);
			if (aFeed.size() != 0) {
				for (CaseFeed a : aFeed) {
					if (a.Body != null) {
						if (a.Body.contains('Escalation Artifacts')) {
							return a.Body;
						}
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('getLatestCasePost', e);
		}
		return ret;
	}

	public static String getTAMTeamRecordTypeId(String caseRecordType, String type) {
		Id ret;
		if (caseRecordType.left(3) == '012') {
			caseRecordType = [SELECT Name FROM RecordType WHERE Id = :caseRecordType].Name;
		}
		caseRecordType = 'Support';
		if (type == 'Pod') {
			if (caseRecordType == 'Internal') {
				ret = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Solution_Specialist_Pod');
			} else {
				ret = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_Pod');
			}
		} else if (type == 'Speciality') {
			if (caseRecordType == 'Internal') {
				ret = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Solution_Speciality_Group');
			} else {
				ret = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_Speciality_Group');
			}
		} else {
			if (caseRecordType == 'Internal') {
				ret = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Solution_Specialist');
			} else {
				ret = Utility.getRecordTypeIdByAPIName('TAM_Team__c', 'Escalation_SME');
			}
		}
		return ret;
	}

	public static String getTAMTeamMemberRecordTypeId(String caseRecordType) {
		Id ret = Utility.getRecordTypeIdByAPIName('TAM_Team_Member__c', 'Escalation_SME');
		if (caseRecordType == 'Internal') {
			ret = Utility.getRecordTypeIdByAPIName('TAM_Team_Member__c', 'Solution_Specialist');
		}
		return ret;
	}

	public static Map<String, String> getPodMap(String caseRecordType) {
		Map<String, String> ret = new Map<String, String>();
		try {
			Id recordTypeId = getTAMTeamRecordTypeId(caseRecordType, 'Pod');

			String soql =
				'SELECT Leader__c, ' +
				'Name ' +
				'FROM TAM_Team__c ' +
				'WHERE RecordTypeId = \'' +
				recordTypeId +
				'\' ';

			List<TAM_Team__c> pods = Database.query(soql);
			if (pods.size() != 0) {
				for (TAM_Team__c p : pods) {
					ret.put(p.Leader__c, p.Name);
					ret.put(p.Name, p.Leader__c);
				}
			}
		} catch (Exception e) {
			logNebulaException('getPodMap', e);
		}
		return ret;
	}

	public static Map<String, String> getPodOverrideMap(String caseRecordType) {
		Map<String, String> ret = new Map<String, String>();
		try {
			Id recordTypeId = Utility.getRecordTypeIdByAPIName('TAM_Team_Member__c', 'Escalation_Pod');

			String soql =
				'SELECT TAM__c, ' +
				'TAM_Team__r.Name, ' +
				'TAM_Team__r.Leader__c ' +
				'FROM TAM_Team_Member__c ' +
				'WHERE RecordTypeId = \'' +
				recordTypeId +
				'\' ';

			List<TAM_Team_Member__c> aTeams = Database.query(soql);
			if (aTeams.size() != 0) {
				for (TAM_Team_Member__c t : aTeams) {
					ret.put(t.TAM__c, t.TAM_Team__r.Leader__c);
					ret.put(t.TAM_Team__r.Name, t.TAM__c);
				}
			}
		} catch (Exception e) {
			logNebulaException('getPodOverrideMap', e);
		}
		return ret;
	}

	@AuraEnabled
	public static Map<String, String> getEscalationEngineerInfo(
		String team,
		String caseRecordType,
		String level
	) {
		Map<String, String> teamMembers = new Map<String, String>();
		try {
			String specialityGroup = getSpecialityGroup(team, caseRecordType);
			String memberRecordTypeId = getTAMTeamMemberRecordTypeId(caseRecordType);
			String teamRecordTypeId = getTAMTeamRecordTypeId(caseRecordType, null);
			String teamRecordTypeId2 = getTAMTeamRecordTypeId(caseRecordType, 'Speciality');
			if (level.contains('2')) {
				for (TAM_Team_Member__c member : [
					SELECT Slack_Member_ID__c, Slack_Name__c
					FROM TAM_Team_Member__c
					WHERE
						RecordTypeId = :memberRecordTypeId
						AND (TAM_Team__r.RecordTypeId = :teamRecordTypeId
						OR TAM_Team__r.RecordTypeId = :teamRecordTypeId2)
						AND (TAM_Team__r.Name = :team
						OR TAM_Team__r.Name = :specialityGroup
						OR TAM_Team__r.Specialty_Group__r.Name = :specialityGroup)
						AND Responsibility__c IN ('Escalation Engineer')
					ORDER BY Name ASC NULLS LAST
				]) {
					teamMembers.put(member.Slack_Name__c, member.Slack_Member_ID__c);
				}
			} else if (level.contains('3')) {
				for (TAM_Team_Member__c member : [
					SELECT Slack_Member_ID__c, Slack_Name__c
					FROM TAM_Team_Member__c
					WHERE
						RecordTypeId = :memberRecordTypeId
						AND (TAM_Team__r.RecordTypeId = :teamRecordTypeId
						OR TAM_Team__r.RecordTypeId = :teamRecordTypeId2)
						AND TAM_Team__r.Name = :team
						AND Responsibility__c IN ('Principal Escalation Engineer')
					ORDER BY Name ASC NULLS LAST
				]) {
					teamMembers.put(member.Slack_Name__c, member.Slack_Member_ID__c);
				}
			}
		} catch (Exception e) {
			logNebulaException('getEscalationEngineerInfo', e);
		}
		return teamMembers;
	}

	@AuraEnabled
	public static List<Map<String, String>> getPodSMEMap(
		Boolean aggregate,
		String caseRecordType,
		String level
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			Id recordTypeId = getTAMTeamMemberRecordTypeId(caseRecordType);
			Map<String, String> podMap = getPodMap(caseRecordType);
			Map<String, String> podMapOverride = getPodOverrideMap(caseRecordType);
			String soql =
				'SELECT TAM__c, ' +
				'Responsibility__c, ' +
				'Slack_Name__c, ' +
				'TAM_Team__r.Name, ' +
				'TAM_Team__r.Specialty_Group__r.Name, ' +
				'TAM__r.Name, ' +
				'TAM__r.Email, ' +
				'TAM__r.ManagerId, ' +
				'TAM__r.Manager.Manager.Id, ' +
				'TAM__r.Manager.Manager.Manager.Id, ' +
				'TAM__r.Manager.Manager.Manager.Manager.Id, ' +
				'TAM__r.Manager.Manager.Manager.Manager.Manager.Id, ' +
				'TAM__r.UserRole.Name ' +
				'FROM TAM_Team_Member__c ' +
				'WHERE RecordTypeId = \'' +
				recordTypeId +
				'\' ';
			if (level?.contains('2')) {
				soql +=
					'AND Responsibility__c IN (\'Escalation Engineer\'' +
					') ' +
					'ORDER BY Slack_Name__c ASC NULLS LAST';
			} else if (level.contains('3')) {
				soql +=
					'AND Responsibility__c IN (\'Principal Escalation Engineer\'' +
					') ' +
					'ORDER BY Slack_Name__c ASC NULLS LAST';
			} else {
				soql += 'ORDER BY Slack_Name__c ASC NULLS LAST';
			}
			List<TAM_Team_Member__c> members = Database.query(soql);
			List<String> retList = new List<String>();
			for (TAM_Team_Member__c m : members) {
				Map<String, String> sme = new Map<String, String>();
				sme.put('Id', m.TAM__c);
				sme.put('SlackName', m.Slack_Name__c);
				sme.put('Name', m.TAM__r.Name);
				sme.put('Responsiblity', m.Responsibility__c);
				if (nullOrEmpty(m.TAM_Team__r.Specialty_Group__r.Name)) {
					sme.put('Speciality Group', m.TAM_Team__r.Name);
				} else {
					sme.put('Speciality Group', m.TAM_Team__r.Specialty_Group__r.Name);
				}
				if (nullOrEmpty(m.TAM__r.UserRole.Name)) {
					sme.put('Role', '');
				} else {
					sme.put('Role', m.TAM__r.UserRole.Name);
				}
				sme.put('SMETeam', m.TAM_Team__r.Name);
				sme.put('TeamAndResponsiblity', m.TAM_Team__r.Name + ' (' + m.Responsibility__c + ')');
				sme.put('contactemail', m.TAM__r.Email);
				sme.put('Email', m.TAM__r.Email);
				String managerId = m.TAM__r.ManagerId;
				if (podMapOverride.containsKey(m.TAM__c)) {
					managerId = podMapOverride.get(m.TAM__c);
				}
				if (managerId != null) {
					if (podMap.containsKey(managerId)) {
						sme.put('Pod', podMap.get(managerId));
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
						String teamAndResponsiblity = existing.get('TeamAndResponsiblity');
						teamAndResponsiblity += ' | ' + r.get('TeamAndResponsiblity');
						existing.put('TeamAndResponsiblity', teamAndResponsiblity);
					} else {
						agg.put(r.get('SlackName'), r);
					}
				}
				ret = agg.values();
			}
		} catch (Exception e) {
			logNebulaException('getPodSMEMap', e);
		}
		return ret;
	}

	public static String getPriorShadow(String caseId) {
		String ret = '';
		try {
			String soql =
				'SELECT Field, OldValue, NewValue ' +
				'FROM CaseHistory ' +
				'WHERE CaseId = \'' +
				caseId +
				'\' ' +
				'AND Field = \'SME_Shadow__c\' ' +
				'ORDER BY CreatedDate ASC';

			List<CaseHistory> changes = Database.query(soql);
			List<String> smeIds = new List<String>();
			List<String> smeNames = new List<String>();
			if (changes.size() != 0) {
				for (CaseHistory c : changes) {
					if (!nullOrEmpty(c.NewValue)) {
						if (String.valueOf(c.NewValue).contains('005')) {
							smeIds.add(String.valueOf(c.NewValue));
						} else {
							smeNames.add(String.valueOf(c.NewValue));
						}
					}
				}
			}
			String soql2 =
				'SELECT Slack_Name__c, TAM_Team__r.Name, TAM__c ' +
				'FROM TAM_Team_Member__c ' +
				'WHERE (RecordType.Name = \'Escalation_SME\' ' +
				' OR RecordType.Name = \'Escalation SME\') ' +
				'AND TAM__c IN:smeIds';

			List<TAM_Team_Member__c> members = Database.query(soql2);
			Map<String, String> smeMap = new Map<String, String>();
			Map<String, String> smeNameMap = new Map<String, String>();
			for (TAM_Team_Member__c m : members) {
				if (smeMap.containsKey(m.TAM__c)) {
					smeMap.put(m.TAM__c, smeMap.get(m.TAM__c) + ' | ' + m.TAM_Team__r.Name);
				} else {
					smeMap.put(m.TAM__c, m.TAM_Team__r.Name);
				}
				smeNameMap.put(m.TAM__c, m.Slack_Name__c);
			}
			for (String smeId : smeIds) {
				String name = smeNameMap.get(smeId);
				if (name == null) {
					name = [SELECT Name FROM User WHERE Id = :smeId].Name;
				}
				String smeGroup = smeMap.get(smeId);
				if (smeGroup == null) {
					smeGroup = '';
				}
				String nameGroup = name + '(' + smeGroup + ')';
				ret = ret == '' ? nameGroup : ret + ' > ' + nameGroup;
			}
		} catch (Exception e) {
			logNebulaException('getPriorShadow', e);
		}
		return ret;
	}

	public static String getPriorSME(String caseId) {
		String ret = '';
		try {
			String soql =
				'SELECT Field, OldValue, NewValue ' +
				'FROM CaseHistory ' +
				'WHERE CaseId = \'' +
				caseId +
				'\' ' +
				'AND Field = \'SME_OwnerId__c\' ' +
				'ORDER BY CreatedDate ASC';

			List<CaseHistory> changes = Database.query(soql);
			List<String> smeIds = new List<String>();
			List<String> smeNames = new List<String>();
			if (changes.size() != 0) {
				for (CaseHistory c : changes) {
					if (!nullOrEmpty(c.NewValue)) {
						if (String.valueOf(c.NewValue).contains('005')) {
							smeIds.add(String.valueOf(c.NewValue));
						} else {
							smeNames.add(String.valueOf(c.NewValue));
						}
					}
				}
			}
			String soql2 =
				'SELECT Slack_Name__c, TAM_Team__r.Name, TAM__c ' +
				'FROM TAM_Team_Member__c ' +
				'WHERE (RecordType.Name = \'Escalation_SME\' ' +
				' OR RecordType.Name = \'Escalation SME\') ' +
				'AND TAM__c IN:smeIds';

			List<TAM_Team_Member__c> members = Database.query(soql2);
			Map<String, String> smeMap = new Map<String, String>();
			Map<String, String> smeNameMap = new Map<String, String>();
			for (TAM_Team_Member__c m : members) {
				if (smeMap.containsKey(m.TAM__c)) {
					smeMap.put(m.TAM__c, smeMap.get(m.TAM__c) + ' | ' + m.TAM_Team__r.Name);
				} else {
					smeMap.put(m.TAM__c, m.TAM_Team__r.Name);
				}
				smeNameMap.put(m.TAM__c, m.Slack_Name__c);
			}
			for (String smeId : smeIds) {
				String name = smeNameMap.get(smeId);
				if (name == null) {
					name = [SELECT Name FROM User WHERE Id = :smeId].Name;
				}
				String smeGroup = smeMap.get(smeId);
				if (smeGroup == null) {
					smeGroup = '';
				}
				String nameGroup = name + '(' + smeGroup + ')';

				ret = ret == '' ? nameGroup : ret + ' > ' + nameGroup;
			}
		} catch (Exception e) {
			logNebulaException('getPriorSME', e);
		}
		return ret;
	}

	public static String getThreadIdFromEmail(String caseId, String expression) {
		String ret = '';
		if (nullOrEmpty(expression)) {
			return ret;
		}
		try {
			if (expression == 'chronicle') {
				Case_Management__c cm = Case_Management__c.getInstance();
				Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

				if (cmfields.contains('rosco_chronicle_refid_re__c')) {
					if (!nullOrEmpty(cm.get('rosco_chronicle_refid_re__c'))) {
						expression = String.valueOf(cm.get('rosco_chronicle_refid_re__c'));
					} else {
						return ret;
					}
				} else {
					return ret;
				}
			}
			Pattern caseThreadIdPattern = Pattern.compile(expression);
			String soql =
				'SELECT Subject, TextBody, HtmlBody FROM EmailMessage ' +
				'WHERE ParentId = \'' +
				caseId +
				'\'';

			List<EmailMessage> caseemail = Database.query(soql);
			if (caseemail.size() != 0) {
				for (EmailMessage e : caseemail) {
					if (ret == '') {
						Matcher matcher = caseThreadIdPattern.matcher(e.Subject);
						if (matcher.find()) {
							ret = matcher.group(0);
						}
					}
				}
				for (EmailMessage e : caseemail) {
					if (ret == '') {
						String textbody = String.valueOf(e.TextBody);
						if (!nullOrEmpty(textbody)) {
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
						}
					}
				}
				for (EmailMessage e : caseemail) {
					if (ret == '') {
						String htmlbody = String.valueOf(e.HtmlBody);
						if (!nullOrEmpty(htmlbody)) {
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
						}
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('getThreadIdFromEmail', e);
		}
		return ret;
	}

	public static void removeChronicleSupportFromCc(String caseId) {
		try {
			String contactIds;
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			if (cmfields.contains('rosco_chronicle_contactid__c')) {
				if (!nullOrEmpty(cm.get('rosco_chronicle_contactid__c'))) {
					contactIds = String.valueOf(cm.get('rosco_chronicle_contactid__c'));
				}
			}
			if (!nullOrEmpty(contactIds) && !nullOrEmpty(caseId)) {
				String soql = 'select ContactId from CaseContactRole where CasesId=\'' + caseId + '\'';

				List<CaseContactRole> smes = Database.query(soql);
				if (smes.size() != 0) {
					for (CaseContactRole sme : smes) {
						String cid = String.valueOf(sme.ContactId);
						if (contactIds.contains(String.valueOf(sme.ContactId))) {
							delete sme;
						}
					}
					sendChronicleEmailDeEscalated(caseId);
				}
			}
		} catch (Exception e) {
			logNebulaException('removeChronicleSupportFromCc', e);
		}
	}

	public static void removeSMEFromAllCases(String userId) {
		try {
			if (!nullOrEmpty(userId)) {
				String name = [SELECT Name FROM User WHERE Id = :userId].Name;
				String soql =
					'SELECT Id ' +
					'FROM Case ' +
					'WHERE SME_OwnerId__c = \'' +
					userId +
					'\' ' +
					'AND Status NOT IN (\'Closed\', \'Solved\' ) ' +
					'AND Escalation_Tier__c IN (\'Level 2\', \'Level 3\', \'Level 4\', \'Level 5\') ';

				List<Case> cases = Database.query(soql);
				List<FeedItem> items = new List<FeedItem>();
				if (cases.size() != 0) {
					for (Case c : cases) {
						c.SME_OwnerId__c = null;
						FeedItem fi = new FeedItem(
							Body = 'Removing ' + name + ' as engaged SME',
							IsRichText = true,
							NetworkScope = 'AllNetworks',
							Type = 'TextPost',
							Visibility = 'InternalUsers',
							ParentId = c.Id
						);
						items.add(fi);
					}
				}
				update cases;
				insert items;
			}
		} catch (Exception e) {
			logNebulaException('removeSMEFromAllCases', e);
		}
	}

	public static String getSpecialityGroup(String team, String caseRecordType) {
		String specialtyGroup = '';
		try {
			Id recordTypeId = getTAMTeamRecordTypeId(caseRecordType, '');
			for (TAM_Team__c tamTeam : [
				SELECT Specialty_Group__r.Name
				FROM TAM_Team__c
				WHERE Name = :team AND RecordTypeId = :recordTypeId
				LIMIT 1
			]) {
				specialtyGroup = tamTeam.Specialty_Group__r.Name;
			}
		} catch (Exception e) {
			logNebulaException('getSpecialityGroup', e);
		}
		return specialtyGroup;
	}

	public static String getPods(String caseRecordType) {
		String ret = '';
		try {
			Id recordTypeId = getTAMTeamRecordTypeId(caseRecordType, 'Pod');
			String soql =
				'SELECT Name' +
				' FROM TAM_Team__c' +
				' WHERE RecordTypeId = \'' +
				recordTypeId +
				'\' ' +
				' ORDER BY Name ASC NULLS LAST';

			List<TAM_Team__c> aTeams = Database.query(soql);
			if (aTeams.size() != 0) {
				for (TAM_Team__c aTeam : aTeams) {
					if (ret == '') {
						ret = aTeam.Name;
					} else {
						ret = ret + ',' + aTeam.Name;
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('getPods', e);
		}
		return ret;
	}

	@AuraEnabled
	public static void setPodSMEAsCCR(String accountId, String caseId, String team) {
		if (team == 'SME-Chronicle') {
			team = 'SME-Threat Response';
		}
		Map<String, String> account = RoscoUtility.getAccountDetails(accountId);
		String pod = account.get('ptampod');
		if (pod == null) {
			pod = account.get('stampod');
		} else if (pod == '') {
			pod = account.get('stampod');
		}
		if (pod != null) {
			if (pod != '') {
				List<Map<String, String>> peeps = RoscoUtility.getPeopleDetails();
				for (Map<String, String> peep : peeps) {
					String contactid = '';
					if (peep.get('pod') == pod) {
						String p = peep.get('psme');
						String s = peep.get('ssme');
						if (team == 'SME-Platform') {
							p = p.replaceAll('SME-Platform Services', '');
							s = s.replaceAll('SME-Platform Services', '');
						}
						if (p.contains(team) == true) {
							contactid = peep.get('contactid');
						}
						if (s.contains(team) == true) {
							contactid = peep.get('contactid');
						}
					}
					if (contactid != null) {
						if (contactid != '' && contactid != 'not defined') {
							setCcr(contactid, caseId, '');
						}
					}
				}
			}
		}
	}

	@AuraEnabled
	public static String getSMEInfo(
		String accountId,
		String smeTeam,
		String level,
		String caseRecordType
	) {
		String smeInfo = getSMETeamDescription(smeTeam, caseRecordType);
		Map<String, String> teamMembers = new Map<String, String>();
		teamMembers = getEscalationEngineerInfo(smeTeam, caseRecordType, level);
		String escEngineer = teamMembers.keySet().toString().replace('{', '').replace('}', '');
		if (!nullOrEmpty(escEngineer)) {
			smeInfo += '<br/><br/>' + escEngineer;
		}
		return smeInfo;
	}

	/** getShadowLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @smestring - used to exclude from lookup
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getShadowLookup(
		String searchKeyWord,
		String smeteam,
		String smestring,
		String caseId,
		String level,
		String caseRecordType
	) {
		smeteam = smeteam.trim();
		smestring = smestring.trim();
		caseId = caseId.trim();
		searchKeyWord = searchKeyWord.trim();
		List<Map<String, String>> returnList1 = new List<Map<String, String>>();
		List<String> relatedSpecialtyGroups = new List<String>();
		if (!String.isBlank(smeteam)) {
			relatedSpecialtyGroups = getSpecialtyGroupFromEscalationSubTeams(smeteam);
		}
		List<Map<String, String>> podSMEMap = getPodSMEMap(true, caseRecordType, '');

		for (Map<String, String> s : podSMEMap) {
			String responsibility = s.get('Responsiblity');
			s.put('Type', 'Shadow');
			Boolean isRelatedSpecialtyGroupMatch = false;
			Boolean isSpecialtyGroupMatch = false;
			Boolean isSMETeamMatch = false;
			String shadowSpecialtyGroup = s.get('Speciality Group');
			for (String eachSpecialtyGroup : relatedSpecialtyGroups) {
				if (shadowSpecialtyGroup?.contains(eachSpecialtyGroup)) {
					isRelatedSpecialtyGroupMatch = true;
					break;
				}
				if (eachSpecialtyGroup?.contains(smeteam)) {
					isSpecialtyGroupMatch = true;
					break;
				}
			}
			if (s.get('SMETeam').containsIgnoreCase(smeteam)) {
				isSMETeamMatch = true;
			}
			if (isRelatedSpecialtyGroupMatch || isSpecialtyGroupMatch || isSMETeamMatch) {
				Boolean slackNameExists = false;
				for (Map<String, String> eachInReturnList : returnList1) {
					if (eachInReturnList.get('SlackName').equalsIgnoreCase(s.get('SlackName'))) {
						slackNameExists = true;
						break;
					}
				}
				if (!slackNameExists) {
					if (String.isBlank(searchKeyWord)) {
						returnList1.add(s);
					} else if (s.get('SlackName').containsIgnoreCase(searchKeyWord)) {
						returnList1.add(s);
					}
				}
			}
		}
		List<Map<String, String>> returnList = new List<Map<String, String>>();
		returnList.addAll(returnList1);
		return returnList;
	}

	/** getSMELookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @smestring - used to exclude from lookup
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getEscalationEngineer(
		String searchKeyWord,
		String smeteam,
		String smestring,
		String caseId,
		String level,
		String caseRecordType
	) {
		if (nullOrEmpty(searchKeyWord) == true) {
			searchKeyWord = '';
		}
		searchKeyWord = searchKeyWord.trim();
		smeteam = smeteam.trim();
		smestring = smestring.trim();
		caseId = caseId.trim();
		List<Map<String, String>> returnList1 = new List<Map<String, String>>();
		List<Map<String, String>> podSMEMap = getPodSMEMap(true, caseRecordType, level);

		List<String> relatedSpecialtyGroups = new List<String>();
		if (!String.isBlank(smeteam)) {
			relatedSpecialtyGroups = getSpecialtyGroupFromEscalationSubTeams(smeteam);
		}
		String responsibilityType = '';
		Boolean notPrincipal = false;
		if (level.contains('3')) {
			responsibilityType = 'Principal';
		} else {
			responsibilityType = 'Escalation';
		}
		if (String.isBlank(smeteam)) {
			return podSMEMap;
		} else {
			for (Map<String, String> s : podSMEMap) {
				if (s.get('Responsiblity').contains(responsibilityType)) {
					if (level.contains('2') && s.get('Responsiblity').contains('Principal')) {
						//skip this iteration and go to next. We don't want Principal escalation Engineer
						continue;
					}
					Boolean isRelatedSpecialtyGroupMatch = false;
					Boolean isSpecialtyGroupMatch = false;
					Boolean isSMETeamMatch = false;
					String engineerSpecialtyGroup = s.get('Speciality Group');
					if (level.contains('2')) {
						for (String eachSpecialtyGroup : relatedSpecialtyGroups) {
							if (engineerSpecialtyGroup?.contains(eachSpecialtyGroup)) {
								isRelatedSpecialtyGroupMatch = true;
								break;
							}
							if (eachSpecialtyGroup?.contains(smeteam)) {
								isSpecialtyGroupMatch = true;
								break;
							}
						}
					}
					if (s.get('SMETeam').containsIgnoreCase(smeteam)) {
						isSMETeamMatch = true;
					}
					if (isRelatedSpecialtyGroupMatch || isSpecialtyGroupMatch || isSMETeamMatch) {
						if (String.isBlank(searchKeyWord)) {
							returnList1.add(s);
						} else {
							if (s.get('SlackName').containsIgnoreCase(searchKeyWord)) {
								returnList1.add(s);
							}
						}
					}
				}
			}
		}
		List<Map<String, String>> returnList = new List<Map<String, String>>();
		returnList.addAll(returnList1);
		return returnList;
	}

	public static String getUsersAuthorizedLevels() {
		String ret = '';
		try {
			Boolean five = false;
			Boolean four = false;
			Boolean three = false;
			Boolean two = false;
			Boolean one = false;
			String userid = String.valueOf(UserInfo.getUserId());
			List<String> userauthorized = new List<String>();
			String soql = 'SELECT Name' + ',authorized__c' + ' FROM rosco_escalation_rbac__c';

			List<rosco_escalation_rbac__c> aRules = Database.query(soql);
			if (aRules.size() != 0) {
				for (rosco_escalation_rbac__c u : aRules) {
					if (String.valueOf(u.Name) == '5') {
						five = true;
					}
					if (String.valueOf(u.Name) == '4') {
						four = true;
					}
					if (String.valueOf(u.Name) == '3') {
						three = true;
					}
					if (String.valueOf(u.Name) == '2') {
						two = true;
					}
					if (userid == String.valueOf(u.authorized__c)) {
						userauthorized.add(String.valueOf(u.Name));
					}
				}
			}
			if (five != true) {
				if (!userauthorized.contains('5')) {
					userauthorized.add(String.valueOf('5'));
				}
			}
			if (four != true) {
				if (!userauthorized.contains('4')) {
					userauthorized.add(String.valueOf('4'));
				}
			}
			if (three != true) {
				if (!userauthorized.contains('3')) {
					userauthorized.add(String.valueOf('3'));
				}
			}
			if (two != true) {
				if (!userauthorized.contains('2')) {
					userauthorized.add(String.valueOf('2'));
				}
			}
			List<String> prep = new List<String>();
			prep.add('Level 1');
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			if (cmfields.contains('rosco_case_escalation_level_1__c')) {
				String cmlevel1esc = String.valueOf(cm.get('rosco_case_escalation_level_1__c'));
				if (cmlevel1esc != null) {
					if (cmlevel1esc.containsIgnoreCase('true')) {
						prep.add('Level 1');
					}
				}
			}
			if (userauthorized.contains('2')) {
				prep.add('Level 2');
			}
			if (userauthorized.contains('3')) {
				prep.add('Level 3');
			}
			if (userauthorized.contains('4')) {
				prep.add('Level 4');
			}
			if (userauthorized.contains('5')) {
				prep.add('Level 5');
			}
			ret = String.join(prep, ',');
		} catch (Exception e) {
			logNebulaException('getUsersAuthorizedLevels', e);
		}
		return ret;
	}

	public static String getUsersAuthorizedLevels2() {
		String ret = 'Level 1, Level 2, Level 3';
		try {
			UserRole uRole = [SELECT Name FROM UserRole WHERE Id = :UserInfo.getUserRoleId() LIMIT 1];
			if (String.valueOf(uRole.Name).containsIgnoreCase('Principal Escalation Engineer')) {
				ret = ret + ',Level 4';
			} else {
				String soql =
					'SELECT Id ' +
					'FROM PermissionSet ' +
					'WHERE Name = \'Support_Management\'';

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
						ret = ret + ',Level 4';
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('getUsersAuthorizedLevels2', e);
		}
		return ret;
	}

	/** getSMEOwnerLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getSMEOwnerLookup(String searchKeyWord) {
		if (searchKeyWord == null) {
			searchKeyWord = '';
		}
		searchKeyWord = searchKeyWord.trim();
		String searchKey = '%' + searchKeyWord + '%';
		String taniumemail = '%tanium.com';
		List<Map<String, String>> returnList = new List<Map<String, String>>();
		String soql;
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

		List<User> users = Database.query(soql);
		if (!users.isEmpty()) {
			for (User u : users) {
				Map<String, String> people = new Map<String, String>();
				String uid = String.valueOf(u.get('Id'));
				String name = String.valueOf(u.get('Name'));
				String email = String.valueOf(u.get('Email'));
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
		return returnList;
	}

	@AuraEnabled
	public static List<Map<String, String>> getShadowList2(String caseId, String caseRecordType) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			List<Map<String, String>> podSMEMap = getPodSMEMap(true, caseRecordType, '');

			String soql =
				'SELECT Id, ' +
				'SME_Shadow__c, ' +
				'SME_Shadow__r.Email, ' +
				'SME_Shadow__r.Name ' +
				'FROM Case ' +
				'WHERE Id = \'' +
				caseId +
				'\' ' +
				'AND SME_Shadow__c != null';

			List<Case> cases = Database.query(soql);
			if (cases.size() != 0) {
				for (Case c : cases) {
					Map<String, String> shadow = new Map<String, String>();
					shadow.put('Id', c.SME_Shadow__c);
					shadow.put('Email', c.SME_Shadow__r.Email);
					shadow.put('Name', c.SME_Shadow__r.Name);
					shadow.put('contactemail', c.SME_Shadow__r.Email);
					shadow.put('SlackName', '');
					shadow.put('SMETeam', '');
					shadow.put('Pod', '');
					for (Map<String, String> m : podSMEMap) {
						if (m.get('Id') == c.SME_Shadow__c) {
							shadow.put('SlackName', m.get('SlackName'));
							shadow.put('SMETeam', m.get('SMETeam'));
							shadow.put('Pod', m.get('Pod'));
							shadow.put('Role', m.get('Role'));
						}
					}
					ret.add(shadow);
				}
			}
		} catch (DmlException e) {
			logNebulaException('getShadowList2', e);
		}
		return ret;
	}

	@AuraEnabled
	public static List<Map<String, String>> getSMEList(String caseId, String caseRecordType) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			List<Map<String, String>> podSMEMap = getPodSMEMap(true, caseRecordType, '');

			String soql =
				'SELECT Id, ' +
				'Contact.Email ' +
				'FROM CaseContactRole ' +
				'WHERE Role = \'Engaged SME\' ' +
				'AND CasesId = \'' +
				caseId +
				'\'';

			List<CaseContactRole> ccrs = Database.query(soql);
			if (ccrs.size() != 0) {
				for (CaseContactRole c : ccrs) {
					Map<String, String> thissme = new Map<String, String>();
					thissme.put('contactid', c.ContactId);
					thissme.put('contactemail', c.Contact.Email);
					thissme.put('SlackName', 'n/a');
					thissme.put('SMETeam', 'n/a');
					thissme.put('Pod', 'n/a');
					for (Map<String, String> m : podSMEMap) {
						if (m.get('contactemail') == c.Contact.Email) {
							thissme.put('SlackName', m.get('SlackName'));
							thissme.put('SMETeam', m.get('SMETeam'));
							thissme.put('Pod', m.get('Pod'));
							thissme.put('Role', m.get('Role'));
							thissme.put('Name', m.get('Name'));
						}
					}
					if (thissme.get('SMETeam') != 'n/a') {
						ret.add(thissme);
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('getSMEList', e);
		}
		return ret;
	}

	public static String getSMEString(String caseId) {
		String ret = '';
		try {
			List<String> contactIds = new List<String>();
			List<CaseContactRole> ccrlist = [
				SELECT ContactId
				FROM CaseContactRole
				WHERE Role = 'Engaged SME' AND CasesId = :caseId
			];
			for (CaseContactRole c : ccrList) {
				contactIds.add(String.valueOf(c.ContactId));
			}
			List<Map<String, String>> peeps = RoscoUtility.getPeopleDetails();
			for (Map<String, String> peep : peeps) {
				String thissme = '';
				String contactid = String.valueOf(peep.get('contactid'));
				if (contactIds.contains(contactid) == true) {
					String slackname = String.valueOf(peep.get('slackname'));
					String email = String.valueOf(peep.get('contactemail'));
					String sme = String.valueOf(peep.get('psme'));
					sme = sme.replace(';', '|');
					String secondarysme = String.valueOf(peep.get('ssme'));
					if (secondarysme.containsIgnoreCase(';') == true) {
						List<String> parts = secondarysme.split(';');
						for (String part : parts) {
							if (sme.containsIgnoreCase(part) == false) {
								sme += '|' + part;
							}
						}
					}
					if (ret == '') {
						ret = thissme;
					} else {
						ret += ';' + thissme;
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('getSMEString', e);
		}
		return ret;
	}

	public static List<String> getSpecialtyGroupFromEscalationSubTeams(String smeTeam) {
		List<String> specialtyGroups = new List<String>();
		List<TAM_Team__c> aTeams = new List<TAM_Team__c>(
			[
				SELECT Name, Description__c, EscalationSubTeams__c
				FROM TAM_Team__c
				WHERE RecordType.DeveloperName = 'Escalation_Speciality_Group'
			]
		);
		if (!String.isBlank(smeTeam)) {
			for (TAM_Team__c eachTeam : aTeams) {
				if (
					eachTeam.EscalationSubTeams__c != null &&
					eachTeam.EscalationSubTeams__c.contains(smeTeam)
				) {
					specialtyGroups.add(eachTeam.Name);
				}
			}
		}
		return specialtyGroups;
	}

	public static String getSMETeamDescription(String smeTeam, String caseRecordType) {
		String ret =
			'Not sure which Escalation Team to select? ' +
			'Try selecting a team in the drop down.  You should see ' +
			'additional information here.';
		try {
			Id recordTypeId = getTAMTeamRecordTypeId(caseRecordType, null);
			List<TAM_Team__c> tamTeams = [
				SELECT Description__c
				FROM TAM_Team__c
				WHERE Name = :smeTeam AND RecordTypeId = :recordTypeId
			];
			if (!tamTeams.isEmpty()) {
				ret = tamTeams[0].Description__c;
			}
		} catch (Exception e) {
			logNebulaException('getSMETeamDescription', e);
		}
		return ret;
	}

	public static String getSMETeams(String caseRecordType) {
		String ret = '';
		try {
			Id recordTypeId = getTAMTeamRecordTypeId(caseRecordType, null);
			String soql =
				'SELECT Name' +
				' FROM TAM_Team__c' +
				' WHERE RecordTypeId = \'' +
				recordTypeId +
				'\' ' +
				' ORDER BY Name ASC NULLS LAST';

			List<TAM_Team__c> aTeams = Database.query(soql);
			if (aTeams.size() != 0) {
				for (TAM_Team__c aTeam : aTeams) {
					if (ret == '') {
						ret = aTeam.Name;
					} else {
						ret = ret + ',' + aTeam.Name;
					}
				}
			}
		} catch (Exception e) {
			logNebulaException('getSMETeams', e);
		}
		return ret;
	}

	@AuraEnabled
	public static String saveCase(
		String caseId,
		String level,
		String pod,
		String smegroup,
		String deescinput,
		String escinput,
		String escartifact,
		String critsit,
		List<Map<String, String>> smes
	) {
		return saveCase(
			caseId,
			level,
			pod,
			smegroup,
			deescinput,
			escinput,
			escartifact,
			critsit,
			smes,
			new List<Map<String, String>>(),
			null,
			null
		);
	}

	@AuraEnabled
	public static String saveCase(
		String caseId,
		String level,
		String pod,
		String smegroup,
		String deescinput,
		String escinput,
		String escartifact,
		String critsit,
		List<Map<String, String>> smes,
		List<Map<String, String>> shadows,
		String status,
		String hydra
	) {
		String ret;
		if (smegroup == null) {
			return 'smegroup is required, exiting...';
		}
		if (deescinput == null) {
			deescinput = '';
		}
		deescinput = deescinput.trim();
		if (escinput == null) {
			escinput = '';
		}
		escinput = escinput.trim();
		escinput = escinput.replaceAll('<', ' ');
		escinput = escinput.replaceAll('>', ' ');
		if (escartifact == null) {
			escartifact = '';
		}
		escartifact = escartifact.trim();
		escartifact = escartifact.replaceAll('<', ' ');
		escartifact = escartifact.replaceAll('>', ' ');
		try {
			Case c = [
				SELECT
					SME_Shadow__r.Name,
					SME_OwnerId__r.Name,
					Tags__c,
					Escalation_Team__c,
					Escalation_Pod__c,
					Escalation_Status__c,
					Escalation_Tier__c,
					Escalation_Reason__c,
					Escalation_Artifact__c,
					AccountId,
					Account.Name,
					CaseNumber,
					Subject,
					RecordType.Name
				FROM Case
				WHERE Id = :caseid
				LIMIT 1
			];
			String caseNumber = c.CaseNumber;
			String caseSubject = c.Subject;
			String caseRefId = EmailMessages.getFormattedThreadingToken(c.Id);
			String accountName = c.Account.Name;
			String existing_team = c.Escalation_Team__c;
			String existing_level = c.Escalation_Tier__c;
			String existing_status = c.Escalation_Status__c;
			String existing_reason = c.Escalation_Reason__c;
			String existing_artifact = c.Escalation_Artifact__c;
			String existing_shadow = c.SME_Shadow__r.Name;
			String existing_sme = c.SME_OwnerId__r.Name;
			String existing_pod = c.Escalation_Pod__c;
			String existingpost = getLatestCasePost(caseId);

			String newsme = 'None';
			if (smes.size() == 0) {
				c.SME_OwnerId__c = null;
			} else {
				newsme = smes[0].get('Name');
			}
			String newshadow = 'None';
			if (shadows.size() == 0) {
				c.SME_Shadow__c = null;
			} else {
				c.SME_Shadow__c = shadows[0].get('Id');
				newshadow = shadows[0].get('Name');
			}
			String tags = String.isNotBlank(c.Tags__c) ? c.Tags__c : '';
			if (hydra == 'Yes') {
				String hydraTag = 'HydraReporting';
				if (existing_level == 'Level 1') {
					hydraTag = 'HydraReportingL1';
				} else if (existing_level == 'Level 2') {
					hydraTag = 'HydraReportingL2';
				} else if (existing_level == 'Level 3') {
					hydraTag = 'HydraReportingL3';
				} else if (existing_level == 'Level 4') {
					hydraTag = 'HydraReportingL4';
				}
				if (!tags.containsIgnoreCase(hydraTag)) {
					c.Tags__c = tags + ' ' + hydraTag;
				}
			} else if (hydra == 'No' && String.isNotBlank(tags)) {
				c.Tags__c = tags.replace('HydraReportingL1', '')
					.replace('HydraReportingL2', '')
					.replace('HydraReportingL3', '')
					.replace('HydraReportingL4', '')
					.normalizeSpace();
			}
			if (level == 'Level 1') {
				c.Escalation_Reason__c = deescinput;
				c.Escalation_Artifact__c = null;
				c.Escalation_Tier__c = null;
				c.Escalation_Type__c = null;
				c.IsEscalated = false;
				smegroup = 'None';
			} else {
				c.Escalation_Team__c = smegroup;
				c.Escalation_Reason__c = escinput;
				c.Escalation_Artifact__c = escartifact;
				c.Escalation_Tier__c = level;
				c.Escalation_Type__c = 'General';
				c.IsEscalated = true;
				c.Escalation_Pod__c = pod;
				c.Escalation_Status__c = status;
				if (existing_level != level) {
					c.Escalation_Date__c = Datetime.now();
				}
			}
			update c;
			List<Map<String, String>> existing_smes = getSMEList(caseId, c.RecordType.Name);
			String smestring = '';
			if (smes.size() != 0) {
				for (Map<String, String> sme : smes) {
					if (smestring == '') {
						smestring = sme.get('contactemail');
					} else {
						smestring = smestring + ';' + sme.get('contactemail');
					}
				}
			}
			for (Map<String, String> shadow : shadows) {
				String soql =
					'SELECT Id ' +
					'FROM Contact ' +
					'WHERE Email = \'' +
					shadow.get('Email') +
					'\'';

				List<Contact> contacts = Database.query(soql);
				if (!contacts.isEmpty()) {
					for (Contact contact : contacts) {
						setCcr(contact.Id, c.Id, '');
					}
				} else {
					String smeAccountId = '0013200001D3n0nAAB';
					List<Account> tanInc = [SELECT Id FROM Account WHERE Name = 'Tanium Inc.' LIMIT 1];
					if (tanInc.size() > 0) {
						smeAccountId = tanInc[0].Id;
					}
					Contact contact = new Contact(
						Email = shadow.get('Email'),
						LastName = shadow.get('Email').left(50),
						AccountId = smeAccountId
					);
					insert contact;
					setCcr(contact.Id, c.Id, '');
				}
			}
			String newsmestoslack = '';

			if (String.isBlank(existing_sme)) {
				existing_sme = 'None';
			}
			if (String.isBlank(existing_shadow)) {
				existing_shadow = 'None';
			}
			if (String.isBlank(existing_status)) {
				existing_status = 'blank';
			}
			if (String.isBlank(existing_team)) {
				existing_team = 'blank';
			}
			String escalationBody = buildEscalationBody(
				accountName,
				existing_level,
				existing_team,
				existing_status,
				existing_sme,
				existing_shadow,
				existing_reason,
				existing_artifact,
				level,
				status,
				smegroup,
				newsme,
				newshadow,
				escinput,
				deescinput,
				escartifact
			);

			if (level.contains('1')) {
				if (String.isNotBlank(escalationBody)) {
					RoscoUtility.addCasePostRich(caseId, escalationBody);
				}
				smestring = '';
				setSmeViaString(smestring, caseId, c.RecordType.Name);
				setSMEOwner(caseId);
			} else {
				setSmeViaString(smestring, caseId, c.RecordType.Name);
				setSMEOwner(caseId);
				if (String.isNotBlank(escalationBody)) {
					RoscoUtility.addCasePostRich(caseId, escalationBody);
				}
			}

			if (level.contains('4') && (smegroup == 'SME-Chronicle')) {
				addChronicleSupportToCc(caseId);
				sendChronicleEmail(caseId, caseNumber, caseSubject, caseRefId, escinput, escartifact);
			}
			if (level.contains('2') || level.contains('3') || level.contains('4')) {
				if (existing_level != level || existing_team != smegroup) {
					Boolean isDescalationWithSME = false;
					if (smestring != '') {
						if (level.contains('3') && existing_level.contains('4')) {
							isDescalationWithSME = true;
						} else if (
							level.contains('2') &&
							(existing_level.contains('3') || existing_level.contains('4'))
						) {
							isDescalationWithSME = true;
						}
					}
					if (!isDescalationWithSME) {
						sendToEscalationSlack(caseId, level, pod, smegroup, escinput, escartifact);
					}
				}
			}
			if (newsmestoslack != '') {
				sendToEscalationSlackNewSME(caseId, level, smegroup, newsmestoslack);
			}
			if (existing_team == 'SME-Chronicle' && existing_level.contains('4')) {
				if (!level.contains('4') || smegroup != 'SME-Chronicle') {
					removeChronicleSupportFromCc(caseId);
				}
			}
		} catch (Exception e) {
			logNebulaException('saveCase', e);
		}
		return ret;
	}

	@TestVisible
	private static String buildEscalationBody(
		String accountName,
		String existing_level,
		String existing_team,
		String existing_status,
		String existing_sme,
		String existing_shadow,
		String existing_reason,
		String existing_artifact,
		String level,
		String status,
		String smegroup,
		String newsme,
		String newshadow,
		String escinput,
		String deescinput,
		String escartifact
	) {
		String escalationBody = '';
		Boolean isEscalationLevelUpdate = existing_level != level;
		Boolean isEscalationUpdate = isEscalationLevelUpdate;

		escalationBody += '<p><b><u>Escalation Update</u></b></p>';
		if (isEscalationLevelUpdate || existing_team != smegroup) {
			escalationBody += '<p>SME Group: ' + smegroup;
			if (existing_team != smegroup) {
				escalationBody += ' (changed from ' + existing_team + ')';
				isEscalationUpdate = true;
			}
			escalationBody += '</p>';
		}
		if (isEscalationLevelUpdate) {
			escalationBody += '<p>Level: ' + level + ' (changed from ' + existing_level + ')</p>';
		}
		if (isEscalationLevelUpdate || existing_status != status) {
			escalationBody += '<p>Status: ' + status;
			if (existing_status != status) {
				escalationBody += ' (changed from ' + existing_status + ')';
				isEscalationUpdate = true;
			}
			escalationBody += '</p>';
		}
		if (isEscalationLevelUpdate && level.contains('1')) {
			escalationBody += '<p>&nbsp;</p><p>&nbsp;</p><p><b><u>De-Escalation Reason</u></b></p>';
			escalationBody += '<p>' + deescinput + '</p>';
		} else {
			if (isEscalationLevelUpdate || existing_sme != newsme) {
				escalationBody += '<p>&nbsp;</p><p><b><u>Engaged:</u></b></p>';
				escalationBody += '<p>' + newsme;
				if (existing_sme != newsme) {
					escalationBody += ' (changed from ' + existing_sme + ')';
					isEscalationUpdate = true;
				}
				escalationBody += '</p>';
			}
			if (isEscalationLevelUpdate || existing_shadow != newshadow) {
				escalationBody += '<p>&nbsp;</p><p><b><u>Shadow:</u></b></p>';
				escalationBody += '<p>' + newshadow;
				if (existing_shadow != newshadow) {
					escalationBody += ' (changed from ' + existing_shadow + ')';
					isEscalationUpdate = true;
				}
				escalationBody += '</p>';
			}
			if (isEscalationLevelUpdate) {
				escalationBody += '<p>&nbsp;</p><p><b><u>Account</u></b></p>';
				escalationBody += '<p>' + accountName + '</p>';
			}
			if (existing_reason != escinput) {
				escalationBody += '<p>&nbsp;</p><p>&nbsp;</p><p><b><u>Escalation Reason (changed)</u></b></p>';
				escalationBody +=
					'<p>' +
					escinput.replaceAll('\n', '<p>&nbsp;</p>').abbreviate(5000) +
					'</p>';
				isEscalationUpdate = true;
			} else if (isEscalationLevelUpdate) {
				escalationBody += '<p>&nbsp;</p><p>&nbsp;</p><p><b><u>Escalation Reason (unchanged)</u></b></p>';
				escalationBody +=
					'<p>' +
					escinput.replaceAll('\n', '<p>&nbsp;</p>').abbreviate(5000) +
					'</p>';
			}
			if (existing_artifact != escartifact) {
				escalationBody += '<p>&nbsp;</p><p>&nbsp;</p><p><b><u>Escalation Artifacts (changed)</u></b></p>';
				escalationBody +=
					'<p>' +
					escartifact.replaceAll('\n', '<p>&nbsp;</p>').abbreviate(1000) +
					'</p><p>&nbsp;</p>';
				isEscalationUpdate = true;
			} else if (isEscalationLevelUpdate) {
				escalationBody += '<p>&nbsp;</p><p>&nbsp;</p><p><b><u>Escalation Artifacts (unchanged)</u></b></p>';
				escalationBody +=
					'<p>' +
					escartifact.replaceAll('\n', '<p>&nbsp;</p>').abbreviate(1000) +
					'</p><p>&nbsp;</p>';
			}
		}
		return isEscalationLevelUpdate || isEscalationUpdate ? escalationBody : '';
	}

	public static void sendChronicleEmail(
		String caseId,
		String caseNumber,
		String caseSubject,
		String caseRefId,
		String reason,
		String artifacts
	) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D20e0000004DjCCAU';
			if (cmfields.contains('rosco_owea_support__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea_support__c'))) {
					owea = String.valueOf(cm.get('rosco_owea_support__c'));
				}
			}
			String expression;
			if (cmfields.contains('rosco_chronicle_refid_re__c')) {
				if (!nullOrEmpty(cm.get('rosco_chronicle_refid_re__c'))) {
					expression = String.valueOf(cm.get('rosco_chronicle_refid_re__c'));
				}
			}
			String chronicleRefId = getThreadIdFromEmail(caseId, expression);
			caseRefId = caseRefId.replace('ref', '');
			caseRefId = caseRefId.replace(':', '');
			String refString = '';
			if (!nullOrEmpty(caseRefId)) {
				refString = caseRefId;
			}
			if (!nullOrEmpty(chronicleRefId)) {
				refString = refString + ',' + chronicleRefId;
			}
			refString = 'ref:' + refString + ':ref';
			if (chronicleRefId != null) {
				if (chronicleRefId != '') {
					if (!caseSubject.containsIgnoreCase(chronicleRefId)) {
						caseSubject += ' [ ref:' + chronicleRefId + ':ref ]';
					}
				}
			}
			String htmlbody = '<html><body>';
			htmlbody += '<b>Summary</b><br>';
			htmlbody += reason + '<br><br>';
			htmlbody += '<b>Artifacts</b><br>';
			htmlbody += artifacts + '<br><br>';
			htmlbody += '<br><br>' + refString;
			htmlbody += '</body></html>';
			String textbody = 'Summary\n';
			textbody += '================\n';
			textbody += reason + '\n\n';
			textbody += 'Reason\n';
			textbody += '================\n';
			textbody += reason + '\n\n' + refString;
			List<String> cc = new List<String>();
			if (!nullOrEmpty(caseId) && !caseSubject.containsIgnoreCase('roscotestcase')) {
				List<CaseContactRole> ccr = [
					SELECT Contact.Email
					FROM CaseContactRole
					WHERE CasesId = :caseId
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
			}
			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setOrgWideEmailAddressId(owea);
			mail.setToAddresses(cc);
			mail.setSubject(caseNumber + ':' + caseSubject);
			mail.setHtmlBody(htmlbody);
			mail.setPlainTextBody(textbody);
			mail.setWhatId(caseId);
			mail.setSaveAsActivity(true);
			if (!caseSubject.containsIgnoreCase('roscotestcase')) {
				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
		} catch (Exception e) {
			logNebulaException('sendChronicleEmail', e);
		}
	}

	public static void sendChronicleEmailDeEscalated(String caseId) {
		try {
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D260000000XZFg';
			if (cmfields.contains('rosco_owea_noreply__c')) {
				if (!nullOrEmpty(cm.get('rosco_owea_noreply__c'))) {
					owea = String.valueOf(cm.get('rosco_owea_noreply__c'));
				}
			}
			String expression;
			if (cmfields.contains('rosco_chronicle_refid_re__c')) {
				if (!nullOrEmpty(cm.get('rosco_chronicle_refid_re__c'))) {
					expression = String.valueOf(cm.get('rosco_chronicle_refid_re__c'));
				}
			}
			String chronicleRefId = getThreadIdFromEmail(caseId, expression);
			String contactIds;
			if (cmfields.contains('rosco_chronicle_contactid__c')) {
				if (!nullOrEmpty(cm.get('rosco_chronicle_contactid__c'))) {
					contactIds = String.valueOf(cm.get('rosco_chronicle_contactid__c'));
				}
			}
			List<String> to = new List<String>();
			if (contactIds != null) {
				if (contactIds != '') {
					if (contactIds.containsAny(',')) {
						List<String> csplit = contactIds.split(',');
						for (String c : csplit) {
							String cemail = getContactEmail(c);
							if (!nullOrEmpty(cemail)) {
								to.add(cemail);
							}
						}
					} else {
						setCcr(contactIds, caseId, null);
					}
				}
			}
			Case c = [
				SELECT Escalation_Team__c, Escalation_Tier__c, AccountId, CaseNumber, Subject
				FROM Case
				WHERE Id = :caseid
				LIMIT 1
			];
			String caseNumber = c.CaseNumber;
			String caseSubject = c.Subject;
			String caseRefId = EmailMessages.getFormattedThreadingToken(c.Id).replace('ref', '');
			caseRefId = caseRefId.replace(':', '');
			String refString = '';
			if (!nullOrEmpty(caseRefId)) {
				refString = caseRefId;
			}
			if (!nullOrEmpty(chronicleRefId)) {
				refString = refString + ',' + chronicleRefId;
			}
			refString = 'ref:' + refString + ':ref';
			String htmlbody = '<html><body>';
			htmlbody += '<b>Summary</b><br>';
			htmlbody += 'Case has been descalated at Tanium please remove support@tanium.com from future replies.<br><br>';
			htmlbody += '<br><br>' + refString;
			htmlbody += '</body></html>';
			String textbody = 'Summary\n';
			textbody += '================';
			textbody += 'Case has been descalated at Tanium - please remove support@tanium.com from future replies.\n\n';
			textbody += refString;
			if (!nullOrEmpty(to)) {
				Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
				mail.setOrgWideEmailAddressId(owea);
				mail.setToAddresses(to);
				mail.setSubject(caseNumber + ':' + caseSubject);
				mail.setHtmlBody(htmlbody);
				mail.setPlainTextBody(textbody);
				if (!caseSubject.containsIgnoreCase('roscotestcase')) {
					Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
				}
			}
		} catch (Exception e) {
			logNebulaException('sendChronicleEmailDeEscalated', e);
		}
	}

	public static void sendToEscalationSlack(
		String caseId,
		String level,
		String pod,
		String smegroup,
		String escinput,
		String escartifact
	) {
		try {
			escinput = escinput.replaceAll('<p>', '\n');
			escinput = escinput.replaceAll('\\n', '\n');
			Case aCase = RoscoUtility.getCaseDetails(caseId);
			Map<String, String> state = RoscoCaseProcesses.getCaseState(caseId);
			Map<String, String> settings = RoscoCaseProcesses.getEscalationTeamSettings(
				state.get('model'),
				state.get('escalationTeam'),
				state.get('escalationLevel'),
				Decimal.valueOf(state.get('severity')),
				aCase.RecordType.Name
			);
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String caseLink = System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + aCase.ID;
			if (
				cmfields.contains('rosco_case_url_prefix__c') &&
				cmfields.contains('rosco_sfdc_dom_l__c')
			) {
				String urlprefix = String.valueOf(cm.get('rosco_case_url_prefix__c'));
				String urlfriend = String.valueOf(cm.get('rosco_sfdc_dom_l__c'));
				if (nullOrEmpty(urlprefix) == false && nullOrEmpty(urlfriend) == false) {
					caseLink =
						'<' +
						urlprefix +
						aCase.ID +
						'/view|https://' +
						urlfriend +
						'/lightning/r/Case/' +
						aCase.ID +
						'/view>';
					caseLink +=
						' <https://' +
						urlfriend +
						'/lightning/r/Case/' +
						aCase.ID +
						'/view|(alt)>';
				}
			}
			String accountChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String ac = String.valueOf(cm.get('rosco_slack_exceptions__c'));
				if (nullOrEmpty(ac) == false) {
					accountChannel = ac;
				}
			}
			String webhookURL = '';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));
				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}
			String contact_from;
			if (String.isBlank(aCase.ContactEmail)) {
				contact_from = aCase.SuppliedEmail;
			} else {
				contact_from = aCase.ContactEmail;
			}
			String sev = String.valueOf(aCase.Severity_Community__c).left(1);
			String caseNumber = aCase.CaseNumber;
			// Add context for level
			String emoji = (aCase.RecordType.Name == 'Support')
				? ':rosco_alert:'
				: ':rosco_internal-escalation:';
			String fallbackPretext =
				emoji +
				' *' +
				level +
				' ' +
				aCase.RecordType.Name +
				' Escalation (' +
				smegroup +
				')* ';
			fallbackPretext +=
				'requested for Sev *' +
				sev +
				'* Case *' +
				caseNumber +
				'* for *' +
				contact_from +
				'*';

			List<Map<String, Object>> fieldsInternalListSME = new List<Map<String, Object>>();
			List<Map<String, Object>> fieldsInternalListAccount = new List<Map<String, Object>>();
			Map<String, Object> fieldsInternalMap = new Map<String, Object>();
			fieldsInternalMap.put('title', '*' + aCase.subject + '*');
			fieldsInternalMap.put('text', '*' + aCase.subject + '*');
			fieldsInternalMap.put('value', caseLink);
			fieldsInternalMap.put('short', false);
			fieldsInternalListSME.add(fieldsInternalMap);
			fieldsInternalListAccount.add(fieldsInternalMap);

			Map<String, Object> fieldsInternalMapSev = new Map<String, Object>();
			fieldsInternalMapSev.put('title', 'Severity:');
			fieldsInternalMapSev.put('value', sev);
			fieldsInternalMapSev.put('short', false);
			fieldsInternalListSME.add(fieldsInternalMapSev);
			fieldsInternalListAccount.add(fieldsInternalMapSev);

			Map<String, Object> fieldsInternalMapUser = new Map<String, Object>();
			fieldsInternalMapUser.put('title', 'Who Escalated:');
			fieldsInternalMapUser.put('value', UserInfo.getName());
			fieldsInternalMapUser.put('short', false);
			fieldsInternalListSME.add(fieldsInternalMapUser);
			fieldsInternalListAccount.add(fieldsInternalMapUser);

			if (nullOrEmpty(aCase.AccountId) == false) {
				Account anAccount = [
					SELECT id, name, Slack_Channel_Id__c, Support_Model__c, Premium_Support__c
					FROM account
					WHERE id = :aCase.AccountId
				];
				if (!String.isBlank(anAccount.Slack_Channel_Id__c)) {
					accountChannel = anAccount.Slack_Channel_Id__c;
					String sLink =
						'<https://tanium.slack.com/messages/' +
						anAccount.Slack_Channel_Id__c +
						'| Channel Id: ' +
						anAccount.Slack_Channel_Id__c +
						'>';
					String soql2 =
						'SELECT Id,Name FROM rosco_account__c ' +
						'WHERE account__c= \'' +
						anAccount.Id +
						'\' ' +
						'AND (NOT Name LIKE \'a8q%\')';

					List<Rosco_Account__c> slacknames = Database.query(soql2);
					if (slacknames.size() != 0) {
						sLink =
							'<https://tanium.slack.com/messages/' +
							anAccount.Slack_Channel_Id__c +
							'|#' +
							slacknames[0].Name +
							'>';
					}
					Map<String, Object> fieldsInternalMap2 = new Map<String, Object>();
					fieldsInternalMap2.put('title', 'Customer Channel:');
					fieldsInternalMap2.put('value', sLink);
					fieldsInternalMap2.put('short', false);
					fieldsInternalListSME.add(fieldsInternalMap2);
				}
			}

			Map<String, Object> fieldsInternalMap3 = new Map<String, Object>();
			fieldsInternalMap3.put('title', 'Component:');
			fieldsInternalMap3.put('value', aCase.Component__c);
			fieldsInternalMap3.put('short', false);
			fieldsInternalListSME.add(fieldsInternalMap3);
			fieldsInternalListAccount.add(fieldsInternalMap3);

			if (nullOrEmpty(aCase.Escalation_Reason__c) == false) {
				Map<String, Object> fieldsInternalMap5 = new Map<String, Object>();
				fieldsInternalMap5.put('title', 'Escalation Reason:');
				fieldsInternalMap5.put('value', escinput);
				fieldsInternalMap5.put('short', false);
				fieldsInternalListSME.add(fieldsInternalMap5);
				fieldsInternalListAccount.add(fieldsInternalMap5);
				if (!nullOrEmpty(escartifact)) {
					if (escartifact != '(Presales SME Engagement)') {
						escartifact = escartifact.replaceAll('\\n', '\n');
						Map<String, Object> fieldsInternalMap6 = new Map<String, Object>();
						fieldsInternalMap6.put('title', 'Escalation Artifacts:');
						fieldsInternalMap6.put('value', escartifact);
						fieldsInternalMap6.put('short', false);
						fieldsInternalListSME.add(fieldsInternalMap6);
						fieldsInternalListAccount.add(fieldsInternalMap6);
					}
				}
			}

			if (nullOrEmpty(aCase.Escalation_Reason__c) == false) {
				String peopleonccr;
				if (!aCase.subject.containsIgnoreCase('roscotestcase')) {
					peopleonccr = RoscoUtility.getSlackNamesFromCCR(caseId);
				}
				if (peopleonccr != null) {
					Map<String, Object> fieldsInternalMap7 = new Map<String, Object>();
					fieldsInternalMap7.put('title', 'Case Contacts:');
					fieldsInternalMap7.put('value', peopleonccr);
					fieldsInternalMap7.put('short', false);
					fieldsInternalListAccount.add(fieldsInternalMap7);
				}
			}
			List<String> mrkdwnList = new List<String>();
			mrkdwnList.add('text');
			mrkdwnList.add('pretext');
			Map<String, Object> attInternalMapAccount = new Map<String, Object>();
			attInternalMapAccount.put('mrkdwn_in', mrkdwnList);
			attInternalMapAccount.put('fallback', fallbackPretext);
			attInternalMapAccount.put('pretext', fallbackPretext);
			attInternalMapAccount.put('color', '#D00000');
			attInternalMapAccount.put('fields', fieldsInternalListAccount);
			List<Map<String, Object>> attInternalListAccount = new List<Map<String, Object>>();
			attInternalListAccount.add(attInternalMapAccount);
			JSONGenerator genAccount = JSON.createGenerator(true);
			genAccount.writeStartObject();
			if (URL.getSalesforceBaseUrl().getHost() != 'tanium.my.salesforce.com') {
				genAccount.writeStringField('channel', 'CCC66LTRT');
			} else {
				genAccount.writeStringField('channel', accountChannel);
			}
			genAccount.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			genAccount.writeStringField('link_names', 'true');
			genAccount.writeFieldName('attachments');
			genAccount.writeObject(attInternalListAccount);
			genAccount.writeEndObject();
			String bodyAccount = genAccount.getAsString();
			if (!aCase.Subject.contains('ROSCOTESTCASE')) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', bodyAccount));
			}
			String smeString = '';
			if (!nullOrEmpty(settings.get('escalationSlackGroups').split(','))) {
				List<String> smeGroupList = settings.get('escalationSlackGroups').split(',');
				for (String grp : smeGroupList) {
					smeString = smeString == '' ? '@' + grp : smeString + ' @' + grp;
				}
			}

			Map<String, String> teamMembers = new Map<String, String>();
			List<String> podSmeList = new List<String>();
			teamMembers = getEscalationEngineerInfo(smegroup, aCase.RecordType.Name, level);
			String escEngineer = teamMembers.keySet().toString().replace('{', '').replace('}', '');
			if (!nullOrEmpty(escEngineer)) {
				podSmeList = escEngineer.split(',');
			}
			String podString = '';
			try {
				if (!nullOrEmpty(aCase.SME_OwnerId__c)) {
					TAM_Team_Member__c tm = [
						SELECT Slack_Member_ID__c, Slack_Name__c
						FROM TAM_Team_Member__c
						WHERE Slack_Name__c != NULL AND TAM__c = :aCase.SME_OwnerId__c
						LIMIT 1
					];
					if (aCase.SME_OwnerId__c == UserInfo.getUserId()) {
						podString = tm.Slack_Name__c + ' engaged as SME (added themself)';
					} else {
						String slackUser = String.isNotBlank(tm.Slack_Member_ID__c)
							? tm.Slack_Member_ID__c
							: tm.Slack_Name__c;
						podString =
							'<@' +
							slackUser +
							'> engaged as SME (added by ' +
							UserInfo.getName() +
							')';
					}
				}
			} catch (Exception e) {
				logNebulaException('sendToEscalationSlack', e);
			}
			if (podString == '') {
				for (String podSme : podSmeList) {
					String slackUsername = podSme.trim();
					String slackMemberId = teamMembers.get(slackUsername);
					String slackUser = String.isNotBlank(slackMemberId) ? slackMemberId : slackUsername;
					if (!podString.containsIgnoreCase(slackUser)) {
						podString = podString == ''
							? '<@' + slackUser + '> '
							: podString + ' <@' + slackUser + '>';
					}
				}
			}
			if (podString.containsIgnoreCase('No Pod SME')) {
				podString =
					'No Pod SMEs for ' +
					smegroup +
					' in pod ' +
					pod +
					'. Alerting ' +
					smeString;
			}
			Map<String, Object> fieldsSME2 = new Map<String, Object>();
			fieldsSME2.put('title', 'POD SMEs/Escalation Engineers:');
			fieldsSME2.put('value', podString);
			fieldsSME2.put('short', false);
			fieldsInternalListSME.add(fieldsSME2);

			Map<String, Object> attInternalMapSME = new Map<String, Object>();
			attInternalMapSME.put('mrkdwn_in', mrkdwnList);
			attInternalMapSME.put('fallback', fallbackPretext);
			attInternalMapSME.put('pretext', fallbackPretext);
			attInternalMapSME.put('color', '#D00000');
			attInternalMapSME.put('fields', fieldsInternalListSME);

			List<Map<String, Object>> attInternalListSME = new List<Map<String, Object>>();
			attInternalListSME.add(attInternalMapSME);

			List<String> channels = settings.get('escalationSlackChannels').split(',');
			List<String> alreadySlacked = new List<String>();
			for (String channel : channels) {
				JSONGenerator genSME = JSON.createGenerator(true);
				genSME.writeStartObject();
				genSME.writeStringField('channel', channel);
				genSME.writeStringField('link_names', 'true');
				genSME.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
				genSME.writeFieldName('attachments');
				genSME.writeObject(attInternalListSME);
				genSME.writeEndObject();
				String bodySME = genSME.getAsString();
				if (!Test.isRunningTest()) {
					System.enqueueJob(new qCallOut(webhookURL, 'POST', bodySME));
				}
			}
		} catch (Exception e) {
			logNebulaException('sendToEscalationSlack', e);
		}
	}

	public static void sendToEscalationSlackNewSME(
		String caseId,
		String level,
		String smegroup,
		String newsmes
	) {
		try {
			Case aCase = RoscoUtility.getCaseDetails(caseId);
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String caseLink = System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + aCase.ID;
			if (
				cmfields.contains('rosco_case_url_prefix__c') &&
				cmfields.contains('rosco_sfdc_dom_l__c')
			) {
				String urlprefix = String.valueOf(cm.get('rosco_case_url_prefix__c'));
				String urlfriend = String.valueOf(cm.get('rosco_sfdc_dom_l__c'));
				if (nullOrEmpty(urlprefix) == false && nullOrEmpty(urlfriend) == false) {
					caseLink =
						'<' +
						urlprefix +
						aCase.ID +
						'%2Fview|https://' +
						urlfriend +
						'/lightning/r/Case/' +
						aCase.ID +
						'/view>';
					caseLink +=
						' <https://' +
						urlfriend +
						'/lightning/r/Case/' +
						aCase.ID +
						'/view|(alt)>';
				}
			}
			String accountChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String ac = String.valueOf(cm.get('rosco_slack_exceptions__c'));
				if (nullOrEmpty(ac) == false) {
					accountChannel = ac;
				}
			}
			String accountchannelname = '';
			if (
				URL.getSalesforceBaseUrl().getHost() != 'tanium.my.salesforce.com' &&
				!Test.isRunningTest()
			) {
				accountChannel = 'CCC66LTRT';
				accountchannelname = '#<https://tanium.slack.com/messages/CCC66LTRT|#rosco-debug>';
			} else {
				if (nullOrEmpty(aCase.AccountId) == false) {
					Account anAccount = [
						SELECT id, name, Slack_Channel_Id__c, Premium_Support__c
						FROM account
						WHERE id = :aCase.AccountId
					];
					if (!String.isBlank(anAccount.Slack_Channel_Id__c)) {
						accountChannel = anAccount.Slack_Channel_Id__c;

						String soql2 =
							'SELECT Name FROM rosco_account__c ' +
							'WHERE account__c= \'' +
							anAccount.Id +
							'\'';

						List<Rosco_Account__c> slacknames = Database.query(soql2);
						if (slacknames.size() != 0) {
							String slackname;
							slackname = String.valueOf(slacknames[0].Name);
							if (nullOrEmpty(slackname) == false) {
								accountchannelname =
									'<https://tanium.slack.com/messages/' +
									anAccount.Slack_Channel_Id__c +
									'|#' +
									slackname +
									'>';
							}
						}
					}
				}
			}
			String webhookURL = '';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}
			String caseNumber = aCase.CaseNumber;
			String accounttext =
				'Escalation FYI:' +
				newsmes +
				' engaging as SME on ' +
				'<https://tanium.lightning.force.com/lightning/r/Case/' +
				caseId +
				'%2Fview|' +
				aCase.CaseNumber +
				':' +
				aCase.Subject +
				'>';

			JSONGenerator genAccount = JSON.createGenerator(true);
			genAccount.writeStartObject();
			genAccount.writeStringField('text', accounttext);
			genAccount.writeStringField('username', 'rosco');
			if (URL.getSalesforceBaseUrl().getHost() != 'tanium.my.salesforce.com') {
				genAccount.writeStringField('channel', 'CCC66LTRT');
			} else {
				genAccount.writeStringField('channel', accountChannel);
			}
			genAccount.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			genAccount.writeStringField('link_names', 'true');
			genAccount.writeEndObject();
			String bodyAccount = genAccount.getAsString();
			if (!aCase.Subject.contains('ROSCOTESTCASE')) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', bodyAccount));
			}
		} catch (Exception e) {
			logNebulaException('sendToEscalationSlackNewSME', e);
		}
	}

	@AuraEnabled
	public static void setSmeOwner(String caseId) {
		try {
			List<CaseContactRole> caseContactRoles = [
				SELECT Contact.Email
				FROM CaseContactRole
				WHERE CasesId = :caseId AND Role = 'Engaged SME'
				ORDER BY CreatedDate DESC
				LIMIT 1
			];
			if (!caseContactRoles.isEmpty()) {
				List<User> users = [
					SELECT Id
					FROM User
					WHERE
						Email = :caseContactRoles[0].Contact.Email
						AND IsActive = TRUE
						AND UserType = 'Standard'
				];

				if (!users.isEmpty()) {
					Case c = [SELECT Id FROM Case WHERE Id = :caseId];
					c.SME_OwnerId__c = users[0].Id;
					update c;
				}
			}
		} catch (Exception e) {
			logNebulaException('setSmeOwner', e);
		}
	}

	@AuraEnabled
	public static List<Map<String, String>> setSmeViaString(
		String smestring,
		String caseId,
		String caseRecordType
	) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			if (!nullOrEmpty(caseId)) {
				Case_Management__c cm = Case_Management__c.getInstance();
				Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
				String contactid_exclusion = '0030e00002JnUQcAAN';
				if (cmfields.contains('rosco_contactid_exclusion__c')) {
					contactid_exclusion = String.valueOf(cm.get('rosco_contactid_exclusion__c'));
				}
				String fallback_accountid = '0010e00001JOFGPAA5';
				if (cmfields.contains('rosco_case_accountid__c')) {
					fallback_accountid = String.valueOf(cm.get('rosco_case_accountid__c'));
				}
				String smeAccountId = '0013200001D3n0nAAB';
				List<Account> tanInc = [SELECT Id FROM Account WHERE Name = 'Tanium Inc.' LIMIT 1];
				if (tanInc.size() > 0) {
					smeAccountId = tanInc[0].Id;
				}
				clearSme(caseId);
				List<string> smes = new List<string>();
				if (smestring.contains(';')) {
					List<String> smesplit = smestring.split(';');
					smes.addAll(smesplit);
				} else {
					smes.add(smestring);
				}

				if (smestring != '') {
					Set<String> smesset = new Set<String>();
					smesset.addAll(smes);
					List<String> smesnodup = new List<String>();
					smesnodup.addAll(smesset);
					String newsmelist = String.join(smesnodup, ';');
					String smeClause = RoscoUtility.getCleanWhereClause(newsmelist);
					String soql =
						'SELECT Id,Email,AccountId FROM Contact ' +
						'WHERE email IN (' +
						smeClause +
						')';

					List<Contact> cs = Database.query(soql);
					for (String s : smesnodup) {
						Boolean isContact = false;
						if (!cs.isEmpty()) {
							for (Contact c : cs) {
								if (c.Email == s) {
									isContact = true;
									setCcr(c.Id, caseId, 'Engaged SME');
								}
							}
						}
						if (!isContact) {
							Contact c = new Contact(
								Email = s,
								LastName = s.left(50),
								AccountId = smeAccountId
							);
							insert c;
							setCcr(c.Id, caseId, 'Engaged SME');
						}
					}
				}
			}
			ret = getSMEList(caseId, caseRecordType);
		} catch (Exception e) {
			logNebulaException('setSmeViaString', e);
		}
		return ret;
	}

	public static void setCcr(String contactid, String caseid, String role) {
		try {
			CaseContactRole NewCcr = new CaseContactRole(
				CasesId = caseid,
				ContactId = contactid,
				Role = role
			);
			upsert NewCcr;
		} catch (DmlException e) {
			logNebulaException('setCcr', e);
		}
	}

	public static String getContactEmail(String contactId) {
		String ret = null;

		try {
			List<Contact> contacts = [SELECT Email FROM Contact WHERE Id = :contactId];
			if (!contacts.IsEmpty()) {
				ret = contacts[0].Email;
			}
		} catch (DmlException e) {
			logNebulaException('getContactEmail', e);
		}
		return ret;
	}

	@TestVisible
	private static void logNebulaException(String method, Exception e) {
		Logger.error('RoscoEscalate.' + method + ' Errors', e).addTag('apex').addTag('rosco');
		Logger.saveLog();
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