/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
/**
 * @description This class handles all the operation of Idea List components
 */
public without sharing class x7sIdeasViewController {
	/**
	 * @description To get common setting for Ideas
	 * @param zoneName Idea Zone Name
	 * @param loadCustomFields Whether to load custom fields or not
	 * @param fieldSetName Field Set Name
	 * @return Idea Settings
	 */
	@AuraEnabled
	public static x7sIdeasCommon getCommonSettings(
		String zoneName,
		Boolean loadCustomFields,
		String fieldSetName
	) {
		x7sIdeasCommon settings = new x7sIdeasCommon('', loadCustomFields);

		settings.sitePath = System.Site.getPathPrefix();
		settings.nicknameEnabled = x7sIdeasUtility.isNicknameDisplayEnabled();
		settings.isAuthenticated = x7sIdeasUtility.isAuthenticated();
		settings.zoneId = x7sIdeasUtility.getZoneId(zoneName);

		return settings;
	}

	/**
	 * @description Used to check if current user is authenticated or not
	 * @return True if authenticated else false
	 */
	@AuraEnabled
	public static Boolean isAuthenticated() {
		return x7sIdeasUtility.isAuthenticated();
	}

	/**
	 * @description Check if the user nickname should be displayed. This is a community preference but we use a CMT setting for LEX.
	 * @return true if display nickname is enabled
	 */
	@AuraEnabled
	public static Boolean isNicknameDisplayEnabled() {
		return x7sIdeasUtility.isNicknameDisplayEnabled();
	}

	private static UserRecordAccess getUserRecordAccess(String userId, String recordId) {
		String currentUserId = String.isBlank(userId) ? UserInfo.getUserId() : userId;
		try {
			return [
				SELECT
					RecordId,
					HasAllAccess,
					HasDeleteAccess,
					HasEditAccess,
					HasTransferAccess,
					HasReadAccess,
					MaxAccessLevel
				FROM UserRecordAccess
				WHERE UserId = :currentUserId AND RecordId = :recordId
			];
		} catch (Exception ex) {
			System.debug(
				'getUserRecordAccess() - Error :' +
				ex.getMessage() +
				',Line number : ' +
				ex.getLineNumber()
			);
			return null;
		}
	}

	/**
	 * @description Check if given record is editable for current User
	 * @param recordId Idea Record id
	 * @return true if editable else false
	 */
	@AuraEnabled
	public static Boolean isRecordEditable(String recordId) {
		try {
			return getUserRecordAccess(UserInfo.getUserId(), recordId).HasEditAccess;
		} catch (Exception e) {
			return false;
		}
	}

	/**
	 * @description Check if given record can be deleted by current User
	 * @param recordId Idea Record id
	 * @return true if user has delete access else false
	 */
	@AuraEnabled
	public static Boolean isRecordDeletable(String recordId) {
		try {
			return getUserRecordAccess(UserInfo.getUserId(), recordId).HasDeleteAccess;
		} catch (Exception e) {
			return false;
		}
	}

	/**
	 * @description Used to check if user has access to chatter feed
	 * @return true if user has chatter feed access else false
	 */
	@AuraEnabled
	public static Boolean userAuthorizedChatter() {
		System.debug('Check userAuthorizedChatter');
		Boolean authorized = false;

		x7sIdeasCommon settings = new x7sIdeasCommon('', false);
		String userId = UserInfo.getUserId();

		if (String.isNotBlank(settings.chatterPermissions)) {
			System.debug('Chatter permissions: ' + settings.chatterPermissions);
			authorized = x7sIdeasUtility.permissionSetMember(userId, settings.chatterPermissions);
		}

		if (!authorized && String.isNotBlank(settings.chatterProfiles)) {
			System.debug('Chatter profiles: ' + settings.chatterProfiles);
			authorized = x7sIdeasUtility.profileMember(userId, settings.chatterProfiles);
		}

		System.debug('    userAuthorizedChatter: ' + authorized);

		return authorized;
	}

	/**
	 * @description To get topics
	 * @param managedTopics Include Managed Topics Flag
	 * @return List of topics
	 */
	@AuraEnabled
	public static List<Topic> getTopicNamesList(Boolean managedTopics) {
		return x7sIdeasNewController.getTopicNamesList(managedTopics);
	}

	@AuraEnabled
	public static Map<String, String> getTopicMap(String topicName) {
		List<String> topicNames = new List<String>();
		topicNames.add(topicName);

		return x7sIdeasTopicController.getTopicMap(topicNames);
	}

	@AuraEnabled
	public static x7sIdeasListWrapper getIdeaRecord(
		String zoneId,
		String recordId,
		String customFields
	) {
		x7sIdeasCommon settings = new x7sIdeasCommon('', true);

		Set<Id> ideasIds = new Set<Id>{ recordId };
		Integer listSize = ideasIds.size();
		List<String> fields;
		if (customFields != null) {
			fields = getCustomFields(customFields);
		}

		String query =
			'SELECT Id,' +
			' Title,' +
			' Status,' +
			' CommunityId,' +
			' CreatedBy.Name,' +
			' CreatedBy.CommunityNickname,' +
			' CreatedBy.CreatedDate, ' +
			' CreatedById,' +
			' CreatorSmallPhotoUrl,' +
			' CreatedDate,' +
			' Categories,' +
			' VoteTotal,' +
			' AttachmentName,' +
			' NumComments,' +
			' Related_Topic_Name__c,' +
			' Requested_By__c,' +
			' IdeaThemeId,' +
			' IdeaTheme.Title,' +
			' Featured__c,' +
			' Body,' +
			' X7S_Ideas_Extension__c' +
			getCustomFieldsString(fields) +
			' FROM Idea WHERE Id IN :ideasIds';
		//			+
		//			' AND CommunityId = ' +
		//			'\'' + String.escapeSingleQuotes(zoneId) + '\''
		x7sIdeasListWrapper wrapper = new x7sIdeasListWrapper(query, listSize, ideasIds);

		return wrapper;
	}

	public static List<String> getCustomFields(String fieldList) {
		List<String> fields = new List<String>();
		if (fieldList != null) {
			List<String> fieldsSet = String.escapeSingleQuotes(fieldList).split(',');

			// prefix the namespace
			for (Integer pos = 0; pos < fieldsSet.size(); pos++) {
				String fieldValue = fieldsSet.get(pos);
				fieldsSet.set(pos, fieldValue);
			}

			Map<String, Schema.SObjectField> ideaFldMap = Schema.SObjectType.Idea.fields.getMap();

			for (String field : fieldsSet) {
				if (ideaFldMap.containsKey(field.trim())) {
					fields.add(field.trim());
				} else {
					System.debug('Custom field ' + field + ' not found on the Idea record');
				}
			}
		}
		return fields;
	}

	private static String getCustomFieldsString(List<String> fieldList) {
		List<String> customFields = new List<String>();

		if (fieldList != null) {
			for (String field : fieldList) {
				customFields.add(field);
			}
		}

		return customFields.size() > 0 ? (', ' + String.join(customFields, ', ')) : '';
	}

	@AuraEnabled
	public static List<Idea> getMergedIdeas(String recordId, String zoneId) {
		Id parentIdValue = Id.valueOf(recordId);
		Id zoneIdValue = Id.valueOf(zoneId);
		try {
			List<Idea> mergedIdeas = [
				SELECT Id, Title, ParentIdeaId, CreatedById, CreatedDate, IsMerged, CommunityId
				FROM Idea
				WHERE IsMerged = TRUE AND ParentIdeaId = :parentIdValue AND CommunityId = :zoneIdValue
			];

			return mergedIdeas;
		} catch (Exception ex) {
			System.debug(
				'getMergedIdeas() - Error :' +
				ex.getMessage() +
				',Line number : ' +
				ex.getLineNumber()
			);
			return new List<Idea>();
		}
	}

	@AuraEnabled
	public static Boolean deleteIdea(String ideaId) {
		return x7sIdeasNewController.deleteIdea(ideaId);
	}

	@AuraEnabled
	public static Vote vote(String recordId, Boolean isUp) {
		System.debug('Voting: ' + recordId + ', ' + isUp);
		Vote theVote = null;
		try {
			if (String.isNotBlank(recordId) && Vote.SObjectType.getDescribe().isCreateable()) {
				Id recordIdValue = Id.valueOf(recordId);
				theVote = new Vote();
				theVote.ParentId = recordIdValue;

				theVote.Type = isUp ? 'Up' : 'Down';

				insert theVote;
				System.debug('Voted: ' + theVote);
			}
		} catch (Exception e) {
			System.debug('Apex Error: ' + e);
			return null;
		}
		return theVote;
	}
	@AuraEnabled
	public static Vote deleteVote(String recordId) {
		System.debug('Voting: ' + recordId);
		Vote theVote = null;
		try {
			if (String.isNotBlank(recordId) && Vote.SObjectType.getDescribe().isDeletable()) {
				Id recordIdValue = Id.valueOf(recordId);
				theVote = [SELECT Id FROM Vote WHERE Id = :recordIdValue];

				delete theVote;
				System.debug('Deleted Vote: ' + theVote);
			}
		} catch (Exception e) {
			System.debug('Apex Error: ' + e);
			return null;
		}
		return theVote;
	}
	@AuraEnabled
	public static Vote getVote(String recordId) {
		// check if guest user
		String loggedInUserType = UserInfo.getUserType();

		if (loggedInUserType != 'Guest') {
			try {
				return [
					SELECT Id, ParentId, Type, CreatedById, IsDeleted
					FROM Vote
					WHERE
						ParentId = :recordId
						AND CreatedById = :UserInfo.getUserId()
						AND IsDeleted = FALSE
					LIMIT 1
				];
			} catch (Exception e) {
				// No votes yet
				Vote v = new Vote();
				v.ParentId = recordId;
				return v;
			}
		} else {
			return null;
		}
	}

	@AuraEnabled
	public static List<String> getIdeaStatusValues(String zoneName) {
		return x7sIdeasUtility.getIdeaStatusValues(zoneName);
	}

	// Subscription related
	// -----------------------------------------------
	@AuraEnabled
	public static Boolean followIdea(String ideaId) {
		return x7sIdeasSubscription.ideaSubscribe(UserInfo.getUserId(), ideaId);
	}

	@AuraEnabled
	public static Boolean unFollowIdea(String ideaId) {
		return x7sIdeasSubscription.ideaUnSubscribe(UserInfo.getUserId(), ideaId);
	}

	@AuraEnabled
	public static Boolean isFollowingIdea(String ideaId) {
		return x7sIdeasSubscription.ideaIsSubscribed(UserInfo.getUserId(), ideaId);
	}

	// Voting related
	// ------------------------------------------------------
	@AuraEnabled
	public static VotingDetails getVotingLimitsForAccount(String ideaId) {
		VotingDetails votingDetails = new VotingDetails();
		Boolean ignoreVoteLimit = false;

		X7S_Ideas_Setting__mdt ideasSettings = X7S_Ideas_Setting__mdt.getInstance(
			x7sIdeasCommon.IDEAS_DEVELOPER_NAME
		);

		if (ideasSettings != null) {
			votingDetails.accountVoteLimitMessage = ideasSettings.Account_Limit_Message__c;
			ignoreVoteLimit = ideasSettings.Ignore_Vote_Limit_Field__c;
		}

		List<User> usr = (List<User>) Database.query(
			'SELECT Id, AccountId FROM User WHERE Id = ' +
			'\'' +
			String.escapeSingleQuotes(UserInfo.getUserId()) +
			'\' LIMIT 1'
		);

		if (!usr.isEmpty() && usr[0].AccountId != null) {
			List<Account> acc = (List<Account>) Database.query(
				'SELECT Id,Name FROM Account WHERE Id = ' +
				'\'' +
				String.escapeSingleQuotes(usr[0].AccountId) +
				'\' LIMIT 1'
			);

			if (!acc.isEmpty()) {
				if (!ignoreVoteLimit) {
					Map<Id, Integer> mapVoteCounts = new Map<Id, Integer>();
					Integer voteCount = 0;
					votingDetails.hasAccount = true;

					if (!acc.isEmpty()) {
						votingDetails.totalVotes = Integer.valueOf(
							ideasSettings.Account_Votes_per_Idea__c
						);
						List<Vote> listOfVotes = (List<Vote>) Database.query(
							'SELECT Id,ParentId,Parent.Type,CreatedById FROM Vote WHERE Parent.Type = \'Idea\' AND ParentId = ' +
							'\'' +
							String.escapeSingleQuotes(ideaId) +
							'\''
						);

						for (Vote vt : listOfVotes) {
							if (mapVoteCounts.containsKey(vt.CreatedById)) {
								mapVoteCounts.put(vt.CreatedById, mapVoteCounts.get(vt.CreatedById) + 1);
							} else {
								mapVoteCounts.put(vt.CreatedById, 1);
							}
						}

						List<User> listOfUsersVoted = (List<User>) Database.query(
							'SELECT Id,ContactId,AccountId from User WHERE AccountId = ' +
							'\'' +
							String.escapeSingleQuotes(acc[0].Id) +
							'\''
						);

						for (User user : listOfUsersVoted) {
							if (mapVoteCounts.containsKey(user.Id)) {
								voteCount = voteCount + mapVoteCounts.get(user.Id);
							}
						}
						votingDetails.currentVoteCount = voteCount;
					}
				}
			}
		}

		System.debug('getVotingLimitsForAccount - votingDetails: ' + votingDetails);

		return votingDetails;
	}

	public class VotingDetails {
		@AuraEnabled
		public Integer totalVotes;
		@AuraEnabled
		public Integer currentVoteCount;
		@AuraEnabled
		public String accountVoteLimitMessage;
		@AuraEnabled
		public Boolean hasAccount;

		public VotingDetails() {
			totalVotes = 0;
			currentVoteCount = 0;
			accountVoteLimitMessage = '';
			hasAccount = false;
		}
	}
}