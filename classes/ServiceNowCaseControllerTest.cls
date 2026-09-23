/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for ServiceNowCaseController
 * @Date: 2026-07-02
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13542   2026-07-02    Created the test class
 */
@IsTest
private class ServiceNowCaseControllerTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Private_Key__c privateKey = TestFactory.buildPrivateKey();
			insert privateKey;
		}
	}

	@IsTest
	static void testGetIframeContext_WhenUserHasContext_DoReturnContextWithToken() {
		User adminUser = TestUserFactory.getAdminUser();
		User expectedUser = [SELECT Id, AccountId FROM User WHERE Id = :adminUser.Id];
		ServiceNowCaseController.IframeContext ctx;

		System.runAs(adminUser) {
			Test.startTest();
			ctx = ServiceNowCaseController.getIframeContext('TestClassKey');
			Test.stopTest();
		}

		Assert.areEqual(expectedUser.AccountId, ctx.accountId);
		Assert.isNotNull(ctx.ssoToken);
		Assert.areEqual(3, ctx.ssoToken.split('\\.').size());
	}

	@IsTest
	static void testGetBaseUrl_Always_DoReturnConfiguredUrl() {
		User adminUser = TestUserFactory.getAdminUser();
		String expectedUrl = Utility.getInstanceSettingValue('ServiceNowIntegrationUrl');
		String actualUrl;

		System.runAs(adminUser) {
			Test.startTest();
			actualUrl = ServiceNowCaseController.getBaseUrl();
			Test.stopTest();
		}

		Assert.areEqual(expectedUrl, actualUrl);
	}

	@IsTest
	static void testGenerateToken_WhenValidUserProvided_DoReturnJwtFormattedToken() {
		User adminUser = TestUserFactory.getAdminUser();
		User expectedUser = [SELECT Id, Email, Name FROM User WHERE Id = :adminUser.Id];
		String token;

		System.runAs(adminUser) {
			Test.startTest();
			token = ServiceNowCaseController.generateToken(expectedUser, 'TestClassKey');
			Test.stopTest();
		}

		Assert.areEqual(3, token.split('\\.').size());
		Assert.isFalse(token.contains('+'));
		Assert.isFalse(token.contains('/'));
	}
}