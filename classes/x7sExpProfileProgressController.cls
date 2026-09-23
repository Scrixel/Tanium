/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpProfileProgressController {
    /*
    * Builds a SOQL query based on the provided values.
    *
    * @param String objectName - Name of the object to be used in the query.
    * @param String userId - Id of the object to be used in the query.
    * @param List<String> fieldNameList - Names of the fields to be used in the query.
    * @return String - Built query string.
    */
    @TestVisible
    private static String dynamicQueryBuilder(String objectName, String objectId, List<String> fieldNameList) {
        String dynamicQuery;

        if (!String.isEmpty(objectName) || !String.isBlank(objectName) && !String.isEmpty(objectId) || !String.isBlank(objectId)) {
            dynamicQuery = 'SELECT Id';

            // Add the fields provided
            for (String currentFieldName : fieldNameList) {
                if (!String.isEmpty(currentFieldName) || !String.isBlank(currentFieldName)) {
                    dynamicQuery += ', ' + String.escapeSingleQuotes(currentFieldName);
                }
            }

            dynamicQuery += ' FROM '
                    + String.escapeSingleQuotes(objectName)
                    + ' WHERE Id = \''
                    + String.escapeSingleQuotes(objectId) + '\'';
        }

        return dynamicQuery;
    }

    @AuraEnabled (Cacheable=true)
    public static User getUser() {
        try{
			User loggedInUser = [SELECT Id, Name,FirstName, LastName FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]; //NOSONAR
            return loggedInUser;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }

    @AuraEnabled (Cacheable=true)
    public static Integer getUserById(String userId, List<String> aboutMeFieldNameList) {
        try{
        String PLACEHOLDER_PROFILE_PHOTO_PATH = 'profilephoto/005/';
        String queryString = dynamicQueryBuilder('User', userId, aboutMeFieldNameList);
        List<User> userList = (List<User>) Database.query(queryString);

        User user = userList[0];
        Integer completedFields = 0;

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.User.fields.getMap();

        for (String fieldName : aboutMeFieldNameList) {
            try {
                if (user.get(fieldName) != null) {
                    Schema.DisplayType fieldDataType = fieldMap.get(fieldName).getDescribe().getType();

                    // special case for profile photo
                    if (fieldDataType == Schema.DisplayType.STRING && String.isNotBlank((String) user.get(fieldName)) &&
                    ((String) user.get(fieldName)).indexOf(PLACEHOLDER_PROFILE_PHOTO_PATH) != -1) {
                        break;
                    }
                    ++completedFields;
                }

            } catch (System.TypeException ex) {
                System.debug('x7sExpProfileProgressController getUserById: ' + ex.getMessage());
            }
        }
        return completedFields;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }

    // Get the site prefix (for displaying links/assets)
    @AuraEnabled
    public static String getSitePrefix() {
        try{
            return x7sExpUtils.getSitePrefix();
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }
}