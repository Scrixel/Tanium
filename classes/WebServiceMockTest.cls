@isTest
global class WebServiceMockTest implements WebServiceMock {
	global void doInvoke(
		Object stub,
		Object request,
		Map<String, Object> response,
		String endpoint,
		String soapAction,
		String requestName,
		String responseNS,
		String responseName,
		String responseType
	) {
		switch on requestName {
			when 'SampleServiceName' {
				response.put('response_x', 'Success');
			}
			when else {
				response.put('response_x', 'Success');
			}
		}
	}
}