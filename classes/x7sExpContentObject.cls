/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public virtual with sharing class x7sExpContentObject {
    @AuraEnabled public Id contentID { get; set; }
    @AuraEnabled public String title { get; set; }
    @AuraEnabled public String description { get; set; }
    @AuraEnabled public String fullDescription { get; set; }
    @AuraEnabled public List<Attachment> attachments { get; set; }
    @AuraEnabled public String url { get; set; }
    @AuraEnabled public Boolean featured { get; set; }
    @AuraEnabled public String bannerImage { get; set; }
    @AuraEnabled public String avatar { get; set; }
    @AuraEnabled public Integer commentCount { get; set; }
    @AuraEnabled public String commentUrl { get; set; }
    @AuraEnabled public Datetime dateTimeField { get; set; }
    @AuraEnabled public Date dateField { get; set; }
}