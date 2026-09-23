/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpMyGroupsController {
	/**
	 * @description Determine if user is a member of any group
	 *  *
	 *
	 * @return true if a member
	 */
	@AuraEnabled
	public static Boolean isInAGroup() {
		try {
			// Find group membership records for current user
			List<CollaborationGroupMember> groupMembers = [
				SELECT MemberId
				FROM CollaborationGroupMember
				WHERE MemberId = :UserInfo.getUserId() AND NetworkId = :Network.getNetworkId()
				WITH SECURITY_ENFORCED
			];

			// Hey, found one, return that we are in a group
			if (!groupMembers.isEmpty()) {
				return true;
			}
		}
		catch (Exception ex) {throw new AuraHandledException(ex.getMessage()); }

		return false;
	}

	/**
	 * @description Get a featured group by Id
	 *  *
	 *
	 * @param groupIdString Group Id
	 *  *
	 *
	 * @return Exp response
	 */
	@AuraEnabled
	public static x7sExpResponse getFeaturedGroup(String groupIdString) {
		x7sExpResponse response = new x7sExpResponse();

		try {
			if (!String.isEmpty(groupIdString)) {
				CollaborationGroup featuredGroup = [
					SELECT BannerPhotoUrl, Description, FullPhotoUrl, Id, MemberCount, Name, SmallPhotoUrl
					FROM CollaborationGroup
					WHERE Id = :groupIdString
					WITH SECURITY_ENFORCED
					ORDER BY Name ASC
				];

				if (featuredGroup != null) {
					response.results.add(featuredGroup);
				}
			}
		}
		catch (Exception ex) {response.success = false; throw new AuraHandledException(ex.getMessage());}

		return response;
	}


	/**
	 * @description Get a featured group by list of IDs
     * @param groupIdStrings group ids
	 * @param numResultsString number of items to retrieve
	 * @return response
	 */
	@AuraEnabled
	public static x7sExpResponse getFeaturedGroups(List<String> groupIdStrings, String numResultsString) {
		x7sExpResponse response = new x7sExpResponse();

		try {
			Integer queryLimit = Integer.valueOf(numResultsString);

			if (!x7sExpUtils.isNullOrEmpty(groupIdStrings)) {
				List<CollaborationGroup> featuredGroups = [
					SELECT BannerPhotoUrl, Description, FullPhotoUrl, Id, MemberCount, Name, SmallPhotoUrl
					FROM CollaborationGroup
					WHERE Id IN :groupIdStrings
					WITH SECURITY_ENFORCED
					ORDER BY Name ASC
					LIMIT :queryLimit
				];

				if (featuredGroups != null) {
					response.results = featuredGroups;
				}
			}

			return response;
		}
		catch (Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}

	// Get My Groups
	@AuraEnabled
	public static x7sExpResponse getMyGroups(String numResultsString) {
		x7sExpResponse response = new x7sExpResponse();

		try {
			Integer queryLimit = Integer.valueOf(numResultsString); // https://developer.salesforce.com/forums/?id=906F00000005FxqIAE

			// Get group Ids for current user
			List<Id> groupIds = new List<Id>();
			for (CollaborationGroupMember groupMembership : [SELECT CollaborationGroupId FROM CollaborationGroupMember WHERE MemberId = :UserInfo.getUserId() AND NetworkId != NULL]) {
				groupIds.add(groupMembership.CollaborationGroupId);
			}

			// And now query those groups with the IDs

			List<CollaborationGroup> myGroups = [
				SELECT BannerPhotoUrl, Description, FullPhotoUrl, Id,MemberCount, Name, SmallPhotoUrl,NetworkId
				FROM CollaborationGroup
				WHERE Id IN :groupIds
				AND NetworkId = :Network.getNetworkId()
				WITH SECURITY_ENFORCED
				ORDER BY Name ASC
				LIMIT :queryLimit
			];

			response.results = myGroups;

			return response;
		}
		catch (Exception ex) {throw new AuraHandledException(ex.getMessage()); }
	}

	@AuraEnabled
	public static String getSitePrefix() {
		try{return x7sExpUtils.getSitePrefix();}catch (Exception ex) {throw new AuraHandledException(ex.getMessage());}
	}
}