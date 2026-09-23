/*
 * Licensed Materials - Property of IBM
 * 6949-84J
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

global without sharing class X7S_ThemeController {
    /*
    @Name		  :  getSiteName
    @Description  :  Method to fetch the Network Name (Community Name) of the user's community so we can use it in our theme.
    */
    @AuraEnabled
    global static String getSiteName() {
        return X7S_ThemeController.getSiteNameInternal(System.Network.getNetworkId());
    }

    public static String getSiteNameInternal(String networkId) {
        try {
            if (String.isNotBlank(networkId))
            {
                Network communityNetwork = [ SELECT Id, Name FROM Network WHERE ID = :networkId  ]; return communityNetwork != null ? communityNetwork.Name : '';
            }
        } catch (Exception e) {
            System.debug('getSiteName() : ' + e.getMessage() + ' line number: ' + e.getLineNumber());
        }

        return '';
    }
}