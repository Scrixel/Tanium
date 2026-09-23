/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Featured User Controller
 */
public with sharing class x7sExpFeaturedUserController {
	public class ExpeditionException extends Exception {
	}

	// Get user ID for a user
	@AuraEnabled
	public static User getUserInformation(Id userId) {
		try {
			User featuredUser = [SELECT Id, Name, Title, MediumPhotoUrl FROM User WHERE Id = :userId WITH SECURITY_ENFORCED];
			return featuredUser;
		}
        catch (Exception e){throw new AuraHandledException(e.getMessage());}
	}

	// Get the site prefix (for displaying links/assets)
	@AuraEnabled
	public static String getSitePrefix() {
		try {
				return x7sExpUtils.getSitePrefix();
	       }
		catch (Exception e){throw new AuraHandledException(e.getMessage());}
	}

	// Get user List for a user
	@AuraEnabled
	public static List<User> getUserListInformation(List<Id> userIds) {
		try {
			Set<Id> userList = new Set<Id>();
			userList.addAll(userIds);
			List<User> featuredUser = [SELECT Id, Name, Title, MediumPhotoUrl FROM User WHERE Id = :userList WITH SECURITY_ENFORCED];
			return featuredUser;
		}
        catch (Exception e){throw new AuraHandledException(e.getMessage());}
	}
}