/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
trigger x7sEventsRSVPTrigger on X7S_Event_RSVP__c (after insert) {
    if (Trigger.IsAfter) {
         if (Trigger.isInsert) {
             x7sEventsRSVPTriggerHelper.handleEventsRSVPInsert(Trigger.new);
         }       
     }
}