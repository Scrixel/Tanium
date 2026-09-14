/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @Class Name          : x7sMembersWrapper
 * @Description         : Wrapper Apex class used by SVNSUMMITS_MemberController Apex class
 *                        Mainly this class was created for implementing pagination using set controller.
 */

public without sharing class x7sMembersWrapper {
	static Id networkId {
		get {
			return Test.isRunningTest()
				? x7sMembersUtilityTest.NETWORK_ID
				: System.Network.getNetworkId();
		}
	}

	@AuraEnabled
	public String currentUser { get; set; }

	@AuraEnabled
	public Boolean isInternalUser { get; set; }

	@AuraEnabled
	public Boolean isGuestUser { get; set; }

	@AuraEnabled
	public Boolean isExternalUser { get; set; }

	@AuraEnabled
	public List<User> membersList { get; set; }

	@AuraEnabled
	public List<NetworkMember> members { get; set; }

	@AuraEnabled
	public Map<Id, x7sMembersWrapperNetwork> mapUserId_Wrapper { get; set; }

	@AuraEnabled
	public Integer listSizeValue { get; set; }

	//Total number of result (records) returned in query
	@AuraEnabled
	public Integer totalResults { get; set; }

	//Total number of pages in pagination as per total results
	@AuraEnabled
	public Integer totalPages { get; set; }

	//Page number for all total number of pages
	@AuraEnabled
	public Integer pageNumber { get; set; }

	//Boolean to check is there previous functionality to show previous button on component
	@AuraEnabled
	public Boolean hasPreviousSet { get; set; }

	//Boolean to check is there next functionality to show next button on component
	@AuraEnabled
	public Boolean hasNextSet { get; set; }

	@AuraEnabled
	public ApexPages.StandardSetController setController { get; set; }

	public x7sMembersWrapper() {
		hasNextSet = false;
		hasPreviousSet = false;
		totalPages = 0;
		totalResults = 0;
		pageNumber = 0;
		members = new List<NetworkMember>();
		currentUser = UserInfo.getUserId();
		isInternalUser = UserInfo.getUserType() == 'Standard';
		isGuestUser = UserInfo.getUserType() == 'Guest';
		isExternalUser = !isInternalUser && !isGuestUser;
		membersList = new List<User>();
	}

	/**
	 * @Name  x7sMembersWrapper
	 * @param QUERY     (query string to query records)
	 * @param intLimit  is the limit to query
	 * @param lstMemberNicKNames list of member nick names
	 * @param setUserId Not Used
	 * @param nullifySSC clear the set controller
	 * @param isFeatured featured members
	 * @Description   : constructor for wrapper
	 */
	public x7sMembersWrapper(
		String QUERY,
		Integer intLimit,
		List<String> lstMemberNicKNames,
		Set<String> setUserId,
		Boolean nullifySSC,
		Boolean isFeatured
	) {
		this.membersList = new List<User>();
		this.currentUser = UserInfo.getUserId();
		isInternalUser = UserInfo.getUserType() == 'Standard';
		isGuestUser = UserInfo.getUserType() == 'Guest';
		isExternalUser = !isInternalUser && !isGuestUser;

		this.listSizeValue = intLimit;
		System.debug('Wrapper Query: ' + QUERY);

		this.setController = new ApexPages.StandardSetController(Database.getQueryLocator(QUERY));
		this.setController.setPageSize(listSizeValue);
		updateControllerAttributes(isFeatured, lstMemberNicKNames);

		if (nullifySSC) {
			this.setController = null;
		}
	}

	/**
        @Name          :  nextPage
        @Description   :  used in pagination on click on next button
    */
	public void nextPage() {
		this.setController.setPageNumber(this.pageNumber + 1 > 0 ? this.pageNumber + 1 : 1);
		updateControllerAttributes(false, null);
	}

	/**
        @Name          :  previousPage
        @Description   :  used in pagination on click on previous button
    */
	public void previousPage() {
		this.setController.setPageNumber(this.pageNumber - 1 > 0 ? this.pageNumber - 1 : 1);
		updateControllerAttributes(false, null);
	}

	/**
       @Name          :  updateControllerAttributes
       @param isFeatured boolean
       @param lstMemberNicKNames use nicknames
       @Description   :  used to set attributes of wrapper so that it can be used on components with proper data
   */
    @TestVisible
	private void updateControllerAttributes(Boolean isFeatured, List<String> lstMemberNicKNames) {
		if (isFeatured) {
			List<User> tempList = this.setController.getRecords();
			Map<String, User> tempUserMap = new Map<String, User>();

			for (User cMember : tempList) {
				tempUserMap.put(cMember.CommunityNickname, cMember);
			}

			for (String str : lstMemberNicKNames) {
				if (tempUserMap.containsKey(str)) {
					this.membersList.add(tempUserMap.get(str));
				}
			}
		} else {
			this.membersList = this.setController.getRecords();
		}

		updateWrapperContent(this.membersList);

		Integer resultSize = this.setController.getResultSize();
		Integer pageSize = this.setController.getPageSize();

		this.totalResults = resultSize;
		this.totalPages = resultSize > 0
			? (Math.mod(resultSize, pageSize) == 0 ? resultSize / pageSize : resultSize / pageSize + 1)
			: 0;
		this.pageNumber = this.totalPages > 0 ? this.setController.getPageNumber() : 0;
		this.hasPreviousSet = this.setController.getHasPrevious();
		this.hasNextSet = this.setController.getHasNext();
	}

	/**
		@Name          :  updateWrapperContent
		@param lstUser list of users
        @Description   :  used for making data for the wrapper class which will display the values associated with
                          the user like likes received, follower count, posts and knowledge topics
    */
	public void updateWrapperContent(List<User> lstUser) {
		mapUserId_Wrapper = new Map<Id, x7sMembersWrapperNetwork>();

		for (User objUser : lstUser) {
			x7sMembersWrapperNetwork objSVNSUMMITS_WrapperNetwork = new x7sMembersWrapperNetwork(objUser);
			mapUserId_Wrapper.put(objUser.Id, objSVNSUMMITS_WrapperNetwork);
		}
		getFollowersCount(mapUserId_Wrapper);
	}

	/**
        @Name          :    getFollowersCount
        @param mapUserId_Wrapper map of user ids
        @Description   :    used for fetching the number of followers
    */
	private void getFollowersCount(Map<Id, x7sMembersWrapperNetwork> mapUserId_Wrapper) {
		for (AggregateResult results : [
			SELECT COUNT(Id) countNumber, ParentId
			FROM EntitySubscription
			WHERE NetworkId = :Network.getNetworkId() AND ParentId = :mapUserId_Wrapper.keySet()
			GROUP BY ParentId
			LIMIT 100
		]) {
			String userId = String.valueOf(results.get('ParentId'));
			if (mapUserId_Wrapper.containsKey(userId)) {
				mapUserId_Wrapper.get(userId).intNumberOfFollowers = Integer.valueOf(
					results.get('countNumber')
				);
			}
		}
		getLikesPostsCount(mapUserId_Wrapper);
	}

	/**
        @Name          :    getLikesPostsCount
        @Description   :    used for fetching the number of likes received and posts made
    */
	private void getLikesPostsCount(Map<Id, x7sMembersWrapperNetwork> mapUserId_Wrapper) {
        System.debug([SELECT ParentId, LikeReceivedCount, PostCount, NetworkId FROM ChatterActivity WHERE ParentId = :mapUserId_Wrapper.keySet()]);
		for (ChatterActivity results : [
			SELECT ParentId, LikeReceivedCount, PostCount
			FROM ChatterActivity
			WHERE NetworkId = :Network.getNetworkId() AND ParentId = :mapUserId_Wrapper.keySet()
		]) {
			if (mapUserId_Wrapper.containsKey(results.ParentId)) {
				mapUserId_Wrapper.get(results.ParentId).intLikeReceived = results.LikeReceivedCount;
				mapUserId_Wrapper.get(results.ParentId).intPostsMade = results.PostCount;
			}
		}

		getFollowing(mapUserId_Wrapper);
	}

	/**
        @Name       : get all the members I am following
        @Description: set all members that I follow to true in the user map
     */
	private void getFollowing(Map<Id, x7sMembersWrapperNetwork> mapUserId_Wrapper) {
		for (EntitySubscription results : [
			SELECT ParentId, SubscriberId
			FROM EntitySubscription
			WHERE
				NetworkId = :Network.getNetworkId()
				AND SubscriberId = :UserInfo.getUserId()
				AND ParentId IN :mapUserId_Wrapper.keySet()
			LIMIT 100
		]) {
			if (mapUserId_Wrapper.containsKey(results.ParentId)) {
				mapUserId_Wrapper.get(results.ParentId).isFollowing = true;
			}
		}
		getKnowledgeableTopics(mapUserId_Wrapper);
	}

	/**
        @Name          :    getKnowledgeableTopics
        @Description   :    used for fetching the knowledge topics related to user
    */
	private void getKnowledgeableTopics(Map<Id, x7sMembersWrapperNetwork> mapUserId_Wrapper) {
		final Integer MAX_TOPIC = 3;

		Map<Id, String> mapTopicId_Name = new Map<Id, String>();
		Map<Id, Set<Id>> mapUserId_SetTopicId = new Map<Id, Set<Id>>();
		Set<Id> setTopicId = new Set<Id>();
		String strTopicName;
		Id topicId;

		// Fetching the topic records.
		for (Topic objTopic : [SELECT Id, Name FROM Topic WHERE NetworkId = :Network.getNetworkId()]) {
			mapTopicId_Name.put(objTopic.Id, objTopic.Name);
		}

		// Fetching the KnowledgeableUser records for topics associated with community.
		for (KnowledgeableUser objKnowledgeableUser : [
			SELECT UserId, TopicId, NetworkId, RawRank
			FROM KnowledgeableUser
			WHERE
				UserId IN :mapUserId_Wrapper.keySet()
				AND TopicId IN :mapTopicId_Name.keySet()
				AND NetworkId = :Network.getNetworkId()
		]) {
			//Check if the UserId is present, if not then creates a new map entry
			if (!mapUserId_SetTopicId.containsKey(objKnowledgeableUser.UserId)) {
				setTopicId.add(objKnowledgeableUser.TopicId);
				mapUserId_SetTopicId.put(objKnowledgeableUser.UserId, setTopicId);
				strTopicName = mapTopicId_Name.get(objKnowledgeableUser.TopicId);
				topicId = objKnowledgeableUser.TopicId;
			} else if (
				mapUserId_SetTopicId.get(objKnowledgeableUser.UserId).size() <= MAX_TOPIC &&
				!mapUserId_SetTopicId.get(objKnowledgeableUser.UserId)
					.contains(objKnowledgeableUser.TopicId)
			) {
				// Check if topic already counted & check if more than 3 topics counted
				mapUserId_SetTopicId.get(objKnowledgeableUser.UserId).add(objKnowledgeableUser.TopicId);
				strTopicName = mapTopicId_Name.get(objKnowledgeableUser.TopicId);
				topicId = objKnowledgeableUser.TopicId;
			}
			//Check if strTopic name is not null & adds the strTopicName, topicId to wrapper class fields
			if (strTopicName != null) {
				if (String.isBlank(mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics)) {
					mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics = strTopicName;
					mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopicId = topicId;
				} else if (
					(String.isBlank(
						mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics1
					)) &&
					(!String.isBlank(mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics))
				) {
					mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics1 = strTopicName;
					mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopicId1 = topicId;
				} else if (
					(!String.isBlank(
						mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics
					)) &&
					(!String.isBlank(
						mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics1
					) &&
					String.isBlank(mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics2))
				) {
					mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopics2 = strTopicName;
					mapUserId_Wrapper.get(objKnowledgeableUser.UserId).strKnowledgeTopicId2 = topicId;
				}
			}
		}
	}
}