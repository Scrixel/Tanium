/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CatalystRecaptchaVerify
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-08       Created the test class
 */

@IsTest
private class CatalystRecaptchaVerifyTest {
	@IsTest
	static void testVerify_WhenValidToken_ReturnSuccess() {
		Test.setMock(HttpCalloutMock.class, new SuccessMock());
		List<CatalystRecaptchaVerify.Result> results;
		CatalystRecaptchaVerify.Request request = new CatalystRecaptchaVerify.Request();
		request.token = 'fake-token';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaVerify.verify(
				new List<CatalystRecaptchaVerify.Request>{ request }
			);
			Test.stopTest();
		}

		Assert.areEqual(1, results.size());
		Assert.areEqual(true, results[0].isValid);
		Assert.areEqual(null, results[0].errorMessage);
	}

	@IsTest
	static void testVerify_WhenFailedVerification_ReturnInvalidInputResponseMsg() {
		Test.setMock(HttpCalloutMock.class, new FailureMock());
		List<CatalystRecaptchaVerify.Result> results;
		CatalystRecaptchaVerify.Request request = new CatalystRecaptchaVerify.Request();
		request.token = 'bad-token';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaVerify.verify(
				new List<CatalystRecaptchaVerify.Request>{ request }
			);
			Test.stopTest();
		}

		Assert.areEqual(false, results[0].isValid);
		Assert.isTrue(results[0].errorMessage.contains('invalid-input-response'));
	}

	@IsTest
	static void testVerify_WhenInvalidToken_ReturnServerErrorMsg() {
		Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
		List<CatalystRecaptchaVerify.Result> results;
		CatalystRecaptchaVerify.Request request = new CatalystRecaptchaVerify.Request();
		request.token = 'some-token';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaVerify.verify(
				new List<CatalystRecaptchaVerify.Request>{ request }
			);
			Test.stopTest();

			Assert.areEqual(false, results[0].isValid);
			Assert.isTrue(results[0].errorMessage.contains('503'));
		}
	}

	@IsTest
	static void testVerify_WhenBlankToken_ReturnNoTokenSuppliedMsg() {
		List<CatalystRecaptchaVerify.Result> results;
		CatalystRecaptchaVerify.Request request = new CatalystRecaptchaVerify.Request();
		request.token = '';

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaVerify.verify(
				new List<CatalystRecaptchaVerify.Request>{ request }
			);
			Test.stopTest();
		}

		Assert.areEqual(false, results[0].isValid);
		Assert.areEqual('No reCAPTCHA token was supplied.', results[0].errorMessage);
	}

	@IsTest
	static void testVerify_WhenBulkRequests_ReturnValidResults() {
		Test.setMock(HttpCalloutMock.class, new SuccessMock());
		List<CatalystRecaptchaVerify.Result> results;
		List<CatalystRecaptchaVerify.Request> requests = new List<CatalystRecaptchaVerify.Request>();
		for (Integer i = 0; i < 5; i++) {
			CatalystRecaptchaVerify.Request request = new CatalystRecaptchaVerify.Request();
			request.token = 'token-' + i;
			requests.add(request);
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaVerify.verify(requests);
			Test.stopTest();
		}

		Assert.areEqual(5, results.size());
		for (CatalystRecaptchaVerify.Result result : results) {
			Assert.areEqual(true, result.isValid);
		}
	}

	private class SuccessMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(200);
			res.setBody(
				'{"success": true, "challenge_ts": "2026-01-01T00:00:00Z", "hostname": "test.my.salesforce.com"}'
			);
			return res;
		}
	}

	private class FailureMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(200);
			res.setBody('{"success": false, "error-codes": ["invalid-input-response"]}');
			return res;
		}
	}

	private class ServerErrorMock implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(503);
			res.setBody('Service Unavailable');
			return res;
		}
	}
}