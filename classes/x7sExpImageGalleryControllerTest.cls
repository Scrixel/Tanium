/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sExpImageGalleryControllerTest {
    @TestSetup
    static void testSetup() {
        User testUser = x7sExpTestUtils.createStandardUser();
        try {
            insert testUser;
        } catch (Exception e) {
            testUser.ContactId = null;
            insert testUser;
        }

        X7S_Image_Gallery__c testGallery = new X7S_Image_Gallery__c(Name = x7sExpTestConstants.TEST_GALLERYNAME, Default_Image__c = x7sExpTestConstants.TEST_URL, Description__c = x7sExpTestConstants.TEST_DESCRIPTION);
        insert testGallery;

        List<X7S_Image_Gallery_Entry__c> testEntries = new List<X7S_Image_Gallery_Entry__c>();
        testEntries.add(new X7S_Image_Gallery_Entry__c(Name = x7sExpTestConstants.TEST_GALLERYENTRYNAME, X7S_Image_Gallery__c = testGallery.Id, Image_URL__c = x7sExpTestConstants.TEST_URL, Sort_Order__c = x7sExpTestConstants.TEST_GALLERYENTRYSORT1));
        testEntries.add(new X7S_Image_Gallery_Entry__c(Name = x7sExpTestConstants.TEST_GALLERYENTRYNAME, X7S_Image_Gallery__c = testGallery.Id, Image_URL__c = x7sExpTestConstants.TEST_URL, Sort_Order__c = x7sExpTestConstants.TEST_GALLERYENTRYSORT2));
        insert testEntries;

    }
    @IsTest
    public static void testGetImageGallery() {
        //creating test user to run with to make sure the user has access to the object
        List<User> testUsers = [SELECT Id FROM User WHERE Email = :x7sExpTestConstants.STANDARD_EMAIL];
        List<X7S_Image_Gallery__c> testGalleries = [SELECT Id FROM X7S_Image_Gallery__c WHERE Name = :x7sExpTestConstants.TEST_GALLERYNAME];

        Test.startTest();
        System.runAs(testUsers[0]) {
            x7sExpResponse testResults = x7sExpImageGalleryController.getImageGallery(testGalleries[0].Id);
            X7S_Image_Gallery__c foundGallery = (X7S_Image_Gallery__c) testResults.results[0];
            /*Can't test the gallery entries because for some reason the subquery doesn't show in the x7sExpResponse object 
             * while in apex but goes through to the component 
             */
            String testString = foundGallery.Default_Image__c + foundGallery.Description__c;
            String assertString = x7sExpTestConstants.TEST_URL + x7sExpTestConstants.TEST_DESCRIPTION;
            System.assertEquals(assertString, testString);
        }
        Test.stopTest();
    }

}