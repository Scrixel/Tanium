/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Format various pieces of content as a x7sExp Content Object
 * When to use this? When you're not querying an SObject directly. For example,
 * if you have a custom wrapper class that you want to return in a x7sExp Response list,
 * you will have to format using a helper method here
 */
public with sharing class x7sExpContentObjectHelper {

    // Basic demo - create x7sExp Content Object from string
    public x7sExpContentObject formatFromString(String objectName) {
        x7sExpContentObject contentObject = new x7sExpContentObject();
        contentObject.title = objectName;
        return contentObject;
    }

    // Other examples would be something like formatFromYourCustomObject
}