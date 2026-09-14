/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CatalystRecaptchaGetKey
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-07       Created the class
 */
@IsTest
private class CatalystRecaptchaGetKeyTest {
	@IsTest
	static void testGetKey_WhenValidType_ReturnKey() {
		String keyType = 'CustAuthSelfRegCaptchaKey'; // TODO: replace with a real key type used in this org
		List<CatalystRecaptchaGetKey.Result> results;
		CatalystRecaptchaGetKey.Request request = new CatalystRecaptchaGetKey.Request();
		request.keyType = keyType;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaGetKey.getKey(
				new List<CatalystRecaptchaGetKey.Request>{ request }
			);
			Test.stopTest();
		}

		Assert.areEqual(1, results.size(), 'Expected exactly one result for one request.');
		Assert.areEqual(
			Utility.getInstanceSettingValue(keyType),
			results[0].siteKey,
			'Result siteKey should match what Utility.getInstanceSettingValue returns for the given keyType.'
		);
	}

	@IsTest
	static void testGetKey_WhenBulkRequest_ReturnResults() {
		List<String> keyTypes = new List<String>{
			'BaseUrlClassic',
			'BaseUrlLightning',
			'CustAuthSelfRegCaptchaKey'
		};

		List<CatalystRecaptchaGetKey.Request> requests = new List<CatalystRecaptchaGetKey.Request>();
		List<CatalystRecaptchaGetKey.Result> results;
		for (String keyType : keyTypes) {
			CatalystRecaptchaGetKey.Request req = new CatalystRecaptchaGetKey.Request();
			req.keyType = keyType;
			requests.add(req);
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaGetKey.getKey(requests);
			Test.stopTest();
		}
		Assert.areEqual(
			keyTypes.size(),
			results.size(),
			'Expected one result per request, in order.'
		);
		for (Integer i = 0; i < keyTypes.size(); i++) {
			Assert.areEqual(
				Utility.getInstanceSettingValue(keyTypes[i]),
				results[i].siteKey,
				'Result at index ' + i + ' should correspond to the request at the same index.'
			);
		}
	}

	@IsTest
	static void testGetKey_WhenEmptyInput_ReturnsEmptyList() {
		List<CatalystRecaptchaGetKey.Result> results;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystRecaptchaGetKey.getKey(new List<CatalystRecaptchaGetKey.Request>());
			Test.stopTest();
		}

		Assert.areEqual(
			0,
			results.size(),
			'An empty request list should produce an empty result list.'
		);
	}
}