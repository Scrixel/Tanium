/**
 * @Business: Test class CryptoUtility
 * @Author: Tanium Dev team
 * RequestId  ModifiedDate  Description
 * SS-11659   2025-09-14    Created the test class
 */
@IsTest
private class CryptoUtilityTest {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Private_Key__c privateKey = TestFactory.buildPrivateKey();
			insert privateKey;
		}
	}

	@IsTest
	static void testEncryptDecryptData_WhenValidFeature_DecryptedDataEqualsData() {
		Private_Key__c privateKey = [SELECT Id, Key__c FROM Private_Key__c];
		String instanceSettingType = 'TestClassKey';
		String dataToEncrypt = 'SomePrivateKey!';
		String encryptedData;
		String decryptedData;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			encryptedData = CryptoUtility.encryptData(dataToEncrypt, instanceSettingType);
			decryptedData = CryptoUtility.decryptData(encryptedData, instanceSettingType);
			Test.stopTest();
		}
		Assert.isTrue(decryptedData == dataToEncrypt);
	}
}