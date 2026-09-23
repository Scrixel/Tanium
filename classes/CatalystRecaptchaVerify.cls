/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Class for verifying reCAPTCHA tokens, support Catalyst Register Screen Flow
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-08       Created the class
 */
public with sharing class CatalystRecaptchaVerify {
	private static final String SITEVERIFY_ENDPOINT = 'https://www.google.com/recaptcha/api/siteverify';

	@InvocableMethod(
		label='Verify reCAPTCHA Token'
		description='Calls Google siteverify with the secret key and returns whether the token is valid.'
		category='reCAPTCHA'
	)
	public static List<Result> verify(List<Request> requests) {
		List<Result> results = new List<Result>();
		String secretKey = Utility.getInstanceSettingValue('CustAuthSelfRegCaptchaSecretKey');

		for (Request request : requests) {
			Result result = new Result();

			if (String.isBlank(secretKey)) {
				//reCAPTCHA secret key is not configured, but we return generic error to user in case hacker is trying to use information somehow.
				result.errorMessage = 'reCAPTCHA error, please contact your administrator.';
				results.add(result);
				continue;
			}

			if (String.isBlank(request.token)) {
				//No reCAPTCHA token was supplied, but we return generic error to user in case hacker is trying to use information somehow.
				result.errorMessage = 'reCAPTCHA error, please contact your administrator.';
				results.add(result);
				continue;
			}

			try {
				result = callSiteVerify(secretKey, request.token);
			} catch (Exception e) {
				// Callout to reCAPTCHA siteverify failed:, but we return generic error to user in case hacker is trying to use information somehow.
				result.isValid = false;
				result.errorMessage = 'reCAPTCHA error, please contact your administrator.';
			}
			results.add(result);
		}
		return results;
	}

	private static Result callSiteVerify(String secretKey, String token) {
		Result result = new Result();
		HttpRequest httpReq = new HttpRequest();
		httpReq.setEndpoint(SITEVERIFY_ENDPOINT);
		httpReq.setMethod('POST');
		httpReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
		httpReq.setTimeout(10000);
		String body =
			'secret=' +
			EncodingUtil.urlEncode(secretKey, 'UTF-8') +
			'&response=' +
			EncodingUtil.urlEncode(token, 'UTF-8');
		httpReq.setBody(body);
		Http http = new Http();
		HttpResponse httpRes = http.send(httpReq);

		if (httpRes.getStatusCode() != 200) {
			result.isValid = false;
			result.errorMessage = 'Unexpected HTTP status from Google: ' + httpRes.getStatusCode();
			return result;
		}

		Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
		result.isValid = (parsed.get('success') == true);

		if (parsed.get('score') != null) {
			result.score = (Decimal) parsed.get('score');
		}

		if (!result.isValid) {
			List<Object> errorCodes = (List<Object>) parsed.get('error-codes');
			result.errorMessage = (errorCodes != null && !errorCodes.isEmpty())
				? String.join(toStringList(errorCodes), ', ')
				: 'Verification failed.';
		}
		return result;
	}

	private static List<String> toStringList(List<Object> objects) {
		List<String> strings = new List<String>();
		for (Object obj : objects) {
			strings.add(String.valueOf(obj));
		}
		return strings;
	}

	public class Request {
		@InvocableVariable(
			label='reCAPTCHA Token'
			description='The g-recaptcha-response token produced by the recaptchaWidget LWC.'
			required=true
		)
		public String token;
	}

	public class Result {
		@InvocableVariable(label='Is Valid')
		public Boolean isValid = false;

		@InvocableVariable(label='Score (v3 only - null for v2 checkbox)')
		public Decimal score;

		@InvocableVariable(label='Error Message')
		public String errorMessage;
	}
}