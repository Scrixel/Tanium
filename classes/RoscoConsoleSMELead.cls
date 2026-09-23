public with sharing class RoscoConsoleSMELead {
	public static Map<String, Map<String, String>> getCases(Integer daysBack) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();

		String soql =
			'SELECT Id, Account.Name, CaseNumber,Subject, Component__c  ' +
			'FROM Case ' +
			'WHERE Escalation_Date__c =  LAST_N_DAYS:' +
			daysBack;

		System.debug('SOQL: ' + soql);
		List<Case> cases = Database.query(soql);

		for (Case c : cases) {
			Map<String, String> caseObj = new Map<String, String>();
			caseObj.put('Account', c.Account.Name);
			caseObj.put('CaseNumber', c.CaseNumber);
			caseObj.put('Subject', c.Subject);
			caseObj.put('Component', c.Component__c);

			ret.put(c.Id, caseObj);
		}
		return ret;
	}

	public static Map<String, String> getLabor(Set<String> keys) {
		Map<String, String> ret = new Map<String, String>();

		String soql = 'SELECT Case__c, Minutes__c FROM Rosco_Time__c WHERE Case__c IN :keys';

		System.debug('SOQL: ' + soql);
		List<Rosco_Time__c> rt = Database.query(soql);

		for (Rosco_Time__c r : rt) {
			String caseId = String.valueOf(r.Case__c);
			Integer min = Integer.valueOf(r.Minutes__c);

			if (ret.containsKey(caseId)) {
				Integer totalMin = min + Integer.valueOf(ret.get(caseId));
				ret.put(caseId, String.valueOf(totalMin));
			} else {
				ret.put(caseId, String.valueOf(min));
			}
		}

		return ret;
	}

	public static Map<String, Map<String, String>> getEscHistory(Set<String> keys) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();

		String soql =
			'SELECT ParentId, Body ' +
			'FROM CaseFeed ' +
			'WHERE ParentId IN :keys ' +
			'ORDER BY CreatedDate ASC';

		System.debug('SOQL: ' + soql);
		List<CaseFeed> cfs = Database.query(soql);

		for (CaseFeed cf : cfs) {
			String parentId = String.valueOf(cf.ParentId);
			String levelHistory = '1';
			String groupHistory = '';

			if (ret.containsKey(cf.parentId)) {
				Map<String, String> levelHistoryObj = ret.get(parentId);
				levelHistory = levelHistoryObj.get('level');
				groupHistory = levelHistoryObj.get('group');
			}

			if (cf.Body != null) {
				if (cf.Body.contains('Escalation')) {
					List<String> lines = new List<String>();
					lines = String.valueOf(cf.Body).split('\n');

					for (String line : lines) {
						// Level
						if (line.contains('Level:')) {
							List<String> aLines = line.split('\\(');
							String smeLevel = aLines[0];
							smeLevel = smeLevel.replace('Level: Level ', '');
							smeLevel = smeLevel.left(1);

							if (smeLevel == '1' || smeLevel == '2' || smeLevel == '3' || smeLevel == '4') {
								if (levelHistory != '') {
									String lastLevel = levelHistory.right(1);
									if (lastLevel != smeLevel) {
										levelHistory = levelHistory + '>' + smeLevel;
									}
								} else {
									levelHistory = smeLevel;
								}
							}
						}

						// SME Group
						if (line.contains('SME Group:')) {
							List<String> aLines = line.split('\\(');
							String smeGroup = aLines[0];
							smeGroup = smeGroup.replace('SME Group: ', '');
							smeGroup = smeGroup.replace(
								'<p>Escalation Update</p><p>=======================</p><p>',
								''
							);
							smeGroup = smeGroup.trim();

							if (groupHistory == '') {
								groupHistory = smeGroup;
							} else if (groupHistory.right(smeGroup.length()) == smeGroup) {
								//nothing
							} else {
								groupHistory += '>' + smeGroup;
							}
						}

						// Add to ret

						Map<String, String> history = new Map<String, String>();
						history.put('level', levelHistory);
						history.put('group', groupHistory);
						ret.put(cf.ParentId, history);
					}
				}
			}
		}
		return ret;
	}

	/** getEscalationHistory
	 */
	@AuraEnabled
	public static String getEscalationHistory() {
		Map<String, Map<String, String>> cases = getCases(60);
		SET<String> keys = cases.keyset();
		System.debug(cases.size());
		//Map<String,String> levels = getLevels(keys);
		Map<String, Map<String, String>> history = getEscHistory(keys);
		Map<String, String> labor = getLabor(keys);

		String csv = '';
		csv = 'Id,CaseNumber,Subject,Account,Component,Escalation Levels, Escalation Groups,Case Minutes\n';
		for (String k : keys) {
			Map<String, String> caseObj = cases.get(k);
			Map<String, String> escHistory = history.get(k);

			String caseId = k;
			System.debug(caseId);
			csv += caseId;

			String caseNumber = caseObj.get('CaseNumber');
			System.debug(caseNumber);
			csv += ',' + caseNumber;

			String caseSubject = caseObj.get('Subject');
			System.debug(caseSubject);
			caseSubject = caseSubject.replace(',', ' ');
			csv += ',' + caseSubject;

			String caseAccount = caseObj.get('Account');
			caseAccount = caseAccount.replace(',', ' ');
			System.debug(caseAccount);
			csv += ',' + caseAccount;

			String component = caseObj.get('Component');
			System.debug(component);
			csv += ',' + component;

			String level = 'error';
			try {
				level = escHistory.get('level');
				System.debug(level);
			} catch (Exception e) {
				System.debug(e.getMessage() + '\n' + e.getStackTraceString());
			}
			csv += ',' + level;

			String smegroup = 'error';
			try {
				smegroup = escHistory.get('group');
				System.debug(smegroup);
			} catch (Exception e) {
				System.debug(e.getMessage() + '\n' + e.getStackTraceString());
			}

			csv += ',' + smegroup;

			String caseMinutes = 'error';
			try {
				caseMinutes = labor.get(k);
				if (caseMinutes == null) {
					caseMinutes = '0';
				}
				System.debug(caseMinutes);
				csv += ',' + caseMinutes;
			} catch (Exception e) {
				System.debug(e.getMessage() + '\n' + e.getStackTraceString());
			}

			csv += ',' + caseMinutes;

			csv += '\n';
		}
		return csv;
	}
}