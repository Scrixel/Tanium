/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description This is helper class for the ConnectApi ManagedContent Calls
 */
public with sharing class x7sEventsCMSHelper {
	final static Integer NUMBER_OF_PAGE = 0;
	final static Integer PAGE_SIZE = 250;
	final static String LANGUAGE = 'en_US';
	final static Boolean SHOW_ABSOLUTE_URL = true;
	final static String MANAGED_CONTENT_TYPE = 'cms_image';

	/**
	 * @description Get managed content versions for an Experience Cloud site using a list of managed content IDs.
	 * @param communityId Id of current community
	 * @param contentIds List of content Ids
	 * @return ConnectApi.ManagedContentVersionCollection
	 */
	public ConnectApi.ManagedContentVersionCollection getManagedContentByIds(
		String communityId,
		List<String> contentIds
	) {
        System.debug('ConnectApi.ManagedContent.getManagedContentByIds');
		return ConnectApi.ManagedContent.getManagedContentByIds(
			communityId,
			contentIds,
			NUMBER_OF_PAGE,
			PAGE_SIZE,
			LANGUAGE,
			MANAGED_CONTENT_TYPE,
			SHOW_ABSOLUTE_URL
		);
	}

	/**
	 * @description Get managed content versions for a channel using a list of managed content IDs.
	 * @param channelId channel Id
	 * @param contentIds List of content ids
	 * @param startDate Start date to search
	 * @param endDate End date to search
	 * @return ConnectApi.ManagedContentVersionCollection
	 */
	public ConnectApi.ManagedContentVersionCollection getContentByIds(
		String channelId,
		List<String> contentIds,
		String startDate,
		String endDate
	) {
		return ConnectApi.ManagedContent.getContentByIds(
			channelId,
			contentIds,
			NUMBER_OF_PAGE,
			PAGE_SIZE,
			LANGUAGE,
			MANAGED_CONTENT_TYPE,
			true,
			startDate,
			endDate,
			SHOW_ABSOLUTE_URL
		);
	}

	/**
	 * @description Get managed content delivery channels for the context user.
	 * @return ConnectApi.ManagedContentChannelCollection
	 */
	public ConnectApi.ManagedContentChannelCollection getAllDeliveryChannels() {
		return ConnectApi.ManagedContent.getAllDeliveryChannels(0, 1);
	}
}