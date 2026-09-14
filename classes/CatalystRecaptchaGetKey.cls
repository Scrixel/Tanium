/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Class get ReCaptcha site key dynamically, support Catalyst Register Screen Flow
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-07       Created the class
 */
public with sharing class CatalystRecaptchaGetKey {
	@InvocableMethod(
		label='Get reCAPTCHA Key'
		description='Retrieves the reCAPTCHA key based on the specified key type.'
		category='reCAPTCHA'
	)
	public static List<Result> getKey(List<Request> requests) {
		List<Result> results = new List<Result>();
		Result result;

		for (Request request : requests) {
			result = new Result();
			result.siteKey = Utility.getInstanceSettingValue(request.keyType);
			results.add(result);
		}
		return results;
	}

	public class Request {
		@InvocableVariable(
			label='Key Type'
			description='The type of reCAPTCHA key to retrieve.'
			required=true
		)
		public String keyType;
	}

	public class Result {
		@InvocableVariable(label='Site Key')
		public String siteKey;
	}
}