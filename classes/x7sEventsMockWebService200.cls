/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@SuppressWarnings('PMD.AvoidGlobalModifier')
@IsTest
global class x7sEventsMockWebService200 implements HttpCalloutMock {
	private Integer responseCode;
	private String body = x7sEventsTestConstants.TEST_HTTP_BODY;

	public x7sEventsMockWebService200(Integer responseCode) {
		this.responseCode = responseCode;
	}

	public x7sEventsMockWebService200(Integer responseCode, String body) {
		this.responseCode = responseCode;
		this.body = body;
	}

	global HTTPResponse respond(HTTPRequest req) {
		// Send a mock response for a specific endpoint and method.
		String endpointUrl = req.getEndpoint();
		System.assertEquals(endpointUrl, req.getEndpoint());

		// Create a successful response
		HttpResponse res = new HttpResponse();
		res.setHeader('Content-Type', 'application/json');
		res.setBody(body);
		res.setStatusCode(this.responseCode);
		return res;
	}
}