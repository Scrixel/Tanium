/*
 * Licensed Materials - Property of IBM
 * 6949-82X
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Wrapper Apex class used by x7sGroupsController Apex class
 *              Mainly this class was created for implementing pagination using setcontroller.	
 */
global without sharing class x7sGroupsWrapper
{
	/**
	 * @description The current user's id
	 */
	@AuraEnabled
	global String currentUserId { get; set; }

	/**
	 * @description List of CollaborationGroup objects
	 */
	@AuraEnabled
	global List<CollaborationGroup> groupsList { get; set; }

	/**
	 * @description Map of group memberships
	 */
	@AuraEnabled
	global Map<String, String> groupMembership {get; set;}

	/**
	 * @description Total search result
	 */
	@AuraEnabled
	global Integer totalResults { get; set; }

	/**
	 * @description Total number of pages in pagination as per total results
	 */
	@AuraEnabled
	global Integer totalPages { get; set; }

	/**
	 * @description Page number for all total number of pages
	 */
	@AuraEnabled
	global Integer pageNumber { get; set; }

	/**
	 * @description Does the current page has a previous page
	 */
	@AuraEnabled
	global Boolean hasPreviousSet { get; set; }

	/**
	 * @description Does the current page has a next page
	 */
	@AuraEnabled
	global Boolean hasNextSet { get; set; }

	/**
	 * @description Integer listSizeValue to define limit in query as per design attributes
	 */
	@AuraEnabled
	global Integer listSizeValue { get; private set; }

	/**
	 * @description Error message to be displayed
	 */
	@AuraEnabled
	global String errorMsg { get; set; }

	private ApexPages.StandardSetController setController { get; set; }

	/**
	 * @description Class constructor
	 */
	global x7sGroupsWrapper() {
		System.debug('Default ctor');
	}

	/**
	 * @description constructor for wrapper
	 * @param errorMsg
	 */
	global x7sGroupsWrapper(String errorMsg) {
		this.errorMsg = errorMsg;
	}

	/**
	 * @description constructor for wrapper
	 * @param QUERY
	 * @param intLimit
	 * @param groupIds
	 * @param isFeatured
	 * @param featurdGroupsIds
	 * @param lstOfIds
 	 */
	global x7sGroupsWrapper(String QUERY, Integer intLimit, Set<String> groupIds, Boolean isFeatured, Map<String, String> featurdGroupsIds, List<String> lstOfIds) {
		this.groupsList = new List<CollaborationGroup>();

		//set limit to query
		this.listSizeValue = intLimit;

		//Query Groups records as per query string from parameters
		this.setController = new ApexPages.StandardSetController(Database.getQueryLocator(QUERY));
		
		//setting page size for position based on listSizeValue
		this.setController.setPageSize(listSizeValue);

		//call updateControllerAttributes method
		updateControllerAttributes(isFeatured, lstOfIds);
	}

	/**
	 * @description Used in pagination on click on next button
 	 */
	global void nextPage() {

		//set page number for next page in pagination
		this.setController.setPageNumber(this.pageNumber + 1 > 0 ? this.pageNumber + 1 : 1);

		//call updateControllerAttributes method
		updateControllerAttributes(false, null);
	}

	/**
	 * @description Used in pagination on click on previous button
	 */
	global void previousPage() {

		//set page number for previous page in pagination
		this.setController.setPageNumber(this.pageNumber - 1 > 0 ? this.pageNumber - 1 : 1);

		//call updateControllerAttributes method
		updateControllerAttributes(false, null);
	}

	/**
	 * @description Used in identifying the current page number
	 */
	global void currentPage() {

		//set page number for specific page in pagination
		this.setController.setPageNumber(this.pageNumber);		
		updateControllerAttributes(false, null);
	}

	/**
	 * @description used to set attributes of wrapper so that it can be used on components with proper data
	 * @param isFeatured
	 * @param lstOfIds
 	 */
	private void updateControllerAttributes(Boolean isFeatured, List<String> lstOfIds) {

		/*
		Fetch groups list for featured group component in order it is entered in property editor
		isFeatured identifies that this featured component,
		lstOfIds is list of string that contains ids in order it is entered in property editor,so
		we query records that gives random data and by this list we get order of groups to display on featured component
		*/

		//check if featured
		if (isFeatured == true) {

			//query and get record in temporary list
			List<CollaborationGroup> templist = this.setController.getRecords();
			Map<Id, CollaborationGroup> tempGroupsMap = new Map<Id, CollaborationGroup>();

			//fill temporary map of group id and group object
			for (CollaborationGroup cgroup : templist) {
				tempGroupsMap.put(cgroup.Id, cgroup);
			}

			//iterate on map that gives order and check if temporary map contains that id then add it to group list
			for (String str : lstOfIds) {
				if (tempGroupsMap.containsKey(str)) {

					//add groups to list in order in which it is added in community builder
					this.groupsList.add(tempGroupsMap.get(str));
				}
			}
		} else {
			//for all other Groups list get records for set controller directly
			this.groupsList = this.setController.getRecords();
		}

		this.errorMsg		= '';
		this.currentUserId   = UserInfo.getUserId();
		this.groupMembership = x7sGroupsController.getMembershipGroups(UserInfo.getUserId());

		//set totalResults from query result
		this.totalResults = this.setController.getResultSize();

		this.totalPages = Math.mod(this.setController.getResultSize(), this.setController.getPageSize()) == 0
				? this.setController.getResultSize() / this.setController.getPageSize()
				: this.setController.getResultSize() / this.setController.getPageSize() + 1;
		this.pageNumber = this.totalPages > 0 ? this.setController.getPageNumber() : 0;

		this.hasPreviousSet = this.setController.getHasPrevious();
		this.hasNextSet = this.setController.getHasNext();
	}
}