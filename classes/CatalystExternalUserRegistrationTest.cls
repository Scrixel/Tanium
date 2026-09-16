/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for CatalystExternalUserRegistration
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-07       Created the test class
 */
@IsTest
private class CatalystExternalUserRegistrationTest {
	@TestSetup
	static void makeData() {
		Account account = new Account(Name = 'Catalyst Test Account');
		insert account;

		Contact contact = new Contact(
			FirstName = 'Portal',
			LastName = 'Tester',
			Email = 'portal.tester@example.invalid',
			AccountId = account.Id
		);
		insert contact;
	}

	@IsTest
	static void testCreateExternalUser_WhenNoSiteContext_ReturnsGracefulFailure() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		Profile profile = [SELECT Id FROM Profile LIMIT 1];

		CatalystExternalUserRegistration.Request request = buildRequest(
			account.Id,
			contact.Id,
			profile.Id,
			'1'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			List<CatalystExternalUserRegistration.Response> results = CatalystExternalUserRegistration.createExternalUser(
				new List<CatalystExternalUserRegistration.Request>{ request }
			);
			Test.stopTest();

			Assert.areEqual(1, results.size(), 'Expected exactly one response for one request.');
			CatalystExternalUserRegistration.Response result = results[0];
			Assert.areEqual(
				false,
				result.isSuccess,
				'Outside a Site context, creation cannot succeed.'
			);
			Assert.areEqual(null, result.userId, 'No user Id should be returned on failure.');
			Assert.isTrue(
				String.isNotBlank(result.errorMessage),
				'An error message should be populated on failure.'
			);
		}
	}

	@IsTest
	static void testCreateExternalUser_WhenBulkRequests_HandledIndependently() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		Profile profile = [SELECT Id FROM Profile LIMIT 1];

		List<CatalystExternalUserRegistration.Response> results;
		List<CatalystExternalUserRegistration.Request> requests = new List<CatalystExternalUserRegistration.Request>{
			buildRequest(account.Id, contact.Id, profile.Id, '2'),
			buildRequest(account.Id, contact.Id, profile.Id, '3')
		};

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystExternalUserRegistration.createExternalUser(requests);
			Test.stopTest();
		}

		Assert.areEqual(2, results.size(), 'Expected one response per request (bulk-safe).');
		for (CatalystExternalUserRegistration.Response result : results) {
			Assert.areEqual(
				false,
				result.isSuccess,
				'Outside a Site context, creation cannot succeed.'
			);
			Assert.isTrue(
				String.isNotBlank(result.errorMessage),
				'Each failed request should carry its own error message.'
			);
		}
	}

	@IsTest
	static void testCreateExternalUser_WhenMissingAccount_ReturnsGracefulFailure() {
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		Profile profile = [SELECT Id FROM Profile LIMIT 1];

		List<CatalystExternalUserRegistration.Response> results;
		CatalystExternalUserRegistration.Request request = buildRequest(
			null,
			contact.Id,
			profile.Id,
			'4'
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystExternalUserRegistration.createExternalUser(
				new List<CatalystExternalUserRegistration.Request>{ request }
			);
			Test.stopTest();
		}

		CatalystExternalUserRegistration.Response result = results[0];
		Assert.areEqual(false, result.isSuccess, 'Missing accountId must not succeed.');
		Assert.areEqual(
			true,
			String.isNotBlank(result.errorMessage),
			'An error message should be populated.'
		);
	}

	@isTest
	static void testCreateExternalUser_BlankAliasAndNullSendEmailFlag_DefaultsApplied() {
		Account account = [SELECT Id FROM Account LIMIT 1];
		Contact contact = [SELECT Id FROM Contact LIMIT 1];
		Profile profile = [SELECT Id FROM Profile LIMIT 1];

		List<CatalystExternalUserRegistration.Response> results;
		CatalystExternalUserRegistration.Request request = buildRequest(
			account.Id,
			contact.Id,
			profile.Id,
			'5'
		);
		request.alias = null;
		request.sendEmailConfirmation = null;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			results = CatalystExternalUserRegistration.createExternalUser(
				new List<CatalystExternalUserRegistration.Request>{ request }
			);
			Test.stopTest();
		}

		Assert.areEqual(false, results[0].isSuccess);
	}

	@IsTest
	static void testGenerateAlias_TruncatesAndStripsNonAlphanumeric() {
		String alias;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			alias = CatalystExternalUserRegistration.generateAlias('Jean-Luc', 'Connor');
			Test.stopTest();
		}

		Assert.isTrue(alias.length() <= 8, 'Alias must never exceed 8 characters.');
		Assert.areEqual(false, alias.contains('-'), 'Alias must strip hyphens.');
		Assert.areEqual(false, alias.contains('\''), 'Alias must strip apostrophes.');
	}

	@IsTest
	static void testGenerateAlias_HandlesNullNameParts() {
		String alias;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			alias = CatalystExternalUserRegistration.generateAlias(null, null);
			Test.stopTest();
		}
		Assert.areEqual(
			'',
			alias,
			'Null first and last name should yield an empty alias, not throw.'
		);

		String aliasFirstOnly = CatalystExternalUserRegistration.generateAlias('Al', null);
		Assert.areEqual('Al', aliasFirstOnly);
	}

	@IsTest
	static void testGenerateUniqueCommunityNickname_NoCollision_ReturnsBaseUnchanged() {
		String expectedBase = CatalystExternalUserRegistration.buildNicknameBase(
			'Zzqxvant',
			'Klorbin'
		);
		String generatedCommunityNickname;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			generatedCommunityNickname = CatalystExternalUserRegistration.generateUniqueCommunityNickname(
				'Zzqxvant',
				'Klorbin',
				new Set<String>()
			);
			Test.stopTest();
		}

		System.assertEquals(
			expectedBase,
			generatedCommunityNickname,
			'With no existing collision, the base itself should be returned untouched.'
		);
	}

	@IsTest
	static void testGenerateUniqueCommunityNickname_WhenCollision_AppendsSuffix() {
		String base = CatalystExternalUserRegistration.buildNicknameBase('Uniq', 'Collidetest');
		Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
		User collidingUser;
		String generatedCommunityNickname;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			collidingUser = new User(
				FirstName = 'Uniq',
				LastName = 'Collidetest',
				Email = 'uniq.collidetest@catalysttest.invalid',
				Username = 'uniq.collidetest.' + DateTime.now().getTime() + '@catalysttest.invalid',
				Alias = 'uniqct',
				CommunityNickname = base,
				ProfileId = standardProfile.Id,
				TimeZoneSidKey = 'America/Los_Angeles',
				LocaleSidKey = 'en_US',
				EmailEncodingKey = 'UTF-8',
				LanguageLocaleKey = 'en_US'
			);
			insert collidingUser;

			generatedCommunityNickname = CatalystExternalUserRegistration.generateUniqueCommunityNickname(
				'Uniq',
				'Collidetest',
				new Set<String>()
			);
			Test.stopTest();
		}

		Assert.areNotEqual(
			base,
			generatedCommunityNickname,
			'A nickname already in use must not be handed out again.'
		);
		Assert.areEqual(
			base + '1',
			generatedCommunityNickname,
			'First collision should resolve to the base with a "1" suffix (base is short enough to need no truncation).'
		);

		Integer maxLength = Schema.SObjectType.User.fields.CommunityNickname.getLength();
		Assert.isTrue(
			generatedCommunityNickname.length() <= maxLength,
			'Generated nickname must respect the field\'s max length.'
		);
	}

	@isTest
	static void testBuildNicknameBase_SanitizesAndDefaultsToUser() {
		String sanitized;

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			sanitized = CatalystExternalUserRegistration.buildNicknameBase(
				'O\'Brien-Smythe',
				'Jr. III'
			);
			Test.stopTest();
		}

		Assert.isTrue(!sanitized.contains('\''), 'Apostrophes must be stripped.');
		Assert.isTrue(!sanitized.contains('-'), 'Hyphens must be stripped.');
		Assert.isTrue(!sanitized.contains(' '), 'Spaces must be stripped.');
		Assert.isTrue(!sanitized.contains('.'), 'Periods must be stripped.');

		String fallback = CatalystExternalUserRegistration.buildNicknameBase(null, null);
		Assert.areEqual(
			'user',
			fallback,
			'Blank first/last name should fall back to a default base rather than an empty string.'
		);

		String blankStrings = CatalystExternalUserRegistration.buildNicknameBase('', '');
		Assert.areEqual(
			'user',
			blankStrings,
			'Empty-string first/last name should also fall back to the default base.'
		);
	}

	static CatalystExternalUserRegistration.Request buildRequest(
		Id accountId,
		Id contactId,
		Id profileId,
		String uniqueSuffix
	) {
		CatalystExternalUserRegistration.Request request = new CatalystExternalUserRegistration.Request();
		request.firstName = 'Portal';
		request.lastName = 'Tester' + uniqueSuffix;
		request.email = 'portal.tester' + uniqueSuffix + '@example.invalid';
		request.username = 'portal.tester' + uniqueSuffix + '@example.invalid.catalyst';
		request.profileId = profileId;
		request.accountId = accountId;
		request.contactId = contactId;
		request.password = 'CatalystTest#12345';
		return request;
	}
}