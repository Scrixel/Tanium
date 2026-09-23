/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sMembersWrapperNetwork {

    @AuraEnabled
    public String userId { get; set; }

    @AuraEnabled
    public Boolean isFollowing { get; set; }  // Am I following this User

    @AuraEnabled
    public Integer intLikeReceived { get; set; }  // number of likes associated with user

    @AuraEnabled
    public Integer intPostsMade { get; set; }  // number of posts made by the user

    @AuraEnabled
    public Integer intNumberOfFollowers { get; set; }  // number of followers associated with user

    @AuraEnabled
    public String strKnowledgeTopics { get; set; }  // topics associated with record

    @AuraEnabled
    public String strKnowledgeTopics1 { get; set; }  // topics associated with record

    @AuraEnabled
    public String strKnowledgeTopics2 { get; set; }  // topics associated with record

    @AuraEnabled
    public Id strKnowledgeTopicId { get; set; }  // topicsId associated with record

    @AuraEnabled
    public Id strKnowledgeTopicId1 { get; set; }  //  topicsId associated with record

    @AuraEnabled
    public Id strKnowledgeTopicId2 { get; set; }  // topicsId associated with record

    @AuraEnabled
    public User objUser { get; set; }  // data associated with user

    public x7sMembersWrapperNetwork(User objUser) {
        this.objUser = objUser;
        this.userId = objUser.Id;
        this.isFollowing = isFollowing;
        this.intLikeReceived = intLikeReceived;
        this.intPostsMade = intPostsMade;
        this.intNumberOfFollowers = intNumberOfFollowers;
        this.strKnowledgeTopics = strKnowledgeTopics;
        this.strKnowledgeTopics1 = strKnowledgeTopics1;
        this.strKnowledgeTopics2 = strKnowledgeTopics2;
        this.strKnowledgeTopicId = strKnowledgeTopicId;
        this.strKnowledgeTopicId1 = strKnowledgeTopicId1;
        this.strKnowledgeTopicId2 = strKnowledgeTopicId2;
    }
}