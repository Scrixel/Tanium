/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpRelatedFilesController {

    /*
        Get attachments a User added to a Record
     */
    @AuraEnabled
    public static x7sExpResponse getFilesForCurrentUserForRecord(String recordIdString) {
        try{
			// Init response
            x7sExpResponse expResponse = new x7sExpResponse();

            // Call Helper
            expResponse = x7sExpFilesHelper.getFilesForCurrentUserForRecord(UserInfo.getUserId(), Id.valueOf(recordIdString));
    
            // Return
            return expResponse;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }

}