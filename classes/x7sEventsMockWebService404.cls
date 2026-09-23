/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@SuppressWarnings('PMD.AvoidGlobalModifier')
@IsTest
global class x7sEventsMockWebService404 implements HttpCalloutMock {
	global HTTPResponse respond(HTTPRequest req) {
		// Send a mock response for a specific endpoint and method.
		String endpointUrl = req.getEndpoint();
		System.assertEquals(endpointUrl, req.getEndpoint());

		// Create an error response
		HttpResponse res = new HttpResponse();
		res.setStatusCode(404);
		return res;
	}
}