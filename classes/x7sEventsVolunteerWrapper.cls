/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsVolunteerWrapper {
	@AuraEnabled
	public X7S_Events_Volunteer_Need__c volunteerNeed { get; set; }
	@AuraEnabled
	public Boolean currentUserRegistered { get; set; }
}