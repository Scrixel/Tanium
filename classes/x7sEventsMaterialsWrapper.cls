/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsMaterialsWrapper {
    
    @AuraEnabled
    public String eventId { get; set; }

    @AuraEnabled
    public String id { get; set; }

    @AuraEnabled
    public String materialType { get; set; }

    @AuraEnabled
    public String usage { get; set; }

    @AuraEnabled
    public String name { get; set; }

    @AuraEnabled
    public String link { get; set; }

    @AuraEnabled
    public String description { get; set; }

    @AuraEnabled
    public String applicability { get; set; }

    @AuraEnabled
    public Boolean requiredPreWork { get; set; }

    @AuraEnabled
    public fileWrapper file { get; set; }

    @AuraEnabled
    public String uniqueKey { get; set; }

    public class fileWrapper {
        @AuraEnabled
        public String fileName { get; set; }
        @AuraEnabled
        public String fileContent { get; set; }
        @AuraEnabled
        public Integer fileSize { get; set; }
        @AuraEnabled
        public String fileExtension { get; set; }
        @AuraEnabled
        public String contentDocId { get; set; }
    }

    public x7sEventsMaterialsWrapper() {
        id = '';
        eventId = '';
        materialType = '';
        usage = '';
        name = '';
        link = '';
        description = '';
        applicability = '';
        requiredPreWork = false;
        file = new fileWrapper();
        uniqueKey = '';
    }
}