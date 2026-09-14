/*
 * Licensed Materials - Property of IBM
 * 6949-82D
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sOnboardingUserWrapper {
    @AuraEnabled
    public String Id { get; set; }

    @AuraEnabled
    public String MediumPhotoUrl { get; set; }

    @AuraEnabled
    public String FirstName { get; set; }

    @AuraEnabled
    public String LastName { get; set; }

    @AuraEnabled
    public String Title { get; set; }

    @AuraEnabled
    public String CompanyName { get; set; }

    @AuraEnabled
    public String Email { get; set; }

    @AuraEnabled
    public String MobilePhone { get; set; }

    @AuraEnabled
    public String CommunityNickname { get; set; }

    @AuraEnabled
    public String AboutMe { get; set; }

    @AuraEnabled
    public String ProfileName { get; set; }

    @AuraEnabled
    public Boolean X7SAgreedtoTermsandConditions { get; set; }

    @AuraEnabled
    public Boolean X7SCompletedAdditionalUserData { get; set; }

    @AuraEnabled
    public Boolean X7SCompletedGroupsSlide { get; set; }

    @AuraEnabled
    public Boolean X7SCompletedNotificationSlide { get; set; }

    @AuraEnabled
    public Boolean X7SCompletedProfileSlide { get; set; }

    @AuraEnabled
    public Boolean X7SCompletedTopicsSlide { get; set; }

    @AuraEnabled
    public Boolean X7SCompletedToursSlide { get; set; }

    @AuraEnabled
    public Boolean X7SCompletedWelcomeSlide { get; set; }

    @AuraEnabled
    public Boolean X7SHideModalOnboarding { get; set; }

    @AuraEnabled
    public Boolean X7SNotificationConfirmation { get; set; }

    @AuraEnabled
    public Boolean X7SOnboardingComplete { get; set; }

    @AuraEnabled
    public Decimal X7SOnboardingModalDisplayCount { get; set; }


    public x7sOnboardingUserWrapper() {
        MediumPhotoUrl = '';
        FirstName = '';
        LastName = '';
        Title = '';
        CompanyName = '';
        Email = '';
        MobilePhone = '';
        CommunityNickname = '';
        AboutMe = '';
    }
}