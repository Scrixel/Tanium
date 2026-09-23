/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sExpMyAccountTeamController {

    @AuraEnabled
    public static x7sExpResponse getAccountTeam() {

        try{
			x7sExpResponse expResponse = new x7sExpResponse();
            List<User> currentUser = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId()]; //NOSONAR

        // If current user was found WITH a contact ID
        if (!x7sExpUtils.isNullOrEmpty(currentUser)) { //&& currentUser[0].ContactId != null) {

            // Get Contact for user, with associated account
            List <Contact> contact = [SELECT Id, AccountId FROM Contact WHERE Id = :currentUser[0].ContactId]; //NOSONAR

            // ... and if user's contact is found...
            if (!x7sExpUtils.isNullOrEmpty(contact)) {
                expResponse = queryAccountTeams(contact);
            } else {
                expResponse.messages.add(Label.x7sExpLabelNoContactId);
            }
        }

        // Flip to unsuccessful if there are any error messages
        if (expResponse.messages.size() > 0) {
            expResponse.success = false;
        }
        return expResponse;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
        
    }

    @AuraEnabled
    public static x7sExpResponse queryAccountTeams(List<Contact> contact) {

        try{
			x7sExpResponse expResponse = new x7sExpResponse();
        // AND if account teams are enabled
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get('AccountTeamMember');
        if (targetType != null) {
            // Use database.query in case Account teams are not enabled, otherwise a standard select won't even compile!
            try {
                expResponse.results = Database.query('SELECT Id, TeamMemberRole, User.Firstname, User.Lastname,User.Email, User.Phone FROM AccountTeamMember WHERE AccountId = \'' + String.escapeSingleQuotes(contact[0].AccountId) + '\'');
            } catch (Exception e) {expResponse.messages.add(e.getMessage());}
        } else {
            expResponse.messages.add(Label.x7sExpAccountTeamsNotEnabled);
        }
        return expResponse;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
        
    }
}