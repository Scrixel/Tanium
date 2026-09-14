/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpJSONFeedControllerTest {
	/*
       Mock callout
    */
	private class mockCallout implements HttpCalloutMock {
		Boolean isMockResponseSuccessful;

		public mockCallout(Boolean isMockResponseSuccessful) {
			this.isMockResponseSuccessful = isMockResponseSuccessful;
		}

		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			if (this.isMockResponseSuccessful) {
				res.setStatus('OK');
				res.setStatusCode(200);
				String body = 'test body';
				res.setBody(body);
				return res;
			} else {
				CalloutException e = (CalloutException) CalloutException.class.newInstance();
				e.setMessage('Unauthorized endpoint, please check Setup->Security->Remote site settings.');
				throw e;
			}
		}
	}

	@IsTest
	static void testGetJSONFeed() {
		// Set mock
		Test.setMock(HttpCalloutMock.class, new mockCallout(true));

		Test.startTest();

		// Get it!
		x7sExpJSONFeedController.ResponseWrapper testResponseWrapper = x7sExpJSONFeedController.getJSONFeed(
			'endpoint does not matter, mock will be used',
			'feed type does not matter, default will be used'
		);

		// Assert that the two test feed items are found!
		System.assertEquals(testResponseWrapper.responseCode, 200);

		// Test debug/test mode
		testResponseWrapper = x7sExpJSONFeedController.getJSONFeed(
			'endpoint does not matter, mock will be used',
			x7sExpJSONFeedController.FEED_TYPE_TEST
		);
		System.assertEquals(testResponseWrapper.responseCode, 200);

		Test.stopTest();
	}

	@IsTest
	static void testGetJSONFeed_WhenErrorOccured_ReturnsException() {
		Test.setMock(HttpCalloutMock.class, new mockCallout(false));

		Test.startTest();
		x7sExpJSONFeedController.ResponseWrapper testResponseWrapper = x7sExpJSONFeedController.getJSONFeed(
			'endpoint does not matter, mock will be used',
			'feed type does not matter, default will be used'
		);
		System.assertNotEquals(testResponseWrapper.responseCode, 200);
		Test.stopTest();
	}
}