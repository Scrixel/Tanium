/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpJoinCommunityController {
    public class ExpeditionException extends Exception {}

    @AuraEnabled
    public static List<User> getUsersWithPublicPhotos(String desiredResultsCount) {
        try {
            Integer limitInteger = Integer.valueOf(desiredResultsCount); // https://developer.salesforce.com/forums/?id=906F00000005FxqIAE
            List<User> userList = [
                    SELECT Id,SmallPhotoUrl,FullPhotoUrl,UserPreferencesShowProfilePicToGuestUsers
                    FROM User
                    WHERE UserPreferencesShowProfilePicToGuestUsers = TRUE
                    WITH SECURITY_ENFORCED
                    LIMIT:limitInteger];

            // If we did not find enough users, just add new blank users to the list to fill the slots
            while (userList.size() < limitInteger) {
                User newUser = new User();
                userList.add(newUser);
            }

            return userList;
        }
        catch (Exception e){throw new AuraHandledException(e.getMessage());}

    }
}