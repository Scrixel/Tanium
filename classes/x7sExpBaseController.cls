/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */


public with sharing class x7sExpBaseController {

	// Get the site prefix (for displaying links/assets)
	@AuraEnabled
	public static String getSitePrefix() {
		try{return System.Site.getPathPrefix();}catch(Exception e){throw new AuraHandledException(e.getMessage());}
	}

	// Determine if guest or logged in
	@AuraEnabled
	public static Boolean isGuestUser() {
		try{
			Boolean isGuest = false;
			if (UserInfo.getUserType() == 'Guest' || UserInfo.getUserName() == 'Tanium Customer Community Site Guest User') {
				isGuest = true;
			}
			return isGuest;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
	}

	// Get Community URL
	@AuraEnabled(Cacheable=true)
	public static String getSiteUrl() {
		try{ String communityId = System.Network.getNetworkId();
			return communityId != null ? ConnectApi.Communities.getCommunity(communityId).siteUrl : '';
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
		
	}
}