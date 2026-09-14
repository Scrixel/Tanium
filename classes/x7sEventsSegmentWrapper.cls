/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsSegmentWrapper {
    @AuraEnabled
    public String eventId { get; set; }

    @AuraEnabled
    public String id { get; set; }

    @AuraEnabled
    public Boolean TrackCapacity { get; set; }

    @AuraEnabled
    public Integer Capacity { get; set; }

    @AuraEnabled
    public Boolean WaitList { get; set; }

    @AuraEnabled
    public String RegistrationSetting { get; set; }

    @AuraEnabled
    public String Segment { get; set; }

    public x7sEventsSegmentWrapper() {
        id = null;
        eventId = null;
        TrackCapacity = false;
        Capacity = 0;
        WaitList = false;
        RegistrationSetting = '';
        Segment = '';
    }
}