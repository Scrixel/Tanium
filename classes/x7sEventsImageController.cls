/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Events Image Controller to handle loading different type of images.
 */
public with sharing class x7sEventsImageController {
	/**
	 * @description Get List of Image Types from Event Object
	 *
	 * @return Map<String, String> - Map of Image Types
	 */
	@AuraEnabled
	public static Map<String, String> getImageTypes() {
		Map<String, String> options = new Map<String, String>();
		try {
			Schema.DescribeFieldResult fieldResult = X7S_Event__c.Image_Type__c.getDescribe();
			List<Schema.PicklistEntry> imageTypes = fieldResult.getPicklistValues();

			for (Schema.PicklistEntry type : imageTypes) {
				options.put(type.getValue(), type.getLabel());
			}
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}

		return options;
	}

	/**
	 * @description Get Image URL for each event in collection
	 * @param eventList : List of events to retrieve image urls.
	 * @return Map<Id, String> - Map of Id of Event Id and Image URL
	 */
	public static Map<Id, String> getImageURL(List<X7S_Event__c> eventList) {
		Map<Id, String> eventToImageURLMap = new Map<Id, String>();
		Map<Id, String> eventsWithRelatedFiles = new Map<Id, String>();
		Map<Id, String> eventsWithExternalURL = new Map<Id, String>();
		Map<Id, String> eventsWithStaticResource = new Map<Id, String>();
		Map<Id, String> eventsWithCMSImage = new Map<Id, String>();

		for (X7S_Event__c event : eventList) {
			switch on event.Image_Type__c {
				when 'Related File' {
					eventsWithRelatedFiles.put(event.Id, event.Image_Reference__c);
				}
				when 'External URL' {
					eventsWithExternalURL.put(event.Id, event.Image_Reference__c);
				}
				when 'Static Resource' {
					eventsWithStaticResource.put(event.Id, event.Image_Reference__c);
				}
				when 'CMS Content' {
					eventsWithCMSImage.put(event.Id, event.Image_Reference__c);
				}
			}
		}

		//When Image Type = Related File
		if (!eventsWithRelatedFiles.isEmpty()) {
			List<Id> listIds = new List<Id>();
			listIds.addAll(eventsWithRelatedFiles.keySet());

			//Get All document links for event having Image Type = Related File only
			List<ContentDocumentLink> documentLinkList = x7sEventsContentDocument.getContentDocumentLinks(
				listIds
			);
			String communityURL = x7sEventsBaseController.getCommunityUrl();

			for (Id eventId : eventsWithRelatedFiles.keySet()) {
				Id imageId;
				String imageURL;
				List<ContentDocumentLink> links = x7sEventsContentDocument.containsEntityId(
					documentLinkList,
					eventId
				);

				//Get the Image Reference field value
				String imageRef = eventsWithRelatedFiles.get(eventId);
				if (imageRef != null && imageRef != '') {
					for (ContentDocumentLink docLink : links) {
						if (docLink.ContentDocument.LatestPublishedVersionId == imageRef) {
							imageId = docLink.ContentDocument.LatestPublishedVersionId;
							break;
						}
					}
				}
				if (imageId == null && !links.isEmpty()) {
					imageURL =
						communityURL +
						x7sEventsContentDocument.FILE_LOCATION +
						links[0].ContentDocument.LatestPublishedVersionId;
				} else {
					imageURL = communityURL + x7sEventsContentDocument.FILE_LOCATION + imageId;
				}
				if (imageURL != null) {
					eventToImageURLMap.put(eventId, (String) imageURL);
				}
			}
		}

		//When Image Type = External URL
		if (!eventsWithExternalURL.isEmpty()) {
			for (Id eventId : eventsWithExternalURL.keySet()) {
				if (
					eventsWithExternalURL.get(eventId) != null &&
					eventsWithExternalURL.get(eventId) != ''
				) {
					eventToImageURLMap.put(eventId, (String) (eventsWithExternalURL.get(eventId)));
				}
			}
		}

		//When Image Type = Static Resource
		if (!eventsWithStaticResource.isEmpty()) {
			for (Id eventId : eventsWithStaticResource.keySet()) {
				if (
					eventsWithStaticResource.get(eventId) != null &&
					eventsWithStaticResource.get(eventId) != ''
				) {
					String imageURL = '/resource/' + eventsWithStaticResource.get(eventId);
					eventToImageURLMap.put(eventId, (String) imageURL);
				}
			}
		}

		//When Image Type = CMS Content
		if (!eventsWithCMSImage.isEmpty()) {
			Map<String, String> contentIdToImageURLMap = new Map<String, String>();
			contentIdToImageURLMap = getCMSImageURL(eventsWithCMSImage, new List<String>());
			if (!contentIdToImageURLMap.isEmpty()) {
				for (Id eventId : eventsWithCMSImage.keySet()) {
					String imageURL = contentIdToImageURLMap.containsKey(eventsWithCMSImage.get(eventId))
						? contentIdToImageURLMap.get(eventsWithCMSImage.get(eventId))
						: '';
					eventToImageURLMap.put(eventId, (String) imageURL);
				}
			}
		}
		return eventToImageURLMap;
	}

	/**
	 * @description Get Image URL of the image stored in the CMS
	 *
	 * @param eventsWithCMSImage : Event Ids to CMS Content Ids Map
	 * @param contentIdList : List of CMS Content Ids
	 *
	 * @return imageURLMap : CMS Content Id to content image URL Map
	 **/
	@AuraEnabled
	public static Map<String, String> getCMSImageURL(
		Map<Id, String> eventsWithCMSImage,
		List<String> contentIdList
	) {
		Map<String, String> imageURLMap;
		try {
			imageURLMap = callCMSUtilities(
				eventsWithCMSImage,
				contentIdList,
				System.Network.getNetworkId(),
				new x7sEventsCMSHelper()
			);
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}

		return imageURLMap;
	}

	@TestVisible
	private static Map<String, String> callCMSUtilities(
		Map<Id, String> eventsWithCMSImage,
		List<String> contentIdList,
		String communityId,
		x7sEventsCMSHelper eventsCMSHelper
	) {
		List<String> contentIds = new List<String>();
		Map<String, String> imageURLMap;

		if (!eventsWithCMSImage.isEmpty()) {
			for (String content : eventsWithCMSImage.values()) {
				if (content != null && String.isNotBlank(content) && ((String) content).length() == 18) {
					contentIds.add(content);
				}
			}
		} else if (!contentIdList.isEmpty()) {
			contentIds.addAll(contentIdList);
		}

		if (communityId == null) {
			String channelId = (String) getCMSChannelId(eventsCMSHelper);
			imageURLMap = getCMSImageURLForChannel(channelId, contentIds, eventsCMSHelper);
		} else {
			imageURLMap = getCMSImageURLForCommunity(contentIds, communityId, eventsCMSHelper);
		}

		return imageURLMap;
	}

	private static Map<String, String> getCMSImageURLForCommunity(
		List<String> contentIds,
		String communityId,
		x7sEventsCMSHelper eventsCMSHelper
	) {
		Map<String, String> imageURLMap = new Map<String, String>();

		if (contentIds != null && !contentIds.isEmpty()) {
			try {
				ConnectApi.ManagedContentVersionCollection contentList = eventsCMSHelper.getManagedContentByIds(
					communityId,
					contentIds
				);
				if (contentList != null) {
					for (String contentId : contentIds) {
						for (ConnectApi.ManagedContentVersion cmsContent : contentList.items) {
							if (cmsContent.managedContentId == contentId) {
								imageURLMap.put(
									contentId,
									((ConnectApi.ManagedContentMediaSourceNodeValue) cmsContent.contentNodes.get(
											'source'
										))
										.url
								);
							}
						}
					}
				}
			} catch (Exception e) {
				System.debug(
					'getCMSImageURLForCommunity() : ' +
					e.getMessage() +
					' line number: ' +
					e.getLineNumber()
				);
			}
		}
		return imageURLMap;
	}

	private static Map<String, String> getCMSImageURLForChannel(
		String channelId,
		List<String> contentIds,
		x7sEventsCMSHelper eventsCMSHelper
	) {
		Map<String, String> imageURLMap = new Map<String, String>();

		if (contentIds != null && !contentIds.isEmpty() && channelId != null) {
			Datetime startDate = Datetime.newInstanceGmt(2015, 6, 6, 0, 0, 0);
			String startDateFormatted = startDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
			Datetime endDate = Datetime.now();
			String endDateFormatted = endDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');

			try {
				ConnectApi.ManagedContentVersionCollection contentList = eventsCMSHelper.getContentByIds(
					channelId,
					contentIds,
					startDateFormatted,
					endDateFormatted
				);

				if (contentList != null) {
					for (String contentId : contentIds) {
						for (ConnectApi.ManagedContentVersion cmsContent : contentList.items) {
							if (cmsContent.managedContentId == contentId) {
								imageURLMap.put(
									contentId,
									((ConnectApi.ManagedContentMediaSourceNodeValue) cmsContent.contentNodes.get(
											'source'
										))
										.url
								);
							}
						}
					}
				}
			} catch (Exception e) {
				System.debug(
					'getCMSImageURLForChannel() : ' +
					e.getMessage() +
					' line number: ' +
					e.getLineNumber()
				);
			}
		}
		return imageURLMap;
	}

	private static String getCMSChannelId(x7sEventsCMSHelper eventsCMSHelper) {
		String channelId = '';
		ConnectApi.ManagedContentChannelCollection channelList = eventsCMSHelper.getAllDeliveryChannels();

		for (ConnectApi.ManagedContentChannel channel : channelList.channels) {
			channelId = (String) ((ConnectApi.ManagedContentChannel) channel).channelId;
		}

		return channelId;
	}
}