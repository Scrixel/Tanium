/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpFeaturedGroupsController {

    public class ExpeditionException extends Exception {}

    // Get a featured group by ID
    @AuraEnabled
    public static x7sExpResponse getFeaturedGroups(String groupIdsString) {
        try{
            x7sExpResponse response = new x7sExpResponse();

            List<String> idsList = groupIdsString.split(',');

            if (!x7sExpUtils.isNullOrEmpty(idsList)) {
                List<CollaborationGroup> featuredGroups = [
                        SELECT BannerPhotoUrl, Description, FullPhotoUrl, Id, MemberCount, Name, SmallPhotoUrl
                        FROM CollaborationGroup
                        WHERE Id IN :idsList
                        WITH SECURITY_ENFORCED
                ];

                if (!x7sExpUtils.isNullOrEmpty(featuredGroups)) {
                    response.results = featuredGroups;
                }
            }

            return response;
        }
        catch (Exception e){throw new AuraHandledException(e.getMessage());}
    }


    @AuraEnabled
    public static String getSitePrefix() {
        try{
			return x7sExpUtils.getSitePrefix();
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }
}