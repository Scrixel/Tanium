/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CatalystUserReactivation
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-08       Created the test class
 */
@IsTest
private class CatalystUserReactivationTest {
	@TestSetup
	static void makeData() {
		Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

		User inactiveUser = new User(
			FirstName = 'Reactivate',
			LastName = 'TestUser',
			Email = 'reactivate.testuser@catalysttest.invalid',
			Username = 'reactivate.testuser.' + DateTime.now().getTime() + '@catalysttest.invalid',
			Alias = 'reacttu',
			CommunityNickname = 'reacttu' + DateTime.now().getTime(),
			ProfileId = standardProfile.Id,
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			IsActive = false
		);
		insert inactiveUser;
	}

	@IsTest
	static void testReactivateUsers_WhenInactiveUser_UserIsReactivated() {
		User user = [
			SELECT Id, IsActive
			FROM User
			WHERE LastName = 'TestUser' AND FirstName = 'Reactivate'
			LIMIT 1
		];
		List<CatalystUserReactivation.Response> results;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystUserReactivation.reactivateUsers(
				new List<CatalystUserReactivation.Request>{ buildRequest(user.Id) }
			);
			Test.stopTest();
		}

		Assert.areEqual(1, results.size());
		CatalystUserReactivation.Response response = results[0];
		Assert.areEqual(
			true,
			response.isSuccess,
			'Reactivation should succeed: ' + response.errorMessage
		);

		User reActivatedUser = [SELECT Id, IsActive FROM User WHERE Id = :user.Id];
		Assert.areEqual(true, reActivatedUser.IsActive, 'User should now be active.');
	}

	@IsTest
	static void testReactivateUsers_WhenNullUserId_ReturnsGracefulError() {
		List<CatalystUserReactivation.Response> results;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystUserReactivation.reactivateUsers(
				new List<CatalystUserReactivation.Request>{ buildRequest(null) }
			);
			Test.stopTest();
		}

		CatalystUserReactivation.Response response = results[0];
		Assert.areEqual(false, response.isSuccess);
		Assert.isTrue(String.isNotBlank(response.errorMessage));
	}

	@IsTest
	static void testReactivateUsers_NonExistentUserId_ReturnsGracefulError() {
		Id fakeUserId = Id.valueOf('005000000000000AAA');
		List<CatalystUserReactivation.Response> results;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystUserReactivation.reactivateUsers(
				new List<CatalystUserReactivation.Request>{ buildRequest(fakeUserId) }
			);
			Test.stopTest();
		}

		CatalystUserReactivation.Response response = results[0];
		Assert.areEqual(false, response.isSuccess);
		Assert.isTrue(
			response.errorMessage.contains('No valid user IDs provided'),
			'Expected No valid user IDs provided, got: ' + response.errorMessage
		);
	}

	@IsTest
	static void testDescribeErrors_WhenNull_HandlesNullSaveResult() {
		String message;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			message = CatalystUserReactivation.describeErrors(null);
		}
		Assert.areEqual('Unknown error reactivating user.', message);
	}

	private static CatalystUserReactivation.Request buildRequest(Id userId) {
		CatalystUserReactivation.Request request = new CatalystUserReactivation.Request();
		request.userId = userId;
		return request;
	}
}