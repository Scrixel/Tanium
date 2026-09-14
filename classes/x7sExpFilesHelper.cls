/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpFilesHelper {
    public class ExpeditionException extends Exception {}

    /*
           Get attachments a User added to a Record
        */
    public static x7sExpResponse getFilesForCurrentUserForRecord(Id userId, Id recordId) {

        x7sExpResponse peakResponse = new x7sExpResponse();
        try {
            // Query by User and Parent record
            List<Attachment> attachments = [
                    SELECT BodyLength,ContentType, CreatedById, CreatedDate, Id, IsDeleted, Name, ParentId, SystemModstamp
                    FROM Attachment
                    WHERE OwnerId = :userId AND ParentId = :recordId
                    WITH SECURITY_ENFORCED
            ];
            peakResponse.results = attachments;

            // Get that 75%
            peakResponse.messages.add('Attachments found');
            peakResponse.success = true;
        }
        catch (Exception e){peakResponse.success = false; peakResponse.messages.add(e.getMessage()) ;throw new AuraHandledException(e.getMessage());}
        return peakResponse;
    }
}