@isTest
global class RestAPIUnauthorizedEndpointMock_Test implements HttpCalloutMock {
	global HttpResponse respond(HttpRequest request) {
		CalloutException calloutException = (CalloutException) CalloutException.class.newInstance();
		calloutException.setMessage(
			'Unauthorized endpoint, please check Setup->Security->Remote Site Settings'
		);
		throw calloutException;
	}
}