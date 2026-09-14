/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpFeaturedTopicsController {

    private static Integer COMMUNITY_QUERY_LIMIT = 1;

    // Get a list of featured topics for the active community
    @AuraEnabled (Cacheable=true)
    public static ConnectApi.ManagedTopicCollection getFeaturedTopics() {
        try{
			String networkId = Network.getNetworkId();
            if (Test.isRunningTest()) {
                List<Network> networks = [SELECT Id FROM Network LIMIT :COMMUNITY_QUERY_LIMIT]; //NOSONAR
                networkId = networks[0].Id;
            }
            ConnectApi.ManagedTopicCollection featuredTopics = ConnectAPI.ManagedTopics.getManagedTopics(networkId, ConnectApi.ManagedTopicType.Featured);
            return featuredTopics;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
        
    }

}