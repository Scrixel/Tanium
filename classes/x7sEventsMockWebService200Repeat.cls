/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@SuppressWarnings('PMD.AvoidGlobalModifier')
@IsTest
global class x7sEventsMockWebService200Repeat implements HttpCalloutMock {
	private Integer responseCode;
	private String body = x7sEventsTestConstants.TEST_HTTP_BODY;
	private String bodyRepeat = '';
	private String repeatFlag = 'repeat_body';

	public x7sEventsMockWebService200Repeat(Integer responseCode) {
		this.responseCode = responseCode;
	}

	public x7sEventsMockWebService200Repeat(Integer responseCode, String body, String bodyRepeat) {
		this.responseCode = responseCode;
		this.body = body;
		this.bodyRepeat = bodyRepeat;
	}

	global HTTPResponse respond(HTTPRequest req) {
		// Send a mock response for a specific endpoint and method.
		String endpointUrl = req.getEndpoint();
		String returnBody = body;
		String splitTerm = 'next_page_token';

		System.assertEquals(
			true,
			endpointUrl.split(splitTerm).size() == 2,
			'Check if the url contains multiple instances of next page token'
		);

		if (endpointUrl.contains(repeatFlag)) {
			returnBody = bodyRepeat;
		}

		// Create a successful response
		HttpResponse res = new HttpResponse();
		res.setHeader('Content-Type', 'application/json');
		res.setBody(returnBody);
		res.setStatusCode(this.responseCode);
		return res;
	}
}