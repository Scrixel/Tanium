/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
* @description This class handles all the operations of the idea filter component
*/

public without sharing class x7sIdeasFiltersController {

	/**
	* @description Used to check if current user has permission to show account filter
	* @return true if can show account filter else false
	*/
	@AuraEnabled
	public static Boolean showAccountFilter() {
		x7sIdeasCommon common = new x7sIdeasCommon('', false);
		String permissionSetName = common.accountFilterPermissions;
		String userId = UserInfo.getUserId();

		return x7sIdeasUtility.permissionSetMember(userId, permissionSetName);
	}

	/**
	 * @description Get Idea Theme List based on zone name
	 * @param zoneName Idea Zone Name
	 * @return List of themes
	 */
	@AuraEnabled
	public static List<String> getThemeValues(String zoneName) {
		List<String> lstFieldValues = new List<String>();

		List<IdeaTheme> themeList = [SELECT Id, Title FROM IdeaTheme WHERE Community.Name = :zoneName ORDER BY Title];
		for (IdeaTheme themeItem : themeList) {
			lstFieldValues.add(themeItem.Title);
		}

		return lstFieldValues;
	}

	/**
	* @description  Method for fetching all Topics values from any sObject.
	* @return List of topics
	*/
	@AuraEnabled
	public static List<String> getTopicNamesList() {
		return x7sIdeasTopicController.getTopicNamesList();
	}

	/**
	 * @description Method to get idea status list
	 * @param zoneName Idea zone name
	 * @return List of statuses
	 */
	@AuraEnabled
	public static List<String> getStatusValues(String zoneName) {
		return x7sIdeasUtility.getIdeaStatusValues(zoneName);
	}

	/**
	 * @description To get list of idea categories
	 * @param themeName Idea Theme Name to filter with
	 * @return list of categories
	 */
	@AuraEnabled
	public static List<String> getCategoryValues(String themeName) {
		return String.isBlank(themeName) ? x7sIdeasUtility.getIdeaCategoryValues() : x7sIdeasUtility.getThemeCategories(themeName);
	}
}