/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasListController {
	@AuraEnabled
	public static Id getUserId() {
		return UserInfo.getUserId();
	}

	@AuraEnabled(Cacheable=true)
	public static String getSitePrefix() {
		return System.Site.getPathPrefix();
	}

	@AuraEnabled
	public static Boolean isAuthenticated() {
		return !Auth.CommunitiesUtil.isGuestUser();
	}

	@AuraEnabled(Cacheable=true)
	public static Boolean isNicknameDisplayEnabled() {
		return x7sIdeasUtility.isNicknameDisplayEnabled();
	}

	private static List<String> customFieldList { get; set; }

	@AuraEnabled(Cacheable=true)
	public static String getZoneId(String nameValue) {
		if (!String.isEmpty(nameValue)) {
			try {
				List<Community> currCommunity = [SELECT Id FROM Community WHERE Name = :nameValue];
				if (currCommunity != null && currCommunity.size() > 0) {
					return currCommunity[0].Id;
				}
			} catch (Exception ex) {
				System.debug(
					'getZoneId() - Error :' +
					ex.getMessage() +
					',Line number : ' +
					ex.getLineNumber()
				);
			}
		}
		return '';
	}

	@AuraEnabled(Cacheable=true)
	public static x7sIdeasCommon getCommonSettings(String zoneName) {
		x7sIdeasCommon settings = new x7sIdeasCommon('', false);
		if (String.isNotBlank(zoneName)) {
			settings.zoneId = getZoneId(zoneName);
		}
		return settings;
	}

	@AuraEnabled
	public static x7sIdeasListWrapper getIdeas() {
		System.debug('getIdeas >>>');
		return getIdeas(
			50,
			null,
			null,
			'Popular',
			false,
			false,
			null,
			false,
			null,
			false,
			false,
			'My Ideas',
			'',
			'',
			'',
			'',
			false,
			false,
			false,
			false,
			false,
			false,
			false,
			false,
			'None',
			null
		);
	}

	@AuraEnabled
	public static x7sIdeasViewController.VotingDetails getVotingDetails(String ideaId) {
		return x7sIdeasViewController.getVotingLimitsForAccount(ideaId);
	}

	@AuraEnabled
	public static Integer getIdeasAttributeCount(String zoneId, String type, String userId) {
		if (type == 'Voted On Ideas' && Vote.SObjectType.getDescribe().isAccessible()) {
			List<Vote> voteList = [
				SELECT ParentId
				FROM Vote
				WHERE CreatedById = :userId AND Parent.Type = 'Idea'
			];
			List<String> votedOnIdList = new List<String>();
			for (Vote v : voteList) {
				votedOnIdList.add(v.ParentId);
			}

			return [
				SELECT COUNT()
				FROM Idea
				WHERE CommunityId = :zoneId AND Id IN :votedOnIdList AND CreatedById != :userId
			];
		} else {
			return [SELECT COUNT() FROM Idea WHERE CreatedById = :userId AND CommunityId = :zoneId];
		}
	}

	@AuraEnabled
	public static x7sIdeasListWrapper getIdeas(
		Integer listSize,
		String categories,
		String zoneId,
		String sortBy,
		Boolean limitVoteToEmailDomain,
		Boolean filterByTopic,
		String topicNameAndFeatureList,
		Boolean filterBySearchTerm,
		String searchTerm,
		Boolean filterOnUserOwned,
		Boolean filterOnUserVoted,
		String searchMyIdeas,
		String searchByCategories,
		String searchByTopics,
		String searchByStatus,
		String searchByThemes,
		Boolean filterByMergeIdea,
		Boolean filterByMyVotedIdeas,
		Boolean filterMyCommentedIdeas,
		Boolean filterMySubscribedIdeas,
		Boolean filterMyCompanyIdeas,
		Boolean filterMyCompanyVotedIdeas,
		Boolean filterMyCompanyCommentedIdeas,
		Boolean filterMyCompanySubscribedIdeas,
		String filterToFeatured,
		String customFields
	) {
		customFieldList = x7sIdeasViewController.getCustomFields(customFields);

		List<String> featuredIds = new List<String>();
		String topicName = '';
		String category = '';
		String zone = '';
		String sortWith = '';
		String searchString = '';

		if (String.isNotBlank(topicNameAndFeatureList)) {
			Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(
				topicNameAndFeatureList
			);
			System.debug('topicNameAndFeatureList' + m);

			topicName = (String) m.get('topicName');

			List<Object> idList = (List<Object>) m.get('featureids');
			if (idList != null) {
				for (Object a : idList) {
					featuredIds.add(String.escapeSingleQuotes(String.valueOf(a)));
				}
			}
		}

		System.debug('--- categories        ---' + categories);
		System.debug('--- zoneId            ---' + zoneId);
		System.debug('--- sortBy            ---' + sortBy);
		System.debug('--- limitVoteToEmailDomain ---' + limitVoteToEmailDomain);
		System.debug('--- filterByTopic     ---' + filterByTopic);
		System.debug('--- topicName         ---' + topicName);
		System.debug('--- filterBySearchTerm ---' + filterBySearchTerm);
		System.debug('--- searchTerm        ---' + searchTerm);
		System.debug('--- filterOnUserOwned ---' + filterOnUserOwned);
		System.debug('--- filterOnUserVoted ---' + filterOnUserVoted);
		System.debug('--- searchMyIdeas     ---' + searchMyIdeas);
		System.debug('--- searchByCategories ---' + searchByCategories);
		System.debug('--- searchByTopics    ---' + searchByTopics);
		System.debug('--- searchByStatus    ---' + searchByStatus);
		System.debug('--- searchByThemes    ---' + searchByThemes);
		System.debug('--- filterByMergeIdea ---' + filterByMergeIdea);
		System.debug('--- filterByMyVotedIdeas ---' + filterByMyVotedIdeas);
		System.debug('--- filterMyCommentedIdeas ---' + filterMyCommentedIdeas);
		System.debug('--- filterMySubscribedIdeas ---' + filterMySubscribedIdeas);
		System.debug('--- filterMyCompanyIdeas ---' + filterMyCompanyIdeas);
		System.debug('--- filterMyCompanyVotedIdeas ---' + filterMyCompanyVotedIdeas);
		System.debug('--- filterMyCompanyCommentedIdeas ---' + filterMyCompanyCommentedIdeas);
		System.debug('--- filterMyCompanySubscribedIdeas ---' + filterMyCompanySubscribedIdeas);
		System.debug('--- featuredIds ---' + featuredIds);
		System.debug('--- filterToFeatured ---' + filterToFeatured);

		if (!String.isEmpty(categories)) {
			category = String.escapeSingleQuotes(categories);
		}
		if (!String.isEmpty(zoneId)) {
			zone = String.escapeSingleQuotes(zoneId);
		}
		if (!String.isEmpty(sortBy)) {
			sortWith = String.escapeSingleQuotes(sortBy);
		}
		if (!String.isEmpty(topicName)) {
			topicName = String.escapeSingleQuotes(topicName);
		}
		if (!String.isEmpty(searchTerm)) {
			searchString = String.escapeSingleQuotes(searchTerm);
		}

		List<String> categoryList = parseStringToList(category);
		List<String> themesList = parseStringToList(searchByThemes);
		List<String> topicsList = parseStringToList(searchByTopics);
		System.debug('Topic list: ' + topicsList);

		Set<Id> ideasIds = new Set<Id>();
		Integer listSizeValue = listSize != null ? Integer.valueOf(listSize) : 50;

		Boolean limitVoteToEmailDomainValue = limitVoteToEmailDomain != null
			? Boolean.valueOf(limitVoteToEmailDomain)
			: false;
		Boolean filterByTopicValue = filterByTopic != null ? Boolean.valueOf(filterByTopic) : false;
		Boolean filterBySearchTermValue = filterBySearchTerm != null
			? Boolean.valueOf(filterBySearchTerm)
			: false;
		Boolean filterOnUserOwnedValue = filterOnUserOwned != null
			? Boolean.valueOf(filterOnUserOwned)
			: false;
		Boolean filterOnUserVotedValue = filterOnUserVoted != null
			? Boolean.valueOf(filterOnUserVoted)
			: false;
		Boolean filterOnMyCommentedIdeas = filterMyCommentedIdeas != null
			? Boolean.valueOf(filterMyCommentedIdeas)
			: false;
		Boolean filterOnMySubscribedIdeas = filterMySubscribedIdeas != null
			? Boolean.valueOf(filterMySubscribedIdeas)
			: false;
		Boolean filterOnMyCompanyIdeas = filterMyCompanyIdeas != null
			? Boolean.valueOf(filterMyCompanyIdeas)
			: false;
		Boolean filterOnMyCompanyVotedIdeas = filterMyCompanyVotedIdeas != null
			? Boolean.valueOf(filterMyCompanyVotedIdeas)
			: false;

		Boolean filterOnMyCompanyCommentedIdeas = filterMyCompanyCommentedIdeas != null
			? Boolean.valueOf(filterMyCompanyCommentedIdeas)
			: false;
		Boolean filterOnMyCompanySubscribedIdeas = filterMyCompanySubscribedIdeas != null
			? Boolean.valueOf(filterMyCompanySubscribedIdeas)
			: false;

		String QUERY = 'SELECT Id, Title, Status, CreatedBy.Name, CreatedBy.CommunityNickname, CreatedBy.Id, Related_Topic_Name__c, Featured__c,';
		QUERY += ' Body, CreatedDate, Categories, numComments, VoteTotal, attachmentName,';
		QUERY += ' X7S_Ideas_Extension__c, X7S_Ideas_Extension__r.Name, ';

		if (!String.isEmpty(sortWith) && sortWith == 'Recent Comments') {
			QUERY += ' LastComment.CreatedDate, LastComment.CreatedBy.Name, LastComment.CreatedBy.CommunityNickname, LastComment.CreatedBy.Id,LastComment.CommentBody,';
		}

		QUERY +=
			' (SELECT Type, CreatedById, CreatedBy.CommunityNickname FROM Votes WHERE CreatedById = \'' +
			UserInfo.getUserId() +
			'\'';

		if (limitVoteToEmailDomainValue) {
			String userEmail = UserInfo.getUserEmail();
			String domain = '%' + userEmail.split('@')[1];
			QUERY += ' OR CreatedBy.Email LIKE \'' + domain + '\' ORDER BY CreatedDate DESC)';
		} else {
			QUERY += ')';
		}

		if (customFieldList != null) {
			for (String field : customFieldList) {
				QUERY += ', ' + String.escapeSingleQuotes(field.trim());
			}
		}

		QUERY += ' FROM Idea';

		if (String.isEmpty(zone)) {
			QUERY += ' WHERE CommunityId != null ';
		} else {
			QUERY += ' WHERE CommunityId = \'' + zone + '\' ';
		}
		// IsMerged
		if (filterByMergeIdea == true) {
			QUERY += ' AND IsMerged != true ';
		}

		//My Ideas
		if (
			!String.isEmpty(searchMyIdeas) &&
			searchMyIdeas.indexOf('No') == -1 &&
			searchMyIdeas.indexOf('Topic') == -1
		) {
			if (searchMyIdeas.indexOf('Ideas') != -1) {
				for (Idea lstIdeas : [
					SELECT Id, CreatedById
					FROM Idea
					WHERE CreatedById = :UserInfo.getUserId()
					LIMIT 1000
				]) {
					ideasIds.add(lstIdeas.Id);
				}
			}

			if (searchMyIdeas.indexOf('Voted') != -1) {
				filterOnUserVotedValue = true;
			}

			QUERY += ' And Id IN : ideasIds';
		}

		if (featuredIds.size() > 0) {
			QUERY += ' And Id IN ' + '(\'' + String.join(featuredIds, '\',\'') + '\')';
		}

		System.debug('My Ideas : ' + QUERY);

		// Idea Themes
		if (themesList.size() > 0) {
			QUERY += ' AND ' + buildInQuery(themesList, 'IdeaTheme.Title');
		}

		System.debug('Idea Themes: ' + QUERY);

		// Categories
		if (categoryList.size() > 0) {
			String categoriesJoined = '(\'' + String.join(categoryList, '\',\'') + '\')';

			QUERY += ' AND Categories INCLUDES ' + categoriesJoined;
		}

		System.debug('Categories: ' + QUERY);

		// Topics - handle '-' in topic name
		if (filterByTopicValue && !String.isEmpty(topicName)) {
			System.debug('Topic: ' + topicName);
			QUERY += ' AND Related_Topic_Name__c = \'' + getTopicNameFromId(topicName) + '\'';
		}

		// Search term
		if (String.isNotBlank(searchString)) {
			String searchQueryTerm = searchString.trim();

			if (String.isNotBlank(searchQueryTerm)) {
				QUERY += ' AND ( Title LIKE \'%' + searchQueryTerm + '%\' )';
				System.debug(QUERY);
			}
		} else if (filterBySearchTermValue && String.isEmpty(searchString)) {
			QUERY += ' AND Title = \'______\'';
		}

		System.debug('Search Term: ' + QUERY);

		//Ideas Picklist Filters
		if (filterOnUserOwnedValue) {
			QUERY += ' AND CreatedById = \'' + UserInfo.getUserId() + '\'';
		} else if (filterOnUserVotedValue || filterByMyVotedIdeas) {
			QUERY +=
				' AND Id IN (SELECT ParentId FROM Vote WHERE CreatedById = \'' +
				UserInfo.getUserId() +
				'\' AND Parent.Type = \'Idea\')';
		} else if (filterOnMyCommentedIdeas) {
			QUERY +=
				' AND Id IN (SELECT IdeaId FROM IdeaComment WHERE CommunityId = \'' +
				zone +
				'\' AND CreatedById = \'' +
				UserInfo.getUserId() +
				'\')';
		} else if (filterOnMySubscribedIdeas) {
			QUERY +=
				' AND Id IN (SELECT ParentId__c FROM X7S_Ideas_Subscription__c WHERE CreatedById = \'' +
				UserInfo.getUserId() +
				'\')';
		}

		System.debug('Voted by Me: ' + QUERY.substring(25, QUERY.length() - 1));

		//Ideas Picklist Account Filters
		List<User> usr = (List<User>) Database.query(
			'SELECT Id, AccountId FROM User WHERE Id = ' +
			'\'' +
			String.escapeSingleQuotes(UserInfo.getUserId()) +
			'\''
		);
		List<String> listOfUserIds = new List<String>();

		if (!usr.isEmpty() && usr[0].AccountId != null) {
			List<Account> acc = (List<Account>) Database.query(
				'SELECT Id,Name FROM Account WHERE Id = ' +
				'\'' +
				String.escapeSingleQuotes(usr[0].AccountId) +
				'\''
			);

			if (!acc.isEmpty()) {
				for (
					User userr : (List<User>) Database.query(
						'SELECT Id,ContactId,AccountId FROM User WHERE AccountId = ' +
						'\'' +
						String.escapeSingleQuotes(acc[0].Id) +
						'\''
					)
				) {
					listOfUserIds.add(userr.Id);
				}
			}
		}

		if (!listOfUserIds.isEmpty()) {
			if (filterOnMyCompanyIdeas) {
				QUERY += 'AND ' + buildInQuery(listOfUserIds, 'CreatedById');
			} else if (filterOnMyCompanyVotedIdeas) {
				QUERY +=
					'AND Id IN (SELECT ParentId FROM Vote WHERE ' +
					buildInQuery(listOfUserIds, 'CreatedById') +
					' AND Parent.Type = \'Idea\' )';
			} else if (filterOnMyCompanyCommentedIdeas) {
				QUERY +=
					' AND Id IN (SELECT IdeaId FROM IdeaComment WHERE CommunityId = \'' +
					zone +
					'\' AND ' +
					buildInQuery(listOfUserIds, 'CreatedById') +
					')';
			} else if (filterOnMyCompanySubscribedIdeas) {
				QUERY +=
					' AND Id IN (SELECT ParentId__c FROM X7S_Ideas_Subscription__c WHERE ' +
					buildInQuery(listOfUserIds, 'CreatedById') +
					')';
			}
		}
		System.debug('My Account Filters: ' + QUERY.substring(30, QUERY.length() - 1));

		//To make it csv instead of single value
		if (String.isNotBlank(searchByCategories)) {
			QUERY +=
				' AND Categories IN  ' +
				'(\'' +
				String.join(searchByCategories.split(','), '\',\'') +
				'\')';
		}

		// Can't do filter and search together
		if (String.isEmpty(topicName) && String.isNotBlank(searchByTopics)) {
			List<String> topicFilterList = new List<String>();

			System.debug('topic filer: ' + topicsList);
			for (String topicEntry : topicsList) {
				if (topicEntry.indexOf('-') != -1) {
					topicFilterList.add(
						' Related_Topic_Name__c LIKE \'%' +
						topicEntry.replace('-', '%') +
						'%\''
					);
				} else {
					topicFilterList.add(' Related_Topic_Name__c = \'' + topicEntry + '\'');
				}
			}

			QUERY += ' AND (';
			QUERY += String.join(topicFilterList, ' OR ');
			QUERY += ') ';
		}

		if (String.isNotBlank(searchByStatus)) {
			QUERY +=
				' AND Status IN ' +
				'(\'' +
				String.join(String.escapeSingleQuotes(searchByStatus).split(','), '\',\'') +
				'\')';
		}

		if (filterToFeatured == 'Featured Flag') {
			QUERY += ' AND Featured__c = true ';
		}

		System.debug('Status Filter: ' + QUERY);

		if (String.isNotBlank(sortWith)) {
			if (sortWith == 'Recent') {
				QUERY += ' ORDER BY CreatedDate DESC';
			} else if (sortWith == 'Top All-Time') {
				// R1 sort expression
				QUERY += ' ORDER BY VoteTotal DESC, CreatedBy.Name ASC, Title DESC';
			} else if (sortWith == 'Recent Comments') {
				QUERY += ' ORDER BY LastComment.CreatedDate DESC, Title ASC'; //LastComment.CreatedDate DESC,
			} else {
				// Sort By Popular Ideas
				QUERY += ' ORDER BY VoteScore DESC, Title ASC';
			}
		}

		System.debug('Ideas QUERY: ' + QUERY);
		System.debug('listSizeValue: ' + listSizeValue);
		System.debug('ideasIds: ' + ideasIds);

		return new x7sIdeasListWrapper(QUERY, listSizeValue, ideasIds);
	}

	@AuraEnabled
	public static x7sIdeasListWrapper nextPage(
		Integer listSize,
		Integer pageNumber,
		String categories,
		String zoneId,
		String sortBy,
		Boolean limitVoteToEmailDomain,
		Boolean filterByTopic,
		String topicNameAndFeatureList,
		Boolean filterBySearchTerm,
		String searchTerm,
		Boolean filterOnUserOwned,
		Boolean filterOnUserVoted,
		String searchMyIdeas,
		String searchByCategories,
		String searchByTopics,
		String searchByStatus,
		String searchByThemes,
		Boolean filterByMergeIdea,
		Boolean filterByMyVotedIdeas,
		Boolean filterMyCommentedIdeas,
		Boolean filterMySubscribedIdeas,
		Boolean filterMyCompanyIdeas,
		Boolean filterMyCompanyVotedIdeas,
		Boolean filterMyCompanyCommentedIdeas,
		Boolean filterMyCompanySubscribedIdeas,
		String filterToFeatured,
		String customFields
	) {
		customFieldList = x7sIdeasViewController.getCustomFields(customFields);
		Integer pageNumberValue = pageNumber != null ? Integer.valueOf(pageNumber) : 1;

		x7sIdeasListWrapper ilw = getIdeas(
			listSize,
			categories,
			zoneId,
			sortBy,
			limitVoteToEmailDomain,
			filterByTopic,
			topicNameAndFeatureList,
			filterBySearchTerm,
			searchTerm,
			filterOnUserOwned,
			filterOnUserVoted,
			searchMyIdeas,
			searchByCategories,
			searchByTopics,
			searchByStatus,
			searchByThemes,
			filterByMergeIdea,
			filterByMyVotedIdeas,
			filterMyCommentedIdeas,
			filterMySubscribedIdeas,
			filterMyCompanyIdeas,
			filterMyCompanyVotedIdeas,
			filterMyCompanyCommentedIdeas,
			filterMyCompanySubscribedIdeas,
			filterToFeatured,
			customFields
		);
		ilw.pageNumber = pageNumberValue;
		ilw.nextPage();

		System.debug('ilw: ' + ilw);

		return ilw;
	}

	@AuraEnabled
	public static x7sIdeasListWrapper previousPage(
		Integer listSize,
		Integer pageNumber,
		String categories,
		String zoneId,
		String sortBy,
		Boolean limitVoteToEmailDomain,
		Boolean filterByTopic,
		String topicNameAndFeatureList,
		Boolean filterBySearchTerm,
		String searchTerm,
		Boolean filterOnUserOwned,
		Boolean filterOnUserVoted,
		String searchMyIdeas,
		String searchByCategories,
		String searchByTopics,
		String searchByStatus,
		String searchByThemes,
		Boolean filterByMergeIdea,
		Boolean filterByMyVotedIdeas,
		Boolean filterMyCommentedIdeas,
		Boolean filterMySubscribedIdeas,
		Boolean filterMyCompanyIdeas,
		Boolean filterMyCompanyVotedIdeas,
		Boolean filterMyCompanyCommentedIdeas,
		Boolean filterMyCompanySubscribedIdeas,
		String filterToFeatured,
		String customFields
	) {
		customFieldList = x7sIdeasViewController.getCustomFields(customFields);
		Integer pageNumberValue = pageNumber != null ? Integer.valueOf(pageNumber) : 1;

		x7sIdeasListWrapper ilw = getIdeas(
			listSize,
			categories,
			zoneId,
			sortBy,
			limitVoteToEmailDomain,
			filterByTopic,
			topicNameAndFeatureList,
			filterBySearchTerm,
			searchTerm,
			filterOnUserOwned,
			filterOnUserVoted,
			searchMyIdeas,
			searchByCategories,
			searchByTopics,
			searchByStatus,
			searchByThemes,
			filterByMergeIdea,
			filterByMyVotedIdeas,
			filterMyCommentedIdeas,
			filterMySubscribedIdeas,
			filterMyCompanyIdeas,
			filterMyCompanyVotedIdeas,
			filterMyCompanyCommentedIdeas,
			filterMyCompanySubscribedIdeas,
			filterToFeatured,
			customFields
		);

		ilw.pageNumber = pageNumberValue;
		ilw.previousPage();

		return ilw;
	}

	/**
	 * @description Used to get ideas for the specific page number.
	 * @return Idea Wrapper
	 */
	@AuraEnabled
	public static x7sIdeasListWrapper getPage(
		Integer listSize,
		Integer pageNumber,
		String categories,
		String zoneId,
		String sortBy,
		Boolean limitVoteToEmailDomain,
		Boolean filterByTopic,
		String topicNameAndFeatureList,
		Boolean filterBySearchTerm,
		String searchTerm,
		Boolean filterOnUserOwned,
		Boolean filterOnUserVoted,
		String searchMyIdeas,
		String searchByCategories,
		String searchByTopics,
		String searchByStatus,
		String searchByThemes,
		Boolean filterByMergeIdea,
		Boolean filterByMyVotedIdeas,
		Boolean filterMyCommentedIdeas,
		Boolean filterMySubscribedIdeas,
		Boolean filterMyCompanyIdeas,
		Boolean filterMyCompanyVotedIdeas,
		Boolean filterMyCompanyCommentedIdeas,
		Boolean filterMyCompanySubscribedIdeas,
		String filterToFeatured,
		String customFields
	) {
		Integer pageNumberValue = pageNumber != null ? Integer.valueOf(pageNumber) : 1;
		x7sIdeasListWrapper ilw = getIdeas(
			listSize,
			categories,
			zoneId,
			sortBy,
			limitVoteToEmailDomain,
			filterByTopic,
			topicNameAndFeatureList,
			filterBySearchTerm,
			searchTerm,
			filterOnUserOwned,
			filterOnUserVoted,
			searchMyIdeas,
			searchByCategories,
			searchByTopics,
			searchByStatus,
			searchByThemes,
			filterByMergeIdea,
			filterByMyVotedIdeas,
			filterMyCommentedIdeas,
			filterMySubscribedIdeas,
			filterMyCompanyIdeas,
			filterMyCompanyVotedIdeas,
			filterMyCompanyCommentedIdeas,
			filterMyCompanySubscribedIdeas,
			filterToFeatured,
			customFields
		);
		customFieldList = x7sIdeasViewController.getCustomFields(customFields);
		ilw.pageNumber = pageNumberValue;
		ilw.getPage();
		return ilw;
	}

	@AuraEnabled
	public static x7sIdeasListWrapper submitVote(Id ideaId, String voteType) {
		Set<Id> ideasIds = new Set<Id>{ ideaId };

		//ideasIds.add(ideaId);

		String QUERY = 'SELECT Id, Title, Status, CreatedBy.Name, CreatedBy.CommunityNickname, CreatedBy.Id, Related_Topic_Name__c,';
		QUERY += ' Body, CreatedDate, Categories, numComments, VoteTotal, attachmentName,';
		QUERY +=
			' (SELECT Type, CreatedById, CreatedBy.CommunityNickname FROM Votes WHERE CreatedById = \'' +
			UserInfo.getUserId() +
			'\'' +
			')';
		QUERY += ' FROM Idea';
		QUERY += ' WHERE Id IN :ideasIds ';

		try {
			if (Vote.SObjectType.getDescribe().isCreateable()) {
				Vote v = new Vote();
				v.ParentId = ideaId;
				v.Type = voteType;

				insert v;
			}
			x7sIdeasListWrapper wrapper = new x7sIdeasListWrapper(QUERY, 1, ideasIds);
			return wrapper;
		} catch (Exception e) {
			System.debug('submitVote failed: ' + e.getMessage());
		}

		return null;
	}
	/**
	 * @description :  Valdate field API name
	 *
	 * @param recordId Id of the record
	 *
	 * @return string as name of the record
	 */
	@AuraEnabled
	public static List<SObject> getCustomLookupDisplayName(String recordId) {
		// Prepare results
		List<SObject> results = new List<SObject>();

		if (String.isNotBlank(recordId)) {
			Id myId = (Id) recordId;
			String sObjName = myId.getSObjectType().getDescribe().getName();
			System.debug(sObjName);

			String queryRecord = 'SELECT Id, Name FROM ' + sObjName + ' WHERE Id =: myId';

			for (SObject query : Database.query(queryRecord)) {
				//NOPMD
				results.add(query);
			}
		}

		return results;
	}

	/**
	 * @description :  get default fieldset
	 *
	 * @return string as name of the fieldset
	 */
	@AuraEnabled
	public static String getFieldSetName() {
		String shrFieldSet = '';
		X7S_Ideas_Setting__mdt fieldSet = X7S_Ideas_Setting__mdt.getInstance('Default');
		if (fieldSet.X7S_Ideas_Default_Custom_Field_Set__c != null) {
			X7S_Shr_Custom_Field_Set__mdt cf = X7S_Shr_Custom_Field_Set__mdt.getInstance(
				fieldSet.X7S_Ideas_Default_Custom_Field_Set__c
			);
			if (cf?.Active__c && cf?.Object_API_Name__c == 'Idea') {
				shrFieldSet = fieldSet.X7S_Ideas_Default_Custom_Field_Set__c;
			}
		}
		return shrFieldSet;
	}
	//	UTILITY FUNCTIONS
	// ----------------------------------------------------------

	@TestVisible
	private static List<String> parseStringToList(String stringValue) {
		List<String> stringList = new List<String>();

		if (String.isNotBlank(stringValue)) {
			String parseString = String.escapeSingleQuotes(stringValue);
			stringList = parseString.split(',');
		}

		return stringList;
	}

	@TestVisible
	private static String buildInQuery(List<String> valueList, String fieldName) {
		String inQuery = '';
		List<String> fieldValues = new List<String>();

		for (String entry : valueList) {
			fieldValues.add('\'' + entry.trim() + '\'');
		}

		if (fieldValues.size() > 0) {
			inQuery = fieldName + ' IN (';
			inQuery += String.join(fieldValues, ',');
			inQuery += ') ';
		}

		return inQuery;
	}

	@TestVisible
	private static String getTopicNameFromId(String topicId) {
		String topicName = '';

		Topic foundTopic = [SELECT Id, Name FROM Topic WHERE Id = :topicId];
		if (foundTopic != null) {
			topicName = foundTopic.Name;
		}

		return topicName;
	}
}