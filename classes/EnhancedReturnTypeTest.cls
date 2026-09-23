/*
 * @BUSINESS: Test class for class EnhancedReturnType
 * @DATE: 2024-04-23
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7698    2024-04-23    Created the test class
 */
@IsTest
private class EnhancedReturnTypeTest {
	@TestSetup
	static void makeData() {
	}

	@IsTest
	static void testGetRetResult_WhenEmptyConstructor_ReturnNull() {
		EnhancedReturnType rt;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = new EnhancedReturnType();
			Test.stopTest();
		}

		Assert.isTrue(rt.retResult == null);
	}

	@IsTest
	static void testGetRetResult_WhenOverloadedConstructorNoRetDataProvided_ReturnNull() {
		EnhancedReturnType rt;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = new EnhancedReturnType(true);
			Test.stopTest();
		}

		Assert.isTrue(rt.retData == null);
	}

	@IsTest
	static void testGetRetResult_WhenOverloadedConstructor_ReturnRetData() {
		EnhancedReturnType rt;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			rt = new EnhancedReturnType('retMessage', false);
			Test.stopTest();
		}

		Assert.isTrue(rt.retData == 'retMessage');
	}
}