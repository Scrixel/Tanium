/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

/**
 * @description Events Image Mock Provider used for mocking and testing ConnectAPI calls
 */
public with sharing class x7sEventsImageMockProvider implements System.StubProvider {
	private static final String GET_CONTENT_BY_IDS = 'getContentByIds';
	private static final String GET_MANAGED_CONTENT_BY_IDS = 'getManagedContentByIds';
	private static final String GET_ALL_DELIVERY_CHANNELS = 'getAllDeliveryChannels';
	private static final String TEST_URL = 'SampleUrl';
	private static final String TEST_CHANNEL_ID = 'SampleChannelId';

	/**
	 * @description Handle Method Call - required to implement for StubProvider.  Handles all calls to Mock.
	 * @param stubbedObject : Object that is mocked
	 * @param stubbedMethodName : Method name that was called
	 * @param returnType : return type of method called
	 * @param listOfParamTypes : List of parameters
	 * @param listOfParamNames : List of parameter names
	 * @param listOfArgs : List of arguments
	 * @return Object : return object from method call
	 */
	public Object handleMethodCall(
		Object stubbedObject,
		String stubbedMethodName,
		Type returnType,
		List<Type> listOfParamTypes,
		List<String> listOfParamNames,
		List<Object> listOfArgs
	) {
		if (stubbedMethodName == GET_CONTENT_BY_IDS) {
			ConnectApi.ManagedContentVersionCollection managedContentVersionCollection = new ConnectApi.ManagedContentVersionCollection();
			ConnectApi.ManagedContentVersion managedContentVersion = new ConnectApi.ManagedContentVersion();
			managedContentVersionCollection.items = new List<ConnectApi.ManagedContentVersion>();
			ConnectApi.ManagedContentMediaSourceNodeValue nodeValue = new ConnectApi.ManagedContentMediaSourceNodeValue();

			managedContentVersion.managedContentId = x7sEventsTestConstants.TEST_CMS_ID_1;
			managedContentVersion.contentNodes = new Map<String, ConnectApi.ManagedContentNodeValue>();

			nodeValue.url = TEST_URL;
			managedContentVersion.contentNodes.put('source', nodeValue);
			managedContentVersionCollection.items.add(managedContentVersion);

			return managedContentVersionCollection;
		} else if (stubbedMethodName == GET_MANAGED_CONTENT_BY_IDS) {
			ConnectApi.ManagedContentVersionCollection managedContentVersionCollection = new ConnectApi.ManagedContentVersionCollection();
			ConnectApi.ManagedContentVersion managedContentVersion = new ConnectApi.ManagedContentVersion();
			managedContentVersionCollection.items = new List<ConnectApi.ManagedContentVersion>();
			ConnectApi.ManagedContentMediaSourceNodeValue nodeValue = new ConnectApi.ManagedContentMediaSourceNodeValue();

			managedContentVersion.managedContentId = x7sEventsTestConstants.TEST_CMS_ID_1;

			managedContentVersion.contentNodes = new Map<String, ConnectApi.ManagedContentNodeValue>();

			nodeValue.url = TEST_URL;
			managedContentVersion.contentNodes.put('source', nodeValue);
			managedContentVersionCollection.items.add(managedContentVersion);

			return managedContentVersionCollection;
		} else if (stubbedMethodName == GET_ALL_DELIVERY_CHANNELS) {
			ConnectApi.ManagedContentChannelCollection managedContentChannelCollection = new ConnectApi.ManagedContentChannelCollection();
			ConnectApi.ManagedContentChannel managedContentChannel = new ConnectApi.ManagedContentChannel();
			managedContentChannelCollection.channels = new List<ConnectApi.ManagedContentChannel>();

			managedContentChannel.channelId = TEST_CHANNEL_ID;
			managedContentChannelCollection.channels.add(managedContentChannel);

			return managedContentChannelCollection;
		}

		return null;
	}
}