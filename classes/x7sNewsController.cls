/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Apex class to provide access to the News object
 * @Date: 2022
 * @Author: IBM Corp / 7Summits
 * RequestId  ModifiedDate  Description
 * SS-13018   2026-05-29    Block guest user access to write methods (followRecord, unfollowRecord, deleteRecord, saveNews, likeNews, unLikeNews, deleteCurrentAudience); enforce USER_MODE in getCustomLookupDisplayName
 */
@SuppressWarnings('PMD.ExcessiveClassLength')
public with sharing class x7sNewsController {
	private static final String STR_SEARCH_TERM = 'Search Term';
	private static final String STR_NONE = 'None';
	private static final String STR_TOPIC_VALUE = 'Topic Value';
	private static final String FOR_GROUP_ID = 'Group';
	private static final Integer TOPIC_SEARCH_LIMIT = 1000;
	public static final String FOR_GUEST_TYPE = 'Guest';
	@TestVisible private static final String NEWS_FIELD_SEPARATOR = ',';
	private static final String FEATURED_RECORDS = 'Featured Records';
	private static final Integer NEWS_UNFOLLOW_LIMIT = 1000;
	private static final String NEWS_CMT_SETTING_DEFAULT = 'Default';
	private static final String NETWORKID_FIELD = 'NetworkId__c';
	private static final String NAME_FIELD = 'Name';
	private static final String CUSTOM_OBJ_EXTENSION = '__c';
	private static final Integer USER_SEARCH_LIMIT = 500;

	//We need to use both networkId and strNetworkId to handle 15 digit and 18 digit id in news records as per CLF-210
	//networkId of type id returns 18 digit id
	@TestVisible private static Id networkId = System.Network.getNetworkId();
	//networkId of type string i.e. strNetworkId returns 15 digit id
	@TestVisible private static String strNetworkId = System.Network.getNetworkId();

	private static String TOKEN_SOBJECT_NAME = 'X7S_News__c';
	private static String TOKEN_GROUP_NAME = 'News Article';

	//custom field list
	private static List<String> customFieldList {
        get;
        set;
    }

	@AuraEnabled
	public static Boolean requireGroupMembership() {
		Boolean requireMembership = false;

		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);

			if(setting != null) {
				requireMembership = setting.Require_Group_Membership__c;
			}
		}
		catch (Exception ex) { System.debug(System.LoggingLevel.ERROR, 'X7S_News_Setting__mdt not configured + ' + ex.getMessage()); throw new AuraHandledException(ex.getMessage());}

		return requireMembership;
	}

	@TestVisible
	private static Boolean userAuthorizedToViewAll() {
		Boolean authorized = false;
		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);
			if(setting != null) {
				authorized = x7sNewsBaseController.permissionSetMember(UserInfo.getUserId(), setting.View_All_Permission_Set__c);
			}
		}
		catch (Exception ex) { System.debug(System.LoggingLevel.ERROR, 'CMT Author_Permission_Set__c : ' + ex.getMessage());}

		return authorized;
	}

	// CURRENT USER
	@AuraEnabled
	public static User getCurrentUser() {
		try {
			return [SELECT Id, Name, CommunityNickname,LanguageLocaleKey,UserType FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED LIMIT 1];
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/*
	* @description : Method for getting the namespace
	*/
	public static String getOrgNamespace() {
		String thisNameSpace = x7sNewsBaseController.getModel().namespacePrefix;

		return String.isBlank(thisNameSpace) ? '' : thisNameSpace + '__';
	}

	// FOLLOWING
	@AuraEnabled
	public static Boolean isFollowing(String recordId) {
		try {
			return [
				SELECT COUNT()
				FROM EntitySubscription
				WHERE NetworkId = :System.Network.getNetworkId()
				AND ParentId = :recordId
				AND SubscriberId = :UserInfo.getUserId()
				LIMIT 1000
			] > 0;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@AuraEnabled
	public static Boolean followRecord(String recordId) {
		requireAuthenticatedUser();
		try {
			ConnectApi.ChatterUsers.follow(System.Network.getNetworkId(), UserInfo.getUserId(), recordId); return true;
		}
		catch (Exception e) {
			System.debug(e);
			throw new AuraHandledException(e.getMessage());
		}		
	}

	@AuraEnabled
	public static void unfollowRecord(String recordId) {
		requireAuthenticatedUser();
		try {
			for (EntitySubscription follow : [
				SELECT Id
				FROM EntitySubscription
				WHERE NetworkId = :System.Network.getNetworkId() AND ParentId = :recordId AND SubscriberId = :UserInfo.getUserId()
				LIMIT :NEWS_UNFOLLOW_LIMIT
			]) { ConnectApi.Chatter.deleteSubscription(System.Network.getNetworkId(), follow.Id);}
		}
		catch (Exception e) {throw new AuraHandledException(e.getMessage());}

	}

	/*
	* @description   :  Method to fetch community setting for nick name to display users name or name as per setting.
	*/
	@AuraEnabled(Cacheable=true)
	public static Boolean isNicknameDisplayEnabled() {

		if (!hasNicknameDisplayEnabledQueried) {
			try {
				if(networkId == null) {
					X7S_News_Setting__mdt setting =  X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);
					showNickNames = setting.Show_Nickname_in_Lightning_Experience__c;
				} else {
					Network currNetwork = [SELECT Id, OptionsNicknameDisplayEnabled FROM Network WHERE Id = :networkId WITH SECURITY_ENFORCED LIMIT 1];
					showNickNames = currNetwork.OptionsNicknameDisplayEnabled;
				}
			}
			catch (Exception e) {
				System.debug(e.getMessage());
				throw new AuraHandledException(e.getMessage());
			}
			finally {
				hasNicknameDisplayEnabledQueried = true;
			}
		}
		return showNickNames;
	}

	@TestVisible private static Boolean hasNicknameDisplayEnabledQueried = false;
	@TestVisible private static Boolean showNickNames = true;

	// ACCESS TO OBJECT
	@AuraEnabled(Cacheable=true)
	public static Boolean isObjectCreatable() {
		try {
			return Schema.SObjectType.X7S_News__c.isCreateable();
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@AuraEnabled(Cacheable=true)
	public static Boolean isObjectEditable() {
		try {
			return Schema.SObjectType.X7S_News__c.isUpdateable();
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@AuraEnabled(Cacheable=true)
	public static Boolean isRecordEditable(String recordId) {
		try {
			return getUserRecordAccess(UserInfo.getUserId(), recordId).HasEditAccess;
		}
		catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@AuraEnabled(Cacheable=true)
	public static Boolean isRecordDeletable(String recordId) {
		try {
			return getUserRecordAccess(UserInfo.getUserId(), recordId).HasDeleteAccess;
		}
		catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@TestVisible
	private static Boolean isRecordShareable(String recordId) {
		try {
			return getUserRecordAccess(UserInfo.getUserId(), recordId).HasAllAccess;
		}
		catch (Exception e) { return false;}
	}

	@AuraEnabled
	public static Boolean deleteRecord(String recordId) {
		requireAuthenticatedUser();
		try {
			if (!X7S_News__c.SObjectType.getDescribe().isDeletable()) {
				System.debug('deleteRecord(): Unable to delete X7S_News__c');
				return false;
			}

			UserRecordAccess access = getUserRecordAccess(UserInfo.getUserId(), recordId);
			if (access.HasDeleteAccess) {				
				delete new X7S_News__c(Id = recordId);
				return true;
			}
			else {
				System.debug('No delete access');
			}
			return false;
		}
		catch (Exception e) { System.debug(e); throw new AuraHandledException(e.getMessage());}
	}

	@TestVisible
	private static UserRecordAccess getUserRecordAccess(String userId, String recordId) {
		return [
			SELECT RecordId,
				HasAllAccess,
				HasDeleteAccess,
				HasEditAccess,
				HasTransferAccess,
				HasReadAccess,
				MaxAccessLevel
			FROM UserRecordAccess
			WHERE UserId = :userId
			AND RecordId = :recordId
			WITH SECURITY_ENFORCED
		];
	}

	/**
	 * @description :  Method to News Records as per different criteria in different components
	 *
	 * @param numberOfNewsPerPage page size
	 * @param strRecordId current record
	 * @param networkIds community id
	 * @param sortBy sort order
	 * @param filterByTopic topic filter
	 * @param filterByAuthor author filter
	 * @param topicName current topic
	 * @param filterOn filter option
	 * @param searchTerm search string
	 * @param fromDate date range start
	 * @param toDate date range end
	 * @param listofNewsIds featured IDs
	 * @param isFeatured in featured mode
	 * @param customFields Custom fields
	 *
	 * @return News wrapper
	 */
	@AuraEnabled
	public static x7sNewsWrapper getNews(
		Integer numberOfNewsPerPage,
		String strRecordId,
		String networkIds,
		String sortBy,
		String filterByTopic,
		String filterByAuthor,
		String topicName,
		String filterOn,
		String searchTerm,
		String fromDate,
		String toDate,
		List<String> listofNewsIds,
		Boolean isFeatured,
		String customFields) {
		
		customFieldList = getCustomFields(customFields);
		Datetime fromDt;
		Datetime toDt;
		String networkClause, topicNetworkClause;

		try {
			//create datetime instance of fromDate and toDate as we get them in string format
			if (String.isNotBlank(fromDate) || String.isNotBlank(toDate)) {

				if (String.isNotBlank(fromDate) && fromDate.length() > 0) {
					List<String> lstOfFromDt = fromDate.split('-');

					//set date by splitting string because expected format is mm/dd/yyyy but we are getting string in yy/mm/dd
					fromDt = Datetime.newInstance(
						Integer.valueOf(lstOfFromDt[0]),
						Integer.valueOf(lstOfFromDt[1]),
						Integer.valueOf(lstOfFromDt[2]),
						0, 0, 0);
				}

				if (String.isNotBlank(toDate) && toDate.length() > 0) {
					List<String> lstOfToDt = toDate.split('-');

					//set date by splitting string because expected format is mm/dd/yyyy but we are getting string in yy/mm/dd

					toDt = Datetime.newInstance(
						Integer.valueOf(lstOfToDt[0]),
						Integer.valueOf(lstOfToDt[1]),
						Integer.valueOf(lstOfToDt[2]),
						23, 59, 59);
				}
			}
		}
		catch (Exception e) { System.debug(e.getMessage()); throw new AuraHandledException(e.getMessage());}

		try {
			// note this variable is also declared in the Wrapper
			// as we pass the QUERY string to the wrapper
			// not needed here but makes the code more readable
			Datetime rightNow = Datetime.now();
			System.assertNotEquals(null, rightNow);

			Integer intLimit = Integer.valueOf(numberOfNewsPerPage);
			String recId = validateId(strRecordId);

			//set of topicIds ,authorIds and newsIds for filter criteria
			Set<String> topicIds = new Set<String>();
			Set<String> newsIds = new Set<String>();
            Set<String> newsIdsByTopic = new Set<String>();
			Set<String> authorIds = new Set<String>();

			// Multi Language
			Set<String> multiLngIds = new Set<String>();
			String userLanguage = getLanguage();
			User currentUser = getCurrentUser();
			Boolean useMultiLanguage = String.isNotBlank(userLanguage) && currentUser.UserType != FOR_GUEST_TYPE;

			// disable Audience for users that can Authorise news via permission set
			Boolean useAudience = audienceEnabled() && !userAuthorizedToViewAll();
			List<String> audienceIds = new List<String>();

			if (useAudience) {
				audienceIds = getAudienceTargetIds(strNetworkId);
			}

			//collect news id related to similar topics
			if (filterOn != STR_SEARCH_TERM && String.isNotBlank(strRecordId) && String.isNotBlank(recId)) {				

				String queryTopicAssignment = x7sNewsBaseController.getQueryString(x7sNewsBaseController.TOPIC_ASSIGNMENT_OBJ);

				if (String.isNotBlank(queryTopicAssignment)) {
					queryTopicAssignment += ' WHERE EntityId = \'' + recId + '\''; // note: recId already sanitized

					topicNetworkClause = getNetworkClause('NetworkId', networkId, networkIds);

					if (String.isNotBlank(topicNetworkClause)) {
						queryTopicAssignment += ' AND ' + topicNetworkClause;
					}

					queryTopicAssignment += ' LIMIT : TOPIC_SEARCH_LIMIT';
					List<TopicAssignment> topicAssignments = Database.query(queryTopicAssignment); // NOPMD - Embedded variables have been escaped

					//collect all topics related to X7S_News__c object
					for (TopicAssignment topicAssignment : topicAssignments) {
						topicIds.add(topicAssignment.TopicId);
					}

					//collect all news Ids related to topicIds above
					String queryTopicSubAssignment = x7sNewsBaseController.getQueryString(x7sNewsBaseController.TOPIC_ASSIGNMENT_OBJ);
					queryTopicSubAssignment += ' WHERE TopicId IN : topicIds';
					queryTopicSubAssignment += String.isNotBlank(networkId) ? ' AND NetworkId = \'' + networkId + '\'' : '';

					queryTopicSubAssignment += ' LIMIT :TOPIC_SEARCH_LIMIT';
					List<TopicAssignment> topics = Database.query(queryTopicSubAssignment); // NOPMD - Embedded variables have been escaped

					for (TopicAssignment topicAssignment : topics) {
						newsIds.add(topicAssignment.EntityId);
					}
				}
			
			}

			// multi language enabled logic
			if (useMultiLanguage) {

				String queryNewsTranslate = x7sNewsBaseController.getQueryString('X7S_News_Translation__c');

				//Translation Records
				if (String.isNotBlank(queryNewsTranslate)) {
					List<X7S_News_Translation__c> translateList;

					if (String.isNotBlank(searchTerm)) { translateList = Database.query(String.escapeSingleQuotes(queryNewsTranslate) + ' WHERE Title__c LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'' + ' AND Language__c = \'' + String.escapeSingleQuotes(userLanguage) + '\'');}
					else { translateList = Database.query(String.escapeSingleQuotes(queryNewsTranslate) + ' WHERE Language__c = \'' + String.escapeSingleQuotes(userLanguage) + '\'');}

					for (X7S_News_Translation__c newsRecord : translateList) { multiLngIds.add(newsRecord.Parent_X7S_News__c);}
				}

				//News Records
				String queryNewsArticle = x7sNewsBaseController.getQueryString(TOKEN_SOBJECT_NAME);
				if (String.isNotBlank(queryNewsArticle)) {

					List<X7S_News__c> newsList;

					if (String.isNotBlank(searchTerm)) { newsList = Database.query(String.escapeSingleQuotes(queryNewsArticle) + ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'' + ' AND Language__c = \'' + String.escapeSingleQuotes(userLanguage) + '\'');}
					else { newsList = Database.query(String.escapeSingleQuotes(queryNewsArticle) + ' WHERE Language__c = \'' + String.escapeSingleQuotes(userLanguage) + '\'');}

					for (X7S_News__c newsRecord : newsList) { multiLngIds.add(newsRecord.Id);}
				}
			}

			if (!listofNewsIds.isEmpty()) {
				if (useMultiLanguage) { multiLngIds = multiLanguageSet(listofNewsIds, multiLngIds);}
				else {
					newsIds.addAll(listofNewsIds);
				}
			}

			//fetch Query string for X7S_News__c (news) with child query attachment and user required fields
			String Query = getSobjectQueryString(TOKEN_SOBJECT_NAME);

			if (String.isNotBlank(Query)) {
				Boolean applyLimitToQuery = false;

				// get recommended news records
				if (filterOn == STR_NONE && String.isNotBlank(strRecordId) && String.isNotBlank(recId)) {

					networkClause = getNetworkClause(NETWORKID_FIELD, networkId, networkIds);
					if (String.isNotBlank(networkClause)) {
						Query += ' WHERE ' + networkClause;
					}

					if (String.isNotBlank(searchTerm)) {
						Query += String.isBlank(networkId) ? ' WHERE' : ' AND ';
						if (String.isNotBlank(searchTerm)) { Query += ' Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'';}
					}

					if (useMultiLanguage) { newsIds.addAll(multiLngIds);} else {newsIds.addAll(listofNewsIds);}

					Query += ' AND Publish_DateTime__c <= :rightNow ';
					Query += ' AND (Archive_DateTime__c = null OR Archive_DateTime__c > :rightNow )';
					Query += ' AND Id IN : newsIds';

					if (useAudience) { Query += getAudienceQuery(audienceIds);}

					Query += ' AND Id != \'' + recId + '\'';
					applyLimitToQuery = true;
				}
				else if(filterOn == FEATURED_RECORDS && isFeatured == true) {
					Query += ' WHERE x7s_Featured_Formula__c = true';
				}
				//get news records on search page as per searchterm entered with sort by filter selected by user
				else if (filterOn == STR_SEARCH_TERM && String.isNotBlank(searchTerm)) {

					if (useMultiLanguage) { Query += ' WHERE id  IN : multiLngIds ';}
					else {
						if (String.isNotBlank(searchTerm)) {
							Query += ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'';
						}
					}

					Query += ' AND Publish_DateTime__c <= :rightNow ';
					Query += ' AND (Archive_DateTime__c = null OR Archive_DateTime__c > :rightNow )';

					if (useAudience) { Query += getAudienceQuery(audienceIds);}

					networkClause = getNetworkClause(NETWORKID_FIELD, networkId, networkIds);
					if (String.isNotBlank(networkClause)) {
						Query += ' AND ' + networkClause;
					}
				}
				//get news records on Topic detail as per topicName selected by user
				else if (String.isNotBlank(topicName) && filterOn == STR_TOPIC_VALUE) {

					String EntityKeyPrefixNews = X7S_News__c.SObjectType.getDescribe().getKeyPrefix();
					newsIds = new Set<String>();

					String queryStrTopic = x7sNewsBaseController.getQueryString(x7sNewsBaseController.TOPIC_ASSIGNMENT_OBJ);

					if (String.isNotBlank(queryStrTopic)) {

						// hack for Topic names with spaces that are replaced with a '-' in the URL
						String subTopicQuery;

						// check if ID is passed as the parameter
						if (topicName instanceof Id) {
							subTopicQuery = ' WHERE Topic.Id = \'' + String.escapeSingleQuotes(topicName) + '\'';
						}
						else {
							if (topicName.indexOf('-') != -1) {
								subTopicQuery = ' WHERE Topic.Name LIKE \'%' + String.escapeSingleQuotes(topicName.replace('-', '%')) + '%\'';
							}
							else {
								subTopicQuery = ' WHERE Topic.Name = \'' + String.escapeSingleQuotes(topicName) + '\'';
							}
						}
						queryStrTopic += subTopicQuery;

						topicNetworkClause = getNetworkClause('NetworkId', networkId, networkIds);

						if (String.isNotBlank(topicNetworkClause)) {
							queryStrTopic += ' AND ' + topicNetworkClause;
						}
						queryStrTopic += ' AND EntityKeyPrefix = \'' + String.escapeSingleQuotes(EntityKeyPrefixNews) + '\'';
						queryStrTopic += ' LIMIT :TOPIC_SEARCH_LIMIT';

						List<TopicAssignment> topicsLst = Database.query(queryStrTopic); // NOPMD - Embedded variables have been escaped

						for (TopicAssignment topic : topicsLst) {
							newsIds.add(topic.EntityId);
						}
					}
					
					Query += ' Where Id IN : newsIds';

					if (useMultiLanguage) { Query += ' AND id  IN : multiLngIds ';}
					else { if (String.isNotBlank(searchTerm)) { Query += ' AND Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'';}}

					Query += ' AND Publish_DateTime__c <= :rightNow ';
					Query += ' AND (Archive_DateTime__c = null OR Archive_DateTime__c > :rightNow )';
					
					if (useAudience) { Query += getAudienceQuery(audienceIds);}

					networkClause = getNetworkClause(NETWORKID_FIELD, networkId, networkIds);

					if (String.isNotBlank(networkClause)) {
						Query += ' AND ' + networkClause;
					}
				}
				// filter by group id (stored in topicName for now)
				else if (filterOn == FOR_GROUP_ID) {

					Query += ' WHERE GroupId__c  = \'' + String.escapeSingleQuotes(topicName) + '\'';


					if (useMultiLanguage) { Query += ' AND id  IN : multiLngIds ';}

					if (useAudience) { Query += getAudienceQuery(audienceIds);}

					if (fromDt != null || toDt != null) {
						if (fromDt != null) {
							Query += ' AND Publish_DateTime__c >=: fromDt ';
						}

						if (toDt != null) {
							Query += ' AND Publish_DateTime__c <=:  toDt ' ;
						}
					}

					Query += ' AND Publish_DateTime__c <= :rightNow ' ;
					
				}
				//get news records on List View as per combination of Topic, date, Author and sort by
				else if (String.isNotBlank(filterByTopic) || String.isNotBlank(filterByAuthor) || fromDt != null || toDt != null) {

					Query += ' WHERE (Archive_DateTime__c = null OR Archive_DateTime__c > :rightNow )';

					networkClause = getNetworkClause(NETWORKID_FIELD, networkId, networkIds);

					if (String.isNotBlank(networkClause)) {
						Query += ' AND ' + networkClause;
					}

					if (useMultiLanguage) { Query += ' AND id  IN : multiLngIds ';}
					else { if (String.isNotBlank(searchTerm)) { Query += ' AND Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'';}}

					// PRIVATE GROUPS ---------------------------------------------------------------------------------
					// Hide Private items
					// re-purposed newsId for the group id's that the user is a member of
					// the 2 will never be used together in the same query
					// not great but it is difficult to add to the packaged WrapperNews parameters
                        newsIdsByTopic = getGroups().keySet();                        
                        Query += newsIdsByTopic.isEmpty() ? ' AND GroupId__c = null' : ' AND (GroupId__c = null OR GroupId__c IN : newsIdsByTopic) ';
						Query += ' AND Private_Group__c = false';
					
					if (String.isNotBlank(filterByTopic) && !filterByTopic.isWhitespace()) {
						Set<String> topicLst = new Set<String>();
						topicLst.addAll(String.escapeSingleQuotes(filterByTopic).split(NEWS_FIELD_SEPARATOR));

						Boolean fieldIsId = false;

						for (String topicNameEntry : topicLst) {
							if (topicNameEntry instanceof Id) { fieldIsId = true;}
							else { if (topicNameEntry.indexOf('-') != -1) { topicLst.add(topicNameEntry.replace('-', ' '));}}
						}

						List<String> topicIdList = new List<String>();
						String targetName = fieldIsId ? 'Id' : 'name';
						String topicIdQuery = 'SELECT Id, Name FROM Topic WHERE ' + targetName + ' IN : topicLst';
						List<Topic> topics = Database.query(String.escapeSingleQuotes(topicIdQuery));
						for (Topic entry : topics) {
							topicIdList.add(entry.Id);
						}

						newsIds = new Set<String>();
						String queryTopic = x7sNewsBaseController.getQueryString(x7sNewsBaseController.TOPIC_ASSIGNMENT_OBJ);
						if (String.isNotBlank(queryTopic)) {
							queryTopic += ' WHERE TopicId IN :topicIdList ';
							queryTopic += ' LIMIT 1000';

							List<TopicAssignment> topicsLst = Database.query(queryTopic);

							for (TopicAssignment topic : topicsLst) {
								newsIds.add(topic.EntityId);
							}
						}
						Query += ' AND Id IN : newsIds';
					}

					if (String.isNotBlank(filterByAuthor) && !filterByAuthor.isWhitespace()) {
						authorIds = new Set<String>();
						authorIds.addAll( String.escapeSingleQuotes(filterByAuthor).split(NEWS_FIELD_SEPARATOR));

						Query += ' AND Author__c IN : authorIds';
						Query += ' AND Show_Author__c = true';
					}

					if (fromDt != null || toDt != null) {
						if (fromDt != null) {
							Query += ' AND Publish_DateTime__c >=: fromDt ';
						}

						if (toDt != null) {
							Query += ' AND Publish_DateTime__c <=:  toDt ' ;
						}
					}

					Query += ' AND Publish_DateTime__c <= :rightNow ' ;

					if (useAudience) {
						Query += getAudienceQuery(audienceIds);
					}
				}
				//when no criteria is selected without sort by as well
				else {
					networkClause = getNetworkClause(NETWORKID_FIELD, networkId, networkIds);

					if (String.isNotBlank(networkClause)) {
						Query += ' WHERE ' + networkClause;
					}
					
					if (useMultiLanguage) { Query += ' AND Id  IN :multiLngIds ';}
					else if (!newsIds.isEmpty()) { Query += ' AND Id IN :newsIds';}
					else { if (String.isNotBlank(searchTerm)) { Query += ' AND Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\'';}}

					Query += ' AND Publish_DateTime__c <= :rightNow ';
					Query += ' AND (Archive_DateTime__c = null OR Archive_DateTime__c > :rightNow )';
                    newsIdsByTopic = getGroups().keySet();
                    Query += newsIdsByTopic.isEmpty() ? ' AND GroupId__c = null' : ' AND (GroupId__c = null OR GroupId__c IN : newsIdsByTopic)';
					Query += ' AND Private_Group__c = false';
					if (useAudience) { Query += getAudienceQuery(audienceIds);}
				}
				
				if (String.isNotBlank(sortBy)) {
					if (sortBy == 'Oldest First') {
						Query += ' WITH SECURITY_ENFORCED ORDER BY Publish_DateTime__c';
					} else if (sortBy == 'Most Recent') {
						Query += ' WITH SECURITY_ENFORCED ORDER BY Publish_DateTime__c DESC';
					} else {
						Query += ' WITH SECURITY_ENFORCED ORDER BY Publish_DateTime__c DESC';
					}
				} else {
					Query += ' WITH SECURITY_ENFORCED ORDER BY Publish_DateTime__c DESC';
				}

				if(applyLimitToQuery) {
					Query += ' LIMIT : intLimit';
				}
				System.debug('ProfileId:' + Userinfo.getProfileId());
				//calling wrapper class to execute query and set controller parameters
				x7sNewsWrapper WrapperNews = new x7sNewsWrapper(
					Query,
					userLanguage,
					intLimit,
					newsIds,
                    newsIdsByTopic,
					authorIds,
					fromDt,
					toDt,
					false,
					null,
					multiLngIds,
					currentUser.UserType,
					audienceIds);
				return WrapperNews;
			}
			else {
				return null;
			}
		}
		catch (Exception e) { throw new AuraHandledException(e.getMessage());}
	}

	private static Set<String> multiLanguageSet(List<String> newsIds, Set<String> multiLngIds) {
		Set<String> newsLanguageIds = new Set<String>();

		for (String id : newsIds) { if (multiLngIds.contains(id)) { newsLanguageIds.add(id);}}
		return newsLanguageIds;
	}

	/**
	 * @description Create the query sub-string to select news articles for the use's audience
	 *
	 * @param audienceIds list of target ids applicable to the user's audience
	 *
	 * @return sub-query string to select items for the user's target audience
	 */
	private static String getAudienceQuery(List<String> audienceIds) {
		return ' AND (Audience_Selected__c = false' + (audienceIds.isEmpty() ? '' : ' OR Id IN : audienceIds') + (') ');
	}

	@TestVisible
	private static String getNetworkClause(String targetField, String networkId, String networkIds) {
		String networkClause = '';

		if (String.isNotBlank(networkId)) {
			networkClause = targetField + ' = \'' + networkId + '\'';
		}
		else if (String.isNotBlank(networkIds)) {
			List<String> idList = new List<String>();
			for (String idItem : networkIds.split(NEWS_FIELD_SEPARATOR)) {
				idList.add(targetField + ' = \'' + String.escapeSingleQuotes(idItem) + '\'');
			}

			networkClause = String.join(idList, ' OR ');
		}
		else {
			networkClause = targetField + ' = null';
		}

		return ' ' + networkClause;
	}

	/*	
	* @description   :  Method used on click of "Next" in pagination to display news records as per numberOfNewsPerPage
	*/
	@AuraEnabled
	public static x7sNewsWrapper nextPage(
		Integer numberOfNewsPerPage,
		Integer pageNumber,
		String strRecordId,
		String networkIds,
		String sortBy,
		String filterByTopic,
		String filterByAuthor,
		String topicName,
		String filterOn,
		String searchTerm,
		String fromDate,
		String toDate,
		List<String> listofNewsIds,
		Boolean isFeatured,
		String customFields) {

		try {
			customFieldList = getCustomFields(customFields);

			Integer pageNumberValue = pageNumber != null ? Integer.valueOf(pageNumber) : 1;

			x7sNewsWrapper nlw = getNews(
				numberOfNewsPerPage,
				strRecordId,
				networkIds,
				sortBy,
				filterByTopic,
				filterByAuthor,
				topicName,
				filterOn,
				searchTerm,
				fromDate,
				toDate,
				listofNewsIds,
				isFeatured,
				customFields);

			nlw.pageNumber = pageNumberValue;
			nlw.nextPage();

			return nlw;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/*
	* @description   :  Method used on click of "Previous" in pagination to diaplay news records as per numberOfNewsPerPage
	*/
	@AuraEnabled
	public static x7sNewsWrapper previousPage(
		Integer numberOfNewsPerPage,
		Integer pageNumber,
		String strRecordId,
		String networkIds,
		String sortBy,
		String filterByTopic,
		String filterByAuthor,
		String topicName,
		String filterOn,
		String searchTerm,
		String fromDate,
		String toDate,
		List<String> listofNewsIds,
		Boolean isFeatured,
		String customFields) {
		
		try {
			customFieldList = getCustomFields(customFields);
			
			Integer pageNumberValue = pageNumber != null ? Integer.valueOf(pageNumber) : 1;

			x7sNewsWrapper nlw = getNews(
				numberOfNewsPerPage,
				strRecordId,
				networkIds,
				sortBy,
				filterByTopic,
				filterByAuthor,
				topicName,
				filterOn,
				searchTerm,
				fromDate,
				toDate,
				listofNewsIds,
				isFeatured,
				customFields);

			nlw.pageNumber = pageNumberValue;
			nlw.previousPage();

			return nlw;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description Method to get news based on page number clicked
	 *
	 * @param numberOfNewsPerPage - count for news to show in one page
	 * @param pageNumber - Page number for which you need news
	 * @param strRecordId - News Record Ids
	 * @param networkIds - Experience site Id
	 * @param sortBy - Sort String
	 * @param filterByTopic - Topic to filter with,
	 * @param filterByAuthor - Author to filter with
	 * @param topicName - Used to topic record pages
	 * @param filterOn - Filter on string,
	 * @param searchTerm - search news containing this term
	 * @param fromDate - filter news with publish date from
	 * @param toDate - filter news with publish date to
	 * @param listofNewsIds - List of News record Ids
	 * @param isFeatured - If filter with featured news or not
	 * @param customFields custom fields
	 *
	 * @return x7sNewsWrapper - News wrapper
	 */
	@AuraEnabled
	public static x7sNewsWrapper getNewsForPage(
		Integer numberOfNewsPerPage,
		Integer pageNumber,
		String strRecordId,
		String networkIds,
		String sortBy,
		String filterByTopic,
		String filterByAuthor,
		String topicName,
		String filterOn,
		String searchTerm,
		String fromDate,
		String toDate,
		List<String> listofNewsIds,
		Boolean isFeatured,
		String customFields) {

		try {
			customFieldList = getCustomFields(customFields);

			Integer pageNumberValue = pageNumber != null ? Integer.valueOf(pageNumber) : 1;

			x7sNewsWrapper newsWrapper = getNews(
				numberOfNewsPerPage,
				strRecordId,
				networkIds,
				sortBy,
				filterByTopic,
				filterByAuthor,
				topicName,
				filterOn,
				searchTerm,
				fromDate,
				toDate,
				listofNewsIds,
				isFeatured,
				customFields);

			newsWrapper.pageNumber = pageNumberValue;
			newsWrapper.currentPage();

			return newsWrapper;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description : Get a list of all the groups this user is a member of
	 *
	 * @return Map Groups Id, Group
	 */
	@AuraEnabled
	public static Map<String, String> getGroups() {
		try {
			Map<String, String> groups = new Map<String, String>();

			if (UserInfo.getUserType() != 'Guest') {
				for (CollaborationGroupMember member : [
						SELECT Id, CollaborationGroupId, CollaborationGroup.Name
						FROM CollaborationGroupMember
						WHERE MemberId = :UserInfo.getUserId() AND NetworkId = :networkId
						LIMIT 1000
				]) {
					groups.put(member.CollaborationGroupId, member.CollaborationGroup.Name);
				}
			}

			return groups;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description Get a list of all the groups
	 *
	 * @return Map GroupdId, Group
	 */
	public static Map<String, String> getAllGroups() {
		Map<String, String> groups = new Map<String, String>();

		for (CollaborationGroup groupItem : [
				SELECT Id, Name
				FROM CollaborationGroup
				WHERE NetworkId = :networkId
				LIMIT 1000
		]) {
			groups.put(groupItem.Id, groupItem.Name);
		}

		return groups;
	}

	/**
	 * :  @description fetch site prefix so that urls are redirected properly dynamically in any org.
	 *
	 * @return Path prefix
	 */
	@AuraEnabled (Cacheable=true)
	public static String getSitePrefix() {
		try {
			return System.Site.getPathPrefix();
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	static public String validateId(String idParam) {
		try {
			if (String.isNotBlank(idParam)) {
				String recId = String.escapeSingleQuotes(idParam);
				return (String.isNotBlank(recId) &&
						Id.valueOf(recId).getSobjectType() == X7S_News__c.SObjectType) ? recId : null;
			}

			return null;
		}
		catch (Exception e) {
			return null;
		}
	}

	/**
	 * @description Method to fetch news record as per newsRecordId used on news detail page components
	 *
	 * @param newsRecordId requested news record Id
	 *
	 * @return NewsWrapper
	 */
	@AuraEnabled
	public static x7sNewsWrapper getNewsRecord(String newsRecordId) {
		List<String> audienceIds = new List<String>();

		try {
			Boolean useAudience = audienceEnabled() && !userAuthorizedToViewAll();

			if (useAudience) {
				audienceIds = getAudienceTargetIds(strNetworkId);
			}
			String Query = getSobjectQueryString(TOKEN_SOBJECT_NAME);

			User currentUser = getCurrentUser();
			if (String.isNotBlank(Query)) {
				Query += ' Where Id = \'' + String.escapeSingleQuotes(newsRecordId) + '\'';
				if (useAudience) {
					Query += getAudienceQuery(audienceIds);
				}

				if (String.isNotBlank(networkId)) {
					Query += ' AND (NetworkId__c = \'' + networkId + '\'';
					Query += ' OR NetworkId__c = \'' + strNetworkId + '\')';
				}
				else {
					Query += ' AND NetworkId__c = null';
				}

				Query += ' AND Publish_DateTime__c <= :rightNow';
				Query += ' LIMIT 1';

				return new x7sNewsWrapper(Query, getLanguage(), 1, null, null, null, null, null, false, null, null, currentUser.UserType, audienceIds);
			}

			return null;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@AuraEnabled
    public static x7sNewsWrapper getNewsRecord(String newsRecordId, String customFields) {
		try {			
			if (String.isNotBlank(customFields)) {
				customFieldList = getCustomFields(customFields);
			}

			return getNewsRecord(newsRecordId);
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
    }

	private static List<String> getCustomFields(String fieldList) {
        List<String> fieldsSet = String.escapeSingleQuotes(fieldList).split(NEWS_FIELD_SEPARATOR);

        // prefix the namespace
        for (Integer pos = 0; pos < fieldsSet.size(); pos++) {
            String fieldValue = fieldsSet.get(pos);
            fieldsSet.set(pos, fieldValue);
        }

        List<String> fields = new List<String>();

        Map<String, Schema.SObjectField> eventFldMap = Schema.SObjectType.X7S_News__c.fields.getMap();

        for (String field : fieldsSet) {
            if (eventFldMap.containsKey(field.trim())) {
                fields.add(field.trim());
            } else {
                System.debug('Custom field ' + field + ' not found on the X7S_News__c record');
            }
        }

        return fields;
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
		try {
			if(String.isNotBlank(recordId)) {
				Id myId = (Id) recordId;
				String sObjName = myId.getSobjectType().getDescribe().getName();				
		
				String queryRecord = 'SELECT Id, Name FROM ' + sObjName + ' WHERE Id =: myId WITH USER_MODE';

				results.addAll(Database.query(queryRecord));//NOPMD
			}

			return results;

		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description :  Method to save new news object used on create news component.
	 *
	 * @param newsObj News object
	 * @param strFilterByTopic topic filter
	 * @param attachmentType Attachment Type
	 * @param attachmentName Image attachment file name
	 * @param image Featured image as a binary64 encoded string
	 * @param audience Target audience
	 * @param publishNow publish immediately
	 *
	 * @return news model
	 */
	@AuraEnabled
	public static x7sNewsModel saveNews(
		X7S_News__c newsObj,
		String strFilterByTopic,
		String attachmentType,
		String attachmentName,
		String image,
		String audience,
		Boolean publishNow) {

		requireAuthenticatedUser();
		x7sNewsModel modelCls = new x7sNewsModel();
		try {
			if (newsObj != null) {
				if (!X7S_News__c.SObjectType.getDescribe().isCreateable() ||
					!X7S_News__c.SObjectType.getDescribe().isUpdateable() ||
					!Attachment.SObjectType.getDescribe().isCreateable() ||
					!TopicAssignment.SObjectType.getDescribe().isCreateable() ||
					!TopicAssignment.SObjectType.getDescribe().isDeletable()) {
					System.debug('saveNews() : Access Denied!');
				}

				newsObj.NetworkId__c = networkId;
				newsObj.Audience_Selected__c = String.isNotBlank(audience);

				Map<String, TopicAssignment> topicMap = new Map<String, TopicAssignment>();

				if (newsObj.Id != null) {
					String queryTopicAssignment = x7sNewsBaseController.getQueryString(x7sNewsBaseController.TOPIC_ASSIGNMENT_OBJ);

					if (String.isNotBlank(queryTopicAssignment)) {
						List<TopicAssignment> topicAssignments = Database.query(String.escapeSingleQuotes(queryTopicAssignment) +
							' WHERE EntityId = \'' + String.escapeSingleQuotes(newsObj.Id) + '\'' + ' LIMIT 1000'
						);
						for (TopicAssignment tAssgn : topicAssignments) {
							topicMap.put(tAssgn.TopicId, tAssgn);
						}
					}
				}

				upsert newsObj;

				modelCls.id = newsObj.Id;

				if (String.isNotEmpty(image) && String.isNotEmpty(attachmentType) && String.isNotEmpty(attachmentName)) {
					if (newsObj.Image_Type__c == 'Attachment') {
						Attachment attachment = new Attachment();

						attachment.Body = EncodingUtil.base64Decode(image);
						attachment.Name = String.valueOf(('' + attachmentName));
						attachment.ParentId = newsObj.Id;
						attachment.ContentType = attachmentType;

						insert attachment;

					} else if (newsObj.Image_Type__c == 'Related File') {
						if(ContentVersion.SObjectType.getDescribe().isCreateable() &&
							Schema.SObjectType.ContentVersion.fields.Title.isCreateable() &&
							Schema.SObjectType.ContentVersion.fields.PathOnClient.isCreateable() &&
							Schema.SObjectType.ContentVersion.fields.ContentLocation.isCreateable() &&
							Schema.SObjectType.ContentVersion.fields.VersionData.isCreateable() &&
							ContentDocumentLink.SObjectType.getDescribe().isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.ContentDocumentId.isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.LinkedEntityId.isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.ShareType.isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.Visibility.isCreateable()) {

							ContentVersion content = new ContentVersion();

							content.Title = attachmentName;
							content.PathOnClient = '/' + attachmentName;
							content.ContentLocation = 'S';
							content.VersionData = EncodingUtil.base64Decode(image);

							insert content;

							// link to the News record
							ContentVersion insertedContent = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :content.Id];

							ContentDocumentLink relatedLink = new ContentDocumentLink();

							relatedLink.ContentDocumentId = insertedContent.ContentDocumentId;
							relatedLink.LinkedEntityId = newsObj.Id;
							relatedLink.ShareType = 'I';
							relatedLink.Visibility = 'AllUsers';
							insert relatedLink;

							ContentDocumentLink docLink = [SELECT LinkedEntityId,ContentDocument.LatestPublishedVersionId
														FROM ContentDocumentLink
														WHERE LinkedEntityId = :newsObj.Id AND
														ContentDocumentId = :relatedLink.ContentDocumentId
														LIMIT 1];
							X7S_News__c news = [SELECT Id,Image_Reference__c FROM X7S_News__c WHERE Id = :newsObj.Id LIMIT 1];

							if(news.Id != null && docLink.ContentDocument.LatestPublishedVersionId != null && X7S_News__c.SObjectType.getDescribe().isUpdateable() &&
								Schema.SObjectType.X7S_News__c.fields.Image_Reference__c.isUpdateable()) {
								news.Image_Reference__c = docLink.ContentDocument.LatestPublishedVersionId;
								update news;
							}
						} else {
							System.debug('saveNews() - Access denied to upload related files');
						}
					}
				}

				if (!topicMap.isEmpty() || String.isNotBlank(strFilterByTopic)) {
					List<TopicAssignment> topicAssignmentLst = new List<TopicAssignment>();
					List<TopicAssignment> deleteAssignments = new List<TopicAssignment>();
					Set<String> topicLst = new Set<String>();

					if (String.isNotBlank(strFilterByTopic) && !strFilterByTopic.isWhitespace()) {
						topicLst.addAll(strFilterByTopic.split(NEWS_FIELD_SEPARATOR));
					}

					if (topicMap.isEmpty()) {
						for (String strTopicId : topicLst) {
							if (!String.isEmpty(strTopicId)) {
								TopicAssignment t = new TopicAssignment();
								t.EntityId = newsObj.Id;
								t.TopicId = strTopicId;
								topicAssignmentLst.add(t);
							}
						}	
					} else {
						// check existing assignments to see if they should be retained
						for (String topicId : topicMap.keySet()) {
							if (!topicLst.contains(topicId)) {
								deleteAssignments.add(topicMap.get(topicId));
							}
						}
						// check separately for assignments that need to be created new
						list<String> existingAssignments = new List<String>(topicMap.keySet());
						for (String tId : topicLst) {
							if (!existingAssignments.contains(tId)) {
								TopicAssignment t = new TopicAssignment();
								t.EntityId = newsObj.Id;
								t.TopicId = tId;
								topicAssignmentLst.add(t);
							}
						}
					}

					if (!deleteAssignments.isEmpty()) {
						delete deleteAssignments;
					}

					if (!topicAssignmentLst.isEmpty()) {
						insert topicAssignmentLst;
					}
				}

				// Sharing - check CMT flag
				List<String> userOrGroupList;
				Datetime rightNow = Datetime.now();

				if (useManagedSharing()) {
					if (String.isNotBlank(newsObj.GroupId__c)) { userOrGroupList.add(newsObj.GroupId__c);} else { userOrGroupList = getUserGroupId();}

					if (newsObj.Publish_DateTime__c <= rightNow) { for (String userOrGroup : userOrGroupList) { shareRecord(newsObj, userOrGroup);}}
					else { for (String userOrGroup : userOrGroupList) { unShareRecord(newsObj, userOrGroup);} }
				}

				// create an audience target record for this item
				if (String.isNotBlank(audience)) { assignAudienceToRecord(audience, newsObj.Id, strNetworkId);}
			}

			return modelCls;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/*
	* @description   :  Method to generate dynamic query for objects used in process.
	*				  this method is generating query for News,Attachment (as child query),User (some fields of user needed in news object) as per our requirement
	*/
	private static String getSobjectQueryString(String strObj) {

		List<String> objectAccessFields = x7sNewsBaseController.getAccessibleFields(strObj);

		if (objectAccessFields != null && !objectAccessFields.isEmpty()) {
			String query = '';
			List<String> childFields = x7sNewsBaseController.getAccessibleFields('Attachment');


			objectAccessFields.add(String.escapeSingleQuotes('Author__r.Name'));
			objectAccessFields.add(String.escapeSingleQuotes('CreatedBy.Name'));
			objectAccessFields.add(String.escapeSingleQuotes('createdBy.FullPhotoUrl'));
			objectAccessFields.add(String.escapeSingleQuotes('Author__r.FullPhotoUrl'));
			objectAccessFields.add(String.escapeSingleQuotes('createdBy.SmallPhotoUrl'));
			objectAccessFields.add(String.escapeSingleQuotes('Author__r.SmallPhotoUrl'));
			objectAccessFields.add(String.escapeSingleQuotes('Author__r.CommunityNickName'));
			objectAccessFields.add(String.escapeSingleQuotes('createdBy.CommunityNickname'));
			objectAccessFields.add(String.escapeSingleQuotes('RecordType.Name'));
			objectAccessFields.add(String.escapeSingleQuotes('Owner.Name'));

			query += 'SELECT ';
			query += String.join(objectAccessFields, ',');

			if (customFieldList != null) {
				for (String field : customFieldList) {
					if (!objectAccessFields.contains(field)) {
						query += ', ' + String.escapeSingleQuotes(field.trim());
					}
				}
			}

			if (childFields != null && !childFields.isEmpty()) {
				query += ',(' + 'SELECT ' + String.join(childFields, ',') + ' FROM Attachments )';
			}

			String userLanguage = getLanguage();

			if (String.isNotBlank(userLanguage)) {
				User currentUser = getCurrentUser();
				if (currentUser.UserType != FOR_GUEST_TYPE) {
					List<String> childTranslateFields = x7sNewsBaseController.getAccessibleFields('X7S_News_Translation__c');

					if (childTranslateFields != null && !childTranslateFields.isEmpty()) {
						query += ',(' + 'SELECT ' + String.join(childTranslateFields, ',') + ' FROM X7S_News_Translation__r ';
						query += ' WHERE Language__c = \'' + String.escapeSingleQuotes(userLanguage) + '\')';
					}
				}
			}

			query += ' FROM ';
			if (strObj.contains(CUSTOM_OBJ_EXTENSION)) {
				query += getOrgNamespace();
			}
			query += strObj;

			return query;
		}
		else {
			return null;
		}
	}

	@AuraEnabled
	public static Boolean isLiking(String recordId) {
		try {
			return x7sNewsLikeController.isLiking(recordId);
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@AuraEnabled
	public static Boolean likeNews(String recordId) {
		requireAuthenticatedUser();
		try {
			return x7sNewsLikeController.likeNews(recordId);
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	@AuraEnabled
	public static Boolean unLikeNews(String recordId) {
		requireAuthenticatedUser();
		try {
			return x7sNewsLikeController.unLikeNews(recordId);
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	private static Boolean useManagedSharing() {
		Boolean useSharing = false;

		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);

			if(setting != null) {
				useSharing = setting.Use_Managed_Sharing__c;
			}
		}
		catch (Exception e) { System.debug(System.LoggingLevel.ERROR, 'X7S_News_Setting__mdt not configured for Use_Managed_Sharing');}

		return useSharing;
	}

	@TestVisible
	private static List<String> getUserGroupId() {
		List<String> idList = new List<String>();

		try {
			X7S_News_Setting__mdt setting =  X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);
			idList = setting.UserOrGroupId__c.split(NEWS_FIELD_SEPARATOR);
		}
		catch (Exception e) {
			System.debug(System.LoggingLevel.ERROR, 'X7S_News_Setting__mdt not configured for UserOrGroupId');
		}

		return idList;
	}

	@TestVisible
	private static void shareRecord(SObject shareRecord, Id userOrGroup) {
		if (shareRecord.get('OwnerId') == userOrGroup || !isRecordShareable((String) shareRecord.get('Id'))) { return;}

		String objName = shareRecord.getSObjectType().getDescribe().getName();
		Id parentId = (Id) shareRecord.get('Id');
		SObject shareObject = newSObject(objName.replace(CUSTOM_OBJ_EXTENSION, '__Share'));
		List<String> causes = getRowCause(shareObject, 'RowCause');
		String shareLevel = 'READ';

		shareObject.put('ParentId', parentId);
		shareObject.put('AccessLevel', shareLevel);
		shareObject.put('UserOrGroupId', userOrGroup);
		shareObject.put('RowCause', causes[0]);

		insert shareObject; // NOPMD - Access check handled via call to isRecordShareable
	}

	@TestVisible
	private static void unShareRecord(SObject shareRecord, Id userOrGroup) {
		if (shareRecord.get('OwnerId') == userOrGroup || !isRecordShareable((String) shareRecord.get('Id'))) { return;}

		String objName = shareRecord.getSObjectType().getDescribe().getName();
		String shareName = objName.endsWith(CUSTOM_OBJ_EXTENSION) ? objName.replace(CUSTOM_OBJ_EXTENSION, '__Share') : (objName + 'Share');
		Id parentId = (Id) shareRecord.get('Id');
		
		String query = 'SELECT Id, ParentId FROM ' + shareName + ' WHERE ParentId = \'' + parentId + '\'';
		List<SObject> shareObjects = (List<SObject>) Database.query(String.escapeSingleQuotes(query));

		if (!shareObjects.isEmpty()) {
			delete shareObjects; // NOPMD - Access check handled via call to isRecordShareable
		}
	}

	public class UndefinedSObjectTypeException extends Exception {
	}

	// typeName must be a valid API name (i.e. custom objects should be suffixed with "__c"):
	@TestVisible
	private static SObject newSObject(String typeName) {
		Schema.SObjectType targetType = Schema.getGlobalDescribe().get(typeName);

		if (targetType == null) {
			// calling code should usually handle this exception:
			throw new UndefinedSObjectTypeException('The requested SObject type [' + typeName + '] cannot be constructed - it is not configured in this org.');
		}

		// SObjects offer the only way in Apex to instantiate an object with a type determined at
		// runtime -- you can optionally pass an Id argument to instantiate an SObject for an existing record:
		return targetType.newSObject();
	}

	@TestVisible
	private static List<String> getRowCause(SObject targetObject, String fieldName) {
		List<String> values = new List<String>();
		Schema.SObjectType objType = targetObject.getSObjectType();
		Schema.DescribeSObjectResult objDescribe = objType.getDescribe();

		Map < String, Schema.SObjectField > fieldMap = objDescribe.fields.getMap();

		for (Schema.PicklistEntry a : fieldMap.get(fieldName).getDescribe().getPicklistValues()) {
			values.add(a.getValue());
		}

		return values;
	}

	@TestVisible
	private static Boolean useLanguage() {
		Boolean useMultiLanguage = false;

		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);
			if(setting != null) {
				useMultiLanguage = setting.Enable_Multi_Language__c;
			}
		}
		catch (Exception e) {
			System.debug(System.LoggingLevel.ERROR, 'X7S_News_Setting__mdt not configured for Enable_Multi_Language__c');
		}

		return useMultiLanguage;
	}

	@AuraEnabled(Cacheable=true)
	public static String getLanguage() {
		String userLanguage = '';
		User currentUser = getCurrentUser();
		try {
			if (useLanguage() && String.isNotBlank(currentUser.LanguageLocaleKey)) {
				userLanguage = currentUser.LanguageLocaleKey;
			}
			return userLanguage;
		}
		catch (Exception e) { System.debug(System.LoggingLevel.ERROR, 'User local language not configured for translation'); throw new AuraHandledException(e.getMessage());}
	}


	//////////////////////////////////////////////////////////////////////////////////////////////////
	// Audience Personalization
	//

	final static ConnectApi.PublishStatus CONNECT_API_PUBLISH_STATUS_DRAFT = ConnectApi.PublishStatus.Draft;
	final static ConnectApi.PublishStatus CONNECT_API_PUBLISH_STATUS_LIVE = ConnectApi.PublishStatus.Live;
	final static String DEFAULT_PUBLISH_STATUS = 'Draft';	
	final static Integer AUDIENCE_QUERY_LIMIT = 200;

	/**
	 * @description Check CMT record for audience checkbox
	 *
	 * @return Audience enabled status - true or false
	 */
	@AuraEnabled(Cacheable=true)
	public static Boolean audienceEnabled() {
		Boolean enabled = false;
		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);
			if(setting != null) {
				enabled = setting.Enable_Audience_Targeting__c;
			}
		}
		catch (Exception ex) { System.debug('CMT audienceEnabled exception: ' + ex.getMessage()); throw new AuraHandledException(ex.getMessage());}

		return enabled;
	}

	/**
	 * @description Assign the item to an audience
	 *
	 * @param audienceId Selected Audience is
	 * @param recordId record Id
	 * @param networkId Community ID
	 *  NOTE: networkId must be provided as the future method does not have access to NetWork
	 */
	@Future
	public static void assignAudienceToRecord(String audienceId, String recordId, String networkId) {

		ConnectApi.TargetCollectionInput inputCollection = new ConnectApi.TargetCollectionInput();
		List<ConnectApi.TargetInput> targetInputList = new List<ConnectApi.TargetInput>();
		ConnectApi.TargetInput targetInput = new ConnectApi.TargetInput();

		targetInput.audienceId = audienceId.substring(0, 15);
		targetInput.groupName = TOKEN_GROUP_NAME;
		targetInput.publishStatus = CONNECT_API_PUBLISH_STATUS_LIVE;
		targetInput.targetType = TOKEN_SOBJECT_NAME;
		targetInput.targetValue = recordId.substring(0, 15);

		targetInputList.add(targetInput);

		inputCollection.targets = targetInputList;

		// Add as Draft
		for (ConnectApi.TargetInput input : inputCollection.targets) { input.publishStatus = CONNECT_API_PUBLISH_STATUS_DRAFT;}
		ConnectApi.Personalization.createTargets(networkId, inputCollection);
	}

	/**
	 * @description Remove the item from the audience
	 * Clear the audience flag.
	 *
	 * @param recordId record Id
	 */
	@AuraEnabled
	public static void deleteCurrentAudience(String recordId) {
		requireAuthenticatedUser();
		try {
			if (Schema.SObjectType.X7S_News__c.isUpdateable()) {
				X7S_News__c newsItem = [SELECT Id, Audience_Selected__c FROM X7S_News__c WHERE Id = :recordId WITH SECURITY_ENFORCED LIMIT 1];
				if (newsItem != null) {
					newsItem.Audience_Selected__c = false;
					update newsItem;
				}

				deleteAudienceRecord(System.Network.getNetworkId(), recordId);
			}
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description Remove the item from the audience
	 *
	 * @param networkId Community Id
	 * @param recordId record Id
	 * NOTE: networkId must be provided as the future method do not have access to NetWork
	 */
	@Future
	public static void deleteAudienceRecord(String networkId, String recordId) {
		if (String.isNotBlank(recordId)) {
			String communityId = String.isBlank(networkId) ? System.Network.getNetworkId() : networkId;
			if (String.isBlank(communityId)) {
				if (Test.isRunningTest()) { communityId = x7sNewsUtilityTest.strNetworkId;}
				else { return;}
			}
			List<String> targets = getTargetsForRecordId(communityId, recordId);

			if (!targets.isEmpty()) {
				
				for (String target : targets) {
					ConnectApi.Personalization.deleteTarget(communityId.substring(0, 15), target.substring(0, 15));
				}
			}
		}
	}

	public static List<String> getAudienceTargetIds(String networkId) {
		List<String> targetIds = new List<String>();
		List<String> targetTypes = new List<String>{TOKEN_SOBJECT_NAME};
		List<String> groupTypes = new List<String>{TOKEN_GROUP_NAME};
		Boolean includeAudience = true;
		Boolean includeInGroups = true;

		String communityId = String.isBlank(networkId) ? System.Network.getNetworkId() : networkId;
		if (String.isBlank(communityId)) {
			if (Test.isRunningTest()) { communityId = x7sNewsUtilityTest.strNetworkId;}
			else { return targetIds;}
		}

		ConnectApi.TargetCollection targetCollection = ConnectApi.Personalization.getTargets(communityId.substring(0, 15), null, null, null, CONNECT_API_PUBLISH_STATUS_DRAFT, null, targetTypes, includeAudience, includeInGroups, groupTypes);

		for (ConnectApi.Target target : targetCollection.targets) { targetIds.add(target.targetValue);}
		
		return targetIds;
	}

	/**
	 * @description Get the audience Id for the specified record
	 *
	 * @param networkId Community ID
	 * @param recordId Item record Id
	 *
	 * @return Audience id
	 */
	@AuraEnabled
	public static String getAudienceIdForRecordId(String networkId, String recordId) {
		try {
			String audienceId = '';
			ConnectApi.Target target = getTarget(networkId, recordId);

			if (target != null) { audienceId = (String) ((ConnectApi.AudienceTarget) target.audience).id;}

			return audienceId;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	public static List<String> getTargetsForRecordId(String networkId, String recordId) {
		List<String> targetIds = new List<String>();

		String communityId = String.isBlank(networkId) ? System.Network.getNetworkId() : networkId;
		if (String.isBlank(communityId)) {
			if (Test.isRunningTest()) { communityId = x7sNewsUtilityTest.strNetworkId;} else { return targetIds;}
		}

		String targetRecordId = recordId.substring(0, 15);
		String targetCommunity = communityId.substring(0, 15);

		List<PersonalizationTargetInfo> targets = [SELECT Id, ContainerId, TargetValue, PublishStatus FROM PersonalizationTargetInfo WHERE ContainerId = :targetCommunity AND TargetValue = :targetRecordId WITH SECURITY_ENFORCED ORDER BY PublishStatus DESC LIMIT :AUDIENCE_QUERY_LIMIT];

		if (!targets.isEmpty()) {
			for (PersonalizationTargetInfo target : targets) { targetIds.add(target.Id);}
		}

		return targetIds;
	}

	private static ConnectApi.Target getTarget(String networkId, String recordId) {
		ConnectApi.Target target = null;

		String communityId = String.isBlank(networkId) ? System.Network.getNetworkId() : networkId;
		String targetValue = String.isNotBlank(recordId) ? recordId.substring(0, 15) : null;

		List<PersonalizationTargetInfo> targetInfos = [
			SELECT Id, DraftRowId, ContainerId, TargetType, TargetValue, GroupName, PublishStatus
			FROM PersonalizationTargetInfo
			WHERE TargetValue = :targetValue AND ContainerId = :communityId
			WITH SECURITY_ENFORCED
		];

		if (!targetInfos.isEmpty()) {
			String targetId = targetInfos[0].Id;

			target = ConnectApi.Personalization.getTarget(communityId, targetId);
		}

		return target;
	}

	/**
	 * @description Used to get timzone in which article will be published based on CMT settings
	 *
	 * @return Timezone Display Name
	 */
	@AuraEnabled
	public static String getTimeZone() {
		TimeZone tz = UserInfo.getTimeZone();

		try {
			X7S_News_Setting__mdt setting = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);

			if(setting != null && setting.Article_Publish_Date__c == 'Company Time Zone') {
				String timeZoneId = [SELECT TimeZoneSidKey FROM Organization LIMIT 1]?.TimeZoneSidKey;
				tz = TimeZone.getTimeZone(timeZoneId);
			}

			return tz.getDisplayName();		
		}
		catch (Exception ex) { System.debug(System.LoggingLevel.ERROR, 'X7S_News_Setting__mdt not configured ' + +ex.getMessage()); throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description Use to check the Publish Date and time.
	 * @return true if future publish Date and time.
	 */

	@AuraEnabled
	public static Boolean checkPublishedDateTime(String recordId) {
		Datetime current = Datetime.now();

		try {
			Datetime published = [SELECT Publish_DateTime__c FROM X7S_News__c WHERE Id=:recordId ].Publish_DateTime__c;
			return current.getTime() < published.getTime();
		} catch(Exception e) {throw new AuraHandledException(e.getMessage());}
	}
	/**
	 * @description :  get default fieldset
	 * 
	 * @return string as name of the fieldset
	 */
	@AuraEnabled
    public static String getFieldSetName() {
		try {
			String shrFieldSet = '';
			X7S_News_Setting__mdt fieldSet = X7S_News_Setting__mdt.getInstance(NEWS_CMT_SETTING_DEFAULT);
			if(fieldSet.X7S_News_Default_Custom_Field_Set__c != null) {
				String fieldSetId = fieldSet.X7S_News_Default_Custom_Field_Set__c;
				X7S_Shr_Custom_Field_Set__mdt fieldSetName = X7S_Shr_Custom_Field_Set__mdt.getInstance(fieldSetId);
				if(fieldSetName.Active__c && fieldSetName.Object_API_Name__c == 'X7S_News__c'){
                    shrFieldSet = fieldSetName.DeveloperName;
                }
			}
			return shrFieldSet;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	/**
	 * @description :  Method to fetch users and display in dropdown of "Author Filter" component.
	 *
	 * @return Map UserId, User
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<String, String> getUsers() {

		try {
			Map<String, String> users = new Map<String, String>();
			Boolean useNickname = isNicknameDisplayEnabled();

			if(String.isNotBlank(networkId)) {
				String queryUser = x7sNewsBaseController.getQueryString('NetworkMember') + ' n';

				if (String.isNotBlank(queryUser)) {
					
					List<NetworkMember> userLst = Database.query(String.escapeSingleQuotes(queryUser) +
						' WHERE (NetworkId = \'' + String.escapeSingleQuotes(networkId) + '\'' +
						' OR NetworkId = \'' + String.escapeSingleQuotes(strNetworkId) + '\')' +
						' AND n.Member.IsActive = TRUE' +
						' LIMIT ' + USER_SEARCH_LIMIT
					);

					for (NetworkMember nMember : userLst) {
						users.put(nMember.MemberId, useNickname ? nMember.Member.CommunityNickname : nMember.Member.Name);
					}
				}
			} else {
				List<User> userList = [SELECT Id, Name, IsActive, CommunityNickname FROM User WHERE IsActive = TRUE AND UserType != :FOR_GUEST_TYPE LIMIT :USER_SEARCH_LIMIT];

				for(User user : userList) {
					users.put(user.Id, useNickname ? user.CommunityNickname : user.Name);
				}	
			} 
			// make sure we add the current user
			User currentUser = getCurrentUser();
			if (!users.containsKey(currentUser.Id)) { users.put(currentUser.Id, useNickname ? currentUser.CommunityNickname : currentUser.Name);}

			return users;
		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

    /**
	 * @description :  Method to fetch users and display in dropdown of "Author Filter" component.
	 *
	 * @return Map AuthorId, Author
	 */
	@AuraEnabled(Cacheable=true)
	public static Map<String, String> getAuthors() {
		try {
			Map<String, String> authors = new Map<String, String>();

			if (Schema.SObjectType.X7S_News__c.isAccessible() && Schema.SObjectType.X7S_News__c.fields.Author__c.isAccessible()) {
				String queryBefore = 'SELECT Author__c authorId, Author__r.Name authorName, Author__r.CommunityNickname authorNickname';
				String queryAfter = '';

				queryBefore += ' FROM ';
				queryBefore += getOrgNamespace();
				queryBefore += TOKEN_SOBJECT_NAME;

				queryAfter += ' AND Author__c != null';
				queryAfter += ' GROUP BY Author__c, Author__r.Name, Author__r.CommunityNickname';
				queryAfter += ' LIMIT ' + USER_SEARCH_LIMIT;

				List<AggregateResult> newsLst;

				if (String.isNotBlank(networkId)) {
					newsLst = Database.query(String.escapeSingleQuotes(queryBefore) +
						' WHERE (NetworkId__c = \'' + String.escapeSingleQuotes(networkId) + '\'' +
						' OR NetworkId__c = \'' + String.escapeSingleQuotes(strNetworkId) + '\')' +
						String.escapeSingleQuotes(queryAfter)
					);
				}
				else {
					newsLst = Database.query(String.escapeSingleQuotes(queryBefore) + ' WHERE NetworkId__c = NULL' + String.escapeSingleQuotes(queryAfter));
				}

				Boolean useNickName = isNicknameDisplayEnabled();

				for (AggregateResult n : newsLst) {
					authors.put(String.valueOf(n.get('authorId')),
						useNickName ? String.valueOf(n.get('authorNickname')) : String.valueOf(n.get('authorName')));
				}
				return authors;
			} 

			return authors;

		} catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

    /**
	 * @description :  Method to search users and display for the dropdown of "Author Filter" component.
	 *
	 * @param searchString search string
	 *
	 * @return Map userId, user
	 */
	@AuraEnabled
	public static Map<String, String> searchUsers(String searchString) {
		Map<String, String> users = new Map<String, String>();	
		try {
			Boolean useNickName = isNicknameDisplayEnabled();	

			if (String.isNotBlank(networkId)) {
				String queryUser = x7sNewsBaseController.getQueryString(x7sNewsBaseController.NETWORK_MEMBER_OBJ) + ' n ';
				if (String.isNotBlank(queryUser)) {
					queryUser += ' WHERE (NetworkId = \'' + networkId + '\'';
					queryUser += ' OR NetworkId = \'' + String.escapeSingleQuotes(strNetworkId) + '\')';
				
					if (String.isNotBlank(searchString)) {
						queryUser += ' AND (n.Member.Name LIKE \'%' + String.escapeSingleQuotes(String.valueOf(searchString)) + '%\')';
					}

					queryUser += ' AND n.Member.IsActive = true';
					queryUser += ' LIMIT ' + USER_SEARCH_LIMIT;

					List<NetworkMember> userLst = Database.query(queryUser); // NOPMD - Embedded variables have been escaped

					for (NetworkMember nMember : userLst) { users.put(nMember.MemberId, useNickName ?  nMember.Member.CommunityNickname : nMember.Member.Name);}
				}
			} else {
					List<User> userList = new List<User>();

					if(String.isNotBlank(searchString)) {
						String tempSearchString = '%' + searchString + '%';
						userList = [SELECT Id, Name, IsActive, CommunityNickname 
										FROM User 
										WHERE IsActive = TRUE AND UserType != :FOR_GUEST_TYPE AND Name LIKE :tempSearchString
										WITH SECURITY_ENFORCED
										LIMIT :USER_SEARCH_LIMIT];
					} else {
						userList = [SELECT Id, Name, IsActive, CommunityNickname 
										FROM User 
										WHERE IsActive = TRUE AND UserType != :FOR_GUEST_TYPE
										WITH SECURITY_ENFORCED
										LIMIT :USER_SEARCH_LIMIT];
					}
		
					for(User user : userList) {
						users.put(user.Id, useNickName ? user.CommunityNickname : user.Name);
					}	
			}	
			return users;
		}
		catch(Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	private static void requireAuthenticatedUser() {
		if (Auth.CommunitiesUtil.isGuestUser()) {
			throw new AuraHandledException('Access denied.');
		}
	}
}