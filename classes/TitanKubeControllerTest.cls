/**
 * @Business: Test class for TitanKubeController
 * @Authors: Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-11659   2025-07-09    Created the test class
 */
@IsTest
private class TitanKubeControllerTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Private_Key__c privateKey = TestFactory.buildPrivateKey();
			insert privateKey;
		}
	}

	@IsTest
	static void testGenerateUserVoiceUrl_WhenValidUserAndFeature_ReturnUserVoiceTestUrl() {
		String userVoiceUrl = null;
		Test.startTest();
		userVoiceUrl = TitanKubeController.generateUserVoiceUrl(UserInfo.getUserId(), 'TestClassKey');
		Test.stopTest();

		Assert.isNotNull(userVoiceUrl);
	}
}