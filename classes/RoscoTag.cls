/**
 * @Business: RoscoTag, controller class for (Case) Tag tab
 * @Date: 8/4/2019
 * @Authors: Jason Johnson, Tanium Dev Team
 * @Request: ??
 * RequestId  ModifiedDate  Description
 * SS-9601    2024-11-01    Updated method getTagLookupJira plus class cleanup
 */
public with sharing class RoscoTag {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** attachArticlesReferenced
	 * @param caseId - case to retrieve Case escalation info
	 * @return Map of Escalation Info
	 */
	@AuraEnabled
	public static void attachArticlesReferenced(String caseId) {
		try {
			List<String> artifacts = new List<String>();
			String soqlFeed = 'SELECT Body ' + 'FROM CaseFeed ' + 'WHERE ParentId= \'' + caseId + '\' ';

			List<CaseFeed> feeds = Database.query(soqlFeed);
			if (!feeds.isEmpty()) {
				for (CaseFeed f : feeds) {
					artifacts.add(String.valueOf(f.Body));
				}
			}
			String soqlEmail =
				'SELECT HtmlBody,TextBody  ' +
				'FROM EmailMessage ' +
				'WHERE ParentId= \'' +
				caseId +
				'\' ';

			List<EmailMessage> emails = Database.query(soqlEmail);
			if (!emails.isEmpty()) {
				for (EmailMessage e : emails) {
					artifacts.add(String.valueOf(e.HtmlBody));
					artifacts.add(String.valueOf(e.TextBody));
				}
			}
			String soqlUrl =
				'SELECT UrlName,Title,KnowledgeArticleId ' +
				'FROM Knowledge__kav ' +
				'WHERE KnowledgeArticleId NOT IN(SELECT KnowledgeArticleId ' +
				'FROM CaseArticle ' +
				'WHERE CaseId != \'' +
				caseId +
				'\')';
			List<Knowledge__kav> kbs = Database.query(soqlUrl);
			List<CaseArticle> caseArticles = new List<caseArticle>();
			Set<String> alreadyAdded = new Set<String>();
			List<String> urls = new List<String>();
			for (String a : artifacts) {
				if (!nullOrEmpty(a)) {
					for (Knowledge__kav kb : kbs) {
						if (a.containsIgnoreCase(kb.UrlName)) {
							if (!alreadyAdded.contains(kb.KnowledgeArticleId)) {
								CaseArticle ca = new CaseArticle();
								ca.CaseId = caseId;
								ca.KnowledgeArticleId = kb.KnowledgeArticleId;
								caseArticles.add(ca);
								alreadyAdded.add(kb.KnowledgeArticleId);
							}
						}
					}
				}
			}
			insert caseArticles;
		} catch (DmlException e) {
			System.debug('attachArticlesReferenced:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	/** getAttachedArticles
	 * @param caseId
	 * @return List of tags on case
	 */
	@AuraEnabled
	public static List<Map<String, String>> getAttachedArticles(String caseId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		try {
			List<String> artifacts = new List<String>();
			String soql =
				'SELECT CreatedDate, ' +
				'KnowledgeArticleId, ' +
				'KnowledgeArticleVersion.ArticleNumber,' +
				'KnowledgeArticleVersion.Title, ' +
				'KnowledgeArticleVersion.UrlName, ' +
				'KnowledgeArticleVersion.Summary, ' +
				'KnowledgeArticleVersion.ArticleCaseAttachCount ' +
				'FROM CaseArticle ' +
				'WHERE CaseId = \'' +
				caseId +
				'\'';

			List<CaseArticle> caseArticles = Database.query(soql);
			if (!caseArticles.isEmpty()) {
				for (CaseArticle ca : caseArticles) {
					Map<String, String> tmpmap = new Map<String, String>();
					String tId = '';
					if (!nullOrEmpty(ca.KnowledgeArticleId)) {
						tId = String.valueOf(ca.KnowledgeArticleId).trim();
					}
					tmpmap.put('Id', tId);
					String tNumber = '';
					if (!nullOrEmpty(ca.KnowledgeArticleVersion.ArticleNumber)) {
						tNumber = String.valueOf(ca.KnowledgeArticleVersion.ArticleNumber).trim();
					}
					tmpmap.put('Tag', tNumber);
					String tTitle = '';
					if (!nullOrEmpty(ca.KnowledgeArticleVersion.Title)) {
						tTitle = String.valueOf(ca.KnowledgeArticleVersion.Title).trim();
					}
					tmpmap.put('Title', tTitle);
					String handyURL = '';
					if (!nullOrEmpty(ca.KnowledgeArticleVersion.UrlName)) {
						handyURL =
							'https://tanium.lightning.force.com/servlet/networks/switch?networkId=0DB0e000000Caez&startURL=s/article/' +
							String.valueOf(ca.KnowledgeArticleVersion.UrlName).trim();
					}
					tmpmap.put('HandyURL', handyURL);
					String tType = 'Knowledge Base';
					tmpmap.put('Type', tType);
					String tDescription = '';
					if (!nullOrEmpty(ca.KnowledgeArticleVersion.Summary)) {
						tDescription = String.valueOf(ca.KnowledgeArticleVersion.Summary).abbreviate(64).trim();
					}
					tmpmap.put('Description', tDescription);
					String tSolution = '';
					tmpmap.put('Solution', tSolution);
					String tCaseCount = '';
					if (!nullOrEmpty(ca.KnowledgeArticleVersion.ArticleCaseAttachCount)) {
						tCaseCount = String.valueOf(ca.KnowledgeArticleVersion.ArticleCaseAttachCount).trim();
					}
					tmpmap.put('Cases', tCaseCount);
					ret.add(tmpmap);
				}
			}
		} catch (DmlException e) {
			System.debug('attachArticlesReferenced:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getCaseAccountOpportunities
	 * @param caseId
	 * @return List of opportunities on Account
	 */
	@AuraEnabled
	public static List<Map<String, String>> getCaseAccountOpportunities(String caseId) {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		Id accountId = [SELECT AccountId FROM Case WHERE Id = :caseId].AccountId;
		String soql =
			'SELECT Id, Name ' +
			'FROM Opportunity ' +
			'WHERE AccountId = \'' +
			accountId +
			'\'';

		List<Opportunity> opps = Database.query(soql);
		if (!opps.isEmpty()) {
			for (Opportunity o : opps) {
				Map<String, String> opp = new Map<String, String>();
				opp.put('label', o.Name);
				opp.put('value', o.Id);
				ret.add(opp);
			}
		}
		return ret;
	}

	/** getExistingCaseMaps
	 * @param caseId
	 * @return
	 */
	public static Map<String, Rosco_Tag_Map__c> getExistingCaseMaps(String caseId) {
		Map<String, Rosco_Tag_Map__c> ret = new Map<String, Rosco_Tag_Map__c>();
		List<Rosco_Tag_Map__c> existingMaps = [
			SELECT
				Id,
				tag__c,
				Account__c,
				Case__c,
				Comment__c,
				Impact__c,
				Jira_Issue__c,
				Name,
				Opportunity__c
			FROM Rosco_Tag_Map__c
			WHERE Case__c = :caseId
		];
		if (existingMaps.size() != null) {
			for (Rosco_Tag_Map__c tMap : existingMaps) {
				ret.put(tMap.tag__c, tMap);
			}
		}
		return ret;
	}

	/** getExistingCaseTags
	 * @param caseId
	 * @return
	 */
	public static Map<String, Rosco_Tag__c> getExistingCaseTags(List<String> tags) {
		Map<String, Rosco_Tag__c> ret = new Map<String, Rosco_Tag__c>();
		List<Rosco_Tag__c> existingTags = [
			SELECT Id, description__c, Name, solution__c, type__c
			FROM Rosco_Tag__c
			WHERE Name IN :tags
		];
		if (existingTags.size() != null) {
			for (Rosco_Tag__c tag : existingTags) {
				if (nullOrEmpty(tag.description__c)) {
					tag.description__c = '';
				}

				if (nullOrEmpty(tag.solution__c)) {
					tag.solution__c = '';
				}

				ret.put(tag.Name, tag);
			}
		}
		return ret;
	}

	/** getJiraIssueSFId
	 * @param tagId
	 * @return List of tags on account
	 */
	public static Map<String, String> getJiraIssueSFId(List<String> tags) {
		Map<String, String> ret = new Map<String, String>();
		try {
			List<Jira_Issue__c> jRs = [
				SELECT Id, Issue_Key__c
				FROM Jira_Issue__c
				WHERE Issue_Key__c IN :tags
			];
			if (jRs.size() != null) {
				for (Jira_Issue__c j : jRs) {
					ret.put(String.valueOf(j.Issue_Key__c), String.valueOf(j.Id));
				}
			}
		} catch (DmlException e) {
			System.debug('getJiraIssueSFId:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getModuleOptions
	 * @return List of tags on case
	 */
	@AuraEnabled
	public static List<Map<String, String>> getModuleOptions() {
		List<Map<String, String>> ret = new List<Map<String, String>>();
		StaticResource sr = [
			SELECT Id, Body
			FROM StaticResource
			WHERE Name = 'rosco_tag_module_translations'
			LIMIT 1
		];
		String body = sr.Body.toString();
		Map<String, Object> srObj = (Map<String, Object>) JSON.deserializeUntyped(body);
		Map<String, Object> map1 = (Map<String, Object>) srObj;
		Map<String, String> translation = new Map<String, String>();
		for (String key : map1.keyset()) {
			translation.put(key, (String) map1.get(key));
		}
		Schema.DescribeFieldResult fieldResult = Rosco_Tag_Map__c.Module__c.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for (Schema.PicklistEntry f : ple) {
			Map<String, String> o = new Map<String, String>();
			if (translation.containsKey(f.getLabel())) {
				o.put('label', translation.get(f.getLabel()));
			} else {
				o.put('label', f.getLabel());
			}
			o.put('value', f.getValue());
			ret.add(o);
		}
		return ret;
	}

	/** getTagsCase
	 * @param caseId
	 * @return List of tags on case
	 */
	@AuraEnabled
	public static String getTagsCase(String caseId) {
		String ret = '';
		try {
			String soql = 'SELECT Tags__c ' + 'FROM Case ' + 'WHERE Id = \'' + caseId + '\'';
			List<Case> caseRs = Database.query(soql);
			String tags = '';
			if (caseRs.size() != 0) {
				for (Case r : caseRs) {
					ret = r.Tags__c;
				}
			}
		} catch (DmlException e) {
			System.debug('getTagsCase:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getTagsCase2
	 * @param caseId
	 * @return List of tags on case
	 */
	@AuraEnabled
	public static List<Map<String, String>> getTagsCase2(String caseId) {
		List<Map<String, String>> ret = getAttachedArticles(caseId);
		try {
			String soql =
				'SELECT Id,Tag_Number__c, Name, type__c, description__c, solution__c ' +
				'FROM Rosco_Tag__c ' +
				'WHERE Id IN (SELECT tag__c FROM Rosco_Tag_Map__c ' +
				'WHERE Case__c = \'' +
				caseId +
				'\')';

			List<Rosco_Tag__c> tagRs = Database.query(soql);
			if (tagRs.size() != 0) {
				Map<String, Map<String, String>> mapInfo = getTagMapInfo(caseId);
				for (Rosco_Tag__c c : tagRs) {
					Map<String, String> tmpmap = new Map<String, String>();
					String tId = '';
					if (!nullOrEmpty(c.Id)) {
						tId = String.valueOf(c.Id).trim();
					}
					tmpmap.put('Id', tId);
					String tNumber = '';
					if (!nullOrEmpty(c.Tag_Number__c)) {
						tNumber = String.valueOf(c.Tag_Number__c).trim();
					}
					tmpmap.put('Tag', tNumber);
					String tTitle = '';
					if (!nullOrEmpty(c.Name)) {
						tTitle = String.valueOf(c.Name).trim();
					}
					tmpmap.put('Title', tTitle);
					String handyURL = '';
					if (!nullOrEmpty(c.Name)) {
						handyURL = 'https://jira.corp.tanium.com/browse/' + String.valueOf(c.Name).trim();
					}
					tmpmap.put('HandyURL', handyURL);
					String tType = '';
					if (!nullOrEmpty(c.type__c)) {
						tType = String.valueOf(c.type__c).trim();
					}
					tmpmap.put('Type', tType);
					if (c.type__c == 'Legacy (String)') {
						tmpmap.put('IsEditable', 'false');
					} else {
						tmpmap.put('IsEditable', 'true');
					}
					String tDescription = '';
					if (!nullOrEmpty(c.description__c)) {
						tDescription = String.valueOf(c.description__c).trim();
					}
					tmpmap.put('Description', tDescription);
					String tSolution = '';
					if (!nullOrEmpty(c.solution__c)) {
						tSolution = String.valueOf(c.solution__c).trim();
					}
					tmpmap.put('Solution', tSolution);
					String tCaseCount = getTagCaseCount(tId);
					tmpmap.put('Cases', tCaseCount);
					Map<String, String> mapInfoDetail = mapInfo.get(tId);
					String tOpportunityId = mapInfoDetail.get('OpportunityId');
					if (nullOrEmpty(tOpportunityId) || tOpportunityId == 'null') {
						tOpportunityId = '';
					}
					tmpmap.put('OpportunityId', tOpportunityId);
					String tOpportunityName = mapInfoDetail.get('OpportunityName');
					if (nullOrEmpty(tOpportunityName) || tOpportunityName == 'null') {
						tOpportunityName = '';
					}
					tmpmap.put('OpportunityName', tOpportunityName);
					String tModule = mapInfoDetail.get('Module');
					if (nullOrEmpty(tModule) || tModule == 'null') {
						tModule = '';
					}
					tmpmap.put('Module', tModule);
					String tImpact = mapInfoDetail.get('Impact');
					if (nullOrEmpty(tImpact) || tImpact == 'null') {
						tImpact = '';
					}
					tmpmap.put('Impact', tImpact);
					String tComment = mapInfoDetail.get('Comment');
					if (nullOrEmpty(tComment) || tComment == 'null') {
						tComment = '';
					}
					tmpmap.put('Comment', tComment);
					ret.add(tmpmap);
				}
			}
		} catch (DmlException e) {
			System.debug('getTagsCase2:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getJiraLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @tagstring - used to exclude from lookup
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getJiraLookup(
		String searchKeyWord,
		String tagstring,
		String caseId
	) {
		if (searchKeyword == null) {
			searchKeyWord = '';
		}
		searchKeyWord = searchKeyWord.trim();
		String searchKey = '%' + searchKeyWord + '%';
		List<Map<String, String>> returnList = new List<Map<String, String>>();
		String alreadytag = RoscoUtility.getCleanWhereClause(String.valueOf(tagstring));
		String soql;
		if (searchKeyWord == '') {
			soql =
				'SELECT Id,Name,description__c, Tag_Number__c, type__c,solution__c,moreinfo__c FROM Rosco_Tag__c ' +
				'WHERE Name NOT IN (' +
				alreadytag +
				') ' +
				'ORDER BY Name DESC LIMIT 10';
		} else {
			soql =
				'SELECT Id, Name,description__c, Tag_Number__c, type__c,solution__c,moreinfo__c FROM Rosco_Tag__c ' +
				'WHERE Name NOT IN (' +
				alreadytag +
				') ' +
				'AND (Name LIKE \'%' +
				searchKeyWord +
				'%\' ' +
				'OR Tag_Number__c LIKE \'%' +
				searchKeyWord +
				'%\') ' +
				'ORDER BY Name DESC LIMIT 10';
		}

		List<Rosco_Tag__c> tags = Database.query(soql);
		if (!tags.isEmpty()) {
			for (Rosco_Tag__c t : tags) {
				String tId = String.valueOf(t.get('Id'));
				String tNumber = String.valueOf(t.get('Tag_Number__c'));
				String type = String.valueOf(t.get('type__c'));
				String name = String.valueOf(t.get('Name'));
				String description = String.valueOf(t.get('description__c'));
				Map<String, String> tag = new Map<String, String>();
				tag.put('Id', tId);
				tag.put('Number', tNumber);
				tag.put('Type', type);
				tag.put('Name', name);
				if (nullOrEmpty(description)) {
					tag.put('Description', '');
				} else {
					tag.put('Description', description.stripHtmlTags());
				}
				returnList.add(tag);
			}
		}
		return returnList;
	}

	/** getTagLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @tagstring - used to exclude from lookup
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getTagLookup(
		String searchKeyWord,
		String tagstring,
		String caseId
	) {
		if (searchKeyword == null) {
			searchKeyWord = '';
		}
		searchKeyWord = searchKeyWord.trim();
		String searchKey = '%' + searchKeyWord + '%';
		List<Map<String, String>> returnList = new List<Map<String, String>>();
		String alreadytag = RoscoUtility.getCleanWhereClause(String.valueOf(tagstring));
		String soql;
		if (searchKeyWord == '') {
			soql =
				'SELECT Id,Name,description__c, Tag_Number__c, type__c,solution__c,moreinfo__c FROM Rosco_Tag__c ' +
				'WHERE Name NOT IN (' +
				alreadytag +
				') ' +
				'AND type__c != \'JIRA\' ' +
				'ORDER BY Name ASC LIMIT 5';
		} else {
			soql =
				'SELECT Id, Name,description__c, Tag_Number__c, type__c,solution__c,moreinfo__c FROM Rosco_Tag__c ' +
				'WHERE Name NOT IN (' +
				alreadytag +
				') ' +
				'AND (Name LIKE \'%' +
				searchKeyWord +
				'%\' ' +
				'OR Tag_Number__c LIKE \'%' +
				searchKeyWord +
				'%\') ' +
				'AND type__c != \'JIRA\' ' +
				'ORDER BY Name ASC LIMIT 5';
		}
		List<Rosco_Tag__c> tags = Database.query(soql);
		if (!tags.isEmpty()) {
			for (Rosco_Tag__c t : tags) {
				String tId = String.valueOf(t.get('Id'));
				String tNumber = String.valueOf(t.get('Tag_Number__c'));
				String type = String.valueOf(t.get('type__c'));
				String name = String.valueOf(t.get('Name'));
				String description = String.valueOf(t.get('description__c'));
				Map<String, String> tag = new Map<String, String>();
				tag.put('Id', tId);
				tag.put('Number', tNumber);
				tag.put('Type', type);
				tag.put('Title', name);
				if (nullOrEmpty(description)) {
					tag.put('Description', '');
				} else {
					tag.put('Description', description.stripHtmlTags());
				}
				returnList.add(tag);
			}
		}
		List<Map<String, String>> jiras = getTagLookupJira(searchKeyWord, tagstring, caseId);
		returnList.addAll(jiras);
		return returnList;
	}

	/** getTagLookup - used by lightning component to readahead
	 * @param search - read ahead value
	 * @tagstring - used to exclude from lookup
	 * @caseid - case id used to lookup account
	 * @return List of possible new case contact role emails
	 */
	@AuraEnabled
	public static List<Map<String, String>> getTagLookupJira(
		String searchKeyWord,
		String tagstring,
		String caseId
	) {
		if (searchKeyword == null) {
			searchKeyWord = '';
		}
		searchKeyWord = searchKeyWord.trim();
		String searchKey = '%' + searchKeyWord + '%';
		List<Map<String, String>> returnList = new List<Map<String, String>>();
		String alreadytag = RoscoUtility.getCleanWhereClause(String.valueOf(tagstring));
		String soql;
		if (searchKeyWord == '') {
			soql =
				'SELECT Id, Issue_Key__c,Issue_Summary__c FROM Jira_Issue__c ' +
				'WHERE Issue_Key__c NOT IN (' +
				alreadytag +
				') ' +
				'ORDER BY Issue_Key__c ASC LIMIT 15';
		} else {
			soql =
				'SELECT Id, Issue_Key__c,Issue_Summary__c FROM Jira_Issue__c ' +
				'WHERE Issue_Key__c NOT IN (' +
				alreadytag +
				') ' +
				'AND (Issue_Key__c LIKE \'' +
				searchKeyWord +
				'%\') ' +
				'ORDER BY Issue_Key__c ASC LIMIT 15';
		}

		List<Jira_Issue__c> tags = Database.query(soql);
		if (!tags.isEmpty()) {
			for (Jira_Issue__c t : tags) {
				String tId = String.valueOf(t.get('Id'));
				String tNumber = 'JIRA';
				String type = 'JIRA';
				String name = String.valueOf(t.get('Issue_Key__c'));
				String description = String.valueOf(t.get('Issue_Summary__c'));
				Map<String, String> tag = new Map<String, String>();
				tag.put('Id', tId);
				tag.put('Number', tNumber);
				tag.put('Type', type);
				tag.put('Title', name);
				if (nullOrEmpty(description)) {
					tag.put('Description', '');
				} else {
					tag.put('Description', description.stripHtmlTags());
				}
				returnList.add(tag);
			}
		}
		return returnList;
	}

	/** getTagCaseCount
	 * @param tagId
	 * @return List of tags on account
	 */
	public static String getTagCaseCount(String tagId) {
		String ret = '0';
		try {
			Integer counter = [SELECT COUNT() FROM Rosco_Tag_Map__c WHERE tag__c = :tagId];
			ret = String.valueOf(counter);
		} catch (DmlException e) {
			System.debug('getTagCaseCount:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** getTagMapInfo
	 * @param tagId
	 * @return List of tags on account
	 */
	public static Map<String, Map<String, String>> getTagMapInfo(String caseId) {
		Map<String, Map<String, String>> ret = new Map<String, Map<String, String>>();
		try {
			String soql =
				'SELECT tag__c, Impact__c, Opportunity__c,Opportunity__r.Name,Comment__c,Module__c ' +
				'FROM Rosco_Tag_Map__c ' +
				'WHERE Case__c = \'' +
				caseId +
				'\'';

			List<Rosco_Tag_Map__c> tagRs = Database.query(soql);
			if (tagRs.size() != 0) {
				for (Rosco_Tag_Map__c tag : tagRs) {
					Map<String, String> t = new Map<String, String>();
					t.put('Impact', String.valueOf(tag.Impact__c));
					t.put('OpportunityId', String.valueOf(tag.Opportunity__c));
					t.put('OpportunityName', String.valueOf(tag.Opportunity__r.Name));
					t.put('Comment', String.valueOf(tag.Comment__c));
					t.put('Module', String.valueOf(tag.Module__c));
					ret.put(String.valueOf(tag.tag__c), t);
				}
			}
		} catch (DmlException e) {
			System.debug('getTagMapInfo:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** initRoscoTags
	 * @param caseId
	 * @return List of opportunities on Account
	 */
	@AuraEnabled
	public static Map<String, String> initRoscoTags(String caseId) {
		Map<String, String> ret = new Map<String, String>();
		try {
			String soql =
				'SELECT Opportunity__c ' +
				'FROM Case ' +
				'WHERE Id = \'' +
				caseId +
				'\' ' +
				'AND Opportunity__c != null ' +
				'LIMIT 1';

			List<Case> cases = Database.query(soql);
			ret.put('caseOpportunityId', '');
			if (!cases.isEmpty()) {
				ret.put('caseOpportunityId', String.valueOf(cases[0].Opportunity__c));
			}
		} catch (DmlException e) {
			System.debug('initRoscoTags:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return ret;
	}

	/** removeAttachedKB
	 * @param caseId
	 * @return
	 */
	@AuraEnabled
	public static List<Map<String, String>> removeAttachedKB(String caseId, String kb) {
		try {
			String soql =
				'SELECT Id ' +
				'FROM CaseArticle ' +
				'WHERE CaseId = \'' +
				caseId +
				'\' ' +
				'AND KnowledgeArticleId = \'' +
				kb +
				'\' ' +
				'LIMIT 1';
			List<CaseArticle> caseArticles = Database.query(soql);
			if (!caseArticles.isEmpty()) {
				delete caseArticles;
			}
		} catch (DmlException e) {
			System.debug('removeAttachedKB:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return getTagsCase2(caseId);
	}

	/** saveNewIndividualTag
	 * @return Map of Tags
	 */
	@AuraEnabled
	public static List<Map<String, String>> saveNewIndividualTag(
		String caseId,
		String type,
		String name,
		String description,
		String solution,
		String opportunity,
		String impact,
		String comment,
		String module
	) {
		String ret = '';
		try {
			if (nullOrEmpty(opportunity)) {
				String caseOpportunity = [SELECT Opportunity__c FROM Case WHERE Id = :caseid LIMIT 1]
				.Opportunity__c;
				if (!nullOrEmpty(caseOpportunity)) {
					opportunity = caseOpportunity;
				}
			}
			if (nullOrEmpty(impact)) {
				impact = 'No Impact';
			}
			String accountId;
			Case c = [SELECT Tags__c, AccountId, JIRA_ID__c FROM Case WHERE Id = :caseId LIMIT 1];
			String cTags = '';
			if (c.Tags__c != null) {
				cTags = String.valueOf(c.Tags__c);
			}
			String cJira = '';
			if (c.JIRA_ID__c != null) {
				cJira = String.valueOf(c.JIRA_ID__c);
			}
			String tPattern = '.*' + name + '\\b.*';
			Pattern tagPattern = Pattern.compile(tPattern);
			Boolean updateCase = false;
			Matcher tagMatcher = tagPattern.matcher(String.valueOf(cTags));
			if (!tagMatcher.matches()) {
				c.Tags__c = c.Tags__c + ' ' + name;
				updateCase = true;
			}
			Map<String, String> jiraIssueId = new Map<String, String>();
			if (type == 'JIRA') {
				jiraIssueId = getJiraIssueSFId(new List<string>{ name });
				Matcher jiraMatcher = tagPattern.matcher(String.valueOf(cJira));
				if (!jiraMatcher.matches()) {
					c.JIRA_ID__c = c.JIRA_ID__c + ' ' + name;
					updateCase = true;
				}
			}
			if (updateCase) {
				update c;
			}
			accountId = c.AccountId;
			String tagId = '';
			String soql = 'SELECT Id ' + 'FROM Rosco_Tag__c ' + 'WHERE Name = \'' + name + '\' LIMIT 1';
			List<Rosco_Tag__c> tagRs = Database.query(soql);
			if (tagRs.size() != 0) {
				if (type == 'JIRA') {
					tagRs[0].Jira_Issue__c = jiraIssueId.get(name);
				}
				tagRs[0].type__c = type;
				tagRs[0].description__c = description;
				tagRs[0].solution__c = solution;
				update tagRs[0];
				tagId = tagRs[0].Id;
			} else {
				Rosco_Tag__c newTag = new Rosco_Tag__c();
				newTag.Name = name;
				newTag.type__c = type;
				newTag.description__c = description;
				newTag.solution__c = solution;
				if (type == 'JIRA') {
					newTag.Jira_Issue__c = jiraIssueId.get(name);
				} else {
					newTag.description__c = description;
					newTag.solution__c = solution;
				}
				insert newTag;
				tagId = newTag.Id;
			}
			if (opportunity == '') {
				opportunity = null;
			}
			String soql2 =
				'SELECT Id ' +
				'FROM Rosco_Tag_Map__c ' +
				'WHERE Case__c = \'' +
				caseId +
				'\' ' +
				'AND tag__c = \'' +
				tagId +
				'\'';

			List<Rosco_Tag_Map__c> existingRs = Database.query(soql2);
			if (existingRs.size() == 0) {
				Rosco_Tag_Map__c newMap = new Rosco_Tag_Map__c();
				newMap.Name = caseId;
				newMap.tag__c = tagId;
				newMap.Opportunity__c = opportunity;
				newMap.Case__c = caseId;
				newMap.Account__c = accountId;
				newMap.Impact__c = impact;
				newMap.Comment__c = comment;
				newMap.Module__c = module;
				if (type == 'JIRA') {
					newMap.Jira_Issue__c = jiraIssueId.get(name);
				}
				insert newMap;
			} else {
				existingRs[0].Opportunity__c = opportunity;
				existingRs[0].Impact__c = impact;
				existingRs[0].Comment__c = comment;
				existingRs[0].Module__c = module;
				update existingRs[0];
			}
		} catch (DmlException e) {
			System.debug('saveNewIndividualTag:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return getTagsCase2(caseId);
	}

	/** saveTags
	 * @return Map of Tags
	 */
	@AuraEnabled
	public static List<Map<String, String>> saveTags(String caseId, List<Map<String, String>> tags) {
		String ret = '';
		try {
			String caseTags = '';
			String incomingIds = '';
			for (Map<String, String> t : tags) {
				if (!nullOrEmpty(t.get('Id'))) {
					if (!incomingIds.containsIgnoreCase(t.get('Id'))) {
						incomingIds += '|' + t.get('Id');
					}
				}
				if (caseTags == '') {
					caseTags = t.get('Title');
				} else {
					caseTags += ' ' + t.get('Title');
				}
			}
			Case c = [SELECT Id, Opportunity__c FROM Case WHERE Id = :caseid LIMIT 1];
			c.Tags__c = caseTags;
			update c;
			String soql =
				'SELECT Id,tag__c ' +
				'FROM Rosco_Tag_Map__c ' +
				'WHERE Case__c = \'' +
				caseId +
				'\'';
			String existingIds = '';
			List<Rosco_Tag_Map__c> existingRs = Database.query(soql);
			if (existingRs.size() != 0) {
				for (Rosco_Tag_Map__c x : existingRs) {
					String eId = String.valueOf(x.get('Id'));
					existingIds += '|' + eId;
					if (!incomingIds.containsIgnoreCase(eId)) {
						delete x;
					}
				}
			}

			for (Map<String, String> t : tags) {
				saveNewIndividualTag(
					caseId,
					t.get('Type'),
					t.get('Title'),
					t.get('Description'),
					t.get('Solution'),
					t.get('OpportunityId'),
					t.get('Impact'),
					t.get('Comment'),
					t.get('Module')
				);
			}
		} catch (DmlException e) {
			System.debug('saveTags:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return getTagsCase2(caseId);
	}

	/** saveTags2
	 * @return Map of Tags
	 */
	@AuraEnabled
	public static List<Map<String, String>> saveTags2(String caseId, List<Map<String, String>> tags) {
		String ret = '';
		try {
			Case c = [
				SELECT Tags__c, AccountId, JIRA_ID__c, Opportunity__c
				FROM Case
				WHERE Id = :caseId
				LIMIT 1
			];

			List<String> tagList = new List<String>();
			String tagString = '';
			for (Map<String, String> t : tags) {
				if (t.get('Type') != 'Knowledge Base') {
					tagList.add(t.get('Title'));
					if (tagString == '') {
						tagString = ' \'' + t.get('Title') + '\'';
					} else {
						tagString = tagString + ',\'' + t.get('Title') + '\'';
					}
				}
			}
			Map<String, Rosco_Tag__c> existingTags = getExistingCaseTags(tagList);
			List<Rosco_Tag__c> rTagsNew = new List<Rosco_Tag__c>();
			List<Rosco_Tag__c> rTagsUpdate = new List<Rosco_Tag__c>();
			for (Map<String, String> t : tags) {
				String tType = t.get('Type');
				if (tType != 'Knowledge Base') {
					String tTitle = t.get('Title');
					String tDescription = t.get('Description');
					String tSolution = t.get('Solution');
					Rosco_Tag__c newRT = new Rosco_Tag__c();
					newRT.description__c = tDescription;
					newRT.Name = tTitle;
					newRT.solution__c = tSolution;
					newRT.type__c = tType;
					if (existingTags.containsKey(tTitle)) {
						Rosco_Tag__c eTag = existingTags.get(tTitle);
						if (
							(newRT.description__c != eTag.description__c) ||
							newRT.solution__c != eTag.solution__c ||
							newRT.type__c != eTag.type__c
						) {
							newRT.Id = eTag.Id;
							rTagsUpdate.add(newRT);
						}
					} else {
						rTagsNew.add(newRT);
					}
				}
			}
			if (!rTagsNew.IsEmpty()) {
				insert rTagsNew;
			}
			if (!rTagsUpdate.IsEmpty()) {
				update rTagsUpdate;
			}
			Map<String, String> jiraMap = getJiraIssueSFId(tagList);
			Map<String, Rosco_Tag__c> existingTags2 = getExistingCaseTags(tagList);
			Map<String, Rosco_Tag_Map__c> existingTagMaps = getExistingCaseMaps(caseId);
			String incomingIds = '';
			List<Rosco_Tag_Map__c> rTagMapsNew = new List<Rosco_Tag_Map__c>();
			List<Rosco_Tag_Map__c> rTagMapsUpdate = new List<Rosco_Tag_Map__c>();
			for (Map<String, String> t : tags) {
				String tTitle = t.get('Title');
				String tComment = t.get('Comment');
				String tOpportunityId = t.get('OpportunityId');
				if (nullOrEmpty(tOpportunityId)) {
					tOpportunityId = c.Opportunity__c;
				}
				String tJiraIssueId = jiraMap.get(tTitle);
				String tImpact = t.get('Impact');
				if (nullOrEmpty(tImpact)) {
					tImpact = 'No Impact';
				}
				String tTagId;
				if (existingTags2.containsKey(tTitle)) {
					Rosco_Tag__c eTag = existingTags2.get(tTitle);
					tTagId = eTag.Id;
				}
				Rosco_Tag_Map__c newRTM = new Rosco_Tag_Map__c();
				newRTM.Account__c = c.AccountId;
				newRTM.Name = c.Id;
				newRTM.Case__c = c.Id;
				newRTM.Comment__c = tComment;
				newRTM.Impact__c = tImpact;
				newRTM.Jira_Issue__c = tJiraIssueId;
				newRTM.Opportunity__c = tOpportunityId;
				newRTM.tag__c = tTagId;
				if (existingTagMaps.containsKey(tTagId)) {
					Rosco_Tag_Map__c eTagMap = existingTagMaps.get(tTagId);
					if (
						(newRTM.Account__c != eTagMap.Account__c) ||
						newRTM.Case__c != eTagMap.Case__c ||
						newRTM.Comment__c != eTagMap.Comment__c ||
						newRTM.Impact__c != eTagMap.Impact__c ||
						newRTM.Jira_Issue__c != eTagMap.Jira_Issue__c ||
						newRTM.Opportunity__c != eTagMap.Opportunity__c
					) {
						newRTM.Id = eTagMap.Id;
						rTagMapsUpdate.add(newRTM);
					}
				} else {
					rTagMapsNew.add(newRTM);
				}
			}
			if (!rTagMapsNew.IsEmpty()) {
				insert rTagMapsNew;
			}
			if (!rTagMapsUpdate.IsEmpty()) {
				update rTagMapsUpdate;
			}
			String mapDelSoql =
				'SELECT Id,Case__c ' +
				'FROM Rosco_Tag_Map__c ' +
				'WHERE Case__c = \'' +
				caseId +
				'\' ' +
				'AND tag__c NOT IN (SELECT ID ' +
				'FROM Rosco_Tag__c ' +
				'WHERE Name IN (' +
				tagString +
				'))';
			if (nullOrEmpty(tagString)) {
				mapDelSoql =
					'SELECT Id,Case__c ' +
					'FROM Rosco_Tag_Map__c ' +
					'WHERE Case__c = \'' +
					caseId +
					'\' ';
			}
			List<Rosco_Tag_Map__c> delRs = Database.query(mapDelSoql);
			if (delRs.size() != 0) {
				for (Rosco_Tag_Map__c r : delRs) {
					String rCaseId = String.valueOf(r.get('Case__c'));

					if (caseId == rCaseId) {
						delete r;
					}
				}
			}
			String cTags = '';
			String cJira = '';
			for (Map<String, String> t : tags) {
				String tType = t.get('Type');
				String tTitle = t.get('Title');
				if (cTags == '') {
					cTags = tTitle;
				} else {
					cTags = cTags + ' ' + tTitle;
				}
				if (tType == 'JIRA') {
					if (cJira == '') {
						cJira = tTitle;
					} else {
						cJira = cJira + ' ' + tTitle;
					}
				}
			}
			c.Tags__c = cTags;
			c.JIRA_ID__c = cJira;
			update c;
		} catch (DmlException e) {
			System.debug('saveTags2:' + e.getMessage() + '\n' + e.getStackTraceString());
		}
		return getTagsCase2(caseId);
	}
}