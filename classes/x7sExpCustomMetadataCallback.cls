/*
 * Copyright (c) 2020. 7Summits Inc.
 */

public with sharing class x7sExpCustomMetadataCallback implements Metadata.DeployCallback {

    public void handleResult(Metadata.DeployResult result,
            Metadata.DeployCallbackContext context) {

        if (!X7S_Metadata_Deploy_Result__c.SObjectType.getDescribe().isCreateable()) {
            System.debug('handleResult() - unable to insert X7S_Metadata_Deploy_Result__c object.');
            return;
        }

        X7S_Metadata_Deploy_Result__c deployResult = new X7S_Metadata_Deploy_Result__c();
        deployResult.Job_ID__c = result.id;
        deployResult.Name = 'Job ' + result.id;

        if (result.status == Metadata.DeployStatus.Succeeded) {
            deployResult.Success__c = true;
        } else {
            deployResult.Success__c = false;

            // Build a string to return (well, build a List which will turn into a string)
            List<String> errorMessages = new List<String>();

            // For each deploy message, grab the problem
            for (Metadata.DeployMessage thisMessage : result.details.componentFailures) {
                errorMessages.add(thisMessage.problem);
            }
            // Format list into string
            deployResult.Detailed_Message__c = x7sExpUtils.buildStringFromList(errorMessages);
        }

        insert deployResult;
    }
}