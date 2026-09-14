@isTest
global class RestAPIMock_Test implements HttpCalloutMock {
	protected Integer code;
	protected String status;
	protected String body;
	protected Map<String, String> responseHeaders;
	protected Integer callouts = 0;

	public RestAPIMock_Test(
		Integer code,
		String status,
		String body,
		Map<String, String> responseHeaders
	) {
		this.code = code;
		this.status = status;
		this.body = body;
		this.responseHeaders = responseHeaders;
	}

	global HttpResponse respond(HttpRequest request) {
		HttpResponse response = new HttpResponse();
		for (String key : this.responseHeaders.keySet()) {
			response.setHeader(key, this.responseHeaders.get(key));
		}
		response.setBody(this.body);
		response.setStatusCode(this.code);
		if (this.status != null) {
			response.setStatus(this.status);
		}
		this.callouts++;
		return response;
	}

	public Integer getCallouts() {
		return this.callouts;
	}
}