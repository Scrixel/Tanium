/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

public with sharing class x7sNewsImageController {

    final static String  key 				= 'key';
	final static Integer NUMBEROFPAGE 		= 0;
	final static Integer PAGESIZE 			= 250;
	final static String  LANGUAGE 			= 'en_US';
	final static Boolean SHOWABSOLUTEURL 	= true;
	final static String  MANAGEDCONTENTTYPE = 'cms_image';

    // Current community ID
    @TestVisible
    private static Id communityId {
        get {
           return System.Network.getNetworkId();
        }
    }

    /**
     * Get List of Image Types from News Object
     * @return List of Image Types
     */

    @AuraEnabled
    public static Map<String,String> getImageTypes() {
        Map<String,String> options = new Map<String,String>();
                
        try {
            Schema.DescribeFieldResult fieldResult = X7S_News__c.Image_Type__c.getDescribe();
            List<Schema.PicklistEntry> imageTypes = fieldResult.getPicklistValues();
                    
            for(Schema.PicklistEntry type : imageTypes) {
                options.put(type.getValue(), type.getLabel());
            }       
            return options;
        } catch(Exception ex) {throw new AurahandledException(ex.getMessage());}
    }

    public static Map<Id,String> getImageURL(List<X7S_News__c> newsList) {

        Map<Id,String> newstoImageURLMap = new Map<Id,String>();
        Map<Id,String> newsWithRelatedFiles = new Map<Id,String>();
        Map<Id,String> newsWithExternalURL = new Map<Id,String>();
        Map<Id,String> newsWithStaticResource = new Map<Id,String>();
        Map<Id,String> newsWithCMSImage = new Map<Id,String>();

        for(X7S_News__c news : newsList) {
            switch on news.Image_Type__c {
                when 'Related File' {
                    newsWithRelatedFiles.put(news.Id, news.Image_Reference__c);
                }
                when 'External URL' {
                    newsWithExternalURL.put(news.Id, news.Image_Reference__c);
                }
                when 'Static Resource' {
                    newsWithStaticResource.put(news.Id, news.Image_Reference__c);
                }
                when 'CMS Content' {
                    newsWithCMSImage.put(news.Id, news.Image_Reference__c);
                }
            }
        }
        
        //When Image Type = Related File
        List<Id> listIds = new List<Id>();
        if(!newsWithRelatedFiles.isEmpty()) {
            listIds.addAll(newsWithRelatedFiles.keySet());
            
            //Get All document links for news having Image Type = Related File only
            List<ContentDocumentLink> documentLinkList = x7sNewsContentDocument.getContentDocumentLinks(listIds);
            String communityURL = x7sNewsBaseController.getCommunityUrl();

            for (Id newsId : newsWithRelatedFiles.keySet()) {
                Id imageId;
                String imageURL;
                List<ContentDocumentLink> links = x7sNewsContentDocument.containsEntityId(documentLinkList, newsId);

                //Get the Image Reference field value
                String imageRef = newsWithRelatedFiles.get(newsId);
                
                if(imageRef != null && imageRef != '') {
                    for(ContentDocumentLink docLink : links) {
                        if(docLink.ContentDocument.LatestPublishedVersionId == imageRef) {
                            imageId = docLink.ContentDocument.LatestPublishedVersionId;
                            break;
                        }
                    }
                }

                if(imageId == null) {
                    if(!links.isEmpty()) { imageURL = communityURL + x7sNewsContentDocument.FILE_LOCATION + links[0].ContentDocument.LatestPublishedVersionId; }
                } else { imageURL = communityURL + x7sNewsContentDocument.FILE_LOCATION + imageId; }
                if(imageURL != null) { newstoImageURLMap.put(newsId, (String)imageURL); }
            }
        }

        //When Image Type = External URL
        if(!newsWithExternalURL.isEmpty()) {
            for (Id newsId : newsWithExternalURL.keySet()) {
                if(newsWithExternalURL.get(newsId) != null && newsWithExternalURL.get(newsId) != '') {
                    newstoImageURLMap.put(newsId, (String)(newsWithExternalURL.get(newsId)));
                }
            }
        }

        //When Image Type = Static Resource
        if(!newsWithStaticResource.isEmpty()) {
            for (Id newsId : newsWithStaticResource.keySet()) {
                if(newsWithStaticResource.get(newsId) != null && newsWithStaticResource.get(newsId) != '') {
                    String imageURL = '/resource/' + newsWithStaticResource.get(newsId);
                    newstoImageURLMap.put(newsId, (String) imageURL);
                }
            }
        }

        //When Image Type = CMS Content 
        if(!newsWithCMSImage.isEmpty()) {
            Map<String,String> contentIdToImageURLMap  =  new Map<String,String>();
            contentIdToImageURLMap = getCMSImageURL(newsWithCMSImage, new List<String>());
            if(!contentIdToImageURLMap.isEmpty()) {
                for (Id newsId : newsWithCMSImage.keySet()) {
                    String imageURL = contentIdToImageURLMap.containsKey(newsWithCMSImage.get(newsId)) ? contentIdToImageURLMap.get(newsWithCMSImage.get(newsId)) : '';
                    newstoImageURLMap.put(newsId, (String) imageURL);
                }
            }
        }
        return newstoImageURLMap;
    }

    /**
    * Get Image URL of the image stored in the CMS
    * @param    newsWithCMSImage : News Id to CMS Content Id Map
    * @param    contectIdList : List of CMS Content Ids
    * @return   imageURLMap : CMS Content Id to content image URL Map
    **/ 
    @AuraEnabled
    public static Map<String,String> getCMSImageURL(Map<Id,String> newsWithCMSImage, List<String> contectIdList) {

        try {
            Map<String,String> imageURLMap = new Map<String,String>();
            List<String> contentIds = new List<String>();

            if(!newsWithCMSImage.isEmpty()) {
                for (String content : newsWithCMSImage.values()) {
                    if(content != null && String.isNotBlank(content) && ((String)content).length() == 18) {
                        contentIds.add(content);
                    }
                }
            } else if(!contectIdList.isEmpty() && contectIdList != null) { contentIds.addAll(contectIdList); }

            if(communityId != null) { imageURLMap =  getCMSImageURLForCommunity(contentIds); }
            else {
                String channelId = (String) getCMSChannelId();
                imageURLMap =  getCMSImageURLForChannel(channelId, contentIds);
            }

            return imageURLMap;
        } catch(Exception ex) {throw new AurahandledException(ex.getMessage());}
    }
    
    @TestVisible
    private static Map<String,String> getCMSImageURLForCommunity(List<String> contentIds) {

		Map<String,String> imageURLMap = new Map<String,String>();

		if (contentIds != null && !contentIds.isEmpty()) {
			try {
                if (!Test.isRunningTest()) {
    				ConnectApi.ManagedContentVersionCollection contentList = ConnectApi.ManagedContent.getManagedContentByIds(communityId, contentIds, NUMBEROFPAGE, PAGESIZE, LANGUAGE, MANAGEDCONTENTTYPE, SHOWABSOLUTEURL);
                    if (contentList != null) {
                        for (String contentId : contentIds) {
                            for (ConnectApi.ManagedContentVersion cmsContent : contentList.items) {
                                if (cmsContent.managedContentId == contentId) {
                                    imageURLMap.put(contentId, ((ConnectApi.ManagedContentMediaSourceNodeValue) cmsContent.contentNodes.get('source')).url);
                                }
                            }
                        }
                    }
                }
			}
			catch (Exception e) {
				System.debug('getCMSImageURLForCommunity() : ' + e.getMessage() + ' line number: ' + e.getLineNumber());
			}
		}
		return imageURLMap;
    }

    private static Map<String,String> getCMSImageURLForChannel(String channelId, List<String> contentIds) {
		Map<String,String> imageURLMap = new Map<String,String>();

		if (contentIds != null && !contentIds.isEmpty() && channelId != null) {
			Datetime startDate = Datetime.newInstanceGmt(2015, 6, 6, 0, 0, 0);
			String sDate =  startDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
			Datetime endDate = Datetime.now();
			String edate =  endDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

			try {
                if (!Test.isRunningTest()) {
				    ConnectApi.ManagedContentVersionCollection contentList = ConnectApi.ManagedContent.getContentByIds(channelId, contentIds, NUMBEROFPAGE, PAGESIZE, LANGUAGE, MANAGEDCONTENTTYPE, true, sDate, edate, SHOWABSOLUTEURL);
                    if (contentList != null) {
                        for (String contentId : contentIds) {
                            for (ConnectApi.ManagedContentVersion cmsContent : contentList.items) {
                                if (cmsContent.managedContentId == contentId) {
                                    imageURLMap.put(contentId, ((ConnectApi.ManagedContentMediaSourceNodeValue) cmsContent.contentNodes.get('source')).url);
                                }
                            }
                        }
                    }
                }
			}
			catch (Exception e) {
				System.debug('getCMSImageURLForChannel() : ' + e.getMessage() + ' line number: ' + e.getLineNumber());
			}
        }
		return imageURLMap;
	}
    
    private static String getCMSChannelId() {
		String channelId = '';
		ConnectApi.ManagedContentChannelCollection channelList = ConnectApi.ManagedContent.getAllDeliveryChannels(0, 1); 
		for(ConnectApi.ManagedContentChannel channel : channelList.channels) {
			channelId = (String) ((ConnectApi.ManagedContentChannel) channel).channelId;
		}
		return channelId;
	}
}