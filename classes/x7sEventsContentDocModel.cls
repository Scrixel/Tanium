/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsContentDocModel {

    @AuraEnabled public String latestImageVersionId { get; set; }

    @AuraEnabled public String imageTitle { get; set; }

    @AuraEnabled public Boolean selectedImage { get; set; }
    
    public x7sEventsContentDocModel() {
        this.latestImageVersionId = '';
        this.imageTitle = '';
        this.selectedImage = false;
    }
}