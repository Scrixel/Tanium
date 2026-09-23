/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description x7sExp Utility Navigation controller
 */
public with sharing class x7sExpUtilityNavigationController {

    // Determine if guest or logged in
    @AuraEnabled
    public static Boolean isGuestUser() {
        try{ return x7sExpUtils.isGuestUser();}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }
}