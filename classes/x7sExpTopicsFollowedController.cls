/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description x7sExp Topics Followed controller
 */
public with sharing class x7sExpTopicsFollowedController {

    @AuraEnabled
    public static List<Topic> getMyFollowedTopics(String recordsToShow) {
        try{
			String currentUserId = UserInfo.getUserId();
            Integer listSize = recordsToShow != null ? Integer.valueOf(recordsToShow) : 1000;

            Map<Id, Topic> topicMap = new Map<Id, Topic>();
            for (Topic t : [
                SELECT Id, Name
                FROM Topic
                WHERE NetworkId = :Network.getNetworkId()
            ]) {
                topicMap.put(t.Id, t);
            }

        List<Topic> followedTopics = new List<Topic>();
        for (EntitySubscription sub : [
                SELECT Id, SubscriberId, ParentId
                FROM EntitySubscription
                WHERE SubscriberId = :currentUserId AND ParentId IN :topicMap.keySet()
                LIMIT :listSize
        ]) {
            followedTopics.add(topicMap.get(sub.ParentId));
        }

        return followedTopics;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
        
    }

}